import 'dart:io';

import 'package:facetune/features/subscription/domain/catalog/top_up_pack_catalog.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/top_up_pack.dart';
import 'package:flutter_test/flutter_test.dart';

/// SUB-13B — the shape of purchased top-up credits, read from the sources
/// that define them.
///
/// The migration, the Edge Function, and the Flutter catalog each hold one
/// piece of the approved matrix. These tests read all three and refuse to let
/// them drift: the pack a product grants is decided once, on the server, and
/// everything else must agree with it.
String source(String path) => File(path).readAsStringSync();

String sqlCodeOnly(String value) => value
    .split('\n')
    .map((line) => line.split('--').first)
    .join('\n')
    .toLowerCase();

String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

void main() {
  const migrationPath =
      'supabase/migrations/20260923000100_purchased_top_up_credits.sql';
  const functionDir = 'supabase/functions/verify-google-play-top-up';
  late String migration;
  late String code;
  late String flattened;

  setUpAll(() {
    migration = source(migrationPath);
    code = sqlCodeOnly(migration);
    flattened = collapse(code);
  });

  void declares(String snippet, {String? reason}) => expect(
    flattened,
    contains(collapse(snippet.toLowerCase())),
    reason: reason ?? 'migration must declare: $snippet',
  );

  void declaresNot(String snippet, {String? reason}) => expect(
    flattened,
    isNot(contains(collapse(snippet.toLowerCase()))),
    reason: reason ?? 'migration must not declare: $snippet',
  );

  group('migration hygiene', () {
    test('is ordered after the SUB-13 telemetry migration', () {
      final names =
          Directory('supabase/migrations')
              .listSync()
              .whereType<File>()
              .map((file) => file.path.split(Platform.pathSeparator).last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();
      const thisMigration = '20260923000100_purchased_top_up_credits.sql';
      const sub13 = '20260922000100_subscription_telemetry.sql';
      expect(names, contains(thisMigration));
      expect(names.indexOf(sub13), lessThan(names.indexOf(thisMigration)));
    });

    test('drops nothing, disables no RLS, rewrites no product row', () {
      for (final forbidden in [
        'drop table',
        'drop policy',
        'drop column',
        'disable row level security',
        'update public.subscription_products',
        'insert into public.subscription_products',
        'alter table public.subscription_products',
        'alter table public.user_entitlements',
      ]) {
        declaresNot(forbidden);
      }
    });

    test('leaves the subscription lifecycle and commit/release untouched', () {
      for (final untouched in [
        'activate_verified_google_play_subscription',
        'revoke_google_play_subscription',
        'claim_google_play_notification',
        'finalize_google_play_notification',
        'google_play_purchase_owner',
        'commit_ai_look',
        'release_ai_look',
        'reconcile_stale_ai_look_reservations',
        'authorize_tutorial_generation',
        'record_ai_operation_metric',
      ]) {
        declaresNot('create or replace function public.$untouched');
        declaresNot('create function public.$untouched');
      }
    });

    test('touches no Gemini, prompt, or Tutorial V4 configuration', () {
      for (final forbidden in [
        'gemini',
        'tutorial_guideline_v4',
        'tutorial_manifest_v4',
        'prompt_version',
      ]) {
        declaresNot(forbidden);
      }
    });
  });

  group('the approved matrix is written once, server-side', () {
    test('configures exactly the two approved packs', () {
      declares(
        "('extra_ai_look', 'Extra AI Look', 'google_play', "
        "'facetune_ai_look_topup_1', 'tutorial_capable_ai_look', 1, "
        "array['plus', 'pro', 'salon_pro'])",
      );
      declares(
        "('preview_boost', 'Preview Boost', 'google_play', "
        "'facetune_preview_credit_topup_10', 'preview_only_final_preview', 10, "
        "array['plus_preview', 'pro_preview', 'salon_preview'])",
      );
      declares("pack_code in ('extra_ai_look', 'preview_boost')");
    });

    test('locks each pack to its class and quantity in the table itself', () {
      declares('constraint top_up_packs_locked_matrix');
      declares(
        "pack_code = 'extra_ai_look' and credit_class = "
        "'tutorial_capable_ai_look' and quantity = 1",
      );
      declares(
        "pack_code = 'preview_boost' and credit_class = "
        "'preview_only_final_preview' and quantity = 10",
      );
      declares('create trigger purchased_credit_grants_pack_guard');
    });

    test('the approved product ids are the locked production ids', () {
      expect(
        TopUpPackCatalog.productIdFor(TopUpPack.extraAiLook),
        'facetune_ai_look_topup_1',
      );
      expect(
        TopUpPackCatalog.productIdFor(TopUpPack.previewBoost),
        'facetune_preview_credit_topup_10',
      );
      // The earlier assumed ids must not survive anywhere in authority.
      for (final stale in [
        'facetune_extra'
            'ai_look',
        'facetune_preview'
            '_boost',
      ]) {
        expect(flattened, isNot(contains(stale)));
        expect(source('$functionDir/index.ts'), isNot(contains(stale)));
      }
    });

    test('purchase eligibility is exact and lives on the pack row', () {
      declares("eligible_plan_codes = array['plus', 'pro', 'salon_pro']");
      declares(
        "eligible_plan_codes = array['plus_preview', 'pro_preview', "
        "'salon_preview']",
      );
      declares('v_ent.plan_code = any (v_pack.eligible_plan_codes)');
      expect(TopUpPack.extraAiLook.eligiblePlans, {
        SubscriptionPlanCode.plus,
        SubscriptionPlanCode.pro,
        SubscriptionPlanCode.salonPro,
      });
      expect(TopUpPack.previewBoost.eligiblePlans, {
        SubscriptionPlanCode.plusPreview,
        SubscriptionPlanCode.proPreview,
        SubscriptionPlanCode.salonPreview,
      });
      for (final pack in TopUpPack.values) {
        expect(pack.isOfferedTo(SubscriptionPlanCode.free), isFalse);
        expect(pack.isOfferedTo(SubscriptionPlanCode.salonPilot), isFalse);
      }
    });

    test('the Flutter catalog mirrors the server matrix', () {
      expect(TopUpPack.values, hasLength(2));
      expect(TopUpPack.extraAiLook.quantity, 1);
      expect(TopUpPack.extraAiLook.tutorialCapable, isTrue);
      expect(TopUpPack.previewBoost.quantity, 10);
      expect(TopUpPack.previewBoost.tutorialCapable, isFalse);
      for (final pack in TopUpPack.values) {
        final productId = TopUpPackCatalog.productIdFor(pack);
        declares(
          "'$productId', '${pack.creditClass.code}', ${pack.quantity}",
          reason: '${pack.code} must grant on the server what it says here',
        );
      }
    });

    test('the Edge Function approves exactly the catalog products', () {
      final function = source('$functionDir/index.ts');
      final approved = RegExp(
        r'const approvedProductIds = new Set\(\[([^\]]*)\]\)',
      ).firstMatch(function)!.group(1)!;
      final ids = RegExp(
        r'"([a-z0-9_]+)"',
      ).allMatches(approved).map((match) => match.group(1)!).toSet();
      expect(ids, TopUpPackCatalog.productIds);
    });

    test('pack identifiers live only in the pack catalog', () {
      final catalogPath =
          'lib/features/subscription/domain/catalog/'
          'top_up_pack_catalog.dart';
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.replaceAll('\\', '/').endsWith(catalogPath)) continue;
        final content = file.readAsStringSync();
        for (final id in TopUpPackCatalog.productIds) {
          expect(
            content,
            isNot(contains(id)),
            reason: '${file.path} must read pack ids from the catalog',
          );
        }
      }
    });
  });

  group('the client cannot grant, mutate, or count credits', () {
    test('the grant writer is service-role only', () {
      declares('revoke all on function public.grant_verified_top_up_purchase');
      declares(
        'grant execute on function public.grant_verified_top_up_purchase( '
        'uuid, text, text, text, text, boolean ) to service_role',
      );
      declaresNot(
        'grant execute on function public.grant_verified_top_up_purchase( '
        'uuid, text, text, text, text, boolean ) to authenticated',
      );
      declares(
        'grant execute on function public.mark_top_up_purchase_consumed'
        '(uuid, text) to service_role',
      );
    });

    test('quantity, class, and pack are not writer arguments', () {
      final signature = flattened.substring(
        flattened.indexOf(
          'create function public.grant_verified_top_up_purchase',
        ),
        flattened.indexOf(
          'returns jsonb language plpgsql security definer',
          flattened.indexOf(
            'create function public.grant_verified_top_up_purchase',
          ),
        ),
      );
      expect(signature, isNot(contains('quantity')));
      expect(signature, isNot(contains('credit_class')));
      expect(signature, isNot(contains('pack_code')));
      declares('from public.top_up_packs as t');
    });

    test(
      'grants are RLS-protected, owner-readable, and never client-writable',
      () {
        declares(
          'alter table public.purchased_credit_grants enable row level security',
        );
        declares(
          'revoke all on table public.purchased_credit_grants from anon',
        );
        declares(
          'revoke all on table public.purchased_credit_grants from authenticated',
        );
        declares(
          'on public.purchased_credit_grants for select to authenticated',
        );
        declaresNot('on public.purchased_credit_grants for insert');
        declaresNot('on public.purchased_credit_grants for update');
        declaresNot('on public.purchased_credit_grants for delete');
      },
    );

    test('grants are append-only and keyed on the purchase reference', () {
      declares(
        'constraint purchased_credit_grants_reference_unique unique '
        '(purchase_reference)',
      );
      declares(r"purchase_reference ~ '^[0-9a-f]{64}$'");
      declares('create trigger purchased_credit_grants_immutable');
      declares('create trigger purchased_credit_grants_no_delete');
      declaresNot('purchase_token');
      declaresNot('quantity_remaining');
      declaresNot('balance');
    });

    test('a revocation can only freeze unused credits, never go negative', () {
      declares('revoked_at timestamptz');
      declares("revocation_reason in ('refunded', 'voided', 'revoked')");
      declares('create function public.revoke_top_up_purchase');
      declares(
        'grant execute on function public.revoke_top_up_purchase( '
        'text, text, text, timestamptz ) to service_role',
      );
      declaresNot(
        'grant execute on function public.revoke_top_up_purchase( '
        'text, text, text, timestamptz ) to authenticated',
      );
      // Revoked grants are excluded from every sum; nothing is subtracted.
      declares('where g.user_id = v_user and g.revoked_at is null');
      declares(
        "and l.allowance_source = 'purchased_credit' and g.revoked_at is null",
      );
      declares(
        'greatest(0, v_grant.quantity_granted - v_committed - v_reserved)',
      );
      declaresNot('set quantity_granted');
      declaresNot('delete from public.usage_ledger');
      declaresNot('update public.usage_ledger');
    });

    test('consumption is derived from the usage ledger, not a counter', () {
      declares(
        "add column allowance_source text not null default 'subscription'",
      );
      declares('add column purchased_credit_grant_id uuid');
      declares('constraint usage_ledger_purchased_source_pair');
      declares("and u.allowance_source = 'subscription'");
      declaresNot('update public.purchased_credit_grants set quantity');
      declaresNot('set quantity_granted');
    });

    test(
      'purchased credits are spent after the subscription and only when eligible',
      () {
        declares("v_next_source := 'subscription'");
        declares("elsif v_compatible_available > 0 then");
        declares(
          "v_ent.plan_code in ( 'plus', 'plus_preview', 'pro', 'pro_preview', "
          "'salon_pro', 'salon_preview' )",
        );
        declares(
          "g.credit_class = 'tutorial_capable_ai_look' and "
          "coalesce(v_tutorial_enabled, false)",
        );
      },
    );
  });

  group('the Edge Function is server-authoritative and leak-free', () {
    late String function;
    late String logic;

    setUpAll(() {
      function = source('$functionDir/index.ts');
      logic = source('$functionDir/top_up_verification.ts');
    });

    test('verifies with Google, grants, then consumes — in that order', () {
      final verify = function.indexOf('getProductPurchase(');
      final grant = function.indexOf('"grant_verified_top_up_purchase"');
      final consume = function.indexOf('consumeProduct(');
      expect(verify, greaterThan(0));
      expect(grant, greaterThan(verify));
      expect(consume, greaterThan(grant));
    });

    test('hashes the token and never persists or logs it', () {
      expect(function, contains('sha256Hex(purchaseToken)'));
      expect(function, isNot(contains('console.log(purchaseToken')));
      expect(function, isNot(contains('console.error(purchaseToken')));
      expect(function, isNot(contains('p_purchase_token')));
      expect(function, isNot(contains('console.log(error')));
    });

    test('the privileged client only calls the two grant RPCs', () {
      final privileged = RegExp(
        r'privilegedClient\s*\.\s*(\w+)\(',
      ).allMatches(function).map((match) => match.group(1)).toSet();
      expect(privileged, {'rpc'});
      expect(function, isNot(contains('privilegedClient.from(')));
    });

    test('a client quantity or class is never read', () {
      expect(logic, isNot(contains('body.quantity')));
      expect(logic, isNot(contains('body.creditClass')));
      expect(logic, isNot(contains('body.packCode')));
      expect(function, isNot(contains('p_quantity')));
    });

    test('the subscription verifier is untouched by top-ups', () {
      final subscription = source(
        'supabase/functions/verify-google-play-purchase/index.ts',
      );
      expect(subscription, isNot(contains('top_up')));
      expect(subscription, isNot(contains('grant_verified_top_up_purchase')));
      expect(subscription, isNot(contains('getProductPurchase')));
    });
  });

  group('the Flutter purchase flow', () {
    late String controller;

    setUpAll(() {
      controller = source(
        'lib/features/subscription/presentation/controllers/'
        'purchase_controller.dart',
      );
    });

    test('verifies before it consumes', () {
      final verify = controller.indexOf('verifier().verify(');
      final complete = controller.indexOf('completeVerifiedTopUp(');
      expect(verify, greaterThan(0));
      expect(complete, greaterThan(verify));
    });

    test('never counts a credit', () {
      for (final forbidden in [
        'creditsRemaining +',
        'creditsRemaining -',
        'quantityGranted',
        'grantCredit',
        'addCredits',
      ]) {
        expect(controller, isNot(contains(forbidden)));
      }
    });

    test('buys a pack as a consumable that is not auto-consumed', () {
      final dataSource = source(
        'lib/features/subscription/data/data_sources/'
        'google_play_billing_data_source.dart',
      );
      expect(dataSource, contains('autoConsume: false'));
      expect(dataSource, isNot(contains('autoConsume: true')));
    });
  });
}
