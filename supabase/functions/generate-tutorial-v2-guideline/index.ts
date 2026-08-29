import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { requestGuidelineImage, type SourceImage } from "./gemini_client.ts";
import {
  extensionFor,
  guidelinePath,
  isOwnedGuidelinePath,
  isOwnedSourcePath,
} from "./image_validation.ts";
import { TUTORIAL_V2_GUIDELINE_PROMPT_VERSION } from "./prompt.ts";
import {
  FINAL_LOOK,
  FunctionFailure,
  type ProductSnapshot,
  type StepSpec,
} from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const MINIMUM_PLAN_VERSION = 2;
const bucket = "face-images";

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[tutorial-v2-guideline] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial service is not configured.",
    );
  }
  return value;
}

function requestPayload(
  value: unknown,
): { tutorialSessionId: string; stepIndex: number } {
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
  if (
    typeof input.stepIndex !== "number" || !Number.isInteger(input.stepIndex) ||
    input.stepIndex < 0
  ) {
    throw new FunctionFailure(
      400,
      "invalid_step_index",
      "A valid step index is required.",
    );
  }
  // Deliberately nothing else. Storage paths are derived server-side from the
  // rows this caller provably owns, never accepted from the client.
  return {
    tutorialSessionId: input.tutorialSessionId,
    stepIndex: input.stepIndex,
  };
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

  let claimedStepId: string | null = null;
  let claimedRetryCount = 0;
  let uploadedPath: string | null = null;
  let client;

  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before opening a tutorial.",
      );
    }

    client = createClient(
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
    const userId = authData.user.id;

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

    // --- Session ownership (RLS-scoped, then re-checked) -------------------
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
    if (session.user_id !== userId) {
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
    if (session.status !== "plan_ready") {
      throw new FunctionFailure(
        409,
        "plan_not_ready",
        "This tutorial has no plan yet.",
      );
    }

    const analysisId = session.analysis_id as string;

    // --- Step ownership -----------------------------------------------------
    const { data: step, error: stepError } = await client
      .from("tutorial_v2_steps")
      .select("*")
      .eq("tutorial_v2_session_id", payload.tutorialSessionId)
      .eq("step_index", payload.stepIndex)
      .maybeSingle();
    if (stepError || !step) {
      throw new FunctionFailure(
        404,
        "step_not_found",
        "This tutorial step could not be found.",
      );
    }
    if (step.user_id !== userId) {
      throw new FunctionFailure(
        403,
        "forbidden",
        "This tutorial step does not belong to you.",
      );
    }
    if (step.category === FINAL_LOOK) {
      // The terminal step reuses the canonical preview and teaches no
      // placement, so it has no guideline to generate.
      throw new FunctionFailure(
        409,
        "final_step_has_no_guideline",
        "The final look reuses your existing preview.",
      );
    }

    const spec = step.step_spec_json as StepSpec;
    if (!spec || typeof spec !== "object" || spec.category !== step.category) {
      throw new FunctionFailure(
        409,
        "corrupt_step_spec",
        "This tutorial step could not be read. Start a new tutorial.",
      );
    }

    // --- Claim: exactly one caller generates this asset --------------------
    const { data: claim, error: claimError } = await client.rpc(
      "claim_tutorial_v2_guideline",
      {
        p_session_id: payload.tutorialSessionId,
        p_step_index: payload.stepIndex,
      },
    );
    if (claimError) {
      throw new FunctionFailure(
        500,
        "claim_failed",
        "This tutorial step could not be prepared.",
        true,
      );
    }
    const outcome = (claim as Record<string, unknown>)?.outcome;
    if (outcome === "ready") {
      // Already generated. Reuse rather than spend image quota again.
      console.log("[tutorial-v2-guideline] reused existing asset");
      return jsonResponse({
        guideline: {
          tutorialSessionId: payload.tutorialSessionId,
          stepIndex: payload.stepIndex,
          storagePath: (claim as Record<string, unknown>).path,
          status: "ready",
          reused: true,
        },
      });
    }
    if (outcome === "in_flight") {
      throw new FunctionFailure(
        409,
        "guideline_already_generating",
        "This step is already being prepared.",
      );
    }
    if (outcome !== "claimed") {
      throw new FunctionFailure(
        404,
        "step_not_found",
        "This tutorial step could not be found.",
      );
    }
    claimedStepId = step.id as string;
    claimedRetryCount = typeof step.retry_count === "number"
      ? step.retry_count
      : 0;

    // --- Cumulative context from sibling steps ------------------------------
    const { data: siblings } = await client
      .from("tutorial_v2_steps")
      .select("step_index, category, result_image_path")
      .eq("tutorial_v2_session_id", payload.tutorialSessionId)
      .order("step_index", { ascending: true });

    const ordered = (siblings ?? []) as Array<
      { step_index: number; category: string; result_image_path: string | null }
    >;
    const completedCategories = ordered
      .filter((row) =>
        row.step_index < payload.stepIndex && row.category !== FINAL_LOOK
      )
      .map((row) => row.category);
    const futureCategories = ordered
      .filter((row) =>
        row.step_index > payload.stepIndex && row.category !== FINAL_LOOK
      )
      .map((row) => row.category);

    // --- Source images: identity, base state, canonical target -------------
    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select(
        "id, original_image_path, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
      )
      .eq("id", analysisId)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "analysis_not_found",
        "The face analysis behind this tutorial could not be found.",
      );
    }

    const originalPath = analysis.original_image_path as string;
    const canonicalPath = session.canonical_image_path as string;

    // The previous step's cumulative result is the base state. V2-6 produces
    // those, so until then the original selfie is the base for every step.
    const previousResult = ordered.find(
      (row) => row.step_index === payload.stepIndex - 1,
    )?.result_image_path ?? null;
    const basePath = previousResult ?? originalPath;
    const baseIsOriginalSelfie = basePath === originalPath;

    for (const path of [originalPath, canonicalPath, basePath]) {
      if (!isOwnedSourcePath(path, userId, analysisId)) {
        throw new FunctionFailure(
          409,
          "unsafe_storage_path",
          "This tutorial references an image that is not yours.",
        );
      }
    }

    async function download(path: string): Promise<SourceImage> {
      const { data, error } = await client!.storage.from(bucket).download(path);
      if (error || !data) {
        throw new FunctionFailure(
          404,
          "source_image_unavailable",
          "An image needed for this tutorial step could not be loaded.",
          true,
        );
      }
      return {
        bytes: new Uint8Array(await data.arrayBuffer()),
        mimeType: mimeTypeFor(path),
      };
    }

    const [identity, baseState, canonicalTarget] = await Promise.all([
      download(originalPath),
      baseIsOriginalSelfie ? download(originalPath) : download(basePath),
      download(canonicalPath),
    ]);

    // --- Quota --------------------------------------------------------------
    const quota = await consumeAiQuota(client, "tutorial_v2_guideline");
    if (!quota.allowed) {
      await client
        .from("tutorial_v2_steps")
        .update({ guideline_status: "pending" })
        .eq("id", claimedStepId);
      claimedStepId = null;
      return jsonResponse({
        error: {
          code: quota.reason,
          message: quotaMessage(quota.reason),
          retryable: true,
          retryAfterSeconds: quota.retryAfterSeconds,
        },
      }, 429);
    }

    // --- Generate -----------------------------------------------------------
    const model = Deno.env.get("TUTORIAL_V2_GUIDELINE_MODEL")?.trim() ||
      "gemini-3.1-flash-image";

    const snapshot = step.product_snapshot_json as ProductSnapshot | null;

    const generated = await requestGuidelineImage(
      requiredEnvironment("GEMINI_API_KEY"),
      model,
      {
        spec,
        styleCode: session.makeup_style as string,
        attributes: {
          faceShape: analysis.face_shape,
          skinTone: analysis.skin_tone,
          undertone: analysis.undertone,
          eyeShape: analysis.eye_shape,
          lipShape: analysis.lip_shape,
          hairColor: analysis.hair_color,
          eyeColor: analysis.eye_color,
        },
        product: snapshot ?? null,
        stepNumber: payload.stepIndex + 1,
        totalSteps: session.total_steps as number,
        baseIsOriginalSelfie,
        completedCategories,
        futureCategories,
      },
      { identity, baseState, canonicalTarget },
    );

    // --- Store --------------------------------------------------------------
    const extension = extensionFor(generated.mimeType);
    const targetPath = guidelinePath(
      userId,
      analysisId,
      payload.tutorialSessionId,
      payload.stepIndex,
      extension,
    );
    // Re-validated even though this function built it: a path that is not
    // exactly this user's asset for this step must never be written.
    if (
      !isOwnedGuidelinePath(
        targetPath,
        userId,
        analysisId,
        payload.tutorialSessionId,
        payload.stepIndex,
      ) ||
      targetPath === originalPath || targetPath === canonicalPath ||
      targetPath === basePath || targetPath.includes("/original/")
    ) {
      throw new FunctionFailure(
        500,
        "unsafe_storage_path",
        "A safe guideline path could not be created.",
      );
    }

    const { error: uploadError } = await client.storage
      .from(bucket)
      .upload(targetPath, generated.bytes, {
        contentType: generated.mimeType,
        // The path is deterministic per (session, step), so a retry after a
        // failed attempt must be able to rewrite it rather than accumulating
        // orphaned objects. It can never reach a protected image: the path is
        // validated above and explicitly compared against the original selfie,
        // the canonical preview, and the base state.
        upsert: true,
      });
    if (uploadError) {
      throw new FunctionFailure(
        500,
        "storage_upload_failed",
        "The guideline could not be stored.",
        true,
      );
    }
    uploadedPath = targetPath;

    const { error: updateError } = await client
      .from("tutorial_v2_steps")
      .update({
        guideline_image_path: targetPath,
        guideline_status: "ready",
        guideline_error: null,
        model_name: model,
        prompt_version: TUTORIAL_V2_GUIDELINE_PROMPT_VERSION,
      })
      .eq("id", claimedStepId);
    if (updateError) {
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "The guideline could not be linked to this step.",
        true,
      );
    }
    claimedStepId = null;
    uploadedPath = null;

    console.log(
      `[tutorial-v2-guideline] completed model=${model} prompt=${TUTORIAL_V2_GUIDELINE_PROMPT_VERSION} step=${payload.stepIndex}`,
    );
    return jsonResponse({
      guideline: {
        tutorialSessionId: payload.tutorialSessionId,
        stepIndex: payload.stepIndex,
        storagePath: targetPath,
        status: "ready",
        reused: false,
        model,
        promptVersion: TUTORIAL_V2_GUIDELINE_PROMPT_VERSION,
      },
    });
  } catch (error) {
    const failure = error instanceof FunctionFailure ? error : null;

    // A missing guideline is preferable to a confidently wrong one: record the
    // failure so the step stays retryable and the written instruction remains
    // the user's source of truth. No fallback graphic is ever produced.
    if (claimedStepId && client) {
      try {
        if (uploadedPath) {
          await client.storage.from(bucket).remove([uploadedPath]);
        }
        await client
          .from("tutorial_v2_steps")
          .update({
            guideline_status: "failed",
            guideline_error: failure?.code ?? "unexpected_error",
            retry_count: claimedRetryCount + 1,
          })
          .eq("id", claimedStepId);
      } catch (cleanupError) {
        console.error(
          `[tutorial-v2-guideline] cleanup failed type=${
            (cleanupError as Error)?.constructor?.name ?? "unknown"
          }`,
        );
      }
    }

    if (failure) {
      return jsonResponse({
        error: {
          code: failure.code,
          message: failure.message,
          retryable: failure.retryable,
        },
      }, failure.status);
    }
    console.error(
      `[tutorial-v2-guideline] Unhandled error type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return jsonResponse({
      error: {
        code: "unexpected_error",
        message: "The guideline could not be generated right now.",
        retryable: true,
      },
    }, 500);
  }
});
