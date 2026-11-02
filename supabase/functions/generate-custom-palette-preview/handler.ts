import {
  isOwnedGeneratedPreviewPath,
  isOwnedOriginalPath,
} from "../_shared/storage_ownership.ts";
import type { MetricOutcome } from "../_shared/ai_telemetry.ts";
import type { UsageResult } from "../_shared/ai_look_usage.ts";
import {
  usageFailureMessage,
  usageFailureRetryable,
  usageFailureStatus,
} from "../_shared/ai_look_usage.ts";
import { extensionFor } from "../generate-makeup-preview/image_validation.ts";
import type { GeneratedImage } from "../generate-makeup-preview/types.ts";
import {
  assertFrozenSource,
  type FrozenPaletteSource,
  InvalidFrozenPalette,
  type PreviewImage,
  type PreviewPorts,
  runPreviewCandidate,
} from "./pipeline.ts";
import type { PreviewVerdict } from "./validator.ts";
import { CUSTOM_PALETTE_VALIDATOR_VERSION } from "./validator_prompt.ts";

/**
 * The approved Final Preview bound: two attempts inside a 135 second budget, the
 * same as the Standard and My Makeup Kit paths. Each attempt here is one image
 * call and one validation, with no hidden retry beneath it.
 */
export const MAX_PREVIEW_ATTEMPTS = 2;
export const INVOCATION_BUDGET_MS = 135000;

/** Below this, a second attempt waits for the client's replay instead. */
export const MINIMUM_ATTEMPT_MS = 60000;

/** Longer than an invocation, so a live worker's attempt is never taken over. */
export const ATTEMPT_LEASE_SECONDS = 180;

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
    readonly details: Record<string, unknown> = {},
  ) {
    super(message);
    this.name = "FunctionFailure";
  }
}

export interface PaletteRecommendationRow extends FrozenPaletteSource {
  id: string;
  analysis_id: string;
}

export interface PreviewRow {
  id: string;
  analysis_id: string;
  custom_palette_recommendation_id: string;
  storage_path: string;
  generation_number: number;
  accepted_attempt_number: number;
  model_name: string;
  prompt_version: string;
  validator_version: string;
  created_at: string;
}

export type ClaimResult =
  | {
    status: "claimed";
    attemptNumber: number;
    generationNumber: number;
    previousReasons: string[];
  }
  | { status: "accepted"; previewId: string }
  | { status: "in_progress" }
  | { status: "not_found" }
  | { status: "conflict" }
  | { status: "terminal"; lastStatus: string; mismatchCategories: string[] }
  | { status: "exhausted"; lastStatus: string; mismatchCategories: string[] };

export type FinalizeResult =
  | { ok: true; replayed: boolean; preview: PreviewRow }
  | { ok: false; status: "stale" | "no_reservation" };

export interface OperationMetric {
  outcome: MetricOutcome;
  failureCategory: string | null;
  operationId: string;
  attempts: number;
  model: string | null;
}

/**
 * Everything the orchestration needs from the outside world.
 *
 * Reservation, commit, release, reads and storage run as the caller, so the JWT
 * and row level security scope them. Attempts and the accepted row go through
 * the service role, which is what stops a client forging an accepted preview.
 */
export interface PreviewRequestPorts {
  authenticate(authorization: string): Promise<string | null>;
  loadRecommendation(id: string): Promise<PaletteRecommendationRow | null>;
  loadOriginalPath(analysisId: string): Promise<string | null>;
  downloadOriginal(path: string): Promise<PreviewImage>;
  findPreviewByOperation(operationId: string): Promise<PreviewRow | null>;
  reserve(operationId: string): Promise<UsageResult>;
  commit(operationId: string, previewId: string): Promise<UsageResult>;
  release(operationId: string, code: string): Promise<UsageResult>;
  consumeQuota(): Promise<{ allowed: boolean; message: string }>;
  claim(args: {
    userId: string;
    operationId: string;
    recommendationId: string;
  }): Promise<ClaimResult>;
  finishAttempt(args: {
    userId: string;
    operationId: string;
    attemptNumber: number;
    status: string;
    categories: string[];
    reasons: string[];
    validatorVersion: string | null;
  }): Promise<void>;
  upload(path: string, image: PreviewImage): Promise<void>;
  removeUpload(path: string): Promise<void>;
  finalize(args: {
    userId: string;
    operationId: string;
    attemptNumber: number;
    storagePath: string;
    model: string;
    promptVersion: string;
    validatorVersion: string;
  }): Promise<FinalizeResult>;
  /** Provider ports whose calls cannot outlive [deadlineMs]. */
  provider(deadlineMs: number): PreviewPorts;
  recordMetric(userId: string, metric: OperationMetric): Promise<void>;
  now(): number;
}

