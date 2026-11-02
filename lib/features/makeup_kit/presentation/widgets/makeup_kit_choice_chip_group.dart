import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';

/// A wrapping row of single-select chips: the Finish, Depth and Undertone
/// pickers of the product form.
///
/// Presentation only. It draws [options] with [labelOf], marks [selected],
/// and reports a tap through [onSelected]. Which options exist and what a
/// choice means stay with the caller.
///
/// The chips are the theme's [ChoiceChip]s (pill shape, hairline border, the
/// brand fill when selected), with a compact geometry set here:
///
/// * **Width.** Material 3's defaults put 8 of chip padding and 8 of label
///   padding on each side. [_horizontalPadding] + 8 keeps the label clear of
///   the border, lets the four finishes share a row on a 393-wide phone, and
///   lets the five foundation depths share one too (they missed it by 3).
/// * **Height.** 12 above and below the label gives a chip of about 43 at
///   normal text size, inside a 48 tap target the theme still pads to. The
///   label font is unchanged.
/// * **Rows.** 4 of run spacing plus the tap padding above and below each chip
///   leave about 9 between wrapped rows.
class MakeupKitChoiceChipGroup<T> extends StatelessWidget {
  const MakeupKitChoiceChipGroup({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    super.key,
    this.showCheckmark = true,
  });

  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  /// Whether the selected chip shows Material's check mark.
  ///
  /// The check widens the chip by about 17, which on a phone is enough to
  /// push the last option onto a row of its own. Without it, the selected
  /// chip is marked by more than its fill colour: a bolder label and a
  /// heavier brand border, plus its spoken "selected" state.
  final bool showCheckmark;

  /// 1 under [AppSpacing.xxs]: lets Fair … Deep share a row at 321 of card
  /// content width with a few points to spare for font differences.
  static const _horizontalPadding = AppSpacing.xxs - 1;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Two options share the row evenly, so a pair reads as a deliberate
    // choice rather than two small chips at one end of a wide card. Any other
    // count keeps its natural widths and wraps; stretching four finishes to
    // equal widths would push the last one onto a second row.
    if (options.length == 2) {
      return Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _chip(
                options[i],
                isSelected: options[i] == selected,
                isDark: isDark,
                fillWidth: true,
              ),
            ),
          ],
        ],
      );
    }
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final option in options)
          _chip(option, isSelected: option == selected, isDark: isDark),
      ],
    );
  }

  Widget _chip(
    T option, {
    required bool isSelected,
    required bool isDark,
    bool fillWidth = false,
  }) {
    final marksWithoutCheck = isSelected && !showCheckmark;
    final text = Text(
      labelOf(option),
      style: marksWithoutCheck
          ? const TextStyle(fontWeight: FontWeight.w700)
          : null,
    );
    return ChoiceChip(
      // A chip centres itself at its content width inside its tap target, so
      // widening its slot alone leaves a small pill in a wide gap. A label
      // that takes the full width (but keeps its own height) stretches the
      // pill across the slot at the usual chip height.
      label: fillWidth ? Align(heightFactor: 1, child: text) : text,
      selected: isSelected,
      showCheckmark: showCheckmark,
      onSelected: (_) => onSelected(option),
      side: marksWithoutCheck
          ? BorderSide(
              color: isDark ? AppColors.roseLight : AppColors.rose,
              width: AppBorders.emphasis,
            )
          : null,
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: AppSpacing.sm,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
    );
  }
}
