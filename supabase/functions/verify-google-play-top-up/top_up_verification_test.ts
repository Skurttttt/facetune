import {
  assert,
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  failureForGrantCode,
  interpretTopUpPurchase,
  parseTopUpRequest,
  type ProductPurchaseV2,
  VerificationFailure,
} from "./top_up_verification.ts";

const approvedProductIds = new Set([
  "facetune_ai_look_topup_1",
  "facetune_preview_credit_topup_10",
]);

const account = "user-account-id";

function purchase(
  overrides: Partial<ProductPurchaseV2> = {},
): ProductPurchaseV2 {
  return {
    productLineItem: [
      {
        productId: "facetune_ai_look_topup_1",
        productOfferDetails: {
          quantity: 1,
          consumptionState: "CONSUMPTION_STATE_YET_TO_BE_CONSUMED",
        },
      },
    ],
    purchaseStateContext: { purchaseState: "PURCHASED" },
    acknowledgementState: "ACKNOWLEDGEMENT_STATE_PENDING",
    orderId: "GPA.1111-2222-3333-44444",
    obfuscatedExternalAccountId: account,
    ...overrides,
  };
}

function interpret(value: ProductPurchaseV2, claimed: string | null = null) {
  return interpretTopUpPurchase(value, {
    approvedProductIds,
    claimedProductId: claimed,
    expectedAccountId: account,
  });
}

// ---------------------------------------------------------------------------
// Request parsing
// ---------------------------------------------------------------------------

Deno.test("accepts a request carrying only a purchase token", () => {
  const parsed = parseTopUpRequest({ purchaseToken: "abc.123_token-x" });
  assertEquals(parsed.purchaseToken, "abc.123_token-x");
  assertEquals(parsed.claimedProductId, null);
  assertEquals(parsed.source, null);
});

Deno.test("a client-supplied quantity or class is not even parsed", () => {
  const parsed = parseTopUpRequest({
    purchaseToken: "abc.123_token-x",
    quantity: 500,
    creditClass: "tutorial_capable_ai_look",
    packCode: "extra_ai_look",
  });
  assertEquals(Object.keys(parsed).sort(), [
    "claimedProductId",
    "purchaseToken",
    "source",
  ]);
});

Deno.test("rejects a missing or malformed purchase token", () => {
  for (
    const body of [
      {},
      { purchaseToken: "" },
      { purchaseToken: 42 },
      { purchaseToken: "has spaces" },
      null,
      [],
      "string",
    ]
  ) {
    assertThrows(() => parseTopUpRequest(body), VerificationFailure);
  }
});

// ---------------------------------------------------------------------------
// Interpreting the provider's answer
// ---------------------------------------------------------------------------

Deno.test("a purchased approved pack is verified with its provider facts", () => {
  const verified = interpret(purchase());
  assertEquals(verified, {
    providerProductId: "facetune_ai_look_topup_1",
    purchaseState: "PURCHASED",
    needsConsumption: true,
    orderId: "GPA.1111-2222-3333-44444",
    testPurchase: false,
    clientProductMismatch: false,
  });
});

Deno.test("the provider's product wins over the client's claim", () => {
  const verified = interpret(purchase(), "facetune_preview_credit_topup_10");
  assertEquals(verified.providerProductId, "facetune_ai_look_topup_1");
  assertEquals(verified.clientProductMismatch, true);
});

Deno.test("a subscription or unknown product cannot become a pack", () => {
  for (
    const productId of [
      "facetune_plus",
      "facetune_pro_preview",
      "some_other_app_item",
      "",
    ]
  ) {
    const failure = assertThrows(
      () =>
        interpret(purchase({
          productLineItem: [{
            productId,
            productOfferDetails: { quantity: 1 },
          }],
        })),
      VerificationFailure,
    );
    assertEquals(failure.code, "INVALID_TOP_UP_PRODUCT");
  }
});

Deno.test("a purchase with no or several approved line items is refused", () => {
  assertThrows(
    () => interpret(purchase({ productLineItem: [] })),
    VerificationFailure,
  );
  assertThrows(
    () => interpret(purchase({ productLineItem: undefined })),
    VerificationFailure,
  );
  assertThrows(
    () =>
      interpret(purchase({
        productLineItem: [
          { productId: "facetune_ai_look_topup_1" },
          { productId: "facetune_preview_credit_topup_10" },
        ],
      })),
    VerificationFailure,
  );
});

Deno.test("pending and cancelled states are carried, not granted here", () => {
  assertEquals(
    interpret(purchase({ purchaseStateContext: { purchaseState: "PENDING" } }))
      .purchaseState,
    "PENDING",
  );
  assertEquals(
    interpret(
      purchase({ purchaseStateContext: { purchaseState: "CANCELLED" } }),
    ).purchaseState,
    "CANCELLED",
  );
});

