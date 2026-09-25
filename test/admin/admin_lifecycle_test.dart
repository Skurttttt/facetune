import 'dart:async';

import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/app/admin_router.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/salon_pilot/data/admin_salon_pilot_gateway_provider.dart';
import 'package:facetune/admin/salon_pilot/data/supabase_admin_salon_pilot_gateway.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_lifecycle_controller.dart';
import 'package:facetune/admin/salon_pilot/presentation/pages/admin_lifecycle_page.dart';
import 'package:facetune/admin/users/data/admin_users_gateway_provider.dart';
import 'package:facetune/admin/users/domain/admin_user_models.dart';
import 'package:facetune/admin/users/presentation/pages/admin_user_detail_page.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_router_test.dart' show FrozenAuthorization, identity;
import 'admin_salon_pilot_test.dart' show ScriptedSalonPilotGateway;
import 'admin_user_models_test.dart'
    show detailPayload, entitlementPayload, userId;
import 'admin_users_controller_test.dart' show ScriptedUsersGateway;

const entitlementId = '51000000-0000-4000-8000-000000000001';

Map<String, Object?> lifecycleDetailPayload({
  String storedStatus = 'active',
  String effectiveStatus = 'active',
  String planCode = 'salon_pilot',
  String provider = 'admin_granted',
  String? expiresAt = '2026-10-22T23:59:59Z',
  int version = 7,
}) => {
  ...detailPayload(),
  'entitlement': {
    ...entitlementPayload(),
    'entitlementId': entitlementId,
    'planCode': planCode,
    'planDisplayName': planCode == 'salon_pilot' ? 'Salon Pilot' : 'Pro',
    'storedStatus': storedStatus,
    'effectiveStatus': effectiveStatus,
    'billingProvider': provider,
    'effectiveAllowance': 30,
    'committedUsage': 3,
    'reservedUsage': 1,
    'availableAiLooks': 26,
    'remainingAiLooks': 27,
    'periodStart': null,
    'periodEnd': null,
    'expiresAt': expiresAt,
    'autoRenew': false,
    'version': version,
  },
};

Map<String, Object?> lifecycleOutcome({
  required SalonPilotLifecycleAction action,
  String status = 'active',
  bool replayed = false,
  String? expiresAt = '2026-10-22T23:59:59Z',
}) => {
  'success': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'action': action.code,
  'replayed': replayed,
  'targetUserId': userId,
  'entitlementId': entitlementId,
  'planCode': 'salon_pilot',
  'status': status,
  'effectiveAllowance': 30,
  'committedUsage': 3,
  'reservedUsage': 1,
  'availableAiLooks': status == 'active' ? 26 : 0,
  'remainingAiLooks': 27,
  'expiresAt': expiresAt,
  'version': 8,
  'updatedAt': '2026-09-22T12:00:00Z',
};

AdminLifecycleController lifecycleController(
  ScriptedSalonPilotGateway gateway,
  SalonPilotLifecycleAction action, {
  bool Function()? isAuthorized,
  void Function(AdminAuthFailure)? onRefusal,
  String Function()? mintKey,
}) => AdminLifecycleController(
  entitlementId: entitlementId,
  action: action,
  gateway: gateway,
  isAuthorized: isAuthorized ?? () => true,
  onServerRefusal: onRefusal ?? (_) {},
  mintIdempotencyKey: mintKey,
);

