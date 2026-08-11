import '../../domain/entities/avatar_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/errors/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';

class UnavailableProfileRepository implements ProfileRepository {
  const UnavailableProfileRepository();

  @override
  Future<UserProfile> load() =>
      throw const ProfileFailure('Profile is unavailable in this build.');

  @override
  Future<UserProfile> updateAvatar(AvatarImage avatar) =>
      throw const ProfileFailure('Profile is unavailable in this build.');

  @override
  Future<UserProfile> updateDisplayName(String displayName) =>
      throw const ProfileFailure('Profile is unavailable in this build.');
}
