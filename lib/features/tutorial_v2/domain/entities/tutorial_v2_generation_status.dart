/// The lifecycle of a single generated tutorial asset.
///
/// A step tracks its guideline and result assets independently (Source of
/// Truth §27) so the UI can render partial readiness instead of blocking on
/// whichever asset is slower.
enum TutorialV2GenerationStatus {
  pending('pending'),
  generating('generating'),
  ready('ready'),
  failed('failed');

  const TutorialV2GenerationStatus(this.code);

  final String code;

  bool get isReady => this == TutorialV2GenerationStatus.ready;
  bool get isTerminal =>
      this == TutorialV2GenerationStatus.ready ||
      this == TutorialV2GenerationStatus.failed;

  /// Whether a generation request is already outstanding for this asset.
  ///
  /// Used to suppress duplicate concurrent requests for the same step
  /// (Source of Truth §28).
  bool get isInFlight => this == TutorialV2GenerationStatus.generating;

  static TutorialV2GenerationStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// The per-step asset state: which of the two assets exist, and where.
///
/// The final canonical-reuse step carries no generated assets of its own —
/// it points at the already-persisted canonical final preview — so both
/// statuses stay [TutorialV2GenerationStatus.ready] with a null
/// [guidelinePath] and a [resultPath] supplied by the canonical preview.
class TutorialV2StepAssets {
  const TutorialV2StepAssets({
    this.guidelineStatus = TutorialV2GenerationStatus.pending,
    this.resultStatus = TutorialV2GenerationStatus.pending,
    this.guidelinePath,
    this.resultPath,
    this.guidelineError,
    this.resultError,
    this.retryCount = 0,
  });

  final TutorialV2GenerationStatus guidelineStatus;
  final TutorialV2GenerationStatus resultStatus;
  final String? guidelinePath;
  final String? resultPath;
  final String? guidelineError;
  final String? resultError;
  final int retryCount;

  /// Whether both assets are available for display.
  bool get isComplete => guidelineStatus.isReady && resultStatus.isReady;

  /// Whether at least one asset can be shown while the other still works.
  bool get isPartiallyReady =>
      (guidelineStatus.isReady || resultStatus.isReady) && !isComplete;

  bool get hasFailure =>
      guidelineStatus == TutorialV2GenerationStatus.failed ||
      resultStatus == TutorialV2GenerationStatus.failed;

  TutorialV2StepAssets copyWith({
    TutorialV2GenerationStatus? guidelineStatus,
    TutorialV2GenerationStatus? resultStatus,
    String? guidelinePath,
    String? resultPath,
    String? guidelineError,
    String? resultError,
    int? retryCount,
  }) => TutorialV2StepAssets(
    guidelineStatus: guidelineStatus ?? this.guidelineStatus,
    resultStatus: resultStatus ?? this.resultStatus,
    guidelinePath: guidelinePath ?? this.guidelinePath,
    resultPath: resultPath ?? this.resultPath,
    guidelineError: guidelineError ?? this.guidelineError,
    resultError: resultError ?? this.resultError,
    retryCount: retryCount ?? this.retryCount,
  );
}

/// Which of a step's two generated assets is being referred to.
enum TutorialV2AssetKind {
  guideline('guideline'),
  result('result');

  const TutorialV2AssetKind(this.code);

  final String code;

  static TutorialV2AssetKind? fromCode(String code) {
    for (final kind in values) {
      if (kind.code == code) return kind;
    }
    return null;
  }
}
