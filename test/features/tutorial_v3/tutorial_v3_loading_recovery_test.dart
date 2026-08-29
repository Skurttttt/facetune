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
import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_timeouts.dart';
import 'package:facetune/features/tutorial_v3/presentation/controllers/tutorial_v3_session_controller.dart';
import 'package:facetune/features/tutorial_v3/presentation/controllers/tutorial_v3_session_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

/// V3-10F2 — the tutorial must always stop loading.
///
/// A real-device test found the screen stuck on "Opening your tutorial…"
/// indefinitely. `open_tutorial_v3_session` is not yet applied to the database,
/// so PostgREST answered with an exception the controller did not catch: every
/// path caught `TutorialV3Failure` and nothing else, so an infrastructure
/// error escaped, `_fail` never ran, and the state stayed `opening` forever.
/// There was also no timeout anywhere in the V3 stack, so a call that never
/// answered had the same effect.
///
/// Every test here fails if the error boundary or the timeout is removed.
/// They deliberately throw things that are *not* domain failures, because
/// domain failures were never the problem.

/// Stands in for a `PostgrestException` — an exception the app has no
/// vocabulary for, whose text carries internals a user must never be shown.
class _InfrastructureException implements Exception {
  const _InfrastructureException();

  @override
  String toString() =>
      'PGRST202: Could not find the function '
      'public.open_tutorial_v3_session(p_generated_image_id, p_kit) '
      'in the schema cache';
}

class _FakeRepository implements TutorialV3Repository {
  _FakeRepository(this.snapshot);

  TutorialV3SessionSnapshot? snapshot;

  /// What `openSession` should do. Defaults to returning [snapshot].
  Future<TutorialV3SessionSnapshot> Function()? onOpen;
  Future<TutorialV3SessionSnapshot?> Function()? onFind;
  Future<TutorialV3SessionImages> Function()? onLoadImages;

  int openCalls = 0;

  @override
  Future<TutorialV3SessionSnapshot> openSession(
    TutorialV3EntryPoint entry,
  ) async {
    openCalls++;
    final behaviour = onOpen;
    if (behaviour != null) return behaviour();
    return snapshot!;
  }

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) async {
    final behaviour = onFind;
    if (behaviour != null) return behaviour();
    return snapshot;
  }

  @override
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session) async {
    final behaviour = onLoadImages;
    if (behaviour != null) return behaviour();
    return const TutorialV3SessionImages(
      originalSelfieUrl: 'https://example.test/selfie.jpg',
      canonicalPreviewUrl: 'https://example.test/preview.png',
    );
  }

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakePlanner implements TutorialV3Planner {
  Future<void> Function()? onPlan;
  int calls = 0;

  @override
  Future<void> plan({required String sessionId}) async {
    calls++;
    final behaviour = onPlan;
    if (behaviour != null) return behaviour();
  }
}

class _FakeMapper implements TutorialV3GeometryMapper {
  final List<int> calls = [];

  /// Step indices that should fail with a non-domain exception.
  final Set<int> infrastructureFailures = <int>{};

  /// Step indices whose mapping never completes.
  final Set<int> hanging = <int>{};

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) {
    calls.add(stepIndex);
    if (infrastructureFailures.contains(stepIndex)) {
      return Future.error(const _InfrastructureException());
    }
    if (hanging.contains(stepIndex)) {
      return Completer<TutorialV3Geometry>().future;
    }
    return Future.value(testGeometry(category: expectedCategory));
  }
}

const _entry = TutorialV3EntryPoint(
  canonicalImageId: 'generated-1',
  sourceMode: TutorialV3SourceMode.standard,
);

/// Short enough that a test can wait out a real timeout, while production keeps
/// its own defaults. The controller takes these injected, so nothing here
/// changes what ships.
const _fastTimeouts = TutorialV3Timeouts(
  session: Duration(milliseconds: 30),
  ai: Duration(milliseconds: 30),
);

