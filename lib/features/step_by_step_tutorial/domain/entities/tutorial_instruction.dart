import 'tutorial_step_category.dart';

/// Structured written guidance for one tutorial step.
///
/// Field shape intentionally mirrors `MakeupRecommendationItem`
/// (recommendation/domain/entities/makeup_recommendation.dart) — placement,
/// technique, finish, intensity, reasoning-style fields already exist there
/// and proved sufficient for the standard recommendation flow. This adds
/// [direction] and [tip], which
/// FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md §8 calls for and the existing
/// type does not carry.
class TutorialInstruction {
  const TutorialInstruction({
    required this.category,
    required this.placement,
    required this.intensity,
    required this.technique,
    this.productName,
    this.colorName,
    this.hex,
    this.finish,
    this.direction,
    this.tip,
  });

  final TutorialStepCategory category;
  final String? productName;
  final String? colorName;
  final String? hex;
  final String? finish;
  final String placement;
  final String? direction;
  final String intensity;
  final String technique;
  final String? tip;
}
