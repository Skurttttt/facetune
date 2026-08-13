import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { isOwnedOriginalPath } from "../_shared/storage_ownership.ts";
import { extensionFor } from "./image_validation.ts";
import { requestGeminiPreview } from "./gemini_client.ts";
import { MAKEUP_PREVIEW_PROMPT_VERSION } from "./prompt.ts";
import { FunctionFailure } from "./types.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumOriginalBytes = 10 * 1024 * 1024;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[generate-makeup-preview] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The image service is not configured.",
    );
  }
  return value;
}

function recommendationId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid preview request is required.",
    );
  }
  const id = (value as Record<string, unknown>).recommendationId;
  if (typeof id !== "string" || !uuidPattern.test(id)) {
    throw new FunctionFailure(
      400,
      "invalid_recommendation_id",
      "A valid recommendation ID is required.",
    );
  }
  return id;
}

function previewResponse(
  row: Record<string, unknown>,
  originalImagePath: string,
) {
  return {
    preview: {
      id: row.id,
      analysisId: row.analysis_id,
      recommendationId: row.recommendation_id,
      originalImagePath,
      generatedImagePath: row.storage_path,
      generationNumber: row.generation_number,
      modelId: row.model_name,
      promptVersion: row.prompt_version,
      createdAt: row.created_at,
    },
  };
}

