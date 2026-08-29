import 'dart:io';

import 'package:facetune/features/tutorial_v3/domain/errors/tutorial_v3_failure.dart';
import 'package:flutter_test/flutter_test.dart';

/// V3-10F3 — the failure a real device actually hit.
///
/// Symptom: tapping "Step-by-step tutorial" showed
/// *"This tutorial could not be opened"* / *"The tutorial service is
/// temporarily unavailable."* after about one second, with nothing in the
/// Flutter console.
///
/// That sentence is not written anywhere in Dart. It exists in exactly one
/// reachable place in this flow: the branch of `plan-tutorial-v3`'s Gemini
/// client taken when Gemini **answers** with a non-ok status. Reaching it
/// proves the entry RPC succeeded, the session was created without a plan, and
/// the planner was invoked — so the failure is upstream of this repository, at
/// the model provider.
///
/// These tests pin that chain to the real sources, so the day the wording or
/// the envelope changes, the diagnosis recorded in
/// `docs/tutorial_v3/V3-10_STANDARD_PREVIEW_HISTORY_ENTRY_REPORT.md` §13 stops
/// being true out loud rather than quietly.
void main() {
  final root = Directory.current;

  String source(String relativePath) => File(
    '${root.path}${Platform.pathSeparator}'
    '${relativePath.replaceAll('/', Platform.pathSeparator)}',
  ).readAsStringSync();

  final geminiClient = source(
    'supabase/functions/plan-tutorial-v3/gemini_client.ts',
  );
  final index = source('supabase/functions/plan-tutorial-v3/index.ts');
  final functionDataSource = source(
    'lib/features/tutorial_v3/data/data_sources/'
    'tutorial_v3_function_data_source.dart',
  );

  /// The exact sentence the device showed.
  const observed = 'The tutorial service is temporarily unavailable.';

  group('the observed message can only come from the planner', () {
    test('the planner emits it when Gemini answers with an error', () {
      expect(geminiClient, contains('"$observed"'));
      // V3-10F4: the branch is no longer chosen by the bare HTTP status.
      // Gemini answers 400 for an invalid schema, an unusable API key and a
      // billing precondition alike, so the classification reads the error
      // envelope through the shared classifier and only a genuinely transient
      // verdict is allowed to say "temporarily unavailable".
      expect(geminiClient, contains('describeGeminiError(response)'));
      expect(geminiClient, contains('geminiFailureFor(detail)'));
      expect(
        geminiClient,
        contains('mapping.configuration\n'
            '          ? "The tutorial service is not configured correctly."\n'
            '          : "$observed"'),
      );
    });

    test('the old status-only heuristic is gone', () {
      // It grouped every non-429 rejection — HTTP 400 included — into
      // `gemini_upstream_error` + retryable, so a request that could never
      // succeed was reported to the user as a passing outage and retried.
      // The Deno suites own the behavioural proof; this pins that the defect
      // cannot return unnoticed on either side of the language boundary.
      expect(
        geminiClient,
        isNot(
          contains('const transient = response.status === 429 '
              '|| response.status >= 500'),
        ),
      );
      expect(
        geminiClient,
        isNot(contains('response.status === 429 ? 503 : 502')),
      );
    });

    test('a permanent configuration fault is never retried', () {
      final shared = source('supabase/functions/_shared/gemini_error.ts');
      // `configuration: true` and `retryable: true` must never coexist: the
      // identical body would be rejected identically, so a retry only spends
      // the step's bounded attempts.
      final mappings = RegExp(
        r'retryable: (true|false),\s*configuration: (true|false),',
      ).allMatches(shared);
      expect(mappings, isNotEmpty);
      for (final mapping in mappings) {
        if (mapping.group(2) == 'true') {
          expect(
            mapping.group(1),
            'false',
            reason: 'a configuration fault must not be retryable',
          );
        }
      }
    });

    test('a quota rejection is still 503 gemini_rate_limited', () {
      // A negative prepaid balance makes Gemini answer 429. That is one of the
      // two verdicts that stays transient, and it must remain distinguishable
      // from both `gemini_upstream_error` and the permanent 400 family.
      final shared = source('supabase/functions/_shared/gemini_error.ts');
      expect(shared, contains('code: "gemini_rate_limited"'));
      expect(shared, contains('code: "gemini_upstream_error"'));
      expect(shared, contains('code: "gemini_invalid_request"'));
      expect(shared, contains('code: "gemini_credential_rejected"'));
      expect(shared, contains('code: "gemini_account_precondition"'));
    });

    test('no Dart source produces this sentence', () {
      // If it were written on this side, the diagnosis above would be wrong.
      final lib = Directory('${root.path}${Platform.pathSeparator}lib');
      final offenders = lib
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => file.readAsStringSync().contains(observed))
          .map((file) => file.path)
          .toList();

      expect(offenders, isEmpty);
    });

    test('reaching it requires the planner, which requires an open session',
        () {
      // The planner is only invoked for a session that exists and has no plan,
      // so this message is downstream of a successful open_tutorial_v3_session.
      final controller = source(
        'lib/features/tutorial_v3/presentation/controllers/'
        'tutorial_v3_session_controller.dart',
      );
      expect(controller, contains('if (!loaded.hasPlan) {'));
      expect(controller, contains('_planner.plan(sessionId: loaded.sessionId)'));
    });
  });

  group('the envelope the client parses', () {
    test('the function returns code, message and retryable', () {
      expect(
        index,
        contains('error: {\n          code: failure.code,\n'
            '          message: failure.message,\n'
            '          retryable: failure.retryable,\n        }'),
      );
    });

    test('the client reads exactly those three fields', () {
      expect(functionDataSource, contains("payload['code']"));
      expect(functionDataSource, contains("payload['message']"));
      expect(functionDataSource, contains("payload['retryable'] == true"));
    });

    test('a 503 is classified as unavailable and stays retryable', () {
      expect(
        functionDataSource,
        contains('if (status == 429 || status == 503) {\n'
            '      return TutorialV3FailureKind.unavailable;\n    }'),
      );
      // The server's verdict decides, not the client's guess.
      expect(
        TutorialV3FailureKind.values,
        contains(TutorialV3FailureKind.unavailable),
      );
    });
  });

  group('the failure is now visible to whoever is debugging', () {
    test('the edge function failure records status, code and kind', () {
      expect(functionDataSource, contains('edge function rejected'));
      expect(functionDataSource, contains(r'status=$status'));
      expect(functionDataSource, contains('code='));
      expect(functionDataSource, contains(r'kind=${failure.kind.name}'));
      expect(functionDataSource, contains(r'retryable=${failure.retryable}'));
    });

    test('it is debug-only', () {
      expect(functionDataSource, contains('if (!kDebugMode) return;'));
    });

    test('it records nothing sensitive', () {
      // The response body carries the plan; the request carries the caller's
      // JWT. Only the server's own code, its status and the derived kind are
      // recorded.
      final logMethod = functionDataSource.substring(
        functionDataSource.indexOf('static void _logFailure'),
      );
      for (final banned in [
        'error.details',
        'error.reasonPhrase',
        'payload[',
        'root[',
        'headers',
        'token',
        'apikey',
        'authorization',
        'failure.message',
      ]) {
        expect(
          logMethod.contains(banned),
          isFalse,
          reason: '$banned must never be logged',
        );
      }
    });

    test('the entry RPC records its SQLSTATE and nothing else', () {
      final remote = source(
        'lib/features/tutorial_v3/data/data_sources/'
        'tutorial_v3_remote_data_source.dart',
      );
      expect(remote, contains('open_tutorial_v3_session rejected'));
      expect(remote, contains(r'code=${error.code ?? '));
      // `error.message` can carry the statement and its arguments.
      final logBlock = remote.substring(
        remote.indexOf('[tutorial_v3] open_tutorial_v3_session rejected'),
        remote.indexOf('// The RPC raises rather than'),
      );
      expect(logBlock.contains('error.message'), isFalse);
      expect(logBlock.contains('error.details'), isFalse);
    });

    test('a translated domain failure is no longer silent', () {
      // This was the gap: the boundary logged only *unexpected* exceptions, so
      // a correctly translated server failure produced an empty console.
      final controller = source(
        'lib/features/tutorial_v3/presentation/controllers/'
        'tutorial_v3_session_controller.dart',
      );
      expect(controller, contains('} on TutorialV3Failure catch (failure) {'));
      expect(controller, contains('_logFailure(context, failure);'));
      expect(controller, contains('void _logFailure('));
      expect(
        controller,
        contains(r'kind=${failure.kind.name} '),
      );
    });

    test('the stage names which layer failed', () {
      // "before RPC / during RPC / after RPC" is answered by the context
      // label, so each bounded operation carries a distinct one.
      final controller = source(
        'lib/features/tutorial_v3/presentation/controllers/'
        'tutorial_v3_session_controller.dart',
      );
      for (final stage in [
        "context: 'openSession'",
        "context: 'findSessionById'",
        "context: 'plan'",
        "context: 'findSessionById.replanned'",
        "context: 'ensureGeometry'",
        "context: 'loadImages'",
      ]) {
        expect(controller, contains(stage));
      }
    });
  });
}
