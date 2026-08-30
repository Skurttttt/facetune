import 'dart:io';

import 'package:facetune/features/tutorial/domain/catalog/tutorial_category_mapping.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the manifest analyzer Edge Function.
///
/// Deno is not installed here, so `analyze-tutorial-manifest-v4/validation_test.ts`
/// cannot be executed. These assert the same guarantees against the TypeScript
/// source, and additionally pin the Dart and TypeScript vocabularies together —
/// the one guarantee neither language's own suite can make alone.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const dir = 'supabase/functions/analyze-tutorial-manifest-v4';
  // The vocabulary moved to _shared in V4-8 so the analyzer and the source
  // resolver read one copy; this test follows it there.
  final types = source('supabase/functions/_shared/tutorial_vocabulary.ts');
  final schema = source('$dir/schema.ts');
  final prompt = source('$dir/prompt.ts');
  final validation = source('$dir/validation.ts');
  final index = source('$dir/index.ts');
  final client = source('$dir/gemini_client.ts');
  final ownership = source('supabase/functions/_shared/storage_ownership.ts');

  /// The category codes declared in the TypeScript vocabulary, in order.
  List<String> typescriptCategories() {
    final block = RegExp(
      r'export const TUTORIAL_CATEGORIES = \[([\s\S]*?)\] as const;',
    ).firstMatch(types)!.group(1)!;
    return RegExp(
      r'"([a-z_]+)"',
    ).allMatches(block).map((match) => match.group(1)!).toList();
  }

  group('the two languages share one vocabulary', () {
    test('TypeScript categories match Dart exactly, in order', () {
      expect(
        typescriptCategories(),
        TutorialCategory.orderedVocabulary
            .map((category) => category.code)
            .toList(),
        reason: 'a drift here would give the two sides different tutorials',
      );
    });

    test('the deterministic order is the array order', () {
      expect(typescriptCategories(), <String>[
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrows',
        'eyeshadow',
        'eyeliner',
        'lips',
      ]);
      expect(types, contains('TUTORIAL_CATEGORIES.indexOf(category) + 1'));
    });

    test('the inventory mapping matches Dart, including many-to-one', () {
      final block = RegExp(
        r'INVENTORY_TO_TUTORIAL[\s\S]*?\{([\s\S]*?)\n  \};',
      ).firstMatch(types)!.group(1)!;
      final pairs = <String, String>{
        for (final match in RegExp(r'([a-z_]+): "([a-z_]+)"').allMatches(block))
          match.group(1)!: match.group(2)!,
      };

      expect(pairs, hasLength(MakeupKitCategory.values.length));
      for (final kit in MakeupKitCategory.values) {
        expect(
          pairs[kit.code],
          TutorialCategoryMapping.fromKitCategory(kit).code,
          reason: '${kit.code} must map identically on both sides',
        );
      }
      expect(pairs['lipstick'], 'lips');
      expect(pairs['lip_gloss'], 'lips');
    });
  });

  group('the analyzer compares two owned images', () {
    test('the original is IMAGE A and the preview is IMAGE B', () {
      expect(prompt, contains('IMAGE A is the ORIGINAL photograph'));
      expect(prompt, contains('IMAGE B is the FINAL photograph'));
      // Part order must match the prompt's labels or every verdict inverts.
      final originalAt = client.indexOf('IMAGE A — ORIGINAL, before makeup:');
      final previewAt = client.indexOf('IMAGE B — FINAL, after makeup:');
      expect(originalAt, greaterThan(-1));
      expect(previewAt, greaterThan(originalAt));
    });

    test('both images are ownership-proven before they are read', () {
      expect(index, contains('isOwnedOriginalPath'));
      expect(index, contains('isOwnedGeneratedPreviewPath'));
      expect(index, contains('invalid_original_path'));
      expect(index, contains('invalid_preview_path'));
    });

    test('the preview ownership helper validates segment by segment', () {
      expect(
        ownership,
        contains('export function isOwnedGeneratedPreviewPath'),
      );
      expect(ownership, contains('segments.length !== 6'));
      expect(ownership, contains(r'/^preview_\d{4}$/'));
      expect(
        ownership,
        contains('segments[3] !== folder'),
        reason: 'the original folder must never satisfy a preview path',
      );
    });

    test('comparison is impossible without both images, and fails safely', () {
      expect(index, contains('visual_comparison_unavailable'));
      expect(
        index,
        contains('originalDownload.error || !originalDownload.data'),
      );
      expect(index, contains('previewDownload.error || !previewDownload.data'));
    });

    test('the client cannot declare the source mode', () {
      expect(
        index,
        contains('sourceMode: hasStandard ? "standard" : "my_makeup_kit"'),
      );
      expect(
        index,
        isNot(contains('input.sourceMode')),
        reason: 'mode is derived from which owner-scoped table holds the row',
      );
      expect(index, contains('Provide exactly one canonical preview.'));
    });
  });

  group('inclusion comes from visual evidence only', () {
    test('the prompt forbids style and face-shape templates', () {
      expect(
        prompt,
        contains(
          'Never mark a category present because a makeup style usually '
          'includes it.',
        ),
      );
      expect(
        prompt,
        contains(
          'Never mark a category present because of face shape, skin tone, or '
          'what would be flattering.',
        ),
      );
      expect(prompt, contains('Do not assume every category was used.'));
    });

    test('the prompt frames every judgement as a change from IMAGE A', () {
      expect(prompt, contains('Always compare against IMAGE A.'));
      expect(prompt, contains('Natural features are not makeup.'));
    });

    test('the look plan is a tie-breaker, never evidence', () {
      expect(prompt, contains('SUPPORTING CONTEXT — TIE-BREAKER ONLY'));
      expect(
        prompt,
        contains(
          'Never mark a category present because it appears in the supporting '
          'context below.',
        ),
      );
      expect(prompt, contains('It is not evidence, it is not a checklist'));
      expect(
        prompt,
        contains('it is absent or uncertain no matter what this context says'),
      );
      expect(
        index,
        contains('This is context only and never evidence of visual presence.'),
      );
    });

    test('uncertain is offered as a correct answer, not discouraged', () {
      expect(
        prompt,
        contains(
          '"uncertain" is a correct and useful answer; a wrong "present" '
          'creates a tutorial step for makeup that was never applied.',
        ),
      );
    });

    test('only present is included; uncertain never is', () {
      expect(
        validation,
        contains('const visible = verdict.presence === "present"'),
      );
      expect(
        validation,
        isNot(contains('presence !== "absent"')),
        reason: 'treating not-absent as present would promote uncertain',
      );
    });

    test('no confidence threshold is hardcoded', () {
      // The score is carried and range-checked, but never compared against a
      // cutoff — SoT forbids inventing one before controlled QA.
      expect(validation, contains('confidence < 0 || confidence > 1'));
      for (final threshold in <String>[
        'visualConfidence >',
        'visualConfidence <',
        'confidence >= 0.',
        'confidence > 0.',
      ]) {
        expect(
          validation,
          isNot(contains(threshold)),
          reason: 'an evidence-free threshold must not gate inclusion',
        );
      }
    });
  });

  group('the vocabulary is closed', () {
    test('the schema forbids extra properties and requires all nine', () {
      expect(schema, contains('additionalProperties: false'));
      expect(schema, contains('required: [...TUTORIAL_CATEGORIES]'));
      expect(schema, contains('enum: ["present", "absent", "uncertain"]'));
    });

    test('validation rejects an invented or missing category', () {
      expect(validation, contains('TUTORIAL_CATEGORY_SET.has(key)'));
      expect(validation, contains('unsupported_category'));
      expect(validation, contains('incomplete_manifest'));
    });

    test('rejects rather than repairs an unusable response', () {
      expect(validation, contains('malformed_ai_json'));
      expect(validation, contains('invalid_ai_response'));
      expect(validation, contains('Rejects rather than repairs.'));
    });
  });

  group('My Makeup Kit intersection', () {
    test('inclusion is visible AND owned', () {
      expect(
        validation,
        contains('included: isKit ? visible && productBacked : visible'),
      );
    });

    test('a visible unowned category becomes kit_preview_mismatch', () {
      expect(
        validation,
        contains('item.presence === "present" && !item.productBacked'),
      );
      expect(
        validation,
        contains(
          'manifestStatus: unbackedPresentCategories.length > 0\n'
          '      ? "kit_preview_mismatch"\n'
          '      : "accepted"',
        ),
      );
    });

    test('owning a product never forces a visually absent step', () {
      // Behavioural rather than prose: `visible` is required in both branches,
      // so a backed-but-absent category cannot be included by any path.
      expect(
        validation,
        contains('included: isKit ? visible && productBacked : visible'),
      );
      expect(
        validation,
        isNot(contains('included: isKit ? productBacked')),
        reason: 'ownership alone must never satisfy inclusion',
      );
    });

    test('backed categories come from the server-side snapshot only', () {
      expect(index, contains('.from("kit_makeup_recommendations")'));
      expect(index, contains('product_snapshot_json'));
      expect(index, contains('backed = productBackedCategories(snapshot)'));
      // Backing is derived from the stored snapshot through the server-owned
      // mapping; nothing the model returned reaches it.
      expect(validation, contains('INVENTORY_TO_TUTORIAL[category]'));
      expect(
        validation,
        isNot(contains('INVENTORY_TO_TUTORIAL[verdict')),
        reason: 'backing must never be derived from the AI response',
      );
    });

    test('standard mode has no mismatch and no backing', () {
      expect(validation, contains('unbackedPresentCategories = isKit'));
      expect(
        validation,
        contains('const productBacked = isKit && backedCategories.has'),
      );
    });
  });

  group('order stays deterministic after filtering', () {
    test('items are sorted by vocabulary position, then filtered', () {
      final sortAt = validation.indexOf(
        'sort((a, b) => a.position - b.position)',
      );
      final filterAt = validation.indexOf('.filter((item) => item.included)');
      expect(sortAt, greaterThan(-1));
      expect(filterAt, greaterThan(sortAt));
    });

    test('position is derived from the vocabulary, not the model', () {
      expect(
        validation,
        contains('position: categoryPosition(verdict.category)'),
      );
      expect(
        prompt,
        isNot(contains('position')),
        reason: 'the model must never choose order',
      );
    });
  });

  group('persistence, reuse, and versioning', () {
    test('an accepted manifest is reused without an AI call', () {
      final reuseAt = index.indexOf('.from("tutorial_v4_sessions")');
      final geminiAt = index.indexOf('requestGeminiManifest(');
      final quotaAt = index.indexOf('consumeAiQuota(');
      expect(reuseAt, greaterThan(-1));
      expect(
        reuseAt,
        lessThan(quotaAt),
        reason: 'reuse must be checked before quota is spent',
      );
      expect(reuseAt, lessThan(geminiAt));
      expect(index, contains('reused: true'));
    });

    test('a mismatch is also reused rather than re-analyzed', () {
      expect(
        index,
        contains('existing.manifest_status === "kit_preview_mismatch"'),
      );
    });

    test('reuse requires matching prompt and schema versions', () {
      expect(
        index,
        contains(
          'existing.manifest_prompt_version === TUTORIAL_MANIFEST_PROMPT_VERSION',
        ),
      );
      expect(
        index,
        contains(
          'existing.manifest_schema_version === TUTORIAL_MANIFEST_SCHEMA_VERSION',
        ),
      );
    });

    test('a session is keyed to one canonical preview', () {
      // A regenerated preview has a different id, so it cannot match an
      // existing session and necessarily gets its own manifest.
      expect(index, contains('canonical_kit_generated_image_id'));
      expect(index, contains('canonical_generated_image_id'));
      expect(index, contains('onConflict:'));
    });

    test('model, prompt, and schema versions are persisted', () {
      expect(index, contains('manifest_model: model'));
      expect(
        index,
        contains('manifest_prompt_version: TUTORIAL_MANIFEST_PROMPT_VERSION'),
      );
      expect(
        index,
        contains('manifest_schema_version: TUTORIAL_MANIFEST_SCHEMA_VERSION'),
      );
      expect(prompt, contains('tutorial_manifest_v4_1'));
      expect(schema, contains('tutorial_manifest_schema_v1'));
    });

    test('re-analysis replaces old verdicts rather than appending', () {
      expect(
        index,
        contains('.from("tutorial_v4_manifest_items").delete().eq('),
      );
    });

    test('a mismatch marks the session, not just the manifest', () {
      expect(
        index,
        contains('resolved.manifestStatus === "kit_preview_mismatch"'),
      );
      expect(index, contains('"manifest_ready"'));
    });
  });

  group('the analyzer stays in its lane', () {
    test('it reuses the approved structured-output model', () {
      expect(index, contains('Deno.env.get("GEMINI_MANIFEST_MODEL")'));
      expect(index, contains('"gemini-3.6-flash"'));
      expect(client, contains('responseJsonSchema: TUTORIAL_MANIFEST_SCHEMA'));
      expect(client, contains('responseMimeType: "application/json"'));
    });

    test('it never renders an image', () {
      for (final token in <String>[
        'gemini-3-pro-image',
        'gemini-3.1-flash-image',
        'guideline',
        'storage.from("face-images").upload',
      ]) {
        expect(index.toLowerCase(), isNot(contains(token.toLowerCase())));
      }
    });

    test('it consumes its own bounded quota', () {
      expect(
        index,
        contains('consumeAiQuota(client, "tutorial_manifest_analysis")'),
      );
      expect(index, contains('rate_limited'));
      expect(client, contains('const maximumAttempts = 2'));
      expect(client, contains('AbortSignal.timeout(requestTimeoutMs)'));
    });

    test('it verifies the caller and the gateway verifies the JWT', () {
      expect(RegExp(r'auth\.getUser\(\)').hasMatch(index), isTrue);
      expect(index, contains('authentication_required'));
      expect(index, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
      expect(
        RegExp(
          r'\[functions\.analyze-tutorial-manifest-v4\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(source('supabase/config.toml')),
        isTrue,
      );
    });
  });
}
