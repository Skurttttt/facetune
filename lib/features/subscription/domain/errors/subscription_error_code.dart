/// The sanitized, shared error vocabulary for subscription and entitlement
/// operations.
///
/// One enum serves both a thrown `SubscriptionFailure` and a returned
/// `GenerationDenied` decision, so a refusal means the same thing whether it
/// arrives as an error or as an answer. Two parallel vocabularies would drift.
///
/// These codes are sanitized by design. They never carry SQL state, provider
/// payloads, tokens, storage paths, or internal quota figures — a client and a
/// future Web Admin both see only the stable code and a user-facing message.
enum SubscriptionErrorCode {
  // Identity and authorization.
  authRequired('AUTH_REQUIRED'),
  adminUnauthorized('ADMIN_UNAUTHORIZED'),

  // Entitlement resolution.
  entitlementNotFound('ENTITLEMENT_NOT_FOUND'),
  entitlementPending('ENTITLEMENT_PENDING'),
  entitlementInactive('ENTITLEMENT_INACTIVE'),
  entitlementExpired('ENTITLEMENT_EXPIRED'),
  entitlementSuspended('ENTITLEMENT_SUSPENDED'),
  entitlementRevoked('ENTITLEMENT_REVOKED'),

  // AI Look capacity and the usage ledger.
  aiLookLimitReached('AI_LOOK_LIMIT_REACHED'),
  aiLookReservationConflict('AI_LOOK_RESERVATION_CONFLICT'),
  usageOperationNotFound('USAGE_OPERATION_NOT_FOUND'),
  usageAlreadyCommitted('USAGE_ALREADY_COMMITTED'),
  usageAlreadyReleased('USAGE_ALREADY_RELEASED'),
  usageStateConflict('USAGE_STATE_CONFLICT'),

  // Plan, transition, and allowance validation.
  invalidPlanCode('INVALID_PLAN_CODE'),
  invalidEntitlementTransition('INVALID_ENTITLEMENT_TRANSITION'),
  invalidAllowanceAdjustment('INVALID_ALLOWANCE_ADJUSTMENT'),
  allowanceBelowCommittedUsage('ALLOWANCE_BELOW_COMMITTED_USAGE'),
  allowanceConflictsWithActiveReservation(
    'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
  ),

  // Salon Pilot.
  salonPilotAlreadyGranted('SALON_PILOT_ALREADY_GRANTED'),
  salonPilotExpired('SALON_PILOT_EXPIRED'),

  // Billing provider.
  purchaseVerificationFailed('PURCHASE_VERIFICATION_FAILED'),
  providerStateConflict('PROVIDER_STATE_CONFLICT'),

  // Idempotency and concurrency.
  idempotencyConflict('IDEMPOTENCY_CONFLICT'),
  concurrentModification('CONCURRENT_MODIFICATION'),

  // Transient.
  temporaryBackendFailure('TEMPORARY_BACKEND_FAILURE');

  const SubscriptionErrorCode(this.code);

  /// The stable wire identifier.
  final String code;

  /// Returns the error code for [code], or `null` when [code] is outside the
  /// controlled vocabulary.
  ///
  /// An unknown code from a newer backend must be handled as an unrecognised
  /// failure, never quietly mapped onto a known one.
  static SubscriptionErrorCode? fromCode(String code) {
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }
}
