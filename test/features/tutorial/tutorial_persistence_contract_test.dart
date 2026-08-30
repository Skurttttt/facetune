import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the V4-2 migration SQL.
///
/// These assert the schema and RLS *as declared*. They deliberately do not
/// claim to prove PostgreSQL's runtime enforcement — that needs a live database
/// and is recorded as a manual verification step. This mirrors the approach
/// already used by `makeup_kit_security_contract_test.dart`, which is the
/// established way this project proves ownership rules without a database in
/// the test environment.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260830000100_tutorial_persistence.sql',
  );
  final kitProducts = source(
    'supabase/migrations/20260813000100_makeup_kit_products.sql',
  );

  const newTables = <String>[
    'look_product_snapshot_items',
    'tutorial_v4_sessions',
    'tutorial_v4_manifest_items',
    'tutorial_v4_steps',
    'tutorial_v4_step_products',
  ];

  group('every new table is private user data', () {
    test('enables row level security', () {
      for (final table in newTables) {
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
          reason: '$table must have RLS enabled',
        );
      }
    });

    test('revokes all access from anon', () {
      for (final table in newTables) {
        expect(
          migration,
          contains('revoke all on table public.$table from anon'),
          reason: '$table must be unreachable anonymously',
        );
      }
    });

    test('never disables RLS for convenience', () {
      expect(migration, isNot(contains('disable row level security')));
      expect(migration.toLowerCase(), isNot(contains('force row level')));
    });

    test('owns a user_id column referencing auth.users', () {
      expect(
        RegExp(
          r'user_id uuid not null references auth\.users\(id\) on delete cascade',
        ).allMatches(migration).length,
        newTables.length,
      );
    });
  });

  group('own-user allow, cross-user denial', () {
    test('every policy authorizes only on the caller uuid', () {
      // Every policy in the migration must be scoped by auth.uid() = user_id.
      final policyCount = RegExp(
        r'create policy "',
      ).allMatches(migration).length;
      final scopedCount = RegExp(
        r'\(select auth\.uid\(\)\) = user_id',
      ).allMatches(migration).length;

      expect(policyCount, greaterThanOrEqualTo(16));
      // Update policies carry the predicate twice (using + with check).
      expect(scopedCount, greaterThanOrEqualTo(policyCount));
    });

    test('no policy grants access to the public or anon role', () {
      // \b matters here: without it, `insert into public.ai_usage_events`
      // matches as "to public".
      expect(
        RegExp(
          r'create policy[\s\S]*?\bto (anon|public)\b',
        ).hasMatch(migration),
        isFalse,
      );
      expect(
        RegExp(r'create policy "').allMatches(migration).length,
        RegExp(r'\nto authenticated').allMatches(migration).length,
      );
    });

    test('kit snapshot rows are readable only by their owner', () {
      expect(
        migration,
        contains('create policy "look_product_snapshot_items_select_own"'),
      );
      expect(
        migration,
        contains('create policy "look_product_snapshot_items_insert_own"'),
      );
    });

    test('tutorial rows are readable only by their owner', () {
      for (final table in <String>[
        'tutorial_v4_sessions',
        'tutorial_v4_manifest_items',
        'tutorial_v4_steps',
        'tutorial_v4_step_products',
      ]) {
        expect(migration, contains('create policy "${table}_select_own"'));
        expect(migration, contains('create policy "${table}_insert_own"'));
      }
    });

    test('child rows cannot be attached across accounts', () {
      // Composite (id, user_id) foreign keys make it impossible to attach a
      // child row to a parent owned by a different account, even if RLS were
      // somehow bypassed.
      for (final table in newTables) {
        expect(
          migration,
          contains('constraint ${table}_owner_identity unique (id, user_id)'),
          reason: '$table must expose a composite ownership key',
        );
      }
      for (final fk in <String>[
        'look_product_snapshot_items_recommendation_owner_fk',
        'tutorial_v4_sessions_analysis_owner_fk',
        'tutorial_v4_sessions_recommendation_owner_fk',
        'tutorial_v4_sessions_kit_recommendation_owner_fk',
        'tutorial_v4_sessions_generated_image_owner_fk',
        'tutorial_v4_sessions_kit_generated_image_owner_fk',
        'tutorial_v4_manifest_items_session_owner_fk',
        'tutorial_v4_steps_session_owner_fk',
        'tutorial_v4_step_products_step_owner_fk',
        'tutorial_v4_step_products_snapshot_owner_fk',
      ]) {
        expect(migration, contains('constraint $fk'));
      }
      // Each of those foreign keys carries user_id in the key itself.
      expect(
        RegExp(
          r'foreign key \([a-z_]+, user_id\)',
        ).allMatches(migration).length,
        greaterThanOrEqualTo(9),
      );
    });
  });

  group('My Makeup Kit inventory is reused, not duplicated', () {
    test('the migration creates no second kit product table', () {
      expect(
        migration,
        isNot(
          contains('create table if not exists public.makeup_kit_products'),
        ),
      );
    });

    test('existing inventory allows many products in one category', () {
      // The only unique constraints on makeup_kit_products are the primary key
      // and the composite ownership key. Nothing constrains (user_id, category),
      // so a user may register several products of the same category.
      expect(
        kitProducts,
        contains(
          'constraint makeup_kit_products_owner_identity unique (id, user_id)',
        ),
      );
      expect(
        RegExp(r'unique \(user_id, category\)').hasMatch(kitProducts),
        isFalse,
      );
      expect(
        RegExp(
          r'create unique index[^;]*makeup_kit_products[^;]*\(user_id, category\)',
        ).hasMatch(kitProducts),
        isFalse,
      );
    });

    test('existing inventory allows an incomplete kit', () {
      // Optional, category-aware fields are nullable, so a user may register a
      // product without naming it or describing its shade.
      for (final nullableColumn in <String>[
        'product_name text,',
        'color_label text,',
        'foundation_depth text,',
        'foundation_undertone text,',
      ]) {
        expect(kitProducts, contains(nullableColumn));
      }
      expect(kitProducts, isNot(contains('product_name text not null')));
      expect(kitProducts, isNot(contains('color_label text not null')));
    });
  });

  group('snapshot stability', () {
    test('snapshot items allow many products per category', () {
      // Uniqueness is per product, not per category, so a Lipstick and a Lip
      // Gloss can both belong to one look.
      expect(
        migration,
        contains(
          'constraint look_product_snapshot_items_product_unique\n'
          '    unique (kit_recommendation_id, product_id)',
        ),
      );
      expect(
        RegExp(
          r'unique \(kit_recommendation_id, category\)',
        ).hasMatch(migration),
        isFalse,
      );
    });

    test('snapshot items do not foreign-key to mutable inventory', () {
      // A foreign key here would let a product deletion cascade into — or a
      // product edit invalidate — a historical look.
      expect(
        RegExp(
          r'look_product_snapshot_items[\s\S]*?\);',
        ).firstMatch(migration)!.group(0),
        isNot(contains('references public.makeup_kit_products')),
      );
    });

    test('snapshot items are insert-once', () {
      expect(
        migration,
        contains(
          'grant select, insert, delete\n'
          '  on table public.look_product_snapshot_items to authenticated',
        ),
      );
      expect(
        migration,
        isNot(
          contains('create policy "look_product_snapshot_items_update_own"'),
        ),
      );
      expect(migration, contains('reject_snapshot_item_update'));
      expect(
        migration,
        contains('before update on public.look_product_snapshot_items'),
      );
    });

    test('snapshot items have no updated_at, because they never change', () {
      final table = RegExp(
        r'create table if not exists public\.look_product_snapshot_items[\s\S]*?\n\);',
      ).firstMatch(migration)!.group(0)!;
      expect(table, isNot(contains('updated_at')));
      expect(table, contains('created_at timestamptz not null'));
    });
  });

  group('source mode lineage', () {
    test('stores source mode explicitly with a controlled vocabulary', () {
      expect(migration, contains('source_mode text not null'));
      expect(
        migration,
        contains("check (source_mode in ('standard', 'my_makeup_kit'))"),
      );
    });

    test('forces the populated lineage to agree with the declared mode', () {
      expect(
        migration,
        contains('constraint tutorial_v4_sessions_source_mode_lineage'),
      );
      final constraint = RegExp(
        r'constraint tutorial_v4_sessions_source_mode_lineage[\s\S]*?\n    \),',
      ).firstMatch(migration)!.group(0)!;

      expect(constraint, contains("source_mode = 'standard'"));
      expect(constraint, contains('recommendation_id is not null'));
      expect(constraint, contains('canonical_generated_image_id is not null'));
      expect(constraint, contains('kit_recommendation_id is null'));
      expect(constraint, contains("source_mode = 'my_makeup_kit'"));
      expect(
        constraint,
        contains('canonical_kit_generated_image_id is not null'),
      );
    });
  });

  group('manifest constraints', () {
    test('constrains the tutorial category vocabulary to nine values', () {
      final constraint = RegExp(
        r'constraint tutorial_v4_manifest_items_category_valid[\s\S]*?\n    \),',
      ).firstMatch(migration)!.group(0)!;

      for (final category in <String>[
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrows',
        'eyeshadow',
        'eyeliner',
        'lips',
      ]) {
        expect(constraint, contains("'$category'"));
      }
      // Inventory-only names must not leak into the tutorial vocabulary.
      expect(constraint, isNot(contains("'lipstick'")));
      expect(constraint, isNot(contains("'lip_gloss'")));
      expect(constraint, isNot(contains("'eyebrow'")));
    });

    test('constrains presence to present, absent, or uncertain', () {
      expect(
        migration,
        contains("check (presence in ('present', 'absent', 'uncertain'))"),
      );
    });

    test('binds deterministic order to the category', () {
      final constraint = RegExp(
        r'constraint tutorial_v4_manifest_items_position_matches_category[\s\S]*?\n    \),',
      ).firstMatch(migration)!.group(0)!;

      expect(constraint, contains("category = 'foundation' and position = 1"));
      expect(
        constraint,
        contains("category = 'contour_bronzer' and position = 3"),
      );
      expect(constraint, contains("category = 'lips' and position = 9"));
    });

    test('allows exactly one verdict per category per session', () {
      expect(
        migration,
        contains(
          'constraint tutorial_v4_manifest_items_category_unique\n'
          '    unique (tutorial_session_id, category)',
        ),
      );
    });

    test('bounds an optional confidence score without thresholding it', () {
      expect(
        migration,
        contains('visual_confidence >= 0 and visual_confidence <= 1'),
      );
    });

    test('an absent category cannot claim to be product-backed', () {
      expect(
        migration,
        contains("check (presence = 'present' or product_backed = false)"),
      );
    });
  });

  group('steps exist only for included categories', () {
    test('foreign-keys the step to a present manifest item', () {
      expect(
        migration,
        contains(
          'constraint tutorial_v4_steps_included_category_fk\n'
          '    foreign key (tutorial_session_id, category, manifest_presence)\n'
          '    references public.tutorial_v4_manifest_items\n'
          '      (tutorial_session_id, category, presence)',
        ),
      );
      expect(
        migration,
        contains('unique (tutorial_session_id, category, presence)'),
      );
    });

    test('pins the referenced presence to present', () {
      expect(migration, contains("check (manifest_presence = 'present')"));
    });
  });

  group('idempotency and duplicate prevention', () {
    test('permits one session per canonical preview', () {
      expect(
        migration,
        contains(
          'create unique index if not exists tutorial_v4_sessions_canonical_preview_idx',
        ),
      );
      expect(
        migration,
        contains(
          'create unique index if not exists tutorial_v4_sessions_kit_canonical_preview_idx',
        ),
      );
      expect(
        migration,
        contains('where canonical_generated_image_id is not null'),
      );
    });

    test('permits one step per category per session', () {
      expect(
        migration,
        contains(
          'constraint tutorial_v4_steps_category_unique\n'
          '    unique (tutorial_session_id, category)',
        ),
      );
      expect(
        migration,
        contains(
          'constraint tutorial_v4_steps_position_unique\n'
          '    unique (tutorial_session_id, position)',
        ),
      );
    });

    test('permits one link row per step and snapshot item', () {
      expect(
        migration,
        contains(
          'constraint tutorial_v4_step_products_unique\n'
          '    unique (tutorial_step_id, look_product_snapshot_item_id)',
        ),
      );
    });

    test('a rendered guideline path is globally unique', () {
      expect(migration, contains('guideline_storage_path text unique'));
    });
  });

  group('guideline storage safety', () {
    test('confines a guideline path to the owner tutorials folder', () {
      expect(
        migration,
        contains(
          "guideline_storage_path like\n"
          "        (user_id::text || '/analyses/%/tutorials/%')",
        ),
      );
    });

    test('cannot name the original selfie or the canonical preview', () {
      // Existing paths are `<uid>/analyses/<id>/original/...` and
      // `<uid>/analyses/<id>/generated/...`. The `/tutorials/` segment is what
      // keeps a guideline from ever overwriting either one.
      final pattern = RegExp(
        r"guideline_storage_path like\s*\n?\s*\(user_id::text \|\| '(/analyses/%/tutorials/%)'\)",
      );
      expect(pattern.hasMatch(migration), isTrue);
      final path = pattern.firstMatch(migration)!.group(1)!;
      expect(path, isNot(contains('original')));
      expect(path, isNot(contains('generated')));
      expect(path, contains('/tutorials/'));
    });

    test('creates no bucket and no public storage', () {
      expect(migration, isNot(contains('storage.buckets')));
      expect(migration, isNot(contains('public, true')));
    });

    test('a ready step must carry its image and full provenance', () {
      final constraint = RegExp(
        r'constraint tutorial_v4_steps_ready_is_complete[\s\S]*?\n    \),',
      ).firstMatch(migration)!.group(0)!;

      expect(constraint, contains('guideline_storage_path is not null'));
      expect(constraint, contains('model_name is not null'));
      expect(constraint, contains('output_resolution is not null'));
      expect(constraint, contains('prompt_version is not null'));
    });
  });

  group('AI quota vocabulary', () {
    test('extends both the constraint and the limits table', () {
      for (final operation in <String>[
        'tutorial_manifest_analysis',
        'tutorial_step_generation',
      ]) {
        // Once in the check constraint, once in the in-function limits table.
        expect(
          RegExp("'$operation'").allMatches(migration).length,
          greaterThanOrEqualTo(2),
          reason: '$operation must be in the constraint AND the limits table',
        );
      }
      expect(migration, contains("('tutorial_manifest_analysis', 20, 80)"));
      expect(migration, contains("('tutorial_step_generation', 90, 360)"));
    });

    test('preserves the existing operations', () {
      for (final operation in <String>[
        'face_analysis',
        'makeup_recommendation',
        'kit_makeup_recommendation',
        'makeup_preview',
        'kit_makeup_preview',
      ]) {
        expect(migration, contains("'$operation'"));
      }
      expect(migration, contains("('face_analysis', 20, 100)"));
      expect(migration, contains("('kit_makeup_preview', 30, 120)"));
    });

    test('keeps the quota function fail-closed and search-path safe', () {
      expect(migration, contains('security definer'));
      expect(migration, contains("set search_path = ''"));
      expect(migration, contains("'unsupported_operation'"));
    });

    test('the shared Edge Function type mirrors the database vocabulary', () {
      final quota = source('supabase/functions/_shared/ai_quota.ts');
      expect(quota, contains('"tutorial_manifest_analysis"'));
      expect(quota, contains('"tutorial_step_generation"'));
    });
  });

  group('no generation logic exists yet', () {
    test('the migration contains no Gemini or model configuration', () {
      // Strip `--` comments first. The header prose explains what is
      // deliberately absent and legitimately names Gemini; what matters is
      // that no executable statement configures a model or a credential.
      final statements = migration
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('--'))
          .join('\n')
          .toLowerCase();

      expect(statements, isNot(contains('gemini')));
      expect(statements, isNot(contains('api_key')));
      expect(statements, isNot(contains('service_role')));
      expect(statements, isNot(contains('http')));
    });

    test('the migration itself still creates no generation logic', () {
      // The analyzer arrived in V4-6 and the guideline renderer in V4-9; both
      // are expected now. What this guards is that neither leaked into the
      // persistence migration, which must stay pure schema.
      final functions = Directory(
        '${root.path}${Platform.pathSeparator}supabase${Platform.pathSeparator}functions',
      ).listSync().map((entry) => entry.path.split(Platform.pathSeparator).last);

      expect(functions, contains('analyze-tutorial-manifest-v4'));
      expect(functions, contains('generate-tutorial-step-v4'));
      expect(
        migration.toLowerCase(),
        isNot(contains('generate-tutorial-step-v4')),
      );
    });
  });

  group('V4 tables live in their own namespace (V4-DEBUG-01 regression)', () {
    // The remote database already carries tutorial_sessions and tutorial_steps
    // from an earlier tutorial generation, with a different shape. Reusing
    // those names made every V4 query fail with PostgreSQL 42703 (column does
    // not exist), which surfaced as "This step could not be drawn."
    //
    // The project already solved this once: tutorial_v2_* and tutorial_v3_*
    // exist remotely. V4 follows the same convention.
    test('every V4 table is version-prefixed', () {
      for (final table in <String>[
        'tutorial_v4_sessions',
        'tutorial_v4_manifest_items',
        'tutorial_v4_steps',
        'tutorial_v4_step_products',
      ]) {
        expect(migration, contains('create table if not exists public.$table'));
      }
    });

    test('no unversioned tutorial table name is used anywhere', () {
      // Bare names belong to the earlier generation and must never be touched.
      for (final owned in <String>[
        'public.tutorial_sessions',
        'public.tutorial_steps',
        '"tutorial_sessions"',
        '"tutorial_steps"',
      ]) {
        expect(
          migration,
          isNot(contains(owned)),
          reason: '$owned belongs to a previous tutorial generation',
        );
      }
    });

    test('index names are version-prefixed too', () {
      // Index names are schema-wide in PostgreSQL, so an unprefixed name would
      // collide with the earlier generation's index and `if not exists` would
      // silently skip creating ours — leaving the V4 tables unindexed.
      final indexNames = RegExp(
        r'create (?:unique )?index if not exists (\w+)',
      ).allMatches(migration).map((match) => match.group(1)!);
      for (final name in indexNames) {
        if (!name.startsWith('tutorial_')) continue;
        expect(
          name.startsWith('tutorial_v4_'),
          isTrue,
          reason: '$name would collide with the earlier generation',
        );
      }
    });

    test('the quota vocabulary preserves every live operation', () {
      // This statement REPLACES the constraint and the limits table, so any
      // omission silently revokes a live operation. The five legacy tutorial
      // operations were recovered from 20260828000100 during V4-DEBUG-02.
      for (final operation in <String>[
        'face_analysis',
        'makeup_recommendation',
        'kit_makeup_recommendation',
        'makeup_preview',
        'kit_makeup_preview',
        'tutorial_step',
        'tutorial_geometry_plan',
        'tutorial_v2_plan',
        'tutorial_v3_plan',
        'tutorial_v3_geometry',
        'tutorial_manifest_analysis',
        'tutorial_step_generation',
      ]) {
        expect(
          RegExp("'$operation'").allMatches(migration).length,
          greaterThanOrEqualTo(2),
          reason: '$operation must be in the constraint AND the limits table',
        );
      }
      // Legacy limits copied verbatim rather than retuned.
      expect(migration, contains("('tutorial_step', 80, 400)"));
      expect(migration, contains("('tutorial_v3_geometry', 120, 600)"));
      expect(
        migration,
        contains('select 20, 80 into v_hourly_limit, v_daily_limit'),
        reason: 'an unknown recorded operation still degrades safely',
      );
    });
  });
}
