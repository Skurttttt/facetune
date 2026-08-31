import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the two recommendation Edge Functions.
///
/// These Dart tests assert the security properties directly against the
/// TypeScript source, using the cross-language technique established by
/// `makeup_kit_security_contract_test.dart`, so the contract is checked by
/// `flutter test` alone. They prove the rules are present and wired; they do
/// not replace running the Deno suites beside those functions.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const standardDir = 'supabase/functions/generate-makeup-recommendation';
  const kitDir = 'supabase/functions/generate-kit-makeup-recommendation';

  final standardPrompt = source('$standardDir/prompt.ts');
  final standardSchema = source('$standardDir/schema.ts');
  final standardIndex = source('$standardDir/index.ts');
  final kitPrompt = source('$kitDir/prompt.ts');
  final kitValidation = source('$kitDir/validation.ts');
  final kitIndex = source('$kitDir/index.ts');
  final kitClient = source('$kitDir/gemini_client.ts');

  group('Standard Mode stays brand-neutral', () {
    test('the prompt forbids brands, retailers, and sponsorship', () {
      expect(
        standardPrompt,
        contains(
          'Never name, imply, or recommend a cosmetic brand, product line, '
          'retailer, celebrity, or sponsored product.',
        ),
      );
      expect(standardPrompt, contains('brand-neutral makeup artist'));
    });

    test('the schema has no brand, retailer, or purchase field', () {
      for (final forbidden in <String>[
        'brand',
        'retailer',
        'productLine',
        'purchase',
        'price',
        'url',
        'link',
      ]) {
        expect(
          standardSchema.toLowerCase(),
          isNot(contains(forbidden.toLowerCase())),
          reason: 'Standard Mode must not carry a $forbidden field',
        );
      }
    });

    test('the schema describes shades, not products to buy', () {
      // `name` is a shade name such as "warm peach"; the prompt constrains it
      // to a colour description and forbids brands outright.
      expect(standardSchema, contains('name:'));
      expect(standardPrompt, contains('concise shade or colour name'));
    });

    test('Standard Mode never reads the user kit', () {
      for (final token in <String>[
        'makeup_kit_products',
        'kit_makeup_recommendations',
        'productId',
        'inventory',
      ]) {
        expect(
          standardPrompt + standardIndex,
          isNot(contains(token)),
          reason: 'a user product name must never reach Standard Mode',
        );
      }
    });
  });

  group('only owned products reach Gemini', () {
    test(
      'the kit prompt sends the authenticated inventory and nothing else',
      () {
        expect(kitPrompt, contains('Authenticated inventory:'));
        expect(
          kitPrompt,
          contains(
            'using ONLY products in the supplied authenticated inventory',
          ),
        );
      },
    );

    test('the prompt requires exact copying of supplied identity', () {
      expect(
        kitPrompt,
        contains(
          'Every selection must copy productId, category, colorHex, and '
          'finish exactly from one supplied inventory object.',
        ),
      );
      expect(
        kitPrompt,
        contains(
          'Never invent, alter, infer, substitute, or recommend a product the '
          'user does not own.',
        ),
      );
      expect(kitPrompt, contains('Use each productId at most once.'));
    });

    test('an incomplete kit is stated as valid in the prompt', () {
      expect(kitPrompt, contains('An incomplete kit is valid.'));
      expect(
        kitPrompt,
        contains('Omit any category that is absent or unnecessary'),
      );
    });

    test('the prompt forbids brands and retailers in kit mode too', () {
      expect(kitPrompt, contains('Never include brands, retailers'));
    });
  });

  group('ownership is proven server-side, never by Gemini', () {
    test('the inventory is read through the RLS-scoped user client', () {
      expect(kitIndex, contains('userClient'));
      expect(kitIndex, contains('.from("makeup_kit_products")'));
      expect(
        kitIndex,
        isNot(contains('SUPABASE_SERVICE_ROLE_KEY')),
        reason: 'a service-role read would bypass RLS',
      );
    });

    test('rows not owned by the caller are rejected outright', () {
      expect(kitIndex, contains('product.user_id !== authData.user.id'));
      expect(kitIndex, contains('ownership_mismatch'));
    });

    test('an id absent from the owned inventory is rejected', () {
      // `byId` is built from the RLS-scoped inventory, so an invented id and a
      // foreign id both fail the same lookup.
      expect(kitValidation, contains('const byId = new Map('));
      expect(kitValidation, contains('inventory.map((product) => [product.id'));
      expect(
        kitValidation,
        contains('if (!product) throw invalid("fabricated_product")'),
      );
    });

    test('a malformed or duplicated id is rejected before lookup', () {
      expect(kitValidation, contains('uuidPattern.test(productId)'));
      expect(kitValidation, contains('seen.has(productId)'));
    });

    test('a wrong-category or altered attribute is rejected', () {
      expect(kitValidation, contains('category !== product.category'));
      expect(kitValidation, contains('colorHex !== product.color_hex'));
      expect(kitValidation, contains('finish !== product.finish'));
      expect(kitValidation, contains('throw invalid("product_mismatch")'));
    });

    test('an unsupported inventory category is rejected', () {
      expect(kitValidation, contains('unsupported_inventory_category'));
      expect(
        kitValidation,
        contains('supportedCategorySet.has(product.category)'),
      );
    });

    test('deletion or mutation during the AI call is detected', () {
      expect(kitIndex, contains('assertProductsUnchanged'));
      expect(kitValidation, contains('inventory_changed'));
      expect(
        kitIndex,
        contains('.in("id", selectedIds)'),
        reason: 'selected rows are re-read after Gemini responds',
      );
    });
  });

  group('the immutable snapshot is built from server data', () {
    test('snapshot fields come from the database row, not the AI response', () {
      // `products` is the server-side inventory; the AI response supplies only
      // which ids were chosen. Echoed attributes never reach persistence.
      expect(
        kitIndex,
        contains(
          'const product = products.find((candidate) => candidate.id === id)!',
        ),
      );
      expect(kitIndex, contains('colorHex: product.color_hex'));
      expect(kitIndex, contains('finish: product.finish'));
      expect(kitIndex, contains('productName: product.product_name'));
    });

    test('the snapshot is persisted with the recommendation', () {
      expect(kitIndex, contains('product_snapshot_json: snapshots'));
    });

    test('the snapshot is derived only after validation succeeds', () {
      // lastIndexOf, not indexOf: both helpers are also named on the import
      // line at the top of the file, which would otherwise be matched instead
      // of the call site.
      final validateAt = kitIndex.lastIndexOf(
        'parseAndValidateKitRecommendation(geminiText',
      );
      final assertAt = kitIndex.lastIndexOf('assertProductsUnchanged(');
      final snapshotAt = kitIndex.indexOf('const snapshots = selectedIds.map');

      expect(validateAt, greaterThan(-1));
      expect(assertAt, greaterThan(validateAt));
      expect(snapshotAt, greaterThan(assertAt));
    });
  });

  group('mode and versions are persisted', () {
    test('each mode records its model and prompt version', () {
      expect(kitIndex, contains('model_name: model'));
      expect(
        kitIndex,
        contains('prompt_version: KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION'),
      );
      expect(standardIndex, contains('model_name: model'));
      expect(
        standardIndex,
        contains('prompt_version: MAKEUP_RECOMMENDATION_PROMPT_VERSION'),
      );
    });

    test('the two prompt versions are distinct and isolated', () {
      // Each mode declares its own constant, so bumping one cannot silently
      // renumber the other. Note KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION
      // contains the standard constant's name as a substring, so the two are
      // compared by their declarations and values rather than by absence.
      expect(
        kitPrompt,
        contains('export const KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION ='),
      );
      expect(
        standardPrompt,
        contains('export const MAKEUP_RECOMMENDATION_PROMPT_VERSION ='),
      );
      expect(kitPrompt, contains('"kit_makeup_recommendation_v2"'));
      expect(standardPrompt, contains('"makeup_recommendation_v2"'));
      expect(
        standardPrompt,
        isNot(contains('KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION')),
        reason: 'Standard Mode must not depend on the kit prompt version',
      );
    });

    test('source mode is carried by the table, not a nullable flag', () {
      // Each mode writes to its own table, so the row's identity is the
      // discriminator. The domain makes it explicit through the sealed
      // LookPlanSource rather than inferring it from a nullable column.
      expect(kitIndex, contains('.from("kit_makeup_recommendations")'));
      expect(standardIndex, contains('.from("recommendations")'));
    });
  });

  group('no silent fallback and no unbounded work', () {
    test('kit mode never invokes the Standard Mode path', () {
      for (final token in <String>[
        'generate-makeup-recommendation',
        'makeupRecommendationPrompt',
        'MAKEUP_RECOMMENDATION_SCHEMA',
      ]) {
        expect(
          kitIndex + kitPrompt + kitValidation,
          isNot(contains(token)),
          reason: 'kit mode must never fall back to Standard Mode',
        );
      }
    });

    test('an empty kit fails explicitly rather than degrading', () {
      expect(kitIndex, contains('empty_kit'));
      expect(kitValidation, contains('empty_kit'));
      expect(
        kitValidation,
        contains('Add at least one product to My Makeup Kit first.'),
      );
    });

    test('Gemini retries are bounded with a timeout', () {
      expect(kitClient, contains('const maximumAttempts = 2'));
      expect(kitClient, contains('const timeoutMs = 45000'));
      expect(kitClient, contains('AbortSignal.timeout(timeoutMs)'));
      expect(kitClient, contains('attempt < maximumAttempts'));
    });

    test('malformed AI output is a typed failure, not a crash', () {
      expect(kitValidation, contains('malformed_ai_json'));
      expect(kitValidation, contains('invalid_ai_response'));
      expect(kitClient, contains('empty_ai_response'));
      expect(kitClient, contains('gemini_refusal'));
    });
  });

  group('authentication', () {
    test('both functions verify the caller before any work', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(RegExp(r'auth\s*\.getUser\(\)').hasMatch(index), isTrue);
        expect(index, contains('authData.user'));
      }
    });

    test('the gateway verifies the JWT for both functions', () {
      final config = source('supabase/config.toml');

      expect(
        RegExp(
          r'\[functions\.generate-makeup-recommendation\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(config),
        isTrue,
      );
      expect(
        RegExp(
          r'\[functions\.generate-kit-makeup-recommendation\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(config),
        isTrue,
      );
    });

    test('an unauthenticated caller is refused', () {
      expect(kitIndex, contains('401'));
      expect(standardIndex, contains('401'));
    });
  });
}
