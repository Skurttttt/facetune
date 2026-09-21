/**
 * Web Admin read models, mutation results, and query contracts (WA-1).
 *
 * Typed views of what the deployed Subscription system already exposes, and
 * strict decoders from the two wire shapes that exist today:
 *
 *   - the camelCase JSON object returned by `public.resolve_subscription_state()`
 *     (contract §74 — the canonical wire shape for both clients)
 *   - snake_case rows of `usage_ledger`, `entitlement_allowance_adjustments`
 *     and `purchased_credit_grants` (contract §42, §43, §74a)
 *
 * Decoding is strict and fails closed: a missing required field, a wrong type,
 * or a value outside the contract vocabulary yields a `DecodeFailure` naming
 * the field — never a defaulted view. The failure carries no raw value, so it
 * can be logged under the logging contract (§91).
 *
 * Nothing here computes entitlement truth. Allowance, usage, availability and
 * authorization are copied from the server figures exactly as received
 * (contract §75). The one derivation is `effectiveEntitlementStatus`, which
 * applies the rule contract §74 states for the read model, from server-supplied
 * fields only. The adjustment preview is an advisory mirror of the database
 * trigger's rule (§44) for display before submission; the trigger remains the
 * authority and recomputes on write.
 *
 * No I/O, no client, no authority, no admin check. Those arrive in WA-2+.
 */

import {
  type AdminAction,
  type AllowanceAdjustmentType,
  type AllowanceSource,
  type AllowanceUnit,
  asAdminAction,
  asAllowanceAdjustmentType,
  asAllowanceSource,
  asAllowanceUnit,
  asAuditEventSource,
  asBillingProvider,
  asEntitlementStatus,
  asPreviewSourceMode,
  asPurchasedCreditClass,
  asResetPolicy,
  asSubscriptionErrorCode,
  asSubscriptionPlanCode,
  asUsageStatus,
  asUsageType,
  type AuditEventSource,
  type BillingProvider,
  type EntitlementStatus,
  type PreviewSourceMode,
  type PurchasedCreditClass,
  type ResetPolicy,
  type SubscriptionErrorCode,
  type SubscriptionPlanCode,
  type UsageStatus,
  type UsageType,
} from "./admin_contract.ts";

// ---------------------------------------------------------------------------
// Decoding primitives
// ---------------------------------------------------------------------------

/** Why a payload could not become a typed view. Carries no payload data. */
export interface DecodeFailure {
  ok: false;
  /** Always the contract's generic server-side code for a malformed payload. */
  errorCode: "TEMPORARY_BACKEND_FAILURE";
  /** Dotted field path that failed, e.g. `entitlementStatus`. */
  field: string;
  reason: "missing" | "wrong_type" | "unknown_value" | "not_an_object";
}

export type DecodeResult<T> = { ok: true; value: T } | DecodeFailure;

class Decode extends Error {
  constructor(
    readonly field: string,
    readonly reason: DecodeFailure["reason"],
  ) {
    super(`${reason}: ${field}`);
  }
}

const fail = (
  field: string,
  reason: DecodeFailure["reason"],
): DecodeFailure => ({
  ok: false,
  errorCode: "TEMPORARY_BACKEND_FAILURE",
  field,
  reason,
});

function run<T>(decode: () => T): DecodeResult<T> {
  try {
    return { ok: true, value: decode() };
  } catch (error) {
    if (error instanceof Decode) return fail(error.field, error.reason);
    throw error;
  }
}

type Rec = Record<string, unknown>;

function object(payload: unknown, field: string): Rec {
  if (
    typeof payload !== "object" || payload === null || Array.isArray(payload)
  ) {
    throw new Decode(field, "not_an_object");
  }
  return payload as Rec;
}

function present(r: Rec, k: string): unknown {
  if (!(k in r) || r[k] === undefined) throw new Decode(k, "missing");
  return r[k];
}

