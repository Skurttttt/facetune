import 'package:facetune/admin/auth/domain/admin_auth_failure.dart';
import 'package:facetune/admin/users/domain/admin_user_models.dart';
import 'package:facetune/admin/users/domain/admin_users_failure.dart';
import 'package:facetune/admin/users/domain/admin_users_gateway.dart';
import 'package:facetune/admin/users/presentation/admin_users_controller.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_error_code.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_user_models_test.dart' show detailPayload, summaryPayload, userId;

class ScriptedUsersGateway implements AdminUsersGateway {
  ScriptedUsersGateway({
    List<Future<AdminUserPage> Function(String?, String?)>? searches,
    List<Future<AdminUserDetail> Function(String)>? details,
  }) : searches = searches ?? [],
       details = details ?? [];

  final List<Future<AdminUserPage> Function(String?, String?)> searches;
  final List<Future<AdminUserDetail> Function(String)> details;
  final List<(String?, String?)> searchCalls = [];
  final List<String> detailCalls = [];

  @override
  Future<AdminUserPage> searchUsers({String? search, String? cursor}) {
    searchCalls.add((search, cursor));
    return searches.removeAt(0)(search, cursor);
  }

  @override
  Future<AdminUserDetail> getUser(String userId) {
    detailCalls.add(userId);
    return details.removeAt(0)(userId);
  }
}

AdminUserPage page({List<Map<String, Object?>>? items, String? nextCursor}) =>
    AdminUserPage.decode({
      'ok': true,
      'contractVersion': 'subscription_admin_contract_v1.1',
      'pageSize': 25,
      'sort': {'field': 'accountCreatedAt', 'direction': 'desc'},
      'items': items ?? [summaryPayload()],
      'nextCursor': nextCursor,
    });

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('AdminUsersController', () {
    test('normalizes exact search and handles a no-result page', () async {
      final gateway = ScriptedUsersGateway(
        searches: [
          (_, _) async => page(),
          (_, _) async => page(items: []),
        ],
      );
      final controller = AdminUsersController(
        gateway: gateway,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      await controller.search('  MEMBER@EXAMPLE.INVALID  ');

      expect(gateway.searchCalls.last.$1, 'member@example.invalid');
      expect((controller.state as AdminUsersReady).page.items, isEmpty);
      controller.dispose();
    });

    test('paginates by cursor and retains only the current page', () async {
      final gateway = ScriptedUsersGateway(
        searches: [
          (_, _) async => page(nextCursor: 'cursor-2'),
          (_, _) async =>
              page(items: [summaryPayload(id: userId.replaceFirst('1', '2'))]),
          (_, _) async => page(),
        ],
      );
      final controller = AdminUsersController(
        gateway: gateway,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      await controller.nextPage();

      final second = controller.state as AdminUsersReady;
      expect(second.pageNumber, 2);
      expect(second.page.items, hasLength(1));
      expect(second.page.items.single.userId, isNot(userId));
      expect(gateway.searchCalls.last.$2, 'cursor-2');

      await controller.previousPage();
      expect((controller.state as AdminUsersReady).pageNumber, 1);
      expect(gateway.searchCalls.last.$2, isNull);
      controller.dispose();
    });

    test('does not query before authorization is established', () async {
      final gateway = ScriptedUsersGateway();
      final controller = AdminUsersController(
        gateway: gateway,
        isAuthorized: () => false,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(gateway.searchCalls, isEmpty);
      expect(controller.state, isA<AdminUsersUnavailable>());
      controller.dispose();
    });

    test('hands a server authorization refusal to the app gate', () async {
      final refusals = <AdminAuthFailure>[];
      final gateway = ScriptedUsersGateway(
        searches: [
          (_, _) async => throw const AdminAuthFailure(
            SubscriptionErrorCode.adminUnauthorized,
          ),
        ],
      );
      final controller = AdminUsersController(
        gateway: gateway,
        isAuthorized: () => true,
        onServerRefusal: refusals.add,
      );
      await settle();
      expect(refusals.single.code, SubscriptionErrorCode.adminUnauthorized);
      expect(controller.state, isA<AdminUsersUnavailable>());
      controller.dispose();
    });
  });

  group('AdminUserDetailController', () {
    test('loads subscription-relevant detail', () async {
      final gateway = ScriptedUsersGateway(
        details: [(_) async => AdminUserDetail.decode(detailPayload())],
      );
      final controller = AdminUserDetailController(
        userId: userId,
        gateway: gateway,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(controller.state, isA<AdminUserDetailReady>());
      expect(gateway.detailCalls, [userId]);
      controller.dispose();
    });

    test('has a dedicated not-found state', () async {
      final gateway = ScriptedUsersGateway(
        details: [
          (_) async =>
              throw const AdminUsersFailure(AdminUsersFailureType.notFound),
        ],
      );
      final controller = AdminUserDetailController(
        userId: userId,
        gateway: gateway,
        isAuthorized: () => true,
        onServerRefusal: (_) {},
      );
      await settle();
      expect(controller.state, isA<AdminUserDetailNotFound>());
      controller.dispose();
    });
  });
}
