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
      if (userId != null) controller.load();
      return controller;
    });

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository, this._avatarPicker)
    : super(const ProfileState());

  final ProfileRepository _repository;
  final AvatarPicker _avatarPicker;

  Future<void> load() async {
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
        );
      }
    }
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
      if (mounted) {
        state = _state(feedback: failure.message);
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
      if (mounted) {
        state = _state(feedback: failure.message);
      }
    }
  }

  void clearFeedback() => state = _state();

  ProfileState _state({ProfileOperation? activeOperation, String? feedback}) =>
      ProfileState(
        status: state.status,
        profile: state.profile,
        activeOperation: activeOperation,
        message: state.message,
        feedback: feedback,
      );
}
