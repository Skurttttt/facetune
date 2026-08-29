/// The schema version of a persisted Tutorial V2 plan.
///
/// V1 tutorial rows still exist in the remote database (see
/// `docs/tutorial_v2/V2-0_BASELINE_AUDIT.md`). A V2 reader must reject or
/// route away from incompatible session data rather than silently
/// reinterpreting a V1 row as V2, and must never rewrite historical rows
/// in place (Source of Truth §21).
///
/// Versions below [minimumSupportedValue] are treated as legacy V1 data.
/// Versions above [currentValue] are treated as written by a newer build and
/// are also rejected — reading forward would mean guessing at fields this
/// build does not know about.
class TutorialV2PlanVersion {
  const TutorialV2PlanVersion._(this.value);

  /// The version this build writes.
  static const int currentValue = 2;

  /// The oldest version this build can read. V2 is a clean restart, so V2
  /// never reads a V1 plan.
  static const int minimumSupportedValue = 2;

  static const TutorialV2PlanVersion current = TutorialV2PlanVersion._(
    currentValue,
  );

  final int value;

  /// Whether [value] is a version this build can safely read.
  static bool isSupported(int value) =>
      value >= minimumSupportedValue && value <= currentValue;

  /// Whether [value] identifies a pre-V2 (V1) plan.
  static bool isLegacyV1(int value) => value < minimumSupportedValue;

  /// Whether [value] was written by a newer build than this one.
  static bool isFromNewerBuild(int value) => value > currentValue;

  /// Parses [value], returning `null` when it is not readable by this build.
  static TutorialV2PlanVersion? tryParse(int value) =>
      isSupported(value) ? TutorialV2PlanVersion._(value) : null;

  /// Parses [value].
  ///
  /// Throws a [FormatException] when the version is not readable by this
  /// build, naming which side of the supported range it fell on so callers
  /// can route a stale session differently from a forward-incompatible one.
  factory TutorialV2PlanVersion.parse(int value) {
    final parsed = tryParse(value);
    if (parsed != null) return parsed;
    if (isLegacyV1(value)) {
      throw FormatException(
        'Tutorial plan version $value is a legacy V1 plan and cannot be '
        'read as V2.',
      );
    }
    throw FormatException(
      'Tutorial plan version $value was written by a newer build than this '
      'one (current: $currentValue).',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TutorialV2PlanVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'v$value';
}
