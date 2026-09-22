import 'package:facetune/admin/auth/data/supabase_admin_session_gateway.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/domain/admin_role.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Decoding of the `admin-session` answer. The server's word is taken
/// strictly and never improved on: anything short of `ok: true` with
/// `role: "admin"` is a refusal.
void main() {
  const decode = SupabaseAdminSessionGateway.decodeAdminSession;

  Map<String, Object?> success({Object? role = 'admin', Object? email}) => {
    'ok': true,
    'contractVersion': 'subscription_admin_contract_v1.1',
    'admin': {'userId': 'admin-1', 'email': email, 'role': role},
  };

  group('decodeAdminSession', () {
    test('a verified admin answer becomes an identity', () {
      final identity = decode(success(email: 'ops@example.invalid'));
      expect(identity.userId, 'admin-1');
      expect(identity.email, 'ops@example.invalid');
      expect(identity.role, AdminRole.admin);
    });

    test('a missing email is null, never fabricated', () {
      expect(decode(success(email: null)).email, isNull);
      expect(decode(success(email: '')).email, isNull);
    });

    test('anything that does not say admin is unauthorized', () {
      final refusals = <Object?>[
        success(role: 'normal_user'),
        success(role: 'Admin'),
        success(role: true),
        success(role: null),
        {...success(), 'ok': false},
        {...success(), 'ok': 'true'},
        {'ok': true},
        {'ok': true, 'admin': 'admin'},
        {
          'ok': true,
          'admin': {'role': 'admin'},
        },
        {
          'ok': true,
          'admin': {'role': 'admin', 'userId': ''},
        },
        // A client-side flag echoed back is not the server's conclusion.
        {'isAdmin': true, 'role': 'admin'},
      ];
      for (final payload in refusals) {
        expect(
          () => decode(payload),
          throwsA(
            isA<AdminAuthFailure>().having(
              (f) => f.code,
              'code',
              SubscriptionErrorCode.adminUnauthorized,
            ),
          ),
          reason: '$payload',
        );
      }
    });

    test('a non-object payload is a temporary failure, not a refusal', () {
      for (final payload in <Object?>[null, 'ok', 42, <Object?>[]]) {
        expect(
          () => decode(payload),
          throwsA(
            isA<AdminAuthFailure>().having(
              (f) => f.code,
              'code',
              SubscriptionErrorCode.temporaryBackendFailure,
            ),
          ),
        );
      }
    });
  });

  group('failureFrom', () {
    AdminAuthFailure map(int status, [Object? details]) =>
        SupabaseAdminSessionGateway.failureFrom(
          FunctionException(status: status, details: details),
        );

    test('401 is unauthenticated, 403 is unauthorized, regardless of body', () {
      expect(map(401).code, SubscriptionErrorCode.authRequired);
      expect(
        map(401, {
          'error': {'code': 'ADMIN_UNAUTHORIZED'},
        }).code,
        SubscriptionErrorCode.authRequired,
      );
      expect(map(403).code, SubscriptionErrorCode.adminUnauthorized);
      expect(
        map(403, {
          'error': {'code': 'AUTH_REQUIRED'},
        }).code,
        SubscriptionErrorCode.adminUnauthorized,
      );
    });

    test('other statuses honour a contract code or fall back to temporary', () {
      expect(
        map(400, {
          'error': {'code': 'ADMIN_UNAUTHORIZED'},
        }).code,
        SubscriptionErrorCode.adminUnauthorized,
      );
      final unknown = map(500, {
        'error': {'code': 'SOMETHING_ELSE', 'retryable': false},
      });
      expect(unknown.code, SubscriptionErrorCode.temporaryBackendFailure);
      expect(unknown.retryable, isTrue, reason: '5xx is retryable');
      final backend = map(503, {
        'error': {'code': 'TEMPORARY_BACKEND_FAILURE', 'retryable': true},
      });
      expect(backend.code, SubscriptionErrorCode.temporaryBackendFailure);
      expect(backend.retryable, isTrue);
      expect(map(418).retryable, isFalse);
    });

    test('a body never escalates a refusal into authorization', () {
      // There is no status/body combination that yields anything but a
      // failure; the return type alone guarantees it, and the codes are the
      // three the contract allows for a session check.
      for (final status in [400, 401, 403, 404, 409, 500, 503]) {
        final failure = map(status, {
          'ok': true,
          'admin': {'role': 'admin', 'userId': 'x'},
        });
        expect(
          failure.code,
          isIn([
            SubscriptionErrorCode.authRequired,
            SubscriptionErrorCode.adminUnauthorized,
            SubscriptionErrorCode.temporaryBackendFailure,
          ]),
        );
      }
    });
  });
}
