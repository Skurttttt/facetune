import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { createPreview, FunctionFailure } from "./handler.ts";
import { createSupabasePorts } from "./supabase_ports.ts";

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
    const result = await createPreview(
      request,
      createSupabasePorts(request.headers.get("authorization") ?? ""),
    );
    return jsonResponse(result.body, result.status);
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The preview request could not be completed.",
        true,
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-custom-palette-preview] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    // A code only: never a color, a prompt, a path, or a token.
    console.error(
      `[generate-custom-palette-preview] Failed code=${failure.code}`,
    );
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
        ...failure.details,
      },
    }, failure.status);
  }
});
