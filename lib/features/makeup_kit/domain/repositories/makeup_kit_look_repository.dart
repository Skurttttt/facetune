import '../entities/kit_generated_preview.dart';
import '../entities/kit_makeup_recommendation.dart';

abstract interface class MakeupKitLookRepository {
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  });

  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  });
}
