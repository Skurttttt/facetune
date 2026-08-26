import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { requestTutorialV2Plan } from "./gemini_client.ts";
import { TUTORIAL_V2_PLANNER_PROMPT_VERSION } from "./prompt.ts";
import { FunctionFailure, type OwnedProduct } from "./types.ts";
import { planRows, parseAndValidatePlan, PlanRejected } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Total planner attempts, including one repair retry. Never unbounded. */
const maximumPlanAttempts = 2;

const MINIMUM_PLAN_VERSION = 2;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[plan-tutorial-v2] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial service is not configured.",
    );
  }
  return value;
}

function requestPayload(value: unknown): { tutorialSessionId: string } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid request is required.",
    );
  }
  const input = value as Record<string, unknown>;
  if (
    typeof input.tutorialSessionId !== "string" ||
    !uuidPattern.test(input.tutorialSessionId)
  ) {
    throw new FunctionFailure(
      400,
      "invalid_session_id",
      "A valid tutorial session ID is required.",
    );
  }
  return { tutorialSessionId: input.tutorialSessionId };
}

function mimeTypeFor(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
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
        "Sign in before opening a tutorial.",
      );
    }

    // Every read below goes through the caller's own client, so RLS decides
    // what this user can see. The client never supplies ownership.
    const client = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: authData, error: authError } = await client.auth.getUser();
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

    // --- Session (server-verified, RLS-scoped) -----------------------------
    const { data: session, error: sessionError } = await client
      .from("tutorial_v2_sessions")
      .select("*")
      .eq("id", payload.tutorialSessionId)
      .maybeSingle();
    if (sessionError || !session) {
      throw new FunctionFailure(
        404,
        "session_not_found",
        "This tutorial could not be found.",
      );
    }
    if (session.user_id !== authData.user.id) {
      // RLS should already have hidden it; this is defense in depth.
      throw new FunctionFailure(
        403,
        "forbidden",
        "This tutorial does not belong to you.",
      );
    }
    if ((session.plan_version as number) < MINIMUM_PLAN_VERSION) {
      throw new FunctionFailure(
        409,
        "incompatible_plan_version",
        "This tutorial was saved by an earlier version. Start a new one.",
      );
    }

    const sourceMode = session.source_mode as
      | "standard_recommendation"
      | "makeup_kit";
    const isKit = sourceMode === "makeup_kit";
    const style = session.makeup_style as string;

    // --- Analysis + face attributes ----------------------------------------
    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select(
        "id, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
      )
      .eq("id", session.analysis_id)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "analysis_not_found",
        "The face analysis behind this tutorial could not be found.",
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

    // --- Recommendation: read by the SESSION's own id, never the client's ---
    const recommendationTable = isKit
      ? "kit_makeup_recommendations"
      : "recommendations";
    const recommendationId = isKit
      ? session.kit_recommendation_id
      : session.recommendation_id;
    const { data: recommendation, error: recommendationError } = await client
      .from(recommendationTable)
      .select("*")
      .eq("id", recommendationId)
      .maybeSingle();
    if (recommendationError || !recommendation) {
      throw new FunctionFailure(
        404,
        "recommendation_not_found",
        "The makeup plan behind this tutorial could not be found.",
      );
    }
    if (
      recommendation.analysis_id !== session.analysis_id ||
      recommendation.makeup_style !== style
    ) {
      throw new FunctionFailure(
        409,
        "recommendation_mismatch",
        "This tutorial's makeup plan no longer matches. Start a new one.",
      );
    }

    // --- Kit ownership, re-verified against live inventory ------------------
    const ownedProducts: OwnedProduct[] = [];
    if (isKit) {
      const snapshots = recommendation.product_snapshot_json;
      if (!Array.isArray(snapshots) || snapshots.length === 0) {
        throw new FunctionFailure(
          409,
          "inventory_changed",
          "This kit look has no products. Create a new kit look.",
        );
      }
      const snapshotIds = snapshots
        .map((item) => (item as Record<string, unknown>).productId)
        .filter((id): id is string => typeof id === "string");

      // RLS scopes this to the caller, so any id that does not come back is
      // one the user does not own.
      const { data: products, error: productsError } = await client
        .from("makeup_kit_products")
        .select("id")
        .in("id", snapshotIds);
      if (productsError) {
        throw new FunctionFailure(
          500,
          "inventory_lookup_failed",
          "Your makeup kit could not be verified.",
          true,
        );
      }
      const ownedIds = new Set((products ?? []).map((row) => row.id as string));
      const missing = snapshotIds.filter((id) => !ownedIds.has(id));
      if (missing.length > 0) {
        throw new FunctionFailure(
          409,
          "inventory_changed",
          "A product in this look was edited or removed. Create a new kit look.",
        );
      }

      for (const item of snapshots) {
        const snapshot = item as Record<string, unknown>;
        ownedProducts.push({
          productId: snapshot.productId as string,
          category: snapshot.category as string,
          colorHex: snapshot.colorHex as string,
          finish: snapshot.finish as string,
          productName: (snapshot.productName as string | null) ?? null,
          colorLabel: (snapshot.colorLabel as string | null) ?? null,
          foundationDepth: (snapshot.foundationDepth as string | null) ?? null,
          foundationUndertone:
            (snapshot.foundationUndertone as string | null) ?? null,
        });
      }
    }

    // --- Canonical final preview: the target the planner decomposes --------
    const canonicalPath = session.canonical_image_path as string;
    const expectedPrefix = `${authData.user.id}/analyses/${session.analysis_id}/`;
    if (
      !canonicalPath.startsWith(expectedPrefix) ||
      canonicalPath.includes("..") ||
      canonicalPath.includes("/original/")
    ) {
      throw new FunctionFailure(
        409,
        "unsafe_storage_path",
        "This tutorial's target image reference is invalid.",
      );
    }
    const { data: canonicalBlob, error: canonicalError } = await client.storage
      .from("face-images")
      .download(canonicalPath);
    if (canonicalError || !canonicalBlob) {
      throw new FunctionFailure(
        404,
        "canonical_preview_unavailable",
        "The final look for this tutorial could not be loaded.",
        true,
      );
    }
    const canonicalImage = {
      bytes: new Uint8Array(await canonicalBlob.arrayBuffer()),
      mimeType: mimeTypeFor(canonicalPath),
    };

    // --- Quota --------------------------------------------------------------
    const quota = await consumeAiQuota(client, "tutorial_v2_plan");
    if (!quota.allowed) {
      return jsonResponse({
        error: {
          code: quota.reason,
          message: quotaMessage(quota.reason),
          retryable: true,
          retryAfterSeconds: quota.retryAfterSeconds,
        },
      }, 429);
    }

    // --- Plan, validate, repair once ---------------------------------------
    const model = Deno.env.get("TUTORIAL_V2_PLANNER_MODEL")?.trim() ||
      "gemini-3.6-flash";

    let repairNotes: string[] | undefined;
    let plan;
    for (let attempt = 1; attempt <= maximumPlanAttempts; attempt += 1) {
      const raw = await requestTutorialV2Plan(
        requiredEnvironment("GEMINI_API_KEY"),
        model,
        {
          style,
          attributes,
          recommendation: recommendation.recommendation_json as Record<
            string,
            unknown
          >,
          sourceMode,
          ownedProducts,
          repairNotes,
        },
        canonicalImage,
      );
      try {
        plan = parseAndValidatePlan(raw, { style, sourceMode, ownedProducts });
        break;
      } catch (error) {
        if (!(error instanceof PlanRejected)) throw error;
        console.error(
          `[plan-tutorial-v2] Plan rejected attempt=${attempt} reasons=${error.reasons.length}`,
        );
        if (attempt >= maximumPlanAttempts) {
          // Bounded: never loop until something happens to pass.
          throw new FunctionFailure(
            422,
            "plan_validation_failed",
            "A usable tutorial could not be planned for this look. Please try again.",
            true,
          );
        }
        repairNotes = error.reasons;
      }
    }
    if (!plan) {
      throw new FunctionFailure(
        422,
        "plan_validation_failed",
        "A usable tutorial could not be planned for this look. Please try again.",
        true,
      );
    }

    // --- Persist atomically -------------------------------------------------
    const { data: totalSteps, error: persistError } = await client.rpc(
      "persist_tutorial_v2_plan",
      {
        p_session_id: payload.tutorialSessionId,
        p_planner_model: model,
        p_planner_prompt_version: TUTORIAL_V2_PLANNER_PROMPT_VERSION,
        p_steps: planRows(plan, ownedProducts),
      },
    );
    if (persistError) {
      console.error(
        `[plan-tutorial-v2] Persistence failed code=${
          persistError.code ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "Your tutorial plan could not be saved.",
        true,
      );
    }

    console.log(
      `[plan-tutorial-v2] Completed model=${model} prompt=${TUTORIAL_V2_PLANNER_PROMPT_VERSION} steps=${totalSteps}`,
    );
    return jsonResponse({
      plan: {
        tutorialSessionId: payload.tutorialSessionId,
        totalSteps,
        plannerModel: model,
        plannerPromptVersion: TUTORIAL_V2_PLANNER_PROMPT_VERSION,
      },
    });
  } catch (error) {
    if (error instanceof FunctionFailure) {
      return jsonResponse({
        error: {
          code: error.code,
          message: error.message,
          retryable: error.retryable,
        },
      }, error.status);
    }
    console.error(
      `[plan-tutorial-v2] Unhandled error type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return jsonResponse({
      error: {
        code: "unexpected_error",
        message: "Your tutorial could not be planned right now.",
        retryable: true,
      },
    }, 500);
  }
});
