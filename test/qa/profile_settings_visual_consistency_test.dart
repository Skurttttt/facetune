import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/settings/data/providers/settings_providers.dart';
import 'package:facetune/features/settings/presentation/pages/settings_page.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/data/repositories/unavailable_subscription_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:facetune/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_account_repositories.dart';
import '../helpers/fake_auth_repository.dart';

/// PSUX-P4: the restructured Profile and Settings speak one design language.
///
/// Measured from the rendered tree rather than from screenshots: list rows take
/// their colours from `listTileTheme` (no per-screen overrides), share one
/// height and one icon/chevron column, sections keep the token rhythm, and the
/// last action clears the bottom of the page — in all four theme states.
void main() {
  for (final variant in _variants) {
    group(variant.name, () {
      testWidgets('Profile and Settings rows share the theme colours', (
        tester,
      ) async {
        await _pump(tester, _Screen.profile, variant, tall: true);
        final profile = _rowStyle(tester, _profileIcons, _profileSubtitles);

        await _pump(tester, _Screen.settings, variant, tall: true);
        final settings = _rowStyle(tester, _settingsIcons, _settingsSubtitles);

        final theme = Theme.of(tester.element(find.byType(ListTile).first));
        expect(theme.brightness, variant.brightness);
        final expected = (
          icon: theme.listTileTheme.iconColor,
          subtitle: theme.listTileTheme.subtitleTextStyle?.color,
        );
        expect(profile, {expected}, reason: 'Profile follows the theme');
        expect(settings, {expected}, reason: 'Settings follows the theme');
      });

      testWidgets('rows share one height, icon column and chevron column', (
        tester,
      ) async {
        await _pump(tester, _Screen.profile, variant, tall: true);
        final profile = _geometry(tester, _profileRows);

        await _pump(tester, _Screen.settings, variant, tall: true);
        final settings = _geometry(tester, _settingsRows);

        final all = [...profile, ...settings];
        expect(all.map((row) => row.height).toSet(), hasLength(1));
        expect(all.map((row) => row.iconLeft).toSet(), hasLength(1));
        final chevrons = all.map((row) => row.chevronRight).nonNulls.toSet();
        expect(chevrons, hasLength(1));
      });

      testWidgets('Profile sections keep the page rhythm', (tester) async {
        await _pump(tester, _Screen.profile, variant, tall: true);

        final library = _cardOf(tester, 'My Makeup Kit');
        final account = _header(tester, 'Account');
        final accountCard = _cardOf(tester, 'Settings & Privacy');
        final libraryHeader = _header(tester, 'Your library');

        expect(account.top - library.bottom, AppSpacing.lg);
        expect(accountCard.top - account.bottom, AppSpacing.xs);
        expect(
          library.top - libraryHeader.bottom,
          accountCard.top - account.bottom,
          reason: 'both sections hang their card the same way',
        );
      });

      testWidgets('Settings sections keep the page rhythm', (tester) async {
        await _pump(tester, _Screen.settings, variant, tall: true);

        for (final (header, previousRow, firstRow) in [
          ('Preferences', null, 'Notifications'),
          ('Privacy', 'Notifications', 'Image privacy'),
          ('About', 'Privacy policy', 'About FaceTune'),
        ]) {
          final rect = _header(tester, header);
          if (previousRow != null) {
            expect(
              rect.top - _cardOf(tester, previousRow).bottom,
              AppSpacing.xl,
              reason: header,
            );
          }
          expect(
            _cardOf(tester, firstRow).top - rect.bottom,
            AppSpacing.sm,
            reason: header,
          );
        }
        final account = _header(tester, 'Account');
        final signOut = tester.getRect(find.byType(SecondaryButton));
        expect(
          account.top - _cardOf(tester, 'App version').bottom,
          AppSpacing.xl,
        );
        expect(signOut.top - account.bottom, AppSpacing.sm);
      });

      testWidgets('the last action clears the bottom on a POCO X3 GT', (
        tester,
      ) async {
        await _pump(tester, _Screen.profile, variant);
        await _scrollToEnd(tester);
        final nav = tester.getRect(find.byType(NavigationBar));
        final lastCard = _cardOf(tester, 'Settings & Privacy');
        expect(lastCard.bottom, lessThanOrEqualTo(nav.top - AppSpacing.xl));
        expect(tester.takeException(), isNull);

        await _pump(tester, _Screen.settings, variant);
        await _scrollToEnd(tester);
        final list = tester.getRect(find.byType(ListView));
        final signOut = tester.getRect(find.byType(SecondaryButton));
        expect(signOut.bottom, lessThanOrEqualTo(list.bottom - AppSpacing.xl));
        expect(tester.takeException(), isNull);
      });
    });
  }
}

enum _Screen { profile, settings }

typedef _Variant = ({
  String name,
  ThemeMode mode,
  Brightness platform,
  Brightness brightness,
});

