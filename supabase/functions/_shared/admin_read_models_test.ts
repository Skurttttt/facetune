import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  ADMIN_PAGE_SIZE_DEFAULT,
  ADMIN_PAGE_SIZE_MAX,
  boundedPageSize,
  decodeAdminMutationResult,
  decodeAllowanceAdjustment,
  decodeAuditEvent,
  decodeAuditEventSummary,
  decodeEntitlementHistoryEvent,
  decodePurchasedCreditGrant,
  type DecodeResult,
  decodeSubscriptionState,
  decodeUsageRecord,
  effectiveEntitlementStatus,
  previewAllowanceAdjustment,
  type SubscriptionState,
  toAdminEntitlementView,
} from "./admin_read_models.ts";

// ---------------------------------------------------------------------------
// Fixtures. The resolver payload carries exactly the 35 keys that
// `public.resolve_subscription_state()` (migration 20260923000100) emits.
// ---------------------------------------------------------------------------

const USER = "11111111-1111-4111-8111-111111111111";
const ENT = "22222222-2222-4222-8222-222222222222";
const T0 = "2026-09-21T00:00:00+00:00";
const T1 = "2026-12-21T00:00:00+00:00";

/** A Salon Pilot account: base 30, +10 adjusted, 18 committed, 0 reserved. */
function salonPilotPayload(overrides: Record<string, unknown> = {}) {
  return {
    hasEntitlement: true,
    entitlementId: ENT,
    planCode: "salon_pilot",
    planDisplayName: "Salon Pilot",
    entitlementStatus: "active",
    billingProvider: "admin_granted",
    providerProductId: null,
    publiclyPurchasable: false,
    allowanceUnit: "ai_look",
    tutorialEnabled: true,
    finalPreviewEnabled: true,
    periodStart: null,
    periodEnd: null,
    startsAt: T0,
    expiresAt: T1,
    autoRenew: false,
    resetPolicy: "none",
    resetAt: null,
    baseAllowance: 30,
    allowanceAdjustmentTotal: 10,
    effectiveAllowance: 40,
    committedUsage: 18,
    reservedUsage: 0,
    availableAiLooks: 22,
    remainingAiLooks: 22,
    generationAuthorized: true,
    denialReason: null,
    purchasedTutorialCreditsRemaining: 0,
    purchasedPreviewCreditsRemaining: 0,
    purchasedCreditsUsable: false,
    availablePurchasedCredits: 0,
    nextAllowanceSource: "subscription",
    nextAllowanceUnit: "ai_look",
    verifiedAt: null,
    resolvedAt: T0,
    ...overrides,
  };
}

function ok<T>(r: DecodeResult<T>): T {
  assert(r.ok, r.ok ? "" : `decode failed: ${r.reason} ${r.field}`);
  return r.value;
}
function failed<T>(r: DecodeResult<T>, field: string, reason: string) {
  assert(!r.ok, "expected a decode failure");
  assertEquals(r.field, field);
  assertEquals(r.reason, reason);
  assertEquals(r.errorCode, "TEMPORARY_BACKEND_FAILURE");
  // The failure names the field and the reason and nothing else: no raw
  // value from the payload can leak into a log through it.
  assertEquals(Object.keys(r).sort(), ["errorCode", "field", "ok", "reason"]);
}

// ---------------------------------------------------------------------------
// resolve_subscription_state() → SubscriptionState
// ---------------------------------------------------------------------------

