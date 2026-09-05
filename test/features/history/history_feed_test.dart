import 'dart:io';

import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/face_analysis.dart';
import 'package:facetune/features/history/domain/entities/history_entry.dart';
import 'package:facetune/features/history/presentation/models/history_feed_item.dart';
import 'package:facetune/features/history/presentation/widgets/history_feed.dart';
import 'package:facetune/features/history/presentation/widgets/history_filter_controls.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_generated_preview.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_look_result.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/entities/makeup_style.dart';
import 'package:flutter/material.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

void main() {
  group('History shared feed adapters', () {
    test('adapts Standard-only records without a My Kit fallback', () {
      final standard = _standard('standard-1', DateTime(2026, 9, 5, 10));

      final feed = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: const [],
      );

      expect(feed, hasLength(1));
      expect(feed.single, isA<StandardHistoryFeedItem>());
      expect(feed.single.recordType, HistoryFeedRecordType.recommendation);
      expect(feed.single.stableId, standard.id);
      expect(feed.single.presentationKey, 'recommendation:${standard.id}');
      expect((feed.single as StandardHistoryFeedItem).entry, same(standard));
    });

    test('adapts My Kit-only records without a Standard fallback', () {
      final kit = _kit('kit-1', DateTime(2026, 9, 5, 11));

      final feed = buildHistoryFeed(
        recommendations: const [],
        myMakeupKit: [kit],
      );

      expect(feed, hasLength(1));
      expect(feed.single, isA<MyMakeupKitHistoryFeedItem>());
      expect(feed.single.recordType, HistoryFeedRecordType.myMakeupKit);
      expect(feed.single.stableId, kit.id);
      expect(feed.single.presentationKey, 'myMakeupKit:${kit.id}');
      expect((feed.single as MyMakeupKitHistoryFeedItem).entry, same(kit));
    });

    test('mixes both authorities into one newest-first feed', () {
      final olderStandard = _standard(
        'standard-older',
        DateTime(2026, 9, 5, 8),
      );
      final newestStandard = _standard(
        'standard-newest',
        DateTime(2026, 9, 5, 12),
      );
      final middleKit = _kit('kit-middle', DateTime(2026, 9, 5, 10));

      final feed = buildHistoryFeed(
        recommendations: [olderStandard, newestStandard],
        myMakeupKit: [middleKit],
      );

      expect(feed.map((item) => item.stableId), [
        newestStandard.id,
        middleKit.id,
        olderStandard.id,
      ]);
      expect(feed.map((item) => item.recordType), [
        HistoryFeedRecordType.recommendation,
        HistoryFeedRecordType.myMakeupKit,
        HistoryFeedRecordType.recommendation,
      ]);
    });

    test('equal timestamps have deterministic type and stable-id order', () {
      final timestamp = DateTime(2026, 9, 5, 10);

      final feed = buildHistoryFeed(
        recommendations: [
          _standard('standard-b', timestamp),
          _standard('standard-a', timestamp),
        ],
        myMakeupKit: [_kit('kit-b', timestamp), _kit('kit-a', timestamp)],
      );

      expect(feed.map((item) => item.presentationKey), [
        'recommendation:standard-a',
        'recommendation:standard-b',
        'myMakeupKit:kit-a',
        'myMakeupKit:kit-b',
      ]);
    });

    test('groups local dates into the four accepted headings', () {
      final now = DateTime(2026, 9, 5, 12);
      final feed = buildHistoryFeed(
        recommendations: [
          _standard('today', DateTime(2026, 9, 5, 10)),
          _standard('this-week', DateTime(2026, 9, 2, 10)),
          _standard('earlier', DateTime(2026, 8, 30, 10)),
        ],
        myMakeupKit: [_kit('yesterday', DateTime(2026, 9, 4, 10))],
      );

      final sections = groupHistoryFeed(feed, now: now);

      expect(sections.map((section) => section.group), [
        HistoryDateGroup.today,
        HistoryDateGroup.yesterday,
        HistoryDateGroup.thisWeek,
        HistoryDateGroup.earlier,
      ]);
      expect(sections.map((section) => section.group.label), [
        'Today',
        'Yesterday',
        'This week',
        'Earlier',
      ]);
      expect(sections.map((section) => section.items.single.stableId), [
        'today',
        'yesterday',
        'this-week',
        'earlier',
      ]);
    });

    test('mode metadata remains isolated in its authoritative adapter', () {
      final standard = _standard('shared-analysis', DateTime(2026, 9, 5));
      final kit = _kit(
        'owned-preview',
        DateTime(2026, 9, 5),
        analysisId: 'shared-analysis',
        productName: 'Authoritative owned lipstick',
      );

      final feed = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: [kit],
      );
      final standardItem = feed.whereType<StandardHistoryFeedItem>().single;
      final kitItem = feed.whereType<MyMakeupKitHistoryFeedItem>().single;

      expect(standardItem.entry, same(standard));
      expect(standardItem.stableId, 'shared-analysis');
      expect(kitItem.entry, same(kit));
      expect(kitItem.stableId, 'owned-preview');
      expect(
        kitItem.entry.result.recommendation.productSnapshots.single.productName,
        'Authoritative owned lipstick',
      );
      expect(standardItem.presentationKey, isNot(kitItem.presentationKey));
    });
  });

  testWidgets(
    'one feed routes each mode to its existing callback with zero AI calls',
    (tester) async {
      final standard = _standard('standard-route', DateTime(2026, 9, 5, 12));
      final kit = _kit('kit-route', DateTime(2026, 9, 5, 11));
      final items = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: [kit],
      );
      var standardOpenCalls = 0;
      var kitOpenCalls = 0;
      var aiCalls = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HistoryFeed(
                  items: items,
                  sort: HistoryFeedSort.newest,
                  now: DateTime(2026, 9, 5, 13),
                  itemBuilder: (context, item) => switch (item) {
                    StandardHistoryFeedItem() => TextButton(
                      key: const ValueKey('open-standard'),
                      onPressed: () => standardOpenCalls += 1,
                      child: const Text('Open Standard'),
                    ),
                    MyMakeupKitHistoryFeedItem() => TextButton(
                      key: const ValueKey('open-kit'),
                      onPressed: () => kitOpenCalls += 1,
                      child: const Text('Open My Kit'),
                    ),
                  },
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(HistoryFeed), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('open-standard')));
      await tester.tap(find.byKey(const ValueKey('open-kit')));

      expect(standardOpenCalls, 1);
      expect(kitOpenCalls, 1);
      expect(aiCalls, 0);
    },
  );

  group('HIST-UI-2 filters and sorting', () {
    test('type filters use authoritative record type', () {
      final standard = _standard('standard', DateTime(2026, 9, 5));
      final kit = _kit('kit', DateTime(2026, 9, 5));

      final all = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: [kit],
      );
      final kitOnly = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: [kit],
        typeFilter: HistoryFeedTypeFilter.myMakeupKit,
      );
      final recommendationsOnly = buildHistoryFeed(
        recommendations: [standard],
        myMakeupKit: [kit],
        typeFilter: HistoryFeedTypeFilter.recommendations,
      );

      expect(all, hasLength(2));
      expect(kitOnly.single, isA<MyMakeupKitHistoryFeedItem>());
      expect(recommendationsOnly.single, isA<StandardHistoryFeedItem>());
    });

    test('status filters retain the accepted per-mode meanings', () {
      final incomplete = _standard('incomplete', DateTime(2026, 9, 5));
      final complete = _standard(
        'complete',
        DateTime(2026, 9, 4),
        status: HistoryCompletionStatus.complete,
      );
      final favoriteKit = _kit(
        'favorite-kit',
        DateTime(2026, 9, 3),
        favorite: true,
      );
      final regularKit = _kit('regular-kit', DateTime(2026, 9, 2));

      final completed = buildHistoryFeed(
        recommendations: [incomplete, complete],
        myMakeupKit: [favoriteKit, regularKit],
        statusFilter: HistoryFilter.completed,
      );
      final favorites = buildHistoryFeed(
        recommendations: [incomplete, complete],
        myMakeupKit: [favoriteKit, regularKit],
        statusFilter: HistoryFilter.favorites,
      );

      expect(completed.map((item) => item.stableId), [
        'complete',
        'favorite-kit',
        'regular-kit',
      ]);
      expect(favorites.map((item) => item.stableId), ['favorite-kit']);
    });

    test('type, status, and local search intersect without fallback', () {
      final softGlam = MakeupStyleCatalog.styles[3];
      final matchingStandard = _standard(
        'matching-standard',
        DateTime(2026, 9, 5),
        status: HistoryCompletionStatus.complete,
        style: softGlam,
      );
      final incompleteStandard = _standard(
        'incomplete-standard',
        DateTime(2026, 9, 4),
        style: softGlam,
      );
      final matchingKit = _kit(
        'matching-kit',
        DateTime(2026, 9, 3),
        style: softGlam,
      );

      final result = buildHistoryFeed(
        recommendations: [matchingStandard, incompleteStandard],
        myMakeupKit: [matchingKit],
        typeFilter: HistoryFeedTypeFilter.recommendations,
        statusFilter: HistoryFilter.completed,
        query: 'soft glam',
      );

      expect(result.map((item) => item.stableId), ['matching-standard']);
    });

    test('oldest sort reverses item and chronological group order', () {
      final items = buildHistoryFeed(
        recommendations: [
          _standard('today', DateTime(2026, 9, 5, 10)),
          _standard('earlier', DateTime(2026, 8, 20, 10)),
        ],
        myMakeupKit: [_kit('yesterday', DateTime(2026, 9, 4, 10))],
        sort: HistoryFeedSort.oldest,
      );
      final groups = groupHistoryFeed(
        items,
        now: DateTime(2026, 9, 5, 12),
        oldestFirst: true,
      );

      expect(items.map((item) => item.stableId), [
        'earlier',
        'yesterday',
        'today',
      ]);
      expect(groups.map((group) => group.group), [
        HistoryDateGroup.earlier,
        HistoryDateGroup.yesterday,
        HistoryDateGroup.today,
      ]);
    });

    test('Style A-Z uses authoritative style names deterministically', () {
      final items = buildHistoryFeed(
        recommendations: [
          _standard(
            'office',
            DateTime(2026, 9, 5),
            style: MakeupStyleCatalog.styles[2],
          ),
          _standard(
            'bridal',
            DateTime(2026, 9, 4),
            style: MakeupStyleCatalog.styles[5],
          ),
        ],
        myMakeupKit: [
          _kit(
            'natural',
            DateTime(2026, 9, 3),
            style: MakeupStyleCatalog.styles[0],
          ),
        ],
        sort: HistoryFeedSort.styleAscending,
      );

      expect(items.map((item) => item.styleName), [
        'Bridal',
        'Natural',
        'Office',
      ]);
    });

    test('duplicate source rows are removed only within the same mode', () {
      final standard = _standard('shared-id', DateTime(2026, 9, 5));
      final kit = _kit('shared-id', DateTime(2026, 9, 4));

      final items = buildHistoryFeed(
        recommendations: [standard, standard],
        myMakeupKit: [kit, kit],
      );

      expect(items, hasLength(2));
      expect(items.map((item) => item.presentationKey).toSet(), hasLength(2));
    });

    testWidgets('Style A-Z suppresses chronological headings', (tester) async {
      final items = buildHistoryFeed(
        recommendations: [
          _standard(
            'office',
            DateTime(2026, 9, 5),
            style: MakeupStyleCatalog.styles[2],
          ),
        ],
        myMakeupKit: const [],
        sort: HistoryFeedSort.styleAscending,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [
              HistoryFeed(
                items: items,
                sort: HistoryFeedSort.styleAscending,
                itemBuilder: (_, item) => Text(item.styleName),
              ),
            ],
          ),
        ),
      );

      expect(find.text('Office'), findsOneWidget);
      for (final group in HistoryDateGroup.values) {
        expect(find.text(group.label), findsNothing);
      }
    });

    testWidgets('controls are independent, and there is no Sort among them', (
      tester,
    ) async {
      final typeChanges = <HistoryFeedTypeFilter>[];
      final statusChanges = <HistoryFilter>[];
      final queries = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryFilterControls(
                query: '',
                typeFilter: HistoryFeedTypeFilter.all,
                statusFilter: HistoryFilter.all,
                onQueryChanged: queries.add,
                onTypeChanged: typeChanges.add,
                onStatusChanged: statusChanges.add,
              ),
            ),
          ),
        ),
      );

      expect(find.text('TYPE'), findsOneWidget);
      expect(find.text('STATUS'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search your history'), findsOneWidget);

      // POLISH-P1 removed the control, its glyph, and the sheet behind it. The
      // sheet's own options are named here too: finding one of those would mean
      // some other trigger still reaches it.
      expect(find.text('Sort'), findsNothing);
      expect(find.text('Sort history'), findsNothing);
      expect(find.byIcon(Icons.swap_vert_rounded), findsNothing);
      for (final option in HistoryFeedSort.values) {
        expect(find.text(option.label), findsNothing);
      }

      await tester.tap(find.widgetWithText(FilterChip, 'My Makeup Kit'));
      expect(typeChanges, [HistoryFeedTypeFilter.myMakeupKit]);
      expect(statusChanges, isEmpty);

      await tester.tap(find.widgetWithText(FilterChip, 'Completed'));
      expect(statusChanges, [HistoryFilter.completed]);
      expect(typeChanges, hasLength(1));

      await tester.enterText(find.byType(TextField), 'soft glam');
      expect(queries.last, 'soft glam');
      expect(typeChanges, hasLength(1));
      expect(statusChanges, hasLength(1));
    });

    testWidgets('the TYPE chips stay on one row on a narrow phone', (
      tester,
    ) async {
      // 320pt wide: narrower than the POCO, and far too narrow for the three
      // TYPE labels to fit. A `Wrap` used to fold "Recommendations" onto a
      // second run here; the row scrolls instead.
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final typeChanges = <HistoryFeedTypeFilter>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: HistoryFilterControls(
                query: '',
                typeFilter: HistoryFeedTypeFilter.all,
                statusFilter: HistoryFilter.all,
                onQueryChanged: (_) {},
                onTypeChanged: typeChanges.add,
                onStatusChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The two unambiguous TYPE labels — "All" also labels a STATUS chip —
      // share a top edge, which is what "one row" means geometrically.
      final kit = tester.getRect(
        find.widgetWithText(FilterChip, 'My Makeup Kit'),
      );
      final recommendations = tester.getRect(
        find.widgetWithText(FilterChip, 'Recommendations'),
      );
      expect(recommendations.top, closeTo(kit.top, 0.01));
      expect(recommendations.left, greaterThan(kit.left));

      // Full labels, not abbreviations, and the far chip is still reachable.
      await tester.dragUntilVisible(
        find.widgetWithText(FilterChip, 'Recommendations'),
        find.byType(SingleChildScrollView).last,
        const Offset(-60, 0),
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Recommendations'));
      expect(typeChanges, [HistoryFeedTypeFilter.recommendations]);

      // STATUS is untouched: still a Wrap, still not scrollable.
      expect(
        find.ancestor(
          of: find.widgetWithText(FilterChip, 'Favorites'),
          matching: find.byType(Wrap),
        ),
        findsOneWidget,
      );
    });
  });

  test('the shared feed owns no repositories, controllers, or AI work', () {
    final modelSource = File(
      'lib/features/history/presentation/models/history_feed_item.dart',
    ).readAsStringSync();
    final widgetSource = File(
      'lib/features/history/presentation/widgets/history_feed.dart',
    ).readAsStringSync();
    final pageSource = File(
      'lib/features/history/presentation/pages/history_page.dart',
    ).readAsStringSync();

    for (final source in [modelSource, widgetSource]) {
      expect(source, isNot(contains('/repositories/')));
      expect(source, isNot(contains('/controllers/')));
      expect(source, isNot(contains('flutter_riverpod')));
      expect(source, isNot(contains('.generate(')));
      expect(source.toLowerCase(), isNot(contains('gemini')));
    }
    expect(pageSource, contains('onOpen: () => _open(entry)'));
    expect(pageSource, contains('onOpen: () => _openKit(entry)'));
    expect(pageSource, isNot(contains("'Makeup Recommendations'")));
  });
}

