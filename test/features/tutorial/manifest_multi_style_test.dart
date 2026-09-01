import 'dart:io';

import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_step_planner.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/standard_look_entry.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

/// V4-QA-6: proof that tutorial inclusion is driven by visual evidence rather
/// than by which style was requested.
///
/// The claim being tested is a negative — "no style-to-step template, no
/// fixed-nine fallback" — and a negative is only worth asserting if it is
/// asserted the way it would actually fail. Two ways are covered here:
///
///  * **behaviourally**, by running the same inclusion logic over verdict sets
///    shaped like real Full Glam, Soft Glam, and Natural looks, and then
///    running *identical* verdicts under different style codes to show the
///    style changes nothing;
///  * **structurally**, by reading the analyzer source and showing the style
///    has no path into it at all — the strongest form of the guarantee, since
///    a value that is never passed cannot be consulted.
///
/// Counts here are *outcomes* of the fixtures, never rules. The fixtures are
/// hand-written verdict sets, not recorded model output, so nothing in this
/// file is evidence about how the model actually classifies a real photograph.
/// That evidence can only come from device QA over real canonical previews, and
/// this file deliberately does not pretend otherwise.

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
  modelId: 'server-reported-model',
  promptVersion: 'tutorial_manifest_v4_1',
  schemaVersion: 'manifest_schema_v1',
  createdAt: DateTime.utc(2026, 8, 30),
);

/// A look plan carrying a style code, so a planner run can be handed one.
///
/// The entries are irrelevant to inclusion by design — that is the point of
/// passing a plan at all here. What matters is that [styleCode] differs between
/// runs while the manifest does not.
ValidatedLookPlan _plan(String styleCode) => ValidatedLookPlan(
  id: 'rec-$styleCode',
  analysisId: 'analysis-1',
  styleCode: styleCode,
  source: StandardLookPlanSource(
    recommendationId: 'rec-$styleCode',
    entries: StandardLookEntries(
      byCategory: <TutorialCategory, List<StandardLookEntry>>{},
    ),
  ),
  modelId: 'm',
  promptVersion: 'v1',
  createdAt: DateTime.utc(2026, 8, 30),
);

const _present = TutorialCategoryPresence.present;
const _absent = TutorialCategoryPresence.absent;
const _uncertain = TutorialCategoryPresence.uncertain;

