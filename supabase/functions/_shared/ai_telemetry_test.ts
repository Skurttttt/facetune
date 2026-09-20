import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  metricArguments,
  noteProviderAttempt,
  readProviderUsage,
  recordAiOperationMetric,
  sanitizeCategory,
  type TelemetryClient,
  usageForMetric,
  type UsageSink,
} from "./ai_telemetry.ts";

const eventId = "11111111-1111-4111-8111-111111111111";
const userId = "22222222-2222-4222-8222-222222222222";
const operationId = "33333333-3333-4333-8333-333333333333";

Deno.test("provider usage keeps safe totals and modality counts", () => {
  const usage = readProviderUsage({
    usageMetadata: {
      promptTokenCount: 1400,
      candidatesTokenCount: 1130,
      totalTokenCount: 2580,
      cachedContentTokenCount: 20,
      thoughtsTokenCount: 50,
      promptTokensDetails: [
        { modality: "TEXT", tokenCount: 280 },
        { modality: "IMAGE", tokenCount: 1120 },
      ],
      candidatesTokensDetails: [
        { modality: "IMAGE", tokenCount: 1120 },
        { modality: "TEXT", tokenCount: 10 },
      ],
    },
  }, 2);

  assertEquals(usage, {
    inputTokens: 1400,
    outputTokens: 1130,
    totalTokens: 2580,
    cachedTokens: 20,
    thoughtsTokens: 50,
    inputImageTokens: 1120,
    outputImageTokens: 1120,
    attempts: 2,
  });
});

Deno.test("failed provider calls still expose attempt and retry counts", () => {
  const sink: UsageSink = {};
  noteProviderAttempt(sink, 1);
  noteProviderAttempt(sink, 2);

  assertEquals(usageForMetric(sink), {
    inputTokens: null,
    outputTokens: null,
    totalTokens: null,
    cachedTokens: null,
    thoughtsTokens: null,
    inputImageTokens: null,
    outputImageTokens: null,
    attempts: 2,
  });
});

Deno.test("metric arguments contain categories and counts, never content", () => {
  const args = metricArguments(eventId, userId, {
    operationKind: "final_preview",
    outcome: "failed",
    failureCategory: "GEMINI_TIMEOUT",
    sourceMode: "my_makeup_kit",
    operationId,
    providerName: "google_gemini",
    providerAttemptCount: 3,
    modelName: "gemini-3.1-flash-image",
    promptVersion: "kit_makeup_preview_v1",
    usage: {
      inputTokens: 100,
      outputTokens: null,
      totalTokens: 100,
      cachedTokens: null,
      thoughtsTokens: null,
      inputImageTokens: 80,
      outputImageTokens: null,
      attempts: 2,
    },
  });

  assertEquals(args.p_event_id, eventId);
  assertEquals(args.p_user_id, userId);
  assertEquals(args.p_source_mode, "makeup_kit");
  assertEquals(args.p_provider_attempt_count, 3);
  assertEquals(args.p_input_image_tokens, 80);
  const serialized = JSON.stringify(args).toLowerCase();
  for (
    const prohibited of [
      "purchase-token",
      "signedurl",
      "base64",
      "prompt text",
      "image bytes",
    ]
  ) {
    assert(!serialized.includes(prohibited));
  }
});

Deno.test("free text is rejected instead of transformed into a category", () => {
  assertEquals(sanitizeCategory("GEMINI_TIMEOUT"), "GEMINI_TIMEOUT");
  assertEquals(sanitizeCategory("https://private.example/token"), null);
  assertEquals(sanitizeCategory("secret.with.dots"), null);
  assertEquals(sanitizeCategory("x".repeat(65)), null);
});

Deno.test("writer errors and timeouts cannot escape into the product path", async () => {
  const rejects: TelemetryClient = {
    rpc: () => Promise.reject(new Error("private database detail")),
  };
  const hangs: TelemetryClient = {
    rpc: () => new Promise(() => undefined),
  };
  const metric = {
    operationKind: "final_preview" as const,
    outcome: "denied" as const,
    failureCategory: "AI_LOOK_LIMIT_REACHED",
    operationId,
  };

  assertEquals(
    await recordAiOperationMetric(rejects, eventId, userId, metric, 10),
    false,
  );
  assertEquals(
    await recordAiOperationMetric(hangs, eventId, userId, metric, 10),
    false,
  );
});
