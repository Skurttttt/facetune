import { assertEquals, assertRejects } from "jsr:@std/assert@1";

import { requestGeometry } from "./gemini_client.ts";
import { FunctionFailure } from "./types.ts";

const selfie = {
  bytes: new Uint8Array([255, 216, 255]),
  mimeType: "image/jpeg",
};

interface Capture {
  url: string;
  init: RequestInit;
}

async function withFetch<T>(
  responses: Array<() => Response>,
  body: (captures: Capture[]) => Promise<T>,
): Promise<T> {
  const captures: Capture[] = [];
  const original = globalThis.fetch;
  let index = 0;
  globalThis.fetch = ((url: string | URL | Request, init?: RequestInit) => {
    captures.push({ url: String(url), init: init ?? {} });
    const next = responses[Math.min(index, responses.length - 1)];
    index += 1;
    return Promise.resolve(next());
  }) as typeof fetch;
  try {
    return await body(captures);
  } finally {
    globalThis.fetch = original;
  }
}

function googleError(
  status: number,
  apiStatus: string,
  message: string,
  reason?: string,
): () => Response {
  return () =>
    new Response(
      JSON.stringify({
        error: {
          code: status,
          message,
          status: apiStatus,
          details: reason ? [{ reason, domain: "googleapis.com" }] : undefined,
        },
      }),
      { status, headers: { "content-type": "application/json" } },
    );
}

async function failureFrom(
  responses: Array<() => Response>,
): Promise<{ failure: FunctionFailure; attempts: number }> {
  return await withFetch(responses, async (captures) => {
    const failure = await assertRejects(
      () => requestGeometry("test-key", "gemini-3.6-flash", "prompt", selfie),
      FunctionFailure,
    );
    return { failure, attempts: captures.length };
  });
}

Deno.test("the mapper sends exactly one image to the proven endpoint", async () => {
  await withFetch([
    () =>
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: "{}" }] } }],
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
  ], async (captures) => {
    await requestGeometry("test-key", "gemini-3.6-flash", "prompt", selfie);

    assertEquals(
      captures[0].url,
      "https://generativelanguage.googleapis.com/v1beta/models/" +
        "gemini-3.6-flash:generateContent",
    );
    const sent = JSON.parse(captures[0].init.body as string);
    // The canonical final preview is never an input to the mapper (§14).
    const parts = sent.contents[0].parts as Array<Record<string, unknown>>;
    assertEquals(
      parts.filter((part) => part.inlineData !== undefined).length,
      1,
    );
  });
});

Deno.test("a deterministic 400 is a configuration fault, attempted once", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(400, "INVALID_ARGUMENT", "Invalid JSON payload received."),
  ]);

  assertEquals(attempts, 1);
  assertEquals(failure.status, 500);
  assertEquals(failure.code, "gemini_invalid_request");
  assertEquals(failure.retryable, false);
});

Deno.test("a rejected API key is separated from an invalid request", async () => {
  const { failure } = await failureFrom([
    googleError(
      400,
      "INVALID_ARGUMENT",
      "API key not valid.",
      "API_KEY_INVALID",
    ),
  ]);

  assertEquals(failure.code, "gemini_credential_rejected");
  assertEquals(failure.retryable, false);
});

Deno.test("the V3-6R transient 503 is still absorbed by one retry", async () => {
  await withFetch([
    googleError(503, "UNAVAILABLE", "high demand"),
    () =>
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: "{}" }] } }],
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
  ], async (captures) => {
    assertEquals(
      await requestGeometry("test-key", "gemini-3.6-flash", "prompt", selfie),
      "{}",
    );
    assertEquals(captures.length, 2);
  });
});

Deno.test("a rate limit stays retryable, a missing model does not", async () => {
  const limited = await failureFrom([
    googleError(429, "RESOURCE_EXHAUSTED", "Quota exceeded."),
  ]);
  assertEquals(limited.failure.code, "gemini_rate_limited");
  assertEquals(limited.failure.retryable, true);

  const missing = await failureFrom([
    googleError(404, "NOT_FOUND", "models/nope is not found."),
  ]);
  assertEquals(missing.attempts, 1);
  assertEquals(missing.failure.code, "GEMINI_MODEL_NOT_FOUND");
  assertEquals(missing.failure.retryable, false);
});

Deno.test("image bytes in the response remain a configuration fault", async () => {
  const { failure } = await failureFrom([
    () =>
      new Response(
        JSON.stringify({
          candidates: [{
            content: { parts: [{ inlineData: { data: "AAAA" } }] },
          }],
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
  ]);

  assertEquals(failure.code, "unexpected_image_output");
});
