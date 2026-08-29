import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the only supported way into a V3 tutorial.
///
/// Before V3-10 a session was created from a request the client assembled: the
/// analysis id, the recommendation id, the selected style and the canonical
/// preview's storage path. Every one of those is a server fact, and a caller
/// that can choose them can aim a tutorial at something it was never meant to
/// teach. These tests assert that the client now names one preview and that
/// everything else is derived in the database.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  const migrationName = '20260828000200_tutorial_v3_entry.sql';
  final migration = source('supabase/migrations/$migrationName');

  /// The migration with `--` comments stripped, so a "must not mention"
  /// assertion reads the executable statements rather than the prose.
  final ddl = migration
      .split('\n')
      .map((line) {
        final comment = line.indexOf('--');
        return comment == -1 ? line : line.substring(0, comment);
      })
      .join('\n');

  final repository = source(
    'lib/features/tutorial_v3/domain/repositories/tutorial_v3_repository.dart',
  );
  final dataSource = source(
    'lib/features/tutorial_v3/data/data_sources/'
    'tutorial_v3_remote_data_source.dart',
  );
  final router = source('lib/app/router/app_router.dart');

  group('migration hygiene', () {
    test('it sorts after every other V3 migration', () {
      final migrations =
          Directory(
                '${root.path}${Platform.pathSeparator}supabase'
                '${Platform.pathSeparator}migrations',
              )
              .listSync()
              .whereType<File>()
              .map((file) => file.uri.pathSegments.last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();

      expect(migrations.last, migrationName);
    });

    test('it is additive: no table, column or policy is changed', () {
      // The entry resolver only reads existing tables and inserts one session
      // row. Anything else here would be a schema change smuggled into an
      // entry-point phase.
      for (final banned in [
        'create table',
        'alter table',
        'drop table',
        'drop column',
        'create policy',
        'drop policy',
        'enable row level security',
      ]) {
        expect(
          ddl.toLowerCase().contains(banned),
          isFalse,
          reason: '$banned does not belong in this migration',
        );
      }
    });

    test('it touches no V1 or V2 object', () {
      expect(ddl.contains('tutorial_sessions'), isFalse);
      expect(ddl.contains('tutorial_v2'), isFalse);
    });
  });

  group('the resolver runs as the caller', () {
    test('SECURITY INVOKER, so RLS decides what is visible', () {
      expect(migration, contains('security invoker'));
      expect(migration.contains('security definer'), isFalse);
      expect(migration, contains("set search_path = ''"));
    });

    test('anonymous execution is revoked', () {
      expect(
        migration,
        contains(
          'revoke all on function public.open_tutorial_v3_session(uuid, boolean) '
          'from anon',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.open_tutorial_v3_session(uuid, boolean)\n'
          '  to authenticated',
        ),
      );
      expect(migration, contains("raise exception 'authentication required'"));
    });

    test('it never filters ownership by a supplied user id', () {
      // Ownership comes from RLS. A `user_id` predicate would be a second,
      // weaker answer to the same question.
      expect(ddl.contains('images.user_id ='), isFalse);
      expect(ddl.contains('sessions.user_id = '), isFalse);
    });
  });

  group('everything is derived, nothing is supplied', () {
    test('it takes exactly one identifier plus the chain flag', () {
      expect(
        migration,
        contains(
          'create or replace function public.open_tutorial_v3_session(\n'
          '  p_generated_image_id uuid,\n'
          '  p_kit boolean\n'
          ')',
        ),
      );
    });

    test('the analysis, recommendation and path come from the preview row', () {
      expect(migration, contains('from public.generated_images as images'));
      expect(migration, contains('from public.kit_generated_images as images'));
      expect(
        migration,
        contains(
          'images.analysis_id, images.recommendation_id, images.storage_path',
        ),
      );
      expect(
        migration,
        contains(
          'images.analysis_id, images.kit_recommendation_id, images.storage_path',
        ),
      );
    });

    test('the selected look comes from the recommendation', () {
      expect(
        migration,
        contains('from public.recommendations as recommendations'),
      );
      expect(
        migration,
        contains('from public.kit_makeup_recommendations as recommendations'),
      );
      expect(migration, contains('recommendations.makeup_style into v_style'));
      expect(migration, contains("raise exception 'makeup plan not found'"));
    });

    test('a missing preview or plan is reported, never invented', () {
      expect(migration, contains("raise exception 'final preview not found'"));
      expect(migration, contains("using errcode = 'P0002'"));
    });

    test('the derived path is still checked before it is stored', () {
      expect(migration, contains("v_path not like ('%' || v_folder || '%')"));
      expect(migration, contains("v_path like '%/original/%'"));
      expect(migration, contains("v_path like '%..%'"));
      expect(migration, contains("raise exception 'unsafe preview path'"));
    });
  });

  group('reopen reuses rather than duplicates', () {
    test('an existing session for the preview is returned', () {
      expect(
        migration,
        contains('from public.tutorial_v3_sessions as sessions'),
      );
      expect(migration, contains('if v_session_id is not null then'));
      expect(migration, contains('return v_session_id;'));
    });

    test('reuse is not filtered by plan version', () {
      // A session this build cannot read must still be found, so it is
      // reported as incompatible instead of being duplicated by a second
      // tutorial for the same target.
      expect(
        ddl.contains('sessions.plan_version = '),
        isFalse,
        reason: 'an incompatible session must still be found',
      );
      expect(migration, contains('order by sessions.plan_version desc'));
    });

    test('the reuse lookup is keyed on the mode\'s own column', () {
      expect(
        migration,
        contains(
          'when p_kit then sessions.canonical_kit_generated_image_id\n'
          '          else sessions.canonical_generated_image_id',
        ),
      );
    });

    test('a new session starts unplanned', () {
      expect(migration, contains("'planning'"));
      expect(migration, contains('    0,\n    3,\n'));
    });
  });

  group('the client-side entry carries one identifier', () {
    test('the entry point has no analysis, recommendation, style or path', () {
      final entry = repository.substring(
        repository.indexOf('class TutorialV3EntryPoint'),
        repository.indexOf('/// What happened when a step was prepared'),
      );
      expect(entry, contains('final String canonicalImageId;'));
      expect(entry, contains('final TutorialV3SourceMode sourceMode;'));
      for (final banned in [
        'analysisId',
        'recommendationId',
        'kitRecommendationId',
        'selectedStyleCode',
        'storagePath',
        'canonicalPreview',
      ]) {
        expect(
          entry.contains(banned),
          isFalse,
          reason: '$banned must not be client-supplied',
        );
      }
    });

    test('the old client-assembled request is gone entirely', () {
      expect(repository.contains('TutorialV3SessionRequest'), isFalse);
    });

    test('the data source sends the two RPC parameters and no more', () {
      expect(
        dataSource,
        contains(
          "params: {'p_generated_image_id': canonicalImageId, 'p_kit': kit}",
        ),
      );
    });

    test('the RPC\'s raised errors become domain failures', () {
      // Otherwise a Postgres exception would escape the controller's handling
      // and surface as an unhandled crash rather than a retryable message.
      for (final code in ["'P0002'", "'28000'", "'22023'"]) {
        expect(dataSource, contains(code));
      }
    });
  });

  group('routing', () {
    test('the route carries only the preview id and the chain', () {
      expect(AppConstants.tutorialRoute, '/tutorial/:canonicalImageId');
      expect(
        AppConstants.tutorialPathFor('generated-1'),
        '/tutorial/generated-1',
      );
      expect(
        AppConstants.tutorialPathFor('kit-generated-1', kit: true),
        '/tutorial/kit-generated-1?kit=true',
      );
    });

    test('the route builder reads nothing else from the URL', () {
      // Bounded at this route's own end, so the next route's name does not
      // leak into the assertion.
      final start = router.indexOf("name: 'tutorial'");
      final route = router.substring(start, router.indexOf('GoRoute(', start));
      expect(route, contains("state.pathParameters['canonicalImageId']!"));
      expect(route, contains("state.uri.queryParameters['kit'] == 'true'"));
      // Exactly two reads from the request, and nothing that could name a
      // server fact.
      expect(RegExp(r'state\.').allMatches(route).length, 2);
      for (final banned in ['analysis', 'recommendation', 'style', 'storage']) {
        expect(
          route.toLowerCase().contains(banned),
          isFalse,
          reason: '$banned must not come from the URL',
        );
      }
    });
  });
}