const List<_Variant> _variants = [
  (
    name: 'Light',
    mode: ThemeMode.light,
    platform: Brightness.dark,
    brightness: Brightness.light,
  ),
  (
    name: 'Dark',
    mode: ThemeMode.dark,
    platform: Brightness.light,
    brightness: Brightness.dark,
  ),
  (
    name: 'System light',
    mode: ThemeMode.system,
    platform: Brightness.light,
    brightness: Brightness.light,
  ),
  (
    name: 'System dark',
    mode: ThemeMode.system,
    platform: Brightness.dark,
    brightness: Brightness.dark,
  ),
];

const _profileIcons = [
  Icons.favorite_border_rounded,
  Icons.history_rounded,
  Icons.inventory_2_outlined,
  Icons.workspace_premium_outlined,
  Icons.settings_outlined,
];

const _profileSubtitles = [
  'Your saved makeup looks',
  'Past analyses and previews',
  'Makeup products you own',
  'See available plans',
  'Appearance, privacy, and sign out',
];

const _settingsIcons = [
  Icons.notifications_outlined,
  Icons.image_outlined,
  Icons.analytics_outlined,
  Icons.policy_outlined,
  Icons.info_outline_rounded,
  Icons.tag_rounded,
];

const _settingsSubtitles = [
  'Coming soon',
  'How your photos are stored',
  'Not published yet',
  'What FaceTune does',
];

const _profileRows = [
  'Saved looks',
  'History',
  'My Makeup Kit',
  'Plans & Subscription',
  'Settings & Privacy',
];

/// Every single-line-subtitle row. Analytics consent is left out on purpose:
/// its subtitle is a full sentence, and a row that wraps is allowed to grow.
const _settingsRows = [
  'Notifications',
  'Image privacy',
  'Privacy policy',
  'About FaceTune',
  'App version',
];

Finder _row(String title) =>
    find.ancestor(of: find.text(title), matching: find.byType(ListTile));

Set<({Color? icon, Color? subtitle})> _rowStyle(
  WidgetTester tester,
  List<IconData> icons,
  List<String> subtitles,
) {
  Color? colorOf(Finder finder) => tester
      .widget<RichText>(
        find.descendant(of: finder, matching: find.byType(RichText)).first,
      )
      .text
      .style
      ?.color;
  final iconColors = {for (final icon in icons) colorOf(find.byIcon(icon))};
  final subtitleColors = {
    for (final subtitle in subtitles) colorOf(find.text(subtitle)),
  };
  expect(iconColors, hasLength(1), reason: 'one icon colour: $iconColors');
  expect(subtitleColors, hasLength(1), reason: 'one subtitle colour');
  return {(icon: iconColors.single, subtitle: subtitleColors.single)};
}

List<({double height, double iconLeft, double? chevronRight})> _geometry(
  WidgetTester tester,
  List<String> titles,
) => [
  for (final title in titles)
    (() {
      final row = _row(title);
      final icon = find.descendant(of: row, matching: find.byType(Icon));
      final chevron = find.descendant(
        of: row,
        matching: find.byIcon(Icons.chevron_right_rounded),
      );
      return (
        height: tester.getSize(row).height,
        iconLeft: tester.getTopLeft(icon.first).dx,
        chevronRight: chevron.evaluate().isEmpty
            ? null
            : tester.getTopRight(chevron).dx,
      );
    })(),
];

Rect _cardOf(WidgetTester tester, String rowTitle) => tester.getRect(
  find.ancestor(of: _row(rowTitle), matching: find.byType(AppCard)).first,
);

Rect _header(WidgetTester tester, String title) => tester.getRect(
  find.ancestor(of: find.text(title), matching: find.byType(SectionHeader)),
);

Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = find.descendant(
    of: find.byType(ListView),
    matching: find.byType(Scrollable),
  );
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  _Screen screen,
  _Variant variant, {
  bool tall = false,
}) async {
  // Tall: every section built at once, and wide enough that no subtitle wraps.
  // The test font draws every glyph as a full em square, so at phone width it
  // wraps copy that fits on a device, and row heights would measure the font
  // rather than the layout. Otherwise the POCO X3 GT, the primary device:
  // 1080x2400 physical at 2.75 dpr.
  tester.view
    ..physicalSize = tall ? const Size(1600, 5000) : const Size(1080, 2400)
    ..devicePixelRatio = tall ? 1 : 2.75;
  tester.platformDispatcher.platformBrightnessTestValue = variant.platform;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

  final auth = FakeAuthRepository(
    user: const AuthUser(
      id: 'registered-user',
      email: 'mia@example.com',
      displayName: 'Mia Chen',
      isAnonymous: false,
    ),
  );
  addTearDown(auth.dispose);

  // A fresh scope per pump, so the second screen in a test never inherits
  // the first one's providers.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
        subscriptionRepositoryProvider.overrideWithValue(
          const UnavailableSubscriptionRepository(),
        ),
        settingsRepositoryProvider.overrideWithValue(FakeSettingsRepository()),
        appVersionProvider.overrideWith((ref) async => '1.1.0+7'),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: variant.mode,
        home: switch (screen) {
          _Screen.profile => const ProfilePage(),
          _Screen.settings => const SettingsPage(),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
