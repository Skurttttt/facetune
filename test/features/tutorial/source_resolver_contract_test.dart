import 'dart:io';

import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/tutorial/domain/catalog/tutorial_category_mapping.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_category.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the server-authoritative source resolver.
///
/// Deno is not installed here, so `tutorial_source_resolver_test.ts` cannot be
/// executed. These assert the same security properties against the TypeScript
/// source, and pin the shared vocabulary to the Dart definitions.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final resolver = source(
    'supabase/functions/_shared/tutorial_source_resolver.ts',
  );
  final vocabulary = source(
    'supabase/functions/_shared/tutorial_vocabulary.ts',
  );
  final analyzerTypes = source(
    'supabase/functions/analyze-tutorial-manifest-v4/types.ts',
  );

  group('one shared vocabulary, no second copy', () {
    test('the shared file matches Dart exactly, in order', () {
      final block = RegExp(
        r'export const TUTORIAL_CATEGORIES = \[([\s\S]*?)\] as const;',
      ).firstMatch(vocabulary)!.group(1)!;
      final categories = RegExp(
        r'"([a-z_]+)"',
      ).allMatches(block).map((match) => match.group(1)!).toList();

      expect(
        categories,
        TutorialCategory.orderedVocabulary
            .map((category) => category.code)
            .toList(),
      );
    });

    test('the analyzer re-exports rather than redefining', () {
      expect(
        analyzerTypes,
        contains('from "../_shared/tutorial_vocabulary.ts"'),
      );
      expect(
        analyzerTypes,
        isNot(contains('export const TUTORIAL_CATEGORIES = [')),
        reason: 'a second definition would be free to drift',
      );
    });

    test('the standard-key mapping matches Dart, including many-to-one', () {
      final block = RegExp(
        r'STANDARD_KEY_TO_TUTORIAL[\s\S]*?\{([\s\S]*?)\n\};',
      ).firstMatch(vocabulary)!.group(1)!;
      final pairs = <String, String>{
        for (final match in RegExp(
          r'([A-Za-z_]+): "([a-z_]+)"',
        ).allMatches(block))
          match.group(1)!: match.group(2)!,
      };

      pairs.forEach((key, value) {
        expect(
          TutorialCategoryMapping.fromStandardRecommendationKey(key)?.code,
          value,
          reason: 'recommendation key "$key" must map identically',
        );
      });
      expect(pairs['lipstick'], 'lips');
      expect(pairs['lipGloss'], 'lips');
      expect(pairs['contour'], 'contour_bronzer');
      expect(pairs['highlight'], 'highlighter');
    });

    test('the inventory mapping still matches Dart', () {
      final block = RegExp(
        r'INVENTORY_TO_TUTORIAL[\s\S]*?\{([\s\S]*?)\n  \};',
      ).firstMatch(vocabulary)!.group(1)!;
      final pairs = <String, String>{
        for (final match in RegExp(r'([a-z_]+): "([a-z_]+)"').allMatches(block))
          match.group(1)!: match.group(2)!,
      };

      expect(pairs, hasLength(MakeupKitCategory.values.length));
      for (final kit in MakeupKitCategory.values) {
        expect(
          pairs[kit.code],
          TutorialCategoryMapping.fromKitCategory(kit).code,
        );
      }
    });
  });

  group('the client is never trusted', () {
    test('the request carries only a session id and a category', () {
      expect(
        resolver,
        contains(
          'export interface ResolveRequest {\n'
          '  tutorialSessionId: string;\n'
          '  category: string;\n'
          '}',
        ),
      );
    });

    test('no client-supplied model, resolution, or prompt is accepted', () {
      for (final forbidden in <String>[
        'request.model',
        'request.resolution',
        'request.promptVersion',
        'request.sourceMode',
        'request.imagePath',
        'request.productId',
      ]) {
        expect(
          resolver,
          isNot(contains(forbidden)),
          reason: '$forbidden would hand authority to the caller',
        );
      }
    });

    test('the user id comes from the caller-scoped client, not the body', () {
      expect(
        resolver,
        contains('[userId] must come'),
        reason: 'the contract is documented at the call boundary',
      );
      expect(resolver, contains('session.user_id !== userId'));
    });

    test('the category is re-validated against the vocabulary', () {
      expect(resolver, contains('asTutorialCategory(request.category)'));
      expect(resolver, contains('unsupported_category'));
    });
  });

  group('both images are mandatory and owner-proven', () {
    test('ownership is checked before either download', () {
      final originalCheck = resolver.indexOf(
        'isOwnedOriginalPath(originalPath',
      );
      final previewCheck = resolver.indexOf('isOwnedGeneratedPreviewPath(');
      final download = resolver.indexOf('.download(originalPath)');

      expect(originalCheck, greaterThan(-1));
      expect(previewCheck, greaterThan(originalCheck));
      expect(download, greaterThan(previewCheck));
    });

    test('a missing path fails rather than degrading to one image', () {
      expect(
        resolver,
        contains('if (!originalPath || !previewPath) throw notFound()'),
      );
      expect(resolver, contains('There is no single-image fallback'));
    });

    test('a failed download is a typed, retryable failure', () {
      expect(resolver, contains('source_image_unavailable'));
      expect(
        resolver,
        contains('originalDownload?.error || !originalDownload?.data'),
      );
      expect(
        resolver,
        contains('previewDownload?.error || !previewDownload?.data'),
      );
    });

    test('paths are carried, never signed URLs', () {
      expect(resolver, isNot(contains('createSignedUrl')));
      expect(resolver, contains('Never a signed URL'));
    });
  });

  group('manifest approval gates every request', () {
    test('only an accepted manifest proceeds', () {
      expect(resolver, contains("session.manifest_status !== \"accepted\""));
      expect(resolver, contains('manifest_not_accepted'));
      expect(resolver, contains('kit_preview_mismatch'));
    });

    test('the category must be included, and backed in kit mode', () {
      expect(
        resolver,
        contains(
          'item.presence === "present" && (!isKit || item.product_backed === true)',
        ),
      );
      expect(resolver, contains('category_not_included'));
    });

    test('includedCount drives Step X of N', () {
      expect(resolver, contains('includedCount: included.length'));
    });
  });

  group('product context comes from the immutable snapshot', () {
    test('live inventory is never queried', () {
      // The identifier appears once, in the comment explaining why it is never
      // read. What matters is that it is never queried.
      expect(
        resolver,
        isNot(contains('from("makeup_kit_products")')),
        reason: 'mutable inventory is not historical authority',
      );
      expect(resolver, contains('product_snapshot_json'));
    });

    test(
      'a kit category with no snapshot item refuses rather than invents',
      () {
        expect(resolver, contains('isKit && products.length === 0'));
        expect(resolver, contains('inventing a product'));
      },
    );

    test('Standard Mode resolves brand-neutral metadata only', () {
      expect(resolver, contains('recommendation_json'));
      expect(resolver, contains('standardPlan: isKit'));
      // The standard plan carries shade names and technique. "brand" appears
      // only in "brand-neutral"; what must be absent is a brand FIELD.
      expect(resolver, isNot(contains('brandName')));
      expect(resolver, isNot(contains('retailer')));
      expect(resolver, contains('Brand-neutral Standard Mode guidance'));
    });

    test('product context is documented as not overriding placement', () {
      expect(resolver, contains('the visual placement authority'));
      expect(
        resolver,
        contains('placement authority, which belongs to the canonical preview'),
      );
    });
  });

  group('errors and logs are sanitized', () {
    test('one opaque message covers every not-found case', () {
      expect(
        resolver,
        contains('Distinguishing "no such\n  // session" from "not yours"'),
      );
      expect(
        resolver,
        contains('"This tutorial step is no longer available."'),
      );
    });

    test('the log helper emits ids and counts only', () {
      final log = RegExp(
        r'export function sanitizedResolutionLog[\s\S]*?\n\}',
      ).firstMatch(resolver)!.group(0)!;

      for (final leak in <String>[
        'originalImage',
        'canonicalPreview',
        'faceAttributes',
        'productName',
        'colorHex',
        'styleCode',
      ]) {
        expect(
          log,
          isNot(contains(leak)),
          reason: '$leak must never reach a log line',
        );
      }
      expect(log, contains('context.stepId'));
      expect(log, contains('context.products.length'));
    });
  });

  group('the resolver stays in its lane', () {
    test('it performs no generation and calls no model', () {
      for (final token in <String>[
        'generativelanguage',
        'gemini',
        'GEMINI_API_KEY',
        'responseJsonSchema',
        'upload(',
      ]) {
        expect(
          resolver.toLowerCase(),
          isNot(contains(token.toLowerCase())),
          reason: 'generation belongs to a later phase',
        );
      }
    });

    test('it never uses a service-role client', () {
      expect(resolver, isNot(contains('SERVICE_ROLE')));
    });

    test('the resolver itself contains no generation logic', () {
      // The guideline renderer arrived in V4-9 and consumes this module. What
      // matters is that resolution and generation stay separate: the resolver
      // must not reach back into the function that calls it.
      expect(
        resolver,
        isNot(contains('generate-tutorial-step-v4')),
        reason: 'the resolver must not depend on its caller',
      );
      expect(resolver, isNot(contains('requestGeminiGuideline')));
    });
  });
}
