import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../shared/widgets/app_shell.dart';
import '../../../../shared/widgets/app_ui.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) => AppShell(
    index: 2,
    child: SafeArea(
      child: PageFrame(
        child: ListView(
          children: [
            Text('History', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            const TextField(
              decoration: InputDecoration(
                hintText: 'Search your looks',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              children: [
                const FilterChip(
                  label: Text('All'),
                  selected: true,
                  onSelected: null,
                ),
                FilterChip(label: const Text('Favorites'), onSelected: (_) {}),
                FilterChip(label: const Text('This month'), onSelected: (_) {}),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Today'),
            const SizedBox(height: AppSpacing.sm),
            const _HistoryTile(
              title: 'Soft Glam',
              subtitle: 'Warm Â· Luminous Â· 10:42 AM',
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader('Earlier'),
            const SizedBox(height: AppSpacing.sm),
            const _HistoryTile(
              title: 'Clean Girl',
              subtitle: 'Fresh Â· Sheer Â· Monday',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _HistoryTile(
              title: 'Date Night',
              subtitle: 'Rosewood Â· Satin Â· Aug 1',
            ),
          ],
        ),
      ),
    ),
  );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(12),
    onTap: () => context.push(AppConstants.previewRoute),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Image.asset(
            'assets/images/beauty_portrait.png',
            width: 76,
            height: 76,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
  );
}
