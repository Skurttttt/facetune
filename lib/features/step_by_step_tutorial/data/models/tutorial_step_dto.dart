import '../../domain/entities/tutorial_generation_status.dart';
import '../../domain/entities/tutorial_instruction.dart';
import '../../domain/entities/tutorial_placement_metadata.dart';
import '../../domain/entities/tutorial_step.dart';
import '../../domain/entities/tutorial_step_category.dart';

/// Maps between raw `tutorial_steps` Supabase rows and the [TutorialStep]
/// domain entity.
///
/// Every raw value is defensively re-validated here — a database row is
/// untrusted input, even though the columns are also constrained at the
/// schema level
/// (`supabase/migrations/20260814000300_tutorial_sessions_steps.sql`).
///
/// Unlike `MakeupKitProductDto`, this stays an instance rather than a bag of
/// static methods: building the domain [TutorialStep] requires signed image
/// URLs, which only the repository can fetch (async, requires a Supabase
/// call). [fromRow] parses everything synchronously available; [toDomain]
/// combines it with those URLs once the repository has them — the same
/// two-phase split `GeneratedPreviewDto` uses.
class TutorialStepDto {
  const TutorialStepDto({
    required this.id,
    required this.tutorialSessionId,
    required this.stepNumber,
    required this.category,
    required this.title,
    required this.instruction,
    required this.generationStatus,
    required this.createdAt,
    required this.updatedAt,
    this.placementMetadata,
    this.placementImagePath,
    this.resultImagePath,
    this.modelId,
    this.imageSize,
    this.promptVersion,
  });

  final String id;
  final String tutorialSessionId;
  final int stepNumber;
  final TutorialStepCategory category;
  final String title;
  final TutorialInstruction instruction;
  final TutorialPlacementMetadata? placementMetadata;
  final String? placementImagePath;
  final String? resultImagePath;
  final String? modelId;
  final int? imageSize;
  final String? promptVersion;
  final TutorialStepGenerationStatus generationStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory TutorialStepDto.fromRow(Map<String, Object?> row) {
    final category = _requiredEnum(
      row,
      'category',
      TutorialStepCategory.fromCode,
    );
    return TutorialStepDto(
      id: _requiredString(row, 'id'),
      tutorialSessionId: _requiredString(row, 'tutorial_session_id'),
      stepNumber: _requiredInt(row, 'step_number'),
      category: category,
      title: _requiredString(row, 'title'),
      instruction: _instructionFromJson(row['instruction_json'], category),
      placementMetadata: _placementMetadataFromJson(
        row['placement_metadata_json'],
      ),
      placementImagePath: _optionalString(row, 'placement_image_path'),
      resultImagePath: _optionalString(row, 'result_image_path'),
      modelId: _optionalString(row, 'model_name'),
      imageSize: _optionalInt(row, 'image_size'),
      promptVersion: _optionalString(row, 'prompt_version'),
      generationStatus: _requiredEnum(
        row,
        'generation_status',
        TutorialStepGenerationStatus.fromCode,
      ),
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
    );
  }

