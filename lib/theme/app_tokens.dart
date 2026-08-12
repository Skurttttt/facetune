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
  static const gold = Color(0xFFB58A52);
  static const success = Color(0xFF557A68);
  static const error = Color(0xFFB64D56);
  static const darkSurface = Color(0xFF1A1517);
  static const darkCard = Color(0xFF261F22);

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
