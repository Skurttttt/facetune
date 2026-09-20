import 'dart:io';

import 'package:facetune/features/subscription/data/models/subscription_summary_dto.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-12 Free / Salon Pilot migration, as written.
///
/// The migration's *behaviour* was proven against live PostgreSQL 17.6 — 65
/// scenarios covering Free provisioning (including two concurrent sessions),
/// lifetime reset protection across month/year/session/purchase/renewal/
/// expiry/restore/re-subscription, Salon Pilot allowance arithmetic and audited
/// adjustment, status enforcement, store isolation, client privilege, and the
/// SUB-10/SUB-11 regressions — and is recorded in the SUB-12 completion report.
/// These tests pin the declarations that behaviour depends on, in the same way
/// `subscription_resolver_contract_test.dart` and
/// `purchase_verification_contract_test.dart` do, so a later edit cannot
/// quietly remove a guard no Dart test would otherwise notice.
///
/// Matching is whitespace-insensitive via [declares] and line endings are
/// normalized, so a CRLF checkout or a reindent cannot fail a test about what
/// a statement *says*.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  String source(String relativePath) =>
      File(pathOf(relativePath)).readAsStringSync().replaceAll('\r\n', '\n');

  String sqlCodeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  const migrationPath =
      'supabase/migrations/20260920000100_free_and_salon_pilot_compatibility.sql';
  const sub10Path =
      'supabase/migrations/20260910000100_google_play_purchase_verification.sql';
  const sub2Path =
      'supabase/migrations/20260907000100_subscription_foundation.sql';

  final migration = source(migrationPath);
  final code = sqlCodeOnly(migration);
  final flattened = collapse(code);

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
    test('is ordered after the SUB-11 reconciliation migration', () {
      final names =
          Directory(pathOf('supabase/migrations'))
              .listSync()
              .whereType<File>()
              .map((file) => file.path.split(Platform.pathSeparator).last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();
      const thisMigration =
          '20260920000100_free_and_salon_pilot_compatibility.sql';
      const sub11 = '20260917000100_subscription_lifecycle_reconciliation.sql';
      expect(names, contains(thisMigration));
      expect(names.indexOf(sub11), lessThan(names.indexOf(thisMigration)));
    });

    test('drops no table, policy, or column and never disables RLS', () {
      for (final forbidden in [
        'drop table',
        'drop policy',
        'drop column',
        'disable row level security',
        'alter table public.user_entitlements',
        'alter table public.usage_ledger',
        'alter table public.subscription_products',
      ]) {
        declaresNot(forbidden);
      }
    });

    test('changes no product configuration', () {
      // Allowances and purchasability live in `subscription_products`. This
      // phase reads that table; it must not rewrite the approved baseline.
      declaresNot('update public.subscription_products');
      declaresNot('insert into public.subscription_products');
    });

    test('creates no RLS policy: nothing here is client-writable', () {
      declaresNot('create policy');
    });

    test('adds no new plan, product, or credit concept', () {
      for (final forbidden in [
        'plus_preview',
        'pro_preview',
        'salon_preview',
        'top_up',
        'topup',
        'purchased_credit',
        'credit_balance',
      ]) {
        expect(
          migration.toLowerCase(),
          isNot(contains(forbidden)),
          reason: 'SUB-12 must not implement $forbidden',
        );
      }
    });

    test('does not touch the existing AI rate limiter', () {
      declaresNot('ai_usage_events');
      declaresNot('consume_ai_quota');
    });
  });

  group('Free is structurally one per account', () {
    test('a unique partial index makes a second Free row unrepresentable', () {
      declares(
        'create unique index if not exists user_entitlements_one_free_idx '
        "on public.user_entitlements (user_id) where plan_code = 'free';",
      );
    });

    test('the one-current rule no longer counts Free', () {
      // Same name as SUB-2, narrowed so Free can sit beside a live paid row.
      declares(
        'drop index if exists public.user_entitlements_one_current_idx;',
      );
      declares(
        'create unique index user_entitlements_one_current_idx '
        'on public.user_entitlements (user_id) '
        "where status in ('active', 'grace_period') and plan_code <> 'free';",
      );
    });

    test('provisioning is idempotent against that index', () {
      declares("on conflict (user_id) where plan_code = 'free' do nothing");
    });
  });

  group('Free provisioning', () {
    test('one function defines the Free shape', () {
      declares(
        'create or replace function public.provision_free_entitlement('
        'p_user_id uuid)',
      );
      declares("'free', 'active', 'none',");
      // The allowance is read from the product row, never written as a literal.
      declares(
        'select p.base_ai_look_allowance into v_allowance '
        'from public.subscription_products as p '
        "where p.plan_code = 'free' and p.active;",
      );
    });

    test('the provisioning function is held by no client role', () {
      declares(
        'revoke all on function public.provision_free_entitlement(uuid) '
        'from public;',
      );
      declares(
        'revoke all on function public.provision_free_entitlement(uuid) '
        'from anon;',
      );
      declares(
        'revoke all on function public.provision_free_entitlement(uuid) '
        'from authenticated;',
      );
      declaresNot(
        'grant execute on function public.provision_free_entitlement',
        reason: 'no role, including service_role, is granted provisioning',
      );
    });

    test('the account-creation trigger provisions Free', () {
      declares('create or replace function public.handle_new_auth_user()');
      declares('perform public.provision_free_entitlement(new.id);');
      // The trigger binding itself is Phase 4's and is not recreated.
      declaresNot('create trigger on_auth_user_created');
      // The profile and settings inserts survive unchanged.
      declares('insert into public.profiles (auth_user_id, display_name)');
      declares('insert into public.user_settings (user_id)');
    });

    test('existing accounts are backfilled through the same function', () {
      declares(
        'perform public.provision_free_entitlement(u.id) from auth.users as u;',
      );
    });

    test('no client-callable initialize RPC exists', () {
      // The only `to authenticated` grant in the file is the resolver's
      // restatement; nothing that provisions, grants, or adjusts is opened.
      expect(
        RegExp(
          r'grant execute on function [^;]* to authenticated',
        ).allMatches(flattened).map((m) => m.group(0)).toList(),
        [
          'grant execute on function public.resolve_subscription_state() '
              'to authenticated',
        ],
      );
    });
  });

  group('Free lifetime guard', () {
    test('a Free row cannot be retired, reset, resized, or converted', () {
      declares(
        'create or replace function public.guard_free_entitlement_lifetime()',
      );
      declares(
        'create trigger user_entitlements_free_lifetime_guard '
        'before insert or update on public.user_entitlements',
      );
      for (final column in [
        'new.status <> old.status',
        'new.base_ai_look_allowance <> old.base_ai_look_allowance',
        'new.allowance_adjustment_total <> old.allowance_adjustment_total',
        'new.plan_code <> old.plan_code',
        'new.billing_provider <> old.billing_provider',
        'new.expires_at is distinct from old.expires_at',
        'new.period_start is distinct from old.period_start',
      ]) {
        declares(column);
      }
      declares("if new.plan_code = 'free' then raise exception");
    });

    test('a Free row is provisioned active at the configured allowance', () {
      declares(
        "if new.status <> 'active' or new.allowance_adjustment_total <> 0",
      );
      declares('new.base_ai_look_allowance <> v_product_allowance');
    });
  });

  group('resolver precedence', () {
    test('an in-force store or admin entitlement outranks Free', () {
      declares(
        "case when e.plan_code <> 'free' "
        "and e.status in ('active', 'grace_period', 'suspended') "
        'and e.starts_at <= v_now '
        'and (e.expires_at is null or e.expires_at > v_now) '
        'and (e.period_end is null or e.period_end > v_now) then 0 '
        "when e.plan_code = 'free' then 1 else 2 end,",
      );
    });

    test('the SUB-3 status order and refusal order are preserved', () {
      declares(
        "case e.status when 'active' then 0 when 'grace_period' then 1 "
        "when 'suspended' then 2 when 'pending' then 3 when 'expired' then 4 "
        "when 'revoked' then 5 else 6 end, e.starts_at desc, e.created_at desc "
        'limit 1;',
      );
      // Status before capacity: remaining allowance never overrides a block.
      final refusals = RegExp(
        r"if v_ent\.status = 'revoked' then.*?elsif v_ent\.status = 'suspended'.*?"
        r"elsif v_ent\.status = 'expired'.*?elsif v_ent\.status = 'pending'.*?"
        r'elsif v_ent\.starts_at > v_now.*?'
        r'elsif v_ent\.expires_at is not null and v_ent\.expires_at <= v_now.*?'
        r"'SALON_PILOT_EXPIRED'.*?"
        r'elsif v_ent\.period_end is not null and v_ent\.period_end <= v_now.*?'
        r'elsif v_available <= 0 then v_reason := .AI_LOOK_LIMIT_REACHED.',
      );
      expect(flattened, matches(refusals));
    });

    test('capacity is derived from the ledger, never stored', () {
      declares(
        'v_available := greatest(0, v_effective - v_committed - v_reserved);',
      );
      declares('v_remaining := greatest(0, v_effective - v_committed);');
      declares(
        'v_effective := greatest( 0, '
        'v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total );',
      );
      declares(
        'v_ent.period_start is null or u.reserved_at >= v_ent.period_start',
      );
    });

    test('the resolver stays argument-free, stable, and JWT-derived', () {
      declares(
        'create or replace function public.resolve_subscription_state()',
      );
      declares('v_user uuid := (select auth.uid());');
      final header = RegExp(
        r'resolve_subscription_state\(\) returns jsonb language plpgsql '
        r"security definer stable set search_path = ''",
      );
      expect(flattened, matches(header));
    });

    test('non-store classification is reported from product configuration', () {
      declares("'publiclyPurchasable', coalesce(v_purchasable, false),");
      declares('p.publicly_purchasable into v_display_name');
    });
  });

  group('activation function: one predicate, nothing else', () {
    String functionBody(String text) {
      final start = text.indexOf(
        'create or replace function '
        'public.activate_verified_google_play_subscription(',
      );
      expect(start, greaterThanOrEqualTo(0));
      final end = text.indexOf('\n\$\$;', start);
      expect(end, greaterThan(start));
      return text.substring(start, end + 4);
    }

    test('the SUB-12 redefinition equals SUB-10 plus the Free exclusion', () {
      final original = collapse(sqlCodeOnly(functionBody(source(sub10Path))));
      final redefined = collapse(sqlCodeOnly(functionBody(migration)));

      const insertedPredicate = "and e.plan_code <> 'free' ";
      const anchor =
          "where e.user_id = p_user_id and e.status in ('active', 'grace_period') ";

      expect(original, contains(anchor));
      expect(original, isNot(contains(insertedPredicate)));
      expect(redefined, contains(anchor + insertedPredicate));
      expect(
        redefined.replaceFirst(anchor + insertedPredicate, anchor),
        original,
        reason:
            'the activation function may differ from SUB-10 only by the '
            'predicate that keeps Free out of the retire statement',
      );
    });

    test('the activation function remains service_role only', () {
      const signature =
          'public.activate_verified_google_play_subscription( '
          'uuid, text, text, text, timestamptz, timestamptz, boolean, text, '
          'boolean )';
      declares('revoke all on function $signature from public;');
      declares('revoke all on function $signature from anon;');
      declares('revoke all on function $signature from authenticated;');
      declares('grant execute on function $signature to service_role;');
      expect(
        RegExp(r'to service_role').allMatches(flattened).length,
        1,
        reason: 'no other function is opened to service_role',
      );
    });

    test('store isolation from SUB-10 is untouched', () {
      final sub10 = collapse(sqlCodeOnly(source(sub10Path)));
      expect(
        sub10,
        contains(
          collapse(
            "constraint provider_purchase_verifications_plan_purchasable "
            "check (plan_code in ('plus', 'pro', 'salon_pro'))",
          ),
        ),
      );
      expect(
        sub10,
        contains(
          collapse(
            'where p.provider_product_id = btrim(p_provider_product_id) '
            'and p.active and p.publicly_purchasable '
            "and p.billing_provider = 'google_play';",
          ),
        ),
      );
      // The SUB-2 constraints that keep Free and Salon Pilot out of the store.
      final sub2 = collapse(sqlCodeOnly(source(sub2Path)));
      for (final constraint in [
        'subscription_products_salon_pilot_not_public',
        'subscription_products_free_has_no_provider',
        'subscription_products_salon_pilot_admin_granted',
        'user_entitlements_admin_granted_is_salon_pilot',
        'user_entitlements_salon_pilot_shape',
        'user_entitlements_free_shape',
      ]) {
        expect(sub2, contains(constraint));
      }
    });
  });

  group('Salon Pilot adjustment ledger', () {
    test('the table follows the shared contract adjustment fields', () {
      declares(
        'create table if not exists public.entitlement_allowance_adjustments (',
      );
      for (final column in [
        'entitlement_id uuid not null,',
        'target_user_id uuid not null references auth.users(id) on delete cascade,',
        'admin_user_id uuid references auth.users(id) on delete set null,',
        'adjustment_type text not null,',
        'amount integer not null,',
        'reason text not null,',
        'idempotency_key text not null,',
      ]) {
        declares(column);
      }
      declares(
        "check (adjustment_type in ('increase_allowance', 'decrease_allowance'))",
      );
      declares(
        "(adjustment_type = 'increase_allowance' and amount > 0) "
        "or (adjustment_type = 'decrease_allowance' and amount < 0)",
      );
      declares('unique (entitlement_id, idempotency_key)');
      declares('check (char_length(btrim(reason)) between 1 and 500)');
    });

    test('an adjustment cannot attach to another account\'s entitlement', () {
      declares(
        'foreign key (entitlement_id, target_user_id) '
        'references public.user_entitlements(id, user_id)',
      );
    });

    test('only an admin-granted entitlement is adjustable', () {
      declares(
        "if v_ent.billing_provider <> 'admin_granted' then raise exception",
      );
    });

    test('an adjustment must name its administrator', () {
      declares('if new.admin_user_id is null then raise exception');
    });

    test('a reduction cannot strand committed or reserved usage', () {
      declares(
        'if v_effective_after < v_committed + v_reserved then raise exception',
      );
      declares(
        "count(*) filter (where u.status = 'committed'), "
        "count(*) filter (where u.status = 'reserved')",
      );
    });

    test('adjustments serialize with reservations on the account lock', () {
      declares(
        'perform pg_advisory_xact_lock(hashtextextended('
        'new.target_user_id::text, 0));',
      );
      declares('for update;');
    });

    test('the adjustment total moves only through the ledger', () {
      declares(
        "perform set_config('facetune.applying_allowance_adjustment', 'on', true);",
      );
      declares(
        'create trigger user_entitlements_adjustment_total_guard '
        'before update on public.user_entitlements',
      );
      declares(
        'if new.allowance_adjustment_total <> old.allowance_adjustment_total '
        "and coalesce( current_setting('facetune.applying_allowance_adjustment', "
        "true), '' ) <> 'on'",
      );
    });

    test('adjustment rows are immutable audit records', () {
      declares(
        'create trigger entitlement_allowance_adjustments_immutable '
        'before update on public.entitlement_allowance_adjustments',
      );
      declares(
        "raise exception 'allowance adjustments are immutable audit records';",
      );
      declaresNot(
        'before delete on public.entitlement_allowance_adjustments',
        reason: 'a delete trigger would abort the auth.users cascade',
      );
    });

    test('usage history is never rewritten by an adjustment', () {
      // The apply trigger writes exactly one table: the entitlement's total.
      final apply = flattened.substring(
        flattened.indexOf(
          'create or replace function public.apply_entitlement_allowance_adjustment()',
        ),
        flattened.indexOf(
          'create trigger entitlement_allowance_adjustments_apply',
        ),
      );
      expect(apply, contains('update public.user_entitlements as e'));
      expect(apply, isNot(contains('update public.usage_ledger')));
      expect(apply, isNot(contains('delete from')));
      expect(apply, isNot(contains('insert into')));
    });

    test('no client role can read or write the ledger', () {
      declares(
        'alter table public.entitlement_allowance_adjustments '
        'enable row level security;',
      );
      declares(
        'revoke all on table public.entitlement_allowance_adjustments from anon;',
      );
      declares(
        'revoke all on table public.entitlement_allowance_adjustments '
        'from authenticated;',
      );
      declaresNot(
        'grant select on table public.entitlement_allowance_adjustments',
      );
      declaresNot(
        'grant insert on table public.entitlement_allowance_adjustments',
      );
    });
  });

  group('resolver payload compatibility', () {
    test('a Free payload parses with the added non-store field', () {
      final summary = SubscriptionSummaryDto.fromResponse({
        'hasEntitlement': true,
        'entitlementId': '11111111-1111-1111-1111-111111111111',
        'planCode': 'free',
        'planDisplayName': 'FaceTune Free',
        'entitlementStatus': 'active',
        'billingProvider': 'none',
        'publiclyPurchasable': false,
        'resetPolicy': 'none',
        'resetAt': null,
        'baseAllowance': 1,
        'allowanceAdjustmentTotal': 0,
        'effectiveAllowance': 1,
        'committedUsage': 1,
        'reservedUsage': 0,
        'availableAiLooks': 0,
        'remainingAiLooks': 0,
        'generationAuthorized': false,
        'denialReason': 'AI_LOOK_LIMIT_REACHED',
        'resolvedAt': '2026-09-20T00:00:00Z',
      });
      expect(summary.planCode, SubscriptionPlanCode.free);
      expect(summary.billingProvider, BillingProvider.none);
      expect(summary.resetPolicy, ResetPolicy.none);
      expect(summary.status, EntitlementStatus.active);
      expect(summary.replenishes, isFalse);
      expect(summary.hasEnded, isFalse);
      expect(summary.currentPlan, SubscriptionPlanCode.free);
      expect(summary.usage.remainingAiLooks, 0);
      expect(summary.generationAuthorized, isFalse);
    });

    test('a Salon Pilot payload with an adjustment parses as the contract', () {
      final summary = SubscriptionSummaryDto.fromResponse({
        'hasEntitlement': true,
        'entitlementId': '22222222-2222-2222-2222-222222222222',
        'planCode': 'salon_pilot',
        'planDisplayName': 'Salon Pilot',
        'entitlementStatus': 'active',
        'billingProvider': 'admin_granted',
        'publiclyPurchasable': false,
        'resetPolicy': 'none',
        'resetAt': null,
        'expiresAt': '2026-11-19T00:00:00Z',
        'autoRenew': false,
        'baseAllowance': 30,
        'allowanceAdjustmentTotal': 10,
        'effectiveAllowance': 40,
        'committedUsage': 18,
        'reservedUsage': 0,
        'availableAiLooks': 22,
        'remainingAiLooks': 22,
        'generationAuthorized': true,
        'resolvedAt': '2026-09-20T00:00:00Z',
      });
      expect(summary.planCode, SubscriptionPlanCode.salonPilot);
      expect(summary.billingProvider, BillingProvider.adminGranted);
      expect(summary.usage.effectiveAllowance, 40);
      expect(summary.usage.committedUsage, 18);
      expect(summary.usage.remainingAiLooks, 22);
      expect(summary.usage.availableAiLooks, 22);
      expect(summary.autoRenew, isFalse);
      expect(summary.replenishes, isFalse);
      expect(summary.expiresAt, isNotNull);
    });
  });
}
