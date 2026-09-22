/**
 * Server-side admin authorization for Edge Functions (WA-2).
 *
 * The one gate every privileged Web Admin operation passes through before
 * doing anything. It answers "who is calling, and are they an active admin?"
 * from two server facts and nothing else:
 *
 *   1. the caller's identity, established by Supabase Auth from the request's
 *      own JWT (`auth.getUser()`), exactly as every existing Edge Function
 *      does — never from a body field, a header the browser chose, or a claim
 *      the browser can write;
 *   2. the roster answer from `public.current_user_is_admin()`, a
 *      `security definer` database function that reads `admin_users` for the
 *      session it is called from and returns a boolean.
 *
 * Both calls are made AS THE CALLER, with the anon key and the caller's
 * Authorization header. No service-role key is needed to decide whether a
 * session is administrative, so this module never touches one.
 *
 * Fails closed. An unreachable or malformed authorizer denies rather than
 * letting a request through while the gate is down. Anonymous (guest)
 * sessions are refused before the roster is consulted: they hold the
 * `authenticated` role but are not accounts.
 *
 * A JWT `app_metadata.role`, `is_admin` claim, `x-admin` header, or any other
 * client-controlled signal is ignored by construction — nothing here reads
 * them.
 */

import type { SubscriptionErrorCode } from "./admin_contract.ts";
import { adminErrorStatus } from "./admin_contract.ts";

/** The subset of a Supabase client these helpers use. Loose for the reason given in `ai_quota.ts`. */
export interface AdminAuthClient {
  auth: {
    // deno-lint-ignore no-explicit-any
    getUser: () => Promise<any>;
  };
  // deno-lint-ignore no-explicit-any
  rpc: (...args: any[]) => any;
}

/** Builds a client bound to the caller's own session. Injected so tests need no network. */
export type UserClientFactory = (authorization: string) => AdminAuthClient;

export type AdminAuthErrorCode = Extract<
  SubscriptionErrorCode,
  "AUTH_REQUIRED" | "ADMIN_UNAUTHORIZED" | "TEMPORARY_BACKEND_FAILURE"
>;

export interface AdminAuthFailure {
  ok: false;
  errorCode: AdminAuthErrorCode;
  status: number;
}

/** A verified administrator. Carries only what an admin screen may show about itself. */
export interface AdminIdentity {
  ok: true;
  userId: string;
  email: string | null;
  role: "admin";
}

export type AdminAuthResult = AdminIdentity | AdminAuthFailure;

const failure = (errorCode: AdminAuthErrorCode): AdminAuthFailure => ({
  ok: false,
  errorCode,
  status: adminErrorStatus(errorCode),
});

/** The Bearer credential from the request, or null when there is none. */
export function bearerAuthorization(request: Request): string | null {
  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) return null;
  return authorization.slice("bearer ".length).trim().length > 0
    ? authorization
    : null;
}

/**
 * Verifies that the request is made by an active administrator.
 *
 * Reads the Authorization header and nothing else from the request. Returns
 * the caller's identity, or a typed failure with the HTTP status to answer.
 */
export async function requireAdmin(
  request: Request,
  createUserClient: UserClientFactory,
): Promise<AdminAuthResult> {
  const authorization = bearerAuthorization(request);
  if (authorization === null) return failure("AUTH_REQUIRED");

  let client: AdminAuthClient;
  try {
    client = createUserClient(authorization);
  } catch {
    return failure("TEMPORARY_BACKEND_FAILURE");
  }

  // 1. Identity, from the JWT alone. An expired or tampered token fails here.
  let userId: string;
  let email: string | null;
  try {
    const { data, error } = await client.auth.getUser();
    const user = data?.user;
    if (error || !user || typeof user.id !== "string") {
      return failure("AUTH_REQUIRED");
    }
    if (user.is_anonymous === true) {
      return failure("ADMIN_UNAUTHORIZED");
    }
    userId = user.id;
    email = typeof user.email === "string" && user.email.length > 0
      ? user.email
      : null;
  } catch (error) {
    console.error(
      `[admin-auth] getUser threw type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return failure("TEMPORARY_BACKEND_FAILURE");
  }

  // 2. The roster answer, for this session only.
  try {
    const result = await client.rpc("current_user_is_admin");
    if (result?.error) {
      console.error(
        `[admin-auth] rpc failed code=${result.error?.code ?? "unknown"}`,
      );
      return failure("TEMPORARY_BACKEND_FAILURE");
    }
    if (result?.data !== true) {
      return failure("ADMIN_UNAUTHORIZED");
    }
  } catch (error) {
    console.error(
      `[admin-auth] rpc threw type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return failure("TEMPORARY_BACKEND_FAILURE");
  }

  return { ok: true, userId, email, role: "admin" };
}

/** Sanitized, actionable message for a refusal. Never names an account. */
export function adminAuthMessage(code: AdminAuthErrorCode): string {
  switch (code) {
    case "AUTH_REQUIRED":
      return "Sign in to continue.";
    case "ADMIN_UNAUTHORIZED":
      return "This account is not authorized to use the FaceTune Admin.";
    case "TEMPORARY_BACKEND_FAILURE":
      return "Authorization could not be verified. Please try again.";
  }
}

/** The error body every protected admin function returns, in the project's existing shape. */
export function adminAuthErrorBody(failure: AdminAuthFailure) {
  return {
    error: {
      code: failure.errorCode,
      message: adminAuthMessage(failure.errorCode),
      retryable: failure.errorCode === "TEMPORARY_BACKEND_FAILURE",
    },
  };
}
