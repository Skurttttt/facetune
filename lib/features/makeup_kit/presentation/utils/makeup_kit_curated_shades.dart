import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/value_objects/normalized_hex_color.dart';

/// A named, brand-neutral reference shade offered as a quick-tap starting
/// point in the visual color picker (MK-5).
///
/// Users are never required to understand HEX: picking a curated shade sets
/// both a normalized color and a friendly label in one tap.
class CuratedShade {
  const CuratedShade(this.label, this.hex);

  final String label;
  final String hex;

  /// [hex] is a compile-time-known literal for every entry in
  /// [MakeupKitCuratedShades], so this never throws in practice.
  NormalizedHexColor get color => NormalizedHexColor.parse(hex);
}

/// Curated, category-appropriate starting shades.
///
/// Brand-neutral by construction (CODEX_MASTER_GUIDE.md §2): every label
/// describes a color, never a product or brand.
abstract final class MakeupKitCuratedShades {
  static const Map<MakeupKitCategory, List<CuratedShade>> _byCategory = {
    MakeupKitCategory.foundation: [
      CuratedShade('Fair Ivory', '#F1DFCB'),
      CuratedShade('Light Beige', '#EFCBA9'),
      CuratedShade('Warm Beige', '#C99578'),
      CuratedShade('Medium Honey', '#C68642'),
      CuratedShade('Tan Caramel', '#A9702F'),
      CuratedShade('Deep Espresso', '#5C3A21'),
    ],
    MakeupKitCategory.concealer: [
      CuratedShade('Fair', '#F3E1CE'),
      CuratedShade('Light', '#EAC9A6'),
      CuratedShade('Medium', '#CE9B72'),
      CuratedShade('Tan', '#B27D4B'),
      CuratedShade('Deep', '#6E4527'),
    ],
    MakeupKitCategory.blush: [
      CuratedShade('Soft Pink', '#F2B8C6'),
      CuratedShade('Warm Peach', '#E69A7A'),
      CuratedShade('Rose', '#C97B84'),
      CuratedShade('Coral', '#E8836B'),
      CuratedShade('Berry', '#A24B5E'),
    ],
    MakeupKitCategory.highlighter: [
      CuratedShade('Champagne', '#F3D9B1'),
      CuratedShade('Rose Gold', '#E8B4A0'),
      CuratedShade('Gold', '#E4C078'),
      CuratedShade('Pearl', '#F5E9DA'),
    ],
    MakeupKitCategory.eyeshadow: [
      CuratedShade('Champagne', '#E8D5B7'),
      CuratedShade('Taupe', '#9C8574'),
      CuratedShade('Bronze', '#8A5A34'),
      CuratedShade('Plum', '#6B4358'),
      CuratedShade('Olive', '#6E7355'),
      CuratedShade('Charcoal', '#4A4646'),
    ],
    MakeupKitCategory.lipstick: [
      CuratedShade('Nude Rose', '#B86F72'),
      CuratedShade('Peach Nude', '#D98B72'),
      CuratedShade('Soft Pink', '#E6A2B0'),
      CuratedShade('Terracotta', '#B5613E'),
      CuratedShade('Deep Red', '#8B2635'),
      CuratedShade('Berry', '#7A2E4A'),
    ],
    MakeupKitCategory.lipGloss: [
      CuratedShade('Clear Pink', '#E8A9B8'),
      CuratedShade('Peach Shine', '#E8B090'),
      CuratedShade('Natural', '#D6A98C'),
      CuratedShade('Berry Gloss', '#B05C74'),
    ],
    MakeupKitCategory.contourBronzer: [
      CuratedShade('Warm Tan', '#A9713D'),
      CuratedShade('Cool Taupe', '#8C6C5C'),
      CuratedShade('Deep Bronze', '#7A4B2A'),
    ],
    MakeupKitCategory.eyebrow: [
      CuratedShade('Soft Taupe', '#8A6E5D'),
      CuratedShade('Ash Brown', '#6B4A3A'),
      CuratedShade('Warm Brunette', '#5C3E2E'),
      CuratedShade('Charcoal', '#4A4038'),
    ],
    MakeupKitCategory.eyeliner: [
      CuratedShade('Black', '#1B1B1B'),
      CuratedShade('Charcoal Gray', '#3A3A3C'),
      CuratedShade('Deep Brown', '#2E1F17'),
      CuratedShade('Brown', '#3E2A1E'),
    ],
  };

  /// The curated shades for [category], in display order. Never empty for a
  /// supported category.
  static List<CuratedShade> forCategory(MakeupKitCategory category) =>
      _byCategory[category] ?? const [];
}
