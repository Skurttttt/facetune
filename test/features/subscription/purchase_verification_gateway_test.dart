import 'dart:async';
import 'dart:io';

import 'package:facetune/features/subscription/data/data_sources/purchase_verification_remote_data_source.dart';
import 'package:facetune/features/subscription/data/repositories/supabase_purchase_verification_gateway.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client half of server-side verification.
///
/// What is being pinned here is mostly what the client *cannot* do: it sends a
/// token, it learns whether verification succeeded, and it receives nothing it
/// could mistake for an entitlement.
class _Remote implements PurchaseVerificationRemoteDataSource {
  _Remote({this.userId = 'account-uuid', this.failure, this.response});

  final String? userId;
  final Object? failure;
  final Object? response;

  final List<({String token, String productId})> calls = [];

  @override
  String? get currentUserId => userId;

  @override
  Future<Object?> verify({
    required String purchaseToken,
    required String providerProductId,
  }) async {
    calls.add((token: purchaseToken, productId: providerProductId));
    final thrown = failure;
    if (thrown != null) throw thrown;
    return response;
  }
}

const _evidence = PurchaseEvidence(
  provider: BillingProvider.googlePlay,
  providerProductId: 'facetune_pro',
  purchaseToken: 'super-secret-provider-token',
);

void main() {
  group('sending evidence for verification', () {
    test('forwards the token and the product to the backend', () async {
      final remote = _Remote(
        response: const {'verified': true, 'subscription': <String, Object?>{}},
      );

      await SupabasePurchaseVerificationGateway(remote).verify(_evidence);

      expect(remote.calls, hasLength(1));
      expect(remote.calls.single.token, 'super-secret-provider-token');
      expect(remote.calls.single.productId, 'facetune_pro');
    });

    test('success yields nothing the caller could apply as a plan', () async {
      // The backend returns the account's authoritative state, but this
      // interface returns void: there is no plan, allowance, or expiry handed
      // back for a caller to trust. Entitlement is re-read from the resolver.
      final remote = _Remote(
        response: const {
          'verified': true,
          'subscription': {'planCode': 'salon_pro', 'effectiveAllowance': 35},
        },
      );

      // `verify` returns `Future<void>`, so this call site is the proof: the
      // rich payload above is reachable by the backend and by the resolver,
      // and by nothing on this path. It cannot even be assigned.
      await expectLater(
        SupabasePurchaseVerificationGateway(remote).verify(_evidence),
        completes,
      );
    });
  });

  group('requests that must never reach the backend', () {
    test('evidence with no token is refused locally', () async {
      final remote = _Remote();

      await expectLater(
        SupabasePurchaseVerificationGateway(remote).verify(
          const PurchaseEvidence(
            provider: BillingProvider.googlePlay,
            providerProductId: 'facetune_pro',
            purchaseToken: '',
          ),
        ),
        throwsA(
          isA<SubscriptionStateFailure>().having(
            (failure) => failure.retryable,
            'retryable',
            isFalse,
          ),
        ),
      );
      expect(remote.calls, isEmpty);
    });

    test('a signed-out caller is refused before any call', () async {
      final remote = _Remote(userId: null);

      await expectLater(
        SupabasePurchaseVerificationGateway(remote).verify(_evidence),
        throwsA(
          isA<SubscriptionStateFailure>().having(
            (failure) => failure.kind,
            'kind',
            SubscriptionStateFailureKind.sessionExpired,
          ),
        ),
      );
      expect(remote.calls, isEmpty);
    });
  });

  group('backend refusals keep the server\'s own words', () {
    Future<SubscriptionStateFailure> failureFrom(
      PurchaseVerificationRemoteFailure remote,
    ) async {
      try {
        await SupabasePurchaseVerificationGateway(
          _Remote(failure: remote),
        ).verify(_evidence);
        fail('expected a failure');
      } on SubscriptionStateFailure catch (failure) {
        return failure;
      }
    }

    test('an expired session is reported as one', () async {
      final failure = await failureFrom(
        const PurchaseVerificationRemoteFailure(
          status: 401,
          code: 'AUTH_REQUIRED',
          message: 'Sign in before confirming a purchase.',
          retryable: false,
        ),
      );

      expect(failure.kind, SubscriptionStateFailureKind.sessionExpired);
      expect(failure.message, 'Sign in before confirming a purchase.');
      expect(failure.retryable, isFalse);
    });

    test('a refused purchase is not presented as worth retrying', () async {
      final failure = await failureFrom(
        const PurchaseVerificationRemoteFailure(
          status: 409,
          code: 'PROVIDER_STATE_CONFLICT',
          message: 'This purchase could not be applied to your account.',
          retryable: false,
        ),
      );

      expect(failure.retryable, isFalse);
      expect(failure.message, contains('could not be applied'));
    });

    test('a provider outage stays retryable', () async {
      final failure = await failureFrom(
        const PurchaseVerificationRemoteFailure(
          status: 503,
          code: 'TEMPORARY_BACKEND_FAILURE',
          message: 'Google Play could not be reached. Please try again.',
          retryable: true,
        ),
      );

      expect(failure.kind, SubscriptionStateFailureKind.offline);
      expect(failure.retryable, isTrue);
    });

    test('a plan the store does not sell is refused', () async {
      final failure = await failureFrom(
        const PurchaseVerificationRemoteFailure(
          status: 409,
          code: 'INVALID_PLAN_CODE',
          message: 'This purchase is not for a FaceTune plan.',
          retryable: false,
        ),
      );

      expect(failure.retryable, isFalse);
    });
  });

  group('transport failures become controlled failures', () {
    Future<SubscriptionStateFailure> failureFor(Object error) async {
      try {
        await SupabasePurchaseVerificationGateway(
          _Remote(failure: error),
          operationTimeout: const Duration(milliseconds: 10),
        ).verify(_evidence);
        fail('expected a failure');
      } on SubscriptionStateFailure catch (failure) {
        return failure;
      }
    }

    test('being offline says so, and says the purchase is not lost', () async {
      final failure = await failureFor(
        const SocketException('no route to host'),
      );

      expect(failure.kind, SubscriptionStateFailureKind.offline);
      expect(failure.message, contains('offline'));
      // A user who paid and lost connectivity must not think it vanished.
      expect(failure.message, contains('reconnect'));
    });

    test('an unexpected error does not leak its detail', () async {
      final failure = await failureFor(
        Exception('PostgrestException: relation user_entitlements'),
      );

      expect(failure.message, isNot(contains('user_entitlements')));
      expect(failure.message, isNot(contains('Postgrest')));
    });

    test('a slow backend times out rather than hanging the purchase', () async {
      final slow = _Remote();
      final gateway = SupabasePurchaseVerificationGateway(
        _SlowRemote(slow),
        operationTimeout: const Duration(milliseconds: 20),
      );

      await expectLater(
        gateway.verify(_evidence),
        throwsA(
          isA<SubscriptionStateFailure>().having(
            (failure) => failure.kind,
            'kind',
            SubscriptionStateFailureKind.timeout,
          ),
        ),
      );
    });
  });

  group('the purchase token stays out of everything user-visible', () {
    test('no failure message contains it', () async {
      for (final error in <Object>[
        const SocketException('no route'),
        Exception('super-secret-provider-token leaked into an error'),
        const PurchaseVerificationRemoteFailure(
          status: 409,
          code: 'PROVIDER_STATE_CONFLICT',
          message: 'This purchase could not be applied to your account.',
          retryable: false,
        ),
      ]) {
        try {
          await SupabasePurchaseVerificationGateway(
            _Remote(failure: error),
          ).verify(_evidence);
          fail('expected a failure');
        } on SubscriptionStateFailure catch (failure) {
          expect(failure.message, isNot(contains('super-secret')));
        }
      }
    });

    test('the remote failure type does not print it either', () {
      const failure = PurchaseVerificationRemoteFailure(
        status: 409,
        code: 'PROVIDER_STATE_CONFLICT',
        message: 'refused',
        retryable: false,
      );
      expect(failure.toString(), isNot(contains('super-secret')));
      expect(failure.toString(), contains('PROVIDER_STATE_CONFLICT'));
    });
  });
}

/// Never answers, so the gateway's own timeout is what ends the call.
class _SlowRemote implements PurchaseVerificationRemoteDataSource {
  _SlowRemote(this._inner);
  final _Remote _inner;

  @override
  String? get currentUserId => _inner.currentUserId;

  @override
  Future<Object?> verify({
    required String purchaseToken,
    required String providerProductId,
  }) => Completer<Object?>().future;
}
