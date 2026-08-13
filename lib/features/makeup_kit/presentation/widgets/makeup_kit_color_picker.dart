import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/value_objects/normalized_hex_color.dart';
import '../utils/makeup_kit_curated_shades.dart';
import '../utils/makeup_kit_display.dart';
import 'makeup_kit_color_swatch.dart';

/// The visual color picker for registering a product's shade (MK-5).
///
/// Users are never required to understand HEX: a tap on a curated shade is
/// the primary path. The HSV sliders allow precise adjustment, and the
/// advanced HEX field is an optional secondary entry point — an invalid
/// value there is rejected inline and never reaches [onColorSelected].
class MakeupKitColorPicker extends StatefulWidget {
  const MakeupKitColorPicker({
    required this.category,
    required this.selectedColor,
    required this.selectedLabel,
    required this.onColorSelected,
    super.key,
  });

  final MakeupKitCategory category;
  final NormalizedHexColor selectedColor;

  /// The curated shade name matching [selectedColor], or `null` when the
  /// current color was fine-tuned (slider or HEX entry) and no longer
  /// matches a curated label.
  final String? selectedLabel;

  /// Called with the new color and, when it came from a curated tap, its
  /// label (`null` for slider/HEX-entered colors).
  final void Function(NormalizedHexColor color, String? label) onColorSelected;

  @override
  State<MakeupKitColorPicker> createState() => _MakeupKitColorPickerState();
}

class _MakeupKitColorPickerState extends State<MakeupKitColorPicker> {
  late HSVColor _hsv = HSVColor.fromColor(widget.selectedColor.toColor());
  late final _hexController = TextEditingController(
    text: widget.selectedColor.value,
  );
  String? _hexError;

  @override
  void didUpdateWidget(covariant MakeupKitColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedColor == widget.selectedColor) return;
    _hsv = HSVColor.fromColor(widget.selectedColor.toColor());
    _hexController.text = widget.selectedColor.value;
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shades = MakeupKitCuratedShades.forCategory(widget.category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Color / Shade', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final shade in shades)
              _ShadeChoice(
                shade: shade,
                selected: shade.label == widget.selectedLabel,
                onTap: () => _selectShade(shade),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            MakeupKitColorSwatch(color: widget.selectedColor, size: 40),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Selected: ${widget.selectedLabel ?? widget.selectedColor.value}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Customize',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: AppColors.muted(context)),
        ),
        Slider(
          value: _hsv.hue,
          min: 0,
          max: 360,
          label: 'Hue',
          onChanged: (value) => _updateHsv(_hsv.withHue(value)),
        ),
        Slider(
          value: _hsv.saturation,
          label: 'Saturation',
          onChanged: (value) => _updateHsv(_hsv.withSaturation(value)),
        ),
        Slider(
          value: _hsv.value,
          label: 'Brightness',
          onChanged: (value) => _updateHsv(_hsv.withValue(value)),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _hexController,
          decoration: InputDecoration(
            labelText: 'Advanced: HEX reference',
            prefixText: '#',
            errorText: _hexError,
            helperText: 'Optional — most people can skip this.',
          ),
          textCapitalization: TextCapitalization.characters,
          onSubmitted: _submitHex,
          onEditingComplete: () => _submitHex(_hexController.text),
        ),
      ],
    );
  }

  void _selectShade(CuratedShade shade) {
    setState(() {
      _hsv = HSVColor.fromColor(shade.color.toColor());
      _hexController.text = shade.color.value;
      _hexError = null;
    });
    widget.onColorSelected(shade.color, shade.label);
  }

  void _updateHsv(HSVColor hsv) {
    final color = _hsvToHex(hsv);
    setState(() {
      _hsv = hsv;
      _hexController.text = color.value;
      _hexError = null;
    });
    widget.onColorSelected(color, null);
  }

  void _submitHex(String value) {
    final withoutHash = value.trim();
    final parsed = NormalizedHexColor.tryParse(withoutHash);
    if (parsed == null) {
      setState(() => _hexError = 'Enter a valid 6-digit HEX color.');
      return;
    }
    setState(() {
      _hexError = null;
      _hsv = HSVColor.fromColor(parsed.toColor());
    });
    widget.onColorSelected(parsed, null);
  }

  static NormalizedHexColor _hsvToHex(HSVColor hsv) {
    final rgb = hsv.toColor().toARGB32() & 0xFFFFFF;
    return NormalizedHexColor.parse(
      '#${rgb.toRadixString(16).padLeft(6, '0')}',
    );
  }
}

class _ShadeChoice extends StatelessWidget {
  const _ShadeChoice({
    required this.shade,
    required this.selected,
    required this.onTap,
  });

  final CuratedShade shade;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: '${shade.label} shade',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: shade.color.toColor(),
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
                      color: AppColors.onAccent(shade.color.toColor()),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 56,
              child: Text(
                shade.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
