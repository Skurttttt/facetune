import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  buildCanonicalPlan,
  PlanViolation,
  STYLE_PROFILES,
} from "../_shared/kit_makeup_plan.ts";
import { requestGeminiKitPlanDraft } from "./gemini_client.ts";
import {
  KIT_MAKEUP_RECOMMENDATION_V3_PROMPT_VERSION,
  kitMakeupRecommendationV3SystemInstruction,
  kitMakeupRecommendationV3UserText,
} from "./prompt_v3.ts";
import { KIT_MAKEUP_RECOMMENDATION_V3_SCHEMA } from "./schema_v3.ts";
import type { KitProduct } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { assertProductsUnchanged } from "./validation.ts";
import { parseKitRecommendationV3Draft } from "./validation_v3.ts";

// deno-lint-ignore no-explicit-any
type Client = SupabaseClient<any, "public", "public", any, any>;

export type PlanRequest = {
  analysisId: string;
  style: string;
  planRequestId: string;
};

const productColumns =
  "id,user_id,category,product_name,color_hex,color_label,finish,foundation_depth,foundation_undertone";

/** The server switch for the plan-driven pipeline. Anything but the exact
 * value keeps every request on the v2 path. */
export function planPipelineEnabled(): boolean {
  return Deno.env.get("KIT_MAKEUP_PLAN_PIPELINE")?.trim() === "enabled";
}

export function planResponse(row: Record<string, unknown>) {
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
      planId: row.plan_id,
      planVersion: row.plan_version,
    },
  };
}

/**
 * Creates — or, for a replayed `planRequestId`, returns — the canonical plan
 * and its derived recommendation.
 *
 * The replay lookup runs before quota and before the model, so a client that
 * lost a response and asks again gets the same plan and spends nothing.
 */
export async function handlePlanRequest(
  userClient: Client,
  userId: string,
  request: PlanRequest,
  environment: (name: string) => string,
): Promise<Record<string, unknown>> {
  const existing = await findByPlanRequest(userClient, request.planRequestId);
  if (existing) return replayed(existing, request);

  const { data: analysis, error: analysisError } = await userClient
    .from("analyses")
    .select(
      "id, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
    )
    .eq("id", request.analysisId)
    .maybeSingle();
  if (analysisError || !analysis) {
    throw new FunctionFailure(
      404,
      "analysis_not_found",
      "The completed analysis could not be found.",
    );
  }
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
  if (products.some((product) => product.user_id !== userId)) {
    throw new FunctionFailure(
      403,
      "ownership_mismatch",
      "Your makeup kit could not be verified.",
    );
  }
  const row = analysis as Record<string, unknown>;
  const attributes = {
    faceShape: row.face_shape,
    skinTone: row.skin_tone,
    undertone: row.undertone,
    eyeShape: row.eye_shape,
    lipShape: row.lip_shape,
    hairColor: row.hair_color,
    eyeColor: row.eye_color,
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
  const expectation = STYLE_PROFILES[request.style].complexion_expectation;
  const geminiText = await requestGeminiKitPlanDraft(
    environment("GEMINI_API_KEY"),
    model,
    kitMakeupRecommendationV3SystemInstruction(expectation),
    kitMakeupRecommendationV3UserText(attributes, request.style, products),
    KIT_MAKEUP_RECOMMENDATION_V3_SCHEMA,
  );
  const draft = parseKitRecommendationV3Draft(geminiText);
  let built;
  try {
    built = await buildCanonicalPlan({
      planId: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
      analysisId: request.analysisId,
      styleCode: request.style,
      recommendationPromptVersion: KIT_MAKEUP_RECOMMENDATION_V3_PROMPT_VERSION,
      inventory: products,
      draft,
    });
  } catch (error) {
    if (!(error instanceof PlanViolation)) throw error;
    console.error(
      `[generate-kit-makeup-recommendation] plan_rejected code=${error.code}`,
    );
    throw new FunctionFailure(
      502,
      "invalid_ai_plan",
      "The kit recommendation service returned an invalid plan.",
      true,
    );
  }

  // Re-read the selected rows after the model answered. RLS still scopes this
  // to the caller, and exact field comparison detects an edit or deletion race.
  const selectedIds = built.plan.selected_items.map((item) => item.product_id);
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

  // Plan-backed rows are written by the server only: the insert policy for
  // callers refuses any row that carries a plan.
  const serviceClient = createClient(
    environment("SUPABASE_URL"),
    environment("SUPABASE_SERVICE_ROLE_KEY"),
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
  const { data: inserted, error: insertError } = await serviceClient
    .from("kit_makeup_recommendations")
    .insert({
      user_id: userId,
      analysis_id: request.analysisId,
      makeup_style: request.style,
      recommendation_json: built.recommendation,
      product_snapshot_json: built.snapshot,
      model_name: model,
      prompt_version: KIT_MAKEUP_RECOMMENDATION_V3_PROMPT_VERSION,
      plan_id: built.plan.plan_id,
      plan_version: built.plan.plan_version,
      plan_json: built.plan,
      plan_digest: built.planDigest,
      plan_request_id: request.planRequestId,
    } as never)
    .select("*")
    .single();
  if (insertError?.code === "23505") {
    // A concurrent replay of this planRequestId won the insert. Its plan is
    // the plan for this request; this one is discarded.
    const winner = await findByPlanRequest(userClient, request.planRequestId);
    if (winner) return replayed(winner, request);
  }
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
    `[generate-kit-makeup-recommendation] Completed model=${model} prompt=${KIT_MAKEUP_RECOMMENDATION_V3_PROMPT_VERSION} plan=${built.plan.plan_version} products=${selectedIds.length}`,
  );
  return planResponse(inserted as Record<string, unknown>);
}

async function findByPlanRequest(
  client: Client,
  planRequestId: string,
): Promise<Record<string, unknown> | null> {
  const { data, error } = await client
    .from("kit_makeup_recommendations")
    .select("*")
    .eq("plan_request_id", planRequestId)
    .maybeSingle();
  if (error) {
    throw new FunctionFailure(
      503,
      "plan_lookup_failed",
      "The kit-based makeup plan could not be checked.",
      true,
    );
  }
  return data as Record<string, unknown> | null;
}

function replayed(
  row: Record<string, unknown>,
  request: PlanRequest,
): Record<string, unknown> {
  if (
    row.analysis_id !== request.analysisId ||
    row.makeup_style !== request.style
  ) {
    throw new FunctionFailure(
      409,
      "plan_request_conflict",
      "This request was already used for a different look.",
    );
  }
  console.log("[generate-kit-makeup-recommendation] plan_request_replayed");
  return planResponse(row);
}
