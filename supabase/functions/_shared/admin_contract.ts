/**
 * Subscription / Web Admin shared contract vocabulary (WA-1).
 *
 * One server-side copy of every controlled identifier that
 * `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` (v1.1) fixes for both the
 * Subscription system and the Web Admin. It follows `tutorial_vocabulary.ts`:
 * a `const` tuple is the single source, the union type is derived from it, and
 * `asX(unknown)` returns `null` for anything outside the vocabulary. An unknown
 * value is never coerced into a default — not into `active`, not into `free`,
 * not into `ai_look`.
 *
 * Every string here is already fixed elsewhere and is mirrored, not decided:
 *
 *   - CHECK constraints on `subscription_products`, `user_entitlements`,
 *     `usage_ledger`, `entitlement_allowance_adjustments`,
 *     `purchased_credit_grants` (migrations 20260907000100 … 20260923000100)
 *   - the Flutter enums in `lib/features/subscription/domain/entities/*.dart`
 *     and `domain/errors/subscription_error_code.dart`
 *
 * This module has no runtime dependency, performs no I/O, holds no authority,
 * and knows nothing about who is an admin. It exists so later Web Admin phases
 * and the existing Edge Functions cannot drift into two vocabularies.
 *
 * Deliberately absent: prices, allowance quantities, product ids, capability
 * per plan. Those are server product configuration read at runtime (contract
 * §9–§10); a client that "knows" `plus = 3` has already violated the contract.
 */

import type { PreviewSourceMode as UsagePreviewSourceMode } from "./ai_look_usage.ts";

/** The contract version both systems declare. Contract §4, §124. */
export const SUBSCRIPTION_ADMIN_CONTRACT_VERSION =
  "subscription_admin_contract_v1.1" as const;

// ---------------------------------------------------------------------------
// Plan identity — contract §7. Eight codes as of v1.1.
// ---------------------------------------------------------------------------

export const SUBSCRIPTION_PLAN_CODES = [
  "free",
  "plus",
  "plus_preview",
  "pro",
  "pro_preview",
  "salon_pro",
  "salon_preview",
  "salon_pilot",
] as const;
export type SubscriptionPlanCode = typeof SUBSCRIPTION_PLAN_CODES[number];

// ---------------------------------------------------------------------------
// Billing provider — contract §11.
// ---------------------------------------------------------------------------

export const BILLING_PROVIDERS = [
  "none",
  "google_play",
  "apple_app_store",
  "admin_granted",
] as const;
export type BillingProvider = typeof BILLING_PROVIDERS[number];

// ---------------------------------------------------------------------------
// Entitlement status — contract §12. `pending` is required: the Google Play
// activation writer emits it for SUBSCRIPTION_STATE_PENDING.
// ---------------------------------------------------------------------------

export const ENTITLEMENT_STATUSES = [
  "pending",
  "active",
  "grace_period",
  "expired",
  "suspended",
  "revoked",
] as const;
export type EntitlementStatus = typeof ENTITLEMENT_STATUSES[number];

// ---------------------------------------------------------------------------
// Usage ledger — contract §20, §24, §42.
// ---------------------------------------------------------------------------

export const USAGE_TYPES = ["final_makeup_preview"] as const;
export type UsageType = typeof USAGE_TYPES[number];

export const USAGE_STATUSES = ["reserved", "committed", "released"] as const;
export type UsageStatus = typeof USAGE_STATUSES[number];

/** Which bucket a ledger row drew from. `usage_ledger.allowance_source`. */
export const ALLOWANCE_SOURCES = ["subscription", "purchased_credit"] as const;
export type AllowanceSource = typeof ALLOWANCE_SOURCES[number];

/** Which pipeline produced a committed row's canonical Final Preview. */
export const PREVIEW_SOURCE_MODES = ["standard", "makeup_kit"] as const;
export type PreviewSourceMode = typeof PREVIEW_SOURCE_MODES[number];

// `ai_look_usage.ts` (SUB-4) already names this union for the reserve /
// commit / release wrappers. The two declarations are tied here at compile
// time so neither can gain or lose a member without `deno check` failing.
type MutuallyAssignable<A, B> = [A] extends [B] ? [B] extends [A] ? true
  : false
  : false;
/** Compile-time proof; `true` is only assignable while the two unions agree. */
export const PREVIEW_SOURCE_MODES_AGREE_WITH_USAGE_ENGINE: MutuallyAssignable<
  PreviewSourceMode,
  UsagePreviewSourceMode
> = true;

// ---------------------------------------------------------------------------
// Plan capability and reset — contract §9, §38.
// ---------------------------------------------------------------------------

