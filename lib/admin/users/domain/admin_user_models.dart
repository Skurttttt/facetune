import '../../../features/subscription/domain/entities/allowance_unit.dart';
import '../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import 'admin_account_status.dart';
import 'admin_users_failure.dart';

const _adminContractVersion = 'subscription_admin_contract_v1.1';

/// One server-bounded row on the Users page.
class AdminUserSummary {
  const AdminUserSummary({
    required this.userId,
    required this.email,
    required this.accountCreatedAt,
    required this.accountStatus,
    required this.currentPlanCode,
    required this.currentPlanDisplayName,
    required this.entitlementStatus,
    required this.remainingAiLooks,
    required this.allowanceUnit,
    required this.periodEnd,
    required this.expiresAt,
    required this.autoRenew,
  });

  final String userId;
  final String? email;
  final DateTime accountCreatedAt;
  final AdminAccountStatus accountStatus;
  final SubscriptionPlanCode? currentPlanCode;
  final String? currentPlanDisplayName;
  final EntitlementStatus? entitlementStatus;
  final int? remainingAiLooks;
  final AllowanceUnit? allowanceUnit;
  final DateTime? periodEnd;
  final DateTime? expiresAt;
  final bool? autoRenew;

  static AdminUserSummary decode(Object? payload) {
    final value = _object(payload);
    return AdminUserSummary(
      userId: _string(value, 'userId'),
      email: _nullableString(value, 'email'),
      accountCreatedAt: _date(value, 'accountCreatedAt'),
      accountStatus: _enum(value, 'accountStatus', AdminAccountStatus.fromCode),
      currentPlanCode: _nullableEnum(
        value,
        'currentPlanCode',
        SubscriptionPlanCode.fromCode,
      ),
      currentPlanDisplayName: _nullableString(value, 'currentPlanDisplayName'),
      entitlementStatus: _nullableEnum(
        value,
        'entitlementStatus',
        EntitlementStatus.fromCode,
      ),
      remainingAiLooks: _nullableInt(value, 'remainingAiLooks'),
      allowanceUnit: _nullableEnum(
        value,
        'allowanceUnit',
        AllowanceUnit.fromCode,
      ),
      periodEnd: _nullableDate(value, 'periodEnd'),
      expiresAt: _nullableDate(value, 'expiresAt'),
      autoRenew: _nullableBool(value, 'autoRenew'),
    );
  }
}

class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.nextCursor,
    required this.pageSize,
  });

  final List<AdminUserSummary> items;
  final String? nextCursor;
  final int pageSize;

  static AdminUserPage decode(Object? payload) {
    final value = _object(payload);
    final rawItems = value['items'];
    final pageSize = value['pageSize'];
    final sort = _object(value['sort']);
    if (value['ok'] != true ||
        value['contractVersion'] != _adminContractVersion ||
        rawItems is! List ||
        pageSize is! int ||
        pageSize != 25 ||
        sort['field'] != 'accountCreatedAt' ||
        sort['direction'] != 'desc') {
      throw const AdminUsersFailure(
        AdminUsersFailureType.unavailable,
        retryable: true,
      );
    }
    return AdminUserPage(
      items: List.unmodifiable(rawItems.map(AdminUserSummary.decode)),
      nextCursor: _nullableString(value, 'nextCursor'),
      pageSize: pageSize,
    );
  }
}

