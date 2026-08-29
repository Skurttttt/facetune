import {
  assert,
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "jsr:@std/assert@1";

import { requestTutorialV3Plan } from "./gemini_client.ts";
import { type PlannerInput } from "./prompt.ts";
import { TUTORIAL_V3_PLAN_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const canonicalImage = {
  bytes: new Uint8Array([137, 80, 78, 71]),
  mimeType: "image/png",
};

function plannerInput(overrides: Partial<PlannerInput> = {}): PlannerInput {
  return {
    style: "soft_glam",
    sourceMode: "standard",
    attributes: { face_shape: "round" },
    recommendation: { blush: { name: "Soft rose" } },
    ownedProducts: [],
    ...overrides,
  };
}

interface Capture {
  url: string;
  init: RequestInit;
}

/**
 * Replaces `fetch` for one call, recording every request and answering with
 * the supplied responses in order. The last response repeats.
 */
async function withFetch<T>(
  responses: Array<() => Response | Promise<Response>>,
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

const emptyPlan = JSON.stringify({ steps: [] });

function planResponse(): Response {
  return new Response(
    JSON.stringify({
      candidates: [{
        content: { parts: [{ text: emptyPlan }] },
        finishReason: "STOP",
      }],
    }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

/**
 * Requests that carry the real planner prompt.
 *
 * Every request the client makes is now a planner attempt — the V3-10F4
 * diagnostic probe matrix has been removed. This filter stays so the retry
 * assertions keep measuring the thing they name, and so a probe re-introduced
 * on this code path fails the test below rather than inflating a count
 * silently.
 */
function plannerAttempts(captures: Capture[]): number {
  return captures.filter((capture) =>
    String(capture.init.body ?? "").includes("SELECTED LOOK")
  ).length;
}

async function failureFrom(
  responses: Array<() => Response | Promise<Response>>,
): Promise<{ failure: FunctionFailure; attempts: number }> {
  return await withFetch(responses, async (captures) => {
    const failure = await assertRejects(
      () =>
        requestTutorialV3Plan(
          "test-key",
          "gemini-3.6-flash",
          plannerInput(),
          canonicalImage,
        ),
      FunctionFailure,
    );
    return { failure, attempts: plannerAttempts(captures) };
  });
}

Deno.test("the request keeps the proven endpoint and structured-output contract", async () => {
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "test-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );

    assertEquals(captures.length, 1);
    const [capture] = captures;
    assertEquals(
      capture.url,
      "https://generativelanguage.googleapis.com/v1beta/models/" +
        "gemini-3.6-flash:generateContent",
    );

    const sent = JSON.parse(capture.init.body as string);
    assertEquals(Object.keys(sent).sort(), ["contents", "generationConfig"]);
    assertEquals(
      Object.keys(sent.generationConfig).sort(),
      [
        "candidateCount",
        "maxOutputTokens",
        "responseJsonSchema",
        "responseMimeType",
        "temperature",
        "topP",
      ],
    );
    assertEquals(sent.generationConfig.responseMimeType, "application/json");
    assertEquals(sent.generationConfig.candidateCount, 1);
    assert(sent.generationConfig.responseJsonSchema !== undefined);

    // One text part plus exactly one image: the canonical final preview the
    // planner decomposes. A second image is what V3-6A.2 proved drives style
    // transfer, and it has no place here either.
    assertEquals(sent.contents.length, 1);
    assertEquals(sent.contents[0].role, "user");
    const parts = sent.contents[0].parts as Array<Record<string, unknown>>;
    assertEquals(parts.length, 2);
    assertEquals(typeof parts[0].text, "string");
    assertEquals(
      (parts[1].inlineData as Record<string, unknown>).mimeType,
      "image/png",
    );
  });
});

Deno.test("the serialized request carries no steps.maxItems", async () => {
  // The V3-10F4.4 defect, asserted on the bytes Gemini actually receives.
  // Production bisection proved `properties.steps.maxItems` is the single
  // construct that makes `gemini-3.6-flash` answer 400 INVALID_ARGUMENT, while
  // `minItems` and the two inner `maxItems` were accepted in the same request.
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "test-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );
    const schema = JSON.parse(captures[0].init.body as string)
      .generationConfig.responseJsonSchema;
    const steps = schema.properties.steps;
    const stepProperties = steps.items.properties;

    // The one thing that must be gone.
    assertEquals(steps.maxItems, undefined);

    // Everything the same bisection cleared must still be here — removing more
    // than the defect would be a different, unproven change.
    assertEquals(steps.minItems, 1);
    assertEquals(stepProperties.target_look_cues.maxItems, 4);
    assertEquals(stepProperties.target_look_cues.minItems, 1);
    assertEquals(
      stepProperties.guideline_visual_intent.properties.graphics.maxItems,
      5,
    );
    assertEquals(
      stepProperties.guideline_visual_intent.properties.graphics.minItems,
      1,
    );
    // Nullability stays as a union type: rewriting it to `anyOf` was probed
    // and left the request rejected.
    assertEquals(stepProperties.product_id.type, ["string", "null"]);
  });
});

Deno.test("the diagnostic change transmits the schema unaltered", async () => {
  // V3-10F4.1 ships error-body parsing and classification ONLY. The bytes
  // Gemini receives must be identical to the deployed build's, so the
  // diagnostic run reproduces the real 400 rather than a different request
  // that happens to fail differently.
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "test-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );
    const sent = JSON.parse(captures[0].init.body as string);

    assertEquals(
      sent.generationConfig.responseJsonSchema,
      JSON.parse(JSON.stringify(TUTORIAL_V3_PLAN_SCHEMA)),
    );
  });
});