export const RESET_POLICIES = ["none", "billing_period"] as const;
export type ResetPolicy = typeof RESET_POLICIES[number];

export const ALLOWANCE_UNITS = ["ai_look", "final_preview_credit"] as const;
export type AllowanceUnit = typeof ALLOWANCE_UNITS[number];

// ---------------------------------------------------------------------------
// Purchased credits — contract §74a. Read-only for Web Admin V1.
// ---------------------------------------------------------------------------

export const PURCHASED_CREDIT_CLASSES = [
  "tutorial_capable_ai_look",
  "preview_only_final_preview",
] as const;
export type PurchasedCreditClass = typeof PURCHASED_CREDIT_CLASSES[number];

// ---------------------------------------------------------------------------
// Admin vocabulary — contract §43, §45, §53.
// ---------------------------------------------------------------------------

/** Account-level authorization tiers. Contract §53. */
export const ADMIN_ROLES = ["normal_user", "admin"] as const;
export type AdminRole = typeof ADMIN_ROLES[number];

/** Privacy-minimal Supabase Auth account state shown by WA-5. */
export const ADMIN_ACCOUNT_STATUSES = [
  "active",
  "unconfirmed",
  "banned",
  "anonymous",
] as const;
export type AdminAccountStatus = typeof ADMIN_ACCOUNT_STATUSES[number];

/**
 * Privileged admin action identifiers. Contract §45 is the authority; the
 * looser names in Web Admin SOT §41 (`grant_entitlement`, `adjust_allowance`)
 * are not part of the vocabulary and must not appear on the wire.
 */
export const ADMIN_ACTIONS = [
  "grant_salon_pilot",
  "increase_allowance",
  "decrease_allowance",
  "extend_expiration",
  "suspend_entitlement",
  "reactivate_entitlement",
  "revoke_entitlement",
] as const;
export type AdminAction = typeof ADMIN_ACTIONS[number];

/** `entitlement_allowance_adjustments.adjustment_type`. Contract §43. */
export const ALLOWANCE_ADJUSTMENT_TYPES = [
  "increase_allowance",
  "decrease_allowance",
] as const;
export type AllowanceAdjustmentType = typeof ALLOWANCE_ADJUSTMENT_TYPES[number];

/**
 * Where an entitlement-history event originated. Web Admin SOT §40 requires
 * history "derived from authoritative events/audit records"; the deployed
 * system has exactly three writers of entitlement state:
 *
 *   admin     a privileged admin action (contract §45) — audit events and
 *             `entitlement_allowance_adjustments` rows
 *   provider  verified Google Play state — purchase verification and RTDN
 *             (`provider_purchase_verifications`, `provider_notification_events`)
 *   system    server lifecycle with no external actor — Free provisioning at
 *             sign-up, supersession of a replaced subscription, reconciliation
 */
export const AUDIT_EVENT_SOURCES = ["admin", "provider", "system"] as const;
export type AuditEventSource = typeof AUDIT_EVENT_SOURCES[number];

// ---------------------------------------------------------------------------
// Sanitized error codes — contract §71, plus the one admin-only code that Web
// Admin SOT §53 names for target resolution (§104). Nothing else is added:
// `STALE_ENTITLEMENT_VERSION` and `DUPLICATE_OPERATION` from SOT §53 are
// expressed with the contract's `CONCURRENT_MODIFICATION` and
// `IDEMPOTENCY_CONFLICT`, because the Shared Contract wins for common
// semantics (Web Admin Phase Prompts §2).
// ---------------------------------------------------------------------------

export const SUBSCRIPTION_ERROR_CODES = [
  "AUTH_REQUIRED",
  "ADMIN_UNAUTHORIZED",
  "USER_NOT_FOUND",

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
] as const;
export type SubscriptionErrorCode = typeof SUBSCRIPTION_ERROR_CODES[number];

// ---------------------------------------------------------------------------
// Parsing. `null` for anything outside the vocabulary; never a default.
// ---------------------------------------------------------------------------

function asMember<T extends string>(
  vocabulary: readonly T[],
  value: unknown,
): T | null {
  return typeof value === "string" &&
      (vocabulary as readonly string[]).includes(value)
    ? value as T
    : null;
}

export const asSubscriptionPlanCode = (
  v: unknown,
): SubscriptionPlanCode | null => asMember(SUBSCRIPTION_PLAN_CODES, v);
export const asBillingProvider = (v: unknown): BillingProvider | null =>
  asMember(BILLING_PROVIDERS, v);
export const asEntitlementStatus = (v: unknown): EntitlementStatus | null =>
  asMember(ENTITLEMENT_STATUSES, v);
