import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/custom_palette_providers.dart';
import '../../domain/entities/custom_palette_look.dart';
import '../../domain/repositories/custom_palette_gateway.dart';

enum CustomPaletteLookStatus { idle, generating, success, failure }

class CustomPaletteLookState {
  const CustomPaletteLookState({
    this.status = CustomPaletteLookStatus.idle,
    this.recommendation,
    this.preview,
    this.previousPreview,
    this.message,
    this.retryable = false,
  });

  final CustomPaletteLookStatus status;

  /// The frozen palette and plan. The same object for every variation of a look.
  final CustomPaletteRecommendation? recommendation;
  final CustomPaletteGeneratedPreview? preview;

  /// The look on screen before a variation started, kept if the variation fails.
  final CustomPaletteGeneratedPreview? previousPreview;
  final String? message;
  final bool retryable;

  bool get isGenerating => status == CustomPaletteLookStatus.generating;
}

final customPaletteLookControllerProvider =
    StateNotifierProvider<CustomPaletteLookController, CustomPaletteLookState>((
      ref,
    ) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return CustomPaletteLookController(
        ref.watch(customPaletteGatewayProvider),
      );
    });

/// Generates and restores looks from one frozen palette.
///
/// Holds no palette of its own: every call passes the recommendation the server
/// froze, so a variation has nothing it could change. Each logical preview request
/// has one operation id, kept while its outcome is unknown and replaced only when
/// the server says the request ended, so a retry can never be a second charge.
class CustomPaletteLookController
    extends StateNotifier<CustomPaletteLookState> {
  CustomPaletteLookController(
    this._gateway, {
    String Function()? newOperationId,
    Duration replayDelay = const Duration(seconds: 10),
    int maximumReplays = 12,
  }) : _newOperationId = newOperationId ?? const Uuid().v4,
       _replayDelay = replayDelay,
       _maximumReplays = maximumReplays,
       super(const CustomPaletteLookState());

  final CustomPaletteGateway _gateway;
  final String Function() _newOperationId;
  final Duration _replayDelay;
  final int _maximumReplays;
  String? _operationId;
  int _epoch = 0;

  /// Starts the first preview for [recommendation].
  ///
  /// The same palette already here is left alone, so returning to a finished look
  /// costs nothing.
  Future<void> start(CustomPaletteRecommendation recommendation) async {
    if (state.isGenerating) return;
    if (state.recommendation?.id == recommendation.id &&
        state.status == CustomPaletteLookStatus.success) {
      return;
    }
    _operationId = null;
    await _run(recommendation, previous: null);
  }

  /// Generates another look from the same frozen palette. A new charge, because
  /// it is a new request, and a palette that cannot have changed.
  Future<void> generateVariation() async {
    final recommendation = state.recommendation;
    if (state.isGenerating || recommendation == null) return;
    _operationId = null;
    await _run(
      recommendation,
      previous: state.preview ?? state.previousPreview,
    );
  }

  /// Continues the failed request, or starts a new one if it definitively ended.
  Future<void> retry() async {
    final recommendation = state.recommendation;
    if (state.isGenerating || recommendation == null) return;
    await _run(recommendation, previous: state.previousPreview);
  }

  /// Shows a look from History or Saved Looks, from its own frozen rows.
  void restore({
    required CustomPaletteRecommendation recommendation,
    required CustomPaletteGeneratedPreview preview,
  }) {
    if (recommendation.analysisId != preview.analysisId ||
        recommendation.id != preview.recommendationId) {
      throw ArgumentError('Look linkage is invalid.');
    }
    _epoch += 1;
    _operationId = null;
    state = CustomPaletteLookState(
      status: CustomPaletteLookStatus.success,
      recommendation: recommendation,
      preview: preview,
    );
  }

  void showPreviousResult() {
    final previous = state.previousPreview;
    if (previous == null) return;
    state = CustomPaletteLookState(
      status: CustomPaletteLookStatus.success,
      recommendation: state.recommendation,
      preview: previous,
    );
  }

  void clear() {
    _epoch += 1;
    _operationId = null;
    state = const CustomPaletteLookState();
  }

  Future<void> _run(
    CustomPaletteRecommendation recommendation, {
    required CustomPaletteGeneratedPreview? previous,
  }) async {
    final epoch = ++_epoch;
    final operationId = _operationId ??= _newOperationId();
    state = CustomPaletteLookState(
      status: CustomPaletteLookStatus.generating,
      recommendation: recommendation,
      previousPreview: previous,
    );
    var replays = 0;
    while (true) {
      try {
        final preview = await _gateway.generatePreview(
          recommendation: recommendation,
          operationId: operationId,
        );
        if (!mounted || epoch != _epoch) return;
        _operationId = null;
        state = CustomPaletteLookState(
          status: CustomPaletteLookStatus.success,
          recommendation: recommendation,
          preview: preview,
        );
        return;
      } on CustomPaletteFailure catch (failure) {
        if (!mounted || epoch != _epoch) return;
        // Still running, or unknown: wait and ask about the same operation.
        if (!failure.requestEnded && replays < _maximumReplays) {
          replays += 1;
          await Future<void>.delayed(_replayDelay);
          if (!mounted || epoch != _epoch) return;
          continue;
        }
        if (failure.requestEnded) _operationId = null;
        state = CustomPaletteLookState(
          status: CustomPaletteLookStatus.failure,
          recommendation: recommendation,
          previousPreview: previous,
          message: failure.message,
          retryable: failure.retryable,
        );
        return;
      } catch (_) {
        if (!mounted || epoch != _epoch) return;
        state = CustomPaletteLookState(
          status: CustomPaletteLookStatus.failure,
          recommendation: recommendation,
          previousPreview: previous,
          message: 'Your look could not be created. Please try again.',
          retryable: true,
        );
        return;
      }
    }
  }
}
