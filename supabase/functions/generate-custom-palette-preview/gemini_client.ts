import { resolveFinalPreviewModel } from "../_shared/final_preview_model.ts";
import { validateGeneratedImage } from "../generate-makeup-preview/image_validation.ts";
import type { PreviewImage, PreviewPorts } from "./pipeline.ts";
import { CUSTOM_PALETTE_VALIDATOR_SCHEMA } from "./validator_prompt.ts";

/// One image attempt: the same ceiling the existing Final Preview paths use.
const imageTimeoutMs = 90000;
const validatorTimeoutMs = 45000;

/** A provider call that failed. Carries a status only, never provider text. */
export class ProviderCallFailed extends Error {
  constructor(readonly status: number | null) {
    super("provider_call_failed");
    this.name = "ProviderCallFailed";
  }
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

function inlineImage(image: PreviewImage) {
  return {
    inlineData: { mimeType: image.mimeType, data: encodeBase64(image.bytes) },
  };
}

async function callGemini(
  apiKey: string,
  model: string,
  body: unknown,
  timeoutMs: number,
): Promise<unknown> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeoutMs),
  });
  if (!response.ok) {
    await response.body?.cancel();
    console.error(
      `[generate-custom-palette-preview] Gemini failed status=${response.status}`,
    );
    throw new ProviderCallFailed(response.status);
  }
  return await response.json();
}

/**
 * The real provider ports.
 *
 * Each call is made once: this module does not retry, because a retry is a new
 * attempt that the caller must count. The image model comes from the Final
 * Preview lock and is checked before any request, so a misconfigured deployment
 * spends nothing. The validator reads images, so it is a text model, configured
 * the same way as the app's other text calls.
 */
export function createGeminiPreviewPorts(
  apiKey: string,
  options: { deadlineMs?: number } = {},
): PreviewPorts {
  // A retry may be shortened by the budget. It is never lengthened.
  const within = (ceilingMs: number) =>
    options.deadlineMs === undefined
      ? ceilingMs
      : Math.max(1, Math.min(ceilingMs, options.deadlineMs - Date.now()));
  return {
    async generateImage(prompt, original) {
      const model = resolveFinalPreviewModel();
      const payload = await callGemini(apiKey, model, {
        contents: [{
          role: "user",
          parts: [{ text: prompt }, inlineImage(original)],
        }],
      }, within(imageTimeoutMs)) as {
        candidates?: Array<{
          content?: {
            parts?: Array<{
              inlineData?: { data?: unknown; mimeType?: unknown };
            }>;
          };
        }>;
      };
      const part = payload.candidates?.[0]?.content?.parts?.find(
        (candidate) => candidate.inlineData?.data,
      );
      if (!part?.inlineData) throw new ProviderCallFailed(null);
      const image = validateGeneratedImage(
        part.inlineData.data,
        part.inlineData.mimeType,
      );
      return { bytes: image.bytes, mimeType: image.mimeType, model };
    },
    async requestValidation(prompt, original, candidate) {
      const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";
      const payload = await callGemini(apiKey, model, {
        contents: [{
          role: "user",
          parts: [
            { text: prompt },
            { text: "IMAGE A (original):" },
            inlineImage(original),
            { text: "IMAGE B (candidate):" },
            inlineImage(candidate),
          ],
        }],
        generationConfig: {
          responseMimeType: "application/json",
          responseJsonSchema: CUSTOM_PALETTE_VALIDATOR_SCHEMA,
          maxOutputTokens: 2048,
          temperature: 0,
          candidateCount: 1,
        },
      }, within(validatorTimeoutMs)) as {
        candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
      };
      const text = payload.candidates?.[0]?.content?.parts?.map((part) =>
        part.text ?? ""
      ).join("").trim();
      if (!text) throw new ProviderCallFailed(null);
      return text;
    },
  };
}
