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
  // The migration that defines the current (v2) palette validity rules.
  final migration = File(
    'supabase/migrations/20261120000100_ccp_category_parity.sql',
  ).readAsStringSync();
  // The original migration, which created the v1 rules and still governs the
  // rows written under them.
  final legacyMigration = File(
    'supabase/migrations/20261008000100_ccp_palette_lineage.sql',
  ).readAsStringSync();

  test('identifiers agree', () {
    expect(contract, contains('"$customColorPaletteSourceMode"'));
    expect(contract, contains('"$customColorPaletteContractVersion"'));
    expect(contract, contains('"$customColorPaletteLegacyContractVersion"'));
    expect(migration, contains("'$customColorPaletteContractVersion'"));
    expect(migration, contains("'$customColorPaletteLegacyContractVersion'"));
    expect(
      legacyMigration,
      contains("'$customColorPaletteLegacyContractVersion'"),
    );
    expect(customColorPaletteReadableContractVersions, {
      'custom_color_palette_contract_v1',
      'custom_color_palette_contract_v2',
    });
  });

  test('every swatch agrees across Dart, TypeScript and SQL, per category', () {
    var total = 0;
    final seen = <String>{};
    for (final category in CustomPaletteCatalog.categories) {
      for (final swatch in CustomPaletteCatalog.swatchesFor(category)) {
        // Each (category list, hex) pair is counted once: the shared list is
        // used by five categories but written once on each side.
        if (!seen.add(
          '${CustomPaletteCatalog.usesCuratedShades(category) ? category.code : 'shared'}'
          '|${swatch.hex}',
        )) {
          continue;
        }
        total += 1;
        expect(
          contract,
          contains('"${swatch.hex}": "${swatch.label}"'),
          reason: '${category.code} ${swatch.label}',
        );
        expect(
          migration,
          contains("when '${swatch.hex}' then '${swatch.label}'"),
          reason: '${category.code} ${swatch.label}',
        );
      }
    }
    expect(total, 24 + 6 + 5 + 3 + 4 + 4);
    expect(RegExp(r'"#[0-9A-F]{6}": "').allMatches(contract), hasLength(total));
    expect(
      RegExp(r"when '#[0-9A-F]{6}' then '").allMatches(migration),
      hasLength(total),
    );
  });

  test('the v1 migration still holds only the original rules', () {
    // Rows written under v1 were checked by these rules; they must not change.
    expect(
      RegExp(r"when '#[0-9A-F]{6}' then '").allMatches(legacyMigration),
      hasLength(CustomPaletteCatalog.swatches.length),
    );
    expect(legacyMigration, contains('not between 1 and 4'));
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

  test('the functions are JWT-protected and hold no service key at entry', () {
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
  });
}
