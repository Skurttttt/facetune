import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { isOwnedOriginalPath } from "../_shared/storage_ownership.ts";
import { requestGeminiGeometryPlan } from "./gemini_client.ts";
import { tutorialFaceAttributesFromRow, TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION } from "./prompt.ts";
import type { CategoryProductFacts } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { parseAndValidateGeometryPlan } from "./validation.ts";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumSourceBytes = 10 * 1024 * 1024;
const defaultTutorialGeometryModel = "gemini-3.6-flash";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[plan-tutorial-geometry] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial geometry planning service is not configured.",
    );
  }
  return value;
}

/**
 * Read from an env var every request rather than baked into this function's
 * code, matching the exact configurability rule already applied to
 * `generate-tutorial-step`'s `TUTORIAL_IMAGE_MODEL`. Deliberately its own
 * env var, not a re-use of `GEMINI_MODEL`/`TUTORIAL_IMAGE_MODEL`, so an
 * operator can tune geometry planning independently of face analysis and
 * tutorial image generation (same rationale ST-9 already recorded for
 * `TUTORIAL_IMAGE_MODEL`).
 */
function configuredModel(): string {
  return Deno.env.get("TUTORIAL_GEOMETRY_MODEL")?.trim() ||
    defaultTutorialGeometryModel;
}

function requestedSessionId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid tutorial geometry planning request is required.",
    );
  }
  const id = (value as Record<string, unknown>).tutorialSessionId;
  if (typeof id !== "string" || !uuidPattern.test(id)) {
    throw new FunctionFailure(
      400,
      "invalid_tutorial_session_id",
      "A valid tutorial session ID is required.",
    );
  }
  return id;
}

function categoryLabel(code: string): string {
  return code
    .split("_")
    .map((word) => word.length === 0 ? word : word[0].toUpperCase() + word.slice(1))
    .join(" ");
}

