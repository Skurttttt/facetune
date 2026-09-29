import 'dart:io';

import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/profile/data/providers/profile_providers.dart';
import 'package:facetune/features/profile/domain/entities/user_profile.dart';
import 'package:facetune/features/profile/presentation/pages/profile_page.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_account_repositories.dart';
import '../../helpers/fake_auth_repository.dart';

/// PSUX-P1: Profile is an account hub with one Settings entry point.
///
/// The restructure is presentation-only, so these tests hold the things it must
/// not have moved: every destination and its navigation semantics (a tab switch
/// stays a tab switch, a pushed screen stays pushed), the name editor, the plan
/// card's visibility and values, and how often the page asks for data.
void main() {
  group('Profile information architecture', () {
    testWidgets('exposes exactly one Settings entry, in the Account section', (
      tester,
    ) async {
      final harness = await _pump(tester);

      expect(find.byTooltip('Open settings'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(TopLevelPageHeader),
          matching: find.byType(IconButton),
        ),
        findsNothing,
      );
      expect(find.text('Settings and privacy'), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(_row('Settings & Privacy'), findsOneWidget);

      await tester.tap(_row('Settings & Privacy'));
      await tester.pumpAndSettle();

      expect(find.text('settings screen'), findsOneWidget);
      expect(harness.router.canPop(), isTrue, reason: 'still pushed');
    });

    testWidgets('orders identity, plan, library, then account', (tester) async {
      await _pump(tester, summary: _plus);

      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final identity = top(find.text('Mia Chen'));
      final plan = top(find.byKey(const ValueKey('subscription-summary-card')));
      final library = top(find.text('Your library'));
      final account = top(find.text('Account'));

      expect(identity, lessThan(plan));
      expect(plan, lessThan(library));
      expect(library, lessThan(account));
      for (final row in ['Saved looks', 'History', 'My Makeup Kit']) {
        expect(top(_row(row)), inExclusiveRange(library, account));
      }
      for (final row in ['Plans & Subscription', 'Settings & Privacy']) {
        expect(top(_row(row)), greaterThan(account));
      }
    });

    for (final destination in _destinations) {
      testWidgets('${destination.label} still opens ${destination.route}', (
        tester,
      ) async {
        final harness = await _pump(tester);

        await tester.tap(_row(destination.label));
        await tester.pumpAndSettle();

        expect(find.text(destination.screen), findsOneWidget);
        expect(
          harness.router.canPop(),
          destination.pushed,
          reason: destination.pushed
              ? 'opened as a pushed screen'
              : 'switched location without stacking, like a tab',
        );
      });
    }

    testWidgets('Edit name still edits only the display name', (tester) async {
      final harness = await _pump(tester);

      expect(find.text('Edit display name'), findsNothing);
      await tester.tap(find.text('Edit name'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Edit name'),
        ),
        findsOneWidget,
      );
      // One field, pre-filled with the current display name: nothing else about
      // the profile is editable here, which is why the label is "Edit name".
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TextFormField),
          matching: find.text('Mia Chen'),
        ),
        findsOneWidget,
      );

      // The display-name validator still guards Save.
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(harness.profiles.nameUpdates, 0);

      // A valid name saves once and closes the dialog cleanly. Before PSUX-P5
      // closing threw: the controller was disposed mid-animation.
      await tester.enterText(find.byType(TextFormField), 'Ana Ruiz');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.profiles.nameUpdates, 1);
      expect(harness.profiles.profile.displayName, 'Ana Ruiz');
      expect(find.text('Ana Ruiz'), findsOneWidget);
    });

    testWidgets('cancelling Edit name saves nothing and closes cleanly', (
      tester,
    ) async {
      final harness = await _pump(tester);

      await tester.tap(find.text('Edit name'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Ana Ruiz');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(harness.profiles.nameUpdates, 0);
      expect(find.text('Mia Chen'), findsOneWidget);
    });

    testWidgets('an entitled plan card keeps its values and opens plans', (
      tester,
    ) async {
      final harness = await _pump(tester, summary: _plus);

      expect(
        find.byKey(const ValueKey('subscription-summary-card')),
        findsOneWidget,
      );
      expect(find.text('FaceTune Plus'), findsOneWidget);
      expect(find.text('2 of 3 AI Looks remaining'), findsOneWidget);
      expect(find.text('Compare plans'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('subscription-summary-compare-plans')),
      );
      await tester.pumpAndSettle();

      expect(find.text('plans screen'), findsOneWidget);
      expect(harness.router.canPop(), isTrue);
    });

    testWidgets('an unprovisioned account still hides the plan card', (
      tester,
    ) async {
      await _pump(tester, summary: _unprovisioned);

      expect(
        find.byKey(const ValueKey('subscription-summary-card')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('profile-plans-and-subscription')),
        findsOneWidget,
      );
    });

    testWidgets('asks for profile and subscription data once each', (
      tester,
    ) async {
      final harness = await _pump(tester, summary: _plus);

      expect(harness.profiles.loads, 1);
      expect(harness.subscriptions.resolves, 1);
    });

    test('the page source keeps one Settings route and no AI dependency', () {
      final source = File(
        'lib/features/profile/presentation/pages/profile_page.dart',
      ).readAsStringSync();

      expect(
        RegExp(r'AppConstants\.settingsRoute').allMatches(source),
        hasLength(1),
      );
      final imports = RegExp(
        r"^import '([^']+)';",
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)!);
      for (final path in imports) {
        expect(
          path,
          isNot(
            matches(
              RegExp(
                r'features/(analysis|preview|recommendation|tutorial|makeup_kit|scan)/',
              ),
            ),
          ),
        );
      }
    });
  });
}

