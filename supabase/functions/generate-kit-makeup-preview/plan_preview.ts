import {
  usageFailureMessage,
  usageFailureRetryable,
  usageFailureStatus,
  type UsageResult,
} from "../_shared/ai_look_usage.ts";
import type { CanonicalPlan } from "../_shared/kit_makeup_plan.ts";
import type { GeneratedImage } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { attemptColumns, type ValidationResult } from "./validator.ts";
import type { ReadinessResult } from "./readiness.ts";

/**
 * Bounded plan-driven preview orchestration.
 *
 * One logical preview request is one AI Look operation: one reservation, one
 * generation row, one frozen plan, and at most [PLAN_PREVIEW_MAX_ATTEMPTS]
 * candidate attempts. A candidate becomes the user's preview only when the
 * validator accepts it; every other candidate is recorded as evidence and
 * discarded. The operation commits once, on acceptance, or is released once,
 * when the generation ends without one.
 *
 * An Edge invocation cannot hold three generations and three validations, so
 * a request may span invocations. Each invocation holds a lease on the
 * generation, runs whole attempts while its budget allows, and otherwise
 * yields; the client replays the same operation id and the next invocation
 * continues at the next attempt. The attempt bound is enforced by the database,
 * so no sequence of invocations can exceed it.
 */

export const PLAN_PREVIEW_MAX_ATTEMPTS = 3;
/** Longer than any invocation, so a live holder never loses its lease. */
export const LEASE_MS = 180_000;
/** Under the platform's wall-clock window, with room to reply. */
export const INVOCATION_BUDGET_MS = 140_000;
export const GENERATION_BUDGET_MS = 90_000;
export const VALIDATION_BUDGET_MS = 35_000;
/** An attempt starts only when a whole one fits. */
export const ATTEMPT_BUDGET_MS = GENERATION_BUDGET_MS + VALIDATION_BUDGET_MS;
export const BUSY_RETRY_AFTER_MS = 5_000;

export type GenerationRow = {
  id: string;
  operation_id: string;
  kit_recommendation_id: string;
  status: "in_progress" | "accepted" | "failed";
  terminal_outcome: string | null;
  max_attempts: number;
  lease_expires_at: string | null;
};

export type AttemptRow = {
  id: string;
  attempt_number: number;
  status: "generating" | "validating" | "completed";
  outcome: string | null;
  reason_code: string | null;
  mismatch_categories: string[];
  missing_required_categories: string[];
  preview_storage_path: string | null;
};

export type SourceImage = { bytes: Uint8Array; mimeType: string };

export interface PlanPreviewPorts {
  now(): number;
  reserve(operationId: string): Promise<UsageResult>;
  commit(operationId: string, previewId: string): Promise<UsageResult>;
  release(operationId: string, failureCode: string): Promise<UsageResult>;
  findGeneration(operationId: string): Promise<GenerationRow | null>;
  /** Inserts holding the lease; null when another insert won the race. */
  insertGeneration(input: {
    operationId: string;
    maxAttempts: number;
    leaseExpiresAt: string;
  }): Promise<GenerationRow | null>;
  /** Takes the lease only if it is free or expired at [nowIso]. */
  takeLease(generationId: string, untilIso: string, nowIso: string): Promise<
    boolean
  >;
  yieldLease(generationId: string): Promise<void>;
  endGeneration(generationId: string, terminalOutcome: string): Promise<void>;
  listAttempts(generationId: string): Promise<AttemptRow[]>;
  /** Starts the next attempt; null when the database refuses it. */
  startAttempt(input: {
    generationId: string;
    attemptNumber: number;
    repairCodes: string[];
  }): Promise<string | null>;
  markValidating(
    attemptId: string,
    sha256: string,
    generationLatencyMs: number,
  ): Promise<void>;
  completeAttempt(
    attemptId: string,
    result: ReturnType<typeof attemptColumns> | {
      outcome: "provider_failure";
      reason_code: string;
    },
    validationLatencyMs: number | null,
  ): Promise<void>;
  abandonAttempt(attemptId: string, reasonCode: string): Promise<void>;
  claimSlot(attemptId: string, extension: string): Promise<{
    generationNumber: number;
    storagePath: string;
  }>;
  finalize(
    attemptId: string,
    validatorVersion: string,
    evidence: Record<string, unknown> | null,
  ): Promise<string>;
  findPreview(operationId: string): Promise<Record<string, unknown> | null>;
  upload(path: string, bytes: Uint8Array, mimeType: string): Promise<void>;
  remove(path: string): Promise<void>;
  generate(
    plan: CanonicalPlan,
    original: SourceImage,
    variationNumber: number,
    repairCodes: string[],
    budgetMs: number,
  ): Promise<GeneratedImage>;
  validate(
    plan: CanonicalPlan,
    original: SourceImage,
    candidate: GeneratedImage,
    budgetMs: number,
  ): Promise<ValidationResult>;
  /** Tutorial readiness of a candidate. Never throws: a provider or parse
   * problem is a `failure` result. */
  assessReadiness(
    plan: CanonicalPlan,
    original: SourceImage,
    candidate: GeneratedImage,
    budgetMs: number,
  ): Promise<ReadinessResult>;
  sha256(bytes: Uint8Array): Promise<string>;
}

