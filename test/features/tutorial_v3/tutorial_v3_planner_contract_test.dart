import 'dart:io';

import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_category_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_graphic.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the server-side planner to the client-side V3 domain.
///
/// The Edge Function and the Dart domain are edited independently and never
/// import each other, so a vocabulary that drifts between them would surface
/// only as a decode failure on a real user's tutorial. These tests read the
/// actual TypeScript and SQL and compare them against the actual Dart enums.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const functionDir = 'supabase/functions/plan-tutorial-v3';
  final types = source('$functionDir/types.ts');
  final schema = source('$functionDir/schema.ts');
  final prompt = source('$functionDir/prompt.ts');
  final index = source('$functionDir/index.ts');
  final validation = source('$functionDir/validation.ts');
  final quotaModule = source('supabase/functions/_shared/ai_quota.ts');
  final quotaMigration = source(
    'supabase/migrations/20260827000200_tutorial_v3_planner.sql',
  );

  /// The migration that most recently redefines the quota vocabulary.
  ///
  /// Resolved rather than hard-coded: whichever migration owns the constraint
  /// today is the one the shared TypeScript union has to match, so a later
  /// phase adding an operation cannot leave this test comparing against a
  /// superseded definition.
  final currentQuotaMigration = (Directory(
    '${root.path}${Platform.pathSeparator}supabase'
    '${Platform.pathSeparator}migrations',
  ).listSync().whereType<File>().where((file) => file.path.endsWith('.sql')).toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      .lastWhere(
        (file) =>
            file.readAsStringSync().contains('ai_usage_events_operation_valid'),
      )
      .readAsStringSync();

  /// String literals inside the `{...}` or `[...]` block following [anchor].
  Set<String> literalsAfter(String text, String anchor, String open) {
    final start = text.indexOf(anchor);
    expect(start, greaterThan(-1), reason: 'missing $anchor');
    final from = text.indexOf(open, start);
    final close = text.indexOf(open == '{' ? '}' : ']', from);
    return RegExp(
      '"([a-z_0-9]+)"',
    ).allMatches(text.substring(from, close)).map((m) => m.group(1)!).toSet();
  }

  group('category vocabulary', () {
    test('the planner ranks exactly the domain categories', () {
      final ranked = RegExp(r'^\s{2}([a-z_]+): \d+,$', multiLine: true)
          .allMatches(types)
          .map((match) => match.group(1)!)
          .toSet();

      expect(
        ranked,
        TutorialV3Category.values.map((category) => category.code).toSet(),
      );
    });

    test('the canonical order matches the domain catalog', () {
      final ordered =
          RegExp(r'^\s{2}([a-z_]+): (\d+),$', multiLine: true)
              .allMatches(types)
              .map((match) => MapEntry(match.group(1)!, int.parse(match.group(2)!)))
              .toList()
            ..sort((a, b) => a.value.compareTo(b.value));

      expect(
        ordered.map((entry) => entry.key).toList(),
        TutorialV3CategoryCatalog.canonicalOrder
            .map((category) => category.code)
            .toList(),
      );
    });

    test('the response schema offers exactly those categories', () {
      final enumerated = literalsAfter(schema, 'enum: [', '[');
      expect(
        enumerated,
        TutorialV3Category.values.map((category) => category.code).toSet(),
      );
    });
  });

  group('guideline marks', () {
    test('the planner allows exactly the domain graphics', () {
      expect(
        literalsAfter(types, 'ALLOWED_GRAPHICS', '['),
        TutorialV3GuidelineGraphic.values.map((g) => g.code).toSet(),
      );
    });

    test('the schema constrains graphics to the same set', () {
      final start = schema.indexOf('graphics');
      final enumStart = schema.indexOf('enum: [', start);
      final close = schema.indexOf(']', enumStart);
      final enumerated = RegExp('"([a-z0-9_]+)"')
          .allMatches(schema.substring(enumStart, close))
          .map((m) => m.group(1)!)
          .toSet();

      expect(
        enumerated,
        TutorialV3GuidelineGraphic.values.map((g) => g.code).toSet(),
      );
    });
  });

  group('style and source vocabulary', () {
    test('the planner allows exactly the catalog styles', () {
      expect(
        literalsAfter(types, 'ALLOWED_STYLES', '['),
        MakeupStyleCatalog.styles.map((style) => style.code).toSet(),
      );
    });

    test('source modes match the domain codes', () {
      final declared = RegExp(r'export type SourceMode = ([^;]+);')
          .firstMatch(types)!
          .group(1)!;
      for (final mode in TutorialV3SourceMode.values) {
        expect(
          declared,
          contains('"${mode.code}"'),
          reason: 'missing ${mode.code}',
        );
      }
      // V2 used `standard_recommendation`; V3 must not inherit that spelling.
      expect(declared.contains('standard_recommendation'), isFalse);
    });
  });

  group('attribute scoping agrees with the catalog', () {
    test('every category maps to the same attribute set', () {
      final block = types.substring(
        types.indexOf('CATEGORY_ATTRIBUTES'),
        types.indexOf('export const ALLOWED_ATTRIBUTES'),
      );

      for (final category in TutorialV3Category.values) {
        // `final_look` scopes to nothing and is written `new Set<string>()`,
        // so the array form is optional.
        final match = RegExp(
          '${category.code}: new Set(?:<string>)?\\((?:\\[([^\\]]*)\\])?\\)',
        ).firstMatch(block);
        expect(match, isNotNull, reason: 'no scope for ${category.code}');

        final declared = RegExp('"([a-z0-9_]+)"')
            .allMatches(match!.group(1) ?? '')
            .map((m) => m.group(1)!)
            .toSet();
        expect(
          declared,
          TutorialV3CategoryCatalog.relevantAttributes(
            category,
          ).map((attribute) => attribute.code).toSet(),
          reason: 'scope drift for ${category.code}',
        );
      }
    });

    test('hair and eye colour are never sent to the planner', () {
      expect(index.contains('hair_color'), isFalse);
      expect(index.contains('eye_color'), isFalse);
    });
  });

  group('plan version and target reference', () {
    test('the planner writes plan version 3', () {
      expect(validation, contains('plan_version: 3'));
      expect(index, contains('const supportedPlanVersion = 3'));
    });

    test('the planner uses only the supported target reference mode', () {
      expect(
        validation,
        contains('target_reference_mode: "full_canonical_preview"'),
      );
      expect(types, contains('FULL_CANONICAL_PREVIEW = "full_canonical_preview"'));
    });
  });

  group('no result generation is representable', () {
    test('no planner file mentions a per-step result', () {
      for (final entry in {
        'types.ts': types,
        'schema.ts': schema,
        'validation.ts': validation,
      }.entries) {
        final offending = RegExp(
          r'result_status|result_image|resultStatus|resultImage',
        ).allMatches(entry.value);
        expect(
          offending,
          isEmpty,
          reason: '${entry.key} must not model a step result',
        );
      }
    });

    test('the prompt forbids cumulative generation explicitly', () {
      expect(
        prompt,
        contains('Do not describe generating, rendering or previewing'),
      );
      expect(
        prompt,
        contains("Do not make any step depend on a previous step's image"),
      );
      expect(prompt, contains('Do not produce a new final look'));
    });
  });

  group('model configuration', () {
    test('the planner model is server-configurable', () {
      expect(index, contains('Deno.env.get("TUTORIAL_V3_PLANNER_MODEL")'));
    });

    test('it does not reuse the image model variable', () {
      // GEMINI_IMAGE_MODEL belongs to the premium preview pipeline. Sharing it
      // would make a V3 model change silently alter the stable preview.
      expect(index.contains('GEMINI_IMAGE_MODEL'), isFalse);
    });

    test('a missing model surfaces as configuration, not an outage', () {
      final client = source('$functionDir/gemini_client.ts');
      expect(client, contains('GEMINI_MODEL_NOT_FOUND'));
    });

    test('the API key is only ever read server-side', () {
      expect(index, contains('requiredEnvironment("GEMINI_API_KEY")'));
      final libDir = Directory(
        '${root.path}${Platform.pathSeparator}lib',
      );
      final leaked = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains('GEMINI_API_KEY'));
      expect(leaked, isEmpty, reason: 'the Gemini key must never reach Flutter');
    });
  });

  group('quota superset', () {
    // Every operation live before this migration, per the V3-0.5 recovery.
    const previouslyLive = <String>[
      'face_analysis',
      'makeup_recommendation',
      'kit_makeup_recommendation',
      'makeup_preview',
      'kit_makeup_preview',
      'tutorial_step',
      'tutorial_geometry_plan',
      'tutorial_v2_plan',
    ];

    test('the migration preserves every live operation', () {
      for (final operation in previouslyLive) {
        expect(
          quotaMigration,
          contains("'$operation'"),
          reason: 'dropping $operation would break a deployed function',
        );
      }
    });

    test('the migration adds the V3 planner operation with a limit', () {
      expect(quotaMigration, contains("'tutorial_v3_plan'"));
      expect(quotaMigration, contains("('tutorial_v3_plan', 30, 150)"));
    });

    test('the constraint and the function agree', () {
      final constraint = RegExp(r'check \(operation in \(([^)]*)\)\)')
          .firstMatch(quotaMigration)!
          .group(1)!;
      final constraintOps = RegExp("'([a-z0-9_]+)'")
          .allMatches(constraint)
          .map((m) => m.group(1)!)
          .toSet();

      final valuesBlock = quotaMigration.substring(
        quotaMigration.indexOf('from (values'),
        quotaMigration.indexOf('as limits(operation'),
      );
      final functionOps = RegExp(r"\('([a-z0-9_]+)', \d+, \d+\)")
          .allMatches(valuesBlock)
          .map((m) => m.group(1)!)
          .toSet();

      expect(constraintOps, functionOps);
      expect(constraintOps, containsAll(previouslyLive));
      expect(constraintOps, contains('tutorial_v3_plan'));
    });

    test('the shared TypeScript union matches the current SQL exactly', () {
      final union = quotaModule.substring(
        quotaModule.indexOf('export type AiOperation'),
        quotaModule.indexOf(';', quotaModule.indexOf('export type AiOperation')),
      );
      final unionOps = RegExp('"([a-z0-9_]+)"')
          .allMatches(union)
          .map((m) => m.group(1)!)
          .toSet();

      final constraint = RegExp(r'check \(operation in \(([^)]*)\)\)')
          .firstMatch(currentQuotaMigration)!
          .group(1)!;
      final constraintOps = RegExp("'([a-z0-9_]+)'")
          .allMatches(constraint)
          .map((m) => m.group(1)!)
          .toSet();

      expect(unionOps, constraintOps);
    });

    test('the function requests the operation it registered', () {
      expect(index, contains('consumeAiQuota(client, "tutorial_v3_plan")'));
    });

    test('it touches no table other than the quota events', () {
      expect(quotaMigration.contains('tutorial_v3_sessions'), isFalse);
      expect(quotaMigration.contains('tutorial_v3_steps'), isFalse);
      expect(quotaMigration.contains('drop table'), isFalse);
    });
  });

  group('server-verified inputs', () {
    test('the session is the only client input', () {
      expect(index, contains('requestedSessionId'));
      expect(index, contains('uuidPattern.test(sessionId)'));
    });

    test('the recommendation is read by the session, not the caller', () {
      expect(index, contains('session.kit_recommendation_id'));
      expect(index, contains('session.recommendation_id'));
      expect(index, contains('recommendation_mismatch'));
    });

    test('kit ownership is re-verified against live inventory', () {
      expect(index, contains("from(\"makeup_kit_products\")"));
      expect(index, contains('inventory_changed'));
    });

    test('the canonical preview path is checked before download', () {
      expect(index, contains('unsafe_storage_path'));
      expect(index, contains("canonicalPath.includes(\"/original/\")"));
    });

    test('the caller JWT drives every read, so RLS applies', () {
      expect(index, contains('SUPABASE_ANON_KEY'));
      expect(index.contains('SERVICE_ROLE'), isFalse);
    });
  });
}