Deno.test("decodes the full resolver payload key-for-key", () => {
  const s = ok(decodeSubscriptionState(salonPilotPayload()));
  assert(s.hasEntitlement);
  assertEquals(s.entitlementId, ENT);
  assertEquals(s.planCode, "salon_pilot");
  assertEquals(s.entitlementStatus, "active");
  assertEquals(s.billingProvider, "admin_granted");
  assertEquals(s.capability, {
    allowanceUnit: "ai_look",
    tutorialEnabled: true,
    finalPreviewEnabled: true,
    publiclyPurchasable: false,
  });
  assertEquals(s.allowance, {
    allowanceUnit: "ai_look",
    baseAllowance: 30,
    allowanceAdjustmentTotal: 10,
    effectiveAllowance: 40,
    committedUsage: 18,
    reservedUsage: 0,
    availableAiLooks: 22,
    remainingAiLooks: 22,
  });
  assertEquals(s.purchasedCredits, {
    purchasedTutorialCreditsRemaining: 0,
    purchasedPreviewCreditsRemaining: 0,
    purchasedCreditsUsable: false,
    availablePurchasedCredits: 0,
    nextAllowanceSource: "subscription",
    nextAllowanceUnit: "ai_look",
  });
  assertEquals(s.expiresAt, T1);
  assertEquals(s.periodStart, null);
  assertEquals(s.generationAuthorized, true);
  assertEquals(s.denialReason, null);
});

Deno.test("remaining-balance fields are copied from the server, never recomputed", () => {
  // Deliberately inconsistent figures. A decoder that "helpfully" derived
  // available = effective − committed − reserved would produce 22 here; the
  // contract (§75) says the server number is the number.
  const s = ok(decodeSubscriptionState(salonPilotPayload({
    effectiveAllowance: 40,
    committedUsage: 18,
    reservedUsage: 0,
    availableAiLooks: 7,
    remainingAiLooks: 9,
  })));
  assert(s.hasEntitlement);
  assertEquals(s.allowance.availableAiLooks, 7);
  assertEquals(s.allowance.remainingAiLooks, 9);
});

Deno.test("available and remaining are distinct fields with contract §30 semantics", () => {
  // Two reservations in flight: available drops, the user-facing remaining does not.
  const s = ok(decodeSubscriptionState(salonPilotPayload({
    reservedUsage: 2,
    availableAiLooks: 20,
    remainingAiLooks: 22,
  })));
  assert(s.hasEntitlement);
  assertEquals(s.allowance.reservedUsage, 2);
  assertEquals(s.allowance.availableAiLooks, 20);
  assertEquals(s.allowance.remainingAiLooks, 22);
});

Deno.test("a Preview-only paid plan decodes with its unit and capability", () => {
  const s = ok(decodeSubscriptionState(salonPilotPayload({
    planCode: "pro_preview",
    planDisplayName: "FaceTune Pro Preview",
    billingProvider: "google_play",
    providerProductId: "facetune_pro_preview",
    publiclyPurchasable: true,
    allowanceUnit: "final_preview_credit",
    tutorialEnabled: false,
    periodStart: T0,
    periodEnd: T1,
    expiresAt: null,
    autoRenew: true,
    resetPolicy: "billing_period",
    resetAt: T1,
    baseAllowance: 80,
    allowanceAdjustmentTotal: 0,
    effectiveAllowance: 80,
    committedUsage: 80,
    availableAiLooks: 0,
    remainingAiLooks: 0,
    purchasedPreviewCreditsRemaining: 10,
    purchasedCreditsUsable: true,
    availablePurchasedCredits: 10,
    nextAllowanceSource: "purchased_credit",
    nextAllowanceUnit: "final_preview_credit",
    verifiedAt: T0,
  })));
  assert(s.hasEntitlement);
  assertEquals(s.planCode, "pro_preview");
  assertEquals(s.capability.allowanceUnit, "final_preview_credit");
  assertEquals(s.capability.tutorialEnabled, false);
  assertEquals(s.resetAt, T1);
  // Purchased credits are reported beside, never inside, the allowance.
  assertEquals(s.allowance.availableAiLooks, 0);
  assertEquals(s.purchasedCredits.availablePurchasedCredits, 10);
  assertEquals(s.purchasedCredits.nextAllowanceSource, "purchased_credit");
});

