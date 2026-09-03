import 'package:flutter/material.dart';

/// FaceTune's brand palette.
///
/// Two layers live here and they answer different questions.
///
///  * The **raw brand tones** (`rose`, `blush`, `cocoa`, …) are the identity.
///    They are fixed values and they do not change between themes.
///  * The **contrast helpers** (`muted`, `onTint`, `onAccent`) resolve a
///    readable foreground for a given context or ground. They exist because a
///    brand tone tuned for a light surface is not automatically legible on a
///    dark one, and several of FaceTune's are not.
///
/// What is deliberately *not* here is meaning. "Which colour says this failed"
/// is a semantic question, and it is answered by [AppSemantics] in
/// `app_semantics.dart` — a `ThemeExtension` whose roles resolve per brightness.
/// Reaching for a raw tone to signal an outcome is the mistake that let one pink
/// surface mean success and failure on the same screen.
abstract final class AppColors {
  static const rose = Color(0xFFA94E6B);
  static const roseDark = Color(0xFF7C354D);
  static const blush = Color(0xFFF5DDE3);
  static const petal = Color(0xFFFBEFF2);
  static const ivory = Color(0xFFFFFBF8);
  static const sand = Color(0xFFF4ECE7);
  static const cocoa = Color(0xFF2E2225);
  static const taupe = Color(0xFF75686B);

  /// Dark-theme counterpart to [taupe].
  ///
  /// [taupe] reaches only 3.4:1 against [darkSurface], below the 4.5:1 WCAG AA
  /// minimum for body text. This lighter tone of the same hue reaches 5.8:1 on
  /// [darkSurface] and 5.2:1 on [darkCard].
  static const taupeLight = Color(0xFF9C8E92);
  static const gold = Color(0xFFB58A52);
  static const success = Color(0xFF557A68);
  static const error = Color(0xFFB64D56);
  static const darkSurface = Color(0xFF1A1517);
  static const darkCard = Color(0xFF261F22);

  /// Dark-theme text variants of the accent colours.
  ///
  /// The brand accents are tuned for light surfaces and drop below the 4.5:1
  /// WCAG AA text minimum on [darkCard] ([rose] 3.1:1, [success] 3.4:1). These
  /// lighter tones of the same hues clear 6:1.
  static const roseLight = Color(0xFFE08BA3);
  static const successLight = Color(0xFF8FBBA6);

  /// Light-theme *text* variants of the accent colours.
  ///
  /// [gold], [success] and [error] are chosen as fills and as decorative marks.
  /// Used as a label or an icon on their own pale tint they fall short:
  /// measured against the warning tint, [gold] reaches only 2.83:1 — under even
  /// the 3:1 minimum WCAG 1.4.11 sets for non-text graphics, let alone the 4.5:1
  /// text minimum. These deepened tones of the same hues clear 4.7:1.
  ///
  /// Every one of these figures is asserted in `test/theme/design_system_test.dart`,
  /// so a future tweak to any tone fails loudly rather than quietly dropping a
  /// label below AA.
  static const goldDeep = Color(0xFF8A6634);
  static const successDeep = Color(0xFF46685A);
  static const errorDeep = Color(0xFFA03C46);

  /// Dark-theme counterparts to [goldDeep] and [errorDeep].
  static const goldLight = Color(0xFFD9B478);
  static const errorLight = Color(0xFFE8909A);

  /// Readable text colour for an [accent] drawn on its own tinted chip.
  ///
  /// The tint keeps the accent hue in both themes; only the label lightens.
  static Color onTint(BuildContext context, Color accent) {
    if (Theme.of(context).brightness != Brightness.dark) return accent;
    if (accent == rose) return roseLight;
    if (accent == success) return successLight;
    if (accent == taupe) return taupeLight;
    if (accent == gold || accent == goldDeep) return goldLight;
    if (accent == error || accent == errorDeep) return errorLight;
    if (accent == successDeep) return successLight;
    return accent;
  }

  /// Secondary text colour for the active theme.
  ///
  /// Use for supporting copy — subtitles, timestamps, helper text — so it stays
  /// legible in dark mode instead of sinking into the background.
  static Color muted(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? taupeLight : taupe;

  /// Foreground that stays readable on a fixed [background] in either theme.
  ///
  /// Accent surfaces such as [petal] and [blush] keep their own brightness in
  /// dark mode, so text drawn on them cannot inherit the theme's `onSurface`
  /// colour — that renders near-white text on a near-white card.
  static Color onAccent(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : cocoa;
}

abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Horizontal inset from the screen edge to page content.
  ///
  /// Its own token rather than one of the steps above because it is a layout
  /// decision, not a gap between two things: it sets how wide the readable
  /// column is on a phone, and it is the one value that must stay identical on
  /// every screen for the app to feel like one app.
  static const gutter = 20.0;
}

abstract final class AppRadii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const pill = 999.0;
}

abstract final class AppElevation {
  static const none = 0.0;
  static const subtle = 1.0;
  static const floating = 6.0;
}

/// Border weights.
///
/// FaceTune separates surfaces with a hairline and a tint rather than with
/// shadow. [hairline] is the default; [emphasis] marks a selected or focused
/// boundary, where the extra weight is carrying state rather than decoration.
abstract final class AppBorders {
  static const hairline = 1.0;
  static const emphasis = 1.5;
}

abstract final class AppIconSizes {
  static const sm = 18.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const hero = 48.0;
}

abstract final class AppDurations {
  static const quick = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 280);

  /// For transitions that move a large surface, where [standard] reads as a
  /// snap rather than a movement.
  static const slow = Duration(milliseconds: 420);

  /// One cycle of an indeterminate loading shimmer.
  ///
  /// Much slower than the interaction durations on purpose: a shimmer that
  /// pulses at interaction speed reads as urgency, which is the wrong signal
  /// while someone is waiting.
  static const shimmer = Duration(milliseconds: 1200);
}

/// Easing curves.
///
/// Paired with [AppDurations]. The rule is that things entering or settling use
/// [decelerate]; things leaving use [accelerate]; anything the user is directly
/// dragging uses [linear] so it tracks the finger exactly.
abstract final class AppCurves {
  /// Default for state changes: quick to start, gentle to land.
  static const standard = Curves.easeOutCubic;

  /// For a surface arriving on screen. Longer tail than [standard], which is
  /// what makes an entrance feel deliberate rather than abrupt.
  static const decelerate = Curves.easeOutQuint;

  /// For a surface leaving. Departures are not worth dwelling on.
  static const accelerate = Curves.easeInCubic;

  /// Direct manipulation only.
  static const linear = Curves.linear;
}
