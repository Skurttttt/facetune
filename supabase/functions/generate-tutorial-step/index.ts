import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  isOwnedOriginalPath,
  isOwnedTutorialResultPath,
} from "../_shared/storage_ownership.ts";
import { extensionFor } from "./image_validation.ts";
import { requestGeminiTutorialStep } from "./gemini_client.ts";
import {
  personalizedPromptInput,
  TUTORIAL_STEP_PROMPT_VERSION,
} from "./prompt.ts";
import { FunctionFailure } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumSourceBytes = 10 * 1024 * 1024;
const defaultTutorialImageModel = "gemini-3.1-flash-image";
const defaultTutorialImageSize = 512;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[generate-tutorial-step] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial image service is not configured.",
    );
  }
  return value;
}

/**
 * Model and output size are read from env vars every request rather than
 * baked into this function's code, per the roadmap's strict engineering
 * rule: "the tutorial image-generation model and output resolution must be
 * configurable server-side and must not be tightly coupled to tutorial
 * business logic or UI." Falling back to the guide's V1 defaults
 * (§5.2 — gemini-3.1-flash-image, 512px) only when unset, so the
 * function works out of the box without requiring every deploy to set
 * these explicitly.
 */
function configuredModel(): string {
  return Deno.env.get("TUTORIAL_IMAGE_MODEL")?.trim() ||
    defaultTutorialImageModel;
}

function configuredImageSize(): number {
  const raw = Deno.env.get("TUTORIAL_IMAGE_SIZE")?.trim();
  if (!raw) return defaultTutorialImageSize;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) && parsed > 0
    ? parsed
    : defaultTutorialImageSize;
}

function requestedStepId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid tutorial step request is required.",
    );
  }
  const id = (value as Record<string, unknown>).tutorialStepId;
  if (typeof id !== "string" || !uuidPattern.test(id)) {
    throw new FunctionFailure(
      400,
      "invalid_tutorial_step_id",
      "A valid tutorial step ID is required.",
    );
  }
  return id;
}

/** Title-cases a `category` code (e.g. `lip_gloss` → `Lip Gloss`) for the
 * Gemini prompt — matches `TutorialPlanningEngine._title` on the Flutter
 * side, kept independent since this side never imports Dart code. */
function categoryLabel(code: string): string {
  return code
    .split("_")
    .map((word) => word.length === 0 ? word : word[0].toUpperCase() + word.slice(1))
    .join(" ");
}

function imagesAreIdentical(first: Uint8Array, second: Uint8Array): boolean {
  if (first.length !== second.length) return false;
  return first.every((value, index) => value === second[index]);
}