Deno.test("an account without an entitlement row decodes to the absent shape", () => {
  const s = ok(decodeSubscriptionState({
    hasEntitlement: false,
    denialReason: "ENTITLEMENT_NOT_FOUND",
    resolvedAt: T0,
    planCode: "free",
    effectiveAllowance: 0,
  }));
  assertEquals(s, {
    hasEntitlement: false,
    denialReason: "ENTITLEMENT_NOT_FOUND",
    resolvedAt: T0,
  });
  const unauth = ok(decodeSubscriptionState({
    hasEntitlement: false,
    generationAuthorized: false,
    denialReason: "AUTH_REQUIRED",
    resolvedAt: T0,
  }));
  assertEquals(unauth.denialReason, "AUTH_REQUIRED");
});

Deno.test("a denied state carries its contract code", () => {
  const s = ok(decodeSubscriptionState(salonPilotPayload({
    generationAuthorized: false,
    denialReason: "SALON_PILOT_EXPIRED",
  })));
  assert(s.hasEntitlement);
  assertEquals(s.denialReason, "SALON_PILOT_EXPIRED");
});

Deno.test("an unknown plan code fails the decode instead of defaulting", () => {
  failed(
    decodeSubscriptionState(salonPilotPayload({ planCode: "premium" })),
    "planCode",
    "unknown_value",
  );
  failed(
    decodeSubscriptionState(
      salonPilotPayload({ entitlementStatus: "inactive" }),
    ),
    "entitlementStatus",
    "unknown_value",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ allowanceUnit: "credit" })),
    "allowanceUnit",
    "unknown_value",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ denialReason: "NEW_CODE" })),
    "denialReason",
    "unknown_value",
  );
});

Deno.test("missing and mistyped fields fail by name", () => {
  const missing = salonPilotPayload();
  delete (missing as Record<string, unknown>).availableAiLooks;
  failed(decodeSubscriptionState(missing), "availableAiLooks", "missing");
  failed(
    decodeSubscriptionState(salonPilotPayload({ committedUsage: "18" })),
    "committedUsage",
    "wrong_type",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ committedUsage: 18.5 })),
    "committedUsage",
    "wrong_type",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ autoRenew: "false" })),
    "autoRenew",
    "wrong_type",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ planCode: 3 })),
    "planCode",
    "wrong_type",
  );
  failed(
    decodeSubscriptionState(salonPilotPayload({ expiresAt: 0 })),
    "expiresAt",
    "wrong_type",
  );
});

Deno.test("non-object payloads fail closed", () => {
  failed(decodeSubscriptionState(null), "$", "not_an_object");
  failed(decodeSubscriptionState("active"), "$", "not_an_object");
  failed(decodeSubscriptionState([salonPilotPayload()]), "$", "not_an_object");
  failed(decodeSubscriptionState(undefined), "$", "not_an_object");
});

// ---------------------------------------------------------------------------
// Effective status and the admin entitlement view
// ---------------------------------------------------------------------------

function state(overrides: Record<string, unknown> = {}): SubscriptionState {
  const s = ok(decodeSubscriptionState(salonPilotPayload(overrides)));
  assert(s.hasEntitlement);
  return s;
}

Deno.test("effective status follows contract §74's rule from server fields only", () => {
  assertEquals(effectiveEntitlementStatus(state()), "active");
  assertEquals(
    effectiveEntitlementStatus(
      state({
        generationAuthorized: false,
        denialReason: "SALON_PILOT_EXPIRED",
      }),
    ),
    "expired",
  );
  assertEquals(
    effectiveEntitlementStatus(state({
      entitlementStatus: "grace_period",
      generationAuthorized: false,
      denialReason: "ENTITLEMENT_EXPIRED",
    })),
    "expired",
  );
  // A stored non-live status is reported as stored; nothing is upgraded.
  assertEquals(
    effectiveEntitlementStatus(state({
      entitlementStatus: "suspended",
      generationAuthorized: false,
      denialReason: "ENTITLEMENT_SUSPENDED",
    })),
    "suspended",
  );
  assertEquals(
    effectiveEntitlementStatus(state({
      entitlementStatus: "revoked",
      generationAuthorized: false,
      denialReason: "ENTITLEMENT_REVOKED",
    })),
    "revoked",
  );
  // Out of capacity is not a lifecycle change.
  assertEquals(
    effectiveEntitlementStatus(state({
      generationAuthorized: false,
      denialReason: "AI_LOOK_LIMIT_REACHED",
    })),
    "active",
  );
});