function str(r: Rec, k: string): string {
  const v = present(r, k);
  if (typeof v !== "string") throw new Decode(k, "wrong_type");
  return v;
}
function strOrNull(r: Rec, k: string): string | null {
  const v = present(r, k);
  if (v === null) return null;
  if (typeof v !== "string") throw new Decode(k, "wrong_type");
  return v;
}
function bool(r: Rec, k: string): boolean {
  const v = present(r, k);
  if (typeof v !== "boolean") throw new Decode(k, "wrong_type");
  return v;
}
function int(r: Rec, k: string): number {
  const v = present(r, k);
  if (typeof v !== "number" || !Number.isInteger(v)) {
    throw new Decode(k, "wrong_type");
  }
  return v;
}
/** Timestamps travel as ISO-8601 strings in both wire shapes; kept as strings. */
function ts(r: Rec, k: string): string {
  return str(r, k);
}
function tsOrNull(r: Rec, k: string): string | null {
  return strOrNull(r, k);
}
function vocab<T>(r: Rec, k: string, as: (v: unknown) => T | null): T {
  const v = present(r, k);
  const parsed = as(v);
  if (parsed === null) {
    throw new Decode(k, typeof v === "string" ? "unknown_value" : "wrong_type");
  }
  return parsed;
}
function vocabOrNull<T>(
  r: Rec,
  k: string,
  as: (v: unknown) => T | null,
): T | null {
  const v = present(r, k);
  if (v === null) return null;
  return vocab(r, k, as);
}

// ---------------------------------------------------------------------------
// Allowance, capability, purchased credits — contract §29–§31, §9, §74a
// ---------------------------------------------------------------------------

/**
 * The server's capacity figures, copied verbatim. `availableAiLooks` is the
 * authoritative number for a NEW generation; `remainingAiLooks` is the
 * user-facing "N of M" that ignores in-flight reservations (contract §30).
 * Consumers display these; they never recompute them.
 */
export interface AllowanceSummary {
  allowanceUnit: AllowanceUnit;
  baseAllowance: number;
  allowanceAdjustmentTotal: number;
  effectiveAllowance: number;
  committedUsage: number;
  reservedUsage: number;
  availableAiLooks: number;
  remainingAiLooks: number;
}

/** Plan capability, read from server product configuration. Contract §9. */
export interface PlanCapability {
  allowanceUnit: AllowanceUnit;
  tutorialEnabled: boolean;
  finalPreviewEnabled: boolean;
  publiclyPurchasable: boolean;
}

/** Contract §74a. Read-only for Web Admin V1. */
export interface PurchasedCreditSummary {
  purchasedTutorialCreditsRemaining: number;
  purchasedPreviewCreditsRemaining: number;
  purchasedCreditsUsable: boolean;
  availablePurchasedCredits: number;
  nextAllowanceSource: AllowanceSource | null;
  nextAllowanceUnit: AllowanceUnit | null;
}

// ---------------------------------------------------------------------------
// resolve_subscription_state() — the canonical read model (contract §74)
// ---------------------------------------------------------------------------

/** A resolved account with a governing entitlement. */
export interface SubscriptionState {
  hasEntitlement: true;
  entitlementId: string;
  planCode: SubscriptionPlanCode;
  planDisplayName: string;
  /** Stored row status. See `effectiveEntitlementStatus`. */
  entitlementStatus: EntitlementStatus;
  billingProvider: BillingProvider;
  providerProductId: string | null;
  capability: PlanCapability;
  periodStart: string | null;
  periodEnd: string | null;
  startsAt: string;
  expiresAt: string | null;
  autoRenew: boolean;
  resetPolicy: ResetPolicy;
  resetAt: string | null;
  allowance: AllowanceSummary;
  generationAuthorized: boolean;
  denialReason: SubscriptionErrorCode | null;
  purchasedCredits: PurchasedCreditSummary;
  verifiedAt: string | null;
  resolvedAt: string;
}

/** An account with no entitlement row at all (broken provisioning), or no session. */
export interface SubscriptionStateAbsent {
  hasEntitlement: false;
  denialReason: SubscriptionErrorCode;
  resolvedAt: string;
}

