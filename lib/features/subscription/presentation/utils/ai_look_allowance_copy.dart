import '../../../../theme/app_semantics.dart';
import '../../domain/entities/allowance_unit.dart';
import '../../domain/entities/entitlement_status.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/entities/subscription_summary.dart';
import '../controllers/subscription_state.dart';

/// The words shown for an account's AI Look allowance.
///
/// All plan-specific wording lives here, in one pure function, so the rules
/// that differ between plans — "resets" versus "expires", the Free upgrade
/// line, the absence of a store prompt for Salon Pilot — are testable without
/// building a widget and cannot drift between the two places they appear.
///
/// Nothing here computes entitlement or a date. Every number and every instant
/// comes from the server summary; this only chooses which of them to say.
class AiLookAllowanceCopy {
  const AiLookAllowanceCopy({
    required this.planName,
    required this.remainingLine,
    required this.remaining,
    required this.periodScoped,
    required this.tone,
    this.planQualifier,
    this.renewalLine,
    this.headline,
    this.detail,
    this.upgradePrompt = false,
    this.unit = AllowanceUnit.aiLook,
    this.purchasedLine,
    this.nextPurchasedUnit,
  });

  /// Product name, e.g. "FaceTune Plus". Server-supplied.
  final String planName;

  /// A short clarifier under the plan name, e.g. "Research Access".
  final String? planQualifier;

  /// e.g. "2 of 3 AI Looks remaining".
  final String remainingLine;

  /// e.g. "Resets Oct 7" or "Expires Nov 7". Null when the allowance neither
  /// replenishes nor lapses.
  final String? renewalLine;

  /// Emphasis line shown when the allowance is used up or access is blocked.
  final String? headline;

  /// Supporting sentence for [headline].
  final String? detail;

  /// Whether an upgrade is a genuine next step.
  ///
  /// False for Salon Pilot even when exhausted: it is admin-granted research
  /// access with no store product behind it, so offering to "upgrade" would
  /// send the user to buy something unrelated to their entitlement.
  final bool upgradePrompt;

  /// Allowance units left, as reported by the server.
  final int remaining;

  /// What [remaining] counts. Server-reported from the governing plan; the
  /// words for the unit come from it and nowhere else, so a Preview-only
  /// allowance is never called AI Looks.
  final AllowanceUnit unit;

  /// Whether the allowance is scoped to a billing period, which decides
  /// whether "this month" is true.
  final bool periodScoped;

  final AppTone tone;

  /// Purchased top-up credits stored on the account, e.g. "Plus 2 purchased
  /// AI Looks and 10 purchased Final Preview Credits", or null when none.
  ///
  /// Counts are server-reported. Shown beneath the plan's own figure and
  /// never added to it: the two are different money and stay different
  /// numbers. When the plan cannot spend them right now, the line says so
  /// rather than promising capacity the server would refuse.
  final String? purchasedLine;

  /// The compact line shown beside the Generate action, e.g.
  /// "2 AI Looks remaining this month".
  ///
  /// When access is blocked or the allowance is spent, the headline is the
  /// more useful thing to say. When the plan's own allowance is spent but a
  /// purchased credit will be used, the line says which kind — so a person on
  /// a Tutorial plan is told, before spending it, that a Preview-only credit
  /// carries no Tutorial.
  String get compactLine {
    if (headline != null) return headline!;
    if (nextPurchasedUnit case final purchasedUnit?) {
      return purchasedUnit == AllowanceUnit.aiLook
          ? 'Next look uses a purchased AI Look'
          : 'Next look uses a purchased Final Preview Credit (no Tutorial)';
    }
    final unitLabel = unit.label(remaining);
    return periodScoped
        ? '$remaining $unitLabel remaining this month'
        : '$remaining $unitLabel remaining';
  }

  /// The unit the next generation would spend from a purchased credit, when
  /// the plan's own allowance is used up and a credit is available. Null when
  /// the next look comes from the plan or nothing is available.
  final AllowanceUnit? nextPurchasedUnit;

  /// The purchased-credit line for [summary], or null when there is none.
  static String? purchasedCreditsLine(SubscriptionSummary summary) {
    final credits = summary.purchasedCredits;
    if (!credits.hasAny) return null;
    final parts = <String>[
      if (credits.tutorialCapableRemaining > 0)
        '${credits.tutorialCapableRemaining} purchased '
            '${AllowanceUnit.aiLook.label(credits.tutorialCapableRemaining)}',
      if (credits.previewOnlyRemaining > 0)
        '${credits.previewOnlyRemaining} purchased '
            '${AllowanceUnit.finalPreviewCredit.label(credits.previewOnlyRemaining)}',
    ];
    final stored = 'Plus ${parts.join(' and ')}';
    // A blocked, lapsed, Free, or Salon Pilot account keeps its credits and
    // is told they are waiting, not that they can be spent.
    return credits.usable
        ? stored
        : '$stored — kept for you, usable while a paid plan is active';
  }

  /// Builds the copy for [state], or null when there is nothing honest to say.
  ///
  /// Returns null while loading, on failure with nothing cached, when signed
  /// out, and when no entitlement has been provisioned. Showing "1 of 1
  /// remaining" in any of those cases would be the UI inventing a quota it was
  /// never told about — the one thing this surface must never do.
  static AiLookAllowanceCopy? forState(SubscriptionState state) {
    final summary = state.summary;
    if (summary == null) return null;
    if (state.status == SubscriptionStatus.signedOut) return null;
    if (!summary.hasEntitlement) return null;
    return forSummary(summary);
  }

