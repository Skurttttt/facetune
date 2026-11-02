import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';

/// A color's HSL position: the integers the adjuster's sliders hold, plus the
/// hue they leave untouched.
class CustomPaletteHsl {
  const CustomPaletteHsl({
    required this.hue,
    required this.saturation,
    required this.lightness,
    required this.isAchromatic,
  });

  /// Degrees in `[0, 360)`.
  final double hue;

  /// Integer percent, 0–100.
  final int saturation;

  /// Integer percent, 0–100.
  final int lightness;

  /// Red, green and blue are equal, so there is no hue to saturate.
  final bool isAchromatic;
}

/// The deterministic color adjuster: base color plus Saturation and Lightness.
///
/// Hand-written rather than using Flutter's `HSLColor` so the domain layer
/// stays free of Flutter, and so the rounding is pinned here by test vectors.
///
/// HSL rather than HSV because one Lightness control can make any color lighter
/// or darker; HSV Brightness cannot lighten a saturated red on its own.
abstract final class CustomPaletteColorModel {
  static CustomPaletteHsl toHsl(NormalizedHexColor color) {
    final hex = color.value;
    final r = int.parse(hex.substring(1, 3), radix: 16) / 255;
    final g = int.parse(hex.substring(3, 5), radix: 16) / 255;
    final b = int.parse(hex.substring(5, 7), radix: 16) / 255;
    final maximum = [r, g, b].reduce((a, c) => a > c ? a : c);
    final minimum = [r, g, b].reduce((a, c) => a < c ? a : c);
    final delta = maximum - minimum;
    final lightness = (maximum + minimum) / 2;
    if (delta == 0) {
      return CustomPaletteHsl(
        hue: 0,
        saturation: 0,
        lightness: (lightness * 100).round(),
        isAchromatic: true,
      );
    }
    final saturation = delta / (1 - (2 * lightness - 1).abs());
    final double sector;
    if (maximum == r) {
      sector = ((g - b) / delta) % 6;
    } else if (maximum == g) {
      sector = (b - r) / delta + 2;
    } else {
      sector = (r - g) / delta + 4;
    }
    return CustomPaletteHsl(
      hue: sector * 60,
      saturation: (saturation * 100).round(),
      lightness: (lightness * 100).round(),
      isAchromatic: false,
    );
  }

  /// The final color for [base] at [saturation] and [lightness].
  ///
  /// Values are clamped to 0–100. When they equal the base's own rounded
  /// position the base is returned exactly, because rounding through HSL could
  /// otherwise shift an untouched color by a step. An achromatic base stays
  /// achromatic: its hue is undefined, so saturating it would invent one.
  static NormalizedHexColor adjust(
    NormalizedHexColor base, {
    required int saturation,
    required int lightness,
  }) {
    final position = toHsl(base);
    final s = position.isAchromatic ? 0 : saturation.clamp(0, 100);
    final l = lightness.clamp(0, 100);
    if (s == position.saturation && l == position.lightness) return base;
    return _fromHsl(position.hue, s / 100, l / 100);
  }

  static NormalizedHexColor _fromHsl(double hue, double s, double l) {
    final chroma = (1 - (2 * l - 1).abs()) * s;
    final second = chroma * (1 - ((hue / 60) % 2 - 1).abs());
    final match = l - chroma / 2;
    final (double r, double g, double b) = switch (hue) {
      < 60 => (chroma, second, 0.0),
      < 120 => (second, chroma, 0.0),
      < 180 => (0.0, chroma, second),
      < 240 => (0.0, second, chroma),
      < 300 => (second, 0.0, chroma),
      _ => (chroma, 0.0, second),
    };
    return NormalizedHexColor.parse(
      '#${_channel(r + match)}${_channel(g + match)}${_channel(b + match)}',
    );
  }

  static String _channel(double value) =>
      (value * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
}