function parseBody(
  value: unknown,
): { recommendationId: string; operationId: string } {
  const input = typeof value === "object" && value !== null &&
      !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
  const allowed = new Set(["customPaletteRecommendationId", "operationId"]);
  if (!input || Object.keys(input).some((key) => !allowed.has(key))) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid request is required.",
    );
  }
  const recommendationId = input.customPaletteRecommendationId;
  if (
    typeof recommendationId !== "string" || !uuidPattern.test(recommendationId)
  ) {
    throw new FunctionFailure(
      400,
      "invalid_recommendation_id",
      "A valid recommendation is required.",
    );
  }
  // Required here, unlike the older preview paths. A server-generated id would
  // make every retry a new request and a new charge.
  const operationId = input.operationId;
  if (typeof operationId !== "string" || !uuidPattern.test(operationId)) {
    throw new FunctionFailure(
      400,
      "invalid_operation_id",
      "A valid operation ID is required.",
    );
  }
  return { recommendationId, operationId };
}

function responseBody(preview: PreviewRow, originalImagePath: string) {
  return {
    preview: {
      id: preview.id,
      mode: "custom_color_palette",
      analysisId: preview.analysis_id,
      customPaletteRecommendationId: preview.custom_palette_recommendation_id,
      originalImagePath,
      generatedImagePath: preview.storage_path,
      generationNumber: preview.generation_number,
      modelId: preview.model_name,
      promptVersion: preview.prompt_version,
      createdAt: preview.created_at,
    },
  };
}

/** `category:reason` codes, so a later attempt can tighten its instructions. */
export function reasonCodes(verdict: PreviewVerdict): string[] {
  return [
    ...verdict.color_mismatch_reasons.map((r) => `${r.category}:${r.reason}`),
    ...verdict.finish_mismatch_reasons.map((r) => `${r.category}:${r.reason}`),
    ...verdict.uncertain_categories.map((c) => `${c}:uncertain`),
    ...verdict.introduced_categories.map((c) => `${c}:introduced`),
    ...(verdict.identity === "changed" ? ["identity:changed"] : []),
  ];
}

function inProgress(operationId: string): FunctionFailure {
  return new FunctionFailure(
    409,
    "preview_in_progress",
    "Your preview is still being created.",
    true,
    { operationId },
  );
}

/**
 * Runs one logical preview request: one reservation, at most
 * [MAX_PREVIEW_ATTEMPTS] attempts, at most one accepted preview, one charge.
 *
 * Every attempt reads the same frozen palette row, so a retry has nothing it
 * could change. A failed candidate is never uploaded. Capacity is returned only
 * when the request has definitively ended without a preview. While attempts
 * remain the reservation stands, so the client can replay the same operation id
 * and either continue or collect the result, and an abandoned request is
 * resolved by reconciliation.
 */