export type ResolvedSubscriptionState =
  | SubscriptionState
  | SubscriptionStateAbsent;

/** Decodes the JSON object returned by `public.resolve_subscription_state()`. */
export function decodeSubscriptionState(
  payload: unknown,
): DecodeResult<ResolvedSubscriptionState> {
  return run(() => {
    const r = object(payload, "$");
    if (!bool(r, "hasEntitlement")) {
      return {
        hasEntitlement: false,
        denialReason: vocab(r, "denialReason", asSubscriptionErrorCode),
        resolvedAt: ts(r, "resolvedAt"),
      } satisfies SubscriptionStateAbsent;
    }
    const allowanceUnit = vocab(r, "allowanceUnit", asAllowanceUnit);
    return {
      hasEntitlement: true,
      entitlementId: str(r, "entitlementId"),
      planCode: vocab(r, "planCode", asSubscriptionPlanCode),
      planDisplayName: str(r, "planDisplayName"),
      entitlementStatus: vocab(r, "entitlementStatus", asEntitlementStatus),
      billingProvider: vocab(r, "billingProvider", asBillingProvider),
      providerProductId: strOrNull(r, "providerProductId"),
      capability: {
        allowanceUnit,
        tutorialEnabled: bool(r, "tutorialEnabled"),
        finalPreviewEnabled: bool(r, "finalPreviewEnabled"),
        publiclyPurchasable: bool(r, "publiclyPurchasable"),
      },
      periodStart: tsOrNull(r, "periodStart"),
      periodEnd: tsOrNull(r, "periodEnd"),
      startsAt: ts(r, "startsAt"),
      expiresAt: tsOrNull(r, "expiresAt"),
      autoRenew: bool(r, "autoRenew"),
      resetPolicy: vocab(r, "resetPolicy", asResetPolicy),
      resetAt: tsOrNull(r, "resetAt"),
      allowance: {
        allowanceUnit,
        baseAllowance: int(r, "baseAllowance"),
        allowanceAdjustmentTotal: int(r, "allowanceAdjustmentTotal"),
        effectiveAllowance: int(r, "effectiveAllowance"),
        committedUsage: int(r, "committedUsage"),
        reservedUsage: int(r, "reservedUsage"),
        availableAiLooks: int(r, "availableAiLooks"),
        remainingAiLooks: int(r, "remainingAiLooks"),
      },
      generationAuthorized: bool(r, "generationAuthorized"),
      denialReason: vocabOrNull(r, "denialReason", asSubscriptionErrorCode),
      purchasedCredits: {
        purchasedTutorialCreditsRemaining: int(
          r,
          "purchasedTutorialCreditsRemaining",
        ),
        purchasedPreviewCreditsRemaining: int(
          r,
          "purchasedPreviewCreditsRemaining",
        ),
        purchasedCreditsUsable: bool(r, "purchasedCreditsUsable"),
        availablePurchasedCredits: int(r, "availablePurchasedCredits"),
        nextAllowanceSource: vocabOrNull(
          r,
          "nextAllowanceSource",
          asAllowanceSource,
        ),
        nextAllowanceUnit: vocabOrNull(r, "nextAllowanceUnit", asAllowanceUnit),
      },
      verifiedAt: tsOrNull(r, "verifiedAt"),
      resolvedAt: ts(r, "resolvedAt"),
    } satisfies SubscriptionState;
  });
}

/**
 * The status an admin should be shown. Contract §74: a row may still read
 * `active` after `expiresAt` / `periodEnd` has passed, in which case the
 * server denies with `SALON_PILOT_EXPIRED` or `ENTITLEMENT_EXPIRED`. Derived
 * from server-supplied fields only; no clock is consulted here.
 */
