import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/errors/tutorial_failure.dart';
import 'package:flutter_test/flutter_test.dart';

KitProductSnapshot kitSnapshot({
  required String productId,
  required String category,
  String colorHex = '#B86F72',
  String finish = 'satin',
  String? productName,
  String? colorLabel,
  String? foundationDepth,
  String? foundationUndertone,
}) => KitProductSnapshot(
  productId: productId,
  category: category,
  colorHex: colorHex,
  finish: finish,
  productName: productName,
  colorLabel: colorLabel,
  foundationDepth: foundationDepth,
  foundationUndertone: foundationUndertone,
);

void main() {
  group('LookProductSnapshotItem parsing', () {
    test('parses a persisted kit snapshot into typed values', () {
      final item = LookProductSnapshotItem.fromKitSnapshot(
        kitSnapshot(
          productId: 'p1',
          category: 'foundation',
          colorHex: '#e3c4a8',
          finish: 'dewy',
          productName: 'Studio Base',
          colorLabel: 'Warm Sand',
          foundationDepth: 'light',
          foundationUndertone: 'warm',
        ),
      );

      expect(item.productId, 'p1');
      expect(item.kitCategory, MakeupKitCategory.foundation);
      expect(item.finish, MakeupKitFinish.dewy);
      expect(item.color.value, '#E3C4A8');
      expect(item.productName, 'Studio Base');
      expect(item.colorLabel, 'Warm Sand');
      expect(item.foundationDepth, FoundationDepth.light);
      expect(item.foundationUndertone, FoundationUndertone.warm);
      expect(item.tutorialCategory, TutorialCategory.foundation);
    });

    test('derives the tutorial category rather than storing it', () {
      final lipstick = LookProductSnapshotItem.fromKitSnapshot(
        kitSnapshot(productId: 'p1', category: 'lipstick', finish: 'cream'),
      );
      final gloss = LookProductSnapshotItem.fromKitSnapshot(
        kitSnapshot(productId: 'p2', category: 'lip_gloss', finish: 'glossy'),
      );

      expect(lipstick.tutorialCategory, TutorialCategory.lips);
      expect(gloss.tutorialCategory, TutorialCategory.lips);
      expect(lipstick.kitCategory, isNot(gloss.kitCategory));
    });

    test('accepts a product with no optional metadata', () {
      final item = LookProductSnapshotItem.fromKitSnapshot(
        kitSnapshot(productId: 'p1', category: 'blush', finish: 'matte'),
      );

      expect(item.productName, isNull);
      expect(item.colorLabel, isNull);
      expect(item.foundationDepth, isNull);
      expect(item.foundationUndertone, isNull);
    });

    test('rejects an unsupported category', () {
      expect(
        () => LookProductSnapshotItem.fromKitSnapshot(
          kitSnapshot(productId: 'p1', category: 'setting_spray'),
        ),
        throwsA(
          isA<TutorialFailure>()
              .having(
                (failure) => failure.kind,
                'kind',
                TutorialFailureKind.unsupportedCategory,
              )
              .having((failure) => failure.retryable, 'retryable', false),
        ),
      );
    });

    test('rejects an unsupported finish', () {
      expect(
        () => LookProductSnapshotItem.fromKitSnapshot(
          kitSnapshot(
            productId: 'p1',
            category: 'blush',
            finish: 'holographic',
          ),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.unsupportedCategory,
          ),
        ),
      );
    });

    test('rejects a malformed colour', () {
      expect(
        () => LookProductSnapshotItem.fromKitSnapshot(
          kitSnapshot(productId: 'p1', category: 'blush', colorHex: 'nope'),
        ),
        throwsA(
          isA<TutorialFailure>().having(
            (failure) => failure.kind,
            'kind',
            TutorialFailureKind.validation,
          ),
        ),
      );
    });
  });

  group('LookProductSnapshot', () {
    test('returns every product mapped to one tutorial category', () {
      final snapshot = LookProductSnapshot.fromKitSnapshots(
        <KitProductSnapshot>[
          kitSnapshot(productId: 'p1', category: 'lipstick', finish: 'cream'),
          kitSnapshot(productId: 'p2', category: 'lip_gloss', finish: 'glossy'),
          kitSnapshot(productId: 'p3', category: 'blush', finish: 'matte'),
        ],
      );

      final lips = snapshot.itemsFor(TutorialCategory.lips);
      expect(lips, hasLength(2));
      expect(lips.map((item) => item.productId).toList(), <String>['p1', 'p2']);
      expect(snapshot.itemsFor(TutorialCategory.blush), hasLength(1));
    });

    test('represents an incomplete kit without error', () {
      final snapshot =
          LookProductSnapshot.fromKitSnapshots(<KitProductSnapshot>[
            kitSnapshot(
              productId: 'p1',
              category: 'foundation',
              finish: 'natural',
            ),
            kitSnapshot(productId: 'p2', category: 'lipstick', finish: 'matte'),
          ]);

      expect(snapshot.items, hasLength(2));
      expect(snapshot.covers(TutorialCategory.foundation), isTrue);
      expect(snapshot.covers(TutorialCategory.lips), isTrue);
      expect(snapshot.covers(TutorialCategory.eyeliner), isFalse);
      expect(snapshot.itemsFor(TutorialCategory.eyeliner), isEmpty);
      expect(snapshot.coveredCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.lips,
      ]);
    });

    test('represents an empty kit selection without error', () {
      expect(LookProductSnapshot.empty.items, isEmpty);
      expect(LookProductSnapshot.empty.coveredCategories, isEmpty);
      expect(LookProductSnapshot.empty.covers(TutorialCategory.blush), isFalse);
    });

    test('reports covered categories in deterministic order', () {
      final snapshot = LookProductSnapshot.fromKitSnapshots(<
        KitProductSnapshot
      >[
        kitSnapshot(productId: 'p1', category: 'lip_gloss', finish: 'glossy'),
        kitSnapshot(productId: 'p2', category: 'eyeliner', finish: 'matte'),
        kitSnapshot(productId: 'p3', category: 'foundation', finish: 'natural'),
        kitSnapshot(productId: 'p4', category: 'lipstick', finish: 'cream'),
      ]);

      expect(snapshot.coveredCategories, const <TutorialCategory>[
        TutorialCategory.foundation,
        TutorialCategory.eyeliner,
        TutorialCategory.lips,
      ]);
    });

    test('is immutable', () {
      final snapshot = LookProductSnapshot.fromKitSnapshots(
        <KitProductSnapshot>[
          kitSnapshot(productId: 'p1', category: 'blush', finish: 'matte'),
        ],
      );
      expect(
        () => snapshot.items.add(snapshot.items.first),
        throwsUnsupportedError,
      );
    });

    test('rejects the whole snapshot when one product is unsupported', () {
      expect(
        () => LookProductSnapshot.fromKitSnapshots(<KitProductSnapshot>[
          kitSnapshot(productId: 'p1', category: 'blush', finish: 'matte'),
          kitSnapshot(productId: 'p2', category: 'setting_spray'),
        ]),
        throwsA(isA<TutorialFailure>()),
      );
    });
  });
}
