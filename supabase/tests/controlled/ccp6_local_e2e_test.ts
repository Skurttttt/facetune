/**
 * CCP-6 — the real handlers and real ports against a throwaway local stack.
 *
 * Everything is real except Gemini: Auth, row level security, the RPCs, the usage
 * engine and Storage. Only requests to the Gemini host are intercepted, and any
 * other non-loopback request fails, so this cannot reach a provider or a remote
 * project. It refuses to start unless every URL is loopback.
 *
 * Run from `supabase/functions` with LOCAL_SUPABASE_URL, LOCAL_ANON_KEY and
 * LOCAL_SERVICE_ROLE_KEY set:
 *   deno test --no-lock --allow-all ../tests/controlled/ccp6_local_e2e_test.ts
 */
import { assert, assertEquals, assertRejects } from "jsr:@std/assert@1";
import { createClient } from "npm:@supabase/supabase-js@2";

import { createPreview } from "../../functions/generate-custom-palette-preview/handler.ts";
import { createSupabasePorts as previewPorts } from "../../functions/generate-custom-palette-preview/supabase_ports.ts";
import { createRecommendation } from "../../functions/generate-custom-palette-recommendation/handler.ts";
import { createSupabasePorts as recommendationPorts } from "../../functions/generate-custom-palette-recommendation/supabase_ports.ts";

const url = Deno.env.get("LOCAL_SUPABASE_URL") ?? "";
const anon = Deno.env.get("LOCAL_ANON_KEY") ?? "";
const service = Deno.env.get("LOCAL_SERVICE_ROLE_KEY") ?? "";
if (!/^http:\/\/(127\.0\.0\.1|localhost):\d+$/.test(url)) {
  throw new Error("Refusing to run: LOCAL_SUPABASE_URL must be loopback.");
}
Deno.env.set("SUPABASE_URL", url);
Deno.env.set("SUPABASE_ANON_KEY", anon);
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", service);
Deno.env.set("GEMINI_API_KEY", "not-a-real-key");
Deno.env.delete("GEMINI_IMAGE_MODEL");

function pngBytes(seed: number): Uint8Array {
  const bytes = new Uint8Array(11 * 1024);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  bytes[20] = seed;
  return bytes;
}

const PLAN = JSON.stringify({
  applications: [{
    categoryCode: "blush",
    placement: "Along the upper cheekbones toward the temples.",
    technique: "Blend outward in light layers.",
    intensity: "medium",
    reasoning: "This lifts the face and suits the selected style.",
  }],
  overallIntensity: "soft",
  summary: "A balanced look that follows your chosen color.",
});

function observed(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    categories: [{
      categoryCode: "blush",
      featureVisibleInOriginal: true,
      presence: "present",
      color: "consistent",
      colorReason: "none",
      finish: "consistent",
      finishReason: "none",
      ...overrides,
    }],
    introducedCategories: [],
    identity: "preserved",
  });
}
const WRONG = observed({ color: "different", colorReason: "hue_differs" });

/** Canned Gemini. Each validation consumes the next queued answer. */
const gemini = {
  validations: [] as string[],
  imageCalls: 0,
  validatorCalls: 0,
  textCalls: 0,
  imageDelayMs: 0,
  prompts: [] as string[],
};