Deno.test("the admin entitlement view copies every figure and adds nothing", () => {
  const s = state({
    generationAuthorized: false,
    denialReason: "SALON_PILOT_EXPIRED",
  });
  const view = toAdminEntitlementView(USER, s);
  assertEquals(view.userId, USER);
  assertEquals(view.storedStatus, "active");
  assertEquals(view.effectiveStatus, "expired");
  assertEquals(view.allowance, s.allowance);
  assertEquals(view.capability, s.capability);
  assertEquals(view.denialReason, "SALON_PILOT_EXPIRED");
  assertEquals(view.version, null);
  assertEquals(toAdminEntitlementView(USER, s, 4).version, 4);
});

// ---------------------------------------------------------------------------
// usage_ledger rows → AdminUsageRecord
// ---------------------------------------------------------------------------

function ledgerRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "33333333-3333-4333-8333-333333333333",
    user_id: USER,
    entitlement_id: ENT,
    usage_type: "final_makeup_preview",
    operation_id: "44444444-4444-4444-8444-444444444444",
    status: "committed",
    source_mode: "standard",
    canonical_generated_image_id: "55555555-5555-4555-8555-555555555555",
    canonical_kit_generated_image_id: null,
    plan_code: "salon_pilot",
    allowance_unit: "ai_look",
    allowance_source: "subscription",
    purchased_credit_grant_id: null,
    period_start: null,
    period_end: null,
    reserved_at: T0,
    committed_at: T0,
    released_at: null,
    sanitized_failure_code: null,
    created_at: T0,
    updated_at: T0,
    ...overrides,
  };
}

Deno.test("a committed Standard Mode row carries a discriminated preview reference", () => {
  const u = ok(decodeUsageRecord(ledgerRow()));
  assertEquals(u.status, "committed");
  assertEquals(u.canonicalPreview, {
    sourceMode: "standard",
    generatedImageId: "55555555-5555-4555-8555-555555555555",
  });
  assertEquals(u.allowanceSource, "subscription");
  assertEquals(u.purchasedCreditGrantId, null);
  assertEquals(u.usageType, "final_makeup_preview");
});

Deno.test("a committed My Makeup Kit row uses the kit id under makeup_kit", () => {
  const u = ok(decodeUsageRecord(ledgerRow({
    source_mode: "makeup_kit",
    canonical_generated_image_id: null,
    canonical_kit_generated_image_id: "66666666-6666-4666-8666-666666666666",
  })));
  assertEquals(u.canonicalPreview, {
    sourceMode: "makeup_kit",
    kitGeneratedImageId: "66666666-6666-4666-8666-666666666666",
  });
});

Deno.test("a committed row whose preview was deleted keeps its mode with a null id", () => {
  const u = ok(
    decodeUsageRecord(ledgerRow({ canonical_generated_image_id: null })),
  );
  assertEquals(u.canonicalPreview, {
    sourceMode: "standard",
    generatedImageId: null,
  });
  assertEquals(u.status, "committed");
});

Deno.test("a committed row without source_mode is malformed, not guessed from ids", () => {
  failed(
    decodeUsageRecord(ledgerRow({ source_mode: null })),
    "source_mode",
    "missing",
  );
});

Deno.test("reserved and released rows have no preview reference", () => {
  const reserved = ok(decodeUsageRecord(ledgerRow({
    status: "reserved",
    source_mode: null,
    canonical_generated_image_id: null,
    committed_at: null,
  })));
  assertEquals(reserved.canonicalPreview, null);
  const released = ok(decodeUsageRecord(ledgerRow({
    status: "released",
    source_mode: null,
    canonical_generated_image_id: null,
    committed_at: null,
    released_at: T0,
    sanitized_failure_code: "generation_failed",
  })));
  assertEquals(released.canonicalPreview, null);
  assertEquals(released.sanitizedFailureCode, "generation_failed");
});

