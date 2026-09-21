import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  ADMIN_ACTIONS,
  ADMIN_ROLES,
  adminErrorRetryable,
  adminErrorStatus,
  ALLOWANCE_ADJUSTMENT_TYPES,
  ALLOWANCE_SOURCES,
  ALLOWANCE_UNITS,
  asAdminAction,
  asAdminRole,
  asAllowanceAdjustmentType,
  asAllowanceSource,
  asAllowanceUnit,
  asAuditEventSource,
  asBillingProvider,
  asEntitlementStatus,
  asKnownErrorCodeOrUnknown,
  asPreviewSourceMode,
  asPurchasedCreditClass,
  asResetPolicy,
  asSubscriptionErrorCode,
  asSubscriptionPlanCode,
  asUsageStatus,
  asUsageType,
  AUDIT_EVENT_SOURCES,
  BILLING_PROVIDERS,
  ENTITLEMENT_STATUSES,
  PREVIEW_SOURCE_MODES,
  PREVIEW_SOURCE_MODES_AGREE_WITH_USAGE_ENGINE,
  PURCHASED_CREDIT_CLASSES,
  RESET_POLICIES,
  SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
  SUBSCRIPTION_ERROR_CODES,
  SUBSCRIPTION_PLAN_CODES,
  USAGE_STATUSES,
  USAGE_TYPES,
} from "./admin_contract.ts";

// ---------------------------------------------------------------------------
// Contract identity — the lists are exactly what the Shared Contract v1.1
// fixes, in its order. A drifted member fails here before it reaches a wire.
// ---------------------------------------------------------------------------

Deno.test("declares contract v1.1", () => {
  assertEquals(
    SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
    "subscription_admin_contract_v1.1",
  );
});

Deno.test("plan codes are the eight of contract §7, in order", () => {
  assertEquals([...SUBSCRIPTION_PLAN_CODES], [
    "free",
    "plus",
    "plus_preview",
    "pro",
    "pro_preview",
    "salon_pro",
    "salon_preview",
    "salon_pilot",
  ]);
});

Deno.test("billing providers match contract §11", () => {
  assertEquals([...BILLING_PROVIDERS], [
    "none",
    "google_play",
    "apple_app_store",
    "admin_granted",
  ]);
});

Deno.test("entitlement statuses match contract §12, including pending", () => {
  assertEquals([...ENTITLEMENT_STATUSES], [
    "pending",
    "active",
    "grace_period",
    "expired",
    "suspended",
    "revoked",
  ]);
});

Deno.test("usage vocabulary matches contract §20, §24, §42", () => {
  assertEquals([...USAGE_TYPES], ["final_makeup_preview"]);
  assertEquals([...USAGE_STATUSES], ["reserved", "committed", "released"]);
  assertEquals([...ALLOWANCE_SOURCES], ["subscription", "purchased_credit"]);
  assertEquals([...PREVIEW_SOURCE_MODES], ["standard", "makeup_kit"]);
  assertEquals(PREVIEW_SOURCE_MODES_AGREE_WITH_USAGE_ENGINE, true);
});

Deno.test("capability and reset vocabulary match contract §9, §38", () => {
  assertEquals([...RESET_POLICIES], ["none", "billing_period"]);
  assertEquals([...ALLOWANCE_UNITS], ["ai_look", "final_preview_credit"]);
});

Deno.test("purchased credit classes match contract §74a", () => {
  assertEquals([...PURCHASED_CREDIT_CLASSES], [
    "tutorial_capable_ai_look",
    "preview_only_final_preview",
  ]);
});

Deno.test("admin vocabulary matches contract §43, §45, §53", () => {
  assertEquals([...ADMIN_ROLES], ["normal_user", "admin"]);
  assertEquals([...ADMIN_ACTIONS], [
    "grant_salon_pilot",
    "increase_allowance",
    "decrease_allowance",
    "extend_expiration",
    "suspend_entitlement",
    "reactivate_entitlement",
    "revoke_entitlement",
  ]);
  assertEquals([...ALLOWANCE_ADJUSTMENT_TYPES], [
    "increase_allowance",
    "decrease_allowance",
  ]);
  assertEquals([...AUDIT_EVENT_SOURCES], ["admin", "provider", "system"]);
});