export const asUsageType = (v: unknown): UsageType | null =>
  asMember(USAGE_TYPES, v);
export const asUsageStatus = (v: unknown): UsageStatus | null =>
  asMember(USAGE_STATUSES, v);
export const asAllowanceSource = (v: unknown): AllowanceSource | null =>
  asMember(ALLOWANCE_SOURCES, v);
export const asPreviewSourceMode = (v: unknown): PreviewSourceMode | null =>
  asMember(PREVIEW_SOURCE_MODES, v);
export const asResetPolicy = (v: unknown): ResetPolicy | null =>
  asMember(RESET_POLICIES, v);
export const asAllowanceUnit = (v: unknown): AllowanceUnit | null =>
  asMember(ALLOWANCE_UNITS, v);
export const asPurchasedCreditClass = (
  v: unknown,
): PurchasedCreditClass | null => asMember(PURCHASED_CREDIT_CLASSES, v);
export const asAdminRole = (v: unknown): AdminRole | null =>
  asMember(ADMIN_ROLES, v);
export const asAdminAccountStatus = (
  v: unknown,
): AdminAccountStatus | null => asMember(ADMIN_ACCOUNT_STATUSES, v);
export const asAdminAction = (v: unknown): AdminAction | null =>
  asMember(ADMIN_ACTIONS, v);
export const asAllowanceAdjustmentType = (
  v: unknown,
): AllowanceAdjustmentType | null => asMember(ALLOWANCE_ADJUSTMENT_TYPES, v);
export const asAuditEventSource = (v: unknown): AuditEventSource | null =>
  asMember(AUDIT_EVENT_SOURCES, v);
export const asSubscriptionErrorCode = (
  v: unknown,
): SubscriptionErrorCode | null => asMember(SUBSCRIPTION_ERROR_CODES, v);

/**
 * A denial or error code as received from the server. Codes outside the
 * contract are not silently dropped — a server that starts emitting a new
 * code must be visible — but they are not typed as contract codes either, so
 * a consumer must handle them as `TEMPORARY_BACKEND_FAILURE`-class unknowns.
 */
export function asKnownErrorCodeOrUnknown(
  value: unknown,
): SubscriptionErrorCode | "UNKNOWN_ERROR_CODE" {
  return asSubscriptionErrorCode(value) ?? "UNKNOWN_ERROR_CODE";
}

// ---------------------------------------------------------------------------
// Transport mapping for admin server operations. Mirrors the shape of
// `usageFailureStatus` / `usageFailureRetryable` in `ai_look_usage.ts` so a
// future admin Edge Function answers exactly like the existing ones.
// ---------------------------------------------------------------------------

/** HTTP status a protected admin operation returns for a sanitized code. */
export function adminErrorStatus(code: SubscriptionErrorCode | null): number {
  switch (code) {
    case null:
      return 200;
    case "AUTH_REQUIRED":
      return 401;
    case "ADMIN_UNAUTHORIZED":
      return 403;
    case "USER_NOT_FOUND":
    case "ENTITLEMENT_NOT_FOUND":
    case "USAGE_OPERATION_NOT_FOUND":
      return 404;
    case "INVALID_PLAN_CODE":
    case "INVALID_ALLOWANCE_ADJUSTMENT":
      return 400;
    case "INVALID_ENTITLEMENT_TRANSITION":
    case "ALLOWANCE_BELOW_COMMITTED_USAGE":
    case "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION":
    case "SALON_PILOT_ALREADY_GRANTED":
    case "SALON_PILOT_EXPIRED":
    case "ENTITLEMENT_PENDING":
    case "ENTITLEMENT_INACTIVE":
    case "ENTITLEMENT_EXPIRED":
    case "ENTITLEMENT_SUSPENDED":
    case "ENTITLEMENT_REVOKED":
    case "AI_LOOK_LIMIT_REACHED":
    case "USAGE_ALREADY_COMMITTED":
    case "USAGE_ALREADY_RELEASED":
    case "USAGE_STATE_CONFLICT":
    case "AI_LOOK_RESERVATION_CONFLICT":
    case "IDEMPOTENCY_CONFLICT":
    case "CONCURRENT_MODIFICATION":
    case "PROVIDER_STATE_CONFLICT":
    case "PURCHASE_VERIFICATION_FAILED":
      return 409;
    case "TEMPORARY_BACKEND_FAILURE":
      return 503;
  }
}

/** Whether an identical retry could reasonably succeed. */
export function adminErrorRetryable(
  code: SubscriptionErrorCode | null,
): boolean {
  return code === "TEMPORARY_BACKEND_FAILURE" ||
    code === "CONCURRENT_MODIFICATION";
}
