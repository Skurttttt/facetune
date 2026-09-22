import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the Web Admin *as written*.
///
/// Same convention as `subscription_billing_security_test.dart`: these assert
/// the WA-2 hard locks against source text, because they protect properties
/// the type system cannot express — "no service-role credential can reach the
/// admin bundle", "no admin email is hardcoded", "no local flag is an
/// authority". Line endings are normalized so a CRLF checkout does not fail
/// them.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  String codeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .where((line) => !line.trimLeft().startsWith('///'))
      .join('\n');

  List<File> dartFilesIn(String relativeDirectory) {
    final directory = Directory(pathOf(relativeDirectory));
    if (!directory.existsSync()) return const <File>[];
    return directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
  }

  String codeOf(File file) =>
      codeOnly(file.readAsStringSync().replaceAll('\r\n', '\n'));

  final adminFiles = [
    ...dartFilesIn('lib/admin'),
    File(pathOf('lib/admin_main.dart')),
  ];

  test('the admin tree exists and is non-trivial', () {
    expect(adminFiles.length, greaterThan(10));
  });

  group('service-role exposure', () {
    test('no admin source names a service-role credential', () {
      for (final file in adminFiles) {
        final code = codeOf(file).toLowerCase();
        expect(code, isNot(contains('service_role')), reason: file.path);
        expect(code, isNot(contains('servicerole')), reason: file.path);
        expect(code, isNot(contains('service-role')), reason: file.path);
      }
    });

    test(
      'the admin entrypoint reads only the public Supabase configuration',
      () {
        final bootstrap = codeOf(
          File(pathOf('lib/admin/app/admin_bootstrap.dart')),
        );
        expect(bootstrap, contains('SupabaseConfig.fromEnvironment()'));
        final defines = RegExp(r"String\.fromEnvironment\('([A-Z_]+)'\)");
        for (final file in adminFiles) {
          for (final match in defines.allMatches(codeOf(file))) {
            expect(
              match.group(1),
              isIn(['SUPABASE_URL', 'SUPABASE_PUBLISHABLE_KEY']),
              reason: '${file.path} reads an unexpected define',
            );
          }
        }
      },
    );
  });

  group('no client-side authority', () {
    test('no admin email, user id, or password is hardcoded', () {
      final email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}');
      final uuid = RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      );
      for (final file in adminFiles) {
        final code = codeOf(file);
        expect(
          email.hasMatch(code),
          isFalse,
          reason: '${file.path} has an email',
        );
        expect(uuid.hasMatch(code), isFalse, reason: '${file.path} has a uuid');
        expect(
          RegExp("password\\s*[:=]\\s*['\"]").hasMatch(code),
          isFalse,
          reason: '${file.path} has a password literal',
        );
      }
    });

    test(
      'no local storage, preference, or flag is consulted for admin status',
      () {
        for (final file in adminFiles) {
          final code = codeOf(file);
          for (final forbidden in [
            'localStorage',
            'sessionStorage',
            'SharedPreferences',
            'window.localStorage',
            'isAdmin =',
            'isAdmin:',
            'kDebugMode',
            'debugAdmin',
            'adminOverride',
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

    test('no admin source inspects JWT claims or app metadata', () {
      for (final file in adminFiles) {
        final code = codeOf(file);
        for (final forbidden in [
          'appMetadata',
          'app_metadata',
          'userMetadata',
          'user_metadata',
          'accessToken',
          'JwtDecoder',
          'jwt_decode',
          'currentSession!.user.role',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason: '${file.path}: $forbidden',
          );
        }
      }
    });

    test('email is never compared to decide authorization', () {
      final emailCompare = RegExp("email\\s*==\\s*['\"]|endsWith\\('@");
      for (final file in adminFiles) {
        expect(emailCompare.hasMatch(codeOf(file)), isFalse, reason: file.path);
      }
    });

    test('the only path to an authorized state is the session gateway', () {
      final producers = adminFiles.where(
        (file) => codeOf(file).contains('AdminAuthorized('),
      );
      // The state class itself, the controller that produces it, and the
      // router/pages that match on it — but only the controller constructs
      // it from a gateway answer.
      final constructing = producers.where(
        (file) => RegExp(r'=\s*AdminAuthorized\(').hasMatch(codeOf(file)),
      );
      expect(
        constructing.map((f) => f.path.split(Platform.pathSeparator).last),
        ['admin_authorization_controller.dart'],
      );
      final controller = codeOf(
        File(
          pathOf(
            'lib/admin/auth/presentation/admin_authorization_controller.dart',
          ),
        ),
      );
      expect(controller, contains('_gateway.verifyAdminSession()'));
    });

    test('the gateway sends no claim about the caller', () {
      final gateway = codeOf(
        File(pathOf('lib/admin/auth/data/supabase_admin_session_gateway.dart')),
      );
      expect(gateway, contains("'admin-session'"));
      expect(gateway, isNot(contains('body:')));
    });
  });

  group('separation from the consumer app', () {
    test('the consumer entrypoint and router do not reach the admin tree', () {
      for (final path in [
        'lib/main.dart',
        'lib/app/app.dart',
        'lib/app/router/app_router.dart',
        'lib/app/bootstrap/bootstrap.dart',
      ]) {
        expect(
          codeOf(File(pathOf(path))),
          isNot(contains('admin/')),
          reason: path,
        );
      }
      for (final file in dartFilesIn('lib/features')) {
        expect(codeOf(file), isNot(contains('/admin/')), reason: file.path);
      }
    });

    test('the admin tree offers no guest, registration, or OAuth sign-in', () {
      for (final file in adminFiles) {
        final code = codeOf(file);
        for (final forbidden in [
          'signInAnonymously',
          'registerWithEmail',
          'signInWithGoogle',
          'sendPasswordReset',
        ]) {
          expect(
            code,
            isNot(contains('.$forbidden(')),
            reason: '${file.path}: $forbidden',
          );
        }
      }
    });
  });

  group('server side', () {
    test('the admin-session function holds no service-role key', () {
      final function = File(
        pathOf('supabase/functions/admin-session/index.ts'),
      ).readAsStringSync();
      expect(function, isNot(contains('SERVICE_ROLE')));
      expect(function, contains('SUPABASE_ANON_KEY'));
      expect(function, contains('requireAdmin('));
      final helper = File(
        pathOf('supabase/functions/_shared/admin_auth.ts'),
      ).readAsStringSync();
      expect(helper, isNot(contains('SERVICE_ROLE')));
      expect(helper, contains('current_user_is_admin'));
    });

    test('the gateway JWT check is enabled for admin-session', () {
      final config = File(
        pathOf('supabase/config.toml'),
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(config, contains('[functions.admin-session]\nverify_jwt = true'));
    });

    test('the WA-7 grant function is gated twice and holds no secret', () {
      final function = File(
        pathOf('supabase/functions/admin-grant-salon-pilot/index.ts'),
      ).readAsStringSync();
      expect(function, isNot(contains('SERVICE_ROLE')));
      expect(function, contains('SUPABASE_ANON_KEY'));
      expect(function, contains('requireAdmin('));
      expect(function, contains('admin_grant_salon_pilot'));
      // The body is intent only: the function never forwards an admin id,
      // a before-state, or an entitlement status from the request.
      expect(function, isNot(contains('p_admin_user_id')));
      final config = File(
        pathOf('supabase/config.toml'),
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        config,
        contains('[functions.admin-grant-salon-pilot]\nverify_jwt = true'),
      );
      // The Flutter tree reaches the writer only through the Edge Function.
      final adminSources = Directory(pathOf('lib/admin'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(adminSources, isNot(contains("'admin_grant_salon_pilot'")));
      expect(adminSources, contains("'admin-grant-salon-pilot'"));
    });

    test(
      'the WA-8 adjustment function is gated twice and writes only via the ledger',
      () {
        final function = File(
          pathOf(
            'supabase/functions/admin-adjust-salon-pilot-allowance/index.ts',
          ),
        ).readAsStringSync();
        expect(function, isNot(contains('SERVICE_ROLE')));
        expect(function, contains('SUPABASE_ANON_KEY'));
        expect(function, contains('requireAdmin('));
        expect(function, contains('admin_adjust_salon_pilot_allowance'));
        expect(function, isNot(contains('p_admin_user_id')));
        final config = File(
          pathOf('supabase/config.toml'),
        ).readAsStringSync().replaceAll('\r\n', '\n');
        expect(
          config,
          contains(
            '[functions.admin-adjust-salon-pilot-allowance]\nverify_jwt = true',
          ),
        );
        // The writer never sets the adjustment total or touches usage rows
        // itself: the audited ledger's trigger is the only path.
        final writer = File(
          pathOf(
            'supabase/migrations/20260930000100_admin_adjust_salon_pilot_allowance.sql',
          ),
        ).readAsStringSync();
        expect(
          writer,
          isNot(matches(RegExp(r'set\s+allowance_adjustment_total'))),
        );
        expect(
          writer,
          isNot(
            matches(
              RegExp(
                r'(update|delete from|insert into)\s+public\.usage_ledger',
              ),
            ),
          ),
        );
        expect(
          writer,
          contains('insert into public.entitlement_allowance_adjustments'),
        );
        final adminSources = Directory(pathOf('lib/admin'))
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .map((f) => f.readAsStringSync())
            .join('\n');
        expect(
          adminSources,
          isNot(contains("'admin_adjust_salon_pilot_allowance'")),
        );
        expect(adminSources, contains("'admin-adjust-salon-pilot-allowance'"));
      },
    );

    test('the WA-9 lifecycle function is gated twice and holds no secret', () {
      final function = File(
        pathOf('supabase/functions/admin-salon-pilot-lifecycle/index.ts'),
      ).readAsStringSync();
      expect(function, isNot(contains('SERVICE_ROLE')));
      expect(function, contains('SUPABASE_ANON_KEY'));
      expect(function, contains('requireAdmin('));
      expect(function, contains('admin_extend_salon_pilot_expiration'));
      expect(function, contains('admin_set_salon_pilot_lifecycle'));
      expect(function, isNot(contains('p_admin_user_id')));

      final config = File(
        pathOf('supabase/config.toml'),
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        config,
        contains('[functions.admin-salon-pilot-lifecycle]\nverify_jwt = true'),
      );

      // Browser presentation knows only the Edge Function name. The two
      // security-definer writer names stay behind that server boundary.
      final adminSources = Directory(pathOf('lib/admin'))
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      expect(
        adminSources,
        isNot(contains("'admin_extend_salon_pilot_expiration'")),
      );
      expect(
        adminSources,
        isNot(contains("'admin_set_salon_pilot_lifecycle'")),
      );
      expect(adminSources, contains("'admin-salon-pilot-lifecycle'"));

      final gateway = File(
        pathOf(
          'lib/admin/salon_pilot/data/supabase_admin_salon_pilot_gateway.dart',
        ),
      ).readAsStringSync();
      expect(gateway, contains('applyLifecycle(LifecycleIntent intent)'));
      expect(
        gateway,
        contains('_invoke(lifecycleFunctionName, intent.toRequestBody())'),
      );
    });

    test('the roster is unreadable by every client role', () {
      final migration = File(
        pathOf('supabase/migrations/20260925000100_admin_identity.sql'),
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        migration,
        contains('alter table public.admin_users enable row level security;'),
      );
      for (final role in ['anon', 'authenticated', 'service_role']) {
        expect(
          migration,
          contains('revoke all on table public.admin_users from $role;'),
        );
      }
      expect(migration, isNot(contains('create policy')));
      expect(
        migration,
        contains(
          'grant execute on function public.current_user_is_admin() to authenticated;',
        ),
      );
      expect(
        migration,
        isNot(
          contains(
            'grant execute on function public.is_admin(uuid) to authenticated',
          ),
        ),
      );
    });

    test('WA-5 reads no private FaceTune content source', () {
      final migration =
          File(
                pathOf(
                  'supabase/migrations/20260927000100_admin_users_search_and_detail.sql',
                ),
              )
              .readAsStringSync()
              .replaceAll('\r\n', '\n')
              .split('\n')
              .where((line) => !line.trimLeft().startsWith('--'))
              .join('\n')
              .toLowerCase();
      for (final forbidden in [
        'face_images',
        'analysis_results',
        'generated_images',
        'tutorial_sessions',
        'tutorial_steps',
        'makeup_kit_products',
        'kit_makeup_recommendations',
        'storage.objects',
        'signed_url',
        'raw_prompt',
        'gemini',
      ]) {
        expect(migration, isNot(contains(forbidden)), reason: forbidden);
      }
      expect(migration, contains('limit 26'));
      expect(migration, contains('limit 25'));
    });
  });
}
