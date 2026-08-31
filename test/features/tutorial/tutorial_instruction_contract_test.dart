import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/tutorial/domain/entities/look_product_snapshot.dart';
import 'package:facetune/features/tutorial/domain/entities/recommendation_source_mode.dart';
import 'package:facetune/features/tutorial/domain/entities/standard_look_entry.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_guide_type.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_instruction.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_shade_details.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_step_presentation.dart';
import 'package:facetune/features/tutorial/domain/entities/validated_look_plan.dart';
import 'package:facetune/features/tutorial/presentation/utils/tutorial_labels.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialInstructionStep step(
  int sequence, {
  TutorialGuideType guideType = TutorialGuideType.startAnchor,
  String shortTitle = 'Start',
  String instruction = 'Begin at the outer lash line.',
}) => TutorialInstructionStep(
  sequence: sequence,
  guideType: guideType,
  shortTitle: shortTitle,
  instruction: instruction,
);

StandardLookEntry standardEntry({
  String planKey = 'blush',
  String shadeName = 'Warm Rose',
  String? colorHex = '#B65A68',
  String finish = 'soft satin',
  String intensity = 'medium',
}) => StandardLookEntry(
  planKey: planKey,
  shadeName: shadeName,
  colorHex: colorHex,
  placement: 'Over the cheekbone.',
  technique: 'Blend upward toward the temple.',
  finish: finish,
  intensity: intensity,
);

LookProductSnapshotItem snapshotItem({
  String productId = 'p1',
  String category = 'blush',
  String colorHex = '#D98983',
  String finish = 'satin',
  String? productName = 'Example Blush',
  String? colorLabel = 'Rose',
}) => LookProductSnapshotItem.fromKitSnapshot(
  KitProductSnapshot(
    productId: productId,
    category: category,
    colorHex: colorHex,
    finish: finish,
    productName: productName,
    colorLabel: colorLabel,
  ),
);

ValidatedLookPlan standardPlan(List<StandardLookEntry> entries) =>
    ValidatedLookPlan(
      id: 'rec-1',
      analysisId: 'analysis-1',
      styleCode: 'soft_glam',
      source: StandardLookPlanSource(
        recommendationId: 'rec-1',
        entries: StandardLookEntries(
          byCategory: <TutorialCategory, List<StandardLookEntry>>{
            TutorialCategory.blush: entries,
          },
        ),
      ),
      modelId: 'model',
      promptVersion: 'makeup_recommendation_v2',
      createdAt: DateTime.utc(2026, 8, 31),
    );

ValidatedLookPlan kitPlan(List<LookProductSnapshotItem> items) =>
    ValidatedLookPlan(
      id: 'kit-rec-1',
      analysisId: 'analysis-1',
      styleCode: 'soft_glam',
      source: MyMakeupKitLookPlanSource(
        kitRecommendationId: 'kit-rec-1',
        productSnapshot: LookProductSnapshot(items: items),
      ),
      modelId: 'model',
      promptVersion: 'kit_makeup_recommendation_v1',
      createdAt: DateTime.utc(2026, 8, 31),
    );

