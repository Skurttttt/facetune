import '../../../preview/domain/errors/preview_failure.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';
import '../../domain/repositories/makeup_kit_look_repository.dart';

class UnavailableMakeupKitLookRepository implements MakeupKitLookRepository {
  const UnavailableMakeupKitLookRepository();

  Never _unavailable() => throw const PreviewFailure(
    PreviewFailureType.server,
    'My Makeup Kit AI is not configured in this build.',
  );

  @override
  Future<KitMakeupRecommendation> generateRecommendation({
    required String analysisId,
    required String styleCode,
  }) async => _unavailable();

  @override
  Future<KitGeneratedPreview> generatePreview({
    required KitMakeupRecommendation recommendation,
  }) async => _unavailable();
}
