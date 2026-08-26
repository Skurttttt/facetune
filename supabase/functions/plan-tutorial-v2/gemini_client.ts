import { encodeBase64 } from "jsr:@std/encoding@1/base64";

import { type PlannerInput, tutorialV2PlannerPrompt } from "./prompt.ts";
import { TUTORIAL_V2_PLAN_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const timeoutMs = 60000;
const maximumAttempts = 2;

function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<
      { content?: { parts?: Array<{ text?: string }> }; finishReason?: string }
    >;
    promptFeedback?: { blockReason?: string };
  };
  const candidate = data.candidates?.[0];
  const text = candidate?.content?.parts?.map((part) => part.text ?? "").join(
    "",
  ).trim();
  if (text) return text;
  if (data.promptFeedback?.blockReason) {
    throw new FunctionFailure(
      422,
      "gemini_refusal",
      "The tutorial service could not complete this request.",
    );
  }
  if (candidate?.finishReason === "MAX_TOKENS") {
    throw new FunctionFailure(
      502,
      "plan_truncated",
      "The tutorial plan was cut short. Please try again.",
      true,
    );
  }
  throw new FunctionFailure(
    502,
    "empty_ai_response",
    "The tutorial service returned an empty response.",
    true,
  );
}

/**
 * Asks the planner to decompose the canonical final preview into steps.
 *
 * The canonical preview is sent as inline image data so the planner is
 * decomposing the actual target rather than a description of it.
 */
export async function requestTutorialV2Plan(
  apiKey: string,
  model: string,
  input: PlannerInput,
  canonicalImage: { bytes: Uint8Array; mimeType: string },
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: tutorialV2PlannerPrompt(input) },
        {
          inlineData: {
            mimeType: canonicalImage.mimeType,
            data: encodeBase64(canonicalImage.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: TUTORIAL_V2_PLAN_SCHEMA,
      maxOutputTokens: 8192,
      // Lower than the recommendation planner: a tutorial is a decomposition
      // of an image that already exists, so variety is a defect here, not a
      // feature.
      temperature: 0.2,
      topP: 0.9,
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
      if (response.status === 404) {
        // A missing model must surface as a configuration fault rather than a
        // transient upstream error, so a bad TUTORIAL_V2_PLANNER_MODEL is
        // obvious instead of looking like an outage.
        console.error(
          `[plan-tutorial-v2] Planner model not found model=${model}`,
        );
        throw new FunctionFailure(
          500,
          "GEMINI_MODEL_NOT_FOUND",
          "The tutorial service is not configured correctly.",
        );
      }
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[plan-tutorial-v2] Gemini request failed status=${response.status} attempt=${attempt}`,
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
        "The tutorial service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new FunctionFailure(
          504,
          "gemini_timeout",
          "Planning your tutorial took too long. Please try again.",
          true,
        );
      }
      throw new FunctionFailure(
        503,
        "gemini_network_error",
        "The tutorial service could not be reached.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "gemini_unavailable",
    "The tutorial service is unavailable.",
    true,
  );
}
