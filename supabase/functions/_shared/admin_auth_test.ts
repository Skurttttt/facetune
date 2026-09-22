import { assertEquals } from "jsr:@std/assert@1";

import {
  adminAuthErrorBody,
  bearerAuthorization,
  requireAdmin,
} from "./admin_auth.ts";

const ADMIN = "11111111-1111-4111-8111-111111111111";

interface FakeUser {
  id: string;
  email?: string | null;
  is_anonymous?: boolean;
  app_metadata?: Record<string, unknown>;
}

/// A client bound to a fixed session outcome. Records every call so a test
/// can prove what the helper did and did not consult.
function fakeClient(opts: {
  user?: FakeUser | null;
  userError?: unknown;
  getUserThrows?: boolean;
  isAdmin?: unknown;
  rpcError?: unknown;
  rpcThrows?: boolean;
}) {
  const calls: string[] = [];
  return {
    calls,
    auth: {
      getUser: () => {
        calls.push("getUser");
        if (opts.getUserThrows) return Promise.reject(new Error("network"));
        return Promise.resolve({
          data: { user: opts.user ?? null },
          error: opts.userError ?? null,
        });
      },
    },
    rpc: (name: string, args?: unknown) => {
      calls.push(
        `rpc:${name}${args === undefined ? "" : ":" + JSON.stringify(args)}`,
      );
      if (opts.rpcThrows) return Promise.reject(new Error("network"));
      return Promise.resolve({
        data: opts.isAdmin,
        error: opts.rpcError ?? null,
      });
    },
  };
}

