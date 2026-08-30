import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialManifest manifest({
  required List<TutorialManifestItem> items,
  RecommendationSourceMode sourceMode = RecommendationSourceMode.standard,
  TutorialManifestStatus status = TutorialManifestStatus.accepted,
  String canonicalPreviewId = 'preview-1',
}) => TutorialManifest(
  canonicalPreviewId: canonicalPreviewId,
  sourceMode: sourceMode,
  status: status,
  items: items,
  modelId: 'server-reported-model',
  promptVersion: 'tutorial_manifest_v4_1',
  schemaVersion: 'manifest_schema_v1',
  createdAt: DateTime.utc(2026, 8, 30),
);

TutorialManifestItem item(
  TutorialCategory category,
  TutorialCategoryPresence presence, {
  bool productBacked = false,
  double? visualConfidence,
}) => TutorialManifestItem(
  category: category,
  presence: presence,
  productBacked: productBacked,
  visualConfidence: visualConfidence,
);

void main() {
  group('TutorialCategoryPresence', () {
    test('models present, absent, and uncertain as distinct states', () {
      expect(TutorialCategoryPresence.values, hasLength(3));
      for (final presence in TutorialCategoryPresence.values) {
        expect(TutorialCategoryPresence.fromCode(presence.code), presence);
      }
      expect(TutorialCategoryPresence.fromCode('maybe'), isNull);
    });
  });

  group('manifest inclusion', () {
    test('includes only categories visibly present', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          item(TutorialCategory.foundation, TutorialCategoryPresence.present),
          item(TutorialCategory.concealer, TutorialCategoryPresence.absent),
          item(TutorialCategory.blush, TutorialCategoryPresence.present),
          item(TutorialCategory.eyeliner, TutorialCategoryPresence.uncertain),
          item(TutorialCategory.lips, TutorialCategoryPresence.present),
        ],
      );

      expect(subject.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.blush,
        TutorialCategory.lips,
      ]);
    });

    test('never promotes uncertain to present', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          item(
            TutorialCategory.contourBronzer,
            TutorialCategoryPresence.uncertain,
          ),
          item(
            TutorialCategory.highlighter,
            TutorialCategoryPresence.uncertain,
          ),
        ],
      );

      expect(subject.includedCategories, isEmpty);
      expect(subject.uncertainCategories, const <TutorialCategory>[
        TutorialCategory.contourBronzer,
        TutorialCategory.highlighter,
      ]);
    });

    test('does not create nine steps merely because nine are supported', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          for (final category in TutorialCategory.values)
            item(category, TutorialCategoryPresence.absent),
        ],
      );

      expect(TutorialCategory.values, hasLength(9));
      expect(subject.includedCategories, isEmpty);
    });

    test('orders included categories deterministically', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          item(TutorialCategory.lips, TutorialCategoryPresence.present),
          item(TutorialCategory.foundation, TutorialCategoryPresence.present),
          item(TutorialCategory.eyeshadow, TutorialCategoryPresence.present),
          item(TutorialCategory.blush, TutorialCategoryPresence.present),
        ],
      );

      expect(subject.includedCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.blush,
        TutorialCategory.eyeshadow,
        TutorialCategory.lips,
      ]);
    });

    test('looks up the verdict for one category', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          item(
            TutorialCategory.blush,
            TutorialCategoryPresence.present,
            visualConfidence: 0.82,
          ),
        ],
      );

      expect(
        subject.itemFor(TutorialCategory.blush)?.presence,
        TutorialCategoryPresence.present,
      );
      expect(subject.itemFor(TutorialCategory.blush)?.visualConfidence, 0.82);
      expect(subject.itemFor(TutorialCategory.lips), isNull);
    });
  });

  group('kit preview mismatch detection', () {
    test('flags a present category with no validated owned product', () {
      final subject = manifest(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        items: <TutorialManifestItem>[
          item(
            TutorialCategory.foundation,
            TutorialCategoryPresence.present,
            productBacked: true,
          ),
          item(
            TutorialCategory.eyeliner,
            TutorialCategoryPresence.present,
            productBacked: false,
          ),
        ],
      );

      expect(subject.unbackedPresentCategories, const <TutorialCategory>[
        TutorialCategory.eyeliner,
      ]);
    });

    test('reports no mismatch when every present category is backed', () {
      final subject = manifest(
        sourceMode: RecommendationSourceMode.myMakeupKit,
        items: <TutorialManifestItem>[
          item(
            TutorialCategory.blush,
            TutorialCategoryPresence.present,
            productBacked: true,
          ),
          item(
            TutorialCategory.eyeliner,
            TutorialCategoryPresence.absent,
            productBacked: false,
          ),
        ],
      );

      expect(subject.unbackedPresentCategories, isEmpty);
    });

    test('never flags a mismatch in standard mode', () {
      final subject = manifest(
        items: <TutorialManifestItem>[
          item(TutorialCategory.eyeliner, TutorialCategoryPresence.present),
        ],
      );

      expect(subject.sourceMode, RecommendationSourceMode.standard);
      expect(subject.unbackedPresentCategories, isEmpty);
    });
  });

  test('manifest items are immutable', () {
    final subject = manifest(
      items: <TutorialManifestItem>[
        item(TutorialCategory.blush, TutorialCategoryPresence.present),
      ],
    );
    expect(
      () => subject.items.add(subject.items.first),
      throwsUnsupportedError,
    );
  });

  test('manifest status vocabulary round-trips', () {
    for (final status in TutorialManifestStatus.values) {
      expect(TutorialManifestStatus.fromCode(status.code), status);
    }
    expect(TutorialManifestStatus.fromCode('done'), isNull);
  });
}