void main() {
  late _FakeRepository repository;
  late _FakePlanner planner;
  late _FakeMapper mapper;
  late TutorialV3GeometryCoordinator coordinator;
  late TutorialV3SessionController controller;

  TutorialV3SessionController build({
    TutorialV3SessionSnapshot? snapshot,
    TutorialV3Timeouts timeouts = const TutorialV3Timeouts(),
  }) {
    repository = _FakeRepository(snapshot ?? loadedSession());
    planner = _FakePlanner();
    mapper = _FakeMapper();
    coordinator = TutorialV3GeometryCoordinator(mapper);
    controller = TutorialV3SessionController(
      repository: repository,
      planner: planner,
      coordinator: coordinator,
      timeouts: timeouts,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  group(
    'an unexpected infrastructure error never leaves the screen loading',
    () {
      test('a missing RPC ends in a visible failure, not a spinner', () async {
        // The exact production case: the entry migration is not applied, so
        // PostgREST reports an unknown function.
        build();
        repository.onOpen = () =>
            Future.error(const _InfrastructureException());

        await controller.open(_entry);

        expect(controller.state.phase, TutorialV3Phase.failed);
        expect(controller.state.phase, isNot(TutorialV3Phase.opening));
        expect(controller.state.message, isNotNull);
      });

      test('the message shows nothing from the exception', () async {
        build();
        repository.onOpen = () =>
            Future.error(const _InfrastructureException());

        await controller.open(_entry);

        final message = controller.state.message!;
        for (final leak in [
          'PGRST202',
          'open_tutorial_v3_session',
          'p_generated_image_id',
          'schema cache',
          'public.',
        ]) {
          expect(
            message.contains(leak),
            isFalse,
            reason: '$leak must never reach the user',
          );
        }
        expect(message, 'Your tutorial could not be opened. Please try again.');
      });

      test('an unexpected open failure is retryable', () async {
        // The app cannot tell a transient outage from a permanent one here, and
        // refusing a retry for something it does not understand would strand the
        // user on a dead screen.
        build();
        repository.onOpen = () =>
            Future.error(const _InfrastructureException());

        await controller.open(_entry);

        expect(controller.state.retryable, isTrue);
      });

      test('a synchronous throw is caught too', () async {
        build();
        repository.onOpen = () => throw const _InfrastructureException();

        await controller.open(_entry);

        expect(controller.state.phase, TutorialV3Phase.failed);
      });

      test('reopen is protected in the same way', () async {
        build();
        repository.onFind = () =>
            Future.error(const _InfrastructureException());

        await controller.reopen('session-1');

        expect(controller.state.phase, TutorialV3Phase.failed);
        expect(controller.state.message!.contains('PGRST202'), isFalse);
      });

      test(
        'an unexpected planner error fails, rather than planning forever',
        () async {
          build(
            snapshot: TutorialV3LoadedSession(
              session: testSession(totalSteps: 0),
              steps: const [],
            ),
          );
          planner.onPlan = () => Future.error(const _InfrastructureException());

          await controller.open(_entry);

          expect(controller.state.phase, TutorialV3Phase.failed);
          expect(controller.state.phase, isNot(TutorialV3Phase.planning));
        },
      );

      test('a domain failure keeps its own wording and verdict', () async {
        // The boundary must not flatten failures the server already described.
        build();
        repository.onOpen = () => Future.error(
          const TutorialV3Failure(
            'The final look for this tutorial is no longer available.',
            kind: TutorialV3FailureKind.notFound,
            retryable: false,
          ),
        );

        await controller.open(_entry);

        expect(
          controller.state.message,
          'The final look for this tutorial is no longer available.',
        );
        expect(controller.state.retryable, isFalse);
      });
    },
  );

  group('operations are bounded', () {
    test('an open that never answers fails instead of hanging', () async {
      build(timeouts: _fastTimeouts);
      repository.onOpen = () => Completer<TutorialV3SessionSnapshot>().future;

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.failed);
      expect(
        controller.state.message,
        'This is taking longer than expected. Please try again.',
      );
      expect(controller.state.retryable, isTrue);
    });

    test('a hung reopen is bounded too', () async {
      build(timeouts: _fastTimeouts);
      repository.onFind = () => Completer<TutorialV3SessionSnapshot?>().future;

      await controller.reopen('session-1');

      expect(controller.state.phase, TutorialV3Phase.failed);
    });

    test('a hung plan is bounded', () async {
      build(
        snapshot: TutorialV3LoadedSession(
          session: testSession(totalSteps: 0),
          steps: const [],
        ),
        timeouts: _fastTimeouts,
      );
      planner.onPlan = () => Completer<void>().future;

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.failed);
    });

    test('a hung geometry mapping fails only the overlay', () async {
      build(timeouts: _fastTimeouts);
      mapper.hanging.add(1);

      await controller.open(_entry);

      // The tutorial itself stays readable — a missing overlay is not a broken
      // tutorial, which is V3-8's rule and still holds under a timeout.
      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(
        controller.state.geometryPhase,
        TutorialV3StepGeometryPhase.failed,
      );
      expect(controller.state.canRetryGeometry, isTrue);
    });

    test('a hung image load leaves the instructions readable', () async {
      build(timeouts: _fastTimeouts);
      repository.onLoadImages = () =>
          Completer<TutorialV3SessionImages>().future;

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.imagesPhase, TutorialV3ImagesPhase.failed);
    });

    test('production defaults are long enough for a slow generation', () {
      // The Edge Function allows two Gemini attempts at 60s each plus backoff,
      // so anything at or below that would abort work the server was about to
      // finish and spend the quota anyway.
      const timeouts = TutorialV3Timeouts();

      expect(timeouts.ai.inSeconds, greaterThan(121));
      expect(timeouts.session.inSeconds, greaterThanOrEqualTo(20));
      expect(timeouts.session, lessThan(timeouts.ai));
    });
  });

  group('a stale result cannot overwrite a newer one', () {
    test(
      'a late timeout does not fail a tutorial that has since opened',
      () async {
        build(timeouts: _fastTimeouts);
        final hung = Completer<TutorialV3SessionSnapshot>();
        repository.onOpen = () => hung.future;

        final first = controller.open(_entry);

        // A second open supersedes the first before its timeout can fire.
        repository.onOpen = null;
        await controller.open(_entry);
        expect(controller.state.phase, TutorialV3Phase.ready);

        await first;

        expect(
          controller.state.phase,
          TutorialV3Phase.ready,
          reason: 'the abandoned open must not fail the tutorial now on screen',
        );
      },
    );

    test('a late unexpected error does not overwrite a newer state', () async {
      build();
      final hung = Completer<TutorialV3SessionSnapshot>();
      repository.onOpen = () => hung.future;

      final first = controller.open(_entry);
      repository.onOpen = null;
      await controller.open(_entry);

      hung.completeError(const _InfrastructureException());
      await first;

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.message, isNull);
    });
  });

  group('recovery', () {
    test('retrying after a failed open reopens from the same entry', () async {
      // Before this fix retryOpen read a session id that a failed open never
      // produced, so "Try again" silently did nothing.
      build();
      repository.onOpen = () => Future.error(const _InfrastructureException());

      await controller.open(_entry);
      expect(controller.state.phase, TutorialV3Phase.failed);

      repository.onOpen = null;
      await controller.retryOpen();

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(repository.openCalls, 2);
    });

    test('retrying a failed overlay maps the step again', () async {
      build();
      mapper.infrastructureFailures.add(1);

      await controller.open(_entry);
      expect(
        controller.state.geometryPhase,
        TutorialV3StepGeometryPhase.failed,
      );

      mapper.infrastructureFailures.clear();
      await controller.retryGeometry();

      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
    });
  });

  group('geometry and prefetch', () {
    test(
      'an unexpected geometry error fails the overlay, not the tutorial',
      () async {
        build();
        mapper.infrastructureFailures.add(1);

        await controller.open(_entry);

        expect(controller.state.phase, TutorialV3Phase.ready);
        expect(
          controller.state.geometryPhase,
          TutorialV3StepGeometryPhase.failed,
        );
        expect(controller.state.message!.contains('PGRST202'), isFalse);
      },
    );

    test(
      'an unexpected prefetch error never reaches the current step',
      () async {
        // Step 1 is shown; step 2 is warmed in the background and explodes. The
        // user is reading step 1 and must not be told about it.
        build(
          snapshot: loadedSession(
            categories: const [
              TutorialV3Category.foundation,
              TutorialV3Category.blush,
            ],
          ),
        );
        mapper.infrastructureFailures.add(2);

        await controller.open(_entry);

        expect(controller.state.phase, TutorialV3Phase.ready);
        expect(controller.state.currentStepIndex, 1);
        expect(
          controller.state.geometryPhase,
          TutorialV3StepGeometryPhase.ready,
        );
        expect(controller.state.message, isNull);
      },
    );

    test('a hung prefetch does not hold up the step being read', () async {
      build(timeouts: _fastTimeouts);
      mapper.hanging.add(2);

      await controller.open(_entry);

      expect(controller.state.phase, TutorialV3Phase.ready);
      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
    });

    test('a failed prefetch leaves the step mappable on arrival', () async {
      build();
      mapper.infrastructureFailures.add(2);

      await controller.open(_entry);
      mapper.infrastructureFailures.clear();
      await controller.next();

      expect(controller.state.currentStepIndex, 2);
      expect(controller.state.geometryPhase, TutorialV3StepGeometryPhase.ready);
    });
  });
}
