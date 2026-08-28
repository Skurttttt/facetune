import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the V3 persistence security posture.
///
/// Every rule here is one the rest of FaceTune already relies on. A V3
/// migration that quietly dropped one would not fail any behavioural test —
/// it would just widen the blast radius of a bug — so they are asserted
/// directly against the SQL.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260827000100_tutorial_v3_sessions_steps.sql',
  );
  final geometryMigration = source(
    'supabase/migrations/20260828000100_tutorial_v3_geometry.sql',
  );

  const tables = ['tutorial_v3_sessions', 'tutorial_v3_steps'];

  group('row level security', () {
    test('RLS is enabled on both tables', () {
      for (final table in tables) {
        expect(
          migration,
          contains('alter table public.$table enable row level security'),
          reason: '$table must enable RLS',
        );
      }
    });

    test('anonymous access is revoked on both tables', () {
      for (final table in tables) {
        expect(
          migration,
          contains('revoke all on table public.$table from anon'),
          reason: '$table must revoke anon',
        );
      }
    });

    test('only authenticated users are granted access', () {
      for (final table in tables) {
        expect(
          migration,
          contains(
            'grant select, insert, update, delete\n  on table public.$table to authenticated',
          ),
          reason: '$table must grant only authenticated',
        );
      }
      // Word-boundary matched: a bare `contains('to public')` also matches
      // the `into public.tutorial_v3_steps` insert inside the plan writer.
      expect(RegExp(r'\bto (anon|public)\b').hasMatch(migration), isFalse);
    });

    test('all four policies exist per table and are owner scoped', () {
      for (final table in tables) {
        for (final action in ['select', 'insert', 'update', 'delete']) {
          expect(
            migration,
            contains('create policy "${table}_${action}_own"'),
            reason: 'missing ${table}_${action}_own',
          );
        }
      }
      // Eight policies, each scoped to the caller.
      expect(
        RegExp(r'\(select auth\.uid\(\)\) = user_id').allMatches(migration),
        // select + insert + delete once each, update twice (using + with check)
        hasLength(10),
      );
    });

    test('no policy is written for an unauthenticated role', () {
      final policyRoles = RegExp(
        r'create policy[\s\S]{0,200}?\n\s*to (\w+)',
      ).allMatches(migration).map((match) => match.group(1)).toSet();
      expect(policyRoles, {'authenticated'});
    });
  });

  group('ownership-safe foreign keys', () {
    test('every foreign key carries the owner column', () {
      // A bare `references analyses(id)` would let a row point at another
      // user's analysis. Each of these is a composite key including user_id.
      for (final constraint in [
        'tutorial_v3_sessions_analysis_owner_fk',
        'tutorial_v3_sessions_recommendation_owner_fk',
        'tutorial_v3_sessions_kit_recommendation_owner_fk',
        'tutorial_v3_sessions_canonical_image_owner_fk',
        'tutorial_v3_sessions_canonical_kit_image_owner_fk',
        'tutorial_v3_steps_session_owner_fk',
      ]) {
        expect(migration, contains(constraint), reason: 'missing $constraint');
      }
    });

    test('history deletion cascades into V3 rows', () {
      // delete-history-item deletes the analyses row; without cascade the V3
      // session would survive as an orphan pointing at deleted assets.
      expect(
        migration,
        contains(
          'foreign key (analysis_id, user_id)\n    references public.analyses(id, user_id)\n    on delete cascade',
        ),
      );
      expect(
        RegExp(r'on delete cascade').allMatches(migration).length,
        greaterThanOrEqualTo(6),
      );
    });

    test('steps are owner-identified for the composite child key', () {
      expect(migration, contains('tutorial_v3_steps_owner_identity unique (id, user_id)'));
      expect(
        migration,
        contains('tutorial_v3_sessions_owner_identity unique (id, user_id)'),
      );
    });
  });

  group('stored payload safety', () {
    test('the canonical preview can never be an original selfie', () {
      expect(
        migration,
        contains("canonical_image_path not like '%/original/%'"),
      );
      expect(migration, contains("canonical_image_path not like '%..%'"));
    });

    test('V3-6B removes the per-step image path entirely', () {
      // With no path column there is no path to validate, no object to
      // overwrite, and no way for a step to reference another user's asset.
      for (final constraint in [
        'tutorial_v3_steps_guideline_path_unique',
        'tutorial_v3_steps_guideline_path_owned',
        'tutorial_v3_steps_guideline_ready_has_path',
        'tutorial_v3_steps_guideline_unready_has_no_path',
      ]) {
        expect(
          geometryMigration,
          contains(constraint),
          reason: '$constraint must be dropped, not left behind',
        );
      }
      expect(
        geometryMigration,
        contains('drop column if exists guideline_image_path'),
      );
      expect(geometryMigration.contains('storage.objects'), isFalse);
      expect(geometryMigration.contains('face-images'), isFalse);
    });

    test('geometry is a JSON object, never arbitrary scalar or text', () {
      expect(
        geometryMigration,
        contains("check (geometry_json is null or jsonb_typeof(geometry_json) = 'object')"),
      );
    });

    test('a stored document always declares a usable schema version', () {
      // A payload with no version could not be checked for staleness, so it
      // would be rendered under whatever vocabulary the reader happened to
      // have.
      expect(
        geometryMigration,
        contains('tutorial_v3_steps_geometry_schema_version_positive'),
      );
      expect(
        geometryMigration,
        contains('tutorial_v3_steps_geometry_ready_has_payload'),
      );
      expect(
        geometryMigration,
        contains('tutorial_v3_steps_geometry_unready_has_no_payload'),
      );
    });

    test('an unready step never keeps a stale document', () {
      final collapsed = geometryMigration.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        collapsed,
        contains(
          "check ( geometry_status <> 'ready' or (geometry_json is not null "
          'and geometry_schema_version is not null) )',
        ),
      );
      expect(
        collapsed,
        contains(
          "check ( geometry_status = 'ready' or (geometry_json is null "
          'and geometry_schema_version is null) )',
        ),
      );
    });
  });

  /// The body of `claim_tutorial_v3_geometry` alone, bounded at its own `$$;`
  /// terminator so a later function in the same migration is never read as
  /// part of it.
  final claimBody = (() {
    final start = geometryMigration.indexOf(
      'function public.claim_tutorial_v3_geometry',
    );
    return geometryMigration.substring(
      start,
      geometryMigration.indexOf(r"$$;", start),
    );
  })();

  group('atomic geometry claim', () {
    test('the claim runs as the caller, not as definer', () {
      // SECURITY INVOKER keeps RLS in force, so a caller can only ever claim
      // a step inside a session they own.
      expect(claimBody, contains('security invoker'));
      expect(claimBody.contains('security definer'), isFalse);
      expect(claimBody, contains("set search_path = ''"));
    });

    test('the claim rejects anonymous execution', () {
      expect(
        geometryMigration,
        contains(
          'revoke all on function public.claim_tutorial_v3_geometry'
          '(uuid, integer, integer, integer)\n  from anon',
        ),
      );
      expect(
        geometryMigration,
        contains(
          'grant execute on function public.claim_tutorial_v3_geometry'
          '(uuid, integer, integer, integer)\n  to authenticated',
        ),
      );
      expect(
        geometryMigration,
        contains("raise exception 'authentication required'"),
      );
    });

    test('the claim decides in one statement, not read-then-write', () {
      // Two concurrent callers must not both win. The UPDATE itself carries
      // the state guard, so exactly one can move a step to `generating`.
      expect(
        geometryMigration,
        contains('and geometry_status = any(v_claimable)'),
      );
      expect(geometryMigration, contains('if not found then'));
      expect(geometryMigration, contains("'outcome', 'in_flight'"));
    });

    test('a claim always starts from an empty payload', () {
      expect(claimBody, contains('geometry_json = null'));
      expect(claimBody, contains('geometry_schema_version = null'));
    });

    test('reuse is version-scoped, so a stale document is never rendered', () {
      expect(
        claimBody,
        contains(
          'if v_row.geometry_schema_version is not distinct from '
          'p_schema_version then',
        ),
      );
      expect(claimBody, contains("'outcome', 'reused'"));
      expect(claimBody, contains("'replaced_schema_version'"));
    });

    test('the final look and a foreign step are refused before any write', () {
      expect(claimBody.indexOf("'outcome', 'not_found'"), greaterThan(-1));
      expect(claimBody.indexOf("'outcome', 'final_look'"), greaterThan(-1));
      expect(
        claimBody.indexOf("'outcome', 'final_look'"),
        lessThan(claimBody.indexOf('update public.tutorial_v3_steps')),
      );
    });

    test('retries are bounded inside the database', () {
      expect(
        geometryMigration,
        contains('if v_row.attempt_count >= p_max_attempts then'),
      );
      expect(geometryMigration, contains("'outcome', 'exhausted'"));
    });
  });

  group('server-side plan write', () {
    test('the atomic plan writer runs as the caller, not as definer', () {
      expect(migration, contains('persist_tutorial_v3_plan'));
      expect(migration, contains('security invoker'));
      expect(
        RegExp(
          r'function public\.persist_tutorial_v3_plan[\s\S]*?security definer',
        ).hasMatch(migration),
        isFalse,
        reason: 'the plan writer must not bypass RLS',
      );
    });

    test('the plan writer pins its search path', () {
      expect(migration, contains("set search_path = ''"));
    });

    test('the plan writer rejects anonymous execution', () {
      expect(
        migration,
        contains(
          'revoke all on function public.persist_tutorial_v3_plan(uuid, text, text, jsonb)\n  from anon',
        ),
      );
      expect(
        migration,
        contains(
          'grant execute on function public.persist_tutorial_v3_plan(uuid, text, text, jsonb)\n  to authenticated',
        ),
      );
    });

    test('the plan writer enforces exactly one terminal final look', () {
      expect(
        migration,
        contains('a plan must contain exactly one final look step'),
      );
      expect(migration, contains('the final look must be the last step'));
    });

    test('the plan writer replaces rather than appends steps', () {
      expect(
        migration,
        contains('delete from public.tutorial_v3_steps'),
      );
    });
  });
}
