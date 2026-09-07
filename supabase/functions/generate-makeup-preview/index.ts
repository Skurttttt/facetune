import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  commitAiLook,
  releaseAiLook,
  reserveAiLook,
  usageFailureMessage,
  usageFailureRetryable,
  usageFailureStatus,
} from "../_shared/ai_look_usage.ts";
import {
  FINAL_PREVIEW_MODEL,
  finalPreviewModelConfigurationError,
} from "../_shared/final_preview_model.ts";
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

/**
 * The AI Look operation identity for this request.
 *
 * A client that supplies a stable `operationId` and reuses it across retries
 * gets idempotency: the same operation resolves to one reservation and one
 * charge, however many times the request is repeated. When the field is absent
 * the server mints one, which still bills correctly but cannot recognise a
 * retry as the same operation — the existing app does not send one yet, and
 * SUB-6 is where the client starts to.
 *
 * The shape is constrained to a uuid so a storage path, an email, or any other
 * user content cannot be used as an idempotency key.
 */
function operationId(value: unknown): string {
  const supplied = typeof value === "object" && value !== null
    ? (value as Record<string, unknown>).operationId
    : undefined;
  if (supplied === undefined || supplied === null) {
    return crypto.randomUUID();
  }
  if (typeof supplied !== "string" || !uuidPattern.test(supplied)) {
    throw new FunctionFailure(
      400,
      "invalid_operation_id",
      "A valid operation ID is required.",
    );
  }
  return supplied;
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
  // The AI Look this request holds, once reserved.
  let heldOperationId: string | null = null;
  // Set the instant a usable canonical preview row exists. From that point the
  // reservation must never be released: the user can open the result, so the
  // AI Look is owed. Anything that fails afterwards leaves the reservation
  // standing for reconciliation to commit from the persisted evidence.
  let previewPersisted = false;
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
    const requestedOperationId = operationId(body);
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

    // ---- AI Look reservation -------------------------------------------
    //
    // Placed here for two reasons. It is after ownership is proven, so a
    // request that was never valid cannot burn capacity; and it is before any
    // paid work, so a refusal costs nothing. An exhausted, expired, suspended,
    // or revoked entitlement stops the request here and Gemini is never
    // contacted.
    const reservation = await timed(
      "ai_look_reserve",
      () => reserveAiLook(client, requestedOperationId),
    );

    if (!reservation.ok) {
      // A replay of an operation that already committed is not a failure: the
      // preview it paid for still exists, so return that instead of generating
      // — and charging — a second time. This is what makes a lost response or
      // a client timeout safe to retry.
      if (reservation.errorCode === "USAGE_ALREADY_COMMITTED") {
        const { data: priorUsage } = await timed(
          "prior_usage_fetch",
          () =>
            client
              .from("usage_ledger")
              .select("canonical_generated_image_id")
              .eq("operation_id", requestedOperationId)
              .maybeSingle(),
        );
        const priorPreviewId =
          (priorUsage as Record<string, unknown> | null)
            ?.canonical_generated_image_id;
        if (typeof priorPreviewId === "string") {
          const { data: priorPreview } = await timed(
            "prior_preview_fetch",
            () =>
              client
                .from("generated_images")
                .select("*")
                .eq("id", priorPreviewId)
                .maybeSingle(),
          );
          if (priorPreview) {
            console.log("[Phase10] ai_look_replayed_committed");
            reportTimings("replayed");
            return jsonResponse(
              previewResponse(
                priorPreview as Record<string, unknown>,
                originalImagePath,
              ),
            );
          }
        }
      }
      console.error(
        `[Phase10] ai_look_reserve_denied code=${reservation.errorCode}`,
      );
      throw new FunctionFailure(
        usageFailureStatus(reservation.errorCode),
        reservation.errorCode ?? "TEMPORARY_BACKEND_FAILURE",
        usageFailureMessage(reservation.errorCode),
        usageFailureRetryable(reservation.errorCode),
      );
    }
    heldOperationId = requestedOperationId;
    console.log("[Phase10] ai_look_reserved");

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
    // The canonical final preview is the visual authority the whole tutorial is
    // grounded in, so the model is locked in code rather than selected by
    // environment. Checked before the request, so a misconfigured deployment
    // fails without spending anything.
    const configurationError = finalPreviewModelConfigurationError();
    if (configurationError !== null) {
      throw new FunctionFailure(500, "server_configuration", configurationError);
    }
    const model = FINAL_PREVIEW_MODEL;
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
    // A usable canonical preview now exists and the user can open it, so the
    // AI Look is owed from this line onward and must never be released.
    previewPersisted = true;

    // ---- AI Look commit -------------------------------------------------
    //
    // Deliberately after the row insert rather than after the storage upload:
    // an object with no row is unreachable from History, Saved Looks, Tutorial,
    // and reopen, so it is not a usable result and must not be charged.
    //
    // A commit that cannot be recorded does not fail the request. The preview
    // is real and the user has it; failing here would deny them a result they
    // already own. The reservation is left standing instead, and
    // `reconcile_stale_ai_look_reservations` commits it from the persisted
    // preview — which is exactly the evidence-first case it was built for.
    const commit = await timed(
      "ai_look_commit",
      () =>
        commitAiLook(
          client,
          requestedOperationId,
          "standard",
          (inserted as Record<string, unknown>).id as string,
        ),
    );
    if (commit.ok) {
      console.log("[Phase10] ai_look_committed");
    } else {
      console.error(
        `[Phase10] ai_look_commit_deferred code=${commit.errorCode}`,
      );
    }

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
    // ---- AI Look release ------------------------------------------------
    //
    // This block is the only place that can say a request definitively failed
    // on the server, and it releases only when no usable canonical preview was
    // persisted. If `previewPersisted` is set the reservation is left alone:
    // the user has a result, so the AI Look is owed, and reconciliation will
    // commit it rather than hand back capacity for work that succeeded.
    //
    // Nothing here reacts to a client timeout or a dropped connection. Those
    // never reach this code — the request keeps running server-side — which is
    // precisely why an abandoned request cannot cause a wrong release.
    if (heldOperationId && !previewPersisted && userClient) {
      const released = await releaseAiLook(
        userClient,
        heldOperationId,
        error instanceof FunctionFailure ? error.code : "server_error",
      );
      console.log(
        `[Phase10] ai_look_release ok=${released.ok} code=${released.errorCode}`,
      );
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