export function effectiveEntitlementStatus(
  state: SubscriptionState,
): EntitlementStatus {
  const lapsed = state.denialReason === "SALON_PILOT_EXPIRED" ||
    state.denialReason === "ENTITLEMENT_EXPIRED";
  if (
    lapsed && (state.entitlementStatus === "active" ||
      state.entitlementStatus === "grace_period")
  ) {
    return "expired";
  }
  return state.entitlementStatus;
}

// ---------------------------------------------------------------------------
// Admin views — Web Admin SOT §15, §16, §19 over contract §65
// ---------------------------------------------------------------------------

/** One row of the Users list. Email is present only via a privileged server read. */
export interface AdminUserSummary {
  userId: string;
  email: string | null;
  displayName: string | null;
  /** Supabase anonymous guest; can never hold admin privilege. */
  isAnonymous: boolean;
  createdAt: string;
  currentPlanCode: SubscriptionPlanCode | null;
  currentEntitlementStatus: EntitlementStatus | null;
  availableAiLooks: number | null;
}

/** The current entitlement as the admin sees it. Web Admin SOT §19. */
export interface AdminEntitlementView {
  entitlementId: string;
  userId: string;
  planCode: SubscriptionPlanCode;
  planDisplayName: string;
  storedStatus: EntitlementStatus;
  effectiveStatus: EntitlementStatus;
  billingProvider: BillingProvider;
  providerProductId: string | null;
  capability: PlanCapability;
  allowance: AllowanceSummary;
  periodStart: string | null;
  periodEnd: string | null;
  startsAt: string;
  expiresAt: string | null;
  autoRenew: boolean;
  resetPolicy: ResetPolicy;
  resetAt: string | null;
  generationAuthorized: boolean;
  denialReason: SubscriptionErrorCode | null;
  /** Optimistic-concurrency token for later mutation phases. Null until an admin read supplies it. */
  version: number | null;
  verifiedAt: string | null;
  resolvedAt: string;
}

/** Maps a resolved state to the admin view. Pure; copies every figure verbatim. */
export function toAdminEntitlementView(
  userId: string,
  state: SubscriptionState,
  version: number | null = null,
): AdminEntitlementView {
  return {
    entitlementId: state.entitlementId,
    userId,
    planCode: state.planCode,
    planDisplayName: state.planDisplayName,
    storedStatus: state.entitlementStatus,
    effectiveStatus: effectiveEntitlementStatus(state),
    billingProvider: state.billingProvider,
    providerProductId: state.providerProductId,
    capability: state.capability,
    allowance: state.allowance,
    periodStart: state.periodStart,
    periodEnd: state.periodEnd,
    startsAt: state.startsAt,
    expiresAt: state.expiresAt,
    autoRenew: state.autoRenew,
    resetPolicy: state.resetPolicy,
    resetAt: state.resetAt,
    generationAuthorized: state.generationAuthorized,
    denialReason: state.denialReason,
    version,
    verifiedAt: state.verifiedAt,
    resolvedAt: state.resolvedAt,
  };
}

/** Web Admin SOT §16. Composed by a protected server read; nothing here fetches. */
export interface AdminUserDetail {
  user: AdminUserSummary;
  entitlement: AdminEntitlementView | null;
  purchasedCredits: PurchasedCreditSummary | null;
  adjustments: AllowanceAdjustment[];
}

// ---------------------------------------------------------------------------
// Usage ledger — contract §42 (rows are snake_case table columns)
// ---------------------------------------------------------------------------

/**
 * The concrete canonical Final Preview lineage. Discriminated by
 * `source_mode`; the id is null when the user later deleted the history item
 * (deletion never refunds). Never inferred from which id column is populated.
 */
export type CanonicalPreviewRef =
  | { sourceMode: "standard"; generatedImageId: string | null }
  | { sourceMode: "makeup_kit"; kitGeneratedImageId: string | null };

