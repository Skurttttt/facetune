import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/kit_look_result.dart';

/// One saved My Makeup Kit look, as a tile in the library.
///
/// The same tile the Makeup Recommendation card draws, with this mode's own
/// facts in it. Two things used to sit over the photograph — a pink "MY KIT"
/// pill and a white circle carrying a heart — so a kit tile read as a labelled
/// variant of the product rather than the same library holding a different kind
/// of look. The mode is now a line of the footer, in the words History uses,
/// and the favourite it toggled moved into the tile's one secondary control.
///
/// My Makeup Kit authority only. The owned-product count is read from the
/// immutable recommendation this look was validated against; nothing here
/// consults a Standard recommendation, and nothing falls back to one.
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

  /// The app's existing owned-product count authority — the same `selections`
  /// field the kit result screen and the History row already read.
  ///
  /// Pluralised, which the old footer was not: it printed "1 owned products"
  /// for a single-product look. The wording matches History's exactly.
  static String ownedProductLabel(KitSavedLook look) {
    final count = look.result.recommendation.selections.length;
    return '$count owned product${count == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isMutating ? null : onOpen,
      child: Column(
        // Stretch, not start — the same cross-axis fix the Makeup
        // Recommendation tile needed, for the same reason: `Expanded` governs
        // only the main axis, so on a loose cross axis a portrait preview sized
        // itself narrower than the tile and left a strip down the right edge.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nothing over the photograph any more — no badge, no chip, no
          // second control.
          Expanded(
            child: PrivateImage(
              url: look.result.preview.generatedImageUrl,
              // The feed treatment, identical to the Makeup Recommendation
              // tile: a still ground instead of a spinner per loading tile, and
              // one short fade instead of a hard swap.
              placeholder: const ImageSkeleton(),
              fadeIn: true,
            ),
          ),
          LookCardMetadata(
            title: look.result.style.name,
            modeLabel: 'My Makeup Kit',
            secondaryMetadata: ownedProductLabel(look),
            savedAt: look.createdAt,
            isFavorite: look.isFavorite,
            action: LookCardActions(
              isMutating: isMutating,
              tooltip: 'Saved kit look options',
              items: <LookCardAction>[
                LookCardAction(
                  label: look.isFavorite ? 'Remove favorite' : 'Add favorite',
                  icon: look.isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  onSelected: onFavorite,
                ),
                LookCardAction(
                  label: 'Remove from saved',
                  icon: Icons.bookmark_remove_outlined,
                  onSelected: onRemove,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
