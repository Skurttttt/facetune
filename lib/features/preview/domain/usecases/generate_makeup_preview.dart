import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../entities/generated_preview.dart';
import '../repositories/makeup_preview_repository.dart';

class GenerateMakeupPreview {
  const GenerateMakeupPreview(this._repository);

  final MakeupPreviewRepository _repository;

  Future<GeneratedPreview> call({
    required MakeupRecommendation recommendation,
  }) => _repository.generate(recommendation: recommendation);
}
