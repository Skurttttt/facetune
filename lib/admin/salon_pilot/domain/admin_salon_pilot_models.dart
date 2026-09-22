import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../../features/subscription/domain/entities/subscription_plan_code.dart';
import '../../shared/admin_wire.dart' as wire;

/// Salon Pilot default fixed by the Shared Contract (§32). The form proposes
/// it; the server validates whatever is actually submitted. A custom initial
/// allowance is any non-negative integer — no authority defines a business
/// maximum, so the form imposes none.
const salonPilotDefaultInitialAllowance = 30;
const adminReasonMaxLength = 500;

/// What the admin intends. This is the whole request body: no admin
/// identity, no before-state, no expected figures. The idempotency key is
/// minted once per intended grant and reused verbatim on every retry, so a
/// double submission can never create two grants.
class GrantSalonPilotIntent {
  const GrantSalonPilotIntent({
    required this.targetUserId,
    required this.expiresAt,
    required this.initialAllowance,
    required this.reason,
    required this.idempotencyKey,
  });

  final String targetUserId;
  final DateTime expiresAt;
  final int initialAllowance;
  final String reason;
  final String idempotencyKey;

  Map<String, Object?> toRequestBody() => {
    'targetUserId': targetUserId,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'initialAllowance': initialAllowance,
    'reason': reason,
    'idempotencyKey': idempotencyKey,
  };
}

/// The server's authoritative answer to a successful mutation (Shared
/// Contract §73). Every figure is the consumer resolver's, after the grant.
class AdminMutationOutcome {
  const AdminMutationOutcome({
    required this.action,
    required this.replayed,
    required this.entitlementId,
    required this.planCode,
    required this.status,
    required this.effectiveAllowance,
    required this.committedUsage,
    required this.reservedUsage,
    required this.availableAiLooks,
    required this.remainingAiLooks,
    required this.expiresAt,
    required this.updatedAt,
  });

  final String action;
  final bool replayed;
  final String entitlementId;
  final SubscriptionPlanCode planCode;
  final EntitlementStatus status;
  final int effectiveAllowance;
  final int committedUsage;
  final int reservedUsage;
  final int availableAiLooks;
  final int remainingAiLooks;
  final DateTime? expiresAt;
  final DateTime updatedAt;

  static AdminMutationOutcome decode(Object? payload) {
    final v = wire.object(payload);
    if (v['success'] != true ||
        v['contractVersion'] != wire.adminContractVersion) {
      wire.malformed();
    }
    return AdminMutationOutcome(
      action: wire.string(v, 'action'),
      replayed: wire.boolean(v, 'replayed'),
      entitlementId: wire.string(v, 'entitlementId'),
      planCode: wire.vocabulary(v, 'planCode', SubscriptionPlanCode.fromCode),
      status: wire.vocabulary(v, 'status', EntitlementStatus.fromCode),
      effectiveAllowance: wire.nonNegativeInt(v, 'effectiveAllowance'),
      committedUsage: wire.nonNegativeInt(v, 'committedUsage'),
      reservedUsage: wire.nonNegativeInt(v, 'reservedUsage'),
      availableAiLooks: wire.nonNegativeInt(v, 'availableAiLooks'),
      remainingAiLooks: wire.nonNegativeInt(v, 'remainingAiLooks'),
      expiresAt: wire.nullableDate(v, 'expiresAt'),
      updatedAt: wire.date(v, 'updatedAt'),
    );
  }
}

/// Sanitized outcomes a mutation can end in. Contract codes are mirrored by
/// name; anything the server sends outside this set is [unknown], which is
/// shown as a failure and never as a success.
enum AdminMutationErrorCode {
  invalidRequest('invalid_request'),
  userNotFound('USER_NOT_FOUND'),
  salonPilotAlreadyGranted('SALON_PILOT_ALREADY_GRANTED'),
  providerStateConflict('PROVIDER_STATE_CONFLICT'),
  idempotencyConflict('IDEMPOTENCY_CONFLICT'),
  concurrentModification('CONCURRENT_MODIFICATION'),
  temporaryBackendFailure('TEMPORARY_BACKEND_FAILURE'),
  unknown('UNKNOWN');

  const AdminMutationErrorCode(this.code);

  final String code;

  static AdminMutationErrorCode fromCode(String? code) {
    for (final value in values) {
      if (value != unknown && value.code == code) return value;
    }
    return unknown;
  }
}

/// A refused or failed mutation. [message] is the server's sanitized text
/// when it sent one; the page falls back to its own wording otherwise.
class AdminMutationFailure implements Exception {
  const AdminMutationFailure(
    this.code, {
    this.message,
    this.field,
    this.retryable = false,
  });

  final AdminMutationErrorCode code;
  final String? message;
  final String? field;
  final bool retryable;

  @override
  String toString() => 'AdminMutationFailure(${code.code})';
}
