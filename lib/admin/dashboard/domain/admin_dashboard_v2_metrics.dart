import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../features/subscription/domain/errors/subscription_error_code.dart';
import '../../auth/domain/admin_auth_failure.dart';

/// The bounded aggregate returned by `admin_dashboard_v2_metrics()`.
///
/// The browser only validates and presents these server-created aggregates. It
/// does not fill dates, attribute deliveries, or resolve governing
/// entitlements.
class AdminDashboardV2Metrics {
  const AdminDashboardV2Metrics({
    required this.asOf,
    required this.reportingTimezone,
    required this.todayStartsAt,
    required this.window30dStart,
    required this.window30dEnd,
    required this.committedDaily,
    required this.finalPreviewsByPlan30d,
    required this.finalPreviewsUnattributed30d,
    required this.committedTodayByUnit,
    required this.entitlementStatusDistribution,
  });

  static const contractVersion = 'admin_dashboard_v2_contract_v1';

  final DateTime asOf;
  final String reportingTimezone;
  final DateTime todayStartsAt;
  final DateTime window30dStart;
  final DateTime window30dEnd;
  final List<AdminDashboardDailyPoint> committedDaily;
  final Map<SubscriptionPlanCode, int> finalPreviewsByPlan30d;
  final int finalPreviewsUnattributed30d;
  final CommittedByUnit committedTodayByUnit;
  final EntitlementStatusDistribution entitlementStatusDistribution;

  static AdminDashboardV2Metrics decode(Object? payload) {
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
    if (root['contractVersion'] != contractVersion ||
        root['reportingTimezone'] != 'UTC') {
      throw _malformed();
    }

    final start = _timestamp(root, 'window30dStart');
    final end = _timestamp(root, 'window30dEnd');
    final dailyRaw = root['committedDaily'];
    if (dailyRaw is! List || dailyRaw.length != 30) throw _malformed();
    final daily = List<AdminDashboardDailyPoint>.unmodifiable(
      dailyRaw.map(AdminDashboardDailyPoint.decode),
    );
    for (var index = 0; index < daily.length; index++) {
      final expected = DateTime.utc(start.year, start.month, start.day + index);
      if (daily[index].day != expected) throw _malformed();
    }
    if (end != DateTime.utc(start.year, start.month, start.day + 30)) {
      throw _malformed();
    }

    final plansRaw = root['finalPreviewsByPlan30d'];
    if (plansRaw is! List ||
        plansRaw.length != SubscriptionPlanCode.values.length) {
      throw _malformed();
    }
    final plans = <SubscriptionPlanCode, int>{};
    for (final value in plansRaw) {
      final row = _objectValue(value);
      final code = row['planCode'];
      final plan = code is String ? SubscriptionPlanCode.fromCode(code) : null;
      if (plan == null || plans.containsKey(plan)) throw _malformed();
      plans[plan] = _count(row, 'delivered');
    }
    if (plans.length != SubscriptionPlanCode.values.length) throw _malformed();

    return AdminDashboardV2Metrics(
      asOf: _timestamp(root, 'asOf'),
      reportingTimezone: root['reportingTimezone']! as String,
      todayStartsAt: _timestamp(root, 'todayStartsAt'),
      window30dStart: start,
      window30dEnd: end,
      committedDaily: daily,
      finalPreviewsByPlan30d: Map.unmodifiable(plans),
      finalPreviewsUnattributed30d: _count(
        root,
        'finalPreviewsUnattributed30d',
      ),
      committedTodayByUnit: CommittedByUnit.decode(
        root['committedTodayByUnit'],
      ),
      entitlementStatusDistribution: EntitlementStatusDistribution.decode(
        root['entitlementStatusDistribution'],
      ),
    );
  }
}

class AdminDashboardDailyPoint {
  const AdminDashboardDailyPoint({
    required this.day,
    required this.aiLook,
    required this.finalPreviewCredit,
    required this.unattributed,
  });

  final DateTime day;
  final int aiLook;
  final int finalPreviewCredit;
  final int unattributed;

  static AdminDashboardDailyPoint decode(Object? payload) {
    final value = _objectValue(payload);
    final dayValue = value['day'];
    final day = dayValue is String ? _dateOnly(dayValue) : null;
    if (day == null) throw _malformed();
    return AdminDashboardDailyPoint(
      day: day,
      aiLook: _count(value, 'aiLook'),
      finalPreviewCredit: _count(value, 'finalPreviewCredit'),
      unattributed: _count(value, 'unattributed'),
    );
  }
}

class CommittedByUnit {
  const CommittedByUnit({
    required this.aiLook,
    required this.finalPreviewCredit,
    required this.unattributed,
  });

  final int aiLook;
  final int finalPreviewCredit;
  final int unattributed;

  static CommittedByUnit decode(Object? payload) {
    final value = _objectValue(payload);
    return CommittedByUnit(
      aiLook: _count(value, 'aiLook'),
      finalPreviewCredit: _count(value, 'finalPreviewCredit'),
      unattributed: _count(value, 'unattributed'),
    );
  }
}

class EntitlementStatusDistribution {
  const EntitlementStatusDistribution({
    required this.total,
    required this.byStoredStatus,
    required this.byEffectiveStatus,
  });

  final int total;
  final Map<EntitlementStatus, int> byStoredStatus;
  final Map<EntitlementStatus, int> byEffectiveStatus;

  static EntitlementStatusDistribution decode(Object? payload) {
    final value = _objectValue(payload);
    final total = _count(value, 'total');
    final stored = _statusCounts(value['byStoredStatus']);
    final effective = _statusCounts(value['byEffectiveStatus']);
    if (_sum(stored.values) != total || _sum(effective.values) != total) {
      throw _malformed();
    }
    return EntitlementStatusDistribution(
      total: total,
      byStoredStatus: stored,
      byEffectiveStatus: effective,
    );
  }

  static Map<EntitlementStatus, int> _statusCounts(Object? payload) {
    final value = _objectValue(payload);
    if (value.length != EntitlementStatus.values.length) throw _malformed();
    final result = <EntitlementStatus, int>{};
    for (final status in EntitlementStatus.values) {
      if (!value.containsKey(status.code)) throw _malformed();
      result[status] = _count(value, status.code);
    }
    if (value.keys.any((key) => EntitlementStatus.fromCode(key) == null)) {
      throw _malformed();
    }
    return Map.unmodifiable(result);
  }
}

int _sum(Iterable<int> values) => values.fold(0, (sum, value) => sum + value);

AdminAuthFailure _malformed() => const AdminAuthFailure(
  SubscriptionErrorCode.temporaryBackendFailure,
  retryable: true,
);

Map<String, Object?> _stringKeyed(Map<Object?, Object?> map) =>
    map.map((key, value) => MapEntry(key.toString(), value));

Map<String, Object?> _objectValue(Object? value) {
  if (value is! Map) throw _malformed();
  return _stringKeyed(value);
}

int _count(Map<String, Object?> parent, String key) {
  final value = parent[key];
  if (value is int && value >= 0) return value;
  if (value is num && value >= 0 && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw _malformed();
}

DateTime _timestamp(Map<String, Object?> parent, String key) {
  final value = parent[key];
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw _malformed();
  return parsed.toUtc();
}

DateTime? _dateOnly(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null ||
      parsed.year.toString().padLeft(4, '0') != match.group(1) ||
      parsed.month.toString().padLeft(2, '0') != match.group(2) ||
      parsed.day.toString().padLeft(2, '0') != match.group(3)) {
    return null;
  }
  return parsed;
}
