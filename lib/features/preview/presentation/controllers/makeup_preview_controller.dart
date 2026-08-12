import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/preview_providers.dart';
import '../../domain/entities/generated_preview.dart';
import '../../domain/errors/preview_failure.dart';
import '../../domain/usecases/generate_makeup_preview.dart';
import 'makeup_preview_state.dart';

final makeupPreviewControllerProvider =
    StateNotifierProvider<MakeupPreviewController, MakeupPreviewState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return MakeupPreviewController(ref.watch(generateMakeupPreviewProvider));
    });

class MakeupPreviewController extends StateNotifier<MakeupPreviewState> {
  MakeupPreviewController(this._generate) : super(const MakeupPreviewState());

  final GenerateMakeupPreview _generate;
  MakeupRecommendation? _recommendation;
  int _operationEpoch = 0;

  Future<void> generate({required MakeupRecommendation recommendation}) async {
    if (state.status == MakeupPreviewStatus.generating) return;
    _recommendation = recommendation;
    final candidatePreview = state.status == MakeupPreviewStatus.success
        ? state.preview
        : state.previousPreview;
    final previousPreview =
        candidatePreview?.recommendationId == recommendation.id
        ? candidatePreview
        : null;
    final operation = ++_operationEpoch;
    state = MakeupPreviewState(
      status: MakeupPreviewStatus.generating,
      previousPreview: previousPreview,
    );
    try {
      final preview = await _generate(recommendation: recommendation);
      if (mounted && operation == _operationEpoch) {
        state = MakeupPreviewState(
          status: MakeupPreviewStatus.success,
          preview: preview,
        );
      }
    } on PreviewFailure catch (failure) {
      if (mounted && operation == _operationEpoch) {
        state = MakeupPreviewState(
          status: MakeupPreviewStatus.failure,
          previousPreview: previousPreview,
          message: failure.message,
          retryable: failure.retryable,
          technicalCode: failure.technicalCode,
          failureType: failure.type,
        );
      }
    } catch (_) {
      if (mounted && operation == _operationEpoch) {
        state = MakeupPreviewState(
          status: MakeupPreviewStatus.failure,
          previousPreview: previousPreview,
          message:
              'Your makeup preview could not be created. Please try again.',
          retryable: true,
          failureType: PreviewFailureType.server,
        );
      }
    }
  }

  Future<void> retry() async {
    final recommendation = _recommendation;
    if (recommendation != null) await generate(recommendation: recommendation);
  }

  Future<void> generateVariation() => retry();

  void showPreviousResult() {
    final previous = state.previousPreview;
    if (previous == null) return;
    state = MakeupPreviewState(
      status: MakeupPreviewStatus.success,
      preview: previous,
    );
  }

  void clear() {
    _operationEpoch += 1;
    _recommendation = null;
    state = const MakeupPreviewState();
  }

  void restore(
    GeneratedPreview preview, {
    required MakeupRecommendation recommendation,
  }) {
    _operationEpoch += 1;
    _recommendation = recommendation;
    state = MakeupPreviewState(
      status: MakeupPreviewStatus.success,
      preview: preview,
    );
  }
}
