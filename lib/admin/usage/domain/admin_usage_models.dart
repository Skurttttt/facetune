import '../../../features/subscription/domain/entities/allowance_unit.dart';
import '../../../features/subscription/domain/entities/purchased_credit_summary.dart'
    show AllowanceSource;
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../../features/subscription/domain/entities/usage_status.dart';
import '../../../features/subscription/domain/entities/usage_type.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_wire.dart' as wire;

/// Which pipeline produced a committed row's canonical Final Preview
/// (`usage_ledger.source_mode`). Set at commit, never cleared; null for
/// reserved and released rows.
enum AdminPreviewSourceMode {
  standard('standard', 'Standard Mode'),
  makeupKit('makeup_kit', 'My Makeup Kit');

  const AdminPreviewSourceMode(this.code, this.label);

  final String code;
  final String label;

  static AdminPreviewSourceMode? fromCode(String code) {
    for (final mode in values) {
      if (mode.code == code) return mode;
    }
    return null;
  }
}

/// One sanitized `usage_ledger` row, exactly as `admin_list_usage` returns it.
class AdminUsageListItem {
  const AdminUsageListItem({
    required this.usageId,
    required this.userId,
    required this.email,
    required this.entitlementId,
    required this.usageType,
    required this.operationId,
    required this.status,
    required this.planCode,
    required this.allowanceUnit,
    required this.allowanceSource,
    required this.sourceMode,
    required this.canonicalPreviewRetained,
    required this.periodStart,
    required this.periodEnd,
    required this.reservedAt,
    required this.committedAt,
    required this.releasedAt,
    required this.sanitizedFailureCode,
    required this.createdAt,
    required this.updatedAt,
  });

  final String usageId;
  final String userId;
  final String? email;
  final String entitlementId;
  final UsageType usageType;
  final String operationId;
  final UsageStatus status;
  final SubscriptionPlanCode? planCode;
  final AllowanceUnit? allowanceUnit;
  final AllowanceSource allowanceSource;
  final AdminPreviewSourceMode? sourceMode;
  final bool? canonicalPreviewRetained;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime reservedAt;
  final DateTime? committedAt;
  final DateTime? releasedAt;
  final String? sanitizedFailureCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  static AdminUsageListItem decode(Object? payload) {
    final v = wire.object(payload);
    final status = wire.vocabulary(v, 'status', UsageStatus.fromCode);
    final committedAt = wire.nullableDate(v, 'committedAt');
    final releasedAt = wire.nullableDate(v, 'releasedAt');
    final failureCode = wire.nullableString(v, 'sanitizedFailureCode');
    // The ledger's own invariants (usage_ledger_status_timestamps,
    // usage_ledger_failure_code_scoped). A row that violates them is not a
    // ledger row this client understands.
    final consistent = switch (status) {
      UsageStatus.reserved =>
        committedAt == null && releasedAt == null && failureCode == null,
      UsageStatus.committed =>
        committedAt != null && releasedAt == null && failureCode == null,
      UsageStatus.released => releasedAt != null && committedAt == null,
    };
    if (!consistent) wire.malformed();

    return AdminUsageListItem(
      usageId: wire.string(v, 'usageId'),
      userId: wire.string(v, 'userId'),
      email: wire.nullableString(v, 'email'),
      entitlementId: wire.string(v, 'entitlementId'),
      usageType: wire.vocabulary(v, 'usageType', UsageType.fromCode),
      operationId: wire.string(v, 'operationId'),
      status: status,
      planCode: wire.nullableVocabulary(
        v,
        'planCode',
        SubscriptionPlanCode.fromCode,
      ),
      allowanceUnit: wire.nullableVocabulary(
        v,
        'allowanceUnit',
        AllowanceUnit.fromCode,
      ),
      allowanceSource: wire.vocabulary(
        v,
        'allowanceSource',
        AllowanceSource.fromCode,
      ),
      sourceMode: wire.nullableVocabulary(
        v,
        'sourceMode',
        AdminPreviewSourceMode.fromCode,
      ),
      canonicalPreviewRetained: wire.nullableBool(
        v,
        'canonicalPreviewRetained',
      ),
      periodStart: wire.nullableDate(v, 'periodStart'),
      periodEnd: wire.nullableDate(v, 'periodEnd'),
      reservedAt: wire.date(v, 'reservedAt'),
      committedAt: committedAt,
      releasedAt: releasedAt,
      sanitizedFailureCode: failureCode,
      createdAt: wire.date(v, 'createdAt'),
      updatedAt: wire.date(v, 'updatedAt'),
    );
  }

