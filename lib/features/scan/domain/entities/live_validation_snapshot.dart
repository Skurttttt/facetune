import 'live_check.dart';

/// The result of evaluating every [LiveCheck] against one frame.
///
/// Immutable and whole: a snapshot always carries a state for every check, so
/// there is no partially-populated shape for a reader to guess about. A check
/// that has not been measured is [LiveCheckState.unknown], explicitly.
class LiveValidationSnapshot {
  const LiveValidationSnapshot(this.states);

  /// Nothing measured yet.
  factory LiveValidationSnapshot.unknown() => const LiveValidationSnapshot({
    LiveCheck.lighting: LiveCheckState.unknown,
    LiveCheck.sharpness: LiveCheckState.unknown,
    LiveCheck.steadiness: LiveCheckState.unknown,
  });

  /// A frame is in flight; every check is provisionally [LiveCheckState.checking].
  factory LiveValidationSnapshot.checking() => const LiveValidationSnapshot({
    LiveCheck.lighting: LiveCheckState.checking,
    LiveCheck.sharpness: LiveCheckState.checking,
    LiveCheck.steadiness: LiveCheckState.checking,
  });

  final Map<LiveCheck, LiveCheckState> states;

  LiveCheckState stateOf(LiveCheck check) =>
      states[check] ?? LiveCheckState.unknown;

  /// The order guidance is chosen in, most actionable first.
  ///
  /// Lighting leads because it is the one thing a user can fix by moving, and
  /// because a frame that is too dark makes the other two unreliable anyway.
  /// Steadiness precedes sharpness because "hold still" is an instruction,
  /// while blur is usually a symptom of not holding still.
  static const priority = <LiveCheck>[
    LiveCheck.lighting,
    LiveCheck.steadiness,
    LiveCheck.sharpness,
  ];

  /// The single check worth telling the user about, or null when all is well.
  ///
  /// One message, not five. A wall of changing checks is noise; the user needs
  /// the next thing to do. Failures outrank warnings so the guidance never
  /// suggests a small improvement while something is actually unusable.
  LiveCheck? get primaryIssue {
    for (final check in priority) {
      if (stateOf(check) == LiveCheckState.fail) return check;
    }
    for (final check in priority) {
      if (stateOf(check) == LiveCheckState.warning) return check;
    }
    return null;
  }

  /// How many checks are comfortably in range.
  int get passingCount =>
      states.values.where((state) => state == LiveCheckState.pass).length;

  int get checkCount => states.length;

  bool get hasFailure =>
      states.values.any((state) => state == LiveCheckState.fail);

  bool get hasWarning =>
      states.values.any((state) => state == LiveCheckState.warning);

  /// True only once every check has actually been measured and passed.
  ///
  /// `unknown` and `checking` are not readiness. Treating an unmeasured check
  /// as ready would show a confident Ready state built on nothing.
  bool get isReady =>
      states.isNotEmpty &&
      states.values.every((state) => state == LiveCheckState.pass);

  /// What the checks imply about the shutter. See [LiveCaptureEligibility].
  LiveCaptureEligibility get eligibility {
    if (hasFailure) return LiveCaptureEligibility.blocked;
    if (isReady) return LiveCaptureEligibility.ready;
    return LiveCaptureEligibility.allowedWithWarning;
  }

  @override
  bool operator ==(Object other) =>
      other is LiveValidationSnapshot &&
      other.states.length == states.length &&
      states.entries.every((entry) => other.states[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAllUnordered(
    states.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );
}
