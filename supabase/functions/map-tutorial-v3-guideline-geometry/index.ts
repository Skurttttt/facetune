import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { isOwnedOriginalPath } from "../_shared/storage_ownership.ts";
import { requestGeometry } from "./gemini_client.ts";
import { GEOMETRY_PROMPT_VERSION, geometryMapperPrompt } from "./prompt.ts";
import {
  FINAL_LOOK,
  FunctionFailure,
  GEOMETRY_SCHEMA_VERSION,
  SCOPED_ATTRIBUTES,
  type SourceMode,
} from "./types.ts";
import { GeometryRejected, parseAndValidateGeometry } from "./validation.ts";

/**
 * Maps ONE persisted Step Spec to validated normalized geometry.
 *
 * The client sends identifiers only. Everything the mapper sees — the Step
 * Spec, the category, the face attributes, the selfie — is resolved here from
 * persisted records under the caller's own JWT, so RLS governs every read.
 *
 * The canonical final preview is NOT an input. It reaches the tutorial through
 * the planner (which wrote the Step Spec) and through the UI, never through
 * this call.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const supportedPlanVersion = 3;
const maxMappingAttempts = 3;

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

/** The only two values a client may supply. */
function requestedTarget(value: unknown): {
  sessionId: string;
  stepIndex: number;
} {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid guideline request is required.",
    );
  }
  const body = value as Record<string, unknown>;

  // Anything that would let a caller steer the mapper is refused outright
  // rather than ignored, so a future client cannot start relying on it.
  for (
    const forbidden of [
      "prompt",
      "stepSpec",
      "step_spec_json",
      "category",
      "faceAttributes",
      "selectedStyle",
      "analysisId",
      "storagePath",
      "imagePath",
      "geometry",
      "schemaVersion",
      "planVersion",
      "productId",
      "ownedProductIds",
      "sourceMode",
      "model",
    ]
  ) {
    if (body[forbidden] !== undefined) {
      throw new FunctionFailure(
        400,
        "unsupported_field",
        `"${forbidden}" is resolved by the server and may not be supplied.`,
      );
    }
  }

  const sessionId = body.sessionId;
  if (typeof sessionId !== "string" || !uuidPattern.test(sessionId)) {
    throw new FunctionFailure(
      400,
      "invalid_session_id",
      "A valid tutorial session ID is required.",
    );
  }
  const stepIndex = body.stepIndex;
  if (
    typeof stepIndex !== "number" || !Number.isInteger(stepIndex) ||
    stepIndex < 1
  ) {
    throw new FunctionFailure(
      400,
      "invalid_step_index",
      "A valid step index is required.",
    );
  }
  return { sessionId, stepIndex };
}

