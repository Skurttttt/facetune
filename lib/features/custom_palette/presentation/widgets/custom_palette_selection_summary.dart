import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../controllers/custom_palette_draft_state.dart';

/// One category's final choice: swatch, color name, HEX value and finish.
///
/// Every value is also text, so nothing here depends on seeing the color.
class CustomPaletteSelectionSummary extends StatelessWidget {
  const CustomPaletteSelectionSummary({
    required this.title,
    required this.selection,
    super.key,
    this.swatchSize = AppColorSwatch.defaultSize,
  });

  final String title;
  final CustomPaletteDraftSelection selection;
  final double swatchSize;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: AppColors.muted(context),
    );
    final color = selection.adjustedColor;
    final finish = selection.finish;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppColorSwatch(color: color?.toColor(), size: swatchSize),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  color == null
                      ? 'No color chosen'
                      : '${selection.colorName} (${color.value})',
                  style: muted,
                ),
                Text(
                  finish == null
                      ? 'No finish chosen'
                      : '${finish.label} finish',
                  style: muted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
