import { FACE_ANALYSIS_PROMPT } from "./prompt.ts";
import { FACE_ANALYSIS_SCHEMA } from "./schema.ts";
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
        "The analysis service could not process this image.",
      );
    }
    throw new FunctionFailure(
      502,
      "empty_ai_response",
      "The analysis service returned an empty response.",
      true,
    );
  }
  return text;
}

export async function requestGeminiAnalysis(
  apiKey: string,
  model: string,
  image: Uint8Array,
  mimeType: string,
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: FACE_ANALYSIS_PROMPT },
        { inlineData: { mimeType, data: encodeBase64(image) } },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: FACE_ANALYSIS_SCHEMA,
      maxOutputTokens: 2048,
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
        `[analyze-face] Gemini request failed status=${response.status} attempt=${attempt}`,
      );
      if (transient && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      if (response.status === 429) {
        throw new FunctionFailure(
          503,
          "gemini_rate_limited",
          "Analysis is busy. Please try again shortly.",
          true,
        );
      }
      throw new FunctionFailure(
        502,
        "gemini_upstream_error",
        "The analysis service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new FunctionFailure(
          504,
          "gemini_timeout",
          "Analysis took too long. Please try again.",
          true,
        );
      }
      throw new FunctionFailure(
        503,
        "gemini_network_error",
        "The analysis service could not be reached.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "gemini_unavailable",
    "The analysis service is unavailable.",
    true,
  );
}
