import 'package:facetune/features/tutorial_v3/data/models/tutorial_v3_session_dto.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_canonical_preview.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_readiness.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_step_spec.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_retry_policy.dart';
import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

const _user = 'user-1';
const _analysis = 'analysis-1';

TutorialV3Session _session({
  TutorialV3SessionStatus status = TutorialV3SessionStatus.ready,
  int totalSteps = 2,
}) => TutorialV3Session(
  id: 'session-1',
  userId: _user,
  analysisId: _analysis,
  sourceMode: TutorialV3SourceMode.standard,
  recommendationId: 'recommendation-1',
  selectedStyleCode: testStyleCode,
  canonicalPreview: const TutorialV3CanonicalPreview(
    generatedImageId: 'generated-1',
    storagePath: '$_user/analyses/$_analysis/generated/r/preview_0001.png',
    sourceMode: TutorialV3SourceMode.standard,
  ),
  totalSteps: totalSteps,
  planVersion: TutorialV3PlanVersion.current,
  status: status,
  createdAt: DateTime.utc(2026, 8, 27),
  updatedAt: DateTime.utc(2026, 8, 27),
);

TutorialV3Step _step(
  TutorialV3StepSpec spec, {
  TutorialV3GeometryStatus? status,
  int attemptCount = 0,
}) {
  final resolved =
      status ??
      (spec.isFinalLook
          ? TutorialV3GeometryStatus.notRequired
          : TutorialV3GeometryStatus.pending);
  return TutorialV3Step(
    spec: spec,
    geometryStatus: resolved,
    // A ready step must carry a document: `hasGeometry` is the conjunction of
    // the two, so a ready-but-empty step would silently read as not ready.
    geometry: resolved == TutorialV3GeometryStatus.ready
        ? testGeometry(category: spec.category)
        : null,
    geometrySchemaVersion: resolved == TutorialV3GeometryStatus.ready
        ? tutorialV3GeometrySchemaVersion
        : null,
    attemptCount: attemptCount,
  );
}

TutorialV3LoadedSession _loaded({
  TutorialV3SessionStatus status = TutorialV3SessionStatus.ready,
  required List<TutorialV3Step> steps,
  int? totalSteps,
}) => TutorialV3LoadedSession(
  session: _session(status: status, totalSteps: totalSteps ?? steps.length),
  steps: steps,
);

