/**
 * Client for the SUB-4 AI Look usage engine.
 *
 * One AI Look is one successfully generated *and successfully persisted* Final
 * Makeup Preview. These helpers wrap the three database functions that enforce
 * that, and nothing more: the arithmetic, the capacity rules, the idempotency,
 * and the concurrency guarantees all live in PostgreSQL, where a single
 * transaction can hold them.
 *
 * The functions run `security definer` and derive the account from the request
 * JWT, so none of them takes a user id. A caller cannot act as anyone else, and
 * these helpers deliberately offer no way to try.
 *
 * Failure policy differs by operation and is not symmetric:
 *
 *   * A reservation that cannot be taken must stop the request before any paid
 *     Gemini call. It fails closed.
 *   * A commit that cannot be recorded must NOT fail the request and must NOT
 *     release: a usable preview has already been persisted, and the user can
 *     open it. The reservation is left standing for
 *     `reconcile_stale_ai_look_reservations` to resolve from the persisted
 *     evidence, which is exactly the case that function exists for.
 */

/** Which pipeline produced a canonical Final Makeup Preview. */
export type PreviewSourceMode = "standard" | "makeup_kit";

export interface UsageResult {
  ok: boolean;
  /** Shared sanitized error code, e.g. `AI_LOOK_LIMIT_REACHED`. */
  errorCode: string | null;
  /** True when the engine recognised this operation and replayed its state. */
  replayed: boolean;
  /** `reserved`, `committed`, or `released` when the engine reported one. */
  status: string | null;
  availableAiLooks: number | null;
}

/**
 * Minimal view of the Supabase client these helpers need.
 *
 * Intentionally loose, for the same reason as `ai_quota.ts`: without generated
 * database types the client's `rpc` resolves its argument type to `undefined`,
 * so a more precise declaration is not assignable from the real client.
 */
export interface UsageClient {
  // deno-lint-ignore no-explicit-any
  rpc: (...args: any[]) => any;
}

function decode(payload: unknown): UsageResult {
  if (typeof payload !== "object" || payload === null) {
    return {
      ok: false,
      errorCode: "TEMPORARY_BACKEND_FAILURE",
      replayed: false,
      status: null,
      availableAiLooks: null,
    };
  }
  const value = payload as Record<string, unknown>;
  return {
    ok: value.ok === true,
    errorCode: typeof value.errorCode === "string" ? value.errorCode : null,
    replayed: value.replayed === true,
    status: typeof value.status === "string" ? value.status : null,
    availableAiLooks: typeof value.availableAiLooks === "number"
      ? value.availableAiLooks
      : null,
  };
}

async function callUsageFunction(
  client: UsageClient,
  name: string,
  args: Record<string, unknown>,
): Promise<UsageResult> {
  try {
    const result = await client.rpc(name, args);
    if (result?.error) {
      console.error(
        `[ai-look-usage] ${name} failed code=${
          result.error?.code ?? "unknown"
        }`,
      );
      return {
        ok: false,
        errorCode: "TEMPORARY_BACKEND_FAILURE",
        replayed: false,
        status: null,
        availableAiLooks: null,
      };
    }
    return decode(result?.data);
  } catch (error) {
    console.error(
      `[ai-look-usage] ${name} threw type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return {
      ok: false,
      errorCode: "TEMPORARY_BACKEND_FAILURE",
      replayed: false,
      status: null,
      availableAiLooks: null,
    };
  }
}

/**
 * Holds one AI Look for [operationId].
 *
 * Fails closed: an unreachable or malformed engine denies the request rather
 * than allowing an unmetered paid generation. Repeating the same
 * [operationId] returns the existing reservation instead of taking a second
 * one.
 */
export function reserveAiLook(
  client: UsageClient,
  operationId: string,
): Promise<UsageResult> {
  return callUsageFunction(client, "reserve_ai_look", {
    p_operation_id: operationId,
  });
}

/**
 * Charges exactly one AI Look, once a usable canonical preview exists.
 *
 * [canonicalPreviewId] must be the row just persisted for this user; the engine
 * verifies ownership and refuses a preview that another operation already
 * billed.
 */
export function commitAiLook(
  client: UsageClient,
  operationId: string,
  sourceMode: PreviewSourceMode,
  canonicalPreviewId: string,
): Promise<UsageResult> {
  return callUsageFunction(client, "commit_ai_look", {
    p_operation_id: operationId,
    p_source_mode: sourceMode,
    p_canonical_preview_id: canonicalPreviewId,
  });
}

/**
 * Returns held capacity after an authoritative failure.
 *
 * Call this ONLY when it is known that no usable canonical preview was
 * persisted. A client timeout, a lost connection, or an abandoned request is
 * not such a case, and neither is a failure that happens after the preview row
 * was written — the engine refuses to release a committed operation, and
 * reconciliation resolves anything left reserved.
 */
export function releaseAiLook(
  client: UsageClient,
  operationId: string,
  failureCode: string,
): Promise<UsageResult> {
  return callUsageFunction(client, "release_ai_look", {
    p_operation_id: operationId,
    p_failure_code: failureCode.slice(0, 64),
  });
}

/**
 * HTTP status for a sanitized usage/entitlement refusal.
 *
 * `402 Payment Required` is used for an exhausted allowance specifically, so
 * the client can tell "you have run out of AI Looks" — which an upgrade fixes —
 * apart from "your subscription is suspended", which it does not.
 */
export function usageFailureStatus(errorCode: string | null): number {
  switch (errorCode) {
    case "AUTH_REQUIRED":
      return 401;
    case "AI_LOOK_LIMIT_REACHED":
      return 402;
    case "ENTITLEMENT_NOT_FOUND":
    case "ENTITLEMENT_PENDING":
    case "ENTITLEMENT_INACTIVE":
    case "ENTITLEMENT_EXPIRED":
    case "ENTITLEMENT_SUSPENDED":
    case "ENTITLEMENT_REVOKED":
    case "SALON_PILOT_EXPIRED":
      return 403;
    case "USAGE_ALREADY_RELEASED":
    case "USAGE_STATE_CONFLICT":
      return 409;
    default:
      return 503;
  }
}

/** User-facing copy for a refusal. Never exposes internal entitlement state. */
export function usageFailureMessage(errorCode: string | null): string {
  switch (errorCode) {
    case "AI_LOOK_LIMIT_REACHED":
      return "You have used all of your AI Looks. Upgrade to create more.";
    case "ENTITLEMENT_NOT_FOUND":
      return "Your subscription could not be found. Please try again shortly.";
    case "ENTITLEMENT_PENDING":
      return "Your subscription is still being confirmed. Please try again shortly.";
    case "ENTITLEMENT_EXPIRED":
    case "SALON_PILOT_EXPIRED":
      return "Your subscription has ended. Renew to create more AI Looks.";
    case "ENTITLEMENT_SUSPENDED":
      return "Your subscription is currently suspended.";
    case "ENTITLEMENT_REVOKED":
      return "Your subscription is no longer active.";
    case "AUTH_REQUIRED":
      return "Sign in again to continue.";
    case "USAGE_ALREADY_RELEASED":
      return "That request already ended. Please start a new preview.";
    default:
      return "AI Looks are temporarily unavailable. Please try again shortly.";
  }
}

/** Whether a refusal is worth the client retrying as-is. */
export function usageFailureRetryable(errorCode: string | null): boolean {
  switch (errorCode) {
    case "TEMPORARY_BACKEND_FAILURE":
    case "ENTITLEMENT_PENDING":
      return true;
    default:
      return false;
  }
}
