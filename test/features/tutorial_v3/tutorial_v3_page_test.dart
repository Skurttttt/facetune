import 'dart:async';

import 'package:facetune/features/tutorial_v3/data/providers/tutorial_v3_providers.dart';
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
import 'package:facetune/features/tutorial_v3/presentation/pages/tutorial_v3_page.dart';
import 'package:facetune/features/tutorial_v3/presentation/widgets/tutorial_v3_step_navigation.dart';
import 'package:facetune/features/tutorial_v3/presentation/widgets/tutorial_v3_target_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

class _FakeRepository implements TutorialV3Repository {
  _FakeRepository(this.snapshot);

  TutorialV3SessionSnapshot? snapshot;
  TutorialV3Failure? imagesFailure;
  int imageLoads = 0;

  /// A non-domain exception for `openSession` to throw, standing in for the
  /// infrastructure faults the controller has to convert rather than leak.
  Object? openError;

  @override
  Future<TutorialV3SessionSnapshot> openSession(
    TutorialV3EntryPoint entry,
  ) async {
    final error = openError;
    if (error != null) throw error;
    return snapshot!;
  }

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) async =>
      snapshot;

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
      throw UnimplementedError('${invocation.memberName}');
}

class _FakePlanner implements TutorialV3Planner {
  Completer<void>? gate;

  @override
  Future<void> plan({required String sessionId}) async {
    final held = gate;
    if (held != null) await held.future;
  }
}