/// A Profile row by its title. The bottom navigation reuses some of the same
/// words, so an unscoped text finder would be ambiguous.
Finder _row(String title) => find.widgetWithText(ListTile, title);

typedef _Destination = ({
  String label,
  String route,
  String screen,
  bool pushed,
});

const List<_Destination> _destinations = [
  (
    label: 'Saved looks',
    route: AppConstants.savedRoute,
    screen: 'saved screen',
    pushed: false,
  ),
  (
    label: 'History',
    route: AppConstants.historyRoute,
    screen: 'history screen',
    pushed: false,
  ),
  (
    label: 'My Makeup Kit',
    route: AppConstants.makeupKitRoute,
    screen: 'kit screen',
    pushed: true,
  ),
  (
    label: 'Plans & Subscription',
    route: AppConstants.subscriptionRoute,
    screen: 'plans screen',
    pushed: true,
  ),
  (
    label: 'Settings & Privacy',
    route: AppConstants.settingsRoute,
    screen: 'settings screen',
    pushed: true,
  ),
];

final _plus = SubscriptionSummary(
  hasEntitlement: true,
  planCode: SubscriptionPlanCode.plus,
  planDisplayName: 'FaceTune Plus',
  usage: const SubscriptionUsageSummary(
    effectiveAllowance: 3,
    committedUsage: 1,
  ),
  generationAuthorized: true,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: EntitlementStatus.active,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
  resetAt: DateTime.utc(2026, 10, 7),
);

final _unprovisioned = SubscriptionSummary(
  hasEntitlement: false,
  planCode: SubscriptionPlanCode.free,
  planDisplayName: 'Free',
  usage: const SubscriptionUsageSummary(
    effectiveAllowance: 0,
    committedUsage: 0,
  ),
  generationAuthorized: false,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: EntitlementStatus.active,
  billingProvider: BillingProvider.googlePlay,
  resetPolicy: ResetPolicy.billingPeriod,
);

class _CountingProfileRepository extends FakeProfileRepository {
  _CountingProfileRepository()
    : super(
        profile: UserProfile(
          id: 'profile-registered-user',
          authUserId: 'registered-user',
          displayName: 'Mia Chen',
          createdAt: DateTime.utc(2026, 8, 11),
          updatedAt: DateTime.utc(2026, 8, 11),
        ),
      );

  int loads = 0;
  int nameUpdates = 0;

  @override
  Future<UserProfile> load() {
    loads++;
    return super.load();
  }

  @override
  Future<UserProfile> updateDisplayName(String displayName) {
    nameUpdates++;
    return super.updateDisplayName(displayName);
  }
}

class _CountingSubscriptionRepository implements SubscriptionRepository {
  _CountingSubscriptionRepository(this.summary);

  final SubscriptionSummary summary;
  int resolves = 0;

  @override
  Future<SubscriptionSummary> resolve() async {
    resolves++;
    return summary;
  }
}

typedef _Harness = ({
  GoRouter router,
  _CountingProfileRepository profiles,
  _CountingSubscriptionRepository subscriptions,
});

Future<_Harness> _pump(
  WidgetTester tester, {
  SubscriptionSummary? summary,
}) async {
  // Tall enough that every section is built at once, so order and presence
  // are asserted on the whole page rather than on what a phone shows first.
  tester.view
    ..physicalSize = const Size(1080, 7200)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository(
    user: const AuthUser(
      id: 'registered-user',
      email: 'mia@example.com',
      displayName: 'Mia Chen',
      isAnonymous: false,
    ),
  );
  addTearDown(auth.dispose);
  final profiles = _CountingProfileRepository();
  final subscriptions = _CountingSubscriptionRepository(
    summary ?? _unprovisioned,
  );
  Widget screen(String text) => Scaffold(body: Text(text));
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ProfilePage()),
      GoRoute(
        path: AppConstants.savedRoute,
        builder: (context, state) => screen('saved screen'),
      ),
      GoRoute(
        path: AppConstants.historyRoute,
        builder: (context, state) => screen('history screen'),
      ),
      GoRoute(
        path: AppConstants.makeupKitRoute,
        builder: (context, state) => screen('kit screen'),
      ),
      GoRoute(
        path: AppConstants.subscriptionRoute,
        builder: (context, state) => screen('plans screen'),
      ),
      GoRoute(
        path: AppConstants.settingsRoute,
        builder: (context, state) => screen('settings screen'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        subscriptionRepositoryProvider.overrideWithValue(subscriptions),
        avatarPickerProvider.overrideWithValue(const FakeAvatarPicker()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (router: router, profiles: profiles, subscriptions: subscriptions);
}
