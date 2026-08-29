import { validateGuidelineImage } from "./image_validation.ts";
import { type GuidelineInput, tutorialV2GuidelinePrompt } from "./prompt.ts";
import type { GeneratedImage } from "./types.ts";
import { FunctionFailure } from "./types.ts";

/// Ceiling for a single attempt. A slow but successful generation must never
/// be abandoned early.
const attemptTimeoutMs = 90000;

/// Ceiling for all attempts combined. Two unbounded attempts could run 180s,
/// which exceeds the Edge Function wall-clock window on some plans and leaves
/// the caller waiting for a response the platform will never deliver.
const totalBudgetMs = 135000;

const maximumAttempts = 2;

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

export type SourceImage = { bytes: Uint8Array; mimeType: string };

function generatedImage(payload: unknown): GeneratedImage {
  const response = payload as {
    candidates?: Array<{
      content?: {
        parts?: Array<{ inlineData?: { data?: unknown; mimeType?: unknown } }>;
      };
      finishReason?: string;
    }>;
    promptFeedback?: { blockReason?: string };
  };
  const part = response.candidates?.[0]?.content?.parts?.find(
    (candidate) => candidate.inlineData?.data,
  );
  if (part?.inlineData) {
    return validateGuidelineImage(part.inlineData.data, part.inlineData.mimeType);
  }
  const reason = response.promptFeedback?.blockReason ||
    response.candidates?.[0]?.finishReason;
  if (reason) {
    // A refusal or a non-STOP finish reason is not worth retrying blind.
    throw new FunctionFailure(
      422,
      "GEMINI_NO_IMAGE_OUTPUT",
      "[GEMINI_NO_IMAGE_OUTPUT] The image service did not return a usable guideline.",
    );
  }
  throw new FunctionFailure(
    502,
    "GEMINI_NO_IMAGE_OUTPUT",
    "[GEMINI_NO_IMAGE_OUTPUT] The image service returned no image output.",
    true,
  );
}

/**
 * Requests one guideline image.
 *
 * Deliberately sends NO `generationConfig`. This mirrors the request shape
 * already verified in production by `generate-makeup-preview`, and follows the
 * reasoning recorded in `docs/AI_QUALITY_NOTES.md`: an unsupported field on
 * this endpoint returns 400 and breaks generation outright, so sampling
 * parameters need a live request to validate before they are introduced.
 * Instructional consistency is pursued through the prompt, which is fully
 * under our control, rather than through unverified sampling fields.
 *
 * The three images are attached in the order the prompt declares: identity
 * reference, base state, canonical target.
 */
export async function requestGuidelineImage(
  apiKey: string,
  model: string,
  input: GuidelineInput,
  images: {
    identity: SourceImage;
    baseState: SourceImage;
    canonicalTarget: SourceImage;
  },
): Promise<GeneratedImage> {
  const endpoint = `https://generativelanguage.googleapis.com/v1/models/${
    encodeURIComponent(model)
  }:generateContent`;

  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: tutorialV2GuidelinePrompt(input) },
        {
          inlineData: {
            mimeType: images.identity.mimeType,
            data: encodeBase64(images.identity.bytes),
          },
        },
        {
          inlineData: {
            mimeType: images.baseState.mimeType,
            data: encodeBase64(images.baseState.bytes),
          },
        },
        {
          inlineData: {
            mimeType: images.canonicalTarget.mimeType,
            data: encodeBase64(images.canonicalTarget.bytes),
          },
        },
      ],
    }],
  });

  const budgetStartedAt = Date.now();
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    const remainingBudgetMs = totalBudgetMs - (Date.now() - budgetStartedAt);
    if (remainingBudgetMs <= 0) break;
    const attemptTimeout = Math.min(attemptTimeoutMs, remainingBudgetMs);
    try {
      console.log(
        `[tutorial-v2-guideline] request model=${model} attempt=${attempt} budget_ms=${attemptTimeout}`,
      );
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(attemptTimeout),
      });
      if (response.ok) return generatedImage(await response.json());

      const detail = await safeErrorPayload(response);
      const classification = classifyGeminiFailure(response.status, detail);
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[tutorial-v2-guideline] gemini_failure code=${classification.code} status=${response.status} detail=${classification.logMessage}`,
      );
      if (transient && attempt < maximumAttempts) continue;
      throw new FunctionFailure(
        classification.httpStatus,
        classification.code,
        `[${classification.code}] ${classification.userMessage}`,
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      throw new FunctionFailure(
        504,
        "GEMINI_TIMEOUT",
        "[GEMINI_TIMEOUT] Guideline generation took too long. Please try again.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    504,
    "GEMINI_TIMEOUT",
    "[GEMINI_TIMEOUT] Guideline generation took too long. Please try again.",
    true,
  );
}

async function safeErrorPayload(response: Response): Promise<string> {
  try {
    const payload = await response.json() as {
      error?: { message?: unknown; status?: unknown };
    };
    const status = typeof payload.error?.status === "string"
      ? payload.error.status
      : "";
    const message = typeof payload.error?.message === "string"
      ? payload.error.message
      : "";
    return `${status} ${message}`.replace(/[\r\n]+/g, " ").slice(0, 300);
  } catch {
    return "unparseable_upstream_error";
  }
}

export function classifyGeminiFailure(
  status: number,
  detail: string,
): {
  code: string;
  httpStatus: number;
  userMessage: string;
  logMessage: string;
} {
  const normalized = detail.toLowerCase();
  if (status === 404) {
    // A missing model is a configuration fault, not an outage. Surfacing it
    // distinctly keeps a bad TUTORIAL_V2_GUIDELINE_MODEL obvious.
    return {
      code: "GEMINI_MODEL_NOT_FOUND",
      httpStatus: 502,
      userMessage: "The configured Gemini image model was not found.",
      logMessage: detail,
    };
  }
  if (status === 403 && normalized.includes("bill")) {
    return {
      code: "GEMINI_BILLING_REQUIRED",
      httpStatus: 502,
      userMessage:
        "Gemini image generation requires billing for this Google project.",
      logMessage: detail,
    };
  }
  if (status === 401 || status === 403) {
    return {
      code: "GEMINI_ACCESS_DENIED",
      httpStatus: 502,
      userMessage: "The Google project cannot access the configured image model.",
      logMessage: detail,
    };
  }
  if (status === 429) {
    return {
      code: "GEMINI_QUOTA_EXCEEDED",
      httpStatus: 503,
      userMessage: "Gemini image-generation quota is currently unavailable.",
      logMessage: detail,
    };
  }
  if (status === 400) {
    return {
      code: "GEMINI_INVALID_REQUEST",
      httpStatus: 502,
      userMessage: "Gemini rejected the image-generation request format.",
      logMessage: detail,
    };
  }
  return {
    code: "GEMINI_API_FAILURE",
    httpStatus: 502,
    userMessage: "The Gemini image service returned an upstream failure.",
    logMessage: detail,
  };
}