Deno.test("error codes are contract §71 plus USER_NOT_FOUND, nothing else", () => {
  const contract71 = [
    "AUTH_REQUIRED",
    "ADMIN_UNAUTHORIZED",
    "ENTITLEMENT_NOT_FOUND",
    "ENTITLEMENT_PENDING",
    "ENTITLEMENT_INACTIVE",
    "ENTITLEMENT_EXPIRED",
    "ENTITLEMENT_SUSPENDED",
    "ENTITLEMENT_REVOKED",
    "AI_LOOK_LIMIT_REACHED",
    "AI_LOOK_RESERVATION_CONFLICT",
    "USAGE_OPERATION_NOT_FOUND",
    "USAGE_ALREADY_COMMITTED",
    "USAGE_ALREADY_RELEASED",
    "USAGE_STATE_CONFLICT",
    "INVALID_PLAN_CODE",
    "INVALID_ENTITLEMENT_TRANSITION",
    "INVALID_ALLOWANCE_ADJUSTMENT",
    "ALLOWANCE_BELOW_COMMITTED_USAGE",
    "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION",
    "SALON_PILOT_ALREADY_GRANTED",
    "SALON_PILOT_EXPIRED",
    "PURCHASE_VERIFICATION_FAILED",
    "PROVIDER_STATE_CONFLICT",
    "IDEMPOTENCY_CONFLICT",
    "CONCURRENT_MODIFICATION",
    "TEMPORARY_BACKEND_FAILURE",
  ];
  const actual = new Set<string>(SUBSCRIPTION_ERROR_CODES);
  for (const code of contract71) assert(actual.has(code), `missing ${code}`);
  assertEquals(actual.size, contract71.length + 1);
  assert(actual.has("USER_NOT_FOUND"));
  // Web Admin SOT §53 names these; the contract expresses them otherwise.
  assertEquals(asSubscriptionErrorCode("STALE_ENTITLEMENT_VERSION"), null);
  assertEquals(asSubscriptionErrorCode("DUPLICATE_OPERATION"), null);
});

// ---------------------------------------------------------------------------
// Parsing — every member accepted, everything else null, never a default.
// ---------------------------------------------------------------------------

Deno.test("every vocabulary member round-trips through its parser", () => {
  for (const v of SUBSCRIPTION_PLAN_CODES) {
    assertEquals(asSubscriptionPlanCode(v), v);
  }
  for (const v of BILLING_PROVIDERS) assertEquals(asBillingProvider(v), v);
  for (const v of ENTITLEMENT_STATUSES) assertEquals(asEntitlementStatus(v), v);
  for (const v of USAGE_TYPES) assertEquals(asUsageType(v), v);
  for (const v of USAGE_STATUSES) assertEquals(asUsageStatus(v), v);
  for (const v of ALLOWANCE_SOURCES) assertEquals(asAllowanceSource(v), v);
  for (const v of PREVIEW_SOURCE_MODES) assertEquals(asPreviewSourceMode(v), v);
  for (const v of RESET_POLICIES) assertEquals(asResetPolicy(v), v);
  for (const v of ALLOWANCE_UNITS) assertEquals(asAllowanceUnit(v), v);
  for (const v of PURCHASED_CREDIT_CLASSES) {
    assertEquals(asPurchasedCreditClass(v), v);
  }
  for (const v of ADMIN_ROLES) assertEquals(asAdminRole(v), v);
  for (const v of ADMIN_ACTIONS) assertEquals(asAdminAction(v), v);
  for (const v of ALLOWANCE_ADJUSTMENT_TYPES) {
    assertEquals(asAllowanceAdjustmentType(v), v);
  }
  for (const v of AUDIT_EVENT_SOURCES) assertEquals(asAuditEventSource(v), v);
  for (const v of SUBSCRIPTION_ERROR_CODES) {
    assertEquals(asSubscriptionErrorCode(v), v);
  }
});

Deno.test("forbidden plan aliases and near-misses are rejected", () => {
  for (
    const alias of [
      "premium",
      "premium_plus",
      "professional",
      "salon",
      "salon_test",
      "salon_research",
      "research_salon",
      "salon_trial",
      "plus_no_tutorial",
      "preview_plus",
      "pro_no_tutorial",
      "salon_preview_only",
      "pilot",
      "research",
      "Plus",
      "PLUS_PREVIEW",
      " plus",
      "plus ",
      "",
    ]
  ) {
    assertEquals(asSubscriptionPlanCode(alias), null, alias);
  }
});

