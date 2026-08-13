/// Depth of a registered Foundation product.
///
/// This describes the physical product the user owns and is unrelated to
/// the AI-detected `SkinTone` produced by the frozen face analysis feature.
enum FoundationDepth {
  fair('fair'),
  light('light'),
  medium('medium'),
  tan('tan'),
  deep('deep');

  const FoundationDepth(this.code);

  final String code;

  static FoundationDepth? fromCode(String code) {
    for (final depth in values) {
      if (depth.code == code) return depth;
    }
    return null;
  }
}
