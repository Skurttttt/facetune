import 'dart:ui' show CheckedState, Tristate;

import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/domain/entities/user_settings.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';

/// PSUX-P5: Profile and Settings across the device, text-scale and theme
/// matrix, with the longest realistic account data, plus the semantics a
/// screen-reader user depends on.
void main() {
  for (final device in _devices) {
    for (final scale in [1.0, 2.0]) {
      for (final variant in _variants) {
        final label = '${device.name} · ${scale}x · ${variant.name}';

        testWidgets('Profile — $label', (tester) async {
          await _pump(tester, _Screen.profile, device, scale, variant);
          expect(tester.takeException(), isNull);

          expect(
            find.descendant(
              of: find.byType(TopLevelPageHeader),
              matching: find.text('Profile'),
            ),
            findsOneWidget,
          );
          expect(find.byTooltip('Open settings'), findsNothing);
          final nav = tester.getRect(find.byType(NavigationBar));

          for (final target in [
            find.text(_longName),
            find.text(_longEmail),
            find.text('Edit name'),
            find.text(_longPlan),
            find.text('Research Access'),
            find.text('19 of 30 AI Looks remaining'),
            find.textContaining('Expires'),
            _row('Saved looks'),
            _row('History'),
            _row('My Makeup Kit'),
            _row('Plans & Subscription'),
            _row('Settings & Privacy'),
          ]) {
            await _reach(tester, target, visibleBottom: nav.top);
          }
          expect(_row('Settings & Privacy'), findsOneWidget);
          expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

          await _scrollToEnd(tester);
          final lastCard = tester.getRect(
            find
                .ancestor(
                  of: _row('Settings & Privacy'),
                  matching: find.byType(AppCard),
                )
                .first,
          );
          expect(lastCard.bottom, lessThanOrEqualTo(nav.top));
          expect(tester.takeException(), isNull);
        });

        testWidgets('Settings — $label', (tester) async {
          await _pump(tester, _Screen.settings, device, scale, variant);
          expect(tester.takeException(), isNull);
          final list = tester.getRect(find.byType(ListView));

          // The theme control first, while it is near the top: every segment
          // label must sit inside the control, not spill or vanish.
          final theme = find.byType(SegmentedButton<AppThemePreference>);
          await _reach(
            tester,
            _heading('Appearance'),
            visibleBottom: list.bottom,
          );
          await _reach(tester, theme, visibleBottom: list.bottom);
          final control = tester.getRect(theme);
          for (final segment in ['System', 'Light', 'Dark']) {
            final rect = tester.getRect(find.text(segment));
            expect(rect.width, greaterThan(0), reason: segment);
            expect(rect.left, greaterThanOrEqualTo(control.left - 0.5));
            expect(rect.right, lessThanOrEqualTo(control.right + 0.5));
          }

          for (final target in [
            _heading('Preferences'),
            find.text('Notifications'),
            find.text('Coming soon'),
            _heading('Privacy'),
            _row('Image privacy'),
            _row('Analytics consent'),
            _row('Privacy policy'),
            _heading('About'),
            _row('About FaceTune'),
            find.text('1.1.0 (build 7)'),
            _heading('Account'),
            find.byType(SecondaryButton),
          ]) {
            await _reach(tester, target, visibleBottom: list.bottom);
          }

          await _scrollToEnd(tester);
          final signOut = tester.getRect(find.byType(SecondaryButton));
          expect(signOut.bottom, lessThanOrEqualTo(list.bottom));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  group('accessibility guidelines', () {
    for (final screen in _Screen.values) {
      for (final scale in [1.0, 2.0]) {
        for (final variant in [_variants.first, _variants[1]]) {
          testWidgets('${screen.name} · ${scale}x · ${variant.name}', (
            tester,
          ) async {
            final handle = tester.ensureSemantics();
            await _pump(tester, screen, _devices.first, scale, variant);

            // Checked at every scroll position the page can reach, so rows
            // below the fold are measured too.
            final scrollable = tester.state<ScrollableState>(
              find.descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              ),
            );
            final step = scrollable.position.viewportDimension * 0.6;
            while (true) {
              await expectLater(
                tester,
                meetsGuideline(androidTapTargetGuideline),
              );
              await expectLater(
                tester,
                meetsGuideline(labeledTapTargetGuideline),
              );
              if (scale == 1) {
                await expectLater(
                  tester,
                  meetsGuideline(textContrastGuideline),
                );
              }
              final position = scrollable.position;
              if (position.pixels >= position.maxScrollExtent) break;
              position.jumpTo(
                (position.pixels + step).clamp(0, position.maxScrollExtent),
              );
              await tester.pumpAndSettle();
            }
            handle.dispose();
          });
        }
      }
    }
  });

  group('semantics', () {
    testWidgets('Profile reads top to bottom and every row is actionable', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Screen.profile, _tall, 1, _variants.first);

      final nodes = _traversal(tester);
      _expectOrder(nodes, [
        'Profile',
        'Profile photo',
        _longName,
        'Edit name',
        _longPlan,
        'Your library',
        'Your saved makeup looks',
        'Past analyses and previews',
        'Makeup products you own',
        'Account',
        'See available plans',
        'Appearance, privacy, and sign out',
      ]);
      for (final subtitle in [
        'Your saved makeup looks',
        'Past analyses and previews',
        'Makeup products you own',
        'See available plans',
        'Appearance, privacy, and sign out',
      ]) {
        final row = _node(nodes, subtitle);
        expect(row.hasAction(SemanticsAction.tap), isTrue, reason: subtitle);
      }
      handle.dispose();
    });

    testWidgets('Settings reads top to bottom with honest states', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _Screen.settings, _tall, 1, _variants.first);

      final nodes = _traversal(tester);
      _expectOrder(nodes, [
        'Appearance',
        'System',
        'Light',
        'Dark',
        'Preferences',
        'Coming soon',
        'How your photos are stored',
        'No analytics tools are active yet',
        'Not published yet',
        'What FaceTune does',
        '1.1.0 (build 7)',
        'Sign out',
      ]);

      // Unavailable reads as unavailable: the words say so, and there is
      // nothing to activate.
      final notifications = _node(nodes, 'Coming soon');
      expect(notifications.label, contains('Notifications'));
      expect(notifications.hasAction(SemanticsAction.tap), isFalse);
      expect(notifications.flagsCollection.isButton, isFalse);

      final version = _node(nodes, '1.1.0 (build 7)');
      expect(version.label, contains('App version'));
      expect(version.hasAction(SemanticsAction.tap), isFalse);

      // Switch state is announced, not only drawn.
      final analytics = _node(nodes, 'No analytics tools are active yet');
      expect(analytics.label, contains('Analytics consent'));
      // A toggled state that is "off" rather than "not applicable".
      expect(analytics.flagsCollection.isToggled, Tristate.isFalse);
      expect(analytics.hasAction(SemanticsAction.tap), isTrue);

      // The chosen theme is announced as chosen, not only coloured.
      bool chosen(SemanticsData node) =>
          node.flagsCollection.isSelected == Tristate.isTrue ||
          node.flagsCollection.isChecked == CheckedState.isTrue;
      expect(chosen(_node(nodes, 'System', exact: true)), isTrue);
      expect(chosen(_node(nodes, 'Light', exact: true)), isFalse);
      expect(chosen(_node(nodes, 'Dark', exact: true)), isFalse);

      for (final subtitle in [
        'How your photos are stored',
        'Not published yet',
        'What FaceTune does',
      ]) {
        expect(
          _node(nodes, subtitle).hasAction(SemanticsAction.tap),
          isTrue,
          reason: subtitle,
        );
      }
      expect(_node(nodes, 'Sign out').hasAction(SemanticsAction.tap), isTrue);
      handle.dispose();
    });
  });
}

