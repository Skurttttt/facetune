import { assertEquals } from "jsr:@std/assert@1";

import {
  authorizeTutorialForPreview,
  authorizeTutorialForSession,
  tutorialDenialCode,
  tutorialDenialMessage,
  tutorialDenialRetryable,
  tutorialDenialStatus,
} from "./tutorial_authorization.ts";

/// A client whose `rpc` records the call and answers with a fixed payload.
function client(answer: unknown, error: unknown = null) {
  const calls: Array<{ name: string; args: Record<string, unknown> }> = [];
  return {
    calls,
    rpc: (name: string, args: Record<string, unknown>) => {
      calls.push({ name, args });
      return Promise.resolve({ data: answer, error });
    },
  };
}

Deno.test("a preview check names the preview and mode, never an account", async () => {
  const c = client({ ok: true, authorized: true, planCode: "plus" });
  const result = await authorizeTutorialForPreview(c, "my_makeup_kit", "p-1");
  assertEquals(result.authorized, true);
  assertEquals(result.denialReason, null);
  assertEquals(c.calls[0].name, "authorize_tutorial_generation");
  assertEquals(c.calls[0].args, {
    p_source_mode: "my_makeup_kit",
    p_canonical_preview_id: "p-1",
    p_tutorial_session_id: null,
  });
  assertEquals("p_user_id" in c.calls[0].args, false);
});

Deno.test("a session check names only the session", async () => {
  const c = client({ ok: true, authorized: true });
  await authorizeTutorialForSession(c, "s-1");
  assertEquals(c.calls[0].args, {
    p_source_mode: null,
    p_canonical_preview_id: null,
    p_tutorial_session_id: "s-1",
  });
});

Deno.test("a denial carries the reason and the plan for the message", async () => {
  const c = client({
    ok: false,
    authorized: false,
    denialReason: "TUTORIAL_NOT_INCLUDED",
    planCode: "plus_preview",
    planDisplayName: "FaceTune Plus Preview",
  });
  const result = await authorizeTutorialForPreview(c, "standard", "p-1");
  assertEquals(result.authorized, false);
  assertEquals(result.denialReason, "TUTORIAL_NOT_INCLUDED");
  assertEquals(tutorialDenialStatus(result.denialReason), 403);
  assertEquals(
    tutorialDenialCode(result.denialReason),
    "tutorial_not_included",
  );
  assertEquals(tutorialDenialRetryable(result.denialReason), false);
  const message = tutorialDenialMessage(result);
  assertEquals(message.includes("FaceTune Plus Preview"), true);
  assertEquals(message.includes("plus_preview"), false);
});

Deno.test("an rpc error fails closed as a retryable outage", async () => {
  const c = client(null, { code: "PGRST301" });
  const result = await authorizeTutorialForPreview(c, "standard", "p-1");
  assertEquals(result.authorized, false);
  assertEquals(result.denialReason, "TEMPORARY_BACKEND_FAILURE");
  assertEquals(tutorialDenialStatus(result.denialReason), 503);
  assertEquals(tutorialDenialRetryable(result.denialReason), true);
});

Deno.test("a malformed or partial payload never authorizes", async () => {
  for (
    const payload of [null, "yes", 42, {}, { ok: true }, { authorized: true }]
  ) {
    const result = await authorizeTutorialForPreview(
      client(payload),
      "standard",
      "p-1",
    );
    assertEquals(result.authorized, false, JSON.stringify(payload));
  }
});

Deno.test("a thrown rpc fails closed", async () => {
  const c = {
    rpc: () => {
      throw new Error("network");
    },
  };
  const result = await authorizeTutorialForSession(c, "s-1");
  assertEquals(result.authorized, false);
  assertEquals(result.denialReason, "TEMPORARY_BACKEND_FAILURE");
});

Deno.test("every denial maps to a sanitized code and status", () => {
  assertEquals(tutorialDenialCode("AUTH_REQUIRED"), "authentication_required");
  assertEquals(tutorialDenialStatus("AUTH_REQUIRED"), 401);
  assertEquals(
    tutorialDenialCode("ENTITLEMENT_NOT_FOUND"),
    "entitlement_not_found",
  );
  assertEquals(tutorialDenialStatus("ENTITLEMENT_NOT_FOUND"), 403);
  assertEquals(
    tutorialDenialCode("TUTORIAL_SOURCE_NOT_FOUND"),
    "canonical_preview_not_found",
  );
  assertEquals(tutorialDenialStatus("TUTORIAL_SOURCE_NOT_FOUND"), 404);
  assertEquals(
    tutorialDenialCode("SOMETHING_NEW"),
    "tutorial_authorization_unavailable",
  );
  assertEquals(tutorialDenialStatus("SOMETHING_NEW"), 503);
});
