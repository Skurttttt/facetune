import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  commitAiLook,
  releaseAiLook,
  reserveAiLook,
} from "../_shared/ai_look_usage.ts";
import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  recordAiOperationMetric,
  type TelemetryClient,
  usageForMetric,
  type UsageSink,
} from "../_shared/ai_telemetry.ts";
import {
  FINAL_PREVIEW_MODEL,
  finalPreviewModelConfigurationError,
} from "../_shared/final_preview_model.ts";
import type { CanonicalPlan } from "../_shared/kit_makeup_plan.ts";
import { isOwnedOriginalPath } from "../_shared/storage_ownership.ts";
import { requestGeminiKitPlanPreview } from "./gemini_client.ts";
import {
  type AttemptRow,
  type GenerationRow,
  type PlanPreviewPorts,
  type PlanPreviewReply,
  runPlanPreview,
  type SourceImage,
} from "./plan_preview.ts";
import { previewResponse } from "./preview_response.ts";
import { KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION } from "./prompt_v2.ts";
import type { CurrentKitProduct } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { normalizeAndValidateKitPreviewPlan } from "./validation.ts";
import { productBackedCategories } from "../analyze-tutorial-manifest-v4/validation.ts";
import {
  assessReadiness,
  kitManifestSupportingContext,
  manifestPreflightBody,
  readinessFailure,
  readinessModel,
  ReadinessProviderError,
  requestManifestPreflight,
} from "./readiness.ts";
import { geminiValidatorRequest, validateKitCandidate } from "./validator.ts";
import { validatorModel } from "./validator_client.ts";

// deno-lint-ignore no-explicit-any
type Client = SupabaseClient<any, "public", "public", any, any>;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const maximumOriginalBytes = 10 * 1024 * 1024;
const generationColumns =
  "id,operation_id,kit_recommendation_id,status,terminal_outcome,max_attempts,lease_expires_at";
const attemptColumnsSelect =
  "id,attempt_number,status,outcome,reason_code,mismatch_categories,missing_required_categories,preview_storage_path";

export type PlanPreviewRequest = {
  userClient: Client;
  userId: string;
  body: unknown;
  recommendation: Record<string, unknown>;
  plan: CanonicalPlan;
  telemetryClient: TelemetryClient | null;
  telemetryEventId: string;
};

export type HandlerReply = { status: number; body: Record<string, unknown> };

function required(name: string): string {
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

/** The client's operation id. Mandatory on this path: a server-minted id
 * could never be replayed, and replay is how a request survives. */
function operationIdFrom(body: unknown): string {
  const value = typeof body === "object" && body !== null
    ? (body as Record<string, unknown>).operationId
    : undefined;
  if (typeof value !== "string" || !uuidPattern.test(value)) {
    throw new FunctionFailure(
      400,
      "operation_id_required",
      "A valid operation ID is required.",
    );
  }
  return value;
}

/**
 * Serves one invocation of a plan-driven preview request and shapes the reply.
 *
 * Every reply that ends the request carries `operation.state` — `accepted`
 * or `failed` — which is the only signal the client may use to forget its
 * operation id. A retryable failure carries no state, so the client replays.
 */
export async function handlePlanPreview(
  request: PlanPreviewRequest,
): Promise<HandlerReply> {
  let operationId: string | null = null;
  try {
    operationId = operationIdFrom(request.body);
    const configurationError = finalPreviewModelConfigurationError();
    if (configurationError !== null) {
      throw new FunctionFailure(
        500,
        "server_configuration",
        configurationError,
      );
    }
    const { userClient, userId, recommendation, plan } = request;
    const { data: analysis, error: analysisError } = await userClient
      .from("analyses").select("id,original_image_path")
      .eq("id", recommendation.analysis_id as string).maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "source_image_not_found",
        "The original analysis could not be found.",
      );
    }
    const originalImagePath = (analysis as Record<string, unknown>)
      .original_image_path as string;
    if (
      !isOwnedOriginalPath(
        originalImagePath,
        userId,
        (analysis as Record<string, unknown>).id as string,
        ["jpg", "jpeg", "png", "webp"],
      )
    ) {
      throw new FunctionFailure(
        403,
        "invalid_original_path",
        "The original image path is invalid.",
      );
    }
    const serviceClient = createClient(
      required("SUPABASE_URL"),
      required("SUPABASE_SERVICE_ROLE_KEY"),
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    const usageSink: UsageSink = {};
    const ports = supabasePlanPreviewPorts({
      userClient,
      serviceClient,
      userId,
      kitRecommendationId: recommendation.id as string,
      plan,
      planDigest: recommendation.plan_digest as string,
      snapshot: recommendation.product_snapshot_json,
      apiKey: () => required("GEMINI_API_KEY"),
      usageSink,
    });
    const reply = await runPlanPreview({
      operationId,
      kitRecommendationId: recommendation.id as string,
      plan,
      prepare: (isNew) =>
        prepareSource(
          userClient,
          userId,
          recommendation,
          originalImagePath,
          isNew,
        ),
    }, ports);
    await recordReply(request, operationId, reply, usageSink);
    return shapeReply(operationId, reply, originalImagePath);
  } catch (error) {
    if (!(error instanceof FunctionFailure)) throw error;
    return {
      status: error.status,
      body: {
        error: {
          code: error.code,
          message: error.message,
          retryable: error.retryable,
        },
        ...(operationId && !error.retryable
          ? { operation: { id: operationId, state: "failed" } }
          : {}),
      },
    };
  }
}

