import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_availability_provider.dart';
import '../../../core/supabase/supabase_client_provider.dart';
import '../domain/admin_user_models.dart';
import '../domain/admin_users_failure.dart';
import '../domain/admin_users_gateway.dart';
import 'supabase_admin_users_gateway.dart';

final adminUsersGatewayProvider = Provider<AdminUsersGateway>((ref) {
  if (!ref.watch(supabaseAvailableProvider)) {
    return const _UnavailableAdminUsersGateway();
  }
  return SupabaseAdminUsersGateway(ref.watch(supabaseClientProvider));
});

class _UnavailableAdminUsersGateway implements AdminUsersGateway {
  const _UnavailableAdminUsersGateway();

  @override
  Future<AdminUserDetail> getUser(String userId) async {
    throw const AdminUsersFailure(AdminUsersFailureType.unavailable);
  }

  @override
  Future<AdminUserPage> searchUsers({String? search, String? cursor}) async {
    throw const AdminUsersFailure(AdminUsersFailureType.unavailable);
  }
}
