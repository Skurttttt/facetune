import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../entities/generated_preview.dart';

abstract interface class MakeupPreviewRepository {
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  });
}
