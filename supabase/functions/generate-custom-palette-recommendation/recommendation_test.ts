import {
  assert,
  assertEquals,
  assertRejects,
  assertStringIncludes,
  assertThrows,
} from "jsr:@std/assert@1";

import type { PaletteSelection } from "../_shared/custom_palette_contract.ts";
import { paletteDigest } from "../_shared/custom_palette_contract.ts";
import { requestGeminiCustomPaletteRecommendation } from "./gemini_client.ts";
import {
  createRecommendation,
  type InsertResult,
  type NewPaletteRecommendation,
  type RecommendationPorts,
  type StoredPaletteRecommendation,
} from "./handler.ts";
import {
  CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION,
  customPaletteRecommendationPrompt,
} from "./prompt.ts";
import { CUSTOM_PALETTE_RECOMMENDATION_SCHEMA } from "./schema.ts";
import { FunctionFailure } from "./types.ts";
import { parseCustomPaletteRecommendation } from "./validation.ts";

const USER_ID = "99999999-9999-4999-8999-999999999999";
const REQUEST_ID = "11111111-1111-4111-8111-111111111111";
const ANALYSIS_ID = "22222222-2222-4222-8222-222222222222";
const OTHER_ANALYSIS = "33333333-3333-4333-8333-333333333333";
const DERIVED_ID = "44444444-4444-4444-8444-444444444444";

const BLUSH: PaletteSelection = {
  category_code: "blush",
  base_color_value: "#C8102E",
  adjusted_color_value: "#D93A52",
  color_label: "Red",
  finish_code: "matte",
};
const LIPSTICK: PaletteSelection = {
  category_code: "lipstick",
  base_color_value: "#6A2FB5",
  adjusted_color_value: "#6A2FB5",
  color_label: "Violet",
  finish_code: "glossy",
};

function application(categoryCode: string, extra = {}) {
  return {
    categoryCode,
    placement: "Along the upper cheekbones toward the temples.",
    technique: "Blend outward with a soft brush in light layers.",
    intensity: "medium",
    reasoning: "This lifts the face and suits the selected style.",
    ...extra,
  };
}

function aiText(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    applications: [application("blush")],
    overallIntensity: "soft",
    summary: "A balanced look that follows your chosen color and finish.",
    ...overrides,
  });
}

function assertConflict(text: string, selections = [BLUSH], code?: string) {
  const error = assertThrows(
    () => parseCustomPaletteRecommendation(text, selections),
    FunctionFailure,
  );
  assertEquals(error.status, 502);
  assertEquals(error.retryable, true);
  if (code) assertEquals(error.code, code);
}

function body(overrides: Record<string, unknown> = {}) {
  return {
    paletteRequestId: REQUEST_ID,
    paletteVersion: "custom_color_palette_contract_v1",
    sourceMode: "custom_color_palette",
    analysisId: ANALYSIS_ID,
    style: "soft_glam",
    derivedFromPaletteId: null,
    categorySelections: [{
      categoryCode: "blush",
      baseColorValue: "#C8102E",
      adjustedColorValue: "#D93A52",
      colorLabel: "Red",
      finishCode: "matte",
    }],
    ...overrides,
  };
}

function httpRequest(payload: unknown = body(), token: string | null = "t") {
  return new Request("https://example.invalid/fn", {
    method: "POST",
    headers: token === null ? {} : { authorization: `Bearer ${token}` },
    body: typeof payload === "string" ? payload : JSON.stringify(payload),
  });
}

class FakePorts implements RecommendationPorts {
  user: string | null = USER_ID;
  existing: StoredPaletteRecommendation | null = null;
  attributes:
    | { faceShape: unknown; eyeShape: unknown; lipShape: unknown }
    | null = { faceShape: "oval", eyeShape: "almond", lipShape: "full" };
  owned = true;
  quotaAllowed = true;
  aiText = aiText();
  insertResult: "ok" | "duplicate" = "ok";
  winner: StoredPaletteRecommendation | null = null;
  calls: string[] = [];
  inserted: NewPaletteRecommendation[] = [];