function request(headers: Record<string, string> = {}, body?: unknown) {
  return new Request("https://example.invalid/admin-session", {
    method: "POST",
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

const BEARER = { authorization: "Bearer eyJ.fake.jwt" };

Deno.test("a valid admin is accepted with only its own identity", async () => {
  const c = fakeClient({
    user: { id: ADMIN, email: "ops@example.invalid" },
    isAdmin: true,
  });
  const authorizations: string[] = [];
  const result = await requireAdmin(request(BEARER), (authorization) => {
    authorizations.push(authorization);
    return c;
  });
  assertEquals(result, {
    ok: true,
    userId: ADMIN,
    email: "ops@example.invalid",
    role: "admin",
  });
  // The client is built from the caller's own header, and both server facts were consulted.
  assertEquals(authorizations, ["Bearer eyJ.fake.jwt"]);
  assertEquals(c.calls, ["getUser", "rpc:current_user_is_admin"]);
});

Deno.test("a normal authenticated user is rejected with 403", async () => {
  const c = fakeClient({ user: { id: ADMIN }, isAdmin: false });
  const result = await requireAdmin(request(BEARER), () => c);
  assertEquals(result, {
    ok: false,
    errorCode: "ADMIN_UNAUTHORIZED",
    status: 403,
  });
});

Deno.test("an unauthenticated request is rejected with 401 before any server call", async () => {
  const c = fakeClient({ user: { id: ADMIN }, isAdmin: true });
  const attempts: Record<string, string>[] = [
    {},
    { authorization: "Basic abc" },
    { authorization: "Bearer " },
    { authorization: "bearer" },
  ];
  for (const headers of attempts) {
    const result = await requireAdmin(request(headers), () => c);
    assertEquals(result, {
      ok: false,
      errorCode: "AUTH_REQUIRED",
      status: 401,
    });
  }
  assertEquals(c.calls, []);
});

Deno.test("an expired or invalid session is rejected with 401 and the roster is not consulted", async () => {
  const expired = fakeClient({
    user: null,
    userError: { message: "token is expired" },
    isAdmin: true,
  });
  assertEquals(await requireAdmin(request(BEARER), () => expired), {
    ok: false,
    errorCode: "AUTH_REQUIRED",
    status: 401,
  });
  assertEquals(expired.calls, ["getUser"]);
  const noUser = fakeClient({ user: null, isAdmin: true });
  assertEquals((await requireAdmin(request(BEARER), () => noUser)).ok, false);
});

Deno.test("an anonymous guest session is rejected even if the roster would say yes", async () => {
  const c = fakeClient({
    user: { id: ADMIN, is_anonymous: true },
    isAdmin: true,
  });
  const result = await requireAdmin(request(BEARER), () => c);
  assertEquals(result, {
    ok: false,
    errorCode: "ADMIN_UNAUTHORIZED",
    status: 403,
  });
  assertEquals(c.calls, ["getUser"]);
});

Deno.test("forged client-side role signals are ignored", async () => {
  // A JWT whose app_metadata claims admin, a header that claims admin, and a
  // body that claims admin — none of them are read; the roster says no.
  const c = fakeClient({
    user: { id: ADMIN, app_metadata: { role: "admin", is_admin: true } },
    isAdmin: false,
  });
  const result = await requireAdmin(
    request({ ...BEARER, "x-admin": "true", "x-role": "admin" }, {
      isAdmin: true,
      role: "admin",
    }),
    () => c,
  );
  assertEquals(result, {
    ok: false,
    errorCode: "ADMIN_UNAUTHORIZED",
    status: 403,
  });
});

Deno.test("a revoked admin is rejected on the next request (the roster answers false)", async () => {
  // Same session, same valid token; only the roster changed.
  const before = fakeClient({ user: { id: ADMIN }, isAdmin: true });
  assertEquals((await requireAdmin(request(BEARER), () => before)).ok, true);
  const after = fakeClient({ user: { id: ADMIN }, isAdmin: false });
  assertEquals(await requireAdmin(request(BEARER), () => after), {
    ok: false,
    errorCode: "ADMIN_UNAUTHORIZED",
    status: 403,
  });
});

Deno.test("the roster call carries no account argument: the session is the identity", async () => {
  const c = fakeClient({ user: { id: ADMIN }, isAdmin: true });
  await requireAdmin(request(BEARER), () => c);
  assertEquals(c.calls[1], "rpc:current_user_is_admin");
});

Deno.test("an unreachable or malformed authorizer fails closed with 503", async () => {
  const rpcError = fakeClient({
    user: { id: ADMIN },
    rpcError: { code: "PGRST301" },
  });
  assertEquals(await requireAdmin(request(BEARER), () => rpcError), {
    ok: false,
    errorCode: "TEMPORARY_BACKEND_FAILURE",
    status: 503,
  });
  const rpcThrows = fakeClient({ user: { id: ADMIN }, rpcThrows: true });
  assertEquals(
    (await requireAdmin(request(BEARER), () => rpcThrows)).ok,
    false,
  );
  const getUserThrows = fakeClient({ getUserThrows: true });
  assertEquals(await requireAdmin(request(BEARER), () => getUserThrows), {
    ok: false,
    errorCode: "TEMPORARY_BACKEND_FAILURE",
    status: 503,
  });
  const factoryThrows = await requireAdmin(request(BEARER), () => {
    throw new Error("no anon key");
  });
  assertEquals(factoryThrows, {
    ok: false,
    errorCode: "TEMPORARY_BACKEND_FAILURE",
    status: 503,
  });
});

Deno.test("a non-boolean roster answer is a refusal, never a yes", async () => {
  for (
    const answer of ["true", 1, null, undefined, { isAdmin: true }, [true]]
  ) {
    const c = fakeClient({ user: { id: ADMIN }, isAdmin: answer });
    assertEquals(
      (await requireAdmin(request(BEARER), () => c)).ok,
      false,
      String(answer),
    );
  }
});

Deno.test("email is optional and never fabricated", async () => {
  const c = fakeClient({ user: { id: ADMIN, email: "" }, isAdmin: true });
  const result = await requireAdmin(request(BEARER), () => c);
  assertEquals(result.ok && result.email, null);
});

Deno.test("bearerAuthorization extracts the header verbatim", () => {
  assertEquals(bearerAuthorization(request(BEARER)), "Bearer eyJ.fake.jwt");
  assertEquals(
    bearerAuthorization(request({ authorization: "BEARER x" })),
    "BEARER x",
  );
  assertEquals(bearerAuthorization(request()), null);
});

Deno.test("error bodies use the project's existing shape and name no account", () => {
  assertEquals(
    adminAuthErrorBody({
      ok: false,
      errorCode: "ADMIN_UNAUTHORIZED",
      status: 403,
    }),
    {
      error: {
        code: "ADMIN_UNAUTHORIZED",
        message: "This account is not authorized to use the FaceTune Admin.",
        retryable: false,
      },
    },
  );
  assertEquals(
    adminAuthErrorBody({
      ok: false,
      errorCode: "TEMPORARY_BACKEND_FAILURE",
      status: 503,
    }).error.retryable,
    true,
  );
});
