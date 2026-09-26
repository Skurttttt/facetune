import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';
import '../theme/admin_typography.dart';
import 'admin_keyset_list_controller.dart';
import 'admin_labels.dart';
import 'admin_wire.dart';

/// Shared building blocks for the filtered, paginated admin listings.
///
/// Dense, bordered, text-first. Status is always written out; color is never
/// the only carrier. Nothing here fetches or computes a figure.

/// A contained, horizontally scrollable operational table.
///
/// The widget owns only table presentation. Callers retain their existing
/// server rows, filters, actions, routing and pagination behavior.
class AdminTable extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyState,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  /// Optional table-contained content for a legitimate empty result set.
  ///
  /// The caller still owns the distinction between empty, no-result, error,
  /// and loading states. This slot only keeps an accepted empty state inside
  /// the same operational surface as the table heading.
  final Widget? emptyState;

  @override
  State<AdminTable> createState() => _AdminTableState();
}

class _AdminTableState extends State<AdminTable> {
  final ScrollController _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final scaleAdjustment = (textScale - 1).clamp(0.0, 1.0);
    final headingRowHeight = 44.0 + (12 * scaleAdjustment);
    final dataRowMinHeight = 52.0 + (12 * scaleAdjustment);
    final dataRowMaxHeight = 64.0 + (24 * scaleAdjustment);
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : 0.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(
              color: colors.border,
              width: AdminBorders.hairline,
            ),
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminRadii.card),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Scrollbar(
                  controller: _horizontal,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  scrollbarOrientation: ScrollbarOrientation.bottom,
                  child: SingleChildScrollView(
                    controller: _horizontal,
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: availableWidth),
                      child: DataTable(
                        headingRowHeight: headingRowHeight,
                        dataRowMinHeight: dataRowMinHeight,
                        dataRowMaxHeight: dataRowMaxHeight,
                        horizontalMargin: AdminSpacing.md,
                        columnSpacing: AdminSpacing.xl,
                        dividerThickness: AdminBorders.hairline,
                        headingRowColor: WidgetStatePropertyAll(
                          colors.surfaceSecondary,
                        ),
                        dataRowColor: WidgetStateProperty.resolveWith((states) {
                          return states.contains(WidgetState.hovered)
                              ? colors.surfaceSecondary
                              : colors.surface;
                        }),
                        headingTextStyle: AdminTypography.tableHeading,
                        dataTextStyle: AdminTypography.tableContent,
                        showCheckboxColumn: false,
                        columns: widget.columns,
                        rows: widget.rows,
                      ),
                    ),
                  ),
                ),
                if (widget.emptyState != null) widget.emptyState!,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The stable rightmost action region used by every operational table.
class AdminTableActions extends StatelessWidget {
  const AdminTableActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(width: AdminSpacing.xxs),
        children[index],
      ],
    ],
  );
}

class AdminListLoadingRow extends StatelessWidget {
  const AdminListLoadingRow({
    super.key,
    required this.label,
    this.skeleton = true,
  });

  final String label;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    if (!skeleton) return AdminProgressState(label: label);
    return AdminSkeletonRows(label: label);
  }
}

class AdminListNotice extends StatelessWidget {
  const AdminListNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.error = false,
    this.bordered = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool error;
  final bool bordered;

  @override
  Widget build(BuildContext context) => AdminStatePanel(
    icon: icon,
    title: title,
    message: message,
    action: action,
    error: error,
    bordered: bordered,
  );
}

