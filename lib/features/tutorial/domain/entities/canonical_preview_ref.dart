import 'recommendation_source_mode.dart';

/// A reference to one canonical final preview, carrying the mode that says
/// which table holds it.
///
/// A bare id is not enough: Standard Mode previews live in `generated_images`
/// and My Makeup Kit previews in `kit_generated_images`, so nothing can resolve
/// a preview without also knowing its mode. Pairing them in one value makes it
/// impossible to pass an id without its mode, or to pair an id with the wrong
/// one halfway down a call chain.
///
/// The mode here always originates server-side — from which owner-scoped table
/// the row actually resolved in — and is never a client assertion.
class CanonicalPreviewRef {
  const CanonicalPreviewRef({required this.id, required this.sourceMode});

  const CanonicalPreviewRef.standard(this.id)
    : sourceMode = RecommendationSourceMode.standard;

  const CanonicalPreviewRef.myMakeupKit(this.id)
    : sourceMode = RecommendationSourceMode.myMakeupKit;

  final String id;
  final RecommendationSourceMode sourceMode;

  bool get isMyMakeupKit => sourceMode == RecommendationSourceMode.myMakeupKit;

  @override
  bool operator ==(Object other) =>
      other is CanonicalPreviewRef &&
      other.id == id &&
      other.sourceMode == sourceMode;

  @override
  int get hashCode => Object.hash(id, sourceMode);

  @override
  String toString() => '${sourceMode.code}:$id';
}