const realFetch = globalThis.fetch;
globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
  const target = new URL(input instanceof Request ? input.url : String(input));
  if (target.hostname === "generativelanguage.googleapis.com") {
    const body = JSON.parse(String(init?.body));
    const parts = body.contents[0].parts as Array<{ text?: string }>;
    const prompt = parts[0].text ?? "";
    if (target.pathname.includes("gemini-3.1-flash-image")) {
      gemini.imageCalls += 1;
      gemini.prompts.push(prompt);
      await new Promise((resolve) => setTimeout(resolve, gemini.imageDelayMs));
      const data = btoa(String.fromCharCode(...pngBytes(gemini.imageCalls)));
      return Response.json({
        candidates: [{
          content: { parts: [{ inlineData: { data, mimeType: "image/png" } }] },
        }],
      });
    }
    if (prompt.startsWith("You are checking")) {
      gemini.validatorCalls += 1;
      const text = gemini.validations.shift() ?? observed();
      return Response.json({
        candidates: [{ content: { parts: [{ text }] } }],
      });
    }
    gemini.textCalls += 1;
    return Response.json({
      candidates: [{ content: { parts: [{ text: PLAN }] } }],
    });
  }
  if (target.hostname !== "127.0.0.1" && target.hostname !== "localhost") {
    throw new Error(`Refused non-local request to ${target.hostname}`);
  }
  return realFetch(input, init);
};

const admin = createClient(url, service, {
  auth: { persistSession: false, autoRefreshToken: false },
});

async function signUp(): Promise<
  // deno-lint-ignore no-explicit-any
  { userId: string; token: string; client: any }
> {
  const email = `ccp6-${crypto.randomUUID()}@example.invalid`;
  const password = "ccp6-local-password";
  const created = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  assert(!created.error, created.error?.message);
  const session = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const signedIn = await session.auth.signInWithPassword({ email, password });
  assert(!signedIn.error, signedIn.error?.message);
  const token = signedIn.data.session!.access_token;
  const client = createClient(url, anon, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  return { userId: created.data.user!.id, token, client };
}

async function createAnalysis(
  user: Awaited<ReturnType<typeof signUp>>,
): Promise<string> {
  const analysisId = crypto.randomUUID();
  const path =
    `${user.userId}/analyses/${analysisId}/original/${crypto.randomUUID()}.jpg`;
  const uploaded = await user.client.storage.from("face-images").upload(
    path,
    new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]),
    { contentType: "image/jpeg" },
  );
  assert(!uploaded.error, uploaded.error?.message);
  const inserted = await user.client.from("analyses").insert({
    id: analysisId,
    user_id: user.userId,
    original_image_path: path,
    face_shape: "oval",
    eye_shape: "almond",
    lip_shape: "full",
  } as never);
  assert(!inserted.error, inserted.error?.message);
  return analysisId;
}

function http(token: string, body: unknown): Request {
  return new Request("http://local.invalid/fn", {
    method: "POST",
    headers: { authorization: `Bearer ${token}` },
    body: JSON.stringify(body),
  });
}

function recommendationBody(analysisId: string, requestId: string) {
  return {
    paletteRequestId: requestId,
    paletteVersion: "custom_color_palette_contract_v1",
    sourceMode: "custom_color_palette",
    analysisId,
    style: "soft_glam",
    derivedFromPaletteId: null,
    categorySelections: [{
      categoryCode: "blush",
      baseColorValue: "#C8102E",
      adjustedColorValue: "#D93A52",
      colorLabel: "Red",
      finishCode: "matte",
    }],
  };
}

async function recommend(
  user: Awaited<ReturnType<typeof signUp>>,
): Promise<string> {
  const analysisId = await createAnalysis(user);
  const authorization = `Bearer ${user.token}`;
  const result = await createRecommendation(
    http(user.token, recommendationBody(analysisId, crypto.randomUUID())),
    recommendationPorts(authorization),
  );
  return (result.body as { recommendation: { id: string } }).recommendation.id;
}

function preview(
  user: Awaited<ReturnType<typeof signUp>>,
  recommendationId: string,
  operationId: string,
) {
  return createPreview(
    http(user.token, {
      customPaletteRecommendationId: recommendationId,
      operationId,
    }),
    previewPorts(`Bearer ${user.token}`),
  );
}

async function ledger(
  user: Awaited<ReturnType<typeof signUp>>,
  operationId: string,
) {
  const { data } = await user.client
    .from("usage_ledger")
    .select(
      "status, source_mode, canonical_custom_palette_preview_id, sanitized_failure_code",
    )
    .eq("operation_id", operationId)
    .maybeSingle();
  return data as {
    status: string;
    source_mode: string | null;
    canonical_custom_palette_preview_id: string | null;
    sanitized_failure_code: string | null;
  } | null;
}

