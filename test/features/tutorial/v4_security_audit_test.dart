import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The V4-14 security audit, expressed as executable assertions.
///
/// Asserts the properties against the TypeScript, SQL, and config that
/// implement them, from the Dart suite, so the audit runs under `flutter test`
/// alone. It proves the controls are present and wired; only a live system
/// proves they hold at runtime.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final config = source('supabase/config.toml');
  final migration = source(
    'supabase/migrations/20260830000100_tutorial_persistence.sql',
  );
  final resolver = source(
    'supabase/functions/_shared/tutorial_source_resolver.ts',
  );
  final aiConfig = source('supabase/functions/_shared/tutorial_ai_config.ts');
  final promptSafety = source('supabase/functions/_shared/prompt_safety.ts');
  final quota = source('supabase/functions/_shared/ai_quota.ts');
  final stepIndex = source(
    'supabase/functions/generate-tutorial-step-v4/index.ts',
  );
  final stepPrompt = source(
    'supabase/functions/generate-tutorial-step-v4/prompt.ts',
  );
  final manifestIndex = source(
    'supabase/functions/analyze-tutorial-manifest-v4/index.ts',
  );
  final manifestValidation = source(
    'supabase/functions/analyze-tutorial-manifest-v4/validation.ts',
  );
  final kitRecIndex = source(
    'supabase/functions/generate-kit-makeup-recommendation/index.ts',
  );
  final kitRecValidation = source(
    'supabase/functions/generate-kit-makeup-recommendation/validation.ts',
  );
  final kitRecPrompt = source(
    'supabase/functions/generate-kit-makeup-recommendation/prompt.ts',
  );

  const allFunctions = <String>[
    'analyze-face',
    'generate-makeup-recommendation',
    'generate-makeup-preview',
    'generate-kit-makeup-recommendation',
    'generate-kit-makeup-preview',
    'analyze-tutorial-manifest-v4',
    'generate-tutorial-step-v4',
    'delete-history-item',
  ];

  group('authentication and JWT', () {
    test('every Edge Function is JWT-verified at the gateway', () {
      for (final name in allFunctions) {
        expect(
          RegExp(
            '\\[functions\\.$name\\]\\s+verify_jwt\\s*=\\s*true',
          ).hasMatch(config),
          isTrue,
          reason: '$name must not be publicly invokable',
        );
      }
      expect(
        RegExp(r'verify_jwt\s*=\s*false').hasMatch(config),
        isFalse,
        reason: 'no function may opt out',
      );
    });

    test('the V4 functions re-verify the caller themselves', () {
      for (final index in <String>[manifestIndex, stepIndex]) {
        expect(RegExp(r'auth\.getUser\(\)').hasMatch(index), isTrue);
        expect(index, contains('authentication_required'));
        expect(index, contains('401'));
      }
    });

    test('no V4 code path uses a service-role key', () {
      for (final file in <String>[
        resolver,
        stepIndex,
        manifestIndex,
        manifestValidation,
      ]) {
        expect(file, isNot(contains('SERVICE_ROLE')));
        expect(file, isNot(contains('service_role')));
      }
    });
  });

  group('cross-user access', () {
    test('every new table enables RLS and revokes anon', () {
      for (final table in <String>[
        'look_product_snapshot_items',
        'tutorial_v4_sessions',
        'tutorial_v4_manifest_items',
        'tutorial_v4_steps',
        'tutorial_v4_step_products',
      ]) {
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
        );
        expect(
          migration,
          contains('revoke all on table public.$table from anon'),
        );
      }
      expect(migration, isNot(contains('disable row level security')));
    });

    test('the resolver re-checks ownership beyond RLS', () {
      expect(resolver, contains('session.user_id !== userId'));
      expect(
        resolver,
        contains('this is the explicit second check'),
        reason: 'a policy regression must not silently widen access',
      );
    });

    test('a foreign session is indistinguishable from a missing one', () {
      // Distinguishing them would let a caller probe for other accounts' ids.
      expect(resolver, contains('tutorial_source_not_found'));
      expect(resolver, contains('Distinguishing "no such'));
    });

    test('kit inventory is read through the caller-scoped client', () {
      expect(kitRecIndex, contains('userClient'));
      expect(kitRecIndex, contains('product.user_id !== authData.user.id'));
      expect(kitRecIndex, contains('ownership_mismatch'));
    });

    test('both images are ownership-proven segment by segment', () {
      expect(resolver, contains('isOwnedOriginalPath'));
      expect(resolver, contains('isOwnedGeneratedPreviewPath'));
      final ownership = source(
        'supabase/functions/_shared/storage_ownership.ts',
      );
      expect(ownership, contains('segments.length !== 5'));
      expect(ownership, contains('segments.length !== 6'));
    });
  });

  group('product ownership and invented IDs', () {
    test('an AI-named product must exist in the owned inventory', () {
      expect(kitRecValidation, contains('const byId = new Map('));
      expect(
        kitRecValidation,
        contains('if (!product) throw invalid("fabricated_product")'),
      );
      expect(kitRecValidation, contains('uuidPattern.test(productId)'));
    });

    test('a wrong-category or altered attribute is rejected', () {
      expect(kitRecValidation, contains('category !== product.category'));
      expect(kitRecValidation, contains('colorHex !== product.color_hex'));
      expect(kitRecValidation, contains('finish !== product.finish'));
      expect(kitRecValidation, contains('product_mismatch'));
    });

    test('the persisted snapshot is built from database rows', () {
      expect(
        kitRecIndex,
        contains(
          'const product = products.find((candidate) => candidate.id === id)!',
        ),
      );
      expect(kitRecIndex, contains('colorHex: product.color_hex'));
    });

    test('the tutorial never reads live inventory for history', () {
      expect(resolver, isNot(contains('from("makeup_kit_products")')));
      expect(resolver, contains('product_snapshot_json'));
    });
  });

  group('source mode and manifest tampering', () {
    test('source mode is derived from the table, never from the body', () {
      expect(
        manifestIndex,
        contains('sourceMode: hasStandard ? "standard" : "my_makeup_kit"'),
      );
      expect(manifestIndex, isNot(contains('input.sourceMode')));
      expect(resolver, isNot(contains('request.sourceMode')));
    });

    test('the database forbids a mode that disagrees with its lineage', () {
      expect(migration, contains('tutorial_v4_sessions_source_mode_lineage'));
      expect(migration, contains('tutorial_v4_sessions_mismatch_is_kit_only'));
    });

    test('a category outside the vocabulary never reaches a prompt', () {
      expect(resolver, contains('asTutorialCategory(request.category)'));
      expect(resolver, contains('unsupported_category'));
      expect(manifestValidation, contains('TUTORIAL_CATEGORY_SET.has(key)'));
    });

    test('an excluded category cannot be generated', () {
      expect(
        resolver,
        contains(
          'item.presence === "present" && (!isKit || item.product_backed === true)',
        ),
      );
      expect(resolver, contains('category_not_included'));
    });

    test('a fixed nine-step manifest is impossible', () {
      // Inclusion comes only from `present`, and the schema requires a verdict
      // for every category rather than defaulting them.
      expect(
        manifestValidation,
        contains('const visible = verdict.presence === "present"'),
      );
      expect(manifestValidation, contains('incomplete_manifest'));
    });
  });

  group('model, resolution, and prompt cannot be steered', () {
    test('the client supplies none of them', () {
      for (final forbidden in <String>[
        'input.model',
        'input.resolution',
        'input.promptVersion',
        'request.model',
        'request.resolution',
        'request.promptVersion',
      ]) {
        expect(
          stepIndex + manifestIndex + resolver,
          isNot(contains(forbidden)),
        );
      }
    });

    test('model and resolution are server constants', () {
      expect(aiConfig, contains('Deno.env.get("GEMINI_TUTORIAL_MODEL")'));
      expect(manifestIndex, contains('Deno.env.get("GEMINI_MANIFEST_MODEL")'));
      expect(
        aiConfig,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
    });

    test('no silent model fallback to a cheaper renderer', () {
      expect(
        aiConfig,
        isNot(contains('"gemini-3-pro-image"')),
        reason: 'the guideline renderer is distinct from the preview model',
      );
      final preview = source(
        'supabase/functions/generate-makeup-preview/index.ts',
      );
      expect(
        preview,
        isNot(contains('"gemini-3.1-flash-image"')),
        reason: 'the canonical preview must not fall back to Flash',
      );
    });

    test('kit mode never silently becomes Standard Mode', () {
      for (final token in <String>[
        'generate-makeup-recommendation',
        'makeupRecommendationPrompt',
      ]) {
        expect(kitRecIndex + kitRecPrompt, isNot(contains(token)));
      }
      expect(kitRecIndex, contains('empty_kit'));
    });
  });

  group('prompt injection from user-entered metadata', () {
    test('a sanitizer exists and bounds length', () {
      expect(promptSafety, contains('export function sanitizePromptText'));
      expect(promptSafety, contains('MAXIMUM_PROMPT_TEXT_LENGTH = 60'));
      expect(promptSafety, contains(r'/[\x00-\x1F\x7F]/g'));
    });

    test('instruction-shaped labels are dropped, not embedded', () {
      expect(promptSafety, contains('INSTRUCTION_MARKERS'));
      for (final marker in <String>['"ignore"', '"disregard"', '"you are"']) {
        expect(promptSafety, contains(marker));
      }
    });

    test('the guideline prompt sanitizes the shade label', () {
      expect(
        stepPrompt,
        contains('sanitizePromptText(product.colorLabel) ?? "an owned shade"'),
      );
    });

    test('the kit recommendation prompt sanitizes both free-text fields', () {
      expect(
        kitRecPrompt,
        contains('sanitizePromptText(product.product_name)'),
      );
      expect(kitRecPrompt, contains('sanitizePromptText(product.color_label)'));
    });

    test('the manifest supporting context carries no free user text', () {
      // Only controlled category codes reach it.
      expect(manifestIndex, contains('[...backed].join(", ")'));
      expect(manifestIndex, isNot(contains('product_name')));
      expect(manifestIndex, isNot(contains('color_label')));
    });
  });

  group('duplicate and repeat cost abuse', () {
    test('a ready step short-circuits before quota and the model', () {
      final ready = stepIndex.indexOf('step.status === "ready"');
      final quotaAt = stepIndex.indexOf('consumeAiQuota(');
      final gemini = stepIndex.indexOf('requestGeminiGuideline(');
      expect(ready, greaterThan(-1));
      expect(ready, lessThan(quotaAt));
      expect(ready, lessThan(gemini));
    });

    test('the step claim is a compare-and-set, not a blind write', () {
      // Without the status predicate, two requests that both read `pending`
      // would both claim and both pay.
      expect(stepIndex, contains('.eq("status", (step.status as string)'));
      expect(
        stepIndex,
        contains('if (!Array.isArray(claimed) || claimed.length === 0)'),
      );
      expect(stepIndex, contains('already_generating'));
    });

    test('one step has a hard lifetime redraw ceiling', () {
      expect(aiConfig, contains('MAXIMUM_STEP_ATTEMPTS = 5'));
      expect(stepIndex, contains('if (attempt > MAXIMUM_STEP_ATTEMPTS)'));
      expect(stepIndex, contains('step_attempt_limit'));
    });

    test('the manifest is reused before quota is touched', () {
      final reuse = manifestIndex.indexOf('.from("tutorial_v4_sessions")');
      final quotaAt = manifestIndex.indexOf('consumeAiQuota(');
      expect(reuse, greaterThan(-1));
      expect(reuse, lessThan(quotaAt));
    });

    test('both V4 operations consume a server-enforced quota', () {
      expect(
        manifestIndex,
        contains('consumeAiQuota(client, "tutorial_manifest_analysis")'),
      );
      expect(
        stepIndex,
        contains('consumeAiQuota(client, "tutorial_step_generation")'),
      );
      expect(quota, contains('"tutorial_manifest_analysis"'));
      expect(quota, contains('"tutorial_step_generation"'));
      expect(migration, contains("('tutorial_manifest_analysis', 20, 80)"));
      expect(migration, contains("('tutorial_step_generation', 90, 360)"));
    });

    test('quota fails closed', () {
      expect(quota, contains('Fails closed'));
      expect(migration, contains("'unsupported_operation'"));
    });

    test('retries are bounded and never retry a refusal', () {
      final client = source(
        'supabase/functions/generate-tutorial-step-v4/gemini_client.ts',
      );
      expect(aiConfig, contains('GUIDELINE_MAXIMUM_ATTEMPTS = 2'));
      expect(client, contains('if (!transient) throw failure'));
    });
  });

  group('privacy of logs and derived assets', () {
    test('the resolution log carries ids and counts only', () {
      final log = RegExp(
        r'export function sanitizedResolutionLog[\s\S]*?\n\}',
      ).firstMatch(resolver)!.group(0)!;
      for (final leak in <String>[
        'originalImage',
        'canonicalPreview',
        'faceAttributes',
        'productName',
        'colorHex',
      ]) {
        expect(log, isNot(contains(leak)));
      }
    });

    test('no function logs image bytes or base64', () {
      for (final file in <String>[stepIndex, manifestIndex, resolver]) {
        expect(file, isNot(contains('console.log(encodeBase64')));
        expect(file, isNot(contains('console.log(generated.bytes')));
      }
    });

    test('signed URLs are never minted or stored server-side', () {
      expect(resolver, isNot(contains('createSignedUrl')));
      expect(stepIndex, isNot(contains('createSignedUrl')));
      expect(resolver, contains('Never a signed URL'));
    });

    test('the bucket stays private and no policy is widened', () {
      expect(migration, isNot(contains('storage.buckets')));
      final bucket = source(
        'supabase/migrations/20260807000200_private_face_images.sql',
      );
      expect(bucket, contains("'face-images',\n  false,"));
    });

    test('a guideline can never overwrite the selfie or the preview', () {
      expect(stepIndex, contains('storagePath.includes("/original/")'));
      expect(stepIndex, contains('storagePath.includes("/generated/")'));
      expect(migration, contains('tutorial_v4_steps_guideline_path_owned'));
    });
  });

  group('partial writes and stale state', () {
    test('a failed persist removes the uploaded object', () {
      expect(stepIndex, contains('.remove([storagePath])'));
      expect(stepIndex, contains('unreferenced'));
    });

    test('a claimed step is released on every failure path', () {
      expect(stepIndex, contains('async function releaseStep'));
      for (final code in <String>[
        'rate_limited',
        'unchanged_guideline',
        'storage_upload_failed',
        'persistence_failed',
      ]) {
        expect(
          stepIndex,
          contains('releaseStep(client, context.stepId, "$code")'),
        );
      }
    });

    test('a ready step must carry its image and full provenance', () {
      expect(migration, contains('tutorial_v4_steps_ready_is_complete'));
    });

    test('a stale manifest version forces re-analysis', () {
      expect(
        manifestIndex,
        contains(
          'existing.manifest_prompt_version === TUTORIAL_MANIFEST_PROMPT_VERSION',
        ),
      );
      expect(
        manifestIndex,
        contains(
          'existing.manifest_schema_version === TUTORIAL_MANIFEST_SCHEMA_VERSION',
        ),
      );
    });
  });
}
