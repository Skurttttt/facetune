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
  entitlementNotFound('ENTITLEMENT_NOT_FOUND'),
  entitlementExpired('ENTITLEMENT_EXPIRED'),
  entitlementRevoked('ENTITLEMENT_REVOKED'),
  invalidAllowanceAdjustment('INVALID_ALLOWANCE_ADJUSTMENT'),
  invalidEntitlementTransition('INVALID_ENTITLEMENT_TRANSITION'),
  allowanceBelowCommittedUsage('ALLOWANCE_BELOW_COMMITTED_USAGE'),
  allowanceConflictsWithActiveReservation(
    'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
  ),
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

// ---------------------------------------------------------------------------
// WA-8 — allowance adjustment
// ---------------------------------------------------------------------------

/// Quick actions the SOT recommends (§23). Custom amounts are typed.
const salonPilotQuickAdjustments = [5, 10];

/// What the admin intends: a signed, non-zero change to one entitlement's
/// allowance. Positive is `increase_allowance`, negative is
/// `decrease_allowance` (Shared Contract §43). [expectedVersion] is the
/// entitlement version the admin was looking at; the server refuses the
/// change if another writer moved it since (Web Admin SOT §47).
class AdjustAllowanceIntent {
  const AdjustAllowanceIntent({
    required this.entitlementId,
    required this.amount,
    required this.reason,
    required this.idempotencyKey,
    required this.expectedVersion,
  });

  final String entitlementId;
  final int amount;
  final String reason;
  final String idempotencyKey;
  final int? expectedVersion;

  bool get isIncrease => amount > 0;

  Map<String, Object?> toRequestBody() => {
    'entitlementId': entitlementId,
    'amount': amount,
    'reason': reason,
    'idempotencyKey': idempotencyKey,
    'expectedVersion': expectedVersion,
  };
}

/// The informational preview shown before confirmation (Web Admin SOT §25).
///
/// Mirrors the arithmetic the Shared Contract fixes (§29, §31, §44) over
/// figures the server already returned; it decides nothing. The server
/// recomputes under the account lock and may still refuse — the page shows
/// that refusal as the authoritative answer.
class AllowanceAdjustmentPreview {
  const AllowanceAdjustmentPreview({
    required this.currentEffectiveAllowance,
    required this.amount,
    required this.committedUsage,
    required this.reservedUsage,
  });

  final int currentEffectiveAllowance;
  final int amount;
  final int committedUsage;
  final int reservedUsage;

  int get newEffectiveAllowance => currentEffectiveAllowance + amount;

  /// Expected `remainingAiLooks` after the change (effective − committed).
  int get newRemaining => newEffectiveAllowance - committedUsage;

  /// Expected `availableAiLooks` after the change (effective − committed − reserved).
  int get newAvailable =>
      newEffectiveAllowance - committedUsage - reservedUsage;

  /// Whether the server's minimum (Shared Contract §44) would be met. Advisory.
  bool get coversCommittedUsage => newEffectiveAllowance >= committedUsage;
  bool get coversReservations =>
      newEffectiveAllowance >= committedUsage + reservedUsage;
}

// ---------------------------------------------------------------------------
// WA-9 — lifecycle: extend expiration, suspend, reactivate, revoke
// ---------------------------------------------------------------------------

/// The lifecycle actions (Shared Contract §45, §47–§50). Codes are the
/// contract's; labels and consequence text are presentation only.
enum SalonPilotLifecycleAction {
  extendExpiration(
    'extend_expiration',
    'Extend expiration',
    'Extend the pilot term to a later date. Access, allowance, and history '
        'are unchanged.',
    confirmLabel: 'Confirm extension',
    highRisk: false,
  ),
  suspend(
    'suspend_entitlement',
    'Suspend',
    'Blocks new premium AI generations for this entitlement until it is '
        'reactivated. The account, History, Saved Looks, existing Final '
        'Previews and Tutorials all remain.',
    confirmLabel: 'Suspend access',
    highRisk: false,
  ),
  reactivate(
    'reactivate_entitlement',
    'Reactivate',
    'Restores generation for a suspended pilot. The server allows this only '
        'while the pilot term has not ended.',
    confirmLabel: 'Reactivate access',
    highRisk: false,
  ),
  revoke(
    'revoke_entitlement',
    'Revoke access',
    'Terminates this entitlement permanently. This blocks new premium AI '
        'generations for this entitlement and cannot be undone; a later '
        'pilot would be a new grant. Existing History, Saved Looks, Final '
        'Previews, and Tutorials remain subject to normal retention rules.',
    confirmLabel: 'Revoke access',
    highRisk: true,
  );

  const SalonPilotLifecycleAction(
    this.code,
    this.label,
    this.consequence, {
    required this.confirmLabel,
    required this.highRisk,
  });

  final String code;
  final String label;
  final String consequence;
  final String confirmLabel;

  /// High-risk actions require the explicit acknowledgement (SOT §31, §44).
  final bool highRisk;

  static SalonPilotLifecycleAction? fromCode(String? code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}

/// What the admin intends. [newExpiresAt] is set only for an extension.
class LifecycleIntent {
  const LifecycleIntent({
    required this.action,
    required this.entitlementId,
    required this.reason,
    required this.idempotencyKey,
    required this.expectedVersion,
    this.newExpiresAt,
  }) : assert(
         (action == SalonPilotLifecycleAction.extendExpiration) ==
             (newExpiresAt != null),
         'an extension carries a date; nothing else does',
       );

  final SalonPilotLifecycleAction action;
  final String entitlementId;
  final String reason;
  final String idempotencyKey;
  final int? expectedVersion;
  final DateTime? newExpiresAt;

  Map<String, Object?> toRequestBody() => {
    'action': action.code,
    'entitlementId': entitlementId,
    'reason': reason,
    'idempotencyKey': idempotencyKey,
    'expectedVersion': expectedVersion,
    if (newExpiresAt != null)
      'newExpiresAt': newExpiresAt!.toUtc().toIso8601String(),
  };
}
