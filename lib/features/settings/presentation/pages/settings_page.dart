import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_ui.dart';
import '../controllers/theme_mode_controller.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: PageFrame(
          child: ListView(
            children: [
              const SectionHeader('Appearance'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Dark appearance'),
                  subtitle: const Text('Preview the dark-ready design system'),
                  value: mode == ThemeMode.dark,
                  onChanged: (_) =>
                      ref.read(themeModeProvider.notifier).toggleThemeMode(),
                  secondary: const Icon(Icons.dark_mode_outlined),
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
                      title: const Text('Look inspiration'),
                      subtitle: const Text('Occasional personalized ideas'),
                      value: true,
                      onChanged: (_) {},
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      title: const Text('Product updates'),
                      value: false,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader('Privacy'),
              const SizedBox(height: AppSpacing.sm),
              const AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      title: Text('Image privacy'),
                      trailing: Icon(Icons.chevron_right_rounded),
                    ),
                    Divider(height: 1),
                    ListTile(
                      title: Text('Data & permissions'),
                      trailing: Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const StatusState(
                title: 'Youâ€™re in control',
                message:
                    'These controls are visual previews only. No settings are persisted in Phase 2.',
                icon: Icons.lock_outline_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
