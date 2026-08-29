import '../../../makeup_kit/presentation/utils/makeup_kit_display.dart';
import '../../domain/entities/tutorial_v3_category.dart';

/// Presentation-only display metadata for [TutorialV3Category].
///
/// Deliberately kept out of the domain layer, matching
/// [MakeupKitCategoryDisplay]: V3-1 established the category as a stable
/// identifier only. The Kit label is reused wherever a Kit category exists, so
/// one product reads the same word in the Kit and in the tutorial.
extension TutorialV3CategoryDisplay on TutorialV3Category {
  String get label {
    final kit = kitCategory;
    if (kit != null) return kit.label;
    return switch (this) {
      TutorialV3Category.finalLook => 'Final Look',
      _ => code,
    };
  }
}
