// Pure verification logic for a Google Play subscription purchase.
//
// Everything here is a total function over data: no network, no environment,
// no clock. That is deliberate — the rules that decide whether a purchase
// grants an entitlement are the part most worth testing exhaustively, and they
// are testable only if they do not need a store, a service account, or a
// device to run.
//
// The HTTP and credential work lives in `google_play_api.ts`; persistence lives
// in the `activate_verified_google_play_subscription` database function.

/// A sanitized failure. `code` is drawn from the shared subscription error
/// vocabulary so a refusal means the same thing to the client here as it does
/// coming out of the database.
export class VerificationFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

/// The subset of `SubscriptionPurchaseV2` this backend reads.
///
/// Typed loosely on purpose: the response is external data, so every field is
/// optional here and validated below rather than assumed by a type assertion.
export interface SubscriptionPurchaseV2 {
  subscriptionState?: string;
  startTime?: string;
  linkedPurchaseToken?: string;
  acknowledgementState?: string;
  testPurchase?: Record<string, unknown> | null;
  externalAccountIdentifiers?: {
    obfuscatedExternalAccountId?: string;
    obfuscatedExternalProfileId?: string;
  };
  lineItems?: Array<{
    productId?: string;
    expiryTime?: string;
    autoRenewingPlan?: { autoRenewEnabled?: boolean };
    offerDetails?: { basePlanId?: string; offerId?: string };
  }>;
}

/// What the provider said, reduced to the facts an entitlement depends on.
export interface VerifiedPurchase {
  providerProductId: string;
  subscriptionState: string;
  subscriptionStart: string | null;
  periodEnd: string | null;
  autoRenew: boolean;
  testPurchase: boolean;
  linkedPurchaseToken: string | null;
  needsAcknowledgement: boolean;
  /// True when the client named a different product than the provider did.
  /// Recorded for diagnostics; the provider's answer is used regardless.
  clientProductMismatch: boolean;
}

/// Every state the `SubscriptionState` enum defines.
///
/// Listed exhaustively so an unrecognised value — a new state Google adds, or a
/// malformed response — is refused rather than silently treated as one of
/// these. The mapping from state to entitlement status is not made here; that
/// belongs to the database function, which is the only thing that can write.
const knownSubscriptionStates = new Set([
  "SUBSCRIPTION_STATE_PENDING",
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_PAUSED",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_ON_HOLD",
  "SUBSCRIPTION_STATE_CANCELED",
  "SUBSCRIPTION_STATE_EXPIRED",
  "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
]);

/// `SUBSCRIPTION_STATE_UNSPECIFIED` is deliberately absent from the set above.
/// It is a real enum member but it carries no meaning, and treating "the
/// provider did not say" as grounds for anything would be exactly the guess
/// this layer exists to prevent.

const purchaseTokenPattern = /^[A-Za-z0-9._~\-]{1,1024}$/;

/// Validates the request body a client may send.
///
/// The token is the only thing that matters. `providerProductId` is accepted
/// because the client has it to hand and it makes a mismatch visible in
/// diagnostics, but it is never used to decide a plan — see
/// `interpretPurchase`.
/// How the client says the purchase reached it. Telemetry only (SUB-13): it
/// is counted, never acted on, and anything but the two known words is
/// dropped rather than stored.
export type VerificationSource = "purchase" | "restore";

export function parseVerificationRequest(
  value: unknown,
): {
  purchaseToken: string;
  claimedProductId: string | null;
  verificationSource: VerificationSource | null;
} {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new VerificationFailure(
      400,
      "invalid_request",
      "A valid purchase verification request is required.",
    );
  }
  const body = value as Record<string, unknown>;
  const purchaseToken = body.purchaseToken;
  if (
    typeof purchaseToken !== "string" ||
    !purchaseTokenPattern.test(purchaseToken)
  ) {
    throw new VerificationFailure(
      400,
      "invalid_purchase_token",
      "A valid Google Play purchase token is required.",
    );
  }
  const claimed = body.providerProductId;
  const source = body.source;
  return {
    purchaseToken,
    claimedProductId: typeof claimed === "string" && claimed.length > 0
      ? claimed
      : null,
    verificationSource: source === "purchase" || source === "restore"
      ? source
      : null,
  };
}

/// Picks the line item the entitlement is based on.
///
/// A subscription can carry several line items once add-ons exist. Only one is
/// ever a plan we sell, so the first item whose `productId` is in
/// [approvedProductIds] is the one that decides — and if none is, the purchase
/// is refused rather than falling back to the first item, which would let an
/// unrelated product grant a FaceTune plan.
export function selectApprovedLineItem(
  purchase: SubscriptionPurchaseV2,
  approvedProductIds: ReadonlySet<string>,
): NonNullable<SubscriptionPurchaseV2["lineItems"]>[number] {
  const items = purchase.lineItems ?? [];
  for (const item of items) {
    if (
      typeof item?.productId === "string" &&
      approvedProductIds.has(item.productId)
    ) {
      return item;
    }
  }
  throw new VerificationFailure(
    409,
    "INVALID_PLAN_CODE",
    "This purchase is not for a FaceTune plan.",
  );
}

