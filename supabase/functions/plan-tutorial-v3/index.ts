import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { requestTutorialV3Plan } from "./gemini_client.ts";
import { TUTORIAL_V3_PLANNER_PROMPT_VERSION } from "./prompt.ts";
import {
  FunctionFailure,
  type OwnedProduct,
  type SourceMode,
} from "./types.ts";
import { PlanRejected, parseAndValidatePlan, planRows } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const supportedPlanVersion = 3;
const maximumPlanAttempts = 2;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial service is not configured.",
    );
  }
  return value;
}

function requestedSessionId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid tutorial planning request is required.",
    );
  }
  const sessionId = (value as Record<string, unknown>).sessionId;
  if (typeof sessionId !== "string" || !uuidPattern.test(sessionId)) {
    throw new FunctionFailure(
      400,
      "invalid_session_id",
      "A valid tutorial session ID is required.",
    );
  }
  return sessionId;
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
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before opening a tutorial.",
      );
    }
    // The caller's own JWT, so RLS governs every read below and a session
    // belonging to someone else is simply invisible.
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
        "authentication_failed",
        "Your session has expired. Sign in again.",
      );
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      throw new FunctionFailure(
        400,
        "invalid_json",
        "The request body must be valid JSON.",
      );
    }
    const sessionId = requestedSessionId(payload);

    // --- Session ------------------------------------------------------------
    const { data: session, error: sessionError } = await client
      .from("tutorial_v3_sessions")
      .select("*")
      .eq("id", sessionId)
      .maybeSingle();
    if (sessionError) {
      throw new FunctionFailure(
        500,
        "session_lookup_failed",
        "This tutorial could not be loaded.",
        true,
      );
    }
    if (!session) {
      throw new FunctionFailure(
        404,
        "session_not_found",
        "This tutorial could not be found.",
      );
    }
    if (session.plan_version !== supportedPlanVersion) {
      throw new FunctionFailure(
        409,
        "incompatible_plan_version",
        "This tutorial was saved by a different version. Start a new one.",
      );
    }

    const sourceMode = session.source_mode as SourceMode;
    const isKit = sourceMode === "makeup_kit";
    const style = session.makeup_style as string;

    // --- Analysis + face attributes ----------------------------------------
    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select("id, face_shape, skin_tone, undertone, eye_shape, lip_shape")
      .eq("id", session.analysis_id)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "analysis_not_found",
        "The face analysis behind this tutorial could not be found.",
      );
    }
    // Only the attributes any V3 category is allowed to reason about. Hair and
    // eye colour are deliberately not sent: no category uses them, and an
    // unused attribute in the prompt invites irrelevant personalization.
    const analysisAttributes: Record<string, string> = {};
    for (
      const key of [
        "face_shape",
        "skin_tone",
        "undertone",
        "eye_shape",
        "lip_shape",
      ]
    ) {
      const value = (analysis as Record<string, unknown>)[key];
      if (typeof value === "string" && value.trim().length > 0) {
        analysisAttributes[key] = value;
      }
    }

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
    const expectedPrefix =
      `${authData.user.id}/analyses/${session.analysis_id}/`;
    // The folder also has to agree with the session's mode. Both preview
    // chains write under the same analysis, so a Kit session pointed at a
    // standard preview path would decompose the wrong look for the same face.
    const canonicalFolder = isKit ? "/kit-generated/" : "/generated/";
    if (
      !canonicalPath.startsWith(expectedPrefix) ||
      canonicalPath.includes("..") ||
      canonicalPath.includes("/original/") ||
      !canonicalPath.includes(canonicalFolder)
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
    const quota = await consumeAiQuota(client, "tutorial_v3_plan");
    if (!quota.allowed) {
      return jsonResponse(
        {
          error: {
            code: quota.reason,
            message: quotaMessage(quota.reason),
            retryable: true,
            retryAfterSeconds: quota.retryAfterSeconds,
          },
        },
        429,
      );
    }

    // --- Plan, validate, repair once ---------------------------------------
    const model = Deno.env.get("TUTORIAL_V3_PLANNER_MODEL")?.trim() ||
      "gemini-3.6-flash";

    let repairNotes: string[] | undefined;
    let plan;
    for (let attempt = 1; attempt <= maximumPlanAttempts; attempt += 1) {
      const raw = await requestTutorialV3Plan(
        requiredEnvironment("GEMINI_API_KEY"),
        model,
        {
          style,
          sourceMode,
          attributes: analysisAttributes,
          recommendation: recommendation.recommendation_json as Record<
            string,
            unknown
          >,
          ownedProducts,
          repairNotes,
        },
        canonicalImage,
      );
      try {
        plan = parseAndValidatePlan(raw, {
          style,
          sourceMode,
          ownedProducts,
          analysisAttributes,
        });
        break;
      } catch (error) {
        if (!(error instanceof PlanRejected)) throw error;
        console.error(
          `[plan-tutorial-v3] plan rejected attempt=${attempt} reasons=${error.reasons.length}`,
        );
        if (attempt >= maximumPlanAttempts) {
          // Bounded: one repair round, then the failure is reported honestly
          // rather than persisted as a broken tutorial.
          throw new FunctionFailure(
            422,
            "plan_validation_failed",
            "A usable tutorial could not be planned for this look.",
            true,
          );
        }
        repairNotes = error.reasons;
      }
    }
    if (!plan) {
      throw new FunctionFailure(
        502,
        "plan_unavailable",
        "A tutorial plan could not be produced.",
        true,
      );
    }

    // --- Persist atomically -------------------------------------------------
    const { data: total, error: persistError } = await client.rpc(
      "persist_tutorial_v3_plan",
      {
        p_session_id: sessionId,
        p_planner_model: model,
        p_planner_prompt_version: TUTORIAL_V3_PLANNER_PROMPT_VERSION,
        p_steps: planRows(plan, { style, sourceMode, ownedProducts }),
      },
    );
    if (persistError) {
      console.error(
        `[plan-tutorial-v3] plan persist failed code=${persistError.code ?? "unknown"}`,
      );
      throw new FunctionFailure(
        500,
        "plan_persist_failed",
        "Your tutorial could not be saved. Please try again.",
        true,
      );
    }

    return jsonResponse({
      sessionId,
      totalSteps: total,
      planVersion: supportedPlanVersion,
      plannerModel: model,
      plannerPromptVersion: TUTORIAL_V3_PLANNER_PROMPT_VERSION,
    });
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "This tutorial could not be planned.",
        true,
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[plan-tutorial-v3] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[plan-tutorial-v3] request_failed code=${failure.code}`);
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
