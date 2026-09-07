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
import { extensionFor } from "../generate-makeup-preview/image_validation.ts";
import { requestGeminiKitPreview } from "./gemini_client.ts";
import { KIT_MAKEUP_PREVIEW_PROMPT_VERSION } from "./prompt.ts";
import type { CurrentKitProduct } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { normalizeAndValidateKitPreviewPlan } from "./validation.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumOriginalBytes = 10 * 1024 * 1024;
const allowedStyles = new Set([
  "natural",
  "everyday",
  "office",
  "soft_glam",
  "full_glam",
  "bridal",
  "korean",
  "clean_girl",
  "party",
  "date_night",
  "no_makeup_makeup",
  "old_money",
]);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[generate-kit-makeup-preview] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The kit preview service is not configured.",
    );
  }
  return value;
}

function kitRecommendationId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid request is required.",
    );
  }
  const id = (value as Record<string, unknown>).kitRecommendationId;
  if (typeof id !== "string" || !uuidPattern.test(id)) {
    throw new FunctionFailure(
      400,
      "invalid_kit_recommendation_id",
      "A valid kit recommendation ID is required.",
    );
  }
  return id;
}

/**
 * The AI Look operation identity for this request.
 *
 * Same contract as the Standard path: a client that reuses a stable
 * `operationId` across retries gets one reservation and one charge however many
 * times the request repeats. Absent, the server mints one, which bills
 * correctly but cannot recognise a retry. Constrained to a uuid so no storage
 * path or other user content can become an idempotency key.
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
      mode: "makeup_kit",
      analysisId: row.analysis_id,
      kitRecommendationId: row.kit_recommendation_id,
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
  // Set the instant a usable canonical kit preview row exists. From that point
  // the reservation must never be released: the user can open the result, so
  // the AI Look is owed.
  let previewPersisted = false;
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before generating a kit preview.",
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
    const requestedId = kitRecommendationId(body);
    const requestedOperationId = operationId(body);
    const { data: recommendation, error: recommendationError } = await client
      .from("kit_makeup_recommendations")
      .select(
        "id,analysis_id,makeup_style,recommendation_json,product_snapshot_json",
      )
      .eq("id", requestedId)
      .maybeSingle();
    if (recommendationError || !recommendation) {
      throw new FunctionFailure(
        404,
        "kit_recommendation_not_found",
        "The kit-based makeup plan is no longer available.",
      );
    }
    const recommendationRow = recommendation as unknown as Record<
      string,
      unknown
    >;
    if (
      typeof recommendationRow.analysis_id !== "string" ||
      !uuidPattern.test(recommendationRow.analysis_id) ||
      typeof recommendationRow.makeup_style !== "string" ||
      !allowedStyles.has(recommendationRow.makeup_style)
    ) {
      throw new FunctionFailure(
        422,
        "invalid_kit_plan",
        "The saved kit-based makeup plan is invalid.",
      );
    }
    const snapshots = recommendationRow.product_snapshot_json;
    const selectedIds = Array.isArray(snapshots)
      ? snapshots.map((item) =>
        typeof item === "object" && item !== null &&
          typeof (item as Record<string, unknown>).productId === "string"
          ? (item as Record<string, string>).productId
          : ""
      ).filter((id) => uuidPattern.test(id))
      : [];
    if (selectedIds.length === 0) {
      throw new FunctionFailure(
        422,
        "invalid_kit_plan",
        "The saved kit-based makeup plan is invalid.",
      );
    }
    const [{ data: analysis, error: analysisError }, currentProducts] =
      await Promise.all([
        client.from("analyses").select("id,original_image_path")
          .eq("id", recommendationRow.analysis_id as string).maybeSingle(),
        client.from("makeup_kit_products").select(
          "id,user_id,category,product_name,color_hex,color_label,finish,foundation_depth,foundation_undertone",
        ).in("id", selectedIds),
      ]);
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "source_image_not_found",
        "The original analysis could not be found.",
      );
    }
    const analysisRow = analysis as unknown as Record<string, unknown>;
    if (currentProducts.error) {
      throw new FunctionFailure(
        503,
        "kit_unavailable",
        "Your makeup kit could not be verified.",
        true,
      );
    }
    const plan = normalizeAndValidateKitPreviewPlan(
      recommendationRow.recommendation_json,
      snapshots,
      (currentProducts.data ?? []) as CurrentKitProduct[],
      authData.user.id,
    );
    const originalImagePath = analysisRow.original_image_path as string;
    if (
      !isOwnedOriginalPath(
        originalImagePath,
        authData.user.id,
        analysisRow.id as string,
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
    // After ownership and the owned-product plan are proven, and before any
    // paid work. The Kit path is wrapped identically to Standard Mode: gating
    // only one of the two would leave the other as a free channel.
    const reservation = await reserveAiLook(client, requestedOperationId);

    if (!reservation.ok) {
      // A replay of an operation that already committed returns the preview it
      // paid for rather than generating and charging a second time.
      if (reservation.errorCode === "USAGE_ALREADY_COMMITTED") {
        const { data: priorUsage } = await client
          .from("usage_ledger")
          .select("canonical_kit_generated_image_id")
          .eq("operation_id", requestedOperationId)
          .maybeSingle();
        const priorPreviewId =
          (priorUsage as Record<string, unknown> | null)
            ?.canonical_kit_generated_image_id;
        if (typeof priorPreviewId === "string") {
          const { data: priorPreview } = await client
            .from("kit_generated_images")
            .select("*")
            .eq("id", priorPreviewId)
            .maybeSingle();
          if (priorPreview) {
            return jsonResponse(
              previewResponse(
                priorPreview as unknown as Record<string, unknown>,
                originalImagePath,
              ),
            );
          }
        }
      }
      console.error(
        `[generate-kit-makeup-preview] ai_look_reserve_denied code=${reservation.errorCode}`,
      );
      throw new FunctionFailure(
        usageFailureStatus(reservation.errorCode),
        reservation.errorCode ?? "TEMPORARY_BACKEND_FAILURE",
        usageFailureMessage(reservation.errorCode),
        usageFailureRetryable(reservation.errorCode),
      );
    }
    heldOperationId = requestedOperationId;

    const [download, latestGeneration, quota] = await Promise.all([
      client.storage.from("face-images").download(originalImagePath),
      client.from("kit_generated_images").select("generation_number")
        .eq("kit_recommendation_id", requestedId)
        .order("generation_number", { ascending: false }).limit(1)
        .maybeSingle(),
      consumeAiQuota(client, "kit_makeup_preview"),
    ]);
    const { data: originalBlob, error: downloadError } = download;
    if (downloadError || !originalBlob) {
      throw new FunctionFailure(
        404,
        "source_image_download_failed",
        "The original selfie could not be loaded.",
      );
    }
    if (latestGeneration.error) {
      throw new FunctionFailure(
        503,
        "preview_history_unavailable",
        "The kit preview history could not be checked.",
        true,
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
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
    const generationNumber =
      (((latestGeneration.data as unknown as Record<string, unknown> | null)
        ?.generation_number as number | undefined) ?? 0) +
      1;
    const originalBytes = new Uint8Array(await originalBlob.arrayBuffer());
    // Same canonical model as the Standard Mode preview, resolved through the
    // same shared lock. Both modes must feed one final-preview architecture, so
    // a divergence here would make the two previews incomparable as tutorial
    // authority — which is exactly why neither reads the environment directly
    // any more.
    const configurationError = finalPreviewModelConfigurationError();
    if (configurationError !== null) {
      throw new FunctionFailure(500, "server_configuration", configurationError);
    }
    const model = FINAL_PREVIEW_MODEL;
    const generated = await requestGeminiKitPreview(
      requiredEnvironment("GEMINI_API_KEY"),
      model,
      originalBytes,
      originalMimeType,
      recommendationRow.makeup_style as string,
      plan,
      generationNumber,
    );
    if (imagesAreIdentical(originalBytes, generated.bytes)) {
      throw new FunctionFailure(
        502,
        "unchanged_generated_image",
        "The image service did not apply the kit plan.",
        true,
      );
    }
    const extension = extensionFor(generated.mimeType);
    const candidatePath =
      `${authData.user.id}/analyses/${analysisRow.id}/kit-generated/${requestedId}/preview_${
        generationNumber.toString().padStart(4, "0")
      }.${extension}`;
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
    const { error: uploadError } = await client.storage.from("face-images")
      .upload(candidatePath, generated.bytes, {
        contentType: generated.mimeType,
        upsert: false,
      });
    if (uploadError) {
      throw new FunctionFailure(
        500,
        "storage_upload_failed",
        "The generated preview could not be stored.",
        true,
      );
    }
    uploadedPath = candidatePath;
    const { data: inserted, error: insertError } = await client
      .from("kit_generated_images").insert({
        user_id: authData.user.id,
        analysis_id: analysisRow.id,
        kit_recommendation_id: requestedId,
        storage_path: candidatePath,
        generation_number: generationNumber,
        model_name: model,
        prompt_version: KIT_MAKEUP_PREVIEW_PROMPT_VERSION,
      } as never).select("*").single();
    if (insertError || !inserted) {
      throw new FunctionFailure(
        500,
        "database_insert_failed",
        "The generated preview could not be linked.",
        true,
      );
    }
    uploadedPath = null;
    // A usable canonical kit preview now exists, so the AI Look is owed from
    // this line onward and must never be released.
    previewPersisted = true;

    // ---- AI Look commit -------------------------------------------------
    //
    // After the row insert, for the same reason as Standard Mode: a stored
    // object with no row is unreachable and is not a usable result. A commit
    // that cannot be recorded does not fail the request — the user has their
    // preview — and reconciliation commits it from the persisted evidence.
    const commit = await commitAiLook(
      client,
      requestedOperationId,
      "makeup_kit",
      (inserted as unknown as Record<string, unknown>).id as string,
    );
    if (!commit.ok) {
      console.error(
        `[generate-kit-makeup-preview] ai_look_commit_deferred code=${commit.errorCode}`,
      );
    }

    console.log(
      `[generate-kit-makeup-preview] Completed model=${model} prompt=${KIT_MAKEUP_PREVIEW_PROMPT_VERSION} variation=${generationNumber}`,
    );
    return jsonResponse(previewResponse(inserted, originalImagePath));
  } catch (error) {
    if (uploadedPath && userClient) {
      await userClient.storage.from("face-images").remove([uploadedPath]);
    }
    // ---- AI Look release ------------------------------------------------
    //
    // Releases only when no usable canonical preview was persisted. A client
    // timeout never reaches here, so an abandoned request cannot cause a wrong
    // release; anything left reserved is resolved by reconciliation.
    if (heldOperationId && !previewPersisted && userClient) {
      const released = await releaseAiLook(
        userClient,
        heldOperationId,
        error instanceof FunctionFailure ? error.code : "server_error",
      );
      console.log(
        `[generate-kit-makeup-preview] ai_look_release ok=${released.ok}`,
      );
    }
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The kit preview request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[generate-kit-makeup-preview] Unhandled error type=${
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
