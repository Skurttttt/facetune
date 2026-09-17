import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Imported from the SUB-10 function rather than copied. These two modules are
// the verified-read half of the billing integration — the authenticated Google
// Play client and the pure interpretation of a `SubscriptionPurchaseV2` — and
// a second copy would be a second thing to keep correct. Neither file is
// modified by this phase.
import {
  GooglePlayApi,
  parseServiceAccount,
} from "../verify-google-play-purchase/google_play_api.ts";
import {
  interpretPurchase,
  sha256Hex,
  type SubscriptionPurchaseV2,
  VerificationFailure,
} from "../verify-google-play-purchase/verification.ts";

import {
  decodeDeveloperNotification,
  NotificationRejected,
  parsePubSubEnvelope,
  plannedAction,
} from "./notification.ts";
import { planReconciliation } from "./reconciliation.ts";
import {
  PushAuthenticationFailed,
  PushKeysUnavailable,
  verifyPushRequest,
} from "./pubsub_auth.ts";

// FaceTune SUB-11 — subscription lifecycle reconciliation.
//
// A Real-time Developer Notification is a trigger and nothing else:
//
//     Pub/Sub push  (authenticated as Google)
//         ↓
//     validate package and event shape
//         ↓
//     claim by message id           ← a redelivery stops here
//         ↓
//     purchases.subscriptionsv2.get ← the only authority on what is true now
//         ↓
//     interpret the verified resource
//         ↓
//     reconcile the entitlement     ← the same SUB-10 write path, reused
//         ↓
//     record the outcome
//
// Nothing below grants, revokes, renews, or expires anything on the strength
// of a `notificationType`. The type selects which verified read to perform,
// and the read decides what is written. That ordering is the whole phase.
//
// ## Why almost everything answers 200
//
// Pub/Sub redelivers anything that is not acknowledged. A 200 here means "do
// not send this again", which is the correct answer for a notification that
// was handled *and* for one that will never be processable — a foreign
// package, a malformed payload, a purchase this backend has no record of.
// Only a genuinely transient failure returns a retryable status, and it
// releases its claim first so the redelivery is free to do the work.

const approvedProductIds = new Set([
  "facetune_plus",
  "facetune_pro",
  "facetune_salon_pro",
]);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) throw new MissingConfiguration(name);
  return value;
}

class MissingConfiguration extends Error {}

