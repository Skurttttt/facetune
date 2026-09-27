import {
  noteProviderAttempt,
  readProviderUsage,
  type UsageSink,
} from "../_shared/ai_telemetry.ts";
import {
  KIT_PREVIEW_VALIDATOR_SCHEMA,
  KIT_PREVIEW_VALIDATOR_USER_TEXT,
  kitPreviewValidatorSystemInstruction,
} from "./validator_prompt.ts";

const requestTimeoutMs = 45000;
const maximumAttempts = 2;

export type ValidatorImage = { bytes: Uint8Array; mimeType: string };

/** A provider failure, classified. Never carries upstream text. */
export class ValidatorProviderError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** The model the validator classifies with. A text model with vision, like
 * the Tutorial manifest analyzer; it never generates images. */
export function validatorModel(): string {
  return Deno.env.get("GEMINI_VALIDATOR_MODEL")?.trim() || "gemini-3.6-flash";
}

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

/**
 * Sends ORIGINAL then CANDIDATE and returns the model's JSON text.
 *
 * Throws [ValidatorProviderError] when no trustworthy answer arrived: a
 * transport failure, an upstream error, a refusal, or an empty response.
 * Parsing and judging the answer is the caller's job.
 */
export async function requestGeminiKitPreviewValidation(
  apiKey: string,
  model: string,
  original: ValidatorImage,
  candidate: ValidatorImage,
  usageSink?: UsageSink,
  budgetMs = requestTimeoutMs * maximumAttempts,
): Promise<string> {
  const startedAt = Date.now();
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const body = JSON.stringify({
    systemInstruction: {
      parts: [{ text: kitPreviewValidatorSystemInstruction() }],
    },
    contents: [{
      role: "user",
      parts: [
        { text: KIT_PREVIEW_VALIDATOR_USER_TEXT },
        {
          inlineData: {
            mimeType: original.mimeType,
            data: encodeBase64(original.bytes),
          },
        },
        {
          inlineData: {
            mimeType: candidate.mimeType,
            data: encodeBase64(candidate.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: KIT_PREVIEW_VALIDATOR_SCHEMA,
      maxOutputTokens: 4096,
      temperature: 0,
      candidateCount: 1,
    },
  });
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    const remainingMs = budgetMs - (Date.now() - startedAt);
    if (remainingMs <= 0) break;
    try {
      noteProviderAttempt(usageSink, attempt);
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(Math.min(requestTimeoutMs, remainingMs)),
      });
      if (response.ok) {
        const payload = await response.json();
        const text = responseText(payload);
        if (usageSink) usageSink.usage = readProviderUsage(payload, attempt);
        return text;
      }
      const transient = response.status === 429 || response.status >= 500;
      console.error(
        `[generate-kit-makeup-preview] validator_failed status=${response.status} attempt=${attempt}`,
      );
      if (transient && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      throw new ValidatorProviderError(
        response.status === 429
          ? "validator_rate_limited"
          : "validator_upstream_error",
      );
    } catch (error) {
      if (error instanceof ValidatorProviderError) throw error;
      if (attempt < maximumAttempts) continue;
      throw new ValidatorProviderError(
        error instanceof DOMException && error.name === "TimeoutError"
          ? "validator_timeout"
          : "validator_network_error",
      );
    }
  }
  throw new ValidatorProviderError("validator_timeout");
}

function responseText(payload: unknown): string {
  const data = payload as {
    candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    promptFeedback?: { blockReason?: string };
  };
  const text = data.candidates?.[0]?.content?.parts?.map((part) =>
    part.text ?? ""
  ).join("").trim();
  if (text) return text;
  throw new ValidatorProviderError(
    data.promptFeedback?.blockReason ? "validator_refused" : "validator_empty",
  );
}
