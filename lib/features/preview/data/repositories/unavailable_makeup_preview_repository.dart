import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../domain/entities/generated_preview.dart';
import '../../domain/errors/preview_failure.dart';
import '../../domain/repositories/makeup_preview_repository.dart';

class UnavailableMakeupPreviewRepository implements MakeupPreviewRepository {
  const UnavailableMakeupPreviewRepository();

  @override
  Future<GeneratedPreview> generate({
    required MakeupRecommendation recommendation,
  }) => throw const PreviewFailure(
    PreviewFailureType.server,
    'Supabase runtime configuration is unavailable.',
  );
}
