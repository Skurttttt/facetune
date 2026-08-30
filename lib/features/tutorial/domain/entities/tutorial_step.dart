import 'look_product_snapshot.dart';
import 'tutorial_ai_configuration.dart';
import 'tutorial_category.dart';

/// Lifecycle of one tutorial step.
///
/// A step that reaches [ready] stays ready. Reopening a tutorial must never
/// regenerate an already-ready step, because each generation is a paid AI call.
enum TutorialStepStatus {
  pending('pending'),
  generating('generating'),
  ready('ready'),
  failed('failed');

  const TutorialStepStatus(this.code);

  final String code;

  static TutorialStepStatus? fromCode(String code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return null;
  }
}

/// One category's step within a tutorial.
///
/// A step exists only for a category the manifest included, so there is no
/// "empty" or "skipped" step state — an excluded category simply has no step.
class TutorialStep {
  TutorialStep({
    required this.id,
    required this.sessionId,
    required this.category,
    required this.position,
    required this.status,
    this.guidelineStoragePath,
    this.modelId,
    this.outputResolution,
    this.promptVersion,
    this.generationAttempt = 0,
    List<LookProductSnapshotItem> productSnapshotItems =
        const <LookProductSnapshotItem>[],
    this.failureCode,
    required this.createdAt,
    required this.updatedAt,
  }) : productSnapshotItems = List<LookProductSnapshotItem>.unmodifiable(
         productSnapshotItems,
       );

  final String id;
  final String sessionId;
  final TutorialCategory category;

  /// 1-based presentation position among the *included* steps of this
  /// tutorial.
  ///
  /// Distinct from [TutorialCategory.order], which ranks a category within the
  /// full vocabulary regardless of inclusion. A tutorial containing only
  /// Foundation, Blush, and Lips gives them positions 1, 2, 3 while their
  /// vocabulary orders remain 1, 4, 9. Relative sequence is identical either
  /// way — filtering never reorders.
  final int position;

  final TutorialStepStatus status;

  /// Path to the rendered guideline image in the private bucket. Null until
  /// the step reaches [TutorialStepStatus.ready].
  ///
  /// A storage path, never a signed URL: signed URLs expire, so persisting one
  /// would store a credential with a lifetime shorter than the record holding
  /// it.
  final String? guidelineStoragePath;

  /// What actually produced this step, as reported by the server. Null until
  /// generation has run.
  final String? modelId;
  final TutorialOutputResolution? outputResolution;
  final String? promptVersion;

  /// How many generation attempts this step has consumed, for retry limits and
  /// cost control.
  final int generationAttempt;

  /// The validated owned product(s) presented with this step.
  ///
  /// A list, not a single reference and never a delimited string, because one
  /// step can legitimately present several owned products — a Lipstick and a
  /// Lip Gloss in the Lips step. Always empty in Standard Mode.
  final List<LookProductSnapshotItem> productSnapshotItems;

  /// A sanitized failure code when [status] is [TutorialStepStatus.failed].
  /// Never carries raw model output or prompt text.
  final String? failureCode;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this step has a usable rendered guideline.
  bool get isReady =>
      status == TutorialStepStatus.ready && guidelineStoragePath != null;
}