Deno.test("recommendation: real auth, RLS and service-role insert, then replay", async () => {
  const user = await signUp();
  const analysisId = await createAnalysis(user);
  const requestId = crypto.randomUUID();
  const authorization = `Bearer ${user.token}`;
  const textBefore = gemini.textCalls;

  const first = await createRecommendation(
    http(user.token, recommendationBody(analysisId, requestId)),
    recommendationPorts(authorization),
  );
  const second = await createRecommendation(
    http(user.token, recommendationBody(analysisId, requestId)),
    recommendationPorts(authorization),
  );
  assertEquals(first.body, second.body);
  assertEquals(gemini.textCalls, textBefore + 1, "a replay calls no AI");

  const { data: rows } = await user.client
    .from("custom_palette_recommendations").select("id");
  assertEquals((rows as unknown[]).length, 1);

  const forged = await user.client.from("custom_palette_recommendations")
    .update({ makeup_style: "bridal" } as never)
    .eq("id", (rows as Array<{ id: string }>)[0].id);
  assertEquals(forged.error?.code, "42501");
});

Deno.test("another account cannot use someone's analysis or look", async () => {
  const owner = await signUp();
  const stranger = await signUp();
  const analysisId = await createAnalysis(owner);
  const error = await assertRejects(() =>
    createRecommendation(
      http(
        stranger.token,
        recommendationBody(analysisId, crypto.randomUUID()),
      ),
      recommendationPorts(`Bearer ${stranger.token}`),
    )
  ) as unknown as { code: string };
  assertEquals(error.code, "analysis_not_found");

  const recommendationId = await recommend(owner);
  const previewError = await assertRejects(() =>
    preview(stranger, recommendationId, crypto.randomUUID())
  ) as unknown as { code: string };
  assertEquals(previewError.code, "recommendation_not_found");
});

Deno.test("terminal failure: bound, release, no charge, no file", async () => {
  const user = await signUp();
  const recommendationId = await recommend(user);
  const operationId = crypto.randomUUID();
  gemini.validations = [WRONG, WRONG];
  const before = gemini.imageCalls;

  const error = await assertRejects(() =>
    preview(user, recommendationId, operationId)
  ) as unknown as { code: string };
  assertEquals(error.code, "palette_preview_mismatch");
  assertEquals(gemini.imageCalls, before + 2, "exactly the bound");

  const row = await ledger(user, operationId);
  assertEquals(row?.status, "released");
  assertEquals(row?.source_mode, null);
  assertEquals(row?.sanitized_failure_code, "retryable_palette_mismatch");

  const { data: previews } = await user.client
    .from("custom_palette_generated_images").select("id");
  assertEquals(previews, []);
  const folder = await admin.storage.from("face-images").list(
    `${user.userId}/analyses`,
  );
  assertEquals((folder.data ?? []).length, 1);
});

