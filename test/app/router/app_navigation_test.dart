import 'package:facetune/app/router/app_navigation_transitions.dart';
import 'package:facetune/app/router/app_router.dart';
import 'package:facetune/core/constants/app_constants.dart';
import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/shared/widgets/app_shell.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/fake_auth_repository.dart';

void main() {
  group('production router contract', () {
    test('the four peers are independent persistent branches', () {
      final auth = FakeAuthRepository(
        user: const AuthUser(id: 'navigation-user', isAnonymous: false),
      );
      final container = ProviderContainer(
        overrides: [
          supabaseAvailableProvider.overrideWithValue(true),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(() async {
        container.read(appRouterProvider).dispose();
        container.dispose();
        await auth.dispose();
      });

      final router = container.read(appRouterProvider);
      final shell = router.configuration.routes
          .whereType<StatefulShellRoute>()
          .single;

      expect(shell.branches, hasLength(4));
      expect(
        [
          for (final branch in shell.branches)
            (branch.routes.single as GoRoute).path,
        ],
        [
          AppConstants.homeRoute,
          AppConstants.savedRoute,
          AppConstants.historyRoute,
          AppConstants.profileRoute,
        ],
      );
      for (final branch in shell.branches) {
        final root = branch.routes.single as GoRoute;
        expect(root.pageBuilder, isNotNull);
      }
      expect(
        shell.navigatorContainerBuilder,
        same(buildTopLevelBranchContainer),
      );
    });

    test(
      'only the hierarchical journey routes use the journey page family',
      () {
        final auth = FakeAuthRepository(
          user: const AuthUser(id: 'navigation-user', isAnonymous: false),
        );
        final container = ProviderContainer(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(auth),
          ],
        );
        addTearDown(() async {
          container.read(appRouterProvider).dispose();
          container.dispose();
          await auth.dispose();
        });

        final routes = container
            .read(appRouterProvider)
            .configuration
            .routes
            .whereType<GoRoute>()
            .toList();
        const journeyPaths = {
          AppConstants.analysisRoute,
          AppConstants.stylesRoute,
          AppConstants.recommendationModeRoute,
          AppConstants.recommendationRoute,
          AppConstants.makeupKitRecommendationEntryRoute,
          AppConstants.previewRoute,
          AppConstants.tutorialRoute,
        };

        for (final route in routes) {
          if (journeyPaths.contains(route.path)) {
            expect(route.pageBuilder, isNotNull, reason: route.path);
          } else {
            expect(route.builder, isNotNull, reason: route.path);
          }
        }
      },
    );
  });

  group('top-level peer navigation', () {
    testWidgets('crossfades branches without route-slide widgets', (
      tester,
    ) async {
      final initializations = <String, int>{};
      final router = _topLevelRouter(initializations);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      final navigationBar = tester.element(find.byType(NavigationBar));
      _selectBranch(tester, 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));

      final homeOpacity = tester
          .renderObject<RenderAnimatedOpacity>(
            find.byKey(const ValueKey('top-level-branch-0')),
          )
          .opacity
          .value;
      final savedOpacity = tester
          .renderObject<RenderAnimatedOpacity>(
            find.byKey(const ValueKey('top-level-branch-1')),
          )
          .opacity
          .value;
      expect(homeOpacity, inExclusiveRange(0, 1));
      expect(savedOpacity, inExclusiveRange(0, 1));

      final branchContainer = find.byType(TopLevelBranchContainer);
      expect(
        find.descendant(
          of: branchContainer,
          matching: find.byType(SlideTransition),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: branchContainer,
          matching: find.byType(JourneyPageTransition),
        ),
        findsNothing,
      );
      for (final opacity in tester.widgetList<AnimatedOpacity>(
        find.descendant(
          of: branchContainer,
          matching: find.byType(AnimatedOpacity),
        ),
      )) {
        expect(opacity.duration, AppNavigationMotion.topLevelDuration);
      }

      await tester.pumpAndSettle();
      expect(tester.element(find.byType(NavigationBar)), same(navigationBar));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(router.canPop(), isFalse);
    });

    testWidgets('preserves every visited page and both scroll positions', (
      tester,
    ) async {
      final initializations = <String, int>{};
      final router = _topLevelRouter(initializations);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      final home = tester.state<_BranchPageState>(
        find.byKey(const ValueKey('Home-page')),
      );
      await tester.tap(find.byKey(const ValueKey('Home-increment')));
      await tester.pump();

      _selectBranch(tester, 1);
      await tester.pumpAndSettle();
      final saved = tester.state<_BranchPageState>(
        find.byKey(const ValueKey('Saved-page')),
      );
      await tester.drag(
        find.byKey(const ValueKey('Saved-list')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      final savedOffset = saved.scrollController.offset;
      expect(savedOffset, greaterThan(0));

      _selectBranch(tester, 2);
      await tester.pumpAndSettle();
      final history = tester.state<_BranchPageState>(
        find.byKey(const ValueKey('History-page')),
      );
      await tester.drag(
        find.byKey(const ValueKey('History-list')),
        const Offset(0, -650),
      );
      await tester.pumpAndSettle();
      final historyOffset = history.scrollController.offset;
      expect(historyOffset, greaterThan(0));

      _selectBranch(tester, 3);
      await tester.pumpAndSettle();
      final profile = tester.state<_BranchPageState>(
        find.byKey(const ValueKey('Profile-page')),
      );
      await tester.tap(find.byKey(const ValueKey('Profile-increment')));
      await tester.pump();

      _selectBranch(tester, 1);
      await tester.pumpAndSettle();
      expect(
        tester.state<_BranchPageState>(
          find.byKey(const ValueKey('Saved-page')),
        ),
        same(saved),
      );
      expect(saved.scrollController.offset, savedOffset);

      _selectBranch(tester, 2);
      await tester.pumpAndSettle();
      expect(
        tester.state<_BranchPageState>(
          find.byKey(const ValueKey('History-page')),
        ),
        same(history),
      );
      expect(history.scrollController.offset, historyOffset);

      _selectBranch(tester, 0);
      await tester.pumpAndSettle();
      expect(
        tester.state<_BranchPageState>(find.byKey(const ValueKey('Home-page'))),
        same(home),
      );
      expect(find.text('Home local value: 1'), findsOneWidget);

      _selectBranch(tester, 3);
      await tester.pumpAndSettle();
      expect(
        tester.state<_BranchPageState>(
          find.byKey(const ValueKey('Profile-page')),
        ),
        same(profile),
      );
      expect(find.text('Profile local value: 1'), findsOneWidget);
      expect(initializations, {
        'Home': 1,
        'Saved': 1,
        'History': 1,
        'Profile': 1,
      });
      expect(router.canPop(), isFalse);
    });

    testWidgets('reduced motion makes a peer switch immediate', (tester) async {
      final router = _topLevelRouter(<String, int>{});
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      _selectBranch(tester, 1);
      await tester.pump();
      final saved = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('top-level-branch-1')),
      );
      expect(saved.duration, Duration.zero);
      expect(
        tester
            .renderObject<RenderAnimatedOpacity>(
              find.byKey(const ValueKey('top-level-branch-1')),
            )
            .opacity
            .value,
        1,
      );
    });
  });

  group('journey navigation', () {
    testWidgets('push and pop use the same 230ms restrained inverse motion', (
      tester,
    ) async {
      final router = _journeyRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('journey-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final incoming = _journeyTransitionFor(const ValueKey('journey-second'));
      expect(_translationX(tester, incoming), inExclusiveRange(0, 10));
      expect(_opacity(tester, incoming), inExclusiveRange(0, 1));
      expect(find.byType(SlideTransition), findsNothing);
      expect(router.canPop(), isTrue);

      await tester.pumpAndSettle();
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final returning = _journeyTransitionFor(const ValueKey('journey-first'));
      final outgoing = _journeyTransitionFor(const ValueKey('journey-second'));
      expect(_translationX(tester, returning), inExclusiveRange(-10, 0));
      expect(_translationX(tester, outgoing), inExclusiveRange(0, 10));
      expect(_opacity(tester, returning), inExclusiveRange(0, 1));
      expect(_opacity(tester, outgoing), inExclusiveRange(0, 1));

      await tester.pumpAndSettle();
      expect(router.canPop(), isFalse);
      expect(
        AppNavigationMotion.journeyDuration,
        const Duration(milliseconds: 230),
      );
      expect(AppNavigationMotion.journeyOffset, 10);
    });

    testWidgets('reduced motion removes journey animation and movement', (
      tester,
    ) async {
      final router = _journeyRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('journey-next')));
      await tester.pump();
      expect(find.byKey(const ValueKey('journey-second')), findsOneWidget);
      expect(find.byType(JourneyPageTransition), findsNothing);
    });
  });
}

