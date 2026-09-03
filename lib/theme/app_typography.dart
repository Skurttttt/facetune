import 'package:flutter/material.dart';

/// FaceTune's type scale.
///
/// Material's default scale is designed to work anywhere, which means its
/// display sizes are tuned for surfaces far larger than a phone: `displayLarge`
/// is 57pt, roughly a seventh of the POCO X3 GT's 393pt width. FaceTune is a
/// phone-first editorial product, so the display and headline end is tightened
/// and the reading end is left alone.
///
/// Every size here is **at or below** the Material default it replaces. That is
/// deliberate for a foundation phase: a scale that only ever shrinks cannot
/// introduce an overflow into the fixed-height boxes the UI-P0 audit found
/// (a 224pt strip on Home, a 190pt grid cell on Style Selection). It can only
/// relieve pressure on them.
///
/// Sizes are the *unscaled* values. The user's text-size preference multiplies
/// them through `MediaQuery.textScaler`, and nothing here opts out of that.
abstract final class AppTypography {
  /// The family for every role.
  ///
  /// `null` means "the platform's default UI face" — Roboto on Android, San
  /// Francisco on iOS. It is deliberately not the string `'sans-serif'` that
  /// used to be here: that is an Android family alias, so it resolved to Roboto
  /// on the target device but was an unrecognised name everywhere else, making
  /// the typeface an accident of platform rather than a decision.
  ///
  /// FaceTune has no licensed brand face yet, and a UI phase cannot choose one —
  /// that is a licensing decision, not a code change. When a face is licensed,
  /// bundle it under `assets/fonts/`, declare it in `pubspec.yaml`, and set this
  /// one constant. Nothing else in the app names a font.
  static const String? fontFamily = null;

  /// Applies FaceTune's scale to [base].
  ///
  /// Takes the theme's own `TextTheme` and copies onto it rather than building
  /// one from nothing, so Material keeps its colour resolution — the roles still
  /// pick up `onSurface` and its variants from the active `ColorScheme`.
  static TextTheme apply(TextTheme base) => base.copyWith(
    // Display — the entry screen's headline, and nothing else. Tight tracking
    // and a sub-1.1 line height are what make a large size read as editorial
    // rather than merely big.
    displayLarge: base.displayLarge?.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.8,
      height: 1.04,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontSize: 40,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.6,
      height: 1.05,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontSize: 34,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.4,
      height: 1.06,
    ),

    // Headline — the first line of most screens.
    headlineLarge: base.headlineLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: -1,
      height: 1.12,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontSize: 27,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      height: 1.15,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.2,
    ),

    // Title — section headers, card titles, app bar. 19 rather than Material's
    // 22: at 22 a `SectionHeader` competes with the screen's own headline, and
    // the hierarchy reads as two peers instead of a heading and its sections.
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 19,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.1,
      height: 1.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.35,
    ),

    // Body — left at Material's sizes. These are the sizes people read, they
    // are already right, and shrinking them to look designed is how an app
    // becomes hard to use. Only the line height is opened up.
    bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
    bodyMedium: base.bodyMedium?.copyWith(height: 1.5),
    bodySmall: base.bodySmall?.copyWith(height: 1.45),

    // Label — buttons, chips, overlines.
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w600),
    labelSmall: base.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
    ),
  );
}
