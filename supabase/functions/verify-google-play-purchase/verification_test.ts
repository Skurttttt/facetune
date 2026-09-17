import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  failureForActivationCode,
  interpretPurchase,
  parseVerificationRequest,
  selectApprovedLineItem,
  sha256Hex,
  type SubscriptionPurchaseV2,
  VerificationFailure,
} from "./verification.ts";

const approvedProductIds = new Set([
  "facetune_plus",
  "facetune_pro",
  "facetune_salon_pro",
]);

const account = "11111111-1111-4111-8111-111111111111";
const otherAccount = "22222222-2222-4222-8222-222222222222";

function purchase(
  overrides: Partial<SubscriptionPurchaseV2> = {},
): SubscriptionPurchaseV2 {
  return {
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    startTime: "2026-09-10T00:00:00.000Z",
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    externalAccountIdentifiers: { obfuscatedExternalAccountId: account },
    lineItems: [
      {
        productId: "facetune_pro",
        expiryTime: "2026-10-10T00:00:00.000Z",
        autoRenewingPlan: { autoRenewEnabled: true },
        offerDetails: { basePlanId: "monthly" },
      },
    ],
    ...overrides,
  };
}

function interpret(value: SubscriptionPurchaseV2, claimed: string | null = null) {
  return interpretPurchase(value, {
    approvedProductIds,
    claimedProductId: claimed,
    expectedAccountId: account,
  });
}

// ---------------------------------------------------------------------------
// Request shape
// ---------------------------------------------------------------------------

Deno.test("accepts a request carrying only a purchase token", () => {
  const parsed = parseVerificationRequest({ purchaseToken: "abc.123_token-x" });
  assertEquals(parsed.purchaseToken, "abc.123_token-x");
  assertEquals(parsed.claimedProductId, null);
});

Deno.test("rejects a missing or malformed purchase token", () => {
  for (const body of [
    {},
    { purchaseToken: "" },
    { purchaseToken: 42 },
    { purchaseToken: "has spaces" },
    { purchaseToken: "semi;colon" },
    null,
    [],
    "string",
  ]) {
    assertThrows(
      () => parseVerificationRequest(body),
      VerificationFailure,
    );
  }
});

// ---------------------------------------------------------------------------
// Valid purchases for each approved plan
// ---------------------------------------------------------------------------

for (const productId of ["facetune_plus", "facetune_pro", "facetune_salon_pro"]) {
  Deno.test(`verifies a valid ${productId} purchase`, () => {
    const verified = interpret(
      purchase({
        lineItems: [
          {
            productId,
            expiryTime: "2026-10-10T00:00:00.000Z",
            autoRenewingPlan: { autoRenewEnabled: true },
          },
        ],
      }),
    );

    assertEquals(verified.providerProductId, productId);
    assertEquals(verified.subscriptionState, "SUBSCRIPTION_STATE_ACTIVE");
    assertEquals(verified.subscriptionStart, "2026-09-10T00:00:00.000Z");
    assertEquals(verified.periodEnd, "2026-10-10T00:00:00.000Z");
    assertEquals(verified.autoRenew, true);
    assertEquals(verified.testPurchase, false);
    assertEquals(verified.needsAcknowledgement, true);
  });
}

// ---------------------------------------------------------------------------
// The client's claim is never authority
// ---------------------------------------------------------------------------

Deno.test("a client claiming a richer plan gets the provider's product", () => {
  // The purchase is Plus; the client says Salon Pro. The provider wins.
  const verified = interpret(
    purchase({
      lineItems: [
        { productId: "facetune_plus", expiryTime: "2026-10-10T00:00:00.000Z" },
      ],
    }),
    "facetune_salon_pro",
  );

  assertEquals(verified.providerProductId, "facetune_plus");
  assertEquals(verified.clientProductMismatch, true);
});

Deno.test("an agreeing client claim is not flagged", () => {
  const verified = interpret(purchase(), "facetune_pro");
  assertEquals(verified.providerProductId, "facetune_pro");
  assertEquals(verified.clientProductMismatch, false);
});

// ---------------------------------------------------------------------------
// Products that are not ours
// ---------------------------------------------------------------------------

Deno.test("an unknown product is rejected", () => {
  const error = assertThrows(
    () =>
      interpret(
        purchase({
          lineItems: [
            { productId: "some_other_app_sub", expiryTime: "2026-10-10T00:00:00.000Z" },
          ],
        }),
      ),
    VerificationFailure,
  ) as VerificationFailure;
  assertEquals(error.code, "INVALID_PLAN_CODE");
});

Deno.test("Salon Pilot and Free can never be purchased products", () => {
  for (const productId of ["salon_pilot", "facetune_salon_pilot", "free"]) {
    assertThrows(
      () =>
        interpret(
          purchase({
            lineItems: [
              { productId, expiryTime: "2026-10-10T00:00:00.000Z" },
            ],
          }),
        ),
      VerificationFailure,
    );
  }
});

Deno.test("a purchase with no line items is rejected", () => {
  assertThrows(() => interpret(purchase({ lineItems: [] })), VerificationFailure);
  assertThrows(
    () => interpret(purchase({ lineItems: undefined })),
    VerificationFailure,
  );
});

Deno.test("the approved item is chosen from a multi-item subscription", () => {
  // Add-ons can sit alongside the plan. The first *approved* item decides,
  // rather than simply the first item.
  const item = selectApprovedLineItem(
    purchase({
      lineItems: [
        { productId: "some_addon", expiryTime: "2026-10-10T00:00:00.000Z" },
        { productId: "facetune_pro", expiryTime: "2026-10-10T00:00:00.000Z" },
      ],
    }),
    approvedProductIds,
  );
  assertEquals(item.productId, "facetune_pro");
});