function mimeTypeFor(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

function text(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      { error: { code: "method_not_allowed", message: "Method not allowed.", retryable: false } },
      405,
    );
  }

  let claimedSessionId: string | null = null;
  let claimedStepIndex: number | null = null;
  // deno-lint-ignore no-explicit-any
  let userClient: any = null;

  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before opening a tutorial.",
      );
    }
    // The caller's own JWT. Never the service role: RLS must govern every read
    // and write below, so a session belonging to someone else is invisible.
    const client = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    userClient = client;

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
      throw new FunctionFailure(400, "invalid_json", "The request body must be valid JSON.");
    }
    const { sessionId, stepIndex } = requestedTarget(payload);

    // --- Session ------------------------------------------------------------
    const { data: session, error: sessionError } = await client
      .from("tutorial_v3_sessions")
      .select("*")
      .eq("id", sessionId)
      .maybeSingle();
    if (sessionError) {
      throw new FunctionFailure(500, "session_lookup_failed", "This tutorial could not be loaded.", true);
    }
    if (!session) {
      throw new FunctionFailure(404, "session_not_found", "This tutorial could not be found.");
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

    // --- Step ---------------------------------------------------------------
    const { data: step, error: stepError } = await client
      .from("tutorial_v3_steps")
      .select("*")
      .eq("tutorial_v3_session_id", sessionId)
      .eq("step_index", stepIndex)
      .maybeSingle();
    if (stepError) {
      throw new FunctionFailure(500, "step_lookup_failed", "This step could not be loaded.", true);
    }
    if (!step) {
      throw new FunctionFailure(404, "step_not_found", "This tutorial step could not be found.");
    }
    if (step.category === FINAL_LOOK) {
      throw new FunctionFailure(
        400,
        "final_look_has_no_geometry",
        "The final look reuses the canonical preview.",
      );
    }

    // --- Step Spec is the authority ----------------------------------------
    const spec = step.step_spec_json as Record<string, unknown> | null;
    if (!spec || typeof spec !== "object") {
      throw new FunctionFailure(409, "step_spec_missing", "This step has no instruction to map.");
    }
    // The spec must agree with the row and the session it belongs to. A
    // disagreement means the plan and its rows drifted, and mapping either one
    // would teach something the tutorial did not decide.
    if (spec.category !== step.category) {
      throw new FunctionFailure(
        409,
        "step_spec_mismatch",
        "This step's instruction does not match its category.",
      );
    }
    if (spec.selected_style_code !== style) {
      throw new FunctionFailure(
        409,
        "step_spec_mismatch",
        "This step's instruction belongs to a different look.",
      );
    }
    if (spec.source_mode !== sourceMode) {
      throw new FunctionFailure(
        409,
        "source_mode_mismatch",
        "This step's instruction belongs to a different recommendation source.",
      );
    }

    // --- Analysis + scoped attributes --------------------------------------
    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select("id, original_image_path, face_shape, skin_tone, undertone, eye_shape, lip_shape")
      .eq("id", session.analysis_id)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "analysis_not_found",
        "The face analysis behind this tutorial could not be found.",
      );
    }

    // Only what this category may reason about. The client's copy of the
    // attributes is never consulted.
    const scoped: Record<string, string> = {};
    for (const key of SCOPED_ATTRIBUTES[step.category as string] ?? []) {
      const value = (analysis as Record<string, unknown>)[key];
      if (typeof value === "string" && value.trim().length > 0) {
        scoped[key] = value;
      }
    }

    // --- Recommendation integrity ------------------------------------------
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
      // one the user does not own. The step's own product snapshot is checked
      // against the same live set rather than trusted.
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
      if (snapshotIds.some((id) => !ownedIds.has(id))) {
        throw new FunctionFailure(
          409,
          "inventory_changed",
          "A product in this look was edited or removed. Create a new kit look.",
        );
      }

      const stepProduct = step.product_snapshot_json as
        | Record<string, unknown>
        | null;
      const stepProductId = stepProduct?.product_id;
      if (typeof stepProductId !== "string" || !ownedIds.has(stepProductId)) {
        throw new FunctionFailure(
          409,
          "inventory_changed",
          "This step teaches a product you no longer own.",
        );
      }
    }

    // --- Original selfie ----------------------------------------------------
    const originalPath = analysis.original_image_path as string;
    if (
      !isOwnedOriginalPath(originalPath, authData.user.id, analysis.id as string)
    ) {
      // Segment-by-segment, never a prefix test: a prefix match accepts `..`
      // traversal and paths outside the caller's own analysis folder.
      throw new FunctionFailure(
        409,
        "unsafe_storage_path",
        "This tutorial's source image reference is invalid.",
      );
    }
    const { data: selfieBlob, error: selfieError } = await client.storage
      .from("face-images")
      .download(originalPath);
    if (selfieError || !selfieBlob) {
      throw new FunctionFailure(
        404,
        "selfie_unavailable",
        "Your photo for this tutorial could not be loaded.",
        true,
      );
    }
    const selfie = {
      bytes: new Uint8Array(await selfieBlob.arrayBuffer()),
      mimeType: mimeTypeFor(originalPath),
    };

    // --- Atomic claim -------------------------------------------------------
    const { data: claim, error: claimError } = await client.rpc(
      "claim_tutorial_v3_geometry",
      {
        p_session_id: sessionId,
        p_step_index: stepIndex,
        p_max_attempts: maxMappingAttempts,
        // The build declares the schema it can render. The RPC reuses a
        // stored document only at this version and re-claims anything else,
        // so a stale document is never returned to be rendered.
        p_schema_version: GEOMETRY_SCHEMA_VERSION,
      },
    );
    if (claimError) {
      throw new FunctionFailure(500, "claim_failed", "This step could not be prepared.", true);
    }
    const outcome = (claim as Record<string, unknown> | null)?.outcome;

    if (outcome === "reused") {
      // Idempotent: compatible geometry already exists, so no model call and
      // no quota is spent.
      const storedVersion = step.geometry_schema_version as number | null;
      if (storedVersion === GEOMETRY_SCHEMA_VERSION) {
        return jsonResponse({
          sessionId,
          stepIndex,
          status: "ready",
          reused: true,
          schemaVersion: storedVersion,
          geometry: step.geometry_json,
        });
      }
      // Unreachable while the RPC is version-scoped, and kept as a hard stop:
      // rendering a document under the wrong vocabulary is worse than an
      // error the client can retry.
      throw new FunctionFailure(
        409,
        "incompatible_geometry_version",
        "This step's guideline was saved in an older format. Refresh it.",
      );
    }
    if (outcome === "in_flight") {
      throw new FunctionFailure(
        409,
        "already_mapping",
        "This step is already being prepared.",
        true,
      );
    }
    if (outcome === "exhausted") {
      throw new FunctionFailure(
        429,
        "mapping_attempts_exhausted",
        "This step could not be prepared after several attempts.",
      );
    }
    if (outcome === "final_look") {
      throw new FunctionFailure(
        400,
        "final_look_has_no_geometry",
        "The final look reuses the canonical preview.",
      );
    }
    if (outcome !== "claimed") {
      throw new FunctionFailure(404, "step_not_found", "This tutorial step could not be found.");
    }
    claimedSessionId = sessionId;
    claimedStepIndex = stepIndex;

    // --- Quota (only once a claim is actually held) -------------------------
    const quota = await consumeAiQuota(client, "tutorial_v3_geometry");
    if (!quota.allowed) {
      await releaseClaim(client, sessionId, stepIndex, "quota_exceeded", step.attempt_count);
      claimedSessionId = null;
      return jsonResponse({
        error: {
          code: quota.reason,
          message: quotaMessage(quota.reason),
          retryable: true,
          retryAfterSeconds: quota.retryAfterSeconds,
        },
      }, 429);
    }

    // --- Map, validate, persist --------------------------------------------
    const model = Deno.env.get("TUTORIAL_V3_GEOMETRY_MODEL")?.trim() ||
      "gemini-3.6-flash";

    const prompt = geometryMapperPrompt({
      category: step.category as string,
      whereToApply: text(spec.where_to_apply) ?? "",
      direction: text(spec.direction) ?? "",
      technique: text(spec.technique) ?? "",
      coverage: text(spec.coverage),
      intensity: text(spec.intensity),
      visualDescription: text(
        (spec.guideline_visual_intent as Record<string, unknown> | undefined)
          ?.description,
      ),
      faceAttributes: scoped,
    });

    const raw = await requestGeometry(
      requiredEnvironment("GEMINI_API_KEY"),
      model,
      prompt,
      selfie,
    );

    const geometry = parseAndValidateGeometry(raw, step.category as string);

    const { data: persisted, error: persistError } = await client
      .from("tutorial_v3_steps")
      .update({
        geometry_status: "ready",
        geometry_json: geometry,
        geometry_schema_version: GEOMETRY_SCHEMA_VERSION,
        geometry_error: null,
        model_name: model,
        prompt_version: GEOMETRY_PROMPT_VERSION,
      })
      .eq("tutorial_v3_session_id", sessionId)
      .eq("step_index", stepIndex)
      // Only the caller holding the claim may attach geometry.
      .eq("geometry_status", "generating")
      .select()
      .maybeSingle();
    if (persistError || !persisted) {
      throw new FunctionFailure(
        500,
        "geometry_persist_failed",
        "This guideline could not be saved. Please try again.",
        true,
      );
    }
    claimedSessionId = null;

    return jsonResponse({
      sessionId,
      stepIndex,
      status: "ready",
      reused: false,
      schemaVersion: GEOMETRY_SCHEMA_VERSION,
      geometry,
      model,
      promptVersion: GEOMETRY_PROMPT_VERSION,
    });
  } catch (error) {
    // A claim this request still owns must not be left in `generating`, or the
    // step would be stuck until something else reset it.
    if (claimedSessionId !== null && claimedStepIndex !== null && userClient) {
      const reason = error instanceof GeometryRejected
        ? "geometry_rejected"
        : error instanceof FunctionFailure
        ? error.code
        : "mapping_failed";
      await releaseClaim(userClient, claimedSessionId, claimedStepIndex, reason, null);
    }

    if (error instanceof GeometryRejected) {
      console.error(
        `[map-tutorial-v3-geometry] geometry rejected reasons=${error.reasons.length}`,
      );
      return jsonResponse({
        error: {
          code: "geometry_validation_failed",
          message: "A usable guideline could not be prepared for this step.",
          retryable: true,
        },
      }, 422);
    }

    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(500, "server_error", "This step could not be prepared.", true);
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[map-tutorial-v3-geometry] Unhandled error type=${
          (error as Error)?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[map-tutorial-v3-geometry] request_failed code=${failure.code}`);
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    }, failure.status);
  }
});

/**
 * Marks a held claim failed so the step becomes retryable.
 *
 * Pass `null` for `previousAttempts` when a real mapping attempt was made:
 * the count is then incremented, which is what makes retries bounded. Pass the
 * current count to hold it steady for a refusal that never reached the model,
 * such as a quota denial, so it does not burn one of the step's attempts.
 *
 * No geometry is written either way: a missing overlay is always preferable to
 * a wrong one.
 */
async function releaseClaim(
  // deno-lint-ignore no-explicit-any
  client: any,
  sessionId: string,
  stepIndex: number,
  reason: string,
  previousAttempts: number | null,
): Promise<void> {
  try {
    const values: Record<string, unknown> = {
      geometry_status: "failed",
      geometry_error: reason.slice(0, 200),
      geometry_json: null,
      geometry_schema_version: null,
    };
    if (typeof previousAttempts === "number") {
      values.attempt_count = previousAttempts;
    } else {
      const { data } = await client
        .from("tutorial_v3_steps")
        .select("attempt_count")
        .eq("tutorial_v3_session_id", sessionId)
        .eq("step_index", stepIndex)
        .maybeSingle();
      values.attempt_count = ((data?.attempt_count as number | null) ?? 0) + 1;
    }
    await client
      .from("tutorial_v3_steps")
      .update(values)
      .eq("tutorial_v3_session_id", sessionId)
      .eq("step_index", stepIndex)
      .eq("geometry_status", "generating");
  } catch {
    console.error("[map-tutorial-v3-geometry] claim release failed");
  }
}