function clean(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

function objectValue(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

/** Builds the real, already-persisted product facts one `tutorial_steps`
 * row carries (TF-1) into the shape `validation.ts` checks Gemini's output
 * against. `personalized_spec_json.what` is preferred (the canonical,
 * TF-1-computed decision); `instruction_json` is only a fallback for a
 * legacy/pre-TF-1 row that has no personalized spec yet. Nothing here
 * invents a fact neither source actually has. */
function categoryFactsFromStep(
  row: Record<string, unknown>,
): CategoryProductFacts {
  const category = row.category as string;
  const instruction = objectValue(row.instruction_json);
  const personalizedSpec = row.personalized_spec_json;
  const what = personalizedSpec ? objectValue(objectValue(personalizedSpec).what) : {};
  const where = personalizedSpec ? objectValue(objectValue(personalizedSpec).where) : {};
  const productSnapshot = objectValue(what.productSnapshot);
  return {
    category,
    label: categoryLabel(category),
    productName: clean(what.productName ?? instruction.productName),
    colorName: clean(what.colorName ?? instruction.colorName),
    colorHex: clean(what.colorHex ?? instruction.hex),
    finish: clean(what.finish ?? instruction.finish),
    placement: clean(where.description ?? instruction.placement),
    technique: clean(instruction.technique),
    intensity: clean(instruction.intensity),
    kitProductId: clean(productSnapshot.productId),
  };
}

function sessionResponse(row: Record<string, unknown>) {
  return { session: row };
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

  let userClient: ReturnType<typeof createClient> | null = null;
  let claimedSessionId: string | null = null;
  const requestStartedAt = Date.now();
  const timings: Record<string, number> = {};

  // Durations only -- never payloads, paths, tokens, or image bytes. Same
  // convention as generate-tutorial-step/index.ts.
  const timed = async <T>(
    stage: string,
    operation: () => PromiseLike<T>,
  ): Promise<T> => {
    const began = Date.now();
    try {
      return await operation();
    } finally {
      timings[stage] = Date.now() - began;
    }
  };

  const reportTimings = (outcome: string) => {
    const parts = Object.entries(timings).map(([stage, ms]) =>
      `${stage}_ms=${ms}`
    );
    console.log(
      `[TutorialGeometryPlanTiming] outcome=${outcome} ${parts.join(" ")} total_ms=${
        Date.now() - requestStartedAt
      }`,
    );
  };

  try {
    console.log("[TutorialGeometryPlan] request_received");
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before planning a tutorial's geometry.",
      );
    }
    userClient = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const client = userClient;
    const { data: authData, error: authError } = await timed(
      "auth",
      () => client.auth.getUser(),
    );
    if (authError || !authData.user) {
      throw new FunctionFailure(
        401,
        "AUTH_FAILED",
        "Your session has expired. Sign in again.",
      );
    }
    console.log("[TutorialGeometryPlan] auth_verified");

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
    const sessionId = requestedSessionId(body);

    // RLS scopes this to the caller's own row -- a session belonging to
    // someone else simply does not come back (matches every other function
    // in this project).
    const { data: session, error: sessionError } = await timed(
      "session_fetch",
      () =>
        client.from("tutorial_sessions").select("*").eq("id", sessionId)
          .maybeSingle(),
    );
    if (sessionError || !session) {
      throw new FunctionFailure(
        404,
        "TUTORIAL_SESSION_NOT_FOUND",
        "This tutorial session could not be found.",
      );
    }
    const sessionRow = session as unknown as Record<string, unknown>;

    // Persist-once-and-reuse (TF-2's core cost/consistency rule): a session
    // that already has a real, validated plan (its geometry_plan_json
    // carries a "steps" array, not just the in-flight claim marker below)
    // is returned as-is. No quota is spent and Gemini is never called again.
    const existingPlan = sessionRow.geometry_plan_json;
    if (
      existingPlan && typeof existingPlan === "object" &&
      Array.isArray((existingPlan as Record<string, unknown>).steps)
    ) {
      console.log("[TutorialGeometryPlan] already_planned=true");
      return jsonResponse(sessionResponse(sessionRow));
    }

    const analysisId = sessionRow.analysis_id as string;
    const sourceMode = sessionRow.source_mode as string;

    const { data: stepRows, error: stepsError } = await timed(
      "steps_fetch",
      () =>
        client.from("tutorial_steps").select(
          "category, instruction_json, personalized_spec_json",
        ).eq("tutorial_session_id", sessionId).neq(
          "category",
          "final_look",
        ).order("step_number", { ascending: true }),
    );
    if (stepsError) {
      throw new FunctionFailure(
        500,
        "STEPS_FETCH_FAILED",
        "This tutorial's steps could not be loaded.",
        true,
      );
    }
    const placementSteps =
      (stepRows ?? []) as unknown as Array<Record<string, unknown>>;
    if (placementSteps.length === 0) {
      throw new FunctionFailure(
        409,
        "NO_PLACEMENT_STEPS",
        "This tutorial has no application steps to plan geometry for.",
      );
    }
    const categories = placementSteps.map(categoryFactsFromStep);
    console.log(
      `[TutorialGeometryPlan] categories_loaded count=${categories.length}`,
    );

    const { data: analysis, error: analysisError } = await timed(
      "analysis_fetch",
      () =>
        client.from("analyses").select(
          "id, original_image_path, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
        ).eq("id", analysisId).maybeSingle(),
    );
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_NOT_FOUND",
        "The original analysis could not be found.",
      );
    }
    const analysisRow = analysis as unknown as Record<string, unknown>;
    const originalImagePath = analysisRow.original_image_path as string;
    if (
      !isOwnedOriginalPath(
        originalImagePath,
        authData.user.id,
        analysisId,
        ["jpg", "jpeg", "png", "webp"],
      )
    ) {
      throw new FunctionFailure(
        403,
        "invalid_original_path",
        "The original image path is invalid.",
      );
    }
    console.log("[TutorialGeometryPlan] source_chain_loaded");

    // Conditional claim -- an application-level lock on top of the row
    // itself, mirroring generate-tutorial-step's claim for the identical
    // reason: a concurrent duplicate request for the same session (e.g. two
    // rapid taps of "Generate my tutorial") must not both call Gemini. Only
    // a session whose geometry_plan_json is still null can be claimed; the
    // marker object passes the same `jsonb_typeof = 'object'` constraint a
    // real plan does, so no schema change beyond geometry_plan_json itself
    // was needed for this.
    const { data: claimed, error: claimError } = await timed(
      "claim_session",
      () =>
        client.from("tutorial_sessions")
          .update({ geometry_plan_json: { planning: true } } as never)
          .eq("id", sessionId)
          .is("geometry_plan_json", null)
          .select("*")
          .maybeSingle(),
    );
    if (claimError) {
      throw new FunctionFailure(
        500,
        "CLAIM_FAILED",
        "This tutorial's geometry could not be claimed for planning.",
        true,
      );
    }
    if (!claimed) {
      const { data: current } = await client.from("tutorial_sessions")
        .select("*").eq("id", sessionId).maybeSingle();
      const currentRow = current as unknown as Record<string, unknown> | null;
      const currentPlan = currentRow?.geometry_plan_json;
      if (
        currentPlan && typeof currentPlan === "object" &&
        Array.isArray((currentPlan as Record<string, unknown>).steps)
      ) {
        return jsonResponse(sessionResponse(currentRow!));
      }
      throw new FunctionFailure(
        409,
        "GEOMETRY_PLANNING_IN_PROGRESS",
        "This tutorial's geometry is already being planned.",
        true,
      );
    }
    claimedSessionId = sessionId;
    console.log("[TutorialGeometryPlan] session_claimed");

    const [selfieDownload, quota] = await Promise.all([
      timed(
        "selfie_download",
        () => client.storage.from("face-images").download(originalImagePath),
      ),
      timed(
        "quota",
        () => consumeAiQuota(client, "tutorial_geometry_plan"),
      ),
    ]);
    const { data: selfieBlob, error: selfieDownloadError } = selfieDownload;
    if (selfieDownloadError || !selfieBlob) {
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_DOWNLOAD_FAILED",
        "The original selfie could not be loaded.",
      );
    }
    if (selfieBlob.size <= 0 || selfieBlob.size > maximumSourceBytes) {
      throw new FunctionFailure(
        422,
        "invalid_source_image",
        "The original selfie cannot be used for geometry planning.",
      );
    }
    const selfieMimeType = selfieBlob.type || "image/jpeg";
    if (
      !["image/jpeg", "image/png", "image/webp"].includes(selfieMimeType)
    ) {
      throw new FunctionFailure(
        422,
        "invalid_source_type",
        "The original selfie's image type is unsupported.",
      );
    }
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
    console.log("[TutorialGeometryPlan] sources_loaded");

    const selfieBytes = new Uint8Array(await selfieBlob.arrayBuffer());
    const model = configuredModel();
    const geminiText = await timed(
      "gemini",
      () =>
        requestGeminiGeometryPlan({
          apiKey: requiredEnvironment("GEMINI_API_KEY"),
          model,
          selfieBytes,
          selfieMimeType,
          selectedStyle: clean(sessionRow.makeup_style),
          sourceMode,
          faceAttributes: tutorialFaceAttributesFromRow(analysisRow),
          categories,
        }),
    );
    console.log("[TutorialGeometryPlan] gemini_response_received");

    const plan = parseAndValidateGeometryPlan(geminiText, {
      requestedCategories: categories,
      sourceMode,
    });
    console.log(
      `[TutorialGeometryPlan] validated=true steps=${plan.steps.length}`,
    );

    const { data: updated, error: updateError } = await timed(
      "db_update",
      () =>
        client.from("tutorial_sessions").update({
          geometry_plan_json: plan,
          geometry_plan_version: TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION,
          geometry_model: model,
        } as never).eq("id", sessionId).select("*").single(),
    );
    if (updateError || !updated) {
      throw new FunctionFailure(
        500,
        "DATABASE_UPDATE_FAILED",
        "The tutorial's geometry plan could not be saved.",
        true,
      );
    }
    claimedSessionId = null;
    console.log("[TutorialGeometryPlan] database_update_success=true");

    console.log(
      `[plan-tutorial-geometry] Completed model=${model} prompt=${TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION} categories=${plan.steps.length}`,
    );
    reportTimings("success");
    return jsonResponse(
      sessionResponse(updated as unknown as Record<string, unknown>),
    );
  } catch (error) {
    if (claimedSessionId && userClient) {
      try {
        // Best-effort revert of the in-flight claim marker back to null so
        // a retry (or a genuinely concurrent request) can claim it again --
        // mirrors generate-tutorial-step reopening a failed step's status
        // for the same reason.
        await userClient.from("tutorial_sessions").update({
          geometry_plan_json: null,
        } as never).eq("id", claimedSessionId);
      } catch {
        // Best-effort only -- the original error below is what matters.
      }
    }
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The tutorial geometry planning request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[plan-tutorial-geometry] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[TutorialGeometryPlan] request_failed code=${failure.code}`);
    reportTimings(failure.code);
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    }, failure.status);
  }
});
