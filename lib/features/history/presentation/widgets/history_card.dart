import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../models/history_feed_item.dart';
import '../utils/look_metadata_presentation.dart';

/// Which action the overflow menu returned.
///
/// Presentation vocabulary only. Every one of these is handed straight back to
/// the callback the owning page already used before HIST-UI-3; this enum names
/// them, it does not decide what any of them do.
enum HistoryCardAction { view, favorite, regenerate, delete }

/// The one History card, drawn identically for both record types.
///
/// It is handed a [HistoryFeedItem] — the presentation adapter that already
/// reads each mode's own authority — plus the callbacks that mode's page
/// already owned. It reads no provider, holds no state, and never derives one
/// mode's metadata from the other's: [HistoryFeedItem.modeLabel] and
/// [HistoryFeedItem.metadataLabel] come from the adapter for that record.
///
/// Shared geometry is the point of the widget, so the thumbnail box, radii and
/// spacing are constants here rather than per-call parameters. A Standard row
/// and a My Kit row cannot drift apart without editing this file.
class HistoryCard extends StatelessWidget {
  const HistoryCard({
    required this.item,
    required this.isMutating,
    required this.onOpen,
    required this.onDelete,
    this.onFavorite,
    this.onRegenerate,
    this.regenerateLabel,
    this.now,
    super.key,
  });

  /// Thumbnail footprint, shared by both modes.
  ///
  /// 4:5 portrait: FaceTune selfies and previews are portrait or square, and a
  /// portrait box crops a square source far more gracefully than the reverse.
  static const thumbnailWidth = 88.0;
  static const thumbnailHeight = 110.0;

  final HistoryFeedItem item;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  /// Omitted where the record's own authority has no favorite action for it.
  final VoidCallback? onFavorite;

  /// Omitted where the record cannot be regenerated, or generation is running.
  final VoidCallback? onRegenerate;

  /// The wording [onRegenerate] already used, which differs by whether the
  /// record has a preview yet. Supplied by the caller because only that mode's
  /// authority knows which case a record is in.
  final String? regenerateLabel;

  /// Injected only so the year rule below is testable; defaults to now.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = AppColors.muted(context);
    // The same four lines Home reads, from the same adapter and the same
    // formatter. Neither screen can restate a record differently without
    // changing what both of them say.
    final metadata = lookMetadataOf(item, now: now);
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: isMutating ? null : onOpen,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: SizedBox(
                width: thumbnailWidth,
                height: thumbnailHeight,
                child: PrivateImage(
                  url: item.thumbnailUrl,
                  semanticLabel: '${item.styleName} preview',
                  // A feed of these, not one hero image: a still ground and a
                  // fade, rather than a spinner per row and a hard swap.
                  placeholder: const ImageSkeleton(),
                  fadeIn: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              // One announcement per card rather than four, so the row reads as
              // "Everyday, My Makeup Kit, 1 owned product, Sep 5 · 2:41 PM".
              child: MergeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            metadata.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium,
                          ),
                        ),
                        if (item.isFavorite) ...[
                          const SizedBox(width: AppSpacing.xxs),
                          Semantics(
                            label: 'Favorited',
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 14,
                              color: AppColors.rose,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      metadata.modeLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelSmall?.copyWith(
                        color: AppColors.onTint(context, AppColors.rose),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      metadata.secondaryMetadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                    Text(
                      metadata.formattedDateTime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: thumbnailHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isMutating)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.sm),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    _HistoryCardMenu(
                      item: item,
                      onOpen: onOpen,
                      onDelete: onDelete,
                      onFavorite: onFavorite,
                      onRegenerate: onRegenerate,
                      regenerateLabel: regenerateLabel,
                    ),
                  // The navigation affordance stays where it was: the card tap
                  // and this chevron are the same action, and neither is next
                  // to anything destructive.
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's single action surface.
///
/// Delete used to sit permanently on the card, one tap from the chevron. It
/// lives here now, last and in the danger role, behind the same confirmation
/// the caller always showed.
class _HistoryCardMenu extends StatelessWidget {
  const _HistoryCardMenu({
    required this.item,
    required this.onOpen,
    required this.onDelete,
    required this.onFavorite,
    required this.onRegenerate,
    required this.regenerateLabel,
  });

  final HistoryFeedItem item;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback? onFavorite;
  final VoidCallback? onRegenerate;
  final String? regenerateLabel;

  @override
  Widget build(BuildContext context) {
    final danger = AppTone.danger.resolve(context);
    return PopupMenuButton<HistoryCardAction>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'More actions',
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        HistoryCardAction.view => onOpen(),
        HistoryCardAction.favorite => onFavorite?.call(),
        HistoryCardAction.regenerate => onRegenerate?.call(),
        HistoryCardAction.delete => onDelete(),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: HistoryCardAction.view,
          child: _MenuRow(icon: Icons.visibility_outlined, label: 'View'),
        ),
        if (onFavorite != null)
          PopupMenuItem(
            value: HistoryCardAction.favorite,
            child: _MenuRow(
              icon: item.isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: item.isFavorite ? 'Remove favorite' : 'Favorite',
            ),
          ),
        if (onRegenerate != null)
          PopupMenuItem(
            value: HistoryCardAction.regenerate,
            child: _MenuRow(
              icon: Icons.auto_awesome_rounded,
              label: regenerateLabel ?? 'Generate another variation',
            ),
          ),
        PopupMenuItem(
          value: HistoryCardAction.delete,
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: danger.accent,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: color),
      const SizedBox(width: AppSpacing.sm),
      // Wraps rather than truncates: a menu is short enough to give a long
      // label a second line, and an elided action is an unreadable action.
      Expanded(
        child: Text(
          label,
          style: color == null ? null : TextStyle(color: color),
        ),
      ),
    ],
  );
}