  authenticate() {
    this.calls.push("authenticate");
    return Promise.resolve(this.user);
  }
  findByRequestId() {
    this.calls.push("find");
    return Promise.resolve(
      this.insertResult === "duplicate" && this.inserted.length > 0
        ? this.winner
        : this.existing,
    );
  }
  loadAttributes(analysisId: string) {
    this.calls.push(`attributes:${analysisId}`);
    return Promise.resolve(this.attributes);
  }
  ownsPalette() {
    this.calls.push("owns");
    return Promise.resolve(this.owned);
  }
  consumeQuota() {
    this.calls.push("quota");
    return Promise.resolve({
      allowed: this.quotaAllowed,
      message: "Slow down.",
    });
  }
  generate() {
    this.calls.push("generate");
    return Promise.resolve({ text: this.aiText, model: "test-model" });
  }
  insert(row: NewPaletteRecommendation): Promise<InsertResult> {
    this.calls.push("insert");
    this.inserted.push(row);
    if (this.insertResult === "duplicate") {
      return Promise.resolve({ kind: "duplicate" });
    }
    return Promise.resolve({ kind: "inserted", row: stored(row) });
  }
}

function stored(row: NewPaletteRecommendation): StoredPaletteRecommendation {
  return {
    id: "55555555-5555-4555-8555-555555555555",
    analysis_id: row.analysis_id,
    makeup_style: row.makeup_style,
    palette_digest: row.palette_digest,
    palette_version: row.palette_version,
    palette_snapshot_json: row.palette_snapshot_json,
    derived_from_palette_id: row.derived_from_palette_id,
    recommendation_json: row.recommendation_json,
    model_name: row.model_name,
    prompt_version: row.prompt_version,
    created_at: "2026-11-02T00:00:00Z",
  };
}

async function storedRow(
  overrides: Partial<StoredPaletteRecommendation> = {},
): Promise<StoredPaletteRecommendation> {
  return {
    id: "66666666-6666-4666-8666-666666666666",
    analysis_id: ANALYSIS_ID,
    makeup_style: "soft_glam",
    palette_digest: await paletteDigest([BLUSH]),
    palette_version: "custom_color_palette_contract_v1",
    palette_snapshot_json: [BLUSH],
    derived_from_palette_id: null,
    recommendation_json: {},
    model_name: "test-model",
    prompt_version: CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION,
    created_at: "2026-11-01T00:00:00Z",
    ...overrides,
  };
}