Deno.test("purchased-credit provenance requires the grant id, and vice versa", () => {
  const credit = ok(decodeUsageRecord(ledgerRow({
    plan_code: "pro",
    allowance_source: "purchased_credit",
    purchased_credit_grant_id: "77777777-7777-4777-8777-777777777777",
  })));
  assertEquals(credit.allowanceSource, "purchased_credit");
  assertEquals(
    credit.purchasedCreditGrantId,
    "77777777-7777-4777-8777-777777777777",
  );
  failed(
    decodeUsageRecord(ledgerRow({ allowance_source: "purchased_credit" })),
    "purchased_credit_grant_id",
    "wrong_type",
  );
  failed(
    decodeUsageRecord(
      ledgerRow({
        purchased_credit_grant_id: "77777777-7777-4777-8777-777777777777",
      }),
    ),
    "purchased_credit_grant_id",
    "wrong_type",
  );
});

Deno.test("invented usage states and types fail the decode", () => {
  failed(
    decodeUsageRecord(ledgerRow({ status: "used" })),
    "status",
    "unknown_value",
  );
  failed(
    decodeUsageRecord(ledgerRow({ usage_type: "tutorial" })),
    "usage_type",
    "unknown_value",
  );
  failed(
    decodeUsageRecord(ledgerRow({ allowance_source: "wallet" })),
    "allowance_source",
    "unknown_value",
  );
});

// ---------------------------------------------------------------------------
// entitlement_allowance_adjustments rows and the advisory preview
// ---------------------------------------------------------------------------

function adjustmentRow(overrides: Record<string, unknown> = {}) {
  return {
    id: "88888888-8888-4888-8888-888888888888",
    entitlement_id: ENT,
    target_user_id: USER,
    admin_user_id: "99999999-9999-4999-8999-999999999999",
    adjustment_type: "increase_allowance",
    amount: 10,
    reason: "Additional panel testing",
    idempotency_key: "adj-2026-09-21-001",
    created_at: T0,
    ...overrides,
  };
}

Deno.test("an adjustment row decodes with its signed amount and administrator", () => {
  const a = ok(decodeAllowanceAdjustment(adjustmentRow()));
  assertEquals(a.adjustmentType, "increase_allowance");
  assertEquals(a.amount, 10);
  assertEquals(a.adminUserId, "99999999-9999-4999-8999-999999999999");
  assertEquals(a.idempotencyKey, "adj-2026-09-21-001");
  const decrease = ok(
    decodeAllowanceAdjustment(
      adjustmentRow({ adjustment_type: "decrease_allowance", amount: -5 }),
    ),
  );
  assertEquals(decrease.amount, -5);
  // The administrator's account was deleted later; the fact survives.
  assertEquals(
    ok(decodeAllowanceAdjustment(adjustmentRow({ admin_user_id: null })))
      .adminUserId,
    null,
  );
});

Deno.test("an adjustment whose sign disagrees with its type is malformed", () => {
  failed(
    decodeAllowanceAdjustment(adjustmentRow({ amount: -10 })),
    "amount",
    "wrong_type",
  );
  failed(
    decodeAllowanceAdjustment(
      adjustmentRow({ adjustment_type: "decrease_allowance", amount: 5 }),
    ),
    "amount",
    "wrong_type",
  );
  failed(
    decodeAllowanceAdjustment(adjustmentRow({ amount: 0 })),
    "amount",
    "wrong_type",
  );
  failed(
    decodeAllowanceAdjustment(
      adjustmentRow({ adjustment_type: "set_allowance" }),
    ),
    "adjustment_type",
    "unknown_value",
  );
});