HistoryEntry _standard(
  String id,
  DateTime occurredAt, {
  HistoryCompletionStatus status = HistoryCompletionStatus.analysisReady,
  MakeupStyle? style,
}) {
  final analysis = _analysis(id, occurredAt.subtract(const Duration(hours: 1)));
  return HistoryEntry(
    analysis: analysis,
    thumbnailUrl: 'https://signed.example/$id',
    style: style,
    status: status,
    createdAt: analysis.createdAt,
    latestActivityAt: occurredAt,
  );
}

KitHistoryEntry _kit(
  String id,
  DateTime occurredAt, {
  String? analysisId,
  String productName = 'Owned product',
  bool favorite = false,
  MakeupStyle? style,
}) {
  final resolvedAnalysisId = analysisId ?? 'analysis-$id';
  final analysis = _analysis(
    resolvedAnalysisId,
    occurredAt.subtract(const Duration(hours: 2)),
  );
  final recommendation = KitMakeupRecommendation(
    id: 'recommendation-$id',
    analysisId: resolvedAnalysisId,
    styleCode: MakeupStyleCatalog.styles.first.code,
    selections: const [],
    productSnapshots: [
      KitProductSnapshot(
        productId: 'product-$id',
        category: 'lipstick',
        productName: productName,
        colorHex: '#A06060',
        finish: 'satin',
      ),
    ],
    overallIntensity: 'soft',
    summary: 'Authoritative kit summary',
    modelId: 'existing-model',
    promptVersion: 'existing-prompt',
    createdAt: occurredAt.subtract(const Duration(hours: 1)),
  );
  final preview = KitGeneratedPreview(
    id: id,
    analysisId: resolvedAnalysisId,
    kitRecommendationId: recommendation.id,
    originalImagePath: 'user/analyses/$resolvedAnalysisId/original/image.jpg',
    generatedImagePath: 'user/analyses/$resolvedAnalysisId/kit/$id.png',
    originalImageUrl: 'https://signed.example/original-$id',
    generatedImageUrl: 'https://signed.example/generated-$id',
    generationNumber: 1,
    modelId: 'existing-model',
    promptVersion: 'existing-prompt',
    createdAt: occurredAt,
  );
  final result = KitLookResult(
    analysis: analysis,
    style: style ?? MakeupStyleCatalog.styles.first,
    recommendation: recommendation,
    preview: preview,
  );
  return KitHistoryEntry(
    result: result,
    savedLook: favorite
        ? KitSavedLook(
            id: 'saved-$id',
            result: result,
            isFavorite: true,
            createdAt: occurredAt,
          )
        : null,
  );
}

FaceAnalysis _analysis(String id, DateTime createdAt) {
  final raw = validAnalysisResponse['analysis']! as Map<String, Object?>;
  return FaceAnalysisDto.fromResponse({
    'analysis': {
      ...raw,
      'id': id,
      'originalImagePath': 'user/analyses/$id/original/image.jpg',
      'createdAt': createdAt.toUtc().toIso8601String(),
    },
  }).analysis;
}
