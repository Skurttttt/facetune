import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 8, 30);

KitProductSnapshot _snapshot(String productId, String category) =>
    KitProductSnapshot(
      productId: productId,
      category: category,
      colorHex: '#B86F72',
      finish: 'matte',
    );

ValidatedLookPlan _kitPlan(List<KitProductSnapshot> snapshots) =>
    LookPlanConvergence.fromMyMakeupKit(
      KitMakeupRecommendation(
        id: 'kit-rec-1',
        analysisId: 'analysis-1',
        styleCode: 'soft_glam',
        selections: const <KitMakeupSelection>[],
        productSnapshots: snapshots,
        overallIntensity: 'soft',
        summary: 'Built from owned products.',
        modelId: 'server-reported-model',
        promptVersion: 'kit_makeup_recommendation_v2',
        createdAt: _now,
      ),
    );

TutorialManifest _manifest({
  required RecommendationSourceMode sourceMode,
  required Map<
    TutorialCategory,
    ({TutorialCategoryPresence presence, bool backed})
  >
  verdicts,
  TutorialManifestStatus status = TutorialManifestStatus.accepted,
  String canonicalPreviewId = 'preview-1',
}) => TutorialManifest(
  canonicalPreviewId: canonicalPreviewId,
  sourceMode: sourceMode,
  status: status,
  items: <TutorialManifestItem>[
    for (final entry in verdicts.entries)
      TutorialManifestItem(
        category: entry.key,
        presence: entry.value.presence,
        productBacked: entry.value.backed,
      ),
  ],
  modelId: 'server-reported-model',
  promptVersion: 'v1',
  schemaVersion: 'v1',
  createdAt: _now,
);

