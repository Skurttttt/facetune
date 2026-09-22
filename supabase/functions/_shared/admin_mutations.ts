/**
 * Request parsing and response mapping for privileged admin mutations (WA-7).
 *
 * Pure: no I/O, no client, no authority. An Edge Function calls
 * `parseGrantSalonPilotRequest` on the JSON body AFTER `requireAdmin` has
 * accepted the session, forwards the parsed intent to the database writer as
 * the caller, and hands the writer's answer to `mutationResponse` to pick the
 * HTTP status and body. The browser never names the administrator, the
 * before-state, or the resulting figures; the writer decides all of that
 * (Shared Contract §72–§73).
 */

import {
  adminErrorRetryable,
  adminErrorStatus,
  asSubscriptionErrorCode,
  SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
  type SubscriptionErrorCode,
} from "./admin_contract.ts";

/**
 * Salon Pilot default fixed by the Shared Contract §32. A custom initial
 * allowance is any non-negative integer (the persisted bound,
 * `user_entitlements_allowance_not_negative`); no authority defines a
 * business maximum, so none is enforced here.
 */
export const SALON_PILOT_DEFAULT_INITIAL_ALLOWANCE = 30 as const;
export const ADMIN_REASON_MAX_LENGTH = 500 as const;
export const ADMIN_IDEMPOTENCY_KEY_MAX_LENGTH = 128 as const;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export interface GrantSalonPilotRequest {
  targetUserId: string;
  /** ISO-8601 instant, strictly in the future. */
  expiresAt: string;
  initialAllowance: number;
  reason: string;
  idempotencyKey: string;
}

/** A request the server does not accept as sent. Names the field, never echoes its value. */
export interface InvalidRequest {
  ok: false;
  field: keyof GrantSalonPilotRequest | "body";
  message: string;
}

export type ParsedGrantRequest =
  | { ok: true; value: GrantSalonPilotRequest }
  | InvalidRequest;

const invalid = (
  field: InvalidRequest["field"],
  message: string,
): InvalidRequest => ({ ok: false, field, message });

/**
 * Validates the grant request body. Every rule here is repeated by the
 * database writer; this layer exists so a malformed request is answered as
 * 400 before any round trip, and so the message can name the field.
 */
export function parseGrantSalonPilotRequest(
  body: unknown,
  now: Date = new Date(),
): ParsedGrantRequest {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return invalid("body", "The request body must be a JSON object.");
  }
  const r = body as Record<string, unknown>;

  const targetUserId = r.targetUserId;
  if (typeof targetUserId !== "string" || !UUID.test(targetUserId)) {
    return invalid("targetUserId", "targetUserId must be a user id.");
  }

  const expiresAt = r.expiresAt;
  const expiresMs = typeof expiresAt === "string" ? Date.parse(expiresAt) : NaN;
  if (typeof expiresAt !== "string" || Number.isNaN(expiresMs)) {
    return invalid("expiresAt", "expiresAt is required (ISO-8601).");
  }
  if (expiresMs <= now.getTime()) {
    return invalid("expiresAt", "expiresAt must be in the future.");
  }

  const initialAllowance = r.initialAllowance === undefined
    ? SALON_PILOT_DEFAULT_INITIAL_ALLOWANCE
    : r.initialAllowance;
  if (
    typeof initialAllowance !== "number" ||
    !Number.isInteger(initialAllowance) ||
    initialAllowance < 0
  ) {
    return invalid(
      "initialAllowance",
      "initialAllowance must be a non-negative integer.",
    );
  }

  const reason = typeof r.reason === "string" ? r.reason.trim() : "";
  if (reason.length < 1 || reason.length > ADMIN_REASON_MAX_LENGTH) {
    return invalid(
      "reason",
      `reason is required (1-${ADMIN_REASON_MAX_LENGTH} characters).`,
    );
  }

  const idempotencyKey = typeof r.idempotencyKey === "string"
    ? r.idempotencyKey.trim()
    : "";
  if (
    idempotencyKey.length < 1 ||
    idempotencyKey.length > ADMIN_IDEMPOTENCY_KEY_MAX_LENGTH
  ) {
    return invalid(
      "idempotencyKey",
      `idempotencyKey is required (1-${ADMIN_IDEMPOTENCY_KEY_MAX_LENGTH} characters).`,
    );
  }

  return {
    ok: true,
    value: {
      targetUserId: targetUserId.toLowerCase(),
      expiresAt: new Date(expiresMs).toISOString(),
      initialAllowance,
      reason,
      idempotencyKey,
    },
  };
}

/** The 400 body for a request the function refuses before calling the writer. */
export function invalidRequestBody(failure: InvalidRequest) {
  return {
    success: false,
    contractVersion: SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
    action: "grant_salon_pilot",
    errorCode: "invalid_request",
    field: failure.field,
    message: failure.message,
    retryable: false,
  };
}

export interface MutationResponse {
  status: number;
  body: Record<string, unknown>;
  /** Sanitized outcome for the log line: an error code or "success" / "replayed". */
  outcome: string;
}

/**
 * Maps the writer's JSON answer to an HTTP response. A success is passed
 * through unchanged (its figures are the resolver's and must not be
 * restated). A typed failure keeps the contract's status mapping. Anything
 * else — a shape the contract does not name — is a temporary backend failure,
 * never an invented success.
 */
export function mutationResponse(result: unknown): MutationResponse {
  if (typeof result !== "object" || result === null) {
    return backendFailure();
  }
  const r = result as Record<string, unknown>;
  if (r.success === true && typeof r.entitlementId === "string") {
    return {
      status: 200,
      body: r,
      outcome: r.replayed === true ? "replayed" : "success",
    };
  }
  if (r.success === false) {
    const code = asSubscriptionErrorCode(r.errorCode);
    if (code !== null) {
      return {
        status: adminErrorStatus(code),
        body: {
          success: false,
          contractVersion: SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
          action: typeof r.action === "string" ? r.action : "grant_salon_pilot",
          errorCode: code,
          message: mutationMessage(code),
          retryable: adminErrorRetryable(code),
        },
        outcome: code,
      };
    }
  }
  return backendFailure();
}

function backendFailure(): MutationResponse {
  const code: SubscriptionErrorCode = "TEMPORARY_BACKEND_FAILURE";
  return {
    status: adminErrorStatus(code),
    body: {
      success: false,
      contractVersion: SUBSCRIPTION_ADMIN_CONTRACT_VERSION,
      action: "grant_salon_pilot",
      errorCode: code,
      message: mutationMessage(code),
      retryable: true,
    },
    outcome: code,
  };
}

/** Sanitized, actionable text for the admin. Never names an account or a row. */
export function mutationMessage(code: SubscriptionErrorCode): string {
  switch (code) {
    case "AUTH_REQUIRED":
      return "Sign in to continue.";
    case "ADMIN_UNAUTHORIZED":
      return "This account is not authorized to perform admin actions.";
    case "USER_NOT_FOUND":
      return "No FaceTune account matches that user id.";
    case "SALON_PILOT_ALREADY_GRANTED":
      return "This account already holds a Salon Pilot entitlement that is in force.";
    case "PROVIDER_STATE_CONFLICT":
      return "This account has a store subscription in force. Salon Pilot cannot replace a paid subscription.";
    case "IDEMPOTENCY_CONFLICT":
      return "This request was already submitted with different values. Start a new grant.";
    case "CONCURRENT_MODIFICATION":
      return "The entitlement changed while you were working. Reload and try again.";
    case "TEMPORARY_BACKEND_FAILURE":
      return "The grant could not be completed. Please try again.";
    default:
      return "The request could not be completed.";
  }
}
