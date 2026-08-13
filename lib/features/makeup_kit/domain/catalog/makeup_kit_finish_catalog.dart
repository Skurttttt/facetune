import '../entities/makeup_kit_category.dart';
import '../entities/makeup_kit_finish.dart';

/// The authoritative catalog of which [MakeupKitFinish] values are valid
/// for each [MakeupKitCategory].
///
/// This is the single source of truth for category/finish compatibility.
/// UI layers must only expose finishes valid for the selected category, and
/// data/domain layers must reject invalid combinations before persistence.
abstract final class MakeupKitFinishCatalog {
  static const Map<MakeupKitCategory, Set<MakeupKitFinish>> _allowedFinishes = {
    MakeupKitCategory.foundation: {
      MakeupKitFinish.matte,
      MakeupKitFinish.natural,
      MakeupKitFinish.dewy,
      MakeupKitFinish.satin,
    },
    MakeupKitCategory.concealer: {
      MakeupKitFinish.matte,
      MakeupKitFinish.natural,
      MakeupKitFinish.radiant,
    },
    MakeupKitCategory.blush: {
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.shimmer,
    },
    MakeupKitCategory.highlighter: {
      MakeupKitFinish.natural,
      MakeupKitFinish.shimmer,
      MakeupKitFinish.metallic,
    },
    MakeupKitCategory.eyeshadow: {
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.shimmer,
      MakeupKitFinish.metallic,
      MakeupKitFinish.glitter,
    },
    MakeupKitCategory.lipstick: {
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.cream,
      MakeupKitFinish.glossy,
    },
    MakeupKitCategory.lipGloss: {
      MakeupKitFinish.glossy,
      MakeupKitFinish.shimmer,
    },
    MakeupKitCategory.contourBronzer: {
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
    },
    MakeupKitCategory.eyebrow: {MakeupKitFinish.matte, MakeupKitFinish.natural},
    MakeupKitCategory.eyeliner: {
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.glossy,
    },
  };

  /// The finishes valid for [category], in declaration order.
  static Set<MakeupKitFinish> allowedFinishes(MakeupKitCategory category) =>
      _allowedFinishes[category] ?? const <MakeupKitFinish>{};

  /// Whether [finish] is a valid choice for [category].
  static bool isValidCombination(
    MakeupKitCategory category,
    MakeupKitFinish finish,
  ) => allowedFinishes(category).contains(finish);
}
