import 'package:flutter/material.dart';

import '../app/admin_routes.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';

/// The Web Admin's persistent navigation (WA-13.5-UI-3).
///
/// Purpose-built rather than a themed [NavigationRail]. Material's rail fixes
/// its own row height, its icon-to-label gap and its pill indicator, and the
/// design system asks for a 44px row, a 12px gap and a 3px edge indicator —
/// none of which the rail can express. Everything it *does* do is preserved
/// here: the same five destinations in the same order, the same selection
/// source, the same callback, and the same keyboard operability.
///
/// This widget decides nothing. It renders [sections] in their canonical
/// order, marks [selected], and reports taps through [onSelect]; the shell
/// owns routing and the router owns authorization.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.extended,
  });

  /// The section the current route belongs to, or null when the route is not
  /// a section (nothing is then marked active).
  final AdminSection? selected;

  final ValueChanged<AdminSection> onSelect;

  /// Labels beside icons at [AdminShellMetrics.expandedWidth]; icons only at
  /// [compactWidth].
  final bool extended;

  /// Brand region height (UI SOT section 11). Matches the top utility bar so
  /// the two align across the frame's corner.
  static const double brandHeight = 64;

  /// Navigation row height (UI SOT section 11).
  static const double rowHeight = 44;

  /// Icon-only width (UI SOT section 12).
  static const double compactWidth = 72;

  /// The selected-state edge indicator.
  static const double indicatorWidth = 3;

  /// The destinations, in canonical order. Not a parameter: the order is a
  /// contract, not a caller's choice.
  static List<AdminSection> get sections => AdminSection.values;

  @override
  Widget build(BuildContext context) {
    final semantics = AdminSemanticColors.of(context);

    return Container(
      width: extended ? AdminShellMetrics.expandedWidth : compactWidth,
      color: semantics.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: brandHeight,
            child: AdminBrand(compact: !extended),
          ),
          for (final section in sections)
            _SidebarRow(
              section: section,
              selected: section == selected,
              extended: extended,
              onTap: () => onSelect(section),
            ),
        ],
      ),
    );
  }
}

/// Frame measurements the sidebar and the shell both depend on.
///
/// Lives here rather than on `AdminShell` so the sidebar does not have to
/// import the shell that renders it.
abstract final class AdminShellMetrics {
  /// Expanded sidebar width (UI SOT section 11).
  static const double expandedWidth = 232;

  /// Top utility bar height (UI SOT section 11).
  static const double topBarHeight = 64;

  /// The readable column for dashboards, detail pages and forms.
  static const double maxContentWidth = 1480;
}

/// The product mark. Text beside the icon when there is room, icon alone
/// with a tooltip when there is not.
class AdminBrand extends StatelessWidget {
  const AdminBrand({super.key, this.compact = false});

  final bool compact;

  static const label = 'FaceTune Admin';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = AdminSemanticColors.of(context);

    if (compact) {
      return Tooltip(
        message: label,
        child: Center(
          child: Icon(
            Icons.admin_panel_settings_outlined,
            semanticLabel: label,
            size: AdminIconSizes.lg,
            color: semantics.accent,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminSpacing.md),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: AdminIconSizes.lg,
            color: semantics.accent,
          ),
          const SizedBox(width: AdminSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: semantics.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// One navigation row.
///
/// Stateful only to render its own focus ring: the design system asks for a
/// visible 2px accent ring, and an ink splash is not a focus indicator.
class _SidebarRow extends StatefulWidget {
  const _SidebarRow({
    required this.section,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  final AdminSection section;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  @override
  State<_SidebarRow> createState() => _SidebarRowState();
}

class _SidebarRowState extends State<_SidebarRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = AdminSemanticColors.of(context);
    final section = widget.section;
    final selected = widget.selected;

    final foreground = selected
        ? semantics.textPrimary
        : semantics.textSecondary;

    // The icon carries the destination's key so a test can find and activate
    // exactly one row, and so keyboard focus is proven to sit on the row that
    // contains it rather than on a scope enclosing all of them.
    final icon = Icon(
      selected ? section.selectedIcon : section.icon,
      key: Key('admin-nav-${section.name}'),
      size: AdminIconSizes.lg,
      color: selected ? semantics.accent : foreground,
    );

    final content = widget.extended
        ? Row(
            children: [
              icon,
              const SizedBox(width: AdminSpacing.sm),
              Expanded(
                child: Text(
                  section.label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          )
        : Center(child: icon);

    // The visible label repeats what the row's semantic label already says.
    // Left in the tree it merges into the node and a screen reader announces
    // the destination twice.
    final row = Container(
      height: AdminSidebar.rowHeight,
      decoration: BoxDecoration(
        color: selected ? semantics.accentSubtle : null,
        borderRadius: BorderRadius.circular(AdminRadii.control),
        border: _focused
            ? Border.all(color: semantics.accent, width: AdminFocus.ringWidth)
            : null,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: widget.extended ? AdminSpacing.sm : 0,
      ),
      child: ExcludeSemantics(child: content),
    );

    // The tooltip exists only when the label is not on screen. An always-on
    // tooltip would put an empty node into the semantics tree and say nothing
    // a sighted user cannot already read.
    Widget withTooltip(Widget child) =>
        widget.extended ? child : Tooltip(message: section.label, child: child);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: section.label,
      child: withTooltip(
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminSpacing.xs,
            vertical: AdminSpacing.xxs / 2,
          ),
          child: Stack(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  onFocusChange: (value) => setState(() => _focused = value),
                  borderRadius: BorderRadius.circular(AdminRadii.control),
                  hoverColor: semantics.surfaceSecondary,
                  focusColor: Colors.transparent,
                  child: row,
                ),
              ),
              if (selected)
                Positioned(
                  left: 0,
                  top: AdminSpacing.xs,
                  bottom: AdminSpacing.xs,
                  child: Container(
                    width: AdminSidebar.indicatorWidth,
                    decoration: BoxDecoration(
                      color: semantics.accent,
                      borderRadius: BorderRadius.circular(
                        AdminSidebar.indicatorWidth,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