  /// Builds the copy for a resolved [summary].
  static AiLookAllowanceCopy forSummary(SubscriptionSummary summary) {
    final remaining = summary.usage.remainingAiLooks;
    final allowance = summary.usage.effectiveAllowance;
    final periodScoped = summary.replenishes;
    final isSalonPilot = summary.planCode == SubscriptionPlanCode.salonPilot;
    final isFree = summary.planCode == SubscriptionPlanCode.free;
    final qualifier = isSalonPilot ? 'Research Access' : null;

    final unit = summary.allowanceUnit;
    final unitLabel = unit.label(allowance);
    final remainingLine = isFree
        ? '$remaining of $allowance complimentary $unitLabel remaining'
        : '$remaining of $allowance $unitLabel remaining';

    // "Resets" and "Expires" are different promises and must not be swapped: a
    // recurring plan replenishes on its renewal date, while an admin grant
    // simply ends. Both dates are server-verified.
    final renewalLine = _renewalLine(summary);
    final purchasedLine = purchasedCreditsLine(summary);
    // Whether the next look would spend a purchased credit rather than the
    // plan's own allowance — the server's answer, carried for wording only.
    final credits = summary.purchasedCredits;
    final nextPurchasedUnit =
        credits.nextDrawsFromPurchased && credits.availableCompatible > 0
        ? credits.nextAllowanceUnit
        : null;

    AiLookAllowanceCopy build({
      String? headline,
      String? detail,
      required AppTone tone,
      bool upgradePrompt = false,
    }) => AiLookAllowanceCopy(
      planName: summary.planDisplayName,
      planQualifier: qualifier,
      remainingLine: remainingLine,
      renewalLine: renewalLine,
      remaining: remaining,
      periodScoped: periodScoped,
      headline: headline,
      detail: detail,
      tone: tone,
      upgradePrompt: upgradePrompt,
      unit: unit,
      purchasedLine: purchasedLine,
      nextPurchasedUnit: nextPurchasedUnit,
    );

    // A blocked entitlement outranks the count. Saying "you have run out" to
    // someone whose subscription was suspended would be wrong and would point
    // them at the wrong remedy.
    //
    // "Ended" is also read from the server's effective refusal, not only from
    // the stored status: a verified period can lapse before a provider read
    // moves the status, and the card must say so rather than promise a reset
    // date that has already passed. A status that already names its own
    // block keeps its own words.
    final blocked =
        _blockedStatus(summary.status) ??
        (summary.hasEnded ? _blockedStatus(EntitlementStatus.expired) : null);
    if (blocked != null) {
      return build(
        headline: blocked.$1,
        detail: blocked.$2,
        tone: AppTone.warning,
      );
    }

    if (remaining > 0) {
      return build(tone: remaining == 1 ? AppTone.warning : AppTone.info);
    }

    // The plan's own allowance is spent, but the server will draw the next
    // look from a purchased credit. Not exhausted, then: the compact line
    // names the credit that will be used, and nothing here says "used all".
    if (nextPurchasedUnit != null) {
      return build(tone: AppTone.info);
    }

    // Exhausted. What to say next differs by plan, because what the user can
    // actually do about it differs.
    if (isFree) {
      return build(
        headline: 'You have used your complimentary AI Look',
        detail: 'Upgrade to create more AI Looks.',
        tone: AppTone.warning,
        upgradePrompt: true,
      );
    }

    if (isSalonPilot) {
      return build(
        headline: 'Salon Pilot allowance used',
        // No store prompt: this is admin-granted research access, not a
        // purchasable product, so the next step is a conversation.
        detail: 'Contact the FaceTune team to review your research allowance.',
        tone: AppTone.warning,
      );
    }

    final resetsOn = _formatDate(summary.resetAt, summary);
    return build(
      headline: 'You have used all your ${unit.plural}',
      detail: resetsOn == null
          ? 'Your allowance will replenish with your next billing period.'
          : 'Your allowance resets on $resetsOn.',
      tone: AppTone.warning,
    );
  }

  /// Copy for an entitlement that exists but cannot currently generate, or
  /// null when the status permits generation.
  static (String, String)? _blockedStatus(EntitlementStatus? status) =>
      switch (status) {
        EntitlementStatus.expired => (
          'Your subscription has ended',
          'Renew to create more AI Looks.',
        ),
        EntitlementStatus.suspended => (
          'Your subscription is suspended',
          'Contact support to restore access.',
        ),
        EntitlementStatus.revoked => (
          'Your subscription is no longer active',
          'Contact support if you think this is a mistake.',
        ),
        EntitlementStatus.pending => (
          'Your subscription is being confirmed',
          'This usually takes a moment.',
        ),
        _ => null,
      };

  static String? _renewalLine(SubscriptionSummary summary) {
    // An ended subscription neither resets nor expires from here: the date on
    // record has already passed, and repeating it would read as a promise.
    if (summary.hasEnded) return null;
    if (summary.replenishes) {
      final date = _formatDate(summary.resetAt, summary);
      return date == null ? null : 'Resets $date';
    }
    final expiry = _formatDate(summary.expiresAt, summary);
    return expiry == null ? null : 'Expires $expiry';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// Formats a server-supplied instant as e.g. "Oct 7".
  ///
  /// Rendered in UTC, matching the calendar the server billed against.
  /// Shifting it into the device's timezone could show "Oct 6" for a period
  /// the server considers to end on the 7th, which is exactly the kind of
  /// quiet disagreement a billing date must not have.
  ///
  /// The year is added only when it differs from the year the server resolved
  /// this state in — a comparison between two server values, so the device
  /// clock plays no part in it.
  static String? _formatDate(DateTime? value, SubscriptionSummary summary) {
    if (value == null) return null;
    final date = value.toUtc();
    final label = '${_months[date.month - 1]} ${date.day}';
    return date.year == summary.resolvedAt.toUtc().year
        ? label
        : '$label, ${date.year}';
  }
}
