import { encodeBase64 } from "jsr:@std/encoding@1/base64";

import { TUTORIAL_V3_GEOMETRY_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";

const timeoutMs = 60000;
const maximumAttempts = 2;

/**
 * Geometry mapping is a TEXT task: image in, strict JSON out.
 *
 * It runs on `/v1beta` with `responseJsonSchema`, the contract `analyze-face`
 * and the V3 planner already use in production. It must never be pointed at an
 * image-output model, and any image bytes in the response are treated as a
 * fault rather than passed through.
 */
function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<{
      content?: { parts?: Array<{ text?: string; inlineData?: unknown }> };
      finishReason?: string;
    }>;
    promptFeedback?: { blockReason?: string };
  };
  const candidate = data.candidates?.[0];
  const parts = candidate?.content?.parts ?? [];

  if (parts.some((part) => part.inlineData)) {
    // The mapper must never produce pixels. Surfacing this as a configuration
    // fault keeps a mis-set model from silently becoming an image generator.
    throw new FunctionFailure(
      500,
      "unexpected_image_output",
      "The geometry service is not configured correctly.",
    );
  }

  const text = parts.map((part) => part.text ?? "").join("").trim();
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
      "geometry_truncated",
      "The guideline was cut short. Please try again.",
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

export async function requestGeometry(
  apiKey: string,
  model: string,
  prompt: string,
  selfie: { bytes: Uint8Array; mimeType: string },
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;

  // Exactly one image: the original selfie. The canonical final preview is
  // never sent — V3-6A.2 proved a second reference image drives style transfer,
  // and the mapper does not need the destination to locate an instruction.
  const body = JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: prompt },
        {
          inlineData: {
            mimeType: selfie.mimeType,
            data: encodeBase64(selfie.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: TUTORIAL_V3_GEOMETRY_SCHEMA,
      maxOutputTokens: 8192,
      // Geometry is a measurement, not a creative act. Variety is a defect.
      temperature: 0.1,
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
        console.error(`[map-tutorial-v3-geometry] model not found model=${model}`);
        throw new FunctionFailure(
          500,
          "GEMINI_MODEL_NOT_FOUND",
          "The tutorial service is not configured correctly.",
        );
      }
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[map-tutorial-v3-geometry] upstream status=${response.status} attempt=${attempt}`,
      );
      if (transient && attempt < maximumAttempts) {
        // V3-6R saw a transient 503 "high demand"; one backed-off retry
        // absorbs it without turning a blip into a failed step.
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      throw new FunctionFailure(
        response.status === 429 ? 503 : 502,
        response.status === 429 ? "gemini_rate_limited" : "gemini_upstream_error",
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
          "Preparing this step took too long. Please try again.",
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
