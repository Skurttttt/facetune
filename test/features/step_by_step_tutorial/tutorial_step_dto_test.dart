import 'package:facetune/features/step_by_step_tutorial/data/models/tutorial_step_dto.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_placement_metadata.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _instructionJson({
  Object? productName = 'Peach Rose Blush',
  Object? colorName = 'Peach Rose',
  Object? hex = '#E58C87',
  Object? finish = 'satin',
  String placement = 'Upper cheekbones',
  Object? direction = 'Blend upward toward temples',
  String intensity = 'light',
  String technique = 'Start with a small amount and build gradually.',
  Object? tip = 'Smile to find the apple of your cheek.',
}) => {
  'productName': productName,
  'colorName': colorName,
  'hex': hex,
  'finish': finish,
  'placement': placement,
  'direction': direction,
  'intensity': intensity,
  'technique': technique,
  'tip': tip,
};

Map<String, Object?> _validRow({
  String category = 'blush',
  Map<String, Object?>? instructionJson,
  List<Object?>? placementMetadataJson,
  Object? placementImagePath = 'user-1/analyses/analysis-1/original/img.jpg',
  Object? resultImagePath =
      'user-1/analyses/analysis-1/tutorials/session-1/step_0004_result.png',
  Object? modelName = 'gemini-3.1-flash-image',
  Object? imageSize = 512,
  Object? promptVersion = 'tutorial_step_v1',
  String generationStatus = 'completed',
}) => {
  'id': 'step-1',
  'tutorial_session_id': 'session-1',
  'step_number': 4,
  'category': category,
  'title': 'Blush',
  'instruction_json': instructionJson ?? _instructionJson(),
  'placement_metadata_json': placementMetadataJson ?? const [],
  'placement_image_path': placementImagePath,
  'result_image_path': resultImagePath,
  'model_name': modelName,
  'image_size': imageSize,
  'prompt_version': promptVersion,
  'generation_status': generationStatus,
  'created_at': '2026-08-14T00:00:00Z',
  'updated_at': '2026-08-14T00:00:00Z',
};

void main() {
  group('fromRow', () {
    test('parses a complete step row', () {
      final dto = TutorialStepDto.fromRow(_validRow());

      expect(dto.id, 'step-1');
      expect(dto.tutorialSessionId, 'session-1');
      expect(dto.stepNumber, 4);
      expect(dto.category, TutorialStepCategory.blush);
      expect(dto.title, 'Blush');
      expect(dto.instruction.placement, 'Upper cheekbones');
      expect(dto.instruction.category, TutorialStepCategory.blush);
      expect(dto.instruction.hex, '#E58C87');
      expect(dto.placementMetadata, isNull);
      expect(
        dto.placementImagePath,
        'user-1/analyses/analysis-1/original/img.jpg',
      );
      expect(dto.modelId, 'gemini-3.1-flash-image');
      expect(dto.imageSize, 512);
      expect(dto.generationStatus, TutorialStepGenerationStatus.completed);
      expect(dto.createdAt, DateTime.utc(2026, 8, 14));
    });

    test('parses placement overlay metadata', () {
      final dto = TutorialStepDto.fromRow(
        _validRow(
          placementMetadataJson: [
            {
              'type': 'zone',
              'points': [
                {'x': 0.3, 'y': 0.4},
                {'x': 0.5, 'y': 0.6},
              ],
              'label': 'Blush zone',
              'colorHex': '#E58C87',
            },
          ],
        ),
      );

      final overlays = dto.placementMetadata!.overlays;
      expect(overlays, hasLength(1));
      expect(overlays.single.type, TutorialPlacementOverlayType.zone);
      expect(overlays.single.points, hasLength(2));
      expect(overlays.single.points.first.x, 0.3);
      expect(overlays.single.label, 'Blush zone');
    });

    test('treats an empty overlay array as no placement metadata', () {
      final dto = TutorialStepDto.fromRow(
        _validRow(placementMetadataJson: const []),
      );

      expect(dto.placementMetadata, isNull);
    });

    test('parses optional image fields as null when absent', () {
      final dto = TutorialStepDto.fromRow(
        _validRow(
          placementImagePath: null,
          resultImagePath: null,
          modelName: null,
          imageSize: null,
          promptVersion: null,
          generationStatus: 'not_started',
        ),
      );

      expect(dto.placementImagePath, isNull);
      expect(dto.resultImagePath, isNull);
      expect(dto.modelId, isNull);
      expect(dto.imageSize, isNull);
      expect(dto.generationStatus, TutorialStepGenerationStatus.notStarted);
    });

    test('rejects an unsupported category code', () {
      expect(
        () => TutorialStepDto.fromRow(_validRow(category: 'mascara')),
        throwsFormatException,
      );
    });

    test('rejects a missing required instruction field', () {
      final row = _validRow(
        instructionJson: _instructionJson()..remove('placement'),
      );
      expect(() => TutorialStepDto.fromRow(row), throwsFormatException);
    });

    test('rejects a malformed instruction hex', () {
      final row = _validRow(instructionJson: _instructionJson(hex: 'nope'));
      expect(() => TutorialStepDto.fromRow(row), throwsFormatException);
    });

    test('rejects an unsupported overlay type code', () {
      final row = _validRow(
        placementMetadataJson: [
          {
            'type': 'sparkle',
            'points': [
              {'x': 0.1, 'y': 0.1},
            ],
          },
        ],
      );
      expect(() => TutorialStepDto.fromRow(row), throwsFormatException);
    });

    test('rejects a missing required field', () {
      final row = _validRow()..remove('id');
      expect(() => TutorialStepDto.fromRow(row), throwsFormatException);
    });
  });

  group('toDomain', () {
    test('carries through signed URLs supplied by the repository', () {
      final dto = TutorialStepDto.fromRow(_validRow());
      final step = dto.toDomain(
        placementImageUrl: 'https://signed.example/placement',
        resultImageUrl: 'https://signed.example/result',
      );

      expect(step.placementImageUrl, 'https://signed.example/placement');
      expect(step.resultImageUrl, 'https://signed.example/result');
      expect(step.id, dto.id);
    });
  });

  group('toInsertRow', () {
    test('includes the owner, category code, and json snapshots', () {
      final row = TutorialStepDto.toInsertRow(
        userId: 'user-1',
        tutorialSessionId: 'session-1',
        stepNumber: 4,
        title: 'Blush',
        instruction: const TutorialInstruction(
          category: TutorialStepCategory.blush,
          placement: 'Upper cheekbones',
          intensity: 'light',
          technique: 'Blend upward.',
          hex: '#E58C87',
        ),
      );

      expect(row['user_id'], 'user-1');
      expect(row['tutorial_session_id'], 'session-1');
      expect(row['step_number'], 4);
      expect(row['category'], 'blush');
      expect(row['title'], 'Blush');
      expect(
        row['instruction_json'],
        containsPair('placement', 'Upper cheekbones'),
      );
      expect(row['placement_metadata_json'], isEmpty);
    });
  });

  group('imagesUpdateRow', () {
    test('omits arguments that were not provided', () {
      final row = TutorialStepDto.imagesUpdateRow(resultImagePath: 'a/b.png');

      expect(row, {'result_image_path': 'a/b.png'});
    });
  });

  group('statusUpdateRow', () {
    test('maps the enum to its persisted code', () {
      expect(
        TutorialStepDto.statusUpdateRow(TutorialStepGenerationStatus.failed),
        {'generation_status': 'failed'},
      );
    });
  });
}
