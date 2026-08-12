/** AI operations that consume a server-enforced quota. */
export type AiOperation =
  | "face_analysis"
  | "makeup_recommendation"
  | "makeup_preview";

export interface QuotaDecision {
  allowed: boolean;
  reason: string;
  retryAfterSeconds: number;
}

/**
 * Minimal view of the Supabase client this helper needs.
 *
 * Declaring only `rpc` keeps the helper independent of the client's generic
 * database typing, which differs per function.
 */
export interface QuotaClient {
  // deno-lint-ignore no-explicit-any
  rpc(name: string, args: Record<string, unknown>): PromiseLike<any>;
}

/**
 * Consumes one unit of the caller's AI quota.
 *
 * Limits are enforced by `public.consume_ai_quota`, which derives the account
 * from the request JWT. The client never supplies the identity or the ceiling,
 * so a caller cannot raise its own limit or spend another account's quota.
 *
 * Fails closed: an unreachable or malformed quota check denies the request
 * rather than allowing unmetered upstream AI spend.
 */
export async function consumeAiQuota(
  client: QuotaClient,
  operation: AiOperation,
): Promise<QuotaDecision> {
  let payload: unknown;
  try {
    const result = await client.rpc("consume_ai_quota", {
      p_operation: operation,
    });
    if (result?.error) {
      console.error(
        `[ai-quota] Quota check failed operation=${operation} code=${
          result.error?.code ?? "unknown"
        }`,
      );
      return {
        allowed: false,
        reason: "quota_unavailable",
        retryAfterSeconds: 60,
      };
    }
    payload = result?.data;
  } catch (error) {
    console.error(
      `[ai-quota] Quota check threw operation=${operation} type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return {
      allowed: false,
      reason: "quota_unavailable",
      retryAfterSeconds: 60,
    };
  }

  if (typeof payload !== "object" || payload === null) {
    console.error(`[ai-quota] Quota check returned no decision operation=${operation}`);
    return {
      allowed: false,
      reason: "quota_unavailable",
      retryAfterSeconds: 60,
    };
  }
  const decision = payload as Record<string, unknown>;
  return {
    allowed: decision.allowed === true,
    reason: typeof decision.reason === "string" ? decision.reason : "unknown",
    retryAfterSeconds: typeof decision.retryAfterSeconds === "number"
      ? decision.retryAfterSeconds
      : 60,
  };
}

/** User-facing copy for a denied request. Never exposes internal quota state. */
export function quotaMessage(reason: string): string {
  switch (reason) {
    case "hourly_quota_exceeded":
      return "You have reached this hour's limit for AI requests. Please try again later.";
    case "daily_quota_exceeded":
      return "You have reached today's limit for AI requests. Please try again tomorrow.";
    case "authentication_required":
      return "Sign in again to continue.";
    default:
      return "AI requests are temporarily limited. Please try again shortly.";
  }
}
