import 'dart:convert';
import 'dart:io';

import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_color_model.dart';
import 'package:facetune/features/custom_palette/domain/validation/custom_palette_contract.dart';
import 'package:facetune/features/custom_palette/presentation/controllers/custom_palette_look_controller.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/custom_palette_fixture.dart';

const _vectorsPath = 'supabase/functions/_shared/custom_palette_vectors.json';

List<Map<String, dynamic>> _vectors() =>
    (jsonDecode(File(_vectorsPath).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();

CustomPaletteSelectionInput _input(
  String category, {
  String? finish = 'matte',
  String? base = '#C8102E',
  String? adjusted = '#D93A52',
  String? label = 'Red',
}) => CustomPaletteSelectionInput(
  categoryCode: category,
  baseColorValue: base,
  adjustedColorValue: adjusted,
  colorLabel: label,
  finishCode: finish,
);

List<String> _codes(List<CustomPaletteSelectionInput> selections) =>
    CustomPaletteValidator.validate(
      selections,
    ).map((issue) => issue.code.code).toList();

void main() {
  group('the approved matrix', () {
    test('is exactly 4 categories and 15 category and finish pairs', () {
      final pairs = CustomPaletteCatalog.categories.expand(
        (category) => CustomPaletteCatalog.finishesFor(
          category,
        ).map((finish) => '${category.code}/${finish.code}'),
      );
      expect(pairs.toSet(), {
        'blush/matte',
        'blush/satin',
        'blush/shimmer',
        'eyeshadow/matte',
        'eyeshadow/satin',
        'eyeshadow/shimmer',
        'eyeshadow/metallic',
        'eyeshadow/glitter',
        'eyeliner/matte',
        'eyeliner/satin',
        'eyeliner/glossy',
        'lipstick/matte',
        'lipstick/satin',
        'lipstick/cream',
        'lipstick/glossy',
      });
    });

    test('every approved pair passes the client contract', () {
      for (final category in CustomPaletteCatalog.categories) {
        for (final finish in CustomPaletteCatalog.finishesFor(category)) {
          expect(
            _codes([_input(category.code, finish: finish.code)]),
            isEmpty,
            reason: '${category.code}/${finish.code}',
          );
        }
      }
    });

    test('every forbidden pair is refused with the server code', () {
      var refused = 0;
      for (final category in CustomPaletteCatalog.categories) {
        final allowed = CustomPaletteCatalog.finishesFor(category);
        for (final finish in MakeupKitFinish.values) {
          if (allowed.contains(finish)) continue;
          expect(
            _codes([_input(category.code, finish: finish.code)]),
            ['finish_not_applicable'],
            reason: '${category.code}/${finish.code}',
          );
          refused += 1;
        }
      }
      expect(refused, 4 * MakeupKitFinish.values.length - 15);
    });

    test('every category combination passes, in canonical order', () {
      final categories = CustomPaletteCatalog.categories;
      for (var mask = 1; mask < 1 << categories.length; mask += 1) {
        final chosen = [
          for (var i = 0; i < categories.length; i += 1)
            if (mask & (1 << i) != 0) categories[i].code,
        ];
        final inputs = chosen.reversed.map(_input).toList();
        expect(_codes(inputs), isEmpty, reason: '$chosen');
        expect(
          CustomPaletteValidator.canonicalOrder(
            inputs,
          ).map((input) => input.categoryCode),
          chosen,
        );
      }
    });
  });

  group('the color controls', () {
    test('the real adjuster produces every shared vector exactly', () {
      final vectors = _vectors();
      expect(vectors, hasLength(CustomPaletteCatalog.swatches.length * 6));
      for (final vector in vectors) {
        final adjusted = CustomPaletteColorModel.adjust(
          NormalizedHexColor.parse(vector['base'] as String),
          saturation: vector['saturation'] as int,
          lightness: vector['lightness'] as int,
        );
        expect(
          adjusted.value,
          vector['adjusted'],
          reason: '${vector['base']} ${vector['control']}',
        );
      }
    });

    test('every vector on every category passes the client contract', () {
      for (final vector in _vectors()) {
        for (final category in CustomPaletteCatalog.categories) {
          expect(
            _codes([
              _input(
                category.code,
                base: vector['base'] as String,
                adjusted: vector['adjusted'] as String,
                label: vector['label'] as String,
              ),
            ]),
            isEmpty,
            reason: '${category.code} ${vector['base']} ${vector['control']}',
          );
        }
      }
    });

    test('every saturation and lightness the sliders hold stays canonical', () {
      final canonical = RegExp(r'^#[0-9A-F]{6}$');
      for (final swatch in CustomPaletteCatalog.swatches) {
        final base = swatch.color;
        for (var saturation = 0; saturation <= 100; saturation += 5) {
          for (var lightness = 0; lightness <= 100; lightness += 5) {
            final adjusted = CustomPaletteColorModel.adjust(
              base,
              saturation: saturation,
              lightness: lightness,
            );
            expect(canonical.hasMatch(adjusted.value), isTrue);
          }
        }
      }
    });
  });

  group('refused payloads use the same codes as the server', () {
    test('invalid colors', () {
      for (final color in [
        '#c8102e',
        'C8102E',
        '#C8102',
        'red',
        '',
        ' #C8102E',
      ]) {
        expect(_codes([_input('blush', adjusted: color)]), ['invalid_color']);
        expect(_codes([_input('blush', base: color)]), ['invalid_color']);
      }
    });

    test('a missing value is incomplete', () {
      expect(_codes([_input('blush', finish: null)]), ['selection_incomplete']);
      expect(_codes([_input('blush', adjusted: null)]), [
        'selection_incomplete',
      ]);
      expect(_codes([_input('blush', base: null)]), ['selection_incomplete']);
    });

    test('a base or label outside the catalog', () {
      expect(_codes([_input('blush', base: '#123456')]), [
        'invalid_base_color',
      ]);
      expect(_codes([_input('blush', label: 'Crimson')]), [
        'invalid_base_color',
      ]);
    });

    test('an unknown finish and an unsupported category', () {
      expect(_codes([_input('blush', finish: 'sparkle')]), [
        'unsupported_finish',
      ]);
      for (final category in ['foundation', 'concealer', 'lips', 'BLUSH', '']) {
        expect(_codes([_input(category)]), ['unsupported_category']);
      }
    });

    test('a duplicate category and an empty palette', () {
      expect(_codes([_input('blush'), _input('blush', finish: 'satin')]), [
        'duplicate_category',
      ]);
      expect(_codes([]), ['palette_empty']);
    });
  });

  group('double tap and retry', () {
    CustomPaletteLookController controller(FakePaletteGateway gateway) {
      var issued = 0;
      return CustomPaletteLookController(
        gateway,
        newOperationId: () => 'operation-${++issued}',
        replayDelay: Duration.zero,
        maximumReplays: 2,
      );
    }

    test(
      'a double tap on Generate Another Variation is one operation',
      () async {
        final gateway = FakePaletteGateway();
        final look = controller(gateway);
        addTearDown(look.dispose);
        await look.start(paletteRecommendation());

        await Future.wait([look.generateVariation(), look.generateVariation()]);

        expect(gateway.operations, ['operation-1', 'operation-2']);
      },
    );

    test('a double start is one operation', () async {
      final gateway = FakePaletteGateway();
      final look = controller(gateway);
      addTearDown(look.dispose);
      final recommendation = paletteRecommendation();

      await Future.wait([
        look.start(recommendation),
        look.start(recommendation),
      ]);

      expect(gateway.operations, ['operation-1']);
    });
  });

  group('the client holds no server authority', () {
    final sources = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    test('no provider host, provider key, or service role in client code', () {
      for (final file in sources) {
        final text = file.readAsStringSync();
        for (final forbidden in [
          'generativelanguage',
          'GEMINI_API_KEY',
          'SERVICE_ROLE',
          'service_role',
        ]) {
          expect(text, isNot(contains(forbidden)), reason: file.path);
        }
      }
    });

    test('the palette feature never logs', () {
      for (final file in sources.where(
        (file) => file.path.replaceAll(r'\', '/').contains('/custom_palette/'),
      )) {
        expect(
          file.readAsStringSync(),
          isNot(matches(RegExp(r'\b(debugPrint|print|log)\('))),
          reason: file.path,
        );
      }
    });

    test('the only table the client writes is saved looks', () {
      final source = File(
        'lib/features/custom_palette/data/custom_palette_remote_data_source.dart',
      ).readAsStringSync();
      final writes = RegExp(
        r'from\((\w+)\)\s*\.(insert|update|upsert|delete)\(',
      ).allMatches(source).map((match) => match.group(1)).toSet();
      expect(writes, {'_saved'});
      expect(source, contains("_saved = 'custom_palette_saved_looks'"));
    });
  });
}
