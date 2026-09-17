import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";

import { GooglePlayApi, parseServiceAccount } from "./google_play_api.ts";
import { VerificationFailure } from "./verification.ts";

// The API layer is exercised over a stubbed transport rather than a mock
// object, so the code under test is the real fetch path: the URLs it builds,
// the status codes it maps, and the order it calls things in.

const packageName = "io.facetune.app";

/// A real RSA key, generated per run.
///
/// Signing genuinely happens in these tests — a fake key would skip the one
/// part of the credential path most likely to be wrong.
async function serviceAccountJson(): Promise<string> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 2048,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(
    await crypto.subtle.exportKey("pkcs8", pair.privateKey),
  );
  let binary = "";
  for (const byte of pkcs8) binary += String.fromCharCode(byte);
  const lines = btoa(binary).match(/.{1,64}/g) ?? [];
  return JSON.stringify({
    client_email: "facetune@example.iam.gserviceaccount.com",
    private_key:
      `-----BEGIN PRIVATE KEY-----\n${lines.join("\n")}\n-----END PRIVATE KEY-----\n`,
  });
}

interface Call {
  url: string;
  method: string;
}

/// Replaces `fetch` for the duration of [run], recording every call.
async function withStubbedFetch(
  handler: (url: string, init?: RequestInit) => Response,
  run: (calls: Call[]) => Promise<void>,
): Promise<void> {
  const original = globalThis.fetch;
  const calls: Call[] = [];
  globalThis.fetch = ((input: string | URL | Request, init?: RequestInit) => {
    const url = typeof input === "string" ? input : input.toString();
    calls.push({ url, method: init?.method ?? "GET" });
    return Promise.resolve(handler(url, init));
  }) as typeof fetch;
  try {
    await run(calls);
  } finally {
    globalThis.fetch = original;
  }
}