/// Reduces a provider response to the facts that decide an entitlement.
///
/// Rejects anything it cannot read with confidence. Note the ordering: the
/// product comes from the provider's line items, never from
/// [claimedProductId] — that argument exists only so a disagreement can be
/// reported, and the caller's claim is discarded either way.
export function interpretPurchase(
  purchase: SubscriptionPurchaseV2,
  options: {
    approvedProductIds: ReadonlySet<string>;
    claimedProductId: string | null;
    expectedAccountId: string;
  },
): VerifiedPurchase {
  const state = purchase.subscriptionState;
  if (typeof state !== "string" || !knownSubscriptionStates.has(state)) {
    throw new VerificationFailure(
      409,
      "PROVIDER_STATE_CONFLICT",
      "Google Play returned a subscription state FaceTune cannot interpret.",
    );
  }

  // A purchase started from another account must never grant this one, even
  // though Google would happily confirm the token is genuine. The identifier
  // compared here is the opaque account id the client sent at purchase time.
  //
  // It is checked only when present: purchases made before the app began
  // sending one, and some restored purchases, legitimately carry none. Its
  // absence is not evidence of theft, so the database's
  // one-purchase-to-one-account constraint is the backstop for that case.
  const externalAccountId = purchase.externalAccountIdentifiers
    ?.obfuscatedExternalAccountId;
  if (
    typeof externalAccountId === "string" &&
    externalAccountId.length > 0 &&
    externalAccountId !== options.expectedAccountId
  ) {
    throw new VerificationFailure(
      409,
      "PROVIDER_STATE_CONFLICT",
      "This purchase belongs to a different FaceTune account.",
    );
  }

  const item = selectApprovedLineItem(purchase, options.approvedProductIds);
  const providerProductId = item.productId as string;

  return {
    providerProductId,
    subscriptionState: state,
    subscriptionStart: isoTimestampOrNull(purchase.startTime),
    periodEnd: isoTimestampOrNull(item.expiryTime),
    // Absent means not auto-renewing. A prepaid plan has no
    // `autoRenewingPlan` block at all, which is exactly that.
    autoRenew: item.autoRenewingPlan?.autoRenewEnabled === true,
    // Present-and-non-null is the signal; the object's contents are not read.
    testPurchase: purchase.testPurchase !== undefined &&
      purchase.testPurchase !== null,
    linkedPurchaseToken: typeof purchase.linkedPurchaseToken === "string" &&
        purchase.linkedPurchaseToken.length > 0
      ? purchase.linkedPurchaseToken
      : null,
    needsAcknowledgement:
      purchase.acknowledgementState === "ACKNOWLEDGEMENT_STATE_PENDING",
    clientProductMismatch: options.claimedProductId !== null &&
      options.claimedProductId !== providerProductId,
  };
}

/// Accepts only a timestamp that actually parses, and normalizes it.
///
/// A malformed date is dropped rather than passed along: the database refuses
/// a half-formed billing period, and a silently wrong one would corrupt every
/// capacity calculation that hangs off it.
function isoTimestampOrNull(value: unknown): string | null {
  if (typeof value !== "string" || value.length === 0) return null;
  const parsed = Date.parse(value);
  if (Number.isNaN(parsed)) return null;
  return new Date(parsed).toISOString();
}

/// SHA-256 as lowercase hex.
///
/// This is what turns a replayable purchase token into a reference safe to
/// persist. The database never receives the token itself.
export async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

/// Maps a database `errorCode` onto an HTTP status and user-facing message.
///
/// The database returns the shared vocabulary; this decides how it reaches the
/// client. Anything unrecognised becomes a generic failure rather than being
/// echoed, so a new internal code can never leak out as user-visible text.
export function failureForActivationCode(code: string): VerificationFailure {
  switch (code) {
    case "AUTH_REQUIRED":
      return new VerificationFailure(
        401,
        "AUTH_REQUIRED",
        "Sign in before confirming a purchase.",
      );
    case "INVALID_PLAN_CODE":
      return new VerificationFailure(
        409,
        "INVALID_PLAN_CODE",
        "This purchase is not for a FaceTune plan.",
      );
    case "PROVIDER_STATE_CONFLICT":
      return new VerificationFailure(
        409,
        "PROVIDER_STATE_CONFLICT",
        "This purchase could not be applied to your account.",
      );
    case "CONCURRENT_MODIFICATION":
      return new VerificationFailure(
        409,
        "CONCURRENT_MODIFICATION",
        "Your subscription was being updated. Please try again.",
        true,
      );
    case "PURCHASE_VERIFICATION_FAILED":
      return new VerificationFailure(
        409,
        "PURCHASE_VERIFICATION_FAILED",
        "This purchase could not be verified.",
      );
    default:
      return new VerificationFailure(
        500,
        "PURCHASE_VERIFICATION_FAILED",
        "This purchase could not be confirmed. Please try again.",
        true,
      );
  }
}
