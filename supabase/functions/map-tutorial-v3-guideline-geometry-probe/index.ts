import "jsr:@supabase/functions-js/edge-runtime.d.ts";

import { PROBE_TOKEN } from "./probe_token.ts";
import { TUTORIAL_V3_GEOMETRY_SCHEMA } from "./schema.ts";

/**
 * TEMPORARY probe for the V3-6R deterministic geometry renderer gate.
 *
 * IT IS NOT PRODUCTION CODE AND MUST BE DELETED AFTER THE GATE RUNS.
 * The production mapper belongs to V3-6B, which is not authorized.
 *
 * This is a TEXT task: image in, strict JSON out, on `/v1beta` with
 * `responseJsonSchema` — the contract `analyze-face` and the V3 planner
 * already run in production. It must never be pointed at an image-output
 * model, and it never returns image bytes.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-tutorial-v3-probe-token",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function tokensMatch(provided: string, expected: string): boolean {
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  // A deployed-but-unconfigured probe accepts nothing. The placeholder token
  // is short, so this guard cannot be defeated by token substitution.
  if (PROBE_TOKEN.length < 32) return json({ error: "probe_not_configured" }, 500);
  if (!tokensMatch(request.headers.get("x-tutorial-v3-probe-token") ?? "", PROBE_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) return json({ error: "gemini_not_configured" }, 500);

  // The geometry mapper has its OWN variable. It must never borrow
  // GEMINI_IMAGE_MODEL or GEMINI_MODEL.
  const model = Deno.env.get("TUTORIAL_V3_GEOMETRY_MODEL")?.trim() ||
    "gemini-3.6-flash";

  let payload: Record<string, unknown>;
  try {
    payload = await request.json() as Record<string, unknown>;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  // Exactly one image, and no field through which a canonical preview or a
  // previous overlay could be smuggled in.
  for (const forbidden of ["images", "parts", "image2", "canonicalPreview", "target", "previousGeometry"]) {
    if (payload[forbidden] !== undefined) {
      return json({
        error: "invalid_request",
        detail: `field "${forbidden}" is not accepted: the mapper takes exactly one image`,
      }, 400);
    }
  }

  const prompt = payload.prompt;
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    return json({ error: "invalid_request", detail: "prompt required" }, 400);
  }
  const image = payload.image as Record<string, unknown> | undefined;
  if (
    !image || typeof image.mimeType !== "string" ||
    !["image/png", "image/jpeg", "image/webp"].includes(image.mimeType) ||
    typeof image.data !== "string" || image.data.length === 0
  ) {
    return json({ error: "invalid_request", detail: "image malformed" }, 400);
  }

  const parts = [
    { text: prompt },
    { inlineData: { mimeType: image.mimeType, data: image.data } },
  ];
  const imagePartCount = parts.filter((part) => "inlineData" in part).length;
  if (imagePartCount !== 1) {
    return json({ error: "single_image_contract_violated", imagePartCount }, 500);
  }

  const started = Date.now();
  try {
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${
        encodeURIComponent(model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({
          contents: [{ role: "user", parts }],
          generationConfig: {
            responseMimeType: "application/json",
            responseJsonSchema: TUTORIAL_V3_GEOMETRY_SCHEMA,
            maxOutputTokens: 8192,
            // Geometry is a measurement, not a creative act. Variety here is
            // a defect.
            temperature: 0.1,
            topP: 0.9,
            candidateCount: 1,
          },
        }),
        signal: AbortSignal.timeout(120000),
      },
    );
    const elapsedMs = Date.now() - started;

    if (!response.ok) {
      const detail = (await response.text().catch(() => ""))
        .replace(/\s+/g, " ").slice(0, 400);
      console.error(`[v3-geometry-probe] upstream status=${response.status}`);
      return json({ ok: false, httpStatus: response.status, elapsedMs, model, detail });
    }

    const body = await response.json() as {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string; inlineData?: unknown }> };
        finishReason?: string;
      }>;
      promptFeedback?: { blockReason?: string };
    };
    const candidate = body.candidates?.[0];
    const responseParts = candidate?.content?.parts ?? [];

    // A geometry response must be text. Image bytes here would mean the model
    // or the configuration is wrong, and the gate must see that, not ignore it.
    const imageParts = responseParts.filter((part) => part.inlineData).length;
    if (imageParts > 0) {
      console.error("[v3-geometry-probe] unexpected image output");
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        error: "unexpected_image_output",
        imageParts,
      });
    }

    const text = responseParts.map((part) => part.text ?? "").join("").trim();
    if (!text) {
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        error: "empty_response",
        finishReason: candidate?.finishReason ?? null,
        blockReason: body.promptFeedback?.blockReason ?? null,
      });
    }

    console.log(`[v3-geometry-probe] geometry_received chars=${text.length}`);
    return json({
      ok: true,
      httpStatus: response.status,
      elapsedMs,
      model,
      imagePartCount,
      finishReason: candidate?.finishReason ?? null,
      geometryJson: text,
    });
  } catch (error) {
    console.error(
      `[v3-geometry-probe] failed type=${(error as Error)?.constructor?.name ?? "unknown"}`,
    );
    return json({
      ok: false,
      elapsedMs: Date.now() - started,
      model,
      error: "probe_request_failed",
      detail: (error as Error)?.message?.slice(0, 300) ?? "unknown",
    });
  }
});
