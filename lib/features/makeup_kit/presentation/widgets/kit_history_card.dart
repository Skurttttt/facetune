import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/kit_look_result.dart';

class KitHistoryCard extends StatelessWidget {
  const KitHistoryCard({
    required this.entry,
    required this.isMutating,
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final KitHistoryEntry entry;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final result = entry.result;
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: isMutating ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: SizedBox.square(
                  dimension: 92,
                  child: PrivateImage(url: result.preview.generatedImageUrl),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MY MAKEUP KIT',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.rose,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      result.style.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Variation ${result.preview.generationNumber} · ${result.recommendation.selections.length} owned products',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMutating)
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                IconButton(
                  tooltip: 'Delete history session',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