Deno.test("a successful plan is returned verbatim, untouched by the new path", async () => {
  // The error parser must not sit anywhere on the success path: a 200 returns
  // the model's text exactly, with one request and no retry.
  await withFetch([planResponse], async (captures) => {
    const raw = await requestTutorialV3Plan(
      "test-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );

    assertEquals(raw, emptyPlan);
    assertEquals(captures.length, 1);
  });
});

Deno.test("the model name is URL-encoded into the endpoint", async () => {
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "test-key",
      "models/weird name",
      plannerInput(),
      canonicalImage,
    );
    assertStringIncludes(
      captures[0].url,
      "models%2Fweird%20name:generateContent",
    );
  });
});

Deno.test("the API key travels in the header and never in the URL or body", async () => {
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "super-secret-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );
    const headers = captures[0].init.headers as Record<string, string>;
    assertEquals(headers["x-goog-api-key"], "super-secret-key");
    assert(!captures[0].url.includes("super-secret-key"));
    assert(!(captures[0].init.body as string).includes("super-secret-key"));
  });
});

Deno.test("a failed request logs the diagnosis and nothing sensitive", async () => {
  // The whole point of the diagnostic deployment is that these lines are the
  // only new thing production emits. Captured for real rather than reasoned
  // about, with a prompt and image present and a Gemini error that echoes the
  // request back.
  const secretKey = "AIzaSyD-0000000000000000000000000000000";
  const lines: string[] = [];
  const originalError = console.error;
  console.error = (...args: unknown[]) => {
    lines.push(args.map(String).join(" "));
  };
  try {
    await withFetch([
      googleError(
        400,
        "INVALID_ARGUMENT",
        `Invalid JSON payload received. Unknown name "x" at ` +
          `generation_config. key=${secretKey} data=${"QUJDRA".repeat(30)}`,
      ),
    ], async () => {
      await assertRejects(
        () =>
          requestTutorialV3Plan(
            secretKey,
            "gemini-3.6-flash",
            plannerInput(),
            { bytes: new Uint8Array(4096).fill(65), mimeType: "image/png" },
          ),
        FunctionFailure,
      );
    });
  } finally {
    console.error = originalError;
  }

  const logged = lines.join("\n");
  assert(logged.length > 0, "the failure must be diagnosable at all");

  // It says what went wrong.
  assertStringIncludes(logged, "api_status=INVALID_ARGUMENT");
  assertStringIncludes(logged, "kind=invalid_request");
  assertStringIncludes(logged, "retryable=false");

  // It says nothing else.
  for (
    const forbidden of [
      secretKey,
      "AIzaSy",
      "QUJDRAQUJDRA", // inline image data echoed back
      "Bearer",
      "authorization",
      "x-goog-api-key",
      "SELECTED LOOK", // the prompt
      "soft_glam",
      "Soft rose", // the persisted recommendation
    ]
  ) {
    assert(
      !logged.includes(forbidden),
      `"${forbidden}" must never be logged`,
    );
  }

  // And it stays bounded: one line per attempt, not a payload dump.
  for (const line of lines) {
    assert(line.length <= 500, `log line was ${line.length} chars`);
  }
});

