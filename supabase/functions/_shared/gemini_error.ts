/**
 * Safe, bounded diagnostics for an unsuccessful Gemini response.
 *
 * The V3 clients previously logged `status=<n>` and discarded the body, then
 * mapped every non-429 failure onto one `gemini_upstream_error` /
 * "temporarily unavailable" branch. A permanently invalid request and a real
 * outage were therefore indistinguishable in production logs, and a request
 * that could never succeed was reported to the user as transient.
 *
 * This module extracts the small set of structured fields Google returns and
 * nothing else. It never sees the request, the prompt, the image bytes, the
 * API key or any header, and it truncates and redacts what it does read.
 */

/** Bodies larger than this are ignored: a Gemini error envelope is tiny. */
const maximumBodyCharacters = 16384;
const maximumMessageCharacters = 300;
const maximumTokenCharacters = 48;

/** Google API keys, so a message that echoed one back cannot reach a log. */
const apiKeyPattern = /AIza[0-9A-Za-z_-]{10,}/g;
/** Any other long opaque run — a JWT, a signed URL token, base64 image data. */
const opaqueRunPattern = /[A-Za-z0-9+/_-]{40,}={0,2}/g;

export type GeminiFailureKind =
  /** The request itself is wrong: schema, generationConfig, contents, size. */
  | "invalid_request"
  /** The key is missing, invalid, blocked or lacks permission. */
  | "credential"
  /** The project is not in a state that permits the call: billing, region. */
  | "precondition"
  /** The model name does not exist or does not serve this method. */
  | "model_not_found"
  /** Quota or rate limit. */
  | "rate_limited"
  /** Gemini's own failure. */
  | "upstream";

export interface GeminiErrorDetail {
  readonly httpStatus: number;
  /** `error.status`, e.g. `INVALID_ARGUMENT`. */
  readonly apiStatus: string | null;
  /** `error.details[].reason`, e.g. `API_KEY_INVALID`. */
  readonly reason: string | null;
  /** `error.message`, collapsed, redacted and truncated. */
  readonly message: string;
  readonly kind: GeminiFailureKind;
  readonly retryable: boolean;
}

export interface GeminiFailureMapping {
  readonly status: number;
  readonly code: string;
  readonly retryable: boolean;
  /**
   * True when the fault is this service's own configuration or request rather
   * than a passing upstream condition, so the caller must not describe it as
   * temporary and must not retry it.
   */
  readonly configuration: boolean;
}

function sanitizeToken(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const token = value.trim().replace(/[^A-Za-z0-9_]/g, "").slice(
    0,
    maximumTokenCharacters,
  );
  return token.length > 0 ? token : null;
}

function sanitizeMessage(value: unknown): string {
  if (typeof value !== "string") return "";
  const collapsed = value
    .replace(/\s+/g, " ")
    .trim()
    .replace(apiKeyPattern, "[redacted]")
    .replace(opaqueRunPattern, "[redacted]");
  return collapsed.length > maximumMessageCharacters
    ? `${collapsed.slice(0, maximumMessageCharacters)}...`
    : collapsed;
}

function kindFor(
  httpStatus: number,
  apiStatus: string | null,
  reason: string | null,
): GeminiFailureKind {
  if (httpStatus === 401 || httpStatus === 403) return "credential";
  if (httpStatus === 404) return "model_not_found";
  if (httpStatus === 429) return "rate_limited";
  if (httpStatus >= 500) return "upstream";
  // Everything below is a 4xx that Google answers with `400 INVALID_ARGUMENT`
  // regardless of cause, so the discriminator has to be the envelope. An
  // unusable API key arrives as 400, not 401.
  if (reason !== null && reason.startsWith("API_KEY")) return "credential";
  if (apiStatus === "UNAUTHENTICATED" || apiStatus === "PERMISSION_DENIED") {
    return "credential";
  }
  if (apiStatus === "FAILED_PRECONDITION") return "precondition";
  if (reason === "SERVICE_DISABLED" || reason === "BILLING_DISABLED") {
    return "precondition";
  }
  if (apiStatus === "RESOURCE_EXHAUSTED") return "rate_limited";
  if (apiStatus === "NOT_FOUND") return "model_not_found";
  return "invalid_request";
}

/**
 * Reads an unsuccessful Gemini response into a loggable description.
 *
 * Consumes the body, so it is called exactly once per failed response.
 */
export async function describeGeminiError(
  response: Response,
): Promise<GeminiErrorDetail> {
  let apiStatus: string | null = null;
  let reason: string | null = null;
  let message = "";
  try {
    const raw = await response.text();
    if (raw.length > 0 && raw.length <= maximumBodyCharacters) {
      const parsed = JSON.parse(raw) as {
        error?: {
          status?: unknown;
          message?: unknown;
          details?: Array<{ reason?: unknown } | null> | null;
        };
      };
      const error = parsed.error;
      if (error) {
        apiStatus = sanitizeToken(error.status);
        message = sanitizeMessage(error.message);
        for (const detail of error.details ?? []) {
          const candidate = sanitizeToken(detail?.reason);
          if (candidate !== null) {
            reason = candidate;
            break;
          }
        }
      }
    }
  } catch {
    // A body that is absent, oversized or not JSON adds nothing the status has
    // not already said. It is never logged raw.
  }
  const kind = kindFor(response.status, apiStatus, reason);
  return {
    httpStatus: response.status,
    apiStatus,
    reason,
    message,
    kind,
    retryable: kind === "rate_limited" || kind === "upstream",
  };
}

/** One bounded log line carrying only the fields above. */
export function geminiErrorLogLine(
  tag: string,
  attempt: number,
  detail: GeminiErrorDetail,
): string {
  return `[${tag}] gemini_error status=${detail.httpStatus} ` +
    `api_status=${detail.apiStatus ?? "none"} ` +
    `reason=${detail.reason ?? "none"} kind=${detail.kind} ` +
    `retryable=${detail.retryable} attempt=${attempt} ` +
    `message="${detail.message}"`;
}

/**
 * How a caller should surface the failure.
 *
 * Configuration faults become 500s the client will not retry: the same request
 * will be rejected the same way for as long as the deployment is unchanged, so
 * retrying it only spends the user's time and the step's bounded attempts.
 */
export function geminiFailureFor(
  detail: GeminiErrorDetail,
): GeminiFailureMapping {
  switch (detail.kind) {
    case "credential":
      return {
        status: 500,
        code: "gemini_credential_rejected",
        retryable: false,
        configuration: true,
      };
    case "precondition":
      return {
        status: 500,
        code: "gemini_account_precondition",
        retryable: false,
        configuration: true,
      };
    case "model_not_found":
      return {
        status: 500,
        code: "GEMINI_MODEL_NOT_FOUND",
        retryable: false,
        configuration: true,
      };
    case "rate_limited":
      return {
        status: 503,
        code: "gemini_rate_limited",
        retryable: true,
        configuration: false,
      };
    case "upstream":
      return {
        status: 502,
        code: "gemini_upstream_error",
        retryable: true,
        configuration: false,
      };
    case "invalid_request":
      return {
        status: 500,
        code: "gemini_invalid_request",
        retryable: false,
        configuration: true,
      };
  }
}