Deno.test("accepted on retry: one charge, one file, correction applied", async () => {
  const user = await signUp();
  const recommendationId = await recommend(user);
  const operationId = crypto.randomUUID();
  gemini.validations = [WRONG, observed()];
  gemini.prompts = [];

  const result = await preview(user, recommendationId, operationId);
  assertEquals(result.status, 200);
  const body = (result.body as {
    preview: {
      id: string;
      generatedImagePath: string;
      generationNumber: number;
      mode: string;
    };
  }).preview;
  assertEquals(body.mode, "custom_color_palette");
  assertEquals(body.generationNumber, 2);

  assert(!gemini.prompts[0].includes("CORRECTION"));
  assert(gemini.prompts[1].includes("CORRECTION"));
  const palette = (prompt: string) =>
    prompt.slice(prompt.indexOf("Fixed palette: "));
  assertEquals(palette(gemini.prompts[0]), palette(gemini.prompts[1]));

  const row = await ledger(user, operationId);
  assertEquals(row?.status, "committed");
  assertEquals(row?.source_mode, "custom_color_palette");
  assertEquals(row?.canonical_custom_palette_preview_id, body.id);

  const download = await user.client.storage.from("face-images")
    .download(body.generatedImagePath);
  assert(!download.error, "the accepted image is stored");

  // A failed candidate was never uploaded: only the accepted file exists.
  const folder = body.generatedImagePath.slice(
    0,
    body.generatedImagePath.lastIndexOf("/"),
  );
  const files = await admin.storage.from("face-images").list(folder);
  assertEquals((files.data ?? []).map((file) => file.name), [
    "preview_0002.png",
  ]);

  // App retry after a lost response: same preview, nothing more spent.
  const imagesBefore = gemini.imageCalls;
  const replay = await preview(user, recommendationId, operationId);
  assertEquals(replay.body, result.body);
  assertEquals(gemini.imageCalls, imagesBefore);

  // The Free plan's single AI Look is now used, so the charge was real.
  const refused = await assertRejects(() =>
    preview(user, recommendationId, crypto.randomUUID())
  ) as unknown as { code: string };
  assertEquals(refused.code, "AI_LOOK_LIMIT_REACHED");

  // A client still cannot read attempts, or accept its own preview.
  const attempts = await user.client
    .from("custom_palette_preview_attempts").select("id");
  assertEquals(attempts.error?.code, "42501");
  const forged = await user.client.rpc(
    "finalize_custom_palette_preview" as never,
    {
      p_user_id: user.userId,
      p_operation_id: crypto.randomUUID(),
      p_attempt_number: 1,
      p_storage_path: "x",
      p_model_name: "m",
      p_prompt_version: "p",
      p_validator_version: "v",
    } as never,
  );
  assert(forged.error, "a client cannot call finalize");
});

Deno.test("duplicate invocation at the same moment: one generation, one charge", async () => {
  const user = await signUp();
  const recommendationId = await recommend(user);
  const operationId = crypto.randomUUID();
  gemini.validations = [observed()];
  gemini.imageDelayMs = 400;
  const before = gemini.imageCalls;

  const settled = await Promise.allSettled([
    preview(user, recommendationId, operationId),
    preview(user, recommendationId, operationId),
    preview(user, recommendationId, operationId),
  ]);
  gemini.imageDelayMs = 0;

  const fulfilled = settled.filter((s) => s.status === "fulfilled");
  const rejected = settled.filter((s) =>
    s.status === "rejected"
  ) as PromiseRejectedResult[];
  assertEquals(gemini.imageCalls, before + 1, "one provider call");
  assertEquals(fulfilled.length, 1);
  assertEquals(rejected.length, 2);
  for (const failure of rejected) {
    assertEquals(failure.reason.code, "preview_in_progress");
    assertEquals(failure.reason.retryable, true);
  }

  const row = await ledger(user, operationId);
  assertEquals(row?.status, "committed");
  const { data: previews } = await user.client
    .from("custom_palette_generated_images").select("id");
  assertEquals((previews as unknown[]).length, 1);

  // Whoever was told to wait collects the same result.
  const replay = await preview(user, recommendationId, operationId);
  assertEquals(replay.status, 200);
  assertEquals(gemini.imageCalls, before + 1);
});

Deno.test("an unreachable validator can never accept", async () => {
  const user = await signUp();
  const recommendationId = await recommend(user);
  const operationId = crypto.randomUUID();
  gemini.validations = ["not json", "not json"];
  const error = await assertRejects(() =>
    preview(user, recommendationId, operationId)
  ) as unknown as { code: string };
  assertEquals(error.code, "palette_preview_failed");
  assertEquals((await ledger(user, operationId))?.status, "released");
});
