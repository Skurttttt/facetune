/// Undertone of a registered Foundation product: Cool, Neutral, or Warm.
///
/// This is intentionally a separate type from the frozen face analysis
/// feature's `Undertone` (which also supports `olive` and describes the
/// user's detected skin, not a product they own). Coupling this feature to
/// that domain type would violate the isolation boundary between My Makeup
/// Kit and the protected Makeup Recommendation flow.
enum FoundationUndertone {
  cool('cool'),
  neutral('neutral'),
  warm('warm');

  const FoundationUndertone(this.code);

  final String code;

  static FoundationUndertone? fromCode(String code) {
    for (final undertone in values) {
      if (undertone.code == code) return undertone;
    }
    return null;
  }
}