  static AdminListPage<AdminUsageListItem> decodePage(Object? payload) {
    final v = wire.listEnvelope(payload);
    return AdminListPage(
      items: List.unmodifiable((v['items'] as List).map(decode)),
      nextCursor: wire.nullableString(v, 'nextCursor'),
    );
  }
}

/// A `created_at` window expressed as a duration back from the moment the
/// filters are applied. It is resolved to one concrete instant at that moment
/// ([AdminUsageFilters.fromInclusive]) and that instant is sent with every
/// page of the result: the server binds a cursor to the exact filters it was
/// issued for, so the window must not move between pages.
enum AdminUsageDateRange {
  last24Hours(Duration(hours: 24), 'Last 24 hours'),
  last7Days(Duration(days: 7), 'Last 7 days'),
  last30Days(Duration(days: 30), 'Last 30 days');

  const AdminUsageDateRange(this.lookBack, this.label);

  final Duration lookBack;
  final String label;
}

/// The Usage list filters. Value-equal so it can key a provider family.
class AdminUsageFilters {
  const AdminUsageFilters({
    this.userId,
    this.entitlementId,
    this.status,
    this.planCode,
    this.allowanceSource,
    this.dateRange,
    this.fromInclusive,
  }) : assert(
         (dateRange == null) == (fromInclusive == null),
         'a date range and its resolved instant are set together',
       );

  /// [filters] with [range] resolved against [now].
  factory AdminUsageFilters.withRange(
    AdminUsageFilters filters,
    AdminUsageDateRange? range, {
    required DateTime now,
  }) => AdminUsageFilters(
    userId: filters.userId,
    entitlementId: filters.entitlementId,
    status: filters.status,
    planCode: filters.planCode,
    allowanceSource: filters.allowanceSource,
    dateRange: range,
    fromInclusive: range == null ? null : now.toUtc().subtract(range.lookBack),
  );

  static const none = AdminUsageFilters();

  final String? userId;
  final String? entitlementId;
  final UsageStatus? status;
  final SubscriptionPlanCode? planCode;
  final AllowanceSource? allowanceSource;
  final AdminUsageDateRange? dateRange;

  /// The resolved lower bound on `created_at`; null exactly when [dateRange] is.
  final DateTime? fromInclusive;

  bool get isEmpty =>
      userId == null &&
      entitlementId == null &&
      status == null &&
      planCode == null &&
      allowanceSource == null &&
      dateRange == null;

  Map<String, Object?> toRpcParams() => {
    'p_user_id': userId,
    'p_entitlement_id': entitlementId,
    'p_status': status?.code,
    'p_plan_code': planCode?.code,
    'p_allowance_source': allowanceSource?.code,
    'p_from': fromInclusive?.toUtc().toIso8601String(),
    'p_to': null,
  };

  @override
  bool operator ==(Object other) =>
      other is AdminUsageFilters &&
      other.userId == userId &&
      other.entitlementId == entitlementId &&
      other.status == status &&
      other.planCode == planCode &&
      other.allowanceSource == allowanceSource &&
      other.dateRange == dateRange &&
      other.fromInclusive == fromInclusive;

  @override
  int get hashCode => Object.hash(
    userId,
    entitlementId,
    status,
    planCode,
    allowanceSource,
    dateRange,
    fromInclusive,
  );
}
