import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../../makeup_kit/domain/entities/kit_generated_preview.dart';
import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../preview/domain/entities/generated_preview.dart';
import '../../../recommendation/domain/entities/makeup_recommendation.dart';
import '../../data/providers/tutorial_providers.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_source_mode.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_repository.dart';
import '../../domain/usecases/get_or_create_tutorial_session.dart';
import 'tutorial_session_state.dart';

final tutorialSessionControllerProvider =
    StateNotifierProvider<TutorialSessionController, TutorialSessionState>((
      ref,
    ) {
      ref.watch(authControllerProvider.select((state) => state.user?.id));
      return TutorialSessionController(
        ref.watch(tutorialRepositoryProvider),
        ref.watch(getOrCreateTutorialSessionProvider),
      );
    });

/// Loads, resumes, and (ST-8) creates a persisted [TutorialSession] for a
/// given source look.
///
/// Two phases, both explicit:
/// - `prepareForRecommendation`/`prepareForKitRecommendation` — called by
///   the calling page (`PreviewResultPage` / `MakeupKitRecommendationEntryPage`)
///   right before pushing `/tutorial`, the same "restore ambient state,
///   then navigate" pattern already used for Saved Looks/History (see
///   `history_page.dart`'s `_open`/`_openKit`). This only *checks* for an
///   existing session (`TutorialRepository.loadExisting`) — it never
///   creates one. It also remembers the source objects so [generate] can
///   use them later without the caller passing them again.
/// - `generate` — called only from an explicit "Generate My Tutorial" tap
///   in `TutorialEntryPage`, once the user has seen there's nothing to
///   resume. This is what roadmap ST-8 task 7 means by "regeneration must
///   be an explicit user action": nothing in this controller ever creates
///   a session on its own initiative.
class TutorialSessionController extends StateNotifier<TutorialSessionState> {
  TutorialSessionController(this._repository, this._getOrCreate)
    : super(const TutorialSessionState());

  final TutorialRepository _repository;
  final GetOrCreateTutorialSession _getOrCreate;
  int _operationEpoch = 0;

  /// What [generate] will run when explicitly tapped — set by
  /// [prepareForRecommendation]/[prepareForKitRecommendation], but never
  /// run by them. Kept separate from [_lastRun] so a failed *check* only
  /// ever retries as a check (see [_lastRun]'s doc comment for why
  /// conflating the two would be a bug, not just an inefficiency).
  Future<TutorialSession> Function()? _pendingGenerate;

  /// Whatever [_run] actually executed most recently — the operation
  /// [retry] replays. Set inside [_run] itself, not by the public methods
  /// that call it, specifically so [retry] repeats *what failed*: if the
  /// initial existing-session check fails, retry must re-check, not
  /// silently escalate to creating a session the user never asked for
  /// (roadmap ST-8 task 7 — regeneration/creation must be an explicit
  /// user action, and a failed check is not that).
  Future<TutorialSession?> Function()? _lastRun;
  String? _sourceOriginalImageUrl;

  Future<void> prepareForRecommendation({
    required MakeupRecommendation recommendation,
    required GeneratedPreview preview,
  }) {
    _sourceOriginalImageUrl = preview.originalImageUrl;
    _pendingGenerate = () => _getOrCreate.forRecommendation(
      recommendation: recommendation,
      preview: preview,
    );
    return _run(
      () => _repository.loadExisting(
        sourceMode: TutorialSourceMode.standardRecommendation,
        analysisId: recommendation.analysisId,
        recommendationId: recommendation.id,
        generationNumber: preview.generationNumber,
      ),
    );
  }

  Future<void> prepareForKitRecommendation({
    required KitMakeupRecommendation recommendation,
    required KitGeneratedPreview preview,
  }) {
    _sourceOriginalImageUrl = preview.originalImageUrl;
    _pendingGenerate = () => _getOrCreate.forKitRecommendation(
      recommendation: recommendation,
      preview: preview,
    );
    return _run(
      () => _repository.loadExisting(
        sourceMode: TutorialSourceMode.makeupKit,
        analysisId: recommendation.analysisId,
        kitRecommendationId: recommendation.id,
        generationNumber: preview.generationNumber,
      ),
    );
  }

  /// Plans and persists a new tutorial session for whichever source was
  /// last passed to [prepareForRecommendation]/[prepareForKitRecommendation].
  /// A no-op if neither has been called. Safe to call even if a session
  /// already exists — [GetOrCreateTutorialSession] resumes it instead of
  /// creating a duplicate (roadmap ST-8 tasks 2/3/5).
  Future<void> generate() async {
    final operation = _pendingGenerate;
    if (operation == null) return;
    await _run(operation);
  }

  /// Repeats whichever operation [_run] executed most recently — see
  /// [_lastRun]'s doc comment for why that must not be conflated with
  /// [_pendingGenerate].
  Future<void> retry() async {
    final operation = _lastRun;
    if (operation == null) return;
    await _run(operation);
  }

