import 'dart:async';

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_geometry_mapper.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_geometry_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

/// Records every mapping request and lets a test decide when it finishes.
class _FakeMapper implements TutorialV3GeometryMapper {
  final List<({String sessionId, int stepIndex, TutorialV3Category category})>
  calls = [];

  /// Steps whose mapping should fail rather than succeed.
  final Set<int> failing = <int>{};

  /// Steps whose mapping is held open until the test completes them.
  final Map<int, Completer<TutorialV3Geometry>> pending = {};

  int callsFor(int stepIndex) =>
      calls.where((call) => call.stepIndex == stepIndex).length;

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) {
    calls.add((
      sessionId: sessionId,
      stepIndex: stepIndex,
      category: expectedCategory,
    ));
    if (failing.contains(stepIndex)) {
      return Future.error(
        const TutorialV3Failure(
          'This step could not be prepared.',
          kind: TutorialV3FailureKind.generation,
        ),
      );
    }
    final held = pending[stepIndex];
    if (held != null) return held.future;
    return Future.value(testGeometry(category: expectedCategory));
  }
}

void main() {
  late _FakeMapper mapper;
  late TutorialV3GeometryCoordinator coordinator;

  setUp(() {
    mapper = _FakeMapper();
    coordinator = TutorialV3GeometryCoordinator(mapper);
  });

  /// A one-step-plus-final session whose first step holds a document written
  /// against [schemaVersion].
  TutorialV3LoadedSession sessionWithStoredVersion(int schemaVersion) {
    final spec = guidelineStep(
      stepIndex: 1,
      category: TutorialV3Category.foundation,
    );
    return TutorialV3LoadedSession(
      session: testSession(totalSteps: 2),
      steps: [
        testStep(
          spec,
          geometryStatus: TutorialV3GeometryStatus.ready,
          geometry: testGeometry(
            category: TutorialV3Category.foundation,
            schemaVersion: schemaVersion,
          ),
          geometrySchemaVersion: schemaVersion,
        ),
        testStep(finalLookStep(stepIndex: 2)),
      ],
    );
  }

  group('prefetch depth', () {
    test('the default depth is one', () {
      expect(tutorialV3PrefetchDepth, 1);
    });

    test('only the next step is targeted', () {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );

      expect(
        coordinator.prefetchTargets(session: session, currentStepIndex: 1),
        [2],
      );
    });

    test('prefetching maps exactly the current step plus one', () async {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );

      await coordinator.ensureGeometry(session: session, stepIndex: 1);
      await coordinator.prefetch(session: session, currentStepIndex: 1);

      expect(mapper.calls.map((call) => call.stepIndex), [1, 2]);
      expect(
        mapper.callsFor(3),
        0,
        reason: 'depth 1 must not reach two steps ahead',
      );
    });

    test('the final look is never a prefetch target', () {
      final session = loadedSession(
        categories: const [TutorialV3Category.foundation],
      );

      // Step 2 is the final look.
      expect(
        coordinator.prefetchTargets(session: session, currentStepIndex: 1),
        isEmpty,
      );
    });

    test('nothing is targeted past the end of the plan', () {
      final session = loadedSession(
        categories: const [TutorialV3Category.foundation],
      );

      expect(
        coordinator.prefetchTargets(session: session, currentStepIndex: 2),
        isEmpty,
      );
    });

    test('a step that already has geometry is not prefetched again', () {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
        ],
        readyUpTo: 2,
      );

      expect(
        coordinator.prefetchTargets(session: session, currentStepIndex: 1),
        isEmpty,
      );
    });

    test('a depth of zero disables prefetching', () {
      final session = loadedSession();

      expect(
        coordinator.prefetchTargets(
          session: session,
          currentStepIndex: 1,
          depth: 0,
        ),
        isEmpty,
      );
    });
  });

  group('duplicate prevention', () {
    test('two concurrent requests for one step share a single call', () async {
      final session = loadedSession();
      mapper.pending[1] = Completer<TutorialV3Geometry>();

      final first = coordinator.ensureGeometry(session: session, stepIndex: 1);
      final second = coordinator.ensureGeometry(session: session, stepIndex: 1);
      expect(coordinator.isMapping(session.sessionId, 1), isTrue);

      mapper.pending[1]!.complete(
        testGeometry(category: TutorialV3Category.foundation),
      );
      final results = await Future.wait([first, second]);

      expect(mapper.callsFor(1), 1, reason: 'the second must join the first');
      expect(results.first, same(results.last));
    });

    test('a prefetch already in flight is not started twice', () async {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );
      mapper.pending[2] = Completer<TutorialV3Geometry>();

      final firstPass = coordinator.prefetch(
        session: session,
        currentStepIndex: 1,
      );
      // A second pass while the first is still outstanding — what a double tap
      // on Next produces.
      expect(
        coordinator.prefetchTargets(session: session, currentStepIndex: 1),
        isEmpty,
      );

      mapper.pending[2]!.complete(
        testGeometry(category: TutorialV3Category.blush),
      );
      await firstPass;

      expect(mapper.callsFor(2), 1);
    });

    test('the in-flight record is released once a call settles', () async {
      final session = loadedSession();

      await coordinator.ensureGeometry(session: session, stepIndex: 1);

      expect(coordinator.isMapping(session.sessionId, 1), isFalse);
    });

    test('a failed call releases its in-flight record too', () async {
      final session = loadedSession();
      mapper.failing.add(1);

      await expectLater(
        coordinator.ensureGeometry(session: session, stepIndex: 1),
        throwsA(isA<TutorialV3Failure>()),
      );

      expect(
        coordinator.isMapping(session.sessionId, 1),
        isFalse,
        reason: 'a stuck record would block every retry',
      );
    });
  });

  group('reuse', () {
    test('persisted geometry is used without a call', () async {
      final session = loadedSession(readyUpTo: 1);

      final geometry = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 1,
      );

      expect(geometry, isNotNull);
      expect(mapper.calls, isEmpty, reason: 'a reopened step must not re-map');
    });

    test('revisiting a mapped step reads the cache', () async {
      final session = loadedSession();

      final first = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 1,
      );
      final second = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 1,
      );

      expect(mapper.callsFor(1), 1);
      expect(second, same(first));
    });

    test('cached geometry is available synchronously', () async {
      final session = loadedSession();
      await coordinator.ensureGeometry(session: session, stepIndex: 1);

      expect(coordinator.cached(session: session, stepIndex: 1), isNotNull);
    });

    test('an unmapped step has nothing cached', () {
      final session = loadedSession();

      expect(coordinator.cached(session: session, stepIndex: 1), isNull);
    });

    test(
      'the mapper is told the category from the persisted Step Spec',
      () async {
        final session = loadedSession(
          categories: const [
            TutorialV3Category.foundation,
            TutorialV3Category.eyeliner,
          ],
        );

        await coordinator.ensureGeometry(session: session, stepIndex: 2);

        expect(mapper.calls.single.category, TutorialV3Category.eyeliner);
      },
    );
  });

  group('version invalidation', () {
    test('persisted geometry from another schema is re-mapped', () async {
      // A step that looks complete but was written by another build. Rendering
      // it would draw a vocabulary this build does not know.
      final session = sessionWithStoredVersion(
        tutorialV3GeometrySchemaVersion - 1,
      );

      expect(coordinator.cached(session: session, stepIndex: 1), isNull);

      await coordinator.ensureGeometry(session: session, stepIndex: 1);

      expect(mapper.callsFor(1), 1, reason: 'stale work must be redone');
    });

    test('a stale document is never written into the cache', () async {
      final session = sessionWithStoredVersion(
        tutorialV3GeometrySchemaVersion + 1,
      );

      coordinator.cached(session: session, stepIndex: 1);

      expect(coordinator.cache.length, 0);
    });

    test('invalidating a session drops its cached work', () async {
      final session = loadedSession();
      await coordinator.ensureGeometry(session: session, stepIndex: 1);

      coordinator.invalidateSession(session.sessionId);

      expect(coordinator.cached(session: session, stepIndex: 1), isNull);
    });
  });

  group('the final step maps nothing', () {
    test('it resolves to no geometry without calling the mapper', () async {
      final session = loadedSession(
        categories: const [TutorialV3Category.foundation],
      );

      final geometry = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 2,
      );

      expect(geometry, isNull);
      expect(mapper.calls, isEmpty);
    });

    test('it is never cached', () async {
      final session = loadedSession(
        categories: const [TutorialV3Category.foundation],
      );
      await coordinator.ensureGeometry(session: session, stepIndex: 2);

      expect(coordinator.cached(session: session, stepIndex: 2), isNull);
      expect(coordinator.cache.length, 0);
    });
  });

  group('failure handling', () {
    test('a failed prefetch is swallowed', () async {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );
      mapper.failing.add(2);

      await expectLater(
        coordinator.prefetch(session: session, currentStepIndex: 1),
        completes,
      );
    });

    test('a failed prefetch leaves the current step untouched', () async {
      final session = loadedSession(
        categories: const [
          TutorialV3Category.foundation,
          TutorialV3Category.blush,
          TutorialV3Category.lipstick,
        ],
      );
      final current = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 1,
      );
      mapper.failing.add(2);

      await coordinator.prefetch(session: session, currentStepIndex: 1);

      expect(coordinator.cached(session: session, stepIndex: 1), same(current));
      expect(coordinator.cached(session: session, stepIndex: 2), isNull);
    });

    test('a failed step is mapped again on the next request', () async {
      final session = loadedSession();
      mapper.failing.add(1);
      await expectLater(
        coordinator.ensureGeometry(session: session, stepIndex: 1),
        throwsA(isA<TutorialV3Failure>()),
      );

      mapper.failing.remove(1);
      final geometry = await coordinator.ensureGeometry(
        session: session,
        stepIndex: 1,
      );

      expect(geometry, isNotNull);
      expect(mapper.callsFor(1), 2);
    });

    test('a step outside the plan is rejected, not mapped', () {
      final session = loadedSession();

      expect(
        () => coordinator.ensureGeometry(session: session, stepIndex: 99),
        throwsA(
          isA<TutorialV3Failure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialV3FailureKind.notFound,
          ),
        ),
      );
      expect(mapper.calls, isEmpty);
    });
  });

  group('the request carries identifiers only', () {
    test('the mapper receives the session and step, nothing more', () async {
      final session = loadedSession();

      await coordinator.ensureGeometry(session: session, stepIndex: 1);

      final call = mapper.calls.single;
      expect(call.sessionId, session.sessionId);
      expect(call.stepIndex, 1);
    });

    test('no step geometry is ever an input to another step', () async {
      // Mapping step 2 after step 1 must look identical to mapping step 2
      // alone: no cumulative state, no previous-guideline dependency.
      final session = loadedSession();
      await coordinator.ensureGeometry(session: session, stepIndex: 1);
      mapper.calls.clear();

      await coordinator.ensureGeometry(session: session, stepIndex: 2);

      expect(mapper.calls.single.stepIndex, 2);
      expect(mapper.calls.single.category, TutorialV3Category.blush);
    });
  });
}
