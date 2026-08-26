/// The plan schema version a tutorial was built against.
///
/// V3 must never silently interpret a V1 or V2 row as V3, so parsing is
/// strict: only [currentValue] is accepted. A row carrying any other version
/// is a different generation of the feature and must be rejected rather than
/// coerced.
class TutorialV3PlanVersion {
  const TutorialV3PlanVersion._(this.value);

  /// The only version this domain can interpret.
  static const int currentValue = 3;

  /// The version every plan built by this code carries.
  static const TutorialV3PlanVersion current = TutorialV3PlanVersion._(
    currentValue,
  );

  final int value;

  /// Parses a persisted version.
  ///
  /// Throws a [FormatException] for any version this domain cannot
  /// interpret.
  factory TutorialV3PlanVersion.parse(int value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw FormatException(
        'Unsupported tutorial plan version: $value. '
        'V3 only interprets plan version $currentValue.',
      );
    }
    return parsed;
  }

  /// Parses a persisted version, returning `null` instead of throwing.
  static TutorialV3PlanVersion? tryParse(int value) =>
      value == currentValue ? current : null;

  static bool isSupported(int value) => value == currentValue;

  @override
  bool operator ==(Object other) =>
      other is TutorialV3PlanVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => '$value';
}