class AdminEntitlementDetail {
  const AdminEntitlementDetail({
    required this.entitlementId,
    required this.planCode,
    required this.planDisplayName,
    required this.storedStatus,
    required this.effectiveStatus,
    required this.billingProvider,
    required this.allowanceUnit,
    required this.effectiveAllowance,
    required this.committedUsage,
    required this.reservedUsage,
    required this.availableAiLooks,
    required this.remainingAiLooks,
    required this.periodStart,
    required this.periodEnd,
    required this.startsAt,
    required this.expiresAt,
    required this.autoRenew,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  final String entitlementId;
  final SubscriptionPlanCode planCode;
  final String planDisplayName;
  final EntitlementStatus storedStatus;
  final EntitlementStatus effectiveStatus;
  final BillingProvider billingProvider;
  final AllowanceUnit allowanceUnit;
  final int effectiveAllowance;
  final int committedUsage;
  final int reservedUsage;
  final int availableAiLooks;
  final int remainingAiLooks;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final bool autoRenew;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;

  static AdminEntitlementDetail decode(Object? payload) {
    final value = _object(payload);
    return AdminEntitlementDetail(
      entitlementId: _string(value, 'entitlementId'),
      planCode: _enum(value, 'planCode', SubscriptionPlanCode.fromCode),
      planDisplayName: _string(value, 'planDisplayName'),
      storedStatus: _enum(value, 'storedStatus', EntitlementStatus.fromCode),
      effectiveStatus: _enum(
        value,
        'effectiveStatus',
        EntitlementStatus.fromCode,
      ),
      billingProvider: _enum(
        value,
        'billingProvider',
        BillingProvider.fromCode,
      ),
      allowanceUnit: _enum(value, 'allowanceUnit', AllowanceUnit.fromCode),
      effectiveAllowance: _nonNegativeInt(value, 'effectiveAllowance'),
      committedUsage: _nonNegativeInt(value, 'committedUsage'),
      reservedUsage: _nonNegativeInt(value, 'reservedUsage'),
      availableAiLooks: _nonNegativeInt(value, 'availableAiLooks'),
      remainingAiLooks: _nonNegativeInt(value, 'remainingAiLooks'),
      periodStart: _nullableDate(value, 'periodStart'),
      periodEnd: _nullableDate(value, 'periodEnd'),
      startsAt: _date(value, 'startsAt'),
      expiresAt: _nullableDate(value, 'expiresAt'),
      autoRenew: _bool(value, 'autoRenew'),
      version: _nonNegativeInt(value, 'version'),
      createdAt: _date(value, 'createdAt'),
      updatedAt: _date(value, 'updatedAt'),
    );
  }
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.userId,
    required this.email,
    required this.accountCreatedAt,
    required this.accountStatus,
    required this.entitlement,
  });

  final String userId;
  final String? email;
  final DateTime accountCreatedAt;
  final AdminAccountStatus accountStatus;
  final AdminEntitlementDetail? entitlement;

  static AdminUserDetail decode(Object? payload) {
    final root = _object(payload);
    if (root['ok'] != true ||
        root['contractVersion'] != _adminContractVersion) {
      throw _malformed();
    }
    final user = _object(root['user']);
    final rawEntitlement = root['entitlement'];
    return AdminUserDetail(
      userId: _string(user, 'userId'),
      email: _nullableString(user, 'email'),
      accountCreatedAt: _date(user, 'accountCreatedAt'),
      accountStatus: _enum(user, 'accountStatus', AdminAccountStatus.fromCode),
      entitlement: rawEntitlement == null
          ? null
          : AdminEntitlementDetail.decode(rawEntitlement),
    );
  }
}

Map<String, Object?> _object(Object? payload) {
  if (payload is! Map) throw _malformed();
  return payload.map((key, value) => MapEntry(key.toString(), value));
}

Never _malformed() => throw const AdminUsersFailure(
  AdminUsersFailureType.unavailable,
  retryable: true,
);

String _string(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is String && field.isNotEmpty ? field : _malformed();
}

String? _nullableString(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return _malformed();
  final field = value[key];
  return field == null
      ? null
      : field is String
      ? field
      : _malformed();
}

int _nonNegativeInt(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is int && field >= 0 ? field : _malformed();
}

int? _nullableInt(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return _malformed();
  final field = value[key];
  return field == null
      ? null
      : field is int && field >= 0
      ? field
      : _malformed();
}

bool _bool(Map<String, Object?> value, String key) {
  final field = value[key];
  return field is bool ? field : _malformed();
}

bool? _nullableBool(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return _malformed();
  final field = value[key];
  return field == null
      ? null
      : field is bool
      ? field
      : _malformed();
}

DateTime _date(Map<String, Object?> value, String key) {
  final field = value[key];
  final parsed = field is String ? DateTime.tryParse(field) : null;
  return parsed == null ? _malformed() : parsed.toUtc();
}

DateTime? _nullableDate(Map<String, Object?> value, String key) {
  if (!value.containsKey(key)) return _malformed();
  final field = value[key];
  if (field == null) return null;
  return _date(value, key);
}

T _enum<T>(Map<String, Object?> value, String key, T? Function(String) decode) {
  final field = value[key];
  final parsed = field is String ? decode(field) : null;
  return parsed ?? _malformed();
}

T? _nullableEnum<T>(
  Map<String, Object?> value,
  String key,
  T? Function(String) decode,
) {
  if (!value.containsKey(key)) return _malformed();
  final field = value[key];
  if (field == null) return null;
  return field is String ? decode(field) ?? _malformed() : _malformed();
}