function shapeReply(
  operationId: string,
  reply: PlanPreviewReply,
  originalImagePath: string,
): HandlerReply {
  switch (reply.kind) {
    case "accepted":
      return {
        status: 200,
        body: {
          ...previewResponse(reply.preview, originalImagePath),
          operation: { id: operationId, state: "accepted" },
        },
      };
    case "in_progress":
      return reply.busy
        ? {
          status: 409,
          body: {
            error: {
              code: "generation_in_progress",
              message: "Your preview is still being prepared.",
              retryable: true,
            },
            operation: {
              id: operationId,
              state: "in_progress",
              retryAfterMs: reply.retryAfterMs,
            },
          },
        }
        : {
          status: 202,
          body: {
            operation: {
              id: operationId,
              state: "in_progress",
              retryAfterMs: reply.retryAfterMs,
            },
          },
        };
    case "failed":
      return {
        status: reply.failure.status,
        body: {
          error: {
            code: reply.failure.code,
            message: reply.failure.message,
            retryable: reply.failure.retryable,
          },
          operation: {
            id: operationId,
            state: "failed",
            outcome: reply.terminalOutcome,
          },
        },
      };
  }
}

async function recordReply(
  request: PlanPreviewRequest,
  operationId: string,
  reply: PlanPreviewReply,
  usageSink: UsageSink,
): Promise<void> {
  if (reply.kind === "in_progress") return;
  await recordAiOperationMetric(
    request.telemetryClient,
    request.telemetryEventId,
    request.userId,
    reply.kind === "accepted"
      ? {
        operationKind: "final_preview",
        outcome: reply.replayed ? "duplicate" : "succeeded",
        sourceMode: "makeup_kit",
        operationId,
        providerName: reply.replayed ? null : "google_gemini",
        modelName: FINAL_PREVIEW_MODEL,
        promptVersion: KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION,
        usage: usageForMetric(usageSink),
        outputImages: reply.replayed ? 0 : 1,
      }
      : {
        operationKind: "final_preview",
        outcome: "failed",
        failureCategory: reply.terminalOutcome,
        sourceMode: "makeup_kit",
        operationId,
        modelName: FINAL_PREVIEW_MODEL,
        promptVersion: KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION,
        usage: usageForMetric(usageSink),
      },
  );
}

/** Proves the look can still be rendered from products the user owns, then
 * loads the original selfie. Quota is taken once, on the request's first
 * invocation, so a multi-invocation request is one rate-limited request. */
