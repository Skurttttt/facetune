import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../domain/admin_auth_failure.dart';
import '../domain/admin_identity.dart';
import '../domain/admin_session_gateway.dart';

/// Used when Supabase is not configured for this build. Nobody is an admin.
class UnavailableAdminSessionGateway implements AdminSessionGateway {
  const UnavailableAdminSessionGateway();

  @override
  Future<AdminIdentity> verifyAdminSession() async {
    throw const AdminAuthFailure(SubscriptionErrorCode.temporaryBackendFailure);
  }
}
