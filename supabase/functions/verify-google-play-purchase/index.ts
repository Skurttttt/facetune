import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  createTelemetryClient,
  outcomeForFailureCode,
  recordAiOperationMetric,
  type TelemetryClient,
} from "../_shared/ai_telemetry.ts";
import { GooglePlayApi, parseServiceAccount } from "./google_play_api.ts";
import {
  failureForActivationCode,
  interpretPurchase,
  parseVerificationRequest,
  sha256Hex,
  type SubscriptionPurchaseV2,
  VerificationFailure,
  type VerificationSource,
} from "./verification.ts";

// FaceTune SUB-10 — server-side Google Play purchase verification.
//
// The whole point of this function is that a purchase becomes an entitlement
// here and nowhere else:
//
//     authenticated user
//         ↓
//     purchase token from the Android client
//         ↓
//     Google Play Developer API  (the only authority on whether it is real)
//         ↓
//     provider product → internal plan   (server-owned mapping, in SQL)
//         ↓
//     idempotent entitlement write       (service-role RPC)
//         ↓
//     acknowledge with Google
//         ↓
//     authoritative state, read back as the user
//
// Nothing the client sends is trusted beyond the token: not a plan, not a
// price, not a product. The client's own claim about which product it bought is
// accepted into the request and then deliberately discarded.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/// The store products a purchase may resolve to.
///
/// The database is the authority for the product → plan mapping; this set only
/// decides which line item of a multi-item subscription is the one we sell. The
/// two are kept in step by `subscription_billing_security_test.dart`.
const approvedProductIds = new Set([
  "facetune_plus",
  "facetune_pro",
  "facetune_salon_pro",
  // SUB-12B Preview-only offers. Same-price siblings of the three above,
  // distinct products: which of the two a purchase is for is decided by the
  // provider product id and never by price.
  "facetune_plus_preview",
  "facetune_pro_preview",
  "facetune_salon_preview",
]);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new VerificationFailure(
      500,
      "server_configuration",
      "Purchase verification is not configured.",
    );
  }
  return value;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      {
        error: {
          code: "method_not_allowed",
          message: "Method not allowed.",
          retryable: false,
        },
      },
      405,
    );
  }

  // SUB-13 telemetry. One `purchase_verification` metric per request, written
  // after the outcome is decided and never able to change it. The token and
  // provider payload never reach it; the Edge Function supplies the account
  // established above from the verified request JWT.
  const startedAt = Date.now();
  const telemetryEventId = crypto.randomUUID();
  let telemetryClient: TelemetryClient | null = null;
  let telemetryUserId: string | null = null;
  let verificationSource: VerificationSource | null = null;
  let purchaseReference: string | null = null;
  let providerAttempted = false;
  try {
    // ---------------------------------------------------------------------
    // Identity. Established from the caller's own JWT, never from the body.
    // ---------------------------------------------------------------------
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new VerificationFailure(
        401,
        "AUTH_REQUIRED",
        "Sign in before confirming a purchase.",
      );
    }

    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const userClient = createClient(
      supabaseUrl,
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: authData, error: authError } = await userClient.auth
      .getUser();
    if (authError || !authData.user) {
      throw new VerificationFailure(
        401,
        "AUTH_REQUIRED",
        "Your session has expired. Sign in again.",
      );
    }
    const userId = authData.user.id;
    telemetryUserId = userId;
    telemetryClient = createTelemetryClient();

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      throw new VerificationFailure(
        400,
        "invalid_json",
        "The request body must be valid JSON.",
      );
    }
    const parsed = parseVerificationRequest(payload);
    const { purchaseToken, claimedProductId } = parsed;
    verificationSource = parsed.verificationSource;

    // ---------------------------------------------------------------------
    // Verify with Google. This is the only step that can establish that a
    // purchase happened at all.
    // ---------------------------------------------------------------------
    const api = new GooglePlayApi(
      parseServiceAccount(
        requiredEnvironment("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"),
      ),
      requiredEnvironment("GOOGLE_PLAY_PACKAGE_NAME"),
    );
    providerAttempted = true;
    const providerResponse = await api.getSubscription(
      purchaseToken,
    ) as SubscriptionPurchaseV2;

    const verified = interpretPurchase(providerResponse, {
      approvedProductIds,
      claimedProductId,
      expectedAccountId: userId,
    });

    if (verified.clientProductMismatch) {
      // Not an error. The provider's answer is authoritative and is what gets
      // used; this only records that the client believed otherwise.
      console.warn(
        "[verify-google-play-purchase] client_product_mismatch " +
          `resolved=${verified.providerProductId}`,
      );
    }

    // ---------------------------------------------------------------------
    // Persist. The raw token never reaches the database — only its hash.
    // ---------------------------------------------------------------------
    purchaseReference = await sha256Hex(purchaseToken);
    const linkedReference = verified.linkedPurchaseToken === null
      ? null
      : await sha256Hex(verified.linkedPurchaseToken);

    // A second client, used for privileged RPCs. The activation function's
    // arguments carry its authority, so it is granted to `service_role` alone;
    // see the rationale in the SUB-10 migration. This client is never used for
    // a table read or write, and the user identity above was established with
    // the user's own token, not this one.
    const privilegedClient = createClient(
      supabaseUrl,
      requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const { data: activation, error: activationError } = await privilegedClient
      .rpc("activate_verified_google_play_subscription", {
        p_user_id: userId,
        p_provider_product_id: verified.providerProductId,
        p_purchase_reference: purchaseReference,
        p_subscription_state: verified.subscriptionState,
        p_subscription_start: verified.subscriptionStart,
        p_period_end: verified.periodEnd,
        p_auto_renew: verified.autoRenew,
        p_linked_purchase_reference: linkedReference,
        p_test_purchase: verified.testPurchase,
      });

    if (activationError) {
      throw new VerificationFailure(
        500,
        "PURCHASE_VERIFICATION_FAILED",
        "Your purchase could not be recorded. Please try again.",
        true,
      );
    }

    const result = (activation ?? {}) as Record<string, unknown>;
    if (result.ok !== true) {
      throw failureForActivationCode(String(result.errorCode ?? ""));
    }

    // ---------------------------------------------------------------------
    // Acknowledge, only now that the entitlement exists.
    // ---------------------------------------------------------------------
    //
    // Acknowledging before the write would tell Google the purchase had been
    // delivered while it might still fail to persist — and would waive the
    // automatic refund that protects the user in exactly that case.
    let acknowledged = !verified.needsAcknowledgement;
    if (verified.needsAcknowledgement) {
      acknowledged = await api.acknowledgeSubscription(
        purchaseToken,
        verified.providerProductId,
      );
      if (!acknowledged) {
        // Not fatal: the entitlement is already granted, and the client's own
        // completion call is a second chance well inside the three-day window.
        console.error(
          "[verify-google-play-purchase] acknowledgement_failed",
        );
      }
    }

    // ---------------------------------------------------------------------
    // Return authoritative state, resolved as the user.
    // ---------------------------------------------------------------------
    //
    // Read through the user's own client so the answer comes from the one
    // resolver every other surface uses, under that user's RLS. The activation
    // result is not reshaped into a second description of entitlement.
    const { data: state, error: stateError } = await userClient.rpc(
      "resolve_subscription_state",
    );
    if (stateError) {
      throw new VerificationFailure(
        500,
        "TEMPORARY_BACKEND_FAILURE",
        "Your purchase was confirmed, but your plan could not be loaded.",
        true,
      );
    }

    await recordAiOperationMetric(
      telemetryClient,
      telemetryEventId,
      userId,
      {
        operationKind: "purchase_verification",
        // The writer derives duplicate/replay from the authoritative provider
        // verification row's creation and latest-verification timestamps.
        outcome: "succeeded",
        latencyMs: Date.now() - startedAt,
        providerName: "google_play",
        providerAttemptCount: 1,
        verificationSource,
        purchaseReference,
      },
    );

    return jsonResponse({
      verified: true,
      acknowledged,
      subscription: state,
    });
  } catch (error) {
    const failure = error instanceof VerificationFailure
      ? error
      : new VerificationFailure(
        500,
        "PURCHASE_VERIFICATION_FAILED",
        "This purchase could not be confirmed. Please try again.",
        true,
      );
    if (!(error instanceof VerificationFailure)) {
      // The error itself is never logged: an unexpected throw from the HTTP or
      // crypto layers can carry a URL, and this function's URLs contain a
      // purchase token.
      console.error(
        "[verify-google-play-purchase] unhandled_error type=" +
          (error?.constructor?.name ?? "unknown"),
      );
    }
    console.error(
      `[verify-google-play-purchase] request_failed code=${failure.code}`,
    );
    if (telemetryClient && telemetryUserId) {
      await recordAiOperationMetric(
        telemetryClient,
        telemetryEventId,
        telemetryUserId,
        {
          operationKind: "purchase_verification",
          outcome: outcomeForFailureCode(failure.code, false),
          failureCategory: failure.code,
          latencyMs: Date.now() - startedAt,
          providerName: providerAttempted ? "google_play" : null,
          providerAttemptCount: providerAttempted ? 1 : 0,
          verificationSource,
          purchaseReference,
        },
      );
    }
    return jsonResponse(
      {
        error: {
          code: failure.code,
          message: failure.message,
          retryable: failure.retryable,
        },
      },
      failure.status,
    );
  }
});
