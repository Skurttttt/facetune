import { validateGeneratedImage } from "../generate-makeup-preview/image_validation.ts";
import { kitMakeupPreviewPrompt } from "./prompt.ts";
import type { GeneratedImage, NormalizedKitPreviewPlan } from "./types.ts";
import { FunctionFailure } from "./types.ts";

const attemptTimeoutMs = 90000;
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
    return validateGeneratedImage(
      part.inlineData.data,
      part.inlineData.mimeType,
    );
  }
  const reason = response.promptFeedback?.blockReason ||
    response.candidates?.[0]?.finishReason;
  throw new FunctionFailure(
    reason ? 422 : 502,
    "GEMINI_NO_IMAGE_OUTPUT",
    "The image service did not return a usable image.",
    !reason,
  );
}

export async function requestGeminiKitPreview(
  apiKey: string,
  model: string,
  originalBytes: Uint8Array,
  originalMimeType: string,
  style: string,
  plan: NormalizedKitPreviewPlan,
  variationNumber: number,
): Promise<GeneratedImage> {
  const endpoint = `https://generativelanguage.googleapis.com/v1/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: kitMakeupPreviewPrompt(style, plan, variationNumber) },
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
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    const remainingBudgetMs = totalBudgetMs - (Date.now() - budgetStartedAt);
    if (remainingBudgetMs <= 0) break;
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(
          Math.min(attemptTimeoutMs, remainingBudgetMs),
        ),
      });
      if (response.ok) return generatedImage(await response.json());
      const detail = await safeErrorPayload(response);
      const failure = classifyGeminiFailure(response.status, detail);
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[generate-kit-makeup-preview] Gemini failure code=${failure.code} status=${response.status} detail=${failure.logMessage}`,
      );
      if (transient && attempt < maximumAttempts) continue;
      throw new FunctionFailure(
        failure.httpStatus,
        failure.code,
        failure.userMessage,
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      throw timeoutFailure();
    }
  }
  throw timeoutFailure();
}

function timeoutFailure(): FunctionFailure {
  return new FunctionFailure(
    504,
    "GEMINI_TIMEOUT",
    "Preview generation took too long. Please try again.",
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
      userMessage: "Gemini image generation requires billing.",
      logMessage: detail,
    };
  }
  if (status === 401 || status === 403) {
    return {
      code: "GEMINI_ACCESS_DENIED",
      httpStatus: 502,
      userMessage: "The image model is not available to this project.",
      logMessage: detail,
    };
  }
  if (status === 429) {
    return {
      code: "GEMINI_QUOTA_EXCEEDED",
      httpStatus: 503,
      userMessage: "Image-generation quota is currently unavailable.",
      logMessage: detail,
    };
  }
  if (status === 400) {
    return {
      code: "GEMINI_INVALID_REQUEST",
      httpStatus: 502,
      userMessage: "The image service rejected the preview request.",
      logMessage: detail,
    };
  }
  return {
    code: "GEMINI_API_FAILURE",
    httpStatus: 502,
    userMessage: "The image service returned an upstream failure.",
    logMessage: detail,
  };
}
