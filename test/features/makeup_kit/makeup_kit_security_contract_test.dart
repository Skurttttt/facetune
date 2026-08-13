import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  test('kit Edge Functions require gateway JWT verification', () {
    final config = source('supabase/config.toml');

    for (final functionName in [
      'generate-kit-makeup-recommendation',
      'generate-kit-makeup-preview',
    ]) {
      expect(
        config,
        contains('[$functionName]'.replaceFirst('[', '[functions.')),
      );
    }
    expect(
      RegExp(
        r'\[functions\.generate-kit-makeup-recommendation\]\s+verify_jwt\s*=\s*true',
      ).hasMatch(config),
      isTrue,
    );
    expect(
      RegExp(
        r'\[functions\.generate-kit-makeup-preview\]\s+verify_jwt\s*=\s*true',
      ).hasMatch(config),
      isTrue,
    );
  });

  test('kit tables retain owner-scoped RLS and deny anonymous access', () {
    final migrations = [
      source('supabase/migrations/20260813000100_makeup_kit_products.sql'),
      source(
        'supabase/migrations/20260813000200_kit_makeup_recommendations.sql',
      ),
      source('supabase/migrations/20260813000300_kit_generated_images.sql'),
      source('supabase/migrations/20260814000100_kit_saved_looks.sql'),
    ].join('\n');

    for (final table in [
      'makeup_kit_products',
      'kit_makeup_recommendations',
      'kit_generated_images',
      'kit_saved_looks',
    ]) {
      expect(
        migrations,
        contains('alter table public.$table enable row level security'),
      );
      expect(
        migrations,
        contains('revoke all on table public.$table from anon'),
      );
    }
    expect(
      RegExp(r'auth\.uid\(\)\) = user_id').allMatches(migrations).length,
      greaterThanOrEqualTo(12),
    );
  });

  test('Edge Functions authenticate and derive ownership server-side', () {
    final recommendation = source(
      'supabase/functions/generate-kit-makeup-recommendation/index.ts',
    );
    final preview = source(
      'supabase/functions/generate-kit-makeup-preview/index.ts',
    );

    for (final edgeFunction in [recommendation, preview]) {
      expect(RegExp(r'auth\s*\.getUser\(\)').hasMatch(edgeFunction), isTrue);
      expect(edgeFunction, contains('authData.user.id'));
      expect(edgeFunction, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(edgeFunction, isNot(contains('body.userId')));
      expect(edgeFunction, isNot(contains('body.user_id')));
    }
    expect(recommendation, contains('product.user_id !== authData.user.id'));
    expect(preview, contains('isOwnedOriginalPath'));
  });

  test('client bundle contains no Gemini endpoint or secret key reference', () {
    final dartSources = root
        .listSync(recursive: true)
        .whereType<File>()
        .where(
          (file) =>
              file.path.contains(
                '${Platform.pathSeparator}lib${Platform.pathSeparator}',
              ) &&
              file.path.endsWith('.dart'),
        )
        .map((file) => file.readAsStringSync())
        .join('\n');

    expect(dartSources, isNot(contains('GEMINI_API_KEY')));
    expect(dartSources, isNot(contains('generativelanguage.googleapis.com')));
    expect(dartSources, isNot(contains('x-goog-api-key')));
  });

  test('database enforces the category-specific finish catalog', () {
    final migration = source(
      'supabase/migrations/20260814000200_makeup_kit_hardening.sql',
    );

    expect(migration, contains('makeup_kit_products_category_finish_valid'));
    expect(migration, contains("category = 'foundation'"));
    expect(migration, contains("category = 'eyeliner'"));
  });
}
