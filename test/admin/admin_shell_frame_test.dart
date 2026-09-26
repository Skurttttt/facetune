import 'package:facetune/admin/app/admin_routes.dart';
import 'package:facetune/admin/auth/presentation/admin_authorization_state.dart';
import 'package:facetune/admin/shell/admin_shell.dart';
import 'package:facetune/admin/shell/admin_sidebar.dart';
import 'package:facetune/admin/theme/admin_theme.dart';
import 'package:facetune/admin/theme/admin_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_shell_test.dart' show pumpAdmin, locationOf;

/// WA-13.5-UI-2: the application frame.
///
/// These assert the frame's measurements, its colours and — the point of the
/// phase — its scroll ownership: the shell scrolls vertically and never
/// horizontally, so no page can slide sideways and strand its right-hand
/// action column. Routing, authorization and section behaviour are asserted
/// by `admin_shell_test.dart` and `admin_router_test.dart`; this file must
/// not duplicate them, only prove they still hold through the new frame.
void main() {
  group('frame measurements', () {
    test('the frame uses the canonical sizes', () {
      expect(AdminShell.sidebarWidth, 232);
      expect(AdminShell.topBarHeight, 64);
      expect(AdminShell.maxContentWidth, 1480);
    });

    test('the content inset follows the viewport, not one flat value', () {
      expect(AdminShell.contentInsetFor(1920), AdminSpacing.xxl); // 40
      expect(AdminShell.contentInsetFor(1440), AdminSpacing.xxl); // 40
      expect(AdminShell.contentInsetFor(1366), AdminSpacing.xl); // 32
      expect(AdminShell.contentInsetFor(1200), AdminSpacing.xl); // 32
      expect(AdminShell.contentInsetFor(1100), AdminSpacing.lg); // 24
      expect(AdminShell.contentInsetFor(1024), AdminSpacing.lg); // 24
      expect(AdminShell.contentInsetFor(900), AdminSpacing.ml); // 20
      expect(AdminShell.contentInsetFor(768), AdminSpacing.ml); // 20
      expect(AdminShell.contentInsetFor(600), AdminSpacing.md); // 16
    });

    test('every inset is a step on the admin spacing scale', () {
      const scale = [
        AdminSpacing.xxs,
        AdminSpacing.xs,
        AdminSpacing.sm,
        AdminSpacing.md,
        AdminSpacing.ml,
        AdminSpacing.lg,
        AdminSpacing.xl,
        AdminSpacing.xxl,
        AdminSpacing.xxxl,
      ];
      for (final width in const [1920, 1440, 1366, 1200, 1024, 900, 768, 600]) {
        expect(
          scale,
          contains(AdminShell.contentInsetFor(width.toDouble())),
          reason: 'inset at ${width}px is off the scale',
        );
      }
    });

    testWidgets('the rail is 232 wide when extended and carries the sidebar '
        'surface', (tester) async {
      await pumpAdmin(tester, size: const Size(1600, 900));

      final sidebar = tester.widget<AdminSidebar>(
        find.byKey(const Key('admin-nav-rail')),
      );
      expect(sidebar.extended, isTrue);

      final railSize = tester.getSize(find.byKey(const Key('admin-nav-rail')));
      expect(railSize.width, AdminShell.sidebarWidth);
    });

    for (final entry in const [
      (1440.0, true),
      (1200.0, true),
      (1024.0, false),
      (768.0, false),
    ]) {
      testWidgets(
        'the ${entry.$1.toInt()}px width class uses the safe sidebar mode',
        (tester) async {
          await pumpAdmin(tester, size: Size(entry.$1, 900));

          final sidebar = tester.widget<AdminSidebar>(
            find.byKey(const Key('admin-nav-rail')),
          );
          expect(sidebar.extended, entry.$2);
          expect(find.byKey(const Key('admin-nav-drawer')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the top utility bar is 64 tall', (tester) async {
      await pumpAdmin(tester, size: const Size(1600, 900));

      // Anchored on the identity chip: since UI-4 the bar carries no title.
      final identity = find.byKey(const Key('admin-identity'));
      expect(identity, findsOneWidget);

      final bar = find.ancestor(of: identity, matching: find.byType(Container));
      expect(tester.getSize(bar.first).height, AdminShell.topBarHeight);
    });

    testWidgets('content is inset by the band and capped at the readable '
        'column', (tester) async {
      await pumpAdmin(tester, size: const Size(1920, 900));

      final scroll = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('admin-content-scroll')),
      );
      expect(scroll.padding, const EdgeInsets.all(AdminSpacing.xxl));

      final box = tester.widget<ConstrainedBox>(
        find.byKey(const Key('admin-content-column')),
      );
      expect(box.constraints.maxWidth, AdminShell.maxContentWidth);
    });
  });

  group('scroll ownership', () {
    testWidgets('the shell scrolls vertically and never horizontally', (
      tester,
    ) async {
      await pumpAdmin(tester, size: const Size(1440, 900));

      // The frame's own scroll view is vertical. Any horizontal one belongs
      // to a table inside the section and is contained by it.
      final frame = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('admin-content-scroll')),
      );
      expect(frame.scrollDirection, Axis.vertical);
      expect(frame.primary, isTrue);
    });

    for (final size in const [
      Size(1920, 1080),
      Size(1440, 900),
      Size(1200, 800),
      Size(1024, 768),
      Size(768, 720),
    ]) {
      testWidgets('the frame does not overflow at ${size.width.toInt()}px', (
        tester,
      ) async {
        await pumpAdmin(tester, size: size);

        expect(
          tester.takeException(),
          isNull,
          reason: 'the shell overflowed at ${size.width}px',
        );

        final shell = tester.getSize(find.byType(AdminShell));
        expect(
          shell.width,
          lessThanOrEqualTo(size.width),
          reason: 'the frame is wider than the viewport at ${size.width}px',
        );
      });
    }
  });

  group('the frame changed nothing functional', () {
    testWidgets('every section still renders inside the shell', (tester) async {
      final (_, container) = await pumpAdmin(tester);

      for (final section in AdminSection.values) {
        await tester.tap(find.byKey(Key('admin-nav-${section.name}')));
        await tester.pumpAndSettle();

        expect(locationOf(container), section.path, reason: section.label);
        expect(find.byType(AdminShell), findsOneWidget, reason: section.label);
        expect(
          find.byKey(Key('admin-section-${section.name}')),
          findsOneWidget,
          reason: section.label,
        );
      }
    });

    testWidgets('a sub-page route also renders inside the shell', (
      tester,
    ) async {
      final (_, container) = await pumpAdmin(
        tester,
        initialLocation: AdminRoutes.salonPilotResearch,
      );

      expect(locationOf(container), AdminRoutes.salonPilotResearch);
      expect(find.byType(AdminShell), findsOneWidget);
      expect(find.byKey(const Key('admin-nav-rail')), findsOneWidget);
    });

    testWidgets('sign out is still present and still signs out', (
      tester,
    ) async {
      final (controller, _) = await pumpAdmin(tester);

      final signOut = find.byKey(const Key('admin-sign-out'));
      expect(signOut, findsOneWidget);
      expect(find.byKey(const Key('admin-identity')), findsOneWidget);

      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(controller.signOuts, 1);
    });

    testWidgets('the narrow window still uses the drawer, now on the sidebar '
        'surface', (tester) async {
      await pumpAdmin(tester, size: const Size(700, 900));

      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.drawer, isNotNull);

      final drawer = scaffold.drawer! as NavigationDrawer;
      expect(drawer.backgroundColor, AdminColors.sidebarBackground);
    });

    testWidgets('an unauthorized visitor gets no frame at all', (tester) async {
      await pumpAdmin(
        tester,
        state: const AdminUnauthorized(),
        size: const Size(1440, 900),
      );

      // The resized, recoloured frame must not have become reachable to
      // someone the server did not authorize: no rail, no section content
      // region, no shell at all. The sign-out control the unauthorized page
      // offers is its own — that page is the only thing rendered here.
      expect(find.byType(AdminShell), findsNothing);
      expect(find.byKey(const Key('admin-nav-rail')), findsNothing);
      expect(find.byKey(const Key('admin-content-scroll')), findsNothing);
      expect(find.byKey(const Key('admin-page-title')), findsNothing);
    });
  });

  group('the frame uses the admin theme, not raw colour', () {
    testWidgets('the sidebar reads its colour from the semantic roles', (
      tester,
    ) async {
      await pumpAdmin(tester, size: const Size(1600, 900));

      final context = tester.element(find.byType(AdminShell));
      final semantics = AdminSemanticColors.of(context);

      final surface = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('admin-nav-rail')),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(surface.color, semantics.sidebarBackground);
      expect(
        Theme.of(context).scaffoldBackgroundColor,
        semantics.pageBackground,
      );
    });
  });
}
