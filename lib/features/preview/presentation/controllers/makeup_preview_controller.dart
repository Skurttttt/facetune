import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../data/providers/preview_providers.dart';
import '../../domain/errors/preview_failure.dart';
import '../../domain/usecases/generate_makeup_preview.dart';
import 'makeup_preview_state.dart';

final makeupPreviewControllerProvider =
    StateNotifierProvider<MakeupPreviewController, MakeupPreviewState>(
      (ref) =>
          MakeupPreviewController(ref.watch(generateMakeupPreviewProvider)),
    );

class MakeupPreviewController extends StateNotifier<MakeupPreviewState> {
  MakeupPreviewController(this._generate) : super(const MakeupPreviewState());

  final GenerateMakeupPreview _generate;
  MakeupRecommendation? _recommendation;

  Future<void> generate({required MakeupRecommendation recommendation}) async {
    if (state.status == MakeupPreviewStatus.generating) return;
    _recommendation = recommendation;
    state = const MakeupPreviewState(status: MakeupPreviewStatus.generating);
    try {
      final preview = await _generate(recommendation: recommendation);
      if (mounted) {
        state = MakeupPreviewState(
          status: MakeupPreviewStatus.success,
          preview: preview,
        );
      }
    } on PreviewFailure catch (failure) {
      if (mounted) {
        state = MakeupPreviewState(
          status: MakeupPreviewStatus.failure,
          message: failure.message,
          retryable: failure.retryable,
          technicalCode: failure.technicalCode,
        );
      }
    }
  }

  Future<void> retry() async {
    final recommendation = _recommendation;
    if (recommendation != null) await generate(recommendation: recommendation);
  }

  Future<void> generateVariation() => retry();

  void clear() => state = const MakeupPreviewState();
}
