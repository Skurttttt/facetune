import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../preview/domain/errors/preview_failure.dart';
import '../../data/providers/makeup_kit_look_providers.dart';
import '../../domain/entities/kit_generated_preview.dart';
import '../../domain/entities/kit_makeup_recommendation.dart';
import '../../domain/repositories/makeup_kit_look_repository.dart';
import 'makeup_kit_look_state.dart';

final makeupKitLookControllerProvider =
    StateNotifierProvider<MakeupKitLookController, MakeupKitLookState>((ref) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return MakeupKitLookController(
        ref.watch(makeupKitLookRepositoryProvider),
      );
    });

class MakeupKitLookController extends StateNotifier<MakeupKitLookState> {
  MakeupKitLookController(this._repository) : super(const MakeupKitLookState());

  final MakeupKitLookRepository _repository;
  String? _analysisId;
  String? _styleCode;
  KitMakeupRecommendation? _recommendation;
  int _operationEpoch = 0;

  Future<void> generate({
    required String analysisId,
    required String styleCode,
  }) async {
    if (state.isGenerating) return;
    _analysisId = analysisId;
    _styleCode = styleCode;
    _recommendation = null;
    final operation = ++_operationEpoch;
    state = const MakeupKitLookState(
      status: MakeupKitLookStatus.generatingRecommendation,
    );
    try {
      final recommendation = await _repository.generateRecommendation(
        analysisId: analysisId,
        styleCode: styleCode,
      );
      if (!mounted || operation != _operationEpoch) return;
      _recommendation = recommendation;
      state = MakeupKitLookState(
        status: MakeupKitLookStatus.generatingPreview,
        recommendation: recommendation,
      );
      await _generatePreview(recommendation, operation: operation);
    } on PreviewFailure catch (failure) {
      _fail(failure, operation: operation);
    } catch (_) {
      _fail(_unknownFailure, operation: operation);
    }
  }

  Future<void> generateVariation() async {
    if (state.isGenerating) return;
    final recommendation = _recommendation;
    if (recommendation == null) {
      await retry();
      return;
    }
    final operation = ++_operationEpoch;
    final previous = state.preview ?? state.previousPreview;
    state = MakeupKitLookState(
      status: MakeupKitLookStatus.generatingPreview,
      recommendation: recommendation,
      previousPreview: previous,
    );
    await _generatePreview(
      recommendation,
      operation: operation,
      previousPreview: previous,
    );
  }

  Future<void> retry() async {
    if (state.isGenerating) return;
    final recommendation = _recommendation;
    if (recommendation != null) {
      await generateVariation();
      return;
    }
    final analysisId = _analysisId;
    final styleCode = _styleCode;
    if (analysisId != null && styleCode != null) {
      await generate(analysisId: analysisId, styleCode: styleCode);
    }
  }

  void showPreviousResult() {
    final previous = state.previousPreview;
    if (previous == null) return;
    state = MakeupKitLookState(
      status: MakeupKitLookStatus.success,
      recommendation: _recommendation,
      preview: previous,
    );
  }

  void clear() {
    _operationEpoch += 1;
    _analysisId = null;
    _styleCode = null;
    _recommendation = null;
    state = const MakeupKitLookState();
  }

  Future<void> _generatePreview(
    KitMakeupRecommendation recommendation, {
    required int operation,
    KitGeneratedPreview? previousPreview,
  }) async {
    try {
      final preview = await _repository.generatePreview(
        recommendation: recommendation,
      );
      if (mounted && operation == _operationEpoch) {
        state = MakeupKitLookState(
          status: MakeupKitLookStatus.success,
          recommendation: recommendation,
          preview: preview,
        );
      }
    } on PreviewFailure catch (failure) {
      _fail(failure, operation: operation, previousPreview: previousPreview);
    } catch (_) {
      _fail(
        _unknownFailure,
        operation: operation,
        previousPreview: previousPreview,
      );
    }
  }

  void _fail(
    PreviewFailure failure, {
    required int operation,
    KitGeneratedPreview? previousPreview,
  }) {
    if (!mounted || operation != _operationEpoch) return;
    state = MakeupKitLookState(
      status: MakeupKitLookStatus.failure,
      recommendation: _recommendation,
      previousPreview: previousPreview,
      message: failure.message,
      retryable: failure.retryable,
      failureType: failure.type,
      technicalCode: failure.technicalCode,
    );
  }

  static const _unknownFailure = PreviewFailure(
    PreviewFailureType.server,
    'Your kit-based look could not be generated.',
    retryable: true,
  );
}
