import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/history_entry.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({
    required this.entry,
    required this.isMutating,
    required this.onOpen,
    required this.onFavorite,
    required this.onRegenerate,
    required this.onDelete,
    super.key,
  });

  final HistoryEntry entry;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback? onFavorite;
  final VoidCallback? onRegenerate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isMutating ? null : onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: SizedBox(
                width: 104,
                height: 132,
                child: PrivateImage(url: entry.thumbnailUrl),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: SizedBox(
                height: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.style?.name ?? 'Beauty analysis',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        _StatusBadge(status: entry.status),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _details(entry),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.taupe),
                    ),
                    const Spacer(),
                    if (isMutating)
                      const Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onFavorite != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: entry.isFavorite
                                  ? 'Remove favorite'
                                  : 'Add favorite',
                              onPressed: onFavorite,
                              icon: Icon(
                                entry.isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: AppColors.rose,
                              ),
                            ),
                          if (onRegenerate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: entry.preview == null
                                  ? 'Generate preview'
                                  : 'Generate another variation',
                              onPressed: onRegenerate,
                              icon: const Icon(Icons.auto_awesome_rounded),
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Delete history session',
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static String _details(HistoryEntry entry) {
    final attributes = entry.analysis.attributes;
    final variation = entry.preview == null
        ? ''
        : 'Variation ${entry.preview!.generationNumber} · ';
    return '$variation${_label(attributes.faceShape.name)} face · '
        '${_label(attributes.undertone.name)} undertone\n'
        '${_dateLabel(entry.latestActivityAt)}';
  }

  static String _dateLabel(DateTime value) {
    final date = value.toLocal();
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} · '
        '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }

  static String _label(String value) {
    final spaced = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final HistoryCompletionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      HistoryCompletionStatus.analysisReady => ('Analysis', AppColors.taupe),
      HistoryCompletionStatus.recommendationReady => (
        'Plan ready',
        AppColors.rose,
      ),
      HistoryCompletionStatus.complete => ('Complete', AppColors.success),
    };
    return Semantics(
      label: 'Status: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
