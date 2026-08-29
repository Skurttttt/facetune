import 'dart:io';

import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_category.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_generation_status.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_plan_version.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_session.dart';
import 'package:facetune/features/tutorial_v2/domain/entities/tutorial_v2_source_mode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the V2 persistence layer to the V2 domain contract.
///
/// The migration and the Dart enums are edited independently, so a
/// vocabulary that drifts between them would only surface as a Postgres
/// check-constraint violation in production. These tests read the actual SQL
/// and compare it against the actual enums.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const migrationName = '20260826000100_tutorial_v2_sessions_steps.sql';
  final migration = source('supabase/migrations/$migrationName');

  /// The contents of a `check (... in ('a', 'b'))` list following [anchor].
  Set<String> vocabularyAfter(String anchor) {
    final start = migration.indexOf(anchor);
    expect(start, greaterThan(-1), reason: 'missing constraint $anchor');
    final open = migration.indexOf('in (', start);
    final close = migration.indexOf(')', open);
    final body = migration.substring(open + 4, close);
    return RegExp("'([a-z_]+)'")
        .allMatches(body)
        .map((match) => match.group(1)!)
        .toSet();
  }

  group('migration chronology', () {
    test('the tables are created before anything references them', () {
      final migrations =
          Directory(
                '${root.path}${Platform.pathSeparator}supabase${Platform.pathSeparator}migrations',
              )
              .listSync()
              .whereType<File>()
              .map((file) => file.uri.pathSegments.last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();

      // Every later V2 migration builds on these tables, so this one must
      // sort first among the V2 set.
      final v2 = migrations
          .where((name) => name.contains('tutorial_v2'))
          .toList();

      expect(v2, isNotEmpty);
      expect(v2.first, migrationName);
    });

    test('sorts after every remote V1 tutorial migration', () {
      // The remote database is ahead of this branch by three V1 tutorial
      // migrations with no local file (V2-0 audit §4). A V2 migration that
      // sorted before them would be applied out of order.
      const newestRemoteV1 = '20260816000100';
      expect(
        migrationName.compareTo(newestRemoteV1),
        greaterThan(0),
        reason: 'V2 migration must sort after $newestRemoteV1',
      );
    });

    test('historical applied migrations are untouched by this phase', () {
      // Every other local migration predates V2 and must not be edited.
      const historical = [
        '20260807000100_initial_schema.sql',
        '20260812000100_ai_usage_quota.sql',
        '20260813000300_kit_generated_images.sql',
        '20260814000200_makeup_kit_hardening.sql',
      ];
      for (final name in historical) {
        expect(
          source('supabase/migrations/$name'),
          isNot(contains('tutorial_v2')),
          reason: '$name must not mention V2 objects',
        );
      }
    });
  });

  group('V1 isolation', () {
    test('creates distinct V2 tables', () {
      expect(
        migration,
        contains('create table if not exists public.tutorial_v2_sessions'),
      );
      expect(
        migration,
        contains('create table if not exists public.tutorial_v2_steps'),
      );
    });

    test('never binds to the V1 tutorial tables', () {
      // `tutorial_v2_sessions` contains `tutorial_v2_`, so match the V1 names
      // only where they are NOT followed by the v2 infix.
      final v1References = RegExp(
        r'public\.tutorial_(sessions|steps)\b',
      ).allMatches(migration);

      expect(v1References, isEmpty);
    });

    test('does not redefine the shared AI quota objects', () {
      // Both currently carry V1's tutorial operations remotely. Rewriting
      // either from this branch would strip them. The header comment
      // explains that, so assert on the DDL rather than the mention.
      expect(
        RegExp(
          r'(create|replace)\s+(or\s+replace\s+)?function\s+public\.consume_ai_quota',
        ).hasMatch(migration),
        isFalse,
      );
      expect(
        RegExp(r'alter\s+table\s+public\.ai_usage_events').hasMatch(migration),
        isFalse,
      );
      expect(
        RegExp(r'drop\s+function\s+.*consume_ai_quota').hasMatch(migration),
        isFalse,
      );
    });
  });

  group('row level security', () {
    test('RLS is enabled and anonymous access revoked', () {
      for (final table in ['tutorial_v2_sessions', 'tutorial_v2_steps']) {
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
        );
        expect(
          migration,
          contains('revoke all on table public.$table from anon'),
        );
        expect(migration, contains('on table public.$table to authenticated'));
      }
    });

    test('every table has all four owner-scoped policies', () {
      for (final table in ['tutorial_v2_sessions', 'tutorial_v2_steps']) {
        for (final action in ['select', 'insert', 'update', 'delete']) {
          expect(
            migration,
            contains('"${table}_${action}_own"'),
            reason: '$table is missing its $action policy',
          );
        }
      }
    });

    test('ownership is always the authenticated user', () {
      // 4 policies x 2 tables, with update carrying both using and with
      // check, and insert carrying with check only.
      expect(
        RegExp(r'auth\.uid\(\)\) = user_id').allMatches(migration).length,
        greaterThanOrEqualTo(10),
      );
      expect(migration, isNot(contains('to anon')));
      expect(migration, isNot(contains('using (true)')));
    });
  });

  group('ownership and history deletion', () {
    test('sessions cascade from the owning analysis', () {
      // delete-history-item deletes the analyses row; the tutorial must go
      // with it rather than orphaning rows.
      expect(migration, contains('tutorial_v2_sessions_analysis_owner_fk'));
      expect(
        migration,
        contains('references public.analyses(id, user_id)\n    on delete cascade'),
      );
    });

    test('steps cascade from the owning session', () {
      expect(migration, contains('tutorial_v2_steps_session_owner_fk'));
      expect(
        migration,
        contains(
          'references public.tutorial_v2_sessions(id, user_id)\n    on delete cascade',
        ),
      );
    });

    test('foreign keys carry user_id so ownership is schema-enforced', () {
      for (final fk in [
        'foreign key (analysis_id, user_id)',
        'foreign key (recommendation_id, analysis_id, user_id)',
        'foreign key (kit_recommendation_id, analysis_id, user_id)',
        'foreign key (canonical_generated_image_id, user_id)',
        'foreign key (canonical_kit_generated_image_id, user_id)',
        'foreign key (tutorial_v2_session_id, user_id)',
      ]) {
        expect(migration, contains(fk));
      }
    });

    test('every table carries a composite owner identity', () {
      expect(
        migration,
        contains('tutorial_v2_sessions_owner_identity unique (id, user_id)'),
      );
      expect(
        migration,
        contains('tutorial_v2_steps_owner_identity unique (id, user_id)'),
      );
    });
  });

  group('storage safety', () {
    test('generated assets must sit in the owner folder', () {
      for (final column in [
        'guideline_image_path',
        'result_image_path',
        'canonical_image_path',
      ]) {
        expect(
          migration,
          contains("$column like (user_id::text || '/analyses/%')"),
          reason: '$column is not owner-scoped',
        );
      }
    });

    test('no tutorial asset can point at an original selfie', () {
      expect(
        RegExp(r"not like '%/original/%'").allMatches(migration).length,
        3,
      );
    });

    test('traversal segments are rejected', () {
      expect(RegExp(r"not like '%\.\.%'").allMatches(migration).length, 3);
    });

    test('a stored asset path can never be claimed twice', () {
      expect(migration, contains('tutorial_v2_steps_guideline_path_unique'));
      expect(migration, contains('tutorial_v2_steps_result_path_unique'));
    });
  });

  group('vocabulary matches the domain', () {
    test('source modes match TutorialV2SourceMode', () {
      expect(
        vocabularyAfter('tutorial_v2_sessions_source_mode_valid'),
        TutorialV2SourceMode.values.map((mode) => mode.code).toSet(),
      );
    });

    test('step categories match TutorialV2Category', () {
      expect(
        vocabularyAfter('tutorial_v2_steps_category_valid'),
        TutorialV2Category.values.map((category) => category.code).toSet(),
      );
    });

    test('asset statuses match TutorialV2GenerationStatus', () {
      final expected = TutorialV2GenerationStatus.values
          .map((status) => status.code)
          .toSet();

      expect(
        vocabularyAfter('tutorial_v2_steps_guideline_status_valid'),
        expected,
      );
      expect(
        vocabularyAfter('tutorial_v2_steps_result_status_valid'),
        expected,
      );
    });

    test('session statuses are the persisted subset of the domain enum', () {
      // `incompatible` is derived at read time from plan_version and is
      // never stored, so the database must refuse it.
      final persisted = vocabularyAfter(
        'tutorial_v2_sessions_status_valid',
      );
      final domain = TutorialV2SessionStatus.values
          .map((status) => status.code)
          .toSet();

      expect(persisted, domain.difference({'incompatible'}));
      expect(persisted, isNot(contains('incompatible')));
      expect(domain.difference(persisted), {'incompatible'});
    });

    test('the plan version floor matches the domain', () {
      expect(
        migration,
        contains('plan_version >= ${TutorialV2PlanVersion.minimumSupportedValue}'),
      );
      expect(
        migration,
        contains('plan_version integer not null default '
            '${TutorialV2PlanVersion.currentValue}'),
      );
    });
  });

  group('session invariants', () {
    test('exactly one recommendation reference, matching the mode', () {
      expect(
        migration,
        contains('tutorial_v2_sessions_recommendation_matches_mode'),
      );
    });

    test('exactly one canonical preview reference, matching the mode', () {
      expect(
        migration,
        contains('tutorial_v2_sessions_canonical_matches_mode'),
      );
    });

    test('one tutorial per canonical target per plan version', () {
      expect(
        migration,
        contains('tutorial_v2_sessions_canonical_standard_idx'),
      );
      expect(migration, contains('tutorial_v2_sessions_canonical_kit_idx'));
    });

    test('a ready plan has steps and an unready one does not', () {
      expect(migration, contains('tutorial_v2_sessions_ready_has_steps'));
      expect(migration, contains("status = 'plan_ready' and total_steps > 0"));
    });

    test('the selected style is required', () {
      expect(migration, contains('makeup_style text not null'));
      expect(
        migration,
        contains('tutorial_v2_sessions_makeup_style_not_blank'),
      );
    });
  });

  group('step invariants', () {
    test('the validated step spec is persisted as one object', () {
      expect(migration, contains('step_spec_json jsonb not null'));
      expect(migration, contains('tutorial_v2_steps_spec_is_object'));
    });

    test('step order is unique within a session', () {
      expect(
        migration,
        contains(
          'tutorial_v2_steps_session_index_unique\n    unique (tutorial_v2_session_id, step_index)',
        ),
      );
    });

    test('step indexes are zero-based, matching the domain', () {
      expect(migration, contains('step_index >= 0'));
    });

    test('the final look step carries no product', () {
      expect(
        migration,
        contains('tutorial_v2_steps_final_look_has_no_product'),
      );
    });

    test('a ready asset must have a path', () {
      expect(
        migration,
        contains('tutorial_v2_steps_guideline_ready_has_path'),
      );
      expect(migration, contains('tutorial_v2_steps_result_ready_has_path'));
    });

    test('retry and error metadata is persisted', () {
      for (final column in [
        'guideline_error text',
        'result_error text',
        'retry_count integer not null default 0',
      ]) {
        expect(migration, contains(column));
      }
    });
  });
}
