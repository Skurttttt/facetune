import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';

class SavedLook {
  const SavedLook({
    required this.id,
    required this.preview,
    required this.analysis,
    required this.recommendation,
    required this.style,
    required this.isFavorite,
    required this.createdAt,
  });

  final String id;
  final GeneratedPreview preview;
  final FaceAnalysis analysis;
  final MakeupRecommendation recommendation;
  final MakeupStyle style;
  final bool isFavorite;
  final DateTime createdAt;

  SavedLook copyWith({bool? isFavorite}) => SavedLook(
    id: id,
    preview: preview,
    analysis: analysis,
    recommendation: recommendation,
    style: style,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}

class SavedLooksPageResult {
  const SavedLooksPageResult({required this.items, required this.hasMore});

  final List<SavedLook> items;
  final bool hasMore;
}
