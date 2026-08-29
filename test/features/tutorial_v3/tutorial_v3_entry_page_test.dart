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
import 'package:facetune/features/tutorial_v3/presentation/pages/tutorial_v3_entry_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_v3_fixtures.dart';

class _FakeRepository implements TutorialV3Repository {
  _FakeRepository(this.snapshot);

  TutorialV3SessionSnapshot? snapshot;
  final List<TutorialV3EntryPoint> opened = [];
  TutorialV3Failure? openFailure;

  @override
  Future<TutorialV3SessionSnapshot> openSession(
    TutorialV3EntryPoint entry,
  ) async {
    opened.add(entry);
    final failure = openFailure;
    if (failure != null) throw failure;
    return snapshot!;
  }

  @override
  Future<TutorialV3SessionSnapshot?> findSessionById(String sessionId) async =>
      snapshot;

  @override
  Future<TutorialV3SessionImages> loadImages(TutorialV3Session session) async =>
      const TutorialV3SessionImages(
        originalSelfieUrl: 'https://example.test/selfie.jpg',
        canonicalPreviewUrl: 'https://example.test/preview.png',
      );

  @override
  Object noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _FakePlanner implements TutorialV3Planner {
  @override
  Future<void> plan({required String sessionId}) async {}
}

class _FakeMapper implements TutorialV3GeometryMapper {
  @override
  Future<TutorialV3Geometry> map({
    required String sessionId,
    required int stepIndex,
    required TutorialV3Category expectedCategory,
  }) async => testGeometry(category: expectedCategory);
}

void main() {
  late _FakeRepository repository;
  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    String canonicalImageId = 'generated-1',
    TutorialV3SourceMode sourceMode = TutorialV3SourceMode.standard,
  }) async {
    repository = _FakeRepository(loadedSession());
    container = ProviderContainer(
      overrides: [
        tutorialV3RepositoryProvider.overrideWithValue(repository),
        tutorialV3PlannerProvider.overrideWithValue(_FakePlanner()),
        tutorialV3GeometryMapperProvider.overrideWithValue(_FakeMapper()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TutorialV3EntryPage(
            canonicalImageId: canonicalImageId,
            sourceMode: sourceMode,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('it opens the tutorial for the preview it was routed to', (
    tester,
  ) async {
    await pump(tester);

    expect(repository.opened, hasLength(1));
    expect(repository.opened.single.canonicalImageId, 'generated-1');
    expect(repository.opened.single.sourceMode, TutorialV3SourceMode.standard);
  });

  testWidgets('the kit flag selects the Kit chain', (tester) async {
    await pump(
      tester,
      canonicalImageId: 'kit-generated-1',
      sourceMode: TutorialV3SourceMode.makeupKit,
    );

    expect(repository.opened.single.isKit, isTrue);
  });

  testWidgets('it opens once, not on every rebuild', (tester) async {
    await pump(tester);
    await tester.pump();
    await tester.pump();

    expect(repository.opened, hasLength(1));
  });

  testWidgets('the tutorial screen is rendered once opened', (tester) async {
    await pump(tester);

    expect(find.text('STEP 1 OF 3'), findsOneWidget);
    expect(find.text('Foundation'), findsOneWidget);
  });

  testWidgets('a failure to open is reported inside the screen', (
    tester,
  ) async {
    repository = _FakeRepository(loadedSession());
    container = ProviderContainer(
      overrides: [
        tutorialV3RepositoryProvider.overrideWithValue(repository),
        tutorialV3PlannerProvider.overrideWithValue(_FakePlanner()),
        tutorialV3GeometryMapperProvider.overrideWithValue(_FakeMapper()),
      ],
    );
    addTearDown(container.dispose);
    repository.openFailure = const TutorialV3Failure(
      'The final look for this tutorial is no longer available.',
      kind: TutorialV3FailureKind.notFound,
      retryable: false,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TutorialV3EntryPage(
            canonicalImageId: 'generated-missing',
            sourceMode: TutorialV3SourceMode.standard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Rendered as a screen state, not thrown during the build that created it.
    expect(find.text('This tutorial could not be opened'), findsOneWidget);
    expect(
      find.text('The final look for this tutorial is no longer available.'),
      findsOneWidget,
    );
  });

  testWidgets('routing to a different preview reopens', (tester) async {
    await pump(tester);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: TutorialV3EntryPage(
            canonicalImageId: 'generated-2',
            sourceMode: TutorialV3SourceMode.standard,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.opened, hasLength(2));
    expect(repository.opened.last.canonicalImageId, 'generated-2');
  });

  testWidgets('nothing but the two identifiers reaches the repository', (
    tester,
  ) async {
    // There is no other field on the entry point to carry a path, an analysis
    // or a style, which is the whole point of the type.
    await pump(tester);
    final entry = repository.opened.single;

    expect(entry.canonicalImageId, isNotEmpty);
    expect(entry.sourceMode, isA<TutorialV3SourceMode>());
    expect(entry.isKit, isFalse);
  });
}