/// Verdict sets shaped like three real looks.
///
/// Written as what a comparison of two photographs might plausibly yield, not
/// as a specification of what each style must produce. If a real Full Glam
/// preview came back with seven categories rather than nine, that would be a
/// correct manifest, and nothing in the production path would resist it.
const _fullGlam = <TutorialCategory, TutorialCategoryPresence>{
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

const _softGlam = <TutorialCategory, TutorialCategoryPresence>{
  TutorialCategory.foundation: _present,
  TutorialCategory.concealer: _present,
  TutorialCategory.blush: _present,
  TutorialCategory.eyebrows: _present,
  TutorialCategory.eyeshadow: _present,
  TutorialCategory.lips: _present,
  // Not every category a "glam" label implies is actually visible.
  TutorialCategory.contourBronzer: _uncertain,
  TutorialCategory.highlighter: _absent,
  TutorialCategory.eyeliner: _absent,
};

const _natural = <TutorialCategory, TutorialCategoryPresence>{
  TutorialCategory.foundation: _present,
  TutorialCategory.eyebrows: _present,
  TutorialCategory.lips: _present,
  TutorialCategory.concealer: _uncertain,
  TutorialCategory.contourBronzer: _absent,
  TutorialCategory.blush: _absent,
  TutorialCategory.highlighter: _absent,
  TutorialCategory.eyeshadow: _absent,
  TutorialCategory.eyeliner: _absent,
};

void main() {
  group('inclusion is a pure function of the verdicts', () {
    test('three differently-shaped looks yield three different step sets', () {
      final full = _manifest(_fullGlam).includedCategories;
      final soft = _manifest(_softGlam).includedCategories;
      final natural = _manifest(_natural).includedCategories;

      expect(full, hasLength(9));
      expect(soft, hasLength(6));
      expect(natural, hasLength(3));

      // The point is not the numbers, which are properties of the fixtures.
      // It is that one code path produced three different answers from three
      // different sets of visual evidence.
      expect(<int>{full.length, soft.length, natural.length}, hasLength(3));
    });

    test('the same verdicts give the same steps under any style code', () {
      // The decisive test for "no style-to-step template". If a style name
      // reached inclusion anywhere, these three would diverge.
      final manifest = _manifest(_softGlam);
      // Compared as joined codes rather than as lists: Dart lists have identity
      // equality, so a set of four equal lists still has four members and the
      // assertion would fail whatever the planner did.
      final byStyle = <String, String>{
        for (final style in <String>[
          'full_glam',
          'soft_glam',
          'natural',
          'a_style_that_does_not_exist',
        ])
          style: TutorialStepPlanner.plan(
            manifest: manifest,
            lookPlan: _plan(style),
          ).map((step) => step.category.code).join(','),
      };

      expect(
        byStyle.values.toSet(),
        hasLength(1),
        reason: 'the style code changed the tutorial: $byStyle',
      );
      expect(
        byStyle['full_glam'],
        manifest.includedCategories.map((c) => c.code).join(','),
      );
    });

    test('a style label never widens a sparse look', () {
      // "Full Glam" over evidence that shows three categories must yield three
      // steps, not nine. This is the fixed-nine failure in its most tempting
      // form, because the label says the look should be complete.
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(_natural),
        lookPlan: _plan('full_glam'),
      );
      expect(steps, hasLength(3));
      expect(steps.map((step) => step.category), <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.eyebrows,
        TutorialCategory.lips,
      ]);
    });

    test('a style label never narrows a complete look', () {
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(_fullGlam),
        lookPlan: _plan('natural'),
      );
      expect(steps, hasLength(9));
    });
  });

  group('no fixed-nine behaviour', () {
    test('an empty look yields no steps rather than a default set', () {
      expect(_manifest(const {}).includedCategories, isEmpty);
      expect(
        TutorialStepPlanner.plan(
          manifest: _manifest(const {}),
          lookPlan: _plan('natural'),
        ),
        isEmpty,
      );
    });

    test('a single visible category yields exactly one step', () {
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(const {TutorialCategory.lips: _present}),
        lookPlan: _plan('full_glam'),
      );
      expect(steps, hasLength(1));
      expect(steps.single.category, TutorialCategory.lips);
      expect(steps.single.position, 1, reason: 'Step 1 of 1, not Step 9 of 9');
    });

    test('every count from zero to nine is representable', () {
      // A count that could not occur would be a template hiding somewhere.
      for (var size = 0; size <= TutorialCategory.values.length; size += 1) {
        final verdicts = <TutorialCategory, TutorialCategoryPresence>{
          for (final category in TutorialCategory.values.take(size))
            category: _present,
        };
        expect(_manifest(verdicts).includedCategories, hasLength(size));
      }
    });

    test('positions renumber to the included set, never to the vocabulary', () {
      // Highlighter is 5th of nine in the vocabulary. In a look containing only
      // Blush, Highlighter and Lips it is the 2nd step, and "Step 2 of 3" is
      // what the user must see.
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(const {
          TutorialCategory.blush: _present,
          TutorialCategory.highlighter: _present,
          TutorialCategory.lips: _present,
        }),
        lookPlan: _plan('soft_glam'),
      );
      expect(steps.map((step) => step.position), <int>[1, 2, 3]);
      expect(steps[1].category, TutorialCategory.highlighter);
    });
  });

  group('absent and uncertain are honoured, never converted', () {
    test('an absent category is omitted from the tutorial', () {
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(_softGlam),
        lookPlan: _plan('soft_glam'),
      );
      final categories = steps.map((step) => step.category).toSet();
      for (final absent in <TutorialCategory>[
        TutorialCategory.highlighter,
        TutorialCategory.eyeliner,
      ]) {
        expect(
          categories.contains(absent),
          isFalse,
          reason: '${absent.code} was not visible and must not be a step',
        );
      }
    });

    test('uncertain is excluded and stays visible as uncertain', () {
      final manifest = _manifest(_natural);
      expect(
        manifest.includedCategories.contains(TutorialCategory.concealer),
        isFalse,
      );
      expect(manifest.uncertainCategories, <TutorialCategory>[
        TutorialCategory.concealer,
      ]);
      expect(
        manifest.itemFor(TutorialCategory.concealer)!.presence,
        _uncertain,
        reason: 'uncertain is preserved, not rewritten to absent',
      );
    });

    test('confidence never promotes uncertain to present', () {
      // No threshold exists, so a high-confidence uncertain is still excluded.
      // If a cutoff were ever introduced, this is where it would show up.
      for (final confidence in <double>[0, 0.5, 0.94, 0.99, 1]) {
        final manifest = TutorialManifest(
          canonicalPreviewId: 'preview-1',
          sourceMode: RecommendationSourceMode.standard,
          status: TutorialManifestStatus.accepted,
          items: <TutorialManifestItem>[
            TutorialManifestItem(
              category: TutorialCategory.blush,
              presence: _uncertain,
              visualConfidence: confidence,
            ),
          ],
          modelId: 'm',
          promptVersion: 'tutorial_manifest_v4_1',
          schemaVersion: 'manifest_schema_v1',
          createdAt: DateTime.utc(2026, 8, 30),
        );
        expect(manifest.includedCategories, isEmpty);
      }
    });
  });

  group('My Makeup Kit intersects; it does not substitute', () {
    test('visible and owned is included; visible and unowned blocks', () {
      final manifest = _manifest(
        _natural,
        sourceMode: RecommendationSourceMode.myMakeupKit,
        backed: const {TutorialCategory.foundation, TutorialCategory.lips},
      );

      // Eyebrows is visible but unowned: the preview promises something the
      // kit cannot reproduce, so no honest tutorial exists.
      expect(manifest.unbackedPresentCategories, <TutorialCategory>[
        TutorialCategory.eyebrows,
      ]);
      expect(manifest.hasKitPreviewMismatch, isTrue);
      expect(manifest.isUsable, isFalse);
      expect(
        () => TutorialStepPlanner.plan(
          manifest: manifest,
          lookPlan: _plan('natural'),
        ),
        throwsA(anything),
        reason: 'a mismatched look must not silently drop the unowned step',
      );
    });

    test('owning a product never manufactures a step', () {
      // Owning eyeshadow while the preview shows none must not add a step.
      final manifest = _manifest(
        _natural,
        sourceMode: RecommendationSourceMode.myMakeupKit,
        backed: const {
          TutorialCategory.foundation,
          TutorialCategory.eyebrows,
          TutorialCategory.lips,
          TutorialCategory.eyeshadow,
        },
      );
      expect(manifest.hasKitPreviewMismatch, isFalse);
      expect(
        manifest.includedCategories.contains(TutorialCategory.eyeshadow),
        isFalse,
      );
      expect(manifest.includedCategories, hasLength(3));
    });

    test('the same verdicts give fewer steps in kit mode, never more', () {
      final standard = _manifest(_softGlam).includedCategories;
      final kit = _manifest(
        _softGlam,
        sourceMode: RecommendationSourceMode.myMakeupKit,
        backed: TutorialCategory.values.toSet(),
      ).includedCategories;
      expect(kit, standard, reason: 'a complete kit reproduces the same look');

      final partial = _manifest(
        _softGlam,
        sourceMode: RecommendationSourceMode.myMakeupKit,
        backed: const {TutorialCategory.foundation},
      );
      expect(
        partial.includedCategories.length,
        lessThanOrEqualTo(standard.length),
      );
    });

    test('a kit step carries the owned product it was matched to', () {
      final steps = TutorialStepPlanner.plan(
        manifest: _manifest(
          const {TutorialCategory.lips: _present},
          sourceMode: RecommendationSourceMode.myMakeupKit,
          backed: const {TutorialCategory.lips},
        ),
        lookPlan: ValidatedLookPlan(
          id: 'kit-1',
          analysisId: 'analysis-1',
          styleCode: 'soft_glam',
          source: MyMakeupKitLookPlanSource(
            kitRecommendationId: 'kit-1',
            productSnapshot: LookProductSnapshot(
              items: <LookProductSnapshotItem>[
                LookProductSnapshotItem.fromKitSnapshot(
                  const KitProductSnapshot(
                    productId: 'p1',
                    category: 'lipstick',
                    colorHex: '#B86F72',
                    finish: 'cream',
                    productName: 'Everyday Nude',
                  ),
                ),
              ],
            ),
          ),
          modelId: 'm',
          promptVersion: 'v1',
          createdAt: DateTime.utc(2026, 8, 30),
        ),
      );
      expect(steps.single.productSnapshotItems, hasLength(1));
      expect(
        steps.single.productSnapshotItems.single.productName,
        'Everyday Nude',
      );
    });
  });

  group('the style has no path into the analyzer', () {
    final root = Directory.current;

    String source(String relativePath) => File(
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    ).readAsStringSync();

    const dir = 'supabase/functions/analyze-tutorial-manifest-v4';
    final index = source('$dir/index.ts');
    final prompt = source('$dir/prompt.ts');
    final validation = source('$dir/validation.ts');

    test('the style code is never sent to the analyzer model', () {
      // The strongest available form of "not style-driven": the analyzer never
      // learns which style was requested. Its supporting context is a fixed
      // sentence in Standard Mode and the owned-category list in kit mode —
      // no style name, no shade names, no recommendation items.
      expect(
        index,
        contains(
          'let supportingContext = "Standard Mode: no owned-product constraint.";',
        ),
      );
      for (final leaked in <String>[
        'styleCode',
        'style_code',
        'makeup_style',
        'full_glam',
        'soft_glam',
      ]) {
        expect(
          index,
          isNot(contains(leaked)),
          reason: 'the analyzer must not know which style was requested',
        );
      }
    });

    test('resolution reads verdicts and ownership, and nothing else', () {
      // resolveManifest's whole input surface. A style could only influence
      // inclusion by being one of these.
      expect(
        validation,
        contains(
          'export function resolveManifest(\n'
          '  verdicts: ManifestVerdict[],\n'
          '  sourceMode: SourceMode,\n'
          '  backedCategories: Set<TutorialCategory>,\n'
          '): ResolvedManifest {',
        ),
      );
      expect(
        validation,
        contains('included: isKit ? visible && productBacked'),
      );
      expect(validation, isNot(contains('style')));
    });

    test('no count is hardcoded anywhere in the inclusion path', () {
      for (final file in <String>[validation, index]) {
        expect(
          RegExp(r'length\s*===\s*9').hasMatch(file),
          isFalse,
          reason: 'a nine-category assumption must not gate inclusion',
        );
        expect(RegExp(r'=\s*9\b').hasMatch(file), isFalse);
      }
      // The only nine in the system is the size of the vocabulary itself, and
      // it is derived rather than written down.
      expect(validation, contains('TUTORIAL_CATEGORIES.length'));
    });

    test('the prompt forbids style-driven and completeness-driven answers', () {
      expect(
        prompt,
        contains(
          'Never mark a category present because a makeup style usually '
          'includes it.',
        ),
      );
      expect(
        prompt,
        contains(
          'Do not assume every category was used. Many real looks use '
          'only a few.',
        ),
      );
      expect(
        prompt,
        contains(
          'Never mark a category present because it appears in the '
          'supporting context below.',
        ),
      );
      expect(prompt, contains('"uncertain" is a correct and useful answer'));
    });
  });
}