export type PlanPreviewContext = {
  operationId: string;
  kitRecommendationId: string;
  plan: CanonicalPlan;
  /** Proves the look can still be rendered and loads the original selfie.
   * `isNew` is true only for the operation's first invocation. Throws a
   * [FunctionFailure] when it cannot. */
  prepare(isNew: boolean): Promise<SourceImage>;
};

export type OperationState = "accepted" | "in_progress" | "failed";

export type PlanPreviewReply =
  | {
    kind: "accepted";
    preview: Record<string, unknown>;
    attempts: number;
    replayed: boolean;
  }
  | { kind: "in_progress"; retryAfterMs: number; busy: boolean }
  | {
    kind: "failed";
    terminalOutcome: string;
    failure: FunctionFailure;
    attempts: number;
  };

/** Terminal outcome → what the user is told. Truthful, and never blames the
 * kit for a model inconsistency. */
function terminalFailure(outcome: string): FunctionFailure {
  switch (outcome) {
    case "inventory_changed":
      return new FunctionFailure(
        409,
        "inventory_changed",
        "A selected product was edited or removed. Create a new kit-based look.",
      );
    case "reservation_released":
      return new FunctionFailure(
        409,
        "operation_expired",
        "This preview request expired. Please try generating another preview.",
        true,
      );
    default:
      return new FunctionFailure(
        422,
        "preview_not_reliable",
        "We couldn't create a reliable tutorial-ready version of this look. Your Makeup Kit is unchanged. Please try generating another preview.",
        true,
      );
  }
}

function extensionFor(mimeType: string): string {
  return mimeType === "image/png"
    ? "png"
    : mimeType === "image/webp"
    ? "webp"
    : "jpg";
}