void main() {
  group('readiness derivation', () {
    test('a session with no plan is planning', () {
      final loaded = _loaded(
        status: TutorialV3SessionStatus.planning,
        steps: const [],
        totalSteps: 0,
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.planning);
      expect(loaded.hasPlan, isFalse);
    });

    test('a failed plan reports failed regardless of steps', () {
      final loaded = _loaded(
        status: TutorialV3SessionStatus.failed,
        steps: [_step(guidelineStep(stepIndex: 1)), _step(finalLookStep())],
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.failed);
    });

    test('a step count that disagrees with the session is not a plan', () {
      // A partially written plan must never look usable.
      final loaded = _loaded(
        steps: [_step(guidelineStep(stepIndex: 1))],
        totalSteps: 5,
      );
      expect(loaded.hasPlan, isFalse);
      expect(loaded.readiness, TutorialV3SessionReadiness.planning);
    });

    test('a persisted plan with outstanding guidelines is plan_ready', () {
      final loaded = _loaded(
        steps: [_step(guidelineStep(stepIndex: 1)), _step(finalLookStep())],
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.planReady);
      expect(loaded.readiness.hasUsablePlan, isTrue);
    });

    test('a step in flight makes the session generating', () {
      final loaded = _loaded(
        steps: [
          _step(
            guidelineStep(stepIndex: 1),
            status: TutorialV3GeometryStatus.generating,
          ),
          _step(finalLookStep()),
        ],
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.generating);
    });

    test('every guideline present makes the session ready', () {
      final loaded = _loaded(
        steps: [
          _step(
            guidelineStep(stepIndex: 1),
            status: TutorialV3GeometryStatus.ready,
          ),
          _step(finalLookStep()),
        ],
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.ready);
    });

    test('the final look is never outstanding work', () {
      // A final-look-only plan is complete the moment it is persisted.
      final loaded = _loaded(steps: [_step(finalLookStep(stepIndex: 1))]);
      expect(loaded.geometrySteps, isEmpty);
      expect(loaded.readiness, TutorialV3SessionReadiness.ready);
    });

    test('a failed guideline leaves the session resumable, not failed', () {
      // Session `failed` means planning failed. One bad image does not.
      final loaded = _loaded(
        steps: [
          _step(
            guidelineStep(stepIndex: 1),
            status: TutorialV3GeometryStatus.failed,
            attemptCount: 1,
          ),
          _step(finalLookStep()),
        ],
      );
      expect(loaded.readiness, TutorialV3SessionReadiness.planReady);
    });
  });

  group('resume ordering', () {
    TutorialV3LoadedSession threeStep({
      TutorialV3GeometryStatus? first,
      int firstAttempts = 0,
    }) => _loaded(
      steps: [
        _step(
          guidelineStep(stepIndex: 1, category: TutorialV3Category.foundation),
          status: first,
          attemptCount: firstAttempts,
        ),
        _step(guidelineStep(stepIndex: 2, category: TutorialV3Category.blush)),
        _step(finalLookStep(stepIndex: 3)),
      ],
    );

    test('resumes at the first missing guideline', () {
      expect(
        threeStep().nextGeneratableStep(maxAttempts: 3)!.stepIndex,
        1,
      );
    });

    test('skips a completed step', () {
      expect(
        threeStep(
          first: TutorialV3GeometryStatus.ready,
        ).nextGeneratableStep(maxAttempts: 3)!.stepIndex,
        2,
      );
    });

    test('skips a step already in flight', () {
      expect(
        threeStep(
          first: TutorialV3GeometryStatus.generating,
        ).nextGeneratableStep(maxAttempts: 3)!.stepIndex,
        2,
      );
    });

    test('skips a step that has exhausted its retries', () {
      expect(
        threeStep(
          first: TutorialV3GeometryStatus.failed,
          firstAttempts: 3,
        ).nextGeneratableStep(maxAttempts: 3)!.stepIndex,
        2,
      );
    });

    test('retries a failed step that has attempts left', () {
      expect(
        threeStep(
          first: TutorialV3GeometryStatus.failed,
          firstAttempts: 1,
        ).nextGeneratableStep(maxAttempts: 3)!.stepIndex,
        1,
      );
    });

    test('returns null when nothing is left to generate', () {
      final loaded = _loaded(
        steps: [
          _step(
            guidelineStep(stepIndex: 1),
            status: TutorialV3GeometryStatus.ready,
          ),
          _step(finalLookStep()),
        ],
      );
      expect(loaded.nextGeneratableStep(maxAttempts: 3), isNull);
    });
  });

  group('retry policy', () {
    test('allows exactly the configured number of attempts', () {
      const max = TutorialV3RetryPolicy.maxGuidelineAttempts;
      for (var attempts = 0; attempts < max; attempts++) {
        expect(TutorialV3RetryPolicy.canAttemptAgain(attempts), isTrue);
      }
      expect(TutorialV3RetryPolicy.canAttemptAgain(max), isFalse);
      expect(TutorialV3RetryPolicy.canAttemptAgain(max + 1), isFalse);
    });

    test('reports remaining attempts without going negative', () {
      expect(
        TutorialV3RetryPolicy.attemptsRemaining(0),
        TutorialV3RetryPolicy.maxGuidelineAttempts,
      );
      expect(
        TutorialV3RetryPolicy.attemptsRemaining(
          TutorialV3RetryPolicy.maxGuidelineAttempts + 5,
        ),
        0,
      );
    });

    test('the bound is finite', () {
      expect(TutorialV3RetryPolicy.maxGuidelineAttempts, greaterThan(0));
      expect(TutorialV3RetryPolicy.maxGuidelineAttempts, lessThan(10));
    });
  });

  group('readiness vocabulary', () {
    test('incompatible is neither usable nor plannable', () {
      const readiness = TutorialV3SessionReadiness.incompatible;
      expect(readiness.hasUsablePlan, isFalse);
      expect(readiness.needsPlan, isFalse);
    });

    test('only the three post-plan states are usable', () {
      final usable = TutorialV3SessionReadiness.values
          .where((readiness) => readiness.hasUsablePlan)
          .toSet();
      expect(usable, {
        TutorialV3SessionReadiness.planReady,
        TutorialV3SessionReadiness.generating,
        TutorialV3SessionReadiness.ready,
      });
    });

    test('codes are unique and stable', () {
      final codes = TutorialV3SessionReadiness.values
          .map((readiness) => readiness.code)
          .toList();
      expect(codes.toSet(), hasLength(codes.length));
      expect(codes, containsAll(<String>['incompatible', 'plan_ready']));
    });
  });

  group('stale version handling at the DTO boundary', () {
    Map<String, Object?> row(int planVersion) => <String, Object?>{
      'id': 'session-1',
      'user_id': _user,
      'analysis_id': _analysis,
      'source_mode': TutorialV3SourceMode.standard.code,
      'recommendation_id': 'recommendation-1',
      'kit_recommendation_id': null,
      'makeup_style': testStyleCode,
      'canonical_generated_image_id': 'generated-1',
      'canonical_kit_generated_image_id': null,
      'canonical_image_path':
          '$_user/analyses/$_analysis/generated/r/preview_0001.png',
      'total_steps': 0,
      'plan_version': planVersion,
      'status': TutorialV3SessionStatus.planning.code,
      'created_at': DateTime.utc(2026, 8, 27),
      'updated_at': DateTime.utc(2026, 8, 27),
    };

    test('version 3 decodes as a loaded session', () {
      final snapshot = TutorialV3SessionDto.fromRows(
        session: row(3),
        steps: const [],
      );
      expect(snapshot, isA<TutorialV3LoadedSession>());
    });

    test('any other version decodes as incompatible', () {
      for (final version in [0, 1, 2, 4, 99]) {
        final snapshot = TutorialV3SessionDto.fromRows(
          session: row(version),
          steps: const [],
        );
        expect(
          snapshot,
          isA<TutorialV3IncompatibleSession>(),
          reason: 'version $version must not load',
        );
        expect(snapshot.readiness, TutorialV3SessionReadiness.incompatible);
      }
    });

    test('an unreadable row never decodes its steps', () {
      // These step rows are deliberately malformed for V3. Reaching the step
      // decoder at all would throw, so a clean incompatible result proves the
      // version gate runs first.
      final snapshot = TutorialV3SessionDto.fromRows(
        session: row(2),
        steps: const [
          {'step_index': 1, 'category': 'foundation_result'},
        ],
      );
      expect(snapshot, isA<TutorialV3IncompatibleSession>());
    });

    test('the session id stays available for reporting', () {
      final snapshot = TutorialV3SessionDto.fromRows(
        session: row(2),
        steps: const [],
      );
      expect(snapshot.sessionId, 'session-1');
    });
  });

  group('no cumulative-result machinery was ported', () {
    test('a step carries exactly one asset lifecycle', () {
      final step = _step(guidelineStep(stepIndex: 1));

      // V2 tracked a guideline AND a result per step, with the result of one
      // step feeding the next. V3 has one asset and no chain.
      expect(step.geometryStatus, isNotNull);
      expect(step.hasGeometry, isFalse);
      expect(
        TutorialV3GeometryStatus.values.map((status) => status.code),
        isNot(contains('result')),
      );
    });

    test('readiness never depends on a previous step', () {
      // Completing step 2 before step 1 is legal: steps are independent, so
      // the session is simply still plan_ready.
      final loaded = _loaded(
        steps: [
          _step(guidelineStep(stepIndex: 1)),
          _step(
            guidelineStep(stepIndex: 2, category: TutorialV3Category.blush),
            status: TutorialV3GeometryStatus.ready,
          ),
          _step(finalLookStep(stepIndex: 3)),
        ],
      );

      expect(loaded.readiness, TutorialV3SessionReadiness.planReady);
      expect(loaded.nextGeneratableStep(maxAttempts: 3)!.stepIndex, 1);
    });
  });
}
