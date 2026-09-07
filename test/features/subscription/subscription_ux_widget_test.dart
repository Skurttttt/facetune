import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/errors/subscription_state_failure.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/presentation/widgets/ai_look_allowance_notice.dart';
import 'package:facetune/features/subscription/presentation/widgets/subscription_summary_card.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

SubscriptionSummary summaryFor({
  required SubscriptionPlanCode plan,
  required String displayName,
  required int allowance,
  int committed = 0,
  EntitlementStatus status = EntitlementStatus.active,
  ResetPolicy resetPolicy = ResetPolicy.billingPeriod,
  BillingProvider provider = BillingProvider.googlePlay,
  DateTime? resetAt,
  DateTime? expiresAt,
  bool hasEntitlement = true,
}) => SubscriptionSummary(
  hasEntitlement: hasEntitlement,
  planCode: plan,
  planDisplayName: displayName,
  usage: SubscriptionUsageSummary(
    effectiveAllowance: allowance,
    committedUsage: committed,
  ),
  generationAuthorized: allowance - committed > 0,
  resolvedAt: DateTime.utc(2026, 9, 7, 12),
  status: status,
  billingProvider: provider,
  resetPolicy: resetPolicy,
  resetAt: resetAt,
  expiresAt: expiresAt,
);

class _StubRepository implements SubscriptionRepository {
  _StubRepository(this._result);

  final Object _result;

  @override
  Future<SubscriptionSummary> resolve() async {
    if (_result is SubscriptionSummary) return _result;
    throw _result;
  }
}

/// A signed-in session, which is what causes the controller to load at all.
FakeAuthRepository _signedIn(WidgetTester tester) {
  final repository = FakeAuthRepository(
    user: const AuthUser(
      id: 'registered-user',
      email: 'mia@example.com',
      displayName: 'Mia Chen',
      isAnonymous: false,
    ),
  );
  addTearDown(repository.dispose);
  return repository;
}