void _selectBranch(WidgetTester tester, int index) {
  tester
      .widget<NavigationBar>(find.byType(NavigationBar))
      .onDestinationSelected!(index);
}

GoRouter _topLevelRouter(Map<String, int> initializations) => GoRouter(
  routes: [
    StatefulShellRoute(
      navigatorContainerBuilder: buildTopLevelBranchContainer,
      builder: (context, state, navigationShell) => AppShell(
        index: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(index),
        child: navigationShell,
      ),
      branches: [
        for (final (index, label) in [
          'Home',
          'Saved',
          'History',
          'Profile',
        ].indexed)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: index == 0 ? '/' : '/${label.toLowerCase()}',
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: _BranchPage(
                    key: ValueKey('$label-page'),
                    label: label,
                    initializations: initializations,
                  ),
                ),
              ),
            ],
          ),
      ],
    ),
  ],
);

class _BranchPage extends StatefulWidget {
  const _BranchPage({
    required this.label,
    required this.initializations,
    super.key,
  });

  final String label;
  final Map<String, int> initializations;

  @override
  State<_BranchPage> createState() => _BranchPageState();
}

class _BranchPageState extends State<_BranchPage> {
  final scrollController = ScrollController();
  var localValue = 0;

  @override
  void initState() {
    super.initState();
    widget.initializations.update(
      widget.label,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    child: SafeArea(
      child: Column(
        children: [
          Text('${widget.label} local value: $localValue'),
          TextButton(
            key: ValueKey('${widget.label}-increment'),
            onPressed: () => setState(() => localValue++),
            child: const Text('Increment'),
          ),
          Expanded(
            child: ListView.builder(
              key: ValueKey('${widget.label}-list'),
              controller: scrollController,
              itemExtent: 56,
              itemCount: 40,
              itemBuilder: (context, index) =>
                  Text('${widget.label} row $index'),
            ),
          ),
        ],
      ),
    ),
  );
}

GoRouter _journeyRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => buildJourneyPage(
        context,
        state,
        _JourneyPage(
          markerKey: const ValueKey('journey-first'),
          label: 'First journey page',
          action: TextButton(
            key: const ValueKey('journey-next'),
            onPressed: () => context.push('/second'),
            child: const Text('Next'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/second',
      pageBuilder: (context, state) => buildJourneyPage(
        context,
        state,
        const _JourneyPage(
          markerKey: ValueKey('journey-second'),
          label: 'Second journey page',
        ),
      ),
    ),
  ],
);

class _JourneyPage extends StatelessWidget {
  const _JourneyPage({
    required this.markerKey,
    required this.label,
    this.action,
  });

  final Key markerKey;
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, key: markerKey),
          ?action,
        ],
      ),
    ),
  );
}

Finder _journeyTransitionFor(Key markerKey) => find.ancestor(
  of: find.byKey(markerKey),
  matching: find.byType(JourneyPageTransition),
);

double _translationX(WidgetTester tester, Finder transition) => tester
    .widget<Transform>(
      find.descendant(of: transition, matching: find.byType(Transform)).first,
    )
    .transform
    .storage[12];

double _opacity(WidgetTester tester, Finder transition) => tester
    .widget<Opacity>(
      find.descendant(of: transition, matching: find.byType(Opacity)).first,
    )
    .opacity;
