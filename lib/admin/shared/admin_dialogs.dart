import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_tokens.dart';

/// Canonical modal confirmation surface for privileged Web Admin workflows.
///
/// This widget owns presentation and keyboard order only. The calling page
/// retains validation, acknowledgement, frozen intent, controller, payload,
/// retry, and server-authority behavior.
class AdminConfirmationDialog extends StatelessWidget {
  const AdminConfirmationDialog({
    super.key,
    required this.title,
    required this.description,
    required this.content,
    required this.confirmLabel,
    required this.confirmButtonKey,
    required this.cancelButtonKey,
    required this.onConfirm,
    required this.onCancel,
    this.confirmIcon = Icons.check,
    this.cancelLabel = 'Cancel',
    this.destructive = false,
  });

  final String title;
  final String description;
  final Widget content;
  final String confirmLabel;
  final Key confirmButtonKey;
  final Key cancelButtonKey;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final IconData confirmIcon;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AdminSemanticColors.of(context);
    final viewport = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AdminSpacing.lg),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: destructive ? theme.colorScheme.error : colors.border,
          width: AdminBorders.hairline,
        ),
        borderRadius: BorderRadius.circular(AdminRadii.dialog),
      ),
      child: ConstrainedBox(
        key: const Key('admin-confirmation-dialog-frame'),
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: viewport.height - (AdminSpacing.lg * 2),
        ),
        child: SingleChildScrollView(
          child: Padding(
            key: const Key('admin-confirmation-dialog-padding'),
            padding: const EdgeInsets.all(AdminSpacing.lg),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(title, style: theme.textTheme.titleLarge),
                  ),
                  const SizedBox(height: AdminSpacing.xs),
                  Text(description, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AdminSpacing.lg),
                  content,
                  const SizedBox(height: AdminSpacing.lg),
                  Wrap(
                    key: const Key('admin-confirmation-dialog-actions'),
                    spacing: AdminSpacing.xs,
                    runSpacing: AdminSpacing.xs,
                    alignment: WrapAlignment.end,
                    children: [
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: TextButton(
                          key: cancelButtonKey,
                          autofocus: true,
                          onPressed: onCancel,
                          child: Text(cancelLabel),
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(2),
                        child: FilledButton.icon(
                          key: confirmButtonKey,
                          style: destructive
                              ? FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                  foregroundColor: theme.colorScheme.onError,
                                )
                              : null,
                          onPressed: onConfirm,
                          icon: Icon(confirmIcon, size: AdminIconSizes.md),
                          label: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Consistent label/value hierarchy for frozen confirmation previews.
class AdminDialogDetailRows extends StatelessWidget {
  const AdminDialogDetailRows({super.key, required this.rows});

  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AdminSpacing.xxs),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final value = SelectableText(
                  row.$2,
                  style: theme.textTheme.bodyMedium,
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(row.$1, style: theme.textTheme.labelMedium),
                      const SizedBox(height: AdminSpacing.xxs),
                      value,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Text(row.$1, style: theme.textTheme.labelMedium),
                    ),
                    Expanded(child: value),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
