import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  describeGeminiError,
  geminiErrorLogLine,
  geminiFailureFor,
} from "./gemini_error.ts";

function errorResponse(status: number, body: unknown): Response {
  return new Response(
    typeof body === "string" ? body : JSON.stringify(body),
    { status, headers: { "content-type": "application/json" } },
  );
}

/** The shape Google returns for a rejected structured-output request. */
function googleError(
  status: number,
  apiStatus: string,
  message: string,
  reason?: string,
): Response {
  return errorResponse(status, {
    error: {
      code: status,
      message,
      status: apiStatus,
      details: reason
        ? [{
          "@type": "type.googleapis.com/google.rpc.ErrorInfo",
          reason,
          domain: "googleapis.com",
        }]
        : undefined,
    },
  });
}

Deno.test("an invalid schema is a configuration fault, not an outage", async () => {
  const detail = await describeGeminiError(
    googleError(
      400,
      "INVALID_ARGUMENT",
      'Invalid JSON payload received. Unknown name "type" at ' +
        "'generation_config.response_json_schema'.",
    ),
  );

  assertEquals(detail.kind, "invalid_request");
  assertEquals(detail.apiStatus, "INVALID_ARGUMENT");
  assertEquals(detail.retryable, false);
  assertStringIncludes(detail.message, "Invalid JSON payload received");

  const mapping = geminiFailureFor(detail);
  assertEquals(mapping.code, "gemini_invalid_request");
  assertEquals(mapping.retryable, false);
  assertEquals(mapping.configuration, true);
  // The regression this phase exists for: a permanently invalid request used
  // to be reported as `gemini_upstream_error` + retryable.
  assert(mapping.code !== "gemini_upstream_error");
});

Deno.test("an unusable API key arrives as 400 and is not an invalid request", async () => {
  // Verified against the live API: a bad key returns HTTP 400 INVALID_ARGUMENT
  // with reason API_KEY_INVALID, not 401. Status alone cannot separate this
  // from a schema fault, so the envelope has to.
  const detail = await describeGeminiError(
    googleError(
      400,
      "INVALID_ARGUMENT",
      "API key not valid. Please pass a valid API key.",
      "API_KEY_INVALID",
    ),
  );

  assertEquals(detail.kind, "credential");
  assertEquals(detail.reason, "API_KEY_INVALID");
  assertEquals(detail.retryable, false);
  assertEquals(geminiFailureFor(detail).code, "gemini_credential_rejected");
});

Deno.test("a billing or region precondition is its own category", async () => {
  const detail = await describeGeminiError(
    googleError(400, "FAILED_PRECONDITION", "Billing is not enabled."),
  );

  assertEquals(detail.kind, "precondition");
  assertEquals(detail.retryable, false);
  assertEquals(geminiFailureFor(detail).code, "gemini_account_precondition");
});

Deno.test("401 and 403 are credential failures and are never retried", async () => {
  for (const status of [401, 403]) {
    const detail = await describeGeminiError(
      googleError(
        status,
        "PERMISSION_DENIED",
        "The caller does not have permission.",
      ),
    );
    assertEquals(detail.kind, "credential");
    assertEquals(detail.retryable, false);
    assertEquals(geminiFailureFor(detail).status, 500);
  }
});

Deno.test("404 stays a model-configuration fault", async () => {
  const detail = await describeGeminiError(
    googleError(404, "NOT_FOUND", "models/nope is not found."),
  );

  assertEquals(detail.kind, "model_not_found");
  assertEquals(detail.retryable, false);
  assertEquals(geminiFailureFor(detail).code, "GEMINI_MODEL_NOT_FOUND");
});

Deno.test("429 is a rate limit and stays retryable", async () => {
  const detail = await describeGeminiError(
    googleError(
      429,
      "RESOURCE_EXHAUSTED",
      "Quota exceeded.",
      "RATE_LIMIT_EXCEEDED",
    ),
  );

  assertEquals(detail.kind, "rate_limited");
  assertEquals(detail.retryable, true);
  const mapping = geminiFailureFor(detail);
  assertEquals(mapping.status, 503);
  assertEquals(mapping.code, "gemini_rate_limited");
  assertEquals(mapping.configuration, false);
});

Deno.test("5xx is a transient upstream failure", async () => {
  for (const status of [500, 502, 503]) {
    const detail = await describeGeminiError(
      googleError(status, "UNAVAILABLE", "The model is overloaded."),
    );
    assertEquals(detail.kind, "upstream");
    assertEquals(detail.retryable, true);
    assertEquals(geminiFailureFor(detail).code, "gemini_upstream_error");
  }
});

Deno.test("a body that is not JSON still classifies from the status", async () => {
  const detail = await describeGeminiError(
    new Response("<html>gateway</html>", { status: 502 }),
  );

  assertEquals(detail.kind, "upstream");
  assertEquals(detail.apiStatus, null);
  assertEquals(detail.message, "");
});

Deno.test("an oversized body is never read into a log line", async () => {
  const detail = await describeGeminiError(
    errorResponse(400, { error: { message: "x".repeat(20000) } }),
  );

  assertEquals(detail.message, "");
  assertEquals(detail.kind, "invalid_request");
});

Deno.test("a leaked credential in the message never reaches the log", async () => {
  const detail = await describeGeminiError(
    googleError(
      400,
      "INVALID_ARGUMENT",
      "API key AIzaSyD-1234567890abcdefghijklmnopqrstu is not valid",
    ),
  );

  assert(!detail.message.includes("AIzaSy"));
  assertStringIncludes(detail.message, "[redacted]");
  assert(!geminiErrorLogLine("probe", 1, detail).includes("AIzaSy"));
});

Deno.test("inline base64 echoed back is redacted", async () => {
  const detail = await describeGeminiError(
    googleError(400, "INVALID_ARGUMENT", `bad part ${"QUJDRA".repeat(20)}`),
  );

  assert(!detail.message.includes("QUJDRAQUJDRA"));
  assertStringIncludes(detail.message, "[redacted]");
});

Deno.test("the message is bounded and single-line", async () => {
  const detail = await describeGeminiError(
    googleError(400, "INVALID_ARGUMENT", `${"word ".repeat(200)}\n\nmore`),
  );

  assert(detail.message.length <= 304, `was ${detail.message.length}`);
  assert(!detail.message.includes("\n"));
});

Deno.test("the log line carries the diagnosis and no payload", async () => {
  const detail = await describeGeminiError(
    googleError(
      400,
      "INVALID_ARGUMENT",
      "Unknown name at response_json_schema.",
    ),
  );
  const line = geminiErrorLogLine("plan-tutorial-v3", 1, detail);

  assertStringIncludes(line, "[plan-tutorial-v3] gemini_error status=400");
  assertStringIncludes(line, "api_status=INVALID_ARGUMENT");
  assertStringIncludes(line, "kind=invalid_request");
  assertStringIncludes(line, "retryable=false");
  assertStringIncludes(line, "attempt=1");
});

Deno.test("a hostile status field cannot inject into a log line", async () => {
  const detail = await describeGeminiError(
    googleError(400, 'X"\nreason=API_KEY_INVALID kind=upstream', "hi"),
  );

  assertEquals(detail.apiStatus, "XreasonAPI_KEY_INVALIDkindupstream");
  assertEquals(detail.kind, "invalid_request");
});
