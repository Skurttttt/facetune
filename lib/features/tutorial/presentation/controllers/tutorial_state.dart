import '../../domain/entities/recommendation_source_mode.dart';
import '../../domain/entities/tutorial_category.dart';
import '../../domain/entities/tutorial_session.dart';
import '../../domain/entities/tutorial_step.dart';

/// What the tutorial is doing right now.
///
/// Explicit states rather than a set of booleans: "opening", "analysing the
/// manifest", and "drawing a step" are three different waits with three
/// different costs, and a single `isLoading` could not tell a free reopen from
/// a paid analysis.
enum TutorialStatus {
  /// Nothing has been requested. Crucially the initial state, so simply
  /// watching the controller cannot start work.
  idle,
  opening,
  analyzingManifest,
  ready,
  generatingStep,
  failed,

  /// The canonical preview shows makeup the user's kit cannot reproduce. A
  /// terminal state, not a retryable error.
  kitPreviewMismatch,
}

/// Counters for how much paid work this session actually caused.
///
/// Sanitized by construction: counts only, no ids, paths, product names, or
/// image data. The point is to make an accidental cost multiplication visible
/// in a test rather than on an invoice.
class TutorialUsageTelemetry {
  const TutorialUsageTelemetry({
    this.manifestAnalyses = 0,
    this.stepGenerations = 0,
    this.stepsReused = 0,
    this.requestsCoalesced = 0,
    this.prefetches = 0,
    this.regenerations = 0,
  });

  /// Paid multimodal analyses actually requested.
  final int manifestAnalyses;

  /// Paid guideline renders actually requested, including prefetch.
  final int stepGenerations;

  /// Renders avoided because a ready step already existed.
  final int stepsReused;

  /// Duplicate calls folded into an in-flight request instead of billed again.
  final int requestsCoalesced;

  final int prefetches;

  /// Renders the user explicitly asked to repeat.
  final int regenerations;

  TutorialUsageTelemetry copyWith({
    int? manifestAnalyses,
    int? stepGenerations,
    int? stepsReused,
    int? requestsCoalesced,
    int? prefetches,
    int? regenerations,
  }) => TutorialUsageTelemetry(
    manifestAnalyses: manifestAnalyses ?? this.manifestAnalyses,
    stepGenerations: stepGenerations ?? this.stepGenerations,
    stepsReused: stepsReused ?? this.stepsReused,
    requestsCoalesced: requestsCoalesced ?? this.requestsCoalesced,
    prefetches: prefetches ?? this.prefetches,
    regenerations: regenerations ?? this.regenerations,
  );

  /// A log-safe summary. Contains no user data by construction.
  @override
  String toString() =>
      'manifest=$manifestAnalyses generated=$stepGenerations '
      'reused=$stepsReused coalesced=$requestsCoalesced '
      'prefetched=$prefetches regenerated=$regenerations';
}

class TutorialViewState {
  const TutorialViewState({
    this.status = TutorialStatus.idle,
    this.session,
    this.currentIndex = 0,
    this.message,
    this.retryable = true,
    this.sessionExpired = false,
    this.telemetry = const TutorialUsageTelemetry(),
    this.guidelineUrls = const <TutorialCategory, String>{},
  });

  final TutorialStatus status;
  final TutorialSession? session;

  /// Index into the included categories, not into the vocabulary.
  final int currentIndex;

  final String? message;
  final bool retryable;
  final bool sessionExpired;
  final TutorialUsageTelemetry telemetry;

  /// Short-lived signed URLs for ready guidelines, keyed by category.
  ///
  /// Held in state rather than resolved during build: signing is cheap but
  /// asynchronous, and a build that awaited it would re-request on every
  /// rebuild.
  final Map<TutorialCategory, String> guidelineUrls;

  /// The categories this tutorial contains, in deterministic order.
  List<TutorialCategory> get categories =>
      session?.includedCategories ?? const <TutorialCategory>[];

  /// The N in "Step X of N" — the included count, never the vocabulary size.
  int get stepCount => categories.length;

  /// The 1-based position of the current step.
  int get stepNumber => categories.isEmpty ? 0 : currentIndex + 1;

  TutorialCategory? get currentCategory =>
      currentIndex >= 0 && currentIndex < categories.length
      ? categories[currentIndex]
      : null;

  TutorialStep? get currentStep {
    final category = currentCategory;
    return category == null ? null : session?.stepFor(category);
  }

  /// The next category, or null at the end. This is the only thing prefetch is
  /// ever allowed to look at, which is what bounds its depth to one.
  TutorialCategory? get nextCategory => currentIndex + 1 < categories.length
      ? categories[currentIndex + 1]
      : null;

  RecommendationSourceMode? get sourceMode => session?.sourceMode;

  bool get isMyMakeupKit => sourceMode == RecommendationSourceMode.myMakeupKit;

  bool get hasCurrentGuideline => currentStep?.isReady == true;

  /// The displayable URL for the current guideline, or null while it is still
  /// being prepared.
  String? get currentGuidelineUrl {
    final category = currentCategory;
    return category == null ? null : guidelineUrls[category];
  }

  bool get isLastStep => stepCount > 0 && currentIndex == stepCount - 1;

  /// Whether every step of this tutorial has been drawn.
  ///
  /// Derived from persisted step state rather than a local flag, so it survives
  /// an app relaunch and can never disagree with what is actually stored.
  bool get isComplete {
    final session = this.session;
    if (session == null || categories.isEmpty) return false;
    return categories.every(
      (category) => session.stepFor(category)?.isReady == true,
    );
  }

  TutorialViewState copyWith({
    TutorialStatus? status,
    TutorialSession? session,
    int? currentIndex,
    String? message,
    bool clearMessage = false,
    bool? retryable,
    bool? sessionExpired,
    TutorialUsageTelemetry? telemetry,
    Map<TutorialCategory, String>? guidelineUrls,
  }) => TutorialViewState(
    status: status ?? this.status,
    session: session ?? this.session,
    currentIndex: currentIndex ?? this.currentIndex,
    message: clearMessage ? null : (message ?? this.message),
    retryable: retryable ?? this.retryable,
    sessionExpired: sessionExpired ?? this.sessionExpired,
    telemetry: telemetry ?? this.telemetry,
    guidelineUrls: guidelineUrls ?? this.guidelineUrls,
  );
}
