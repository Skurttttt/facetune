import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/canonical_preview_ref.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/errors/tutorial_failure.dart';
import '../../domain/repositories/tutorial_step_repository.dart';
import '../../domain/usecases/resolve_tutorial_manifest.dart';
import 'tutorial_state.dart';

/// Orchestrates a tutorial so that paid work happens only on intent.
///
/// Every expensive operation here is reachable only through an explicit method
/// call. Nothing runs from a constructor, a getter, or a `build`, so watching
/// this controller — however many times a widget tree rebuilds — cannot cost
/// anything. That is the single most important property of this class, and the
/// reason `open()` exists rather than eager loading.
///
/// Three independent guards stop one intent becoming several billable calls:
///
///   * `_inFlight` coalesces concurrent requests for the same category, so a
///     double tap awaits one future rather than starting two.
///   * A ready step short-circuits before any request is made.
///   * `_opened` makes a repeated `open()` a no-op, so navigating back and
///     forward re-reads nothing.
///
/// The server enforces its own duplicate protection as well. Both layers are
/// deliberate: this one avoids the round trip, that one is the authority.
class TutorialController extends StateNotifier<TutorialViewState> {
  TutorialController({
    required ResolveTutorialManifest resolveManifest,
    required TutorialStepRepository steps,
  }) : _resolveManifest = resolveManifest,
       _steps = steps,
       super(const TutorialViewState());

  final ResolveTutorialManifest _resolveManifest;
  final TutorialStepRepository _steps;

  /// In-flight generations keyed by category. The single mechanism that turns
  /// N concurrent requests for one step into one paid call.
  final Map<TutorialCategory, Future<TutorialStep>> _inFlight =
      <TutorialCategory, Future<TutorialStep>>{};

  CanonicalPreviewRef? _preview;
  bool _opened = false;
  Future<void>? _opening;

  /// How many automatic retries a failed generation gets before the user must
  /// ask again. One, so a transient blip self-heals but a persistent failure
  /// cannot loop at cost.
  static const _maximumAutomaticRetries = 1;
  final Map<TutorialCategory, int> _automaticRetries =
      <TutorialCategory, int>{};

  /// Opens the tutorial for [preview].
  ///
  /// Safe to call repeatedly: a second call for the same preview returns the
  /// same future while opening, and does nothing once opened. This is what
  /// makes route rebuilds, app resume, and back-then-reopen free.
  ///
  /// Manifest analysis happens at most once, and only when no accepted manifest
  /// already exists — the reuse decision lives in [ResolveTutorialManifest].
  Future<void> open(CanonicalPreviewRef preview) {
    if (_preview != null && _preview != preview) {
      // A different canonical preview is a different tutorial. Reset rather
      // than blending two sessions' state together.
      _reset();
    }
    _preview = preview;
    if (_opened) return Future<void>.value();
    return _opening ??= _open(preview).whenComplete(() => _opening = null);
  }

  Future<void> _open(CanonicalPreviewRef preview) async {
    state = state.copyWith(
      status: TutorialStatus.opening,
      clearMessage: true,
      sessionExpired: false,
    );
    try {
      final beforeAnalyses = state.telemetry.manifestAnalyses;
      state = state.copyWith(status: TutorialStatus.analyzingManifest);
      final session = await _resolveManifest(preview);
      if (!mounted) return;
      _opened = true;
      unawaited(_resolveReadyGuidelines(session));
      _adopt(
        session,
        // The resolver reuses an accepted manifest when one exists, so this
        // counts an open, not necessarily a paid analysis. The repository layer
        // is where a genuine analysis is observable.
        telemetry: state.telemetry.copyWith(
          manifestAnalyses: beforeAnalyses + 1,
        ),
      );
    } on TutorialFailure catch (failure) {
      if (!mounted) return;
      _fail(failure);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(
        status: TutorialStatus.failed,
        message: 'This tutorial could not be opened.',
      );
    }
  }

