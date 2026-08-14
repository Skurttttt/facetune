import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/entities/tutorial_source_mode.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_repository.dart';
import 'tutorial_session_state.dart';

final tutorialSessionControllerProvider =
    StateNotifierProvider<TutorialSessionController, TutorialSessionState>((
      ref,
    ) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return TutorialSessionController(ref.watch(tutorialRepositoryProvider));
    });

/// Loads and resumes a persisted [TutorialSession] for a given source look.
///
/// This controller only reads. It never calls
/// [TutorialRepository.createSession] or any step-mutating repository
/// method — nothing in this phase generates a tutorial (see
/// ARCHITECTURE_NOTES.md). It exists so a later phase's entry point can
/// check "does a tutorial already exist for this look" (guide §12) without
/// re-deriving the resume/retry plumbing, and is not wired into any route
/// or page yet.
class TutorialSessionController extends StateNotifier<TutorialSessionState> {
  TutorialSessionController(this._repository)
    : super(const TutorialSessionState());

  final TutorialRepository _repository;
  int _operationEpoch = 0;
  _TutorialLookup? _lastLookup;

  /// Loads the existing tutorial session for the given source, if any.
  ///
  /// Superseded by any later call: an in-flight [load] whose result arrives
  /// after a subsequent [load]/[clear] is discarded, matching the
  /// operation-epoch guard used throughout this codebase (e.g.
  /// `MakeupKitLookController`).
  Future<void> load({
    required TutorialSourceMode sourceMode,
    required String analysisId,
    String? recommendationId,
    String? kitRecommendationId,
    required int generationNumber,
  }) async {
    final lookup = _TutorialLookup(
      sourceMode: sourceMode,
      analysisId: analysisId,
      recommendationId: recommendationId,
      kitRecommendationId: kitRecommendationId,
      generationNumber: generationNumber,
    );
    _lastLookup = lookup;
    final operation = ++_operationEpoch;
    state = const TutorialSessionState(status: TutorialSessionStatus.loading);
    try {
      final session = await _repository.loadExisting(
        sourceMode: lookup.sourceMode,
        analysisId: lookup.analysisId,
        recommendationId: lookup.recommendationId,
        kitRecommendationId: lookup.kitRecommendationId,
        generationNumber: lookup.generationNumber,
      );
      if (!mounted || operation != _operationEpoch) return;
      state = TutorialSessionState(
        status: TutorialSessionState.statusFor(session),
        session: session,
      );
    } on TutorialFailure catch (failure) {
      _fail(failure, operation: operation);
    } catch (_) {
      _fail(_unknownFailure, operation: operation);
    }
  }

  /// Repeats the most recent [load] call, supporting resume/retry after a
  /// failure without the caller needing to remember the original lookup
  /// arguments.
  Future<void> retry() async {
    final lookup = _lastLookup;
    if (lookup == null) return;
    await load(
      sourceMode: lookup.sourceMode,
      analysisId: lookup.analysisId,
      recommendationId: lookup.recommendationId,
      kitRecommendationId: lookup.kitRecommendationId,
      generationNumber: lookup.generationNumber,
    );
  }

  void clear() {
    _operationEpoch += 1;
    _lastLookup = null;
    state = const TutorialSessionState();
  }

  void _fail(TutorialFailure failure, {required int operation}) {
    if (!mounted || operation != _operationEpoch) return;
    state = TutorialSessionState(
      status: TutorialSessionStatus.failed,
      message: failure.message,
      retryable: failure.retryable,
      failureType: failure.type,
      technicalCode: failure.technicalCode,
    );
  }

  static const _unknownFailure = TutorialFailure(
    TutorialFailureType.server,
    'Your tutorial could not be loaded.',
    retryable: true,
  );
}

class _TutorialLookup {
  const _TutorialLookup({
    required this.sourceMode,
    required this.analysisId,
    required this.generationNumber,
    this.recommendationId,
    this.kitRecommendationId,
  });

  final TutorialSourceMode sourceMode;
  final String analysisId;
  final String? recommendationId;
  final String? kitRecommendationId;
  final int generationNumber;
}
