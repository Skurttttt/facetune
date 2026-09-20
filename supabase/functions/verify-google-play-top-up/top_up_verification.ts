// Pure verification logic for a Google Play one-time product purchase — a
// SUB-13B top-up pack.
//
// Everything here is a total function over data: no network, no environment,
// no clock. The rules that decide whether a purchase grants credits are the
// part most worth testing exhaustively, and they are testable only if they do
// not need a store, a service account, or a device to run.
//
// The HTTP and credential work lives in the SUB-10 `google_play_api.ts`;
// persistence lives in the `grant_verified_top_up_purchase` database
// function, which owns the product → pack mapping and everything about
// quantity and capability. Nothing about what a purchase is *worth* is
// decided here.

import { VerificationFailure } from "../verify-google-play-purchase/verification.ts";

export { VerificationFailure };

/// The subset of `ProductPurchaseV2` this backend reads.
///
/// Typed loosely on purpose: the response is external data, so every field is
/// optional here and validated below rather than assumed by a type assertion.
export interface ProductPurchaseV2 {
  productLineItem?: Array<{
    productId?: string;
    productOfferDetails?: {
      quantity?: number;
      consumptionState?: string;
      offerId?: string;
      purchaseOptionId?: string;
    };
    /// Older/alternate placement of the same facts, read as a fallback.
    quantity?: number;
    consumptionState?: string;
  }>;
  purchaseStateContext?: { purchaseState?: string };
  acknowledgementState?: string;
  orderId?: string;
  obfuscatedExternalAccountId?: string;
  obfuscatedExternalProfileId?: string;
  testPurchaseContext?: Record<string, unknown> | null;
  purchaseCompletionTime?: string;
  regionCode?: string;
}

/// What the provider said, reduced to the facts a grant depends on.
export interface VerifiedTopUpPurchase {
  providerProductId: string;
  /// `PURCHASED`, `PENDING`, or `CANCELLED` — the provider's own words.
  purchaseState: "PURCHASED" | "PENDING" | "CANCELLED";
  /// Whether Google still expects this purchase to be consumed.
  needsConsumption: boolean;
  /// Google's order id, kept for refund reconciliation. Not a secret.
  orderId: string | null;
  testPurchase: boolean;
  /// True when the client named a different product than the provider did.
  /// Recorded for diagnostics; the provider's answer is used regardless.
  clientProductMismatch: boolean;
}

/// Every state the `PurchaseState` enum defines, minus `UNSPECIFIED`, which
/// carries no meaning and is refused rather than guessed at.
const knownPurchaseStates = new Set(["PURCHASED", "PENDING", "CANCELLED"]);

const purchaseTokenPattern = /^[A-Za-z0-9._~\-]{1,1024}$/;
const orderIdPattern = /^[A-Za-z0-9._-]{1,64}$/;

/// How the client says the purchase reached it. Telemetry-style label only:
/// it is never acted on, and anything but the two known words is dropped.
export type TopUpSource = "purchase" | "restore";

/// Validates the request body a client may send.
///
/// The token is the only thing that matters. `providerProductId` is accepted
/// because the client has it to hand and it makes a mismatch visible in
/// diagnostics, but it is never used to decide a pack — see
/// [interpretTopUpPurchase].
export function parseTopUpRequest(
  value: unknown,
): {
  purchaseToken: string;
  claimedProductId: string | null;
  source: TopUpSource | null;
} {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new VerificationFailure(
      400,
      "invalid_request",
      "A valid top-up verification request is required.",
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
    source: source === "purchase" || source === "restore" ? source : null,
  };
}

