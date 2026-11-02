import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_tokens.dart';

/// The Saturation and Lightness controls.
///
/// There is deliberately no hue control: the base swatch sets the hue, and the
/// adjuster only makes that color softer, more vivid, lighter, or darker.
class CustomPaletteColorAdjuster extends StatelessWidget {
  const CustomPaletteColorAdjuster({
    required this.saturation,
    required this.lightness,
    required this.saturationEnabled,
    required this.canReset,
    required this.onSaturationChanged,
    required this.onLightnessChanged,
    required this.onReset,
    super.key,
  });

  final int saturation;
  final int lightness;

  /// False for an achromatic base such as Black, which has no hue to saturate.
  final bool saturationEnabled;
  final bool canReset;
  final ValueChanged<int> onSaturationChanged;
  final ValueChanged<int> onLightnessChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _PercentSlider(
        label: 'Saturation',
        lowLabel: 'Softer',
        highLabel: 'More vivid',
        value: saturation,
        onChanged: saturationEnabled ? onSaturationChanged : null,
      ),
      if (!saturationEnabled)
        Text(
          'This color has no saturation to adjust.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted(context)),
        ),
      const SizedBox(height: AppSpacing.xs),
      _PercentSlider(
        label: 'Lightness',
        lowLabel: 'Darker',
        highLabel: 'Lighter',
        value: lightness,
        onChanged: onLightnessChanged,
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TertiaryButton(
          label: 'Reset',
          onPressed: canReset ? onReset : null,
        ),
      ),
    ],
  );
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({
    required this.label,
    required this.lowLabel,
    required this.highLabel,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String lowLabel;
  final String highLabel;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.bodySmall?.copyWith(
      color: AppColors.muted(context),
    );
    final onChanged = this.onChanged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: textTheme.labelLarge)),
            Text('$value%', style: textTheme.labelLarge),
          ],
        ),
        Slider(
          value: value.toDouble(),
          max: 100,
          divisions: 100,
          semanticFormatterCallback: (_) => '$label, $value percent',
          onChanged: onChanged == null
              ? null
              : (next) => onChanged(next.round()),
        ),
        Row(
          children: [
            Expanded(child: Text(lowLabel, style: muted)),
            Text(highLabel, style: muted),
          ],
        ),
      ],
    );
  }
}
