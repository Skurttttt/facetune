import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../domain/catalog/custom_palette_catalog.dart';

/// The base-color palette: one choice per swatch.
///
/// The selected swatch is marked by a check and a bolder name as well as its
/// ring, and each name is spoken, so the choice never rests on color alone.
class CustomPaletteSwatchGrid extends StatelessWidget {
  const CustomPaletteSwatchGrid({
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final CustomPaletteSwatch? selected;
  final ValueChanged<CustomPaletteSwatch> onSelected;

  static const _minTileWidth = 68.0;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = AppSpacing.xs;
      final minTile = MediaQuery.textScalerOf(context).scale(_minTileWidth);
      final columns = math.max(
        2,
        ((constraints.maxWidth + spacing) / (minTile + spacing)).floor(),
      );
      final tileWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final swatch in CustomPaletteCatalog.swatches)
            SizedBox(
              width: tileWidth,
              child: _SwatchTile(
                swatch: swatch,
                selected: swatch.hex == selected?.hex,
                onTap: () => onSelected(swatch),
              ),
            ),
        ],
      );
    },
  );
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  final CustomPaletteSwatch swatch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = swatch.color.toColor();
    final labelStyle = Theme.of(context).textTheme.labelMedium;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: swatch.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? AppColors.rose
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: selected ? 2.5 : 1,
                  ),
                ),
                child: selected
                    ? Icon(
                        Icons.check_rounded,
                        size: AppIconSizes.sm,
                        color: AppColors.onAccent(color),
                      )
                    : null,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                swatch.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: selected
                    ? labelStyle?.copyWith(fontWeight: FontWeight.w700)
                    : labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
