import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';
import '../theme/admin_typography.dart';

/// A visible label above an Admin control.
///
/// The child retains ownership of controllers, validation, submission and
/// business behavior. This widget standardizes presentation only.
class AdminLabeledField extends StatelessWidget {
  const AdminLabeledField({
    super.key,
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(child: Text(label, style: AdminTypography.formLabel)),
      const SizedBox(height: AdminSpacing.xxs),
      Semantics(label: label, child: child),
    ],
  );
}

/// One coherent surface for a server-backed filter or exact-search form.
class AdminFilterPanel extends StatelessWidget {
  const AdminFilterPanel({
    super.key,
    required this.fields,
    required this.actions,
    this.maxWidth,
  });

  final List<Widget> fields;
  final List<Widget> actions;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border, width: AdminBorders.hairline),
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.ml),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminResponsiveFormGrid(children: fields),
            const SizedBox(height: AdminSpacing.md),
            AdminFormActions(children: actions),
          ],
        ),
      ),
    );
    return maxWidth == null
        ? panel
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: panel,
          );
  }
}

/// A deterministic responsive field grid for desktop and compact Admin widths.
///
/// This intentionally uses explicit rows and breakpoints instead of relying on
/// content-width-driven wrapping, so labels and controls remain aligned.
class AdminResponsiveFormGrid extends StatelessWidget {
  const AdminResponsiveFormGrid({
    super.key,
    required this.children,
    this.columnSpacing = AdminSpacing.ml,
    this.rowSpacing = AdminSpacing.ml,
  });

  final List<Widget> children;
  final double columnSpacing;
  final double rowSpacing;

  @visibleForTesting
  static int columnCountFor(double width) {
    if (width >= 1040) return 4;
    if (width >= 640) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = columnCountFor(constraints.maxWidth);
      final fieldWidth =
          (constraints.maxWidth - (columnSpacing * (columns - 1))) / columns;
      final rows = <Widget>[];
      for (var start = 0; start < children.length; start += columns) {
        final end = (start + columns).clamp(0, children.length);
        if (rows.isNotEmpty) rows.add(SizedBox(height: rowSpacing));
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = start; index < end; index++) ...[
                if (index > start) SizedBox(width: columnSpacing),
                SizedBox(width: fieldWidth, child: children[index]),
              ],
            ],
          ),
        );
      }
      return Column(mainAxisSize: MainAxisSize.min, children: rows);
    },
  );
}

/// Primary submit first, followed by lower-emphasis Clear/Cancel actions.
class AdminFormActions extends StatelessWidget {
  const AdminFormActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AdminSpacing.xs,
    runSpacing: AdminSpacing.xs,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}