TutorialSession _session({
  required ValidatedLookPlan plan,
  TutorialManifest? manifest,
  TutorialSessionStatus status = TutorialSessionStatus.ready,
  String canonicalPreviewId = 'preview-1',
}) => TutorialSession(
  id: 'session-1',
  userId: 'user-1',
  analysisId: 'analysis-1',
  canonicalPreviewId: canonicalPreviewId,
  lookPlan: plan,
  status: status,
  manifest: manifest,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  group('a consistent kit look is usable', () {
    test('every visible category is backed by an owned product', () {
      final manifest = _manifest(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        verdicts: {
          TutorialCategory.foundation: (
            presence: TutorialCategoryPresence.present,
            backed: true,
          ),
          TutorialCategory.lips: (
            presence: TutorialCategoryPresence.present,
            backed: true,
          ),
          TutorialCategory.eyeliner: (
            presence: TutorialCategoryPresence.absent,
            backed: false,
          ),
        },
      );

      expect(manifest.hasKitPreviewMismatch, isFalse);
      expect(manifest.isUsable, isTrue);
      expect(manifest.unbackedPresentCategories, isEmpty);
      expect(manifest.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
    });

    test('the session reports no mismatch and stays reusable', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[
          _snapshot('p1', 'foundation'),
          _snapshot('p2', 'lipstick'),
        ]),
        manifest: _manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          verdicts: {
            TutorialCategory.foundation: (
              presence: TutorialCategoryPresence.present,
              backed: true,
            ),
          },
        ),
      );

      expect(session.hasKitPreviewMismatch, isFalse);
      expect(session.hasReusableManifest, isTrue);
      expect(session.unbackedPresentCategories, isEmpty);
    });
  });

  group('the snapshot decides which kit steps exist', () {
    // OMKT target: snapshot foundation, blush, eyeshadow, lipstick; the image
    // judged foundation and eyeshadow uncertain and showed an unowned concealer.
    final plan = _kitPlan(<KitProductSnapshot>[
      _snapshot('p1', 'foundation'),
      _snapshot('p2', 'blush'),
      _snapshot('p3', 'eyeshadow'),
      _snapshot('p4', 'lipstick'),
    ]);
    final manifest = _manifest(
      sourceMode: RecommendationSourceMode.myMakeupKit,
      status: TutorialManifestStatus.kitPreviewMismatch,
      verdicts: {
        TutorialCategory.foundation: (
          presence: TutorialCategoryPresence.uncertain,
          backed: true,
        ),
        TutorialCategory.concealer: (
          presence: TutorialCategoryPresence.present,
          backed: false,
        ),
        TutorialCategory.blush: (
          presence: TutorialCategoryPresence.present,
          backed: true,
        ),
        TutorialCategory.eyeshadow: (
          presence: TutorialCategoryPresence.uncertain,
          backed: true,
        ),
        TutorialCategory.eyeliner: (
          presence: TutorialCategoryPresence.absent,
          backed: false,
        ),
        TutorialCategory.lips: (
          presence: TutorialCategoryPresence.present,
          backed: true,
        ),
      },
    );

    test('every selected category is a step, whatever the verdict', () {
      expect(manifest.isUsable, isTrue);
      expect(
        _session(plan: plan, manifest: manifest).includedCategories,
        const <TutorialCategory>[
          TutorialCategory.foundation,
          TutorialCategory.blush,
          TutorialCategory.eyeshadow,
          TutorialCategory.lips,
        ],
      );
    });

    test('a selected but visually absent category is still a step', () {
      final absent = _manifest(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        verdicts: {
          TutorialCategory.lips: (
            presence: TutorialCategoryPresence.absent,
            backed: true,
          ),
        },
      );
      expect(
        _session(plan: plan, manifest: absent).includedCategories,
        const <TutorialCategory>[TutorialCategory.lips],
      );
    });

    test('a backed flag the snapshot no longer supports adds nothing', () {
      final stale = _manifest(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        verdicts: {
          TutorialCategory.highlighter: (
            presence: TutorialCategoryPresence.present,
            backed: true,
          ),
          TutorialCategory.lips: (
            presence: TutorialCategoryPresence.present,
            backed: true,
          ),
        },
      );
      expect(
        _session(plan: plan, manifest: stale).includedCategories,
        const <TutorialCategory>[TutorialCategory.lips],
      );
    });
  });

  group('an unbacked visible category is a non-blocking diagnostic', () {
    TutorialManifest mismatched() => _manifest(
      sourceMode: RecommendationSourceMode.myMakeupKit,
      verdicts: {
        TutorialCategory.foundation: (
          presence: TutorialCategoryPresence.present,
          backed: true,
        ),
        // The preview shows eyeliner the user owns no product for.
        TutorialCategory.eyeliner: (
          presence: TutorialCategoryPresence.present,
          backed: false,
        ),
      },
    );

    test('is detected and names the exact discrepancy', () {
      final manifest = mismatched();

      expect(manifest.hasKitPreviewMismatch, isTrue);
      expect(manifest.unbackedPresentCategories, const <TutorialCategory>[
        TutorialCategory.eyeliner,
      ]);
    });

    test('keeps the manifest usable and leaves the category out', () {
      final manifest = mismatched();

      expect(
        manifest.isUsable,
        isTrue,
        reason: 'the snapshot, not the image, decides whether steps exist',
      );
      expect(
        manifest.includedCategories,
        const <TutorialCategory>[TutorialCategory.foundation],
        reason: 'the unowned eyeliner the preview shows is never a step',
      );
    });

    test(
      'a persisted kit_preview_mismatch status stays usable in kit mode',
      () {
        final persisted = _manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          status: TutorialManifestStatus.kitPreviewMismatch,
          verdicts: {
            TutorialCategory.foundation: (
              presence: TutorialCategoryPresence.present,
              backed: true,
            ),
            TutorialCategory.eyeliner: (
              presence: TutorialCategoryPresence.present,
              backed: false,
            ),
          },
        );
        expect(persisted.isUsable, isTrue);
      },
    );

    test('is reported at the session level without blocking reuse', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[_snapshot('p1', 'foundation')]),
        manifest: mismatched(),
        status: TutorialSessionStatus.kitPreviewMismatch,
      );

      expect(session.hasKitPreviewMismatch, isTrue);
      expect(session.hasReusableManifest, isTrue);
      expect(session.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
      ]);
      expect(session.unbackedPresentCategories, const <TutorialCategory>[
        TutorialCategory.eyeliner,
      ]);
    });

    test('has a distinct status, not a generic failure', () {
      expect(
        TutorialManifestStatus.kitPreviewMismatch.code,
        'kit_preview_mismatch',
      );
      expect(
        TutorialManifestStatus.kitPreviewMismatch,
        isNot(TutorialManifestStatus.failed),
      );
      expect(
        TutorialSessionStatus.kitPreviewMismatch.code,
        'kit_preview_mismatch',
      );
      expect(
        TutorialManifestStatus.fromCode('kit_preview_mismatch'),
        TutorialManifestStatus.kitPreviewMismatch,
      );
      expect(
        TutorialSessionStatus.fromCode('kit_preview_mismatch'),
        TutorialSessionStatus.kitPreviewMismatch,
      );
    });

    test('a session marked mismatched reports it even without a manifest', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[_snapshot('p1', 'foundation')]),
        status: TutorialSessionStatus.kitPreviewMismatch,
      );

      expect(session.hasKitPreviewMismatch, isTrue);
      expect(session.hasReusableManifest, isFalse);
    });

    test('never resolves by falling back to Standard Mode', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[_snapshot('p1', 'foundation')]),
        manifest: mismatched(),
      );

      expect(session.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(session.lookPlan.source, isA<MyMakeupKitLookPlanSource>());
    });

    test('never resolves by inventing a product', () {
      final plan = _kitPlan(<KitProductSnapshot>[
        _snapshot('p1', 'foundation'),
      ]);
      final session = _session(plan: plan, manifest: mismatched());

      // Eyeliner is visible in the preview but the snapshot gains nothing.
      expect(
        session.unbackedPresentCategories,
        contains(TutorialCategory.eyeliner),
      );
      expect(plan.productSnapshot.covers(TutorialCategory.eyeliner), isFalse);
      expect(plan.productSnapshot.itemsFor(TutorialCategory.eyeliner), isEmpty);
      expect(plan.productSnapshot.items, hasLength(1));
    });
  });

  group('Standard Mode has no ownership to contradict', () {
    test('an unbacked visible category is never a mismatch', () {
      final manifest = _manifest(
        sourceMode: RecommendationSourceMode.standard,
        verdicts: {
          TutorialCategory.eyeliner: (
            presence: TutorialCategoryPresence.present,
            backed: false,
          ),
        },
      );

      expect(manifest.hasKitPreviewMismatch, isFalse);
      expect(manifest.isUsable, isTrue);
      expect(manifest.unbackedPresentCategories, isEmpty);
      expect(manifest.includedCategories, const <TutorialCategory>[
        TutorialCategory.eyeliner,
      ]);
    });

    test('present is a step; absent and uncertain are not', () {
      final manifest = _manifest(
        sourceMode: RecommendationSourceMode.standard,
        verdicts: {
          TutorialCategory.foundation: (
            presence: TutorialCategoryPresence.uncertain,
            // Never written for Standard; ignored even if it were.
            backed: true,
          ),
          TutorialCategory.blush: (
            presence: TutorialCategoryPresence.present,
            backed: false,
          ),
          TutorialCategory.lips: (
            presence: TutorialCategoryPresence.absent,
            backed: true,
          ),
        },
      );
      final session = _session(
        plan: LookPlanConvergence.fromMyMakeupKit(
          KitMakeupRecommendation(
            id: 'unused',
            analysisId: 'analysis-1',
            styleCode: 'soft_glam',
            selections: const <KitMakeupSelection>[],
            productSnapshots: const <KitProductSnapshot>[],
            overallIntensity: 'soft',
            summary: 'unused',
            modelId: 'm',
            promptVersion: 'v',
            createdAt: _now,
          ),
        ),
        manifest: manifest,
      );

      expect(manifest.includedCategories, const <TutorialCategory>[
        TutorialCategory.blush,
      ]);
      expect(
        manifest.includedCategoriesFor(session.lookPlan.productSnapshot),
        const <TutorialCategory>[TutorialCategory.blush],
        reason: 'Standard Mode ignores any snapshot entirely',
      );
    });

    test('only an accepted manifest is usable', () {
      for (final status in TutorialManifestStatus.values) {
        final manifest = _manifest(
          sourceMode: RecommendationSourceMode.standard,
          status: status,
          verdicts: {
            TutorialCategory.blush: (
              presence: TutorialCategoryPresence.present,
              backed: false,
            ),
          },
        );
        expect(
          manifest.isUsable,
          status == TutorialManifestStatus.accepted,
          reason: status.code,
        );
      }
    });
  });

  group('regenerated canonical preview lineage', () {
    test('a manifest does not carry over to a new preview', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[_snapshot('p1', 'foundation')]),
        canonicalPreviewId: 'preview-2',
        manifest: _manifest(
          sourceMode: RecommendationSourceMode.myMakeupKit,
          canonicalPreviewId: 'preview-1',
          verdicts: {
            TutorialCategory.foundation: (
              presence: TutorialCategoryPresence.present,
              backed: true,
            ),
          },
        ),
      );

      expect(
        session.hasReusableManifest,
        isFalse,
        reason: 'a regenerated preview is a new visual target',
      );
      expect(session.includedCategories, isNotEmpty);
    });

    test('the look plan lineage survives preview regeneration', () {
      final plan = _kitPlan(<KitProductSnapshot>[
        _snapshot('p1', 'foundation'),
        _snapshot('p2', 'lipstick'),
      ]);
      final regenerated = _session(plan: plan, canonicalPreviewId: 'preview-2');

      expect(regenerated.lookPlan.id, 'kit-rec-1');
      expect(regenerated.analysisId, 'analysis-1');
      expect(regenerated.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(regenerated.lookPlan.productSnapshot.items, hasLength(2));
    });
  });
}
