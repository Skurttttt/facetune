import { tutorialManifestPrompt } from "./prompt.ts";
import { TUTORIAL_MANIFEST_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const requestTimeoutMs = 45000;
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

function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<
      { content?: { parts?: Array<{ text?: string }> }; finishReason?: string }
    >;
    promptFeedback?: { blockReason?: string };
  };
  const text = data.candidates?.[0]?.content?.parts?.map((part) =>
    part.text ?? ""
  ).join("").trim();
  if (!text) {
    const blocked = data.promptFeedback?.blockReason ||
      data.candidates?.[0]?.finishReason;
    if (blocked) {
      throw new FunctionFailure(
        422,
        "gemini_refusal",
        "The tutorial could not be prepared for these images.",
      );
    }
    throw new FunctionFailure(
      502,
      "empty_ai_response",
      "The tutorial analysis returned an empty response.",
      true,
    );
  }
  return text;
}

/// Sends the original selfie and the canonical final preview for comparison.
///
/// Part order is deliberate and load-bearing: the prompt names IMAGE A and
/// IMAGE B, so the original must be the first inline image and the preview the
/// second. Swapping them would invert every verdict — makeup would appear to
/// have been removed rather than added.
export async function requestGeminiManifest(
  apiKey: string,
  model: string,
  original: { bytes: Uint8Array; mimeType: string },
  canonicalPreview: { bytes: Uint8Array; mimeType: string },
  supportingContext: string,
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: tutorialManifestPrompt(supportingContext) },
        { text: "IMAGE A — ORIGINAL, before makeup:" },
        {
          inlineData: {
            mimeType: original.mimeType,
            data: encodeBase64(original.bytes),
          },
        },
        { text: "IMAGE B — FINAL, after makeup:" },
        {
          inlineData: {
            mimeType: canonicalPreview.mimeType,
            data: encodeBase64(canonicalPreview.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: TUTORIAL_MANIFEST_SCHEMA,
      maxOutputTokens: 2048,
      // Presence classification must be repeatable: the same pair of images
      // should yield the same verdicts across runs, exactly as in analyze-face.
      // A drifting manifest would give the same look different tutorials.
      temperature: 0.1,
      topP: 0.8,
      candidateCount: 1,
    },
  });

  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    try {
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(requestTimeoutMs),
      });
      if (response.ok) return responseText(await response.json());
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[analyze-tutorial-manifest-v4] Gemini failed status=${response.status} attempt=${attempt}`,
      );
      if (transient && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      throw new FunctionFailure(
        response.status === 429 ? 503 : 502,
        response.status === 429
          ? "gemini_rate_limited"
          : "gemini_upstream_error",
        "The tutorial analysis service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new FunctionFailure(
          504,
          "gemini_timeout",
          "Preparing the tutorial took too long.",
          true,
        );
      }
      throw new FunctionFailure(
        503,
        "gemini_network_error",
        "The tutorial analysis service could not be reached.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "gemini_unavailable",
    "The tutorial analysis service is unavailable.",
    true,
  );
}
