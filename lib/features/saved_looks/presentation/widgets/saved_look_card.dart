import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/saved_look.dart';

class SavedLookCard extends StatelessWidget {
  const SavedLookCard({
    required this.look,
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
    super.key,
  });

  final SavedLook look;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  look.preview.generatedImageUrl,
                  fit: BoxFit.cover,
                  frameBuilder: (context, child, frame, synchronouslyLoaded) =>
                      synchronouslyLoaded || frame != null
                      ? child
                      : const ColoredBox(
                          color: AppColors.sand,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(
                        color: AppColors.sand,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
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
                      onPressed: onFavorite,
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
                        look.style.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _dateLabel(look.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove saved look',
                  onPressed: onRemove,
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}