class _FakeMapper implements TutorialV3GeometryMapper {
  final Set<int> failing = <int>{};
  final Map<int, Completer<TutorialV3Geometry>> pending = {};

  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) {
    if (failing.contains(stepIndex)) {
      return Future.error(
        const TutorialV3Failure(
          'That guideline could not be prepared.',
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

/// An exception the app has no vocabulary for, carrying text the user must
/// never be shown. Stands in for a `PostgrestException`.
class _ServerException implements Exception {
  const _ServerException();

  @override
  String toString() =>
      'PGRST202: Could not find the function '
      'public.open_tutorial_v3_session in the schema cache';
}

void main() {
  late _FakeRepository repository;
  late _FakePlanner planner;
  late _FakeMapper mapper;
  late ProviderContainer container;

  /// Mounts the page over the fakes, opens the tutorial, and settles.
  ///
  /// The signed URLs point at a host the test binding cannot reach, so the
  /// photographs never decode here. That is deliberate: this file tests the
  /// screen's structure, text and navigation, and the overlay's own wiring is
  /// pinned in `tutorial_v3_guideline_view_test.dart` with real bytes.
  Future<void> pumpPage(
    WidgetTester tester, {
    TutorialV3SessionSnapshot? snapshot,
    bool open = true,
    Object? openError,
  }) async {
    repository = _FakeRepository(snapshot ?? loadedSession())
      ..openError = openError;
    planner = _FakePlanner();
    mapper = _FakeMapper();
    final overrides = <Override>[
      tutorialV3RepositoryProvider.overrideWithValue(repository),
      tutorialV3PlannerProvider.overrideWithValue(planner),
      tutorialV3GeometryMapperProvider.overrideWithValue(mapper),
    ];
    container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: TutorialV3Page()),
      ),
    );
    if (open) {
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
    }
    await tester.pump();
    await tester.pump();
  }

  group('opening states', () {
    testWidgets('it shows a loading state before anything is resolved', (
      tester,
    ) async {
      await pumpPage(tester, open: false);

      expect(find.text('Opening your tutorial…'), findsOneWidget);
    });

    testWidgets('it shows a planning state while the plan is generated', (
      tester,
    ) async {
      final unplanned = TutorialV3LoadedSession(
        session: testSession(totalSteps: 0),
        steps: const [],
      );
      await pumpPage(tester, snapshot: unplanned, open: false);
      planner.gate = Completer<void>();
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Building your personalized tutorial…'), findsOneWidget);

      planner.gate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a tutorial-level failure offers a retry', (tester) async {
      await pumpPage(
        tester,
        snapshot: const TutorialV3IncompatibleSession(
          sessionId: 'session-legacy',
          persistedPlanVersion: 2,
        ),
      );

      expect(find.text('This tutorial could not be opened'), findsOneWidget);
      // An incompatible session is not retryable — nothing would change.
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('an unexpected server error becomes a readable failure', (
      tester,
    ) async {
      // V3-10F2: this used to leave the spinner on screen forever, because
      // only TutorialV3Failure was caught anywhere.
      await pumpPage(tester, openError: const _ServerException());
      await tester.pumpAndSettle();

      expect(find.text('Opening your tutorial…'), findsNothing);
      expect(find.text('This tutorial could not be opened'), findsOneWidget);
      expect(
        find.text('Your tutorial could not be opened. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PGRST'), findsNothing);
      expect(find.textContaining('open_tutorial_v3_session'), findsNothing);
    });

    testWidgets('its retry actually reopens the tutorial', (tester) async {
      // The retry used to read a session id that a failed open never produced,
      // so the button was there and did nothing.
      await pumpPage(tester, openError: const _ServerException());
      await tester.pumpAndSettle();

      repository.openError = null;
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });
  });

  group('the step header is driven by the persisted plan', () {
    testWidgets('a three-step plan reads STEP 1 OF 3', (tester) async {
      await pumpPage(tester);

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('Foundation'), findsOneWidget);
    });

    testWidgets('a longer plan reports its own length', (tester) async {
      await pumpPage(
        tester,
        snapshot: loadedSession(
          categories: const [
            TutorialV3Category.foundation,
            TutorialV3Category.blush,
            TutorialV3Category.eyeliner,
            TutorialV3Category.lipstick,
          ],
        ),
      );

      expect(find.text('STEP 1 OF 5'), findsOneWidget);
    });

    testWidgets('the count is never hard-coded to a shorter plan', (
      tester,
    ) async {
      await pumpPage(
        tester,
        snapshot: loadedSession(categories: const [TutorialV3Category.blush]),
      );

      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.text('Blush'), findsOneWidget);
    });
  });

  group('instruction text comes from the Step Spec', () {
    testWidgets('every required block is labelled and populated', (
      tester,
    ) async {
      await pumpPage(tester);

      for (final label in const [
        'APPLY',
        'WHERE',
        'DIRECTION',
        'TECHNIQUE',
        'WHY THIS PLACEMENT',
        'HOW THIS BUILDS THE LOOK',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'missing $label');
      }
      // The fixture's persisted values, rendered verbatim.
      expect(find.text('Upper outer cheeks'), findsOneWidget);
      expect(find.text('Upward toward the temples'), findsOneWidget);
      expect(find.text('Soft circular blending'), findsOneWidget);
      expect(
        find.text('Lifted placement adds length to a round face.'),
        findsOneWidget,
      );
    });

    testWidgets('absent optional fields show no empty heading', (tester) async {
      await pumpPage(tester);

      expect(find.text('TIP'), findsNothing);
      expect(find.text('AVOID'), findsNothing);
      expect(find.text('COVERAGE'), findsNothing);
    });

    testWidgets('a standard step recommends a shade the user does not own', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(
        find.text('Recommended shade · Soft Rose · Satin'),
        findsOneWidget,
      );
      expect(find.text('From your kit'), findsNothing);
    });

    testWidgets('a Kit step says the product is one the user owns', (
      tester,
    ) async {
      await pumpPage(
        tester,
        snapshot: loadedSession(sourceMode: TutorialV3SourceMode.makeupKit),
      );

      expect(find.text('My blush · Soft Rose · Satin'), findsOneWidget);
      expect(find.text('From your kit'), findsOneWidget);
    });
  });

  group('target reference', () {
    testWidgets('the canonical preview is offered on a guideline step', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('TARGET LOOK'), findsOneWidget);
      expect(find.byType(TutorialV3TargetReference), findsOneWidget);
    });

    testWidgets('it is not repeated on the final step', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('TARGET LOOK'), findsNothing);
      expect(find.byType(TutorialV3TargetReference), findsNothing);
    });

    testWidgets('it expands to a full view', (tester) async {
      await pumpPage(tester);

      await tester.ensureVisible(find.byType(TutorialV3TargetReference));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TutorialV3TargetReference));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byTooltip('Close'), findsOneWidget);
    });
  });

  group('geometry states', () {
    testWidgets('a mapping in flight shows progress over the photo', (
      tester,
    ) async {
      mapper.pending[1] = Completer<TutorialV3Geometry>();
      await pumpPage(tester, open: false);
      mapper.pending[1] = Completer<TutorialV3Geometry>();
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);

      mapper.pending[1]!.complete(
        testGeometry(category: TutorialV3Category.foundation),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('a failed mapping keeps the step readable and offers retry', (
      tester,
    ) async {
      await pumpPage(tester, open: false);
      mapper.failing.add(1);
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pumpAndSettle();

      // The failure is reported without hiding the instruction.
      expect(
        find.text('That guideline could not be prepared.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('WHERE'), findsOneWidget);
      expect(find.text('Upper outer cheeks'), findsOneWidget);
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });

    testWidgets('retrying a failed overlay recovers it', (tester) async {
      await pumpPage(tester, open: false);
      mapper.failing.add(1);
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pumpAndSettle();

      mapper.failing.remove(1);
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('That guideline could not be prepared.'), findsNothing);
    });

    testWidgets('a step with cached geometry shows no retry or spinner', (
      tester,
    ) async {
      await pumpPage(tester, snapshot: loadedSession(readyUpTo: 2));

      expect(find.text('Try again'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('image states', () {
    testWidgets('a signing failure offers its own retry', (tester) async {
      await pumpPage(tester, open: false);
      repository.imagesFailure = const TutorialV3Failure(
        'The original photo for this tutorial is no longer available.',
        kind: TutorialV3FailureKind.notFound,
        retryable: false,
      );
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your photo could not be loaded'), findsOneWidget);
      // The tutorial itself is still open and readable.
      expect(find.text('STEP 1 OF 3'), findsOneWidget);
      expect(find.text('WHERE'), findsOneWidget);
    });

    testWidgets('retrying reloads the images', (tester) async {
      await pumpPage(tester, open: false);
      repository.imagesFailure = const TutorialV3Failure(
        'Unavailable.',
        kind: TutorialV3FailureKind.unavailable,
      );
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pumpAndSettle();
      final before = repository.imageLoads;

      repository.imagesFailure = null;
      await tester.ensureVisible(find.text('Try again'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(repository.imageLoads, before + 1);
      expect(find.text('Your photo could not be loaded'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('Previous is disabled on the first step', (tester) async {
      await pumpPage(tester);

      final navigation = tester.widget<TutorialV3StepNavigation>(
        find.byType(TutorialV3StepNavigation),
      );
      expect(navigation.canGoPrevious, isFalse);
      expect(navigation.canGoNext, isTrue);
    });

    testWidgets('Next advances through the plan', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 2 OF 3'), findsOneWidget);
      expect(find.text('Blush'), findsOneWidget);
    });

    testWidgets('Previous goes back', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Previous'));
      await tester.pumpAndSettle();

      expect(find.text('STEP 1 OF 3'), findsOneWidget);
    });

    testWidgets('Next is disabled on the last step', (tester) async {
      await pumpPage(tester);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      final navigation = tester.widget<TutorialV3StepNavigation>(
        find.byType(TutorialV3StepNavigation),
      );
      expect(navigation.canGoNext, isFalse);
      expect(navigation.canGoPrevious, isTrue);
    });
  });

  group('the final step', () {
    Future<void> goToFinal(WidgetTester tester) async {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    testWidgets('it shows the finished look, not a guideline', (tester) async {
      await pumpPage(tester);
      await goToFinal(tester);

      expect(find.text('STEP 3 OF 3'), findsOneWidget);
      expect(find.text('Final Look'), findsOneWidget);
      expect(find.text('YOUR FINISHED LOOK'), findsOneWidget);
      expect(find.text('The completed soft glam look.'), findsOneWidget);
    });

    testWidgets('it has no instruction blocks', (tester) async {
      await pumpPage(tester);
      await goToFinal(tester);

      expect(find.text('WHERE'), findsNothing);
      expect(find.text('DIRECTION'), findsNothing);
      expect(find.text('APPLY'), findsNothing);
    });
  });

  group('what the screen must never show', () {
    testWidgets('there is no Guidelines to Result slider', (tester) async {
      await pumpPage(tester);

      expect(find.byType(Slider), findsNothing);
      expect(find.textContaining('Result'), findsNothing);
      expect(find.textContaining('Before'), findsNothing);
      expect(find.textContaining('After'), findsNothing);
    });

    testWidgets('no step claims an intermediate makeup result', (tester) async {
      await pumpPage(tester);

      // The only two images are the untouched selfie and the canonical
      // preview; nothing labels a per-step generated appearance.
      expect(find.textContaining('applied'), findsNothing);
      expect(find.textContaining('preview of this step'), findsNothing);
    });
  });

  group('accessibility', () {
    testWidgets('the step position and category are headers', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        tester.getSemantics(find.text('STEP 1 OF 3')),
        matchesSemantics(label: 'STEP 1 OF 3', isHeader: true),
      );
      handle.dispose();
    });

    testWidgets('the target reference is an actionable, labelled control', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester);

      expect(
        find.bySemanticsLabel('Target look. Tap to view the full preview.'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a geometry failure is announced', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPage(tester, open: false);
      mapper.failing.add(1);
      unawaited(
        container
            .read(tutorialV3SessionControllerProvider.notifier)
            .open(_entry),
      );
      await tester.pumpAndSettle();

      final node = tester.getSemantics(
        find.text('That guideline could not be prepared.'),
      );
      expect(node, isNotNull);
      handle.dispose();
    });
  });
}
