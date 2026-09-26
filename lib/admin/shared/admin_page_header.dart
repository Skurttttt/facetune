import 'package:flutter/material.dart';

import '../theme/admin_tokens.dart';

/// The one page header every Web Admin page uses (WA-13.5-UI-4).
///
/// Canonical composition: a title, a subtitle that says what the page is for,
/// and an optional right-hand slot for metadata and actions.
///
/// It renders the page's only primary heading. The top utility bar
/// deliberately no longer repeats it — before UI-4 every page announced its
/// name twice, once in the bar and once on the page, which gave a screen
/// reader two headings for one page and gave a sighted reader nothing extra.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.actions = const <Widget>[],
  });

  final String title;

  /// One sentence on what the page is for. Never a number, never a statistic.
  final String subtitle;

  /// Metadata and controls that belong to the page as a whole, such as a
  /// "last updated" stamp and a Refresh button. Laid out at the end of the
  /// title row, where they do not compete with the heading.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        key: const Key('admin-page-title'),
        style: theme.textTheme.headlineSmall,
      ),
    );
    final description = Text(
      subtitle,
      key: const Key('admin-page-subtitle'),
      style: theme.textTheme.bodyMedium,
    );
    final actionRow = Wrap(
      key: const Key('admin-page-actions'),
      spacing: AdminSpacing.xs,
      runSpacing: AdminSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: actions,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackActions = actions.isNotEmpty && constraints.maxWidth < 720;
        if (stackActions) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              heading,
              const SizedBox(height: AdminSpacing.xxs),
              description,
              const SizedBox(height: AdminSpacing.sm),
              actionRow,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: AdminSpacing.md),
                  actionRow,
                ],
              ],
            ),
            const SizedBox(height: AdminSpacing.xxs),
            description,
          ],
        );
      },
    );
  }
}
