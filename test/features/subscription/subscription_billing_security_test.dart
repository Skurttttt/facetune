import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract tests over the billing integration *as written*.
///
/// Same convention as `subscription_domain_boundary_test.dart`: these assert
/// architectural and security rules against source text, because they protect
/// properties the type system cannot express — "no provider credential is ever
/// compiled into the app", "the purchase token is never logged", "the billing
/// SDK does not leak past the data layer".
///
/// Line endings are normalized before matching, so a CRLF checkout does not
/// fail them.
void main() {
  final root = Directory.current;

  String pathOf(String relativePath) =>
      '${root.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}';

  String source(String relativePath) =>
      File(pathOf(relativePath)).readAsStringSync().replaceAll('\r\n', '\n');

  /// [text] with whole-line comments removed, so a rule *described* in prose is
  /// not mistaken for a violation of it.
  String codeOnly(String text) => text
      .split('\n')
      .where((line) => !line.trimLeft().startsWith('//'))
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

  const subscriptionRoot = 'lib/features/subscription';
  const dataRoot = '$subscriptionRoot/data';
  const domainRoot = '$subscriptionRoot/domain';
  const presentationRoot = '$subscriptionRoot/presentation';

  group('no Google credential is compiled into the app', () {
    test('no service-account or private-key material anywhere in lib', () {
      // Server verification authenticates as a service account. That credential
      // belongs to the backend and must never be shipped in an APK, where it
      // could be extracted and used to mint entitlements.
      const forbidden = [
        'service_account',
        'serviceAccount',
        'private_key',
        'privateKey',
        'BEGIN PRIVATE KEY',
        'androidpublisher',
        'client_email',
        'service-role',
        'serviceRole',
      ];

      for (final file in dartFilesIn('lib')) {
        final content = codeOf(file);
        for (final token in forbidden) {
          expect(
            content,
            isNot(contains(token)),
            reason: '${file.path} must not carry provider credentials',
          );
        }
      }
    });

    test('no credential file was added to the repository', () {
      for (final name in [
        'service-account.json',
        'service_account.json',
        'google-services.json',
        'play-service-account.json',
      ]) {
        expect(
          File(pathOf(name)).existsSync(),
          isFalse,
          reason: '$name must not exist in the repository',
        );
      }
    });
  });

  group('the purchase token is never logged', () {
    test('the subscription feature prints nothing at all', () {
      // The narrow rule is "never log a token". The rule enforced is "never
      // log", because a log statement that is safe today is one careless edit
      // away from interpolating the evidence it sits next to.
      for (final file in dartFilesIn(subscriptionRoot)) {
        final content = codeOf(file);
        for (final call in ['print(', 'debugPrint(', 'log(', 'developer.log']) {
          expect(
            content,
            isNot(contains(call)),
            reason: '${file.path} must not log — tokens travel through here',
          );
        }
      }
    });

    test('evidence redacts its token in string form', () {
      final evidence = source('$domainRoot/entities/purchase_evidence.dart');
      expect(evidence, contains('[REDACTED]'));
      // The only toString must not interpolate the token itself.
      expect(codeOnly(evidence), isNot(contains(r'$purchaseToken')));
    });
  });

  group('the billing SDK stays in the data layer', () {
    test('the domain imports no billing package', () {
      for (final file in dartFilesIn(domainRoot)) {
        final content = codeOf(file);
        expect(
          content,
          isNot(contains('package:in_app_purchase')),
          reason: '${file.path} must stay provider-agnostic',
        );
      }
    });

    test('presentation imports no billing package', () {
      // Controllers and widgets work in domain terms only, so the provider can
      // be faked in a test and swapped without touching the UI.
      for (final file in dartFilesIn(presentationRoot)) {
        final content = codeOf(file);
        expect(
          content,
          isNot(contains('package:in_app_purchase')),
          reason: '${file.path} must not reach the billing SDK directly',
        );
      }
    });

    test('only the data layer names the SDK', () {
      final importers = dartFilesIn(subscriptionRoot)
          .where((file) => codeOf(file).contains('package:in_app_purchase'))
          .map((file) => file.path.replaceAll(Platform.pathSeparator, '/'))
          .map((path) => path.split('lib/').last)
          .toSet();

      expect(importers, {
        'features/subscription/data/data_sources/'
            'google_play_billing_data_source.dart',
        'features/subscription/data/repositories/'
            'google_play_billing_gateway.dart',
      });
    });
  });

  group('store product identifiers live in one place', () {
    test('the approved ids appear only in the store product catalog', () {
      final catalogPath = pathOf('$domainRoot/catalog/store_product_catalog.dart');

      for (final file in dartFilesIn('lib')) {
        if (file.path == catalogPath) continue;
        final content = codeOf(file);
        for (final productId in [
          'facetune_plus',
          'facetune_pro',
          'facetune_salon_pro',
        ]) {
          expect(
            content,
            isNot(contains(productId)),
            reason: '${file.path} must read product ids from the catalog',
          );
        }
      }
    });

    test('no product identifier exists for Salon Pilot or Free', () {
      final catalog = codeOnly(
        source('$domainRoot/catalog/store_product_catalog.dart'),
      );

      expect(catalog, isNot(contains('salonPilot')));
      expect(catalog, isNot(contains('salon_pilot')));
      expect(catalog, isNot(contains('SubscriptionPlanCode.free')));
      // And nothing that merely looks like one.
      expect(catalog, isNot(contains('pilot')));
    });
  });

  group('the client cannot grant itself an entitlement', () {
    test('nothing in the feature writes a plan or an allowance locally', () {
      const forbidden = [
        'isPremium',
        'setPlan',
        'grantPlan',
        'grantEntitlement',
        'unlockPremium',
        'purchaseSucceeded',
      ];

      for (final file in dartFilesIn(subscriptionRoot)) {
        final content = codeOf(file);
        for (final token in forbidden) {
          expect(
            content,
            isNot(contains(token)),
            reason: '${file.path} must not grant anything',
          );
        }
      }
    });

    test('acknowledgement is named for its precondition', () {
      // The provider-facing acknowledgement is reachable only through a method
      // whose name states that the server has already verified the purchase, so
      // an unverified call reads as wrong at the call site.
      final gateway = source('$domainRoot/repositories/store_billing_gateway.dart');
      expect(gateway, contains('completeVerifiedPurchase'));

      final controller = codeOnly(
        source('$presentationRoot/controllers/purchase_controller.dart'),
      );
      // Verification is awaited before acknowledgement in the source order.
      // The gateway is resolved on demand, hence the call before `.verify`.
      final verifyAt = controller.indexOf('_verification().verify(');
      final completeAt = controller.indexOf('completeVerifiedPurchase(');
      expect(verifyAt, greaterThan(-1));
      expect(completeAt, greaterThan(verifyAt));
    });

    test('verification is still genuinely unimplemented', () {
      // Guards against the stub quietly becoming a no-op that "succeeds".
      final unavailable = codeOnly(
        source(
          '$dataRoot/repositories/unavailable_purchase_verification_gateway.dart',
        ),
      );
      expect(unavailable, contains('throw'));
    });
  });

  group('one owner for the native billing dependency', () {
    test('the app module declares no billing dependency of its own', () {
      // The plugin brings com.android.billingclient itself. A second declaration
      // would give one native library two owners and two version opinions.
      final gradle = source('android/app/build.gradle.kts');
      expect(gradle, isNot(contains('billingclient')));
      expect(gradle, isNot(contains('com.android.billing')));
    });

    test('the Play Billing Library version is pinned through the plugin', () {
      // Google requires Billing Library 8+ for new apps and updates.
      // in_app_purchase_android 0.5.0 is the release that ships it, and it is
      // also the last one this project's Dart version can resolve.
      final lock = source('pubspec.lock');
      expect(lock, contains('in_app_purchase_android'));
      expect(lock, contains('version: "0.5.0"'));

      final pubspec = source('pubspec.yaml');
      expect(pubspec, contains('in_app_purchase:'));
    });

    test('the app manifest declares no billing permission of its own', () {
      // The Play Billing Library embeds com.android.vending.BILLING in its own
      // manifest and it merges in automatically; declaring it again here would
      // be a second, independently-maintained copy of the same fact.
      final manifest = source('android/app/src/main/AndroidManifest.xml');
      expect(manifest, isNot(contains('com.android.vending.BILLING')));
    });
  });
}
