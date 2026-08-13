import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/kit_look_result.dart';

class KitSavedLookCard extends StatelessWidget {
  const KitSavedLookCard({
    required this.look,
    required this.isMutating,
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
    super.key,
  });

  final KitSavedLook look;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isMutating ? null : onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PrivateImage(url: look.result.preview.generatedImageUrl),
                const Positioned(
                  left: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: _KitBadge(),
                ),
                Positioned(
                  right: AppSpacing.xs,
                  top: AppSpacing.xs,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: .92),
                    child: IconButton(
                      tooltip: look.isFavorite
                          ? 'Remove favorite'
                          : 'Add favorite',
                      onPressed: isMutating ? null : onFavorite,
                      icon: Icon(
                        look.isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: AppColors.rose,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        look.result.style.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${look.result.recommendation.selections.length} owned products',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove saved kit look',
                  onPressed: isMutating ? null : onRemove,
                  icon: isMutating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _KitBadge extends StatelessWidget {
  const _KitBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.xs,
      vertical: AppSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: AppColors.petal,
      borderRadius: BorderRadius.circular(AppRadii.pill),
    ),
    child: const Text(
      'MY KIT',
      style: TextStyle(
        color: AppColors.roseDark,
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
    ),
  );
}