void main() {
  group('guide vocabulary is controlled', () {
    test('it holds exactly the four supported guide meanings', () {
      expect(TutorialGuideType.values, hasLength(4));
      expect(
        TutorialGuideType.values.map((type) => type.code),
        containsAll(<String>[
          'start_anchor',
          'placement_boundary',
          'blend_zone',
          'direction',
        ]),
      );
    });

    test('every guide type has a distinct code, symbol, and name', () {
      final codes = TutorialGuideType.values.map((type) => type.code).toSet();
      final symbols = TutorialGuideType.values
          .map((type) => type.symbol)
          .toSet();
      final names = TutorialGuideType.values
          .map(TutorialLabels.guideTypeName)
          .toSet();

      expect(codes, hasLength(TutorialGuideType.values.length));
      expect(symbols, hasLength(TutorialGuideType.values.length));
      expect(names, hasLength(TutorialGuideType.values.length));
    });

    test('an invalid guide type is rejected rather than coerced', () {
      expect(
        TutorialGuideType.fromCode('start_anchor'),
        TutorialGuideType.startAnchor,
      );
      expect(TutorialGuideType.fromCode('sparkle_burst'), isNull);
      expect(TutorialGuideType.fromCode(''), isNull);
      expect(TutorialGuideType.fromCode('START_ANCHOR'), isNull);
    });

    test('the key order is the order makeup is applied in', () {
      expect(TutorialGuideType.orderedVocabulary, <TutorialGuideType>[
        TutorialGuideType.startAnchor,
        TutorialGuideType.placementBoundary,
        TutorialGuideType.blendZone,
        TutorialGuideType.direction,
      ]);
    });
  });

  group('instruction sequencing', () {
    test('two, three, and four instructions are all representable', () {
      for (final count in <int>[2, 3, 4]) {
        final sequence = TutorialInstructionSequence.from(
          <TutorialInstructionStep>[
            for (var index = 1; index <= count; index += 1) step(index),
          ],
        );
        expect(sequence.length, count);
        expect(sequence.matchesAuthoringGuidance, isTrue);
      }
    });

    test(
      'a single instruction is representable but flagged as off-guidance',
      () {
        final sequence = TutorialInstructionSequence.from(
          <TutorialInstructionStep>[step(1)],
        );
        expect(sequence.length, 1);
        expect(sequence.matchesAuthoringGuidance, isFalse);
      },
    );

    test('an empty sequence is a valid, truthful state', () {
      expect(TutorialInstructionSequence.empty.isEmpty, isTrue);
      expect(
        TutorialInstructionSequence.from(
          const <TutorialInstructionStep>[],
        ).isEmpty,
        isTrue,
      );
    });

    test('more than four instructions is rejected', () {
      expect(
        () => TutorialInstructionSequence.from(<TutorialInstructionStep>[
          for (var index = 1; index <= 5; index += 1) step(index),
        ]),
        throwsArgumentError,
      );
    });

    test('a gap in the numbering is rejected', () {
      expect(
        () => TutorialInstructionSequence.from(<TutorialInstructionStep>[
          step(1),
          step(3),
        ]),
        throwsArgumentError,
      );
    });

    test('out-of-order numbering is rejected', () {
      expect(
        () => TutorialInstructionSequence.from(<TutorialInstructionStep>[
          step(2),
          step(1),
        ]),
        throwsArgumentError,
      );
    });

    test('numbering that does not start at one is rejected', () {
      expect(
        () => TutorialInstructionSequence.from(<TutorialInstructionStep>[
          step(0),
          step(1),
        ]),
        throwsArgumentError,
      );
    });

    test('the ordered steps are preserved and unmodifiable', () {
      final sequence = TutorialInstructionSequence.from(
        <TutorialInstructionStep>[
          step(1, shortTitle: 'Start'),
          step(2, shortTitle: 'Blend'),
        ],
      );
      expect(sequence.steps.map((item) => item.shortTitle), <String>[
        'Start',
        'Blend',
      ]);
      expect(() => sequence.steps.add(step(3)), throwsUnsupportedError);
    });

    test('only the guide types actually used are reported, in key order', () {
      final sequence =
          TutorialInstructionSequence.from(<TutorialInstructionStep>[
            step(1, guideType: TutorialGuideType.direction),
            step(2, guideType: TutorialGuideType.startAnchor),
            step(3, guideType: TutorialGuideType.direction),
          ]);

      expect(sequence.referencedGuideTypes, <TutorialGuideType>[
        TutorialGuideType.startAnchor,
        TutorialGuideType.direction,
      ]);
    });
  });

  group('shade details from Standard Mode', () {
    test('it carries shade, hex, finish, and intensity across', () {
      final details = TutorialShadeDetails.fromStandardEntry(standardEntry());

      expect(details.shadeName, 'Warm Rose');
      expect(details.color?.value, '#B65A68');
      expect(details.finish, isA<DescribedFinish>());
      expect((details.finish! as DescribedFinish).description, 'soft satin');
      expect(details.intensity, TutorialIntensity.medium);
      expect(details.hasAnyDetail, isTrue);
    });

    test('a category with no colour keeps a null hex', () {
      final details = TutorialShadeDetails.fromStandardEntry(
        standardEntry(colorHex: null),
      );
      expect(details.color, isNull);
      expect(details.shadeName, 'Warm Rose');
    });

    test('a malformed hex becomes null rather than a substituted colour', () {
      final details = TutorialShadeDetails.fromStandardEntry(
        standardEntry(colorHex: 'not-a-colour'),
      );
      expect(details.color, isNull);
    });

    test('a blank finish is absent, not an empty row', () {
      final details = TutorialShadeDetails.fromStandardEntry(
        standardEntry(finish: '   '),
      );
      expect(details.finish, isNull);
    });

    test('every validated upstream intensity maps', () {
      expect(TutorialIntensity.fromCode('sheer'), TutorialIntensity.sheer);
      expect(TutorialIntensity.fromCode('soft'), TutorialIntensity.soft);
      expect(TutorialIntensity.fromCode('medium'), TutorialIntensity.medium);
      expect(TutorialIntensity.fromCode('bold'), TutorialIntensity.bold);
    });

    test('an unknown or missing intensity is absent, never guessed', () {
      expect(TutorialIntensity.fromCode(null), isNull);
      expect(TutorialIntensity.fromCode(''), isNull);
      expect(TutorialIntensity.fromCode('very bold indeed'), isNull);
      expect(
        TutorialShadeDetails.fromStandardEntry(
          standardEntry(intensity: 'luminous'),
        ).intensity,
        isNull,
      );
    });
  });

  group('shade details from a My Makeup Kit snapshot', () {
    test('it reads colour and finish from the immutable snapshot', () {
      final details = TutorialShadeDetails.fromSnapshotItem(snapshotItem());

      expect(details.shadeName, 'Rose');
      expect(details.color?.value, '#D98983');
      expect(details.finish, isA<ControlledFinish>());
      expect(
        (details.finish! as ControlledFinish).finish,
        MakeupKitFinish.satin,
      );
    });

    test(
      'an unlabelled product shows no shade name rather than an invented one',
      () {
        final details = TutorialShadeDetails.fromSnapshotItem(
          snapshotItem(colorLabel: null),
        );
        expect(details.shadeName, isNull);
      },
    );

    test('a kit shade has no intensity, because the kit records none', () {
      expect(
        TutorialShadeDetails.fromSnapshotItem(snapshotItem()).intensity,
        isNull,
      );
    });
  });

  group('product presentation source', () {
    test('Standard Mode presents brand-neutral shades only', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        standardPlan(<StandardLookEntry>[standardEntry()]),
        TutorialCategory.blush,
      );

      final product = presentation.product;
      expect(product, isA<StandardShadePresentation>());
      expect(product.sourceMode, RecommendationSourceMode.standard);
      expect(product.shades, hasLength(1));
      expect(product.shades.single.shadeName, 'Warm Rose');
      // The Standard Mode presentation carries no product identity at all —
      // there is no field a brand could occupy.
      expect(
        (product as StandardShadePresentation).entries.single.shadeName,
        'Warm Rose',
      );
    });

    test('My Makeup Kit presents the snapshot products, including names', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        kitPlan(<LookProductSnapshotItem>[snapshotItem()]),
        TutorialCategory.blush,
      );

      final product = presentation.product;
      expect(product, isA<MyMakeupKitProductPresentation>());
      expect(product.sourceMode, RecommendationSourceMode.myMakeupKit);
      expect(
        (product as MyMakeupKitProductPresentation).items.single.productName,
        'Example Blush',
      );
      expect(product.shades.single.color?.value, '#D98983');
    });

    test('one category can present two contributing products', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        kitPlan(<LookProductSnapshotItem>[
          snapshotItem(productId: 'p1', category: 'lipstick', finish: 'cream'),
          snapshotItem(
            productId: 'p2',
            category: 'lip_gloss',
            finish: 'glossy',
          ),
        ]),
        TutorialCategory.lips,
      );

      expect(presentation.product.shades, hasLength(2));
    });

    test('a category the plan says nothing about presents as empty', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        standardPlan(<StandardLookEntry>[standardEntry()]),
        TutorialCategory.eyeliner,
      );

      expect(presentation.product.isEmpty, isTrue);
      expect(presentation.product.shades, isEmpty);
    });

    test('a kit plan never exposes Standard Mode entries, and the reverse', () {
      final kit = TutorialStepPresentation.fromLookPlan(
        kitPlan(<LookProductSnapshotItem>[snapshotItem()]),
        TutorialCategory.blush,
      );
      final standard = TutorialStepPresentation.fromLookPlan(
        standardPlan(<StandardLookEntry>[standardEntry()]),
        TutorialCategory.blush,
      );

      expect(kit.product, isNot(isA<StandardShadePresentation>()));
      expect(standard.product, isNot(isA<MyMakeupKitProductPresentation>()));
    });
  });

  group('step presentation shell', () {
    test('an unauthored step states no goal and no instructions', () {
      final presentation = TutorialStepPresentation.fromLookPlan(
        standardPlan(<StandardLookEntry>[standardEntry()]),
        TutorialCategory.blush,
      );

      expect(presentation.goal, isNull);
      expect(presentation.instructions.isEmpty, isTrue);
    });

    test(
      'a goal and instructions attach without touching the product data',
      () {
        final presentation = TutorialStepPresentation.fromLookPlan(
          standardPlan(<StandardLookEntry>[standardEntry()]),
          TutorialCategory.blush,
          goal: 'Lifted rose blush concentrated toward the outer cheek.',
          instructions: TutorialInstructionSequence.from(
            <TutorialInstructionStep>[
              step(1),
              step(2, guideType: TutorialGuideType.direction),
            ],
          ),
        );

        expect(presentation.goal, isNotNull);
        expect(presentation.instructions.length, 2);
        expect(presentation.category, TutorialCategory.blush);
        expect(presentation.sourceMode, RecommendationSourceMode.standard);
        expect(presentation.product.shades, hasLength(1));
      },
    );
  });
}
