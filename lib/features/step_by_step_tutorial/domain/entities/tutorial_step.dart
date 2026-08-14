import 'tutorial_generation_status.dart';
import 'personalized_tutorial.dart';
import 'tutorial_instruction.dart';
import 'tutorial_placement_metadata.dart';
import 'tutorial_step_category.dart';

/// One step of a [TutorialSession].
///
/// A step has two images per FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §3.3:
/// - placement: the *previous* step's result image plus [placementMetadata]
///   overlays — reused, not regenerated (guide §4.1);
/// - result: one new tutorial-model generation showing the step correctly
///   applied and blended.
///
/// [placementImagePath]/[placementImageUrl] are therefore null only for the
/// first step of a session, which has no prior cumulative state to reuse.
class TutorialStep {
  const TutorialStep({
    required this.id,
    required this.tutorialSessionId,
    required this.stepNumber,
    required this.category,
    required this.title,
    required this.instruction,
    required this.generationStatus,
    required this.createdAt,
    required this.updatedAt,
    this.placementMetadata,
    this.personalizedSpec,
    this.placementImagePath,
    this.placementImageUrl,
    this.resultImagePath,
    this.resultImageUrl,
    this.modelId,
    this.imageSize,
    this.promptVersion,
  });

  final String id;
  final String tutorialSessionId;
  final int stepNumber;
  final TutorialStepCategory category;
  final String title;
  final TutorialInstruction instruction;
  final TutorialPlacementMetadata? placementMetadata;

  /// Immutable placement/product decision loaded from persistence. Reopening
  /// renders this snapshot and must not run personalization rules again.
  final PersonalizedTutorialStepSpec? personalizedSpec;

  final String? placementImagePath;
  final String? placementImageUrl;

  final String? resultImagePath;
  final String? resultImageUrl;

  /// AI configuration actually used for this step's result image, echoed
  /// from server-side config for display/debugging. Never the source of
  /// truth for what generates next — see ARCHITECTURE_NOTES.md.
  final String? modelId;
  final int? imageSize;
  final String? promptVersion;

  final TutorialStepGenerationStatus generationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
}
