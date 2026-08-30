import '../../../makeup_kit/domain/entities/foundation_depth.dart';
import '../../../makeup_kit/domain/entities/foundation_undertone.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../domain/entities/tutorial_category.dart';

/// Every user-facing string the tutorial shows.
///
/// Centralised so the UI never inlines copy, which is what makes this
/// localization-ready: swapping this class for generated localisations later
/// touches no widget. Stable codes stay in the domain; only display text lives
/// here.
abstract final class TutorialLabels {
  static const tutorialTitle = 'Step-by-step tutorial';
  static const suggestedShades = 'Suggested shades';
  static const fromYourKit = 'From your kit';
  static const shade = 'Shade';
  static const finish = 'Finish';
  static const intensity = 'Intensity';
  static const depth = 'Depth';
  static const undertone = 'Undertone';
  static const howToApply = 'How to apply';
  static const whereToApply = 'Where to apply';
  static const back = 'Back';
  static const next = 'Next';
  static const finish_ = 'Finish';
  static const retry = 'Try again';
  static const redraw = 'Draw this step again';
  static const preparingTutorial = 'Working out which steps this look needs…';
  static const drawingStep = 'Drawing this step…';
  static const guidelineUnavailable = 'This step could not be drawn.';
  static const imageUnavailable = 'The guideline image could not be loaded.';
  static const completeTitle = 'That is the whole look';
  static const completeMessage =
      'You have been through every step this look needs.';
  static const yourFinalLook = 'Your final look';
  static const startTutorial = 'Show me how';
  static const emptyTitle = 'No steps for this look';
  static const emptyMessage =
      'This look does not have any makeup steps to show.';

  static String fromYourKitPlural(int count) =>
      'From your kit ($count products)';

  static String stepProgress(int step, int total) => 'Step $step of $total';

  /// Screen-reader description of the guideline image.
  ///
  /// Describes what the image *is*, since its content — drawn markings on a
  /// face — cannot be conveyed usefully by alt text alone.
  static String guidelineImageLabel(TutorialCategory category) =>
      'Guideline markings showing where to apply ${categoryName(category)}';

  /// The display name of a tutorial category.
  static String categoryName(TutorialCategory category) => switch (category) {
    TutorialCategory.foundation => 'Foundation',
    TutorialCategory.concealer => 'Concealer',
    TutorialCategory.contourBronzer => 'Contour & Bronzer',
    TutorialCategory.blush => 'Blush',
    TutorialCategory.highlighter => 'Highlighter',
    TutorialCategory.eyebrows => 'Eyebrows',
    TutorialCategory.eyeshadow => 'Eyeshadow',
    TutorialCategory.eyeliner => 'Eyeliner',
    TutorialCategory.lips => 'Lips',
  };

  /// The display name of an inventory category, used when a product has no
  /// user-entered name.
  static String inventoryCategory(MakeupKitCategory category) =>
      switch (category) {
        MakeupKitCategory.foundation => 'Foundation',
        MakeupKitCategory.concealer => 'Concealer',
        MakeupKitCategory.blush => 'Blush',
        MakeupKitCategory.highlighter => 'Highlighter',
        MakeupKitCategory.eyeshadow => 'Eyeshadow',
        MakeupKitCategory.lipstick => 'Lipstick',
        MakeupKitCategory.lipGloss => 'Lip gloss',
        MakeupKitCategory.contourBronzer => 'Contour or bronzer',
        MakeupKitCategory.eyebrow => 'Eyebrow product',
        MakeupKitCategory.eyeliner => 'Eyeliner',
      };

  static String finishName(MakeupKitFinish finish) => switch (finish) {
    MakeupKitFinish.matte => 'Matte',
    MakeupKitFinish.natural => 'Natural',
    MakeupKitFinish.dewy => 'Dewy',
    MakeupKitFinish.satin => 'Satin',
    MakeupKitFinish.radiant => 'Radiant',
    MakeupKitFinish.shimmer => 'Shimmer',
    MakeupKitFinish.metallic => 'Metallic',
    MakeupKitFinish.glitter => 'Glitter',
    MakeupKitFinish.cream => 'Cream',
    MakeupKitFinish.glossy => 'Glossy',
  };

  static String depthName(FoundationDepth depth) => switch (depth) {
    FoundationDepth.fair => 'Fair',
    FoundationDepth.light => 'Light',
    FoundationDepth.medium => 'Medium',
    FoundationDepth.tan => 'Tan',
    FoundationDepth.deep => 'Deep',
  };

  static String undertoneName(FoundationUndertone undertone) =>
      switch (undertone) {
        FoundationUndertone.cool => 'Cool',
        FoundationUndertone.neutral => 'Neutral',
        FoundationUndertone.warm => 'Warm',
      };
}
