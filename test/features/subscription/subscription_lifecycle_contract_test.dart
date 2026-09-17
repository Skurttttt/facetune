import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-11 lifecycle reconciliation, as written.
///
/// Same convention as `purchase_verification_contract_test.dart`: assert rules
/// against source text, because these protect properties no Dart type can
/// express — "a notification type never decides an entitlement", "a
/// redelivered notification is a no-op", "revocation deletes no history".
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
  String sqlCodeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  /// The same, for TypeScript.
  String tsCodeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  const migrationPath =
      'supabase/migrations/20260917000100_subscription_lifecycle_reconciliation.sql';
  const functionDir = 'supabase/functions/google-play-rtdn';

  late String migration;
  late String migrationCode;
  late String index;
  late String indexCode;
  late String notification;
  late String notificationCode;
  late String pushAuth;

  setUp(() {
    migration = source(migrationPath);
    migrationCode = sqlCodeOnly(migration);
    index = source('$functionDir/index.ts');
    indexCode = tsCodeOnly(index);
    notification = source('$functionDir/notification.ts');
    notificationCode = tsCodeOnly(notification);
    pushAuth = source('$functionDir/pubsub_auth.ts');
  });

  group('a notification never decides an entitlement by itself', () {
    test('the notification parser knows no entitlement vocabulary', () {
      // The whole provider-authority rule in one assertion: this module maps a
      // payload to a *verb*, never to a status. If a subscription state or an
      // entitlement status ever appears here, something has started deciding
      // lifecycle from the notification instead of from the verified read.
      for (final forbidden in [
        'SUBSCRIPTION_STATE_',
        'grace_period',
        'user_entitlements',
        'activate_verified',
      ]) {
        expect(
          notificationCode,
          isNot(contains(forbidden)),
          reason: 'a notification is a trigger, not a source of state',
        );
      }
    });

    test('the verified read happens before anything is written', () {
      // Ordering asserted positionally: the provider read must appear in the
      // function before either write path is reached.
      final read = indexCode.indexOf('getSubscription(');
      final activate = indexCode.indexOf(
        'activate_verified_google_play_subscription',
      );
      final revoke = indexCode.indexOf('revoke_google_play_subscription');

      expect(read, greaterThan(-1), reason: 'the verified read must exist');
      expect(activate, greaterThan(read));
      expect(revoke, greaterThan(read));
    });

    test('revocation requires the verified read to corroborate it', () {
      // A REVOKED notification whose subscription still reads back as live is
      // not acted on as a revocation. The decision is a pure function, so the
      // behaviour itself is covered in `reconciliation_test.ts`; what is
      // pinned here is that the orchestration has no revocation rule of its
      // own to disagree with it.
      final reconciliation = tsCodeOnly(
        source('$functionDir/reconciliation.ts'),
      );
      expect(reconciliation, contains('corroborated'));
      expect(reconciliation, contains('expiredState'));
      expect(indexCode, contains('planReconciliation('));
      expect(
        indexCode,
        isNot(contains('SUBSCRIPTION_STATE_')),
        reason: 'no second, inline reading of provider state',
      );
    });

    test('the deprecated v1 lifecycle read is not used', () {
      expect(indexCode, isNot(contains('purchases/subscriptions/tokens')));
      expect(indexCode, contains('getSubscription('));
    });
  });

  group('a redelivered notification changes nothing', () {
    test('the message id is the unique dedup anchor', () {
      expect(migrationCode, contains('unique (billing_provider, message_id)'));
      expect(
        migrationCode,
        contains('on conflict (billing_provider, message_id) do nothing'),
      );
    });

    test('the claim is taken before the provider is called', () {
      // Google asks that redeliveries not produce redundant API calls, and a
      // duplicate must cost nothing.
      final claim = indexCode.indexOf('claim_google_play_notification');
      final read = indexCode.indexOf('getSubscription(');
      expect(claim, greaterThan(-1));
      expect(claim, lessThan(read));
    });

    test('a transient failure releases its claim so a retry can work', () {
      expect(migrationCode, contains("p_outcome = 'retry'"));
      expect(
        migrationCode,
        contains('delete from public.provider_notification_events'),
        reason: 'the claim row must not survive a transient failure',
      );
      expect(indexCode, contains('finalize("retry")'));
    });

    test('a claim nobody finished does not block the event forever', () {
      // A worker can die between claiming and finalizing. After a grace
      // period the claim is taken over, so a redelivery can still do the work
      // rather than being answered "already handled".
      expect(migrationCode, contains("v_existing.outcome = 'processing'"));
      expect(migrationCode, contains("interval '5 minutes'"));
      expect(migrationCode, contains("'reclaimed', true"));
    });
  });

  group('lifecycle writes reuse the verified activation path', () {
    test('no second entitlement writer is introduced', () {
      // The migration adds revocation, which `SubscriptionState` cannot
      // express, and nothing else that writes an entitlement's plan, period,
      // or allowance.
      expect(
        migrationCode,
        isNot(contains('insert into public.user_entitlements')),
        reason: 'entitlement creation belongs to the SUB-10 activation path',
      );
      expect(migrationCode, isNot(contains('base_ai_look_allowance =')));
    });

    test('renewal resets capacity by moving the period, not by deleting', () {
      // No rollover and no rewriting of history: capacity resets because
      // `resolve_subscription_state` counts usage from `period_start`.
      expect(migrationCode, isNot(contains('delete from public.usage_ledger')));
      expect(migrationCode, isNot(contains('update public.usage_ledger')));
    });

    test('revocation deletes no history', () {
      for (final table in [
        'public.usage_ledger',
        'public.provider_purchase_verifications',
      ]) {
        expect(
          migrationCode,
          isNot(contains('delete from $table')),
          reason: 'revocation ends generation; it does not erase the past',
        );
      }
      // The period is preserved as the record of what was paid for.
      expect(migrationCode, contains("status = 'revoked'"));
    });

    test('revocation is idempotent', () {
      expect(migrationCode, contains("if v_entitlement.status = 'revoked'"));
      expect(migrationCode, contains("'changed', false"));
    });
  });

  group('the lifecycle rules this phase reconciles to', () {
    // These live in the SUB-10 activation function and the SUB-3 resolver.
    // SUB-11 reuses both rather than restating them, so they are pinned here:
    // reconciliation is only correct if they stay true.
    late String activation;
    late String resolver;

    setUp(() {
      activation = sqlCodeOnly(
        source(
          'supabase/migrations/'
          '20260910000100_google_play_purchase_verification.sql',
        ),
      );
      resolver = sqlCodeOnly(
        source(
          'supabase/migrations/'
          '20260907000200_subscription_entitlement_resolver.sql',
        ),
      );
    });

    test('cancelled is not expired', () {
      // Auto-renew off with the paid period still running keeps access. What
      // ends it is `period_end`, not the cancellation.
      expect(
        activation,
        contains("when 'SUBSCRIPTION_STATE_CANCELED' then 'active'"),
      );
    });

    test('grace follows the provider and is never invented locally', () {
      expect(
        activation,
        contains(
          "when 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' then 'grace_period'",
        ),
      );
      // Nothing computes a grace window of its own.
      expect(migrationCode, isNot(contains('grace')));
    });

    test('hold and pause remove access without ending the subscription', () {
      expect(
        activation,
        contains("when 'SUBSCRIPTION_STATE_ON_HOLD' then 'suspended'"),
      );
      expect(
        activation,
        contains("when 'SUBSCRIPTION_STATE_PAUSED' then 'suspended'"),
      );
    });

    test('a renewed period resets capacity without rollover', () {
      // Usage is counted from the current period's start, so a new verified
      // period starts at zero and unused looks do not carry forward — with no
      // ledger row deleted or rewritten to achieve it.
      expect(resolver, contains('u.reserved_at >= v_ent.period_start'));
      expect(resolver, isNot(contains('delete from')));
    });

    test('a reservation open across a renewal stays in its own period', () {
      // The approved period-transition rule: an AI Look belongs to the period
      // it was reserved in. Membership is decided by `reserved_at` against the
      // entitlement's current `period_start` — never by the row's own stamped
      // period columns, which are audit only. That is what lets a renewal land
      // mid-generation without charging the new allowance for old work, and
      // without rewriting a ledger row to achieve it.
      expect(resolver, contains('u.reserved_at >= v_ent.period_start'));
      expect(
        resolver,
        isNot(contains('u.period_start =')),
        reason: 'period membership must not hinge on the stamped column',
      );

      final engine = sqlCodeOnly(
        source('supabase/migrations/20260907000300_ai_look_usage_engine.sql'),
      );
      // Commit and release move a row's status; neither restamps its period,
      // so a transition cannot reassign work that is already in flight.
      expect(engine, isNot(contains('period_start =')));

      // And the rule is written down where the phase that introduced period
      // transitions can be read.
      expect(migration, contains('An AI Look belongs to the period it was'));
    });

    test('a lapsed period blocks generation whatever the status says', () {
      // The reason a missed notification is never a security problem.
      expect(
        resolver,
        contains('v_ent.period_end is not null and v_ent.period_end <= v_now'),
      );
      expect(resolver, contains("'ENTITLEMENT_EXPIRED'"));
    });

    test('expiry and revocation block generation, never reading', () {
      // The resolver decides authorization only. No lifecycle path in either
      // migration touches history, saved looks, or previews.
      for (final forbidden in [
        'history',
        'saved_look',
        'final_preview',
        'tutorial',
      ]) {
        expect(
          migrationCode.toLowerCase(),
          isNot(contains('delete from public.$forbidden')),
        );
      }
      expect(resolver, contains("'ENTITLEMENT_REVOKED'"));
    });
  });

  group('the reconciliation functions are not reachable by a client', () {
    const functions = [
      'public.google_play_purchase_owner',
      'public.claim_google_play_notification',
      'public.finalize_google_play_notification',
      'public.revoke_google_play_subscription',
    ];

    test(
      'each is revoked from every client role and granted to service_role',
      () {
        for (final function in functions) {
          final revokes = RegExp(
            'revoke all on function ${RegExp.escape(function)}',
          ).allMatches(migrationCode).length;
          expect(
            revokes,
            greaterThanOrEqualTo(3),
            reason:
                '$function must be revoked from public, anon, authenticated',
          );
          expect(
            migrationCode,
            contains('grant execute on function $function'),
          );
        }
        // And the grants that exist name only service_role.
        final grantLines = migrationCode
            .split('\n')
            .where((line) => line.contains(' to '))
            .where((line) => !line.contains('service_role'));
        expect(grantLines, isEmpty, reason: 'no client role may hold these');
      },
    );

    test('every function pins its search path and is definer-owned', () {
      final definers = 'security definer'.allMatches(migrationCode).length;
      final paths = "set search_path = ''".allMatches(migrationCode).length;
      expect(definers, functions.length);
      expect(paths, functions.length);
    });

    test('the notification log is not readable by clients', () {
      expect(
        migrationCode,
        contains(
          'alter table public.provider_notification_events '
          'enable row level security',
        ),
      );
      for (final role in ['anon', 'authenticated']) {
        expect(
          migrationCode,
          contains(
            'revoke all on table public.provider_notification_events '
            'from $role',
          ),
        );
      }
      // RLS with no policy: nothing but a definer function or service_role can
      // read it at all.
      expect(
        migrationCode,
        isNot(contains('create policy "provider_notification_events')),
      );
    });
  });

  group('no raw purchase token reaches the database', () {
    test('the notification log stores only a hash', () {
      expect(migrationCode, contains('purchase_reference'));
      expect(migrationCode, isNot(contains('purchase_token')));
      expect(migrationCode, contains(r"purchase_reference ~ '^[0-9a-f]{64}$'"));
    });

    test('the function hashes before it persists', () {
      expect(indexCode, contains('sha256Hex('));
      // Every RPC argument that could carry a token carries a reference.
      expect(indexCode, isNot(contains('p_purchase_token')));
    });

    test('nothing logs the token', () {
      for (final file
          in Directory(pathOf(functionDir)).listSync().whereType<File>().where(
            (file) => file.path.endsWith('.ts'),
          )) {
        final content = tsCodeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        expect(
          content,
          isNot(contains(r'${purchaseToken}')),
          reason: '${file.path} must never interpolate a token',
        );
        expect(content, isNot(contains(r'${token}')));
      }
    });
  });

  group('the push endpoint authenticates its caller', () {
    test('it is deployed without the Supabase JWT gate', () {
      final config = source('supabase/config.toml');
      expect(
        config,
        contains('[functions.google-play-rtdn]\nverify_jwt = false'),
      );
    });

    test('and replaces it with a verified Google identity token', () {
      // Signature first: every claim below is meaningless without it.
      expect(pushAuth, contains('crypto.subtle.verify'));
      expect(pushAuth, contains('token_signature_invalid'));
      // Pinned to this push subscription and its service account.
      expect(pushAuth, contains('token_audience_rejected'));
      expect(pushAuth, contains('token_identity_rejected'));
      expect(pushAuth, contains('token_expired'));
      // `alg: none` and friends are refused before a key is looked up.
      expect(pushAuth, contains('token_algorithm_not_rs256'));
    });

    test('an unset audience or identity refuses to serve', () {
      expect(indexCode, contains('GOOGLE_PLAY_RTDN_AUDIENCE'));
      expect(indexCode, contains('GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT'));
      expect(indexCode, contains('requiredEnvironment('));
    });
  });

  group('the approved products match the rest of the system', () {
    test('the reconciler sells exactly the three store products', () {
      for (final product in [
        'facetune_plus',
        'facetune_pro',
        'facetune_salon_pro',
      ]) {
        expect(indexCode, contains('"$product"'));
      }
      // And nothing that would let an admin-granted plan be reached from a
      // notification.
      expect(indexCode, isNot(contains('salon_pilot')));
      expect(migrationCode, isNot(contains("'salon_pilot'")));
    });
  });
}
