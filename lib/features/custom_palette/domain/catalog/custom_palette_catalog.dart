import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';

/// The stable wire identifier of this recommendation mode.
const customColorPaletteSourceMode = 'custom_color_palette';

/// The version of the canonical palette contract this client produces.
const customColorPaletteContractVersion = 'custom_color_palette_contract_v2';

/// The original four-category contract. Palettes stored under it remain
/// readable; this client never writes it.
const customColorPaletteLegacyContractVersion =
    'custom_color_palette_contract_v1';

/// Every contract version a stored palette may carry.
const customColorPaletteReadableContractVersions = {
  customColorPaletteContractVersion,
  customColorPaletteLegacyContractVersion,
};

/// One base color the user can start from.
class CustomPaletteSwatch {
  const CustomPaletteSwatch(this.label, this.hex);

  /// Presentation metadata only. The hex value is the identity.
  final String label;
  final String hex;

  /// [hex] is a compile-time-known literal for every entry in the catalog.
  NormalizedHexColor get color => NormalizedHexColor.parse(hex);
}

/// What Custom Color Palette supports: My Makeup Kit's exact category set
/// (contract v2; CCP-1 supported the first four).
///
/// This catalog deliberately owns its own constants rather than reading
/// `MakeupKitFinishCatalog` or the kit's curated shades at runtime: a frozen
/// palette must stay valid whatever My Makeup Kit later allows. Tests prove the
/// categories, finishes and curated shades here equal the kit's, so the two
/// cannot quietly disagree.
abstract final class CustomPaletteCatalog {
  /// The supported categories, in Tutorial application order.
  ///
  /// This order is the canonical order of a palette's selections. The original
  /// four keep their relative order, so every v1 palette is still canonical.
  static const List<MakeupKitCategory> categories = [
    MakeupKitCategory.foundation,
    MakeupKitCategory.concealer,
    MakeupKitCategory.contourBronzer,
    MakeupKitCategory.blush,
    MakeupKitCategory.highlighter,
    MakeupKitCategory.eyebrow,
    MakeupKitCategory.eyeshadow,
    MakeupKitCategory.eyeliner,
    MakeupKitCategory.lipstick,
    MakeupKitCategory.lipGloss,
  ];

  /// The categories of the v1 contract.
  static const Set<MakeupKitCategory> legacyCategories = {
    MakeupKitCategory.blush,
    MakeupKitCategory.eyeshadow,
    MakeupKitCategory.eyeliner,
    MakeupKitCategory.lipstick,
  };

  static const Map<MakeupKitCategory, List<MakeupKitFinish>> _finishes = {
    MakeupKitCategory.foundation: [
      MakeupKitFinish.matte,
      MakeupKitFinish.natural,
      MakeupKitFinish.dewy,
      MakeupKitFinish.satin,
    ],
    MakeupKitCategory.concealer: [
      MakeupKitFinish.matte,
      MakeupKitFinish.natural,
      MakeupKitFinish.radiant,
    ],
    MakeupKitCategory.contourBronzer: [
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
    ],
    MakeupKitCategory.highlighter: [
      MakeupKitFinish.natural,
      MakeupKitFinish.shimmer,
      MakeupKitFinish.metallic,
    ],
    MakeupKitCategory.eyebrow: [MakeupKitFinish.matte, MakeupKitFinish.natural],
    MakeupKitCategory.lipGloss: [
      MakeupKitFinish.glossy,
      MakeupKitFinish.shimmer,
    ],
    MakeupKitCategory.blush: [
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.shimmer,
    ],
    MakeupKitCategory.eyeshadow: [
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.shimmer,
      MakeupKitFinish.metallic,
      MakeupKitFinish.glitter,
    ],
    MakeupKitCategory.eyeliner: [
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.glossy,
    ],
    MakeupKitCategory.lipstick: [
      MakeupKitFinish.matte,
      MakeupKitFinish.satin,
      MakeupKitFinish.cream,
      MakeupKitFinish.glossy,
    ],
  };