export async function createPreview(
  request: Request,
  ports: PreviewRequestPorts,
): Promise<{ status: number; body: unknown }> {
  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    throw new FunctionFailure(
      401,
      "authentication_required",
      "Sign in before generating a preview.",
    );
  }
  const userId = await ports.authenticate(authorization);
  if (!userId) {
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
  const { recommendationId, operationId } = parseBody(body);

  // Ownership first, so a request that was never valid cannot burn capacity.
  const source = await ports.loadRecommendation(recommendationId);
  if (!source) {
    throw new FunctionFailure(
      404,
      "recommendation_not_found",
      "This look could not be found.",
    );
  }
  const originalPath = await ports.loadOriginalPath(source.analysis_id);
  if (!originalPath) {
    throw new FunctionFailure(
      404,
      "source_image_not_found",
      "The original analysis could not be found.",
    );
  }
  if (
    !isOwnedOriginalPath(
      originalPath,
      userId,
      source.analysis_id,
      ["jpg", "jpeg", "png", "webp"],
    )
  ) {
    throw new FunctionFailure(
      403,
      "invalid_original_path",
      "The original image path is invalid.",
    );
  }

  const startedAt = ports.now();
  let attemptsRun = 0;
  let model: string | null = null;
  const report = async (
    outcome: MetricOutcome,
    failureCategory: string | null,
  ) => {
    await ports.recordMetric(userId, {
      outcome,
      failureCategory,
      operationId,
      attempts: attemptsRun,
      model,
    });
  };
  const fail = async (failure: FunctionFailure): Promise<never> => {
    await report(
      failure.status === 402 || failure.status === 403 ? "denied" : "failed",
      failure.code,
    );
    throw failure;
  };

  const collect = async (
    preview: PreviewRow,
    replayed: boolean,
  ): Promise<{ status: number; body: unknown }> => {
    // A commit that cannot be recorded does not fail the request: the preview
    // is real. Reconciliation commits it from the operation id, and a commit
    // replay of a charged operation changes nothing.
    await ports.commit(operationId, preview.id);
    await report(replayed ? "duplicate" : "succeeded", null);
    return { status: 200, body: responseBody(preview, originalPath) };
  };

  const reservation = await ports.reserve(operationId);
  if (!reservation.ok) {
    if (reservation.errorCode === "USAGE_ALREADY_COMMITTED") {
      const prior = await ports.findPreviewByOperation(operationId);
      if (prior) {
        await report("duplicate", null);
        return { status: 200, body: responseBody(prior, originalPath) };
      }
    }
    return await fail(
      new FunctionFailure(
        usageFailureStatus(reservation.errorCode),
        reservation.errorCode ?? "TEMPORARY_BACKEND_FAILURE",
        usageFailureMessage(reservation.errorCode),
        usageFailureRetryable(reservation.errorCode),
      ),
    );
  }

  // Produced earlier, but the commit never landed.
  const earlier = await ports.findPreviewByOperation(operationId);
  if (earlier) return await collect(earlier, true);

  try {
    assertFrozenSource(source);
  } catch (error) {
    if (!(error instanceof InvalidFrozenPalette)) throw error;
    await ports.release(operationId, "invalid_frozen_palette");
    return await fail(
      new FunctionFailure(
        422,
        "invalid_frozen_palette",
        "This look can no longer be generated.",
      ),
    );
  }

  const original = await ports.downloadOriginal(originalPath);
  const deadline = startedAt + INVOCATION_BUDGET_MS;
  const provider = ports.provider(deadline);

  const endWithoutPreview = async (
    lastStatus: string,
    categories: string[],
  ): Promise<never> => {
    await ports.release(operationId, lastStatus);
    if (lastStatus === "nonretryable_palette_mismatch") {
      return await fail(
        new FunctionFailure(
          422,
          "palette_feature_not_visible",
          "Part of your face this look needs isn't visible in your photo.",
          false,
          { mismatchCategories: categories },
        ),
      );
    }
    return await fail(
      new FunctionFailure(
        lastStatus === "retryable_palette_mismatch" ? 422 : 502,
        lastStatus === "retryable_palette_mismatch"
          ? "palette_preview_mismatch"
          : "palette_preview_failed",
        "Your preview could not be created with these colors. You were not charged. Please try again.",
        true,
        { mismatchCategories: categories },
      ),
    );
  };

  while (true) {
    if (ports.now() + MINIMUM_ATTEMPT_MS > deadline) {
      // Attempts may remain, but not time. The reservation stands for a replay.
      return await fail(inProgress(operationId));
    }
    const quota = await ports.consumeQuota();
    if (!quota.allowed) {
      await ports.release(operationId, "rate_limited");
      return await fail(
        new FunctionFailure(429, "rate_limited", quota.message, true),
      );
    }
    const claim = await ports.claim({
      userId,
      operationId,
      recommendationId,
    });
    if (claim.status === "accepted") {
      const winner = await ports.findPreviewByOperation(operationId);
      if (winner) return await collect(winner, true);
      return await fail(inProgress(operationId));
    }
    if (claim.status === "in_progress") {
      return await fail(inProgress(operationId));
    }
    if (claim.status === "not_found" || claim.status === "conflict") {
      return await fail(
        new FunctionFailure(
          409,
          "operation_conflict",
          "This request cannot be used for this look.",
        ),
      );
    }
    if (claim.status === "terminal" || claim.status === "exhausted") {
      return await endWithoutPreview(
        claim.lastStatus,
        claim.mismatchCategories,
      );
    }

    attemptsRun += 1;
    const result = await runPreviewCandidate(
      source,
      original,
      claim.generationNumber,
      provider,
      claim.previousReasons,
    );

    if (result.outcome !== "accepted") {
      await ports.finishAttempt({
        userId,
        operationId,
        attemptNumber: claim.attemptNumber,
        status: result.outcome,
        categories: result.verdict.mismatch_categories,
        reasons: reasonCodes(result.verdict),
        validatorVersion: result.verdict.failure_code === null
          ? result.verdict.validator_version
          : null,
      });
      continue;
    }

    model = result.model;
    const path = `${userId}/analyses/${source.analysis_id}/` +
      `custom-palette-generated/${recommendationId}/preview_` +
      `${claim.generationNumber.toString().padStart(4, "0")}.` +
      extensionFor(result.image.mimeType as GeneratedImage["mimeType"]);
    if (
      !isOwnedGeneratedPreviewPath(
        path,
        userId,
        source.analysis_id,
        "custom-palette-generated",
        recommendationId,
      )
    ) {
      throw new FunctionFailure(
        500,
        "unsafe_storage_path",
        "A safe preview path could not be created.",
      );
    }
    try {
      await ports.upload(path, result.image);
    } catch {
      await ports.finishAttempt({
        userId,
        operationId,
        attemptNumber: claim.attemptNumber,
        status: "provider_failure",
        categories: [],
        reasons: [],
        validatorVersion: null,
      });
      continue;
    }

    const finalized = await ports.finalize({
      userId,
      operationId,
      attemptNumber: claim.attemptNumber,
      storagePath: path,
      model: result.model,
      promptVersion: result.prompt_version,
      validatorVersion: CUSTOM_PALETTE_VALIDATOR_VERSION,
    });
    if (!finalized.ok) {
      // This worker's lease was taken over, or there is nothing to charge. The
      // path belongs to this attempt alone, so removing it cannot touch another.
      await ports.removeUpload(path);
      return await fail(inProgress(operationId));
    }
    if (finalized.preview.storage_path !== path) {
      await ports.removeUpload(path);
    }
    return await collect(finalized.preview, finalized.replayed);
  }
}