Deno.test("the adjustment preview reproduces the contract §31 worked example", () => {
  const p = previewAllowanceAdjustment(ENT, {
    effectiveAllowance: 30,
    committedUsage: 18,
    reservedUsage: 0,
  }, 10);
  assertEquals(p.adjustmentType, "increase_allowance");
  assertEquals(p.effectiveAllowanceBefore, 30);
  assertEquals(p.effectiveAllowanceAfter, 40);
  assertEquals(p.expectedRemaining, 22);
  assertEquals(p.expectedAvailable, 22);
  assertEquals(p.valid, true);
  assertEquals(p.rejectionCode, null);
});

Deno.test("the preview refuses what the trigger refuses (contract §44)", () => {
  const current = {
    effectiveAllowance: 30,
    committedUsage: 24,
    reservedUsage: 1,
  };
  // 30 − 5 = 25 ≥ 24 committed, and ≥ 25 held → allowed.
  assertEquals(previewAllowanceAdjustment(ENT, current, -5).valid, true);
  // 30 − 6 = 24 covers committed but strands the reservation.
  const reservation = previewAllowanceAdjustment(ENT, current, -6);
  assertEquals(reservation.valid, false);
  assertEquals(
    reservation.rejectionCode,
    "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION",
  );
  // 30 − 10 = 20 < 24 committed.
  const committed = previewAllowanceAdjustment(ENT, current, -10);
  assertEquals(committed.valid, false);
  assertEquals(committed.rejectionCode, "ALLOWANCE_BELOW_COMMITTED_USAGE");
  assertEquals(committed.adjustmentType, "decrease_allowance");
  // Nothing in a rejected preview goes negative.
  assertEquals(committed.expectedRemaining, 0);
  assertEquals(committed.expectedAvailable, 0);
});

Deno.test("the preview rejects zero, fractional, and below-zero adjustments", () => {
  const current = {
    effectiveAllowance: 30,
    committedUsage: 0,
    reservedUsage: 0,
  };
  assertEquals(
    previewAllowanceAdjustment(ENT, current, 0).rejectionCode,
    "INVALID_ALLOWANCE_ADJUSTMENT",
  );
  assertEquals(
    previewAllowanceAdjustment(ENT, current, 2.5).rejectionCode,
    "INVALID_ALLOWANCE_ADJUSTMENT",
  );
  assertEquals(
    previewAllowanceAdjustment(ENT, current, -31).rejectionCode,
    "INVALID_ALLOWANCE_ADJUSTMENT",
  );
  assertEquals(previewAllowanceAdjustment(ENT, current, -30).valid, true);
});

// ---------------------------------------------------------------------------
// purchased_credit_grants rows (read-only view)
// ---------------------------------------------------------------------------

Deno.test("a purchased credit grant decodes without its purchase references", () => {
  const g = ok(decodePurchasedCreditGrant({
    id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
    user_id: USER,
    billing_provider: "google_play",
    provider_product_id: "facetune_ai_look_topup_1",
    pack_code: "extra_ai_look",
    credit_class: "tutorial_capable_ai_look",
    quantity_granted: 1,
    purchase_reference: "0".repeat(64),
    provider_order_id: "GPA.1234-5678-9012-34567",
    purchase_state: "PURCHASED",
    test_purchase: false,
    granted_under_plan_code: "pro",
    granted_under_entitlement_id: ENT,
    provider_consumed_at: T0,
    revoked_at: null,
    revocation_reason: null,
    revocation_reference: null,
    granted_at: T0,
    created_at: T0,
    updated_at: T0,
  }));
  assertEquals(g.creditClass, "tutorial_capable_ai_look");
  assertEquals(g.quantityGranted, 1);
  assertEquals(g.grantedUnderPlanCode, "pro");
  assertEquals(g.revokedAt, null);
  assertEquals("purchaseReference" in g, false);
  assertEquals("providerOrderId" in g, false);
  assertEquals("revocationReference" in g, false);
});

Deno.test("an unknown credit class fails the grant decode", () => {
  failed(
    decodePurchasedCreditGrant({
      id: "a",
      user_id: USER,
      billing_provider: "google_play",
      provider_product_id: "x",
      pack_code: "x",
      credit_class: "wallet_coin",
    }),
    "credit_class",
    "unknown_value",
  );
});