async function prepareSource(
  client: Client,
  userId: string,
  recommendation: Record<string, unknown>,
  originalImagePath: string,
  isNew: boolean,
): Promise<SourceImage> {
  const snapshots = recommendation.product_snapshot_json as unknown[];
  const selectedIds = snapshots.map((item) =>
    (item as Record<string, unknown>).productId as string
  );
  const current = await client.from("makeup_kit_products").select(
    "id,user_id,category,product_name,color_hex,color_label,finish,foundation_depth,foundation_undertone",
  ).in("id", selectedIds);
  if (current.error) {
    throw new FunctionFailure(
      503,
      "kit_unavailable",
      "Your makeup kit could not be verified.",
      true,
    );
  }
  normalizeAndValidateKitPreviewPlan(
    recommendation.recommendation_json,
    snapshots,
    (current.data ?? []) as CurrentKitProduct[],
    userId,
  );
  const { data: blob, error } = await client.storage.from("face-images")
    .download(originalImagePath);
  if (error || !blob) {
    throw new FunctionFailure(
      404,
      "source_image_download_failed",
      "The original selfie could not be loaded.",
    );
  }
  const mimeType = blob.type || "image/jpeg";
  if (
    blob.size <= 0 || blob.size > maximumOriginalBytes ||
    !["image/jpeg", "image/png", "image/webp"].includes(mimeType)
  ) {
    throw new FunctionFailure(
      422,
      "invalid_original_image",
      "The original selfie cannot be used for generation.",
    );
  }
  if (isNew) {
    const quota = await consumeAiQuota(client, "kit_makeup_preview");
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
  }
  return { bytes: new Uint8Array(await blob.arrayBuffer()), mimeType };
}

type PortsInput = {
  userClient: Client;
  serviceClient: Client;
  userId: string;
  kitRecommendationId: string;
  plan: CanonicalPlan;
  planDigest: string;
  /** The recommendation's persisted product snapshot. */
  snapshot: unknown;
  apiKey: () => string;
  usageSink: UsageSink;
};

/**
 * The orchestrator's ports over Supabase. Usage and storage act as the caller,
 * exactly as on the v1 path. Generation and attempt state is server-only and
 * written with the service role, so every query here is scoped to the caller's
 * user id explicitly — the service role bypasses RLS.
 */
