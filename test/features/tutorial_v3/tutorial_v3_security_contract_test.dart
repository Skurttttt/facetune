import 'dart:io';

import 'package:facetune/features/tutorial_v3/domain/services/tutorial_v3_storage_paths.dart';
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

  group('storage path safety', () {
    test('a guideline must live in the owner folder', () {
      expect(
        migration,
        contains("guideline_image_path like (user_id::text || '/analyses/%')"),
      );
    });

    test('a guideline can never overwrite protected assets', () {
      for (final forbidden in ['/original/', '/generated/', '/kit-generated/']) {
        expect(
          migration,
          contains("guideline_image_path not like '%$forbidden%'"),
          reason: 'guideline must be excluded from $forbidden',
        );
      }
      expect(migration, contains("guideline_image_path not like '%..%'"));
    });

    test('the canonical preview can never be an original selfie', () {
      expect(
        migration,
        contains("canonical_image_path not like '%/original/%'"),
      );
      expect(migration, contains("canonical_image_path not like '%..%'"));
    });

    test('the SQL folder matches the Dart storage path builder', () {
      expect(
        migration,
        contains("guideline_image_path like '%/${TutorialV3StoragePaths.folder}/%'"),
      );
    });

    test('one stored path can never be claimed by two steps', () {
      expect(
        migration,
        contains('tutorial_v3_steps_guideline_path_unique'),
      );
    });

    test('an unready step never keeps a stale asset', () {
      expect(
        migration,
        contains(
          "check (guideline_status = 'ready' or guideline_image_path is null)",
        ),
      );
      expect(
        migration,
        contains(
          "check (guideline_status <> 'ready' or guideline_image_path is not null)",
        ),
      );
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
