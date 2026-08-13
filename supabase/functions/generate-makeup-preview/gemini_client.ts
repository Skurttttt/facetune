import { makeupPreviewPrompt } from "./prompt.ts";
import type { GeneratedImage } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { validateGeneratedImage } from "./image_validation.ts";

/// Ceiling for a single Gemini attempt. Unchanged: a slow but successful
/// generation must never be abandoned early.
const attemptTimeoutMs = 90000;

/// Ceiling for all attempts combined.
///
/// Two unbounded attempts could run 180s, which exceeds the Supabase Edge
/// Function wall-clock window on some plans and leaves the caller waiting for a
/// response the platform will never deliver. The budget only ever shortens a
/// retry — the first attempt always gets the full [attemptTimeoutMs].
const totalBudgetMs = 135000;

const maximumAttempts = 2;

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(
      ...bytes.subarray(offset, offset + chunkSize),
    );
  }
  return btoa(binary);
}

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
    const image = validateGeneratedImage(
      part.inlineData.data,
      part.inlineData.mimeType,
    );
    console.log("[Phase10] gemini_image_received=true");
    return image;
  }
  const reason = response.promptFeedback?.blockReason ||
    response.candidates?.[0]?.finishReason;
  if (reason) {
    throw new FunctionFailure(
      422,
      "GEMINI_NO_IMAGE_OUTPUT",
      "[GEMINI_NO_IMAGE_OUTPUT] The image service did not return a usable image.",
    );
  }
  throw new FunctionFailure(
    502,
    "GEMINI_NO_IMAGE_OUTPUT",
    "[GEMINI_NO_IMAGE_OUTPUT] The image service returned no image output.",
    true,
  );
}

export async function requestGeminiPreview(
  apiKey: string,
  model: string,
  originalBytes: Uint8Array,
  originalMimeType: string,
  style: string,
  recommendation: Record<string, unknown>,
  variationNumber: number,
): Promise<GeneratedImage> {
  const endpoint = `https://generativelanguage.googleapis.com/v1/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: makeupPreviewPrompt(style, recommendation, variationNumber) },
        {
          inlineData: {
            mimeType: originalMimeType,
            data: encodeBase64(originalBytes),
          },
        },
      ],
    }],
  });
  const budgetStartedAt = Date.now();
  {
    for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
      const remainingBudgetMs = totalBudgetMs - (Date.now() - budgetStartedAt);
      if (remainingBudgetMs <= 0) break;
      const attemptTimeout = Math.min(attemptTimeoutMs, remainingBudgetMs);
      try {
        console.log(
          `[Phase10] gemini_request_started model=${model} attempt=${attempt} budget_ms=${attemptTimeout}`,
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
        console.log(`[Phase10] gemini_status=${response.status}`);
        if (response.ok) return generatedImage(await response.json());
        const errorPayload = await safeErrorPayload(response);
        const classification = classifyGeminiFailure(
          response.status,
          errorPayload,
        );
        const transient = response.status === 429 || response.status >= 500;
        console.error(
          `[Phase10] gemini_failure code=${classification.code} status=${response.status} message=${classification.logMessage}`,
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
          "[GEMINI_TIMEOUT] Preview generation took too long. Please try again.",
          true,
        );
      }
    }
    // Reached only when the shared budget is exhausted before a retry can run.
    throw new FunctionFailure(
      504,
      "GEMINI_TIMEOUT",
      "[GEMINI_TIMEOUT] Preview generation took too long. Please try again.",
      true,
    );
  }
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

function classifyGeminiFailure(
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
      userMessage:
        "The Google project cannot access the configured image model.",
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
