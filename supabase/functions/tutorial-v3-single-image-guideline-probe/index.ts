import "jsr:@supabase/functions-js/edge-runtime.d.ts";

/**
 * TEMPORARY smoke probe for the V3-6A.2 single-image renderer gate.
 *
 * IT IS NOT PRODUCTION CODE AND MUST BE DELETED AFTER THE GATE RUNS.
 * The production function is `generate-tutorial-v3-guideline` (V3-6B, not yet
 * authorized) and must be written separately.
 *
 * Two differences from the V3-6A.1 probe, both load-bearing:
 *
 * 1. It accepts EXACTLY ONE image and rejects anything else. V3-6A.1 proved
 *    that giving the model the canonical final preview as a second image
 *    causes finished makeup to leak into unrelated categories. That
 *    architecture is rejected, and this probe makes it unrepresentable rather
 *    than merely discouraged.
 *
 * 2. Authentication does not touch shared Supabase secrets. `supabase secrets
 *    set/unset` redeploys every function in the project (observed in V3-6A.1:
 *    all nine production functions advanced two versions), so this probe is
 *    deployed with JWT verification ON — the platform requires a valid project
 *    JWT — plus an ephemeral token compiled in at deploy time as a second
 *    factor, since the anon JWT is client-distributable.
 *
 * The ephemeral token is substituted into PROBE_TOKEN at deploy time and never
 * committed. A deployed probe with the placeholder still in place refuses every
 * request.
 */

const PROBE_TOKEN = "__EPHEMERAL_PROBE_TOKEN__";

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

/** Length-independent constant-time comparison. */
function tokensMatch(provided: string, expected: string): boolean {
  const a = new TextEncoder().encode(provided);
  const b = new TextEncoder().encode(expected);
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i += 1) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

interface InlineImage {
  mimeType: string;
  data: string;
}

interface ProbeRequest {
  prompt: string;
  image: InlineImage;
}

/**
 * Parses the request, enforcing the single-image contract.
 *
 * The shape itself only permits one image: `image` is a single object, not an
 * array. `images`, `parts` and any other multi-image field is rejected
 * outright so a caller cannot smuggle a second image through a field this
 * probe would otherwise ignore.
 */
function parseRequest(value: unknown): ProbeRequest {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("body must be a JSON object");
  }
  const body = value as Record<string, unknown>;

  for (const forbidden of ["images", "parts", "image2", "canonicalPreview", "target"]) {
    if (body[forbidden] !== undefined) {
      throw new Error(
        `field "${forbidden}" is not accepted: this renderer takes exactly one image`,
      );
    }
  }

  const prompt = body.prompt;
  if (typeof prompt !== "string" || prompt.trim().length === 0) {
    throw new Error("prompt must be a non-empty string");
  }

  const image = body.image as Record<string, unknown> | undefined;
  if (!image || typeof image !== "object" || Array.isArray(image)) {
    throw new Error("image must be a single inline image object");
  }
  const mimeType = image.mimeType;
  const data = image.data;
  if (
    typeof mimeType !== "string" ||
    !["image/png", "image/jpeg", "image/webp"].includes(mimeType) ||
    typeof data !== "string" || data.length === 0
  ) {
    throw new Error("image is malformed");
  }

  return { prompt, image: { mimeType, data } };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }

  // Prefix check, NOT equality against the placeholder literal: deploy-time
  // substitution rewrites every occurrence of the placeholder in this file, so
  // an equality check would rewrite itself too and compare the real token
  // against itself — always true, refusing every request. (Observed exactly
  // that on the first deploy of this probe.)
  if (PROBE_TOKEN.startsWith("__EPHEMERAL")) {
    // Deployed without token substitution: refuse everything rather than
    // sit on the internet accepting any JWT-bearing caller.
    return json({ error: "probe_not_configured" }, 500);
  }
  const provided = request.headers.get("x-tutorial-v3-probe-token") ?? "";
  if (!tokensMatch(provided, PROBE_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) return json({ error: "gemini_not_configured" }, 500);

  // V3 reads its own variable so the premium preview stays insulated.
  const model = Deno.env.get("TUTORIAL_V3_GUIDELINE_MODEL")?.trim() ||
    "gemini-3.1-flash-image";

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  let parsed: ProbeRequest;
  try {
    parsed = parseRequest(payload);
  } catch (error) {
    return json(
      { error: "invalid_request", detail: (error as Error).message },
      400,
    );
  }

  // Exactly one image part, constructed here rather than forwarded from the
  // caller. There is no code path that can produce two.
  const parts = [
    { text: parsed.prompt },
    {
      inlineData: {
        mimeType: parsed.image.mimeType,
        data: parsed.image.data,
      },
    },
  ];
  const imagePartCount = parts.filter((part) => "inlineData" in part).length;
  if (imagePartCount !== 1) {
    return json({ error: "single_image_contract_violated", imagePartCount }, 500);
  }

  const started = Date.now();
  try {
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
      console.error(`[v3-single-probe] upstream status=${response.status}`);
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        imagePartCount,
        detail,
      });
    }

    const body = await response.json() as {
      candidates?: Array<{
        content?: {
          parts?: Array<
            { text?: string; inlineData?: { data?: unknown; mimeType?: unknown } }
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
      console.error(`[v3-single-probe] no_image parts=${partKinds.join(",")}`);
      return json({
        ok: false,
        httpStatus: response.status,
        elapsedMs,
        model,
        imagePartCount,
        partKinds,
        finishReason: candidate?.finishReason ?? null,
        blockReason: body.promptFeedback?.blockReason ?? null,
        text: responseParts.map((part) => part.text ?? "").join("").slice(0, 600),
      });
    }

    console.log(`[v3-single-probe] image_received parts=${partKinds.join(",")}`);
    return json({
      ok: true,
      httpStatus: response.status,
      elapsedMs,
      model,
      imagePartCount,
      partKinds,
      finishReason: candidate?.finishReason ?? null,
      mimeType: imagePart.inlineData.mimeType,
      data: imagePart.inlineData.data,
    });
  } catch (error) {
    console.error(
      `[v3-single-probe] failed type=${
        (error as Error)?.constructor?.name ?? "unknown"
      }`,
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
