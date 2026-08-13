import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/domain/services/auth_validators.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/widgets/auth_feedback_listener.dart';
import '../../domain/errors/profile_failure.dart';
import '../controllers/profile_controller.dart';
import '../controllers/profile_state.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    final state = ref.watch(profileControllerProvider);
    ref.listen<ProfileState>(profileControllerProvider, (previous, next) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          backgroundColor: next.feedbackIsError ? AppColors.error : null,
        ),
      );
      ref.read(profileControllerProvider.notifier).clearFeedback();
    });
    final user = authState.user;
    final isGuest = user?.isAnonymous == true;
    final sessionExpired =
        state.failureKind == ProfileFailureKind.sessionExpired;

    return AppShell(
      index: 3,
      child: SafeArea(
        child: PageFrame(
          child: switch (state.status) {
            ProfileStatus.loading => const Center(
              child: LoadingState(label: 'Loading your profile…'),
            ),
            ProfileStatus.failure => Center(
              child: StatusState(
                title: 'Profile unavailable',
                message: state.message ?? 'Please try again.',
                icon: Icons.person_off_outlined,
                actionLabel: sessionExpired
                    ? 'Sign in again'
                    : state.retryable
                    ? 'Try again'
                    : null,
                onAction: sessionExpired
                    ? () => ref
                          .read(authControllerProvider.notifier)
                          .recoverExpiredSession()
                    : state.retryable
                    ? () => ref.read(profileControllerProvider.notifier).load()
                    : null,
              ),
            ),
            ProfileStatus.ready => ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Profile',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: 'Open settings',
                      onPressed: () => context.push(AppConstants.settingsRoute),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  child: Column(
                    children: [
                      _ProfileAvatar(
                        imageUrl: state.profile?.avatarUrl,
                        initials: _initials(
                          state.profile?.displayName ?? user?.friendlyName,
                        ),
                        isLoading:
                            state.activeOperation == ProfileOperation.avatar,
                        onPressed: state.isBusy
                            ? null
                            : () => ref
                                  .read(profileControllerProvider.notifier)
                                  .chooseAvatar(),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        state.profile?.displayName ??
                            user?.friendlyName ??
                            'Beauty lover',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isGuest
                            ? 'No email linked'
                            : user?.email ?? 'Email unavailable',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Chip(
                        avatar: Icon(
                          isGuest
                              ? Icons.hourglass_empty_rounded
                              : Icons.verified_user_outlined,
                          size: AppIconSizes.sm,
                        ),
                        label: Text(
                          isGuest ? 'Guest account' : 'Registered account',
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextButton.icon(
                        onPressed: state.isBusy
                            ? null
                            : () => _editDisplayName(
                                context,
                                ref,
                                state.profile?.displayName ?? '',
                              ),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(
                          state.activeOperation == ProfileOperation.displayName
                              ? 'Saving…'
                              : 'Edit display name',
                        ),
                      ),
                    ],
                  ),
                ),
                if (isGuest) ...[
                  const SizedBox(height: AppSpacing.md),
                  const AppCard(
                    color: AppColors.petal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your guest account is temporary',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          'Your private looks remain attached to this anonymous account. Signing out or clearing app data can permanently remove your access. Safe account transfer is not available yet, so do not sign out if you want to keep this history.',
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const SectionHeader('Your library'),
                const SizedBox(height: AppSpacing.xs),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.favorite_border_rounded,
                          color: AppColors.rose,
                        ),
                        title: const Text('Saved looks'),
                        subtitle: const Text('Your intentional collection'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppConstants.savedRoute),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.history_rounded,
                          color: AppColors.rose,
                        ),
                        title: const Text('FaceTune history'),
                        subtitle: const Text('Past analyses and previews'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(AppConstants.historyRoute),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.rose,
                        ),
                        title: const Text('My Makeup Kit'),
                        subtitle: const Text('Makeup products you own'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push(AppConstants.makeupKitRoute),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: const Icon(
                    Icons.settings_outlined,
                    color: AppColors.rose,
                  ),
                  title: const Text('Settings and privacy'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppConstants.settingsRoute),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          },
        ),
      ),
    );
  }

  static Future<void> _editDisplayName(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: currentName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit display name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            validator: AuthValidators.displayName,
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, controller.text);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) {
      await ref
          .read(profileControllerProvider.notifier)
          .updateDisplayName(value);
    }
  }

  static String _initials(String? value) {
    final words = value
        ?.trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words == null || words.isEmpty) return 'FT';
    return words.take(2).map((word) => word[0].toUpperCase()).join();
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.isLoading,
    required this.onPressed,
    this.imageUrl,
  });

  final String? imageUrl;
  final String initials;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Profile photo. Double tap to choose a new photo.',
    button: true,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox.square(
            dimension: 96,
            child: imageUrl == null
                ? _fallback(context)
                : Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    // A 2 MiB avatar drawn into a 96 px circle otherwise decodes
                    // at full source resolution.
                    cacheWidth: decodeWidthForSize(context, 96),
                    errorBuilder: (context, error, stackTrace) =>
                        _fallback(context),
                  ),
          ),
        ),
        if (isLoading)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
        Positioned(
          right: -4,
          bottom: -4,
          child: IconButton.filled(
            tooltip: 'Choose profile photo',
            onPressed: onPressed,
            icon: const Icon(Icons.photo_library_outlined, size: 20),
          ),
        ),
      ],
    ),
  );

  Widget _fallback(BuildContext context) => ColoredBox(
    color: AppColors.blush,
    child: Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: AppColors.roseDark,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
