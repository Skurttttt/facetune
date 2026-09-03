import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/realized_look_filter.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_category_mapping.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_step_planner.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// V4-QA-6B: the Makeup Breakdown and the Step-by-Step tutorial must describe
/// the same canonical final preview identically.
///
/// The invariant is **not** `8 == 8`. Two screens can both show eight
/// categories and still disagree about which eight, which is the subtle version
/// of the defect that would survive a count check. So every consistency test
/// here compares category *identities* and their *order*, and the counts are
/// only ever asserted as a consequence.
///
/// The defect being fixed: `MakeupBreakdown` rendered `recommendation.items`
/// directly — the intent, formed before the preview existed — while the
/// tutorial filtered through the accepted manifest. A Natural look could list
/// Contour in the breakdown and omit it from the tutorial.

final _now = DateTime.utc(2026, 9, 1);

MakeupRecommendationItem _item(String name, String hex) =>
    MakeupRecommendationItem(
      name: name,
      hex: hex,
      placement: 'Across the area.',
      technique: 'Blend outward.',
      finish: 'satin',
      intensity: 'soft',
      reasoning: 'Suits the undertone.',
    );

/// A recommendation proposing all nine categories, including both lip keys.
///
/// Deliberately maximal: the recommendation is the *intent*, and the whole
/// point is that a generous intent must not widen the realized look.
MakeupRecommendation _recommendation({String styleCode = 'natural'}) =>
    MakeupRecommendation(
      id: 'rec-1',
      analysisId: 'analysis-1',
      styleCode: styleCode,
      overallIntensity: 'soft',
      items: <String, MakeupRecommendationItem>{
        'foundation': _item('Warm beige', '#E3C4A8'),
        'concealer': _item('Soft ivory', '#EBD3BE'),
        'contour': _item('Soft bronze contour', '#A9784F'),
        'highlight': _item('Champagne', '#F2E2C4'),
        'blush': _item('Warm peach', '#E8A08C'),
        'eyeshadow': _item('Taupe', '#B79A86'),
        'eyebrow': _item('Soft brown', '#6B4A34'),
        'eyeliner': _item('Espresso', '#3B2A22'),
        'lipstick': _item('Rosewood', '#B86F72'),
        'lipGloss': _item('Clear shine', '#D8A0A2'),
      },
      modelId: 'm',
      promptVersion: 'v1',
      createdAt: _now,
    );

KitMakeupRecommendation _kitRecommendation() => KitMakeupRecommendation(
  id: 'kit-rec-1',
  analysisId: 'analysis-1',
  styleCode: 'natural',
  selections: const <KitMakeupSelection>[
    KitMakeupSelection(
      productId: 'p1',
      category: 'foundation',
      colorHex: '#E3C4A8',
      finish: 'natural',
      placement: 'Centre of the face.',
      technique: 'Blend outward.',
      intensity: 'soft',
    ),
    KitMakeupSelection(
      productId: 'p2',
      category: 'contour_bronzer',
      colorHex: '#A9784F',
      finish: 'matte',
      placement: 'Under the cheekbone.',
      technique: 'Buff along the band.',
      intensity: 'soft',
    ),
    KitMakeupSelection(
      productId: 'p3',
      category: 'lipstick',
      colorHex: '#B86F72',
      finish: 'cream',
      placement: 'Across the lips.',
      technique: 'Fill inward.',
      intensity: 'soft',
    ),
  ],
  productSnapshots: const <KitProductSnapshot>[
    KitProductSnapshot(
      productId: 'p1',
      category: 'foundation',
      colorHex: '#E3C4A8',
      finish: 'natural',
      productName: 'Studio Base',
    ),
    KitProductSnapshot(
      productId: 'p2',
      category: 'contour_bronzer',
      colorHex: '#A9784F',
      finish: 'matte',
      productName: 'Sculpt Powder',
    ),
    KitProductSnapshot(
      productId: 'p3',
      category: 'lipstick',
      colorHex: '#B86F72',
      finish: 'cream',
      productName: 'Everyday Nude',
    ),
  ],
  overallIntensity: 'soft',
  summary: 'Owned products.',
  modelId: 'm',
  promptVersion: 'v1',
  createdAt: _now,
);

