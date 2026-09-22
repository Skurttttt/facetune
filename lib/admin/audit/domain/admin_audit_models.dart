import '../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_wire.dart' as wire;

enum AdminAuditSource {
  admin('admin', 'Admin'),
  provider('provider', 'Provider'),
  system('system', 'System');

  const AdminAuditSource(this.code, this.label);
  final String code;
  final String label;

  static AdminAuditSource? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

enum AdminAuditAction {
  grantSalonPilot('grant_salon_pilot', 'Salon Pilot granted'),
  increaseAllowance('increase_allowance', 'Allowance increased'),
  decreaseAllowance('decrease_allowance', 'Allowance decreased'),
  extendExpiration('extend_expiration', 'Expiration extended'),
  suspendEntitlement('suspend_entitlement', 'Entitlement suspended'),
  reactivateEntitlement('reactivate_entitlement', 'Entitlement reactivated'),
  revokeEntitlement('revoke_entitlement', 'Entitlement revoked');

  const AdminAuditAction(this.code, this.label);
  final String code;
  final String label;

  static AdminAuditAction? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

class AdminEntitlementStateSnapshot {
  const AdminEntitlementStateSnapshot({
    required this.status,
    required this.planCode,
    required this.effectiveAllowance,
    required this.allowanceAdjustmentTotal,
    required this.expiresAt,
    required this.version,
  });

  final EntitlementStatus? status;
  final SubscriptionPlanCode? planCode;
  final int? effectiveAllowance;
  final int? allowanceAdjustmentTotal;
  final DateTime? expiresAt;
  final int? version;

  static AdminEntitlementStateSnapshot? decodeNullable(Object? payload) {
    if (payload == null) return null;
    final value = wire.object(payload);
    return AdminEntitlementStateSnapshot(
      status: wire.nullableVocabulary(
        value,
        'status',
        EntitlementStatus.fromCode,
      ),
      planCode: wire.nullableVocabulary(
        value,
        'planCode',
        SubscriptionPlanCode.fromCode,
      ),
      effectiveAllowance: _nullableInt(value, 'effectiveAllowance'),
      allowanceAdjustmentTotal: _nullableInt(value, 'allowanceAdjustmentTotal'),
      expiresAt: wire.nullableDate(value, 'expiresAt'),
      version: _nullableInt(value, 'version'),
    );
  }
}

class AdminAuditListItem {
  const AdminAuditListItem({
    required this.id,
    required this.source,
    required this.adminUserId,
    required this.adminEmail,
    required this.action,
    required this.targetUserId,
    required this.targetEmail,
    required this.targetEntitlementId,
    required this.createdAt,
  });

  final String id;
  final AdminAuditSource source;
  final String? adminUserId;
  final String? adminEmail;
  final AdminAuditAction action;
  final String targetUserId;
  final String? targetEmail;
  final String? targetEntitlementId;
  final DateTime createdAt;

  static AdminAuditListItem decode(Object? payload) {
    final value = wire.object(payload);
    return AdminAuditListItem(
      id: wire.string(value, 'id'),
      source: wire.vocabulary(value, 'source', AdminAuditSource.fromCode),
      adminUserId: wire.nullableString(value, 'adminUserId'),
      adminEmail: wire.nullableString(value, 'adminEmail'),
      action: wire.vocabulary(value, 'action', AdminAuditAction.fromCode),
      targetUserId: wire.string(value, 'targetUserId'),
      targetEmail: wire.nullableString(value, 'targetEmail'),
      targetEntitlementId: wire.nullableString(value, 'targetEntitlementId'),
      createdAt: wire.date(value, 'createdAt'),
    );
  }

  static AdminListPage<AdminAuditListItem> decodePage(Object? payload) {
    final value = wire.listEnvelope(payload);
    return AdminListPage(
      items: List.unmodifiable((value['items'] as List).map(decode)),
      nextCursor: wire.nullableString(value, 'nextCursor'),
    );
  }
}

class AdminAuditDetail extends AdminAuditListItem {
  const AdminAuditDetail({
    required super.id,
    required super.source,
    required super.adminUserId,
    required super.adminEmail,
    required super.action,
    required super.targetUserId,
    required super.targetEmail,
    required super.targetEntitlementId,
    required super.createdAt,
    required this.beforeState,
    required this.afterState,
    required this.reason,
    required this.requestCorrelationId,
    required this.idempotencyKey,
  });

  final AdminEntitlementStateSnapshot? beforeState;
  final AdminEntitlementStateSnapshot? afterState;
  final String? reason;
  final String? requestCorrelationId;
  final String? idempotencyKey;

  static AdminAuditDetail? decodeEnvelope(Object? payload) {
    final envelope = wire.object(payload);
    if (envelope['ok'] != true ||
        envelope['contractVersion'] != wire.adminContractVersion ||
        !envelope.containsKey('event')) {
      wire.malformed();
    }
    final raw = envelope['event'];
    if (raw == null) return null;
    final value = wire.object(raw);
    final summary = AdminAuditListItem.decode(raw);
    return AdminAuditDetail(
      id: summary.id,
      source: summary.source,
      adminUserId: summary.adminUserId,
      adminEmail: summary.adminEmail,
      action: summary.action,
      targetUserId: summary.targetUserId,
      targetEmail: summary.targetEmail,
      targetEntitlementId: summary.targetEntitlementId,
      createdAt: summary.createdAt,
      beforeState: AdminEntitlementStateSnapshot.decodeNullable(
        value['beforeState'],
      ),
      afterState: AdminEntitlementStateSnapshot.decodeNullable(
        value['afterState'],
      ),
      reason: wire.nullableString(value, 'reason'),
      requestCorrelationId: wire.nullableString(value, 'requestCorrelationId'),
      idempotencyKey: wire.nullableString(value, 'idempotencyKey'),
    );
  }
}

enum AdminAuditDateRange {
  last24Hours(Duration(hours: 24), 'Last 24 hours'),
  last7Days(Duration(days: 7), 'Last 7 days'),
  last30Days(Duration(days: 30), 'Last 30 days');

