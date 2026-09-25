import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/salon_pilot/data/admin_salon_pilot_gateway_provider.dart';
import 'package:facetune/admin/salon_pilot/data/supabase_admin_salon_pilot_gateway.dart';
import 'package:facetune/admin/salon_pilot/domain/admin_salon_pilot_models.dart';
import 'package:facetune/admin/salon_pilot/presentation/admin_adjust_allowance_controller.dart';
import 'package:facetune/admin/salon_pilot/presentation/pages/admin_adjust_allowance_page.dart';
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

const pilotId = '31000000-0000-4000-8000-000000000001';

/// The WA-5 detail read for an account holding the SOT §25 example pilot:
/// effective 30, committed 18, reserved 0, version 3.
Map<String, Object?> pilotDetailPayload({
  int effective = 30,
  int committed = 18,
  int reserved = 0,
  int version = 3,
}) => {
  ...detailPayload(),
  'entitlement': {
    ...entitlementPayload(),
    'entitlementId': pilotId,
    'planCode': 'salon_pilot',
    'planDisplayName': 'Salon Pilot',
    'billingProvider': 'admin_granted',
    'effectiveAllowance': effective,
    'committedUsage': committed,
    'reservedUsage': reserved,
    'availableAiLooks': effective - committed - reserved,
    'remainingAiLooks': effective - committed,
    'periodStart': null,
    'periodEnd': null,
    'expiresAt': '2026-10-22T23:59:59+00:00',
    'autoRenew': false,
    'version': version,
  },
};

/// The writer's success body after +10 on the example pilot.
Map<String, Object?> adjustOutcomePayload({
  int amount = 10,
  bool replayed = false,
  int effective = 40,
  int committed = 18,
  int reserved = 0,
  int version = 4,
}) => {
  'success': true,
  'contractVersion': 'subscription_admin_contract_v1.1',
  'action': amount > 0 ? 'increase_allowance' : 'decrease_allowance',
  'replayed': replayed,
  'targetUserId': userId,
  'entitlementId': pilotId,
  'adjustmentId': '33000000-0000-4000-8000-000000000001',
  'amount': amount,
  'planCode': 'salon_pilot',
  'status': 'active',
  'baseAllowance': 30,
  'allowanceAdjustmentTotal': effective - 30,
  'effectiveAllowance': effective,
  'committedUsage': committed,
  'reservedUsage': reserved,
  'availableAiLooks': effective - committed - reserved,
  'remainingAiLooks': effective - committed,
  'expiresAt': '2026-10-22T23:59:59+00:00',
  'version': version,
  'updatedAt': '2026-09-22T12:00:00+00:00',
};

AdminAdjustAllowanceController controller(
  ScriptedSalonPilotGateway gateway, {
  bool authorized = true,
  void Function(AdminAuthFailure)? onRefusal,
}) => AdminAdjustAllowanceController(
  entitlementId: pilotId,
  gateway: gateway,
  isAuthorized: () => authorized,
  onServerRefusal: onRefusal ?? (_) {},
);

void previewPlus10(AdminAdjustAllowanceController c) => c.preview(
  amount: 10,
  reason: '  Panel testing extension ',
  currentEffectiveAllowance: 30,
  committedUsage: 18,
  reservedUsage: 0,
  expectedVersion: 3,
);

Future<void> pumpAdjust(
  WidgetTester tester, {
  required ScriptedSalonPilotGateway gateway,
  Map<String, Object?>? detail,
  Widget? child,
}) async {
  tester.view.physicalSize = const Size(1500, 1200);
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
            details: [
              (_) async =>
                  AdminUserDetail.decode(detail ?? pilotDetailPayload()),
              (_) async =>
                  AdminUserDetail.decode(detail ?? pilotDetailPayload()),
            ],
          ),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: child ?? const AdminAdjustAllowancePage(userId: userId),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> submitForm(
  WidgetTester tester, {
  String? amount,
  String reason = 'Panel testing extension',
}) async {
  if (amount != null) {
    await tester.enterText(
      find.byKey(const Key('admin-adjust-amount')),
      amount,
    );
  }
  await tester.enterText(find.byKey(const Key('admin-adjust-reason')), reason);
  await tester.tap(find.byKey(const Key('admin-adjust-preview')));
  await tester.pump();
}

Finder inPreview(String text) => find.descendant(
  of: find.byKey(const Key('admin-adjust-preview-panel')),
  matching: find.text(text),
);

