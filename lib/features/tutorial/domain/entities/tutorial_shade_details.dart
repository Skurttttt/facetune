import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'look_product_snapshot.dart';
import 'standard_look_entry.dart';

/// How strongly a category was applied.
///
/// These are the four values the frozen Standard Mode recommendation schema
/// already validates (`sheer | soft | medium | bold`), not a new vocabulary
/// invented for display. The quality contract names Soft / Medium / Bold as the
/// display set, but the authoritative data distinguishes `sheer` from `soft`,
/// and collapsing the two would report an intensity the recommendation never
/// gave. Carrying the fourth value is the smaller deviation: it maps the
/// established terminology carefully instead of falsifying the source.
///
/// My Makeup Kit has no intensity at all — an owned product records what it is,
/// not how heavily it was used — so kit shades carry `null` here rather than a
/// guess.
enum TutorialIntensity {
  sheer('sheer'),
  soft('soft'),
  medium('medium'),
  bold('bold');

  const TutorialIntensity(this.code);

  /// The stable identifier, matching the upstream recommendation schema.
  final String code;

  /// Returns the intensity for [code], or `null` when [code] is absent, blank,
  /// or outside the validated vocabulary.
  ///
  /// Null means "no intensity to show", and callers render nothing. An
  /// unrecognised value is deliberately not coerced onto the nearest band: the
  /// upstream schema already restricts this field, so a value outside it
  /// signals drift, and displaying a guess would hide that.
  static TutorialIntensity? fromCode(String? code) {
    if (code == null) return null;
    final trimmed = code.trim().toLowerCase();
    for (final intensity in values) {
      if (intensity.code == trimmed) return intensity;
    }
    return null;
  }
}

/// The finish of a shade, from whichever vocabulary its mode actually uses.
///
/// Sealed because the two modes genuinely differ and flattening them would lose
/// information in one direction or the other. My Makeup Kit finishes come from
/// a database-constrained enum; Standard Mode finishes are free text the
/// recommendation schema bounds only by length. Forcing the kit value through a
/// string would discard the enum the UI already knows how to name, and forcing
/// the recommendation's wording into the enum would silently rewrite it.
sealed class TutorialFinish {
  const TutorialFinish();

  /// Wraps a controlled kit finish.
  factory TutorialFinish.fromKit(MakeupKitFinish finish) = ControlledFinish;

  /// Wraps a Standard Mode finish description.
  ///
  /// Returns `null` for absent or blank text, so an empty upstream field
  /// renders as nothing rather than as an empty row.
  static TutorialFinish? fromRecommendation(String? description) {
    final trimmed = description?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return DescribedFinish(trimmed);
  }
}

/// A finish from the controlled My Makeup Kit vocabulary.
final class ControlledFinish extends TutorialFinish {
  const ControlledFinish(this.finish);

  final MakeupKitFinish finish;
}

/// A finish described in the recommendation's own words.
final class DescribedFinish extends TutorialFinish {
  const DescribedFinish(this.description);

  /// Non-empty, trimmed. Brand-neutral by construction: the upstream schema has
  /// no brand, retailer, or product field for this text to have come from.
  final String description;
}

/// The colour block shown beside one tutorial step: what shade, what finish,
/// how strong.
///
/// Every field is optional because absence is a real, common state — a
/// category with no colour, an owned product the user never labelled, a kit
/// item with no intensity — and the rule throughout is that a missing value is
/// shown as missing, never filled in.
///
/// There is deliberately **no product-name field here**. Shade guidance and
/// product identity are separate authorities: Standard Mode must stay
/// brand-neutral, and My Makeup Kit product identity may come only from the
/// immutable validated snapshot. Giving this shared type a name field would
/// create somewhere for a brand to appear in Standard Mode, so kit product
/// names stay on [LookProductSnapshotItem] where their provenance is provable.
class TutorialShadeDetails {
  const TutorialShadeDetails({
    this.shadeName,
    this.color,
    this.finish,
    this.intensity,
  });

  /// A colour description — "Warm Rose", or the user's own shade label. Never
  /// a product to buy.
  final String? shadeName;

  final NormalizedHexColor? color;
  final TutorialFinish? finish;
  final TutorialIntensity? intensity;

  /// Whether there is anything at all worth rendering.
  bool get hasAnyDetail =>
      shadeName != null || color != null || finish != null || intensity != null;

  /// Reads the shade block out of a validated Standard Mode entry.
  ///
  /// Copies only what the frozen recommendation actually validated. A hex that
  /// fails to parse becomes `null` rather than a substituted colour.
  factory TutorialShadeDetails.fromStandardEntry(StandardLookEntry entry) {
    final name = entry.shadeName.trim();
    final hex = entry.colorHex;
    return TutorialShadeDetails(
      shadeName: name.isEmpty ? null : name,
      color: hex == null ? null : NormalizedHexColor.tryParse(hex),
      finish: TutorialFinish.fromRecommendation(entry.finish),
      intensity: TutorialIntensity.fromCode(entry.intensity),
    );
  }

  /// Reads the shade block out of an immutable owned-product snapshot item.
  ///
  /// The colour and finish are already typed and validated on the snapshot, so
  /// they carry across directly. Intensity is always `null`: the kit records no
  /// such value, and inferring one from the style or the product would be an
  /// invention.
  factory TutorialShadeDetails.fromSnapshotItem(LookProductSnapshotItem item) {
    final label = item.colorLabel?.trim();
    return TutorialShadeDetails(
      shadeName: label == null || label.isEmpty ? null : label,
      color: item.color,
      finish: TutorialFinish.fromKit(item.finish),
      intensity: null,
    );
  }
}
