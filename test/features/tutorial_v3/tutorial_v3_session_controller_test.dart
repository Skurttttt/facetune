import 'dart:async';

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_images.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_geometry_mapper.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_planner.dart';
import 'package:facetune/features/tutorial_v3/domain/repositories/tutorial_v3_repository.dart';
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_geometry_coordinator.dart';
import 'package:facetune/features/tutorial_v3/presentation/controllers/tutorial_v3_session_controller.dart';
import 'package:facetune/features/tutorial_v3/presentation/controllers/tutorial_v3_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

/// Serves whatever session the test sets, and records how often it is read.
///
/// Only the methods the controller uses are implemented. The rest belong to
/// the persistence phase and are deliberately left unimplemented so a future
/// controller change that reaches for one is caught here.
class _FakeRepository implements TutorialV3Repository {
  _FakeRepository(this.snapshot);

  TutorialV3SessionSnapshot? snapshot;
  int getOrCreateCalls = 0;
  int findCalls = 0;
  int imageLoads = 0;
  TutorialV3Failure? openFailure;
  TutorialV3Failure? imagesFailure;

  @override
  Future<TutorialV3SessionSnapshot> openSession(
    TutorialV3EntryPoint entry,
  ) async {
    getOrCreateCalls++;
    final failure = openFailure;
    if (failure != null) throw failure;
    return snapshot!;
  }

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) async {
    findCalls++;
    return snapshot;
  }

  @override
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session) async {
    imageLoads++;
    final failure = imagesFailure;
    if (failure != null) throw failure;
    return const TutorialV3SessionImages(
      originalSelfieUrl: 'https://example.test/selfie.jpg',
      canonicalPreviewUrl: 'https://example.test/preview.png',
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not part of V3-7');
}

class _FakePlanner implements TutorialV3Planner {
  int calls = 0;
  TutorialV3Failure? failure;

  /// What the repository should return once planning has "happened".
  void Function()? onPlan;

  @override
  Future<void> plan({required String sessionId}) async {
    calls++;
    final error = failure;
    if (error != null) throw error;
    onPlan?.call();
  }
}

class _FakeMapper implements TutorialV3GeometryMapper {
  final List<int> calls = [];
  final Set<int> failing = <int>{};
  final Map<int, Completer<TutorialV3Geometry>> pending = {};

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) {
    calls.add(stepIndex);
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

const TutorialV3EntryPoint _entry = TutorialV3EntryPoint(
  canonicalImageId: "generated-1",
  sourceMode: TutorialV3SourceMode.standard,
);

void main() {
  late _FakeRepository repository;
  late _FakePlanner planner;
  late _FakeMapper mapper;
  late TutorialV3GeometryCoordinator coordinator;
  late TutorialV3SessionController controller;
  late List<TutorialV3SessionState> emitted;

  void build({TutorialV3SessionSnapshot? snapshot}) {
    repository = _FakeRepository(snapshot ?? loadedSession());
    planner = _FakePlanner();
    mapper = _FakeMapper();
    coordinator = TutorialV3GeometryCoordinator(mapper);
    controller = TutorialV3SessionController(
      repository: repository,
      planner: planner,
      coordinator: coordinator,
    );
    emitted = [];
    controller.addListener(emitted.add, fireImmediately: false);
  }

  setUp(build);
  tearDown(() => controller.dispose());

  group('opening', () {
    test('a planned session goes straight to its first step', () async {
      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.currentStepIndex, 1);
      expect(controller.state.totalSteps, 3);
      expect(planner.calls, 0, reason: 'a persisted plan must be reused');
    });

    test('an unplanned session is planned once, then read back', () async {
      repository.snapshot = TutorialV3LoadedSession(
        session: testSession(totalSteps: 0),
        steps: const [],
      );
      planner.onPlan = () => repository.snapshot = loadedSession();

      await controller.open(_entry);

      expect(planner.calls, 1);
      expect(
        repository.findCalls,
        1,
        reason: 'the plan is read from the database, not the response',
      );
      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.totalSteps, 3);
    });

    test('the planning phase is visible while it runs', () async {
      repository.snapshot = TutorialV3LoadedSession(
        session: testSession(totalSteps: 0),
        steps: const [],
      );
      planner.onPlan = () => repository.snapshot = loadedSession();

      await controller.open(_entry);

      expect(
        emitted.map((state) => state.phase),
        containsAllInOrder([
          TutorialV3Phase.opening,
          TutorialV3Phase.planning,
          TutorialV3Phase.ready,
        ]),
      );
    });

    test('a planning failure fails the tutorial, not a step', () async {
      repository.snapshot = TutorialV3LoadedSession(
        session: testSession(totalSteps: 0),
        steps: const [],
      );
      planner.failure = const TutorialV3Failure(
        'The tutorial service is temporarily unavailable.',
        kind: TutorialV3FailureKind.unavailable,
      );

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.failed);
      expect(controller.state.retryable, isTrue);
      expect(
        controller.state.message,
        'The tutorial service is temporarily unavailable.',
      );
    });

    test('a session this build cannot read is reported, never guessed at', () {
      build(
        snapshot: const TutorialV3IncompatibleSession(
          sessionId: 'session-legacy',
          persistedPlanVersion: 2,
        ),
      );

      return controller.open(_entry).then((_) {
        expect(controller.state.phase, TutorialV3Phase.failed);
        expect(controller.state.loaded, isNull);
        expect(controller.state.steps, isEmpty);
        expect(mapper.calls, isEmpty);
      });
    });

    test('reopening resumes an existing tutorial by id', () async {
      repository.snapshot = loadedSession(readyUpTo: 1);

      await controller.reopen('session-1');

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.currentStepIndex, 1);
      expect(controller.state.hasOverlay, isTrue);
      expect(
        mapper.calls,
        isNot(contains(1)),
        reason: "step 1's finished work must be reused, not re-mapped",
      );
    });

    test('reopening a tutorial that is gone reports not found', () async {
      repository.snapshot = null;

      await controller.reopen('session-missing');

      expect(controller.state.phase, TutorialV3Phase.failed);
      expect(controller.state.retryable, isFalse);
    });
  });

  group('current step geometry', () {
    test('a missing overlay is mapped and shown', () async {
      await controller.open(_entry);

      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
      expect(controller.state.geometry, isNotNull);
      expect(mapper.calls, contains(1));
    });

    test('a loading state is shown while mapping', () async {
      mapper.pending[1] = Completer<TutorialV3Geometry>();

      final opening = controller.open(_entry);
      await Future<void>.delayed(Duration.zero);
      expect(
        controller.state.geometryPhase,
        TutorialV3StepGeometryPhase.loading,
      );

      mapper.pending[1]!.complete(
        testGeometry(category: TutorialV3Category.foundation),
      );
      await opening;

      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
    });

    test('cached geometry appears with no loading state at all', () async {
      // Persisted geometry is already usable, so a revisit must not flash a
      // spinner for work that is finished.
      repository.snapshot = loadedSession(readyUpTo: 2);

      await controller.open(_entry);

      expect(
        emitted.map((state) => state.geometryPhase),
        isNot(contains(TutorialV3StepGeometryPhase.loading)),
      );
      expect(controller.state.hasOverlay, isTrue);
    });

    test('a failed overlay leaves the tutorial readable', () async {
      mapper.failing.add(1);

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(
        controller.state.geometryPhase,
        TutorialV3StepGeometryPhase.failed,
      );
      expect(controller.state.geometry, isNull);
      expect(controller.state.canRetryGeometry, isTrue);
      // The instruction text is still there, which is the whole point.
      expect(controller.state.currentStep, isNotNull);
      expect(controller.state.totalSteps, 3);
    });

    test('retrying a failed overlay maps it again', () async {
      mapper.failing.add(1);
      await controller.open(_entry);

      mapper.failing.remove(1);
      await controller.retryGeometry();

      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
      expect(mapper.calls.where((step) => step == 1), hasLength(2));
    });
  });

  group('prefetch', () {
    test('the next step is warmed while the current one is read', () async {
      await controller.open(_entry);

      expect(mapper.calls, [1, 2]);
      expect(
        coordinator.cached(session: controller.state.loaded!, stepIndex: 2),
        isNotNull,
      );
    });

    test('moving to a prefetched step is instant', () async {
      await controller.open(_entry);
      emitted.clear();

      await controller.next();

      expect(controller.state.currentStepIndex, 2);
      expect(controller.state.hasOverlay, isTrue);
      expect(
        emitted.map((state) => state.geometryPhase),
        isNot(contains(TutorialV3StepGeometryPhase.loading)),
      );
      expect(
        mapper.calls.where((step) => step == 2),
        hasLength(1),
        reason: 'the prefetched result must be reused, not re-mapped',
      );
    });

    test('a failed prefetch does not disturb the current step', () async {
      mapper.failing.add(2);

      await controller.open(_entry);

      expect(controller.state.currentStepIndex, 1);
      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
      expect(controller.state.message, isNull);
      expect(controller.state.phase, TutorialV3Phase.ready);
    });

    test(
      'a step whose prefetch failed is mapped normally on arrival',
      () async {
        mapper.failing.add(2);
        await controller.open(_entry);

        mapper.failing.remove(2);
        await controller.next();

        expect(
          controller.state.geometryPhase,
          TutorialV3StepGeometryPhase.ready,
        );
        expect(controller.state.currentStepIndex, 2);
      },
    );

    test('nothing is prefetched past the last guideline step', () async {
      repository.snapshot = loadedSession(
        categories: const [TutorialV3Category.foundation],
      );

      await controller.open(_entry);

      expect(mapper.calls, [1], reason: 'step 2 is the final look');
    });
  });

  group('navigation', () {
    test('next and previous move within the plan', () async {
      await controller.open(_entry);

      await controller.next();
      expect(controller.state.currentStepIndex, 2);

      await controller.previous();
      expect(controller.state.currentStepIndex, 1);
    });

    test('navigation stops at both ends', () async {
      await controller.open(_entry);
      expect(controller.state.canGoPrevious, isFalse);

      await controller.previous();
      expect(controller.state.currentStepIndex, 1);

      await controller.goToStep(3);
      expect(controller.state.canGoNext, isFalse);
      await controller.next();
      expect(controller.state.currentStepIndex, 3);
    });

    test('an index outside the plan is ignored', () async {
      await controller.open(_entry);

      await controller.goToStep(99);

      expect(controller.state.currentStepIndex, 1);
    });

    test('revisiting an earlier step reuses its geometry', () async {
      await controller.open(_entry);
      await controller.next();
      final callsBefore = mapper.calls.length;

      await controller.previous();

      expect(controller.state.hasOverlay, isTrue);
      expect(mapper.calls, hasLength(callsBefore));
    });
  });

  group('the final step', () {
    test('it maps no geometry at all', () async {
      await controller.open(_entry);
      mapper.calls.clear();

      await controller.goToStep(3);

      expect(controller.state.isFinalStep, isTrue);
      expect(
        controller.state.geometryPhase,
        TutorialV3StepGeometryPhase.notRequired,
      );
      expect(controller.state.geometry, isNull);
      expect(mapper.calls, isEmpty);
    });

    test('it is still a normal, readable step', () async {
      await controller.open(_entry);
      await controller.goToStep(3);

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.currentStep, isNotNull);
      expect(controller.state.canGoPrevious, isTrue);
    });
  });

  group('stale results', () {
    test('a slow overlay never lands on a step the user has left', () async {
      mapper.pending[1] = Completer<TutorialV3Geometry>();
      final opening = controller.open(_entry);
      await Future<void>.delayed(Duration.zero);

      // The user pages on while step 1 is still mapping.
      final moving = controller.goToStep(2);
      mapper.pending[1]!.complete(
        testGeometry(category: TutorialV3Category.foundation),
      );
      await Future.wait([opening, moving]);

      expect(controller.state.currentStepIndex, 2);
      expect(
        controller.state.geometry?.category,
        TutorialV3Category.blush,
        reason: "step 1's result must not be shown on step 2",
      );
    });
  });
}
