import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_step_spec.dart';
import 'package:facetune/features/tutorial_v2/domain/errors/tutorial_v2_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/tutorial_v2_fixtures.dart';

TutorialV2StepDraft _kitDraft(
  TutorialV2Category category, {
  String productId = 'product-1',
  TutorialV2Category? productCategory,
  String? productName,
  String? colorLabel,
}) => tutorialV2Draft(
  category,
  productSnapshot: tutorialV2Product(
    category: productCategory ?? category,
    productId: productId,
    productName: productName,
    colorLabel: colorLabel,
  ),
);

TutorialV2Plan _kitPlan(
  List<TutorialV2StepDraft> makeupDrafts, {
  Set<String> ownedProductIds = const {'product-1', 'product-2'},
}) => TutorialV2Plan.fromDrafts(
  context: tutorialV2Context(sourceMode: TutorialV2SourceMode.makeupKit),
  drafts: [...makeupDrafts, tutorialV2Draft(TutorialV2Category.finalLook)],
  ownedProductIds: ownedProductIds,
);

Matcher _planValidationFailure(String fragment) => throwsA(
  isA<TutorialV2Failure>()
      .having(
        (failure) => failure.kind,
        'kind',
        TutorialV2FailureKind.planValidation,
      )
      .having((failure) => failure.message, 'message', contains(fragment)),
);

void main() {
  group('Kit mode product rules', () {
    test('accepts steps backed by owned products', () {
      final plan = _kitPlan([
        _kitDraft(TutorialV2Category.foundation),
        _kitDraft(TutorialV2Category.blush, productId: 'product-2'),
      ]);

      expect(plan.totalSteps, 3);
      expect(plan.stepAt(0).productSnapshot?.productId, 'product-1');
      expect(plan.stepAt(1).productSnapshot?.productId, 'product-2');
    });

    test('rejects a product the user does not own', () {
      expect(
        () => _kitPlan([
          _kitDraft(TutorialV2Category.blush, productId: 'not-owned'),
        ]),
        _planValidationFailure('a product the user does not own'),
      );
    });

    test('rejects a Kit step with no product at all', () {
      expect(
        () => _kitPlan([tutorialV2Draft(TutorialV2Category.blush)]),
        _planValidationFailure('requires an owned product in Kit mode'),
      );
    });

    test('rejects a product whose category differs from the step', () {
      expect(
        () => _kitPlan([
          _kitDraft(
            TutorialV2Category.blush,
            productCategory: TutorialV2Category.lipstick,
          ),
        ]),
        _planValidationFailure('has a lipstick product attached'),
      );
    });

    test('rejects a product attached to the Final Look step', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(
            sourceMode: TutorialV2SourceMode.makeupKit,
          ),
          drafts: [
            _kitDraft(TutorialV2Category.blush),
            _kitDraft(TutorialV2Category.finalLook),
          ],
          ownedProductIds: const {'product-1'},
        ),
        _planValidationFailure('must not carry a product'),
      );
    });

    test('an empty kit cannot produce a tutorial', () {
      expect(
        () => _kitPlan(
          [_kitDraft(TutorialV2Category.blush)],
          ownedProductIds: const {},
        ),
        _planValidationFailure('a product the user does not own'),
      );
    });

    test('an incomplete kit is valid — uncovered categories are omitted', () {
      final plan = _kitPlan([
        _kitDraft(TutorialV2Category.lipstick),
      ], ownedProductIds: const {'product-1'});

      expect(plan.plannedCategories, [TutorialV2Category.lipstick]);
      expect(plan.totalSteps, 2);
    });

    test('an optional product name may be absent', () {
      expect(
        () => _kitPlan([_kitDraft(TutorialV2Category.blush)]),
        returnsNormally,
      );
    });

    test('rejects a blank product name rather than storing it', () {
      expect(
        () => _kitPlan([
          _kitDraft(TutorialV2Category.blush, productName: '  '),
        ]),
        _planValidationFailure('blank product name'),
      );
    });

    test('rejects a blank shade name rather than storing it', () {
      expect(
        () => _kitPlan([_kitDraft(TutorialV2Category.blush, colorLabel: '')]),
        _planValidationFailure('blank shade name'),
      );
    });

    test('the snapshot survives as persisted point-in-time data', () {
      final plan = _kitPlan([
        _kitDraft(
          TutorialV2Category.lipstick,
          productName: 'Studio Matte',
          colorLabel: 'Rosewood',
        ),
      ]);
      final snapshot = plan.stepAt(0).productSnapshot!;

      expect(snapshot.productName, 'Studio Matte');
      expect(snapshot.shadeName, 'Rosewood');
      expect(snapshot.color.value, '#B86F72');
    });
  });

  group('standard mode product rules', () {
    test('rejects a Kit product smuggled into a standard tutorial', () {
      expect(
        () => TutorialV2Plan.fromDrafts(
          context: tutorialV2Context(),
          drafts: [
            _kitDraft(TutorialV2Category.blush),
            tutorialV2Draft(TutorialV2Category.finalLook),
          ],
          ownedProductIds: const {'product-1'},
        ),
        _planValidationFailure('must not carry a Kit product in standard mode'),
      );
    });

    test('standard steps carry no product snapshot', () {
      final plan = TutorialV2Plan.fromDrafts(
        context: tutorialV2Context(),
        drafts: tutorialV2Drafts([TutorialV2Category.blush]),
      );

      expect(plan.stepAt(0).productSnapshot, isNull);
    });
  });

  group('category mapping', () {
    test('every Kit category maps onto a tutorial category', () {
      for (final category in MakeupKitCategory.values) {
        expect(
          TutorialV2Category.fromKitCategory(category),
          isNotNull,
          reason: '${category.code} has no tutorial counterpart',
        );
      }
    });

    test('the mapping preserves the code', () {
      for (final category in MakeupKitCategory.values) {
        expect(
          TutorialV2Category.fromKitCategory(category)!.code,
          category.code,
        );
      }
    });

    test('Final Look has no Kit counterpart', () {
      expect(
        MakeupKitCategory.fromCode(TutorialV2Category.finalLook.code),
        isNull,
      );
    });
  });
}
