import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';

/// The dashboard's figures, exactly as `public.admin_dashboard_metrics()`
/// aggregated them on the server. Every stored number is a count the database
/// computed. The only derived getters are explicitly bounded presentation
/// sums over complete fixed-size server aggregates.
class AdminDashboardMetrics {
  const AdminDashboardMetrics({
    required this.asOf,
    required this.todayStartsAt,
    required this.monthStartsAt,
    required this.expiringSoonWindowDays,
    required this.accounts,
    required this.entitlements,
    required this.aiLooks,
    required this.salonPilot,
    required this.purchasedCredits,
  });

  final DateTime asOf;
  final DateTime todayStartsAt;
  final DateTime monthStartsAt;
  final int expiringSoonWindowDays;
  final AccountCounts accounts;
  final EntitlementCounts entitlements;
  final AiLookCounts aiLooks;
  final SalonPilotCounts salonPilot;
  final PurchasedCreditCounts purchasedCredits;

  /// A fixed eight-value presentation aggregation over the server's complete
  /// canonical plan map. This counts entitlements, not accounts.
  int get inForceEntitlements => entitlements.inForceByPlan.values.fold(
    0,
    (total, count) => total + count,
  );

  /// The V1 current-month outcome aggregate across its two authoritative
  /// funding-source buckets. The result is operations, never "AI Looks".
  int get committedOperationsThisMonth =>
      aiLooks.committedThisMonth.subscription +
      aiLooks.committedThisMonth.purchasedCredit;

  /// True when the system holds no accounts at all — the "empty" state.
  bool get isEmpty => accounts.totalUsers == 0 && accounts.anonymousGuests == 0;

  /// Strict decoding of the RPC payload. A refusal becomes an
  /// [AdminAuthFailure]; anything malformed is a temporary failure. No field
  /// is defaulted: a missing count is a broken server, not a zero.
  static AdminDashboardMetrics decode(Object? payload) {
    if (payload is! Map) throw _malformed();
    final root = _stringKeyed(payload);
    if (root['ok'] != true) {
      final code = SubscriptionErrorCode.fromCode(
        root['errorCode']?.toString() ?? '',
      );
      throw AdminAuthFailure(
        code == SubscriptionErrorCode.authRequired ||
                code == SubscriptionErrorCode.adminUnauthorized
            ? code!
            : SubscriptionErrorCode.temporaryBackendFailure,
        retryable: code == null,
      );
    }
    final accounts = _object(root, 'accounts');
    final entitlements = _object(root, 'entitlements');
    final aiLooks = _object(root, 'aiLooks');
    final salonPilot = _object(root, 'salonPilot');
    final credits = _object(root, 'purchasedCredits');

    return AdminDashboardMetrics(
      asOf: _timestamp(root, 'asOf'),
      todayStartsAt: _timestamp(root, 'todayStartsAt'),
      monthStartsAt: _timestamp(root, 'monthStartsAt'),
      expiringSoonWindowDays: _count(root, 'expiringSoonWindowDays'),
      accounts: AccountCounts(
        totalUsers: _count(accounts, 'totalUsers'),
        anonymousGuests: _count(accounts, 'anonymousGuests'),
      ),
      entitlements: EntitlementCounts(
        inForceByPlan: _byPlan(_object(entitlements, 'inForceByPlan')),
        pending: _count(entitlements, 'pending'),
        suspended: _count(entitlements, 'suspended'),
      ),
      aiLooks: AiLookCounts(
        committedToday: _bySource(_object(aiLooks, 'committedToday')),
        committedThisMonth: _bySource(_object(aiLooks, 'committedThisMonth')),
        reservedOpen: _count(aiLooks, 'reservedOpen'),
        releasedToday: _count(aiLooks, 'releasedToday'),
        releasedThisMonth: _count(aiLooks, 'releasedThisMonth'),
      ),
      salonPilot: SalonPilotCounts(
        inForce: _count(salonPilot, 'inForce'),
        expiringSoon: _count(salonPilot, 'expiringSoon'),
      ),
      purchasedCredits: PurchasedCreditCounts(
        activeGrants: _count(credits, 'activeGrants'),
      ),
    );
  }

  static AdminAuthFailure _malformed() => const AdminAuthFailure(
    SubscriptionErrorCode.temporaryBackendFailure,
    retryable: true,
  );

  static Map<String, Object?> _stringKeyed(Map<Object?, Object?> map) =>
      map.map((key, value) => MapEntry(key.toString(), value));

  static Map<String, Object?> _object(Map<String, Object?> parent, String key) {
    final value = parent[key];
    if (value is! Map) throw _malformed();
    return _stringKeyed(value);
  }

  static int _count(Map<String, Object?> parent, String key) {
    final value = parent[key];
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0 && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw _malformed();
  }

  static DateTime _timestamp(Map<String, Object?> parent, String key) {
    final value = parent[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) throw _malformed();
    return parsed.toUtc();
  }

  /// Every canonical plan code must be present; an unknown code is a
  /// contract drift the client must not paper over.
  static Map<SubscriptionPlanCode, int> _byPlan(Map<String, Object?> raw) {
    final result = <SubscriptionPlanCode, int>{};
    for (final entry in raw.entries) {
      final plan = SubscriptionPlanCode.fromCode(entry.key);
      if (plan == null) throw _malformed();
      result[plan] = _count(raw, entry.key);
    }
    for (final plan in SubscriptionPlanCode.values) {
      if (!result.containsKey(plan)) throw _malformed();
    }
    return Map.unmodifiable(result);
  }

  static CommittedBySource _bySource(Map<String, Object?> raw) =>
      CommittedBySource(
        subscription: _count(raw, 'subscription'),
        purchasedCredit: _count(raw, 'purchasedCredit'),
      );
}

class AccountCounts {
  const AccountCounts({
    required this.totalUsers,
    required this.anonymousGuests,
  });

  final int totalUsers;
  final int anonymousGuests;
}

class EntitlementCounts {
  const EntitlementCounts({
    required this.inForceByPlan,
    required this.pending,
    required this.suspended,
  });

  /// In-force entitlements per canonical plan; every plan present, zero or not.
  final Map<SubscriptionPlanCode, int> inForceByPlan;
  final int pending;
  final int suspended;
}

/// Committed rows split by the bucket they drew from (Shared Contract §74a).
/// Kept separate in the contract: a purchased credit is not an included AI
/// Look. UI-5 may add the two fixed buckets only for an honestly labelled
/// operation-outcome comparison.
class CommittedBySource {
  const CommittedBySource({
    required this.subscription,
    required this.purchasedCredit,
  });

  final int subscription;
  final int purchasedCredit;
}

class AiLookCounts {
  const AiLookCounts({
    required this.committedToday,
    required this.committedThisMonth,
    required this.reservedOpen,
    required this.releasedToday,
    required this.releasedThisMonth,
  });

  final CommittedBySource committedToday;
  final CommittedBySource committedThisMonth;
  final int reservedOpen;
  final int releasedToday;
  final int releasedThisMonth;
}

class SalonPilotCounts {
  const SalonPilotCounts({required this.inForce, required this.expiringSoon});

  final int inForce;
  final int expiringSoon;
}

class PurchasedCreditCounts {
  const PurchasedCreditCounts({required this.activeGrants});

  final int activeGrants;
}
