import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../entities/makeup_recommendation.dart';
import '../repositories/makeup_recommendation_repository.dart';

class GenerateMakeupRecommendation {
  const GenerateMakeupRecommendation(this._repository);

  final MakeupRecommendationRepository _repository;

  Future<MakeupRecommendation> call({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) => _repository.generate(analysis: analysis, style: style);
}
