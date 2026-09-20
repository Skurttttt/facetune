import 'dart:io';

import 'package:facetune/features/subscription/data/models/subscription_summary_dto.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-12B Preview-only offers migration and the
/// Edge Function gate it introduces, as written.
///
/// The migration's *behaviour* was proven against live PostgreSQL 17.6 — 49
/// scenarios covering the six-plan configuration, Preview activation and
/// accounting (30→29, 80→79, 350→349), duplicate and failure handling,
/// server-side Tutorial denial with ledger provenance across plus ↔
/// plus_preview transitions, lifecycle reuse (renewal, cancel-paid-through,
/// restore, RTDN dedup, expiry), store isolation, privilege, and the
/// concurrent last-credit race — and is recorded in the SUB-12B completion
/// report. These tests pin the declarations that behaviour depends on.
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

  String tsCodeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  const migrationPath =
      'supabase/migrations/20260921000100_preview_only_paid_offers.sql';
  const sub4Path =
      'supabase/migrations/20260907000300_ai_look_usage_engine.sql';

  final migration = source(migrationPath);
  final flattened = collapse(sqlCodeOnly(migration));

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
    test('is ordered after the SUB-12 migration', () {
      final names =
          Directory(pathOf('supabase/migrations'))
              .listSync()
              .whereType<File>()
              .map((file) => file.path.split(Platform.pathSeparator).last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();
      const thisMigration = '20260921000100_preview_only_paid_offers.sql';
      const sub12 = '20260920000100_free_and_salon_pilot_compatibility.sql';
      expect(names, contains(thisMigration));
      expect(names.indexOf(sub12), lessThan(names.indexOf(thisMigration)));
    });

    test('drops no table or policy, never disables RLS, adds no policy', () {
      for (final forbidden in [
        'drop table',
        'drop policy',
        'drop column',
        'disable row level security',
        'create policy',
      ]) {
        declaresNot(forbidden);
      }
    });

    test('leaves the lifecycle writers untouched', () {
      // A Preview purchase activates, renews, restores and reconciles through
      // the SUB-10/SUB-11 functions exactly as a Tutorial-plan purchase does.
      for (final untouched in [
        'activate_verified_google_play_subscription',
        'revoke_google_play_subscription',
        'claim_google_play_notification',
        'finalize_google_play_notification',
        'google_play_purchase_owner',
        'commit_ai_look',
        'release_ai_look',
        'reconcile_stale_ai_look_reservations',
      ]) {
        declaresNot('create or replace function public.$untouched');
      }
    });

    test('implements no top-up, credit ledger, or admin UI concept', () {
      for (final forbidden in [
        'top_up',
        'topup',
        'purchased_credit',
        'credit_balance',
        'grant_salon_pilot',
      ]) {
        expect(migration.toLowerCase(), isNot(contains(forbidden)));
      }
    });

    test('touches no Final Preview model, prompt, or validator', () {
      for (final locked in [
        'gemini',
        'prompt_version',
        'tutorial_guideline',
        'tutorial_manifest_v4',
      ]) {
        expect(migration.toLowerCase(), isNot(contains(locked)));
      }
    });
  });

  group('plan codes are widened to the canonical eight', () {
    const eight =
        "plan_code in ( 'free', 'plus', 'plus_preview', 'pro', 'pro_preview', "
        "'salon_pro', 'salon_preview', 'salon_pilot' )";

    test('on subscription_products and user_entitlements', () {
      for (final table in ['subscription_products', 'user_entitlements']) {
        declares(
          'drop constraint if exists ${table}_plan_code_valid, '
          'add constraint ${table}_plan_code_valid check ( $eight )',
        );
      }
    });

    test('paid plans remain store-backed, Preview plans included', () {
      declares(
        'add constraint user_entitlements_paid_plan_shape check ( '
        "plan_code not in ( 'plus', 'plus_preview', 'pro', 'pro_preview', "
        "'salon_pro', 'salon_preview' ) "
        "or billing_provider in ('google_play', 'apple_app_store') )",
      );
    });

    test('verification rows can only ever name a purchasable plan', () {
      declares(
        'add constraint provider_purchase_verifications_plan_purchasable '
        "check ( plan_code in ( 'plus', 'plus_preview', 'pro', 'pro_preview', "
        "'salon_pro', 'salon_preview' ) )",
      );
    });
  });

  group('capability model', () {
    test('lives on the product row, explicitly, with no default', () {
      declares(
        'add column if not exists allowance_unit text not null '
        "default 'ai_look'",
      );
      declares(
        'add column if not exists tutorial_enabled boolean not null '
        'default true',
      );
      declares('alter column allowance_unit drop default');
      declares('alter column tutorial_enabled drop default');
      declares('alter column final_preview_enabled drop default');
    });

    test('a Final Preview Credit can never authorize a Tutorial', () {
      declares(
        'add constraint subscription_products_preview_credit_no_tutorial '
        "check (allowance_unit <> 'final_preview_credit' "
        'or tutorial_enabled = false)',
      );
      declares(
        'add constraint subscription_products_allowance_unit_valid '
        "check (allowance_unit in ('ai_look', 'final_preview_credit'))",
      );
    });

    test('the three Preview products are seeded with locked allowances', () {
      declares(
        "( 'plus_preview', 'FaceTune Plus Preview', true, 'google_play', "
        "'facetune_plus_preview', 'month', 30, 'billing_period', "
        "'final_preview_credit', false, true )",
      );
      declares(
        "( 'pro_preview', 'FaceTune Pro Preview', true, 'google_play', "
        "'facetune_pro_preview', 'month', 80, 'billing_period', "
        "'final_preview_credit', false, true )",
      );
      declares(
        "( 'salon_preview', 'Salon Preview', true, 'google_play', "
        "'facetune_salon_preview', 'month', 350, 'billing_period', "
        "'final_preview_credit', false, true )",
      );
      declares('on conflict (plan_code) do nothing');
    });

    test('existing product rows are not rewritten', () {
      declaresNot('update public.subscription_products');
    });

    test('the resolver reports capability from the product row', () {
      declares("'allowanceUnit', coalesce(v_allowance_unit, 'ai_look'),");
      declares("'tutorialEnabled', coalesce(v_tutorial_enabled, false),");
      declares(
        "'finalPreviewEnabled', coalesce(v_final_preview_enabled, false),",
      );
      // Precedence is SUB-12's, unchanged.
      declares(
        "case when e.plan_code <> 'free' "
        "and e.status in ('active', 'grace_period', 'suspended')",
      );
      declares(
        'v_available := greatest(0, v_effective - v_committed - v_reserved);',
      );
    });
  });

  group('ledger provenance', () {
    test('every reservation is stamped with its plan and unit', () {
      declares(
        'alter table public.usage_ledger add column if not exists '
        'plan_code text, add column if not exists allowance_unit text;',
      );
      declares(
        'add constraint usage_ledger_provenance_pair check ( '
        '(plan_code is null and allowance_unit is null) '
        'or (plan_code is not null and allowance_unit is not null) )',
      );
    });

    test('existing rows are backfilled from their entitlement, once', () {
      declares(
        'update public.usage_ledger as l set plan_code = e.plan_code, '
        'allowance_unit = p.allowance_unit',
      );
      declares('and l.plan_code is null;');
    });

    test('a stamp is immutable on every row', () {
      declares(
        'create trigger usage_ledger_provenance_guard '
        'before update on public.usage_ledger',
      );
      declares(
        'if old.plan_code is not null and ( '
        'new.plan_code is distinct from old.plan_code '
        'or new.allowance_unit is distinct from old.allowance_unit )',
      );
    });

    test('reserve_ai_look equals SUB-4 plus the stamp, nothing else', () {
      String body(String text) {
        final start = text.indexOf(
          'create or replace function public.reserve_ai_look(p_operation_id uuid)',
        );
        expect(start, greaterThanOrEqualTo(0));
        final end = text.indexOf('\n\$\$;', start);
        return text.substring(start, end + 4);
      }

      final original = collapse(sqlCodeOnly(body(source(sub4Path))));
      final redefined = collapse(sqlCodeOnly(body(migration)));

      // Undo the four known additions and the result must be SUB-4 verbatim.
      final reverted = redefined
          .replaceFirst(' v_plan_code text; v_allowance_unit text;', '')
          .replaceFirst(
            'select e.period_start, e.period_end, e.plan_code, p.allowance_unit '
                'into v_period_start, v_period_end, v_plan_code, v_allowance_unit '
                'from public.user_entitlements as e '
                'join public.subscription_products as p on p.plan_code = e.plan_code',
            'select e.period_start, e.period_end '
                'into v_period_start, v_period_end '
                'from public.user_entitlements as e',
          )
          .replaceFirst(
            'period_start, period_end, reserved_at, plan_code, allowance_unit )',
            'period_start, period_end, reserved_at )',
          )
          .replaceFirst(
            'v_period_start, v_period_end, v_now, v_plan_code, v_allowance_unit )',
            'v_period_start, v_period_end, v_now )',
          );
      expect(
        reverted,
        original,
        reason:
            'reserve_ai_look may differ from SUB-4 only by stamping the '
            'plan and unit onto the reservation row',
      );
      declares(
        'grant execute on function public.reserve_ai_look(uuid) to authenticated;',
      );
    });
  });

  group('server-side Tutorial authorization', () {
    test('is JWT-derived, security definer, read-only, client-callable', () {
      declares(
        'create or replace function public.authorize_tutorial_generation( '
        'p_source_mode text default null, '
        'p_canonical_preview_id uuid default null, '
        'p_tutorial_session_id uuid default null )',
      );
      declares('v_user uuid := (select auth.uid());');
      final header = RegExp(
        r'authorize_tutorial_generation\( [^)]*\) returns jsonb language '
        r"plpgsql security definer stable set search_path = ''",
      );
      expect(flattened, matches(header));
      declares(
        'grant execute on function '
        'public.authorize_tutorial_generation(text, uuid, uuid) to authenticated;',
      );
      declares(
        'revoke all on function '
        'public.authorize_tutorial_generation(text, uuid, uuid) from anon;',
      );
    });

    test('takes no capability argument a caller could forge', () {
      declaresNot('p_tutorial_enabled');
      declaresNot('p_plan_code');
      declaresNot('p_user_id uuid default');
    });

    test('denies from the governing plan\'s capability, by field not name', () {
      declares("if (v_state->>'tutorialEnabled')::boolean is not true then");
      declares("'denialReason', 'TUTORIAL_NOT_INCLUDED',");
      // No branch on a Preview plan's name anywhere in the authorizer.
      final authorizer = flattened.substring(
        flattened.indexOf(
          'create or replace function public.authorize_tutorial_generation(',
        ),
      );
      for (final name in ['plus_preview', 'pro_preview', 'salon_preview']) {
        expect(authorizer, isNot(contains("'$name'")));
      }
    });

    test('denies from the preview\'s stamped provenance', () {
      declares(
        'coalesce(l.plan_code, e.plan_code), '
        "coalesce(l.allowance_unit, p.allowance_unit) = 'ai_look' "
        'into v_provenance_plan, v_provenance_tutorial',
      );
      declares("and l.status = 'committed'");
      declares('if found and v_provenance_tutorial is not true then');
    });

    test('verifies preview ownership inside the authority', () {
      declares(
        'select 1 from public.generated_images as g '
        'where g.id = v_preview and g.user_id = v_user',
      );
      declares(
        'select 1 from public.kit_generated_images as k '
        'where k.id = v_preview and k.user_id = v_user',
      );
      declares(
        'from public.tutorial_v4_sessions as s '
        'where s.id = p_tutorial_session_id and s.user_id = v_user;',
      );
    });
  });

  group('Edge Functions enforce the gate before paid work', () {
    final manifest = tsCodeOnly(
      source('supabase/functions/analyze-tutorial-manifest-v4/index.ts'),
    );
    final step = tsCodeOnly(
      source('supabase/functions/generate-tutorial-step-v4/index.ts'),
    );
    final helper = tsCodeOnly(
      source('supabase/functions/_shared/tutorial_authorization.ts'),
    );

    test('the manifest function gates after reuse and before download', () {
      final reuse = manifest.indexOf('reused: true');
      final gate = manifest.indexOf('authorizeTutorialForPreview(');
      final download = manifest.indexOf('.download(originalPath)');
      final quota = manifest.indexOf('consumeAiQuota(');
      expect(reuse, greaterThan(-1));
      expect(gate, greaterThan(reuse), reason: 'historical reuse is ungated');
      expect(gate, lessThan(download), reason: 'no download before the gate');
      expect(gate, lessThan(quota), reason: 'no quota spent before the gate');
      expect(manifest, contains('if (!tutorialAccess.authorized)'));
    });

    test('the step function gates after ready-step reuse and before claim', () {
      final reuse = step.indexOf('reused: true');
      final gate = step.indexOf('authorizeTutorialForSession(');
      final claim = step.indexOf('status: "generating"');
      final quota = step.indexOf('consumeAiQuota(');
      expect(reuse, greaterThan(-1));
      expect(gate, greaterThan(reuse), reason: 'rendered steps are ungated');
      expect(gate, lessThan(claim), reason: 'no claim before the gate');
      expect(gate, lessThan(quota), reason: 'no quota spent before the gate');
    });

    test('the helper fails closed and names no account', () {
      expect(helper, contains('return denied("TEMPORARY_BACKEND_FAILURE")'));
      expect(helper, contains('"authorize_tutorial_generation"'));
      expect(helper, isNot(contains('p_user_id')));
      expect(helper, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(
        collapse(helper),
        contains(
          'case "TUTORIAL_NOT_INCLUDED": case "ENTITLEMENT_NOT_FOUND": return 403',
        ),
      );
      expect(helper, contains('return "tutorial_not_included"'));
    });

    test('the model and prompt of both V4 functions are unchanged', () {
      // The gate was added; nothing about generation moved.
      expect(
        manifest,
        contains('"gemini-3.6-flash"'),
        reason: 'the manifest analyzer keeps its approved model',
      );
      expect(step, contains('TUTORIAL_GUIDELINE_MODEL'));
      expect(step, contains('TUTORIAL_GUIDELINE_PROMPT_VERSION'));
      final config = source('supabase/functions/_shared/tutorial_ai_config.ts');
      expect(config, contains('tutorial_guideline_v4_7'));
    });
  });

  group('store allowlists carry the Preview products', () {
    for (final function in [
      'verify-google-play-purchase',
      'google-play-rtdn',
    ]) {
      test('$function approves the six product ids and nothing else', () {
        final code = tsCodeOnly(
          source('supabase/functions/$function/index.ts'),
        );
        final start = code.indexOf('const approvedProductIds = new Set([');
        final end = code.indexOf(']);', start);
        final block = code.substring(start, end);
        for (final id in [
          'facetune_plus',
          'facetune_plus_preview',
          'facetune_pro',
          'facetune_pro_preview',
          'facetune_salon_pro',
          'facetune_salon_preview',
        ]) {
          expect(block, contains('"$id"'));
        }
        expect(RegExp(r'"facetune_[a-z_]+"').allMatches(block).length, 6);
      });
    }
  });

  group('client contract', () {
    test('a Preview-only payload parses with its unit and capability', () {
      final summary = SubscriptionSummaryDto.fromResponse({
        'hasEntitlement': true,
        'entitlementId': '33333333-3333-3333-3333-333333333333',
        'planCode': 'plus_preview',
        'planDisplayName': 'FaceTune Plus Preview',
        'entitlementStatus': 'active',
        'billingProvider': 'google_play',
        'publiclyPurchasable': true,
        'allowanceUnit': 'final_preview_credit',
        'tutorialEnabled': false,
        'finalPreviewEnabled': true,
        'resetPolicy': 'billing_period',
        'periodStart': '2026-09-01T00:00:00Z',
        'periodEnd': '2026-10-01T00:00:00Z',
        'resetAt': '2026-10-01T00:00:00Z',
        'baseAllowance': 30,
        'effectiveAllowance': 30,
        'committedUsage': 1,
        'reservedUsage': 0,
        'availableAiLooks': 29,
        'remainingAiLooks': 29,
        'generationAuthorized': true,
        'resolvedAt': '2026-09-20T00:00:00Z',
      });
      expect(summary.planCode, SubscriptionPlanCode.plusPreview);
      expect(summary.allowanceUnit, AllowanceUnit.finalPreviewCredit);
      expect(summary.tutorialEnabled, isFalse);
      expect(summary.finalPreviewEnabled, isTrue);
      expect(summary.usage.remainingAiLooks, 29);
      expect(summary.currentPlan, SubscriptionPlanCode.plusPreview);
    });

    test('an unknown unit is a parse failure, never Tutorial-capable', () {
      expect(
        () => SubscriptionSummaryDto.fromResponse({
          'hasEntitlement': true,
          'planCode': 'plus',
          'entitlementStatus': 'active',
          'allowanceUnit': 'wallet',
          'effectiveAllowance': 3,
          'committedUsage': 0,
          'generationAuthorized': true,
        }),
        throwsFormatException,
      );
    });

    test('a pre-expansion payload reads as an AI Look plan', () {
      final summary = SubscriptionSummaryDto.fromResponse({
        'hasEntitlement': true,
        'planCode': 'plus',
        'entitlementStatus': 'active',
        'effectiveAllowance': 3,
        'committedUsage': 0,
        'generationAuthorized': true,
      });
      expect(summary.allowanceUnit, AllowanceUnit.aiLook);
      // Capability flags absent → false, the fail-closed reading. The server
      // is the gate; this only decides what the UI claims.
      expect(summary.tutorialEnabled, isFalse);
    });

    test('every plan code round-trips and no alias parses', () {
      for (final plan in SubscriptionPlanCode.values) {
        expect(SubscriptionPlanCode.fromCode(plan.code), plan);
      }
      for (final alias in [
        'plus_no_tutorial',
        'preview_plus',
        'pro_no_tutorial',
        'salon_preview_only',
      ]) {
        expect(SubscriptionPlanCode.fromCode(alias), isNull);
      }
    });
  });
}
