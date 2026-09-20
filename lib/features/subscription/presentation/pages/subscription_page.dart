import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../controllers/paywall_controller.dart';
import '../controllers/paywall_state.dart';
import '../controllers/purchase_controller.dart';
import '../controllers/purchase_state.dart';
import '../controllers/subscription_controller.dart';
import '../utils/plan_presentation.dart';
import '../widgets/subscription_plan_card.dart';

/// The public plan comparison.
///
/// Shows Free, Plus, Pro, and Salon Pro. Salon Pilot is absent by construction:
/// the list comes from the plans the catalog marks publicly purchasable, and
/// Salon Pilot is admin-granted research access with no store product behind
/// it, so it cannot be added here by editing presentation code.
///
/// This screen cannot grant anything. Tapping a plan opens Google Play's
/// purchase sheet and nothing more: what the account is entitled to is decided
/// by the server after it verifies the purchase, and this page only ever reads
/// that answer back. A plan's action stays disabled unless the store is usable
/// *and* Google Play returned a product for it, so the screen never offers a
/// button that silently fails.
///
/// There is deliberately no countdown, no "limited time", no struck-through
/// price, and no annual saving — none of those are real, and inventing them
/// would be a lie told to sell a subscription.
class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  /// Heads the purchase notice.
  ///
  /// Every title describes a *step*, never a grant: even [PurchasePhase
  /// .verified] says the purchase is confirmed, not that a plan is now active
  /// — what the account has is shown by the subscription surface, which reads
  /// it from the server.
  static String _purchaseNoticeTitle(PurchasePhase phase) => switch (phase) {
    PurchasePhase.awaitingPayment => 'Waiting for Google Play',
    PurchasePhase.restoring => 'Checking your purchases',
    PurchasePhase.restoredNothing => 'Nothing to restore',
    PurchasePhase.verifying => 'Confirming your purchase',
    PurchasePhase.verified => 'Purchase confirmed',
    PurchasePhase.failed => 'Purchase not completed',
    PurchasePhase.idle ||
    PurchasePhase.unavailable ||
    PurchasePhase.starting ||
    PurchasePhase.cancelled => 'Purchase',
  };

  /// Heads the restore notice, shown beside the Restore control.
  ///
  /// The same rule as [_purchaseNoticeTitle]: each title names the step that
  /// just finished. "Purchase confirmed" after a restore means the server
  /// verified what Google Play returned, not that anything was granted here.
  static String _restoreNoticeTitle(PurchasePhase phase) => switch (phase) {
    PurchasePhase.restoring => 'Checking your purchases',
    PurchasePhase.restoredNothing => 'Nothing to restore',
    PurchasePhase.verifying => 'Confirming your purchase',
    PurchasePhase.verified => 'Purchase confirmed',
    PurchasePhase.failed => 'Restore not completed',
    PurchasePhase.idle ||
    PurchasePhase.unavailable ||
    PurchasePhase.starting ||
    PurchasePhase.awaitingPayment ||
    PurchasePhase.cancelled => 'Restore purchases',
  };

  /// The plans shown under the page lead, in catalog order.
  static List<SubscriptionPlanCode> get _consumerPlans => PlanPresentation
      .comparisonPlans
      .where(
        (plan) => PlanPresentation.emphasis(plan) != PlanEmphasis.professional,
      )
      .toList(growable: false);

  /// The plans shown under the professional heading, in catalog order.
  static List<SubscriptionPlanCode> get _professionalPlans => PlanPresentation
      .comparisonPlans
      .where(
        (plan) => PlanPresentation.emphasis(plan) == PlanEmphasis.professional,
      )
      .toList(growable: false);

  /// What the in-flight plan's button says during each busy phase.
  ///
  /// Mirrors the phase the controller already reports — nothing here is a
  /// state of its own. Null for every phase that is not busy, which is what
  /// keeps every other card's button in its normal wording.
  static String? _inFlightLabel(PurchasePhase phase) => switch (phase) {
    PurchasePhase.starting => 'Opening Google Play…',
    PurchasePhase.awaitingPayment => 'Waiting for Google Play…',
    PurchasePhase.verifying => 'Confirming your purchase…',
    // A restore belongs to the account, not to any one plan card, so no card
    // claims its progress. The notice above the list carries it.
    PurchasePhase.restoring ||
    PurchasePhase.restoredNothing ||
    PurchasePhase.idle ||
    PurchasePhase.unavailable ||
    PurchasePhase.verified ||
    PurchasePhase.cancelled ||
    PurchasePhase.failed => null,
  };

  /// One plan card, wired exactly as before the page was sectioned.
  static Widget _planCard(
    WidgetRef ref,
    SubscriptionPlanCode plan,
    SubscriptionPlanCode? currentPlan,
    PaywallState paywall,
    PurchaseState purchase,
    bool purchaseAvailable,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: SubscriptionPlanCard(
      plan: plan,
      isCurrentPlan: currentPlan == plan,
      price: paywall.priceFor(plan),
      // A plan is buyable only when the store is usable *and* it returned a
      // product for this plan. Without that second condition a plan Google
      // Play has no product for would present an enabled button that could
      // only fail.
      purchaseAvailable: purchaseAvailable && paywall.priceFor(plan) != null,
      onSelect: () => ref.read(purchaseControllerProvider.notifier).buy(plan),
      // Only the plan the open purchase is for shows progress. Every busy
      // phase carries the plan it relates to, so the match is exact.
      inFlightLabel: purchase.isBusy && purchase.plan == plan
          ? _inFlightLabel(purchase.phase)
          : null,
    ),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paywall = ref.watch(paywallControllerProvider);
    final subscription = ref.watch(subscriptionControllerProvider);
    final purchaseAvailable = ref.watch(purchaseAvailableProvider);
    final purchase = ref.watch(purchaseControllerProvider);
    // The plan the account still holds, per the server's effective state. An
    // entitlement whose verified period has ended is not a current plan: its
    // card must offer the purchase again rather than a disabled "current".
    final currentPlan = subscription.summary?.currentPlan;

    return Scaffold(
      appBar: const FaceTuneTopBar(title: 'Plans'),
      body: SafeArea(
        top: false,
        child: PageFrame.scrolling(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            children: [
              const _PlansLead(),
              const SizedBox(height: AppSpacing.lg),

              // "Not available" is about the store, not about the moment.
              // `purchaseAvailable` also drops while a purchase is open — that
              // is what keeps a second tap from starting a second sheet — but
              // a person mid-purchase must not be told buying is a future
              // feature. While busy, the purchase notice below speaks instead.
              if (!purchaseAvailable && !purchase.isBusy)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppNotice(
                    key: const ValueKey('paywall-purchases-unavailable'),
                    title: 'Purchasing is not available yet',
                    message:
                        'You can compare plans here. Buying a plan will be '
                        'available in a future update of FaceTune.',
                    tone: AppTone.info,
                  ),
                ),

              // The price slot: loading, unavailable, or nothing. It changes
              // once per visit (and again on retry), so it cross-fades rather
              // than snapping — a settled page should settle, not jump.
              _StateSlot(
                key: const ValueKey('paywall-price-slot'),
                child: paywall.status == PaywallStatus.loading
                    ? const Padding(
                        key: ValueKey('paywall-prices-loading'),
                        padding: EdgeInsets.only(bottom: AppSpacing.md),
                        child: LoadingState(label: 'Loading plan prices…'),
                      )
                    : (paywall.status == PaywallStatus.failure ||
                          !paywall.hasPrices)
                    ? Padding(
                        key: const ValueKey('paywall-prices-unavailable'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppNotice(
                          title: 'Prices are not available right now',
                          message:
                              'Each plan still shows what it includes. The '
                              'price you pay is always the one shown by '
                              'Google Play at checkout, in your own currency.',
                          tone: AppTone.info,
                          actions: [
                            TertiaryButton(
                              label: 'Try again',
                              onPressed: () => ref
                                  .read(paywallControllerProvider.notifier)
                                  .retry(),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('paywall-prices-ready'),
                      ),
              ),

              // The purchase notice. It is the *result* of something the user
              // just did, so it is announced when it appears, and it eases
              // in and out for the same reason the price slot does.
              //
              // Only attempts that began on a plan card are reported here. A
              // restore's outcome is shown beside the Restore control at the
              // foot of the page, where the tap happened, so the answer is
              // never a full page of plans away from the question.
              _StateSlot(
                key: const ValueKey('paywall-purchase-slot'),
                child: purchase.message == null || purchase.viaRestore
                    ? const SizedBox.shrink(
                        key: ValueKey('paywall-purchase-status-empty'),
                      )
                    : Padding(
                        key: const ValueKey('paywall-purchase-status'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AppNotice(
                          title: _purchaseNoticeTitle(purchase.phase),
                          message: purchase.message!,
                          tone: purchase.phase == PurchasePhase.failed
                              ? AppTone.warning
                              : AppTone.info,
                          liveRegion: true,
                          actions: [
                            if (!purchase.isBusy)
                              TertiaryButton(
                                label: 'Dismiss',
                                onPressed: () => ref
                                    .read(purchaseControllerProvider.notifier)
                                    .acknowledgeMessage(),
                              ),
                          ],
                        ),
                      ),
              ),

              // Consumer plans first, then the professional plan under its
              // own heading. Which is which comes from the presentation
              // contract, not from a second, hand-written list of plans: the
              // same catalog-derived order, split by weight.
              for (final plan in _consumerPlans)
                _planCard(
                  ref,
                  plan,
                  currentPlan,
                  paywall,
                  purchase,
                  purchaseAvailable,
                ),

              if (_professionalPlans.isNotEmpty) ...[
                const _ProfessionalSectionHeader(),
                for (final plan in _professionalPlans)
                  _planCard(
                    ref,
                    plan,
                    currentPlan,
                    paywall,
                    purchase,
                    purchaseAvailable,
                  ),
              ],

              // What an AI Look is, in the page's own words, on the page's
              // own notice surface — so it reads as guidance rather than as
              // small print.
              const AppNotice(
                key: ValueKey('paywall-ai-look-info'),
                title: 'What counts as an AI Look',
                message:
                    'One AI Look is used each time FaceTune creates a '
                    'finished Final Makeup Preview for you. Reopening it '
                    'from History or Saved Looks, following a Tutorial, or '
                    'sharing it never uses another. Your Beauty Profile and '
                    'makeup plan are always included, and if a preview '
                    'cannot be created, nothing is used.',
                icon: Icons.face_retouching_natural_outlined,
                tone: AppTone.info,
              ),
              const SizedBox(height: AppSpacing.sm),

              // Restore, wired to the same verification path a fresh purchase
              // takes. Disabled while the store is unusable or another attempt
              // is in flight — the button cannot start a second query on top
              // of one already running, and it grants nothing by itself: what
              // it recovers is evidence, and the server decides the rest.
              //
              // Left-aligned and inline rather than stretched across the list,
              // the way every other utility action in the app sits. While the
              // provider is being asked, the button itself carries the
              // progress — its label and a spinner in place of the icon — and
              // the outcome lands directly beneath it, so nothing about a
              // restore is reported anywhere the user is not looking.
              Align(
                alignment: Alignment.centerLeft,
                child: TertiaryButton(
                  key: const ValueKey('paywall-restore-purchases'),
                  label: purchase.phase == PurchasePhase.restoring
                      ? 'Checking your purchases…'
                      : 'Restore purchases',
                  icon: Icons.restore_rounded,
                  isLoading: purchase.phase == PurchasePhase.restoring,
                  onPressed: purchase.canPurchase
                      ? () => ref
                            .read(purchaseControllerProvider.notifier)
                            .restore()
                      : null,
                ),
              ),

              // A disabled utility button in a text style is easy to mistake
              // for a live one, so a resting disabled state says in words why
              // it is not live. Nothing is shown while an attempt is in flight:
              // the button's own progress already explains that.
              if (!purchase.canPurchase && !purchase.isBusy)
                Padding(
                  key: const ValueKey('paywall-restore-unavailable'),
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sm,
                    top: AppSpacing.xxs,
                  ),
                  child: Text(
                    'Restore is available once Google Play is ready on this '
                    'device.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted(context),
                    ),
                  ),
                ),

              // The restore outcome, beside the control that asked for it.
              _StateSlot(
                key: const ValueKey('paywall-restore-slot'),
                child: purchase.message == null || !purchase.viaRestore
                    ? const SizedBox.shrink(
                        key: ValueKey('paywall-restore-status-empty'),
                      )
                    : Padding(
                        key: const ValueKey('paywall-restore-status'),
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: AppNotice(
                          title: _restoreNoticeTitle(purchase.phase),
                          message: purchase.message!,
                          tone: purchase.phase == PurchasePhase.failed
                              ? AppTone.warning
                              : AppTone.info,
                          liveRegion: true,
                          actions: [
                            if (!purchase.isBusy)
                              TertiaryButton(
                                label: 'Dismiss',
                                onPressed: () => ref
                                    .read(purchaseControllerProvider.notifier)
                                    .acknowledgeMessage(),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page lead: what the plans are for, before the plans themselves.
///
/// The entry screen's gradient recipe — `roseDark → rose`, the `xl` radius,
/// and no shadow — so this reads as the same product as the door the user
/// came in through. It is deliberately compact and carries no action of its
/// own: the plan cards are the point of the page, and a lead that competed
/// with them for attention would be a marketing splash, not an orientation.
///
/// Both lines are full white. The gradient keeps its own brightness in either
/// theme, so the foreground cannot come from the colour scheme, and white
/// clears 5:1 on the gradient's lighter end where a softened white would not.
class _PlansLead extends StatelessWidget {
  const _PlansLead();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('paywall-lead'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.roseDark, AppColors.rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: AppIconSizes.lg,
          ),
          const SizedBox(height: AppSpacing.md),
          Semantics(
            header: true,
            child: Text(
              'Create more looks. Keep every result.',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Same FaceTune AI on every plan. Choose how many AI Looks you '
            'need.',
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// The boundary between the consumer plans and the professional one.
///
/// Structure, not decoration: a hairline, the shared section title, and one
/// supporting line that says who the plan below is for. The plan card under
/// it is the same `AppCard` as every other — the professional distinction is
/// made by grouping and copy, never by a second colour scheme.
///
/// The supporting line claims only what the catalog defines: one makeup
/// artist account, and a larger monthly pool of AI Looks. No client tooling,
/// no seats, no licence — none of those exist.
class _ProfessionalSectionHeader extends StatelessWidget {
  const _ProfessionalSectionHeader();

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('paywall-professional-section'),
    padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: const SectionHeader('For makeup professionals'),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'A larger monthly pool of AI Looks for one makeup artist account.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
        ),
      ],
    ),
  );
}

/// A slot whose content is one of several transient states.
///
/// Cross-fades between keyed children and eases the slot's height with them,
/// so a notice arriving or leaving moves the plans below it smoothly rather
/// than shoving them. Durations and curves are the global ones; when the
/// platform asks for reduced motion both collapse to zero and the slot simply
/// shows its current state. Nothing here loops, shimmers, or draws attention
/// to itself — it only takes the edge off a change the state already made.
class _StateSlot extends StatelessWidget {
  const _StateSlot({required this.child, super.key});

  /// The current state's widget. Give each state its own key so the switcher
  /// can tell a change of state from a rebuild of the same one.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // With motion off there is nothing to ease, so the state is shown
    // directly. Not a zero-duration animation: `AnimatedSize` at zero
    // completes its animation inside its own layout pass, which Flutter
    // reports as a layout mutation — the honest reduced-motion path is no
    // animation widget at all.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: AppDurations.standard,
      curve: AppCurves.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: AppDurations.standard,
        switchInCurve: AppCurves.decelerate,
        switchOutCurve: AppCurves.accelerate,
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}