// ---------------------------------------------------------------------------

const _longName = 'María Alejandra Concepción de los Santos-Villanueva';
const _longEmail =
    'maria.alejandra.concepcion.delossantos.villanueva@example-longdomain.com';
const _longPlan = 'Salon Pilot Research Programme — Extended Partner Access';

enum _Screen { profile, settings }

typedef _Device = ({String name, Size physical, double dpr});

const List<_Device> _devices = [
  (name: 'POCO X3 GT', physical: Size(1080, 2400), dpr: 2.75),
  (name: 'narrow', physical: Size(320, 800), dpr: 1),
  (name: 'short', physical: Size(393, 640), dpr: 1),
];

/// Every section built at once, for reading order.
const _Device _tall = (name: 'tall', physical: Size(1080, 7200), dpr: 3);

typedef _Variant = ({String name, ThemeMode mode, Brightness platform});

const List<_Variant> _variants = [
  (name: 'Light', mode: ThemeMode.light, platform: Brightness.dark),
  (name: 'Dark', mode: ThemeMode.dark, platform: Brightness.light),
  (name: 'System light', mode: ThemeMode.system, platform: Brightness.light),
  (name: 'System dark', mode: ThemeMode.system, platform: Brightness.dark),
];

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

Finder _heading(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(SectionHeader));

