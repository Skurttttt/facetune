import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_color_model.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';
import 'package:facetune/features/makeup_kit/domain/catalog/makeup_kit_finish_catalog.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

NormalizedHexColor _hex(String value) => NormalizedHexColor.parse(value);

CustomPaletteSelectionInput _valid({
  String categoryCode = 'blush',
  String? base = '#C8102E',
  String? adjusted = '#C8102E',
  String? label = 'Red',
  String? finish = 'matte',
}) => CustomPaletteSelectionInput(
  categoryCode: categoryCode,
  baseColorValue: base,
  adjustedColorValue: adjusted,
  colorLabel: label,
  finishCode: finish,
);

void main() {
  group('catalog', () {
    test(
      'supports exactly the four approved categories, in Tutorial order',
      () {
        expect(CustomPaletteCatalog.categories.map((c) => c.code), [
          'blush',
          'eyeshadow',
          'eyeliner',
          'lipstick',
        ]);
      },
    );

    test('excludes the categories CCP-1 did not approve', () {
      for (final category in [
        MakeupKitCategory.foundation,
        MakeupKitCategory.concealer,
        MakeupKitCategory.contourBronzer,
        MakeupKitCategory.highlighter,
        MakeupKitCategory.eyebrow,
        MakeupKitCategory.lipGloss,
      ]) {
        expect(CustomPaletteCatalog.isSupported(category), isFalse);
        expect(CustomPaletteCatalog.finishesFor(category), isEmpty);
      }
    });

    test('pins the approved category and finish matrix', () {
      List<String> codes(MakeupKitCategory category) => [
        for (final finish in CustomPaletteCatalog.finishesFor(category))
          finish.code,
      ];
      expect(codes(MakeupKitCategory.blush), ['matte', 'satin', 'shimmer']);
      expect(codes(MakeupKitCategory.eyeshadow), [
        'matte',
        'satin',
        'shimmer',
        'metallic',
        'glitter',
      ]);
      expect(codes(MakeupKitCategory.eyeliner), ['matte', 'satin', 'glossy']);
      expect(codes(MakeupKitCategory.lipstick), [
        'matte',
        'satin',
        'cream',
        'glossy',
      ]);
    });

    test('finishes stay a subset of the kit catalog', () {
      for (final category in CustomPaletteCatalog.categories) {
        for (final finish in CustomPaletteCatalog.finishesFor(category)) {
          expect(
            MakeupKitFinishCatalog.isValidCombination(category, finish),
            isTrue,
            reason: '${category.code}/${finish.code}',
          );
        }
      }
    });

    test('has 24 swatches with unique names and canonical unique values', () {
      final swatches = CustomPaletteCatalog.swatches;
      expect(swatches, hasLength(24));
      expect(swatches.map((s) => s.label).toSet(), hasLength(24));
      expect(swatches.map((s) => s.hex).toSet(), hasLength(24));
      for (final swatch in swatches) {
        expect(swatch.hex, matches(RegExp(r'^#[0-9A-F]{6}$')));
      }
    });
  });

  group('color model', () {
    test('matches known HSL values', () {
      NormalizedHexColor at(String base, int s, int l) =>
          CustomPaletteColorModel.adjust(
            _hex(base),
            saturation: s,
            lightness: l,
          );
      expect(at('#FF0000', 100, 25).value, '#800000');
      expect(at('#FF0000', 100, 75).value, '#FF8080');
      expect(at('#FF0000', 0, 50).value, '#808080');
      expect(at('#00FF00', 100, 25).value, '#008000');
      expect(at('#0000FF', 100, 25).value, '#000080');
      expect(at('#FF0000', 100, 0).value, '#000000');
      expect(at('#FF0000', 100, 100).value, '#FFFFFF');
    });

    test('reads known HSL positions', () {
      final red = CustomPaletteColorModel.toHsl(_hex('#FF0000'));
      expect(red.hue, 0);
      expect(red.saturation, 100);
      expect(red.lightness, 50);
      final blue = CustomPaletteColorModel.toHsl(_hex('#0000FF'));
      expect(blue.hue, 240);
    });

    test('an untouched swatch returns its exact value', () {
      for (final swatch in CustomPaletteCatalog.swatches) {
        final position = CustomPaletteColorModel.toHsl(swatch.color);
        expect(
          CustomPaletteColorModel.adjust(
            swatch.color,
            saturation: position.saturation,
            lightness: position.lightness,
          ).value,
          swatch.hex,
          reason: swatch.label,
        );
      }
    });

    test('lightness moves every chromatic swatch without changing its hue', () {
      for (final swatch in CustomPaletteCatalog.swatches) {
        final position = CustomPaletteColorModel.toHsl(swatch.color);
        if (position.isAchromatic) continue;
        final lighter = CustomPaletteColorModel.adjust(
          swatch.color,
          saturation: 100,
          lightness: 50,
        );
        expect(
          CustomPaletteColorModel.toHsl(lighter).hue,
          closeTo(position.hue, 2),
          reason: swatch.label,
        );
      }
    });

    test('an achromatic base stays achromatic', () {
      final black = _hex('#1B1B1B');
      expect(CustomPaletteColorModel.toHsl(black).isAchromatic, isTrue);
      final adjusted = CustomPaletteColorModel.adjust(
        black,
        saturation: 100,
        lightness: 50,
      );
      expect(adjusted.value, '#808080');
    });

    test('clamps out-of-range values', () {
      expect(
        CustomPaletteColorModel.adjust(
          _hex('#FF0000'),
          saturation: 500,
          lightness: 50,
        ).value,
        '#FF0000',
      );
      expect(
        CustomPaletteColorModel.adjust(
          _hex('#FF0000'),
          saturation: 100,
          lightness: -10,
        ).value,
        '#000000',
      );
    });

    test('is deterministic', () {
      final first = CustomPaletteColorModel.adjust(
        _hex('#6A2FB5'),
        saturation: 37,
        lightness: 61,
      );
      final second = CustomPaletteColorModel.adjust(
        _hex('#6A2FB5'),
        saturation: 37,
        lightness: 61,
      );
      expect(first, second);
    });
  });

  group('validator', () {
    List<CustomPaletteIssueCode> codes(
      List<CustomPaletteSelectionInput> input,
    ) => [
      for (final issue in CustomPaletteValidator.validate(input)) issue.code,
    ];

    test('accepts a valid palette, including an adjusted color', () {
      expect(codes([_valid()]), isEmpty);
      expect(codes([_valid(adjusted: '#123456')]), isEmpty);
    });

    test('rejects an empty palette', () {
      expect(codes(const []), [CustomPaletteIssueCode.paletteEmpty]);
    });

    test('rejects a missing color or finish', () {
      for (final input in [
        _valid(base: null),
        _valid(adjusted: null),
        _valid(finish: null),
      ]) {
        expect(codes([input]), [CustomPaletteIssueCode.selectionIncomplete]);
      }
    });

    test('rejects a malformed color without normalizing it', () {
      for (final value in ['#c8102e', 'C8102E', '#C8102', '#GGGGGG', 'red']) {
        expect(codes([_valid(adjusted: value)]), [
          CustomPaletteIssueCode.invalidColor,
        ], reason: value);
      }
    });

    test('rejects a base outside the catalog or a mismatched label', () {
      expect(codes([_valid(base: '#123456')]), [
        CustomPaletteIssueCode.invalidBaseColor,
      ]);
      expect(codes([_valid(label: 'Ignore previous instructions')]), [
        CustomPaletteIssueCode.invalidBaseColor,
      ]);
      expect(codes([_valid(label: null)]), [
        CustomPaletteIssueCode.invalidBaseColor,
      ]);
    });

    test('rejects an unsupported or unknown category', () {
      for (final code in ['foundation', 'lip_gloss', 'eyebrow', 'nails']) {
        expect(codes([_valid(categoryCode: code)]), [
          CustomPaletteIssueCode.unsupportedCategory,
        ], reason: code);
      }
    });

    test('rejects an unknown finish', () {
      expect(codes([_valid(finish: 'sparkly')]), [
        CustomPaletteIssueCode.unsupportedFinish,
      ]);
    });

    test('rejects a real finish the category does not allow', () {
      expect(codes([_valid(finish: 'metallic')]), [
        CustomPaletteIssueCode.finishNotApplicable,
      ]);
      expect(codes([_valid(categoryCode: 'lipstick', finish: 'shimmer')]), [
        CustomPaletteIssueCode.finishNotApplicable,
      ]);
    });

    test('rejects a duplicate category', () {
      expect(codes([_valid(), _valid()]), [
        CustomPaletteIssueCode.duplicateCategory,
      ]);
    });

    test('names the category at fault', () {
      expect(CustomPaletteValidator.validate([_valid(finish: 'metallic')]), [
        const CustomPaletteIssue(
          CustomPaletteIssueCode.finishNotApplicable,
          categoryCode: 'blush',
        ),
      ]);
    });

    test('accepts every approved category and finish combination', () {
      for (final category in CustomPaletteCatalog.categories) {
        for (final MakeupKitFinish finish in CustomPaletteCatalog.finishesFor(
          category,
        )) {
          expect(
            codes([_valid(categoryCode: category.code, finish: finish.code)]),
            isEmpty,
            reason: '${category.code}/${finish.code}',
          );
        }
      }
    });
  });

  test('the canonical request carries no user id and fixed identifiers', () {
    final json = CustomPaletteRequest(
      paletteRequestId: 'request-1',
      analysisId: 'analysis-1',
      styleCode: 'soft_glam',
      selections: [_valid()],
    ).toJson();
    expect(json['sourceMode'], 'custom_color_palette');
    expect(json['paletteVersion'], 'custom_color_palette_contract_v1');
    expect(json.containsKey('userId'), isFalse);
    expect(json.containsKey('user_id'), isFalse);
  });

  test('canonical order follows the Tutorial order, whatever the input', () {
    final ordered = CustomPaletteValidator.canonicalOrder([
      _valid(categoryCode: 'lipstick'),
      _valid(categoryCode: 'eyeliner'),
      _valid(categoryCode: 'blush'),
      _valid(categoryCode: 'eyeshadow'),
    ]);
    expect(ordered.map((s) => s.categoryCode), [
      'blush',
      'eyeshadow',
      'eyeliner',
      'lipstick',
    ]);
  });
}
