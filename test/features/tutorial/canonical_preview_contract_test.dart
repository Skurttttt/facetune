import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the two canonical final-preview Edge Functions.
///
/// Deno is not installed here, so the Deno suites beside these functions cannot
/// be executed; these assert the same properties against the TypeScript source,
/// following `makeup_kit_security_contract_test.dart`.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const standardDir = 'supabase/functions/generate-makeup-preview';
  const kitDir = 'supabase/functions/generate-kit-makeup-preview';

  final standardIndex = source('$standardDir/index.ts');
  final kitIndex = source('$kitDir/index.ts');
  final kitPrompt = source('$kitDir/prompt.ts');
  final kitValidation = source('$kitDir/validation.ts');
  final standardGemini = source('$standardDir/gemini_client.ts');
  final kitGemini = source('$kitDir/gemini_client.ts');

  group('the canonical model is Pro in both modes', () {
    test('both previews default to gemini-3-pro-image', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('"gemini-3-pro-image"'));
        expect(
          index,
          isNot(contains('"gemini-3.1-flash-image"')),
          reason: 'the canonical preview must not fall back to a Flash model',
        );
      }
    });

    test('both read the same server-side configuration key', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('Deno.env.get("GEMINI_IMAGE_MODEL")'));
      }
    });

    test('the model is never supplied by the client', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, isNot(contains('body.model')));
        expect(index, isNot(contains('payload.model')));
      }
    });

    test('the persisted row records which model produced the preview', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('model_name: model'));
      }
    });
  });

  group('the original selfie is preserved as identity reference', () {
    test('both resolve the original server-side and prove ownership', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('isOwnedOriginalPath'));
        expect(index, contains('original_image_path'));
        expect(index, contains('.from("face-images").download('));
      }
    });

    test('a generated preview can never overwrite the original', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('candidatePath === originalImagePath'));
        expect(index, contains('candidatePath.includes("/original/")'));
        expect(index, contains('unsafe_storage_path'));
      }
    });

    test('the kit prompt treats the selfie as the sole identity reference', () {
      expect(
        kitPrompt,
        contains(
          'The original image is the sole identity and photographic reference',
        ),
      );
      expect(kitPrompt, contains('HIGHEST PRIORITY — IDENTITY'));
      expect(
        kitPrompt,
        contains('Do not add text, labels, borders, watermarks'),
      );
    });
  });

  group('My Makeup Kit cannot gain an unowned category', () {
    test('the prompt forbids inventing makeup for absent categories', () {
      expect(
        kitPrompt,
        contains('Do not invent makeup for absent categories.'),
      );
      expect(kitPrompt, contains('REGISTERED PRODUCTS ONLY'));
      expect(kitPrompt, contains('Apply only the listed selections.'));
    });

    test('the prompt forbids substituting a more flattering shade', () {
      expect(
        kitPrompt,
        contains(
          'Do not replace a shade with a more conventional, flattering, '
          'vivid, light, or dark alternative.',
        ),
      );
      expect(
        kitPrompt,
        contains(
          'Never label, imply, or depict an unrelated shade as a registered '
          'product.',
        ),
      );
    });

    test('every selection must match the immutable snapshot exactly', () {
      expect(kitValidation, contains('category !== snapshot.category'));
      expect(kitValidation, contains('colorHex !== snapshot.colorHex'));
      expect(kitValidation, contains('finish !== snapshot.finish'));
      expect(kitValidation, contains('if (!snapshot) throw invalidPlan()'));
    });

    test('only the validated plan reaches the model', () {
      expect(kitPrompt, contains('Validated registered-product plan:'));
      expect(kitIndex, contains('normalizeAndValidateKitPreviewPlan'));
    });
  });

  group('missing snapshot is rejected in My Makeup Kit mode', () {
    test('an absent or empty snapshot array is invalid', () {
      expect(
        kitValidation,
        contains(
          'if (!Array.isArray(snapshotValue) || snapshotValue.length < 1)',
        ),
      );
      expect(kitValidation, contains('invalid_kit_plan'));
    });

    test('a snapshot with no usable product ids is invalid', () {
      expect(kitIndex, contains('if (selectedIds.length === 0)'));
      expect(kitIndex, contains('"invalid_kit_plan"'));
    });

    test('a selection with no matching snapshot is invalid', () {
      expect(
        kitValidation,
        contains('const snapshot = snapshotById.get(productId)'),
      );
    });

    test('an edited or deleted product blocks generation', () {
      expect(kitValidation, contains('staleKit()'));
      expect(kitValidation, contains('inventory_changed'));
      expect(
        kitValidation,
        contains('A selected product was edited or removed.'),
      );
    });
  });

  group('lineage is persisted with the canonical preview', () {
    test('standard previews link analysis and recommendation', () {
      expect(standardIndex, contains('.from("generated_images")'));
      expect(standardIndex, contains('recommendation_id'));
      expect(standardIndex, contains('analysis_id'));
    });

    test('kit previews link analysis and kit recommendation', () {
      expect(kitIndex, contains('.from("kit_generated_images")'));
      expect(kitIndex, contains('kit_recommendation_id'));
      expect(kitIndex, contains('analysis_id'));
    });

    test('source mode is resolvable from which table holds the preview', () {
      expect(standardIndex, isNot(contains('kit_generated_images')));
      expect(kitIndex, isNot(contains('.from("generated_images")')));
    });

    test('regeneration keeps a monotonic variation lineage', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('generation_number'));
        expect(
          index,
          contains('order("generation_number", { ascending: false })'),
        );
      }
      expect(kitPrompt, contains('This is variation \${variationNumber}'));
      expect(
        kitPrompt,
        contains('Never vary registered colors, product finishes, identity'),
      );
    });

    test('each generation writes a new path rather than overwriting', () {
      // The storage path embeds the zero-padded generation number, so a
      // regenerated variation lands beside its predecessor instead of
      // replacing it. Asserted on the expression rather than a local variable
      // name: the standard function names it `paddedNumber` while the kit
      // function inlines the same call.
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('padStart(4, "0")'));
        expect(index, contains('generation_number: generationNumber'));
      }
    });
  });

  group('no forbidden work was added', () {
    test('neither preview function performs manifest or guideline work', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        for (final token in <String>[
          'tutorial_v4_sessions',
          'tutorial_v4_steps',
          'tutorial_v4_manifest_items',
          'guideline',
        ]) {
          expect(index.toLowerCase(), isNot(contains(token.toLowerCase())));
        }
      }
    });

    test('generation is bounded, with no silent regeneration loop', () {
      for (final index in <String>[standardIndex, kitIndex]) {
        expect(index, contains('consumeAiQuota'));
        expect(index, contains('rate_limited'));
      }
    });
  });

  group('the canonical preview calls a Gemini API version that serves Pro', () {
    // Proven in production on 2026-08-30: gemini-3-pro-image returned
    // HTTP 404 NOT_FOUND "is not found for API version v1, or is not
    // supported for generateContent". The image-generation models are
    // served from v1beta, which every other Gemini caller already uses.
    test('standard preview requests v1beta', () {
      expect(
        standardGemini,
        contains('https://generativelanguage.googleapis.com/v1beta/models/'),
      );
    });

    test('standard preview no longer requests v1', () {
      expect(
        standardGemini,
        isNot(contains('googleapis.com/v1/models/')),
        reason: 'v1 does not serve gemini-3-pro-image for generateContent',
      );
    });

    test('every other Gemini caller already uses v1beta', () {
      for (final path in <String>[
        'supabase/functions/analyze-face/gemini_client.ts',
        'supabase/functions/generate-makeup-recommendation/gemini_client.ts',
        'supabase/functions/generate-kit-makeup-recommendation/gemini_client.ts',
        'supabase/functions/generate-tutorial-step-v4/gemini_client.ts',
        'supabase/functions/analyze-tutorial-manifest-v4/gemini_client.ts',
      ]) {
        expect(
          source(path),
          isNot(contains('googleapis.com/v1/models/')),
          reason: '$path must stay on v1beta',
        );
      }
    });

    test('My Makeup Kit preview is a known, tracked latent defect', () {
      // Deliberately still on v1: V4-DEBUG-02 proves the correction on
      // Standard Mode alone, one causal variable at a time. When the kit
      // function is corrected in its own controlled change, this
      // expectation must be inverted to match the two tests above.
      expect(
        kitGemini,
        contains('googleapis.com/v1/models/'),
        reason: 'kit correction is a separate, deliberate change',
      );
    });
  });
}
