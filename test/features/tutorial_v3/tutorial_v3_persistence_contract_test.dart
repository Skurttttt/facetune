import 'dart:io';

import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_category.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_guideline_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_session_status.dart';
import 'package:facetune/features/tutorial_v3/domain/entities/tutorial_v3_source_mode.dart';
import 'package:facetune/features/tutorial_v3/domain/value_objects/tutorial_v3_plan_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the V3 persistence layer to the V3 domain contract.
///
/// The migration and the Dart enums are edited independently, so a vocabulary
/// that drifts between them would only surface as a Postgres check-constraint
/// violation in production. These tests read the actual SQL and compare it
/// against the actual enums.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const migrationName = '20260827000100_tutorial_v3_sessions_steps.sql';
  final migration = source('supabase/migrations/$migrationName');

  /// The migration with `--` comments stripped.
  ///
  /// The header deliberately *names* the V1/V2 objects it refuses to touch,
  /// so "must not mention" assertions have to read the executable statements
  /// rather than the prose explaining them.
  final ddl = migration
      .split('\n')
      .map((line) {
        final comment = line.indexOf('--');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  /// The contents of a `check (... in ('a', 'b'))` list following [anchor].
  Set<String> vocabularyAfter(String anchor) {
    final start = migration.indexOf(anchor);
    expect(start, greaterThan(-1), reason: 'missing constraint $anchor');
    final open = migration.indexOf('in (', start);
    final close = migration.indexOf(')', open);
    final body = migration.substring(open + 4, close);
    return RegExp(
      "'([a-z_]+)'",
    ).allMatches(body).map((match) => match.group(1)!).toSet();
  }

  group('migration chronology', () {
    test('sorts after every migration applied remotely', () {
      // V3-0.5 §9: the highest applied remote migration is 20260826000200.
      // A V3 migration sorting before it would be applied out of order.
      const newestAppliedRemote = '20260826000200';
      expect(
        migrationName.compareTo(newestAppliedRemote),
        greaterThan(0),
        reason: 'V3 migration must sort after $newestAppliedRemote',
      );
    });

    test('does not reuse the withheld V2 guideline slot', () {
      // 20260826000300 names a recovered-but-unapplied V2 migration that is
      // still in the stash. Reusing that timestamp would make them collide.
      expect(migrationName.startsWith('20260826000300'), isFalse);
    });

    test('creates the V3 tables before any later V3 migration', () {
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

      final v3 = migrations
          .where((name) => name.contains('tutorial_v3'))
          .toList();

      // Later V3 phases add their own migrations; every one of them builds on
      // these tables, so this must sort first among the V3 set.
      expect(v3, isNotEmpty);
      expect(v3.first, migrationName);

      // And nothing predating V3 may sort after it.
      final nonV3 = migrations
          .where((name) => !name.contains('tutorial_v3'))
          .toList();
      expect(nonV3.last.compareTo(migrationName), lessThan(0));
    });

    test('historical applied migrations are untouched by this phase', () {
      // Every other local migration predates V3 and must not be edited.
      const historical = [
        '20260807000100_initial_schema.sql',
        '20260812000100_ai_usage_quota.sql',
        '20260814000200_makeup_kit_hardening.sql',
        '20260814000300_tutorial_sessions_steps.sql',
        '20260826000100_tutorial_v2_sessions_steps.sql',
        '20260826000200_tutorial_v2_planner.sql',
      ];
      for (final name in historical) {
        expect(
          source('supabase/migrations/$name'),
          isNot(contains('tutorial_v3')),
          reason: '$name must not mention V3 objects',
        );
      }
    });
  });

  group('V1 and V2 isolation', () {
    test('creates distinct V3 tables', () {
      expect(
        migration,
        contains('create table if not exists public.tutorial_v3_sessions'),
      );
      expect(
        migration,
        contains('create table if not exists public.tutorial_v3_steps'),
      );
    });

    test('never binds to the V1 tutorial tables', () {
      // `tutorial_v3_sessions` contains `tutorial_v3_`, so match the V1 names
      // only where they are NOT followed by a version infix.
      expect(
        RegExp(r'public\.tutorial_(sessions|steps)\b').allMatches(ddl),
        isEmpty,
      );
    });

    test('never binds to the V2 tutorial tables or functions', () {
      expect(ddl.contains('tutorial_v2_sessions'), isFalse);
      expect(ddl.contains('tutorial_v2_steps'), isFalse);
      expect(
        RegExp(
          r'(create|replace)\s+(or\s+replace\s+)?function\s+public\.persist_tutorial_v2_plan',
        ).hasMatch(ddl),
        isFalse,
      );
    });

    test('does not redefine the shared AI quota objects', () {
      // Their live definition carries eight operations, three belonging to
      // ACTIVE deployed V1/V2 functions (V3-0.5 §6). Rewriting either object
      // here would strip them. The header comment explains that, so assert on
      // the DDL rather than the mention.
      expect(
        RegExp(
          r'(create|replace)\s+(or\s+replace\s+)?function\s+public\.consume_ai_quota',
        ).hasMatch(ddl),
        isFalse,
      );
      expect(ddl.contains('ai_usage_events_operation_valid'), isFalse);
      expect(ddl.contains('alter table public.ai_usage_events'), isFalse);
    });

    test('adds no quota operation of its own', () {
      // V3's operation belongs to the phase that deploys V3's Edge Function,
      // as a superset of whatever is live then.
      expect(ddl.contains("'tutorial_v3"), isFalse);
    });
  });

  group('vocabulary agreement with the domain', () {
    test('step categories match TutorialV3Category exactly', () {
      expect(
        vocabularyAfter('tutorial_v3_steps_category_valid'),
        TutorialV3Category.values.map((category) => category.code).toSet(),
      );
    });

    test('guideline statuses match TutorialV3GuidelineStatus exactly', () {
      expect(
        vocabularyAfter('tutorial_v3_steps_guideline_status_valid'),
        TutorialV3GuidelineStatus.values.map((status) => status.code).toSet(),
      );
    });

    test('session statuses match TutorialV3SessionStatus exactly', () {
      expect(
        vocabularyAfter('tutorial_v3_sessions_status_valid'),
        TutorialV3SessionStatus.values.map((status) => status.code).toSet(),
      );
    });

    test('source modes match TutorialV3SourceMode exactly', () {
      expect(
        vocabularyAfter('tutorial_v3_sessions_source_mode_valid'),
        TutorialV3SourceMode.values.map((mode) => mode.code).toSet(),
      );
    });

    test('the plan version floor matches the domain', () {
      expect(
        migration,
        contains('check (plan_version >= ${TutorialV3PlanVersion.currentValue})'),
      );
    });

    test('the step index floor matches the one-based domain', () {
      expect(migration, contains('check (step_index >= 1)'));
    });
  });

  group('no intermediate result is representable', () {
    test('the steps table has no result asset columns', () {
      expect(ddl.contains('result_status'), isFalse);
      expect(ddl.contains('result_image_path'), isFalse);
    });

    test('the final look must never carry a guideline', () {
      expect(
        migration,
        contains('tutorial_v3_steps_final_look_needs_no_guideline'),
      );
      expect(
        migration,
        contains(
          "(category = 'final_look' and guideline_status = 'not_required')",
        ),
      );
      expect(
        migration,
        contains(
          "(category <> 'final_look' and guideline_status <> 'not_required')",
        ),
      );
    });

    test('the final look carries no product', () {
      expect(
        migration,
        contains(
          "check (category <> 'final_look' or product_snapshot_json is null)",
        ),
      );
    });
  });

  group('session shape', () {
    test('persists every field the domain session needs', () {
      for (final column in [
        'user_id',
        'analysis_id',
        'source_mode',
        'recommendation_id',
        'kit_recommendation_id',
        'makeup_style',
        'canonical_generated_image_id',
        'canonical_kit_generated_image_id',
        'canonical_image_path',
        'total_steps',
        'plan_version',
        'status',
      ]) {
        expect(migration, contains(column), reason: 'missing $column');
      }
    });

    test('persists every field the domain step needs', () {
      for (final column in [
        'step_index',
        'category',
        'step_spec_json',
        'product_snapshot_json',
        'guideline_status',
        'guideline_image_path',
        'guideline_error',
        'attempt_count',
      ]) {
        expect(migration, contains(column), reason: 'missing $column');
      }
    });

    test('exactly one recommendation and one canonical preview per mode', () {
      expect(
        migration,
        contains('tutorial_v3_sessions_recommendation_matches_mode'),
      );
      expect(
        migration,
        contains('tutorial_v3_sessions_canonical_matches_mode'),
      );
    });

    test('a ready session has steps and an unready one does not', () {
      expect(migration, contains('tutorial_v3_sessions_ready_has_steps'));
    });
  });
}