export interface AdminUsageRecord {
  id: string;
  userId: string;
  entitlementId: string;
  usageType: UsageType;
  operationId: string;
  status: UsageStatus;
  planCode: SubscriptionPlanCode | null;
  allowanceUnit: AllowanceUnit | null;
  allowanceSource: AllowanceSource;
  purchasedCreditGrantId: string | null;
  /** Null unless the row is committed. */
  canonicalPreview: CanonicalPreviewRef | null;
  periodStart: string | null;
  periodEnd: string | null;
  reservedAt: string;
  committedAt: string | null;
  releasedAt: string | null;
  sanitizedFailureCode: string | null;
  createdAt: string;
  updatedAt: string;
}

/** Decodes one `public.usage_ledger` row. */
export function decodeUsageRecord(
  row: unknown,
): DecodeResult<AdminUsageRecord> {
  return run(() => {
    const r = object(row, "$");
    const status = vocab(r, "status", asUsageStatus);
    const sourceMode = vocabOrNull(r, "source_mode", asPreviewSourceMode);
    const generatedImageId = strOrNull(r, "canonical_generated_image_id");
    const kitGeneratedImageId = strOrNull(
      r,
      "canonical_kit_generated_image_id",
    );

    let canonicalPreview: CanonicalPreviewRef | null = null;
    if (status === "committed") {
      if (sourceMode === null) throw new Decode("source_mode", "missing");
      canonicalPreview = sourceMode === "standard"
        ? { sourceMode, generatedImageId }
        : { sourceMode, kitGeneratedImageId };
    }

    const allowanceSource = vocab(r, "allowance_source", asAllowanceSource);
    const purchasedCreditGrantId = strOrNull(r, "purchased_credit_grant_id");
    if (
      (allowanceSource === "purchased_credit") !==
        (purchasedCreditGrantId !== null)
    ) {
      throw new Decode("purchased_credit_grant_id", "wrong_type");
    }

    return {
      id: str(r, "id"),
      userId: str(r, "user_id"),
      entitlementId: str(r, "entitlement_id"),
      usageType: vocab(r, "usage_type", asUsageType),
      operationId: str(r, "operation_id"),
      status,
      planCode: vocabOrNull(r, "plan_code", asSubscriptionPlanCode),
      allowanceUnit: vocabOrNull(r, "allowance_unit", asAllowanceUnit),
      allowanceSource,
      purchasedCreditGrantId,
      canonicalPreview,
      periodStart: tsOrNull(r, "period_start"),
      periodEnd: tsOrNull(r, "period_end"),
      reservedAt: ts(r, "reserved_at"),
      committedAt: tsOrNull(r, "committed_at"),
      releasedAt: tsOrNull(r, "released_at"),
      sanitizedFailureCode: strOrNull(r, "sanitized_failure_code"),
      createdAt: ts(r, "created_at"),
      updatedAt: ts(r, "updated_at"),
    } satisfies AdminUsageRecord;
  });
}

/** Aggregate for the Usage page. Counts and capacity come from the server. */
export interface AdminUsageSummary {
  entitlementId: string;
  allowance: AllowanceSummary;
  /** Released rows are history, not capacity; shown separately (Web Admin SOT §37). */
  releasedCount: number;
  /** Rows drawn from purchased credits; never part of `allowance`. */
  purchasedCreditCommittedCount: number;
  purchasedCreditReservedCount: number;
}

// ---------------------------------------------------------------------------
// Allowance adjustments — contract §43, §44 (rows are snake_case)
// ---------------------------------------------------------------------------

export interface AllowanceAdjustment {
  id: string;
  entitlementId: string;
  targetUserId: string;
  /** Null only when the administrator's account was later deleted (ON DELETE SET NULL). */
  adminUserId: string | null;
  adjustmentType: AllowanceAdjustmentType;
  /** Signed: positive for increase, negative for decrease, never zero. */
  amount: number;
  reason: string;
  idempotencyKey: string;
  createdAt: string;
}

