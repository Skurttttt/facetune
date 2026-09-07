import '../../../../theme/app_semantics.dart';
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

  /// AI Looks left, as reported by the server.
  final int remaining;

  /// Whether the allowance is scoped to a billing period, which decides
  /// whether "this month" is true.
  final bool periodScoped;

  final AppTone tone;

  /// The compact line shown beside the Generate action, e.g.
  /// "2 AI Looks remaining this month".
  ///
  /// When access is blocked or the allowance is spent, the headline is the
  /// more useful thing to say.
  String get compactLine {
    if (headline != null) return headline!;
    final unit = remaining == 1 ? 'AI Look' : 'AI Looks';
    return periodScoped
        ? '$remaining $unit remaining this month'
        : '$remaining $unit remaining';
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

    final unit = allowance == 1 ? 'AI Look' : 'AI Looks';
    final remainingLine = isFree
        ? '$remaining of $allowance complimentary $unit remaining'
        : '$remaining of $allowance $unit remaining';

    // "Resets" and "Expires" are different promises and must not be swapped: a
    // recurring plan replenishes on its renewal date, while an admin grant
    // simply ends. Both dates are server-verified.
    final renewalLine = _renewalLine(summary);

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
    );

    // A blocked entitlement outranks the count. Saying "you have run out" to
    // someone whose subscription was suspended would be wrong and would point
    // them at the wrong remedy.
    final blocked = _blockedStatus(summary.status);
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
      headline: 'You have used all your AI Looks',
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
