import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';

/// The stable wire identifier of this recommendation mode.
const customColorPaletteSourceMode = 'custom_color_palette';

/// The version of the canonical palette contract this client produces.
const customColorPaletteContractVersion = 'custom_color_palette_contract_v1';

/// One base color the user can start from.
class CustomPaletteSwatch {
  const CustomPaletteSwatch(this.label, this.hex);

  /// Presentation metadata only. The hex value is the identity.
  final String label;
  final String hex;

  /// [hex] is a compile-time-known literal for every entry in the catalog.
  NormalizedHexColor get color => NormalizedHexColor.parse(hex);
}

/// What Custom Color Palette supports, as approved in CCP-1.
///
/// This catalog deliberately owns its own constants rather than reading
/// `MakeupKitFinishCatalog` at runtime: a frozen palette must stay valid
/// whatever My Makeup Kit later allows. A test proves the finishes here remain
/// a subset of the kit catalog, so the two cannot quietly disagree.
abstract final class CustomPaletteCatalog {
  /// The supported categories, in Tutorial application order.
  ///
  /// This order is the canonical order of a palette's selections.
  static const List<MakeupKitCategory> categories = [
    MakeupKitCategory.blush,
    MakeupKitCategory.eyeshadow,
    MakeupKitCategory.eyeliner,
    MakeupKitCategory.lipstick,
  ];

  static const Map<MakeupKitCategory, List<MakeupKitFinish>> _finishes = {
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

  /// One palette for every category: the kit's curated shades cannot express
  /// a look such as violet eyeliner or orange blush.
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

  static bool isSupported(MakeupKitCategory category) =>
      categories.contains(category);

  /// The finishes valid for [category]; empty for an unsupported one.
  static List<MakeupKitFinish> finishesFor(MakeupKitCategory category) =>
      _finishes[category] ?? const <MakeupKitFinish>[];

  /// The catalog swatch for [hex], or `null` when it is not one.
  static CustomPaletteSwatch? swatchFor(String hex) {
    for (final swatch in swatches) {
      if (swatch.hex == hex) return swatch;
    }
    return null;
  }
}