/// Canonical compact surface for empty, no-result, unavailable, and rejected
/// read states. Callers retain state classification and retry behavior.
class AdminStatePanel extends StatelessWidget {
  const AdminStatePanel({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.error = false,
    this.bordered = true,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool error;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AdminSemanticColors.of(context);
    final semanticColor = error ? colors.danger : colors.textSecondary;
    return Semantics(
      container: true,
      liveRegion: error,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: bordered
              ? Border.all(
                  color: error ? colors.danger : colors.border,
                  width: AdminBorders.hairline,
                )
              : null,
          borderRadius: BorderRadius.circular(AdminRadii.card),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AdminSpacing.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final content = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: semanticColor, size: AdminIconSizes.lg),
                  const SizedBox(width: AdminSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleSmall),
                        const SizedBox(height: AdminSpacing.xxs),
                        Text(message, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              );
              if (action == null) return content;
              if (constraints.maxWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    content,
                    const SizedBox(height: AdminSpacing.sm),
                    Align(alignment: Alignment.centerLeft, child: action),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: content),
                  action!,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Static skeleton rows for server-backed read surfaces. The semantic label
/// remains available while decorative placeholders stay out of the tree.
class AdminSkeletonRows extends StatelessWidget {
  const AdminSkeletonRows({
    super.key,
    required this.label,
    this.rowCount = 4,
    this.bordered = true,
  });

  final String label;
  final int rowCount;
  final bool bordered;

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: bordered
                ? Border.all(color: colors.border, width: AdminBorders.hairline)
                : null,
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AdminSpacing.md),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (var index = 0; index < rowCount; index++) ...[
                if (index > 0) Divider(height: 1, color: colors.border),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.md,
                    vertical: AdminSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _SkeletonBar(color: colors.surfaceSecondary),
                      ),
                      const SizedBox(width: AdminSpacing.lg),
                      Expanded(
                        flex: 2,
                        child: _SkeletonBar(color: colors.surfaceSecondary),
                      ),
                      const SizedBox(width: AdminSpacing.lg),
                      Expanded(
                        child: _SkeletonBar(color: colors.surfaceSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress treatment for mutations, where a read-surface skeleton would be
/// misleading. This does not change whether a workflow is blocking.
class AdminProgressState extends StatelessWidget {
  const AdminProgressState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AdminRadii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AdminSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AdminSpacing.sm),
                const LinearProgressIndicator(minHeight: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 12,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AdminRadii.control),
    ),
  );
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
    final colors = AdminSemanticColors.of(context);
    final (Color border, Color foreground) = switch (emphasis) {
      AdminBadgeEmphasis.neutral => (colors.borderStrong, colors.textSecondary),
      AdminBadgeEmphasis.positive => (colors.success, colors.success),
      AdminBadgeEmphasis.caution => (colors.warning, colors.warning),
      AdminBadgeEmphasis.negative => (colors.danger, colors.danger),
      AdminBadgeEmphasis.information => (
        colors.information,
        colors.information,
      ),
    };
    return Semantics(
      label: '$semanticsPrefix: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.xs,
          vertical: AdminSpacing.xxs / 2,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(AdminRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              key: const Key('admin-status-indicator'),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AdminSpacing.xxs),
            Text(
              label,
              style: AdminTypography.statusBadge.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

enum AdminBadgeEmphasis { neutral, positive, caution, negative, information }

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

/// A compact table identity with email first and shortened UUID metadata.
class AdminIdentityCell extends StatelessWidget {
  const AdminIdentityCell({
    super.key,
    required this.email,
    required this.userId,
    this.emptyLabel = 'No identity',
  });

  final String? email;
  final String? userId;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final primary = email ?? (userId == null ? emptyLabel : 'No email');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: primary,
            child: Text(primary, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (userId != null) AdminIdCell(userId!),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) => AdminPaginationControl(
    keyPrefix: keyPrefix,
    pageNumber: state.pageNumber,
    itemCount: state.page.items.length,
    pageSize: adminPageSize,
    canGoBack: state.canGoBack,
    canGoNext: state.page.nextCursor != null,
    onPrevious: onPrevious,
    onNext: onNext,
  );
}

/// Responsive layout for the existing fixed-size server pagination controls.
class AdminPaginationControl extends StatelessWidget {
  const AdminPaginationControl({
    super.key,
    required this.keyPrefix,
    required this.pageNumber,
    required this.itemCount,
    required this.pageSize,
    required this.canGoBack,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final String keyPrefix;
  final int pageNumber;
  final int itemCount;
  final int pageSize;
  final bool canGoBack;
  final bool canGoNext;
  final Future<void> Function() onPrevious;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AdminSpacing.md,
    runSpacing: AdminSpacing.xs,
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text(
        'Page $pageNumber · $itemCount of up to $pageSize',
        key: Key('$keyPrefix-page-label'),
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton(
            key: Key('$keyPrefix-previous'),
            onPressed: canGoBack ? onPrevious : null,
            child: const Text('Previous'),
          ),
          const SizedBox(width: AdminSpacing.xs),
          OutlinedButton(
            key: Key('$keyPrefix-next'),
            onPressed: canGoNext ? onNext : null,
            child: const Text('Next'),
          ),
        ],
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

// The listing section header moved to `AdminPageHeader` in WA-13.5-UI-4: it
// was the page's heading, not a listing's, and it had no slot for the
// per-page metadata and actions the Dashboard and the research page need.