function tokenResponse(): Response {
  return new Response(
    JSON.stringify({ access_token: "test-access-token", expires_in: 3600 }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

async function api(): Promise<GooglePlayApi> {
  return new GooglePlayApi(
    parseServiceAccount(await serviceAccountJson()),
    packageName,
  );
}

// ---------------------------------------------------------------------------
// Credential handling
// ---------------------------------------------------------------------------

Deno.test("a malformed service account is a configuration error", () => {
  for (const raw of ["", "not json", "{}", '{"client_email":"a@b"}']) {
    let threw = false;
    try {
      parseServiceAccount(raw);
    } catch (error) {
      threw = true;
      assert(error instanceof VerificationFailure);
      assertEquals((error as VerificationFailure).status, 500);
      // The message says nothing about what was wrong with the credential.
      assertEquals(
        (error as VerificationFailure).message,
        "Purchase verification is not configured.",
      );
    }
    assert(threw, `expected a failure for ${JSON.stringify(raw)}`);
  }
});

// ---------------------------------------------------------------------------
// Reading a subscription
// ---------------------------------------------------------------------------

Deno.test("the subscription request is scoped to this app's package", async () => {
  const client = await api();
  await withStubbedFetch(
    (url) =>
      url.includes("oauth2.googleapis.com")
        ? tokenResponse()
        : new Response(JSON.stringify({ subscriptionState: "x" }), {
          status: 200,
        }),
    async (calls) => {
      await client.getSubscription("token-abc");

      const read = calls.find((call) => call.url.includes("androidpublisher"));
      assert(read, "expected an Android Publisher call");
      // Package-scoped and on the v2 resource. A token issued for another app
      // cannot resolve against this URL at all, which is what makes "wrong
      // package" a 404 from Google rather than a check of our own.
      assert(read.url.includes(`/applications/${packageName}/`));
      assert(read.url.includes("/purchases/subscriptionsv2/tokens/token-abc"));
    },
  );
});

Deno.test("a token Google does not recognise is refused, not retried", async () => {
  for (const status of [404, 400]) {
    const client = await api();
    await withStubbedFetch(
      (url) =>
        url.includes("oauth2.googleapis.com")
          ? tokenResponse()
          : new Response("{}", { status }),
      async () => {
        const error = await assertRejects(
          () => client.getSubscription("fabricated-token"),
          VerificationFailure,
        );
        // A fabricated token, or one belonging to a different package.
        assertEquals(error.code, "PURCHASE_VERIFICATION_FAILED");
        assertEquals(error.retryable, false);
      },
    );
  }
});

Deno.test("a credential rejection is reported as our outage, not the user's", async () => {
  for (const status of [401, 403]) {
    const client = await api();
    await withStubbedFetch(
      (url) =>
        url.includes("oauth2.googleapis.com")
          ? tokenResponse()
          : new Response("{}", { status }),
      async () => {
        const error = await assertRejects(
          () => client.getSubscription("token-abc"),
          VerificationFailure,
        );
        assertEquals(error.code, "TEMPORARY_BACKEND_FAILURE");
        assertEquals(error.retryable, true);
      },
    );
  }
});

Deno.test("a provider outage returns a sanitized retryable failure", async () => {
  const client = await api();
  await withStubbedFetch(
    (url) =>
      url.includes("oauth2.googleapis.com")
        ? tokenResponse()
        : new Response("upstream exploded: internal detail", { status: 500 }),
    async () => {
      const error = await assertRejects(
        () => client.getSubscription("token-abc"),
        VerificationFailure,
      );
      assertEquals(error.code, "TEMPORARY_BACKEND_FAILURE");
      // The provider's body never becomes the user's message.
      assertEquals(error.message.includes("internal detail"), false);
    },
  );
});

Deno.test("a rejected credential exchange never leaks the reason", async () => {
  const client = await api();
  await withStubbedFetch(
    () =>
      new Response(
        JSON.stringify({
          error: "invalid_grant",
          error_description: "account facetune@example.iam not authorized",
        }),
        { status: 400 },
      ),
    async () => {
      const error = await assertRejects(
        () => client.getSubscription("token-abc"),
        VerificationFailure,
      );
      assertEquals(error.code, "TEMPORARY_BACKEND_FAILURE");
      assertEquals(error.message.includes("facetune@example.iam"), false);
      assertEquals(error.message.includes("invalid_grant"), false);
    },
  );
});

Deno.test("the access token is minted once and reused", async () => {
  const client = await api();
  await withStubbedFetch(
    (url) =>
      url.includes("oauth2.googleapis.com")
        ? tokenResponse()
        : new Response(JSON.stringify({ subscriptionState: "x" }), {
          status: 200,
        }),
    async (calls) => {
      await client.getSubscription("token-1");
      await client.getSubscription("token-2");
      await client.getSubscription("token-3");

      const tokenCalls = calls.filter((call) =>
        call.url.includes("oauth2.googleapis.com")
      );
      assertEquals(tokenCalls.length, 1);
    },
  );
});

Deno.test("the assertion is a signed RS256 JWT for the publisher scope", async () => {
  const client = await api();
  let assertion = "";
  await withStubbedFetch(
    (url, init) => {
      if (url.includes("oauth2.googleapis.com")) {
        const body = new URLSearchParams(init?.body as string);
        assertEquals(
          body.get("grant_type"),
          "urn:ietf:params:oauth:grant-type:jwt-bearer",
        );
        assertion = body.get("assertion") ?? "";
        return tokenResponse();
      }
      return new Response("{}", { status: 200 });
    },
    async () => {
      await client.getSubscription("token-abc");
    },
  );

  const [header, claims, signature] = assertion.split(".");
  const decode = (part: string) =>
    JSON.parse(atob(part.replace(/-/g, "+").replace(/_/g, "/")));
  assertEquals(decode(header).alg, "RS256");
  const payload = decode(claims);
  assertEquals(payload.aud, "https://oauth2.googleapis.com/token");
  assertEquals(payload.scope, "https://www.googleapis.com/auth/androidpublisher");
  assert(payload.exp > payload.iat);
  assert(signature.length > 0);
});

// ---------------------------------------------------------------------------
// Acknowledgement
// ---------------------------------------------------------------------------

Deno.test("acknowledgement posts to the package-scoped acknowledge endpoint", async () => {
  const client = await api();
  await withStubbedFetch(
    (url) =>
      url.includes("oauth2.googleapis.com")
        ? tokenResponse()
        : new Response("", { status: 200 }),
    async (calls) => {
      const acknowledged = await client.acknowledgeSubscription(
        "token-abc",
        "facetune_pro",
      );
      assertEquals(acknowledged, true);

      const call = calls.find((entry) => entry.url.includes(":acknowledge"));
      assert(call, "expected an acknowledge call");
      assertEquals(call.method, "POST");
      assert(call.url.includes(`/applications/${packageName}/`));
      assert(call.url.includes("/purchases/subscriptions/facetune_pro/"));
      assert(call.url.includes("/tokens/token-abc:acknowledge"));
    },
  );
});

Deno.test("a failed acknowledgement is reported, not thrown", async () => {
  // The entitlement is already granted by this point, so a failure here must
  // not turn a successful purchase into an error for the user.
  const client = await api();
  await withStubbedFetch(
    (url) =>
      url.includes("oauth2.googleapis.com")
        ? tokenResponse()
        : new Response("", { status: 500 }),
    async () => {
      assertEquals(
        await client.acknowledgeSubscription("token-abc", "facetune_pro"),
        false,
      );
    },
  );
});

Deno.test("a network failure during acknowledgement is contained", async () => {
  const client = await api();
  const original = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const url = typeof input === "string" ? input : input.toString();
    if (url.includes("oauth2.googleapis.com")) {
      return Promise.resolve(tokenResponse());
    }
    return Promise.reject(new TypeError("network down"));
  }) as typeof fetch;
  try {
    assertEquals(
      await client.acknowledgeSubscription("token-abc", "facetune_pro"),
      false,
    );
  } finally {
    globalThis.fetch = original;
  }
});
