import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-10 verification migration *as written*.
///
/// Same convention as the other subscription contract tests: assert rules
/// against source text, because these protect properties no Dart type can
/// express — "a client role cannot execute the activation function", "no raw
/// purchase token is ever stored", "a purchase cannot resolve to Salon Pilot".
///
/// Line endings are normalized before matching, so a CRLF checkout does not
/// fail them.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  String source(String relativePath) =>
      File(pathOf(relativePath)).readAsStringSync().replaceAll('\r\n', '\n');

  /// [text] with whole-line SQL comments removed, so a rule described in prose
  /// is not mistaken for the rule itself being present in code.
  String codeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  const migrationPath =
      'supabase/migrations/20260910000100_google_play_purchase_verification.sql';
  const functionDir = 'supabase/functions/verify-google-play-purchase';

  late String migration;
  late String migrationCode;

  setUp(() {
    migration = source(migrationPath);
    migrationCode = codeOnly(migration);
  });

  group('the activation function is not reachable by a client', () {
    test('execute is granted to service_role and nobody else', () {
      // Its arguments carry its authority — unlike every other subscription
      // function, which derives authority from auth.uid(). A client able to
      // call it directly could name any plan and any period.
      expect(
        migrationCode,
        contains('to service_role'),
        reason: 'the Edge Function is the only caller',
      );

      for (final role in ['from public', 'from anon', 'from authenticated']) {
        expect(
          migrationCode,
          contains(role),
          reason: 'execute must be revoked $role',
        );
      }

      // Exactly one execute grant exists, and its target is service_role.
      const grant = 'grant execute on function '
          'public.activate_verified_google_play_subscription';
      expect(
        grant.allMatches(migrationCode).length,
        1,
        reason: 'only one execute grant may exist for this function',
      );
      final afterGrant = migrationCode.substring(
        migrationCode.indexOf(grant) + grant.length,
      );
      expect(
        afterGrant.substring(0, afterGrant.indexOf(';') + 1),
        contains('to service_role'),
        reason: 'the sole execute grant must target service_role',
      );
    });

    test('no client role receives write privilege on the audit table', () {
      expect(
        migrationCode,
        contains('revoke all on table public.provider_purchase_verifications '
            'from authenticated'),
      );
      expect(
        migrationCode,
        contains('revoke all on table public.provider_purchase_verifications '
            'from anon'),
      );
      for (final privilege in [
        'grant insert',
        'grant update',
        'grant delete',
        'for insert',
        'for update',
        'for delete',
      ]) {
        expect(
          migrationCode,
          isNot(contains(privilege)),
          reason: 'the verification record is written by the function only',
        );
      }
    });

    test('row level security is enabled on the new table', () {
      expect(
        migrationCode,
        contains('alter table public.provider_purchase_verifications '
            'enable row level security'),
      );
    });
  });

  group('no raw purchase token is persisted', () {
    test('the schema stores a reference, never a token', () {
      // A purchase token is replayable against Google's API. Only its SHA-256
      // is stored, which keeps equality and uniqueness without keeping a
      // credential.
      expect(migrationCode, contains('purchase_reference text not null'));
      expect(
        migrationCode,
        isNot(contains('purchase_token')),
        reason: 'no column may hold the token itself',
      );
      expect(
        migrationCode,
        contains(r"purchase_reference ~ '^[0-9a-f]{64}$'"),
        reason: 'the column is constrained to a sha-256 digest',
      );
    });

    test('the hash is computed before it reaches the database', () {
      final index = source('$functionDir/index.ts');
      expect(index, contains('sha256Hex(purchaseToken)'));
      expect(
        codeOnly(index),
        isNot(contains('p_purchase_token')),
        reason: 'the RPC takes a reference, not a token',
      );
    });

    test('the raw provider response is not stored', () {
      // It can carry the subscriber's Google profile, and none of it is needed
      // to decide an entitlement.
      for (final leak in [
        'subscribeWithGoogleInfo',
        'raw_response',
        'provider_payload',
      ]) {
        expect(migrationCode, isNot(contains(leak)));
      }
    });
  });

  group('a purchase can only ever buy a plan that is sold', () {
    test('the approved product ids are bound to their plans', () {
      for (final pair in [
        ('facetune_plus', 'plus'),
        ('facetune_pro', 'pro'),
        ('facetune_salon_pro', 'salon_pro'),
      ]) {
        expect(migrationCode, contains("'${pair.$1}'"));
        expect(migrationCode, contains("plan_code = '${pair.$2}'"));
      }
    });

    test('plan resolution requires a purchasable google_play product', () {
      // Free and Salon Pilot carry no provider product id, so no argument can
      // select them. This is the structural guard, not a special case.
      expect(migrationCode, contains('and p.publicly_purchasable'));
      expect(migrationCode, contains("and p.billing_provider = 'google_play'"));
      expect(migrationCode, contains('and p.active'));
    });

    test('the audit table refuses a non-purchasable plan outright', () {
      expect(
        migrationCode,
        contains("check (plan_code in ('plus', 'pro', 'salon_pro'))"),
      );
    });

    test('nothing maps a purchase to salon_pilot or free', () {
      // The strings may appear in prose explaining why they cannot be reached;
      // they must not appear in code that could assign one.
      expect(migrationCode, isNot(contains("'salon_pilot'")));
      expect(migrationCode, isNot(contains("'free'")));
    });
  });

  group('provider state is mapped, never guessed', () {
    test('every documented subscription state is handled explicitly', () {
      for (final state in [
        'SUBSCRIPTION_STATE_ACTIVE',
        'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
        'SUBSCRIPTION_STATE_CANCELED',
        'SUBSCRIPTION_STATE_ON_HOLD',
        'SUBSCRIPTION_STATE_PAUSED',
        'SUBSCRIPTION_STATE_PENDING',
        'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED',
        'SUBSCRIPTION_STATE_EXPIRED',
      ]) {
        expect(
          migrationCode,
          contains("when '$state' then"),
          reason: '$state must map to an explicit entitlement status',
        );
      }
    });

    test('an unrecognised state falls through to a refusal', () {
      expect(migrationCode, contains('else null'));
      expect(migrationCode, contains("'errorCode', 'PROVIDER_STATE_CONFLICT'"));
    });

    test('an unspecified state is never granted', () {
      // `SUBSCRIPTION_STATE_UNSPECIFIED` is a real enum member with no meaning.
      // It must not appear as a mapped case in either half of the system.
      expect(
        migrationCode,
        isNot(contains("when 'SUBSCRIPTION_STATE_UNSPECIFIED'")),
      );
      expect(
        codeOnly(source('$functionDir/verification.ts')),
        isNot(contains('"SUBSCRIPTION_STATE_UNSPECIFIED"')),
      );
    });
  });

  group('idempotency and replay', () {
    test('the purchase reference is unique', () {
      expect(
        migrationCode,
        contains('unique (purchase_reference)'),
        reason: 'verifying the same purchase twice must not add a second row',
      );
    });

    test('activation serializes per account', () {
      expect(
        migrationCode,
        contains('pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0))'),
      );
    });

    test('a repeat verification updates rather than inserts', () {
      expect(migrationCode, contains('on conflict (purchase_reference) do update'));
    });

    test('a race that beats the lock is resolved, not surfaced', () {
      expect(migrationCode, contains('when unique_violation then'));
    });

    test('a purchase bound to another account is refused', () {
      expect(migrationCode, contains('v_entitlement.user_id <> p_user_id'));
      expect(migrationCode, contains('v_existing_owner <> p_user_id'));
    });
  });

  group('the client is never the authority', () {
    test('the plan comes from the provider product, not a client plan code', () {
      // There is no plan argument at all: the function accepts a provider
      // product id and resolves the plan from server-held configuration.
      expect(migrationCode, isNot(contains('p_plan_code')));
      expect(migrationCode, contains('p_provider_product_id'));
    });

    test('no price is accepted or stored anywhere in the flow', () {
      for (final token in ['p_price', 'price_amount', 'p_currency']) {
        expect(migrationCode, isNot(contains(token)));
      }
    });

    test('the client product claim is discarded by the function', () {
      final verification = source('$functionDir/verification.ts');
      expect(verification, contains('clientProductMismatch'));
      expect(
        verification,
        contains('selectApprovedLineItem(purchase, options.approvedProductIds)'),
        reason: 'the product is read from the provider response',
      );
    });
  });

  group('acknowledgement follows the grant', () {
    test('the entitlement is written before Google is told', () {
      final index = codeOnly(source('$functionDir/index.ts'));
      final activateAt = index.indexOf(
        'activate_verified_google_play_subscription',
      );
      final acknowledgeAt = index.indexOf('acknowledgeSubscription(');
      expect(activateAt, greaterThan(-1));
      expect(acknowledgeAt, greaterThan(activateAt));
    });

    test('acknowledgement is skipped when Google already has it', () {
      expect(
        source('$functionDir/verification.ts'),
        contains('ACKNOWLEDGEMENT_STATE_PENDING'),
      );
    });
  });

  group('credentials and logging', () {
    test('no service account material is committed', () {
      for (final name in [
        'supabase/functions/verify-google-play-purchase/service-account.json',
        'service-account.json',
        'play-service-account.json',
      ]) {
        expect(File(pathOf(name)).existsSync(), isFalse);
      }
    });

    test('the credential is read from the environment only', () {
      final index = source('$functionDir/index.ts');
      expect(
        index,
        contains('requiredEnvironment("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")'),
      );
      expect(index, isNot(contains('BEGIN PRIVATE KEY')));
    });

    test('nothing logs a purchase token', () {
      for (final file in [
        '$functionDir/index.ts',
        '$functionDir/google_play_api.ts',
        '$functionDir/verification.ts',
      ]) {
        final content = codeOnly(source(file));
        for (final line in content.split('\n')) {
          if (!line.contains('console.')) continue;
          expect(
            line.contains('purchaseToken') || line.contains('token'),
            isFalse,
            reason: 'a log line in $file references a token: ${line.trim()}',
          );
        }
      }
    });

    test('the whole app still carries no Google private credential', () {
      for (final file in Directory(pathOf('lib'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))) {
        final content = codeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        for (final token in [
          'service_account',
          'private_key',
          'androidpublisher',
          'SERVICE_ROLE',
          'service_role',
        ]) {
          expect(
            content,
            isNot(contains(token)),
            reason: '${file.path} must not carry backend credentials',
          );
        }
      }
    });
  });
}
