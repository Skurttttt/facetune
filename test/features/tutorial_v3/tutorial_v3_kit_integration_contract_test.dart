import 'dart:io';

import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_product_snapshot.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the Kit half of the V3 pipeline to My Makeup Kit's own rules.
///
/// Kit mode is where a model is closest to being able to affect what a user
/// is told to put on their face: it is shown real owned products and asked to
/// choose among them. These tests read the actual TypeScript and assert the
/// boundaries that keep that choice bounded — owned products only, ownership
/// re-verified against live inventory, and the persisted description of a
/// product copied from the user's inventory rather than from the model.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const plannerDir = 'supabase/functions/plan-tutorial-v3';
  const mapperDir = 'supabase/functions/map-tutorial-v3-guideline-geometry';
  final plannerIndex = source('$plannerDir/index.ts');
  final plannerPrompt = source('$plannerDir/prompt.ts');
  final plannerValidation = source('$plannerDir/validation.ts');
  final mapperIndex = source('$mapperDir/index.ts');
  final mapperPrompt = source('$mapperDir/prompt.ts');

  /// TypeScript with `//` and `/* */` comments removed, so a "must not
  /// contain" assertion reads the executable code rather than the prose
  /// explaining the prohibition.
  String stripComments(String code) => code
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .split('\n')
      .map((line) {
        final comment = line.indexOf('//');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  group('the persisted Kit recommendation is the only source', () {
    test('the planner reads the Kit recommendation table by mode', () {
      expect(plannerIndex, contains('kit_makeup_recommendations'));
      expect(plannerIndex, contains('session.kit_recommendation_id'));
      expect(
        plannerIndex,
        contains('const isKit = sourceMode === "makeup_kit"'),
      );
    });

    test('the recommendation must still match the session', () {
      // A recommendation re-run for the same analysis produces a different
      // look; continuing against it would teach toward a target the user
      // never chose.
      expect(plannerIndex, contains('recommendation_mismatch'));
      expect(
        plannerIndex,
        contains('recommendation.analysis_id !== session.analysis_id'),
      );
      expect(plannerIndex, contains('recommendation.makeup_style !== style'));
    });

    test('product selection is never re-run inside tutorial logic', () {
      // The owned set comes from the recommendation's persisted snapshots.
      // Nothing here queries the inventory to pick products of its own.
      final code = stripComments(plannerIndex);
      expect(code, contains('recommendation.product_snapshot_json'));
      for (final banned in ['order(', 'limit(', 'ilike(', 'foundation_depth']) {
        expect(
          code.contains(
            'makeup_kit_products")\n        .select("id")\n        .$banned',
          ),
          isFalse,
          reason: 'the planner must not select products itself',
        );
      }
    });
  });

  group('ownership is re-verified server-side', () {
    test('the planner checks every snapshot id against live inventory', () {
      expect(plannerIndex, contains('.from("makeup_kit_products")'));
      expect(plannerIndex, contains('.in("id", snapshotIds)'));
      expect(plannerIndex, contains('inventory_changed'));
    });

    test('the mapper checks again at geometry time', () {
      // A product can be deleted between planning and the step being opened.
      expect(mapperIndex, contains('.from("makeup_kit_products")'));
      expect(mapperIndex, contains('.in("id", snapshotIds)'));
      expect(
        mapperIndex,
        contains('This step teaches a product you no longer own.'),
      );
    });

    test('the step\'s own snapshot is checked, not only the look\'s', () {
      expect(mapperIndex, contains('step.product_snapshot_json'));
      expect(mapperIndex, contains('ownedIds.has(stepProductId)'));
    });

    test('both lookups run under the caller\'s JWT, so RLS scopes them', () {
      // No service_role, and no user_id filter that could be spoofed: a row
      // belonging to another account is invisible, so its id simply does not
      // come back and the look is reported as changed.
      for (final index in [plannerIndex, mapperIndex]) {
        expect(index, contains('SUPABASE_ANON_KEY'));
        expect(index.contains('SERVICE_ROLE'), isFalse);
      }
      expect(
        stripComments(plannerIndex).contains('.eq("user_id"'),
        isFalse,
        reason: 'ownership comes from RLS, not from a client-supplied filter',
      );
    });

    test('a lookup failure denies rather than assumes ownership', () {
      expect(plannerIndex, contains('inventory_lookup_failed'));
      expect(mapperIndex, contains('inventory_lookup_failed'));
    });
  });

  group('the model chooses among products, it never describes them', () {
    test('the prompt lists the owned products and forbids inventing', () {
      expect(
        plannerPrompt,
        contains('This user owns exactly the products listed below.'),
      );
      expect(
        plannerPrompt,
        contains(
          'Never invent a product, a shade or an id that is not listed.',
        ),
      );
      expect(
        plannerPrompt,
        contains(
          'must set product_id to one of the ids above, exactly as written',
        ),
      );
    });

    test('an unowned product id is rejected, never repaired', () {
      expect(
        plannerValidation,
        contains('references a product the user does not own'),
      );
      expect(
        plannerValidation,
        contains('This is the one\n    // failure that must never be repaired'),
      );
    });

    test('the persisted snapshot is copied from the inventory row', () {
      // Everything the model wrote about the product is discarded. Only the
      // id it chose survives, and even that is looked up again here.
      expect(plannerValidation, contains('owned.get(step.productId)'));
      expect(plannerValidation, contains('category: product.category'));
      expect(plannerValidation, contains('product_id: product.productId'));
      expect(
        plannerValidation,
        contains('color_hex: normalizeHex(product.colorHex)'),
      );
      expect(plannerValidation, contains('finish: product.finish'));
      expect(
        plannerValidation,
        contains('snapshot.product_name = product.productName'),
      );
      expect(
        plannerValidation,
        contains('snapshot.shade_name = product.colorLabel'),
      );
    });

    test('the planner hands its verified inventory to the row builder', () {
      expect(
        plannerIndex,
        contains('planRows(plan, { style, sourceMode, ownedProducts })'),
      );
    });
  });

  group('the geometry mapper cannot invent a product at all', () {
    test('no product information reaches the mapper prompt', () {
      // The mapper is given placement language and scoped face attributes.
      // It is never told what product a step teaches, so it has nothing to
      // invent a shade from and no reason to name one.
      final code = stripComments(mapperPrompt);
      for (final banned in [
        'productId',
        'product_id',
        'productName',
        'shadeName',
        'colorHex',
        'finish',
      ]) {
        expect(
          code.contains(banned),
          isFalse,
          reason: 'the mapper prompt must not carry $banned',
        );
      }
    });

    test('the mapper returns coordinates, never product text', () {
      expect(mapperPrompt, contains('text, labels, captions'));
      expect(
        mapperPrompt,
        contains(
          'colours, opacity, stroke widths, fonts, gradients or blend modes',
        ),
      );
    });

    test('it maps only a step that is already planned and persisted', () {
      expect(mapperIndex, contains('step_spec_json'));
      expect(mapperIndex, contains('step_spec_mismatch'));
      expect(mapperIndex, contains('source_mode_mismatch'));
      // A step that does not belong to this session is not mapped at all.
      expect(mapperIndex, contains('claim_tutorial_v3_geometry'));
    });
  });

  group('an incomplete kit is a normal kit', () {
    test('the prompt says so explicitly', () {
      expect(
        plannerPrompt,
        contains(
          'If the user owns nothing suitable for a category, omit that '
          'category entirely. An incomplete kit is expected and acceptable.',
        ),
      );
    });

    test('only an empty look is refused', () {
      // No product at all is not a tutorial. One product is.
      expect(plannerIndex, contains('This kit look has no products.'));
      expect(
        stripComments(plannerIndex).contains('snapshots.length < 2'),
        isFalse,
        reason: 'a one-product kit must still be teachable',
      );
    });
  });

  group('category codes are shared, never forked', () {
    test('every V3 category maps onto a Kit category or the final look', () {
      for (final category in TutorialV3Category.values) {
        if (category.isFinalLook) {
          expect(category.kitCategory, isNull);
          continue;
        }
        expect(
          category.kitCategory,
          isNotNull,
          reason: '${category.code} has no Kit category',
        );
        expect(category.code, category.kitCategory!.code);
      }
    });

    test('every Kit category is teachable', () {
      for (final kit in MakeupKitCategory.values) {
        expect(
          TutorialV3Category.fromKitCategory(kit),
          isNotNull,
          reason: '${kit.code} cannot be taught',
        );
      }
    });
  });

  group('the two preview chains stay separated', () {
    test('the source mode decides the preview folder', () {
      expect(
        TutorialV3SourceMode.makeupKit.canonicalPreviewFolder,
        'kit-generated',
      );
      expect(TutorialV3SourceMode.standard.canonicalPreviewFolder, 'generated');
    });

    test('the planner refuses a target from the other chain', () {
      expect(
        plannerIndex,
        contains(
          'const canonicalFolder = isKit ? "/kit-generated/" : "/generated/"',
        ),
      );
      expect(
        plannerIndex,
        contains('!canonicalPath.includes(canonicalFolder)'),
      );
      expect(plannerIndex, contains('unsafe_storage_path'));
    });
  });

  group('snapshots are by value, so history cannot rewrite a tutorial', () {
    test('the snapshot carries the product, not a live reference', () {
      const snapshot = TutorialV3ProductSnapshot(
        category: MakeupKitCategory.blush,
        productId: 'product-1',
        productName: 'My blush',
        shadeName: 'Soft Rose',
        finish: MakeupKitFinish.satin,
      );

      // Editing the inventory row later cannot reach any of this: the values
      // were copied when the plan was written.
      expect(snapshot.productName, 'My blush');
      expect(snapshot.shadeName, 'Soft Rose');
      expect(snapshot.isOwnedProduct, isTrue);
    });

    test('the tutorial never reads the live inventory table', () {
      // If it did, a product edited after planning would silently change what
      // a persisted step teaches. Ownership is re-checked server-side by id;
      // the description shown is always the snapshot.
      final feature = Directory(
        '${root.path}${Platform.pathSeparator}lib'
        '${Platform.pathSeparator}features'
        '${Platform.pathSeparator}tutorial_v3',
      );
      final sources = feature
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'));

      for (final file in sources) {
        // Doc comments explaining where a snapshot came from are prose, not
        // a query, so only the executable code is checked.
        expect(
          stripComments(
            file.readAsStringSync(),
          ).contains('makeup_kit_products'),
          isFalse,
          reason: '${file.path} queries live Kit inventory',
        );
      }
    });

    test('a standard step can never carry an owned product id', () {
      const snapshot = TutorialV3ProductSnapshot(
        category: MakeupKitCategory.blush,
        productName: 'Recommended shade',
      );

      expect(snapshot.isOwnedProduct, isFalse);
      expect(
        plannerValidation,
        contains('must not reference an owned product in standard mode'),
      );
    });
  });
}
