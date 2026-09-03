import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// How a [DetailRow] arranges its label and value.
enum DetailRowLayout {
  /// `Label: value` as one run of text that wraps naturally.
  ///
  /// The right default. It costs no horizontal space, it wraps like prose, and
  /// it cannot misalign.
  inline,

  /// A fixed label column beside the value.
  ///
  /// Use only where several rows are read as a table and the eye benefits from
  /// a shared left edge. Falls back to [inline] under large text, where a fixed
  /// column would squeeze the value into a few characters per line.
  columns,
}

/// A labelled value.
///
/// UI-P0 found this shape written four separate times — three private `_Detail`
/// widgets and one `_detailRow` function — in three different typographic
/// treatments (`w700` rich text, `w600` rich text, and a fixed 100pt label
/// column). Same information, three appearances, and the column variant was a
/// text-scaling overflow waiting to happen.
class DetailRow extends StatelessWidget {
  const DetailRow({
    required this.label,
    required this.value,
    super.key,
    this.layout = DetailRowLayout.inline,
    this.labelWidth = 104,
    this.padding = const EdgeInsets.only(bottom: AppSpacing.sm),
  });

  final String label;
  final String value;
  final DetailRowLayout layout;

  /// Width of the label column in [DetailRowLayout.columns]. Ignored otherwise.
  final double labelWidth;

  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Derived from the effective body colour rather than a fixed token, because
    // these rows appear on the default card *and* on tinted notice surfaces
    // whose foreground has already been overridden. A global muted token is
    // correct on one and wrong on the other.
    final bodyStyle = theme.textTheme.bodyMedium;
    final labelStyle = bodyStyle?.copyWith(fontWeight: FontWeight.w700);

    final useColumns =
        layout == DetailRowLayout.columns &&
        MediaQuery.textScalerOf(context).scale(14) <= 20;

    return Padding(
      padding: padding,
      child: useColumns
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(label, style: labelStyle),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(child: Text(value, style: bodyStyle)),
              ],
            )
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '$label: ', style: labelStyle),
                    TextSpan(text: value, style: bodyStyle),
                  ],
                ),
              ),
            ),
    );
  }
}
