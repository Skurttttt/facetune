import 'package:flutter/material.dart';

import '../../theme/app_tokens.dart';
import 'admin_keyset_list_controller.dart';
import 'admin_labels.dart';
import 'admin_wire.dart';

/// Shared building blocks for the filtered, paginated admin listings.
///
/// Dense, bordered, text-first. Status is always written out; color is never
/// the only carrier. Nothing here fetches or computes a figure.

class AdminListLoadingRow extends StatelessWidget {
  const AdminListLoadingRow({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            semanticsLabel: label,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('$label…'),
      ],
    ),
  );
}

class AdminListNotice extends StatelessWidget {
  const AdminListNotice({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// A status written as text inside a subtle outline. The [semanticsPrefix]
/// lets a screen reader hear which status this is (e.g. "Entitlement status").
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    super.key,
    required this.label,
    required this.semanticsPrefix,
    this.emphasis = AdminBadgeEmphasis.neutral,
  });

  final String label;
  final String semanticsPrefix;
  final AdminBadgeEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color border, Color foreground) = switch (emphasis) {
      AdminBadgeEmphasis.neutral => (scheme.outlineVariant, scheme.onSurface),
      AdminBadgeEmphasis.positive => (scheme.primary, scheme.primary),
      AdminBadgeEmphasis.caution => (scheme.tertiary, scheme.tertiary),
      AdminBadgeEmphasis.negative => (scheme.error, scheme.error),
    };
    return Semantics(
      label: '$semanticsPrefix: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs / 2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

enum AdminBadgeEmphasis { neutral, positive, caution, negative }

/// A UUID shortened for a dense table, with the full value in a tooltip and
/// selectable so it can be copied.
class AdminIdCell extends StatelessWidget {
  const AdminIdCell(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: value,
    child: SelectableText(
      shortId(value),
      style: const TextStyle(fontFamily: 'monospace'),
    ),
  );
}

/// Page label plus Previous / Next for one fixed-size server page.
class AdminPaginationBar<T, F> extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.keyPrefix,
    required this.state,
    required this.onPrevious,
    required this.onNext,
  });

  final String keyPrefix;
  final AdminListReady<T, F> state;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        'Page ${state.pageNumber} · ${state.page.items.length} of up to $adminPageSize',
        key: Key('$keyPrefix-page-label'),
      ),
      const Spacer(),
      OutlinedButton(
        key: Key('$keyPrefix-previous'),
        onPressed: state.canGoBack ? onPrevious : null,
        child: const Text('Previous'),
      ),
      const SizedBox(width: AppSpacing.xs),
      OutlinedButton(
        key: Key('$keyPrefix-next'),
        onPressed: state.page.nextCursor == null ? null : onNext,
        child: const Text('Next'),
      ),
    ],
  );
}

/// A fixed-width filter control so a row of them wraps predictably.
class AdminFilterSlot extends StatelessWidget {
  const AdminFilterSlot({super.key, required this.child, this.width = 220});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: child);
}

/// The section header every listing shares.
class AdminSectionHeading extends StatelessWidget {
  const AdminSectionHeading({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(description, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
