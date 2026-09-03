import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';

/// How much room the mark has.
enum BrandMarkSize {
  /// Above a form title, where the screen's own heading is the main event.
  compact(40, AppIconSizes.md, false),

  /// The entry screen, where the mark introduces the product.
  hero(72, AppIconSizes.lg, true);

  const BrandMarkSize(this.badge, this.glyph, this.showsWordmark);

  final double badge;
  final double glyph;
  final bool showsWordmark;
}

/// FaceTune's identity: a glyph in a brand badge, with the wordmark where there
/// is room for it.
///
/// Built from design tokens rather than an image file. That is deliberate — the
/// only brand asset the project has is a 2 MB stock photograph of a stranger's
/// face, which on a *face-analysis* app's entry screen reads less like branding
/// than like an example result. A mark drawn from the palette also scales,
/// recolours for dark mode, and costs nothing to ship.
///
/// This is presentation standing in for an identity decision the product owner
/// still owns. When real brand art exists it replaces the badge here, in one
/// place.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = BrandMarkSize.compact,
    this.foreground,
    this.background,
  });

  final BrandMarkSize size;

  /// Overrides the glyph and wordmark colour. Needed when the mark sits on a
  /// fixed ground the theme does not know about, such as the entry gradient.
  final Color? foreground;

  /// Overrides the badge fill.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeColour =
        background ?? (isDark ? AppColors.roseDark : AppColors.blush);
    final glyphColour =
        foreground ?? (isDark ? AppColors.blush : AppColors.roseDark);

    final badge = Container(
      width: size.badge,
      height: size.badge,
      decoration: BoxDecoration(
        color: badgeColour,
        borderRadius: BorderRadius.circular(size.badge / 3),
      ),
      child: Icon(
        Icons.auto_awesome_rounded,
        color: glyphColour,
        size: size.glyph,
      ),
    );

    if (!size.showsWordmark) {
      return Semantics(
        label: 'FaceTune',
        child: ExcludeSemantics(child: badge),
      );
    }

    return Semantics(
      label: 'FaceTune',
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge,
            const SizedBox(height: AppSpacing.sm),
            Text(
              'FaceTune',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: foreground,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
