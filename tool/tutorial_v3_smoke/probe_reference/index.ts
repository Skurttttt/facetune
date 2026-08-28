import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * TEMPORARY smoke probe for the V3-6A.1 behavioural gate.
 *
 * It exists for one reason: `GEMINI_API_KEY` is a server-side Supabase secret,
 * so the two-image guideline call cannot be made from a developer machine.
 * This probe borrows that secret, makes the call, and returns the bytes.
 *
 * IT IS NOT PRODUCTION CODE AND MUST BE DELETED AFTER THE GATE RUNS.
 *
 * Note especially that this probe accepts a caller-supplied prompt. That is
 * acceptable *only* because it is token-gated, temporary, and exists to let the
 * gate iterate prompt variants without redeploying. The production function
 * (`generate-tutorial-v3-guideline`) must do the opposite: build the prompt
 * server-side from the persisted Step Spec and never accept instruction text
 * from a client.
 */

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-tutorial-v3-smoke-token",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

/** Length-independent constant-time comparison. */
function tokensMatch(provided: string, expected: string): boolean {
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  // Compare a fixed number of bytes so a length difference does not short
  // circuit; the length check is folded into the accumulator.
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) {
    diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  }
  return diff === 0;
}

type GeminiPart =
  | { text: string }
  | { inlineData: { mimeType: string; data: string } };

/**
 * Accepts an ORDERED parts array rather than prompt+images.
 *
 * Ordering is the point: the gate needs to test placing role statements
 * immediately adjacent to their image part (text, IMAGE 1, text, IMAGE 2,
 * text), which a prompt+images shape cannot express.
 */
function parseParts(value: unknown): GeminiPart[] {
  if (!Array.isArray(value) || value.length === 0 || value.length > 8) {
    throw new Error("parts must be an array of 1 to 8 entries");
  }
  let imageCount = 0;
  const parts = value.map((entry, index) => {
    const part = entry as Record<string, unknown>;
    if (typeof part.text === "string") {
      if (part.text.trim().length === 0) {
        throw new Error(`part ${index + 1} has empty text`);
      }
      return { text: part.text } as GeminiPart;
    }
    const inline = part.inlineData as Record<string, unknown> | undefined;
    if (
      !inline || typeof inline.mimeType !== "string" ||
      !["image/png", "image/jpeg", "image/webp"].includes(inline.mimeType) ||
      typeof inline.data !== "string" || inline.data.length === 0
    ) {
      throw new Error(`part ${index + 1} is malformed`);
    }
    imageCount += 1;
    return {
      inlineData: { mimeType: inline.mimeType, data: inline.data },
    } as GeminiPart;
  });
  if (imageCount === 0 || imageCount > 2) {
    throw new Error("parts must contain 1 or 2 images");
  }
  return parts;
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  const expectedToken = Deno.env.get("TUTORIAL_V3_SMOKE_TOKEN")?.trim();
  if (!expectedToken) {
    return json({ error: "probe_not_configured" }, 500);
  }
  const providedToken = request.headers.get("x-tutorial-v3-smoke-token") ?? "";
  if (!tokensMatch(providedToken, expectedToken)) {
    return json({ error: "unauthorized" }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    return json({ error: "gemini_not_configured" }, 500);
  }

  // V3 reads its OWN variable. GEMINI_IMAGE_MODEL is deliberately not used, so
  // the premium preview stays insulated from V3 model changes.
  const model = Deno.env.get("TUTORIAL_V3_GUIDELINE_MODEL")?.trim() ||
    "gemini-3.1-flash-image";

  let payload: Record<string, unknown>;
  try {
    payload = await request.json() as Record<string, unknown>;
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  let parts: GeminiPart[];
  try {
    parts = parseParts(payload.parts);
  } catch (error) {
    return json(
      { error: "invalid_parts", detail: (error as Error).message },
      400,
    );
  }

  const started = Date.now();
  try {
    // Image output lives on /v1 with no generationConfig, matching the proven
    // premium-preview client exactly. Image parts follow the text part in the
    // order supplied: IMAGE 1 first, IMAGE 2 second.
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/${
        encodeURIComponent(model)
      }:generateContent`,
      {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body: JSON.stringify({ contents: [{ role: "user", parts }] }),
        signal: AbortSignal.timeout(120000),
      },
    );

    const elapsedMs = Date.now() - started;

    if (!response.ok) {
      const detail = (await response.text().catch(() => ""))
        .replace(/\s+/g, " ")
        .slice(0, 400);
      console.error(
        `[v3-smoke-probe] upstream_failed status=${response.status}`,
      );
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        detail,
      }, 200);
    }

    const body = await response.json() as {
      candidates?: Array<{
        content?: {
          parts?: Array<
            {
              text?: string;
              inlineData?: { data?: unknown; mimeType?: unknown };
            }
          >;
        };
        finishReason?: string;
      }>;
      promptFeedback?: { blockReason?: string };
    };

    const candidate = body.candidates?.[0];
    const responseParts = candidate?.content?.parts ?? [];
    const partKinds = responseParts.map((part) =>
      part.inlineData?.data ? "inlineData" : part.text ? "text" : "unknown"
    );
    const imagePart = responseParts.find((part) => part.inlineData?.data);

    if (!imagePart?.inlineData) {
      console.error(
        `[v3-smoke-probe] no_image parts=${partKinds.join(",")}`,
      );
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        partKinds,
        finishReason: candidate?.finishReason ?? null,
        blockReason: body.promptFeedback?.blockReason ?? null,
        text: responseParts.map((part) => part.text ?? "").join("").slice(0, 600),
      }, 200);
    }

    console.log(`[v3-smoke-probe] image_received parts=${partKinds.join(",")}`);
    return json({
      ok: true,
      httpStatus: response.status,
      elapsedMs,
      model,
      partKinds,
      finishReason: candidate?.finishReason ?? null,
      mimeType: imagePart.inlineData.mimeType,
      data: imagePart.inlineData.data,
    });
  } catch (error) {
    console.error(
      `[v3-smoke-probe] request_failed type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
    );
    return json({
      ok: false,
      elapsedMs: Date.now() - started,
      model,
      error: "probe_request_failed",
      detail: (error as Error)?.message?.slice(0, 300) ?? "unknown",
    }, 200);
  }
});