TutorialManifest _manifest(
  Map<TutorialCategory, TutorialCategoryPresence> verdicts, {
  RecommendationSourceMode sourceMode = RecommendationSourceMode.standard,
  Set<TutorialCategory> backed = const <TutorialCategory>{},
}) => TutorialManifest(
  canonicalPreviewId: 'preview-1',
  sourceMode: sourceMode,
  status: TutorialManifestStatus.accepted,
  items: <TutorialManifestItem>[
    for (final category in TutorialCategory.values)
      TutorialManifestItem(
        category: category,
        presence: verdicts[category] ?? TutorialCategoryPresence.absent,
        productBacked: backed.contains(category),
      ),
  ],
  modelId: 'm',
  promptVersion: 'tutorial_manifest_v4_1',
  schemaVersion: 'manifest_schema_v1',
  createdAt: _now,
);

const _present = TutorialCategoryPresence.present;
const _absent = TutorialCategoryPresence.absent;
const _uncertain = TutorialCategoryPresence.uncertain;

/// The reported Natural device case: everything visible except Contour.
const _natural = <TutorialCategory, TutorialCategoryPresence>{
  TutorialCategory.foundation: _present,
  TutorialCategory.concealer: _present,
  TutorialCategory.contourBronzer: _absent,
  TutorialCategory.blush: _present,
  TutorialCategory.highlighter: _present,
  TutorialCategory.eyebrows: _present,
  TutorialCategory.eyeshadow: _present,
  TutorialCategory.eyeliner: _present,
  TutorialCategory.lips: _present,
};

const _allNine = <TutorialCategory, TutorialCategoryPresence>{
  TutorialCategory.foundation: _present,
  TutorialCategory.concealer: _present,
  TutorialCategory.contourBronzer: _present,
  TutorialCategory.blush: _present,
  TutorialCategory.highlighter: _present,
  TutorialCategory.eyebrows: _present,
  TutorialCategory.eyeshadow: _present,
  TutorialCategory.eyeliner: _present,
  TutorialCategory.lips: _present,
};

ValidatedLookPlan _plan(MakeupRecommendation recommendation) =>
    LookPlanConvergence.fromStandard(recommendation);

/// The categories the tutorial would build steps for.
List<TutorialCategory> _tutorialCategories(
  TutorialManifest manifest,
  ValidatedLookPlan plan,
) => TutorialStepPlanner.plan(
  manifest: manifest,
  lookPlan: plan,
).map((step) => step.category).toList();

/// The categories the Makeup Breakdown would render.
///
/// Read from the *grouped* structure the widget is actually given, so these
/// assertions measure sections rather than cards. That distinction is the whole
/// subject of the grouping correction: two lip plan keys are two cards inside
/// one Lips section, and it is the section that must line up with a step.
List<TutorialCategory> _breakdownCategories(
  TutorialManifest manifest,
  MakeupRecommendation recommendation,
) => RealizedLookFilter.groupCategories(
  RealizedLookFilter.standardGroups(
    recommendation: recommendation,
    included: manifest.includedCategories,
  ),
);

/// The Everyday look from device QA: no concealer, no brows, no liner.
const _everyday = <TutorialCategory, TutorialCategoryPresence>{
  TutorialCategory.foundation: _present,
  TutorialCategory.contourBronzer: _present,
  TutorialCategory.blush: _present,
  TutorialCategory.highlighter: _present,
  TutorialCategory.eyeshadow: _present,
  TutorialCategory.lips: _present,
  TutorialCategory.concealer: _absent,
  TutorialCategory.eyebrows: _absent,
  TutorialCategory.eyeliner: _absent,
};

