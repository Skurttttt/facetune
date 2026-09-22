import 'admin_user_models.dart';

abstract interface class AdminUsersGateway {
  Future<AdminUserPage> searchUsers({String? search, String? cursor});

  Future<AdminUserDetail> getUser(String userId);
}
