import 'package:flutter/material.dart';

import '../../domain/catalog/subscription_plan_catalog.dart';
import '../../domain/entities/allowance_unit.dart';
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

/// Which group of the paywall a plan is listed under.
///
/// The two paid offer styles are separated by section so the difference is
/// structural and read before any card is: the Tutorial-enabled plans, then
/// the Preview-only plans, then the professional pair. Derived from the
/// catalog's capability, not from a hand-written list.
enum PaywallSection {
  /// Free and the consumer plans that include the Step-by-Step Tutorial.
  tutorial,

  /// The consumer plans that trade the Tutorial for more Final Previews.
  previewOnly,

  /// The professional tier, in both styles.
  professional,
}

/// Product copy for the paywall.
///
/// Separate from `SubscriptionPlanCatalog`, which holds plan *configuration*
/// the entitlement engine mirrors. These are the words and the glyph used to
/// sell a plan, and they carry no authority — changing a line here cannot
/// change what anyone is granted.
abstract final class PlanPresentation {
  /// The plans a user may buy, in catalog order.
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

  /// The plans listed under [section], in catalog order.
  static List<SubscriptionPlanCode> plansIn(PaywallSection section) =>
      comparisonPlans
          .where((plan) => sectionOf(plan) == section)
          .toList(growable: false);

  /// Which section a plan is listed under.
  ///
  /// The professional tier is decided by [emphasis]; within the consumer
  /// tiers, the catalog's capability decides — a plan without the Tutorial is
  /// a Preview-only plan, whatever it is called.
  static PaywallSection sectionOf(SubscriptionPlanCode plan) {
    if (emphasis(plan) == PlanEmphasis.professional) {
      return PaywallSection.professional;
    }
    return SubscriptionPlanCatalog.definitionFor(plan).tutorialEnabled
        ? PaywallSection.tutorial
        : PaywallSection.previewOnly;
  }

  /// The weight a plan's card carries, per the approved plan hierarchy: Plus
  /// is the mainstream recommendation, the two Salon offers are the
  /// professional tier, and everything else — Free as the baseline, Pro as
  /// the larger consumer tier, the Preview-only consumer plans — is drawn
  /// plainly.
  ///
  /// Salon Pilot is never emphasized. It is not on the paywall at all, and
  /// mapping it here to [PlanEmphasis.standard] is what keeps the switch
  /// exhaustive without giving it a presentation it must not have.
  static PlanEmphasis emphasis(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.plus => PlanEmphasis.recommended,
    SubscriptionPlanCode.salonPro ||
    SubscriptionPlanCode.salonPreview => PlanEmphasis.professional,
    SubscriptionPlanCode.free ||
    SubscriptionPlanCode.plusPreview ||
    SubscriptionPlanCode.pro ||
    SubscriptionPlanCode.proPreview ||
    SubscriptionPlanCode.salonPilot => PlanEmphasis.standard,
  };

  /// A one-line description of who the plan is for.
  static String tagline(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.free => 'Try the complete FaceTune experience once.',
    SubscriptionPlanCode.plus =>
      'For refining a look you already have in mind.',
    SubscriptionPlanCode.plusPreview =>
      'For trying many looks, without the Tutorial.',
    SubscriptionPlanCode.pro => 'For exploring several looks each month.',
    SubscriptionPlanCode.proPreview =>
      'For exploring far more looks, without the Tutorial.',
    SubscriptionPlanCode.salonPro =>
      'For a makeup artist working with clients.',
    SubscriptionPlanCode.salonPreview =>
      'For a makeup artist previewing many clients, without the Tutorial.',
    SubscriptionPlanCode.salonPilot => '',
  };

  /// What the plan includes, beyond its allowance.
  ///
  /// No plan claims anything it does not have: there is no unlimited tier, no
  /// annual option, no bundled extras. Every plan gets the same AI quality,
  /// because the canonical preview is the tutorial's visual authority and is
  /// locked to one model for every account. A Preview-only plan says plainly
  /// that the Tutorial is not part of it.
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
    SubscriptionPlanCode.plusPreview => const [
      'Everything in Free, except the Tutorial',
      'Same Final Preview quality as Plus',
      'Step-by-Step Tutorial not included',
    ],
    SubscriptionPlanCode.pro => const [
      'Everything in Plus',
      'Room to compare several styles each period',
    ],
    SubscriptionPlanCode.proPreview => const [
      'Everything in Plus Preview',
      'Same Final Preview quality as Pro',
      'Step-by-Step Tutorial not included',
    ],
    SubscriptionPlanCode.salonPro => const [
      'Everything in Pro',
      '1 Makeup Artist Account',
    ],
    SubscriptionPlanCode.salonPreview => const [
      'Everything in Pro Preview',
      '1 Makeup Artist Account',
      'Step-by-Step Tutorial not included',
    ],
    SubscriptionPlanCode.salonPilot => const [],
  };

  /// The glyph beside the plan name, from the app's existing vector family.
  /// No emoji anywhere.
  static IconData icon(SubscriptionPlanCode plan) => switch (plan) {
    SubscriptionPlanCode.free => Icons.spa_outlined,
    SubscriptionPlanCode.plus => Icons.auto_awesome_outlined,
    SubscriptionPlanCode.plusPreview => Icons.photo_library_outlined,
    SubscriptionPlanCode.pro => Icons.auto_awesome_rounded,
    SubscriptionPlanCode.proPreview => Icons.photo_library_rounded,
    SubscriptionPlanCode.salonPro => Icons.workspace_premium_outlined,
    SubscriptionPlanCode.salonPreview => Icons.workspace_premium_rounded,
    SubscriptionPlanCode.salonPilot => Icons.science_outlined,
  };

  /// How the plan's allowance reads on a card, in the plan's own unit, e.g.
  /// "3 AI Looks per month" or "30 Final Preview Credits per month".
  static String allowanceLine(SubscriptionPlanCode plan) {
    final definition = SubscriptionPlanCatalog.definitionFor(plan);
    final allowance = definition.baseAllowance;
    final unit = definition.allowanceUnit.label(allowance);
    return plan == SubscriptionPlanCode.free
        ? '$allowance one-time $unit'
        : '$allowance $unit per month';
  }

  /// The one-line capability statement a card leads its benefits with.
  ///
  /// Both offer styles are stated positively and specifically, so a person
  /// comparing Plus with Plus Preview sees the trade at a glance and a
  /// Preview-only card never implies the Tutorial.
  static String capabilityLine(SubscriptionPlanCode plan) {
    final definition = SubscriptionPlanCatalog.definitionFor(plan);
    return switch (definition.allowanceUnit) {
      AllowanceUnit.aiLook =>
        definition.tutorialEnabled
            ? 'Tutorial included with every AI Look'
            : 'Final Previews only',
      AllowanceUnit.finalPreviewCredit => 'Final Previews only — no Tutorial',
    };
  }

  /// The heading a paywall section is listed under, or null for the leading
  /// section, which needs none.
  static String? sectionTitle(PaywallSection section) => switch (section) {
    PaywallSection.tutorial => null,
    PaywallSection.previewOnly => 'Preview-only plans',
    PaywallSection.professional => 'For makeup professionals',
  };

  /// One line under a section heading saying what sets the section apart.
  static String? sectionLead(PaywallSection section) => switch (section) {
    PaywallSection.tutorial => null,
    PaywallSection.previewOnly =>
      'The same Final Preview quality, many more of them, and no '
          'Step-by-Step Tutorial. Same monthly price as the plan beside it.',
    PaywallSection.professional =>
      'A larger monthly pool for one makeup artist account, with the '
          'Tutorial or without it.',
  };
}
