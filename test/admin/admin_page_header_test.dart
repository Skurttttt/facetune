import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/shared/admin_page_header.dart';
import 'package:facetune/admin/shell/admin_breadcrumb.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_shell_test.dart' show pumpAdmin, locationOf;

/// WA-13.5-UI-4: one heading per page, and a breadcrumb that is only ever
/// text.
///
/// The phase's point is that a page announces itself once. Before it, the top
/// utility bar repeated the section name the page already rendered, so every
/// page had two headings — one of the defects UI-0 recorded as D-03.
Widget _harness(Widget child) => MaterialApp(
  theme: AdminTheme.dark,
  home: Scaffold(body: child),
);

void main() {
  group('AdminPageHeader', () {
    testWidgets('renders a title, a subtitle, and nothing else by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const AdminPageHeader(title: 'Usage', subtitle: 'The AI Look ledger'),
        ),
      );

      expect(find.byKey(const Key('admin-page-title')), findsOneWidget);
      expect(find.byKey(const Key('admin-page-subtitle')), findsOneWidget);
      expect(find.text('Usage'), findsOneWidget);
      expect(find.text('The AI Look ledger'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsNothing);
    });

    testWidgets('the title is the heading; the subtitle is not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _harness(
          const AdminPageHeader(title: 'Audit', subtitle: 'Immutable actions'),
        ),
      );

      expect(
        tester.getSemantics(find.byKey(const Key('admin-page-title'))),
        containsSemantics(label: 'Audit', isHeader: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('admin-page-subtitle'))),
        containsSemantics(isHeader: false),
      );

      handle.dispose();
    });

    testWidgets('actions sit beside the title without displacing it', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          AdminPageHeader(
            title: 'Dashboard',
            subtitle: 'Live counts',
            actions: [
              const Text('As of 12:00'),
              OutlinedButton(onPressed: () {}, child: const Text('Refresh')),
            ],
          ),
        ),
      );

      final title = tester.getRect(find.byKey(const Key('admin-page-title')));
      final action = tester.getRect(find.text('Refresh'));

      expect(action.left, greaterThan(title.left));
      expect(find.text('As of 12:00'), findsOneWidget);
      // The subtitle still sits under the title, not under the actions.
      final subtitle = tester.getRect(
        find.byKey(const Key('admin-page-subtitle')),
      );
      expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
      expect(subtitle.left, title.left);
    });
  });

  group('AdminBreadcrumb', () {
    test('a section root has no trail', () {
      for (final section in AdminSection.values) {
        expect(
          AdminBreadcrumb.crumbsFor(section.path),
          isEmpty,
          reason: section.label,
        );
      }
    });

    test('a sub-page names its section and itself', () {
      const id = '11111111-2222-3333-4444-555555555555';

      expect(AdminBreadcrumb.crumbsFor(AdminRoutes.salonPilotResearch), const [
        'Dashboard',
        'Salon Pilot research',
      ]);
      expect(AdminBreadcrumb.crumbsFor(AdminRoutes.userDetail(id)), const [
        'Users',
        'User detail',
      ]);
      expect(AdminBreadcrumb.crumbsFor(AdminRoutes.auditDetail(id)), const [
        'Audit',
        'Event detail',
      ]);
      expect(
        AdminBreadcrumb.crumbsFor(AdminRoutes.entitlementHistory(id)),
        const ['Entitlements', 'History'],
      );
      expect(AdminBreadcrumb.crumbsFor(AdminRoutes.grantSalonPilot(id)), const [
        'Users',
        'Grant Salon Pilot',
      ]);
      expect(
        AdminBreadcrumb.crumbsFor(AdminRoutes.revokeEntitlement(id)),
        const ['Users', 'Revoke entitlement'],
      );
    });

    test('an unknown path gets no trail rather than a guess', () {
      expect(AdminBreadcrumb.crumbsFor('/nope'), isEmpty);
      expect(AdminBreadcrumb.crumbsFor('/users/not-a-uuid'), isEmpty);
      expect(AdminBreadcrumb.crumbsFor(''), isEmpty);
    });

    testWidgets('it is text, never a control', (tester) async {
      const id = '11111111-2222-3333-4444-555555555555';
      await tester.pumpWidget(
        _harness(AdminBreadcrumb(location: AdminRoutes.userDetail(id))),
      );

      expect(find.byKey(const Key('admin-breadcrumb')), findsOneWidget);
      // A breadcrumb that navigated would be a second opinion about where a
      // path leads, and a breadcrumb that hid itself would be a second opinion
      // about what an administrator may see.
      expect(find.byType(InkWell), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(GestureDetector), findsNothing);
    });
  });

  group('one heading per page, in the shell', () {
    testWidgets('a section page titles itself once and the bar stays quiet', (
      tester,
    ) async {
      final (_, container) = await pumpAdmin(tester);

      for (final section in AdminSection.values) {
        await tester.tap(find.byKey(Key('admin-nav-${section.name}')));
        await tester.pumpAndSettle();

        expect(locationOf(container), section.path);
        expect(
          find.byKey(const Key('admin-page-title')),
          findsOneWidget,
          reason: '${section.label} must have exactly one primary heading',
        );
        expect(
          tester.widget<Text>(find.byKey(const Key('admin-page-title'))).data,
          section.label,
        );
        expect(
          find.byKey(const Key('admin-breadcrumb')),
          findsNothing,
          reason: 'the root of ${section.label} needs no trail',
        );
      }
    });

    testWidgets('a sub-page shows the trail and still one heading', (
      tester,
    ) async {
      await pumpAdmin(tester, initialLocation: AdminRoutes.salonPilotResearch);

      expect(find.byKey(const Key('admin-breadcrumb')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('admin-breadcrumb'))).data,
        contains('Salon Pilot research'),
      );
      expect(find.byKey(const Key('admin-page-title')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('admin-page-title'))).data,
        'Salon Pilot research',
      );
    });

    testWidgets('identity and sign out survive the header change', (
      tester,
    ) async {
      final (controller, _) = await pumpAdmin(tester);

      expect(find.byKey(const Key('admin-identity')), findsOneWidget);
      expect(find.byKey(const Key('admin-sign-out')), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin-sign-out')));
      await tester.pumpAndSettle();
      expect(controller.signOuts, 1);
    });

    testWidgets('the dashboard keeps its metadata and refresh in the header', (
      tester,
    ) async {
      await pumpAdmin(tester);

      expect(find.byKey(const Key('admin-dashboard-refresh')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('admin-page-title'))).data,
        'Dashboard',
      );
    });
  });
}
