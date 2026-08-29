import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import { classifyGeminiFailure } from "./gemini_client.ts";
import {
  extensionFor,
  guidelinePath,
  isOwnedGuidelinePath,
  isOwnedSourcePath,
  validateGuidelineImage,
} from "./image_validation.ts";
import { FunctionFailure } from "./types.ts";

const userId = "user-1";
const analysisId = "analysis-1";
const sessionId = "session-1";

/// Chunked for the same reason the production encoder is: spreading a
/// multi-megabyte array into String.fromCharCode overflows the call stack.
function base64(bytes: number[]): string {
  const view = Uint8Array.from(bytes);
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < view.length; offset += chunkSize) {
    binary += String.fromCharCode(...view.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

/** A PNG of [size] bytes carrying a real PNG signature. */
function png(size = 20 * 1024): string {
  const bytes = new Uint8Array(size);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a], 0);
  return base64(Array.from(bytes));
}

function jpeg(size = 20 * 1024): string {
  const bytes = new Uint8Array(size);
  bytes.set([0xff, 0xd8], 0);
  bytes[size - 2] = 0xff;
  bytes[size - 1] = 0xd9;
  return base64(Array.from(bytes));
}

// --- Response validation ----------------------------------------------------

Deno.test("accepts a well-formed PNG", () => {
  const image = validateGuidelineImage(png(), "image/png");
  assertEquals(image.mimeType, "image/png");
  assert(image.bytes.length >= 10 * 1024);
});

Deno.test("accepts a well-formed JPEG", () => {
  assertEquals(validateGuidelineImage(jpeg(), "image/jpeg").mimeType, "image/jpeg");
});

Deno.test("rejects a missing image payload", () => {
  assertThrows(() => validateGuidelineImage(undefined, "image/png"), FunctionFailure);
  assertThrows(() => validateGuidelineImage(null, "image/png"), FunctionFailure);
  assertThrows(() => validateGuidelineImage("", "image/png"), FunctionFailure);
});

Deno.test("rejects a non-string payload", () => {
  assertThrows(() => validateGuidelineImage(42, "image/png"), FunctionFailure);
  assertThrows(() => validateGuidelineImage({}, "image/png"), FunctionFailure);
});

Deno.test("rejects an unsupported MIME type", () => {
  for (const mime of ["image/gif", "image/svg+xml", "text/plain", "", null, 7]) {
    assertThrows(() => validateGuidelineImage(png(), mime), FunctionFailure);
  }
});

Deno.test("rejects base64 that does not decode", () => {
  assertThrows(
    () => validateGuidelineImage("!!!not base64!!!", "image/png"),
    FunctionFailure,
  );
});

Deno.test("rejects a payload whose bytes contradict its MIME type", () => {
  // Real PNG bytes, declared as JPEG.
  assertThrows(() => validateGuidelineImage(png(), "image/jpeg"), FunctionFailure);
  // Real JPEG bytes, declared as PNG.
  assertThrows(() => validateGuidelineImage(jpeg(), "image/png"), FunctionFailure);
});

Deno.test("rejects a corrupt image with a valid header but no terminator", () => {
  const bytes = new Uint8Array(20 * 1024);
  bytes.set([0xff, 0xd8], 0);
  // No 0xFFD9 terminator: a truncated JPEG.
  assertThrows(
    () => validateGuidelineImage(base64(Array.from(bytes)), "image/jpeg"),
    FunctionFailure,
  );
});

Deno.test("rejects an implausibly small image", () => {
  assertThrows(() => validateGuidelineImage(png(512), "image/png"), FunctionFailure);
});

Deno.test("rejects an oversized image", () => {
  assertThrows(
    () => validateGuidelineImage(png(11 * 1024 * 1024), "image/png"),
    FunctionFailure,
  );
});

Deno.test("an invalid image is retryable", () => {
  const error = assertThrows(
    () => validateGuidelineImage("", "image/png"),
    FunctionFailure,
  ) as FunctionFailure;
  assertEquals(error.code, "invalid_guideline_image");
  assertEquals(error.retryable, true);
});

Deno.test("extensionFor maps every supported type", () => {
  assertEquals(extensionFor("image/png"), "png");
  assertEquals(extensionFor("image/webp"), "webp");
  assertEquals(extensionFor("image/jpeg"), "jpg");
});

// --- Path construction ------------------------------------------------------

Deno.test("guideline paths sit under the analysis prefix", () => {
  assertEquals(
    guidelinePath(userId, analysisId, sessionId, 0, "png"),
    "user-1/analyses/analysis-1/tutorial-v2/session-1/step_0001_guideline.png",
  );
});

Deno.test("step numbers are one-based and zero-padded", () => {
  assert(guidelinePath(userId, analysisId, sessionId, 9, "png").includes("step_0010_"));
});

