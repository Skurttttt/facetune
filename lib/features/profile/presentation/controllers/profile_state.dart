import '../../domain/entities/user_profile.dart';

enum ProfileStatus { loading, ready, failure }

enum ProfileOperation { displayName, avatar }

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.loading,
    this.profile,
    this.activeOperation,
    this.message,
    this.feedback,
  });

  final ProfileStatus status;
  final UserProfile? profile;
  final ProfileOperation? activeOperation;
  final String? message;
  final String? feedback;

  bool get isBusy => activeOperation != null;
}
