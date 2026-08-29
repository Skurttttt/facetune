import { encodeBase64 } from "jsr:@std/encoding@1/base64";

import {
  describeGeminiError,
  geminiErrorLogLine,
  geminiFailureFor,
} from "../_shared/gemini_error.ts";

import { type PlannerInput, tutorialV3PlannerPrompt } from "./prompt.ts";
import { TUTORIAL_V3_PLAN_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const timeoutMs = 60000;
const maximumAttempts = 2;

/**
 * The first bytes of the image, as hex, so a declared MIME that disagrees with
 * the actual file is visible in a log line. Four bytes identify PNG, JPEG and
 * WEBP without revealing anything about the picture.
 */
function magicBytesOf(bytes: Uint8Array): string {
  return Array.from(bytes.slice(0, 4))
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Planning is a TEXT task, not an image task.
 *
 * It takes an image IN and returns structured JSON OUT, which is the same
 * contract `analyze-face` and `generate-makeup-recommendation` already run in
 * production on `GEMINI_MODEL`. That is why the planner is configured
 * separately from `GEMINI_IMAGE_MODEL`: guideline generation needs image bytes
 * OUT and is a different capability entirely. Sending an image *in* proves
 * nothing about getting an image *out*.
 */
function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<
      { content?: { parts?: Array<{ text?: string }> }; finishReason?: string }
    >;
    promptFeedback?: { blockReason?: string };
  };
  const candidate = data.candidates?.[0];
  const text = candidate?.content?.parts
    ?.map((part) => part.text ?? "")
    .join("")
    .trim();
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
export async function requestTutorialV3Plan(
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
        { text: tutorialV3PlannerPrompt(input) },
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
      responseJsonSchema: TUTORIAL_V3_PLAN_SCHEMA,
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

      // The body is the only place the reason lives: Gemini answers 400 for an
      // invalid schema, an unusable API key and a billing precondition alike.
      // Discarding it is what made the production failure undiagnosable.
      const detail = await describeGeminiError(response);
      console.error(geminiErrorLogLine("plan-tutorial-v3", attempt, detail));
      if (detail.kind === "model_not_found") {
        // A missing model must surface as a configuration fault rather than a
        // transient upstream error, so a bad TUTORIAL_V3_PLANNER_MODEL is
        // obvious instead of looking like an outage.
        console.error(
          `[plan-tutorial-v3] planner model not found model=${model}`,
        );
      }
      // Only a genuinely transient condition earns a second attempt. An
      // invalid request is deterministic: the identical body would be rejected
      // identically, so retrying it is latency theatre.
      if (detail.retryable && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      if (detail.kind === "invalid_request") {
        // Gemini says only "Request contains an invalid argument", so the shape
        // of the request is recorded alongside it. Sizes, MIME and a four-byte
        // signature — never content. This is what made the V3-10F4.4 bisection
        // possible and what would make the next one cheap; it costs one line
        // on a failure that has already ended the request.
        console.error(
          `[plan-tutorial-v3] request_metrics model=${model} ` +
            `body_bytes=${body.length} image_bytes=${canonicalImage.bytes.length} ` +
            `image_mime=${canonicalImage.mimeType} ` +
            `image_magic=${magicBytesOf(canonicalImage.bytes)} ` +
            `schema_bytes=${JSON.stringify(TUTORIAL_V3_PLAN_SCHEMA).length} ` +
            `parts=2 contents=1`,
        );
      }
      const mapping = geminiFailureFor(detail);
      throw new FunctionFailure(
        mapping.status,
        mapping.code,
        mapping.configuration
          ? "The tutorial service is not configured correctly."
          : "The tutorial service is temporarily unavailable.",
        mapping.retryable,
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