export function supabasePlanPreviewPorts(input: PortsInput): PlanPreviewPorts {
  const { userClient, serviceClient: service, userId } = input;
  const generations = () => service.from("kit_preview_generations");
  const attempts = () => service.from("kit_preview_attempts");
  const check = (error: { code?: string } | null, what: string) => {
    if (error) {
      throw new Error(`${what} failed code=${error.code ?? "unknown"}`);
    }
  };
  const nowIso = () => new Date().toISOString();

  return {
    now: () => Date.now(),
    reserve: (operationId) => reserveAiLook(userClient, operationId),
    commit: (operationId, previewId) =>
      commitAiLook(userClient, operationId, "makeup_kit", previewId),
    release: (operationId, code) =>
      releaseAiLook(userClient, operationId, code),

    async findGeneration(operationId) {
      const { data, error } = await generations().select(generationColumns)
        .eq("operation_id", operationId).eq("user_id", userId).maybeSingle();
      check(error, "find_generation");
      return data as GenerationRow | null;
    },
    async insertGeneration({ operationId, maxAttempts, leaseExpiresAt }) {
      const { data, error } = await generations().insert({
        user_id: userId,
        operation_id: operationId,
        kit_recommendation_id: input.kitRecommendationId,
        plan_id: input.plan.plan_id,
        plan_digest: input.planDigest,
        max_attempts: maxAttempts,
        lease_expires_at: leaseExpiresAt,
      } as never).select(generationColumns).single();
      if (error?.code === "23505") return null;
      check(error, "insert_generation");
      return data as GenerationRow;
    },
    async takeLease(generationId, untilIso, atIso) {
      const { data, error } = await generations()
        .update({ lease_expires_at: untilIso } as never)
        .eq("id", generationId).eq("user_id", userId)
        .eq("status", "in_progress")
        .or(`lease_expires_at.is.null,lease_expires_at.lt."${atIso}"`)
        .select("id");
      check(error, "take_lease");
      return (data ?? []).length === 1;
    },
    async yieldLease(generationId) {
      const { error } = await generations()
        .update({ lease_expires_at: null } as never)
        .eq("id", generationId).eq("user_id", userId)
        .eq("status", "in_progress");
      check(error, "yield_lease");
    },
    async endGeneration(generationId, terminalOutcome) {
      const { error } = await generations().update({
        status: "failed",
        terminal_outcome: terminalOutcome,
        completed_at: nowIso(),
        lease_expires_at: null,
      } as never).eq("id", generationId).eq("user_id", userId);
      check(error, "end_generation");
    },
    async listAttempts(generationId) {
      const { data, error } = await attempts().select(attemptColumnsSelect)
        .eq("generation_id", generationId).eq("user_id", userId)
        .order("attempt_number", { ascending: true });
      check(error, "list_attempts");
      return (data ?? []) as AttemptRow[];
    },
    async startAttempt({ generationId, attemptNumber, repairCodes }) {
      const { data, error } = await attempts().insert({
        user_id: userId,
        generation_id: generationId,
        attempt_number: attemptNumber,
        preview_prompt_version: KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION,
        model_name: FINAL_PREVIEW_MODEL,
        repair_codes: repairCodes,
      } as never).select("id").single();
      if (error) {
        console.error(
          `[generate-kit-makeup-preview] attempt_refused code=${error.code}`,
        );
        return null;
      }
      return (data as { id: string }).id;
    },
    async markValidating(attemptId, sha256, generationLatencyMs) {
      const { error } = await attempts().update({
        status: "validating",
        candidate_sha256: sha256,
        generation_latency_ms: generationLatencyMs,
      } as never).eq("id", attemptId).eq("user_id", userId);
      check(error, "mark_validating");
    },
    async completeAttempt(attemptId, result, validationLatencyMs) {
      const { error } = await attempts().update({
        ...result,
        status: "completed",
        completed_at: nowIso(),
        validation_latency_ms: validationLatencyMs,
      } as never).eq("id", attemptId).eq("user_id", userId);
      check(error, "complete_attempt");
    },
    async abandonAttempt(attemptId, reasonCode) {
      const { error } = await attempts().update({
        status: "completed",
        outcome: "abandoned",
        reason_code: reasonCode,
        completed_at: nowIso(),
      } as never).eq("id", attemptId).eq("user_id", userId)
        .neq("status", "completed");
      check(error, "abandon_attempt");
    },
    async claimSlot(attemptId, extension) {
      const { data, error } = await service.rpc("pdmk_claim_preview_slot", {
        p_attempt_id: attemptId,
        p_extension: extension,
      });
      check(error, "claim_slot");
      return data as { generationNumber: number; storagePath: string };
    },
    async finalize(attemptId, validatorVersion, evidence) {
      const { data, error } = await service.rpc(
        "pdmk_finalize_accepted_attempt",
        {
          p_attempt_id: attemptId,
          p_validator_version: validatorVersion,
          p_evidence: evidence,
        },
      );
      check(error, "finalize");
      return data as string;
    },
    async findPreview(operationId) {
      const { data, error } = await userClient.from("kit_generated_images")
        .select("*").eq("operation_id", operationId).maybeSingle();
      check(error, "find_preview");
      return data as Record<string, unknown> | null;
    },
    async upload(path, bytes, mimeType) {
      const { error } = await userClient.storage.from("face-images")
        .upload(path, bytes, { contentType: mimeType, upsert: false });
      if (error) throw new Error("upload_failed");
    },
    async remove(path) {
      await userClient.storage.from("face-images").remove([path]);
    },
    generate: (plan, original, variation, repairs, budgetMs) =>
      requestGeminiKitPlanPreview(
        input.apiKey(),
        FINAL_PREVIEW_MODEL,
        original.bytes,
        original.mimeType,
        plan,
        variation,
        repairs,
        budgetMs,
        input.usageSink,
      ),
    validate: (plan, original, candidate, budgetMs) =>
      validateKitCandidate(
        plan,
        original,
        candidate,
        geminiValidatorRequest(input.apiKey(), validatorModel(), budgetMs),
      ),
    async assessReadiness(plan, original, candidate, budgetMs) {
      // Backing comes from the look's immutable snapshot, exactly as the
      // manifest reads it; the live kit is never consulted.
      const backed = productBackedCategories(input.snapshot);
      let text: string;
      try {
        text = await requestManifestPreflight(
          input.apiKey(),
          readinessModel(),
          manifestPreflightBody(
            original,
            candidate,
            kitManifestSupportingContext(backed),
          ),
          budgetMs,
        );
      } catch (error) {
        return readinessFailure(
          error instanceof ReadinessProviderError
            ? error.code
            : "readiness_provider_error",
        );
      }
      return assessReadiness(plan, input.snapshot, text);
    },
    async sha256(bytes) {
      const hash = new Uint8Array(
        await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)),
      );
      return [...hash].map((byte) => byte.toString(16).padStart(2, "0"))
        .join("");
    },
  };
}
