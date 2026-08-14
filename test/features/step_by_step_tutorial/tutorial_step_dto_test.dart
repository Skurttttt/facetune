import 'package:facetune/features/step_by_step_tutorial/data/models/tutorial_step_dto.dart';
import 'package:facetune/features/step_by_step_tutorial/data/models/personalized_tutorial_step_spec_codec.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/personalized_tutorial.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
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
  Object? personalizedSpecJson,
}) => {
  'id': 'step-1',
  'tutorial_session_id': 'session-1',
  'step_number': 4,
  'category': category,
  'title': 'Blush',
  'instruction_json': instructionJson ?? _instructionJson(),
  'placement_metadata_json': placementMetadataJson ?? const [],
  'personalized_spec_json': personalizedSpecJson,
  'placement_image_path': placementImagePath,
  'result_image_path': resultImagePath,
  'model_name': modelName,
  'image_size': imageSize,
  'prompt_version': promptVersion,
  'generation_status': generationStatus,
  'created_at': '2026-08-14T00:00:00Z',
  'updated_at': '2026-08-14T00:00:00Z',
};

PersonalizedTutorialStepSpec _personalizedSpec() {
  final snapshot = TutorialKitProductSnapshot(
    productId: 'owned-7',
    category: TutorialStepCategory.blush,
    productName: 'Owned Peach Blush',
    colorName: 'Peach Rose',
    colorHex: '#E58C87',
    finish: 'satin',
  );
  return PersonalizedTutorialStepSpec(
    stepNumber: 4,
    what: PersonalizedTutorialWhat(
      category: TutorialStepCategory.blush,
      productName: snapshot.productName,
      colorName: snapshot.colorName,
      colorHex: snapshot.colorHex,
      finish: snapshot.finish,
      kitSnapshot: snapshot,
    ),
    where: PersonalizedTutorialWhere(
      description: 'Upper outer cheeks',
      regions: const {TutorialPlacementRegion.cheek},
      side: TutorialPlacementSide.bilateral,
      geometryConfidence: TutorialPlacementConfidence.high,
      placementConfidence: TutorialPlacementConfidence.high,
      overlays: [
        PersonalizedTutorialOverlay(
          type: TutorialPlacementOverlayType.zone,
          region: TutorialPlacementRegion.cheek,
          colorHex: '#E58C87',
        ),
      ],
      geometryAnchors: [
        PersonalizedTutorialGeometryAnchor(
          region: TutorialPlacementRegion.cheek,
          side: TutorialGeometrySide.left,
          points: [TutorialNormalizedPoint(x: 0.30, y: 0.52)],
        ),
      ],
    ),
    how: PersonalizedTutorialHow(
      direction: TutorialDirection.upwardOutward,
      intensity: TutorialIntensity.light,
      technique: TutorialTechnique('Diffuse with a soft brush'),
      tip: 'Build gradually.',
    ),
    faceAdjustment: 'Lift placement for a round face.',
    styleAdjustment: 'Keep the Korean finish softly diffused.',
  );
}

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

    test('reopening restores the exact personalized plan snapshot', () {
      final original = _personalizedSpec();
      final saved = PersonalizedTutorialStepSpecCodec.toJson(original);

      final reopened = TutorialStepDto.fromRow(
        _validRow(personalizedSpecJson: saved),
      ).toDomain();

      final restored = reopened.personalizedSpec!;
      expect(PersonalizedTutorialStepSpecCodec.toJson(restored), saved);
      expect(restored.where.description, 'Upper outer cheeks');
      expect(restored.how.direction, TutorialDirection.upwardOutward);
      expect(restored.faceAdjustment, 'Lift placement for a round face.');
      expect(
        restored.where.geometryConfidence,
        TutorialPlacementConfidence.high,
      );
      expect(restored.what.kitSnapshot!.productId, 'owned-7');
      expect(restored.what.kitSnapshot!.productName, 'Owned Peach Blush');
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

  group('fromResponse', () {
    test('unwraps the {step: ...} envelope and delegates to fromRow', () {
      final dto = TutorialStepDto.fromResponse({'step': _validRow()});

      expect(dto.id, 'step-1');
      expect(dto.category, TutorialStepCategory.blush);
      expect(dto.generationStatus, TutorialStepGenerationStatus.completed);
    });

    test('rejects a payload missing the step key', () {
      expect(
        () => TutorialStepDto.fromResponse({'notStep': _validRow()}),
        throwsFormatException,
      );
    });

    test('rejects a non-object payload', () {
      expect(
        () => TutorialStepDto.fromResponse('not an object'),
        throwsFormatException,
      );
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
      final personalizedSpec = _personalizedSpec();
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
        personalizedSpec: personalizedSpec,
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
      expect(
        row['personalized_spec_json'],
        PersonalizedTutorialStepSpecCodec.toJson(personalizedSpec),
      );
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

  group('resetRow', () {
    test(
      'explicitly nulls every image/metadata column, unlike imagesUpdateRow',
      () {
        expect(TutorialStepDto.resetRow(), {
          'placement_image_path': null,
          'result_image_path': null,
          'model_name': null,
          'image_size': null,
          'prompt_version': null,
          'generation_status': 'not_started',
        });
      },
    );
  });
}