  void _adopt(TutorialSession session, {TutorialUsageTelemetry? telemetry}) {
    if (session.hasKitPreviewMismatch) {
      state = state.copyWith(
        status: TutorialStatus.kitPreviewMismatch,
        session: session,
        message:
            'This look uses makeup that is not in your kit yet, so it cannot '
            'be turned into a tutorial.',
        retryable: false,
        telemetry: telemetry,
      );
      return;
    }
    state = state.copyWith(
      status: TutorialStatus.ready,
      session: session,
      currentIndex: _resumeIndex(session),
      clearMessage: true,
      retryable: true,
      telemetry: telemetry,
    );
  }

  /// Where a reopened tutorial should land.
  ///
  /// The first step that is not yet drawn, because that is where the user
  /// stopped: everything before it is done, and everything after it depends on
  /// it. When every step is ready the tutorial is complete, so it reopens on
  /// the last step rather than sending the user back to the beginning.
  ///
  /// Deliberately derived from persisted step state rather than remembered
  /// locally, so it survives an app relaunch with no extra storage.
  int _resumeIndex(TutorialSession session) {
    final categories = session.includedCategories;
    if (categories.isEmpty) return 0;
    for (var index = 0; index < categories.length; index += 1) {
      if (session.stepFor(categories[index])?.isReady != true) return index;
    }
    return categories.length - 1;
  }

  /// Generates the current step if it is not already rendered.
  ///
  /// Returns without any request when the step is ready — the common case on a
  /// reopen — and coalesces onto an existing request when one is in flight.
  Future<void> generateCurrentStep() async {
    final category = state.currentCategory;
    if (category == null) return;
    await _generate(category);
  }

  /// Moves to [index] and ensures that step exists.
  ///
  /// Navigation itself never regenerates: if the destination step is already
  /// ready, this only changes the index.
  Future<void> goToStep(int index) async {
    if (index < 0 || index >= state.stepCount) return;
    state = state.copyWith(currentIndex: index, clearMessage: true);
    await generateCurrentStep();
  }

  Future<void> next() => goToStep(state.currentIndex + 1);

  Future<void> previous() => goToStep(state.currentIndex - 1);

  /// Generates at most the single next step, and only when it is missing.
  ///
  /// Depth is one by construction: it reads [TutorialViewState.nextCategory],
  /// which cannot see past the immediate next step, so there is no way to
  /// express a deeper prefetch. Failures are swallowed — a prefetch is an
  /// optimisation, and surfacing its error would confuse a user who never
  /// asked for it.
  Future<void> prefetchNext() async {
    final next = state.nextCategory;
    if (next == null) return;
    if (state.session?.stepFor(next)?.isReady == true) return;
    if (_inFlight.containsKey(next)) return;
    try {
      await _generate(next, isPrefetch: true);
    } on TutorialFailure catch (_) {
      // Deliberately ignored.
    }
  }

