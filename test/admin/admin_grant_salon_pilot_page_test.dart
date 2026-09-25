import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/salon_pilot/data/admin_salon_pilot_gateway_provider.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:facetune/admin/salon_pilot/presentation/pages/admin_grant_salon_pilot_page.dart';
import 'package:facetune/admin/users/data/admin_users_gateway_provider.dart';
import 'package:facetune/admin/users/domain/admin_user_models.dart';
import 'package:facetune/admin/users/presentation/pages/admin_user_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_router_test.dart' show FrozenAuthorization, identity;
import 'admin_salon_pilot_test.dart';
import 'admin_user_models_test.dart' show detailPayload, userId;
import 'admin_users_controller_test.dart' show ScriptedUsersGateway;

Future<void> pumpGrant(
  WidgetTester tester, {
  required ScriptedSalonPilotGateway gateway,
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(1500, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith(
          (ref) => FrozenAuthorization(const AdminAuthorized(identity)),
        ),
        adminSalonPilotGatewayProvider.overrideWithValue(gateway),
        adminUsersGatewayProvider.overrideWithValue(
          ScriptedUsersGateway(
            details: [(_) async => AdminUserDetail.decode(detailPayload())],
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const AdminGrantSalonPilotPage(userId: userId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> fillValidForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('admin-grant-expiration')),
    '2099-01-31',
  );
  await tester.enterText(
    find.byKey(const Key('admin-grant-reason')),
    'Panel research cohort A',
  );
}

void main() {
  testWidgets(
    'the form proposes 30, requires expiration and reason, and previews',
    (tester) async {
      final gateway = ScriptedSalonPilotGateway([]);
      await pumpGrant(tester, gateway: gateway);

      expect(
        tester
            .widget<TextField>(find.byKey(const Key('admin-grant-allowance')))
            .controller
            ?.text,
        '30',
      );
      await tester.tap(find.byKey(const Key('admin-grant-preview')));
      await tester.pump();
      expect(
        find.text('Enter an expiration date as YYYY-MM-DD.'),
        findsOneWidget,
      );
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(gateway.calls, isEmpty);

      await tester.enterText(
        find.byKey(const Key('admin-grant-expiration')),
        '2020-01-01',
      );
      await tester.tap(find.byKey(const Key('admin-grant-preview')));
      await tester.pump();
      expect(
        find.text('The expiration must be in the future.'),
        findsOneWidget,
      );

      await fillValidForm(tester);
      await tester.tap(find.byKey(const Key('admin-grant-preview')));
      await tester.pump();
      expect(
        find.byKey(const Key('admin-grant-preview-panel')),
        findsOneWidget,
      );
      expect(find.text('Salon Pilot (salon_pilot)'), findsOneWidget);
      expect(find.text('Admin Granted (admin_granted)'), findsOneWidget);
      expect(find.text('2099-01-31 23:59:59 UTC'), findsOneWidget);
      expect(find.text('Panel research cohort A'), findsOneWidget);
      // Nothing has been sent yet.
      expect(gateway.calls, isEmpty);
    },
  );

  testWidgets(
    'allowance accepts 30, 0, and any positive integer; rejects the rest',
    (tester) async {
      final gateway = ScriptedSalonPilotGateway([]);
      await pumpGrant(tester, gateway: gateway);
      await fillValidForm(tester);

      Future<void> submitAllowance(String text) async {
        await tester.enterText(
          find.byKey(const Key('admin-grant-allowance')),
          text,
        );
        await tester.tap(find.byKey(const Key('admin-grant-preview')));
        await tester.pump();
      }

      // Rejected at the form: never previewed, never sent.
      for (final rejected in ['-1', '30.5', 'abc', '']) {
        await submitAllowance(rejected);
        expect(
          find.text('Enter a whole number of 0 or more.'),
          findsOneWidget,
          reason: rejected,
        );
        expect(
          find.byKey(const Key('admin-grant-preview-panel')),
          findsNothing,
          reason: rejected,
        );
      }

      // Accepted: the previewed intent carries the value as typed, with no
      // frontend maximum. (The server remains the final authority.)
      for (final (text, value) in [('30', 30), ('0', 0), ('5000', 5000)]) {
        await submitAllowance(text);
        expect(
          find.byKey(const Key('admin-grant-preview-panel')),
          findsOneWidget,
          reason: text,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('admin-grant-preview-panel')),
            matching: find.text('$value'),
          ),
          findsOneWidget,
          reason: text,
        );
        await tester.tap(find.byKey(const Key('admin-grant-edit')));
        await tester.pump();
      }
      expect(gateway.calls, isEmpty);
    },
  );

  testWidgets('confirm sends the intent once and shows the server state', (
    tester,
  ) async {
    final gateway = ScriptedSalonPilotGateway([
      (_) async => AdminMutationOutcome.decode(outcomePayload(available: 30)),
    ]);
    await pumpGrant(tester, gateway: gateway);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('admin-grant-preview')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-grant-confirm')));
    await tester.pump();
    await tester.pump();

    expect(gateway.calls, hasLength(1));
    final sent = gateway.calls.single;
    expect(sent.targetUserId, userId);
    expect(sent.initialAllowance, 30);
    expect(sent.reason, 'Panel research cohort A');
    expect(sent.expiresAt, DateTime.utc(2099, 1, 31, 23, 59, 59));
    expect(sent.idempotencyKey, isNotEmpty);

    expect(find.byKey(const Key('admin-grant-succeeded')), findsOneWidget);
    expect(find.text('Salon Pilot granted'), findsOneWidget);
    expect(find.text(pilotEntitlementId), findsOneWidget);
    for (final label in [
      'Effective allowance',
      'Committed',
      'Reserved',
      'Remaining',
      'Available for a new generation',
      'Expires',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('2026-10-22 23:59:59 UTC'), findsOneWidget);
  });

  testWidgets('Cancel closes the preview without sending the frozen intent', (
    tester,
  ) async {
    final gateway = ScriptedSalonPilotGateway([]);
    await pumpGrant(tester, gateway: gateway);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('admin-grant-preview')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm grant'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-grant-edit')));
    await tester.pumpAndSettle();

    expect(gateway.calls, isEmpty);
    expect(find.byKey(const Key('admin-grant-form')), findsOneWidget);
    expect(find.byKey(const Key('admin-grant-preview-panel')), findsNothing);
  });

  testWidgets('a contract refusal is shown with its code and no retry', (
    tester,
  ) async {
    final gateway = ScriptedSalonPilotGateway([
      (_) async => throw const AdminMutationFailure(
        AdminMutationErrorCode.salonPilotAlreadyGranted,
        message: 'This account already holds a Salon Pilot entitlement.',
      ),
    ]);
    await pumpGrant(tester, gateway: gateway);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('admin-grant-preview')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-grant-confirm')));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('admin-grant-failed')), findsOneWidget);
    expect(find.textContaining('SALON_PILOT_ALREADY_GRANTED'), findsOneWidget);
    expect(find.byKey(const Key('admin-grant-retry')), findsNothing);
    expect(find.byKey(const Key('admin-grant-start-over')), findsOneWidget);
  });

  testWidgets('a replayed grant is labelled as such', (tester) async {
    final gateway = ScriptedSalonPilotGateway([
      (_) async => AdminMutationOutcome.decode(outcomePayload(replayed: true)),
    ]);
    await pumpGrant(tester, gateway: gateway);
    await fillValidForm(tester);
    await tester.tap(find.byKey(const Key('admin-grant-preview')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admin-grant-confirm')));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Salon Pilot was already granted by this request'),
      findsOneWidget,
    );
  });

  testWidgets('user detail offers the grant workflow', (tester) async {
    await pumpGrant(
      tester,
      gateway: ScriptedSalonPilotGateway([]),
      child: const AdminUserDetailPage(userId: userId),
    );
    expect(
      find.byKey(const Key('admin-user-detail-grant-salon-pilot')),
      findsOneWidget,
    );
  });

  test('the grant route is a section path an admin may return to', () {
    final path = AdminRoutes.grantSalonPilot(userId);
    expect(path, '/users/$userId/grant-salon-pilot');
    expect(AdminRoutes.sanitizedReturnTo(path), path);
    expect(AdminSection.fromPath(path), AdminSection.users);
    expect(
      AdminRoutes.sanitizedReturnTo('/users/not-a-uuid/grant-salon-pilot'),
      isNull,
    );
  });
}
