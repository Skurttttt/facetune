import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import {
  adminAuthErrorBody,
  requireAdmin,
  type UserClientFactory,
} from "../_shared/admin_auth.ts";
import { SUBSCRIPTION_ADMIN_CONTRACT_VERSION } from "../_shared/admin_contract.ts";

// FaceTune WA-2 — the Web Admin's session check.
//
// The first, and deliberately smallest, protected admin entry point. It does
// one thing: tell the caller whether their own session is administrative,
// and if so who they are. It reads no other account, returns no subscription
// data, and performs no mutation. Every later admin function is this function
// plus an operation; the authorization line is identical.
//
//     Web Admin (Flutter Web)
//         ↓  Authorization: Bearer <the admin's own JWT>
//     this function
//         ↓  requireAdmin(): auth.getUser() + current_user_is_admin(), AS THE CALLER
//     200 { admin: { userId, email, role } }   or   401 / 403 / 503 { error }
//
// The browser cannot become an admin by anything it sends. There is no body
// to read, and the response is the server's conclusion, not an echo.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "content-type": "application/json",
      // An authorization answer must never be served from a cache.
      "cache-control": "no-store",
    },
  });
}

/// The caller's own session, and nothing more privileged. Same construction
/// as every other Edge Function in this project: anon key + the request's
/// Authorization header. No service-role key exists in this function.
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
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST" && request.method !== "GET") {
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

  const result = await requireAdmin(request, userClient);
  if (!result.ok) {
    return jsonResponse(adminAuthErrorBody(result), result.status);
  }

  return jsonResponse({
    ok: true,
    contractVersion: SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
    admin: {
      userId: result.userId,
      email: result.email,
      role: result.role,
    },
  });
});
