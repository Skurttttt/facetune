import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createRecommendation } from "./handler.ts";
import { CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION } from "./prompt.ts";
import { createSupabasePorts } from "./supabase_ports.ts";
import { FunctionFailure } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({
      error: {
        code: "method_not_allowed",
        message: "Method not allowed.",
        retryable: false,
      },
    }, 405);
  }
  try {
    const authorization = request.headers.get("authorization") ?? "";
    const result = await createRecommendation(
      request,
      createSupabasePorts(authorization),
    );
    // Identifiers only: never a color, a finish, a prompt, or a token.
    console.log(
      `[generate-custom-palette-recommendation] Completed prompt=${CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION}`,
    );
    return jsonResponse(result.body, result.status);
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The recommendation request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-custom-palette-recommendation] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(
      `[generate-custom-palette-recommendation] Failed code=${failure.code}`,
    );
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    }, failure.status);
  }
});