// ---------------------------------------------------------------------------
// Audit events (contract §63)
// ---------------------------------------------------------------------------

function auditPayload(overrides: Record<string, unknown> = {}) {
  return {
    id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    source: "admin",
    adminUserId: "99999999-9999-4999-8999-999999999999",
    action: "increase_allowance",
    targetUserId: USER,
    targetEntitlementId: ENT,
    beforeState: {
      status: "active",
      planCode: "salon_pilot",
      effectiveAllowance: 30,
      allowanceAdjustmentTotal: 0,
      expiresAt: T1,
      version: 3,
    },
    afterState: {
      status: "active",
      planCode: "salon_pilot",
      effectiveAllowance: 40,
      allowanceAdjustmentTotal: 10,
      expiresAt: T1,
      version: 4,
    },
    reason: "Additional panel testing",
    requestCorrelationId: "req-1",
    idempotencyKey: "adj-2026-09-21-001",
    createdAt: T0,
    ...overrides,
  };
}

Deno.test("an admin audit event decodes with before/after snapshots", () => {
  const e = ok(decodeAuditEvent(auditPayload()));
  assertEquals(e.source, "admin");
  assertEquals(e.action, "increase_allowance");
  assertEquals(e.beforeState?.effectiveAllowance, 30);
  assertEquals(e.afterState?.effectiveAllowance, 40);
  assertEquals(e.afterState?.version, 4);
});

Deno.test("a deleted administrator remains a readable audit actor; provider events need none", () => {
  const deletedAdmin = ok(
    decodeAuditEvent(auditPayload({ adminUserId: null })),
  );
  assertEquals(deletedAdmin.adminUserId, null);
  const provider = ok(decodeAuditEvent(auditPayload({
    source: "provider",
    adminUserId: null,
    action: "revoke_entitlement",
    reason: null,
    idempotencyKey: null,
    beforeState: null,
    afterState: null,
  })));
  assertEquals(provider.adminUserId, null);
  assertEquals(provider.beforeState, null);
});

Deno.test("audit list rows decode only operational summary fields", () => {
  const event = ok(decodeAuditEventSummary({
    id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    source: "admin",
    adminUserId: "99999999-9999-4999-8999-999999999999",
    adminEmail: "admin@example.invalid",
    action: "suspend_entitlement",
    targetUserId: USER,
    targetEmail: "artist@example.invalid",
    targetEntitlementId: ENT,
    createdAt: T0,
  }));
  assertEquals(event.action, "suspend_entitlement");
  assertEquals(event.targetEntitlementId, ENT);
});

Deno.test("entitlement history distinguishes admin and provider lifecycle events", () => {
  const admin = ok(decodeEntitlementHistoryEvent({
    id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
    source: "admin",
    eventType: "increase_allowance",
    action: "increase_allowance",
    actorUserId: "99999999-9999-4999-8999-999999999999",
    actorEmail: "admin@example.invalid",
    reason: "Panel extension",
    beforeState: auditPayload().beforeState,
    afterState: auditPayload().afterState,
    requestCorrelationId: "88888888-8888-4888-8888-888888888888",
    provider: null,
    occurredAt: T0,
  }));
  assertEquals(admin.eventType, "increase_allowance");
  assertEquals(admin.afterState?.effectiveAllowance, 40);

  const provider = ok(decodeEntitlementHistoryEvent({
    id: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
    source: "provider",
    eventType: "provider_state_change",
    action: null,
    actorUserId: null,
    actorEmail: null,
    reason: null,
    beforeState: null,
    afterState: null,
    requestCorrelationId: null,
    provider: "google_play",
    occurredAt: T1,
  }));
  assertEquals(provider.provider, "google_play");
  assertEquals(provider.action, null);
});

