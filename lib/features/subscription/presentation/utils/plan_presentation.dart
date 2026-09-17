import 'package:flutter/material.dart';

import '../../domain/catalog/subscription_plan_catalog.dart';
import '../../domain/entities/subscription_plan_code.dart';

/// How much visual weight a plan carries on the paywall, relative to its
/// peers.
///
/// A presentation contract and nothing more. It is keyed by the domain's
/// [SubscriptionPlanCode] rather than carrying a plan of its own, so it cannot
/// become a second list of plans, and it says nothing about price, allowance,
/// or what an account holds — changing which plan is [recommended] changes
/// which card is drawn heavier and not one thing about what anyone is granted.
enum PlanEmphasis {
  /// Drawn as an ordinary card.
  standard,

  /// The plan the paywall leads with for most people. At most one.
  recommended,

  /// A plan for makeup professionals, set apart from the consumer tiers by
  /// structure rather than by decoration.
  professional,
}

/// Product copy for the paywall.
///
/// Separate from `SubscriptionPlanCatalog`, which holds plan *configuration*
/// the entitlement engine mirrors. These are the words and the glyph used to
/// sell a plan, and they carry no authority — changing a line here cannot
/// change what anyone is granted.
abstract final class PlanPresentation {
  /// The plans a user may buy, in ascending order.
  ///
  /// Read from the catalog rather than listed here, so Salon Pilot cannot be
  /// added to the paywall by editing presentation code: it is not publicly
  /// purchasable, and the catalog is what says so.
  static List<SubscriptionPlanCode> get purchasablePlans =>
      SubscriptionPlanCatalog.publiclyPurchasable
          .map((definition) => definition.planCode)
          .toList(growable: false);

  /// Every plan the paywall shows, including Free as the baseline to compare
  /// against. Free appears so the comparison is honest, not because it can be
  /// bought.
  static List<SubscriptionPlanCode> get comparisonPlans => [
    SubscriptionPlanCode.free,
    ...purchasablePlans,
  ];

  /// The weight a plan's card carries, per the approved plan hierarchy: Plus
  /// is the mainstream recommendation, Salon Pro is the professional plan,
  /// and everything else — Free as the baseline, Pro as the larger consumer
  /// tier — is drawn plainly.
  ///
  /// Salon Pilot is never emphasized. It is not on the paywall at all, and
  /// mapping it here to [PlanEmphasis.standard] is what keeps the switch
  /// exhaustive without giving it a presentation it must not have.
  static PlanEmphasis emphasis(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.plus => PlanEmphasis.recommended,
    SubscriptionPlanCode.salonPro => PlanEmphasis.professional,
    SubscriptionPlanCode.free ||
    SubscriptionPlanCode.pro ||
    SubscriptionPlanCode.salonPilot => PlanEmphasis.standard,
  };

  /// A one-line description of who the plan is for.
  static String tagline(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.free => 'Try the complete FaceTune experience once.',
    SubscriptionPlanCode.plus =>
      'For refining a look you already have in mind.',
    SubscriptionPlanCode.pro => 'For exploring several looks each month.',
    SubscriptionPlanCode.salonPro =>
      'For a makeup artist working with clients.',
    SubscriptionPlanCode.salonPilot => '',
  };

  /// What the plan includes, beyond its AI Look allowance.
  ///
  /// No plan claims anything it does not have: there is no unlimited tier, no
  /// annual option, no bundled extras. Every plan gets the same AI quality,
  /// because the canonical preview is the tutorial's visual authority and is
  /// locked to one model for every account.
  static List<String> features(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.free => const [
      'Beauty Profile and AI face analysis',
      'Standard Mode and My Makeup Kit',
      'Step-by-Step Tutorial included',
    ],
    SubscriptionPlanCode.plus => const [
      'Everything in Free',
      'Step-by-Step Tutorial included',
      'History and Saved Looks',
    ],
    SubscriptionPlanCode.pro => const [
      'Everything in Plus',
      'Room to compare several styles each period',
    ],
    SubscriptionPlanCode.salonPro => const [
      'Everything in Pro',
      '1 Makeup Artist Account',
    ],
    SubscriptionPlanCode.salonPilot => const [],
  };

  /// The glyph beside the plan name, from the app's existing vector family.
  /// No emoji anywhere.
  static IconData icon(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.free => Icons.spa_outlined,
    SubscriptionPlanCode.plus => Icons.auto_awesome_outlined,
    SubscriptionPlanCode.pro => Icons.auto_awesome_rounded,
    SubscriptionPlanCode.salonPro => Icons.workspace_premium_outlined,
    SubscriptionPlanCode.salonPilot => Icons.science_outlined,
  };

  /// How the plan's allowance reads on a card, e.g. "3 AI Looks per month".
  static String allowanceLine(SubscriptionPlanCode plan) {
    final definition = SubscriptionPlanCatalog.definitionFor(plan);
    final allowance = definition.baseAiLookAllowance;
    final unit = allowance == 1 ? 'AI Look' : 'AI Looks';
    return plan == SubscriptionPlanCode.free
        ? '$allowance one-time $unit'
        : '$allowance $unit per month';
  }
}
