/**
 * Server-side Tutorial authorization (SUB-12B).
 *
 * Wraps `public.authorize_tutorial_generation(...)`, the database function that
 * decides whether a NEW Tutorial may be generated for a Final Preview: the
 * account's governing plan must include the Tutorial, and the preview itself
 * must have been produced under a Tutorial-capable allowance unit. Both facts
 * come from product capability rows, never from a plan name compared here.
 *
 * Called by the two Tutorial V4 Edge Functions after they have returned any
 * already-generated manifest or step, so reopening historical Tutorial content
 * is never gated, and before any paid work, so a refusal costs nothing.
 *
 * Fails closed. An unreachable or malformed authorizer denies rather than
 * letting a Preview-only account generate a Tutorial while the gate is down.
 *
 * The function derives the account from the request JWT; these helpers take no
 * user id and offer no way to name another account.
 */

/** Which pipeline a canonical Final Preview came from, in Tutorial vocabulary. */
export type TutorialSourceMode = "standard" | "my_makeup_kit";

export interface TutorialAuthorization {
  authorized: boolean;
  /** Shared sanitized code, e.g. `TUTORIAL_NOT_INCLUDED`. Null when authorized. */
  denialReason: string | null;
  /** The governing plan, when the authorizer reported one. */
  planCode: string | null;
  planDisplayName: string | null;
}

/** Minimal Supabase surface, loose for the reason given in `ai_quota.ts`. */
export interface TutorialAuthorizationClient {
  // deno-lint-ignore no-explicit-any
  rpc: (...args: any[]) => any;
}

const denied = (reason: string): TutorialAuthorization => ({
  authorized: false,
  denialReason: reason,
  planCode: null,
  planDisplayName: null,
});

function decode(payload: unknown): TutorialAuthorization {
  if (typeof payload !== "object" || payload === null) {
    return denied("TEMPORARY_BACKEND_FAILURE");
  }
  const value = payload as Record<string, unknown>;
  const authorized = value.ok === true && value.authorized === true;
  return {
    authorized,
    denialReason: authorized
      ? null
      : typeof value.denialReason === "string"
      ? value.denialReason
      : "TEMPORARY_BACKEND_FAILURE",
    planCode: typeof value.planCode === "string" ? value.planCode : null,
    planDisplayName: typeof value.planDisplayName === "string"
      ? value.planDisplayName
      : null,
  };
}

async function authorize(
  client: TutorialAuthorizationClient,
  args: Record<string, unknown>,
): Promise<TutorialAuthorization> {
  try {
    const result = await client.rpc("authorize_tutorial_generation", args);
    if (result?.error) {
      console.error(
        `[tutorial-authorization] rpc failed code=${
          result.error?.code ?? "unknown"
        }`,
      );
      return denied("TEMPORARY_BACKEND_FAILURE");
    }
    return decode(result?.data);
  } catch (error) {
    console.error(
      `[tutorial-authorization] rpc threw type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return denied("TEMPORARY_BACKEND_FAILURE");
  }
}

/** Authorizes a new Tutorial for a canonical preview the caller owns. */
export function authorizeTutorialForPreview(
  client: TutorialAuthorizationClient,
  sourceMode: TutorialSourceMode,
  canonicalPreviewId: string,
): Promise<TutorialAuthorization> {
  return authorize(client, {
    p_source_mode: sourceMode,
    p_canonical_preview_id: canonicalPreviewId,
    p_tutorial_session_id: null,
  });
}

/** Authorizes new step generation within an existing session the caller owns. */
export function authorizeTutorialForSession(
  client: TutorialAuthorizationClient,
  tutorialSessionId: string,
): Promise<TutorialAuthorization> {
  return authorize(client, {
    p_source_mode: null,
    p_canonical_preview_id: null,
    p_tutorial_session_id: tutorialSessionId,
  });
}

/** Sanitized Edge Function error code for a refusal. */
export function tutorialDenialCode(denialReason: string | null): string {
  switch (denialReason) {
    case "TUTORIAL_NOT_INCLUDED":
      return "tutorial_not_included";
    case "AUTH_REQUIRED":
      return "authentication_required";
    case "ENTITLEMENT_NOT_FOUND":
      return "entitlement_not_found";
    case "TUTORIAL_SOURCE_NOT_FOUND":
      return "canonical_preview_not_found";
    default:
      return "tutorial_authorization_unavailable";
  }
}

/** HTTP status for a refusal. */
export function tutorialDenialStatus(denialReason: string | null): number {
  switch (denialReason) {
    case "AUTH_REQUIRED":
      return 401;
    case "TUTORIAL_NOT_INCLUDED":
    case "ENTITLEMENT_NOT_FOUND":
      return 403;
    case "TUTORIAL_SOURCE_NOT_FOUND":
      return 404;
    default:
      return 503;
  }
}

/** User-facing copy for a refusal. Never exposes internal entitlement state. */
export function tutorialDenialMessage(
  authorization: TutorialAuthorization,
): string {
  switch (authorization.denialReason) {
    case "TUTORIAL_NOT_INCLUDED":
      return authorization.planDisplayName
        ? `Step-by-Step Tutorials are not included in ${authorization.planDisplayName}. ` +
          "Looks created on a plan that includes the Tutorial keep theirs."
        : "Step-by-Step Tutorials are not included in your current plan.";
    case "AUTH_REQUIRED":
      return "Sign in again to continue.";
    case "ENTITLEMENT_NOT_FOUND":
      return "Your subscription could not be found. Please try again shortly.";
    case "TUTORIAL_SOURCE_NOT_FOUND":
      return "The final look could not be found.";
    default:
      return "Tutorials are temporarily unavailable. Please try again shortly.";
  }
}

/** Whether a refusal is worth the client retrying as-is. */
export function tutorialDenialRetryable(denialReason: string | null): boolean {
  return denialReason === "TEMPORARY_BACKEND_FAILURE";
}
