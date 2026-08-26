import { tutorialGeometryPlanPrompt } from "./prompt.ts";
import type { TutorialFaceAttributes } from "./prompt.ts";
import type { CategoryProductFacts } from "./types.ts";
import { TUTORIAL_GEOMETRY_PLAN_SCHEMA } from "./schema.ts";
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
        "GEMINI_PLANNING_REFUSAL",
        "[GEMINI_PLANNING_REFUSAL] The geometry planning service could not process this selfie.",
      );
    }
    throw new FunctionFailure(
      502,
      "GEMINI_EMPTY_RESPONSE",
      "[GEMINI_EMPTY_RESPONSE] The geometry planning service returned an empty response.",
      true,
    );
  }
  return text;
}

export async function requestGeminiGeometryPlan(params: {
  apiKey: string;
  model: string;
  selfieBytes: Uint8Array;
  selfieMimeType: string;
  selectedStyle?: string;
  sourceMode?: string;
  faceAttributes: TutorialFaceAttributes;
  categories: CategoryProductFacts[];
}): Promise<string> {
  const {
    apiKey,
    model,
    selfieBytes,
    selfieMimeType,
    selectedStyle,
    sourceMode,
    faceAttributes,
    categories,
  } = params;
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        {
          text: tutorialGeometryPlanPrompt({
            selectedStyle,
            sourceMode,
            faceAttributes,
            categories,
          }),
        },
        {
          inlineData: {
            mimeType: selfieMimeType,
            data: encodeBase64(selfieBytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: TUTORIAL_GEOMETRY_PLAN_SCHEMA,
      maxOutputTokens: 4096,
      // Placement geometry must be repeatable and grounded, not creative --
      // matches analyze-face/gemini_client.ts's identical rationale for a
      // low, deterministic-leaning temperature.
      temperature: 0.15,
      topP: 0.8,
      candidateCount: 1,
    },
  });

  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    try {
      console.log(
        `[TutorialGeometryPlan] gemini_request_started model=${model} attempt=${attempt} categories=${categories.length}`,
      );
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
        `[TutorialGeometryPlan] gemini_request_failed status=${response.status} attempt=${attempt}`,
      );
      if (transient && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      if (response.status === 429) {
        throw new FunctionFailure(
          503,
          "GEMINI_RATE_LIMITED",
          "[GEMINI_RATE_LIMITED] Geometry planning is busy. Please try again shortly.",
          true,
        );
      }
      throw new FunctionFailure(
        502,
        "GEMINI_UPSTREAM_ERROR",
        "[GEMINI_UPSTREAM_ERROR] The geometry planning service is temporarily unavailable.",
        transient,
      );
    } catch (error) {
      if (error instanceof FunctionFailure) throw error;
      if (attempt < maximumAttempts) continue;
      if (error instanceof DOMException && error.name === "TimeoutError") {
        throw new FunctionFailure(
          504,
          "GEMINI_TIMEOUT",
          "[GEMINI_TIMEOUT] Geometry planning took too long. Please try again.",
          true,
        );
      }
      throw new FunctionFailure(
        503,
        "GEMINI_NETWORK_ERROR",
        "[GEMINI_NETWORK_ERROR] The geometry planning service could not be reached.",
        true,
      );
    }
  }
  throw new FunctionFailure(
    503,
    "GEMINI_UNAVAILABLE",
    "[GEMINI_UNAVAILABLE] The geometry planning service is unavailable.",
    true,
  );
}
