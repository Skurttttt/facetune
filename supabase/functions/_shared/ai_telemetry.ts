import { createClient } from "npm:@supabase/supabase-js@2";

/**
 * AI operation telemetry (SUB-13).
 *
 * Best-effort, out-of-band measurement of what the paid AI paths *did*: which
 * kind of operation ran, whether it succeeded, how long it took, which model
 * and prompt version it used, how many attempts it needed, and the provider
 * usage units (tokens, output images) that cost attribution is computed from
 * at reporting time.
 *
 * What this module never carries, by construction: image bytes, base64,
 * storage paths, signed URLs, JWTs, keys, purchase tokens, prompts, makeup
 * content, product names, or free text of any kind. Every string that reaches
 * the database is either a member of a closed vocabulary or is accepted by
 * [sanitizeCategory] only when the complete value is a short category token.
 *
 * Telemetry is never part of entitlement correctness. [recordAiOperationMetric]
 * cannot throw: an unreachable database, a refused insert, or a malformed
 * value is logged (as a code, never a payload) and dropped. Reserve, commit,
 * release, and purchase verification have already produced their result by
 * the time this is called, and nothing here can change it.
 *
 * The Edge Function establishes identity from the request JWT, then a
 * service-role-only RPC receives that verified id and derives subscription
 * provenance from authoritative rows. A mobile client cannot call the writer.
 */

/** Provider usage units from one Gemini response. */
export interface ProviderUsage {
  inputTokens: number | null;
  outputTokens: number | null;
  totalTokens: number | null;
  cachedTokens: number | null;
  thoughtsTokens: number | null;
  inputImageTokens: number | null;
  outputImageTokens: number | null;
  /** Which attempt produced the response (1 = no retry). */
  attempts: number;
}

/**
 * A slot a Gemini client fills with the usage of the response it accepted.
 *
 * Passed in by the caller rather than returned, so the clients' return types
 * — and the protected code that consumes them — stay exactly as they were.
 */
export interface UsageSink {
  usage?: ProviderUsage;
  /** Updated before every existing provider call, including failed calls. */
  attempts?: number;
}

export function noteProviderAttempt(
  sink: UsageSink | undefined,
  attempt: number,
): void {
  if (!sink) return;
  sink.attempts = Math.max(
    sink.attempts ?? 0,
    Math.max(1, Math.round(attempt)),
  );
}

/** Provider facts for persistence, including attempts that returned no usage. */
export function usageForMetric(sink: UsageSink): ProviderUsage | null {
  const attempts = Math.max(sink.attempts ?? 0, sink.usage?.attempts ?? 0);
  if (attempts === 0) return null;
  return {
    inputTokens: sink.usage?.inputTokens ?? null,
    outputTokens: sink.usage?.outputTokens ?? null,
    totalTokens: sink.usage?.totalTokens ?? null,
    cachedTokens: sink.usage?.cachedTokens ?? null,
    thoughtsTokens: sink.usage?.thoughtsTokens ?? null,
    inputImageTokens: sink.usage?.inputImageTokens ?? null,
    outputImageTokens: sink.usage?.outputImageTokens ?? null,
    attempts,
  };
}

/** Reads `usageMetadata` from a Gemini `generateContent` payload. */
export function readProviderUsage(
  payload: unknown,
  attempt: number,
): ProviderUsage {
  const usage = (payload as { usageMetadata?: Record<string, unknown> } | null)
    ?.usageMetadata;
  const count = (key: string): number | null => {
    const value = usage?.[key];
    return typeof value === "number" && Number.isFinite(value) && value >= 0
      ? Math.round(value)
      : null;
  };
  const modalityCount = (key: string, modality: string): number | null => {
    const details = usage?.[key];
    if (!Array.isArray(details)) return null;
    let found = false;
    let total = 0;
    for (const entry of details) {
      if (typeof entry !== "object" || entry === null) continue;
      const value = entry as Record<string, unknown>;
      if (String(value.modality ?? "").toUpperCase() !== modality) continue;
      const tokens = value.tokenCount;
      if (
        typeof tokens !== "number" || !Number.isFinite(tokens) || tokens < 0
      ) {
        continue;
      }
      found = true;
      total += Math.round(tokens);
    }
    return found ? total : null;
  };
  return {
    inputTokens: count("promptTokenCount"),
    outputTokens: count("candidatesTokenCount"),
    totalTokens: count("totalTokenCount"),
    cachedTokens: count("cachedContentTokenCount"),
    thoughtsTokens: count("thoughtsTokenCount"),
    inputImageTokens: modalityCount("promptTokensDetails", "IMAGE"),
    outputImageTokens: modalityCount("candidatesTokensDetails", "IMAGE"),
    attempts: Math.max(1, Math.round(attempt)),
  };
}