Deno.test("history rejects invented event types and provider-shaped admin actions", () => {
  failed(
    decodeEntitlementHistoryEvent({
      id: "c",
      source: "provider",
      eventType: "refund_processed",
      action: null,
      actorUserId: null,
      actorEmail: null,
      reason: null,
      beforeState: null,
      afterState: null,
      requestCorrelationId: null,
      provider: "google_play",
      occurredAt: T1,
    }),
    "eventType",
    "unknown_value",
  );
});

Deno.test("audit actions outside contract §45 are rejected", () => {
  failed(
    decodeAuditEvent(auditPayload({ action: "adjust_allowance" })),
    "action",
    "unknown_value",
  );
  failed(
    decodeAuditEvent(auditPayload({ source: "browser" })),
    "source",
    "unknown_value",
  );
});

// ---------------------------------------------------------------------------
// Mutation results (contract §73)
// ---------------------------------------------------------------------------

Deno.test("decodes the contract §73 success example", () => {
  const m = ok(decodeAdminMutationResult({
    success: true,
    action: "increase_allowance",
    entitlementId: ENT,
    planCode: "salon_pilot",
    status: "active",
    effectiveAllowance: 40,
    committedUsage: 18,
    reservedUsage: 0,
    availableAiLooks: 22,
    expiresAt: T1,
    updatedAt: T0,
  }));
  assert(m.success);
  assertEquals(m.action, "increase_allowance");
  assertEquals(m.availableAiLooks, 22);
  assertEquals(m.replayed, false);
  const replayed = ok(decodeAdminMutationResult({
    success: true,
    action: "grant_salon_pilot",
    entitlementId: ENT,
    planCode: "salon_pilot",
    status: "active",
    effectiveAllowance: 30,
    committedUsage: 0,
    reservedUsage: 0,
    availableAiLooks: 30,
    expiresAt: T1,
    updatedAt: T0,
    replayed: true,
  }));
  assert(replayed.success);
  assertEquals(replayed.replayed, true);
});

Deno.test("decodes a typed failure and rejects unknown codes and actions", () => {
  const f = ok(decodeAdminMutationResult({
    success: false,
    action: "decrease_allowance",
    errorCode: "ALLOWANCE_BELOW_COMMITTED_USAGE",
    retryable: false,
  }));
  assert(!f.success);
  assertEquals(f.errorCode, "ALLOWANCE_BELOW_COMMITTED_USAGE");
  assertEquals(f.action, "decrease_allowance");
  failed(
    decodeAdminMutationResult({
      success: false,
      action: null,
      errorCode: "OOPS",
      retryable: true,
    }),
    "errorCode",
    "unknown_value",
  );
  failed(
    decodeAdminMutationResult({
      success: true,
      action: "adjust_allowance",
      entitlementId: ENT,
      planCode: "salon_pilot",
      status: "active",
      effectiveAllowance: 40,
      committedUsage: 18,
      reservedUsage: 0,
      availableAiLooks: 22,
      expiresAt: T1,
      updatedAt: T0,
    }),
    "action",
    "unknown_value",
  );
  failed(
    decodeAdminMutationResult({ success: "true" }),
    "success",
    "wrong_type",
  );
});

// ---------------------------------------------------------------------------
// Pagination bounds (Web Admin SOT §59)
// ---------------------------------------------------------------------------

Deno.test("page sizes are bounded by construction", () => {
  assertEquals(boundedPageSize(undefined), ADMIN_PAGE_SIZE_DEFAULT);
  assertEquals(boundedPageSize("50"), ADMIN_PAGE_SIZE_DEFAULT);
  assertEquals(boundedPageSize(0), ADMIN_PAGE_SIZE_DEFAULT);
  assertEquals(boundedPageSize(-1), ADMIN_PAGE_SIZE_DEFAULT);
  assertEquals(boundedPageSize(2.5), ADMIN_PAGE_SIZE_DEFAULT);
  assertEquals(boundedPageSize(10), 10);
  assertEquals(boundedPageSize(100), ADMIN_PAGE_SIZE_MAX);
  assertEquals(boundedPageSize(10_000), ADMIN_PAGE_SIZE_MAX);
});
