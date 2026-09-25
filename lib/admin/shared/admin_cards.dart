import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';
import '../theme/admin_typography.dart';

/// The canonical bordered surface for Web Admin content.
///
/// It deliberately owns presentation only: callers provide the content and
/// retain all data, navigation, and action behavior.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AdminSpacing.ml),
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surface,
        border: Border.all(
          color: borderColor ?? colors.border,
          width: AdminBorders.hairline,
        ),
        borderRadius: BorderRadius.circular(AdminRadii.card),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// A compact, consistently typed operational statistic.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    this.metadata,
    this.icon,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? metadata;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = AdminSemanticColors.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220),
      child: Semantics(
        label: '$label: $value${metadata == null ? '' : ', $metadata'}',
        child: ExcludeSemantics(
          child: AdminCard(
            borderColor: emphasized ? colors.warning : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: AdminIconSizes.md),
                      const SizedBox(width: AdminSpacing.xs),
                    ],
                    Expanded(
                      child: Text(label, style: AdminTypography.cardTitle),
                    ),
                  ],
                ),
                const SizedBox(height: AdminSpacing.xs),
                Text(
                  value,
                  style: AdminTypography.metricValue.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (metadata != null) ...[
                  const SizedBox(height: AdminSpacing.xxs),
                  Text(metadata!, style: AdminTypography.metadata),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A chart surface with one consistent title, description, plot and footer
/// hierarchy. The chart itself remains owned by the feature that supplies it.
class AdminChartCard extends StatelessWidget {
  const AdminChartCard({
    super.key,
    required this.title,
    required this.description,
    required this.child,
    this.trailing,
    this.footer,
  });

  final String title;
  final String description;
  final Widget child;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AdminSpacing.xxs),
                    Text(description, style: AdminTypography.metadata),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: AdminSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AdminSpacing.ml),
          child,
          if (footer != null) ...[
            const SizedBox(height: AdminSpacing.sm),
            footer!,
          ],
        ],
      ),
    );
  }
}
