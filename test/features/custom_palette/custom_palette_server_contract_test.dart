import 'dart:io';

import 'package:facetune/features/custom_palette/domain/catalog/custom_palette_catalog.dart';
import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// The palette contract exists in Dart, TypeScript and SQL. These tests read
/// the other two so a change to one cannot quietly disagree with the rest.
void main() {
  final contract = File(
    'supabase/functions/_shared/custom_palette_contract.ts',
  ).readAsStringSync();
  final migration = File(
    'supabase/migrations/20261008000100_ccp_palette_lineage.sql',
  ).readAsStringSync();

  test('identifiers agree', () {
    expect(contract, contains('"$customColorPaletteSourceMode"'));
    expect(contract, contains('"$customColorPaletteContractVersion"'));
    expect(migration, contains("'$customColorPaletteContractVersion'"));
  });

  test('every swatch agrees across Dart, TypeScript and SQL', () {
    for (final swatch in CustomPaletteCatalog.swatches) {
      expect(
        contract,
        contains('"${swatch.hex}": "${swatch.label}"'),
        reason: swatch.label,
      );
      expect(
        migration,
        contains("when '${swatch.hex}' then '${swatch.label}'"),
        reason: swatch.label,
      );
    }
    expect(
      RegExp(r'"#[0-9A-F]{6}": "').allMatches(contract),
      hasLength(CustomPaletteCatalog.swatches.length),
    );
    expect(
      RegExp(r"when '#[0-9A-F]{6}' then '").allMatches(migration),
      hasLength(CustomPaletteCatalog.swatches.length),
    );
  });

  test('every category and finish agrees across all three', () {
    for (final category in CustomPaletteCatalog.categories) {
      final finishes = CustomPaletteCatalog.finishesFor(
        category,
      ).map((finish) => finish.code).toList();
      final quotedTs = finishes.map((code) => '"$code"').join(', ');
      expect(
        contract,
        contains('${category.code}: [$quotedTs]'),
        reason: category.code,
      );
      final quotedSql = finishes.map((code) => "'$code'").join(', ');
      expect(
        migration.replaceAll(RegExp(r'\s+'), ' '),
        contains("when '${category.code}' then array[$quotedSql]"),
        reason: category.code,
      );
    }
    expect(
      RegExp(r'^\s+"(\w+)",$', multiLine: true)
          .allMatches(
            contract.substring(
              contract.indexOf('CUSTOM_PALETTE_CATEGORIES = ['),
              contract.indexOf('] as const'),
            ),
          )
          .map((match) => match.group(1)),
      CustomPaletteCatalog.categories.map((category) => category.code),
    );
  });

  test('every makeup style is accepted by the server', () {
    final block = contract.substring(
      contract.indexOf('CUSTOM_PALETTE_STYLES'),
      contract.indexOf(']);', contract.indexOf('CUSTOM_PALETTE_STYLES')),
    );
    for (final style in MakeupStyleCatalog.styles) {
      expect(block, contains('"${style.code}"'), reason: style.code);
    }
    expect(
      RegExp(r'^\s+"\w+",$', multiLine: true).allMatches(block),
      hasLength(MakeupStyleCatalog.styles.length),
    );
  });

  test('the function is JWT-protected and never reached from Flutter', () {
    final config = File('supabase/config.toml').readAsStringSync();
    expect(
      config.replaceAll('\r\n', '\n'),
      contains(
        '[functions.generate-custom-palette-recommendation]\n'
        'verify_jwt = true',
      ),
    );
    final index = File(
      'supabase/functions/generate-custom-palette-recommendation/index.ts',
    ).readAsStringSync();
    expect(index, isNot(contains('SERVICE_ROLE')));
    expect(
      config.replaceAll('\r\n', '\n'),
      contains(
        '[functions.generate-custom-palette-preview]\n'
        'verify_jwt = true',
      ),
    );
    expect(
      File(
        'supabase/functions/generate-custom-palette-preview/index.ts',
      ).readAsStringSync(),
      isNot(contains('SERVICE_ROLE')),
    );
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      expect(
        source,
        isNot(contains('generate-custom-palette-recommendation')),
        reason: file.path,
      );
      expect(
        source,
        isNot(contains('generate-custom-palette-preview')),
        reason: file.path,
      );
    }
  });
}