void main() {
  group('models', () {
    test(
      'the intent body carries the signed amount and the expected version',
      () {
        const intent = AdjustAllowanceIntent(
          entitlementId: pilotId,
          amount: -5,
          reason: 'Administrative correction',
          idempotencyKey: 'k',
          expectedVersion: 3,
        );
        expect(intent.isIncrease, isFalse);
        expect(intent.toRequestBody(), {
          'entitlementId': pilotId,
          'amount': -5,
          'reason': 'Administrative correction',
          'idempotencyKey': 'k',
          'expectedVersion': 3,
        });
        expect(salonPilotQuickAdjustments, [5, 10]);
      },
    );

    test(
      'the preview reproduces the SOT §25 example and flags unsafe reductions',
      () {
        const preview = AllowanceAdjustmentPreview(
          currentEffectiveAllowance: 30,
          amount: 10,
          committedUsage: 18,
          reservedUsage: 0,
        );
        expect(preview.newEffectiveAllowance, 40);
        expect(preview.newRemaining, 22);
        expect(preview.newAvailable, 22);
        expect(preview.coversCommittedUsage, isTrue);
        expect(preview.coversReservations, isTrue);

        const below = AllowanceAdjustmentPreview(
          currentEffectiveAllowance: 40,
          amount: -25,
          committedUsage: 18,
          reservedUsage: 0,
        );
        expect(below.coversCommittedUsage, isFalse);

        const reserved = AllowanceAdjustmentPreview(
          currentEffectiveAllowance: 30,
          amount: -6,
          committedUsage: 24,
          reservedUsage: 1,
        );
        expect(reserved.coversCommittedUsage, isTrue);
        expect(reserved.coversReservations, isFalse);
      },
    );

    test('the outcome decodes the writer response verbatim', () {
      final outcome = AdminMutationOutcome.decode(adjustOutcomePayload());
      expect(outcome.action, 'increase_allowance');
      expect(outcome.effectiveAllowance, 40);
      expect(outcome.remainingAiLooks, 22);
      expect(outcome.availableAiLooks, 22);
      expect(outcome.committedUsage, 18);
    });

    test('adjustment refusal codes are typed', () {
      Exception map(int status, Object details) =>
          SupabaseAdminSalonPilotGateway.failureFrom(
            FunctionException(status: status, details: details),
          );
      for (final (code, expected) in [
        (
          'ALLOWANCE_BELOW_COMMITTED_USAGE',
          AdminMutationErrorCode.allowanceBelowCommittedUsage,
        ),
        (
          'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
          AdminMutationErrorCode.allowanceConflictsWithActiveReservation,
        ),
        (
          'CONCURRENT_MODIFICATION',
          AdminMutationErrorCode.concurrentModification,
        ),
        (
          'INVALID_ALLOWANCE_ADJUSTMENT',
          AdminMutationErrorCode.invalidAllowanceAdjustment,
        ),
        ('ENTITLEMENT_NOT_FOUND', AdminMutationErrorCode.entitlementNotFound),
        ('ENTITLEMENT_EXPIRED', AdminMutationErrorCode.entitlementExpired),
        ('ENTITLEMENT_REVOKED', AdminMutationErrorCode.entitlementRevoked),
      ]) {
        final failure =
            map(409, {
                  'success': false,
                  'action': 'decrease_allowance',
                  'errorCode': code,
                  'retryable': false,
                })
                as AdminMutationFailure;
        expect(failure.code, expected, reason: code);
        expect(failure.retryable, isFalse);
      }
    });
  });

  group('AdminAdjustAllowanceController', () {
    test('preview freezes amount, reason, version, and a fresh key', () {
      final c = controller(ScriptedSalonPilotGateway([]));
      previewPlus10(c);
      final state = c.state as AdminAdjustPreviewing;
      expect(state.intent.amount, 10);
      expect(state.intent.reason, 'Panel testing extension');
      expect(state.intent.expectedVersion, 3);
      expect(state.intent.idempotencyKey, isNotEmpty);
      expect(state.preview.newEffectiveAllowance, 40);
      expect(state.preview.newRemaining, 22);
    });

    test(
      'confirm sends the previewed intent once and shows the server state',
      () async {
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.add(
            (_) async => AdminMutationOutcome.decode(adjustOutcomePayload()),
          );
        final c = controller(gateway);
        previewPlus10(c);
        final previewed = (c.state as AdminAdjustPreviewing).intent;
        await c.confirm();
        expect(gateway.adjustCalls.single, same(previewed));
        final outcome = (c.state as AdminAdjustSucceeded).outcome;
        expect(outcome.effectiveAllowance, 40);
        expect(outcome.remainingAiLooks, 22);
      },
    );

    test(
      'a retry after a temporary failure reuses the same key and version',
      () async {
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.addAll([
            (_) async => throw const AdminMutationFailure(
              AdminMutationErrorCode.temporaryBackendFailure,
              retryable: true,
            ),
            (_) async => AdminMutationOutcome.decode(
              adjustOutcomePayload(replayed: true),
            ),
          ]);
        final c = controller(gateway);
        previewPlus10(c);
        await c.confirm();
        expect((c.state as AdminAdjustFailed).failure.retryable, isTrue);
        await c.confirm();
        expect(gateway.adjustCalls, hasLength(2));
        expect(
          gateway.adjustCalls[0].idempotencyKey,
          gateway.adjustCalls[1].idempotencyKey,
        );
        expect(gateway.adjustCalls[1].expectedVersion, 3);
        expect((c.state as AdminAdjustSucceeded).outcome.replayed, isTrue);
      },
    );

    test('a stale version refusal is shown and not retried', () async {
      final gateway = ScriptedSalonPilotGateway([])
        ..adjustResponses.add(
          (_) async => throw const AdminMutationFailure(
            AdminMutationErrorCode.concurrentModification,
          ),
        );
      final c = controller(gateway);
      previewPlus10(c);
      await c.confirm();
      final state = c.state as AdminAdjustFailed;
      expect(state.failure.code, AdminMutationErrorCode.concurrentModification);
      expect(state.failure.retryable, isFalse);
      expect(gateway.adjustCalls, hasLength(1));
    });

    test('a session refusal is escalated', () async {
      final refusals = <AdminAuthFailure>[];
      final gateway = ScriptedSalonPilotGateway([])
        ..adjustResponses.add(
          (_) async => throw const AdminAuthFailure(
            SubscriptionErrorCode.adminUnauthorized,
          ),
        );
      final c = controller(gateway, onRefusal: refusals.add);
      previewPlus10(c);
      await c.confirm();
      expect(refusals.single.isUnauthorized, isTrue);
      expect(c.state, isA<AdminAdjustFailed>());
    });
  });

  group('AdminAdjustAllowancePage', () {
    testWidgets(
      'quick +5 / +10 fill the amount and the preview shows the SOT figures',
      (tester) async {
        final gateway = ScriptedSalonPilotGateway([]);
        await pumpAdjust(tester, gateway: gateway);
        expect(find.byKey(const Key('admin-adjust-current')), findsOneWidget);

        await tester.tap(find.byKey(const Key('admin-adjust-quick-5')));
        await tester.pump();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('admin-adjust-amount')))
              .controller
              ?.text,
          '5',
        );
        await tester.tap(find.byKey(const Key('admin-adjust-quick-10')));
        await tester.pump();
        await submitForm(tester);

        expect(
          find.byKey(const Key('admin-adjust-preview-panel')),
          findsOneWidget,
        );
        for (final (label, value) in [
          ('Current effective allowance', '30'),
          ('Adjustment', '+10'),
          ('New effective allowance', '40'),
          ('Committed', '18'),
          ('Reserved', '0'),
          ('New remaining', '22'),
          ('New available', '22'),
          ('Based on version', '3'),
        ]) {
          expect(inPreview(label), findsOneWidget, reason: label);
          expect(inPreview(value), findsWidgets, reason: '$label=$value');
        }
        expect(
          find.byKey(const Key('admin-adjust-preview-warning')),
          findsNothing,
        );
        expect(gateway.adjustCalls, isEmpty);
      },
    );

    testWidgets('form validation: zero, non-integer, empty reason', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([]);
      await pumpAdjust(tester, gateway: gateway);
      await submitForm(tester, amount: '0');
      expect(find.text('The adjustment cannot be zero.'), findsOneWidget);
      await submitForm(tester, amount: '2.5');
      expect(find.text('Enter a whole number, e.g. 10 or -5.'), findsOneWidget);
      await submitForm(tester, amount: '10', reason: '   ');
      expect(find.text('A reason is required.'), findsOneWidget);
      expect(find.byKey(const Key('admin-adjust-preview-panel')), findsNothing);
      expect(gateway.adjustCalls, isEmpty);
    });

    testWidgets('a custom reduction previews with a warning when unsafe', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([]);
      await pumpAdjust(tester, gateway: gateway);
      await submitForm(tester, amount: '-25');
      expect(inPreview('-25'), findsOneWidget);
      expect(inPreview('5'), findsWidgets); // new effective 30 - 25
      expect(
        find.byKey(const Key('admin-adjust-preview-warning')),
        findsOneWidget,
      );
      // Still the server's call: confirm remains available.
      expect(find.byKey(const Key('admin-adjust-confirm')), findsOneWidget);
    });

    testWidgets(
      'confirm sends the intent with the loaded version and shows the result',
      (tester) async {
        final gateway = ScriptedSalonPilotGateway([])
          ..adjustResponses.add(
            (_) async => AdminMutationOutcome.decode(adjustOutcomePayload()),
          );
        await pumpAdjust(tester, gateway: gateway);
        await submitForm(tester, amount: '+10');
        await tester.tap(find.byKey(const Key('admin-adjust-confirm')));
        await tester.pump();
        await tester.pump();

        final sent = gateway.adjustCalls.single;
        expect(sent.entitlementId, pilotId);
        expect(sent.amount, 10);
        expect(sent.expectedVersion, 3);
        expect(sent.reason, 'Panel testing extension');

        expect(find.byKey(const Key('admin-adjust-succeeded')), findsOneWidget);
        expect(find.text('Allowance adjusted (+10)'), findsOneWidget);
        final result = find.byKey(const Key('admin-adjust-succeeded'));
        for (final value in ['40', '18', '22']) {
          expect(
            find.descendant(of: result, matching: find.text(value)),
            findsWidgets,
            reason: value,
          );
        }
      },
    );

    testWidgets('Cancel returns to editing without applying an adjustment', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([]);
      await pumpAdjust(tester, gateway: gateway);
      await submitForm(tester, amount: '+10');

      expect(find.text('Confirm increase'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      await tester.tap(find.byKey(const Key('admin-adjust-edit')));
      await tester.pumpAndSettle();

      expect(gateway.adjustCalls, isEmpty);
      expect(find.byKey(const Key('admin-adjust-form')), findsOneWidget);
      expect(find.byKey(const Key('admin-adjust-preview-panel')), findsNothing);
    });

    testWidgets('a reduction refusal is shown with its contract code', (
      tester,
    ) async {
      final gateway = ScriptedSalonPilotGateway([])
        ..adjustResponses.add(
          (_) async => throw const AdminMutationFailure(
            AdminMutationErrorCode.allowanceBelowCommittedUsage,
            message:
                'That reduction would put the allowance below usage already committed.',
          ),
        );
      await pumpAdjust(tester, gateway: gateway);
      await submitForm(tester, amount: '-25');
      await tester.tap(find.byKey(const Key('admin-adjust-confirm')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('admin-adjust-failed')), findsOneWidget);
      expect(
        find.textContaining('ALLOWANCE_BELOW_COMMITTED_USAGE'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('admin-adjust-retry')), findsNothing);
      expect(find.byKey(const Key('admin-adjust-start-over')), findsOneWidget);
    });

    testWidgets(
      'a non-pilot entitlement is not editable and offers no button',
      (tester) async {
        await pumpAdjust(
          tester,
          gateway: ScriptedSalonPilotGateway([]),
          detail: detailPayload(),
        );
        expect(
          find.byKey(const Key('admin-adjust-not-editable')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('admin-adjust-form')), findsNothing);

        await pumpAdjust(
          tester,
          gateway: ScriptedSalonPilotGateway([]),
          detail: detailPayload(),
          child: const AdminUserDetailPage(userId: userId),
        );
        expect(
          find.byKey(const Key('admin-user-detail-adjust-allowance')),
          findsNothing,
        );
      },
    );

    testWidgets('user detail offers the adjustment for a Salon Pilot', (
      tester,
    ) async {
      await pumpAdjust(
        tester,
        gateway: ScriptedSalonPilotGateway([]),
        child: const AdminUserDetailPage(userId: userId),
      );
      expect(
        find.byKey(const Key('admin-user-detail-adjust-allowance')),
        findsOneWidget,
      );
    });
  });

  test('the adjust route is a section path an admin may return to', () {
    final path = AdminRoutes.adjustAllowance(userId);
    expect(path, '/users/$userId/adjust-allowance');
    expect(AdminRoutes.sanitizedReturnTo(path), path);
    expect(AdminSection.fromPath(path), AdminSection.users);
    expect(AdminRoutes.sanitizedReturnTo('/users/$userId/delete'), isNull);
    expect(AdminRoutes.isGrantSalonPilotPath(path), isFalse);
    expect(
      AdminRoutes.isGrantSalonPilotPath(AdminRoutes.grantSalonPilot(userId)),
      isTrue,
    );
  });
}
