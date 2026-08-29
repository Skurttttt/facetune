import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:facetune/features/tutorial_v2/data/models/tutorial_v2_session_dto.dart';
import 'package:facetune/features/tutorial_v2/data/models/tutorial_v2_step_spec_codec.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_product_snapshot.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session_snapshot.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_step_instructions.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutorial_v2_fixtures.dart';

TutorialV2SessionSnapshot decode({
  Map<String, Object?>? sessionRow,
  List<Map<String, Object?>>? stepRows,
}) => TutorialV2SessionDto.fromRows(
  sessionRow: sessionRow ?? tutorialV2SessionRow(),
  stepRows:
      stepRows ??
      tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]),
  attributes: tutorialV2FaceAttributes,
);

void main() {
  group('facial attributes codec', () {
    test('reads the snake_case codes stored on analyses', () {
      final attributes = TutorialV2FacialAttributesCodec.fromAnalysisRow(
        tutorialV2AnalysisRow(),
      );

      expect(attributes.faceShape, FaceShape.heart);
      expect(attributes.skinTone, SkinTone.medium);
      expect(attributes.undertone, Undertone.warm);
      expect(attributes.eyeShape, EyeShape.almond);
      expect(attributes.lipShape, LipShape.full);
      expect(attributes.hairColor, HairColor.darkBrown);
      expect(attributes.eyeColor, EyeColor.brown);
    });

    test('reads multi-word codes', () {
      final attributes = TutorialV2FacialAttributesCodec.fromAnalysisRow(
        tutorialV2AnalysisRow(
          skinTone: 'very_deep',
          eyeShape: 'deep_set',
          lipShape: 'heart_shaped',
        ),
      );

      expect(attributes.skinTone, SkinTone.veryDeep);
      expect(attributes.eyeShape, EyeShape.deepSet);
      expect(attributes.lipShape, LipShape.heartShaped);
    });

    test('rejects an unsupported value rather than guessing', () {
      expect(
        () => TutorialV2FacialAttributesCodec.fromAnalysisRow(
          tutorialV2AnalysisRow(faceShape: 'rhombus'),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('reading a healthy session', () {
    test('rebuilds the plan and its steps', () {
      final snapshot = decode();

      expect(snapshot.id, tutorialV2SessionId);
      expect(snapshot.userId, tutorialV2UserId);
      expect(snapshot.analysisId, tutorialV2AnalysisId);
      expect(snapshot.integrity, TutorialV2SessionIntegrity.intact);
      expect(snapshot.status, TutorialV2SessionStatus.planReady);
      expect(snapshot.plan, isNotNull);
      expect(snapshot.plan!.totalSteps, 3);
      expect(snapshot.steps.length, 3);
    });

    test('restores the session context', () {
      final context = decode().context;

      expect(context.sourceMode, TutorialV2SourceMode.standardRecommendation);
      expect(context.styleCode, 'soft_glam');
      expect(context.recommendation.recommendationId, 'rec-1');
      expect(context.canonicalFinalPreview.generatedImageId, 'generated-1');
      expect(context.planVersion.value, 2);
      expect(context.faceAttributes.faceShape, FaceShape.heart);
    });

    test('reads the Kit branch from the Kit columns', () {
      final context = decode(
        sessionRow: tutorialV2SessionRow(
          sourceMode: TutorialV2SourceMode.makeupKit,
          canonicalImageId: 'kit-generated-1',
        ),
      ).context;

      expect(context.sourceMode, TutorialV2SourceMode.makeupKit);
      expect(context.recommendation.kitRecommendationId, 'kit-rec-1');
      expect(context.recommendation.recommendationId, isNull);
      expect(context.canonicalFinalPreview.generatedImageId, 'kit-generated-1');
    });

    test('re-derives instructions rather than reading them back', () {
      // Nothing about the guideline or result intent is persisted, so a
      // reloaded step can only agree with its own written text.
      final step = decode().plan!.stepAt(1);

      expect(step.guidelineInstruction!.zones, step.whereToApply);
      expect(step.guidelineInstruction!.direction, step.direction);
      expect(step.resultInstruction.appliedDescription, step.whatToApply);
      expect(
        step.guidelineInstruction!.baseState,
        TutorialV2GuidelineBaseState.previousCumulativeResult,
      );
    });

    test('re-derives cumulative state from step order', () {
      final plan = decode().plan!;

      expect(plan.stepAt(0).previouslyCompletedCategories, isEmpty);
      expect(plan.stepAt(1).previouslyCompletedCategories, [
        TutorialV2Category.foundation,
      ]);
      expect(plan.finalStep.isCanonicalReuse, isTrue);
    });

    test('sorts rows by step index regardless of arrival order', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]).reversed.toList();

      final snapshot = decode(stepRows: rows);

      expect(snapshot.integrity, TutorialV2SessionIntegrity.intact);
      expect(
        snapshot.steps.map((step) => step.stepIndex).toList(),
        [0, 1, 2],
      );
      expect(snapshot.steps.first.spec.category, TutorialV2Category.foundation);
    });

    test('carries per-step asset state', () {
      final rows = tutorialV2StepRows([TutorialV2Category.blush]);
      rows[0] = {
        ...rows[0],
        'guideline_status': 'ready',
        'guideline_image_path': 'user-1/analyses/analysis-1/tutorial-v2/'
            'session-1/step_0001_guideline.png',
        'result_status': 'failed',
        'result_error': 'unchanged_generated_image',
        'retry_count': 2,
      };

      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(totalSteps: 2),
        stepRows: rows,
      );
      final step = snapshot.steps.first;

      expect(step.assets.guidelineStatus.isReady, isTrue);
      expect(step.assets.resultError, 'unchanged_generated_image');
      expect(step.assets.retryCount, 2);
      expect(step.hasFailure, isTrue);
    });
  });

  group('readiness', () {
    test('planning before a plan exists', () {
      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(status: 'planning', totalSteps: 0),
        stepRows: const [],
      );

      expect(snapshot.readiness, TutorialV2Readiness.planning);
      expect(snapshot.plan, isNull);
      expect(snapshot.isReusable, isTrue);
    });

    test('failed when planning failed', () {
      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(
          status: 'plan_failed',
          totalSteps: 0,
          planError: 'planner_invalid_json',
        ),
        stepRows: const [],
      );

      expect(snapshot.readiness, TutorialV2Readiness.failed);
      expect(snapshot.planError, 'planner_invalid_json');
    });

    test('plan ready when steps exist but assets do not', () {
      expect(decode().readiness, TutorialV2Readiness.planReady);
    });

    test('generating while an asset is in flight', () {
      final snapshot = decode(
        stepRows: tutorialV2StepRows([
          TutorialV2Category.foundation,
          TutorialV2Category.blush,
        ], guidelineStatus: 'generating'),
      );

      expect(snapshot.readiness, TutorialV2Readiness.generating);
    });

    test('ready once every required asset is ready', () {
      final snapshot = decode(
        stepRows: tutorialV2StepRows([
          TutorialV2Category.foundation,
          TutorialV2Category.blush,
        ], guidelineStatus: 'ready', resultStatus: 'ready'),
      );

      expect(snapshot.readiness, TutorialV2Readiness.ready);
      expect(snapshot.firstIncompleteStepIndex, isNull);
    });

    test('the final step needs no asset to be satisfied', () {
      final rows = tutorialV2StepRows([TutorialV2Category.blush]);
      // Only the makeup step gets assets; the final look row stays pending.
      rows[0] = {
        ...rows[0],
        'guideline_status': 'ready',
        'result_status': 'ready',
      };

      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(totalSteps: 2),
        stepRows: rows,
      );

      expect(snapshot.steps.last.spec.isCanonicalReuse, isTrue);
      expect(snapshot.steps.last.isSatisfied, isTrue);
      expect(snapshot.readiness, TutorialV2Readiness.ready);
    });

    test('failure outranks in-flight work', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ], guidelineStatus: 'generating');
      rows[1] = {...rows[1], 'result_status': 'failed'};

      expect(decode(stepRows: rows).readiness, TutorialV2Readiness.failed);
    });

    test('reports the first step still missing an asset', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ], guidelineStatus: 'ready', resultStatus: 'ready');
      rows[1] = {...rows[1], 'result_status': 'pending'};

      expect(decode(stepRows: rows).firstIncompleteStepIndex, 1);
    });
  });

  group('version mismatch', () {
    test('a V1 row is incompatible, not reinterpreted', () {
      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(planVersion: 1),
      );

      expect(snapshot.status, TutorialV2SessionStatus.incompatible);
      expect(snapshot.readiness, TutorialV2Readiness.incompatible);
      expect(snapshot.plan, isNull);
      expect(snapshot.steps, isEmpty);
      expect(snapshot.isReusable, isFalse);
    });

    test('a row from a newer build is incompatible too', () {
      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(planVersion: 99),
      );

      expect(snapshot.readiness, TutorialV2Readiness.incompatible);
    });

    test('an incompatible row is reported, never rewritten', () {
      final row = tutorialV2SessionRow(planVersion: 1);
      final before = Map<String, Object?>.from(row);

      decode(sessionRow: row);

      expect(row, before);
    });
  });

  group('stale and incomplete sessions', () {
    test('a ready plan with no step rows is stale', () {
      final snapshot = decode(stepRows: const []);

      expect(snapshot.integrity, TutorialV2SessionIntegrity.missingSteps);
      expect(snapshot.readiness, TutorialV2Readiness.stale);
      expect(snapshot.isReusable, isFalse);
    });

    test('a step count that disagrees with total_steps is stale', () {
      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(totalSteps: 8),
      );

      expect(snapshot.integrity, TutorialV2SessionIntegrity.stepCountMismatch);
      expect(snapshot.readiness, TutorialV2Readiness.stale);
    });

    test('duplicate step indexes are stale', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);
      rows[1] = {...rows[1], 'step_index': 0, 'id': 'step-dup'};

      final snapshot = decode(stepRows: rows);

      expect(
        snapshot.integrity,
        TutorialV2SessionIntegrity.duplicateStepIndex,
      );
    });

    test('an undecodable spec is stale rather than fatal', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);
      rows[0] = {...rows[0], 'step_spec_json': const {'schema': 1}};

      final snapshot = decode(stepRows: rows);

      expect(snapshot.integrity, TutorialV2SessionIntegrity.unreadableSpec);
      expect(snapshot.readiness, TutorialV2Readiness.stale);
    });

    test('a row whose category disagrees with its spec is stale', () {
      final rows = tutorialV2StepRows([
        TutorialV2Category.foundation,
        TutorialV2Category.blush,
      ]);
      rows[0] = {...rows[0], 'category': 'eyeliner'};

      expect(
        decode(stepRows: rows).integrity,
        TutorialV2SessionIntegrity.unreadableSpec,
      );
    });

    test('steps that no longer form a valid plan are stale', () {
      // Persisted ordering that violates the canonical progression.
      final drafts = tutorialV2Drafts([
        TutorialV2Category.lipGloss,
        TutorialV2Category.lipstick,
      ]);
      final rows = [
        for (var index = 0; index < drafts.length; index++)
          tutorialV2StepRow(stepIndex: index, draft: drafts[index]),
      ];

      expect(
        decode(stepRows: rows).integrity,
        TutorialV2SessionIntegrity.unreadableSpec,
      );
    });
  });

  group('Kit historical accuracy', () {
    test('reload validates products against the persisted snapshots', () {
      // The user could have deleted the product since. The snapshot is the
      // historical record, so the tutorial must still load.
      final draft = tutorialV2Draft(
        TutorialV2Category.lipstick,
        productSnapshot: tutorialV2Product(
          category: TutorialV2Category.lipstick,
          productId: 'deleted-product',
          productName: 'Studio Matte',
        ),
      );
      final rows = [
        tutorialV2StepRow(stepIndex: 0, draft: draft),
        tutorialV2StepRow(
          stepIndex: 1,
          draft: tutorialV2Draft(TutorialV2Category.finalLook),
        ),
      ];

      final snapshot = decode(
        sessionRow: tutorialV2SessionRow(
          sourceMode: TutorialV2SourceMode.makeupKit,
          canonicalImageId: 'kit-generated-1',
          totalSteps: 2,
        ),
        stepRows: rows,
      );

      expect(snapshot.integrity, TutorialV2SessionIntegrity.intact);
      final persisted = snapshot.steps.first.spec.productSnapshot!;
      expect(persisted.productId, 'deleted-product');
      expect(persisted.productName, 'Studio Matte');
    });
  });

  group('insert values', () {
    test('a new session starts with no plan', () {
      final values = TutorialV2SessionDto.insertValues(
        userId: tutorialV2UserId,
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(),
      );

      expect(values['status'], 'pending');
      expect(values['total_steps'], 0);
      expect(values['plan_version'], 2);
      expect(values['makeup_style'], 'soft_glam');
      expect(values['recommendation_id'], 'rec-1');
      expect(values['kit_recommendation_id'], isNull);
      expect(values['canonical_generated_image_id'], 'generated-1');
      expect(values['canonical_kit_generated_image_id'], isNull);
    });

    test('Kit mode writes only the Kit columns', () {
      final values = TutorialV2SessionDto.insertValues(
        userId: tutorialV2UserId,
        analysisId: tutorialV2AnalysisId,
        context: tutorialV2Context(
          sourceMode: TutorialV2SourceMode.makeupKit,
        ),
      );

      expect(values['recommendation_id'], isNull);
      expect(values['kit_recommendation_id'], 'kit-rec-1');
      expect(values['canonical_generated_image_id'], isNull);
      expect(values['canonical_kit_generated_image_id'], 'generated-1');
    });

    test('the final step is inserted with no guideline to generate', () {
      final plan = decode().plan!;
      final values = TutorialV2SessionDto.stepInsertValues(
        userId: tutorialV2UserId,
        sessionId: tutorialV2SessionId,
        step: plan.finalStep,
      );

      expect(values['category'], 'final_look');
      expect(values['guideline_status'], 'ready');
      expect(values['product_snapshot_json'], isNull);
    });

    test('a makeup step is inserted pending both assets', () {
      final plan = decode().plan!;
      final values = TutorialV2SessionDto.stepInsertValues(
        userId: tutorialV2UserId,
        sessionId: tutorialV2SessionId,
        step: plan.stepAt(0),
      );

      expect(values['guideline_status'], 'pending');
      expect(values['result_status'], 'pending');
      expect(values['step_index'], 0);
    });

    test('a step row round-trips through insert values', () {
      final plan = decode().plan!;
      final values = TutorialV2SessionDto.stepInsertValues(
        userId: tutorialV2UserId,
        sessionId: tutorialV2SessionId,
        step: plan.stepAt(1),
      );
      final decoded = TutorialV2StepSpecCodec.decodeDraft(
        values['step_spec_json'],
        productSnapshot: TutorialV2StepSpecCodec.decodeProduct(
          values['product_snapshot_json'],
        ),
      );

      expect(decoded.category, plan.stepAt(1).category);
      expect(decoded.whereToApply, plan.stepAt(1).whereToApply);
      expect(decoded.productSnapshot, isNull);
    });
  });

  group('malformed rows', () {
    test('an unknown source mode is rejected outright', () {
      expect(
        () => decode(
          sessionRow: {
            ...tutorialV2SessionRow(),
            'source_mode': 'freestyle',
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('a missing timestamp is rejected', () {
      expect(
        () => decode(
          sessionRow: {...tutorialV2SessionRow(), 'created_at': null},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('product snapshot codec', () {
    test('round-trips every field', () {
      final snapshot = tutorialV2Product(
        category: TutorialV2Category.foundation,
        productName: 'Second Skin',
        colorLabel: 'N200',
      );
      final decoded = TutorialV2StepSpecCodec.decodeProduct(
        TutorialV2StepSpecCodec.encodeProduct(snapshot),
      );

      expect(decoded, isA<TutorialV2ProductSnapshot>());
      expect(decoded, snapshot);
      expect(decoded!.shadeName, 'N200');
    });

    test('null round-trips as null', () {
      expect(TutorialV2StepSpecCodec.encodeProduct(null), isNull);
      expect(TutorialV2StepSpecCodec.decodeProduct(null), isNull);
    });

    test('rejects a final-look product', () {
      expect(
        () => TutorialV2StepSpecCodec.decodeProduct({
          'productId': 'p1',
          'category': 'final_look',
          'colorHex': '#B86F72',
          'finish': 'matte',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an invalid colour or finish', () {
      expect(
        () => TutorialV2StepSpecCodec.decodeProduct({
          'productId': 'p1',
          'category': 'blush',
          'colorHex': 'not-a-color',
          'finish': 'matte',
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => TutorialV2StepSpecCodec.decodeProduct({
          'productId': 'p1',
          'category': 'blush',
          'colorHex': '#B86F72',
          'finish': 'holographic',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('step spec codec', () {
    test('never persists derived instructions', () {
      final encoded = TutorialV2StepSpecCodec.encode(decode().plan!.stepAt(0));

      for (final key in [
        'guidelineInstruction',
        'resultInstruction',
        'stepIndex',
        'previouslyCompletedCategories',
        'cumulativeCategories',
      ]) {
        expect(encoded.containsKey(key), isFalse, reason: key);
      }
    });

    test('rejects a newer payload schema', () {
      expect(
        () => TutorialV2StepSpecCodec.decodeDraft({
          ...TutorialV2StepSpecCodec.encodeDraft(
            tutorialV2Draft(TutorialV2Category.blush),
          ),
          'schema': 99,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects an unknown category', () {
      expect(
        () => TutorialV2StepSpecCodec.decodeDraft({
          ...TutorialV2StepSpecCodec.encodeDraft(
            tutorialV2Draft(TutorialV2Category.blush),
          ),
          'category': 'glitter_beard',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a blank optional field rather than storing it', () {
      expect(
        () => TutorialV2StepSpecCodec.decodeDraft({
          ...TutorialV2StepSpecCodec.encodeDraft(
            tutorialV2Draft(TutorialV2Category.blush),
          ),
          'personalizedTip': '   ',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('preserves optional fields that are present', () {
      final draft = tutorialV2Draft(
        TutorialV2Category.blush,
        amount: 'One light sweep',
        toolSuggestion: 'Fluffy brush',
        personalizedTip: 'Keep colour high on the cheek.',
        avoid: 'Do not drag toward the nose.',
      );
      final decoded = TutorialV2StepSpecCodec.decodeDraft(
        TutorialV2StepSpecCodec.encodeDraft(draft),
      );

      expect(decoded.amount, 'One light sweep');
      expect(decoded.toolSuggestion, 'Fluffy brush');
      expect(decoded.personalizedTip, 'Keep colour high on the cheek.');
      expect(decoded.avoid, 'Do not drag toward the nose.');
    });
  });
}
