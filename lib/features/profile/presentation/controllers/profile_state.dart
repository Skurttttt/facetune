import '../../domain/entities/user_profile.dart';
import '../../domain/errors/profile_failure.dart';

enum ProfileStatus { loading, ready, failure }

enum ProfileOperation { displayName, avatar }

class ProfileState {
  const ProfileState({
    this.status = ProfileStatus.loading,
    this.profile,
    this.activeOperation,
    this.message,
    this.feedback,
    this.feedbackIsError = false,
    this.failureKind,
    this.retryable = true,
  });

  final ProfileStatus status;
  final UserProfile? profile;
  final ProfileOperation? activeOperation;
  final String? message;
  final String? feedback;
  final bool feedbackIsError;
  final ProfileFailureKind? failureKind;
  final bool retryable;

  bool get isBusy => activeOperation != null;
}
