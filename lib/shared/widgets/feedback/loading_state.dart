import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({
    super.key,
    this.label = 'Creating your look…',
    this.supportingText,
    this.progress,
  });

  final String label;
  final String? supportingText;
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
        CircularProgressIndicator(value: progress, strokeWidth: 2.5),
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
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    ),
  );
}