  TutorialStep toDomain({String? placementImageUrl, String? resultImageUrl}) =>
      TutorialStep(
        id: id,
        tutorialSessionId: tutorialSessionId,
        stepNumber: stepNumber,
        category: category,
        title: title,
        instruction: instruction,
        placementMetadata: placementMetadata,
        placementImagePath: placementImagePath,
        placementImageUrl: placementImageUrl,
        resultImagePath: resultImagePath,
        resultImageUrl: resultImageUrl,
        modelId: modelId,
        imageSize: imageSize,
        promptVersion: promptVersion,
        generationStatus: generationStatus,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Column values for inserting a new step owned by [userId].
  static Map<String, Object?> toInsertRow({
    required String userId,
    required String tutorialSessionId,
    required int stepNumber,
    required String title,
    required TutorialInstruction instruction,
    TutorialPlacementMetadata? placementMetadata,
  }) => {
    'user_id': userId,
    'tutorial_session_id': tutorialSessionId,
    'step_number': stepNumber,
    'category': instruction.category.code,
    'title': title,
    'instruction_json': _instructionToJson(instruction),
    'placement_metadata_json': _placementMetadataToJson(placementMetadata),
  };

  /// Column values for a partial update of a step's image references. Only
  /// non-null arguments are included, so unrelated columns are left alone.
  static Map<String, Object?> imagesUpdateRow({
    String? placementImagePath,
    String? resultImagePath,
    String? modelId,
    int? imageSize,
    String? promptVersion,
  }) => {
    'placement_image_path': ?placementImagePath,
    'result_image_path': ?resultImagePath,
    'model_name': ?modelId,
    'image_size': ?imageSize,
    'prompt_version': ?promptVersion,
  };

  static Map<String, Object?> statusUpdateRow(
    TutorialStepGenerationStatus status,
  ) => {'generation_status': status.code};

  static TutorialInstruction _instructionFromJson(
    Object? value,
    TutorialStepCategory category,
  ) {
    final data = _object(value, 'instruction_json');
    return TutorialInstruction(
      category: category,
      placement: _requiredString(data, 'placement'),
      intensity: _requiredString(data, 'intensity'),
      technique: _requiredString(data, 'technique'),
      productName: _optionalString(data, 'productName'),
      colorName: _optionalString(data, 'colorName'),
      hex: _optionalHex(data, 'hex'),
      finish: _optionalString(data, 'finish'),
      direction: _optionalString(data, 'direction'),
      tip: _optionalString(data, 'tip'),
    );
  }

  static Map<String, Object?> _instructionToJson(
    TutorialInstruction instruction,
  ) => {
    'productName': instruction.productName,
    'colorName': instruction.colorName,
    'hex': instruction.hex,
    'finish': instruction.finish,
    'placement': instruction.placement,
    'direction': instruction.direction,
    'intensity': instruction.intensity,
    'technique': instruction.technique,
    'tip': instruction.tip,
  };

  static TutorialPlacementMetadata? _placementMetadataFromJson(Object? value) {
    if (value is! List) {
      throw const FormatException('placement_metadata_json must be an array.');
    }
    if (value.isEmpty) return null;
    final overlays = value.map((entry) {
      final data = _object(entry, 'overlay');
      final rawPoints = data['points'];
      if (rawPoints is! List) {
        throw const FormatException('overlay points must be an array.');
      }
      final points = rawPoints.map((point) {
        final pointData = _object(point, 'point');
        return TutorialPlacementPoint(
          _requiredDouble(pointData, 'x'),
          _requiredDouble(pointData, 'y'),
        );
      }).toList();
      return TutorialPlacementOverlay(
        type: _requiredEnum(
          data,
          'type',
          TutorialPlacementOverlayType.fromCode,
        ),
        points: List.unmodifiable(points),
        label: _optionalString(data, 'label'),
        colorHex: _optionalHex(data, 'colorHex'),
      );
    }).toList();
    return TutorialPlacementMetadata(overlays: List.unmodifiable(overlays));
  }

  static List<Map<String, Object?>> _placementMetadataToJson(
    TutorialPlacementMetadata? metadata,
  ) {
    if (metadata == null) return const [];
    return metadata.overlays
        .map(
          (overlay) => {
            'type': overlay.type.code,
            'points': overlay.points
                .map((point) => {'x': point.x, 'y': point.y})
                .toList(),
            'label': overlay.label,
            'colorHex': overlay.colorHex,
          },
        )
        .toList();
  }

  static Map<String, Object?> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object.');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static String _requiredString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string when present.');
    }
    return value;
  }

  static int _requiredInt(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static int? _optionalInt(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! int) throw FormatException('$key must be an integer.');
    return value;
  }

  static double _requiredDouble(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value is! num) throw FormatException('$key must be a number.');
    return value.toDouble();
  }

  static String? _optionalHex(Map<String, Object?> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String || !RegExp(r'^#[0-9A-F]{6}$').hasMatch(value)) {
      throw FormatException('$key is not a valid HEX color.');
    }
    return value;
  }

  static T _requiredEnum<T>(
    Map<String, Object?> data,
    String key,
    T? Function(String code) fromCode,
  ) {
    final value = data[key];
    if (value is! String) throw FormatException('$key must be a string.');
    final parsed = fromCode(value);
    if (parsed == null) {
      throw FormatException('$key contains an unsupported value.');
    }
    return parsed;
  }
}
