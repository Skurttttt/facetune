import {
  GUIDELINE_MAXIMUM_ATTEMPTS,
  GUIDELINE_REQUEST_TIMEOUT_MS,
  TUTORIAL_OUTPUT_RESOLUTION,
} from "../_shared/tutorial_ai_config.ts";
import { FunctionFailure, type GeneratedGuideline } from "./types.ts";

const maximumBytes = 10 * 1024 * 1024;
const minimumBytes = 10 * 1024;

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunkSize));
  }
  return btoa(binary);
}

function decodeBase64(value: string): Uint8Array {
  try {
    return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
  } catch {
    throw invalidImage();
  }
}

function invalidImage(): FunctionFailure {
  return new FunctionFailure(
    502,
    "invalid_generated_guideline",
    "The tutorial service returned an unusable image.",
    true,
  );
}

/// Confirms the bytes really are the image type claimed.
///
/// A truncated or mislabelled payload would otherwise be stored and later
/// served as a broken step.
function signatureMatches(bytes: Uint8Array, mimeType: string): boolean {
  if (mimeType === "image/png") {
    return bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
      bytes[2] === 0x4e && bytes[3] === 0x47;
  }
  if (mimeType === "image/jpeg") {
    return bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9;
  }
  if (mimeType === "image/webp") {
    return bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

export function validateGuidelineImage(
  data: unknown,
  mimeType: unknown,
): GeneratedGuideline {
  if (
    typeof data !== "string" || data.length === 0 ||
    (mimeType !== "image/png" && mimeType !== "image/jpeg" &&
      mimeType !== "image/webp")
  ) throw invalidImage();
  const bytes = decodeBase64(data);
  if (
    bytes.length < minimumBytes || bytes.length > maximumBytes ||
    !signatureMatches(bytes, mimeType)
  ) throw invalidImage();
  return { bytes, mimeType };
}

/// True when the model returned the input unchanged.
///
/// A guideline identical to the original selfie means nothing was drawn, which
/// is a failure to render rather than a valid empty result.
export function isUnchanged(original: Uint8Array, generated: Uint8Array): boolean {
  if (original.length !== generated.length) return false;
  for (let index = 0; index < original.length; index += 1) {
    if (original[index] !== generated[index]) return false;
  }
  return true;
}

function firstImagePart(payload: unknown): GeneratedGuideline {
  const data = payload as {
    candidates?: Array<{
      content?: {
        parts?: Array<
          { inlineData?: { mimeType?: string; data?: string } }
        >;
      };
      finishReason?: string;
    }>;
    promptFeedback?: { blockReason?: string };
  };
  const parts = data.candidates?.[0]?.content?.parts ?? [];
  for (const part of parts) {
    if (part.inlineData?.data) {
      return validateGuidelineImage(
        part.inlineData.data,
        part.inlineData.mimeType,
      );
    }
  }
  const blocked = data.promptFeedback?.blockReason ||
    data.candidates?.[0]?.finishReason;
  if (blocked) {
    throw new FunctionFailure(
      422,
      "gemini_refusal",
      "This tutorial step could not be drawn.",
    );
  }
  throw new FunctionFailure(
    502,
    "empty_ai_response",
    "The tutorial service returned no image.",
    true,
  );
}

/// Requests one guideline rendering.
///
/// Part order is load-bearing: the prompt names IMAGE A then IMAGE B, so the
/// original must be the first inline image and the canonical preview the
/// second. Swapping them would make the model annotate the finished look
/// instead of the bare face.
export async function requestGeminiGuideline(
  apiKey: string,
  model: string,
  prompt: string,
  original: { bytes: Uint8Array; mimeType: string },
  canonicalPreview: { bytes: Uint8Array; mimeType: string },
): Promise<GeneratedGuideline> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: prompt },
        { text: "IMAGE A — ORIGINAL, no makeup. Edit and return THIS image:" },
        {
          inlineData: {
            mimeType: original.mimeType,
            data: encodeBase64(original.bytes),
          },
        },
        { text: "IMAGE B — FINAL, reference only. Do not return this image:" },
        {
          inlineData: {
            mimeType: canonicalPreview.mimeType,
            data: encodeBase64(canonicalPreview.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      // The locked 1K baseline, sent from the one central constant rather than
      // repeated per category.
      //
      // UNVERIFIED: this request shape for selecting output resolution has not
      // been confirmed against the live API, and no other FaceTune image call
      // sets one. If Gemini rejects it, the fix is here and in
      // _shared/tutorial_ai_config.ts — never by quietly dropping the
      // resolution, which would leave outputs at an unknown size.
      imageConfig: { imageSize: TUTORIAL_OUTPUT_RESOLUTION },
      candidateCount: 1,
    },
  });

  let lastTransient: FunctionFailure | null = null;
  for (let attempt = 1; attempt <= GUIDELINE_MAXIMUM_ATTEMPTS; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(GUIDELINE_REQUEST_TIMEOUT_MS),
      });
      if (response.ok) return firstImagePart(await response.json());
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[generate-tutorial-step-v4] Gemini failed status=${response.status} attempt=${attempt}`,
      );
      const failure = new FunctionFailure(
        response.status === 429 ? 503 : 502,
        response.status === 429
          ? "gemini_rate_limited"
          : "gemini_upstream_error",
        "The tutorial service is temporarily unavailable.",
        transient,
      );
      // Only a technical failure that produced no usable image is retried, and
      // only once. A refusal or an invalid image is not retried: the same
      // request would produce the same answer and be billed again.
      if (!transient) throw failure;
      lastTransient = failure;
    } catch (error) {
      if (error instanceof FunctionFailure) {
        if (!error.retryable) throw error;
        lastTransient = error;
      } else if (error instanceof DOMException && error.name === "TimeoutError") {
        lastTransient = new FunctionFailure(
          504,
          "gemini_timeout",
          "Drawing this tutorial step took too long.",
          true,
        );
      } else {
        lastTransient = new FunctionFailure(
          503,
          "gemini_network_error",
          "The tutorial service could not be reached.",
          true,
        );
      }
    }
    if (attempt < GUIDELINE_MAXIMUM_ATTEMPTS) {
      await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
    }
  }
  throw lastTransient ?? new FunctionFailure(
    503,
    "gemini_unavailable",
    "The tutorial service is unavailable.",
    true,
  );
}
