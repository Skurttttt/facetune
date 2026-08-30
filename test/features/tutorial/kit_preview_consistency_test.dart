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

  group('an unbacked visible category is a controlled mismatch', () {
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

    test('makes the manifest unusable despite a clean analysis', () {
      final manifest = mismatched();

      expect(
        manifest.status,
        TutorialManifestStatus.accepted,
        reason: 'the analysis itself succeeded',
      );
      expect(
        manifest.isUsable,
        isFalse,
        reason: 'a look the user cannot reproduce must not build steps',
      );
    });

    test('blocks manifest reuse at the session level', () {
      final session = _session(
        plan: _kitPlan(<KitProductSnapshot>[_snapshot('p1', 'foundation')]),
        manifest: mismatched(),
      );

      expect(session.hasKitPreviewMismatch, isTrue);
      expect(session.hasReusableManifest, isFalse);
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
