import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// LSEP-1: education rides on the existing recommendation call.
///
/// A cross-language guard in the pattern `final_preview_model_lock_test.dart`
/// established: these assert properties of the TypeScript source from the Dart
/// suite, so `flutter test` alone proves the invariants. The Deno suite in
/// `generate-makeup-recommendation/validation_test.ts` covers runtime parsing;
/// both run, and neither replaces the other.
///
/// What is being locked out: a second paid "education" call, a weakened Kit
/// authority, and a silent loss of placement or technique.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const standardDir = 'supabase/functions/generate-makeup-recommendation';
  const kitDir = 'supabase/functions/generate-kit-makeup-recommendation';

  final standardIndex = source('$standardDir/index.ts');
  final standardPrompt = source('$standardDir/prompt.ts');
  final standardSchema = source('$standardDir/schema.ts');
  final standardValidation = source('$standardDir/validation.ts');
  final standardTypes = source('$standardDir/types.ts');
  final standardClient = source('$standardDir/gemini_client.ts');

  final kitIndex = source('$kitDir/index.ts');
  final kitPrompt = source('$kitDir/prompt.ts');
  final kitSchema = source('$kitDir/schema.ts');
  final kitValidation = source('$kitDir/validation.ts');

  /// [input] with comments removed, so an explanatory comment naming a
  /// forbidden concept is not mistaken for the concept itself.
  String executable(String input) => input
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('exactly one recommendation AI call', () {
    test('the standard function issues one Gemini request', () {
      expect(
        RegExp(
          r'await requestGeminiRecommendation\(',
        ).allMatches(standardIndex).length,
        1,
        reason: 'education must ride on the existing call, never add one',
      );
    });

    test('there is no second education AI operation anywhere', () {
      for (final forbidden in <String>[
        'requestGeminiEducation',
        'educationPrompt',
        'EDUCATION_PROMPT_VERSION',
        'generate-education',
        'requestEducation',
      ]) {
        expect(
          executable(standardIndex),
          isNot(contains(forbidden)),
          reason: 'a second paid education call is prohibited',
        );
        expect(executable(standardPrompt), isNot(contains(forbidden)));
      }
    });

    test('the function opens exactly one Gemini endpoint', () {
      expect(
        RegExp(
          'generativelanguage.googleapis.com',
        ).allMatches(standardClient).length,
        1,
      );
    });

    test('the recommendation model is still environment-resolved', () {
      expect(
        standardIndex,
        contains('Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash"'),
        reason: 'LSEP-1 changes the contract, never the model',
      );
      expect(RegExp('const model = ').allMatches(standardIndex).length, 1);
    });

    test('quota is consumed once, after the cached-plan short circuit', () {
      expect(
        RegExp(
          r'consumeAiQuota\(userClient, "makeup_recommendation"\)',
        ).allMatches(standardIndex).length,
        1,
      );
      expect(
        standardIndex.indexOf('if (existing) return jsonResponse'),
        // lastIndexOf, so this finds the call site rather than the import that
        // sits above every line in the file.
        lessThan(standardIndex.lastIndexOf('consumeAiQuota')),
        reason: 'a reused plan must never spend quota',
      );
    });
  });

  group('the education contract is typed and bounded', () {
    test('the schema requires the three sections', () {
      for (final section in <String>['features', 'effect', 'style']) {
        expect(standardSchema, contains('$section: { type: "string"'));
      }
      expect(standardSchema, contains('education: educationSchema'));
      expect(standardSchema, contains('additionalProperties: false'));
    });

    test('each section is length-capped so one plan cannot truncate', () {
      expect(
        RegExp(
          'minLength: 20, maxLength: 240',
        ).allMatches(standardSchema).length,
        3,
      );
      expect(standardValidation, contains('text(input, "features", 240)'));
      expect(standardValidation, contains('text(input, "effect", 240)'));
      expect(standardValidation, contains('text(input, "style", 240)'));
    });

    test('the output budget has headroom for the larger response', () {
      expect(standardClient, contains('maxOutputTokens: 8192'));
      expect(
        executable(standardClient),
        isNot(contains('maxOutputTokens: 4096')),
      );
    });

    test('the validator accepts education as a known item key', () {
      expect(standardValidation, contains('"education",'));
      expect(
        standardValidation,
        contains('education: education(input.education)'),
      );
    });

    test('the domain type carries the three sections', () {
      expect(standardTypes, contains('export type RecommendationEducation'));
      expect(standardTypes, contains('education: RecommendationEducation;'));
    });
  });

  group('the prompt grounds education and stays brand-neutral', () {
    test('the brand prohibition is intact', () {
      expect(
        standardPrompt,
        contains(
          'Never name, imply, or recommend a cosmetic brand, product line, '
          'retailer, celebrity, or sponsored product.',
        ),
      );
      expect(
        standardPrompt,
        contains('Never mention a brand, product line, retailer'),
        reason: 'the education section repeats the prohibition in its scope',
      );
    });

    test('education may only use supplied attributes, style and values', () {
      expect(
        standardPrompt,
        contains(
          'Ground every sentence in the supplied facial attributes, the '
          'selected style, and the values you chose for this same category.',
        ),
      );
    });

    test('inventing unobserved traits is forbidden by name', () {
      for (final forbidden in <String>[
        'acne',
        'blemishes',
        'scarring',
        'redness',
        'dark circles',
        'skin sensitivity',
        'pores',
        'wrinkles',
        'cheekbone prominence',
        'eye depth',
        'lip asymmetry',
      ]) {
        expect(
          standardPrompt,
          contains(forbidden),
          reason: '$forbidden must be explicitly prohibited',
        );
      }
      expect(standardPrompt, contains('Never state or invent a confidence'));
      expect(
        standardPrompt,
        contains('Never make a medical, dermatological, or corrective claim.'),
      );
    });

    test('absolute claims are forbidden', () {
      for (final absolute in <String>[
        '"perfect"',
        '"guaranteed"',
        '"always best"',
        '"definitely"',
      ]) {
        expect(standardPrompt, contains(absolute));
      }
    });

    test('education does not duplicate the tutorial', () {
      expect(
        standardPrompt,
        contains('Do not restate the placement or technique text.'),
        reason: 'where and how belong to Show Me How, not to the Palette',
      );
    });

    test('no hardcoded beauty-rule engine was introduced', () {
      // Education is generated by the same call that makes the choice. Nothing
      // in the function derives an explanation from a lookup table.
      for (final forbidden in <String>[
        'educationFor',
        'explanationFor',
        'featureRules',
        'undertoneRules',
        'RULE_TABLE',
      ]) {
        expect(executable(standardValidation), isNot(contains(forbidden)));
        expect(executable(standardIndex), isNot(contains(forbidden)));
      }
    });
  });

  group('placement, technique and shade metadata are preserved', () {
    test('the schema still requires all of them', () {
      for (final field in <String>[
        'placement',
        'technique',
        'finish',
        'intensity',
        'name',
        'hex',
        'reasoning',
      ]) {
        expect(standardSchema, contains('$field:'));
      }
    });

    test('the validator still parses all of them', () {
      expect(
        standardValidation,
        contains('placement: text(input, "placement"'),
      );
      expect(
        standardValidation,
        contains('technique: text(input, "technique"'),
      );
      expect(standardValidation, contains('finish: text(input, "finish"'));
      expect(
        standardValidation,
        contains('reasoning: text(input, "reasoning"'),
      );
      expect(standardValidation, contains('intensity,'));
    });

    test('the exported type still carries them', () {
      expect(standardTypes, contains('placement: string;'));
      expect(standardTypes, contains('technique: string;'));
    });
  });

  group('prompt versioning and persistence', () {
    test('the prompt version is bumped', () {
      expect(
        standardPrompt,
        contains(
          'export const MAKEUP_RECOMMENDATION_PROMPT_VERSION = '
          '"makeup_recommendation_v3"',
        ),
      );
    });

    test('the reuse lookup keys on the prompt version', () {
      expect(
        standardIndex,
        contains('.eq("prompt_version", MAKEUP_RECOMMENDATION_PROMPT_VERSION)'),
        reason: 'a v2 row must never be served as a v3 plan',
      );
    });

    test('persistence still writes the same columns', () {
      expect(standardIndex, contains('recommendation_json: plan'));
      expect(
        standardIndex,
        contains('prompt_version: MAKEUP_RECOMMENDATION_PROMPT_VERSION'),
      );
    });

    test('no migration was added for education', () {
      final migrations = Directory(
        '${root.path}${Platform.pathSeparator}supabase'
        '${Platform.pathSeparator}migrations',
      ).listSync().whereType<File>();

      for (final file in migrations) {
        expect(
          file.readAsStringSync(),
          isNot(contains('education')),
          reason: 'education is additive inside the existing jsonb column',
        );
      }
    });
  });

  group('My Makeup Kit authority is untouched', () {
    test('the kit contract gained no education field', () {
      expect(kitSchema, isNot(contains('education')));
      expect(kitValidation, isNot(contains('education')));
      expect(executable(kitPrompt), isNot(contains('education')));
    });

    test('the kit prompt version is unchanged', () {
      expect(kitPrompt, contains('"kit_makeup_recommendation_v2"'));
    });

    test('owned-products-only selection is intact', () {
      expect(
        kitPrompt,
        contains(
          'Create one achievable look using ONLY products in the supplied '
          'authenticated inventory.',
        ),
      );
      expect(
        kitPrompt,
        contains(
          'Every selection must copy productId, category, colorHex, and '
          'finish exactly from one supplied inventory object.',
        ),
      );
    });

    test('product substitution and invention remain prohibited', () {
      expect(
        kitPrompt,
        contains(
          'Never invent, alter, infer, substitute, or recommend a product the '
          'user does not own.',
        ),
      );
    });

    test('the kit never falls back to the standard recommendation', () {
      // Matched on the standard function's own directory and its own version
      // literal. `MAKEUP_RECOMMENDATION_PROMPT_VERSION` alone would match the
      // kit's own `KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION`, which is the
      // symbol this file is supposed to use.
      expect(
        executable(kitIndex),
        isNot(contains('../generate-makeup-recommendation')),
      );
      expect(
        executable(kitIndex),
        isNot(contains('"makeup_recommendation_v')),
        reason: 'the kit must never persist a standard prompt version',
      );
      expect(
        executable(kitIndex),
        isNot(contains(' MAKEUP_RECOMMENDATION_PROMPT_VERSION')),
        reason: 'a leading space excludes the kit-prefixed symbol',
      );
      for (final forbidden in <String>[
        'standardFallback',
        'fallbackToStandard',
        'useStandard',
      ]) {
        expect(executable(kitIndex), isNot(contains(forbidden)));
      }
    });

    test('server-side ownership validation still runs', () {
      expect(kitValidation.isNotEmpty, isTrue);
      expect(kitIndex, contains('makeup_kit_products'));
    });
  });

  group('protected AI surfaces were not touched', () {
    test('the recommendation function references no protected prompt', () {
      for (final protectedVersion in <String>[
        'tutorial_guideline_v4_7',
        'tutorial_manifest_v4_1',
        'MAKEUP_PREVIEW_PROMPT_VERSION',
        'FINAL_PREVIEW_MODEL',
      ]) {
        expect(standardIndex, isNot(contains(protectedVersion)));
        expect(standardPrompt, isNot(contains(protectedVersion)));
      }
    });
  });
}