  const AdminAuditDateRange(this.lookBack, this.label);
  final Duration lookBack;
  final String label;
}

class AdminAuditFilters {
  const AdminAuditFilters({
    this.adminUserId,
    this.action,
    this.targetUserId,
    this.targetEntitlementId,
    this.source,
    this.dateRange,
    this.fromInclusive,
  }) : assert(
         (dateRange == null) == (fromInclusive == null),
         'a date range and its resolved instant are set together',
       );

  factory AdminAuditFilters.withRange(
    AdminAuditFilters filters,
    AdminAuditDateRange? range, {
    required DateTime now,
  }) => AdminAuditFilters(
    adminUserId: filters.adminUserId,
    action: filters.action,
    targetUserId: filters.targetUserId,
    targetEntitlementId: filters.targetEntitlementId,
    source: filters.source,
    dateRange: range,
    fromInclusive: range == null ? null : now.toUtc().subtract(range.lookBack),
  );

  static const none = AdminAuditFilters();

  final String? adminUserId;
  final AdminAuditAction? action;
  final String? targetUserId;
  final String? targetEntitlementId;
  final AdminAuditSource? source;
  final AdminAuditDateRange? dateRange;
  final DateTime? fromInclusive;

  Map<String, Object?> toRpcParams() => {
    'p_admin_user_id': adminUserId,
    'p_action': action?.code,
    'p_target_user_id': targetUserId,
    'p_from': fromInclusive?.toUtc().toIso8601String(),
    'p_to': null,
    'p_target_entitlement_id': targetEntitlementId,
    'p_source': source?.code,
  };

  @override
  bool operator ==(Object other) =>
      other is AdminAuditFilters &&
      other.adminUserId == adminUserId &&
      other.action == action &&
      other.targetUserId == targetUserId &&
      other.targetEntitlementId == targetEntitlementId &&
      other.source == source &&
      other.dateRange == dateRange &&
      other.fromInclusive == fromInclusive;

  @override
  int get hashCode => Object.hash(
    adminUserId,
    action,
    targetUserId,
    targetEntitlementId,
    source,
    dateRange,
    fromInclusive,
  );
}

enum AdminEntitlementHistoryEventType {
  grantSalonPilot('grant_salon_pilot'),
  increaseAllowance('increase_allowance'),
  decreaseAllowance('decrease_allowance'),
  extendExpiration('extend_expiration'),
  suspendEntitlement('suspend_entitlement'),
  reactivateEntitlement('reactivate_entitlement'),
  revokeEntitlement('revoke_entitlement'),
  providerStateChange('provider_state_change');

  const AdminEntitlementHistoryEventType(this.code);
  final String code;

  static AdminEntitlementHistoryEventType? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

class AdminEntitlementHistoryEvent {
  const AdminEntitlementHistoryEvent({
    required this.id,
    required this.source,
    required this.eventType,
    required this.action,
    required this.actorUserId,
    required this.actorEmail,
    required this.reason,
    required this.beforeState,
    required this.afterState,
    required this.requestCorrelationId,
    required this.provider,
    required this.occurredAt,
  });

  final String id;
  final AdminAuditSource source;
  final AdminEntitlementHistoryEventType eventType;
  final AdminAuditAction? action;
  final String? actorUserId;
  final String? actorEmail;
  final String? reason;
  final AdminEntitlementStateSnapshot? beforeState;
  final AdminEntitlementStateSnapshot? afterState;
  final String? requestCorrelationId;
  final BillingProvider? provider;
  final DateTime occurredAt;

  static AdminEntitlementHistoryEvent decode(Object? payload) {
    final value = wire.object(payload);
    final source = wire.vocabulary(value, 'source', AdminAuditSource.fromCode);
    final eventType = wire.vocabulary(
      value,
      'eventType',
      AdminEntitlementHistoryEventType.fromCode,
    );
    final action = wire.nullableVocabulary(
      value,
      'action',
      AdminAuditAction.fromCode,
    );
    if ((source == AdminAuditSource.admin && action == null) ||
        (source == AdminAuditSource.provider &&
            eventType !=
                AdminEntitlementHistoryEventType.providerStateChange)) {
      wire.malformed();
    }
    return AdminEntitlementHistoryEvent(
      id: wire.string(value, 'id'),
      source: source,
      eventType: eventType,
      action: action,
      actorUserId: wire.nullableString(value, 'actorUserId'),
      actorEmail: wire.nullableString(value, 'actorEmail'),
      reason: wire.nullableString(value, 'reason'),
      beforeState: AdminEntitlementStateSnapshot.decodeNullable(
        value['beforeState'],
      ),
      afterState: AdminEntitlementStateSnapshot.decodeNullable(
        value['afterState'],
      ),
      requestCorrelationId: wire.nullableString(value, 'requestCorrelationId'),
      provider: wire.nullableVocabulary(
        value,
        'provider',
        BillingProvider.fromCode,
      ),
      occurredAt: wire.date(value, 'occurredAt'),
    );
  }

  static AdminListPage<AdminEntitlementHistoryEvent> decodePage(
    Object? payload,
  ) {
    final value = wire.listEnvelope(payload);
    return AdminListPage(
      items: List.unmodifiable((value['items'] as List).map(decode)),
      nextCursor: wire.nullableString(value, 'nextCursor'),
    );
  }
}

int? _nullableInt(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) wire.malformed();
  final field = value[key];
  if (field == null) return null;
  if (field is! int) wire.malformed();
  return field;
}
