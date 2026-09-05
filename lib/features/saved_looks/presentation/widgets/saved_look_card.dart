import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/saved_look.dart';

/// One saved Makeup Recommendation, as a tile in the library.
///
/// The photograph is the card, and it is now the only thing on the card face.
/// A white circle carrying a pink heart used to sit in its corner, which said
/// "this is saved" on a screen whose entire purpose is saved looks — and put a
/// second tap target on a tile whose primary gesture is opening it.
///
/// The favourite it toggled has not been dropped: it moved into the one
/// secondary control the tile keeps. Whether a look *is* a favourite is still
/// visible, marked beside the title the way History marks it.
///
/// Standard authority only. Every line comes from this saved look's own
/// recommendation and style; nothing is read from, or filled in from, My
/// Makeup Kit.
class SavedLookCard extends StatelessWidget {
  const SavedLookCard({
    required this.look,
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
    required this.isMutating,
    super.key,
  });

  /// The word History uses for a record that has a generated preview.
  ///
  /// Constant here because it is true here: a saved look is saved *from* a
  /// preview, so `SavedLook.preview` is non-nullable and no saved record can be
  /// analysis-only or plan-only. Printing "Plan ready" would describe a state
  /// this collection cannot contain.
  static const String completionLabel = 'Complete';

  final SavedLook look;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;
  final bool isMutating;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isMutating ? null : onOpen,
      child: Column(
        // Stretch, not start. `Expanded` only makes the image fill the column's
        // main axis; on a loose cross axis the image sized itself to its own
        // aspect ratio inside the tile's fixed height, and a portrait preview is
        // narrower than the tile — which is where the dark strip down the right
        // edge came from. A tight cross-axis constraint hands the image the full
        // tile width and lets `BoxFit.cover` crop, which is what it was always
        // meant to do. The footer already filled the width, so only the image
        // moves.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Nothing over the photograph any more — no badge, no chip, no
          // second control.
          Expanded(
            child: PrivateImage(
              url: look.preview.generatedImageUrl,
              // A grid of these, not one hero image. The default placeholder is
              // a spinner, and a screen of spinning indicators is both a stalled
              // look and a ticker per tile repainting every frame while the user
              // scrolls into fresh rows. The same still ground and one-shot fade
              // History uses for its feed.
              placeholder: const ImageSkeleton(),
              fadeIn: true,
            ),
          ),
          LookCardMetadata(
            title: look.style.name,
            modeLabel: 'Recommendation',
            secondaryMetadata: completionLabel,
            savedAt: look.createdAt,
            isFavorite: look.isFavorite,
            action: LookCardActions(
              isMutating: isMutating,
              tooltip: 'Saved look options',
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
