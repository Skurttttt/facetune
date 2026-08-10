import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../../../features/authentication/presentation/controllers/auth_state.dart';
import '../../../../features/authentication/presentation/widgets/auth_feedback_listener.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    listenForAuthFeedback(ref, context);
    final authState = ref.watch(authControllerProvider);
    final user = authState.user;
    final isGuest = user?.isAnonymous ?? false;

    return AppShell(
      index: 3,
      child: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Profile',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  IconButton(
                    onPressed: () => context.push(AppConstants.settingsRoute),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 42,
                      backgroundColor: AppColors.blush,
                      foregroundColor: AppColors.rose,
                      child: Icon(Icons.person_rounded, size: 44),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      user?.friendlyName ?? 'Beauty lover',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      isGuest
                          ? 'Guest beauty profile'
                          : user?.email ?? 'FaceTune account',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat('12', 'Looks'),
                        _Stat('8', 'Saved'),
                        _Stat('4', 'Favorites'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const _ProfileTile(Icons.favorite_border_rounded, 'Saved looks'),
              const _ProfileTile(Icons.history_rounded, 'Scan history'),
              _ProfileTile(
                Icons.settings_outlined,
                'Settings',
                onTap: () => context.push(AppConstants.settingsRoute),
              ),
              const _ProfileTile(Icons.shield_outlined, 'Privacy & data'),
              const _ProfileTile(Icons.info_outline_rounded, 'About FaceTune'),
              if (isGuest) ...[
                const SizedBox(height: AppSpacing.lg),
                const AppCard(
                  color: AppColors.petal,
                  child: Text(
                    'This guest account is temporary. Signing out removes access to its saved data unless it is upgraded in a future account-linking flow.',
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SecondaryButton(
                label: authState.activeOperation == AuthOperation.signOut
                    ? 'Signing out…'
                    : 'Sign out',
                icon: Icons.logout_rounded,
                onPressed: authState.isLoading
                    ? null
                    : () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(value, style: Theme.of(context).textTheme.titleLarge),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile(this.icon, this.label, {this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(icon, color: AppColors.rose),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
