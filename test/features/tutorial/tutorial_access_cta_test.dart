import 'package:facetune/features/recommendation/domain/entities/makeup_recommendation.dart';
import 'package:facetune/features/subscription/domain/entities/allowance_unit.dart';
import 'package:facetune/features/subscription/domain/entities/billing_provider.dart';
import 'package:facetune/features/subscription/domain/entities/entitlement_status.dart';
import 'package:facetune/features/subscription/domain/entities/reset_policy.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_summary.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_usage_summary.dart';
import 'package:facetune/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:facetune/features/subscription/domain/usecases/resolve_subscription_summary.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_controller.dart';
import 'package:facetune/features/subscription/presentation/controllers/subscription_state.dart';
import 'package:facetune/features/tutorial/domain/catalog/look_plan_convergence.dart';
import 'package:facetune/features/tutorial/domain/entities/canonical_preview_ref.dart';
import 'package:facetune/features/tutorial/domain/entities/tutorial_session.dart';
import 'package:facetune/features/tutorial/presentation/widgets/tutorial_access_cta.dart';
import 'package:facetune/shared/widgets/app_ui.dart';
import 'package:facetune/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The result screen's Tutorial action reflects the server-resolved plan.
///
/// Three states, decided by facts the server sent: a Tutorial-capable plan
/// (or none known yet) shows the action; a Preview-only plan shows the action
/// only for a look that already has a tutorial; otherwise it shows the
/// not-included notice. The widget reflects capability — it never enforces
/// it, and these tests never grant anything.
void main() {
  const preview = CanonicalPreviewRef.standard('preview-1');
  final now = DateTime.utc(2026, 9, 20);

  SubscriptionSummary summaryOn(
    SubscriptionPlanCode plan, {
    required bool tutorialEnabled,
    AllowanceUnit unit = AllowanceUnit.aiLook,
  }) => SubscriptionSummary(
    hasEntitlement: true,
    planCode: plan,
    planDisplayName: plan == SubscriptionPlanCode.plusPreview
        ? 'FaceTune Plus Preview'
        : 'FaceTune Plus',
    usage: const SubscriptionUsageSummary(
      effectiveAllowance: 30,
      committedUsage: 1,
    ),
    generationAuthorized: true,
    resolvedAt: now,
    entitlementId: 'ent-1',
    status: EntitlementStatus.active,
    billingProvider: BillingProvider.googlePlay,
    resetPolicy: ResetPolicy.billingPeriod,
    allowanceUnit: unit,
    tutorialEnabled: tutorialEnabled,
  );

  TutorialSession session() => TutorialSession(
    id: 'session-1',
    userId: 'user-1',
    analysisId: 'analysis-1',
    canonicalPreviewId: preview.id,
    lookPlan: LookPlanConvergence.fromStandard(
      MakeupRecommendation(
        id: 'rec-1',
        analysisId: 'analysis-1',
        styleCode: 'natural',
        overallIntensity: 'soft',
        items: const <String, MakeupRecommendationItem>{},
        modelId: 'm',
        promptVersion: 'v1',
        createdAt: now,
      ),
    ),
    status: TutorialSessionStatus.ready,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pump(
    WidgetTester tester, {
    required SubscriptionSummary? summary,
    Future<TutorialSession?> Function()? existing,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionControllerProvider.overrideWith(
            (ref) => _FixedSubscription(
              SubscriptionState(
                status: summary == null
                    ? SubscriptionStatus.loading
                    : SubscriptionStatus.ready,
                summary: summary,
              ),
            ),
          ),
          existingTutorialSessionProvider.overrideWith(
            (ref, ref2) => existing == null
                ? throw StateError('the session lookup must not run')
                : existing(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: const SizedBox.expand(),
            bottomNavigationBar: TutorialAccessCta(preview: preview),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('a Tutorial-capable plan shows the action, no lookup', (
    tester,
  ) async {
    await pump(
      tester,
      summary: summaryOn(SubscriptionPlanCode.plus, tutorialEnabled: true),
    );
    expect(find.byKey(const ValueKey('result-show-tutorial')), findsOneWidget);
    expect(find.text('Show me how'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-tutorial-not-included')),
      findsNothing,
    );
  });

  testWidgets('no plan known yet shows the action and lets the server decide', (
    tester,
  ) async {
    await pump(tester, summary: null);
    expect(find.byKey(const ValueKey('result-show-tutorial')), findsOneWidget);
  });

  testWidgets(
    'a Preview-only plan with no tutorial for the look shows the notice',
    (tester) async {
      await pump(
        tester,
        summary: summaryOn(
          SubscriptionPlanCode.plusPreview,
          tutorialEnabled: false,
          unit: AllowanceUnit.finalPreviewCredit,
        ),
        existing: () async => null,
      );
      expect(
        find.byKey(const ValueKey('result-tutorial-not-included')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-show-tutorial')), findsNothing);
      expect(
        find.textContaining('not part of FaceTune Plus Preview'),
        findsOneWidget,
      );
      // Nothing implies the Tutorial is available on this plan.
      expect(find.text('Show me how'), findsNothing);
      expect(tester.widget(find.byType(AppNotice)), isA<AppNotice>());
      expect(
        find.byKey(const ValueKey('result-tutorial-see-plans')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'a Preview-only plan still reopens a tutorial the look already has',
    (tester) async {
      await pump(
        tester,
        summary: summaryOn(
          SubscriptionPlanCode.plusPreview,
          tutorialEnabled: false,
          unit: AllowanceUnit.finalPreviewCredit,
        ),
        existing: () async => session(),
      );
      // Historical content: made while the Tutorial was included, readable
      // on every plan.
      expect(
        find.byKey(const ValueKey('result-show-tutorial')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('result-tutorial-not-included')),
        findsNothing,
      );
    },
  );

  testWidgets('a failed lookup falls back to the action; the server decides', (
    tester,
  ) async {
    await pump(
      tester,
      summary: summaryOn(
        SubscriptionPlanCode.plusPreview,
        tutorialEnabled: false,
        unit: AllowanceUnit.finalPreviewCredit,
      ),
      existing: () async => throw Exception('offline'),
    );
    expect(find.byKey(const ValueKey('result-show-tutorial')), findsOneWidget);
  });
}

class _FixedSubscription extends SubscriptionController {
  _FixedSubscription(SubscriptionState fixed)
    : super(const ResolveSubscriptionSummary(_NeverResolves())) {
    state = fixed;
  }
}

class _NeverResolves implements SubscriptionRepository {
  const _NeverResolves();
  @override
  Future<SubscriptionSummary> resolve() => throw UnimplementedError();
}
