import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../utils/tutorial_labels.dart';
import '../utils/tutorial_redraw_reason.dart';

/// Confirms an explicit redraw before it costs a generation.
///
/// Before this existed, "Draw this step again" was a single tap that
/// immediately spent a paid AI call — no confirmation, no warning, and easy to
/// hit by accident on a scrolling page. The sheet turns that into a deliberate
/// two-step action, which is the actual user-facing value of V4-QA-7.
///
/// Returns `true` only when the user explicitly confirms. Choosing a reason
/// never starts generation on its own; dismissing or cancelling costs nothing.
/// The caller keeps every existing guard — quota, the server's five-attempt
/// ceiling, and in-flight coalescing — so this adds a gate rather than
/// replacing one.
class TutorialRedrawSheet extends StatefulWidget {
  const TutorialRedrawSheet({required this.attemptsUsed, super.key});

  /// How many times this step has already been drawn, from the persisted step.
  ///
  /// Shown so the user knows redraws accumulate. Deliberately not presented as
  /// "n of 5": the ceiling is a server constant with no Dart mirror, and a
  /// number that silently drifted from the server would be worse than no
  /// number at all.
  final int attemptsUsed;

  /// Shows the sheet and resolves to whether the user confirmed.
  static Future<bool> confirm(
    BuildContext context, {
    required int attemptsUsed,
  }) async =>
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => TutorialRedrawSheet(attemptsUsed: attemptsUsed),
      ) ??
      false;

  @override
  State<TutorialRedrawSheet> createState() => _TutorialRedrawSheetState();
}

class _TutorialRedrawSheetState extends State<TutorialRedrawSheet> {
  TutorialRedrawReason? _reason;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(TutorialLabels.redraw, style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              TutorialLabels.redrawExplanation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            if (widget.attemptsUsed > 0) ...[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                TutorialLabels.redrawAttemptsUsed(widget.attemptsUsed),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted(context),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              TutorialLabels.redrawReasonPrompt,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xxs),
            for (final reason in TutorialRedrawReason.values)
              _ReasonTile(
                label: TutorialLabels.redrawReason(reason),
                selected: _reason == reason,
                // Tapping the selected reason clears it, so a mis-tap is
                // recoverable without closing the sheet.
                onTap: () =>
                    setState(() => _reason = _reason == reason ? null : reason),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              TutorialLabels.redrawReasonPrivacy,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            // The confirm is always a separate, explicit tap. Selecting a
            // reason must never start generation by itself.
            PrimaryButton(
              label: TutorialLabels.redrawConfirm,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: AppSpacing.xs),
            SecondaryButton(
              label: TutorialLabels.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

/// One selectable reason.
///
/// A plain tile rather than a radio: the selection is optional and clearable,
/// which a radio group cannot express, and this keeps the sheet on the existing
/// design system without introducing a new control.
class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label),
        trailing: selected
            ? Icon(Icons.check_rounded, color: scheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
