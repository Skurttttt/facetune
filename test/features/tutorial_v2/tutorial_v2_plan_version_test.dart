import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_generation_status.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan_version.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session.dart';
import 'package:facetune/features/tutorial_v2/domain/errors/tutorial_v2_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutorial_v2_fixtures.dart';

TutorialV2Plan _plan() => TutorialV2Plan.fromDrafts(
  context: tutorialV2Context(),
  drafts: tutorialV2Drafts([
    TutorialV2Category.foundation,
    TutorialV2Category.blush,
  ]),
);

void main() {
  group('plan version', () {
    test('a new plan is written at the current version', () {
      expect(TutorialV2PlanVersion.current.value, 2);
      expect(_plan().context.planVersion, TutorialV2PlanVersion.current);
    });

    test('the current version is readable', () {
      expect(TutorialV2PlanVersion.isSupported(2), isTrue);
      expect(TutorialV2PlanVersion.tryParse(2), isNotNull);
    });

    test('a V1 version is not readable as V2', () {
      expect(TutorialV2PlanVersion.isSupported(1), isFalse);
      expect(TutorialV2PlanVersion.isLegacyV1(1), isTrue);
      expect(TutorialV2PlanVersion.tryParse(1), isNull);
    });

    test('a newer version is not readable either', () {
      expect(TutorialV2PlanVersion.isSupported(3), isFalse);
      expect(TutorialV2PlanVersion.isFromNewerBuild(3), isTrue);
      expect(TutorialV2PlanVersion.tryParse(3), isNull);
    });

    test('parsing a V1 version names it as legacy', () {
      expect(
        () => TutorialV2PlanVersion.parse(1),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('legacy V1'),
          ),
        ),
      );
    });

    test('parsing a future version names it as newer', () {
      expect(
        () => TutorialV2PlanVersion.parse(9),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('newer build'),
          ),
        ),
      );
    });

    test('versions compare by value', () {
      expect(
        TutorialV2PlanVersion.parse(2),
        TutorialV2PlanVersion.current,
      );
      expect(
        TutorialV2PlanVersion.parse(2).hashCode,
        TutorialV2PlanVersion.current.hashCode,
      );
    });
  });

  group('session version guard', () {
    test('a current-version row is readable', () {
      expect(
        TutorialV2Session.requireReadableVersion(2),
        TutorialV2PlanVersion.current,
      );
    });

    test('a V1 row is rejected, not reinterpreted', () {
      expect(
        () => TutorialV2Session.requireReadableVersion(1),
        throwsA(
          isA<TutorialV2Failure>()
              .having(
                (failure) => failure.kind,
                'kind',
                TutorialV2FailureKind.incompatiblePlanVersion,
              )
              .having((failure) => failure.retryable, 'retryable', false)
              .having(
                (failure) => failure.message,
                'message',
                contains('earlier version'),
              ),
        ),
      );
    });

    test('a newer row asks the user to update', () {
      expect(
        () => TutorialV2Session.requireReadableVersion(5),
        throwsA(
          isA<TutorialV2Failure>()
              .having(
                (failure) => failure.kind,
                'kind',
                TutorialV2FailureKind.incompatiblePlanVersion,
              )
              .having(
                (failure) => failure.message,
                'message',
                contains('newer version'),
              ),
        ),
      );
    });
  });

  group('session', () {
    final now = DateTime.utc(2026, 8, 26);

    test('total steps comes from the plan, never from a caller', () {
      final plan = _plan();
      final session = TutorialV2Session.withPlan(
        id: 'session-1',
        userId: 'user-1',
        analysisId: 'analysis-1',
        plan: plan,
        createdAt: now,
        updatedAt: now,
      );

      expect(session.totalSteps, plan.totalSteps);
      expect(session.totalSteps, 3);
      expect(session.status, TutorialV2SessionStatus.planReady);
      expect(session.status.hasPlan, isTrue);
      expect(session.planVersion, TutorialV2PlanVersion.current);
      expect(session.isReadable, isTrue);
    });

    test('a planless session has no steps', () {
      final session = TutorialV2Session.withoutPlan(
        id: 'session-1',
        userId: 'user-1',
        analysisId: 'analysis-1',
        context: tutorialV2Context(),
        status: TutorialV2SessionStatus.planning,
        createdAt: now,
        updatedAt: now,
      );

      expect(session.plan, isNull);
      expect(session.totalSteps, 0);
      expect(session.status.hasPlan, isFalse);
    });

    test('a planless session cannot claim its plan is ready', () {
      expect(
        () => TutorialV2Session.withoutPlan(
          id: 'session-1',
          userId: 'user-1',
          analysisId: 'analysis-1',
          context: tutorialV2Context(),
          status: TutorialV2SessionStatus.planReady,
          createdAt: now,
          updatedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('an incompatible session is not readable', () {
      final session = TutorialV2Session.withoutPlan(
        id: 'session-1',
        userId: 'user-1',
        analysisId: 'analysis-1',
        context: tutorialV2Context(),
        status: TutorialV2SessionStatus.incompatible,
        createdAt: now,
        updatedAt: now,
      );

      expect(session.isReadable, isFalse);
    });
  });

  group('generation status', () {
    test('a fresh step has neither asset', () {
      const assets = TutorialV2StepAssets();

      expect(assets.guidelineStatus, TutorialV2GenerationStatus.pending);
      expect(assets.resultStatus, TutorialV2GenerationStatus.pending);
      expect(assets.isComplete, isFalse);
      expect(assets.isPartiallyReady, isFalse);
      expect(assets.hasFailure, isFalse);
    });

    test('one ready asset is partial readiness, not completion', () {
      const assets = TutorialV2StepAssets(
        guidelineStatus: TutorialV2GenerationStatus.ready,
        guidelinePath: 'guideline.png',
      );

      expect(assets.isPartiallyReady, isTrue);
      expect(assets.isComplete, isFalse);
    });

    test('both ready is completion', () {
      const assets = TutorialV2StepAssets(
        guidelineStatus: TutorialV2GenerationStatus.ready,
        resultStatus: TutorialV2GenerationStatus.ready,
      );

      expect(assets.isComplete, isTrue);
      expect(assets.isPartiallyReady, isFalse);
    });

    test('a failed asset is surfaced rather than left spinning', () {
      const assets = TutorialV2StepAssets(
        resultStatus: TutorialV2GenerationStatus.failed,
        resultError: 'unchanged_generated_image',
      );

      expect(assets.hasFailure, isTrue);
      expect(assets.resultStatus.isTerminal, isTrue);
    });

    test('an in-flight asset suppresses a duplicate request', () {
      expect(TutorialV2GenerationStatus.generating.isInFlight, isTrue);
      expect(TutorialV2GenerationStatus.pending.isInFlight, isFalse);
      expect(TutorialV2GenerationStatus.ready.isInFlight, isFalse);
    });

    test('copyWith advances one asset without touching the other', () {
      const assets = TutorialV2StepAssets();
      final updated = assets.copyWith(
        guidelineStatus: TutorialV2GenerationStatus.ready,
        guidelinePath: 'guideline.png',
      );

      expect(updated.guidelineStatus, TutorialV2GenerationStatus.ready);
      expect(updated.resultStatus, TutorialV2GenerationStatus.pending);
    });
  });

  group('code round-trips', () {
    test('every enum code parses back to its own value', () {
      for (final value in TutorialV2Category.values) {
        expect(TutorialV2Category.fromCode(value.code), value);
      }
      for (final value in TutorialV2GenerationStatus.values) {
        expect(TutorialV2GenerationStatus.fromCode(value.code), value);
      }
      for (final value in TutorialV2SessionStatus.values) {
        expect(TutorialV2SessionStatus.fromCode(value.code), value);
      }
    });

    test('an unknown code fails closed', () {
      expect(TutorialV2Category.fromCode('glitter_beard'), isNull);
      expect(TutorialV2GenerationStatus.fromCode('almost'), isNull);
      expect(TutorialV2SessionStatus.fromCode('vibes'), isNull);
    });
  });
}