/// Scrolls [target] into view, then proves it is fully on screen, above
/// [visibleBottom], and that no visible text has been cut short.
Future<void> _reach(
  WidgetTester tester,
  Finder target, {
  required double visibleBottom,
}) async {
  printOnFailure("reaching $target");
  await tester.scrollUntilVisible(
    target,
    120,
    scrollable: find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pumpAndSettle();
  final viewTop = tester.getRect(find.byType(ListView)).top;
  final rect = tester.getRect(target.first);
  if (rect.height > visibleBottom - viewTop) {
    // Taller than the screen (a long sentence at 2x on a small phone): it can
    // never be seen whole, so its top and its bottom must each be reachable.
    await _scrollBy(tester, rect.top - viewTop);
    await tester.pumpAndSettle();
    final top = tester.getRect(target.first);
    expect(top.top, greaterThanOrEqualTo(viewTop - 1), reason: '$target');
    _expectNoClippedText(tester);
    await _scrollBy(tester, top.bottom - visibleBottom);
    await tester.pumpAndSettle();
    final bottom = tester.getRect(target.first);
    expect(
      bottom.bottom,
      lessThanOrEqualTo(visibleBottom + 1),
      reason: '$target',
    );
    _expectNoClippedText(tester);
    return;
  }
  // Lift it clear of anything pinned at the bottom (the navigation bar).
  if (rect.bottom > visibleBottom) {
    await _scrollBy(tester, rect.bottom - visibleBottom + 8);
    await tester.pumpAndSettle();
  }
  final shown = tester.getRect(target.first);
  expect(shown.top, greaterThanOrEqualTo(0), reason: '$target');
  expect(shown.bottom, lessThanOrEqualTo(visibleBottom), reason: '$target');
  _expectNoClippedText(tester);
}

/// No paragraph inside the page content was truncated or ellipsized.
void _expectNoClippedText(WidgetTester tester) {
  for (final element
      in find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(RichText),
          )
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: 'clipped: "${paragraph.text.toPlainText()}"',
    );
  }
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  final position = tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

List<SemanticsData> _traversal(WidgetTester tester) {
  var root = tester.getSemantics(find.byType(Scaffold).first);
  while (root.parent != null) {
    root = root.parent!;
  }
  final ordered = <SemanticsData>[];
  void visit(SemanticsNode node) {
    ordered.add(node.getSemanticsData());
    for (final child in node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    )) {
      visit(child);
    }
  }

  visit(root);
  return ordered;
}

SemanticsData _node(
  List<SemanticsData> nodes,
  String text, {
  bool exact = false,
}) => nodes.firstWhere(
  (node) => exact ? node.label == text : node.label.contains(text),
  orElse: () => throw TestFailure('no semantics node for "$text"'),
);

void _expectOrder(List<SemanticsData> nodes, List<String> texts) {
  var previous = -1;
  for (final text in texts) {
    final index = nodes.indexWhere(
      (node) => node.label == text || node.label.contains(text),
    );
    // Equal is allowed: two labels merged into one node read together.
    expect(
      index,
      greaterThanOrEqualTo(previous),
      reason: '"$text" out of order',
    );
    expect(index, isNot(-1), reason: '"$text" not announced');
    previous = index;
  }
}

class _Subscriptions implements SubscriptionRepository {
  @override
  Future<SubscriptionSummary> resolve() async => SubscriptionSummary(
    hasEntitlement: true,
    planCode: SubscriptionPlanCode.salonPilot,
    planDisplayName: _longPlan,
    usage: const SubscriptionUsageSummary(
      effectiveAllowance: 30,
      committedUsage: 11,
    ),
    generationAuthorized: true,
    resolvedAt: DateTime.now().toUtc(),
    status: EntitlementStatus.active,
    billingProvider: BillingProvider.adminGranted,
    resetPolicy: ResetPolicy.none,
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 60)),
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Screen screen,
  _Device device,
  double scale,
  _Variant variant,
) async {
  tester.view
    ..physicalSize = device.physical
    ..devicePixelRatio = device.dpr;
  tester.platformDispatcher.platformBrightnessTestValue = variant.platform;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final auth = FakeAuthRepository(
    user: const AuthUser(
      id: 'registered-user',
      email: _longEmail,
      displayName: _longName,
      isAnonymous: false,
    ),
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(
          FakeProfileRepository(
            profile: UserProfile(
              id: 'profile-registered-user',
              authUserId: 'registered-user',
              displayName: _longName,
              createdAt: DateTime.utc(2026, 8, 11),
              updatedAt: DateTime.utc(2026, 8, 11),
            ),
          ),
        ),
        avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
        subscriptionRepositoryProvider.overrideWithValue(_Subscriptions()),
        settingsRepositoryProvider.overrideWithValue(
          FakeSettingsRepository(settings: UserSettings.defaults()),
        ),
        appVersionProvider.overrideWith((ref) async => '1.1.0+7'),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: variant.mode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: switch (screen) {
          _Screen.profile => const ProfilePage(),
          _Screen.settings => const SettingsPage(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Moves the page by exactly [delta] logical pixels (positive scrolls down).
/// A drag gesture would lose its touch slop and land a few pixels short.
Future<void> _scrollBy(WidgetTester tester, double delta) async {
  final position = tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      )
      .position;
  position.jumpTo(
    (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    ),
  );
  await tester.pumpAndSettle();
}
