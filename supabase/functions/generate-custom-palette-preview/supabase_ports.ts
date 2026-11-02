import { createClient } from "npm:@supabase/supabase-js@2";

import {
  commitAiLook,
  releaseAiLook,
  reserveAiLook,
} from "../_shared/ai_look_usage.ts";
import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  createTelemetryClient,
  recordAiOperationMetric,
} from "../_shared/ai_telemetry.ts";
import { FINAL_PREVIEW_MODEL } from "../_shared/final_preview_model.ts";
import { createGeminiPreviewPorts } from "./gemini_client.ts";
import {
  ATTEMPT_LEASE_SECONDS,
  type ClaimResult,
  type FinalizeResult,
  FunctionFailure,
  MAX_PREVIEW_ATTEMPTS,
  type PaletteRecommendationRow,
  type PreviewRequestPorts,
  type PreviewRow,
} from "./handler.ts";
import { CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION } from "./prompt.ts";

const BUCKET = "face-images";
const MAXIMUM_ORIGINAL_BYTES = 10 * 1024 * 1024;

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[generate-custom-palette-preview] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The preview service is not configured.",
    );
  }
  return value;
}

function temporary(code: string): FunctionFailure {
  return new FunctionFailure(
    503,
    code,
    "Your preview could not be prepared. Please try again.",
    true,
  );
}

/**
 * The real ports.
 *
 * The caller's client handles reservation, commit, release, reads and storage,
 * because the usage engine and row level security derive the account from its
 * JWT. The service-role client is used only for the attempt and accepted-preview
 * RPCs, with an id the handler took from the verified JWT.
 */
export function createSupabasePorts(
  authorization: string,
): PreviewRequestPorts {
  const userClient = createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  const serverClient = () =>
    createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
  const telemetry = createTelemetryClient();

  return {
    async authenticate() {
      const { data, error } = await userClient.auth.getUser();
      return error || !data.user ? null : data.user.id;
    },
    async loadRecommendation(id) {
      const { data, error } = await userClient
        .from("custom_palette_recommendations")
        .select(
          "id, analysis_id, makeup_style, palette_snapshot_json, recommendation_json",
        )
        .eq("id", id)
        .maybeSingle();
      if (error) throw temporary("lookup_failed");
      if (!data) return null;
      const row = data as Record<string, unknown>;
      return {
        id: row.id as string,
        analysis_id: row.analysis_id as string,
        style: row.makeup_style as string,
        palette_snapshot_json: row.palette_snapshot_json,
        recommendation_json: row.recommendation_json,
      } satisfies PaletteRecommendationRow;
    },
    async loadOriginalPath(analysisId) {
      const { data, error } = await userClient
        .from("analyses")
        .select("original_image_path")
        .eq("id", analysisId)
        .maybeSingle();
      if (error) throw temporary("lookup_failed");
      return (data as { original_image_path?: string } | null)
        ?.original_image_path ?? null;
    },
    async downloadOriginal(path) {
      const { data, error } = await userClient.storage.from(BUCKET)
        .download(path);
      if (error || !data) throw temporary("source_image_unavailable");
      if (data.size <= 0 || data.size > MAXIMUM_ORIGINAL_BYTES) {
        throw new FunctionFailure(
          422,
          "invalid_original_image",
          "The original selfie cannot be used for generation.",
        );
      }
      const mimeType = data.type || "image/jpeg";
      if (!["image/jpeg", "image/png", "image/webp"].includes(mimeType)) {
        throw new FunctionFailure(
          422,
          "invalid_original_type",
          "The original selfie type is unsupported.",
        );
      }
      return { bytes: new Uint8Array(await data.arrayBuffer()), mimeType };
    },
    async findPreviewByOperation(operationId) {
      const { data, error } = await userClient
        .from("custom_palette_generated_images")
        .select("*")
        .eq("operation_id", operationId)
        .maybeSingle();
      if (error) throw temporary("lookup_failed");
      return data as PreviewRow | null;
    },
    reserve: (operationId) => reserveAiLook(userClient, operationId),
    commit: (operationId, previewId) =>
      commitAiLook(userClient, operationId, "custom_color_palette", previewId),
    release: (operationId, code) =>
      releaseAiLook(userClient, operationId, code),
    async consumeQuota() {
      const quota = await consumeAiQuota(userClient, "custom_palette_preview");
      return { allowed: quota.allowed, message: quotaMessage(quota.reason) };
    },
    async claim({ userId, operationId, recommendationId }) {
      const { data, error } = await serverClient().rpc(
        "claim_custom_palette_preview_attempt",
        {
          p_user_id: userId,
          p_operation_id: operationId,
          p_recommendation_id: recommendationId,
          p_max_attempts: MAX_PREVIEW_ATTEMPTS,
          p_lease_seconds: ATTEMPT_LEASE_SECONDS,
          p_prompt_version: CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION,
        },
      );
      if (error || !data) throw temporary("attempt_claim_failed");
      return data as ClaimResult;
    },
    async finishAttempt(args) {
      const { error } = await serverClient().rpc(
        "finish_custom_palette_preview_attempt",
        {
          p_user_id: args.userId,
          p_operation_id: args.operationId,
          p_attempt_number: args.attemptNumber,
          p_status: args.status,
          p_mismatch_category_codes: args.categories,
          p_mismatch_reason_codes: args.reasons,
          p_validator_version: args.validatorVersion,
        },
      );
      if (error) throw temporary("attempt_finish_failed");
    },
    async upload(path, image) {
      const { error } = await userClient.storage.from(BUCKET).upload(
        path,
        image.bytes,
        { contentType: image.mimeType, upsert: false },
      );
      if (error) throw temporary("storage_upload_failed");
    },
    async removeUpload(path) {
      await userClient.storage.from(BUCKET).remove([path]);
    },
    async finalize(args) {
      const { data, error } = await serverClient().rpc(
        "finalize_custom_palette_preview",
        {
          p_user_id: args.userId,
          p_operation_id: args.operationId,
          p_attempt_number: args.attemptNumber,
          p_storage_path: args.storagePath,
          p_model_name: args.model,
          p_prompt_version: args.promptVersion,
          p_validator_version: args.validatorVersion,
        },
      );
      if (error || !data) throw temporary("preview_finalize_failed");
      return data as FinalizeResult;
    },
    provider: (deadlineMs) =>
      createGeminiPreviewPorts(requiredEnvironment("GEMINI_API_KEY"), {
        deadlineMs,
      }),
    async recordMetric(userId, metric) {
      // Best effort. Measurement can never fail the request.
      await recordAiOperationMetric(telemetry, crypto.randomUUID(), userId, {
        operationKind: "final_preview",
        outcome: metric.outcome,
        failureCategory: metric.failureCategory,
        sourceMode: "custom_color_palette",
        operationId: metric.operationId,
        providerName: metric.attempts > 0 ? "google_gemini" : null,
        modelName: metric.model ?? FINAL_PREVIEW_MODEL,
        promptVersion: CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION,
        providerAttemptCount: metric.attempts,
        outputImages: metric.outcome === "succeeded" ? 1 : 0,
      });
    },
    now: () => Date.now(),
  };
}
