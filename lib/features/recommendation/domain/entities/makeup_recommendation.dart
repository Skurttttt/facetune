/// The three grounded explanations behind one Palette card's
/// "Why this works for you".
///
/// What and why, deliberately not where and how. Placement and technique
/// already answer where and how, and the Step-by-Step tutorial is the surface
/// that teaches them — education that repeated them would duplicate the
/// tutorial instead of explaining the recommendation.
class MakeupRecommendationEducation {
  const MakeupRecommendationEducation({
    required this.features,
    required this.effect,
    required this.style,
  });

  /// Which actually-detected facial attributes drove this choice.
  final String features;

  /// What this shade, finish, and intensity do visually.
  final String effect;

  /// Why this supports the style the user actually selected.
  final String style;
}

class MakeupRecommendationItem {
  const MakeupRecommendationItem({
    required this.name,
    required this.placement,
    required this.technique,
    required this.finish,
    required this.intensity,
    required this.reasoning,
    this.hex,
    this.education,
  });

  final String name;
  final String? hex;
  final String placement;
  final String technique;
  final String finish;
  final String intensity;
  final String reasoning;

  /// The grounded explanations, or null for a plan generated before education
  /// existed.
  ///
  /// Nullable because this is read from persistence as well as from a fresh
  /// response. Every plan stored under `makeup_recommendation_v2` and earlier
  /// has no education, and those rows are still opened by History, Saved Looks,
  /// and the kit library. Null is the honest representation of "this plan was
  /// never explained" — the Palette shows a compact card rather than inventing
  /// copy, and nothing calls the AI to backfill it.
  final MakeupRecommendationEducation? education;

  /// Whether this item can show the three-section explanation.
  bool get hasEducation => education != null;
}

class MakeupRecommendation {
  const MakeupRecommendation({
    required this.id,
    required this.analysisId,
    required this.styleCode,
    required this.overallIntensity,
    required this.items,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String analysisId;
  final String styleCode;
  final String overallIntensity;
  final Map<String, MakeupRecommendationItem> items;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;
}
