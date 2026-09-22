import 'dart:io';

import 'package:facetune/admin/salon_pilot/data/supabase_admin_salon_pilot_gateway.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// WA-12 — web-security contract over the Web Admin *as written*.
///
/// The architecture is a Flutter Web bundle with a token-based Supabase
/// session (no cookies), calling PostgREST RPCs and bearer-authenticated Edge
/// Functions. These tests pin the controls that architecture actually needs
/// (Web Admin SOT §75): no HTML/JS sinks that could turn server data into
/// markup, no cookie-style CORS, every admin function behind the gateway JWT
/// check, no caching of authorization answers, and a rate-limited answer that
/// the browser treats as "try again" rather than as a partial success.
void main() {
  final root = Directory.current;
  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';
  String read(String relativePath) =>
      File(pathOf(relativePath)).readAsStringSync().replaceAll('\r\n', '\n');
  List<File> dartFilesIn(String dir) => Directory(pathOf(dir))
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  const adminFunctions = [
    'admin-session',
    'admin-grant-salon-pilot',
    'admin-adjust-salon-pilot-allowance',
    'admin-salon-pilot-lifecycle',
  ];

  group('XSS surface', () {
    test('the admin tree has no HTML, JS-interop, or URL-launching sink', () {
      for (final file in dartFilesIn('lib/admin')) {
        final code = file.readAsStringSync();
        for (final sink in [
          'dart:html',
          'dart:js',
          'dart:js_interop',
          'package:js/',
          'js_util',
          'innerHtml',
          'HtmlElementView',
          'WebView',
          'flutter_html',
          'url_launcher',
          'launchUrl(',
          'Uri.parse(',
        ]) {
          expect(code, isNot(contains(sink)), reason: '${file.path}: $sink');
        }
      }
    });

    test('server-supplied text is rendered only through Text widgets', () {
      // Every admin page renders through the framework's text widgets, which
      // never interpret markup. No page builds widgets from raw HTML strings.
      for (final file in dartFilesIn('lib/admin')) {
        final code = file.readAsStringSync();
        expect(code, isNot(contains('RichText.fromHtml')), reason: file.path);
        expect(code, isNot(contains('Html.fromDom')), reason: file.path);
      }
    });
  });

  group('Edge Function boundary', () {
    test('every admin function is behind the gateway JWT check', () {
      final config = read('supabase/config.toml');
      for (final fn in adminFunctions) {
        expect(
          config,
          contains('[functions.$fn]\nverify_jwt = true'),
          reason: fn,
        );
      }
    });

    test(
      'bearer-only CORS: no credentialed cross-origin access, no caching',
      () {
        for (final fn in adminFunctions) {
          final code = read('supabase/functions/$fn/index.ts');
          expect(
            code,
            isNot(contains('Access-Control-Allow-Credentials')),
            reason: '$fn must not enable credentialed CORS',
          );
          expect(code, contains('"cache-control": "no-store"'), reason: fn);
          expect(code, contains('requireAdmin('), reason: fn);
          expect(code, isNot(contains('SERVICE_ROLE')), reason: fn);
          expect(code, contains('SUPABASE_ANON_KEY'), reason: fn);
          // Only POST (and preflight) reaches a mutation; GET is allowed only on
          // the session check, which mutates nothing.
          if (fn != 'admin-session') {
            expect(code, contains('request.method !== "POST"'), reason: fn);
          }
        }
      },
    );

    test(
      'mutation functions answer a throttled request as 429 with Retry-After',
      () {
        for (final fn in adminFunctions.where((f) => f != 'admin-session')) {
          final code = read('supabase/functions/$fn/index.ts');
          expect(code, contains('status === 429'), reason: fn);
          expect(code, contains('"retry-after": "60"'), reason: fn);
        }
        final shared = read('supabase/functions/_shared/admin_mutations.ts');
        expect(shared, contains('throttled ? 429'));
      },
    );

    test('the writers consume a per-administrator budget before any work', () {
      final migration = read(
        'supabase/migrations/20261003000100_admin_abuse_protection.sql',
      );
      for (final fn in [
        'admin_grant_salon_pilot',
        'admin_adjust_salon_pilot_allowance',
        'admin_extend_salon_pilot_expiration',
        'admin_set_salon_pilot_lifecycle',
        'admin_search_users',
      ]) {
        expect(
          migration,
          contains('CREATE OR REPLACE FUNCTION public.$fn('),
          reason: fn,
        );
      }
      expect(
        RegExp(
          r"admin_consume_budget\(v_caller, 'mutation'\)",
        ).allMatches(migration).length,
        4,
      );
      expect(
        RegExp(
          r"admin_consume_budget\(v_caller, 'search'\)",
        ).allMatches(migration).length,
        1,
      );
      expect(migration, contains('enable row level security'));
      expect(
        migration,
        contains(
          'revoke all on function public.admin_consume_budget(uuid, text) from authenticated',
        ),
      );
    });
  });

  group('browser handling of a throttled answer', () {
    test(
      '429 becomes a retryable failure with the server message, never a success',
      () {
        final failure = SupabaseAdminSalonPilotGateway.failureFrom(
          FunctionException(
            status: 429,
            details: {
              'success': false,
              'action': 'increase_allowance',
              'errorCode': 'TEMPORARY_BACKEND_FAILURE',
              'message':
                  'Too many admin operations in the last minute. Wait a moment and try again.',
              'retryable': true,
              'throttled': true,
              'retryAfterSeconds': 60,
            },
          ),
        );
        expect(failure, isA<AdminMutationFailure>());
        final mutation = failure as AdminMutationFailure;
        expect(mutation.code, AdminMutationErrorCode.temporaryBackendFailure);
        expect(mutation.retryable, isTrue);
        expect(mutation.message, contains('Too many'));
      },
    );
  });

  group('session model', () {
    test(
      'no admin source persists or reads the session outside the Supabase SDK',
      () {
        for (final file in dartFilesIn('lib/admin')) {
          final code = file.readAsStringSync();
          for (final forbidden in [
            'SharedPreferences',
            'localStorage',
            'sessionStorage',
            'document.cookie',
            'accessToken',
            'refreshToken',
            'persistSession',
          ]) {
            expect(
              code,
              isNot(contains(forbidden)),
              reason: '${file.path}: $forbidden',
            );
          }
        }
      },
    );

    test(
      'signing out goes through the auth repository, and the state is dropped',
      () {
        final controller = read(
          'lib/admin/auth/presentation/admin_authorization_controller.dart',
        );
        expect(controller, contains('signOut()'));
        expect(controller, contains('AdminUnauthenticated('));
        // A server refusal on any later call drops the authorized state too.
        expect(controller, contains('handleServerRefusal'));
      },
    );
  });
}
