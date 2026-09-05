import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../feedback/app_progress.dart';

/// The four lines a saved look says about itself, under its picture.
///
/// The same four the History row already says, in the same order, at the same
/// weights, in the same words: title, then which authority produced the look,
/// then the one supporting fact that authority can state, then when. Saved
/// Looks previously said two of them — a style name and an ISO date — which
/// made the same record read as two unrelated things depending on which screen
/// you were standing on.
///
/// Presentation only, and it holds no opinion about what a look *is*. Every
/// string is handed to it by the card for that authority, so this cannot invent
/// a fact, and it cannot fill one mode's line from the other's.
class LookCardMetadata extends StatelessWidget {
  const LookCardMetadata({
    required this.title,
    required this.modeLabel,
    required this.secondaryMetadata,
    required this.savedAt,
    required this.action,
    super.key,
    this.isFavorite = false,
  });

  /// The strongest line: the look's own name.
  final String title;

  /// Which authority produced this look, said plainly — "Recommendation" or
  /// "My Makeup Kit". The words History already uses.
  final String modeLabel;

  /// The one supporting fact this look's own authority can state about it.
  final String secondaryMetadata;

  /// When the look was saved. Formatted here rather than by the caller, so two
  /// cards cannot drift into two date formats the way this screen and History
  /// once did.
  final DateTime savedAt;

  /// The card's single secondary control. One per card, by design.
  final Widget action;

  /// Whether the look is a favourite.
  ///
  /// Shown the way History shows it — a small mark beside the title, not a
  /// badge over the photograph. It is an indicator and not a control; the
  /// toggle lives in [action] with the card's other secondary actions.
  final bool isFavorite;

  /// `Sep 5, 2026`, from the platform's own localized short-date format.
  ///
  /// Saved Looks is a library rather than an activity log, so it states the day
  /// and not the minute. Public so a test can assert the rendered line without
  /// writing a second implementation of it to compare against.
  static String formatSavedDate(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatShortDate(value.toLocal());

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = AppColors.muted(context);
    return Padding(
      // Tighter at the trailing edge because the action's own touch target
      // already carries its inset; anything more pushed the text off-centre.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        // Two lines here where History allows one: this tile is
                        // roughly half a phone wide, and a name that fits a
                        // full-width row does not fit this one.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                    ),
                    if (isFavorite) ...[
                      const SizedBox(width: AppSpacing.xxs),
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xxs),
                        child: Semantics(
                          label: 'Favorited',
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 14,
                            color: AppColors.rose,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  modeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  // The same restrained accent History gives the mode, resolved
                  // through `onTint` so it clears contrast on the dark card
                  // rather than staying tuned for the light one.
                  style: text.labelSmall?.copyWith(
                    color: AppColors.onTint(context, AppColors.rose),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  secondaryMetadata,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: muted),
                ),
                Text(
                  formatSavedDate(context, savedAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: muted),
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

/// One entry in a look card's overflow menu.
class LookCardAction {
  const LookCardAction({
    required this.label,
    required this.icon,
    required this.onSelected,
  });

  /// What the user reads, and what a screen reader announces.
  final String label;

  final IconData icon;

  /// Runs the card's own existing handler. This type carries no behaviour of
  /// its own — it is a label and a callback the card already had.
  final VoidCallback onSelected;
}

/// A look card's single secondary control.
///
/// One control per tile, deliberately. Saved Looks used to put a favourite
/// button over the photograph *and* a second button in the footer, so a tile
/// whose primary gesture is "open this look" carried two competing targets. The
/// actions did not go away; they moved behind this one.
///
/// While the look is being mutated the menu is replaced by a progress
/// indicator, which is the same treatment — and the same size — the footer
/// control already used.
class LookCardActions extends StatelessWidget {
  const LookCardActions({
    required this.items,
    required this.isMutating,
    required this.tooltip,
    super.key,
  });

  final List<LookCardAction> items;
  final bool isMutating;

  /// Named for the card it belongs to, so two menus on one screen are
  /// distinguishable to a screen reader.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    if (isMutating) {
      return const SizedBox.square(
        dimension: kMinInteractiveDimension,
        child: Center(child: AppProgress(size: AppProgressSize.small)),
      );
    }
    return PopupMenuButton<LookCardAction>(
      tooltip: tooltip,
      icon: const Icon(Icons.more_horiz_rounded),
      onSelected: (action) => action.onSelected(),
      itemBuilder: (context) => <PopupMenuEntry<LookCardAction>>[
        for (final item in items)
          PopupMenuItem<LookCardAction>(
            value: item,
            child: Row(
              children: [
                Icon(item.icon, size: AppIconSizes.md),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(item.label)),
              ],
            ),
          ),
      ],
    );
  }
}
