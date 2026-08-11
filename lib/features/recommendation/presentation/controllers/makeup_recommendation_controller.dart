import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../data/providers/recommendation_providers.dart';
import '../../domain/errors/recommendation_failure.dart';
import '../../domain/usecases/generate_makeup_recommendation.dart';
import 'makeup_recommendation_state.dart';

final makeupRecommendationControllerProvider =
    StateNotifierProvider<
      MakeupRecommendationController,
      MakeupRecommendationState
    >(
      (ref) => MakeupRecommendationController(
        ref.watch(generateMakeupRecommendationProvider),
      ),
    );

class MakeupRecommendationController
    extends StateNotifier<MakeupRecommendationState> {
  MakeupRecommendationController(this._generate)
    : super(const MakeupRecommendationState());

  final GenerateMakeupRecommendation _generate;
  FaceAnalysis? _analysis;
  MakeupStyle? _style;

  Future<void> generate({
    required FaceAnalysis analysis,
    required MakeupStyle style,
  }) async {
    if (state.status == MakeupRecommendationStatus.generating) return;
    if (state.recommendation?.analysisId == analysis.id &&
        state.recommendation?.styleCode == style.code) {
      return;
    }
    _analysis = analysis;
    _style = style;
    state = const MakeupRecommendationState(
      status: MakeupRecommendationStatus.generating,
    );
    try {
      final recommendation = await _generate(analysis: analysis, style: style);
      if (mounted) {
        state = MakeupRecommendationState(
          status: MakeupRecommendationStatus.success,
          recommendation: recommendation,
        );
      }
    } on RecommendationFailure catch (failure) {
      if (mounted) {
        state = MakeupRecommendationState(
          status: MakeupRecommendationStatus.failure,
          message: failure.message,
          retryable: failure.retryable,
        );
      }
    }
  }

  Future<void> retry() async {
    final analysis = _analysis;
    final style = _style;
    if (analysis != null && style != null) {
      await generate(analysis: analysis, style: style);
    }
  }

  void clear() => state = const MakeupRecommendationState();
}