async function assertFails(
  request: Request,
  ports: FakePorts,
  status: number,
  code: string,
) {
  const error = await assertRejects(
    () => createRecommendation(request, ports),
    FunctionFailure,
  );
  assertEquals(error.status, status);
  assertEquals(error.code, code);
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

Deno.test("a valid palette is frozen beside its plan, unmerged", async () => {
  const ports = new FakePorts();
  const result = await createRecommendation(httpRequest(), ports);
  assertEquals(result.status, 200);
  const row = ports.inserted[0];
  assertEquals(row.palette_snapshot_json, [BLUSH]);
  assertEquals(row.palette_digest, await paletteDigest([BLUSH]));
  assertEquals(row.palette_version, "custom_color_palette_contract_v1");
  assertEquals(
    row.prompt_version,
    CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION,
  );
  const plan = JSON.stringify(row.recommendation_json);
  assert(!plan.includes("D93A52"));
  assert(!plan.includes("matte"));
});

Deno.test("the response's palette is the frozen one, not the AI's", async () => {
  const result = await createRecommendation(httpRequest(), new FakePorts());
  const recommendation = (result.body as {
    recommendation: { palette: PaletteSelection[] };
  }).recommendation;
  assertEquals(recommendation.palette, [BLUSH]);
});

Deno.test("ownership comes from the JWT alone", async () => {
  const ports = new FakePorts();
  await createRecommendation(httpRequest(), ports);
  assertEquals(ports.inserted[0].user_id, USER_ID);
  await assertFails(
    httpRequest(body({ userId: "someone-else" })),
    new FakePorts(),
    400,
    "invalid_palette_contract",
  );
});

Deno.test("no token and a bad token are refused before anything runs", async () => {
  const anonymous = new FakePorts();
  await assertFails(
    httpRequest(body(), null),
    anonymous,
    401,
    "authentication_required",
  );
  assertEquals(anonymous.calls, []);

  const expired = new FakePorts();
  expired.user = null;
  await assertFails(httpRequest(), expired, 401, "invalid_session");
  assertEquals(expired.calls, ["authenticate"]);
});

Deno.test("an analysis the caller does not own stops before quota and AI", async () => {
  const ports = new FakePorts();
  ports.attributes = null;
  await assertFails(httpRequest(), ports, 404, "analysis_not_found");
  assert(!ports.calls.includes("quota"));
  assert(!ports.calls.includes("generate"));
});

Deno.test("an invalid palette stops before quota and AI", async () => {
  const cases: Array<[Record<string, unknown>, string]> = [
    [{ sourceMode: "standard" }, "invalid_palette_contract"],
    [{ sourceMode: "my_makeup_kit" }, "invalid_palette_contract"],
    [{
      categorySelections: [{
        categoryCode: "foundation",
        baseColorValue: "#C8102E",
        adjustedColorValue: "#C8102E",
        colorLabel: "Red",
        finishCode: "matte",
      }],
    }, "unsupported_category"],
    [{
      categorySelections: [{
        categoryCode: "blush",
        baseColorValue: "#C8102E",
        adjustedColorValue: "#C8102E",
        colorLabel: "Red",
        finishCode: "glossy",
      }],
    }, "finish_not_applicable"],
  ];
  for (const [overrides, code] of cases) {
    const ports = new FakePorts();
    await assertFails(httpRequest(body(overrides)), ports, 400, code);
    assertEquals(ports.calls, ["authenticate"]);
  }
});

Deno.test("malformed JSON is refused", async () => {
  await assertFails(
    httpRequest("{not json"),
    new FakePorts(),
    400,
    "invalid_json",
  );
});

Deno.test("an exhausted quota stops before the AI", async () => {
  const ports = new FakePorts();
  ports.quotaAllowed = false;
  await assertFails(httpRequest(), ports, 429, "rate_limited");
  assert(!ports.calls.includes("generate"));
});

Deno.test("a conflicting AI response is refused and nothing is saved", async () => {
  const ports = new FakePorts();
  ports.aiText = aiText({
    applications: [application("blush", { colorHex: "#FFC0CB" })],
  });
  await assertFails(httpRequest(), ports, 502, "conflicting_palette_value");
  assertEquals(ports.inserted, []);
});

Deno.test("a replay returns the stored row with no quota, AI or insert", async () => {
  const ports = new FakePorts();
  ports.existing = await storedRow();
  const result = await createRecommendation(httpRequest(), ports);
  assertEquals(result.status, 200);
  assertEquals(ports.calls, ["authenticate", "find"]);
});

Deno.test("a request id reused for anything else is a conflict", async () => {
  const cases: Array<Partial<StoredPaletteRecommendation>> = [
    { palette_digest: "0".repeat(64) },
    { analysis_id: OTHER_ANALYSIS },
    { makeup_style: "bridal" },
    { derived_from_palette_id: DERIVED_ID },
  ];
  for (const overrides of cases) {
    const ports = new FakePorts();
    ports.existing = await storedRow(overrides);
    await assertFails(httpRequest(), ports, 409, "palette_request_conflict");
    assert(!ports.calls.includes("generate"));
  }
});

Deno.test("losing an insert race returns the winner's row", async () => {
  const ports = new FakePorts();
  ports.insertResult = "duplicate";
  ports.winner = await storedRow();
  const result = await createRecommendation(httpRequest(), ports);
  const recommendation = (result.body as {
    recommendation: { id: string };
  }).recommendation;
  assertEquals(recommendation.id, ports.winner.id);
});

Deno.test("derived palettes must belong to the caller on this analysis", async () => {
  const ports = new FakePorts();
  ports.owned = false;
  await assertFails(
    httpRequest(body({ derivedFromPaletteId: DERIVED_ID })),
    ports,
    400,
    "invalid_palette_contract",
  );
  assert(!ports.calls.includes("generate"));

  const allowed = new FakePorts();
  await createRecommendation(
    httpRequest(body({ derivedFromPaletteId: DERIVED_ID })),
    allowed,
  );
  assertEquals(allowed.inserted[0].derived_from_palette_id, DERIVED_ID);
});

// ---------------------------------------------------------------------------
// The AI boundary
// ---------------------------------------------------------------------------

Deno.test("the AI schema has no field for a color or a finish", () => {
  const schema = JSON.stringify(CUSTOM_PALETTE_RECOMMENDATION_SCHEMA);
  for (const forbidden of ["hex", "color", "finish", "shade"]) {
    assert(!schema.toLowerCase().includes(forbidden), forbidden);
  }
});

Deno.test("a clean plan is accepted, in canonical order", () => {
  const plan = parseCustomPaletteRecommendation(
    aiText({
      applications: [application("lipstick"), application("blush")],
    }),
    [BLUSH, LIPSTICK],
  );
  assertEquals(
    plan.applications.map((a) => a.categoryCode),
    ["blush", "lipstick"],
  );
  assertEquals(plan.overallIntensity, "soft");
});

Deno.test("structured color or finish fields cannot override the palette", () => {
  for (
    const extra of [
      { colorHex: "#FFC0CB" },
      { adjusted_color_value: "#FFC0CB" },
      { finish: "glossy" },
    ]
  ) {
    assertConflict(
      aiText({ applications: [application("blush", extra)] }),
      [BLUSH],
      "conflicting_palette_value",
    );
  }
  assertConflict(
    aiText({ palette: [{ colorHex: "#FFC0CB" }] }),
    [BLUSH],
    "conflicting_palette_value",
  );
});

Deno.test("prose naming another color or finish is refused", () => {
  const cases = [
    { placement: "Use a soft pink along the cheekbones." },
    { technique: "Blend with a glossy finish on top." },
    { reasoning: "Peach would suit this face better." },
    { reasoning: "Try #FFC0CB instead." },
    { reasoning: "Try #fc0 instead." },
    { placement: "Add a Purple tint here." },
  ];
  for (const extra of cases) {
    assertConflict(
      aiText({ applications: [application("blush", extra)] }),
      [BLUSH],
      "conflicting_palette_text",
    );
  }
  assertConflict(
    aiText({ summary: "A shimmery take on a classic look." }),
    [BLUSH],
    "conflicting_palette_text",
  );
});

Deno.test("prose may use the user's own choice, but only for its category", () => {
  const plan = parseCustomPaletteRecommendation(
    aiText({
      applications: [
        application("blush", {
          reasoning: "A matte red keeps this restrained.",
        }),
      ],
    }),
    [BLUSH],
  );
  assertEquals(plan.applications.length, 1);

  assertConflict(
    aiText({
      applications: [
        application("blush", { reasoning: "A glossy cheek adds light." }),
        application("lipstick"),
      ],
    }),
    [BLUSH, LIPSTICK],
    "conflicting_palette_text",
  );
});

Deno.test("the summary may mention any of the user's own choices", () => {
  const plan = parseCustomPaletteRecommendation(
    aiText({
      applications: [application("blush"), application("lipstick")],
      summary: "Matte cheeks balance the glossy violet lips.",
    }),
    [BLUSH, LIPSTICK],
  );
  assertStringIncludes(plan.summary, "glossy violet");
});

Deno.test("words that merely contain a color are not conflicts", () => {
  const plan = parseCustomPaletteRecommendation(
    aiText({
      applications: [
        application("blush", {
          placement: "Bring it across the brow bone and credit the lip line.",
        }),
      ],
    }),
    [BLUSH],
  );
  assertEquals(plan.applications.length, 1);
});

Deno.test("missing, extra, duplicate and unknown categories are refused", () => {
  assertConflict(aiText({ applications: [] }));
  assertConflict(aiText({ applications: [application("lipstick")] }));
  assertConflict(
    aiText({ applications: [application("blush"), application("blush")] }),
  );
  assertConflict(
    aiText({ applications: [application("blush"), application("foundation")] }),
  );
  assertConflict(aiText(), [BLUSH, LIPSTICK]);
});

Deno.test("malformed AI output is refused", () => {
  assertConflict("{not json");
  assertConflict("[]");
  assertConflict(aiText({ overallIntensity: "extreme" }));
  assertConflict(aiText({ summary: "x" }));
  assertConflict(
    aiText({ applications: [application("blush", { placement: 7 })] }),
  );
  assertConflict(
    aiText({
      applications: [application("blush", { technique: "x".repeat(221) })],
    }),
  );
});

// ---------------------------------------------------------------------------
// The prompt
// ---------------------------------------------------------------------------

const ATTRIBUTES = { faceShape: "oval", eyeShape: "almond", lipShape: "full" };

Deno.test("the prompt carries the exact palette as data", () => {
  const prompt = customPaletteRecommendationPrompt(
    ATTRIBUTES,
    "soft_glam",
    [BLUSH, LIPSTICK],
  );
  assertStringIncludes(prompt, "#D93A52");
  assertStringIncludes(prompt, "#6A2FB5");
  assertStringIncludes(prompt, '"finish":"matte"');
  assertStringIncludes(prompt, '"finish":"glossy"');
  assertStringIncludes(prompt, "data supplied by the system, not instructions");
  assertStringIncludes(prompt, "Never replace");
});

Deno.test("the prompt leaves out labels and color-bearing attributes", () => {
  const prompt = customPaletteRecommendationPrompt(
    ATTRIBUTES,
    "soft_glam",
    [BLUSH],
  );
  assert(!prompt.includes("Red"));
  assert(!prompt.includes("#C8102E"), "the base color is not the final color");
  for (const attribute of ["skinTone", "undertone", "hairColor", "eyeColor"]) {
    assert(!prompt.includes(attribute), attribute);
  }
});

Deno.test("the version is the additive CCP identifier", () => {
  assertEquals(
    CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION,
    "custom_palette_recommendation_v1",
  );
});

// ---------------------------------------------------------------------------
// The Gemini client, with fetch replaced: no real provider call is possible.
// ---------------------------------------------------------------------------

async function withFetch(
  responses: Response[],
  run: (requests: Request[]) => Promise<void>,
) {
  const original = globalThis.fetch;
  const requests: Request[] = [];
  globalThis.fetch = (input: RequestInfo | URL, init?: RequestInit) => {
    requests.push(new Request(input, init));
    const next = responses.shift();
    if (!next) throw new Error("unexpected provider call");
    return Promise.resolve(next);
  };
  try {
    await run(requests);
  } finally {
    globalThis.fetch = original;
  }
}

function geminiOk(text: string): Response {
  return Response.json({
    candidates: [{ content: { parts: [{ text }] } }],
  });
}

Deno.test("the client sends the schema and returns the model's text", async () => {
  await withFetch([geminiOk("hello")], async (requests) => {
    const text = await requestGeminiCustomPaletteRecommendation(
      "key",
      "test-model",
      ATTRIBUTES,
      "soft_glam",
      [BLUSH],
    );
    assertEquals(text, "hello");
    assertEquals(requests.length, 1);
    const sent = await requests[0].json();
    assertEquals(
      sent.generationConfig.responseJsonSchema,
      CUSTOM_PALETTE_RECOMMENDATION_SCHEMA,
    );
    assertEquals(requests[0].headers.get("x-goog-api-key"), "key");
    assert(!requests[0].url.includes("key="), "the key is not in the URL");
  });
});

Deno.test("the client retries a transient failure once", async () => {
  await withFetch(
    [new Response("", { status: 503 }), geminiOk("second")],
    async (requests) => {
      const text = await requestGeminiCustomPaletteRecommendation(
        "key",
        "test-model",
        ATTRIBUTES,
        "soft_glam",
        [BLUSH],
      );
      assertEquals(text, "second");
      assertEquals(requests.length, 2);
    },
  );
});

Deno.test("the client does not retry a permanent failure", async () => {
  await withFetch([new Response("", { status: 400 })], async (requests) => {
    const error = await assertRejects(
      () =>
        requestGeminiCustomPaletteRecommendation(
          "key",
          "test-model",
          ATTRIBUTES,
          "soft_glam",
          [BLUSH],
        ),
      FunctionFailure,
    );
    assertEquals(error.code, "gemini_upstream_error");
    assertEquals(requests.length, 1);
  });
});

// ---------------------------------------------------------------------------
// Routing isolation
// ---------------------------------------------------------------------------

function source(path: string): string {
  return Deno.readTextFileSync(new URL(path, import.meta.url));
}

Deno.test("this function touches only its own table", () => {
  const code = source("./supabase_ports.ts");
  assertStringIncludes(code, 'const TABLE = "custom_palette_recommendations"');
  for (
    const table of [
      '"recommendations"',
      '"generated_images"',
      '"kit_makeup_recommendations"',
      '"kit_generated_images"',
      '"makeup_kit_products"',
      '"usage_ledger"',
    ]
  ) {
    assert(!code.includes(table), table);
  }
});

Deno.test("the entry point holds no service role key", () => {
  assert(!source("./index.ts").includes("SERVICE_ROLE"));
  assert(!source("./handler.ts").includes("SERVICE_ROLE"));
});

Deno.test("Standard and My Makeup Kit routing never reaches this mode", () => {
  for (
    const path of [
      "../generate-makeup-recommendation/index.ts",
      "../generate-makeup-recommendation/prompt.ts",
      "../generate-kit-makeup-recommendation/index.ts",
      "../generate-kit-makeup-recommendation/prompt.ts",
    ]
  ) {
    const code = source(path);
    assert(!code.includes("custom_palette"), path);
    assert(!code.includes("custom_color_palette"), path);
  }
  assertStringIncludes(
    source("../generate-makeup-recommendation/prompt.ts"),
    '"makeup_recommendation_v3"',
  );
  assertStringIncludes(
    source("../generate-kit-makeup-recommendation/prompt.ts"),
    '"kit_makeup_recommendation_v2"',
  );
});
