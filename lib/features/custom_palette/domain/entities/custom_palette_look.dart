import '../../../analysis/domain/entities/face_analysis.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../../../makeup_styles/domain/entities/makeup_style.dart';

/// One category of a frozen palette, exactly as the server stored it.
///
/// This is history, not a draft. Everything shown for a generated look comes from
/// here and never from the editor's current state or catalog defaults.
class CustomPaletteShade {
  const CustomPaletteShade({
    required this.category,
    required this.baseColor,
    required this.adjustedColor,
    required this.colorLabel,
    required this.finish,
  });

  final MakeupKitCategory category;
  final NormalizedHexColor baseColor;

  /// The authoritative final color.
  final NormalizedHexColor adjustedColor;

  /// The base swatch's name. Presentation only.
  final String colorLabel;
  final MakeupKitFinish finish;

  bool get isAdjusted => adjustedColor != baseColor;

  String get colorName => isAdjusted ? '$colorLabel, adjusted' : colorLabel;
}

/// The AI's guidance for one category. It holds no color and no finish.
class CustomPaletteApplication {
  const CustomPaletteApplication({
    required this.categoryCode,
    required this.placement,
    required this.technique,
    required this.intensity,
    required this.reasoning,
  });

  final String categoryCode;
  final String placement;
  final String technique;
  final String intensity;
  final String reasoning;
}

/// One frozen palette and the plan derived from it. [id] is the palette id.
class CustomPaletteRecommendation {
  const CustomPaletteRecommendation({
    required this.id,
    required this.analysisId,
    required this.styleCode,
    required this.palette,
    required this.applications,
    required this.overallIntensity,
    required this.summary,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
    this.derivedFromPaletteId,
  });

  final String id;
  final String analysisId;
  final String styleCode;
  final List<CustomPaletteShade> palette;
  final List<CustomPaletteApplication> applications;
  final String overallIntensity;
  final String summary;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;
  final String? derivedFromPaletteId;

  CustomPaletteApplication? applicationFor(MakeupKitCategory category) {
    for (final application in applications) {
      if (application.categoryCode == category.code) return application;
    }
    return null;
  }
}

/// One accepted preview. Only accepted candidates ever exist on the server.
class CustomPaletteGeneratedPreview {
  const CustomPaletteGeneratedPreview({
    required this.id,
    required this.analysisId,
    required this.recommendationId,
    required this.originalImagePath,
    required this.generatedImagePath,
    required this.originalImageUrl,
    required this.generatedImageUrl,
    required this.generationNumber,
    required this.modelId,
    required this.promptVersion,
    required this.createdAt,
  });

  final String id;
  final String analysisId;
  final String recommendationId;
  final String originalImagePath;
  final String generatedImagePath;
  final String originalImageUrl;
  final String generatedImageUrl;
  final int generationNumber;
  final String modelId;
  final String promptVersion;
  final DateTime createdAt;
}

class CustomPaletteLookResult {
  const CustomPaletteLookResult({
    required this.analysis,
    required this.style,
    required this.recommendation,
    required this.preview,
  });

  final FaceAnalysis analysis;
  final MakeupStyle style;
  final CustomPaletteRecommendation recommendation;
  final CustomPaletteGeneratedPreview preview;
}

class CustomPaletteSavedLook {
  const CustomPaletteSavedLook({
    required this.id,
    required this.result,
    required this.isFavorite,
    required this.createdAt,
  });

  final String id;
  final CustomPaletteLookResult result;
  final bool isFavorite;
  final DateTime createdAt;

  CustomPaletteSavedLook copyWith({bool? isFavorite}) => CustomPaletteSavedLook(
    id: id,
    result: result,
    isFavorite: isFavorite ?? this.isFavorite,
    createdAt: createdAt,
  );
}

class CustomPaletteHistoryEntry {
  const CustomPaletteHistoryEntry({required this.result, this.savedLook});

  final CustomPaletteLookResult result;
  final CustomPaletteSavedLook? savedLook;

  String get id => result.preview.id;
  bool get isFavorite => savedLook?.isFavorite == true;
}

class CustomPalettePage<T> {
  const CustomPalettePage({required this.items, required this.hasMore});

  final List<T> items;
  final bool hasMore;
}