Deno.test("an invalid request fails permanently and is attempted once", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(
      400,
      "INVALID_ARGUMENT",
      "Invalid JSON payload received at generation_config.response_json_schema.",
    ),
  ]);

  assertEquals(attempts, 1, "a deterministic 400 must not be retried");
  assertEquals(failure.status, 500);
  assertEquals(failure.code, "gemini_invalid_request");
  assertEquals(failure.retryable, false);
  assertEquals(
    failure.message,
    "The tutorial service is not configured correctly.",
  );
});

Deno.test("no synthetic diagnostic probe is reachable in production", async () => {
  // The V3-10F4 bisection matrix has been removed now that it has done its job.
  // A user hitting any failure must cost exactly the requests the retry policy
  // allows — never a burst of extra synthetic calls to the model.
  const probeCount = (captures: Capture[]) =>
    captures.filter((capture) =>
      String(capture.init.body ?? "").includes(
        "Reply with the shortest valid answer.",
      )
    ).length;

  // Success.
  await withFetch([planResponse], async (captures) => {
    await requestTutorialV3Plan(
      "test-key",
      "gemini-3.6-flash",
      plannerInput(),
      canonicalImage,
    );
    assertEquals(probeCount(captures), 0, "a successful plan must not probe");
    assertEquals(captures.length, 1, "success is exactly one request");
  });

  // Non-invalid-request failures.
  for (
    const response of [
      googleError(429, "RESOURCE_EXHAUSTED", "Quota exceeded."),
      googleError(503, "UNAVAILABLE", "Overloaded."),
      googleError(404, "NOT_FOUND", "models/nope is not found."),
      googleError(400, "INVALID_ARGUMENT", "API key not valid.", "API_KEY_INVALID"),
    ]
  ) {
    await withFetch([response], async (captures) => {
      await assertRejects(
        () =>
          requestTutorialV3Plan(
            "test-key",
            "gemini-3.6-flash",
            plannerInput(),
            canonicalImage,
          ),
        FunctionFailure,
      );
      assertEquals(probeCount(captures), 0, "no failure may trigger a probe");
    });
  }
});

Deno.test("an invalid request is still measured for the next diagnosis", async () => {
  const lines: string[] = [];
  const originalError = console.error;
  console.error = (...args: unknown[]) => lines.push(args.map(String).join(" "));
  try {
    await withFetch([
      googleError(400, "INVALID_ARGUMENT", "Request contains an invalid argument."),
    ], async () => {
      await assertRejects(
        () =>
          requestTutorialV3Plan(
            "test-key",
            "gemini-3.6-flash",
            plannerInput(),
            canonicalImage,
          ),
        FunctionFailure,
      );
    });
  } finally {
    console.error = originalError;
  }

  const metrics = lines.find((line) => line.includes("request_metrics"));
  assert(metrics !== undefined, "the request was never measured");
  // Sizes and MIME identify a payload fault; none of them is content.
  for (
    const field of [
      "body_bytes=",
      "image_bytes=",
      "image_mime=image/png",
      "image_magic=",
      "schema_bytes=",
    ]
  ) {
    assertStringIncludes(metrics, field);
  }
  // The 4-byte PNG signature of the fixture, proving a declared MIME that
  // disagreed with the real bytes would be visible.
  assertStringIncludes(metrics, "image_magic=89504e47");
  assert(!metrics.includes("SELECTED LOOK"), "metrics must not carry the prompt");
});

