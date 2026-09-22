import '../../../features/subscription/domain/entities/allowance_unit.dart';
import '../../../features/subscription/domain/entities/billing_provider.dart';
import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_wire.dart' as wire;

/// One row of the Entitlements list, exactly as `admin_list_entitlements`
/// returns it. Every figure is the server's; nothing here is derived.
class AdminEntitlementListItem {
  const AdminEntitlementListItem({
    required this.entitlementId,
    required this.userId,
    required this.email,
    required this.planCode,
    required this.planDisplayName,
    required this.storedStatus,
    required this.effectiveStatus,
    required this.billingProvider,
    required this.allowanceUnit,
    required this.baseAllowance,
    required this.allowanceAdjustmentTotal,
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
  final String userId;
  final String? email;
  final SubscriptionPlanCode planCode;
  final String planDisplayName;
  final EntitlementStatus storedStatus;
  final EntitlementStatus effectiveStatus;
  final BillingProvider billingProvider;
  final AllowanceUnit allowanceUnit;
  final int baseAllowance;
  final int allowanceAdjustmentTotal;
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

  static AdminEntitlementListItem decode(Object? payload) {
    final v = wire.object(payload);
    return AdminEntitlementListItem(
      entitlementId: wire.string(v, 'entitlementId'),
      userId: wire.string(v, 'userId'),
      email: wire.nullableString(v, 'email'),
      planCode: wire.vocabulary(v, 'planCode', SubscriptionPlanCode.fromCode),
      planDisplayName: wire.string(v, 'planDisplayName'),
      storedStatus: wire.vocabulary(
        v,
        'storedStatus',
        EntitlementStatus.fromCode,
      ),
      effectiveStatus: wire.vocabulary(
        v,
        'effectiveStatus',
        EntitlementStatus.fromCode,
      ),
      billingProvider: wire.vocabulary(
        v,
        'billingProvider',
        BillingProvider.fromCode,
      ),
      allowanceUnit: wire.vocabulary(
        v,
        'allowanceUnit',
        AllowanceUnit.fromCode,
      ),
      baseAllowance: wire.nonNegativeInt(v, 'baseAllowance'),
      allowanceAdjustmentTotal: wire.signedInt(v, 'allowanceAdjustmentTotal'),
      effectiveAllowance: wire.nonNegativeInt(v, 'effectiveAllowance'),
      committedUsage: wire.nonNegativeInt(v, 'committedUsage'),
      reservedUsage: wire.nonNegativeInt(v, 'reservedUsage'),
      availableAiLooks: wire.nonNegativeInt(v, 'availableAiLooks'),
      remainingAiLooks: wire.nonNegativeInt(v, 'remainingAiLooks'),
      periodStart: wire.nullableDate(v, 'periodStart'),
      periodEnd: wire.nullableDate(v, 'periodEnd'),
      startsAt: wire.date(v, 'startsAt'),
      expiresAt: wire.nullableDate(v, 'expiresAt'),
      autoRenew: wire.boolean(v, 'autoRenew'),
      version: wire.nonNegativeInt(v, 'version'),
      createdAt: wire.date(v, 'createdAt'),
      updatedAt: wire.date(v, 'updatedAt'),
    );
  }

  static AdminListPage<AdminEntitlementListItem> decodePage(Object? payload) {
    final v = wire.listEnvelope(payload);
    return AdminListPage(
      items: List.unmodifiable((v['items'] as List).map(decode)),
      nextCursor: wire.nullableString(v, 'nextCursor'),
    );
  }
}

/// The server-supported expiration windows (`p_expires_within_days`), on
/// `expires_at` against the server clock. The browser never sends a time.
enum AdminExpirationWindow {
  within7Days(7, 'Expires within 7 days'),
  within14Days(14, 'Expires within 14 days'),
  within30Days(30, 'Expires within 30 days');

  const AdminExpirationWindow(this.days, this.label);

  final int days;
  final String label;
}

/// The Entitlements list filters. Value-equal so it can key a provider
/// family and be compared against the server's echoed filters.
class AdminEntitlementFilters {
  const AdminEntitlementFilters({
    this.userId,
    this.planCode,
    this.status,
    this.billingProvider,
    this.expiration,
  });

  static const none = AdminEntitlementFilters();

  final String? userId;
  final SubscriptionPlanCode? planCode;
  final EntitlementStatus? status;
  final BillingProvider? billingProvider;
  final AdminExpirationWindow? expiration;

  bool get isEmpty =>
      userId == null &&
      planCode == null &&
      status == null &&
      billingProvider == null &&
      expiration == null;

  Map<String, Object?> toRpcParams() => {
    'p_user_id': userId,
    'p_plan_code': planCode?.code,
    'p_status': status?.code,
    'p_billing_provider': billingProvider?.code,
    'p_expires_within_days': expiration?.days,
  };

  @override
  bool operator ==(Object other) =>
      other is AdminEntitlementFilters &&
      other.userId == userId &&
      other.planCode == planCode &&
      other.status == status &&
      other.billingProvider == billingProvider &&
      other.expiration == expiration;

  @override
  int get hashCode =>
      Object.hash(userId, planCode, status, billingProvider, expiration);
}
