import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

class ResultActions extends StatelessWidget {
  const ResultActions({
    required this.isSaved,
    required this.isFavorite,
    required this.isSharing,
    required this.isMutating,
    required this.onSave,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onReturnHome,
    super.key,
    this.includeSave = true,
  });

  final bool isSaved;
  final bool isFavorite;
  final bool isSharing;
  final bool isMutating;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onReturnHome;
  final bool includeSave;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (includeSave) ...[
        PrimaryButton(
          label: isSaved ? 'Saved' : 'Save look',
          icon: isSaved
              ? Icons.bookmark_rounded
              : Icons.bookmark_border_rounded,
          onPressed: isMutating ? null : onSave,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
      LayoutBuilder(
        builder: (context, constraints) {
          final favorite = OutlinedButton.icon(
            onPressed: isMutating ? null : onFavorite,
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
            label: Text(isFavorite ? 'Favorited' : 'Favorite'),
          );
          final share = OutlinedButton.icon(
            onPressed: isSharing ? null : onShare,
            // The shared spinner, so this matches every other in-flight
            // control in the app instead of being a fourth hand-rolled one.
            icon: isSharing
                ? const ButtonProgress()
                : const Icon(Icons.share_outlined),
            label: Text(isSharing ? 'Preparing' : 'Share'),
          );
          final stackActions =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(14) > 19;
          if (stackActions) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                favorite,
                const SizedBox(height: AppSpacing.xs),
                share,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: favorite),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: share),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        label: 'Generate another variation',
        icon: Icons.refresh_rounded,
        onPressed: onGenerateAnother,
      ),
      const SizedBox(height: AppSpacing.xs),
      TertiaryButton(
        label: 'Return home',
        icon: Icons.home_outlined,
        expand: true,
        onPressed: onReturnHome,
      ),
    ],
  );
}
