import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../../theme/app_semantics.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/entities/subscription_summary.dart';
import '../../domain/entities/top_up_pack.dart';
import '../controllers/paywall_controller.dart';
import '../controllers/paywall_state.dart';
import '../controllers/purchase_controller.dart';
import '../controllers/purchase_state.dart';
import '../controllers/subscription_controller.dart';
import '../controllers/top_up_offers_controller.dart';
import '../utils/ai_look_allowance_copy.dart';
import '../utils/plan_presentation.dart';
import '../widgets/subscription_plan_card.dart';
import '../widgets/top_up_pack_card.dart';

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

  /// The page's sections, in reading order: the Tutorial-enabled consumer
  /// plans under the page lead, then the Preview-only consumer plans under
  /// their own heading, then the professional pair under theirs. Which plan
  /// belongs where comes from the presentation contract, which reads the
  /// catalog's capability — not from a second, hand-written list of plans.
  static const List<PaywallSection> _sections = PaywallSection.values;

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

  /// What a pack's button says during each busy phase of *its* purchase.
  static String? _topUpInFlightLabel(PurchasePhase phase) => switch (phase) {
    PurchasePhase.starting => 'Opening Google Play…',
    PurchasePhase.awaitingPayment => 'Waiting for Google Play…',
    PurchasePhase.verifying => 'Adding your credits…',
    _ => null,
  };

  /// The packs offered to an account, or none.
  ///
  /// Offered only when the server says purchased credits are usable on the
  /// governing plan — an active, eligible paid plan — and only the pack that
  /// plan is approved to buy: Extra AI Look for the Tutorial-enabled plans,
  /// Preview Boost for the Preview-only plans, nothing for Free and Salon
  /// Pilot. A courtesy, not the gate: the server refuses an ineligible grant
  /// regardless, and Google refunds the purchase.
  static List<TopUpPack> _offeredPacks(SubscriptionSummary? summary) {
    if (summary == null || !summary.purchasedCredits.usable) return const [];
    return TopUpPack.values
        .where((pack) => pack.isOfferedTo(summary.planCode))
        .toList(growable: false);
  }

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
    final offeredPacks = _offeredPacks(subscription.summary);
    // Pack prices are only asked for when a pack is on offer, so an account
    // that cannot buy one never queries the store for it.
    final topUpOffers = offeredPacks.isEmpty
        ? null
        : ref.watch(topUpOffersControllerProvider);
    final purchasedLine = subscription.summary == null
        ? null
        : AiLookAllowanceCopy.purchasedCreditsLine(subscription.summary!);

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

              // Section by section. The leading section has no heading; the
              // Preview-only and professional sections each announce what sets
              // them apart before their first card, so the two offer styles
              // are told apart structurally and not only by a line on a card.
              for (final section in _sections)
                if (PlanPresentation.plansIn(section).isNotEmpty) ...[
                  if (PlanPresentation.sectionTitle(section) != null)
                    _SectionHeaderBlock(section: section),
                  for (final plan in PlanPresentation.plansIn(section))
                    _planCard(
                      ref,
                      plan,
                      currentPlan,
                      paywall,
                      purchase,
                      purchaseAvailable,
                    ),
                ],

              // Top-up packs, for accounts that can use them. Structured like
              // the plan sections — a hairline, a title, one line on what the
              // section is — and absent entirely for everyone else, so Free
              // and Salon Pilot are never shown a pack they cannot buy.
              if (offeredPacks.isNotEmpty) ...[
                Padding(
                  key: const ValueKey('paywall-top-up-section'),
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xs,
                    bottom: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(height: AppSpacing.lg),
                      Semantics(
                        header: true,
                        child: const SectionHeader('Top-up packs'),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Add credits to your current plan. They are used '
                        'after the AI Looks or Final Preview Credits your '
                        'plan includes, and they stay on your account.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted(context),
                        ),
                      ),
                      if (purchasedLine != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          key: const ValueKey('paywall-purchased-credits'),
                          purchasedLine,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                for (final pack in offeredPacks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: TopUpPackCard(
                      pack: pack,
                      price: topUpOffers?.priceFor(pack),
                      // Buyable only when the store is usable *and* returned
                      // a product for this pack, exactly as a plan is.
                      purchaseAvailable:
                          purchaseAvailable &&
                          topUpOffers?.priceFor(pack) != null,
                      onSelect: () => ref
                          .read(purchaseControllerProvider.notifier)
                          .buyTopUp(pack),
                      inFlightLabel:
                          purchase.isBusy && purchase.topUpPack == pack
                          ? _topUpInFlightLabel(purchase.phase)
                          : null,
                    ),
                  ),
              ],

              // What an AI Look is, in the page's own words, on the page's
              // own notice surface — so it reads as guidance rather than as
              // small print.
              const AppNotice(
                key: ValueKey('paywall-ai-look-info'),
                title: 'What counts as an AI Look or a Final Preview Credit',
                message:
                    'One AI Look, or one Final Preview Credit, is used each '
                    'time FaceTune creates a finished Final Makeup Preview '
                    'for you. Reopening it from History or Saved Looks, or '
                    'sharing it, never uses another. An AI Look also includes '
                    'the Step-by-Step Tutorial for that look; a Final Preview '
                    'Credit does not. Your Beauty Profile and makeup plan are '
                    'always included, and if a preview cannot be created, '
                    'nothing is used.',
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
/// A section heading on the paywall, with one line on what sets the section
/// apart.
///
/// Keyed per section so tests and assistive technology can find each, and
/// worded by the presentation contract, so the page carries no copy of its
/// own about what a section contains.
class _SectionHeaderBlock extends StatelessWidget {
  const _SectionHeaderBlock({required this.section});

  final PaywallSection section;

  @override
  Widget build(BuildContext context) => Padding(
    key: ValueKey('paywall-${section.name}-section'),
    padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: AppSpacing.lg),
        Semantics(
          header: true,
          child: SectionHeader(PlanPresentation.sectionTitle(section)!),
        ),
        if (PlanPresentation.sectionLead(section) case final lead?) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            lead,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.muted(context)),
          ),
        ],
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
