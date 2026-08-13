import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { requestGeminiKitRecommendation } from "./gemini_client.ts";
import { KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION } from "./prompt.ts";
import type { KitProduct } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import {
  assertProductsUnchanged,
  parseAndValidateKitRecommendation,
} from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const allowedStyles = new Set([
  "natural",
  "everyday",
  "office",
  "soft_glam",
  "full_glam",
  "bridal",
  "korean",
  "clean_girl",
  "party",
  "date_night",
  "no_makeup_makeup",
  "old_money",
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
    console.error(`[generate-kit-makeup-recommendation] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The kit recommendation service is not configured.",
    );
  }
  return value;
}

function requestPayload(value: unknown): { analysisId: string; style: string } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid request is required.",
    );
  }
  const input = value as Record<string, unknown>;
  if (
    typeof input.analysisId !== "string" || !uuidPattern.test(input.analysisId)
  ) {
    throw new FunctionFailure(
      400,
      "invalid_analysis_id",
      "A valid analysis ID is required.",
    );
  }
  if (typeof input.style !== "string" || !allowedStyles.has(input.style)) {
    throw new FunctionFailure(
      400,
      "invalid_style",
      "Choose a supported makeup style.",
    );
  }
  return { analysisId: input.analysisId, style: input.style };
}

function response(row: Record<string, unknown>) {
  return {
    recommendation: {
      id: row.id,
      analysisId: row.analysis_id,
      style: row.makeup_style,
      plan: row.recommendation_json,
      productSnapshot: row.product_snapshot_json,
      modelId: row.model_name,
      promptVersion: row.prompt_version,
      createdAt: row.created_at,
    },
  };
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
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before generating a kit-based plan.",
      );
    }
    const userClient = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: authData, error: authError } = await userClient.auth
      .getUser();
    if (authError || !authData.user) {
      throw new FunctionFailure(
        401,
        "invalid_session",
        "Your session has expired. Sign in again.",
      );
    }
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      throw new FunctionFailure(
        400,
        "invalid_json",
        "The request body must be valid JSON.",
      );
    }
    const payload = requestPayload(body);
    const { data: analysis, error: analysisError } = await userClient
      .from("analyses")
      .select(
        "id, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
      )
      .eq("id", payload.analysisId)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "analysis_not_found",
        "The completed analysis could not be found.",
      );
    }
    const productColumns =
      "id,user_id,category,product_name,color_hex,color_label,finish,foundation_depth,foundation_undertone";
    const { data: productRows, error: kitError } = await userClient
      .from("makeup_kit_products")
      .select(productColumns)
      .order("created_at", { ascending: true });
    if (kitError) {
      throw new FunctionFailure(
        503,
        "kit_unavailable",
        "Your makeup kit could not be loaded.",
        true,
      );
    }
    const products = (productRows ?? []) as KitProduct[];
    if (products.length === 0) {
      throw new FunctionFailure(
        422,
        "empty_kit",
        "Add at least one product to My Makeup Kit first.",
      );
    }
    if (products.some((product) => product.user_id !== authData.user.id)) {
      throw new FunctionFailure(
        403,
        "ownership_mismatch",
        "Your makeup kit could not be verified.",
      );
    }
    const attributes = {
      faceShape: analysis.face_shape,
      skinTone: analysis.skin_tone,
      undertone: analysis.undertone,
      eyeShape: analysis.eye_shape,
      lipShape: analysis.lip_shape,
      hairColor: analysis.hair_color,
      eyeColor: analysis.eye_color,
    };
    const quota = await consumeAiQuota(userClient, "kit_makeup_recommendation");
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
    const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";
    const geminiText = await requestGeminiKitRecommendation(
      requiredEnvironment("GEMINI_API_KEY"),
      model,
      attributes,
      payload.style,
      products,
    );
    const plan = parseAndValidateKitRecommendation(geminiText, products);
    const selectedIds = plan.selections.map((selection) => selection.productId);

    // Re-read selected rows after AI completes. RLS still scopes this query to
    // the caller, and exact field comparison detects deletion/edit races.
    const { data: currentRows, error: currentError } = await userClient
      .from("makeup_kit_products")
      .select(productColumns)
      .in("id", selectedIds);
    if (currentError) {
      throw new FunctionFailure(
        503,
        "kit_unavailable",
        "Your makeup kit could not be verified.",
        true,
      );
    }
    assertProductsUnchanged(
      selectedIds,
      products,
      (currentRows ?? []) as KitProduct[],
    );
    const snapshots = selectedIds.map((id) => {
      const product = products.find((candidate) => candidate.id === id)!;
      return {
        productId: product.id,
        category: product.category,
        productName: product.product_name,
        colorHex: product.color_hex,
        colorLabel: product.color_label,
        finish: product.finish,
        foundationDepth: product.foundation_depth,
        foundationUndertone: product.foundation_undertone,
      };
    });
    const { data: inserted, error: insertError } = await userClient
      .from("kit_makeup_recommendations")
      .insert({
        user_id: authData.user.id,
        analysis_id: payload.analysisId,
        makeup_style: payload.style,
        recommendation_json: plan,
        product_snapshot_json: snapshots,
        model_name: model,
        prompt_version: KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION,
      } as never)
      .select("*")
      .single();
    if (insertError || !inserted) {
      console.error(
        `[generate-kit-makeup-recommendation] Persistence failed code=${
          insertError?.code ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "The kit-based makeup plan could not be saved.",
        true,
      );
    }
    console.log(
      `[generate-kit-makeup-recommendation] Completed model=${model} prompt=${KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION} products=${selectedIds.length}`,
    );
    return jsonResponse(response(inserted));
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The kit recommendation request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-kit-makeup-recommendation] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    }, failure.status);
  }
});
