class KitMakeupRecommendation {
  const KitMakeupRecommendation({
    required this.id,
    required this.analysisId,
    required this.styleCode,
    required this.selections,
    required this.overallIntensity,
    required this.summary,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String analysisId;
  final String styleCode;
  final List<KitMakeupSelection> selections;
  final String overallIntensity;
  final String summary;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;
}

class KitMakeupSelection {
  const KitMakeupSelection({
    required this.productId,
    required this.category,
    required this.colorHex,
    required this.finish,
    required this.placement,
    required this.technique,
    required this.intensity,
  });

  final String productId;
  final String category;
  final String colorHex;
  final String finish;
  final String placement;
  final String technique;
  final String intensity;
}
