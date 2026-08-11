import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../domain/entities/makeup_recommendation.dart';
import '../../domain/errors/recommendation_failure.dart';
import '../../domain/repositories/makeup_recommendation_repository.dart';

class UnavailableMakeupRecommendationRepository
    implements MakeupRecommendationRepository {
  const UnavailableMakeupRecommendationRepository();

  @override
  Future<MakeupRecommendation> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) => throw const RecommendationFailure(
    RecommendationFailureType.server,
    'Supabase runtime configuration is unavailable.',
  );
}