  /// The shared colors, used by Blush, Eyeshadow, Eyeliner, Lipstick and Lip
  /// Gloss: the kit's curated shades cannot express a look such as violet
  /// eyeliner or orange blush.
  static const List<CustomPaletteSwatch> swatches = [
    CustomPaletteSwatch('Black', '#1B1B1B'),
    CustomPaletteSwatch('Charcoal', '#3A3A3C'),
    CustomPaletteSwatch('Brown', '#5C3A21'),
    CustomPaletteSwatch('Taupe', '#9C8574'),
    CustomPaletteSwatch('Nude', '#D9A58B'),
    CustomPaletteSwatch('White', '#F5F2EC'),
    CustomPaletteSwatch('Peach', '#F2A07B'),
    CustomPaletteSwatch('Coral', '#E8636B'),
    CustomPaletteSwatch('Orange', '#E8711A'),
    CustomPaletteSwatch('Red', '#C8102E'),
    CustomPaletteSwatch('Berry', '#7A2E4A'),
    CustomPaletteSwatch('Pink', '#E75480'),
    CustomPaletteSwatch('Rose', '#C97B84'),
    CustomPaletteSwatch('Magenta', '#B5179E'),
    CustomPaletteSwatch('Plum', '#6B4358'),
    CustomPaletteSwatch('Violet', '#6A2FB5'),
    CustomPaletteSwatch('Navy', '#1F2F6B'),
    CustomPaletteSwatch('Blue', '#1F6FD6'),
    CustomPaletteSwatch('Teal', '#0F8B8D'),
    CustomPaletteSwatch('Green', '#2E7D4F'),
    CustomPaletteSwatch('Olive', '#6E7355'),
    CustomPaletteSwatch('Gold', '#C9A227'),
    CustomPaletteSwatch('Bronze', '#8A5A34'),
    CustomPaletteSwatch('Silver', '#B8BCC2'),
  ];

  /// Categories that offer only My Makeup Kit's curated shades: an arbitrary
  /// color is not a sensible foundation, concealer, contour, highlighter or
  /// brow choice. Values equal `MakeupKitCuratedShades` (proven by a test).
  static const Map<MakeupKitCategory, List<CustomPaletteSwatch>> _curated = {
    MakeupKitCategory.foundation: [
      CustomPaletteSwatch('Fair Ivory', '#F1DFCB'),
      CustomPaletteSwatch('Light Beige', '#EFCBA9'),
      CustomPaletteSwatch('Warm Beige', '#C99578'),
      CustomPaletteSwatch('Medium Honey', '#C68642'),
      CustomPaletteSwatch('Tan Caramel', '#A9702F'),
      CustomPaletteSwatch('Deep Espresso', '#5C3A21'),
    ],
    MakeupKitCategory.concealer: [
      CustomPaletteSwatch('Fair', '#F3E1CE'),
      CustomPaletteSwatch('Light', '#EAC9A6'),
      CustomPaletteSwatch('Medium', '#CE9B72'),
      CustomPaletteSwatch('Tan', '#B27D4B'),
      CustomPaletteSwatch('Deep', '#6E4527'),
    ],
    MakeupKitCategory.contourBronzer: [
      CustomPaletteSwatch('Warm Tan', '#A9713D'),
      CustomPaletteSwatch('Cool Taupe', '#8C6C5C'),
      CustomPaletteSwatch('Deep Bronze', '#7A4B2A'),
    ],
    MakeupKitCategory.highlighter: [
      CustomPaletteSwatch('Champagne', '#F3D9B1'),
      CustomPaletteSwatch('Rose Gold', '#E8B4A0'),
      CustomPaletteSwatch('Gold', '#E4C078'),
      CustomPaletteSwatch('Pearl', '#F5E9DA'),
    ],
    MakeupKitCategory.eyebrow: [
      CustomPaletteSwatch('Soft Taupe', '#8A6E5D'),
      CustomPaletteSwatch('Ash Brown', '#6B4A3A'),
      CustomPaletteSwatch('Warm Brunette', '#5C3E2E'),
      CustomPaletteSwatch('Charcoal', '#4A4038'),
    ],
  };

  static bool isSupported(MakeupKitCategory category) =>
      categories.contains(category);

  /// Whether [category] offers curated shades rather than the shared colors.
  static bool usesCuratedShades(MakeupKitCategory category) =>
      _curated.containsKey(category);

  /// The finishes valid for [category]; empty for an unsupported one.
  static List<MakeupKitFinish> finishesFor(MakeupKitCategory category) =>
      _finishes[category] ?? const <MakeupKitFinish>[];

  /// The colors [category] offers, in display order; empty for an
  /// unsupported category.
  static List<CustomPaletteSwatch> swatchesFor(MakeupKitCategory category) {
    if (!isSupported(category)) return const <CustomPaletteSwatch>[];
    return _curated[category] ?? swatches;
  }

  /// [category]'s swatch for [hex], or `null` when it offers no such color.
  ///
  /// Per category, because a curated shade can share a hex value with a
  /// shared color under another name (Foundation "Deep Espresso" and "Brown").
  static CustomPaletteSwatch? swatchFor(
    MakeupKitCategory category,
    String hex,
  ) {
    for (final swatch in swatchesFor(category)) {
      if (swatch.hex == hex) return swatch;
    }
    return null;
  }
}