void main() {
  group('the reported Natural defect', () {
    test('Contour is absent from both screens, not just the tutorial', () {
      final recommendation = _recommendation();
      final manifest = _manifest(_natural);
      final breakdown = _breakdownCategories(manifest, recommendation);
      final tutorial = _tutorialCategories(manifest, _plan(recommendation));

      expect(
        recommendation.items.containsKey('contour'),
        isTrue,
        reason: 'the recommendation still proposes contour; that is the point',
      );
      expect(breakdown.contains(TutorialCategory.contourBronzer), isFalse);
      expect(tutorial.contains(TutorialCategory.contourBronzer), isFalse);
      expect(breakdown, tutorial);
      expect(breakdown, hasLength(8));
    });

    test('the contour card itself is gone, not merely uncounted', () {
      final entries = RealizedLookFilter.standardEntries(
        recommendation: _recommendation(),
        included: _manifest(_natural).includedCategories,
      );
      expect(
        entries.map((entry) => entry.planKey).contains('contour'),
        isFalse,
      );
    });
  });

  group('same category identities, not merely same counts', () {
    test('breakdown and tutorial agree exactly, in the same order', () {
      for (final verdicts in <Map<TutorialCategory, TutorialCategoryPresence>>[
        _natural,
        _allNine,
        const {TutorialCategory.lips: _present},
        const {
          TutorialCategory.blush: _present,
          TutorialCategory.eyeliner: _present,
        },
        const <TutorialCategory, TutorialCategoryPresence>{},
      ]) {
        final recommendation = _recommendation();
        final manifest = _manifest(verdicts);
        final breakdown = _breakdownCategories(manifest, recommendation);
        final tutorial = _tutorialCategories(manifest, _plan(recommendation));

        expect(breakdown, tutorial, reason: 'identities and order must match');
        expect(breakdown.length, tutorial.length);
      }
    });

    test('two lists of the same length but different members would fail', () {
      // Guards the guard: proves these assertions can actually detect the
      // subtle failure, rather than passing because everything is equal.
      final recommendation = _recommendation();
      final eightWithoutContour = _breakdownCategories(
        _manifest(_natural),
        recommendation,
      );
      final eightWithoutBlush = _breakdownCategories(
        _manifest(const {
          TutorialCategory.foundation: _present,
          TutorialCategory.concealer: _present,
          TutorialCategory.contourBronzer: _present,
          TutorialCategory.blush: _absent,
          TutorialCategory.highlighter: _present,
          TutorialCategory.eyebrows: _present,
          TutorialCategory.eyeshadow: _present,
          TutorialCategory.eyeliner: _present,
          TutorialCategory.lips: _present,
        }),
        recommendation,
      );
      expect(eightWithoutContour.length, eightWithoutBlush.length);
      expect(eightWithoutContour, isNot(eightWithoutBlush));
    });

    test('order follows the manifest vocabulary, not recommendation keys', () {
      final breakdown = _breakdownCategories(
        _manifest(_allNine),
        _recommendation(),
      );
      expect(breakdown, TutorialCategory.values);
    });

    test('all nine present yields nine on both screens', () {
      final recommendation = _recommendation();
      final manifest = _manifest(_allNine);
      expect(_breakdownCategories(manifest, recommendation), hasLength(9));
      expect(
        _tutorialCategories(manifest, _plan(recommendation)),
        hasLength(9),
      );
    });
  });

  group('the Everyday look', () {
    test('six categories on both screens, with Lips grouped', () {
      // The reported device case: the breakdown showed seven cards
      // (…Lipstick, Lip Gloss) against six steps. Grouping makes it six
      // sections against six steps, without hiding either lip product.
      final recommendation = _recommendation();
      final manifest = _manifest(_everyday);
      final groups = RealizedLookFilter.standardGroups(
        recommendation: recommendation,
        included: manifest.includedCategories,
      );
      final tutorial = _tutorialCategories(manifest, _plan(recommendation));

      expect(RealizedLookFilter.groupCategories(groups), <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.contourBronzer,
        TutorialCategory.blush,
        TutorialCategory.highlighter,
        TutorialCategory.eyeshadow,
        TutorialCategory.lips,
      ]);
      expect(groups, hasLength(6));
      expect(tutorial, hasLength(6));
      expect(RealizedLookFilter.groupCategories(groups), tutorial);

      // Both lip products survive, inside the one Lips section.
      final lips = groups.last;
      expect(lips.category, TutorialCategory.lips);
      expect(lips.entries.map((entry) => entry.planKey), <String>[
        'lipstick',
        'lipGloss',
      ]);
      expect(lips.hasMultipleEntries, isTrue);
      for (final group in groups.take(5)) {
        expect(group.hasMultipleEntries, isFalse);
      }
    });

    test('one lip product yields one entry and no empty placeholder', () {
      final lipstickOnly = MakeupRecommendation(
        id: 'rec-3',
        analysisId: 'analysis-1',
        styleCode: 'natural',
        overallIntensity: 'soft',
        items: <String, MakeupRecommendationItem>{
          'lipstick': _item('Rosewood', '#B86F72'),
        },
        modelId: 'm',
        promptVersion: 'v1',
        createdAt: _now,
      );
      final groups = RealizedLookFilter.standardGroups(
        recommendation: lipstickOnly,
        included: _manifest(const {
          TutorialCategory.lips: _present,
        }).includedCategories,
      );
      expect(groups, hasLength(1));
      expect(groups.single.entries, hasLength(1));
      expect(groups.single.hasMultipleEntries, isFalse);
    });
  });

  group('grouping is generic, not Lips-specific', () {
    test('any category with two plan keys forms one section', () {
      // Proved through the canonical mapping rather than by naming Lips: every
      // category is asked how many plan keys feed it, and each groups the same
      // way regardless of how many that is.
      for (final category in TutorialCategory.values) {
        final keys = TutorialCategoryMapping.standardRecommendationKeysFor(
          category,
        );
        final groups = RealizedLookFilter.standardGroups(
          recommendation: _recommendation(),
          included: _manifest({category: _present}).includedCategories,
        );
        expect(
          groups,
          hasLength(1),
          reason: '${category.code} must be exactly one section',
        );
        expect(
          groups.single.entries,
          hasLength(keys.length),
          reason:
              '${category.code} has ${keys.length} plan key(s), all of which '
              'belong inside its single section',
        );
      }
    });

    test('multiple entries never add a category', () {
      final groups = RealizedLookFilter.standardGroups(
        recommendation: _recommendation(),
        included: _manifest(_allNine).includedCategories,
      );
      final entryCount = groups.fold<int>(
        0,
        (total, group) => total + group.entries.length,
      );
      expect(groups, hasLength(9), reason: 'nine categories');
      expect(entryCount, 10, reason: 'ten plan keys, because Lips has two');
      expect(
        RealizedLookFilter.groupCategories(groups),
        TutorialCategory.values,
      );
    });

    test('a category with no metadata is omitted, never invented', () {
      // Deliberate and documented: the manifest can include a category the
      // recommendation never described. Rendering an empty heading would be
      // worse than omitting it, and inventing an item is forbidden outright.
      final blushOnly = MakeupRecommendation(
        id: 'rec-4',
        analysisId: 'analysis-1',
        styleCode: 'natural',
        overallIntensity: 'soft',
        items: <String, MakeupRecommendationItem>{
          'blush': _item('Warm peach', '#E8A08C'),
        },
        modelId: 'm',
        promptVersion: 'v1',
        createdAt: _now,
      );
      final groups = RealizedLookFilter.standardGroups(
        recommendation: blushOnly,
        included: _manifest(_allNine).includedCategories,
      );
      expect(groups, hasLength(1));
      expect(groups.single.category, TutorialCategory.blush);
      for (final group in groups) {
        expect(group.entries, isNotEmpty);
      }
    });
  });

  group('My Kit groups the same way', () {
    test('two owned lip products form one Lips section', () {
      final twoLipProducts = KitMakeupRecommendation(
        id: 'kit-rec-2',
        analysisId: 'analysis-1',
        styleCode: 'natural',
        selections: const <KitMakeupSelection>[
          KitMakeupSelection(
            productId: 'p1',
            category: 'lipstick',
            colorHex: '#B86F72',
            finish: 'cream',
            placement: 'Across the lips.',
            technique: 'Fill inward.',
            intensity: 'soft',
          ),
          KitMakeupSelection(
            productId: 'p2',
            category: 'lip_gloss',
            colorHex: '#D8A0A2',
            finish: 'glossy',
            placement: 'Over the centre.',
            technique: 'Dab lightly.',
            intensity: 'sheer',
          ),
        ],
        productSnapshots: const <KitProductSnapshot>[
          KitProductSnapshot(
            productId: 'p1',
            category: 'lipstick',
            colorHex: '#B86F72',
            finish: 'cream',
            productName: 'Everyday Nude',
          ),
          KitProductSnapshot(
            productId: 'p2',
            category: 'lip_gloss',
            colorHex: '#D8A0A2',
            finish: 'glossy',
            productName: 'Clear Shine',
          ),
        ],
        overallIntensity: 'soft',
        summary: 'Owned products.',
        modelId: 'm',
        promptVersion: 'v1',
        createdAt: _now,
      );

      final groups = RealizedLookFilter.kitGroups(
        recommendation: twoLipProducts,
        included: _manifest(
          const {TutorialCategory.lips: _present},
          sourceMode: RecommendationSourceMode.myMakeupKit,
          backed: const {TutorialCategory.lips},
        ).includedCategories,
      );

      expect(groups, hasLength(1));
      expect(groups.single.category, TutorialCategory.lips);
      expect(groups.single.entries, hasLength(2));
      expect(
        groups.single.entries.map((entry) => entry.selection.productId),
        <String>['p1', 'p2'],
      );
    });
  });

  group('absent and uncertain are both excluded', () {
    test('an uncertain category appears on neither screen', () {
      final recommendation = _recommendation();
      final manifest = _manifest(const {
        TutorialCategory.foundation: _present,
        TutorialCategory.highlighter: _uncertain,
        TutorialCategory.lips: _present,
      });
      final breakdown = _breakdownCategories(manifest, recommendation);
      expect(breakdown.contains(TutorialCategory.highlighter), isFalse);
      expect(
        _tutorialCategories(
          manifest,
          _plan(recommendation),
        ).contains(TutorialCategory.highlighter),
        isFalse,
      );
      expect(breakdown, <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
    });
  });

  group('the style label changes nothing', () {
    test('only the manifest decides, whatever the style is called', () {
      final byStyle = <String, String>{
        for (final style in <String>['full_glam', 'soft_glam', 'natural'])
          style: _breakdownCategories(
            _manifest(_natural),
            _recommendation(styleCode: style),
          ).map((category) => category.code).join(','),
      };
      expect(
        byStyle.values.toSet(),
        hasLength(1),
        reason: 'a style label leaked into filtering: $byStyle',
      );
    });
  });

  group('metadata authority is untouched', () {
    test('the recommendation still supplies every detail, unchanged', () {
      final recommendation = _recommendation();
      final entries = RealizedLookFilter.standardEntries(
        recommendation: recommendation,
        included: _manifest(_natural).includedCategories,
      );
      final blush = entries.firstWhere(
        (entry) => entry.category == TutorialCategory.blush,
      );
      expect(blush.item, same(recommendation.items['blush']));
      expect(blush.item.name, 'Warm peach');
      expect(blush.item.hex, '#E8A08C');
      expect(blush.item.placement, 'Across the area.');
      expect(blush.item.reasoning, 'Suits the undertone.');
    });

    test('nothing is invented for a category with no recommendation entry', () {
      final sparse = MakeupRecommendation(
        id: 'rec-2',
        analysisId: 'analysis-1',
        styleCode: 'natural',
        overallIntensity: 'soft',
        items: <String, MakeupRecommendationItem>{
          'blush': _item('Warm peach', '#E8A08C'),
        },
        modelId: 'm',
        promptVersion: 'v1',
        createdAt: _now,
      );
      final entries = RealizedLookFilter.standardEntries(
        recommendation: sparse,
        included: _manifest(_allNine).includedCategories,
      );
      expect(entries, hasLength(1));
      expect(entries.single.category, TutorialCategory.blush);
    });
  });

  group('My Makeup Kit', () {
    test(
      'presence comes from the manifest, product data from the snapshot',
      () {
        final recommendation = _kitRecommendation();
        // Contour is owned, but the preview does not show it.
        final entries = RealizedLookFilter.kitEntries(
          recommendation: recommendation,
          included: _manifest(
            const {
              TutorialCategory.foundation: _present,
              TutorialCategory.contourBronzer: _absent,
              TutorialCategory.lips: _present,
            },
            sourceMode: RecommendationSourceMode.myMakeupKit,
            backed: const {
              TutorialCategory.foundation,
              TutorialCategory.contourBronzer,
              TutorialCategory.lips,
            },
          ).includedCategories,
        );

        expect(RealizedLookFilter.kitCategories(entries), <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.lips,
        ]);
        expect(
          entries.map((entry) => entry.selection.productId),
          <String>['p1', 'p3'],
          reason: 'owning a contour product does not make it visible',
        );
        // Product identity still comes from the immutable snapshot.
        expect(
          recommendation
              .snapshotFor(entries.first.selection.productId)
              .productName,
          'Studio Base',
        );
      },
    );

    test('a kit mismatch is not resolved by filtering it away', () {
      // Blush is visibly present but no owned product backs it. The manifest
      // reports the mismatch; the filter must not be what "fixes" it.
      final manifest = _manifest(
        const {
          TutorialCategory.foundation: _present,
          TutorialCategory.blush: _present,
        },
        sourceMode: RecommendationSourceMode.myMakeupKit,
        backed: const {TutorialCategory.foundation},
      );
      expect(manifest.hasKitPreviewMismatch, isTrue);
      expect(manifest.unbackedPresentCategories, <TutorialCategory>[
        TutorialCategory.blush,
      ]);
      expect(
        manifest.isUsable,
        isFalse,
        reason:
            'the look is unusable, so no breakdown may be presented as if '
            'it were valid',
      );
    });
  });
}
