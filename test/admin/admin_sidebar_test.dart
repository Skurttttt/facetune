import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/shell/admin_sidebar.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_shell_test.dart' show pumpAdmin, locationOf;

/// WA-13.5-UI-3: the sidebar's presentation.
///
/// Navigation *behaviour* — that a destination routes, that the route survives
/// a refresh, that an unauthorized visitor never sees the rail — is asserted
/// in `admin_shell_test.dart` and `admin_router_test.dart`. This file asserts
/// what UI-3 changed: the measurements, the selected and hover treatments, and
/// that nothing about the destinations themselves moved.
Widget _harness({
  AdminSection? selected = AdminSection.dashboard,
  bool extended = true,
  ValueChanged<AdminSection>? onSelect,
}) => MaterialApp(
  theme: AdminTheme.dark,
  home: Scaffold(
    body: Row(
      children: [
        AdminSidebar(
          selected: selected,
          extended: extended,
          onSelect: onSelect ?? (_) {},
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    ),
  ),
);

void main() {
  group('destinations are unchanged', () {
    test('the canonical five, in order', () {
      expect(AdminSidebar.sections, AdminSection.values);
      expect(AdminSidebar.sections.map((section) => section.label), const [
        'Dashboard',
        'Users',
        'Entitlements',
        'Usage',
        'Audit',
      ]);
      expect(AdminSidebar.sections.map((section) => section.path), const [
        '/dashboard',
        '/users',
        '/entitlements',
        '/usage',
        '/audit',
      ]);
    });

    testWidgets('exactly five rows render, no more', (tester) async {
      await tester.pumpWidget(_harness());

      for (final section in AdminSection.values) {
        expect(
          find.byKey(Key('admin-nav-${section.name}')),
          findsOneWidget,
          reason: section.label,
        );
      }
      expect(find.byType(InkWell), findsNWidgets(AdminSection.values.length));
    });

    testWidgets('every destination reports its own tap', (tester) async {
      final tapped = <AdminSection>[];
      await tester.pumpWidget(_harness(onSelect: tapped.add));

      for (final section in AdminSection.values) {
        await tester.tap(find.byKey(Key('admin-nav-${section.name}')));
        await tester.pump();
      }

      expect(tapped, AdminSection.values);
    });
  });

  group('measurements', () {
    test('the canonical sizes', () {
      expect(AdminShellMetrics.expandedWidth, 232);
      expect(AdminSidebar.brandHeight, 64);
      expect(AdminSidebar.rowHeight, 44);
      expect(AdminSidebar.compactWidth, 72);
      expect(AdminSidebar.indicatorWidth, 3);
    });

    testWidgets('expanded is 232 wide with a 64 brand region', (tester) async {
      await tester.pumpWidget(_harness());

      expect(
        tester.getSize(find.byType(AdminSidebar)).width,
        AdminShellMetrics.expandedWidth,
      );
      expect(
        tester.getSize(find.byType(AdminBrand)).height,
        AdminSidebar.brandHeight,
      );
    });

    testWidgets('compact is 72 wide', (tester) async {
      await tester.pumpWidget(_harness(extended: false));

      expect(
        tester.getSize(find.byType(AdminSidebar)).width,
        AdminSidebar.compactWidth,
      );
    });

    testWidgets('a row is 44 high with a 20px icon', (tester) async {
      await tester.pumpWidget(_harness());

      final icon = tester.widget<Icon>(
        find.byKey(const Key('admin-nav-users')),
      );
      expect(icon.size, AdminIconSizes.lg);
      expect(AdminIconSizes.lg, 20);

      final row = find.ancestor(
        of: find.byKey(const Key('admin-nav-users')),
        matching: find.byType(Container),
      );
      expect(tester.getSize(row.first).height, AdminSidebar.rowHeight);
    });

    testWidgets('the icon and its label are 12 apart', (tester) async {
      await tester.pumpWidget(_harness());

      // Measured rather than read off a SizedBox: `Icon` builds a SizedBox of
      // its own size, so reading "the first SizedBox" would measure the icon.
      final icon = tester.getRect(find.byKey(const Key('admin-nav-users')));
      final label = tester.getRect(find.text('Users'));

      expect(label.left - icon.right, AdminSpacing.sm);
      expect(AdminSpacing.sm, 12);
    });
  });

  group('selected treatment', () {
    testWidgets('the active row is accent-subtle, not a full pill', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selected: AdminSection.usage));

      final row = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const Key('admin-nav-usage')),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = row.decoration! as BoxDecoration;

      expect(decoration.color, AdminColors.accentSubtle);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(AdminRadii.control),
        reason: 'a 6px radius, never a capsule',
      );
      expect(AdminRadii.control, lessThan(AdminRadii.pill));
    });

    testWidgets('an inactive row carries no fill', (tester) async {
      await tester.pumpWidget(_harness(selected: AdminSection.usage));

      final row = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const Key('admin-nav-audit')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((row.decoration! as BoxDecoration).color, isNull);
    });

    testWidgets('the active label is semibold, the others are not', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selected: AdminSection.users));

      Text labelOf(String text) => tester.widget<Text>(find.text(text));

      expect(labelOf('Users').style?.fontWeight, FontWeight.w600);
      expect(labelOf('Audit').style?.fontWeight, FontWeight.w500);
    });

    testWidgets('only the active row draws the 3px edge indicator', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selected: AdminSection.entitlements));

      final indicators = find.descendant(
        of: find.byType(AdminSidebar),
        matching: find.byType(Positioned),
      );
      expect(indicators, findsOneWidget);
      expect(tester.getSize(indicators).width, AdminSidebar.indicatorWidth);
    });

    testWidgets('no row is active when the route is not a section', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(selected: null));

      expect(
        find.descendant(
          of: find.byType(AdminSidebar),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
    });

    testWidgets('hover uses the secondary surface', (tester) async {
      await tester.pumpWidget(_harness());

      final inkWell = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.byKey(const Key('admin-nav-users')),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(inkWell.hoverColor, AdminColors.surfaceSecondary);
    });
  });

  group('accessibility', () {
    testWidgets('each row is a labelled button that reports selection', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_harness(selected: AdminSection.audit));

      for (final section in AdminSection.values) {
        expect(
          tester.getSemantics(find.byKey(Key('admin-nav-${section.name}'))),
          containsSemantics(label: section.label, isButton: true),
          reason: section.label,
        );
      }

      expect(
        tester.getSemantics(find.byKey(const Key('admin-nav-audit'))),
        containsSemantics(label: 'Audit', isButton: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.byKey(const Key('admin-nav-usage'))),
        containsSemantics(isSelected: false),
        reason: 'only the current section reports itself selected',
      );

      handle.dispose();
    });

    testWidgets('a compact row keeps its label in the tooltip', (tester) async {
      await tester.pumpWidget(_harness(extended: false));

      expect(find.text('Entitlements'), findsNothing);

      final tooltip = tester.widget<Tooltip>(
        find
            .ancestor(
              of: find.byKey(const Key('admin-nav-entitlements')),
              matching: find.byType(Tooltip),
            )
            .first,
      );
      expect(tooltip.message, 'Entitlements');
    });

    testWidgets('a focused row shows a visible accent ring', (tester) async {
      await tester.pumpWidget(_harness());

      // Walk focus onto the first row.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final decorated = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(AdminSidebar),
              matching: find.byType(Container),
            ),
          )
          .where((container) {
            final decoration = container.decoration;
            return decoration is BoxDecoration && decoration.border != null;
          });

      expect(
        decorated,
        isNotEmpty,
        reason: 'keyboard focus must be visible, not just an ink splash',
      );
      final border =
          (decorated.first.decoration! as BoxDecoration).border! as Border;
      expect(border.top.color, AdminColors.accent);
      expect(border.top.width, AdminFocus.ringWidth);
    });
  });

  group('inside the shell', () {
    testWidgets('every destination still navigates', (tester) async {
      final (_, container) = await pumpAdmin(tester);

      for (final section in AdminSection.values) {
        await tester.tap(find.byKey(Key('admin-nav-${section.name}')));
        await tester.pumpAndSettle();
        expect(locationOf(container), section.path, reason: section.label);
      }
    });

    testWidgets('the current route stays visibly selected', (tester) async {
      await pumpAdmin(tester);

      await tester.tap(find.byKey(const Key('admin-nav-usage')));
      await tester.pumpAndSettle();

      final sidebar = tester.widget<AdminSidebar>(
        find.byKey(const Key('admin-nav-rail')),
      );
      expect(sidebar.selected, AdminSection.usage);

      final row = tester.widget<Container>(
        find
            .ancestor(
              of: find.byKey(const Key('admin-nav-usage')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (row.decoration! as BoxDecoration).color,
        AdminColors.accentSubtle,
      );
    });

    testWidgets('a sub-page keeps its parent section selected', (tester) async {
      await pumpAdmin(tester, initialLocation: AdminRoutes.salonPilotResearch);

      final sidebar = tester.widget<AdminSidebar>(
        find.byKey(const Key('admin-nav-rail')),
      );
      expect(sidebar.selected, AdminSection.dashboard);
    });
  });
}
