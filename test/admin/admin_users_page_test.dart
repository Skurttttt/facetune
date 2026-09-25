import 'package:facetune/admin/auth/presentation/admin_authorization_controller.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/shared/admin_cards.dart';
import 'package:facetune/admin/shared/admin_form_widgets.dart';
import 'package:facetune/admin/shared/admin_list_widgets.dart';
import 'package:facetune/admin/users/data/admin_users_gateway_provider.dart';
import 'package:facetune/admin/users/domain/admin_user_models.dart';
import 'package:facetune/admin/users/domain/admin_users_failure.dart';
import 'package:facetune/admin/users/presentation/pages/admin_user_detail_page.dart';
import 'package:facetune/admin/users/presentation/pages/admin_users_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_router_test.dart' show FrozenAuthorization, identity;
import 'admin_user_models_test.dart' show detailPayload, summaryPayload, userId;
import 'admin_users_controller_test.dart' show ScriptedUsersGateway, page;

Future<void> pumpPage(
  WidgetTester tester, {
  required Widget child,
  required ScriptedUsersGateway gateway,
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
        adminUsersGatewayProvider.overrideWithValue(gateway),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('shows one server page and submits exact email search', (
    tester,
  ) async {
    final gateway = ScriptedUsersGateway(
      searches: [
        (_, _) async => page(),
        (_, _) async => page(items: []),
      ],
    );
    await pumpPage(tester, child: const AdminUsersPage(), gateway: gateway);

    expect(find.byKey(const Key('admin-users-results')), findsOneWidget);
    expect(find.byKey(const Key('admin-users-search-panel')), findsOneWidget);
    expect(find.byType(AdminLabeledField), findsOneWidget);
    expect(
      find.text('Exact matches only. Leave blank to browse.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('admin-users-table')), findsOneWidget);
    expect(find.byType(AdminTable), findsOneWidget);
    expect(find.byType(AdminIdentityCell), findsOneWidget);
    expect(find.byType(AdminStatusBadge), findsNWidgets(2));
    expect(find.text('member@example.invalid'), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('8 AI Looks'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('admin-user-search')),
      'MEMBER@EXAMPLE.INVALID',
    );
    await tester.tap(find.byKey(const Key('admin-user-search-submit')));
    await tester.pump();

    expect(gateway.searchCalls.last.$1, 'member@example.invalid');
    expect(find.byKey(const Key('admin-users-empty')), findsOneWidget);
  });

  testWidgets('pagination controls replace rather than append user rows', (
    tester,
  ) async {
    final secondId = userId.replaceFirst('1', '2');
    final gateway = ScriptedUsersGateway(
      searches: [
        (_, _) async => page(nextCursor: 'cursor-2'),
        (_, _) async => page(items: [summaryPayload(id: secondId)]),
      ],
    );
    await pumpPage(tester, child: const AdminUsersPage(), gateway: gateway);

    expect(find.byKey(Key('view-user-$userId')), findsOneWidget);
    await tester.tap(find.byKey(const Key('admin-users-next')));
    await tester.pump();

    expect(find.byKey(Key('view-user-$userId')), findsNothing);
    expect(find.byKey(Key('view-user-$secondId')), findsOneWidget);
    expect(find.textContaining('Page 2'), findsOneWidget);
  });

  testWidgets('detail renders approved account and subscription fields only', (
    tester,
  ) async {
    final gateway = ScriptedUsersGateway(
      details: [(_) async => AdminUserDetail.decode(detailPayload())],
    );
    await pumpPage(
      tester,
      child: const AdminUserDetailPage(userId: userId),
      gateway: gateway,
    );

    expect(find.byKey(const Key('admin-user-detail-ready')), findsOneWidget);
    expect(find.byType(AdminCard), findsNWidgets(2));
    expect(
      find.byKey(const Key('admin-user-entitlement-detail')),
      findsOneWidget,
    );
    for (final label in [
      'User ID',
      'Email',
      'Account created',
      'Current plan',
      'Entitlement status',
      'Billing provider',
      'Committed usage',
      'Reserved usage',
      'Remaining usage',
      'Period start',
      'Period end',
      'Expiration',
      'Auto-renew',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }

    final visible = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data ?? '')
        .join('\n')
        .toLowerCase();
    for (final forbidden in [
      'selfie',
      'preview image',
      'tutorial image',
      'signed url',
      'prompt',
      'gemini',
      'makeup kit',
    ]) {
      expect(visible, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  testWidgets('detail has a distinct user-not-found state', (tester) async {
    final gateway = ScriptedUsersGateway(
      details: [
        (_) async =>
            throw const AdminUsersFailure(AdminUsersFailureType.notFound),
      ],
    );
    await pumpPage(
      tester,
      child: const AdminUserDetailPage(userId: userId),
      gateway: gateway,
    );

    expect(
      find.byKey(const Key('admin-user-detail-not-found')),
      findsOneWidget,
    );
    expect(find.text('User not found.'), findsOneWidget);
  });
}