/** Decodes one `public.entitlement_allowance_adjustments` row. */
export function decodeAllowanceAdjustment(
  row: unknown,
): DecodeResult<AllowanceAdjustment> {
  return run(() => {
    const r = object(row, "$");
    const adjustmentType = vocab(
      r,
      "adjustment_type",
      asAllowanceAdjustmentType,
    );
    const amount = int(r, "amount");
    const signAgrees = adjustmentType === "increase_allowance"
      ? amount > 0
      : amount < 0;
    if (!signAgrees) throw new Decode("amount", "wrong_type");
    return {
      id: str(r, "id"),
      entitlementId: str(r, "entitlement_id"),
      targetUserId: str(r, "target_user_id"),
      adminUserId: strOrNull(r, "admin_user_id"),
      adjustmentType,
      amount,
      reason: str(r, "reason"),
      idempotencyKey: str(r, "idempotency_key"),
      createdAt: ts(r, "created_at"),
    } satisfies AllowanceAdjustment;
  });
}

/**
 * Advisory preview of an adjustment before it is submitted (Web Admin SOT
 * §25). Mirrors the rule the `entitlement_allowance_adjustments` insert
 * trigger enforces (contract §44): the effective allowance after the change
 * must still cover committed AND currently reserved usage. The trigger
 * recomputes under the account lock and is the authority; a preview that says
 * `valid` can still be refused on write, and a consumer must handle that.
 */
export interface AllowanceAdjustmentPreview {
  entitlementId: string;
  adjustmentType: AllowanceAdjustmentType;
  amount: number;
  effectiveAllowanceBefore: number;
  effectiveAllowanceAfter: number;
  committedUsage: number;
  reservedUsage: number;
  /** Expected `remainingAiLooks` after the change (effective − committed). */
  expectedRemaining: number;
  /** Expected `availableAiLooks` after the change (effective − committed − reserved). */
  expectedAvailable: number;
  valid: boolean;
  rejectionCode:
    | "INVALID_ALLOWANCE_ADJUSTMENT"
    | "ALLOWANCE_BELOW_COMMITTED_USAGE"
    | "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION"
    | null;
}

export function previewAllowanceAdjustment(
  entitlementId: string,
  current: Pick<
    AllowanceSummary,
    "effectiveAllowance" | "committedUsage" | "reservedUsage"
  >,
  amount: number,
): AllowanceAdjustmentPreview {
  const adjustmentType: AllowanceAdjustmentType = amount < 0
    ? "decrease_allowance"
    : "increase_allowance";
  const after = current.effectiveAllowance + amount;
  const base = {
    entitlementId,
    adjustmentType,
    amount,
    effectiveAllowanceBefore: current.effectiveAllowance,
    effectiveAllowanceAfter: after,
    committedUsage: current.committedUsage,
    reservedUsage: current.reservedUsage,
    expectedRemaining: Math.max(0, after - current.committedUsage),
    expectedAvailable: Math.max(
      0,
      after - current.committedUsage - current.reservedUsage,
    ),
  };
  if (!Number.isInteger(amount) || amount === 0 || after < 0) {
    return {
      ...base,
      valid: false,
      rejectionCode: "INVALID_ALLOWANCE_ADJUSTMENT",
    };
  }
  if (after < current.committedUsage) {
    return {
      ...base,
      valid: false,
      rejectionCode: "ALLOWANCE_BELOW_COMMITTED_USAGE",
    };
  }
  if (after < current.committedUsage + current.reservedUsage) {
    return {
      ...base,
      valid: false,
      rejectionCode: "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION",
    };
  }
  return { ...base, valid: true, rejectionCode: null };
}

// ---------------------------------------------------------------------------
// Purchased credit grants — contract §74a (read-only; rows are snake_case)
// ---------------------------------------------------------------------------

export interface PurchasedCreditGrantView {
  id: string;
  userId: string;
  billingProvider: BillingProvider;
  providerProductId: string;
  packCode: string;
  creditClass: PurchasedCreditClass;
  quantityGranted: number;
  grantedUnderPlanCode: SubscriptionPlanCode | null;
  grantedUnderEntitlementId: string | null;
  testPurchase: boolean;
  grantedAt: string;
  revokedAt: string | null;
  revocationReason: string | null;
}

