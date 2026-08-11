import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../entities/makeup_recommendation.dart';

abstract interface class MakeupRecommendationRepository {
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  });
}