Deno.test("a rejected API key is not reported as an invalid request", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(
      400,
      "INVALID_ARGUMENT",
      "API key not valid. Please pass a valid API key.",
      "API_KEY_INVALID",
    ),
  ]);

  assertEquals(attempts, 1);
  assertEquals(failure.code, "gemini_credential_rejected");
  assertEquals(failure.retryable, false);
});

Deno.test("a billing precondition is its own permanent code", async () => {
  const { failure } = await failureFrom([
    googleError(400, "FAILED_PRECONDITION", "Billing is not enabled."),
  ]);

  assertEquals(failure.code, "gemini_account_precondition");
  assertEquals(failure.retryable, false);
});

Deno.test("a missing model stays a configuration fault, once", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(404, "NOT_FOUND", "models/nope is not found."),
  ]);

  assertEquals(attempts, 1);
  assertEquals(failure.status, 500);
  assertEquals(failure.code, "GEMINI_MODEL_NOT_FOUND");
  assertEquals(failure.retryable, false);
});

Deno.test("a rate limit is retried once, then reported as retryable", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(429, "RESOURCE_EXHAUSTED", "Quota exceeded."),
  ]);

  assertEquals(attempts, 2);
  assertEquals(failure.status, 503);
  assertEquals(failure.code, "gemini_rate_limited");
  assertEquals(failure.retryable, true);
  assertEquals(
    failure.message,
    "The tutorial service is temporarily unavailable.",
  );
});

Deno.test("a transient upstream failure is retried once and can succeed", async () => {
  await withFetch(
    [googleError(503, "UNAVAILABLE", "The model is overloaded."), planResponse],
    async (captures) => {
      const raw = await requestTutorialV3Plan(
        "test-key",
        "gemini-3.6-flash",
        plannerInput(),
        canonicalImage,
      );
      assertEquals(raw, emptyPlan);
      assertEquals(captures.length, 2);
    },
  );
});

Deno.test("retries stay bounded at two attempts", async () => {
  const { failure, attempts } = await failureFrom([
    googleError(500, "INTERNAL", "Internal error."),
  ]);

  assertEquals(attempts, 2);
  assertEquals(failure.code, "gemini_upstream_error");
});

Deno.test("a timeout is classified as a timeout, not an upstream error", async () => {
  const timeout = (): Response => {
    throw new DOMException("timed out", "TimeoutError");
  };
  const { failure } = await failureFrom([timeout, timeout]);

  assertEquals(failure.status, 504);
  assertEquals(failure.code, "gemini_timeout");
  assertEquals(failure.retryable, true);
});

Deno.test("an unreachable network is its own retryable code", async () => {
  const offline = (): Response => {
    throw new TypeError("error sending request");
  };
  const { failure } = await failureFrom([offline, offline]);

  assertEquals(failure.status, 503);
  assertEquals(failure.code, "gemini_network_error");
  assertEquals(failure.retryable, true);
});

Deno.test("a safety block is a refusal, not an outage", async () => {
  const { failure } = await failureFrom([
    () =>
      new Response(
        JSON.stringify({ promptFeedback: { blockReason: "SAFETY" } }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
  ]);

  assertEquals(failure.status, 422);
  assertEquals(failure.code, "gemini_refusal");
});

Deno.test("a truncated plan is retryable and named", async () => {
  const { failure } = await failureFrom([
    () =>
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [] }, finishReason: "MAX_TOKENS" }],
        }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
  ]);

  assertEquals(failure.code, "plan_truncated");
  assertEquals(failure.retryable, true);
});
