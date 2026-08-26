import 'package:facetune/features/step_by_step_tutorial/data/models/tutorial_session_dto.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_generation_status.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_source_mode.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_step_category.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _geometryStep({
  String category = 'blush',
  double confidence = 0.9,
  List<Map<String, Object?>> zones = const [],
}) => {
  'category': category,
  'placement': 'Sweep across the upper cheekbones.',
  'direction': 'outward',
  'intensity': 'medium',
  'technique': 'Blend with a fluffy brush.',
  'confidence': confidence,
  'colorHex': null,
  'finish': null,
  'zones': zones.isNotEmpty
      ? zones
      : [
          {
            'shape': 'polygon',
            'points': [
              {'x': 0.3, 'y': 0.5},
              {'x': 0.35, 'y': 0.55},
              {'x': 0.32, 'y': 0.6},
            ],
            'confidence': confidence,
          },
        ],
  'paths': const [],
  'arrows': const [],
};

TutorialStep _step({
  String id = 'step-1',
  TutorialStepCategory category = TutorialStepCategory.blush,
}) => TutorialStep(
  id: id,
  tutorialSessionId: 'session-1',
  stepNumber: 1,
  category: category,
  title: 'Blush',
  instruction: TutorialInstruction(
    category: category,
    placement: 'Upper cheekbones',
    intensity: 'light',
    technique: 'Blend upward.',
  ),
  generationStatus: TutorialStepGenerationStatus.notStarted,
  createdAt: DateTime.utc(2026, 8, 14),
  updatedAt: DateTime.utc(2026, 8, 14),
);

Map<String, Object?> _validRow({
  String sourceMode = 'standard_recommendation',
  Object? recommendationId = 'recommendation-1',
  Object? kitRecommendationId,
  Object? tutorialModel = 'gemini-3.1-flash-image',
  Object? tutorialImageSize = 512,
  Object? promptVersion = 'tutorial_session_v1',
  String generationStatus = 'planning',
}) => {
  'id': 'session-1',
  'user_id': 'user-1',
  'source_mode': sourceMode,
  'analysis_id': 'analysis-1',
  'recommendation_id': recommendationId,
  'kit_recommendation_id': kitRecommendationId,
  'makeup_style': 'soft_glam',
  'generation_number': 1,
  'total_steps': 8,
  'generation_status': generationStatus,
  'tutorial_model': tutorialModel,
  'tutorial_image_size': tutorialImageSize,
  'prompt_version': promptVersion,
  'created_at': '2026-08-14T00:00:00Z',
  'updated_at': '2026-08-14T00:00:00Z',
};

