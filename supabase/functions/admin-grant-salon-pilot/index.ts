import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  adminAuthErrorBody,
  requireAdmin,
  type UserClientFactory,
} from "../_shared/admin_auth.ts";
import {
  invalidRequestBody,
  mutationResponse,
  parseGrantSalonPilotRequest,
} from "../_shared/admin_mutations.ts";

// FaceTune WA-7 — grant a Salon Pilot entitlement.
//
// The first privileged admin mutation, and the template for those that follow
// (Shared Contract §58):
//
//     Web Admin (Flutter Web)
//         ↓  Authorization: Bearer <the admin's own JWT>
//         ↓  { targetUserId, expiresAt, initialAllowance?, reason, idempotencyKey }
//     this function
//         ↓  requireAdmin(): auth.getUser() + current_user_is_admin(), AS THE CALLER
//         ↓  parse + validate the request shape (400 on a client defect)
//         ↓  rpc admin_grant_salon_pilot(...), AS THE CALLER
//         ↓     is_admin(auth.uid()) again · per-account lock · rules ·
//         ↓     transactional INSERT entitlement + INSERT audit event
//     200 { success: true, ...resolver figures, replayed }
//     or  4xx/5xx { success: false, errorCode, message, retryable }
//
// No service-role key exists in this function: the writer is a `security
// definer` database function that decides authorization for itself from the
// session, so both layers must agree before anything is written. The request
// correlation id is minted here, recorded on the audit event, and returned in
// the `x-request-id` header for support; it carries no user content.
//
// Log lines hold only the identifiers the logging contract (§22) allows:
// admin id, target id, action, entitlement id, correlation id, latency,
// sanitized outcome. Never a reason, an email, a token, or a body.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(
  body: unknown,
  status: number,
  correlationId: string,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
      "cache-control": "no-store",
      "x-request-id": correlationId,
      // WA-12: a throttled admin request is a rate limit with a fixed window.
      ...(status === 429 ? { "retry-after": "60" } : {}),
    },
  });
}

const userClient: UserClientFactory = (authorization) => {
  const url = Deno.env.get("SUPABASE_URL")?.trim();
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")?.trim();
  if (!url || !anonKey) throw new Error("server_configuration");
  return createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
};

Deno.serve(async (request) => {
  const correlationId = crypto.randomUUID();
  const startedAt = Date.now();

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
      correlationId,
    );
  }

  const admin = await requireAdmin(request, userClient);
  if (!admin.ok) {
    console.error(
      `[admin-grant-salon-pilot] refused code=${admin.errorCode} correlation=${correlationId}`,
    );
    return jsonResponse(adminAuthErrorBody(admin), admin.status, correlationId);
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    body = null;
  }
  const parsed = parseGrantSalonPilotRequest(body);
  if (!parsed.ok) {
    console.error(
      `[admin-grant-salon-pilot] invalid_request field=${parsed.field} admin=${admin.userId} correlation=${correlationId}`,
    );
    return jsonResponse(invalidRequestBody(parsed), 400, correlationId);
  }
  const intent = parsed.value;

  let result: unknown;
  try {
    const client = userClient(request.headers.get("authorization") ?? "");
    const { data, error } = await client.rpc("admin_grant_salon_pilot", {
      p_target_user_id: intent.targetUserId,
      p_expires_at: intent.expiresAt,
      p_reason: intent.reason,
      p_idempotency_key: intent.idempotencyKey,
      p_initial_allowance: intent.initialAllowance,
      p_request_correlation_id: correlationId,
    });
    if (error) {
      // SQLSTATE 22023 is the writer refusing the request shape — the same
      // client-defect class this function answers with 400 above.
      if (error.code === "22023") {
        console.error(
          `[admin-grant-salon-pilot] invalid_request source=db admin=${admin.userId} correlation=${correlationId}`,
        );
        return jsonResponse(
          invalidRequestBody({
            ok: false,
            field: "body",
            message: "The request was not accepted by the server.",
          }),
          400,
          correlationId,
        );
      }
      console.error(
        `[admin-grant-salon-pilot] rpc_failed code=${
          error.code ?? "unknown"
        } admin=${admin.userId} correlation=${correlationId}`,
      );
      result = null;
    } else {
      result = data;
    }
  } catch (error) {
    console.error(
      `[admin-grant-salon-pilot] rpc_threw type=${
        (error as Error)?.constructor?.name ?? "unknown"
      } admin=${admin.userId} correlation=${correlationId}`,
    );
    result = null;
  }

  const response = mutationResponse(result);
  const entitlementId = typeof (response.body as Record<string, unknown>)
      .entitlementId === "string"
    ? (response.body as Record<string, unknown>).entitlementId
    : "none";
  console.log(
    `[admin-grant-salon-pilot] action=grant_salon_pilot outcome=${response.outcome} admin=${admin.userId} target=${intent.targetUserId} entitlement=${entitlementId} correlation=${correlationId} latency_ms=${
      Date.now() - startedAt
    }`,
  );
  return jsonResponse(response.body, response.status, correlationId);
});
