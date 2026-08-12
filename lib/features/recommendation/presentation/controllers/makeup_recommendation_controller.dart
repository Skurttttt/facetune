import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';
import '../../data/providers/recommendation_providers.dart';
import '../../domain/entities/makeup_recommendation.dart';
import '../../domain/errors/recommendation_failure.dart';
import '../../domain/usecases/generate_makeup_recommendation.dart';
import 'makeup_recommendation_state.dart';

final makeupRecommendationControllerProvider =
    StateNotifierProvider<
      MakeupRecommendationController,
      MakeupRecommendationState
    >((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return MakeupRecommendationController(
        ref.watch(generateMakeupRecommendationProvider),
      );
    });

class MakeupRecommendationController
    extends StateNotifier<MakeupRecommendationState> {
  MakeupRecommendationController(this._generate)
    : super(const MakeupRecommendationState());

  final GenerateMakeupRecommendation _generate;
  FaceAnalysis? _analysis;
  MakeupStyle? _style;
  int _operationEpoch = 0;

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
    final operation = ++_operationEpoch;
    state = const MakeupRecommendationState(
      status: MakeupRecommendationStatus.generating,
    );
    try {
      final recommendation = await _generate(analysis: analysis, style: style);
      if (mounted && operation == _operationEpoch) {
        state = MakeupRecommendationState(
          status: MakeupRecommendationStatus.success,
          recommendation: recommendation,
        );
      }
    } on RecommendationFailure catch (failure) {
      if (mounted && operation == _operationEpoch) {
        state = MakeupRecommendationState(
          status: MakeupRecommendationStatus.failure,
          message: failure.message,
          retryable: failure.retryable,
          failureType: failure.type,
        );
      }
    } catch (_) {
      if (mounted && operation == _operationEpoch) {
        state = const MakeupRecommendationState(
          status: MakeupRecommendationStatus.failure,
          message: 'Your makeup plan could not be created. Please try again.',
          retryable: true,
          failureType: RecommendationFailureType.server,
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

  void clear() {
    _operationEpoch += 1;
    _analysis = null;
    _style = null;
    state = const MakeupRecommendationState();
  }

  void restore(MakeupRecommendation recommendation) {
    _operationEpoch += 1;
    state = MakeupRecommendationState(
      status: MakeupRecommendationStatus.success,
      recommendation: recommendation,
    );
  }
}
