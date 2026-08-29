import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the V2-5 guideline Edge Function to its security, isolation and
/// failure guarantees.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const dir = 'supabase/functions/generate-tutorial-v2-guideline';
  final index = source('$dir/index.ts');
  final client = source('$dir/gemini_client.ts');
  final prompt = source('$dir/prompt.ts');
  final migration = source(
    'supabase/migrations/20260826000300_tutorial_v2_guideline.sql',
  );

  group('V1 isolation', () {
    test('uses its own V2 slug', () {
      expect(
        RegExp(
          r'\[functions\.generate-tutorial-v2-guideline\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(source('supabase/config.toml')),
        isTrue,
      );
    });

    test('never calls the V1 tutorial functions or tables', () {
      for (final v1 in [
        'generate-tutorial-step',
        'plan-tutorial-geometry',
        'tutorial_steps',
        'tutorial_sessions',
      ]) {
        expect(
          RegExp('(?<!v2_)${RegExp.escape(v1)}').hasMatch(index),
          isFalse,
          reason: 'must not reference V1 object $v1',
        );
      }
    });

    test('does not import V1 geometry architecture', () {
      expect(index, isNot(contains('geometry')));
      expect(prompt, isNot(contains('polygon')));
      expect(prompt, isNot(contains('landmark')));
    });
  });

  group('model configuration', () {
    test('the guideline model is server-configurable', () {
      expect(index, contains('TUTORIAL_V2_GUIDELINE_MODEL'));
    });

    test('the default is the verified image model, not the text model', () {
      expect(index, contains('gemini-3.1-flash-image'));
      expect(index, isNot(contains('gemini-3.6-flash')));
    });

    test('it calls the image endpoint and reads image output', () {
      expect(client, contains('generativelanguage.googleapis.com/v1/models/'));
      expect(client, contains('inlineData'));
      expect(client, contains('GEMINI_NO_IMAGE_OUTPUT'));
    });

    test('a missing model is a configuration fault, not an outage', () {
      expect(client, contains('GEMINI_MODEL_NOT_FOUND'));
    });

    test('no model choice leaks into the Flutter bundle', () {
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

      expect(dartSources, isNot(contains('TUTORIAL_V2_GUIDELINE_MODEL')));
      expect(dartSources, isNot(contains('gemini-3.1-flash-image')));
      expect(dartSources, isNot(contains('GEMINI_API_KEY')));
    });
  });

  group('the client supplies no storage paths', () {
    test('only a session id and a step index are accepted', () {
      expect(index, contains('tutorialSessionId'));
      expect(index, contains('stepIndex'));
      for (final field in [
        'input.storagePath',
        'input.imagePath',
        'input.originalPath',
        'input.canonicalPath',
        'body.userId',
        'body.user_id',
      ]) {
        expect(index, isNot(contains(field)), reason: field);
      }
    });

    test('every source path is validated before download', () {
      expect(index, contains('isOwnedSourcePath'));
      expect(index, contains('unsafe_storage_path'));
    });

    test('the written path is re-validated for this exact step', () {
      expect(index, contains('isOwnedGuidelinePath'));
      expect(index, contains('targetPath.includes("/original/")'));
      expect(index, contains('targetPath === originalPath'));
      expect(index, contains('targetPath === canonicalPath'));
      expect(index, contains('targetPath === basePath'));
    });
  });

  group('ownership', () {
    test('identity comes from the JWT', () {
      expect(RegExp(r'auth\s*\.getUser\(\)').hasMatch(index), isTrue);
      expect(index, contains('authData.user.id'));
      expect(index, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    });

    test('session, step and analysis ownership are all checked', () {
      expect(index, contains('session.user_id !== userId'));
      expect(index, contains('step.user_id !== userId'));
      expect(index, contains('analysis_not_found'));
    });

    test('an incompatible plan version is refused', () {
      expect(index, contains('incompatible_plan_version'));
      expect(index, contains('MINIMUM_PLAN_VERSION'));
    });

    test('a session without a plan is refused', () {
      expect(index, contains('plan_not_ready'));
    });

    test('the final look step has no guideline to generate', () {
      expect(index, contains('final_step_has_no_guideline'));
    });

    test('a step whose spec disagrees with its row is refused', () {
      expect(index, contains('corrupt_step_spec'));
    });
  });

  group('idempotency and concurrency', () {
    test('a ready guideline is reused rather than regenerated', () {
      expect(index, contains("outcome === \"ready\""));
      expect(index, contains('reused: true'));
    });

    test('a concurrent request is rejected rather than duplicated', () {
      expect(index, contains("outcome === \"in_flight\""));
      expect(index, contains('guideline_already_generating'));
    });

    test('the claim is atomic and runs as the caller', () {
      expect(migration, contains('claim_tutorial_v2_guideline'));
      expect(migration, contains('security invoker'));
      expect(migration, isNot(contains('security definer\nas \$\$\ndeclare\n  v_claimed')));
      expect(migration, contains("guideline_status <> 'generating'"));
    });

    test('retries are bounded', () {
      expect(client, contains('maximumAttempts = 2'));
      expect(client, contains('totalBudgetMs'));
      expect(client, isNot(contains('while (true)')));
    });
  });

  group('failure behaviour', () {
    test('a failure marks the step failed rather than half-ready', () {
      expect(index, contains("guideline_status: \"failed\""));
      expect(index, contains('guideline_error:'));
      expect(index, contains('retry_count: claimedRetryCount + 1'));
    });

    test('a partially uploaded asset is removed', () {
      expect(index, contains('storage.from(bucket).remove([uploadedPath])'));
    });

    test('no fallback graphic is ever produced', () {
      // A fabricated guideline would need either drawing primitives or a
      // canned asset. Neither exists, and there are no hardcoded face
      // coordinates to draw against.
      for (final construct in [
        'svg',
        '<path',
        'canvas',
        'drawarrow',
        'assets/',
        'coordinates',
      ]) {
        expect(
          index.toLowerCase(),
          isNot(contains(construct)),
          reason: construct,
        );
      }

      // Exactly one code path marks a guideline ready, and it is the one that
      // just stored a validated generated image.
      expect(
        RegExp(r'guideline_status:\s*"ready"').allMatches(index).length,
        1,
      );
    });

    test('the quota claim is released when quota denies the request', () {
      expect(index, contains("guideline_status: \"pending\""));
    });
  });

  group('response validation', () {
    test('image bytes are validated before storage', () {
      final validation = source('$dir/image_validation.ts');
      expect(validation, contains('signatureMatches'));
      expect(validation, contains('minimumBytes'));
      expect(validation, contains('maximumBytes'));
      expect(validation, contains('image/png'));
      expect(validation, contains('image/jpeg'));
      expect(validation, contains('image/webp'));
    });
  });

  group('quota is a strict superset', () {
    test('every live operation survives', () {
      for (final operation in [
        'face_analysis',
        'makeup_recommendation',
        'kit_makeup_recommendation',
        'makeup_preview',
        'kit_makeup_preview',
        'tutorial_step',
        'tutorial_geometry_plan',
        'tutorial_v2_plan',
      ]) {
        expect(migration, contains("'$operation'"), reason: operation);
      }
    });

    test('the guideline operation is added', () {
      expect(migration, contains("('tutorial_v2_guideline', 80, 400)"));
      expect(
        source('supabase/functions/_shared/ai_quota.ts'),
        contains('"tutorial_v2_guideline"'),
      );
    });
  });

  group('storage layout', () {
    test('assets stay under the analysis prefix history deletion sweeps', () {
      expect(
        source('$dir/image_validation.ts'),
        contains(r'${userId}/analyses/${analysisId}/tutorial-v2/${sessionId}'),
      );
    });
  });
}
