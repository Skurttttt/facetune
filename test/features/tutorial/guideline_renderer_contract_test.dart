import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the guideline renderer.
///
/// Deno is not installed here, so `generate-tutorial-step-v4/prompt_test.ts`
/// cannot be executed. These assert the same properties against the TypeScript
/// source.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const dir = 'supabase/functions/generate-tutorial-step-v4';
  final config = source('supabase/functions/_shared/tutorial_ai_config.ts');
  final prompt = source('$dir/prompt.ts');
  final client = source('$dir/gemini_client.ts');
  final index = source('$dir/index.ts');

  group('configuration is centralized and locked', () {
    test(
      'the model is the Flash image renderer, not the Pro preview model',
      () {
        expect(config, contains('"gemini-3.1-flash-image"'));
        expect(
          config,
          isNot(contains('"gemini-3-pro-image"')),
          reason:
              'the guideline renderer and the canonical preview are distinct',
        );
      },
    );

    test('resolution is 1K, defined once', () {
      expect(
        config,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
      expect(
        RegExp('"1K"').allMatches(config).length,
        1,
        reason: 'one definition, so no category can drift',
      );
      expect(
        prompt + client + index,
        isNot(contains('"0.5K"')),
        reason: '0.5K is not an option until the 1K baseline is approved',
      );
    });

    test('the prompt is versioned in the same place', () {
      // Bumped to v4_2 in V4-10, when per-category landmarks and prohibitions
      // changed every rendered prompt. What this guards is that the version
      // lives beside the model and resolution, not that it never moves.
      expect(
        config,
        contains(
          'export const TUTORIAL_GUIDELINE_PROMPT_VERSION = '
          '"tutorial_guideline_v4_2"',
        ),
      );
    });

    test('the client never selects model, resolution, or prompt', () {
      for (final forbidden in <String>[
        'input.model',
        'input.resolution',
        'input.promptVersion',
        'input.outputResolution',
      ]) {
        expect(index, isNot(contains(forbidden)));
      }
      expect(
        index,
        contains("tutorialSessionId: String(input.tutorialSessionId ?? \"\")"),
      );
      expect(index, contains('category: String(input.category ?? "")'));
    });

    test('the 1K resolution is actually sent with the request', () {
      expect(
        client,
        contains('imageConfig: { imageSize: TUTORIAL_OUTPUT_RESOLUTION }'),
      );
      expect(
        client,
        contains('UNVERIFIED'),
        reason: 'the unproven request shape must be flagged in the source',
      );
    });
  });

  group('the renderable set is explicit', () {
    // V4-9 shipped a blush-only pilot; V4-10 opened the set to the full
    // vocabulary. What still matters is that enablement is an explicit set
    // rather than "anything a caller names", so this guards that property
    // rather than the pilot that superseded it.
    test('enablement is an explicit set, not an open door', () {
      expect(config, contains('RENDERABLE_CATEGORIES'));
      expect(config, contains('>(TUTORIAL_CATEGORIES)'));
      expect(
        config,
        contains('cannot reach the model before someone has'),
        reason: 'a new vocabulary entry must not auto-enable',
      );
    });

    test('a category with no reviewed guidance is refused, not rendered', () {
      expect(index, contains('isRenderableCategory(context.category)'));
      expect(index, contains('categoryGuidance(context.category)'));
      expect(index, contains('category_not_available'));
      expect(index, contains('if (guidance === null)'));
    });
  });

  group('Image A renders, Image B directs', () {
    test('the prompt names the roles unambiguously', () {
      expect(prompt, contains('IMAGE A is the ORIGINAL photograph'));
      expect(prompt, contains('This is your CANVAS'));
      expect(prompt, contains('IMAGE B is the FINAL photograph'));
      expect(prompt, contains('This is your REFERENCE'));
      expect(prompt, contains('PLACEMENT COMES FROM IMAGE B ONLY'));
    });

    test('part order matches the prompt labels', () {
      final imageA = client.indexOf('IMAGE A — ORIGINAL, no makeup');
      final imageB = client.indexOf('IMAGE B — FINAL, reference only');
      expect(imageA, greaterThan(-1));
      expect(imageB, greaterThan(imageA));
      expect(client, contains('Part order is load-bearing'));
    });

    test('generic and flattering placement are forbidden', () {
      expect(
        prompt,
        contains('Do not use a standard, textbook, or flattering placement.'),
      );
      expect(
        prompt,
        contains(
          'mark the smaller, more conservative area rather than guessing',
        ),
      );
    });
  });

  group('guidelines only, never pigment or text', () {
    test('applying makeup is forbidden', () {
      expect(prompt, contains('NEVER APPLY MAKEUP'));
      expect(
        prompt,
        contains('Do NOT apply, paint, tint, blend, or simulate any actual'),
      );
      expect(prompt, contains('same bare skin, same tone, same texture'));
    });

    test('only markings are drawn', () {
      expect(prompt, contains('DRAW ONLY GUIDELINES'));
      expect(
        prompt,
        contains('thin outlines, boundary lines, directional arrows'),
      );
      expect(prompt, contains('like annotations drawn on a printed photo'));
    });

    test('no text of any kind, including product names', () {
      expect(prompt, contains('NO TEXT OF ANY KIND'));
      expect(
        prompt,
        contains('brand names, product names, shade names, colour codes'),
      );
      expect(prompt, contains('All wording is shown outside the image'));
    });

    test('unrelated categories are excluded', () {
      expect(prompt, contains(r'Mark ${options.category} and nothing else.'));
      expect(prompt, contains('Ignore every other makeup category'));
    });

    test('the photograph is preserved', () {
      expect(prompt, contains('PRESERVE THE PHOTOGRAPH'));
      expect(
        prompt,
        contains('Preserve identity, facial proportions, pose, head angle'),
      );
      expect(prompt, contains('hairstyle, hairline, clothing, background'));
    });
  });

  group('product context never becomes placement authority', () {
    test('the note is explicitly subordinated to Image B', () {
      expect(prompt, contains('CONTEXT ONLY'));
      expect(prompt, contains('This tells you the '));
      expect(prompt, contains('It does NOT change where the markings go'));
      expect(prompt, contains('IMAGE B remains the only placement authority'));
      expect(prompt, contains('Do not paint this shade '));
    });

    test('Standard Mode adds no note at all', () {
      expect(prompt, contains('if (products.length === 0) return null'));
    });
  });

  group('output validation and private storage', () {
    test('the returned payload must be a real image', () {
      expect(client, contains('signatureMatches'));
      expect(client, contains('invalid_generated_guideline'));
      expect(client, contains('minimumBytes'));
      expect(client, contains('maximumBytes'));
    });

    test('an unchanged image is treated as a failure to draw', () {
      expect(client, contains('export function isUnchanged'));
      expect(index, contains('unchanged_guideline'));
    });

    test('the guideline is written to the private bucket only', () {
      expect(index, contains(".from(\"face-images\")"));
      expect(index, contains('upsert: false'));
      expect(config, contains('guidelineStoragePath'));
      expect(config, contains('/tutorials/'));
    });

    test('it can never overwrite the selfie or the canonical preview', () {
      expect(index, contains('storagePath.includes("/original/")'));
      expect(index, contains('storagePath.includes("/generated/")'));
      expect(index, contains('unsafe_storage_path'));
    });

    test('a failed persist removes the orphaned object', () {
      expect(index, contains('.remove([storagePath])'));
      expect(index, contains('unreferenced'));
    });
  });

  group('metadata persistence', () {
    test('the step records model, resolution, prompt version, and latency', () {
      expect(index, contains('model_name: TUTORIAL_GUIDELINE_MODEL'));
      expect(index, contains('output_resolution: TUTORIAL_OUTPUT_RESOLUTION'));
      expect(
        index,
        contains('prompt_version: TUTORIAL_GUIDELINE_PROMPT_VERSION'),
      );
      expect(index, contains('latency_ms: latencyMs'));
      expect(index, contains("status: \"ready\""));
    });

    test('a failure records a sanitized code and frees the step', () {
      expect(index, contains('async function releaseStep'));
      expect(index, contains("status: \"failed\", failure_code: failureCode"));
      expect(index, contains('Never throws'));
    });
  });

  group('duplicate protection and bounded cost', () {
    test('a ready step is returned without generating', () {
      final readyCheck = index.indexOf('step.status === "ready"');
      final quota = index.indexOf('consumeAiQuota(');
      final gemini = index.indexOf('requestGeminiGuideline(');

      expect(readyCheck, greaterThan(-1));
      expect(readyCheck, lessThan(quota));
      expect(readyCheck, lessThan(gemini));
      expect(index, contains('reused: true'));
    });

    test('a concurrent request is refused while the step is claimed', () {
      expect(index, contains('step.status === "generating"'));
      expect(index, contains('already_generating'));
      expect(index, contains('GUIDELINE_LOCK_TIMEOUT_MS'));
    });

    test('the lock expires, because client cancellation proves nothing', () {
      expect(
        config,
        contains(
          'export const GUIDELINE_LOCK_TIMEOUT_MS = '
          'GUIDELINE_REQUEST_TIMEOUT_MS + 30_000',
        ),
      );
      expect(index, contains('Client cancellation never proves'));
    });

    test('the step is claimed before any money is spent', () {
      final claim = index.indexOf("status: \"generating\"");
      final quota = index.indexOf('consumeAiQuota(');
      expect(claim, greaterThan(-1));
      expect(claim, lessThan(quota));
    });

    test('at most one technical retry, and never for a refusal', () {
      expect(config, contains('GUIDELINE_MAXIMUM_ATTEMPTS = 2'));
      expect(client, contains('if (!transient) throw failure'));
      expect(client, contains('Only a technical failure'));
      expect(
        client,
        contains('AbortSignal.timeout(GUIDELINE_REQUEST_TIMEOUT_MS)'),
      );
    });

    test('quota is consumed per generation', () {
      expect(
        index,
        contains('consumeAiQuota(client, "tutorial_step_generation")'),
      );
      expect(index, contains('rate_limited'));
    });
  });

  group('security', () {
    test('the caller is authenticated and the gateway verifies the JWT', () {
      expect(RegExp(r'auth\.getUser\(\)').hasMatch(index), isTrue);
      expect(index, contains('authentication_required'));
      expect(index, isNot(contains('SERVICE_ROLE')));
      expect(
        RegExp(
          r'\[functions\.generate-tutorial-step-v4\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(source('supabase/config.toml')),
        isTrue,
      );
    });

    test('all source resolution goes through the shared resolver', () {
      expect(index, contains('resolveTutorialSource(client, userId,'));
      expect(
        index,
        isNot(contains('.from("analyses")')),
        reason: 'image resolution belongs to the resolver, not here',
      );
      expect(index, isNot(contains('makeup_kit_products')));
    });

    test('logs carry ids and metrics only', () {
      expect(index, contains('sanitizedResolutionLog(context)'));
      final completion = RegExp(
        r'\[generate-tutorial-step-v4\] Completed[\s\S]{0,220}',
      ).firstMatch(index)!.group(0)!;
      for (final leak in <String>[
        'productName',
        'colorHex',
        'storagePath',
        'prompt',
      ]) {
        expect(completion, isNot(contains(leak)));
      }
    });
  });

  group('nothing beyond the pilot was built', () {
    test('no AI visual reviewer and no cumulative images', () {
      for (final token in <String>['reviewer', 'cumulative', 'previousStep']) {
        expect(index.toLowerCase(), isNot(contains(token.toLowerCase())));
      }
    });

    test('the backend carries no UI concerns', () {
      // V4-12 added the tutorial UI, which is expected. What must stay true is
      // that the Edge Function knows nothing about it.
      expect(index, isNot(contains('Widget')));
      expect(index, isNot(contains('flutter')));
    });
  });
}
