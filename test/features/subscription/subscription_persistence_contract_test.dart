import 'dart:io';

import 'package:facetune/features/subscription/domain/catalog/subscription_plan_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-2 migration SQL.
///
/// These assert the schema, constraints, grants, and RLS *as declared*. They
/// deliberately do not claim to prove PostgreSQL's runtime enforcement — that
/// needs a live database and is recorded as a manual verification step. This
/// mirrors `tutorial_persistence_contract_test.dart` and
/// `makeup_kit_security_contract_test.dart`, the established way this project
/// proves ownership and privilege rules without a database in the test
/// environment.
///
/// Matching is whitespace-insensitive, via [declares]. The 12 pre-existing
/// baseline failures recorded in `SUB_0_BASELINE_AUDIT.md` are all multi-line
/// `contains` assertions that embed a literal `\n` and so fail on a CRLF
/// checkout. Collapsing whitespace fixes that and the wider brittleness behind
/// it: reindenting a constraint should not break a test about what the
/// constraint *says*.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260907000100_subscription_foundation.sql',
  );

  /// The migration with SQL line comments stripped, so an identifier discussed
  /// in a comment is not mistaken for a declaration.
  final statements = migration
      .split(RegExp(r'\r?\n'))
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  final flattened = collapse(statements);

  /// Asserts the migration declares [snippet], ignoring line breaks and
  /// indentation.
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
    test('is ordered after every migration that predates it', () {
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

      const thisMigration = '20260907000100_subscription_foundation.sql';
      expect(names, contains(thisMigration));

      // Asserting this file is *last* would be wrong: later subscription
      // phases legitimately add migrations after it. What must hold is that it
      // applies after everything that existed when it was written — the whole
      // pre-subscription schema it foreign-keys into.
      final predecessors = names.takeWhile((name) => name != thisMigration);
      expect(
        predecessors,
        contains('20260831000100_tutorial_session_arbiter_indexes.sql'),
      );
      expect(predecessors, contains('20260807000100_initial_schema.sql'));
      for (final name in predecessors) {
        expect(name.compareTo(thisMigration), lessThan(0));
      }
    });

    test('is additive: it alters and drops no pre-existing object', () {
      const permittedDrops = [
        'drop policy if exists "subscription_products_select_active"',
        'drop policy if exists "user_entitlements_select_own"',
        'drop policy if exists "usage_ledger_select_own"',
        'drop trigger if exists usage_ledger_committed_immutable',
        'drop trigger if exists subscription_products_set_updated_at',
        'drop trigger if exists user_entitlements_set_updated_at',
        'drop trigger if exists usage_ledger_set_updated_at',
      ];
      for (final line in statements.split('\n')) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('drop ')) continue;
        expect(
          permittedDrops.any(trimmed.startsWith),
          isTrue,
          reason: 'unexpected DROP: $trimmed',
        );
      }

      // The only ALTERs enable RLS on the tables this migration itself creates.
      final alters = statements
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.startsWith('alter table'))
          .toSet();
      expect(alters, {
        'alter table public.subscription_products enable row level security;',
        'alter table public.user_entitlements enable row level security;',
        'alter table public.usage_ledger enable row level security;',
      });
    });

    test('does not touch the existing AI rate limiter', () {
      // ai_usage_events and consume_ai_quota answer a different question and
      // must keep working untouched.
      declaresNot('ai_usage_events');
      declaresNot('consume_ai_quota');
    });

    test('never disables row level security', () {
      expect(migration, isNot(contains('disable row level security')));
      for (final table in [
        'public.subscription_products',
        'public.user_entitlements',
        'public.usage_ledger',
      ]) {
        declares('alter table $table enable row level security;');
      }
    });

    test('introduces no service-role or privileged secret reference', () {
      expect(migration.toLowerCase(), isNot(contains('service_role')));
    });
  });

  group('controlled vocabularies', () {
    test('plan codes are constrained to the canonical five', () {
      for (final table in ['subscription_products', 'user_entitlements']) {
        declares(
          "constraint ${table}_plan_code_valid check (plan_code in "
          "('free', 'plus', 'pro', 'salon_pro', 'salon_pilot'))",
        );
      }
    });

    test('entitlement statuses are constrained to the canonical six', () {
      declares(
        "constraint user_entitlements_status_valid check ( status in ( "
        "'pending', 'active', 'grace_period', 'expired', 'suspended', "
        "'revoked' ) )",
      );
    });

    test('billing providers are constrained to the canonical four', () {
      for (final table in ['subscription_products', 'user_entitlements']) {
        declares(
          "constraint ${table}_billing_provider_valid check ( "
          "billing_provider in ( 'none', 'google_play', 'apple_app_store', "
          "'admin_granted' ) )",
        );
      }
    });

    test('usage statuses are constrained to reserved/committed/released', () {
      declares(
        "constraint usage_ledger_status_valid check (status in "
        "('reserved', 'committed', 'released'))",
      );
    });

    test('usage type is constrained to the one V1 billable unit', () {
      declares(
        "constraint usage_ledger_usage_type_valid "
        "check (usage_type in ('final_makeup_preview'))",
      );
    });

    test('source mode is an explicit discriminator, not an inference', () {
      declares(
        "constraint usage_ledger_source_mode_valid check (source_mode is null "
        "or source_mode in ('standard', 'makeup_kit'))",
      );
      declares(
        'constraint usage_ledger_preview_lineage',
        reason: 'the populated preview id must agree with the declared mode',
      );
    });
  });

  group('idempotency and capacity integrity', () {
    test('one logical operation can only ever create one ledger row', () {
      declares(
        'constraint usage_ledger_operation_unique unique (operation_id)',
      );
    });

    test('one canonical preview can be billed at most once', () {
      declares(
        'create unique index if not exists usage_ledger_canonical_preview_idx '
        'on public.usage_ledger (canonical_generated_image_id);',
      );
      declares(
        'create unique index if not exists '
        'usage_ledger_canonical_kit_preview_idx '
        'on public.usage_ledger (canonical_kit_generated_image_id);',
      );
    });

    test('preview uniqueness indexes are plain, not partial', () {
      // 20260831000100 documents why: PostgREST cannot emit the predicate a
      // partial index needs for ON CONFLICT inference, which fails with 42P10.
      final previewIndexes = statements
          .split(';')
          .where(
            (statement) =>
                statement.contains('unique index') &&
                statement.contains('canonical'),
          )
          .toList();
      expect(previewIndexes, hasLength(2));
      for (final statement in previewIndexes) {
        expect(statement, isNot(contains('where')));
      }
    });

    test('no stored remaining-balance column exists', () {
      // Available capacity is derived from the ledger, so there is no counter
      // to desync or to tamper with.
      for (final forbidden in [
        'remaining',
        'ai_looks_used',
        'ai_look_remaining',
        'available_ai_looks',
        'looks_left',
      ]) {
        declaresNot(
          forbidden,
          reason: 'capacity must be derived, not stored ($forbidden)',
        );
      }
    });

    test('at most one currently-entitled row per account', () {
      declares(
        'create unique index if not exists user_entitlements_one_current_idx '
        "on public.user_entitlements (user_id) "
        "where status in ('active', 'grace_period');",
      );
    });

    test('one provider subscription resolves to one entitlement', () {
      declares(
        'create unique index if not exists '
        'user_entitlements_provider_reference_idx '
        'on public.user_entitlements (provider_subscription_reference);',
      );
    });
  });

  group('ownership and cross-account safety', () {
    test('composite owner identities exist for both new owned tables', () {
      declares(
        'constraint user_entitlements_owner_identity unique (id, user_id)',
      );
      declares('constraint usage_ledger_owner_identity unique (id, user_id)');
    });

    test('usage is foreign-keyed to the entitlement AND its owner', () {
      declares(
        'constraint usage_ledger_entitlement_owner_fk '
        'foreign key (entitlement_id, user_id) '
        'references public.user_entitlements(id, user_id)',
      );
    });

    test('another account\'s canonical preview cannot be attached', () {
      // user_id is part of the foreign key, so a cross-account preview
      // reference has no matching parent row and is rejected at write time.
      declares(
        'constraint usage_ledger_canonical_preview_owner_fk '
        'foreign key (canonical_generated_image_id, user_id) '
        'references public.generated_images(id, user_id)',
      );
      declares(
        'constraint usage_ledger_canonical_kit_preview_owner_fk '
        'foreign key (canonical_kit_generated_image_id, user_id) '
        'references public.kit_generated_images(id, user_id)',
      );
    });

    test('deleting a history item does not refund a committed AI Look', () {
      // ON DELETE SET NULL restricted to the preview column: the link clears,
      // the committed row and its committed_at survive. Without the column
      // list the action would try to null user_id, which is NOT NULL.
      declares('on delete set null (canonical_generated_image_id)');
      declares('on delete set null (canonical_kit_generated_image_id)');
    });

    test('a commit stays self-describing after its preview is deleted', () {
      // source_mode is never nulled, so a committed row records which pipeline
      // produced it even once the preview id is gone.
      declares(
        'constraint usage_ledger_committed_requires_source_mode '
        "check (status <> 'committed' or source_mode is not null)",
      );
    });
  });

  group('historical integrity', () {
    test('committed rows are immutable, with one narrow exception', () {
      declares(
        'create or replace function public.reject_committed_usage_mutation()',
      );
      declares('security definer');
      declares("set search_path = ''");
      declares(
        'create trigger usage_ledger_committed_immutable '
        'before update on public.usage_ledger',
      );
      declares('committed usage_ledger rows are immutable historical records');
    });

    test('a committed row can never be rewritten into a released one', () {
      declares("if old.status <> 'committed' then");
      declares('new.status = old.status');
      declares('new.committed_at = old.committed_at');
      declares('new.operation_id = old.operation_id');
      declares('new.entitlement_id = old.entitlement_id');
    });

    test('no DELETE trigger blocks the account-deletion cascade', () {
      // A BEFORE DELETE guard would fire on the auth.users cascade and make
      // account deletion fail. Deletion is prevented by absent privilege.
      declaresNot('before delete on public.usage_ledger');
    });

    test('status implies exactly which lifecycle timestamps exist', () {
      declares(
        "constraint usage_ledger_status_timestamps check ( "
        "(status = 'reserved' and committed_at is null and released_at is null)",
      );
      declares(
        "status = 'committed' and committed_at is not null "
        'and released_at is null',
      );
      declares(
        "status = 'released' and released_at is not null "
        'and committed_at is null',
      );
    });

    test('a released reservation produced nothing to point at', () {
      declares(
        "constraint usage_ledger_released_has_no_preview check ( "
        "status <> 'released' or ( source_mode is null "
        'and canonical_generated_image_id is null '
        'and canonical_kit_generated_image_id is null )',
      );
    });

    test('a failure reason belongs only to a released operation', () {
      declares(
        'constraint usage_ledger_failure_code_scoped '
        "check (sanitized_failure_code is null or status = 'released')",
      );
      // Bounded and sanitized: never a provider payload or stack trace.
      declares('char_length(btrim(sanitized_failure_code)) between 1 and 64');
    });

    test('reservation always precedes commit or release', () {
      declares(
        'constraint usage_ledger_committed_after_reserved '
        'check (committed_at is null or committed_at >= reserved_at)',
      );
      declares(
        'constraint usage_ledger_released_after_reserved '
        'check (released_at is null or released_at >= reserved_at)',
      );
    });

    test('usage stays linked to the period it happened in', () {
      declares('constraint usage_ledger_period_pair');
      declares('constraint usage_ledger_period_ordered');
    });
  });

  group('privilege model', () {
    test('all write privilege is revoked from clients on all three tables', () {
      for (final table in [
        'public.subscription_products',
        'public.user_entitlements',
        'public.usage_ledger',
      ]) {
        declares('revoke all on table $table from anon;');
        declares('revoke all on table $table from authenticated;');
      }
    });

    test('no insert, update, or delete is ever granted to a client', () {
      final grants = statements
          .split(';')
          .map(collapse)
          .where((statement) => statement.startsWith('grant '))
          .toList();
      expect(grants, isNotEmpty);
      for (final grant in grants) {
        // Take the privilege list only, dropping any parenthesised column
        // list — a column named `updated_at` is not an UPDATE privilege.
        final privileges = grant
            .substring('grant '.length, grant.indexOf(' on table'))
            .replaceAll(RegExp(r'\([^)]*\)'), '')
            .trim();
        expect(
          privileges,
          'select',
          reason: 'clients get read access only: $grant',
        );
      }
    });

    test('no write policy exists for any of the three tables', () {
      for (final action in ['for insert', 'for update', 'for delete']) {
        declaresNot(
          action,
          reason: 'a write policy would imply an intended client write path',
        );
      }
    });

    test('users may read only their own entitlement and usage', () {
      declares(
        'create policy "user_entitlements_select_own" '
        'on public.user_entitlements for select to authenticated '
        'using ((select auth.uid()) = user_id);',
      );
      declares(
        'create policy "usage_ledger_select_own" '
        'on public.usage_ledger for select to authenticated '
        'using ((select auth.uid()) = user_id);',
      );
    });

    test('the provider reference is withheld from clients', () {
      // Least privilege on provider references: the column is absent from the
      // column-level grant, so a client read cannot return it.
      final grantBlock = flattened.substring(
        flattened.indexOf('grant select ('),
        flattened.indexOf(') on table public.user_entitlements'),
      );
      expect(grantBlock, isNot(contains('provider_subscription_reference')));
      for (final exposed in [
        'plan_code',
        'status',
        'base_ai_look_allowance',
        'allowance_adjustment_total',
        'period_end',
        'expires_at',
      ]) {
        expect(grantBlock, contains(exposed));
      }
    });

    test('product configuration is readable but only while active', () {
      declares(
        'create policy "subscription_products_select_active" '
        'on public.subscription_products for select to authenticated '
        'using (active);',
      );
    });
  });

  group('plan semantics are persistable', () {
    test('Free: one-time, no provider, no period, no expiry', () {
      declares("('free', 'FaceTune Free', false, 'none', null, 1, 'none')");
      declares(
        "constraint user_entitlements_free_shape check ( plan_code <> 'free' "
        "or ( billing_provider = 'none' and period_start is null "
        'and period_end is null and expires_at is null '
        'and auto_renew = false',
      );
    });

    test('recurring plans carry a verified billing period', () {
      declares(
        "('plus', 'FaceTune Plus', true, 'google_play', 'month', 3, "
        "'billing_period')",
      );
      declares(
        "('pro', 'FaceTune Pro', true, 'google_play', 'month', 8, "
        "'billing_period')",
      );
      declares(
        "( 'salon_pro', 'Salon Pro', true, 'google_play', 'month', 35, "
        "'billing_period' )",
      );
      declares(
        'constraint user_entitlements_period_pair check ( '
        '(period_start is null and period_end is null) '
        'or (period_start is not null and period_end is not null) )',
      );
      declares(
        'constraint user_entitlements_paid_plan_shape check ( '
        "plan_code not in ('plus', 'pro', 'salon_pro') "
        "or billing_provider in ('google_play', 'apple_app_store') )",
      );
    });

    test('Salon Pilot: admin granted, must expire, never renews', () {
      declares(
        "('salon_pilot', 'Salon Pilot', false, 'admin_granted', null, 30, "
        "'none')",
      );
      declares(
        "constraint user_entitlements_salon_pilot_shape check ( "
        "plan_code <> 'salon_pilot' or ( "
        "billing_provider = 'admin_granted' and expires_at is not null "
        'and auto_renew = false',
      );
      declares(
        'constraint subscription_products_salon_pilot_not_public check '
        "(plan_code <> 'salon_pilot' or publicly_purchasable = false)",
      );
    });

    test('admin_granted cannot be used to hand out a paid plan', () {
      declares(
        'constraint user_entitlements_admin_granted_is_salon_pilot check '
        "(billing_provider <> 'admin_granted' or plan_code = 'salon_pilot')",
      );
    });

    test('only a store-backed plan can be purchasable', () {
      declares(
        'constraint subscription_products_purchasable_requires_store check ( '
        'publicly_purchasable = false or billing_provider in '
        "('google_play', 'apple_app_store') )",
      );
    });

    test('an adjustment can never drive the effective grant below zero', () {
      declares(
        'constraint user_entitlements_effective_allowance_not_negative '
        'check (base_ai_look_allowance + allowance_adjustment_total >= 0)',
      );
    });

    test('a recurring allowance needs an interval and vice versa', () {
      declares(
        'constraint subscription_products_reset_interval_agree check ( '
        "(reset_policy = 'billing_period' and billing_interval is not null) "
        "or (reset_policy = 'none' and billing_interval is null) )",
      );
    });
  });

  group('server and client agree on the V1 baseline', () {
    /// The seeded product row for [plan], as a whitespace-collapsed string.
    String seedRowFor(SubscriptionPlanCode plan) {
      final values = flattened.substring(
        flattened.indexOf('insert into public.subscription_products'),
      );
      final start = values.indexOf("'${plan.code}',");
      expect(start, greaterThan(-1), reason: '${plan.code} must be seeded');
      final end = values.indexOf(')', start);
      return values.substring(start, end).trim();
    }

    test('every seeded allowance matches the Flutter plan catalog', () {
      // Two records of the same approved numbers exist: this seed, which the
      // entitlement engine reads, and the SUB-1 catalog, which describes plans
      // for presentation. They must not drift.
      for (final plan in SubscriptionPlanCode.values) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        expect(
          seedRowFor(plan),
          contains(', ${definition.baseAiLookAllowance},'),
          reason:
              '${plan.code} must be seeded with allowance '
              '${definition.baseAiLookAllowance}',
        );
      }
    });

    test('every seeded reset policy matches the Flutter plan catalog', () {
      for (final plan in SubscriptionPlanCode.values) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        final expected = definition.resetPolicy == ResetPolicy.billingPeriod
            ? "'billing_period'"
            : "'none'";
        expect(
          seedRowFor(plan),
          endsWith(expected),
          reason: '${plan.code} reset policy must match the catalog',
        );
      }
    });

    test('every seeded display name matches the Flutter plan catalog', () {
      for (final plan in SubscriptionPlanCode.values) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        expect(
          seedRowFor(plan),
          contains("'${definition.displayName}'"),
          reason: '${plan.code} display name must match the catalog',
        );
      }
    });

    test('seeded purchasability matches the Flutter plan catalog', () {
      for (final plan in SubscriptionPlanCode.values) {
        final definition = SubscriptionPlanCatalog.definitionFor(plan);
        expect(
          seedRowFor(plan),
          contains(definition.publiclyPurchasable ? ', true,' : ', false,'),
          reason: '${plan.code} purchasability must match the catalog',
        );
      }
    });
  });
}