export type OperationKind =
  | "final_preview"
  | "tutorial_manifest"
  | "tutorial_step"
  | "purchase_verification";

export type MetricOutcome = "succeeded" | "failed" | "denied" | "duplicate";

export type OutputImageResolution = "0.5K" | "1K" | "2K" | "4K";

export interface AiOperationMetric {
  operationKind: OperationKind;
  outcome: MetricOutcome;
  /** A sanitized code such as `GEMINI_TIMEOUT`. Never a message. */
  failureCategory?: string | null;
  sourceMode?: "standard" | "makeup_kit" | "my_makeup_kit" | null;
  /** The AI Look operation, for final previews. Attribution happens server-side. */
  operationId?: string | null;
  tutorialSessionId?: string | null;
  tutorialStepId?: string | null;
  /** The canonical preview, for tutorial operations before a session exists. */
  canonicalPreviewId?: string | null;
  latencyMs?: number | null;
  persistenceLatencyMs?: number | null;
  providerName?: "google_gemini" | "google_play" | null;
  modelName?: string | null;
  promptVersion?: string | null;
  /** Provider calls made when no Gemini usage payload exists (for example Play). */
  providerAttemptCount?: number | null;
  usage?: ProviderUsage | null;
  outputImages?: number | null;
  outputImageResolution?: OutputImageResolution | null;
  verificationSource?: "purchase" | "restore" | null;
  /** SHA-256 provider reference used for attribution and never persisted here. */
  purchaseReference?: string | null;
}

/** Minimal Supabase surface, loose for the reason given in `ai_quota.ts`. */
export interface TelemetryClient {
  // deno-lint-ignore no-explicit-any
  rpc: (...args: any[]) => any;
}

/**
 * Creates the service-role telemetry writer without making it a product-path
 * dependency. Missing or invalid configuration disables measurement only.
 */
