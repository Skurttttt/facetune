import 'dart:io';

import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_category_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/catalog/tutorial_v3_geometry_catalog.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_geometry.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the geometry mapper Edge Function to the client-side V3 domain.
///
/// The function and the Dart domain never import each other, so a vocabulary
/// that drifts between them surfaces only as a rejected document on a real
/// user's tutorial. These tests read the actual TypeScript and compare it
/// against the actual Dart catalogs.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const functionDir = 'supabase/functions/map-tutorial-v3-guideline-geometry';
  final types = source('$functionDir/types.ts');
  final index = source('$functionDir/index.ts');
  final prompt = source('$functionDir/prompt.ts');
  final schema = source('$functionDir/schema.ts');
  final geminiClient = source('$functionDir/gemini_client.ts');
  final validation = source('$functionDir/validation.ts');
  final config = source('supabase/config.toml');

  /// The string literals inside the `[...]` or `{...}` block after [anchor].
  List<String> literalsAfter(String text, String anchor, String open) {
    final start = text.indexOf(anchor);
    expect(start, greaterThan(-1), reason: 'missing $anchor');
    final from = text.indexOf(open, start);
    final close = text.indexOf(open == '[' ? ']' : '}', from);
    return RegExp('"([a-z0-9_]+)"')
        .allMatches(text.substring(from, close))
        .map((match) => match.group(1)!)
        .toList();
  }

  /// TypeScript with `//` and `/* */` comments removed.
  ///
  /// The files deliberately EXPLAIN which constructs are banned, so a
  /// "must not contain" assertion has to read the executable code rather than
  /// the prose describing the prohibition.
  String stripComments(String code) => code
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .map((line) {
        final comment = line.indexOf('//');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  group('vocabulary agreement with the domain', () {
    test('the schema version matches the Dart constant', () {
      expect(
        types,
        contains('GEOMETRY_SCHEMA_VERSION = $tutorialV3GeometrySchemaVersion'),
      );
    });

    test('the coordinate space matches the Dart constant', () {
      expect(
        types,
        contains('COORDINATE_SPACE = "$tutorialV3CoordinateSpace"'),
      );
    });

    test('primitive kinds match TutorialV3PrimitiveKind exactly', () {
      final declared = RegExp('"([a-z_]+)"')
          .allMatches(
            types.substring(
              types.indexOf('export type PrimitiveKind'),
              types.indexOf(';', types.indexOf('export type PrimitiveKind')),
            ),
          )
          .map((match) => match.group(1)!)
          .toSet();
      expect(
        declared,
        TutorialV3PrimitiveKind.values.map((kind) => kind.code).toSet(),
      );
    });

    test('roles match TutorialV3GeometryRole exactly', () {
      final declared = RegExp('"([a-z_]+)"')
          .allMatches(
            types.substring(
              types.indexOf('export type GeometryRole'),
              types.indexOf(';', types.indexOf('export type GeometryRole')),
            ),
          )
          .map((match) => match.group(1)!)
          .toSet();
      expect(
        declared,
        TutorialV3GeometryRole.values.map((role) => role.code).toSet(),
      );
    });

    test('role to kind agrees with the Dart catalog', () {
      for (final role in TutorialV3GeometryRole.values) {
        expect(
          literalsAfter(types, '  ${role.code}: [', '[').toSet(),
          TutorialV3GeometryCatalog.kindsFor(
            role,
          ).map((kind) => kind.code).toSet(),
          reason: 'role ${role.code} drifted',
        );
      }
    });

    test('category to role agrees with the Dart catalog', () {
      final block = types.substring(
        types.indexOf('export const CATEGORY_ROLES'),
      );
      for (final category in TutorialV3Category.values) {
        expect(
          literalsAfter(block, '  ${category.code}: [', '[').toSet(),
          TutorialV3GeometryCatalog.rolesFor(
            category,
          ).map((role) => role.code).toSet(),
          reason: 'category ${category.code} drifted',
        );
      }
    });

    test('the final look is offered no geometry vocabulary at all', () {
      expect(
        TutorialV3GeometryCatalog.rolesFor(TutorialV3Category.finalLook),
        isEmpty,
      );
      expect(types, contains('final_look: [],'));
    });

    test('complexity limits match the Dart catalog', () {
      const expected = {
        'maxPrimitives': TutorialV3GeometryCatalog.maxPrimitives,
        'minRegionVertices': TutorialV3GeometryCatalog.minRegionVertices,
        'maxRegionVertices': TutorialV3GeometryCatalog.maxRegionVertices,
        'minPolylineVertices': TutorialV3GeometryCatalog.minPolylineVertices,
        'maxPolylineVertices': TutorialV3GeometryCatalog.maxPolylineVertices,
        'minRadius': TutorialV3GeometryCatalog.minRadius,
        'maxRadius': TutorialV3GeometryCatalog.maxRadius,
        'minArrowLength': TutorialV3GeometryCatalog.minArrowLength,
      };
      for (final entry in expected.entries) {
        expect(
          types,
          contains('${entry.key}: ${entry.value},'),
          reason: '${entry.key} drifted from the Dart catalog',
        );
      }
    });

    test('the scoped attributes match the category catalog', () {
      final block = types.substring(
        types.indexOf('export const SCOPED_ATTRIBUTES'),
      );
      for (final category in TutorialV3Category.values) {
        if (category == TutorialV3Category.finalLook) continue;
        expect(
          literalsAfter(block, '  ${category.code}: [', '[').toSet(),
          TutorialV3CategoryCatalog.relevantAttributes(
            category,
          ).map((attribute) => attribute.code).toSet(),
          reason: 'category ${category.code} scope drifted',
        );
      }
    });

    test('source modes match TutorialV3SourceMode exactly', () {
      final declared = RegExp('"([a-z_]+)"')
          .allMatches(
            types.substring(
              types.indexOf('export type SourceMode'),
              types.indexOf(';', types.indexOf('export type SourceMode')),
            ),
          )
          .map((match) => match.group(1)!)
          .toSet();
      expect(
        declared,
        TutorialV3SourceMode.values.map((mode) => mode.code).toSet(),
      );
    });
  });

  group('the client supplies identifiers only', () {
    test('nothing but the session and step index is read from the body', () {
      expect(index, contains('body.sessionId'));
      expect(index, contains('body.stepIndex'));
      // Everything the server must own is explicitly refused rather than
      // ignored, so a client that sends it gets an error instead of a
      // silently different tutorial.
      for (final field in [
        'prompt',
        'stepSpec',
        'category',
        'faceAttributes',
        'selectedStyle',
        'analysisId',
        'storagePath',
        'geometry',
        'schemaVersion',
        'planVersion',
        'productId',
      ]) {
        expect(
          index,
          contains('"$field"'),
          reason: '$field must be explicitly refused',
        );
      }
    });

    test('the session, step and analysis are resolved from the database', () {
      expect(index, contains('tutorial_v3_sessions'));
      expect(index, contains('tutorial_v3_steps'));
      expect(index, contains('analyses'));
      expect(index, contains('step_spec_json'));
      expect(index, contains('original_image_path'));
    });

    test('the persisted Step Spec is the only instruction authority', () {
      // The prompt is built from the stored spec, so the client cannot steer
      // the mapper by sending different text.
      expect(index, contains('geometryMapperPrompt('));
      expect(prompt, contains('GEOMETRY_PROMPT_VERSION'));
      expect(index, contains('GEOMETRY_PROMPT_VERSION'));
    });

    test('Kit ownership is re-verified against live inventory', () {
      expect(index, contains('makeup_kit_products'));
      expect(index, contains('inventory_changed'));
      // The step's own snapshot is checked too, not just a client-supplied or
      // recommendation-level id set.
      expect(index, contains('product_snapshot_json'));
    });
  });

  group('no image is requested, sent or accepted', () {
    test('exactly one image goes to the model: the original selfie', () {
      expect(geminiClient, contains('Exactly one image: the original selfie'));
      expect(
        RegExp('inlineData').allMatches(geminiClient).length,
        greaterThan(0),
      );
      // The canonical preview is a session-level column; the mapper never
      // reads it.
      expect(index.contains('canonical_image_path'), isFalse);
      expect(index.contains('canonical_generated_image_id'), isFalse);
      expect(index.contains('canonical_kit_generated_image_id'), isFalse);
    });

    test('image bytes in the response are a configuration fault', () {
      expect(geminiClient, contains('unexpected_image_output'));
    });

    test('the mapper never touches the image model variable', () {
      expect(index, contains('TUTORIAL_V3_GEOMETRY_MODEL'));
      for (final banned in [
        'GEMINI_IMAGE_MODEL',
        'TUTORIAL_V3_GUIDELINE_MODEL',
        'gemini-3.1-flash-image',
      ]) {
        expect(
          '$index$geminiClient'.contains(banned),
          isFalse,
          reason: '$banned must never be used by the geometry mapper',
        );
      }
    });

    test('storage is read from, never written to', () {
      // The selfie download is the only storage call. Nothing is uploaded, so
      // there is no generated object for a step to own or overwrite.
      expect(index, contains('client.storage'));
      expect(index.contains('.upload('), isFalse);
      expect(index.contains('.remove('), isFalse);
      expect(index.contains('createSignedUploadUrl'), isFalse);
    });
  });

  group('response schema stays inside the proven construct set', () {
    test('it uses no construct Gemini rejected in V3-6R', () {
      // V3-6R: `type: "integer"`, integer enums, minimum/maximum and
      // minItems/maxItems all returned 400 INVALID_ARGUMENT. Range and count
      // enforcement therefore lives in the validators, not the schema.
      final code = stripComments(schema);
      for (final banned in [
        '"integer"',
        'minimum',
        'maximum',
        'minItems',
        'maxItems',
      ]) {
        expect(
          code.contains(banned),
          isFalse,
          reason: '$banned makes Gemini reject the request',
        );
      }
    });

    test('the validator enforces what the schema cannot', () {
      expect(validation, contains('LIMITS.maxPrimitives'));
      expect(validation, contains('LIMITS.minRadius'));
      expect(validation, contains('LIMITS.minArrowLength'));
      expect(validation, contains('outside the normalized'));
    });

    test('a rejected document is never repaired', () {
      final code = stripComments(validation);
      for (final banned in ['clamp', 'Math.min(', 'Math.max(']) {
        expect(
          code.contains(banned),
          isFalse,
          reason: 'coordinates must be rejected, never coerced',
        );
      }
    });
  });

  group('lifecycle and quota', () {
    test('the function is registered with JWT verification on', () {
      expect(
        config,
        contains(
          '[functions.map-tutorial-v3-guideline-geometry]\nverify_jwt = true',
        ),
      );
    });

    test('it spends its own quota operation, not the planner\'s', () {
      expect(index, contains('consumeAiQuota(client, "tutorial_v3_geometry")'));
      expect(index.contains('"tutorial_v3_plan"'), isFalse);
    });

    test('quota is spent only after the claim succeeds', () {
      // Reuse returns before any quota is consumed, so revisiting a finished
      // tutorial costs nothing.
      expect(
        index.indexOf('"claim_tutorial_v3_geometry"'),
        lessThan(index.indexOf('consumeAiQuota(client,')),
      );
    });

    test('a claim is released rather than left stuck on failure', () {
      expect(index, contains('releaseClaim'));
      expect(index, contains('geometry_status'));
    });

    test('persisting is guarded by the claim it made', () {
      expect(index, contains('.eq("geometry_status", "generating")'));
    });

    test('the schema version the build understands is sent with the claim', () {
      expect(index, contains('p_schema_version'));
      expect(index, contains('GEOMETRY_SCHEMA_VERSION'));
    });
  });

  group('the Flutter client matches the function it calls', () {
    final dataSource = source(
      'lib/features/tutorial_v3/data/data_sources/'
      'tutorial_v3_function_data_source.dart',
    );

    test('it invokes the function directories that actually exist', () {
      expect(
        dataSource,
        contains("geometryFunction = 'map-tutorial-v3-guideline-geometry'"),
      );
      expect(dataSource, contains("planFunction = 'plan-tutorial-v3'"));
      expect(
        Directory(
          '${root.path}${Platform.pathSeparator}'
          '${functionDir.replaceAll('/', Platform.pathSeparator)}',
        ).existsSync(),
        isTrue,
      );
    });

    test('the geometry request body is exactly two identifiers', () {
      // The server refuses sixteen other fields outright. This is the other
      // half of that contract: the client has no code path that could send
      // one, so the refusal is a backstop rather than the only defence.
      final body = RegExp(
        r"<String, Object\?>\{'sessionId': sessionId, 'stepIndex': stepIndex\}",
      );
      expect(body.hasMatch(dataSource), isTrue);
    });

    test('the plan request body is exactly the session id', () {
      expect(dataSource, contains("<String, Object?>{'sessionId': sessionId}"));
    });

    test('no request may ever carry a spec, a prompt, a path or geometry', () {
      final code = dataSource
          .split('\n')
          .map((line) {
            final comment = line.indexOf('//');
            return comment == -1 ? line : line.substring(0, comment);
          })
          .join('\n');
      for (final banned in [
        "'prompt'",
        "'stepSpec'",
        "'category'",
        "'geometry'",
        "'storagePath'",
        "'analysisId'",
        "'faceAttributes'",
      ]) {
        expect(
          code.contains(banned),
          isFalse,
          reason: '$banned must never appear in a request body',
        );
      }
    });

    test('the server keeps its own retry verdict', () {
      // A client that decided retryability itself could retry a validation
      // failure into the step's bounded attempt budget.
      expect(dataSource, contains("payload['retryable'] == true"));
    });
  });
}