/**
 * Decodes one `public.purchased_credit_grants` row for display. The purchase
 * reference, order id and revocation reference are deliberately not read:
 * they are support data the admin read model does not need (contract §66).
 */
export function decodePurchasedCreditGrant(
  row: unknown,
): DecodeResult<PurchasedCreditGrantView> {
  return run(() => {
    const r = object(row, "$");
    return {
      id: str(r, "id"),
      userId: str(r, "user_id"),
      billingProvider: vocab(r, "billing_provider", asBillingProvider),
      providerProductId: str(r, "provider_product_id"),
      packCode: str(r, "pack_code"),
      creditClass: vocab(r, "credit_class", asPurchasedCreditClass),
      quantityGranted: int(r, "quantity_granted"),
      grantedUnderPlanCode: vocabOrNull(
        r,
        "granted_under_plan_code",
        asSubscriptionPlanCode,
      ),
      grantedUnderEntitlementId: strOrNull(r, "granted_under_entitlement_id"),
      testPurchase: bool(r, "test_purchase"),
      grantedAt: ts(r, "granted_at"),
      revokedAt: tsOrNull(r, "revoked_at"),
      revocationReason: strOrNull(r, "revocation_reason"),
    } satisfies PurchasedCreditGrantView;
  });
}

// ---------------------------------------------------------------------------
// Audit events — contract §63. No table exists yet (WA-0 §H.3); this is the
// shape later phases persist and read.
// ---------------------------------------------------------------------------

/** Privacy-safe snapshot of the fields an action changed. Never image or prompt data. */
export interface EntitlementStateSnapshot {
  status: EntitlementStatus | null;
  planCode: SubscriptionPlanCode | null;
  effectiveAllowance: number | null;
  allowanceAdjustmentTotal: number | null;
  expiresAt: string | null;
  version: number | null;
}

export interface AuditEvent {
  id: string;
  source: AuditEventSource;
  /** Null for `provider` / `system` events. Required for `admin`. */
  adminUserId: string | null;
  action: AdminAction;
  targetUserId: string;
  targetEntitlementId: string | null;
  beforeState: EntitlementStateSnapshot | null;
  afterState: EntitlementStateSnapshot | null;
  reason: string | null;
  requestCorrelationId: string | null;
  idempotencyKey: string | null;
  createdAt: string;
}

function snapshotOrNull(r: Rec, k: string): EntitlementStateSnapshot | null {
  const v = present(r, k);
  if (v === null) return null;
  const s = object(v, k);
  return {
    status: vocabOrNull(s, "status", asEntitlementStatus),
    planCode: vocabOrNull(s, "planCode", asSubscriptionPlanCode),
    effectiveAllowance: s.effectiveAllowance === null
      ? null
      : int(s, "effectiveAllowance"),
    allowanceAdjustmentTotal: s.allowanceAdjustmentTotal === null
      ? null
      : int(s, "allowanceAdjustmentTotal"),
    expiresAt: tsOrNull(s, "expiresAt"),
    version: s.version === null ? null : int(s, "version"),
  };
}

/** Decodes an audit event in its camelCase wire form. */
export function decodeAuditEvent(payload: unknown): DecodeResult<AuditEvent> {
  return run(() => {
    const r = object(payload, "$");
    const source = vocab(r, "source", asAuditEventSource);
    const adminUserId = strOrNull(r, "adminUserId");
    if (source === "admin" && adminUserId === null) {
      throw new Decode("adminUserId", "missing");
    }
    return {
      id: str(r, "id"),
      source,
      adminUserId,
      action: vocab(r, "action", asAdminAction),
      targetUserId: str(r, "targetUserId"),
      targetEntitlementId: strOrNull(r, "targetEntitlementId"),
      beforeState: snapshotOrNull(r, "beforeState"),
      afterState: snapshotOrNull(r, "afterState"),
      reason: strOrNull(r, "reason"),
      requestCorrelationId: strOrNull(r, "requestCorrelationId"),
      idempotencyKey: strOrNull(r, "idempotencyKey"),
      createdAt: ts(r, "createdAt"),
    } satisfies AuditEvent;
  });
}

