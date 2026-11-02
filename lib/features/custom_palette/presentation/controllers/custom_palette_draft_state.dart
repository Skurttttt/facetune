import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../../domain/catalog/custom_palette_catalog.dart';
import '../../domain/catalog/custom_palette_color_model.dart';
import '../../domain/validation/custom_palette_contract.dart';

enum CustomPaletteDraftStatus { editing, submitting, submitted, failed }

/// The in-progress choice for one category.
class CustomPaletteDraftSelection {
  const CustomPaletteDraftSelection({
    this.enabled = false,
    this.base,
    this.saturation = 0,
    this.lightness = 0,
    this.finish,
  });

  /// A disabled category keeps its values for re-enabling but is never sent.
  final bool enabled;
  final CustomPaletteSwatch? base;
  final int saturation;
  final int lightness;
  final MakeupKitFinish? finish;

  /// The authoritative final color; `null` until a base is chosen.
  NormalizedHexColor? get adjustedColor {
    final swatch = base;
    if (swatch == null) return null;
    return CustomPaletteColorModel.adjust(
      swatch.color,
      saturation: saturation,
      lightness: lightness,
    );
  }

  bool get isAdjusted => base != null && adjustedColor != base!.color;

  /// What the user reads as the color's name. Never the source of truth.
  String? get colorName {
    final swatch = base;
    if (swatch == null) return null;
    return isAdjusted ? '${swatch.label}, adjusted' : swatch.label;
  }

  bool get isComplete => base != null && finish != null;

  CustomPaletteDraftSelection copyWith({
    bool? enabled,
    CustomPaletteSwatch? base,
    int? saturation,
    int? lightness,
    MakeupKitFinish? finish,
  }) => CustomPaletteDraftSelection(
    enabled: enabled ?? this.enabled,
    base: base ?? this.base,
    saturation: saturation ?? this.saturation,
    lightness: lightness ?? this.lightness,
    finish: finish ?? this.finish,
  );
}

/// The single in-progress palette on the client.
///
/// This is a draft, never history: the server's frozen palette is the only
/// record of what a generated look used.
class CustomPaletteDraftState {
  const CustomPaletteDraftState({
    this.analysisId,
    this.styleCode,
    this.selections = const {},
    this.status = CustomPaletteDraftStatus.editing,
    this.paletteRequestId,
    this.derivedFromPaletteId,
    this.message,
    this.retryable = false,
  });

  final String? analysisId;
  final String? styleCode;
  final Map<MakeupKitCategory, CustomPaletteDraftSelection> selections;
  final CustomPaletteDraftStatus status;

  /// Issued on the first submit and kept across retries of that request.
  final String? paletteRequestId;
  final String? derivedFromPaletteId;
  final String? message;
  final bool retryable;

  bool get isSubmitting => status == CustomPaletteDraftStatus.submitting;

  CustomPaletteDraftSelection selectionFor(MakeupKitCategory category) =>
      selections[category] ?? const CustomPaletteDraftSelection();

  /// The enabled categories, in canonical order.
  List<MakeupKitCategory> get enabledCategories => [
    for (final category in CustomPaletteCatalog.categories)
      if (selectionFor(category).enabled) category,
  ];

  /// The enabled selections as canonical wire values.
  List<CustomPaletteSelectionInput> get inputs => [
    for (final category in enabledCategories)
      CustomPaletteSelectionInput(
        categoryCode: category.code,
        baseColorValue: selectionFor(category).base?.hex,
        adjustedColorValue: selectionFor(category).adjustedColor?.value,
        colorLabel: selectionFor(category).base?.label,
        finishCode: selectionFor(category).finish?.code,
      ),
  ];

  List<CustomPaletteIssue> get issues =>
      CustomPaletteValidator.validate(inputs);

  bool get isValid => issues.isEmpty;
}
