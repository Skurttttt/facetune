import 'dart:io';

import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-3 entitlement resolver.
///
/// The resolver's *behaviour* was proven against live PostgreSQL 17.6 and is
/// recorded in the SUB-3 completion report — 19 scenarios covering every plan,
/// every blocking status, capacity arithmetic, and cross-user isolation. These
/// tests pin the declarations that behaviour depends on, so a later edit cannot
/// quietly remove a guard that no Dart test would otherwise notice.
///
/// Matching is whitespace-insensitive via [declares], for the reason given in
/// `subscription_persistence_contract_test.dart`.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260907000200_subscription_entitlement_resolver.sql',
  );

  final statements = migration
      .split(RegExp(r'\r?\n'))
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  final flattened = collapse(statements);

  void declares(String snippet, {String? reason}) => expect(
    flattened,
    contains(collapse(snippet)),
    reason: reason ?? 'migration must declare: $snippet',
  );

  void declaresNot(String snippet, {String? reason}) => expect(
    flattened,
    isNot(contains(collapse(snippet))),
    reason: reason ?? 'migration must not declare: $snippet',
  );

  group('migration hygiene', () {
    test('is ordered after the SUB-2 foundation', () {
      final names =
          Directory(
                '${root.path}${Platform.pathSeparator}supabase'
                '${Platform.pathSeparator}migrations',
              )
              .listSync()
              .whereType<File>()
              .map((file) => file.path.split(Platform.pathSeparator).last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();

      const thisMigration =
          '20260907000200_subscription_entitlement_resolver.sql';
      const foundation = '20260907000100_subscription_foundation.sql';

      expect(names, contains(thisMigration));
      // The resolver reads the tables SUB-2 creates, so it must apply after
      // them. Not asserted to be last: SUB-4 will add more.
      expect(names.indexOf(foundation), lessThan(names.indexOf(thisMigration)));
    });

    test(
      'is purely additive: no table, policy, grant, or trigger is changed',
      () {
        for (final forbidden in [
          'alter table',
          'drop table',
          'drop policy',
          'drop trigger',
          'create table',
          'create policy',
          'disable row level security',
        ]) {
          declaresNot(forbidden);
        }
      },
    );

    test('does not touch the existing AI rate limiter', () {
      declaresNot('ai_usage_events');
      declaresNot('consume_ai_quota');
    });

    test('introduces no service-role reference', () {
      expect(migration.toLowerCase(), isNot(contains('service_role')));
    });
  });

  group('server authority', () {
    test('the resolver takes no arguments, so it cannot be aimed', () {
      // Cross-user resolution is not blocked by a check that could be
      // misconfigured — there is simply no parameter to pass.
      declares(
        'create or replace function public.resolve_subscription_state()',
      );
      declaresNot('resolve_subscription_state(p_user');
      declaresNot('resolve_subscription_state(uuid');
    });

    test('the account is derived from the request JWT', () {
      declares('v_user uuid := (select auth.uid());');
      declares("if v_user is null then");
      declares("'denialReason', 'AUTH_REQUIRED'");
    });

    test('it runs security definer with a pinned search path', () {
      declares('security definer');
      declares("set search_path = ''");
    });

    test('it is declared stable, so it cannot mutate usage', () {
      declares('stable');
      for (final write in ['insert into', 'update public.', 'delete from']) {
        declaresNot(write, reason: 'SUB-3 resolves; SUB-4 mutates');
      }
    });

    test('only authenticated callers may execute it', () {
      declares(
        'revoke all on function public.resolve_subscription_state() from public;',
      );
      declares(
        'revoke all on function public.resolve_subscription_state() from anon;',
      );
      declares(
        'grant execute on function public.resolve_subscription_state() '
        'to authenticated;',
      );
    });

    test('time comes from the database, never from a caller', () {
      declares("v_now timestamptz := timezone('utc', now());");
      declaresNot('p_now');
      declaresNot('current_setting(\'request.jwt.claims\')::json->>\'now\'');
    });

    test('every query is scoped to the resolved account', () {
      declares('where e.user_id = v_user');
      declares('and u.user_id = v_user');
    });
  });

  group('capacity arithmetic', () {
    test('effective allowance is base plus adjustment, floored at zero', () {
      declares(
        'v_effective := greatest( 0, v_ent.base_ai_look_allowance '
        '+ v_ent.allowance_adjustment_total );',
      );
    });

    test('available capacity subtracts committed and reserved', () {
      declares(
        'v_available := greatest(0, v_effective - v_committed - v_reserved);',
      );
    });

    test('user-facing remaining ignores in-flight reservations', () {
      declares('v_remaining := greatest(0, v_effective - v_committed);');
    });

    test('capacity is never negative', () {
      // Both figures are floored, so an over-committed entitlement reports 0
      // rather than a negative balance.
      expect(
        RegExp(r'greatest\(\s*0,').allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('only reserved and committed rows consume capacity', () {
      declares("count(*) filter (where u.status = 'committed')");
      declares("count(*) filter (where u.status = 'reserved')");
      declaresNot("filter (where u.status = 'released')");
    });

    test('period membership uses the event time, not a copied timestamp', () {
      // Comparing the row's stamped period_start to the entitlement's is
      // fragile: sub-millisecond drift between two independently written
      // timestamps detaches every row and silently reports a full allowance.
      declares(
        'v_ent.period_start is null or u.reserved_at >= v_ent.period_start',
      );
      declaresNot('u.period_start = v_ent.period_start');
    });

    test('a reset never deletes or rewrites history', () {
      declaresNot('delete from public.usage_ledger');
      declaresNot('update public.usage_ledger');
    });

    test('no remaining balance is read from a stored column', () {
      // Capacity is computed per call from the ledger; there is no second
      // source of truth to drift.
      declaresNot('remaining_ai_looks');
      declaresNot('available_ai_looks');
    });
  });

  group('authorization outcomes', () {
    test('every denial reason is a shared contract error code', () {
      const emitted = [
        'AUTH_REQUIRED',
        'ENTITLEMENT_NOT_FOUND',
        'ENTITLEMENT_REVOKED',
        'ENTITLEMENT_SUSPENDED',
        'ENTITLEMENT_EXPIRED',
        'ENTITLEMENT_PENDING',
        'ENTITLEMENT_INACTIVE',
        'SALON_PILOT_EXPIRED',
        'AI_LOOK_LIMIT_REACHED',
      ];
      final known = SubscriptionErrorCode.values.map((e) => e.code).toSet();
      for (final code in emitted) {
        expect(
          known,
          contains(code),
          reason: '$code must exist in the shared Dart error vocabulary',
        );
        declares("'$code'");
      }
    });

    test('only active and grace_period can authorize generation', () {
      declares("elsif v_ent.status not in ('active', 'grace_period') then");
      declares("v_reason := 'ENTITLEMENT_INACTIVE';");
    });

    test('a lapsed stored end date blocks before any sweep runs', () {
      declares(
        'elsif v_ent.expires_at is not null and v_ent.expires_at <= v_now then',
      );
      declares(
        'elsif v_ent.period_end is not null and v_ent.period_end <= v_now then',
      );
    });

    test('a future start date is not yet entitled', () {
      declares('elsif v_ent.starts_at > v_now then');
    });

    test('an expired Salon Pilot reports its own reason', () {
      declares(
        "v_reason := case when v_ent.plan_code = 'salon_pilot' "
        "then 'SALON_PILOT_EXPIRED' else 'ENTITLEMENT_EXPIRED' end;",
      );
    });

    test('a missing entitlement is refused, never synthesized', () {
      // Free is the default plan, but a plan is not a grant: usage_ledger
      // requires a persisted entitlement to anchor to.
      declares("'hasEntitlement', false");
      declares("'denialReason', 'ENTITLEMENT_NOT_FOUND'");
      declares("'effectiveAllowance', 0");
    });
  });

  group('sanitized response', () {
    test('withholds the provider reference and the concurrency version', () {
      declaresNot(
        'provider_subscription_reference',
        reason: 'provider references stay server-side under least privilege',
      );
      declaresNot("'version', v_ent.version");
    });

    test('exposes the user-facing subscription state', () {
      for (final key in [
        "'planCode'",
        "'planDisplayName'",
        "'entitlementStatus'",
        "'effectiveAllowance'",
        "'committedUsage'",
        "'reservedUsage'",
        "'availableAiLooks'",
        "'remainingAiLooks'",
        "'periodEnd'",
        "'expiresAt'",
        "'resetAt'",
        "'generationAuthorized'",
        "'denialReason'",
      ]) {
        declares(key);
      }
    });

    test('resetAt is the renewal date only for recurring plans', () {
      declares(
        "'resetAt', case when v_reset_policy = 'billing_period' "
        'then v_ent.period_end else null end',
      );
    });
  });
}
