class MakeupRecommendationItem {
  const MakeupRecommendationItem({
    required this.name,
    required this.placement,
    required this.technique,
    required this.finish,
    required this.intensity,
    required this.reasoning,
    this.hex,
  });

  final String name;
  final String? hex;
  final String placement;
  final String technique;
  final String finish;
  final String intensity;
  final String reasoning;
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