/// Reduces a provider response to the facts that decide a grant.
///
/// Rejects anything it cannot read with confidence. The product comes from
/// the provider's line item, never from [claimedProductId]; a purchase whose
/// line item is not an approved top-up pack is refused rather than defaulted,
/// so a subscription token or an unrelated product can never mint credits.
///
/// Quantity is refused unless it is exactly one. The approved matrix is per
/// pack, and multi-quantity purchases are not enabled for these products; a
/// purchase that nonetheless carries another quantity is a configuration
/// disagreement, and the safe answer to a disagreement about money is no.
export function interpretTopUpPurchase(
  purchase: ProductPurchaseV2,
  options: {
    approvedProductIds: ReadonlySet<string>;
    claimedProductId: string | null;
    expectedAccountId: string;
  },
): VerifiedTopUpPurchase {
  const state = purchase.purchaseStateContext?.purchaseState;
  if (typeof state !== "string" || !knownPurchaseStates.has(state)) {
    throw new VerificationFailure(
      409,
      "PROVIDER_STATE_CONFLICT",
      "Google Play returned a purchase state FaceTune cannot interpret.",
    );
  }

  // A purchase started from another account must never grant this one, even
  // though Google would happily confirm the token is genuine. Checked only
  // when present, as for subscriptions: its absence is not evidence of
  // theft, and the one-grant-per-purchase constraint is the backstop.
  const externalAccountId = purchase.obfuscatedExternalAccountId;
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

  const items = purchase.productLineItem ?? [];
  const approved = items.filter((item) =>
    typeof item?.productId === "string" &&
    options.approvedProductIds.has(item.productId)
  );
  if (approved.length !== 1) {
    // No approved pack, or more than one in a single purchase: neither is a
    // shape the approved matrix produces.
    throw new VerificationFailure(
      409,
      "INVALID_TOP_UP_PRODUCT",
      "This purchase is not for a FaceTune top-up pack.",
    );
  }
  const item = approved[0];
  const providerProductId = item.productId as string;

  const quantity = item.productOfferDetails?.quantity ?? item.quantity ?? 1;
  if (quantity !== 1) {
    throw new VerificationFailure(
      409,
      "PROVIDER_STATE_CONFLICT",
      "This purchase has a quantity FaceTune does not sell.",
    );
  }

  const consumptionState = item.productOfferDetails?.consumptionState ??
    item.consumptionState;
  const orderId = purchase.orderId;

  return {
    providerProductId,
    purchaseState: state as VerifiedTopUpPurchase["purchaseState"],
    // Absent is treated as still needing consumption: consuming twice is a
    // harmless provider error, while never consuming is a refund.
    needsConsumption: consumptionState !== "CONSUMPTION_STATE_CONSUMED",
    orderId: typeof orderId === "string" && orderIdPattern.test(orderId)
      ? orderId
      : null,
    // Present-and-non-null is the signal; the object's contents are not read.
    testPurchase: purchase.testPurchaseContext !== undefined &&
      purchase.testPurchaseContext !== null,
    clientProductMismatch: options.claimedProductId !== null &&
      options.claimedProductId !== providerProductId,
  };
}

/// Maps a database `errorCode` from the grant writer onto an HTTP status and
/// user-facing message.
///
/// Anything unrecognised becomes a generic failure rather than being echoed,
/// so a new internal code can never leak out as user-visible text.
export function failureForGrantCode(code: string): VerificationFailure {
  switch (code) {
    case "AUTH_REQUIRED":
      return new VerificationFailure(
        401,
        "AUTH_REQUIRED",
        "Sign in before confirming a purchase.",
      );
    case "INVALID_TOP_UP_PRODUCT":
      return new VerificationFailure(
        409,
        "INVALID_TOP_UP_PRODUCT",
        "This purchase is not for a FaceTune top-up pack.",
      );
    case "TOP_UP_NOT_ELIGIBLE":
      return new VerificationFailure(
        409,
        "TOP_UP_NOT_ELIGIBLE",
        "Top-up packs can only be added to an active paid plan that can use " +
          "them. Google Play will refund a purchase that could not be added.",
      );
    case "TOP_UP_PENDING":
      return new VerificationFailure(
        409,
        "TOP_UP_PENDING",
        "Google Play is still completing this purchase. Your credits will be " +
          "added once it does.",
        true,
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
        "Your account was being updated. Please try again.",
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
