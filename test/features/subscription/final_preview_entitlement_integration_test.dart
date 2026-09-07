import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the SUB-5 Final Preview entitlement integration.
///
/// Two things are asserted here, and the second matters as much as the first:
///
///   1. Both billable entry points are wrapped with reserve / commit / release
///      at the correct seams.
///   2. The protected V4 AI configuration is *unchanged*. Subscription work is
///      allowed to wrap the Final Preview lifecycle and nothing else, so these
///      pin the model lock, both prompt versions, and the absence of any
///      cheaper path for lower-tier plans.
///
/// Matching is whitespace-insensitive via [declares], for the reason given in
/// `subscription_persistence_contract_test.dart`.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  String collapse(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// [path] with comments removed, so an identifier named in prose is not
  /// mistaken for code. Both `//` lines and `/* */` blocks are stripped — a doc
  /// comment explaining why a function is *not* called must not read as a call
  /// to it.
  String codeOf(String path) => collapse(
    source(path)
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ')
        .split(RegExp(r'\r?\n'))
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n'),
  );

  const standardPath = 'supabase/functions/generate-makeup-preview/index.ts';
  const kitPath = 'supabase/functions/generate-kit-makeup-preview/index.ts';
  const usagePath = 'supabase/functions/_shared/ai_look_usage.ts';

  final standard = codeOf(standardPath);
  final kit = codeOf(kitPath);
  final usage = codeOf(usagePath);

  final billablePaths = {'standard': standard, 'makeup_kit': kit};

  group('protected V4 AI configuration is unchanged', () {
    test('the Final Preview model lock is untouched', () {
      expect(
        source('supabase/functions/_shared/final_preview_model.ts'),
        contains('export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image"'),
      );
    });

    test('both prompt versions are untouched', () {
      expect(
        source('supabase/functions/generate-makeup-preview/prompt.ts'),
        contains('MAKEUP_PREVIEW_PROMPT_VERSION = "makeup_preview_v2"'),
      );
      expect(
        source('supabase/functions/generate-kit-makeup-preview/prompt.ts'),
        contains('KIT_MAKEUP_PREVIEW_PROMPT_VERSION = "kit_makeup_preview_v1"'),
      );
    });

    test('both paths still resolve the model through the shared lock', () {
      for (final entry in billablePaths.entries) {
        expect(
          entry.value,
          contains('const model = FINAL_PREVIEW_MODEL;'),
          reason: '${entry.key} must not select its own model',
        );
        expect(
          entry.value,
          contains('finalPreviewModelConfigurationError()'),
          reason: '${entry.key} must still fail closed on misconfiguration',
        );
      }
    });

    test('no plan-dependent AI path exists', () {
      // A cheaper model or prompt for Free or Plus users is forbidden: the
      // canonical preview is the tutorial's visual authority and must be
      // comparable across every plan.
      for (final entry in billablePaths.entries) {
        for (final forbidden in [
          'planCode',
          'plan_code',
          'salon_pro',
          'isPremium',
          'FREE_MODEL',
          'fallbackModel',
        ]) {
          expect(
            entry.value,
            isNot(contains(forbidden)),
            reason:
                '${entry.key} must not branch AI behaviour on plan '
                '($forbidden)',
          );
        }
      }
    });

    test('the existing abuse rate limiter still runs on both paths', () {
      // consume_ai_quota answers a different question from the usage ledger
      // and must keep working alongside it.
      expect(standard, contains('consumeAiQuota(client, "makeup_preview")'));
      expect(kit, contains('consumeAiQuota(client, "kit_makeup_preview")'));
    });
  });

  group('both billable entry points are wrapped', () {
    test('each reserves, commits, and releases', () {
      for (final entry in billablePaths.entries) {
        expect(
          entry.value,
          contains('reserveAiLook(client, requestedOperationId)'),
          reason: '${entry.key} must reserve',
        );
        expect(
          entry.value,
          contains('commitAiLook('),
          reason: '${entry.key} must commit',
        );
        expect(
          entry.value,
          contains('releaseAiLook('),
          reason: '${entry.key} must be able to release',
        );
      }
    });

    test('each commits with its own source mode', () {
      expect(
        standard,
        contains(
          '"standard", (inserted as Record<string, unknown>).id as string',
        ),
      );
      expect(
        kit,
        contains(
          '"makeup_kit", (inserted as unknown as Record<string, unknown>).id '
          'as string',
        ),
      );
    });
  });

  group('reserve happens before any paid work', () {
    test('the reservation precedes the Gemini call on both paths', () {
      for (final entry in billablePaths.entries) {
        final reserveAt = entry.value.indexOf('reserveAiLook(');
        // lastIndexOf, so this finds the call site rather than the import at
        // the top of the file.
        final geminiAt = entry.value.lastIndexOf('requestGemini');
        expect(reserveAt, greaterThan(-1));
        expect(geminiAt, greaterThan(-1));
        expect(
          reserveAt,
          lessThan(geminiAt),
          reason:
              '${entry.key}: an exhausted or blocked entitlement must stop '
              'the request before Gemini is contacted',
        );
      }
    });

    test('the reservation follows the ownership proof on both paths', () {
      // Reserving before ownership is proven would let an invalid request burn
      // capacity.
      for (final entry in billablePaths.entries) {
        expect(
          entry.value.indexOf('isOwnedOriginalPath('),
          lessThan(entry.value.indexOf('reserveAiLook(')),
          reason: '${entry.key}: ownership first, then capacity',
        );
      }
    });

    test('a denied reservation throws before generation', () {
      for (final entry in billablePaths.entries) {
        expect(entry.value, contains('if (!reservation.ok)'));
        expect(
          entry.value,
          contains('usageFailureStatus(reservation.errorCode)'),
        );
      }
    });
  });

  group('commit happens only after a usable persisted preview', () {
    test('the commit follows the database insert, not the storage upload', () {
      // An uploaded object with no row is unreachable from History, Saved
      // Looks, Tutorial and reopen — not a usable result, so not chargeable.
      for (final entry in billablePaths.entries) {
        final uploadAt = entry.value.indexOf('.upload(candidatePath');
        // Both paths clear `uploadedPath` immediately after a successful row
        // insert, so it marks the persistence boundary on either function.
        final insertAt = entry.value.indexOf('uploadedPath = null;');
        final commitAt = entry.value.indexOf('commitAiLook(');
        expect(uploadAt, lessThan(commitAt));
        expect(insertAt, lessThan(commitAt));
      }
    });

    test('persistence is flagged before the commit is attempted', () {
      for (final entry in billablePaths.entries) {
        expect(entry.value, contains('previewPersisted = true;'));
        expect(
          entry.value.indexOf('previewPersisted = true;'),
          lessThan(entry.value.indexOf('commitAiLook(')),
        );
      }
    });

    test('a failed commit does not fail the request', () {
      // The user already owns the preview; refusing to return it would be a
      // worse outcome than a deferred charge that reconciliation resolves.
      for (final entry in billablePaths.entries) {
        expect(entry.value, contains('ai_look_commit_deferred'));
        expect(entry.value, isNot(contains('if (!commit.ok) { throw')));
      }
    });
  });

  group('release only on authoritative failure without a usable result', () {
    test('release is guarded by the persistence flag on both paths', () {
      for (final entry in billablePaths.entries) {
        expect(
          entry.value,
          contains('if (heldOperationId && !previewPersisted && userClient) {'),
          reason: '${entry.key}: a persisted preview must never be released',
        );
      }
    });

    test(
      'release lives in the catch block, the one authoritative failure point',
      () {
        for (final entry in billablePaths.entries) {
          expect(
            entry.value.indexOf('} catch (error) {'),
            lessThan(entry.value.indexOf('releaseAiLook(')),
          );
        }
      },
    );

    test('nothing releases on a client timeout or disconnect', () {
      // A client that stops waiting never reaches server code, so there is no
      // timer, no abort handler, and no navigation signal to react to.
      for (final entry in billablePaths.entries) {
        for (final forbidden in [
          'AbortController',
          'setTimeout(',
          'request.signal',
          'onabort',
        ]) {
          expect(
            entry.value,
            isNot(contains(forbidden)),
            reason: '${entry.key} must not release on client behaviour',
          );
        }
      }
    });
  });

  group('idempotency', () {
    test('an operation id is accepted and constrained to a uuid', () {
      for (final entry in billablePaths.entries) {
        expect(entry.value, contains('function operationId(value: unknown)'));
        expect(
          entry.value,
          contains('!uuidPattern.test(supplied)'),
          reason:
              '${entry.key}: a storage path or other user content must not '
              'become an idempotency key',
        );
        expect(entry.value, contains('return crypto.randomUUID();'));
      }
    });

    test('a replayed committed operation returns the existing preview', () {
      // This is what makes a lost response or a client timeout safe: the
      // preview is returned rather than generated and charged again.
      for (final entry in billablePaths.entries) {
        expect(
          entry.value,
          contains('reservation.errorCode === "USAGE_ALREADY_COMMITTED"'),
        );
        expect(entry.value, contains('.from("usage_ledger")'));
      }
      expect(standard, contains('canonical_generated_image_id'));
      expect(kit, contains('canonical_kit_generated_image_id'));
    });
  });

  group('the shared usage client', () {
    test('exposes only the three lifecycle operations', () {
      for (final fn in [
        'export function reserveAiLook(',
        'export function commitAiLook(',
        'export function releaseAiLook(',
      ]) {
        expect(usage, contains(fn));
      }
      // Reconciliation is not client-callable and must not be wrapped here.
      expect(usage, isNot(contains('reconcile_stale_ai_look_reservations')));
    });

    test('never sends a user id or a timestamp', () {
      for (final forbidden in ['p_user', 'user_id', 'p_now', 'auth.uid']) {
        expect(usage, isNot(contains(forbidden)));
      }
    });

    test('fails closed on an unreachable engine', () {
      expect(usage, contains("errorCode: \"TEMPORARY_BACKEND_FAILURE\""));
      expect(usage, contains('ok: false'));
    });

    test('bounds the failure code it forwards', () {
      expect(usage, contains('failureCode.slice(0, 64)'));
    });

    test('an exhausted allowance is distinguishable from a blocked one', () {
      // 402 invites an upgrade; 403 does not, because upgrading would not fix
      // a suspended or revoked entitlement.
      expect(usage, contains('case "AI_LOOK_LIMIT_REACHED": return 402;'));
      expect(usage, contains('case "ENTITLEMENT_SUSPENDED":'));
      expect(usage, contains('return 403;'));
    });
  });

  group('nothing outside the Final Preview seam changed', () {
    test('the tutorial functions bill no AI Look', () {
      // Tutorial is included with the AI Look: opening or reopening it must
      // never reserve, commit, or release.
      for (final path in [
        'supabase/functions/generate-tutorial-step-v4/index.ts',
        'supabase/functions/analyze-tutorial-manifest-v4/index.ts',
      ]) {
        final content = codeOf(path);
        for (final forbidden in [
          'reserveAiLook',
          'commitAiLook',
          'releaseAiLook',
          'usage_ledger',
        ]) {
          expect(
            content,
            isNot(contains(forbidden)),
            reason: '$path must remain non-billable',
          );
        }
      }
    });

    test('history, analysis, and recommendation paths bill no AI Look', () {
      // Reopening an existing Final Preview reserves nothing, because no read
      // path touches the usage engine at all.
      for (final path in [
        'supabase/functions/delete-history-item/index.ts',
        'supabase/functions/analyze-face/index.ts',
        'supabase/functions/generate-makeup-recommendation/index.ts',
        'supabase/functions/generate-kit-makeup-recommendation/index.ts',
      ]) {
        final content = codeOf(path);
        for (final forbidden in [
          'reserveAiLook',
          'commitAiLook',
          'releaseAiLook',
        ]) {
          expect(
            content,
            isNot(contains(forbidden)),
            reason: '$path must not consume an AI Look',
          );
        }
      }
    });
  });
}
