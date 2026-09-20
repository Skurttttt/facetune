import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String source(String path) => File(path).readAsStringSync();

String sqlCodeOnly(String value) => value
    .split('\n')
    .map((line) => line.split('--').first)
    .join('\n')
    .toLowerCase();

void main() {
  const migrationPath =
      'supabase/migrations/20260922000100_subscription_telemetry.sql';
  late String migration;
  late String code;

  setUpAll(() {
    migration = source(migrationPath);
    code = sqlCodeOnly(migration);
  });

  group('privacy and authority boundary', () {
    test(
      'stores controlled technical facts without private content fields',
      () {
        for (final prohibited in <String>[
          'image_bytes',
          'base64',
          'signed_url',
          'jwt',
          'purchase_token',
          'prompt_text',
          'makeup_kit_content',
          'product_name',
          'email text',
        ]) {
          expect(code, isNot(contains(prohibited)));
        }
      },
    );

    test('users cannot write the table or execute the writer', () {
      expect(
        code,
        contains(
          'alter table public.ai_operation_metrics enable row level security',
        ),
      );
      expect(
        code,
        contains(
          'revoke all on table public.ai_operation_metrics from authenticated',
        ),
      );
      expect(
        code,
        contains('grant execute on function public.record_ai_operation_metric'),
      );
      expect(code, contains('to service_role'));
      expect(
        code,
        contains('from authenticated'),
        reason: 'the writer must not be callable with the mobile JWT',
      );
    });

    test('plan and capability are derived rather than RPC parameters', () {
      final signature = code.substring(
        code.indexOf('create function public.record_ai_operation_metric'),
        code.indexOf('returns boolean'),
      );
      expect(signature, isNot(contains('p_plan_code')));
      expect(signature, isNot(contains('p_allowance_unit')));
      expect(signature, isNot(contains('p_capability_family')));
      expect(code, contains('from public.usage_ledger as l'));
      expect(code, contains('from public.subscription_products as p'));
    });
  });

  group('transaction and idempotency boundary', () {
    test('does not mutate entitlement or usage authority', () {
      expect(code, isNot(contains('update public.usage_ledger')));
      expect(code, isNot(contains('delete from public.usage_ledger')));
      expect(code, isNot(contains('update public.user_entitlements')));
      expect(code, isNot(contains('insert into public.user_entitlements')));
      expect(code, isNot(contains('reserve_ai_look(')));
      expect(code, isNot(contains('commit_ai_look(')));
      expect(code, isNot(contains('release_ai_look(')));
    });

    test('separates a logical delivered unit from provider attempts', () {
      expect(code, contains('operation_id uuid'));
      expect(code, contains('provider_attempt_count integer'));
      expect(
        code,
        contains("usage_status in ('reserved', 'committed', 'released')"),
      );
      expect(code, contains('unique'));
      expect(code, contains('ai_operation_metrics_final_preview_success_idx'));
      expect(code, contains('ai_operation_metrics_step_success_idx'));
      expect(code, contains('on conflict do nothing'));
    });

    test('cost inputs are raw and no peso hypothesis is runtime logic', () {
      expect(code, contains('input_tokens integer'));
      expect(code, contains('output_image_tokens integer'));
      expect(code, contains("telemetry_schema_version = 'sub13_v1'"));
      expect(code, isNot(contains('45')));
      expect(code, isNot(contains('149')));
      expect(code, isNot(contains('estimated_cost')));
    });
  });

  test('Edge writers are privileged and best effort', () {
    final helper = source('supabase/functions/_shared/ai_telemetry.ts');
    expect(helper, contains('SUPABASE_SERVICE_ROLE_KEY'));
    expect(helper, contains('if (!client) return false'));
    expect(helper, contains('Promise.race'));
    expect(helper, contains('return false'));

    for (final path in <String>[
      'supabase/functions/generate-makeup-preview/index.ts',
      'supabase/functions/generate-kit-makeup-preview/index.ts',
      'supabase/functions/analyze-tutorial-manifest-v4/index.ts',
      'supabase/functions/generate-tutorial-step-v4/index.ts',
      'supabase/functions/verify-google-play-purchase/index.ts',
    ]) {
      final function = source(path);
      expect(function, contains('createTelemetryClient()'), reason: path);
    }
  });

  test('cost model is versioned, reporting-only, and sample-honest', () {
    final report = source('docs/SUB_13_UNIT_ECONOMICS.md');
    expect(report, contains('sub13_unit_economics_v1'));
    expect(report, contains('reporting-only'));
    expect(report, contains('INSUFFICIENT_DATA'));
    expect(report, contains('no real Gemini calls'));
    expect(report, contains('No top-up product'));
  });
}
