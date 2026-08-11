import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../authentication/presentation/controllers/auth_state.dart';
import '../../../authentication/presentation/widgets/auth_feedback_listener.dart';
import '../../data/providers/settings_providers.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/errors/settings_failure.dart';
import '../controllers/settings_controller.dart';
import '../controllers/settings_state.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForAuthFeedback(ref, context);
    final state = ref.watch(settingsControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isGuest = authState.user?.isAnonymous == true;
    final version = ref.watch(appVersionProvider);
    final sessionExpired =
        state.failureKind == SettingsFailureKind.sessionExpired;
    ref.listen<SettingsState>(settingsControllerProvider, (previous, next) {
      if (next.feedback == null || next.feedback == previous?.feedback) return;
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(next.feedback!),
          backgroundColor: next.feedbackIsError ? AppColors.error : null,
        ),
      );
      ref.read(settingsControllerProvider.notifier).clearFeedback();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: PageFrame(
          child: switch (state.status) {
            SettingsStatus.loading => const Center(
              child: LoadingState(label: 'Loading your preferences…'),
            ),
            SettingsStatus.failure => Center(
              child: StatusState(
                title: 'Settings unavailable',
                message: state.message ?? 'Please try again.',
                icon: Icons.settings_backup_restore_rounded,
                actionLabel: sessionExpired
                    ? 'Sign in again'
                    : state.retryable
                    ? 'Try again'
                    : 'Sign out',
                onAction: sessionExpired
                    ? () => ref
                          .read(authControllerProvider.notifier)
                          .recoverExpiredSession()
                    : state.retryable
                    ? () => ref.read(settingsControllerProvider.notifier).load()
                    : () => _confirmSignOut(context, ref, isGuest),
                secondaryActionLabel: !sessionExpired && state.retryable
                    ? 'Sign out'
                    : null,
                onSecondaryAction: !sessionExpired && state.retryable
                    ? () => _confirmSignOut(context, ref, isGuest)
                    : null,
              ),
            ),
            SettingsStatus.ready => ListView(
              children: [
                if (isGuest) ...[
                  const AppCard(
                    color: AppColors.petal,
                    child: Text(
                      'These preferences belong to your temporary guest account. Signing out can permanently remove access to this account and its private data.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                const SectionHeader('Appearance'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Use your device appearance or choose a fixed theme.',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<AppThemePreference>(
                          segments: const [
                            ButtonSegment(
                              value: AppThemePreference.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: AppThemePreference.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: AppThemePreference.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {state.settings.theme},
                          onSelectionChanged: state.activeOperation == null
                              ? (selection) => ref
                                    .read(settingsControllerProvider.notifier)
                                    .updateTheme(selection.single)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Preferences'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined),
                        title: const Text('Notification preference'),
                        subtitle: const Text(
                          'Saved for future use. FaceTune does not send notifications yet.',
                        ),
                        value: state.settings.notificationsEnabled,
                        onChanged: state.activeOperation == null
                            ? (value) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .updateNotifications(value)
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.analytics_outlined),
                        title: const Text('Analytics consent'),
                        subtitle: const Text(
                          'Stores your consent choice. No analytics SDK is active.',
                        ),
                        value: state.settings.analyticsConsent,
                        onChanged: state.activeOperation == null
                            ? (value) => ref
                                  .read(settingsControllerProvider.notifier)
                                  .updateAnalyticsConsent(value)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader('Privacy and about'),
                const SizedBox(height: AppSpacing.sm),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Image privacy'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showInformation(
                          context,
                          title: 'Image privacy',
                          message:
                              'Original selfies, generated previews, and profile photos are stored privately. FaceTune uses short-lived signed links for display. Delete a History session to remove its selfie, previews, recommendations, and saved links.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.policy_outlined),
                        title: const Text('Privacy policy'),
                        subtitle: const Text('Publication pending'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showInformation(
                          context,
                          title: 'Privacy policy',
                          message:
                              'A production privacy-policy link has not been published yet. This placeholder does not represent a legal policy.',
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded),
                        title: const Text('About FaceTune'),
                        subtitle: Text(
                          version.when(
                            data: (value) => 'Version $value',
                            loading: () => 'Loading version…',
                            error: (_, _) => 'Version unavailable',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _showInformation(
                          context,
                          title: 'About FaceTune',
                          message:
                              'FaceTune creates personalized, brand-neutral makeup inspiration and identity-conscious AI previews. AI results can vary.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                SecondaryButton(
                  label: authState.activeOperation == AuthOperation.signOut
                      ? 'Signing out…'
                      : 'Sign out',
                  icon: Icons.logout_rounded,
                  onPressed: authState.isLoading
                      ? null
                      : () => _confirmSignOut(context, ref, isGuest),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          },
        ),
      ),
    );
  }

  static Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    bool isGuest,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isGuest ? 'Sign out of guest account?' : 'Sign out?'),
        content: Text(
          isGuest
              ? 'This does not delete backend records, but this temporary account cannot currently be recovered or transferred. You may permanently lose access to its history and saved looks.'
              : 'You can sign in again later to access your private FaceTune data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  static Future<void> _showInformation(
    BuildContext context, {
    required String title,
    required String message,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
