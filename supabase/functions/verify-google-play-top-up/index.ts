import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  GooglePlayApi,
  parseServiceAccount,
} from "../verify-google-play-purchase/google_play_api.ts";
import { sha256Hex } from "../verify-google-play-purchase/verification.ts";
import {
  failureForGrantCode,
  interpretTopUpPurchase,
  parseTopUpRequest,
  type ProductPurchaseV2,
  VerificationFailure,
} from "./top_up_verification.ts";

// FaceTune SUB-13B — server-side Google Play top-up purchase verification.
//
// A one-time product purchase becomes purchased credits here and nowhere
// else:
//
//     authenticated user
//         ↓
//     purchase token from the Android client
//         ↓
//     Google Play Developer API  (the only authority on whether it is real)
//         ↓
//     provider product → pack     (server-owned mapping, in SQL)
//         ↓
//     idempotent credit grant     (service-role RPC, exactly once per purchase)
//         ↓
//     consume with Google         (so the pack can be bought again)
//         ↓
//     authoritative state, read back as the user
//
// Nothing the client sends is trusted beyond the token: not a pack, not a
// quantity, not a price, not a product. The client's claim about which product
// it bought is accepted into the request and then deliberately discarded.
//
// The subscription path (`verify-google-play-purchase`) is untouched. A
// subscription token sent here resolves to no one-time product and is
// refused; a top-up token sent there resolves to no subscription and is
// refused. Neither can grant the other's thing.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/// The store products a top-up purchase may resolve to.
///
/// The database is the authority for the product → pack mapping; this set only
/// decides which line item of a purchase is one we sell. The two are kept in
/// step by `purchased_top_up_credits_contract_test.dart`.
const approvedProductIds = new Set([
  "facetune_ai_look_topup_1",
  "facetune_preview_credit_topup_10",
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
    const { purchaseToken, claimedProductId } = parseTopUpRequest(payload);

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
    const providerResponse = await api.getProductPurchase(
      purchaseToken,
    ) as ProductPurchaseV2;

    const verified = interpretTopUpPurchase(providerResponse, {
      approvedProductIds,
      claimedProductId,
      expectedAccountId: userId,
    });

    if (verified.clientProductMismatch) {
      console.warn(
        "[verify-google-play-top-up] client_product_mismatch " +
          `resolved=${verified.providerProductId}`,
      );
    }

    // ---------------------------------------------------------------------
    // Grant. The raw token never reaches the database — only its hash.
    // ---------------------------------------------------------------------
    const purchaseReference = await sha256Hex(purchaseToken);

    // A second client, used only for the two service-role RPCs below. Their
    // arguments carry their authority, so they are granted to `service_role`
    // alone; see the SUB-13B migration. This client is never used for a table
    // read or write, and the user identity above was established with the
    // user's own token, not this one.
    const privilegedClient = createClient(
      supabaseUrl,
      requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const { data: grant, error: grantError } = await privilegedClient.rpc(
      "grant_verified_top_up_purchase",
      {
        p_user_id: userId,
        p_provider_product_id: verified.providerProductId,
        p_purchase_reference: purchaseReference,
        p_purchase_state: verified.purchaseState,
        p_provider_order_id: verified.orderId,
        p_test_purchase: verified.testPurchase,
      },
    );

    if (grantError) {
      throw new VerificationFailure(
        500,
        "PURCHASE_VERIFICATION_FAILED",
        "Your purchase could not be recorded. Please try again.",
        true,
      );
    }

    const result = (grant ?? {}) as Record<string, unknown>;
    if (result.ok !== true) {
      throw failureForGrantCode(String(result.errorCode ?? ""));
    }

    // ---------------------------------------------------------------------
    // Consume, only now that the credits exist.
    // ---------------------------------------------------------------------
    //
    // Consuming before the grant would tell Google the credits were delivered
    // while they might still fail to persist — and would waive the automatic
    // refund that protects the user in exactly that case. A replayed
    // verification whose consumption failed last time lands here again with
    // the grant already in place, which is the retry path.
    let consumed = !verified.needsConsumption ||
      result.providerConsumed === true;
    if (!consumed) {
      consumed = await api.consumeProduct(
        purchaseToken,
        verified.providerProductId,
      );
      if (consumed) {
        // Best-effort bookkeeping. A failure here changes nothing about the
        // grant or the consumption; the next replay records it again.
        await privilegedClient.rpc("mark_top_up_purchase_consumed", {
          p_user_id: userId,
          p_purchase_reference: purchaseReference,
        });
      } else {
        console.error("[verify-google-play-top-up] consumption_failed");
      }
    }

    // ---------------------------------------------------------------------
    // Return authoritative state, resolved as the user.
    // ---------------------------------------------------------------------
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

    return jsonResponse({
      verified: true,
      consumed,
      replayed: result.replayed === true,
      credits: {
        packCode: result.packCode,
        creditClass: result.creditClass,
        quantityGranted: result.quantityGranted,
      },
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
        "[verify-google-play-top-up] unhandled_error type=" +
          (error?.constructor?.name ?? "unknown"),
      );
    }
    console.error(
      `[verify-google-play-top-up] request_failed code=${failure.code}`,
    );
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
