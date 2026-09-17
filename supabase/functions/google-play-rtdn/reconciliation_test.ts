import { assertEquals } from "jsr:@std/assert@1";

import type { SubscriptionPurchaseV2 } from "../verify-google-play-purchase/verification.ts";
import { planReconciliation } from "./reconciliation.ts";

const owner = "11111111-1111-4111-8111-111111111111";

function purchase(
  state: string,
  overrides: Partial<SubscriptionPurchaseV2> = {},
): SubscriptionPurchaseV2 {
  return {
    subscriptionState: state,
    startTime: "2026-09-17T11:06:15.000Z",
    lineItems: [
      {
        productId: "facetune_plus",
        expiryTime: "2026-10-17T11:06:15.000Z",
        autoRenewingPlan: { autoRenewEnabled: true },
      },
    ],
    ...overrides,
  };
}

Deno.test("a live subscription reconciles to what Google says", () => {
  // Renewal, recovery, restart — every lifecycle notification about a live
  // subscription lands here, and the state it carries is Google's, not the
  // notification's.
  for (
    const state of [
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      "SUBSCRIPTION_STATE_CANCELED",
      "SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_PAUSED",
    ]
  ) {
    assertEquals(
      planReconciliation({
        action: "reconcile",
        owner,
        purchase: purchase(state),
      }),
      { outcome: "activate" },
      `${state} must reconcile`,
    );
  }
});

Deno.test("cancelled is reconciled, never revoked", () => {
  // The business rule in one assertion: cancelled auto-renew is not an ended
  // entitlement. It goes down the ordinary write path, where the period end
  // decides access.
  assertEquals(
    planReconciliation({
      action: "reconcile",
      owner,
      purchase: purchase("SUBSCRIPTION_STATE_CANCELED"),
    }),
    { outcome: "activate" },
  );
});

Deno.test("an expired subscription still reconciles", () => {
  // Expiry is a state to write, not a special case: the activation path maps
  // it to `expired`, which blocks new generation and deletes nothing.
  assertEquals(
    planReconciliation({
      action: "reconcile",
      owner,
      purchase: purchase("SUBSCRIPTION_STATE_EXPIRED"),
    }),
    { outcome: "activate" },
  );
});

Deno.test("revocation is acted on only when Google corroborates it", () => {
  // Corroborated by the verified state.
  assertEquals(
    planReconciliation({
      action: "revoke",
      owner,
      purchase: purchase("SUBSCRIPTION_STATE_EXPIRED"),
    }),
    { outcome: "revoke" },
  );
  // Corroborated by Google no longer serving the purchase at all, which is
  // what a refund older than 60 days looks like.
  assertEquals(
    planReconciliation({ action: "revoke", owner, purchase: null }),
    { outcome: "revoke" },
  );
});

Deno.test("a revocation notification cannot overrule a live subscription", () => {
  // The provider-authority rule at its sharpest. A REVOKED notification whose
  // subscription still reads back as active does not revoke anything — the
  // verified resource wins and the entitlement is reconciled to it.
  for (
    const state of [
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      "SUBSCRIPTION_STATE_CANCELED",
    ]
  ) {
    assertEquals(
      planReconciliation({
        action: "revoke",
        owner,
        purchase: purchase(state),
      }),
      { outcome: "activate" },
      `a revoke notification must not end a ${state} subscription`,
    );
  }
});

Deno.test("a purchase no account owns is never granted to anybody", () => {
  for (const action of ["reconcile", "revoke"] as const) {
    assertEquals(
      planReconciliation({
        action,
        owner: null,
        purchase: purchase("SUBSCRIPTION_STATE_ACTIVE"),
      }),
      { outcome: "unmatched" },
    );
  }
});

Deno.test("ownership is checked before the provider's answer is used", () => {
  // Even a revocation Google corroborates writes nothing without an owner:
  // there is no entitlement to end, and one is never invented to end it.
  assertEquals(
    planReconciliation({ action: "revoke", owner: null, purchase: null }),
    { outcome: "unmatched" },
  );
});

Deno.test("a purchase Google will not describe is a conflict, not a guess", () => {
  // Known owner, unreadable purchase. Nothing is written in either direction:
  // not expired, not revoked, not active.
  assertEquals(
    planReconciliation({ action: "reconcile", owner, purchase: null }),
    { outcome: "conflict", reason: "purchase_not_available" },
  );
});

Deno.test("an unreadable state is not treated as any state", () => {
  // No `subscriptionState` at all. It reaches the activation path, where the
  // database refuses an unmapped state rather than this file inventing one.
  assertEquals(
    planReconciliation({
      action: "reconcile",
      owner,
      purchase: { lineItems: [{ productId: "facetune_plus" }] },
    }),
    { outcome: "activate" },
  );
  // But a revocation is not corroborated by it.
  assertEquals(
    planReconciliation({
      action: "revoke",
      owner,
      purchase: { lineItems: [{ productId: "facetune_plus" }] },
    }),
    { outcome: "activate" },
  );
});

Deno.test("an ignored notification never reaches a write", () => {
  assertEquals(
    planReconciliation({ action: "ignore", owner, purchase: null }),
    { outcome: "ignored" },
  );
  // Including when everything else about it looks actionable.
  assertEquals(
    planReconciliation({
      action: "ignore",
      owner,
      purchase: purchase("SUBSCRIPTION_STATE_ACTIVE"),
    }),
    { outcome: "ignored" },
  );
});