Deno.test("forbidden status and usage substitutes are rejected", () => {
  for (
    const s of [
      "inactive",
      "cancelled",
      "cancelled_entitlement",
      "disabled",
      "blocked",
      "premium_off",
      "bad",
      "ACTIVE",
    ]
  ) {
    assertEquals(asEntitlementStatus(s), null, s);
  }
  for (
    const s of [
      "used",
      "used_up",
      "done",
      "finished",
      "failed_charge",
      "pending_charge",
      "spent",
    ]
  ) {
    assertEquals(asUsageStatus(s), null, s);
  }
  for (
    const t of [
      "tutorial",
      "manifest",
      "analysis",
      "recommendation",
      "makeup_kit",
    ]
  ) {
    assertEquals(asUsageType(t), null, t);
  }
});

Deno.test("non-string inputs never parse", () => {
  for (
    const bad of [null, undefined, 0, 1, true, false, {}, [], ["free"], {
      code: "free",
    }]
  ) {
    assertEquals(asSubscriptionPlanCode(bad), null);
    assertEquals(asEntitlementStatus(bad), null);
    assertEquals(asBillingProvider(bad), null);
    assertEquals(asUsageStatus(bad), null);
    assertEquals(asAdminAction(bad), null);
    assertEquals(asSubscriptionErrorCode(bad), null);
  }
});

Deno.test("Web Admin SOT §41 action spellings are not on the wire", () => {
  for (
    const loose of [
      "grant_entitlement",
      "adjust_allowance",
      "revoke",
      "suspend",
    ]
  ) {
    assertEquals(asAdminAction(loose), null, loose);
  }
});

Deno.test("provider is never inferred from plan; admin_granted parses only as itself", () => {
  assertEquals(asBillingProvider("salon_pilot"), null);
  assertEquals(asBillingProvider("admin_granted"), "admin_granted");
  assertEquals(asBillingProvider("play"), null);
});

Deno.test("unknown server error codes surface as UNKNOWN_ERROR_CODE, not as a contract code", () => {
  assertEquals(
    asKnownErrorCodeOrUnknown("AI_LOOK_LIMIT_REACHED"),
    "AI_LOOK_LIMIT_REACHED",
  );
  assertEquals(
    asKnownErrorCodeOrUnknown("SOMETHING_NEW"),
    "UNKNOWN_ERROR_CODE",
  );
  assertEquals(asKnownErrorCodeOrUnknown(null), "UNKNOWN_ERROR_CODE");
  assertEquals(asKnownErrorCodeOrUnknown(500), "UNKNOWN_ERROR_CODE");
});

// ---------------------------------------------------------------------------
// Transport mapping — exhaustive and shaped like ai_look_usage.ts.
// ---------------------------------------------------------------------------

Deno.test("every error code maps to one HTTP status", () => {
  const allowed = new Set([400, 401, 403, 404, 409, 503]);
  for (const code of SUBSCRIPTION_ERROR_CODES) {
    assert(
      allowed.has(adminErrorStatus(code)),
      `${code} → ${adminErrorStatus(code)}`,
    );
  }
  assertEquals(adminErrorStatus(null), 200);
  assertEquals(adminErrorStatus("AUTH_REQUIRED"), 401);
  assertEquals(adminErrorStatus("ADMIN_UNAUTHORIZED"), 403);
  assertEquals(adminErrorStatus("USER_NOT_FOUND"), 404);
  assertEquals(adminErrorStatus("ENTITLEMENT_NOT_FOUND"), 404);
  assertEquals(adminErrorStatus("INVALID_ALLOWANCE_ADJUSTMENT"), 400);
  assertEquals(adminErrorStatus("ALLOWANCE_BELOW_COMMITTED_USAGE"), 409);
  assertEquals(adminErrorStatus("CONCURRENT_MODIFICATION"), 409);
  assertEquals(adminErrorStatus("IDEMPOTENCY_CONFLICT"), 409);
  assertEquals(adminErrorStatus("TEMPORARY_BACKEND_FAILURE"), 503);
});

Deno.test("only transient outcomes are retryable", () => {
  const retryable = SUBSCRIPTION_ERROR_CODES.filter(adminErrorRetryable);
  assertEquals([...retryable], [
    "CONCURRENT_MODIFICATION",
    "TEMPORARY_BACKEND_FAILURE",
  ]);
  assertEquals(adminErrorRetryable(null), false);
  assertEquals(adminErrorRetryable("IDEMPOTENCY_CONFLICT"), false);
  assertEquals(adminErrorRetryable("ADMIN_UNAUTHORIZED"), false);
});
