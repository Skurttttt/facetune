import { kitMakeupRecommendationPrompt } from "./prompt.ts";
import { KIT_MAKEUP_RECOMMENDATION_SCHEMA } from "./schema.ts";
import type { KitProduct } from "./types.ts";
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
      "The kit recommendation could not be completed.",
    );
  }
  throw new FunctionFailure(
    502,
    "empty_ai_response",
    "The kit recommendation service returned an empty response.",
    true,
  );
}

export async function requestGeminiKitRecommendation(
  apiKey: string,
  model: string,
  attributes: Record<string, unknown>,
  style: string,
  products: KitProduct[],
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [{
        text: kitMakeupRecommendationPrompt(attributes, style, products),
      }],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: KIT_MAKEUP_RECOMMENDATION_SCHEMA,
      maxOutputTokens: 4096,
      temperature: 0.2,
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
        signal: AbortSignal.timeout(timeoutMs),
      });
      if (response.ok) return responseText(await response.json());
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[generate-kit-makeup-recommendation] Gemini failed status=${response.status} attempt=${attempt}`,
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
        "The kit recommendation service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new FunctionFailure(
          504,
          "gemini_timeout",
          "Kit recommendation generation took too long.",
          true,
        );
      }
      throw new FunctionFailure(
        503,
        "gemini_network_error",
        "The kit recommendation service could not be reached.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "gemini_unavailable",
    "The kit recommendation service is unavailable.",
    true,
  );
}
