import 'package:flutter/material.dart';

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

  /// Readable text colour for an [accent] drawn on its own tinted chip.
  ///
  /// The tint keeps the accent hue in both themes; only the label lightens.
  static Color onTint(BuildContext context, Color accent) {
    if (Theme.of(context).brightness != Brightness.dark) return accent;
    if (accent == rose) return roseLight;
    if (accent == success) return successLight;
    if (accent == taupe) return taupeLight;
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

abstract final class AppIconSizes {
  static const sm = 18.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const hero = 48.0;
}

abstract final class AppDurations {
  static const quick = Duration(milliseconds: 180);
  static const standard = Duration(milliseconds: 280);
}
