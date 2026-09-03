import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// V4-QA-8 remediation: the canonical final preview can only be drawn by the
/// locked model.
///
/// A cross-language guard, following the pattern the rest of this suite uses:
/// these assert properties of the TypeScript source from the Dart suite, so the
/// invariant is checked by `flutter test` alone.
/// `_shared/final_preview_model_test.ts` covers the runtime behaviour from the
/// Deno side; both are run, and neither replaces the other.
///
/// The defect being locked out: both preview functions resolved their model as
/// `Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() || "gemini-3-pro-image"`. That is
/// correct only while the secret is set — unset it, rotate it, or deploy to a
/// fresh project, and every canonical preview silently changes model with no
/// code change, no failing test, and no log that looks wrong. Every tutorial
/// baseline measured against those previews would quietly stop meaning what it
/// claimed.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final lock = source('supabase/functions/_shared/final_preview_model.ts');
  final standard = source(
    'supabase/functions/generate-makeup-preview/index.ts',
  );
  final kit = source('supabase/functions/generate-kit-makeup-preview/index.ts');

  /// The two active V4 final-preview execution paths.
  final previewPaths = <String, String>{
    'generate-makeup-preview': standard,
    'generate-kit-makeup-preview': kit,
  };

  /// [source] with comments removed.
  ///
  /// The Pro model must not survive as *executable* configuration. Naming it in
  /// a comment that explains why it was removed is the opposite of the defect,
  /// and a test that forbade the explanation would push future readers toward
  /// deleting the history rather than keeping it.
  String executable(String source) => source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  group('the model is locked in code, not selected by environment', () {
    test('one definition, and it is the flash image model', () {
      expect(
        lock,
        contains('export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image"'),
      );
      expect(
        RegExp('"gemini-3.1-flash-image"').allMatches(lock).length,
        1,
        reason: 'one definition, so the two modes cannot drift apart',
      );
    });

    test('an absent or blank variable resolves to the locked model', () {
      // The behaviour the old fallback got wrong. Asserted on the source
      // because the Deno runtime is not available in this suite.
      expect(
        lock,
        contains('if (!configured || configured === FINAL_PREVIEW_MODEL)'),
      );
      expect(lock, contains('return null'));
    });

    test('a disagreeing variable fails closed rather than being obeyed', () {
      expect(lock, contains('must be unset or exactly'));
      expect(lock, contains('if (error !== null) throw new Error(error)'));
    });

    test('a misconfigured value is never echoed back', () {
      // The message names the expected model only, so a bad secret cannot be
      // read out of an API response.
      final message = RegExp(
        r'return `The image service is misconfigured[\s\S]*?`;',
      ).firstMatch(lock);
      expect(message, isNotNull);
      expect(message!.group(0)!.contains(r'${configured}'), isFalse);
    });
  });

  group('both preview paths resolve identically', () {
    for (final entry in previewPaths.entries) {
      test('${entry.key} uses the shared lock', () {
        expect(entry.value, contains('FINAL_PREVIEW_MODEL'));
        expect(
          entry.value,
          contains('../_shared/final_preview_model.ts'),
          reason: 'both modes must feed one final-preview architecture',
        );
        expect(entry.value, contains('const model = FINAL_PREVIEW_MODEL;'));
      });

      test('${entry.key} checks configuration before spending', () {
        final check = entry.value.indexOf(
          'finalPreviewModelConfigurationError()',
        );
        // lastIndexOf, so this finds the call site rather than the import that
        // sits above every line in the file.
        final request = entry.value.lastIndexOf('requestGemini');
        expect(check, greaterThan(-1));
        expect(request, greaterThan(-1));
        expect(
          check,
          lessThan(request),
          reason: 'a misconfigured deployment must not reach a paid call',
        );
      });

      test('${entry.key} no longer reads the model from the environment', () {
        expect(
          entry.value,
          isNot(contains('Deno.env.get("GEMINI_IMAGE_MODEL")')),
          reason: 'the environment validates the model, it does not select it',
        );
      });
    }
  });

  group('no Pro fallback and no model fallback chain', () {
    test('gemini-3-pro-image is executable nowhere in the preview flow', () {
      for (final entry in previewPaths.entries) {
        expect(
          executable(entry.value),
          isNot(contains('gemini-3-pro-image')),
          reason: '${entry.key} must have no Pro fallback',
        );
      }
      expect(
        executable(lock),
        isNot(contains('gemini-3-pro-image')),
        reason: 'the lock may explain the old fallback, never contain one',
      );
    });

    test('no retry ever swaps the model', () {
      // A Flash failure must never become a Pro attempt. The model is a
      // constant read once per request, so there is nothing for a retry to
      // vary — asserted rather than assumed.
      for (final entry in previewPaths.entries) {
        expect(
          RegExp('const model = ').allMatches(entry.value).length,
          1,
          reason: '${entry.key} must resolve the model exactly once',
        );
        for (final forbidden in <String>[
          'fallbackModel',
          'alternateModel',
          'retryModel',
          'modelFallback',
        ]) {
          expect(entry.value, isNot(contains(forbidden)));
        }
      }
    });

    test('the client cannot select a model', () {
      for (final entry in previewPaths.entries) {
        for (final forbidden in <String>[
          'input.model',
          'body.model',
          '.model as string',
        ]) {
          expect(
            entry.value,
            isNot(contains(forbidden)),
            reason: 'model authority stays server-side in ${entry.key}',
          );
        }
      }
    });
  });

  group('the rest of the AI configuration is untouched', () {
    final config = source('supabase/functions/_shared/tutorial_ai_config.ts');

    test('the tutorial renderer keeps its own locked model and resolution', () {
      expect(
        config,
        contains(
          'Deno.env.get("GEMINI_TUTORIAL_MODEL")?.trim() || '
          '"gemini-3.1-flash-image"',
        ),
      );
      expect(
        config,
        contains('export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const'),
      );
      expect(
        config,
        contains(
          'export const TUTORIAL_GUIDELINE_PROMPT_VERSION = '
          '"tutorial_guideline_v4_7"',
        ),
      );
    });

    test('the manifest analyzer prompt is unchanged', () {
      expect(
        source('supabase/functions/analyze-tutorial-manifest-v4/prompt.ts'),
        contains(
          'export const TUTORIAL_MANIFEST_PROMPT_VERSION = '
          '"tutorial_manifest_v4_1"',
        ),
      );
    });

    test('the final-preview prompts are unchanged', () {
      expect(
        source('supabase/functions/generate-makeup-preview/prompt.ts'),
        contains('MAKEUP_PREVIEW_PROMPT_VERSION'),
      );
      expect(
        source('supabase/functions/generate-kit-makeup-preview/prompt.ts'),
        contains('KIT_MAKEUP_PREVIEW_PROMPT_VERSION'),
      );
    });
  });
}