/// A failure that should be retried by the transport.
class TransientFailure extends Error {}

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  // -------------------------------------------------------------------------
  // Configuration and caller identity
  // -------------------------------------------------------------------------
  let packageName: string;
  let supabaseUrl: string;
  let serviceRoleKey: string;
  let serviceAccountJson: string;
  let pushAudience: string;
  let pushServiceAccount: string;
  try {
    packageName = requiredEnvironment("GOOGLE_PLAY_PACKAGE_NAME");
    supabaseUrl = requiredEnvironment("SUPABASE_URL");
    serviceRoleKey = requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY");
    serviceAccountJson = requiredEnvironment("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
    // No default and no fallback. An unset audience or identity would turn
    // this endpoint into one anybody may post subscription events to, so it
    // refuses to run at all rather than accepting an unauthenticated caller.
    pushAudience = requiredEnvironment("GOOGLE_PLAY_RTDN_AUDIENCE");
    pushServiceAccount = requiredEnvironment(
      "GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT",
    );
  } catch {
    console.error("[google-play-rtdn] server_configuration_incomplete");
    // Retryable: the notification is not at fault and should survive the fix.
    return jsonResponse({ error: "server_configuration" }, 503);
  }

  try {
    await verifyPushRequest(request.headers.get("authorization"), {
      audience: pushAudience,
      serviceAccountEmail: pushServiceAccount,
    });
  } catch (error) {
    if (error instanceof PushKeysUnavailable) {
      console.error("[google-play-rtdn] push_keys_unavailable");
      return jsonResponse({ error: "verification_unavailable" }, 503);
    }
    const reason = error instanceof PushAuthenticationFailed
      ? error.reason
      : "unknown";
    console.error(`[google-play-rtdn] push_auth_rejected reason=${reason}`);
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  // -------------------------------------------------------------------------
  // Shape
  // -------------------------------------------------------------------------
  let messageId: string;
  let notification: ReturnType<typeof decodeDeveloperNotification>;
  try {
    const body = await request.json().catch(() => {
      throw new NotificationRejected("body_not_json");
    });
    const envelope = parsePubSubEnvelope(body);
    messageId = envelope.messageId;
    notification = decodeDeveloperNotification(envelope.data);
  } catch (error) {
    const reason = error instanceof NotificationRejected
      ? error.reason
      : "unreadable";
    // Answered 200 on purpose: a payload that cannot be parsed now will not
    // parse on redelivery either, and asking for it again forever is worse
    // than dropping it with a reason in the log.
    console.error(`[google-play-rtdn] notification_rejected reason=${reason}`);
    return jsonResponse({ ignored: true, reason }, 200);
  }

  const privileged = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const claim = async (purchaseReference: string | null) => {
    const { data, error } = await privileged.rpc(
      "claim_google_play_notification",
      {
        p_message_id: messageId,
        p_notification_kind: notification.kind,
        p_notification_type: notification.notificationType,
        p_purchase_reference: purchaseReference,
        p_event_time: notification.eventTime,
      },
    );
    if (error) throw new TransientFailure("claim_failed");
    return (data ?? {}) as Record<string, unknown>;
  };

  const finalize = async (
    outcome: string,
    ids?: { userId?: string | null; entitlementId?: string | null },
  ) => {
    const { error } = await privileged.rpc(
      "finalize_google_play_notification",
      {
        p_message_id: messageId,
        p_outcome: outcome,
        p_user_id: ids?.userId ?? null,
        p_entitlement_id: ids?.entitlementId ?? null,
      },
    );
    // A failure to record the outcome is not worth undoing the reconciliation
    // over: the entitlement is already correct, and the claim row remains as
    // evidence that this message was handled.
    if (error) console.error("[google-play-rtdn] finalize_failed");
  };

  // A notification for another app never reaches the provider or the database
  // beyond its own audit row. The topic is ours, so this is a configuration
  // mistake rather than an attack, but it is not something to act on.
  if (notification.packageName !== packageName) {
    try {
      const claimed = await claim(null);
      if (claimed.claimed === true) await finalize("ignored");
    } catch {
      return jsonResponse({ error: "unavailable" }, 503);
    }
    console.warn("[google-play-rtdn] foreign_package_ignored");
    return jsonResponse({ ignored: true, reason: "foreign_package" }, 200);
  }

  const action = plannedAction(notification);
  const purchaseToken = notification.purchaseToken;

  let purchaseReference: string | null = null;
  if (purchaseToken !== null) {
    purchaseReference = await sha256Hex(purchaseToken);
  }

  // -------------------------------------------------------------------------
  // Deduplicate before anything else costs anything
  // -------------------------------------------------------------------------
  //
  // Google asks that redeliveries not produce redundant Developer API calls.
  // The claim is therefore taken before the verified read, not after it.
  let claimed: Record<string, unknown>;
  try {
    claimed = await claim(purchaseReference);
  } catch {
    return jsonResponse({ error: "unavailable" }, 503);
  }
  if (claimed.ok !== true) {
    // The claim was refused on shape. It will be refused identically on every
    // redelivery, so it is answered 200 rather than retried forever.
    console.error("[google-play-rtdn] claim_refused");
    return jsonResponse({ ignored: true, reason: "invalid_notification" }, 200);
  }
  if (claimed.claimed !== true) {
    console.log(
      `[google-play-rtdn] duplicate_ignored kind=${notification.kind}`,
    );
    return jsonResponse({ duplicate: true }, 200);
  }

  try {
    if (action === "ignore" || purchaseToken === null) {
      await finalize("ignored");
      return jsonResponse({ ignored: true, reason: notification.kind }, 200);
    }

    // -----------------------------------------------------------------------
    // The verified read. The only authority in this function.
    // -----------------------------------------------------------------------
    let purchase: SubscriptionPurchaseV2 | null = null;
    const api = new GooglePlayApi(
      parseServiceAccount(serviceAccountJson),
      packageName,
    );
    try {
      purchase = await api.getSubscription(purchaseToken) as
        SubscriptionPurchaseV2;
    } catch (error) {
      if (error instanceof VerificationFailure && error.retryable) {
        // Google was unreachable or refused our credential. Nothing is known,
        // so nothing is written and the notification is left to redelivery.
        throw new TransientFailure("provider_unavailable");
      }
      if (!(error instanceof VerificationFailure)) {
        throw new TransientFailure("provider_read_failed");
      }
      // Google does not recognise the purchase: fabricated, belonging to
      // another app, or purged. Purged is the interesting case — Google stops
      // serving expired and refunded subscriptions after 60 days — which is
      // why this is corroboration for a revocation rather than a failure.
      purchase = null;
    }

    const linkedReference =
      typeof purchase?.linkedPurchaseToken === "string" &&
        purchase.linkedPurchaseToken.length > 0
        ? await sha256Hex(purchase.linkedPurchaseToken)
        : null;

    // -----------------------------------------------------------------------
    // Whose subscription is this?
    // -----------------------------------------------------------------------
    //
    // Read back from our own records. A notification carries no account, and
    // this deliberately cannot create a binding — only a verified purchase
    // made by a signed-in user does that, in SUB-10.
    const { data: ownerData, error: ownerError } = await privileged.rpc(
      "google_play_purchase_owner",
      {
        p_purchase_reference: purchaseReference,
        p_linked_purchase_reference: linkedReference,
      },
    );
    if (ownerError) throw new TransientFailure("owner_lookup_failed");
    const userId = typeof ownerData === "string" && ownerData.length > 0
      ? ownerData
      : null;

    // -----------------------------------------------------------------------
    // What the verified read means
    // -----------------------------------------------------------------------
    //
    // The decision itself is a pure function over (what was asked, who owns
    // it, what Google says now) — see `reconciliation.ts`, where it is tested
    // exhaustively. Everything below only carries it out.
    const plan = planReconciliation({ action, owner: userId, purchase });
    const verifiedState = typeof purchase?.subscriptionState === "string"
      ? purchase.subscriptionState
      : null;

    if (plan.outcome === "unmatched") {
      // A real purchase that no FaceTune account has ever verified. Recorded,
      // and nothing is granted to anybody: there is nobody to grant it to.
      await finalize("unmatched");
      console.log("[google-play-rtdn] unmatched_purchase");
      return jsonResponse({ handled: true, outcome: "unmatched" }, 200);
    }

    if (plan.outcome === "conflict") {
      await finalize("conflict", { userId });
      console.warn(`[google-play-rtdn] ${plan.reason}`);
      return jsonResponse({ handled: true, outcome: "conflict" }, 200);
    }

    if (plan.outcome === "revoke") {
      const { data: revokeData, error: revokeError } = await privileged.rpc(
        "revoke_google_play_subscription",
        {
          p_purchase_reference: purchaseReference,
          p_provider_state: verifiedState,
          p_revoked_at: notification.eventTime,
        },
      );
      if (revokeError) throw new TransientFailure("revoke_failed");
      const result = (revokeData ?? {}) as Record<string, unknown>;
      if (result.ok !== true) {
        await finalize("unmatched", { userId });
        return jsonResponse({ handled: true, outcome: "unmatched" }, 200);
      }
      await finalize("revoked", {
        userId,
        entitlementId: typeof result.entitlementId === "string"
          ? result.entitlementId
          : null,
      });
      console.log("[google-play-rtdn] revoked");
      return jsonResponse({ handled: true, outcome: "revoked" }, 200);
    }

    if (userId === null || purchase === null) {
      // Unreachable: `planReconciliation` answers `unmatched` for a missing
      // owner and `conflict` for a missing purchase, and both returned above.
      // Kept because it is what narrows the two values for the activation
      // path, and a compiler-checked impossibility beats a non-null assertion.
      await finalize("conflict", { userId });
      return jsonResponse({ handled: true, outcome: "conflict" }, 200);
    }

    // -----------------------------------------------------------------------
    // Reconcile to the verified resource
    // -----------------------------------------------------------------------
    let verified;
    try {
      verified = interpretPurchase(purchase, {
        approvedProductIds,
        // There is no client here to have claimed anything.
        claimedProductId: null,
        // The account our own records bind this purchase to. If Google says
        // the purchase was made for a different account, that disagreement is
        // a conflict, not something to write.
        expectedAccountId: userId,
      });
    } catch (error) {
      const code = error instanceof VerificationFailure ? error.code : "unknown";
      await finalize("conflict", { userId });
      console.error(`[google-play-rtdn] interpretation_conflict code=${code}`);
      return jsonResponse({ handled: true, outcome: "conflict" }, 200);
    }

    const { data: activation, error: activationError } = await privileged.rpc(
      "activate_verified_google_play_subscription",
      {
        p_user_id: userId,
        p_provider_product_id: verified.providerProductId,
        p_purchase_reference: purchaseReference,
        p_subscription_state: verified.subscriptionState,
        p_subscription_start: verified.subscriptionStart,
        p_period_end: verified.periodEnd,
        p_auto_renew: verified.autoRenew,
        p_linked_purchase_reference: linkedReference,
        p_test_purchase: verified.testPurchase,
      },
    );
    if (activationError) throw new TransientFailure("activation_failed");

    const result = (activation ?? {}) as Record<string, unknown>;
    if (result.ok !== true) {
      const code = String(result.errorCode ?? "");
      if (code === "CONCURRENT_MODIFICATION") {
        // Another writer held the account. Redelivery is exactly the right
        // remedy, so the claim is released rather than recorded.
        throw new TransientFailure("concurrent_modification");
      }
      await finalize("conflict", { userId });
      console.error(`[google-play-rtdn] activation_refused code=${code}`);
      return jsonResponse({ handled: true, outcome: "conflict" }, 200);
    }

    // A notification can arrive before the buying device ever reaches the
    // verification endpoint — a purchase completed while the app was closed,
    // or on another device. Acknowledging here closes that gap, under the same
    // rule as SUB-10: only once the entitlement exists.
    if (verified.needsAcknowledgement) {
      const acknowledged = await api.acknowledgeSubscription(
        purchaseToken,
        verified.providerProductId,
      );
      if (!acknowledged) {
        console.error("[google-play-rtdn] acknowledgement_failed");
      }
    }

    await finalize("reconciled", {
      userId,
      entitlementId: typeof result.entitlementId === "string"
        ? result.entitlementId
        : null,
    });
    console.log(
      `[google-play-rtdn] reconciled type=${notification.notificationType}`,
    );
    return jsonResponse({ handled: true, outcome: "reconciled" }, 200);
  } catch (error) {
    // Release the claim so the redelivery can do the work. Without this the
    // dedup row would make every retry a silent no-op and the event would be
    // lost.
    await finalize("retry");
    const reason = error instanceof TransientFailure
      ? error.message
      : "unhandled";
    console.error(`[google-play-rtdn] transient_failure reason=${reason}`);
    return jsonResponse({ error: "unavailable" }, 503);
  }
});
