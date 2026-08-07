import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../surfaces/app_card.dart';

class StatusState extends StatelessWidget {
  const StatusState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.auto_awesome_rounded,
    this.actionLabel,
    this.onAction,
  });
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.petal,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.rose, size: AppIconSizes.lg),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: AppSpacing.md),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
