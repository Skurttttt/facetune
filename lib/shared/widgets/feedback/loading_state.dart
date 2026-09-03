import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import 'app_progress.dart';

/// A region that is waiting, with an explanation of what for.
///
/// The label is required in practice — it defaults to something, but a spinner
/// with no words tells the user only that the app is not broken yet. Where the
/// wait is long and paid for, saying what is happening is most of the value.
class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.label = 'Creating your look…',
    this.supportingText,
    this.progress,
  });

  final String label;
  final String? supportingText;

  /// Real, measured completion between 0 and 1, or null for indeterminate.
  ///
  /// **Only pass a value the system actually knows.** Null is the honest answer
  /// for everything FaceTune currently waits on: a Gemini generation reports no
  /// progress, so any bar drawn for it would be an animation timed to a guess.
  /// Telling someone they are 70% through a wait that has not started counting
  /// is worse than telling them nothing, because they will plan around it.
  ///
  /// Legitimate uses are things like a multi-step upload where the step count
  /// is known.
  final double? progress;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: supportingText == null ? label : '$label. $supportingText',
    value: progress == null ? null : '${(progress! * 100).round()} percent',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (progress == null)
          const AppProgress(size: AppProgressSize.large)
        else
          SizedBox.square(
            dimension: AppProgressSize.large.dimension,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: AppProgressSize.large.stroke,
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (supportingText != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            supportingText!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
          ),
        ],
      ],
    ),
  );
}
