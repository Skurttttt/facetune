import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  GUIDELINE_LOCK_TIMEOUT_MS,
  guidelineStoragePath,
  isRenderableCategory,
  MAXIMUM_STEP_ATTEMPTS,
  TUTORIAL_GUIDELINE_MODEL,
  TUTORIAL_GUIDELINE_PROMPT_VERSION,
  TUTORIAL_OUTPUT_RESOLUTION,
} from "../_shared/tutorial_ai_config.ts";
import {
  ResolutionFailure,
  resolveTutorialSource,
  sanitizedResolutionLog,
} from "../_shared/tutorial_source_resolver.ts";
import {
  isUnchanged,
  requestGeminiGuideline,
} from "./gemini_client.ts";
import { categoryGuidance } from "./category_prompts.ts";
import { stepProductPresentation } from "./product_presentation.ts";
import { productNote, tutorialGuidelinePrompt } from "./prompt.ts";
import { FunctionFailure } from "./types.ts";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(
      `[generate-tutorial-step-v4] Missing server environment variable: ${name}`,
    );
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial service is not configured.",
    );
  }
  return value;
}

function extensionFor(mimeType: string): string {
  return mimeType === "image/png"
    ? "png"
    : mimeType === "image/webp"
    ? "webp"
    : "jpg";
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      { error: { code: "method_not_allowed", message: "Use POST." } },
      405,
    );
  }
  let uploadedPath: string | null = null;
  let client: ReturnType<typeof createClient> | null = null;
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in to open this tutorial.",
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
    const input = (typeof body === "object" && body !== null)
      ? body as Record<string, unknown>
      : {};

    // The caller names a session and a category. Nothing else is accepted —
    // not a model, a resolution, a prompt version, an image, or a product.
    const context = await resolveTutorialSource(client, userId, {
      tutorialSessionId: String(input.tutorialSessionId ?? ""),
      category: String(input.category ?? ""),
    });

    // Two independent gates. The set says which categories are enabled; the
     // guidance lookup says which have reviewed wording. A category cannot be
     // rendered unless both agree, so enabling one without writing its guidance
     // fails closed instead of falling back to generic instructions.
    const guidance = isRenderableCategory(context.category)
      ? categoryGuidance(context.category)
      : null;
    if (guidance === null) {
      throw new FunctionFailure(
        409,
        "category_not_available",
        "This tutorial step is not available yet.",
      );
    }

    // Product wording travels in the response for Flutter to render. It is
    // never sent to the image model and never baked into the guideline.
    const presentation = stepProductPresentation({
      sourceMode: context.sourceMode,
      category: context.category,
      standardPlan: context.standardPlan,
      products: context.products,
    });

    // Duplicate-call protection, read before any spending.
    const { data: currentStep } = await client
      .from("tutorial_v4_steps")
      .select(
        "id,status,guideline_storage_path,generation_attempt,model_name," +
          "output_resolution,prompt_version,updated_at",
      )
      .eq("id", context.stepId)
      .maybeSingle();
    const step = (currentStep ?? {}) as Record<string, unknown>;

    // An already-rendered step is returned as-is. Its image was paid for once
    // and must never be regenerated by a reopen or a double tap.
    if (step.status === "ready" && typeof step.guideline_storage_path === "string") {
      console.log(
        `[generate-tutorial-step-v4] Reused step=${context.stepId} category=${context.category}`,
      );
      return jsonResponse({
        step: {
          id: context.stepId,
          category: context.category,
          position: context.position,
          stepCount: context.includedCount,
          status: "ready",
          storagePath: step.guideline_storage_path,
          model: step.model_name,
          outputResolution: step.output_resolution,
          promptVersion: step.prompt_version,
          reused: true,
        },
        products: presentation,
      });
    }

    // A concurrent request holds the step. Client cancellation never proves
    // server cancellation, so the lock expires rather than persisting forever.
    if (step.status === "generating") {
      const startedAt = Date.parse(String(step.updated_at ?? ""));
      const heldFor = Number.isNaN(startedAt) ? Infinity : Date.now() - startedAt;
      if (heldFor < GUIDELINE_LOCK_TIMEOUT_MS) {
        throw new FunctionFailure(
          409,
          "already_generating",
          "This tutorial step is already being prepared.",
          true,
        );
      }
    }

    const attempt =
      (typeof step.generation_attempt === "number" ? step.generation_attempt : 0) +
      1;

    // A hard ceiling on how many times one step may ever be drawn.
    //
    // The status lock stops simultaneous duplicates, and quota bounds the
    // account, but neither stops a determined user tapping "draw again" a
    // hundred times on one step over an afternoon. This does.
    if (attempt > MAXIMUM_STEP_ATTEMPTS) {
      throw new FunctionFailure(
        429,
        "step_attempt_limit",
        "This step has been redrawn too many times.",
      );
    }

    // Claim the step before spending, conditionally on the status we read.
    //
    // The `.eq("status", ...)` is what makes this a compare-and-set rather than
    // a blind write: two requests that both read `pending` cannot both claim,
    // because the second one's predicate no longer matches and it updates zero
    // rows. Without it the read and the write are separate operations with a
    // gap between them, and that gap is a duplicate paid image.
    const { data: claimed, error: claimError } = await client
      .from("tutorial_v4_steps")
      .update({
        status: "generating",
        generation_attempt: attempt,
        failure_code: null,
      } as never)
      .eq("id", context.stepId)
      .eq("status", (step.status as string) ?? "pending")
      .select("id");
    if (claimError) {
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "This tutorial step could not be prepared.",
        true,
      );
    }
    if (!Array.isArray(claimed) || claimed.length === 0) {
      // Another request won the race between our read and our write.
      throw new FunctionFailure(
        409,
        "already_generating",
        "This tutorial step is already being prepared.",
        true,
      );
    }

    const quota = await consumeAiQuota(client, "tutorial_step_generation");
    if (!quota.allowed) {
      await releaseStep(client, context.stepId, "rate_limited");
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }

    console.log(sanitizedResolutionLog(context));
    const startedAt = Date.now();
    const generated = await requestGeminiGuideline(
      requiredEnvironment("GEMINI_API_KEY"),
      TUTORIAL_GUIDELINE_MODEL,
      tutorialGuidelinePrompt({
        category: context.category,
        guidance,
        stepPosition: context.position,
        stepCount: context.includedCount,
        productNote: productNote(context.products),
      }),
      context.originalImage,
      context.canonicalPreview,
    );
    const latencyMs = Date.now() - startedAt;

    // An identical image means nothing was drawn.
    if (isUnchanged(context.originalImage.bytes, generated.bytes)) {
      await releaseStep(client, context.stepId, "unchanged_guideline");
      throw new FunctionFailure(
        502,
        "unchanged_guideline",
        "This tutorial step could not be drawn.",
        true,
      );
    }

    const storagePath = guidelineStoragePath({
      userId,
      analysisId: context.analysisId,
      tutorialSessionId: context.tutorialSessionId,
      category: context.category,
      attempt,
      extension: extensionFor(generated.mimeType),
    });
    // Belt and braces alongside the database check constraint: a guideline can
    // never be written over the original selfie or the canonical preview.
    if (
      storagePath === context.originalImage.path ||
      storagePath === context.canonicalPreview.path ||
      storagePath.includes("/original/") ||
      storagePath.includes("/generated/")
    ) {
      await releaseStep(client, context.stepId, "unsafe_storage_path");
      throw new FunctionFailure(
        500,
        "unsafe_storage_path",
        "This tutorial step could not be saved.",
      );
    }

    const { error: uploadError } = await client.storage
      .from("face-images")
      .upload(storagePath, generated.bytes, {
        contentType: generated.mimeType,
        upsert: false,
      });
    if (uploadError) {
      await releaseStep(client, context.stepId, "storage_upload_failed");
      throw new FunctionFailure(
        502,
        "storage_upload_failed",
        "This tutorial step could not be saved.",
        true,
      );
    }
    uploadedPath = storagePath;

    const { error: persistError } = await client
      .from("tutorial_v4_steps")
      .update({
        status: "ready",
        guideline_storage_path: storagePath,
        model_name: TUTORIAL_GUIDELINE_MODEL,
        output_resolution: TUTORIAL_OUTPUT_RESOLUTION,
        prompt_version: TUTORIAL_GUIDELINE_PROMPT_VERSION,
        latency_ms: latencyMs,
        failure_code: null,
      } as never)
      .eq("id", context.stepId);
    if (persistError) {
      // Storage succeeded but the row did not, so the object would be
      // unreferenced. Remove it rather than leaving private data orphaned.
      await client.storage.from("face-images").remove([storagePath]);
      uploadedPath = null;
      await releaseStep(client, context.stepId, "persistence_failed");
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "This tutorial step could not be saved.",
        true,
      );
    }

    console.log(
      `[generate-tutorial-step-v4] Completed step=${context.stepId} ` +
        `category=${context.category} model=${TUTORIAL_GUIDELINE_MODEL} ` +
        `resolution=${TUTORIAL_OUTPUT_RESOLUTION} attempt=${attempt} latency_ms=${latencyMs}`,
    );
    return jsonResponse({
      step: {
        id: context.stepId,
        category: context.category,
        position: context.position,
        stepCount: context.includedCount,
        status: "ready",
        storagePath,
        model: TUTORIAL_GUIDELINE_MODEL,
        outputResolution: TUTORIAL_OUTPUT_RESOLUTION,
        promptVersion: TUTORIAL_GUIDELINE_PROMPT_VERSION,
        reused: false,
      },
      products: presentation,
    });
  } catch (error) {
    if (uploadedPath && client) {
      await client.storage.from("face-images").remove([uploadedPath]);
    }
    const failure = error instanceof FunctionFailure
      ? error
      : error instanceof ResolutionFailure
      ? new FunctionFailure(
        error.status,
        error.code,
        error.message,
        error.retryable,
      )
      : new FunctionFailure(
        500,
        "server_error",
        "This tutorial step could not be prepared.",
      );
    if (
      !(error instanceof FunctionFailure) &&
      !(error instanceof ResolutionFailure)
    ) {
      console.error(
        `[generate-tutorial-step-v4] Unhandled error type=${
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

/// Returns a claimed step to `failed` so a later retry is possible.
///
/// Never throws: it runs on the failure path, and masking the original error
/// with a bookkeeping error would hide what actually went wrong.
async function releaseStep(
  // deno-lint-ignore no-explicit-any
  client: any,
  stepId: string,
  failureCode: string,
): Promise<void> {
  try {
    await client
      .from("tutorial_v4_steps")
      .update({ status: "failed", failure_code: failureCode })
      .eq("id", stepId);
  } catch (_) {
    console.error(
      `[generate-tutorial-step-v4] Could not release step=${stepId}`,
    );
  }
}
