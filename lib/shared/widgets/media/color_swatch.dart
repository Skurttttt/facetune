import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';

/// A circular preview of a makeup shade.
///
/// UI-P0 found four separate implementations of this circle — at 26, 28, 28 and
/// 42pt, with three different border rules, and only two of the four carrying a
/// semantics label. A swatch with no label is silent to a screen reader, which
/// means a blind user is told a product has a colour but never which one.
///
/// The colour drawn here is **data**, not theme: it comes from a recommendation
/// or from a product the user registered. Only the border and the invalid-value
/// fallback are themed, so a shade renders identically in light and dark, which
/// is the point of showing it at all.
class AppColorSwatch extends StatelessWidget {
  const AppColorSwatch({
    required this.color,
    super.key,
    this.size = defaultSize,
    this.semanticLabel,
  });

  /// The default diameter. Large enough to judge a shade, small enough to sit
  /// inside a list row without setting the row's height.
  static const double defaultSize = 28;

  /// A diameter for a swatch that is the subject of its row rather than an
  /// annotation on it.
  static const double largeSize = 42;

  /// The shade. Null renders a neutral placeholder rather than guessing — an
  /// unparseable hex is missing data, and inventing a colour for it would show
  /// the user a shade that does not exist.
  final Color? color;

  final double size;

  /// What a screen reader announces.
  ///
  /// Pass the human shade name where one exists ("Shade Warm Rose"); a bare hex
  /// code is technically accurate and practically useless when read aloud.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final swatch = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.outlineVariant,
          width: AppBorders.hairline,
        ),
      ),
    );

    if (semanticLabel == null) {
      // No label means the swatch is decorative here — the shade is named in
      // adjacent text. Excluding it stops a screen reader announcing an
      // unlabelled node the user cannot act on.
      return ExcludeSemantics(child: swatch);
    }
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: swatch,
    );
  }
}
