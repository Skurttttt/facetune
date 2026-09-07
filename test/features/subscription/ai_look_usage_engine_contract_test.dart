import 'dart:io';

import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-4 AI Look usage engine.
///
/// The engine's *behaviour* was proven against live PostgreSQL 17.6 and is
/// recorded in the SUB-4 completion report: the full reserve/commit/release
/// lifecycle, idempotent replays, cross-account refusal, preview ownership, a
/// genuine two-connection race for one remaining AI Look, and stale-reservation
/// reconciliation. These tests pin the declarations that behaviour rests on, so
/// a later edit cannot quietly drop a guard.
///
/// Matching is whitespace-insensitive via [declares], for the reason given in
/// `subscription_persistence_contract_test.dart`.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final migration = source(
    'supabase/migrations/20260907000300_ai_look_usage_engine.sql',
  );

  final statements = migration
      .split(RegExp(r'\r?\n'))
      .where((line) => !line.trimLeft().startsWith('--'))
      .join('\n');

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  final flattened = collapse(statements);

  void declares(String snippet, {String? reason}) => expect(
    flattened,
    contains(collapse(snippet)),
    reason: reason ?? 'migration must declare: $snippet',
  );

  void declaresNot(String snippet, {String? reason}) => expect(
    flattened,
    isNot(contains(collapse(snippet))),
    reason: reason ?? 'migration must not declare: $snippet',
  );

  group('migration hygiene', () {
    test('applies after the resolver it depends on', () {
      final names =
          Directory(
                '${root.path}${Platform.pathSeparator}supabase'
                '${Platform.pathSeparator}migrations',
              )
              .listSync()
              .whereType<File>()
              .map((file) => file.path.split(Platform.pathSeparator).last)
              .where((name) => name.endsWith('.sql'))
              .toList()
            ..sort();

      const engine = '20260907000300_ai_look_usage_engine.sql';
      expect(names, contains(engine));
      expect(
        names.indexOf('20260907000200_subscription_entitlement_resolver.sql'),
        lessThan(names.indexOf(engine)),
      );
    });

    test('is purely additive', () {
      for (final forbidden in [
        'alter table',
        'drop table',
        'drop policy',
        'drop trigger',
        'create table',
        'create policy',
        'disable row level security',
      ]) {
        declaresNot(forbidden);
      }
    });

    test('does not touch the AI rate limiter or the Final Preview path', () {
      declaresNot('ai_usage_events');
      declaresNot('consume_ai_quota');
      declaresNot('generate-makeup-preview');
      declaresNot('gemini');
    });

    test('introduces no service-role reference', () {
      expect(migration.toLowerCase(), isNot(contains('service_role')));
    });
  });

  group('all three operations are server-authoritative', () {
    const operations = ['reserve_ai_look', 'commit_ai_look', 'release_ai_look'];

    test('each derives the account from the request JWT', () {
      for (final _ in operations) {
        // One shared declaration form across all three.
      }
      expect(
        RegExp(
          r'v_user uuid := \(select auth\.uid\(\)\);',
        ).allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
      expect(
        RegExp(r"'errorCode', 'AUTH_REQUIRED'").allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('each runs security definer with a pinned search path', () {
      expect(
        RegExp('security definer').allMatches(flattened).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        RegExp("set search_path = ''").allMatches(flattened).length,
        greaterThanOrEqualTo(4),
      );
    });

    test('no operation accepts a caller-supplied account or timestamp', () {
      // The account is never a parameter, so one caller cannot act as another.
      for (final forbidden in [
        'p_user uuid',
        'p_user_id',
        'p_now',
        'p_committed_at',
        'p_reserved_at',
      ]) {
        declaresNot(forbidden);
      }
      declares('reserve_ai_look(p_operation_id uuid)');
      declares(
        'commit_ai_look( p_operation_id uuid, p_source_mode text, '
        'p_canonical_preview_id uuid )',
      );
      declares('release_ai_look( p_operation_id uuid, p_failure_code text');
    });

    test('every ownership check compares against the resolved account', () {
      expect(
        RegExp(r'user_id <> v_user').allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('time always comes from the database', () {
      expect(
        RegExp(r"timezone\('utc', now\(\)\)").allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
    });
  });

  group('atomicity and concurrency', () {
    test('reserve serializes per account before checking capacity', () {
      // Without this the capacity read and the insert can interleave, and two
      // concurrent requests both spend the same last AI Look.
      declares(
        'perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));',
      );
      expect(
        RegExp(r'pg_advisory_xact_lock').allMatches(flattened).length,
        greaterThanOrEqualTo(3),
      );
    });

    test('commit and release take a row lock on the operation', () {
      expect(
        RegExp(
          r'where operation_id = p_operation_id for update',
        ).allMatches(flattened).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('a duplicate operation id can never create a second row', () {
      // Belt and braces behind the advisory lock.
      declares('when unique_violation then');
    });

    test('reconciliation skips rows another worker already holds', () {
      declares('for update skip locked');
    });
  });

  group('capacity has exactly one authority', () {
    test('reserve defers to the SUB-3 resolver', () {
      declares('v_state := public.resolve_subscription_state();');
      declares("(v_state->>'generationAuthorized')::boolean is not true");
    });

    test('the engine recomputes no allowance of its own', () {
      // A second capacity calculator is exactly what the contract forbids.
      declaresNot('base_ai_look_allowance + ');
      declaresNot('allowance_adjustment_total -');
      declaresNot('greatest(0, v_effective');
    });

    test('a denial reports the resolver’s own reason', () {
      declares("coalesce(v_state->>'denialReason', 'ENTITLEMENT_INACTIVE')");
    });
  });

  group('the one transition that must never happen', () {
    test('release refuses a committed operation', () {
      declares(
        "if v_row.status = 'committed' then return jsonb_build_object( "
        "'ok', false, 'errorCode', 'USAGE_ALREADY_COMMITTED'",
      );
    });

    test('commit never writes released over committed', () {
      declaresNot(
        "set status = 'released', committed_at = null, "
        "source_mode = p_source_mode",
      );
    });

    test('release clears any preview lineage it returns capacity for', () {
      declares(
        "set status = 'released', released_at = greatest(v_now, "
        'v_row.reserved_at), committed_at = null, source_mode = null, '
        'canonical_generated_image_id = null, '
        'canonical_kit_generated_image_id = null',
      );
    });

    test('a persisted preview outranks a premature release', () {
      // The converse of the hard lock: a usable persisted preview must be
      // charged exactly once, so commit corrects a released row rather than
      // leaving real generated work unpaid.
      declares("'correctedFromReleased', v_row.status = 'released'");
    });
  });

  group('idempotency', () {
    test('a replayed reserve returns the existing reservation', () {
      declares("'replayed', true");
      declares("'ok', v_existing.status = 'reserved'");
    });

    test('a replayed commit of the same preview succeeds', () {
      declares(
        'if v_current_preview is null '
        'or v_current_preview = p_canonical_preview_id then',
      );
    });

    test('a different preview on a committed operation is a conflict', () {
      declares("'errorCode', 'USAGE_ALREADY_COMMITTED'");
    });

    test('a replayed release succeeds without changing anything', () {
      declares(
        "if v_row.status = 'released' then return jsonb_build_object( "
        "'ok', true, 'replayed', true",
      );
    });
  });

  group('preview lineage', () {
    test('commit proves the preview belongs to the caller', () {
      declares(
        'select exists ( select 1 from public.generated_images as g '
        'where g.id = p_canonical_preview_id and g.user_id = v_user )',
      );
      declares(
        'select exists ( select 1 from public.kit_generated_images as k '
        'where k.id = p_canonical_preview_id and k.user_id = v_user )',
      );
    });

    test('the source mode is validated, never inferred', () {
      declares(
        "if p_source_mode is null or "
        "p_source_mode not in ('standard', 'makeup_kit')",
      );
    });

    test('only the column matching the mode is populated', () {
      declares(
        'canonical_generated_image_id = case when p_source_mode = '
        "'standard' then p_canonical_preview_id else null end",
      );
      declares(
        'canonical_kit_generated_image_id = case when p_source_mode = '
        "'makeup_kit' then p_canonical_preview_id else null end",
      );
    });
  });

  group('stale reservation reconciliation', () {
    test('is not a naive timer: it looks for persisted evidence first', () {
      // A client timeout proves nothing about whether the server finished.
      declares(
        'not exists ( select 1 from public.usage_ledger as l '
        'where l.canonical_generated_image_id = g.id )',
      );
      declares('g.created_at >= v_row.reserved_at');
    });

    test(
      'commits when the work succeeded and only the commit call was lost',
      () {
        declares('if v_candidates = 1 then');
        declares("set status = 'committed', source_mode = v_mode");
      },
    );

    test('releases only when nothing usable was persisted', () {
      declares('elsif v_candidates = 0 then');
      declares("set status = 'released'");
      declares("sanitized_failure_code = 'stale_reservation_reconciled'");
    });

    test('refuses to guess when several previews could match', () {
      declares('v_skipped := v_skipped + 1;');
      declares("'skippedAmbiguous', v_skipped");
    });

    test('the threshold cannot be shortened into aggressive releasing', () {
      // Floors any caller-supplied interval, so no schedule can be tuned down
      // to release work that may still be generating.
      declares("greatest( p_older_than, interval '10 minutes' )");
      declares("p_older_than interval default interval '30 minutes'");
    });

    test('is not client-callable', () {
      declares(
        'revoke all on function '
        'public.reconcile_stale_ai_look_reservations(interval) '
        'from authenticated;',
      );
    });
  });

  group('privileges', () {
    test(
      'the three lifecycle operations are granted to authenticated only',
      () {
        for (final signature in [
          'public.reserve_ai_look(uuid)',
          'public.commit_ai_look(uuid, text, uuid)',
          'public.release_ai_look(uuid, text)',
        ]) {
          declares('revoke all on function $signature from public;');
          declares('revoke all on function $signature from anon;');
          declares('grant execute on function $signature to authenticated;');
        }
      },
    );

    test('nothing is granted to anon', () {
      declaresNot('to anon;');
    });
  });

  group('sanitized results', () {
    test('every emitted error code exists in the shared vocabulary', () {
      const emitted = [
        'AUTH_REQUIRED',
        'USAGE_OPERATION_NOT_FOUND',
        'USAGE_ALREADY_COMMITTED',
        'USAGE_ALREADY_RELEASED',
        'USAGE_STATE_CONFLICT',
        'ENTITLEMENT_INACTIVE',
      ];
      final known = SubscriptionErrorCode.values.map((e) => e.code).toSet();
      for (final code in emitted) {
        expect(
          known,
          contains(code),
          reason: '$code must exist in the shared Dart error vocabulary',
        );
        declares("'$code'");
      }
    });

    test('a failure code is bounded and never a raw payload', () {
      declares("v_code := nullif(btrim(coalesce(p_failure_code, '')), '');");
      declares('if v_code is not null and char_length(v_code) > 64 then');
    });

    test(
      'a cross-account operation is reported as absent, not as a conflict',
      () {
        // Confirming an id exists elsewhere would leak another account's
        // operation.
        declares("'errorCode', 'USAGE_OPERATION_NOT_FOUND'");
      },
    );
  });
}