function stepResponse(row: Record<string, unknown>) {
  return { step: row };
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

  let uploadedPath: string | null = null;
  let userClient: ReturnType<typeof createClient> | null = null;
  let claimedStepId: string | null = null;
  const requestStartedAt = Date.now();
  const timings: Record<string, number> = {};

  // Durations only — never payloads, paths, tokens, or image bytes. Same
  // convention as generate-makeup-preview/index.ts.
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
      `[TutorialStepTiming] outcome=${outcome} ${parts.join(" ")} total_ms=${
        Date.now() - requestStartedAt
      }`,
    );
  };

  try {
    console.log("[TutorialStep] request_received");
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before generating a tutorial step.",
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
    console.log("[TutorialStep] auth_verified");

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
    const stepId = requestedStepId(body);

    // RLS scopes every table read below to the caller's own rows; a
    // step/session belonging to someone else simply does not come back,
    // and is reported as "not found" rather than distinguishing
    // "exists but not yours" from "does not exist" (matches every other
    // Edge Function in this project).
    const { data: step, error: stepError } = await timed(
      "step_fetch",
      () =>
        client.from("tutorial_steps").select("*").eq("id", stepId)
          .maybeSingle(),
    );
    if (stepError || !step) {
      throw new FunctionFailure(
        404,
        "TUTORIAL_STEP_NOT_FOUND",
        "This tutorial step could not be found.",
      );
    }
    const stepRow = step as unknown as Record<string, unknown>;

    // Duplicate-generation guard (roadmap ST-9 task 12): a step that
    // already has a result — whether generated by an earlier successful
    // call here, or pre-filled at planning time by reusing the existing
    // final preview (ST-8) — is returned as-is. No quota is spent and
    // Gemini is never called for work that is already done.
    if (
      typeof stepRow.result_image_path === "string" &&
      stepRow.result_image_path.length > 0
    ) {
      console.log("[TutorialStep] already_has_result=true");
      return jsonResponse(stepResponse(stepRow));
    }

    // Cost-protection hardening (roadmap ST-13): the final "complete look"
    // step is designed to always reuse the existing final preview at
    // planning time (ST-7/ST-8), never to be independently generated —
    // reaching this point with a final_look step means that reuse did not
    // happen (a planning bug, not a normal runtime state), and generating
    // it for real here would be an unintended Gemini call for image
    // content that is supposed to already exist. Fail loudly instead of
    // silently spending quota and a Gemini call on it.
    if (stepRow.category === "final_look") {
      throw new FunctionFailure(
        409,
        "FINAL_LOOK_NOT_GENERATED",
        "The final look step reuses an existing preview and is not " +
          "independently generated. Reopen this tutorial from its source " +
          "look to repair it.",
      );
    }

    const stepNumber = stepRow.step_number as number;
    const tutorialSessionId = stepRow.tutorial_session_id as string;

    const { data: session, error: sessionError } = await timed(
      "session_fetch",
      () =>
        client.from("tutorial_sessions").select("*").eq(
          "id",
          tutorialSessionId,
        ).maybeSingle(),
    );
    if (sessionError || !session) {
      throw new FunctionFailure(
        404,
        "TUTORIAL_SESSION_NOT_FOUND",
        "This tutorial session could not be found.",
      );
    }
    const sessionRow = session as unknown as Record<string, unknown>;
    const analysisId = sessionRow.analysis_id as string;
    const totalSteps = sessionRow.total_steps as number;

    const { data: analysis, error: analysisError } = await timed(
      "analysis_fetch",
      () =>
        client.from("analyses").select(
          "id, original_image_path, face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color",
        ).eq(
          "id",
          analysisId,
        ).maybeSingle(),
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
    console.log("[TutorialStep] source_chain_loaded");

    // CUMULATIVE SOURCE STRATEGY (roadmap ST-9 task 8): step 1 sources
    // from the original selfie only. Step N>1 sources from step N-1's own
    // Result (the cumulative visual state) *and* keeps the original selfie
    // attached as a second, separate identity anchor — see
    // gemini_client.ts / prompt.ts for how both images are used together.
    let cumulativePath = originalImagePath;
    let identityAnchorPath: string | null = null;
    if (stepNumber > 1) {
      const { data: previousStep, error: previousStepError } = await timed(
        "previous_step_fetch",
        () =>
          client.from("tutorial_steps").select("result_image_path").eq(
            "tutorial_session_id",
            tutorialSessionId,
          ).eq("step_number", stepNumber - 1).maybeSingle(),
      );
      if (previousStepError) {
        throw new FunctionFailure(
          503,
          "previous_step_unavailable",
          "The previous tutorial step could not be checked.",
          true,
        );
      }
      const previousResultPath = previousStep
        ? (previousStep as unknown as Record<string, unknown>)
          .result_image_path as string | null
        : null;
      if (!previousResultPath) {
        throw new FunctionFailure(
          409,
          "PREVIOUS_STEP_NOT_READY",
          "Generate the previous tutorial step before this one.",
        );
      }
      if (
        !isOwnedTutorialResultPath(
          previousResultPath,
          authData.user.id,
          analysisId,
          tutorialSessionId,
        )
      ) {
        throw new FunctionFailure(
          403,
          "invalid_previous_result_path",
          "The previous step's image path is invalid.",
        );
      }
      cumulativePath = previousResultPath;
      identityAnchorPath = originalImagePath;
    }

    // Claim the step for generation with a conditional update — an
    // application-level lock on top of the row itself, so a concurrent
    // duplicate request for the same step (e.g. a double tap) cannot start
    // a second Gemini call. Only a step sitting at `not_started` or
    // `failed` (a retry) can be claimed; `generating`/`completed` cannot.
    const { data: claimed, error: claimError } = await timed(
      "claim_step",
      () =>
        client.from("tutorial_steps")
          .update({ generation_status: "generating" } as never)
          .eq("id", stepId)
          .in("generation_status", ["not_started", "failed"])
          .select("*")
          .maybeSingle(),
    );
    if (claimError) {
      throw new FunctionFailure(
        500,
        "CLAIM_FAILED",
        "This tutorial step could not be claimed for generation.",
        true,
      );
    }
    if (!claimed) {
      const { data: current } = await client.from("tutorial_steps").select(
        "*",
      ).eq("id", stepId).maybeSingle();
      const currentRow = current as unknown as Record<string, unknown> | null;
      if (
        currentRow && typeof currentRow.result_image_path === "string" &&
        currentRow.result_image_path.length > 0
      ) {
        return jsonResponse(stepResponse(currentRow));
      }
      throw new FunctionFailure(
        409,
        "GENERATION_IN_PROGRESS",
        "This tutorial step is already being generated.",
        true,
      );
    }
    claimedStepId = stepId;
    console.log("[TutorialStep] step_claimed");

    const [cumulativeDownload, identityAnchorDownload, quota] = await Promise
      .all([
        timed(
          "cumulative_download",
          () => client.storage.from("face-images").download(cumulativePath),
        ),
        identityAnchorPath
          ? timed(
            "identity_anchor_download",
            () =>
              client.storage.from("face-images").download(
                identityAnchorPath!,
              ),
          )
          : Promise.resolve(null),
        timed("quota", () => consumeAiQuota(client, "tutorial_step")),
      ]);

    const { data: cumulativeBlob, error: cumulativeDownloadError } =
      cumulativeDownload;
    if (cumulativeDownloadError || !cumulativeBlob) {
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_DOWNLOAD_FAILED",
        "The tutorial step's reference image could not be loaded.",
      );
    }
    let identityAnchorBlob: Blob | null = null;
    if (identityAnchorDownload) {
      const { data: anchorBlob, error: anchorError } = identityAnchorDownload;
      if (anchorError || !anchorBlob) {
        throw new FunctionFailure(
          404,
          "SOURCE_IMAGE_DOWNLOAD_FAILED",
          "The tutorial's identity reference image could not be loaded.",
        );
      }
      identityAnchorBlob = anchorBlob;
    }
    for (
      const blob of [cumulativeBlob, identityAnchorBlob].filter((value) =>
        value !== null
      )
    ) {
      if (blob!.size <= 0 || blob!.size > maximumSourceBytes) {
        throw new FunctionFailure(
          422,
          "invalid_source_image",
          "A tutorial step reference image cannot be used for generation.",
        );
      }
      const mimeType = blob!.type || "image/jpeg";
      if (!["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
        throw new FunctionFailure(
          422,
          "invalid_source_type",
          "A tutorial step reference image type is unsupported.",
        );
      }
    }
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
    console.log("[TutorialStep] sources_loaded");

    const cumulativeMimeType = cumulativeBlob.type || "image/jpeg";
    const cumulativeBytes = new Uint8Array(
      await cumulativeBlob.arrayBuffer(),
    );
    const identityAnchorBytes = identityAnchorBlob
      ? new Uint8Array(await identityAnchorBlob.arrayBuffer())
      : undefined;
    const identityAnchorMimeType = identityAnchorBlob
      ? (identityAnchorBlob.type || "image/jpeg")
      : undefined;

    const model = configuredModel();
    const imageSize = configuredImageSize();
    const promptInput = personalizedPromptInput({
      selectedStyle: sessionRow.style_code,
      sourceMode: sessionRow.source_mode,
      faceAttributes: analysisRow,
      stepNumber,
      category: categoryLabel(stepRow.category as string),
      instruction: stepRow.instruction_json as Record<string, unknown>,
      personalizedSpec: stepRow.personalized_spec_json as
        | Record<string, unknown>
        | undefined,
    });
    const generated = await timed(
      "gemini",
      () =>
        requestGeminiTutorialStep({
          apiKey: requiredEnvironment("GEMINI_API_KEY"),
          model,
          cumulativeBytes,
          cumulativeMimeType,
          identityAnchorBytes,
          identityAnchorMimeType,
          totalSteps,
          promptInput,
        }),
    );
    const identityCheckStartedAt = Date.now();
    const unchanged = imagesAreIdentical(cumulativeBytes, generated.bytes);
    timings.image_validation = Date.now() - identityCheckStartedAt;
    if (unchanged) {
      throw new FunctionFailure(
        502,
        "unchanged_generated_image",
        "The image service did not apply this tutorial step.",
        true,
      );
    }
    console.log("[TutorialStep] gemini_generation_complete");

    const extension = extensionFor(generated.mimeType);
    const paddedStepNumber = stepNumber.toString().padStart(4, "0");
    const candidatePath =
      `${authData.user.id}/analyses/${analysisId}/tutorials/${tutorialSessionId}/step_${paddedStepNumber}_result.${extension}`;
    if (
      candidatePath === originalImagePath ||
      candidatePath.includes("/original/")
    ) {
      throw new FunctionFailure(
        500,
        "unsafe_storage_path",
        "A safe tutorial step path could not be created.",
      );
    }
    const { error: uploadError } = await timed(
      "storage_upload",
      () =>
        client.storage.from("face-images").upload(
          candidatePath,
          generated.bytes,
          { contentType: generated.mimeType, upsert: false },
        ),
    );
    if (uploadError) {
      throw new FunctionFailure(
        500,
        "STORAGE_UPLOAD_FAILED",
        "The generated tutorial step image could not be stored.",
        true,
      );
    }
    uploadedPath = candidatePath;
    console.log("[TutorialStep] storage_upload_success=true");

    const { data: updated, error: updateError } = await timed(
      "db_update",
      () =>
        client.from("tutorial_steps").update({
          placement_image_path: cumulativePath,
          result_image_path: candidatePath,
          model_name: model,
          image_size: imageSize,
          prompt_version: TUTORIAL_STEP_PROMPT_VERSION,
          generation_status: "completed",
        } as never).eq("id", stepId).select("*").single(),
    );
    if (updateError || !updated) {
      throw new FunctionFailure(
        500,
        "DATABASE_UPDATE_FAILED",
        "The generated tutorial step could not be saved.",
        true,
      );
    }
    uploadedPath = null;
    claimedStepId = null;
    console.log("[TutorialStep] database_update_success=true");

    // Best-effort session status rollup. The step itself is already safely
    // persisted at this point, so a failure here is logged, not thrown —
    // it must not turn a successful step generation into a reported
    // failure.
    try {
      const { data: siblingSteps } = await timed(
        "sibling_steps_fetch",
        () =>
          client.from("tutorial_steps").select("generation_status").eq(
            "tutorial_session_id",
            tutorialSessionId,
          ),
      );
      const statuses = ((siblingSteps ?? []) as unknown as Array<
        Record<string, unknown>
      >).map((row) => row.generation_status);
      const allComplete = statuses.length > 0 &&
        statuses.every((status) => status === "completed");
      await client.from("tutorial_sessions").update({
        generation_status: allComplete ? "completed" : "partially_complete",
      } as never).eq("id", tutorialSessionId);
      console.log(
        `[TutorialStep] session_status_updated all_complete=${allComplete}`,
      );
    } catch (rollupError) {
      console.error(
        `[TutorialStep] session_status_rollup_failed type=${
          (rollupError as Error)?.constructor?.name ?? "unknown"
        }`,
      );
    }

    console.log(
      `[generate-tutorial-step] Completed model=${model} prompt=${TUTORIAL_STEP_PROMPT_VERSION} step=${stepNumber}/${totalSteps}`,
    );
    reportTimings("success");
    return jsonResponse(
      stepResponse(updated as unknown as Record<string, unknown>),
    );
  } catch (error) {
    if (uploadedPath && userClient) {
      await userClient.storage.from("face-images").remove([uploadedPath]);
    }
    if (claimedStepId && userClient) {
      try {
        await userClient.from("tutorial_steps").update({
          generation_status: "failed",
        } as never).eq("id", claimedStepId);
      } catch {
        // Best-effort only — the original error below is what matters.
      }
    }
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The tutorial step request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-tutorial-step] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[TutorialStep] request_failed code=${failure.code}`);
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