// ---------------------------------------------------------------------------
// Provider state
// ---------------------------------------------------------------------------

Deno.test("every documented subscription state is interpretable", () => {
  for (
    const state of [
      "SUBSCRIPTION_STATE_PENDING",
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_PAUSED",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      "SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_CANCELED",
      "SUBSCRIPTION_STATE_EXPIRED",
      "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
    ]
  ) {
    const verified = interpret(purchase({ subscriptionState: state }));
    assertEquals(verified.subscriptionState, state);
  }
});

Deno.test("an unspecified or unknown state is refused, never guessed", () => {
  for (
    const state of [
      "SUBSCRIPTION_STATE_UNSPECIFIED",
      "SUBSCRIPTION_STATE_SOMETHING_NEW",
      "",
      undefined,
    ]
  ) {
    const error = assertThrows(
      () => interpret(purchase({ subscriptionState: state })),
      VerificationFailure,
    ) as VerificationFailure;
    assertEquals(error.code, "PROVIDER_STATE_CONFLICT");
  }
});

// ---------------------------------------------------------------------------
// Account binding
// ---------------------------------------------------------------------------

Deno.test("a purchase started from another account is rejected", () => {
  const error = assertThrows(
    () =>
      interpret(
        purchase({
          externalAccountIdentifiers: {
            obfuscatedExternalAccountId: otherAccount,
          },
        }),
      ),
    VerificationFailure,
  ) as VerificationFailure;
  assertEquals(error.code, "PROVIDER_STATE_CONFLICT");
});

Deno.test("a purchase carrying no account identifier is still verifiable", () => {
  // Legitimately absent for older or restored purchases. The database's
  // one-purchase-to-one-account constraint is the backstop.
  const verified = interpret(
    purchase({ externalAccountIdentifiers: undefined }),
  );
  assertEquals(verified.providerProductId, "facetune_pro");
});

// ---------------------------------------------------------------------------
// Periods, renewal linkage, and flags
// ---------------------------------------------------------------------------

Deno.test("a malformed expiry is dropped rather than passed on", () => {
  const verified = interpret(
    purchase({
      lineItems: [{ productId: "facetune_pro", expiryTime: "not-a-date" }],
    }),
  );
  assertEquals(verified.periodEnd, null);
});

Deno.test("a missing auto-renewing plan means not renewing", () => {
  const verified = interpret(
    purchase({
      lineItems: [
        { productId: "facetune_pro", expiryTime: "2026-10-10T00:00:00.000Z" },
      ],
    }),
  );
  assertEquals(verified.autoRenew, false);
});

Deno.test("a replacement purchase carries the token it supersedes", () => {
  const verified = interpret(
    purchase({ linkedPurchaseToken: "previous-token" }),
  );
  assertEquals(verified.linkedPurchaseToken, "previous-token");
});

Deno.test("an empty linked token is treated as absent", () => {
  assertEquals(interpret(purchase({ linkedPurchaseToken: "" })).linkedPurchaseToken, null);
});

Deno.test("a license-tester purchase is flagged", () => {
  assertEquals(interpret(purchase({ testPurchase: {} })).testPurchase, true);
  assertEquals(interpret(purchase()).testPurchase, false);
});

Deno.test("an already-acknowledged purchase is not acknowledged again", () => {
  const verified = interpret(
    purchase({ acknowledgementState: "ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED" }),
  );
  assertEquals(verified.needsAcknowledgement, false);
});

// ---------------------------------------------------------------------------
// The purchase reference
// ---------------------------------------------------------------------------

Deno.test("the purchase reference is a stable sha-256 of the token", async () => {
  const reference = await sha256Hex("provider-purchase-token");
  assertEquals(reference.length, 64);
  assert(/^[0-9a-f]{64}$/.test(reference));
  assertEquals(reference, await sha256Hex("provider-purchase-token"));
});

Deno.test("the reference does not contain the token", async () => {
  const token = "a-very-secret-purchase-token";
  const reference = await sha256Hex(token);
  assertEquals(reference.includes(token), false);
  assert(reference !== await sha256Hex(`${token}x`));
});

// ---------------------------------------------------------------------------
// Sanitized failures
// ---------------------------------------------------------------------------

Deno.test("known activation codes map to their own sanitized failure", () => {
  assertEquals(failureForActivationCode("AUTH_REQUIRED").status, 401);
  assertEquals(failureForActivationCode("INVALID_PLAN_CODE").status, 409);
  assertEquals(failureForActivationCode("PROVIDER_STATE_CONFLICT").status, 409);
  assertEquals(
    failureForActivationCode("CONCURRENT_MODIFICATION").retryable,
    true,
  );
});

Deno.test("an unrecognised activation code is never echoed to the client", () => {
  const failure = failureForActivationCode("SOME_INTERNAL_DETAIL");
  assertEquals(failure.code, "PURCHASE_VERIFICATION_FAILED");
  assertEquals(failure.message.includes("SOME_INTERNAL_DETAIL"), false);
});

Deno.test("no failure message leaks a token or provider payload", () => {
  for (
    const code of [
      "AUTH_REQUIRED",
      "INVALID_PLAN_CODE",
      "PROVIDER_STATE_CONFLICT",
      "CONCURRENT_MODIFICATION",
      "PURCHASE_VERIFICATION_FAILED",
      "anything-else",
    ]
  ) {
    const failure = failureForActivationCode(code);
    assert(failure.message.length > 0);
    assertEquals(failure.message.toLowerCase().includes("token"), false);
    assertEquals(failure.message.includes("androidpublisher"), false);
  }
});