function identical(a: Uint8Array, b: Uint8Array): boolean {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

/** Corrections for the next attempt, derived only from earlier attempts'
 * recorded evidence. Sorted and de-duplicated so the order never varies. */
export function repairCodesFrom(attempts: AttemptRow[]): string[] {
  const codes = new Set<string>();
  for (const attempt of attempts) {
    if (
      attempt.outcome !== "retryable_mismatch" &&
      attempt.outcome !== "nonretryable_mismatch"
    ) continue;
    for (const category of attempt.mismatch_categories) {
      codes.add(`forbid_${category}`);
    }
    for (const category of attempt.missing_required_categories) {
      codes.add(`require_${category}`);
    }
    if (attempt.reason_code === "identity_changed") {
      codes.add("preserve_identity");
    }
  }
  return [...codes].sort();
}

/**
 * Advances one logical preview request as far as this invocation can.
 *
 * Never releases the reservation unless this invocation holds the lease and
 * has ended the generation; never commits anything but the one accepted
 * preview of this operation.
 */
export async function runPlanPreview(
  context: PlanPreviewContext,
  ports: PlanPreviewPorts,
): Promise<PlanPreviewReply> {
  const deadline = ports.now() + INVOCATION_BUDGET_MS;
  const { operationId } = context;
  const busy = (): PlanPreviewReply => ({
    kind: "in_progress",
    retryAfterMs: BUSY_RETRY_AFTER_MS,
    busy: true,
  });

  let generation = await ports.findGeneration(operationId);
  if (
    generation &&
    generation.kit_recommendation_id !== context.kitRecommendationId
  ) {
    throw new FunctionFailure(
      409,
      "operation_conflict",
      "This request belongs to a different look.",
    );
  }
  if (generation?.status === "accepted") {
    return await acceptedReply(operationId, ports, true);
  }
  if (generation?.status === "failed") {
    return failedReply(generation.terminal_outcome ?? "retry_exhausted", 0);
  }
  if (generation && leaseLive(generation, ports.now())) return busy();

  let original: SourceImage;
  try {
    original = await context.prepare(generation === null);
  } catch (error) {
    if (
      generation && error instanceof FunctionFailure &&
      error.code === "inventory_changed"
    ) {
      return await endAndRelease(generation, "inventory_changed", ports, {
        attempts: 0,
        holdsLease: false,
      }) ?? busy();
    }
    throw error;
  }

  const reservation = await ports.reserve(operationId);
  if (!reservation.ok) {
    if (reservation.errorCode === "USAGE_ALREADY_COMMITTED") {
      return await acceptedReply(operationId, ports, true);
    }
    if (reservation.errorCode === "USAGE_ALREADY_RELEASED") {
      if (!generation) return failedReply("reservation_released", 0);
      // Released while no holder was alive: reconciliation found nothing to
      // charge. End the generation so it cannot run again.
      return await endAndRelease(generation, "reservation_released", ports, {
        attempts: 0,
        holdsLease: false,
      }) ?? busy();
    }
    throw new FunctionFailure(
      usageFailureStatus(reservation.errorCode),
      reservation.errorCode ?? "TEMPORARY_BACKEND_FAILURE",
      usageFailureMessage(reservation.errorCode),
      usageFailureRetryable(reservation.errorCode),
    );
  }

  const leaseUntil = () => new Date(ports.now() + LEASE_MS).toISOString();
  if (!generation) {
    generation = await ports.insertGeneration({
      operationId,
      maxAttempts: PLAN_PREVIEW_MAX_ATTEMPTS,
      leaseExpiresAt: leaseUntil(),
    });
    if (!generation) return busy();
  } else if (
    !await ports.takeLease(
      generation.id,
      leaseUntil(),
      new Date(ports.now()).toISOString(),
    )
  ) {
    return busy();
  }

  try {
    return await advance(generation, original, context, ports, deadline);
  } catch (error) {
    // An unexpected failure while holding the lease: hand the lease back so
    // the next replay can continue immediately, and leave the reservation
    // alone — the work may still be completed.
    await ports.yieldLease(generation.id).catch(() => {});
    throw error;
  }
}

async function advance(
  generation: GenerationRow,
  original: SourceImage,
  context: PlanPreviewContext,
  ports: PlanPreviewPorts,
  deadline: number,
): Promise<PlanPreviewReply> {
  const { plan } = context;
  // Anything a dead holder left in flight is abandoned, and its stored
  // object, if it got that far, is removed.
  for (const attempt of await ports.listAttempts(generation.id)) {
    if (attempt.status === "completed") continue;
    if (attempt.preview_storage_path) {
      await ports.remove(attempt.preview_storage_path).catch(() => {});
    }
    await ports.abandonAttempt(attempt.id, "lease_expired");
  }

  while (true) {
    const attempts = await ports.listAttempts(generation.id);
    const last = attempts.at(-1);
    if (last?.outcome === "nonretryable_mismatch") {
      return await endAndRelease(generation, "nonretryable_mismatch", ports, {
        attempts: attempts.length,
        holdsLease: true,
      }) ?? unreachable();
    }
    if (attempts.length >= generation.max_attempts) {
      return await endAndRelease(generation, "retry_exhausted", ports, {
        attempts: attempts.length,
        holdsLease: true,
      }) ?? unreachable();
    }
    if (deadline - ports.now() < ATTEMPT_BUDGET_MS) {
      await ports.yieldLease(generation.id);
      return { kind: "in_progress", retryAfterMs: 0, busy: false };
    }

    const attemptNumber = attempts.length + 1;
    const repairs = repairCodesFrom(attempts);
    const attemptId = await ports.startAttempt({
      generationId: generation.id,
      attemptNumber,
      repairCodes: repairs,
    });
    if (!attemptId) {
      // The database refused the next attempt, so another invocation is
      // acting on this generation. Step aside without holding the lease.
      await ports.yieldLease(generation.id);
      return {
        kind: "in_progress",
        retryAfterMs: BUSY_RETRY_AFTER_MS,
        busy: true,
      };
    }

    const generationStarted = ports.now();
    let candidate: GeneratedImage;
    try {
      candidate = await ports.generate(
        plan,
        original,
        attemptNumber,
        repairs,
        GENERATION_BUDGET_MS,
      );
    } catch (error) {
      if (!(error instanceof FunctionFailure)) throw error;
      await ports.completeAttempt(attemptId, {
        outcome: "provider_failure",
        reason_code: sanitizeCode(error.code),
      }, null);
      if (!error.retryable) {
        return await endAndRelease(generation, "provider_failure", ports, {
          attempts: attemptNumber,
          holdsLease: true,
        }) ?? unreachable();
      }
      continue;
    }
    if (identical(original.bytes, candidate.bytes)) {
      await ports.completeAttempt(attemptId, {
        outcome: "provider_failure",
        reason_code: "unchanged_generated_image",
      }, null);
      continue;
    }
    await ports.markValidating(
      attemptId,
      await ports.sha256(candidate.bytes),
      ports.now() - generationStarted,
    );

    // The plan check and the Tutorial readiness check judge the same bytes
    // side by side, inside the one validation budget.
    const validationStarted = ports.now();
    const [result, readiness] = await Promise.all([
      ports.validate(plan, original, candidate, VALIDATION_BUDGET_MS),
      ports.assessReadiness(plan, original, candidate, VALIDATION_BUDGET_MS),
    ]);
    const validationLatency = ports.now() - validationStarted;
    const evidence = { validator: result.evidence, readiness };
    if (result.outcome !== "accepted") {
      const columns = attemptColumns(result);
      await ports.completeAttempt(
        attemptId,
        // A provider failure carries no evidence by contract.
        columns.outcome === "provider_failure"
          ? columns
          : { ...columns, evidence_json: evidence },
        validationLatency,
      );
      continue;
    }
    if (readiness.status !== "ready") {
      // The plan check passed, but the Tutorial would not accept this preview.
      // It is not accepted: a failed readiness check is retried like a
      // validator failure, and a not-ready verdict like a mismatch, so its
      // unbacked or missing categories tighten the next attempt.
      await ports.completeAttempt(
        attemptId,
        readiness.status === "failure"
          ? {
            outcome: "validator_failure",
            reason_code: readiness.failure_code ?? "readiness_failure",
            validator_version: result.validator_version,
            mismatch_categories: [],
            missing_required_categories: [],
            evidence_json: evidence,
          }
          : {
            outcome: "retryable_mismatch",
            reason_code: "tutorial_not_ready",
            validator_version: result.validator_version,
            mismatch_categories: readiness.unbacked_present_categories,
            missing_required_categories: readiness.missing_required_categories,
            evidence_json: evidence,
          },
        validationLatency,
      );
      continue;
    }

    // Accepted. Claim the slot, store the bytes, then accept and persist in
    // one transaction. A failure in between abandons this attempt; it never
    // leaves a preview behind.
    const slot = await ports.claimSlot(
      attemptId,
      extensionFor(candidate.mimeType),
    );
    let previewId: string;
    try {
      await ports.upload(slot.storagePath, candidate.bytes, candidate.mimeType);
      previewId = await ports.finalize(
        attemptId,
        result.validator_version,
        evidence,
      );
    } catch {
      await ports.remove(slot.storagePath).catch(() => {});
      await ports.abandonAttempt(attemptId, "persist_failed");
      continue;
    }
    const commit = await ports.commit(context.operationId, previewId);
    if (!commit.ok) {
      // The preview is the user's; reconciliation commits it from the row.
      console.error(
        `[generate-kit-makeup-preview] ai_look_commit_deferred code=${commit.errorCode}`,
      );
    }
    const preview = await ports.findPreview(context.operationId);
    if (!preview) throw new Error("accepted preview not readable");
    return {
      kind: "accepted",
      preview,
      attempts: attemptNumber,
      replayed: false,
    };
  }
}

/**
 * Ends the generation and releases its reservation — the only place either
 * happens. A caller that does not already hold the lease must win it first;
 * when another invocation holds it, nothing is ended or released and null is
 * returned, so a live holder can never have its reservation released under it.
 */
async function endAndRelease(
  generation: GenerationRow,
  outcome: string,
  ports: PlanPreviewPorts,
  { attempts, holdsLease }: { attempts: number; holdsLease: boolean },
): Promise<PlanPreviewReply | null> {
  if (
    !holdsLease &&
    !await ports.takeLease(
      generation.id,
      new Date(ports.now() + LEASE_MS).toISOString(),
      new Date(ports.now()).toISOString(),
    )
  ) return null;
  for (const attempt of await ports.listAttempts(generation.id)) {
    if (attempt.status === "completed") continue;
    if (attempt.preview_storage_path) {
      await ports.remove(attempt.preview_storage_path).catch(() => {});
    }
    await ports.abandonAttempt(attempt.id, "lease_expired");
  }
  await ports.endGeneration(generation.id, outcome);
  if (outcome !== "reservation_released") {
    const released = await ports.release(generation.operation_id, outcome);
    console.log(
      `[generate-kit-makeup-preview] ai_look_release ok=${released.ok} outcome=${outcome}`,
    );
  }
  return failedReply(outcome, attempts);
}

function failedReply(outcome: string, attempts: number): PlanPreviewReply {
  return {
    kind: "failed",
    terminalOutcome: outcome,
    failure: terminalFailure(outcome),
    attempts,
  };
}

async function acceptedReply(
  operationId: string,
  ports: PlanPreviewPorts,
  replayed: boolean,
): Promise<PlanPreviewReply> {
  const preview = await ports.findPreview(operationId);
  if (!preview) {
    throw new FunctionFailure(
      503,
      "preview_unavailable",
      "The preview could not be loaded. Please try again.",
      true,
    );
  }
  // Idempotent: a commit that already happened is a replay, never a charge.
  const commit = await ports.commit(operationId, preview.id as string);
  if (!commit.ok) {
    console.error(
      `[generate-kit-makeup-preview] ai_look_commit_deferred code=${commit.errorCode}`,
    );
  }
  return { kind: "accepted", preview, attempts: 0, replayed };
}

function leaseLive(generation: GenerationRow, now: number): boolean {
  return generation.lease_expires_at !== null &&
    Date.parse(generation.lease_expires_at) > now;
}

function sanitizeCode(code: string): string {
  const cleaned = code.toLowerCase().replace(/[^a-z0-9_]/g, "_").slice(0, 64);
  return cleaned.length > 0 ? cleaned : "provider_error";
}

function unreachable(): never {
  throw new Error("lease lost while holding it");
}
