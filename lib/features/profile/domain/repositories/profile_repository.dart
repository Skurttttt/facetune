import '../entities/avatar_image.dart';
import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> load();

  Future<UserProfile> updateDisplayName(String displayName);

  Future<UserProfile> updateAvatar(AvatarImage avatar);
}
