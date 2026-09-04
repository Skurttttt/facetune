/// A quality property the local validator evaluates on a live camera frame.
///
/// These are exactly the checks that can be computed on-device from a frame's
/// luma plane with ordinary arithmetic. Face count, face visibility, and head
/// angle are deliberately **not** here: the approved Live Scan scope adds no
/// face detector, so claiming to check them locally would be a lie told in an
/// enum. Those three remain enforced where they are enforced today — inside the
/// single paid face-analysis call, which judges the still the user actually
/// captured.
///
/// That split is the whole point of this layer. Local validation is a cheap
/// advisory pass that stops obviously unusable frames from reaching a paid
/// call. It never becomes the authority, and it never weakens the server gate.
///
/// The enum is open to extension if a detector is ever separately approved.
enum LiveCheck {
  /// Enough light, and not so much that the face blows out.
  lighting,

  /// Enough high-frequency detail to be in focus.
  sharpness,

  /// Little enough frame-to-frame change to be holding still.
  steadiness,
}

/// How one [LiveCheck] currently reads.
///
/// Five states rather than a boolean because "not measured yet" and "measured
/// and bad" are different things to show a user, and because a check that is
/// merely poor should not be presented like one that is unusable.
enum LiveCheckState {
  /// No frame has been analysed for this check yet.
  unknown,

  /// A frame is being analysed right now.
  checking,

  /// Comfortably within range.
  pass,

  /// Usable, but the capture would be better if this improved.
  warning,

  /// Outside the usable range.
  fail,
}

/// Whether the shutter may fire, given the current checks.
///
/// A *mapping*, not a policy. This layer says what the frames imply; which of
/// these states actually disables a shutter button is a presentation decision
/// and belongs to the screen that owns the shutter.
///
/// Worth stating plainly, because it constrains that later decision: today
/// there is no local gate at all — a user may photograph anything, and the
/// server decides. Local checks exist to save a paid call on an obviously
/// unusable frame, not to lock a user out of their own camera.
enum LiveCaptureEligibility {
  /// At least one check has failed.
  blocked,

  /// Nothing failed, but at least one check is a warning.
  allowedWithWarning,

  /// Every check passes.
  ready,
}
