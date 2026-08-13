/// A validated, normalized 6-digit hex color (e.g. `#B86F72`).
///
/// Normalization matches the shape already relied on by the frozen Makeup
/// Recommendation contract (`^#[0-9A-F]{6}$`): a leading `#` followed by six
/// uppercase hexadecimal digits. Input is accepted with or without a
/// leading `#` and in any letter case, but always normalizes to that exact
/// shape.
///
/// Users are never required to enter a HEX value directly — this type
/// exists so a value produced by a visual color picker (or later, deferred
/// user HEX entry) can be validated once and safely reused across the
/// domain, persistence, and AI boundaries without malformed colors leaking
/// through.
class NormalizedHexColor {
  const NormalizedHexColor._(this.value);

  /// The normalized value: `#` followed by six uppercase hex digits.
  final String value;

  static final RegExp _sixDigitHex = RegExp(r'^[0-9A-Fa-f]{6}$');

  /// Parses and normalizes [input].
  ///
  /// Throws a [FormatException] if [input] is not a valid 6-digit hex
  /// color.
  factory NormalizedHexColor.parse(String input) {
    final normalized = _normalize(input);
    if (normalized == null) {
      throw FormatException('Invalid HEX color: "$input".');
    }
    return NormalizedHexColor._(normalized);
  }

  /// Parses and normalizes [input], returning `null` instead of throwing
  /// when it is not a valid 6-digit hex color.
  static NormalizedHexColor? tryParse(String input) {
    final normalized = _normalize(input);
    return normalized == null ? null : NormalizedHexColor._(normalized);
  }

  /// Whether [input] is a valid 6-digit hex color, with or without a
  /// leading `#`.
  static bool isValid(String input) => _normalize(input) != null;

  static String? _normalize(String input) {
    final trimmed = input.trim();
    final withoutHash = trimmed.startsWith('#')
        ? trimmed.substring(1)
        : trimmed;
    if (!_sixDigitHex.hasMatch(withoutHash)) return null;
    return '#${withoutHash.toUpperCase()}';
  }

  @override
  bool operator ==(Object other) =>
      other is NormalizedHexColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