void main() {
  group('fromRow', () {
    test('parses a complete standard-mode session row', () {
      final session = TutorialSessionDto.fromRow(_validRow(), steps: const []);

      expect(session.id, 'session-1');
      expect(session.userId, 'user-1');
      expect(session.sourceMode, TutorialSourceMode.standardRecommendation);
      expect(session.sourceAnalysisId, 'analysis-1');
      expect(session.sourceRecommendationId, 'recommendation-1');
      expect(session.sourceKitResultId, isNull);
      expect(session.styleCode, 'soft_glam');
      expect(session.generationNumber, 1);
      expect(session.totalSteps, 8);
      expect(session.generationStatus, TutorialGenerationStatus.planning);
      expect(session.tutorialModel, 'gemini-3.1-flash-image');
      expect(session.tutorialImageSize, 512);
      expect(session.steps, isEmpty);
    });

    test('parses a kit-mode session row', () {
      final session = TutorialSessionDto.fromRow(
        _validRow(
          sourceMode: 'makeup_kit',
          recommendationId: null,
          kitRecommendationId: 'kit-recommendation-1',
        ),
        steps: const [],
      );

      expect(session.sourceMode, TutorialSourceMode.makeupKit);
      expect(session.sourceRecommendationId, isNull);
      expect(session.sourceKitResultId, 'kit-recommendation-1');
    });

    test('parses optional session-level fields as null when absent', () {
      final session = TutorialSessionDto.fromRow(
        _validRow(
          tutorialModel: null,
          tutorialImageSize: null,
          promptVersion: null,
        ),
        steps: const [],
      );

      expect(session.tutorialModel, isNull);
      expect(session.tutorialImageSize, isNull);
      expect(session.promptVersion, isNull);
    });

    test('rejects an unsupported source mode code', () {
      expect(
        () => TutorialSessionDto.fromRow(
          _validRow(sourceMode: 'legacy_mode'),
          steps: const [],
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing required field', () {
      final row = _validRow()..remove('makeup_style');
      expect(
        () => TutorialSessionDto.fromRow(row, steps: const []),
        throwsFormatException,
      );
    });

    test('geometryPlan is null when geometry_plan_json is absent', () {
      final session = TutorialSessionDto.fromRow(_validRow(), steps: const []);
      expect(session.geometryPlan, isNull);
    });

    test('geometryPlan is null while a claim is only mid-flight, not yet a '
        'real plan', () {
      final row = _validRow();
      row['geometry_plan_json'] = {'planning': true};
      final session = TutorialSessionDto.fromRow(row, steps: const []);
      expect(session.geometryPlan, isNull);
    });

    test('a real geometry_plan_json is parsed and applied to matching steps '
        '(TF-3 activation, applied automatically inside fromRow)', () {
      final row = _validRow();
      row['geometry_plan_json'] = {
        'steps': [_geometryStep(category: 'blush')],
      };
      row['geometry_plan_version'] = 'tutorial_geometry_plan_v1';
      row['geometry_model'] = 'gemini-3.6-flash';

      final session = TutorialSessionDto.fromRow(
        row,
        steps: [_step(category: TutorialStepCategory.blush)],
      );

      expect(session.geometryPlan, isNotNull);
      expect(session.geometryPlan!.steps, hasLength(1));
      expect(session.geometryPlanVersion, 'tutorial_geometry_plan_v1');
      expect(session.geometryModel, 'gemini-3.6-flash');
      // Activation already ran -- the step's placement metadata now
      // carries the real overlay, not the empty one it started with.
      expect(session.steps.single.placementMetadata!.overlays, isNotEmpty);
    });

    test('a step whose category the plan does not cover is left untouched', () {
      final row = _validRow();
      row['geometry_plan_json'] = {
        'steps': [_geometryStep(category: 'blush')],
      };

      final session = TutorialSessionDto.fromRow(
        row,
        steps: [_step(category: TutorialStepCategory.lipstick)],
      );

      expect(session.steps.single.placementMetadata, isNull);
    });
  });

  group('fromResponse', () {
    test('unwraps the {session: ...} envelope and delegates to fromRow', () {
      final session = TutorialSessionDto.fromResponse({
        'session': _validRow(),
      }, steps: const []);
      expect(session.id, 'session-1');
    });

    test('rejects a payload missing the session key', () {
      expect(
        () => TutorialSessionDto.fromResponse({}, steps: const []),
        throwsFormatException,
      );
    });

    test('rejects a non-object payload', () {
      expect(
        () => TutorialSessionDto.fromResponse('not an object', steps: const []),
        throwsFormatException,
      );
    });
  });

  group('toInsertRow', () {
    test('carries the owner and source-mode code', () {
      final row = TutorialSessionDto.toInsertRow(
        userId: 'user-1',
        sourceMode: TutorialSourceMode.makeupKit,
        analysisId: 'analysis-1',
        kitRecommendationId: 'kit-recommendation-1',
        styleCode: 'soft_glam',
        generationNumber: 2,
        totalSteps: 6,
      );

      expect(row['user_id'], 'user-1');
      expect(row['source_mode'], 'makeup_kit');
      expect(row['kit_recommendation_id'], 'kit-recommendation-1');
      expect(row['recommendation_id'], isNull);
      expect(row['generation_number'], 2);
      expect(row['total_steps'], 6);
    });
  });

  group('statusUpdateRow', () {
    test('maps the enum to its persisted code', () {
      expect(
        TutorialSessionDto.statusUpdateRow(
          TutorialGenerationStatus.partiallyComplete,
        ),
        {'generation_status': 'partially_complete'},
      );
    });
  });
}
