import { makeupRecommendationPrompt } from "./prompt.ts";
import { MAKEUP_RECOMMENDATION_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const timeoutMs = 45000;
const maximumAttempts = 2;

function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    promptFeedback?: { blockReason?: string };
  };
  const text = data.candidates?.[0]?.content?.parts?.map((part) =>
    part.text ?? ""
  ).join("").trim();
  if (text) return text;
  if (data.promptFeedback?.blockReason) {
    throw new FunctionFailure(
      422,
      "gemini_refusal",
      "The recommendation service could not complete this request.",
    );
  }
  throw new FunctionFailure(
    502,
    "empty_ai_response",
    "The recommendation service returned an empty response.",
    true,
  );
}

export async function requestGeminiRecommendation(
  apiKey: string,
  model: string,
  attributes: Record<string, unknown>,
  style: string,
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [{ text: makeupRecommendationPrompt(attributes, style) }],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: MAKEUP_RECOMMENDATION_SCHEMA,
      maxOutputTokens: 4096,
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
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.ok) return responseText(await response.json());
      const transient = response.status === 429 || response.status >= 500;
      if (transient && attempt < maximumAttempts) continue;
      throw new FunctionFailure(
        response.status === 429 ? 503 : 502,
        response.status === 429
          ? "gemini_rate_limited"
          : "gemini_upstream_error",
        "The recommendation service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      throw new FunctionFailure(
        504,
        "gemini_timeout",
        "Recommendation generation took too long. Please try again.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "gemini_unavailable",
    "The recommendation service is unavailable.",
    true,
  );
}
