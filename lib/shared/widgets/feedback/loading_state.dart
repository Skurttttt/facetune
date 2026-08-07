import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.label = 'Creating your lookÃ¢â‚¬Â¦'});
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const CircularProgressIndicator(strokeWidth: 2.5),
      const SizedBox(height: AppSpacing.md),
      Text(label, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}
