import '../entities/tutorial_v3_geometry.dart';
import '../entities/tutorial_v3_session_snapshot.dart';
import '../entities/tutorial_v3_step.dart';
import '../errors/tutorial_v3_failure.dart';
import '../repositories/tutorial_v3_geometry_mapper.dart';
import 'tutorial_v3_geometry_cache.dart';

/// How many steps ahead of the current one are mapped in the background.
///
/// One. Mapping the whole tutorial upfront would spend a model call per step
/// before the user has read the first instruction, and most sessions are
/// abandoned long before the last step. Mapping only what is on screen would
/// make every "Next" wait for the network. Depth 1 is the compromise: the step
/// after the current one is usually already in memory by the time it is
/// needed.
const tutorialV3PrefetchDepth = 1;

/// Owns geometry acquisition for one tutorial at a time.
///
/// Three jobs, all of which have to be in the same place to be correct:
///
/// 1. **Reuse.** A step whose geometry is already cached, or already persisted
///    and readable, never triggers a call.
/// 2. **Deduplication.** Two callers asking for the same step share one
///    in-flight request. The server's atomic claim is the real guard against
///    duplicate mapping; this stops the app from provoking it in the first
///    place, which is what keeps a rejected `already_mapping` off the screen
///    when the user taps Next twice.
/// 3. **Prefetch.** The next step is mapped in the background, and a failure
///    there is silent — a background miss must never disturb the step the user
///    is actually reading.
///
/// Every request carries identifiers only. The original selfie and the
/// persisted Step Spec are what the server maps from, and no step's geometry
/// is ever an input to another step's mapping.
class TutorialV3GeometryCoordinator {
  TutorialV3GeometryCoordinator(this._mapper, {TutorialV3GeometryCache? cache})
    : cache = cache ?? TutorialV3GeometryCache();

  final TutorialV3GeometryMapper _mapper;

  final TutorialV3GeometryCache cache;

  final Map<String, Future<TutorialV3Geometry?>> _inFlight =
      <String, Future<TutorialV3Geometry?>>{};

  static String _key(String sessionId, int stepIndex) =>
      '$sessionId#$stepIndex';

  /// Whether a mapping request for this step is currently outstanding.
  bool isMapping(String sessionId, int stepIndex) =>
      _inFlight.containsKey(_key(sessionId, stepIndex));

  /// Geometry already available without any network call.
  ///
  /// Used to decide whether a step can be rendered immediately, so the UI can
  /// skip its loading state entirely on a revisit.
  TutorialV3Geometry? cached({
    required TutorialV3LoadedSession session,
    required int stepIndex,
  }) {
    final step = session.stepAt(stepIndex);
    if (step == null || step.isFinalLook) return null;

    final hit = cache.read(session.sessionId, stepIndex);
    if (hit != null) return hit;

    // The persisted row is a cache too, and a warmer one than the network: a
    // reopened tutorial has its finished steps sitting in the database.
    return _fromPersistedStep(session.sessionId, step);
  }

  /// Resolves geometry for one step, mapping it only if it is genuinely
  /// missing.
  ///
  /// Returns `null` for the final look, which reuses the canonical preview and
  /// has no geometry to map. Throws [TutorialV3Failure] when mapping fails —
  /// callers that cannot show an error should use [prefetch] instead.
  Future<TutorialV3Geometry?> ensureGeometry({
    required TutorialV3LoadedSession session,
    required int stepIndex,
  }) {
    final step = session.stepAt(stepIndex);
    if (step == null) {
      throw TutorialV3Failure(
        'Step $stepIndex does not belong to this tutorial.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
    }
    // The final step reuses the canonical premium preview. There is no
    // instruction to locate on the face, so no mapping call is made for it —
    // not a skipped one, not a cached one, none.
    if (step.isFinalLook) return Future<TutorialV3Geometry?>.value();

    final available = cached(session: session, stepIndex: stepIndex);
    if (available != null) return Future<TutorialV3Geometry?>.value(available);

    final key = _key(session.sessionId, stepIndex);
    final existing = _inFlight[key];
    if (existing != null) return existing;

    // A block body, not an arrow: `remove` returns the stored Future, and a
    // `whenComplete` callback that RETURNS a future waits for it — which here
    // would be the very future being created.
    final request = _map(session.sessionId, step).whenComplete(() {
      _inFlight.remove(key);
    });
    _inFlight[key] = request;
    return request;
  }

  /// Warms the steps after [currentStepIndex], up to [depth].
  ///
  /// Fire and forget by design: the returned future completes when the
  /// background work settles, and never with an error. A prefetch that fails
  /// leaves the cache untouched, so the step is simply mapped normally when
  /// the user reaches it.
  Future<void> prefetch({
    required TutorialV3LoadedSession session,
    required int currentStepIndex,
    int depth = tutorialV3PrefetchDepth,
  }) async {
    for (final stepIndex in prefetchTargets(
      session: session,
      currentStepIndex: currentStepIndex,
      depth: depth,
    )) {
      try {
        await ensureGeometry(session: session, stepIndex: stepIndex);
      } on Object {
        // Deliberately swallowed, and deliberately every exception rather than
        // only the domain ones: this future is documented never to complete
        // with an error, and a network or serialization fault in speculative
        // background work has no more business reaching the screen than a
        // rejected mapping does. The cache is simply left cold, so the step is
        // mapped normally when the user actually arrives at it.
      }
    }
  }

  /// The step indices a prefetch would target.
  ///
  /// Exposed so the policy is testable on its own: strictly forward, capped at
  /// [depth], never the final look, and never a step that already has usable
  /// geometry.
  List<int> prefetchTargets({
    required TutorialV3LoadedSession session,
    required int currentStepIndex,
    int depth = tutorialV3PrefetchDepth,
  }) {
    if (depth <= 0) return const <int>[];
    final targets = <int>[];
    for (var offset = 1; offset <= depth; offset++) {
      final stepIndex = currentStepIndex + offset;
      final step = session.stepAt(stepIndex);
      if (step == null) break;
      if (step.isFinalLook) continue;
      if (cached(session: session, stepIndex: stepIndex) != null) continue;
      if (isMapping(session.sessionId, stepIndex)) continue;
      targets.add(stepIndex);
    }
    return targets;
  }

  /// Forgets everything cached for a tutorial, for use when its plan is
  /// replaced and the old step indices no longer mean the same thing.
  void invalidateSession(String sessionId) => cache.evictSession(sessionId);

  Future<TutorialV3Geometry?> _map(
    String sessionId,
    TutorialV3Step step,
  ) async {
    // The category comes from the persisted Step Spec, so a document for
    // another category is rejected rather than drawn on the wrong feature.
    final geometry = await _mapper.map(
      sessionId: sessionId,
      stepIndex: step.stepIndex,
      expectedCategory: step.spec.category,
    );
    cache.write(sessionId, step.stepIndex, geometry);
    return geometry;
  }

  TutorialV3Geometry? _fromPersistedStep(
    String sessionId,
    TutorialV3Step step,
  ) {
    // `hasStaleGeometry` is what keeps a document from an older build out of
    // the cache: it is re-mapped rather than rendered under a vocabulary this
    // build does not know.
    if (!step.hasGeometry || step.hasStaleGeometry) return null;
    final geometry = step.geometry!;
    if (!geometry.isCurrentSchema) return null;
    cache.write(sessionId, step.stepIndex, geometry);
    return geometry;
  }
}
