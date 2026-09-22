import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import '../app/admin_routes.dart';

/// A safe destination for a section whose data feature belongs to a later
/// phase. States plainly what the section will show and which phase brings
/// it. Fetches nothing and shows no figures — a placeholder that looked like
/// a dashboard would be a fake one.
class AdminSectionPlaceholderPage extends StatelessWidget {
  const AdminSectionPlaceholderPage({super.key, required this.section});

  final AdminSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: Key('admin-section-${section.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(section.label, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(section.summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'This section is not connected yet. '
                    'Its data arrives in ${section.arrivesIn}.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