  /// Generates one missing step's Result image via the secure backend
  /// (`generate-tutorial-step`, ST-9), then merges the updated step into
  /// the current session in place.
  ///
  /// A no-op — not an error — if: no session is loaded; another step is
  /// already generating (one at a time, matching the app-level busy-guard
  /// convention used elsewhere in this controller); [tutorialStepId] does
  /// not belong to the loaded session; or that step already has a result
  /// (roadmap ST-10 task 3 — never regenerate an already-valid step). The
  /// caller (`TutorialStepViewer`) is expected to only ever offer this
  /// action for a step where it is actually applicable, so these checks
  /// are a defensive backstop, not the primary gate.
  ///
  /// Deliberately does not reload the whole session afterward (unlike
  /// [_run]'s operations) — it merges the one updated step returned by the
  /// backend into the session snapshot already held in [state]. This means
  /// [TutorialSession.generationStatus] can go briefly stale until the next
  /// full [prepareForRecommendation]/[prepareForKitRecommendation] reload,
  /// which is an accepted tradeoff since nothing in this feature's UI
  /// currently renders that field directly — see ARCHITECTURE_NOTES.md.
  Future<void> generateStep(String tutorialStepId) async {
    final session = state.session;
    if (session == null || state.generatingStepId != null) return;
    final targetIndex = session.steps.indexWhere(
      (step) => step.id == tutorialStepId,
    );
    if (targetIndex == -1) return;
    if (session.steps[targetIndex].resultImageUrl != null) return;

    final operation = ++_operationEpoch;
    state = TutorialSessionState(
      status: state.status,
      session: session,
      generatingStepId: tutorialStepId,
      originalImageUrl: _sourceOriginalImageUrl,
    );
    try {
      final updatedStep = await _repository.generateStepResult(
        tutorialStepId: tutorialStepId,
      );
      if (!mounted || operation != _operationEpoch) return;
      final updatedSteps = [
        for (final step in session.steps)
          if (step.id == updatedStep.id) updatedStep else step,
      ];
      state = TutorialSessionState(
        status: state.status,
        session: _withSteps(session, updatedSteps),
        originalImageUrl: _sourceOriginalImageUrl,
      );
    } on TutorialFailure catch (failure) {
      if (!mounted || operation != _operationEpoch) return;
      state = TutorialSessionState(
        status: state.status,
        session: session,
        stepFailureStepId: tutorialStepId,
        stepFailureMessage: failure.message,
        stepFailureRetryable: failure.retryable,
        originalImageUrl: _sourceOriginalImageUrl,
      );
    } catch (_) {
      if (!mounted || operation != _operationEpoch) return;
      state = TutorialSessionState(
        status: state.status,
        session: session,
        stepFailureStepId: tutorialStepId,
        stepFailureMessage: 'This step could not be generated.',
        stepFailureRetryable: true,
        originalImageUrl: _sourceOriginalImageUrl,
      );
    }
  }

  static TutorialSession _withSteps(
    TutorialSession session,
    List<TutorialStep> steps,
  ) => TutorialSession(
    id: session.id,
    userId: session.userId,
    sourceMode: session.sourceMode,
    sourceAnalysisId: session.sourceAnalysisId,
    sourceRecommendationId: session.sourceRecommendationId,
    sourceKitResultId: session.sourceKitResultId,
    styleCode: session.styleCode,
    generationNumber: session.generationNumber,
    totalSteps: session.totalSteps,
    generationStatus: session.generationStatus,
    promptVersion: session.promptVersion,
    tutorialModel: session.tutorialModel,
    tutorialImageSize: session.tutorialImageSize,
    steps: List.unmodifiable(steps),
    createdAt: session.createdAt,
    updatedAt: session.updatedAt,
  );

  /// Resets the current session back to a pre-generation state (see
  /// `TutorialRepository.resetForRegeneration`) so the user can redo image
  /// generation from scratch, one step at a time, via the same explicit
  /// "Generate this step" flow ST-10 already built (roadmap ST-12 tasks
  /// 3–5). A no-op — not an error — if no session is loaded, a session-
  /// level operation is already in flight, or a step is currently
  /// generating; the caller (`TutorialEntryPage`) is expected to only
  /// offer this action when it's actually applicable, matching the
  /// pattern every other explicit action in this controller already
  /// follows.
  ///
  /// Goes through [_run] like [prepareForRecommendation]/[generate] — a
  /// whole-session reset is comparable in scope to those operations
  /// (touches the session and every non-final step), so it's reasonable
  /// for it to briefly own the same whole-page loading state, unlike
  /// [generateStep]'s deliberately narrower, non-blocking per-step state.
  Future<void> regenerate() async {
    final session = state.session;
    if (session == null) return;
    if (state.status == TutorialSessionStatus.loading ||
        state.generatingStepId != null) {
      return;
    }
    await _run(
      () => _repository.resetForRegeneration(tutorialSessionId: session.id),
    );
  }

  void clear() {
    _operationEpoch += 1;
    _pendingGenerate = null;
    _lastRun = null;
    _sourceOriginalImageUrl = null;
    state = const TutorialSessionState();
  }

  Future<void> _run(Future<TutorialSession?> Function() operation) async {
    if (state.status == TutorialSessionStatus.loading) return;
    _lastRun = operation;
    final currentOperation = ++_operationEpoch;
    state = const TutorialSessionState(status: TutorialSessionStatus.loading);
    try {
      final session = await operation();
      if (!mounted || currentOperation != _operationEpoch) return;
      state = TutorialSessionState(
        status: TutorialSessionState.statusFor(session),
        session: session,
        originalImageUrl: _sourceOriginalImageUrl,
      );
    } on TutorialFailure catch (failure) {
      _fail(failure, operation: currentOperation);
    } catch (_) {
      _fail(_unknownFailure, operation: currentOperation);
    }
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