function imagesAreIdentical(first: Uint8Array, second: Uint8Array): boolean {
  if (first.length !== second.length) return false;
  return first.every((value, index) => value === second[index]);
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
  const requestStartedAt = Date.now();
  const timings: Record<string, number> = {};

  // Records how long a stage took. Durations only — never payloads, paths,
  // tokens, or image bytes. PostgREST query builders are thenable rather than
  // real Promises, so the callback is typed as PromiseLike to keep result
  // inference working.
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
      `[Phase10Timing] outcome=${outcome} ${parts.join(" ")} total_ms=${
        Date.now() - requestStartedAt
      }`,
    );
  };

  try {
    console.log("[Phase10] request_received");
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before generating a preview.",
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
    console.log("[Phase10] auth_verified");
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
    const requestedRecommendationId = recommendationId(body);
    // These two reads stay sequential: the analysis id is only known after the
    // recommendation row is read. Collapsing them into one embedded PostgREST
    // query would save a round trip but relies on the composite ownership
    // foreign key resolving as an embed, which cannot be verified without a
    // live database. Left explicit so ownership stays readable.
    const { data: recommendation, error: recommendationError } = await timed(
      "recommendation_fetch",
      () =>
        client
          .from("recommendations")
          .select("id, analysis_id, makeup_style, recommendation_json")
          .eq("id", requestedRecommendationId)
          .maybeSingle(),
    );
    if (recommendationError || !recommendation) {
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_NOT_FOUND",
        "The recommendation could not be linked to a source image.",
      );
    }
    console.log("[Phase10] recommendation_loaded");
    const { data: analysis, error: analysisError } = await timed(
      "analysis_fetch",
      () =>
        client
          .from("analyses")
          .select("id, original_image_path")
          .eq("id", recommendation.analysis_id)
          .maybeSingle(),
    );
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_NOT_FOUND",
        "The original analysis could not be found.",
      );
    }
    console.log("[Phase10] analysis_loaded");
    const originalImagePath = analysis.original_image_path as string;
    if (
      !isOwnedOriginalPath(
        originalImagePath,
        authData.user.id,
        analysis.id as string,
        ["jpg", "jpeg", "png", "webp"],
      )
    ) {
      throw new FunctionFailure(
        403,
        "invalid_original_path",
        "The original image path is invalid.",
      );
    }
    // The source download, the generation-number lookup, and the quota check are
    // mutually independent once ownership is proven, so they run concurrently
    // rather than as three serial round trips. Every one of them is awaited and
    // evaluated below before any paid Gemini call is issued.
    //
    // Trade-off: quota is now consumed alongside the download instead of after
    // it, so a request that fails source validation can still spend one unit.
    // Those failures are rare — the original was already validated at upload —
    // and the saved latency applies to every successful generation.
    const [download, latestGeneration, quota] = await Promise.all([
      timed(
        "image_download",
        () => client.storage.from("face-images").download(originalImagePath),
      ),
      timed("generation_number", () =>
        client
          .from("generated_images")
          .select("generation_number")
          .eq("recommendation_id", requestedRecommendationId)
          .order("generation_number", { ascending: false })
          .limit(1)
          .maybeSingle()),
      timed("quota", () => consumeAiQuota(client, "makeup_preview")),
    ]);

    const { data: originalBlob, error: downloadError } = download;
    if (downloadError || !originalBlob) {
      console.error(
        `[Phase10] source_image_download_failed code=${
          downloadError?.statusCode ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        404,
        "SOURCE_IMAGE_DOWNLOAD_FAILED",
        "The original selfie could not be loaded.",
      );
    }
    if (originalBlob.size <= 0 || originalBlob.size > maximumOriginalBytes) {
      throw new FunctionFailure(
        422,
        "invalid_original_image",
        "The original selfie cannot be used for generation.",
      );
    }
    const originalMimeType = originalBlob.type || "image/jpeg";
    if (!["image/jpeg", "image/png", "image/webp"].includes(originalMimeType)) {
      throw new FunctionFailure(
        422,
        "invalid_original_type",
        "The original selfie type is unsupported.",
      );
    }
    console.log(
      `[Phase10] source_image_loaded mime=${originalMimeType} bytes=${originalBlob.size}`,
    );

    const generationNumber =
      ((latestGeneration.data?.generation_number as number | undefined) ?? 0) +
      1;

    // Image generation is the most expensive AI call in the app, so an
    // exhausted quota must stop the request before Gemini is contacted.
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }

    const originalBytes = new Uint8Array(await originalBlob.arrayBuffer());
    const model = Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() ||
      "gemini-3.1-flash-image";
    const generated = await timed("gemini", () =>
      requestGeminiPreview(
        requiredEnvironment("GEMINI_API_KEY"),
        model,
        originalBytes,
        originalMimeType,
        recommendation.makeup_style as string,
        recommendation.recommendation_json as Record<string, unknown>,
        generationNumber,
      ));
    const identityCheckStartedAt = Date.now();
    const unchanged = imagesAreIdentical(originalBytes, generated.bytes);
    timings.image_validation = Date.now() - identityCheckStartedAt;
    if (unchanged) {
      throw new FunctionFailure(
        502,
        "unchanged_generated_image",
        "The image service did not apply the makeup plan.",
        true,
      );
    }
    const extension = extensionFor(generated.mimeType);
    const paddedNumber = generationNumber.toString().padStart(4, "0");
    const candidatePath =
      `${authData.user.id}/analyses/${analysis.id}/generated/${requestedRecommendationId}/preview_${paddedNumber}.${extension}`;
    if (
      candidatePath === originalImagePath ||
      candidatePath.includes("/original/")
    ) {
      throw new FunctionFailure(
        500,
        "unsafe_storage_path",
        "A safe preview path could not be created.",
      );
    }
    const { error: uploadError } = await timed(
      "storage_upload",
      () =>
        client.storage
          .from("face-images")
          .upload(candidatePath, generated.bytes, {
            contentType: generated.mimeType,
            upsert: false,
          }),
    );
    if (uploadError) {
      console.error(
        `[Phase10] storage_upload_success=false code=${
          uploadError.statusCode ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        500,
        "STORAGE_UPLOAD_FAILED",
        "The generated preview could not be stored.",
        true,
      );
    }
    console.log("[Phase10] storage_upload_success=true");
    uploadedPath = candidatePath;
    const { data: inserted, error: insertError } = await timed(
      "db_insert",
      () =>
        client
          .from("generated_images")
          .insert({
            user_id: authData.user.id,
            analysis_id: analysis.id,
            recommendation_id: requestedRecommendationId,
            storage_path: candidatePath,
            generation_number: generationNumber,
            model_name: model,
            prompt_version: MAKEUP_PREVIEW_PROMPT_VERSION,
          } as never)
          .select("*")
          .single(),
    );
    if (insertError || !inserted) {
      console.error(
        `[generate-makeup-preview] Persistence failed code=${
          insertError?.code ?? "unknown"
        }`,
      );
      console.error("[Phase10] database_insert_success=false");
      throw new FunctionFailure(
        500,
        "DATABASE_INSERT_FAILED",
        "The generated preview could not be linked.",
        true,
      );
    }
    console.log("[Phase10] database_insert_success=true");
    uploadedPath = null;
    console.log(
      `[generate-makeup-preview] Completed model=${model} prompt=${MAKEUP_PREVIEW_PROMPT_VERSION} variation=${generationNumber}`,
    );
    console.log("[Phase10] response_returned");
    reportTimings("success");
    return jsonResponse(previewResponse(inserted, originalImagePath));
  } catch (error) {
    if (uploadedPath && userClient) {
      await userClient.storage.from("face-images").remove([uploadedPath]);
    }
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The preview request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-makeup-preview] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[Phase10] request_failed code=${failure.code}`);
    // Timing on the failure path is what makes a slow-failure diagnosable.
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
