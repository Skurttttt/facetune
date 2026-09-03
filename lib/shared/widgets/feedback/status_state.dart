import 'package:flutter/material.dart';

import '../../../theme/app_semantics.dart';
import '../../../theme/app_tokens.dart';
import '../surfaces/app_card.dart';

/// A whole-region state: nothing here, something failed, something worked, or
/// something you should know before continuing.
///
/// One component with four intents rather than four near-identical widgets. The
/// intents are named constructors, so a call site declares what it means —
/// `StatusState.error(...)` — and the tone, the default icon and the
/// announcement behaviour follow from that automatically.
///
/// The UI-P0 audit found this widget at **38 call sites across 15 files** doing
/// four different jobs with one appearance: empty state, error state, "not
/// ready" state, and a plain informational card. Its icon badge was
/// unconditionally pink whether it was announcing success or failure.
///
/// The default (unnamed) constructor is unchanged and still defaults to
/// [AppTone.info], so every existing call site renders as it did in the light
/// theme. Those call sites are migrated to the named constructors in the
/// feature phases, where there is enough context to say which one each is.
class StatusState extends StatelessWidget {
  /// The unchanged original. Prefer a named constructor in new code.
  const StatusState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.auto_awesome_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.liveRegion = false,
    this.tone = AppTone.info,
  });

  /// There is nothing to show yet, and that is not a problem.
  const StatusState.empty({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.liveRegion = false,
  }) : tone = AppTone.info;

  /// Something failed or is blocked.
  ///
  /// Announces itself by default: an error is almost always the result of
  /// something the user just did, and silence leaves them waiting for feedback
  /// that never comes.
  const StatusState.error({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.error_outline_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.liveRegion = true,
  }) : tone = AppTone.danger;

  /// Something the user did worked.
  const StatusState.success({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.check_circle_outline_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.liveRegion = false,
  }) : tone = AppTone.success;

  /// Context the user needs before continuing. Not an outcome.
  const StatusState.info({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.info_outline_rounded,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.liveRegion = false,
  }) : tone = AppTone.info;

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;
  final bool liveRegion;

  /// What this state means. Drives the icon badge only — see [build].
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    final role = tone.resolve(context);
    return Semantics(
      container: true,
      liveRegion: liveRegion,
      label: '$title. $message',
      child: AppCard(
        child: Column(
          children: [
            // The tone colours the badge, not the whole card. A card flooded
            // with red for every failed load would make ordinary, recoverable
            // problems read as alarms — and this widget is used for empty
            // states as often as for errors.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: role.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: role.border,
                  width: AppBorders.hairline,
                ),
              ),
              child: Icon(icon, color: role.accent, size: AppIconSizes.lg),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null || secondaryActionLabel != null) ...[
              const SizedBox(height: AppSpacing.md),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (actionLabel != null)
                    FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionLabel!),
                    ),
                  if (secondaryActionLabel != null)
                    TextButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionLabel!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