export function createTelemetryClient(): TelemetryClient | null {
  const url = Deno.env.get("SUPABASE_URL")?.trim();
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim();
  if (!url || !key) {
    console.warn("[ai-telemetry] writer_unavailable");
    return null;
  }
  try {
    return createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  } catch {
    console.warn("[ai-telemetry] writer_initialization_failed");
    return null;
  }
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/**
 * Accepts a complete category token or returns null. Values are rejected,
 * never transformed, so arbitrary text cannot be made to look trustworthy.
 */
export function sanitizeCategory(value: unknown): string | null {
  if (typeof value !== "string") return null;
  return /^[A-Za-z0-9_]{1,64}$/.test(value) ? value : null;
}

/** Model and prompt identifiers: lowercase, dots, dashes, underscores. */
export function sanitizeIdentifier(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const normalized = value.toLowerCase();
  return /^[a-z0-9._-]{1,80}$/.test(normalized) ? normalized : null;
}

function uuidOrNull(value: unknown): string | null {
  return typeof value === "string" && uuidPattern.test(value) ? value : null;
}

function countOrNull(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? Math.round(value)
    : null;
}

/** The exact RPC arguments a metric becomes. Exported for tests. */
export function metricArguments(
  eventId: string,
  userId: string,
  metric: AiOperationMetric,
): Record<string, unknown> {
  const sourceMode = metric.sourceMode === "my_makeup_kit"
    ? "makeup_kit"
    : metric.sourceMode ?? null;
  return {
    p_event_id: uuidOrNull(eventId),
    p_user_id: uuidOrNull(userId),
    p_operation_kind: metric.operationKind,
    p_outcome: metric.outcome,
    p_failure_category: sanitizeCategory(metric.failureCategory),
    p_source_mode: sourceMode,
    p_operation_id: uuidOrNull(metric.operationId),
    p_tutorial_session_id: uuidOrNull(metric.tutorialSessionId),
    p_tutorial_step_id: uuidOrNull(metric.tutorialStepId),
    p_canonical_preview_id: uuidOrNull(metric.canonicalPreviewId),
    p_generation_latency_ms: countOrNull(metric.latencyMs),
    p_persistence_latency_ms: countOrNull(metric.persistenceLatencyMs),
    p_provider_name: metric.providerName ?? null,
    p_model_name: sanitizeIdentifier(metric.modelName),
    p_prompt_version: sanitizeIdentifier(metric.promptVersion),
    p_provider_attempt_count: countOrNull(
      metric.providerAttemptCount ?? metric.usage?.attempts ?? 0,
    ),
    p_input_tokens: countOrNull(metric.usage?.inputTokens ?? null),
    p_output_tokens: countOrNull(metric.usage?.outputTokens ?? null),
    p_total_tokens: countOrNull(metric.usage?.totalTokens ?? null),
    p_cached_tokens: countOrNull(metric.usage?.cachedTokens ?? null),
    p_thoughts_tokens: countOrNull(metric.usage?.thoughtsTokens ?? null),
    p_input_image_tokens: countOrNull(metric.usage?.inputImageTokens ?? null),
    p_output_image_tokens: countOrNull(metric.usage?.outputImageTokens ?? null),
    p_output_images: countOrNull(metric.outputImages),
    p_output_image_resolution: metric.outputImageResolution ?? null,
    p_verification_source: metric.verificationSource ?? null,
    p_purchase_reference: typeof metric.purchaseReference === "string" &&
        /^[0-9a-f]{64}$/.test(metric.purchaseReference)
      ? metric.purchaseReference
      : null,
  };
}

/**
 * Records one operation. Never throws, never blocks a result.
 *
 * Awaited by callers so the write completes before the isolate is released,
 * but bounded: a hung telemetry call is abandoned after a short timeout and
 * the response goes out regardless.
 */
export async function recordAiOperationMetric(
  client: TelemetryClient | null,
  eventId: string,
  userId: string,
  metric: AiOperationMetric,
  timeoutMs = 2500,
): Promise<boolean> {
  if (!client) return false;
  let timeoutHandle: ReturnType<typeof setTimeout> | undefined;
  try {
    const call = Promise.resolve(
      client.rpc(
        "record_ai_operation_metric",
        metricArguments(eventId, userId, metric),
      ),
    );
    const timeout = new Promise<{ timedOut: true }>((resolve) =>
      timeoutHandle = setTimeout(() => resolve({ timedOut: true }), timeoutMs)
    );
    const result = await Promise.race([call, timeout]) as
      | { timedOut: true }
      | { error?: { code?: string } | null; data?: unknown };
    if ("timedOut" in result) {
      console.warn("[ai-telemetry] record_timed_out");
      return false;
    }
    if (result?.error) {
      console.warn(
        `[ai-telemetry] record_failed code=${
          sanitizeCategory(result.error?.code) ?? "unknown"
        }`,
      );
      return false;
    }
    return true;
  } catch (error) {
    console.warn(
      `[ai-telemetry] record_threw type=${
        sanitizeCategory((error as Error)?.constructor?.name) ?? "unknown"
      }`,
    );
    return false;
  } finally {
    if (timeoutHandle !== undefined) clearTimeout(timeoutHandle);
  }
}

/**
 * Whether a sanitized failure code means the request was refused before any
 * paid work (a denial) rather than attempted and lost (a failure). Codes are
 * the functions' own; the classification only decides which counter moves.
 */
export function outcomeForFailureCode(
  code: string | null | undefined,
  heldWork: boolean,
): MetricOutcome {
  if (heldWork) return "failed";
  switch (code) {
    case "tutorial_not_included":
    case "entitlement_not_found":
    case "tutorial_authorization_unavailable":
    case "rate_limited":
    case "authentication_required":
    case "invalid_session":
    case "AI_LOOK_LIMIT_REACHED":
    case "ENTITLEMENT_NOT_FOUND":
    case "ENTITLEMENT_PENDING":
    case "ENTITLEMENT_INACTIVE":
    case "ENTITLEMENT_EXPIRED":
    case "ENTITLEMENT_SUSPENDED":
    case "ENTITLEMENT_REVOKED":
    case "SALON_PILOT_EXPIRED":
    case "AUTH_REQUIRED":
      return "denied";
    default:
      return "failed";
  }
}
