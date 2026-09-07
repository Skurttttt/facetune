import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the subscription domain *as written*.
///
/// These follow the established convention in this project (see
/// `tutorial_persistence_contract_test.dart` and
/// `makeup_kit_security_contract_test.dart`) of asserting architectural rules
/// against source text, because the rules they protect are ones the type system
/// cannot express: "no price lives in Flutter", "no client-side premium flag",
/// "the domain stays provider-agnostic".
///
/// Line endings are normalized before matching. Every existing contract test in
/// this repository compares multi-line substrings against files read straight
/// from disk, which fails on a CRLF checkout — that is the sole cause of the 12
/// pre-existing baseline failures recorded in `SUB_0_BASELINE_AUDIT.md`. New
/// contract tests must not inherit that defect.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  /// Reads [relativePath] with line endings normalized to `\n`.
  String source(String relativePath) =>
      File(pathOf(relativePath)).readAsStringSync().replaceAll('\r\n', '\n');

  /// [source] with whole-line comments removed.
  ///
  /// These tests search for identifiers, and an identifier named in prose is
  /// not an occurrence of it in code — a doc comment saying "never treat this
  /// as a client-side `isPremium`" is the rule being documented, not a
  /// violation of it. Only fully commented lines are dropped, so a trailing
  /// `//` after real code, or a `//` inside a string such as a URL, cannot
  /// hide anything.
  String codeOnly(String source) => source
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
      .join('\n');

  List<File> dartFilesIn(String relativeDirectory) =>
      Directory(pathOf(relativeDirectory))
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList();

  const domainRoot = 'lib/features/subscription/domain';

  group('subscription domain boundary', () {
    test('the feature has domain, data, and presentation — and no UI yet', () {
      final featureDirectories = Directory(pathOf('lib/features/subscription'))
          .listSync()
          .whereType<Directory>()
          .map((directory) => directory.path.split(Platform.pathSeparator).last)
          .toSet();

      // SUB-1 added domain; SUB-6 added the data and state path. The paywall
      // and any subscription screen belong to SUB-8, so `presentation` must
      // still contain controllers only.
      expect(featureDirectories, {'domain', 'data', 'presentation'});

      final presentationDirectories =
          Directory(pathOf('lib/features/subscription/presentation'))
              .listSync()
              .whereType<Directory>()
              .map(
                (directory) =>
                    directory.path.split(Platform.pathSeparator).last,
              )
              .toSet();
      // SUB-7 added the allowance widgets and their copy; SUB-8 added the
      // paywall screen. The full presentation layer now exists.
      expect(presentationDirectories, {
        'controllers',
        'widgets',
        'utils',
        'pages',
      });
    });

    test('the paywall cannot grant or spend an entitlement', () {
      // The screen compares plans. Anything that mutates entitlement or usage
      // is server-side, and no presentation file may reach it.
      for (final file in dartFilesIn(
        'lib/features/subscription/presentation',
      )) {
        final content = codeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        for (final forbidden in [
          'reserve_ai_look',
          'commit_ai_look',
          'release_ai_look',
          'user_entitlements',
          'usage_ledger',
          'functions.invoke',
        ]) {
          expect(
            content,
            isNot(contains(forbidden)),
            reason: '${file.path} must not touch entitlement state',
          );
        }
      }
    });

    test('the domain imports no Flutter, Supabase, or provider package', () {
      const forbiddenImports = [
        'package:flutter/',
        'package:flutter_riverpod/',
        'package:supabase',
        'package:supabase_flutter/',
        'package:go_router/',
        'package:in_app_purchase',
        'dart:io',
      ];

      for (final file in dartFilesIn(domainRoot)) {
        final content = codeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        for (final import in forbiddenImports) {
          expect(
            content,
            isNot(contains(import)),
            reason: '${file.path} must stay free of $import',
          );
        }
      }
    });

    test('no pricing is compiled into the subscription feature', () {
      // Business pricing belongs to the Source of Truth; the price a user pays
      // belongs to verified, localized store configuration. Neither belongs in
      // a Dart constant.
      const pricingTokens = ['PHP', '399', '899', '2999', '2,999', '₱'];

      for (final file in dartFilesIn('lib/features/subscription')) {
        final content = file.readAsStringSync().replaceAll('\r\n', '\n');
        for (final token in pricingTokens) {
          expect(
            content,
            isNot(contains(token)),
            reason: '${file.path} must not hardcode pricing ($token)',
          );
        }
      }
    });

    test('the allowance figures appear only in the plan catalog', () {
      final catalog = source(
        '$domainRoot/catalog/subscription_plan_catalog.dart',
      );
      for (final allowance in ['1', '3', '8', '35', '30']) {
        expect(
          catalog,
          contains('baseAiLookAllowance: $allowance,'),
          reason: 'the approved V1 allowance $allowance must be declared once',
        );
      }

      final catalogPath = pathOf(
        '$domainRoot/catalog/subscription_plan_catalog.dart',
      );
      for (final file in dartFilesIn('lib/features/subscription')) {
        if (file.path == catalogPath) continue;
        final content = file.readAsStringSync().replaceAll('\r\n', '\n');
        expect(
          content,
          isNot(contains('baseAiLookAllowance:')),
          reason: '${file.path} must not declare a second allowance value',
        );
      }
    });

    test('no client-side premium flag exists anywhere in the app', () {
      for (final file in dartFilesIn('lib')) {
        final content = codeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        expect(
          content,
          isNot(contains('isPremium')),
          reason: '${file.path} must not carry client-side premium truth',
        );
      }
    });

    test('the domain declares no repository, data source, or widget', () {
      const forbiddenDeclarations = [
        'extends StatelessWidget',
        'extends StatefulWidget',
        'extends ConsumerWidget',
        'StateNotifierProvider',
        'RemoteDataSource',
        'SupabaseClient',
      ];

      for (final file in dartFilesIn(domainRoot)) {
        final content = codeOnly(
          file.readAsStringSync().replaceAll('\r\n', '\n'),
        );
        for (final declaration in forbiddenDeclarations) {
          expect(
            content,
            isNot(contains(declaration)),
            reason: '${file.path} must not contain $declaration in SUB-1',
          );
        }
      }
    });

    test('the plan catalog is not treated as entitlement authority', () {
      // A live entitlement carries its own server-resolved allowance. If the
      // entitlement model ever read the catalog, an adjusted Salon Pilot grant
      // would be silently understated.
      final entitlement = source(
        '$domainRoot/entities/subscription_entitlement.dart',
      );
      expect(entitlement, isNot(contains('SubscriptionPlanCatalog')));
    });
  });
}