Future<void> pumpLifecycle(
  WidgetTester tester, {
  required ScriptedSalonPilotGateway gateway,
  required SalonPilotLifecycleAction action,
  Map<String, Object?>? detail,
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(1500, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final payload = detail ?? lifecycleDetailPayload();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminAuthorizationControllerProvider.overrideWith(
          (ref) => FrozenAuthorization(const AdminAuthorized(identity)),
        ),
        adminSalonPilotGatewayProvider.overrideWithValue(gateway),
        adminUsersGatewayProvider.overrideWithValue(
          ScriptedUsersGateway(
            details: [
              (_) async => AdminUserDetail.decode(payload),
              (_) async => AdminUserDetail.decode(payload),
            ],
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? AdminLifecyclePage(userId: userId, action: action),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> enterReason(
  WidgetTester tester, [
  String reason = 'Research operations review',
]) => tester.enterText(find.byKey(const Key('admin-lifecycle-reason')), reason);

void main() {
  group('lifecycle contract and controller', () {
    test(
      'the request body carries action, version, key, and UTC expiration',
      () {
        final intent = LifecycleIntent(
          action: SalonPilotLifecycleAction.extendExpiration,
          entitlementId: entitlementId,
          reason: 'Extend the cohort',
          idempotencyKey: 'wa9-key',
          expectedVersion: 7,
          newExpiresAt: DateTime.utc(2099, 1, 31, 23, 59, 59),
        );
        expect(intent.toRequestBody(), {
          'action': 'extend_expiration',
          'entitlementId': entitlementId,
          'reason': 'Extend the cohort',
          'idempotencyKey': 'wa9-key',
          'expectedVersion': 7,
          'newExpiresAt': '2099-01-31T23:59:59.000Z',
        });
      },
    );

    test(
      'preview freezes the date/version/key; retry reuses that intent',
      () async {
        var minted = 0;
        final gateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.addAll([
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.temporaryBackendFailure,
              retryable: true,
            ),
            (intent) async => AdminMutationOutcome.decode(
              lifecycleOutcome(action: intent.action),
            ),
          ]);
        final controller = lifecycleController(
          gateway,
          SalonPilotLifecycleAction.extendExpiration,
          mintKey: () => 'key-${++minted}',
        );
        final date = DateTime.utc(2099, 1, 31, 23, 59, 59);
        controller.preview(
          reason: '  Extend the cohort  ',
          expectedVersion: 7,
          newExpiresAt: date,
        );
        final preview = controller.state as AdminLifecyclePreviewing;
        expect(preview.intent.reason, 'Extend the cohort');
        expect(preview.intent.expectedVersion, 7);
        expect(preview.intent.idempotencyKey, 'key-1');
        expect(preview.intent.newExpiresAt, date);

        await controller.confirm();
        expect(controller.state, isA<AdminLifecycleFailed>());
        await controller.confirm();
        expect(controller.state, isA<AdminLifecycleSucceeded>());
        expect(gateway.lifecycleCalls, hasLength(2));
        expect(gateway.lifecycleCalls[1], same(gateway.lifecycleCalls[0]));
        expect(gateway.lifecycleCalls[1].idempotencyKey, 'key-1');
      },
    );

    test('editing then previewing creates a fresh frozen intent', () {
      var minted = 0;
      final controller = lifecycleController(
        ScriptedSalonPilotGateway([]),
        SalonPilotLifecycleAction.suspend,
        mintKey: () => 'key-${++minted}',
      );
      controller.preview(reason: 'First', expectedVersion: 7);
      final first = (controller.state as AdminLifecyclePreviewing).intent;
      controller.edit();
      controller.preview(reason: 'Second', expectedVersion: 8);
      final second = (controller.state as AdminLifecyclePreviewing).intent;
      expect(first.idempotencyKey, 'key-1');
      expect(second.idempotencyKey, 'key-2');
      expect(second.expectedVersion, 8);
    });

    test(
      'a second confirm while submitting cannot duplicate the request',
      () async {
        final pending = Completer<AdminMutationOutcome>();
        final gateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.add((_) => pending.future);
        final controller = lifecycleController(
          gateway,
          SalonPilotLifecycleAction.suspend,
        );
        controller.preview(reason: 'Pause access', expectedVersion: 7);
        final first = controller.confirm();
        final duplicate = controller.confirm();
        expect(gateway.lifecycleCalls, hasLength(1));
        pending.complete(
          AdminMutationOutcome.decode(
            lifecycleOutcome(
              action: SalonPilotLifecycleAction.suspend,
              status: 'suspended',
            ),
          ),
        );
        await Future.wait([first, duplicate]);
        expect(gateway.lifecycleCalls, hasLength(1));
      },
    );

    test(
      'typed transition failures and authorization loss are retained',
      () async {
        final typedGateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.add(
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.entitlementExpired,
              message: 'This entitlement has ended.',
            ),
          );
        final typed = lifecycleController(
          typedGateway,
          SalonPilotLifecycleAction.reactivate,
        )..preview(reason: 'Resume access', expectedVersion: 7);
        await typed.confirm();
        final failure = typed.state as AdminLifecycleFailed;
        expect(failure.failure.code, AdminMutationErrorCode.entitlementExpired);
        expect(failure.failure.message, 'This entitlement has ended.');

        AdminAuthFailure? refusal;
        final authGateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.add(
            (_) async => throw const AdminAuthFailure(
              SubscriptionErrorCode.adminUnauthorized,
            ),
          );
        final auth = lifecycleController(
          authGateway,
          SalonPilotLifecycleAction.revoke,
          onRefusal: (value) => refusal = value,
        )..preview(reason: 'End access', expectedVersion: 7);
        await auth.confirm();
        expect(refusal?.code, SubscriptionErrorCode.adminUnauthorized);
        expect(auth.state, isA<AdminLifecycleFailed>());
      },
    );

    test('the gateway recognizes every WA-9 refusal code', () {
      Exception map(String code) => SupabaseAdminSalonPilotGateway.failureFrom(
        FunctionException(
          status: 409,
          details: {
            'success': false,
            'errorCode': code,
            'message': 'Safe message',
            'retryable': false,
          },
        ),
      );
      for (final (code, expected) in [
        (
          'INVALID_ENTITLEMENT_TRANSITION',
          AdminMutationErrorCode.invalidEntitlementTransition,
        ),
        ('ENTITLEMENT_EXPIRED', AdminMutationErrorCode.entitlementExpired),
        ('ENTITLEMENT_REVOKED', AdminMutationErrorCode.entitlementRevoked),
        (
          'PROVIDER_STATE_CONFLICT',
          AdminMutationErrorCode.providerStateConflict,
        ),
        (
          'CONCURRENT_MODIFICATION',
          AdminMutationErrorCode.concurrentModification,
        ),
      ]) {
        expect((map(code) as AdminMutationFailure).code, expected);
      }
    });
  });

  group('lifecycle pages', () {
    testWidgets('extension validates format, future, and later-than-current', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        action: SalonPilotLifecycleAction.extendExpiration,
      );
      await enterReason(tester);

      await tester.enterText(
        find.byKey(const Key('admin-lifecycle-date')),
        '2026-02-31',
      );
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(
        find.text('Enter the new expiration as YYYY-MM-DD.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('admin-lifecycle-date')),
        '2026-10-22',
      );
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(
        find.text('The new expiration must be later than the current one.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'a valid extension freezes version/date and shows server success',
      (tester) async {
        final gateway = ScriptedSalonPilotGateway([])
          ..lifecycleResponses.add(
            (intent) async => AdminMutationOutcome.decode(
              lifecycleOutcome(
                action: intent.action,
                expiresAt: '2099-01-31T23:59:59Z',
              ),
            ),
          );
        await pumpLifecycle(
          tester,
          gateway: gateway,
          action: SalonPilotLifecycleAction.extendExpiration,
        );
        await tester.enterText(
          find.byKey(const Key('admin-lifecycle-date')),
          '2099-01-31',
        );
        await enterReason(tester, 'Extend cohort access');
        await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
        await tester.pump();
        expect(
          find.byKey(const Key('admin-lifecycle-preview-panel')),
          findsOneWidget,
        );
        expect(find.text('2099-01-31 23:59:59 UTC'), findsOneWidget);

        await tester.tap(find.byKey(const Key('admin-lifecycle-confirm')));
        await tester.pump();
        await tester.pump();
        final sent = gateway.lifecycleCalls.single;
        expect(sent.expectedVersion, 7);
        expect(sent.newExpiresAt, DateTime.utc(2099, 1, 31, 23, 59, 59));
        expect(sent.idempotencyKey, isNotEmpty);
        expect(
          find.byKey(const Key('admin-lifecycle-succeeded')),
          findsOneWidget,
        );
        expect(find.text('Extend expiration: applied'), findsOneWidget);
      },
    );

    testWidgets('suspend explains the consequence and displays a refusal', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([])
        ..lifecycleResponses.add(
          (_) async => throw const AdminMutationFailure(
            AdminMutationErrorCode.invalidEntitlementTransition,
            message: 'The entitlement changed before confirmation.',
          ),
        );
      await pumpLifecycle(
        tester,
        gateway: gateway,
        action: SalonPilotLifecycleAction.suspend,
      );
      await enterReason(tester, 'Pause during review');
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(
        find.textContaining('Blocks new premium AI generations'),
        findsWidgets,
      );
      await tester.tap(find.byKey(const Key('admin-lifecycle-confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-lifecycle-failed')), findsOneWidget);
      expect(
        find.textContaining('INVALID_ENTITLEMENT_TRANSITION'),
        findsOneWidget,
      );
    });

    testWidgets('a suspended pilot can run the reactivate flow', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([])
        ..lifecycleResponses.add(
          (intent) async => AdminMutationOutcome.decode(
            lifecycleOutcome(action: intent.action),
          ),
        );
      await pumpLifecycle(
        tester,
        gateway: gateway,
        action: SalonPilotLifecycleAction.reactivate,
        detail: lifecycleDetailPayload(
          storedStatus: 'suspended',
          effectiveStatus: 'suspended',
        ),
      );
      await enterReason(tester, 'Review completed');
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(find.text('Reactivate access'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-lifecycle-confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Reactivate: applied'), findsOneWidget);
    });

    testWidgets('revoke requires reason and explicit acknowledgement', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        action: SalonPilotLifecycleAction.revoke,
      );
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(
        find.text('Confirm that you understand this cannot be undone.'),
        findsOneWidget,
      );
      await enterReason(tester, 'Pilot participation ended');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      expect(find.text('Revoke Salon Pilot?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('admin-lifecycle-confirm')),
          matching: find.text('Revoke access'),
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Terminates this entitlement permanently'),
        findsWidgets,
      );
      final confirm = tester.widget<FilledButton>(
        find.byKey(const Key('admin-lifecycle-confirm')),
      );
      expect(
        confirm.style?.backgroundColor?.resolve({}),
        Theme.of(
          tester.element(find.byKey(const Key('admin-lifecycle-confirm'))),
        ).colorScheme.error,
      );
    });

    testWidgets('revoke displays the terminal server refusal', (tester) async {
      final gateway = ScriptedSalonPilotGateway([])
        ..lifecycleResponses.add(
          (_) async => throw const AdminMutationFailure(
            AdminMutationErrorCode.entitlementRevoked,
          ),
        );
      await pumpLifecycle(
        tester,
        gateway: gateway,
        action: SalonPilotLifecycleAction.revoke,
      );
      await enterReason(tester, 'Pilot participation ended');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('admin-lifecycle-confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('ENTITLEMENT_REVOKED'), findsOneWidget);
      expect(find.textContaining('revocation is terminal'), findsOneWidget);
    });

    testWidgets(
      'Cancel leaves an acknowledged revoke intent unapplied and editable',
      (tester) async {
        final gateway = ScriptedSalonPilotGateway([]);
        await pumpLifecycle(
          tester,
          gateway: gateway,
          action: SalonPilotLifecycleAction.revoke,
        );
        await enterReason(tester, 'Pilot participation ended');
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        await tester.tap(find.byKey(const Key('admin-lifecycle-preview')));
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byKey(const Key('admin-lifecycle-confirm')),
            matching: find.text('Revoke access'),
          ),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        await tester.tap(find.byKey(const Key('admin-lifecycle-edit')));
        await tester.pumpAndSettle();

        expect(gateway.lifecycleCalls, isEmpty);
        expect(find.byKey(const Key('admin-lifecycle-form')), findsOneWidget);
        expect(
          tester
              .widget<CheckboxListTile>(
                find.byKey(const Key('admin-lifecycle-acknowledge')),
              )
              .value,
          isTrue,
        );
      },
    );
  });

  group('visibility and routing', () {
    testWidgets('active pilot gets extend, suspend, and revoke only', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        action: SalonPilotLifecycleAction.suspend,
        child: const AdminUserDetailPage(userId: userId),
      );
      expect(
        find.byKey(const Key('admin-user-detail-extend-expiration')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-user-detail-suspend')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('admin-user-detail-reactivate')),
        findsNothing,
      );
      expect(find.byKey(const Key('admin-user-detail-revoke')), findsOneWidget);
    });

    testWidgets('suspended pilot gets extend, reactivate, and revoke only', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        action: SalonPilotLifecycleAction.reactivate,
        detail: lifecycleDetailPayload(
          storedStatus: 'suspended',
          effectiveStatus: 'suspended',
        ),
        child: const AdminUserDetailPage(userId: userId),
      );
      expect(
        find.byKey(const Key('admin-user-detail-extend-expiration')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('admin-user-detail-suspend')), findsNothing);
      expect(
        find.byKey(const Key('admin-user-detail-reactivate')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('admin-user-detail-revoke')), findsOneWidget);
    });

    testWidgets('provider-backed subscriptions receive no lifecycle controls', (
      tester,
    ) async {
      await pumpLifecycle(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        action: SalonPilotLifecycleAction.suspend,
        detail: lifecycleDetailPayload(
          planCode: 'pro',
          provider: 'google_play',
          expiresAt: null,
        ),
        child: const AdminUserDetailPage(userId: userId),
      );
      expect(
        find.byKey(const Key('admin-user-detail-lifecycle-actions')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('admin-user-detail-extend-expiration')),
        findsNothing,
      );
      expect(find.byKey(const Key('admin-user-detail-suspend')), findsNothing);
      expect(
        find.byKey(const Key('admin-user-detail-reactivate')),
        findsNothing,
      );
      expect(find.byKey(const Key('admin-user-detail-revoke')), findsNothing);
    });

    test('all lifecycle routes are protected, UUID-bounded user paths', () {
      final paths = [
        AdminRoutes.extendExpiration(userId),
        AdminRoutes.suspendEntitlement(userId),
        AdminRoutes.reactivateEntitlement(userId),
        AdminRoutes.revokeEntitlement(userId),
      ];
      for (final path in paths) {
        expect(AdminRoutes.isLifecyclePath(path), isTrue, reason: path);
        expect(AdminRoutes.sanitizedReturnTo(path), path);
        expect(AdminSection.fromPath(path), AdminSection.users);
        expect(
          redirectFor(const AdminAuthorizationPending(), Uri.parse(path)),
          startsWith('/loading?from='),
          reason: path,
        );
        expect(
          redirectFor(const AdminUnauthenticated(), Uri.parse(path)),
          startsWith('/login?from='),
          reason: path,
        );
        expect(
          redirectFor(const AdminAuthorized(identity), Uri.parse(path)),
          isNull,
          reason: path,
        );
      }
      expect(
        AdminRoutes.sanitizedReturnTo('/users/not-a-uuid/revoke-entitlement'),
        isNull,
      );
      expect(AdminRoutes.isLifecyclePath('/users/$userId/delete'), isFalse);
    });
  });
}