/// Pumps [child] with a signed-in session and a repository answering [result].
Future<void> pumpWith(
  WidgetTester tester,
  Object result,
  Widget child, {
  bool settle = true,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(_signedIn(tester)),
        subscriptionRepositoryProvider.overrideWithValue(
          _StubRepository(result),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  group('SubscriptionSummaryCard', () {
    testWidgets('shows plan, remaining, and the verified reset date', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          committed: 1,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
        const SubscriptionSummaryCard(),
      );

      expect(find.text('FaceTune Plus'), findsOneWidget);
      expect(find.text('2 of 3 AI Looks remaining'), findsOneWidget);
      expect(find.text('Resets Oct 7'), findsOneWidget);
    });

    testWidgets('Salon Pilot reads as research access that expires', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.salonPilot,
          displayName: 'Salon Pilot',
          allowance: 30,
          committed: 11,
          resetPolicy: ResetPolicy.none,
          provider: BillingProvider.adminGranted,
          expiresAt: DateTime.utc(2026, 11, 7),
        ),
        const SubscriptionSummaryCard(),
      );

      expect(find.text('Salon Pilot'), findsOneWidget);
      expect(find.text('Research Access'), findsOneWidget);
      expect(find.text('19 of 30 AI Looks remaining'), findsOneWidget);
      expect(find.text('Expires Nov 7'), findsOneWidget);
    });

    testWidgets('exhausted Salon Pilot shows no upgrade prompt', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.salonPilot,
          displayName: 'Salon Pilot',
          allowance: 30,
          committed: 30,
          resetPolicy: ResetPolicy.none,
          provider: BillingProvider.adminGranted,
          expiresAt: DateTime.utc(2026, 11, 7),
        ),
        const SubscriptionSummaryCard(),
      );

      expect(find.text('Salon Pilot allowance used'), findsOneWidget);
      expect(find.textContaining('Upgrade'), findsNothing);
    });

    testWidgets('exhausted Free offers the upgrade', (tester) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.free,
          displayName: 'FaceTune Free',
          allowance: 1,
          committed: 1,
          resetPolicy: ResetPolicy.none,
          provider: BillingProvider.none,
        ),
        const SubscriptionSummaryCard(),
      );

      expect(
        find.text('0 of 1 complimentary AI Look remaining'),
        findsOneWidget,
      );
      expect(find.textContaining('Upgrade to create more'), findsOneWidget);
    });

    testWidgets('renders nothing at all while loading', (tester) async {
      // A repository that never answers keeps the controller in `loading`.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              _StubRepository(_NeverCompletes()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: SubscriptionSummaryCard()),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('AI Look'), findsNothing);
      expect(
        find.byKey(const ValueKey('subscription-summary-card')),
        findsNothing,
      );
    });

    testWidgets('an unprovisioned account shows no invented quota', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.free,
          displayName: 'FaceTune Free',
          allowance: 0,
          hasEntitlement: false,
          resetPolicy: ResetPolicy.none,
          provider: BillingProvider.none,
        ),
        const SubscriptionSummaryCard(),
      );

      expect(find.textContaining('remaining'), findsNothing);
    });

    testWidgets('a retryable failure offers a retry, not a fake plan', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const SubscriptionStateFailure(
          'You appear to be offline. Reconnect and try again.',
          kind: SubscriptionStateFailureKind.offline,
        ),
        const SubscriptionSummaryCard(),
      );

      expect(find.textContaining('remaining'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('layout safety', () {
    // The accepted QA matrix renders Profile with the subscription repository
    // stubbed out, so it keeps testing the layout it was written for. These
    // cover the card's own layout at the sizes that matrix cares about.
    for (final size in const [
      (label: 'small phone', width: 320.0, height: 640.0),
      (label: 'POCO X3 GT', width: 393.0, height: 873.0),
    ]) {
      testWidgets('${size.label} shows the card without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = Size(size.width, size.height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await pumpWith(
          tester,
          summaryFor(
            plan: SubscriptionPlanCode.salonPilot,
            displayName: 'Salon Pilot',
            allowance: 30,
            committed: 30,
            resetPolicy: ResetPolicy.none,
            provider: BillingProvider.adminGranted,
            expiresAt: DateTime.utc(2026, 11, 7),
          ),
          const SubscriptionSummaryCard(),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('subscription-summary-card')),
          findsOneWidget,
        );
      });
    }

    testWidgets('survives doubled text scale', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseAvailableProvider.overrideWithValue(true),
            authRepositoryProvider.overrideWithValue(_signedIn(tester)),
            subscriptionRepositoryProvider.overrideWithValue(
              _StubRepository(
                summaryFor(
                  plan: SubscriptionPlanCode.plus,
                  displayName: 'FaceTune Plus',
                  allowance: 3,
                  committed: 2,
                  resetAt: DateTime.utc(2026, 10, 7),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: const Scaffold(
                body: SingleChildScrollView(child: SubscriptionSummaryCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('AiLookAllowanceNotice', () {
    testWidgets('shows the month-scoped count for a recurring plan', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          committed: 1,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
        const AiLookAllowanceNotice(),
      );

      expect(find.text('2 AI Looks remaining this month'), findsOneWidget);
    });

    testWidgets('emphasises the last remaining look', (tester) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.plus,
          displayName: 'FaceTune Plus',
          allowance: 3,
          committed: 2,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
        const AiLookAllowanceNotice(),
      );

      expect(find.text('1 AI Look remaining this month'), findsOneWidget);
    });

    testWidgets('shows nothing before the server has answered', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subscriptionRepositoryProvider.overrideWithValue(
              _StubRepository(_NeverCompletes()),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(body: AiLookAllowanceNotice()),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('ai-look-allowance-notice')),
        findsNothing,
      );
    });

    testWidgets('an exhausted plan states the verified reset date', (
      tester,
    ) async {
      await pumpWith(
        tester,
        summaryFor(
          plan: SubscriptionPlanCode.pro,
          displayName: 'FaceTune Pro',
          allowance: 8,
          committed: 8,
          resetAt: DateTime.utc(2026, 10, 7),
        ),
        const AiLookAllowanceNotice(),
      );

      expect(find.text('You have used all your AI Looks'), findsOneWidget);
      expect(find.text('Your allowance resets on Oct 7.'), findsOneWidget);
    });
  });
}

/// A sentinel that is neither a summary nor a throwable outcome the stub will
/// ever reach — used to keep the controller pinned in `loading`.
class _NeverCompletes implements Exception {
  @override
  String toString() => 'never completes';
}