  /// Regenerates the current step at the user's explicit request.
  ///
  /// Separate from [generateCurrentStep] because it is the one path that
  /// deliberately spends money on a step that already exists. Nothing calls it
  /// automatically — not a retry, not a rebuild, not navigation.
  Future<void> regenerateCurrentStep() async {
    final category = state.currentCategory;
    if (category == null) return;
    if (_inFlight.containsKey(category)) {
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(
          requestsCoalesced: state.telemetry.requestsCoalesced + 1,
        ),
      );
      await _inFlight[category];
      return;
    }
    _automaticRetries.remove(category);
    state = state.copyWith(
      telemetry: state.telemetry.copyWith(
        regenerations: state.telemetry.regenerations + 1,
      ),
    );
    await _generate(category, force: true);
  }

  Future<void> _generate(
    TutorialCategory category, {
    bool isPrefetch = false,
    bool force = false,
  }) async {
    final session = state.session;
    if (session == null || !session.hasReusableManifest) return;

    // A ready step costs nothing to show. Checked before the in-flight map so
    // that the overwhelmingly common reopen path does no work at all.
    if (!force && session.stepFor(category)?.isReady == true) {
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(
          stepsReused: state.telemetry.stepsReused + 1,
        ),
      );
      return;
    }

    // A concurrent caller for the same category joins the existing request.
    final existing = _inFlight[category];
    if (existing != null) {
      state = state.copyWith(
        telemetry: state.telemetry.copyWith(
          requestsCoalesced: state.telemetry.requestsCoalesced + 1,
        ),
      );
      await existing;
      return;
    }

    if (!isPrefetch) {
      state = state.copyWith(
        status: TutorialStatus.generatingStep,
        clearMessage: true,
      );
    }
    final request = _steps.generate(sessionId: session.id, category: category);
    _inFlight[category] = request;
    state = state.copyWith(
      telemetry: state.telemetry.copyWith(
        stepGenerations: state.telemetry.stepGenerations + 1,
        prefetches: isPrefetch
            ? state.telemetry.prefetches + 1
            : state.telemetry.prefetches,
      ),
    );
    try {
      final step = await request;
      if (!mounted) return;
      _automaticRetries.remove(category);
      _replaceStep(step);
      await _resolveGuidelineUrl(step);
    } on TutorialFailure catch (failure) {
      if (!mounted) return;
      final attempts = _automaticRetries[category] ?? 0;
      if (failure.retryable &&
          !isPrefetch &&
          attempts < _maximumAutomaticRetries) {
        _automaticRetries[category] = attempts + 1;
        _inFlight.remove(category);
        await _generate(category, force: force);
        return;
      }
      if (!isPrefetch) _fail(failure);
    } catch (_) {
      if (!mounted) return;
      if (!isPrefetch) {
        state = state.copyWith(
          status: TutorialStatus.failed,
          message: 'This tutorial step could not be prepared.',
        );
      }
    } finally {
      _inFlight.remove(category);
    }
  }

  /// Signs the private guideline path so the UI can display it.
  ///
  /// Free — no AI, no generation — but asynchronous, which is why it happens
  /// here and never in a widget's `build`. A failure leaves the URL absent and
  /// the UI shows an image-error state; it never fails the whole step, because
  /// the guideline itself was generated successfully.
  Future<void> _resolveGuidelineUrl(TutorialStep step) async {
    if (!step.isReady) return;
    if (state.guidelineUrls.containsKey(step.category)) return;
    try {
      final url = await _steps.resolveGuidelineUrl(step);
      if (!mounted) return;
      state = state.copyWith(
        guidelineUrls: <TutorialCategory, String>{
          ...state.guidelineUrls,
          step.category: url,
        },
      );
    } catch (_) {
      // Left absent deliberately; the UI offers a retry.
    }
  }

  /// Signs whichever guidelines are already ready when a session is adopted.
  ///
  /// This is what makes a reopen show its images immediately without
  /// regenerating anything.
  Future<void> _resolveReadyGuidelines(TutorialSession session) async {
    for (final step in session.steps) {
      if (step.isReady) await _resolveGuidelineUrl(step);
    }
  }

  void _replaceStep(TutorialStep step) {
    final session = state.session;
    if (session == null) return;
    final steps = <TutorialStep>[
      for (final existing in session.steps)
        if (existing.category == step.category) step else existing,
    ];
    if (!steps.any((existing) => existing.category == step.category)) {
      steps.add(step);
    }
    state = state.copyWith(
      status: TutorialStatus.ready,
      session: TutorialSession(
        id: session.id,
        userId: session.userId,
        analysisId: session.analysisId,
        canonicalPreviewId: session.canonicalPreviewId,
        lookPlan: session.lookPlan,
        status: session.status,
        manifest: session.manifest,
        steps: steps,
        aiConfiguration: session.aiConfiguration,
        createdAt: session.createdAt,
        updatedAt: session.updatedAt,
        completedAt: session.completedAt,
      ),
      clearMessage: true,
    );
  }

  void _fail(TutorialFailure failure) {
    state = state.copyWith(
      status: failure.kind == TutorialFailureKind.kitPreviewMismatch
          ? TutorialStatus.kitPreviewMismatch
          : TutorialStatus.failed,
      message: failure.message,
      retryable: failure.retryable,
      sessionExpired: failure.kind == TutorialFailureKind.sessionExpired,
    );
  }

  void _reset() {
    _opened = false;
    _opening = null;
    _inFlight.clear();
    _automaticRetries.clear();
    state = const TutorialViewState();
  }

  @override
  void dispose() {
    // In-flight server work is NOT cancelled here. A client going away never
    // proves the server stopped, so the step stays claimed until it finishes or
    // its lock expires — pretending otherwise would invite a duplicate call.
    _inFlight.clear();
    super.dispose();
  }
}
