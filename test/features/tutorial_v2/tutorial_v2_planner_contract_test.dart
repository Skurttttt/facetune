import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Pins the V2-4 planner migration and Edge Function to the guarantees the
/// V2-0 audit identified as load-bearing.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260826000200_tutorial_v2_planner.sql',
  );
  final index = source('supabase/functions/plan-tutorial-v2/index.ts');

  group('AI quota is extended as a strict superset', () {
    test('every operation that is live remotely survives', () {
      // The remote constraint and function currently carry V1's operations.
      // Dropping any of them would break a deployed function.
      for (final operation in [
        'face_analysis',
        'makeup_recommendation',
        'kit_makeup_recommendation',
        'makeup_preview',
        'kit_makeup_preview',
        'tutorial_step',
        'tutorial_geometry_plan',
      ]) {
        expect(
          migration,
          contains("'$operation'"),
          reason: '$operation must not be dropped from the quota',
        );
      }
    });

    test('the V2 planner operation is added', () {
      expect(migration, contains("'tutorial_v2_plan'"));
      expect(
        migration,
        contains("('tutorial_v2_plan', 30, 150)"),
      );
    });

    test('the constraint and the function agree on the vocabulary', () {
      final constraintBlock = migration.substring(
        migration.indexOf('ai_usage_events_operation_valid'),
      );
      final checkList = constraintBlock.substring(
        constraintBlock.indexOf('check (operation in ('),
        constraintBlock.indexOf('));'),
      );
      final constraintOps = RegExp("'([a-z0-9_]+)'")
          .allMatches(checkList)
          .map((match) => match.group(1)!)
          .toSet();

      final limitsBlock = migration.substring(
        migration.indexOf('from (values'),
        migration.indexOf('as limits(operation, hourly, daily)'),
      );
      final limitOps = RegExp("\\('([a-z0-9_]+)',")
          .allMatches(limitsBlock)
          .map((match) => match.group(1)!)
          .toSet();

      expect(limitOps, constraintOps);
      expect(constraintOps.length, 8);
    });

    test('the shared Deno helper knows the new operation', () {
      expect(
        source('supabase/functions/_shared/ai_quota.ts'),
        contains('"tutorial_v2_plan"'),
      );
    });
  });

  group('atomic plan persistence', () {
    test('the plan is written by one transactional function', () {
      expect(migration, contains('persist_tutorial_v2_plan'));
      expect(migration, contains('delete from public.tutorial_v2_steps'));
      expect(migration, contains('insert into public.tutorial_v2_steps'));
      expect(migration, contains('update public.tutorial_v2_sessions'));
    });

    test('it runs as the caller so RLS still applies', () {
      // SECURITY DEFINER here would let a caller write steps into another
      // user's tutorial.
      final function = migration.substring(
        migration.indexOf('create or replace function public.persist_tutorial_v2_plan'),
      );
      expect(function, contains('security invoker'));
      expect(function, contains("set search_path = ''"));
      expect(function, isNot(contains('security definer')));
    });

    test('the owner comes from the session, never from the payload', () {
      expect(migration, contains('v_user uuid := (select auth.uid());'));
      expect(migration, contains('raise exception \'tutorial session not found\''));
      // The insert selects the authenticated uid, not a user_id from JSON.
      expect(migration, isNot(contains("->> 'user_id'")));
    });

    test('execute is granted to authenticated and revoked from anon', () {
      expect(
        migration,
        contains('revoke all on function public.persist_tutorial_v2_plan'),
      );
      expect(
        migration,
        contains('grant execute on function public.persist_tutorial_v2_plan'),
      );
      expect(migration, contains('to authenticated'));
    });
  });

  group('the Edge Function trusts nothing from the client', () {
    test('it accepts only a session id', () {
      expect(index, contains('tutorialSessionId'));
      for (final field in [
        'body.userId',
        'body.user_id',
        'input.recommendationId',
        'input.productIds',
        'input.style',
        'input.ownedProducts',
      ]) {
        expect(index, isNot(contains(field)), reason: field);
      }
    });

    test('identity is derived server-side from the JWT', () {
      expect(RegExp(r'auth\s*\.getUser\(\)').hasMatch(index), isTrue);
      expect(index, contains('authData.user.id'));
      expect(index, isNot(contains('SUPABASE_SERVICE_ROLE_KEY')));
    });

    test('the recommendation is read from the session row', () {
      expect(index, contains('session.kit_recommendation_id'));
      expect(index, contains('session.recommendation_id'));
      expect(index, contains('recommendation_mismatch'));
    });

    test('Kit ownership is re-verified against live inventory', () {
      expect(index, contains('makeup_kit_products'));
      expect(index, contains('inventory_changed'));
      expect(index, contains('ownedIds'));
    });

    test('the canonical target path is validated before download', () {
      expect(index, contains('unsafe_storage_path'));
      expect(index, contains('canonicalPath.includes("..")'));
      expect(index, contains('canonicalPath.includes("/original/")'));
      expect(index, contains('canonicalPath.startsWith(expectedPrefix)'));
    });

    test('an incompatible plan version is refused', () {
      expect(index, contains('incompatible_plan_version'));
      expect(index, contains('MINIMUM_PLAN_VERSION'));
    });

    test('retries are bounded', () {
      expect(index, contains('maximumPlanAttempts = 2'));
      expect(index, contains('Bounded: never loop'));
      expect(index, isNot(contains('while (true)')));
    });

    test('the model is server-configurable and never silently substituted', () {
      expect(index, contains('TUTORIAL_V2_PLANNER_MODEL'));
      expect(index, contains('gemini-3.6-flash'));
      expect(
        source('supabase/functions/plan-tutorial-v2/gemini_client.ts'),
        contains('GEMINI_MODEL_NOT_FOUND'),
      );
    });

    test('the function verifies its JWT at the gateway', () {
      expect(
        RegExp(
          r'\[functions\.plan-tutorial-v2\]\s+verify_jwt\s*=\s*true',
        ).hasMatch(source('supabase/config.toml')),
        isTrue,
      );
    });

    test('no Gemini secret reaches the client bundle', () {
      final dartSources = root
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.contains(
                  '${Platform.pathSeparator}lib${Platform.pathSeparator}',
                ) &&
                file.path.endsWith('.dart'),
          )
          .map((file) => file.readAsStringSync())
          .join('\n');

      expect(dartSources, isNot(contains('TUTORIAL_V2_PLANNER_MODEL')));
      expect(dartSources, isNot(contains('GEMINI_API_KEY')));
      expect(dartSources, isNot(contains('generativelanguage.googleapis.com')));
    });
  });
}