Deno.test("an unspecified or unknown state is refused, never guessed", () => {
  for (
    const state of [
      "PURCHASE_STATE_UNSPECIFIED",
      "REFUNDED",
      "",
      undefined,
    ]
  ) {
    const failure = assertThrows(
      () =>
        interpret(purchase({
          purchaseStateContext: state === undefined
            ? undefined
            : { purchaseState: state },
        })),
      VerificationFailure,
    );
    assertEquals(failure.code, "PROVIDER_STATE_CONFLICT");
  }
});

Deno.test("a quantity other than one is refused", () => {
  for (const quantity of [0, 2, 10, -1]) {
    const failure = assertThrows(
      () =>
        interpret(purchase({
          productLineItem: [{
            productId: "facetune_preview_credit_topup_10",
            productOfferDetails: { quantity },
          }],
        })),
      VerificationFailure,
    );
    assertEquals(failure.code, "PROVIDER_STATE_CONFLICT");
  }
});

Deno.test("an absent quantity means one", () => {
  const verified = interpret(purchase({
    productLineItem: [{ productId: "facetune_preview_credit_topup_10" }],
  }));
  assertEquals(verified.providerProductId, "facetune_preview_credit_topup_10");
});

Deno.test("a purchase started from another account is rejected", () => {
  const failure = assertThrows(
    () => interpret(purchase({ obfuscatedExternalAccountId: "someone-else" })),
    VerificationFailure,
  );
  assertEquals(failure.code, "PROVIDER_STATE_CONFLICT");
});

Deno.test("a purchase carrying no account identifier is still verifiable", () => {
  assertEquals(
    interpret(purchase({ obfuscatedExternalAccountId: undefined }))
      .providerProductId,
    "facetune_ai_look_topup_1",
  );
});

Deno.test("an already-consumed purchase is not consumed again", () => {
  const verified = interpret(purchase({
    productLineItem: [{
      productId: "facetune_ai_look_topup_1",
      productOfferDetails: {
        quantity: 1,
        consumptionState: "CONSUMPTION_STATE_CONSUMED",
      },
    }],
  }));
  assertEquals(verified.needsConsumption, false);
});

Deno.test("consumption state is read from either placement", () => {
  const verified = interpret(purchase({
    productLineItem: [{
      productId: "facetune_ai_look_topup_1",
      consumptionState: "CONSUMPTION_STATE_CONSUMED",
    }],
  }));
  assertEquals(verified.needsConsumption, false);
});

Deno.test("a license-tester purchase is flagged", () => {
  assertEquals(
    interpret(purchase({ testPurchaseContext: { fopType: "TEST" } }))
      .testPurchase,
    true,
  );
});

Deno.test("a malformed order id is dropped rather than stored", () => {
  assertEquals(
    interpret(purchase({ orderId: "GPA.1111 2222; drop" })).orderId,
    null,
  );
  assertEquals(interpret(purchase({ orderId: undefined })).orderId, null);
});

// ---------------------------------------------------------------------------
// Failure mapping
// ---------------------------------------------------------------------------

Deno.test("known grant codes map to their own sanitized failure", () => {
  for (
    const code of [
      "AUTH_REQUIRED",
      "INVALID_TOP_UP_PRODUCT",
      "TOP_UP_NOT_ELIGIBLE",
      "TOP_UP_PENDING",
      "PROVIDER_STATE_CONFLICT",
      "CONCURRENT_MODIFICATION",
      "PURCHASE_VERIFICATION_FAILED",
    ]
  ) {
    assertEquals(failureForGrantCode(code).code, code);
  }
});

Deno.test("an unrecognised grant code is never echoed to the client", () => {
  const failure = failureForGrantCode("SOME_INTERNAL_DETAIL");
  assertEquals(failure.code, "PURCHASE_VERIFICATION_FAILED");
  assert(!failure.message.includes("SOME_INTERNAL_DETAIL"));
});

Deno.test("pending and concurrency refusals are retryable; the rest are not", () => {
  assertEquals(failureForGrantCode("TOP_UP_PENDING").retryable, true);
  assertEquals(failureForGrantCode("CONCURRENT_MODIFICATION").retryable, true);
  assertEquals(failureForGrantCode("TOP_UP_NOT_ELIGIBLE").retryable, false);
  assertEquals(failureForGrantCode("INVALID_TOP_UP_PRODUCT").retryable, false);
});

Deno.test("no failure message leaks a token or provider payload", () => {
  const token = "super-secret-purchase-token";
  const messages = [
    ...[
      "INVALID_TOP_UP_PRODUCT",
      "TOP_UP_NOT_ELIGIBLE",
      "PROVIDER_STATE_CONFLICT",
      "PURCHASE_VERIFICATION_FAILED",
      "anything",
    ].map((code) => failureForGrantCode(code).message),
  ];
  for (const message of messages) {
    assert(!message.includes(token));
    assert(!message.includes("GPA."));
  }
});
