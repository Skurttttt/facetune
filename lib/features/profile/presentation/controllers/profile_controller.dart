import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/profile_providers.dart';
import '../../domain/errors/profile_failure.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/services/avatar_picker.dart';
import 'profile_state.dart';

final profileControllerProvider =
    StateNotifierProvider.autoDispose<ProfileController, ProfileState>((ref) {
      final userId = ref.watch(
        authControllerProvider.select((state) => state.user?.id),
      );
      final controller = ProfileController(
        ref.watch(profileRepositoryProvider),
        ref.watch(avatarPickerProvider),
      );
      if (userId != null) {
        controller.load();
      } else {
        controller.markSignedOut();
      }
      return controller;
    });

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository, this._avatarPicker)
    : super(const ProfileState());

  final ProfileRepository _repository;
  final AvatarPicker _avatarPicker;
  bool _isLoading = false;

  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    state = const ProfileState();
    try {
      final profile = await _repository.load();
      if (mounted) {
        state = ProfileState(status: ProfileStatus.ready, profile: profile);
      }
    } on ProfileFailure catch (failure) {
      if (mounted) {
        state = ProfileState(
          status: ProfileStatus.failure,
          message: failure.message,
          failureKind: failure.kind,
          retryable: failure.retryable,
        );
      }
    } on Object {
      if (mounted) {
        state = const ProfileState(
          status: ProfileStatus.failure,
          message: 'Your profile could not be loaded. Please try again.',
          failureKind: ProfileFailureKind.unknown,
        );
      }
    } finally {
      _isLoading = false;
    }
  }

  /// Presents a terminal signed-out state.
  ///
  /// Without this the controller keeps its initial loading state whenever no
  /// account is active, leaving the profile behind a loader that can never
  /// resolve.
  void markSignedOut() {
    _isLoading = false;
    state = const ProfileState(
      status: ProfileStatus.failure,
      message: 'Sign in again to view your FaceTune profile.',
      failureKind: ProfileFailureKind.sessionExpired,
      retryable: false,
    );
  }

  Future<void> updateDisplayName(String displayName) async {
    if (state.isBusy) return;
    state = _state(activeOperation: ProfileOperation.displayName);
    try {
      final profile = await _repository.updateDisplayName(displayName);
      if (mounted) {
        state = ProfileState(
          status: ProfileStatus.ready,
          profile: profile,
          feedback: 'Display name updated.',
        );
      }
    } on ProfileFailure catch (failure) {
      if (mounted) _handleMutationFailure(failure);
    } on Object {
      if (mounted) {
        _handleMutationFailure(
          const ProfileFailure(
            'Your display name could not be updated. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> chooseAvatar() async {
    if (state.isBusy) return;
    state = _state(activeOperation: ProfileOperation.avatar);
    try {
      final avatar = await _avatarPicker.pick();
      if (!mounted) return;
      if (avatar == null) {
        state = _state();
        return;
      }
      final profile = await _repository.updateAvatar(avatar);
      if (mounted) {
        state = ProfileState(
          status: ProfileStatus.ready,
          profile: profile,
          feedback: 'Profile photo updated.',
        );
      }
    } on ProfileFailure catch (failure) {
      if (mounted) _handleMutationFailure(failure);
    } on Object {
      if (mounted) {
        _handleMutationFailure(
          const ProfileFailure(
            'Your profile photo could not be updated. Please try again.',
          ),
        );
      }
    }
  }

  void clearFeedback() => state = _state();

  void _handleMutationFailure(ProfileFailure failure) {
    if (failure.kind == ProfileFailureKind.sessionExpired) {
      state = ProfileState(
        status: ProfileStatus.failure,
        profile: state.profile,
        message: failure.message,
        failureKind: failure.kind,
        retryable: failure.retryable,
      );
      return;
    }
    state = _state(feedback: failure.message, feedbackIsError: true);
  }

  ProfileState _state({
    ProfileOperation? activeOperation,
    String? feedback,
    bool feedbackIsError = false,
  }) => ProfileState(
    status: state.status,
    profile: state.profile,
    activeOperation: activeOperation,
    message: state.message,
    feedback: feedback,
    feedbackIsError: feedbackIsError,
    failureKind: state.failureKind,
    retryable: state.retryable,
  );
}
