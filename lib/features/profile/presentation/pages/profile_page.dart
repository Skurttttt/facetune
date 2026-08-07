import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
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
                    'Mia Chen',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Text('Guest beauty profile'),
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
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              color: AppColors.petal,
              child: const Text(
                'Guest note: future guest data may be removed when you sign out or uninstall. Account and persistence behavior are not active in this static phase.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              label: 'View authentication entry',
              icon: Icons.logout_rounded,
              onPressed: () => context.push(AppConstants.authRoute),
            ),
          ],
        ),
      ),
    ),
  );
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