Deno.test("the first segment is the owner id for storage RLS", () => {
  assertEquals(
    guidelinePath(userId, analysisId, sessionId, 3, "png").split("/")[0],
    userId,
  );
});

// --- Guideline path ownership ----------------------------------------------

function owned(path: string, stepIndex = 0): boolean {
  return isOwnedGuidelinePath(path, userId, analysisId, sessionId, stepIndex);
}

Deno.test("accepts a path it built", () => {
  assert(owned(guidelinePath(userId, analysisId, sessionId, 0, "png")));
  assert(owned(guidelinePath(userId, analysisId, sessionId, 4, "webp"), 4));
});

Deno.test("rejects another user's path", () => {
  assert(
    !owned("user-2/analyses/analysis-1/tutorial-v2/session-1/step_0001_guideline.png"),
  );
});

Deno.test("rejects another analysis", () => {
  assert(
    !owned("user-1/analyses/analysis-9/tutorial-v2/session-1/step_0001_guideline.png"),
  );
});

Deno.test("rejects another session", () => {
  assert(
    !owned("user-1/analyses/analysis-1/tutorial-v2/session-9/step_0001_guideline.png"),
  );
});

Deno.test("rejects the wrong step — a wrong-step asset cannot be attached", () => {
  const path = guidelinePath(userId, analysisId, sessionId, 1, "png");
  assert(owned(path, 1));
  assert(!owned(path, 0));
  assert(!owned(path, 2));
});

Deno.test("rejects a result path where a guideline is expected", () => {
  assert(
    !owned("user-1/analyses/analysis-1/tutorial-v2/session-1/step_0001_result.png"),
  );
});

Deno.test("rejects traversal rather than accepting a prefix match", () => {
  assert(
    !owned(
      "user-1/analyses/analysis-1/tutorial-v2/session-1/../../step_0001_guideline.png",
    ),
  );
  assert(
    !owned(
      "user-1/analyses/analysis-1/tutorial-v2/session-1/nested/step_0001_guideline.png",
    ),
  );
});

Deno.test("rejects an original selfie path", () => {
  assert(!owned("user-1/analyses/analysis-1/original/abcd.jpg"));
});

Deno.test("rejects an unsupported extension", () => {
  assert(
    !owned("user-1/analyses/analysis-1/tutorial-v2/session-1/step_0001_guideline.exe"),
  );
});

Deno.test("rejects an empty path", () => {
  assert(!owned(""));
});

// --- Source path ownership --------------------------------------------------

Deno.test("accepts this analysis's own source images", () => {
  assert(isOwnedSourcePath("user-1/analyses/analysis-1/original/a.jpg", userId, analysisId));
  assert(
    isOwnedSourcePath(
      "user-1/analyses/analysis-1/generated/rec-1/preview_0001.png",
      userId,
      analysisId,
    ),
  );
});

Deno.test("rejects a source path from another account", () => {
  assert(
    !isOwnedSourcePath("user-2/analyses/analysis-1/original/a.jpg", userId, analysisId),
  );
});

Deno.test("rejects a source path from another analysis", () => {
  assert(
    !isOwnedSourcePath("user-1/analyses/analysis-2/original/a.jpg", userId, analysisId),
  );
});

Deno.test("rejects traversal in a source path", () => {
  assert(
    !isOwnedSourcePath("user-1/analyses/analysis-1/../analysis-2/x.jpg", userId, analysisId),
  );
  assert(
    !isOwnedSourcePath("user-1/analyses/analysis-1//x.jpg", userId, analysisId),
  );
});

Deno.test("rejects a bucket-root path", () => {
  assert(!isOwnedSourcePath("x.jpg", userId, analysisId));
});

// --- Upstream failure classification ---------------------------------------

Deno.test("a missing model is a configuration fault, not an outage", () => {
  const result = classifyGeminiFailure(404, "NOT_FOUND model not found");
  assertEquals(result.code, "GEMINI_MODEL_NOT_FOUND");
});

Deno.test("billing and access failures are distinguished", () => {
  assertEquals(
    classifyGeminiFailure(403, "PERMISSION_DENIED billing not enabled").code,
    "GEMINI_BILLING_REQUIRED",
  );
  assertEquals(
    classifyGeminiFailure(403, "PERMISSION_DENIED no access").code,
    "GEMINI_ACCESS_DENIED",
  );
});

Deno.test("quota and bad-request failures are distinguished", () => {
  assertEquals(classifyGeminiFailure(429, "RESOURCE_EXHAUSTED").code, "GEMINI_QUOTA_EXCEEDED");
  assertEquals(classifyGeminiFailure(400, "INVALID_ARGUMENT").code, "GEMINI_INVALID_REQUEST");
});

Deno.test("an unknown status falls back to a generic upstream failure", () => {
  assertEquals(classifyGeminiFailure(503, "UNAVAILABLE").code, "GEMINI_API_FAILURE");
});
