import 'package:facetune/core/supabase/supabase_availability_provider.dart';
import 'package:facetune/features/authentication/data/providers/auth_repository_provider.dart';
import 'package:facetune/features/authentication/domain/entities/auth_user.dart';
import 'package:facetune/features/subscription/data/providers/subscription_providers.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:facetune/features/subscription/presentation/widgets/subscription_resume_refresher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_auth_repository.dart';

/// SUB-11's client half of lifecycle reconciliation.
///
/// A subscription renews, lapses, or is refunded while the app is backgrounded
/// and the server reconciles it from a verified provider read. Nothing pushes
/// that to a running app, so returning to the foreground re-asks. These tests
/// hold the two properties that matter: it does ask, and it never decides.
class CountingRepository implements SubscriptionRepository {
  int resolves = 0;

  @override
  Future<SubscriptionSummary> resolve() async {
    resolves++;
    return SubscriptionSummary(
      hasEntitlement: true,
      planCode: SubscriptionPlanCode.plus,
      planDisplayName: 'FaceTune Plus',
      usage: const SubscriptionUsageSummary(
        effectiveAllowance: 3,
        committedUsage: 0,
        reservedUsage: 0,
      ),
      generationAuthorized: true,
      resolvedAt: DateTime.utc(2026, 9, 17, 11),
      status: EntitlementStatus.active,
      billingProvider: BillingProvider.googlePlay,
      resetPolicy: ResetPolicy.billingPeriod,
    );
  }
}

Future<CountingRepository> pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
}) async {
  final auth = FakeAuthRepository(
    user: signedIn
        ? const AuthUser(
            id: 'account-uuid',
            email: 'mia@example.com',
            displayName: 'Mia Chen',
            isAnonymous: false,
          )
        : null,
  );
  addTearDown(auth.dispose);

  final repository = CountingRepository();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseAvailableProvider.overrideWithValue(true),
        authRepositoryProvider.overrideWithValue(auth),
        subscriptionRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        home: SubscriptionResumeRefresher(
          // A surface that displays subscription state, as every real screen
          // reaching this controller does. Without one the provider is never
          // instantiated and there is no "stale" state to refresh.
          child: Consumer(
            builder: (context, ref, _) {
              ref.watch(subscriptionControllerProvider);
              return const Text('home');
            },
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Drives a real background-then-foreground transition.
Future<void> backgroundThenResume(WidgetTester tester) async {
  // The full transition the framework requires, in both directions:
  // resumed → inactive → hidden → paused, then back out again. Skipping
  // `hidden` is rejected by AppLifecycleListener as an invalid transition.
  for (final state in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pump();
  for (final state in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('returning to the foreground re-reads authoritative state', (
    tester,
  ) async {
    final repository = await pumpApp(tester);
    final afterFirstLoad = repository.resolves;
    expect(afterFirstLoad, 1, reason: 'the controller loads once on creation');

    await backgroundThenResume(tester);

    expect(
      repository.resolves,
      afterFirstLoad + 1,
      reason: 'a subscription can change while the app is backgrounded',
    );
  });

  testWidgets('a signed-out app asks nothing on resume', (tester) async {
    final repository = await pumpApp(tester, signedIn: false);
    final before = repository.resolves;

    await backgroundThenResume(tester);

    expect(repository.resolves, before);
  });

  testWidgets('merely rebuilding generates no backend traffic', (tester) async {
    // The refresh is tied to a real lifecycle event, not to build(). A widget
    // that re-rendered its way into repeated server reads would be a load
    // amplifier on every account.
    final repository = await pumpApp(tester);
    final before = repository.resolves;

    await tester.pump();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(repository.resolves, before);
  });

  testWidgets('the refresher renders its child and nothing of its own', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('home'), findsOneWidget);
  });
}
