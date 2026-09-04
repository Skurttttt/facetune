import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';

/// The owned products this look was built from, as a colour strip.
///
/// The kit-mode counterpart of Standard's recommended palette, and deliberately
/// the same shape: same swatch diameter, same caption treatment, same
/// horizontal rhythm, same scaling behaviour under large text. A user moving
/// between the two modes should recognise the row, not re-learn it.
///
/// What differs is the authority behind it. Standard reads shades an AI
/// proposed; this reads [KitProductSnapshot]s — the immutable record of what
/// the user owned at the moment the look was validated. Live inventory is never
/// consulted, so editing or deleting a product later cannot rewrite a result
/// that already happened.
class KitProductPalette extends StatelessWidget {
  const KitProductPalette({required this.recommendation, super.key});

  final KitMakeupRecommendation recommendation;

  /// Matches `RecommendedPalette`, so the two strips are the same object to the
  /// eye even though nothing is shared between their data sources.
  static const double _swatchDiameter = 58;

  @override
  Widget build(BuildContext context) {
    final snapshots = recommendation.productSnapshots;
    final captionHeight =
        MediaQuery.textScalerOf(context).scale(11) * 2 * 1.45 + AppSpacing.xs;
    return SizedBox(
      height: _swatchDiameter + captionHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: snapshots.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final snapshot = snapshots[index];
          // The registered product's own name where it has one, and its
          // category where it does not. Nothing is invented to fill the slot.
          final title = snapshot.productName ?? _label(snapshot.category);
          final shade = snapshot.colorLabel ?? snapshot.colorHex;
          return Semantics(
            container: true,
            excludeSemantics: true,
            // Swatch and caption read as one node, as they do in Standard.
            label: '$title, $shade, color ${snapshot.colorHex}',
            child: SizedBox(
              width: 84,
              child: Column(
                children: [
                  AppColorSwatch(
                    color: _swatchColour(snapshot.colorHex),
                    size: _swatchDiameter,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// The registered hex, or the swatch's neutral placeholder when it cannot be
  /// parsed. Never a guessed colour: an unreadable value is missing data.
  static Color? _swatchColour(String hex) {
    final parsed = int.tryParse(hex.replaceFirst('#', ''), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }

  static String _label(String value) {
    final words = value.replaceAll('_', ' ');
    return words.isEmpty
        ? words
        : '${words[0].toUpperCase()}${words.substring(1)}';
  }
}
