import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

class ResultActions extends StatelessWidget {
  const ResultActions({
    required this.isSaved,
    required this.isFavorite,
    required this.isSharing,
    required this.onSave,
    required this.onFavorite,
    required this.onShare,
    required this.onGenerateAnother,
    required this.onReturnHome,
    super.key,
  });

  final bool isSaved;
  final bool isFavorite;
  final bool isSharing;
  final VoidCallback onSave;
  final VoidCallback onFavorite;
  final VoidCallback onShare;
  final VoidCallback onGenerateAnother;
  final VoidCallback onReturnHome;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PrimaryButton(
        label: isSaved ? 'Saved for this session' : 'Save look',
        icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
        onPressed: onSave,
      ),
      const SizedBox(height: AppSpacing.sm),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onFavorite,
              icon: Icon(
                isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              label: Text(isFavorite ? 'Favorited' : 'Favorite'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isSharing ? null : onShare,
              icon: isSharing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              label: Text(isSharing ? 'Preparing' : 'Share'),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      SecondaryButton(
        label: 'Generate another variation',
        icon: Icons.refresh_rounded,
        onPressed: onGenerateAnother,
      ),
      const SizedBox(height: AppSpacing.sm),
      TextButton.icon(
        onPressed: onReturnHome,
        icon: const Icon(Icons.home_outlined),
        label: const Text('Return home'),
      ),
    ],
  );
}
