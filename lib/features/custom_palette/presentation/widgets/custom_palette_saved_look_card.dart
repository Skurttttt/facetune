import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../domain/entities/custom_palette_look.dart';

/// One saved Custom Color Palette look, as a tile in the library.
///
/// The same tile the other modes draw, with this mode's own facts in it. The color
/// count comes from the look's frozen palette.
class CustomPaletteSavedLookCard extends StatelessWidget {
  const CustomPaletteSavedLookCard({
    required this.look,
    required this.isMutating,
    required this.onOpen,
    required this.onFavorite,
    required this.onRemove,
    super.key,
  });

  final CustomPaletteSavedLook look;
  final bool isMutating;
  final VoidCallback onOpen;
  final VoidCallback onFavorite;
  final VoidCallback onRemove;

  static String colorCountLabel(int count) =>
      '$count color${count == 1 ? '' : 's'}';

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: isMutating ? null : onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PrivateImage(
              url: look.result.preview.generatedImageUrl,
              placeholder: const ImageSkeleton(),
              fadeIn: true,
            ),
          ),
          LookCardMetadata(
            title: look.result.style.name,
            modeLabel: 'Custom Color Palette',
            secondaryMetadata: colorCountLabel(
              look.result.recommendation.palette.length,
            ),
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
