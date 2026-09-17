// What to do about a notification, once the provider has been asked.
//
// Split out from `index.ts` for the same reason `verification.ts` is split out
// of the SUB-10 function: this is the part where a wrong answer grants or
// removes somebody's subscription, and it is only testable if it needs neither
// Pub/Sub, Google, nor a database to run.
//
// The inputs are the three facts that decide everything: what the notification
// asked for, whose purchase it is according to our own records, and what
// Google says the subscription is *now*. The output names a write; it never
// performs one.

import type { SubscriptionPurchaseV2 } from "../verify-google-play-purchase/verification.ts";
import type { PlannedAction } from "./notification.ts";

/// Google's own name for a subscription that has ended.
///
/// Revocation is not a distinct `SubscriptionState`: a revoked subscription
/// reads back as expired. That is why a revocation notification needs this
/// state — or Google refusing to describe the purchase at all — to corroborate
/// it, and why revocation cannot simply be inferred from the notification.
export const expiredState = "SUBSCRIPTION_STATE_EXPIRED";

export type ReconciliationPlan =
  /// Nothing to do, and nothing was verified. A test ping, a product this app
  /// does not sell, a notification carrying no token.
  | { readonly outcome: "ignored" }
  /// A real purchase that no FaceTune account has ever verified. There is
  /// nobody to reconcile *for*, and an owner is never invented.
  | { readonly outcome: "unmatched" }
  /// Understood, and deliberately not acted on. Terminal: retrying produces
  /// the same answer.
  | { readonly outcome: "conflict"; readonly reason: string }
  /// End the entitlement behind this purchase.
  | { readonly outcome: "revoke" }
  /// Write whatever the verified resource now describes, through the SUB-10
  /// activation path.
  | { readonly outcome: "activate" };

/// Decides what a notification leads to.
///
/// ## The rule this function exists to hold
///
/// The verified resource wins, always. A `SUBSCRIPTION_REVOKED` notification
/// whose subscription still reads back as live does **not** revoke anything —
/// it reconciles to what Google actually says. The notification chose which
/// question to ask; only the answer decides what is written.
export function planReconciliation(input: {
  action: PlannedAction;
  /// The account our own records bind this purchase to, or null if none does.
  owner: string | null;
  /// The verified `SubscriptionPurchaseV2`, or null when Google would not
  /// describe the purchase — fabricated, belonging to another app, or purged.
  /// Google stops serving subscriptions expired or refunded more than 60 days
  /// ago, which is why null is corroboration for a revocation rather than an
  /// error.
  purchase: SubscriptionPurchaseV2 | null;
}): ReconciliationPlan {
  if (input.action === "ignore") return { outcome: "ignored" };

  // Ownership first. Without it there is no account to write to, and both
  // write paths below would have nowhere to go.
  if (input.owner === null) return { outcome: "unmatched" };

  const state = typeof input.purchase?.subscriptionState === "string"
    ? input.purchase.subscriptionState
    : null;

  if (input.action === "revoke") {
    const corroborated = input.purchase === null || state === expiredState;
    if (corroborated) return { outcome: "revoke" };
    // Google says this subscription is still live. The notification does not
    // get to overrule that, so it falls through and the entitlement is
    // reconciled to the verified state instead.
  }

  if (input.purchase === null) {
    // We know whose purchase this is, but Google will not describe it, and a
    // reconciliation has nothing to reconcile *to*. Nothing is written: the
    // entitlement's own lapsed `period_end` already refuses generation, so
    // silence here is safe as well as honest.
    return { outcome: "conflict", reason: "purchase_not_available" };
  }

  return { outcome: "activate" };
}
