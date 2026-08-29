import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tutorial_v3_geometry.dart';
import '../../domain/entities/tutorial_v3_session_snapshot.dart';
import '../../domain/errors/tutorial_v3_failure.dart';
import '../../domain/repositories/tutorial_v3_planner.dart';
import '../../domain/repositories/tutorial_v3_repository.dart';
import '../../domain/services/tutorial_v3_geometry_coordinator.dart';
import '../../domain/services/tutorial_v3_timeouts.dart';
import 'tutorial_v3_session_state.dart';

/// Drives the hybrid tutorial flow.
///
/// ```text
/// open ─→ session ─→ plan (only if missing) ─→ show step 1
///                                                │
///                                    current geometry (cache first)
///                                                │
///                                    prefetch step 2 in background
/// ```
///
/// The whole plan is persisted upfront, because the text of every step has to
/// be readable immediately and planning is one call. Geometry is not: it is
/// one model call per step, so it is acquired for the step being read and,
/// speculatively, for the one after it.
///
/// Nothing here decides *what* a step teaches. The plan and every Step Spec
/// come from the server; this only decides when to ask for geometry.
class TutorialV3SessionController
    extends StateNotifier<TutorialV3SessionState> {
  TutorialV3SessionController({
    required TutorialV3Repository repository,
    required TutorialV3Planner planner,
    required TutorialV3GeometryCoordinator coordinator,
    TutorialV3Timeouts timeouts = const TutorialV3Timeouts(),
  }) : _repository = repository,
       _planner = planner,
       _coordinator = coordinator,
       _timeouts = timeouts,
       super(const TutorialV3SessionState());

  final TutorialV3Repository _repository;
  final TutorialV3Planner _planner;
  final TutorialV3GeometryCoordinator _coordinator;
  final TutorialV3Timeouts _timeouts;

  /// Guards against a slow response landing after the user has moved on.
  ///
  /// Every state write checks it, so paging quickly through steps cannot leave
  /// step 2's geometry rendered on step 4.
  int _epoch = 0;

  /// What this tutorial was opened with, kept so a retry after a failed open
  /// has something to retry. Before the first success there is no session id
  /// to reopen by, and a "Try again" that silently did nothing was its own
  /// small version of the bug this class now guards against.
  TutorialV3EntryPoint? _entry;

  /// Opens the tutorial for a premium preview, creating the session if it does
  /// not exist.
  ///
  /// [entry] names the preview and nothing else; everything the tutorial is
  /// built from is resolved server-side.
  ///
  /// Idempotent at every level: the canonical preview is the session's natural
  /// key, a persisted plan is reused rather than regenerated, and ready
  /// geometry is reused rather than re-mapped.
  Future<void> open(TutorialV3EntryPoint entry) async {
    _entry = entry;
    final epoch = ++_epoch;
    state = const TutorialV3SessionState(phase: TutorialV3Phase.opening);
    try {
      final snapshot = await _bounded(
        () => _repository.openSession(entry),
        limit: _timeouts.session,
        context: 'openSession',
        fallback: _openFallback,
      );
      await _afterLoad(snapshot, epoch);
    } on TutorialV3Failure catch (failure) {
      _fail(failure, epoch);
    } on Object catch (error) {
      // The outermost net. Everything below is bounded and translated, so
      // reaching here means a path was missed — and a missed path must still
      // end in a visible, retryable error rather than a spinner that never
      // stops.
      _logUnexpected('open', error);
      _fail(const TutorialV3Failure(_openFallback), epoch);
    }
  }

  /// Reopens an existing tutorial by id, for history and resume entry points.
  Future<void> reopen(String sessionId) async {
    final epoch = ++_epoch;
    state = const TutorialV3SessionState(phase: TutorialV3Phase.opening);
    try {
      final snapshot = await _bounded(
        () => _repository.findSessionById(sessionId),
        limit: _timeouts.session,
        context: 'findSessionById',
        fallback: _openFallback,
      );
      if (snapshot == null) {
        _fail(
          const TutorialV3Failure(
            'This tutorial could not be found.',
            kind: TutorialV3FailureKind.notFound,
            retryable: false,
          ),
          epoch,
        );
        return;
      }
      await _afterLoad(snapshot, epoch);
    } on TutorialV3Failure catch (failure) {
      _fail(failure, epoch);
    } on Object catch (error) {
      _logUnexpected('reopen', error);
      _fail(const TutorialV3Failure(_openFallback), epoch);
    }
  }

  /// Moves to [stepIndex] and resolves its overlay.
  ///
  /// A step whose geometry is already cached renders immediately — no loading
  /// state is shown for a step the user has already seen.
  Future<void> goToStep(int stepIndex) async {
    final loaded = state.loaded;
    if (loaded == null) return;
    if (loaded.stepAt(stepIndex) == null) return;
    await _showStep(loaded, stepIndex, ++_epoch);
  }

  Future<void> next() =>
      state.canGoNext ? goToStep(state.currentStepIndex + 1) : Future.value();

  Future<void> previous() => state.canGoPrevious
      ? goToStep(state.currentStepIndex - 1)
      : Future.value();

  /// Retries the current step's overlay after a failure.
  ///
  /// The step's bounded attempt budget is enforced server-side, so a step that
  /// has exhausted it reports that rather than looping.
  Future<void> retryGeometry() async {
    final loaded = state.loaded;
    if (loaded == null) return;
    await _showStep(loaded, state.currentStepIndex, ++_epoch);
  }

  /// Retries signing the selfie and the target reference.
  Future<void> retryImages() async {
    final loaded = state.loaded;
    if (loaded == null) return;
    state = state.copyWith(imagesPhase: TutorialV3ImagesPhase.loading);
    await _loadImages(loaded, _epoch);
  }

  /// Retries opening or planning after a tutorial-level failure.
  ///
  /// A session that was reached at least once is reopened by id. One that
  /// never was — the open call itself failed, so there is no id — is opened
  /// again from the entry point it was routed with.
  Future<void> retryOpen() async {
    final sessionId = state.snapshot?.sessionId;
    if (sessionId != null) {
      await reopen(sessionId);
      return;
    }
    final entry = _entry;
    if (entry == null) return;
    await open(entry);
  }

  Future<void> _afterLoad(TutorialV3SessionSnapshot snapshot, int epoch) async {
    if (!_isCurrent(epoch)) return;

    // A session this build cannot read is reported, never reinterpreted.
    if (snapshot is TutorialV3IncompatibleSession) {
      state = TutorialV3SessionState(
        phase: TutorialV3Phase.failed,
        snapshot: snapshot,
        message:
            'This tutorial was created by a different version of FaceTune and '
            'cannot be opened here.',
      );
      return;
    }

    var loaded = snapshot as TutorialV3LoadedSession;
    if (!loaded.hasPlan) {
      state = TutorialV3SessionState(
        phase: TutorialV3Phase.planning,
        snapshot: loaded,
      );
      await _bounded(
        () => _planner.plan(sessionId: loaded.sessionId),
        limit: _timeouts.ai,
        context: 'plan',
        fallback: 'This tutorial could not be prepared. Please try again.',
      );
      if (!_isCurrent(epoch)) return;

      // The plan is read back from the database rather than trusted from the
      // planner's response, and anything cached under the old step numbering
      // is dropped: a replan can change what step 2 teaches.
      _coordinator.invalidateSession(loaded.sessionId);
      final replanned = await _bounded(
        () => _repository.findSessionById(loaded.sessionId),
        limit: _timeouts.session,
        context: 'findSessionById.replanned',
        fallback: 'This tutorial could not be prepared. Please try again.',
      );
      if (!_isCurrent(epoch)) return;
      if (replanned is! TutorialV3LoadedSession || !replanned.hasPlan) {
        _fail(
          const TutorialV3Failure(
            'This tutorial could not be prepared. Please try again.',
            kind: TutorialV3FailureKind.generation,
          ),
          epoch,
        );
        return;
      }
      loaded = replanned;
    }

    // Signed before the first step is shown so a cached overlay and its
    // selfie appear together rather than in two paints.
    await _loadImages(loaded, epoch);
    if (!_isCurrent(epoch)) return;
    await _showStep(loaded, loaded.steps.first.stepIndex, epoch);
  }

  Future<void> _showStep(
    TutorialV3LoadedSession loaded,
    int stepIndex,
    int epoch,
  ) async {
    final step = loaded.stepAt(stepIndex);
    if (step == null) return;

    // The final look reuses the canonical premium preview. No mapping call is
    // made for it at all.
    if (step.isFinalLook) {
      if (!_isCurrent(epoch)) return;
      state = _stepState(
        loaded,
        stepIndex,
        TutorialV3StepGeometryPhase.notRequired,
      );
      return;
    }

    final cached = _cachedOrNull(loaded, stepIndex);
    if (cached != null) {
      if (!_isCurrent(epoch)) return;
      state = _stepState(
        loaded,
        stepIndex,
        TutorialV3StepGeometryPhase.ready,
        geometry: cached,
      );
      await _prefetchAfter(loaded, stepIndex, epoch);
      return;
    }

    if (!_isCurrent(epoch)) return;
    state = _stepState(loaded, stepIndex, TutorialV3StepGeometryPhase.loading);

    try {
      final geometry = await _bounded(
        () =>
            _coordinator.ensureGeometry(session: loaded, stepIndex: stepIndex),
        limit: _timeouts.ai,
        context: 'ensureGeometry',
        fallback: 'This step could not be prepared. Please try again.',
      );
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        geometryPhase: geometry == null
            ? TutorialV3StepGeometryPhase.notRequired
            : TutorialV3StepGeometryPhase.ready,
        geometry: geometry,
        clearGeometry: geometry == null,
        clearMessage: true,
        retryable: false,
      );
    } on TutorialV3Failure catch (failure) {
      if (!_isCurrent(epoch)) return;
      // The tutorial stays open and readable. Only the overlay is missing, and
      // a missing overlay is always preferable to a wrong one.
      state = state.copyWith(
        geometryPhase: TutorialV3StepGeometryPhase.failed,
        clearGeometry: true,
        message: failure.message,
        retryable: failure.retryable,
      );
      return;
    }

    await _prefetchAfter(loaded, stepIndex, epoch);
  }

  /// Warms the next step.
  ///
  /// Awaited rather than detached so the work is observable and cannot outlive
  /// a disposed controller unnoticed. The state has already been published as
  /// `ready` by this point, so the screen is interactive while this runs, and
  /// a caller that moves on simply invalidates the epoch.
  /// Builds the state for one step, carrying the tutorial-level image state
  /// across the switch.
  ///
  /// The images belong to the session, not to a step, so paging must not reset
  /// them back to loading and make the selfie flicker on every Next.
  TutorialV3SessionState _stepState(
    TutorialV3LoadedSession loaded,
    int stepIndex,
    TutorialV3StepGeometryPhase geometryPhase, {
    TutorialV3Geometry? geometry,
  }) => TutorialV3SessionState(
    phase: TutorialV3Phase.ready,
    snapshot: loaded,
    currentStepIndex: stepIndex,
    geometryPhase: geometryPhase,
    geometry: geometry,
    imagesPhase: state.imagesPhase,
    images: state.images,
  );

  /// Signs the original selfie and the canonical preview.
  ///
  /// Failure here is not a tutorial failure: the instruction text stays
  /// readable and the image areas offer a retry, because a signed URL is a
  /// transient thing to lose.
  Future<void> _loadImages(TutorialV3LoadedSession loaded, int epoch) async {
    try {
      final images = await _bounded(
        () => _repository.loadImages(loaded.session),
        limit: _timeouts.session,
        context: 'loadImages',
        fallback: 'Your photo could not be loaded.',
      );
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(
        imagesPhase: TutorialV3ImagesPhase.ready,
        images: images,
      );
    } on TutorialV3Failure {
      if (!_isCurrent(epoch)) return;
      state = state.copyWith(imagesPhase: TutorialV3ImagesPhase.failed);
    }
  }

  /// The cache read, which must not be able to throw its way out of a step.
  ///
  /// Treating an unreadable cache as a miss is the safe degradation: the step
  /// is mapped normally instead of taking the whole screen down.
  TutorialV3Geometry? _cachedOrNull(
    TutorialV3LoadedSession loaded,
    int stepIndex,
  ) {
    try {
      return _coordinator.cached(session: loaded, stepIndex: stepIndex);
    } on Object catch (error) {
      _logUnexpected('cachedGeometry', error);
      return null;
    }
  }

  /// Warms the next step, and never lets that disturb this one.
  ///
  /// The coordinator already swallows a failed prefetch, so this catch is the
  /// second line: speculative work must not be able to turn the step the user
  /// is reading into an error, whatever it throws. Bounded too, so a hung
  /// background call cannot leave `goToStep` pending forever.
  Future<void> _prefetchAfter(
    TutorialV3LoadedSession loaded,
    int stepIndex,
    int epoch,
  ) async {
    if (!_isCurrent(epoch)) return;
    try {
      await _coordinator
          .prefetch(session: loaded, currentStepIndex: stepIndex)
          .timeout(_timeouts.ai);
    } on Object catch (error) {
      _logUnexpected('prefetch', error);
    }
  }

  void _fail(TutorialV3Failure failure, int epoch) {
    if (!_isCurrent(epoch)) return;
    state = state.copyWith(
      phase: TutorialV3Phase.failed,
      message: failure.message,
      retryable: failure.retryable,
      geometryPhase: TutorialV3StepGeometryPhase.notRequired,
      clearGeometry: true,
    );
  }

  bool _isCurrent(int epoch) => mounted && epoch == _epoch;

  /// Runs one asynchronous step of the flow so that it always terminates.
  ///
  /// This is the error boundary. Three outcomes, and only three:
  ///
  /// - the value, if [run] completes in time;
  /// - the original [TutorialV3Failure], rethrown untouched, so a server's own
  ///   wording, its kind and its retry verdict survive — the data layer stays
  ///   the authority on failures it understands;
  /// - a [TutorialV3Failure] this method constructs, for a timeout or for any
  ///   other exception.
  ///
  /// That last case is the point. `PostgrestException`, `SocketException`, a
  /// `TypeError` from a malformed row — none of them are things this screen can
  /// describe, and none of them were being caught, so they escaped and left the
  /// state exactly as it was: `opening`, forever. Converting them here keeps
  /// the translation out of the data sources, which would otherwise need a
  /// branch per Postgres code to achieve the same thing less well.
  ///
  /// [fallback] is what the user reads. The exception's own message never is —
  /// it can carry SQL, RPC names, URLs or tokens. [context] is a fixed label
  /// for the debug log and is never shown.
  Future<T> _bounded<T>(
    Future<T> Function() run, {
    required Duration limit,
    required String context,
    required String fallback,
  }) async {
    try {
      return await run().timeout(limit);
    } on TutorialV3Failure catch (failure) {
      // Logged as well as rethrown. A translated domain failure was the one
      // case that left no trace at all: it was handled correctly at every
      // layer and reported correctly to the user, so a real device could fail
      // in one second with an empty console. The stage is [context], which
      // says whether this was the entry RPC, planning, geometry or signing.
      _logFailure(context, failure);
      rethrow;
    } on TimeoutException {
      throw const TutorialV3Failure(
        'This is taking longer than expected. Please try again.',
        kind: TutorialV3FailureKind.timeout,
      );
    } on Object catch (error) {
      _logUnexpected(context, error);
      throw TutorialV3Failure(fallback);
    }
  }

  /// Records that something unexpected happened, without recording what.
  ///
  /// The type and the call site are enough to find the bug; the message is not
  /// ours to trust, and in debug builds it would be printed to a console. Debug
  /// only, so nothing reaches a release log at all.
  void _logUnexpected(String context, Object error) {
    if (!kDebugMode) return;
    debugPrint(
      '[tutorial_v3] $context failed: unexpected ${error.runtimeType}',
    );
  }

  /// Records a failure the app *does* understand, with the stage it came from.
  ///
  /// The message is the server's own and is already on screen, so nothing new
  /// is disclosed by recording it alongside the stage — which is the part that
  /// says whether the entry RPC, the planner, the geometry mapper or image
  /// signing produced it.
  void _logFailure(String context, TutorialV3Failure failure) {
    if (!kDebugMode) return;
    debugPrint(
      '[tutorial_v3] $context failed: kind=${failure.kind.name} '
      'retryable=${failure.retryable}',
    );
  }

  /// Shown when opening fails for a reason the app cannot describe.
  static const _openFallback =
      'Your tutorial could not be opened. Please try again.';
}