// ---------------------------------------------------------------------------
// Mutation results — contract §73. Decoded only; no mutation exists yet.
// ---------------------------------------------------------------------------

export interface AdminMutationSuccess {
  success: true;
  action: AdminAction;
  entitlementId: string;
  planCode: SubscriptionPlanCode;
  status: EntitlementStatus;
  effectiveAllowance: number;
  committedUsage: number;
  reservedUsage: number;
  availableAiLooks: number;
  expiresAt: string | null;
  updatedAt: string;
  /** True when the server recognised the idempotency key and replayed a prior result. */
  replayed: boolean;
}

export interface AdminMutationFailure {
  success: false;
  action: AdminAction | null;
  errorCode: SubscriptionErrorCode;
  retryable: boolean;
}

export type AdminMutationResult = AdminMutationSuccess | AdminMutationFailure;

export function decodeAdminMutationResult(
  payload: unknown,
): DecodeResult<AdminMutationResult> {
  return run(() => {
    const r = object(payload, "$");
    if (!bool(r, "success")) {
      return {
        success: false,
        action: vocabOrNull(r, "action", asAdminAction),
        errorCode: vocab(r, "errorCode", asSubscriptionErrorCode),
        retryable: bool(r, "retryable"),
      } satisfies AdminMutationFailure;
    }
    return {
      success: true,
      action: vocab(r, "action", asAdminAction),
      entitlementId: str(r, "entitlementId"),
      planCode: vocab(r, "planCode", asSubscriptionPlanCode),
      status: vocab(r, "status", asEntitlementStatus),
      effectiveAllowance: int(r, "effectiveAllowance"),
      committedUsage: int(r, "committedUsage"),
      reservedUsage: int(r, "reservedUsage"),
      availableAiLooks: int(r, "availableAiLooks"),
      expiresAt: tsOrNull(r, "expiresAt"),
      updatedAt: ts(r, "updatedAt"),
      replayed: "replayed" in r ? bool(r, "replayed") : false,
    } satisfies AdminMutationSuccess;
  });
}

// ---------------------------------------------------------------------------
// Query contracts — Web Admin SOT §14, §58, §59. Bounded by construction.
// ---------------------------------------------------------------------------

export const ADMIN_PAGE_SIZE_DEFAULT = 25 as const;
export const ADMIN_PAGE_SIZE_MAX = 100 as const;

/** Keyset pagination: an opaque server-issued cursor, never a raw offset the browser invents. */
export interface AdminPagination {
  limit: number;
  cursor: string | null;
}

export interface AdminPage<T> {
  items: T[];
  nextCursor: string | null;
}

/** Clamps a requested page size into the bounded range. */
export function boundedPageSize(requested: unknown): number {
  if (
    typeof requested !== "number" || !Number.isInteger(requested) ||
    requested < 1
  ) {
    return ADMIN_PAGE_SIZE_DEFAULT;
  }
  return Math.min(requested, ADMIN_PAGE_SIZE_MAX);
}

/** Users search. Email or user id — lookup only, never an authorization key (contract §46). */
export interface AdminUserQuery extends AdminPagination {
  search: string | null;
  planCode: SubscriptionPlanCode | null;
  entitlementStatus: EntitlementStatus | null;
  billingProvider: BillingProvider | null;
}

export interface AdminUsageQuery extends AdminPagination {
  userId: string | null;
  entitlementId: string | null;
  status: UsageStatus | null;
  allowanceSource: AllowanceSource | null;
  fromInclusive: string | null;
  toExclusive: string | null;
}

export interface AdminAuditQuery extends AdminPagination {
  targetUserId: string | null;
  targetEntitlementId: string | null;
  adminUserId: string | null;
  action: AdminAction | null;
  source: AuditEventSource | null;
  fromInclusive: string | null;
  toExclusive: string | null;
}
