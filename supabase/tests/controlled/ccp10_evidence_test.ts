/**
 * CCP-10 — proves the failure evidence: it names what the production guard and
 * judge refused, without ever changing what they decide. No database, no network.
 *
 * Run from `supabase/functions`:
 *   deno test --no-lock --allow-read --allow-env ../tests/controlled/ccp10_evidence_test.ts
 */
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import type { PaletteSelection } from "../../functions/_shared/custom_palette_contract.ts";
import { parseCustomPaletteRecommendation } from "../../functions/generate-custom-palette-recommendation/validation.ts";
import { ProviderCallFailed } from "../../functions/generate-custom-palette-preview/gemini_client.ts";
import { judgeValidatorResponse } from "../../functions/generate-custom-palette-preview/validator.ts";
import { IDENTITY_FEATURES } from "../../functions/generate-custom-palette-preview/validator_prompt.ts";
import {
  classifyValidatorFailure,
  diagnoseValidatorResponse,
  explainPaletteConflict,
  validatorResponseMeta,
} from "./ccp10_evidence.ts";
import { findLeak, GuardRefusal } from "./ccp10_guards.ts";

const selection = (
  category_code: string,
  color_label: string,
  finish_code: string,
  hex: string,
) =>
  ({
    category_code,
    color_label,
    finish_code,
    base_color_value: hex,
    adjusted_color_value: hex,
  }) as unknown as PaletteSelection;

// The E-no_makeup_makeup palette, exactly.
const E_PALETTE = [
  selection("lipstick", "Red", "matte", "#C8102E"),
  selection("blush", "Orange", "satin", "#E8711A"),
  selection("eyeliner", "Violet", "matte", "#6A2FB5"),
  selection("eyeshadow", "Gold", "metallic", "#C9A227"),
];

const application = (category: string, extra: Record<string, string> = {}) => ({
  categoryCode: category,
  placement: "Center of the lips and blended outward.",
  technique: "Blend softly with a brush.",
  intensity: "soft",
  reasoning: "Suits the face and the style.",
  ...extra,
});
const plan = (
  extras: Record<string, Record<string, string>> = {},
  summary = "A fresh, balanced look.",
) =>
  JSON.stringify({
    applications: E_PALETTE.map((s) =>
      application(s.category_code, extras[s.category_code])
    ),
    overallIntensity: "soft",
    summary,
  });
const parse = parseCustomPaletteRecommendation;
const codeOf = (text: string, selections = E_PALETTE) => {
  try {
    parse(text, selections);
    return "accepted";
  } catch (error) {
    return (error as { code: string }).code;
  }
};

// ---------------------------------------------------------------------------
// Finding A: recommendation refusals
// ---------------------------------------------------------------------------

Deno.test("1-3: a refusal names the matched token, its field, category and class", () => {
  const text = plan({
    blush: { technique: "Use a creamy texture for a dewy cheek." },
  });
  assertEquals(codeOf(text), "conflicting_palette_text");
  const { response_parsed, conflicts } = explainPaletteConflict(
    text,
    E_PALETTE,
    parse,
  );
  assertEquals(response_parsed, true);
  assertEquals(conflicts.length, 1);
  assertEquals(conflicts[0].token, "creamy");
  assertEquals(conflicts[0].field, "technique");
  assertEquals(conflicts[0].category, "blush");
  assertEquals(conflicts[0].token_class, "finish_word");
  assertEquals(conflicts[0].finish_code, "cream");
  assert(conflicts[0].context.includes("creamy texture"));
});

Deno.test("each token class, the summary, and another category's own words", () => {
  const text = plan(
    {
      eyeshadow: { reasoning: "A golden wash next to the violet line." },
      lipstick: { placement: "Try rgb(200, 16, 46) on the lips." },
    },
    "Fresh skin with #C9A227 lids and a touch of gloss.",
  );
  assertEquals(codeOf(text), "conflicting_palette_text");
  const found = explainPaletteConflict(text, E_PALETTE, parse).conflicts;
  const by = (token: string) => found.find((c) => c.token.startsWith(token))!;
  assertEquals(by("golden").token_class, "color_word");
  assertEquals(by("golden").belongs_to_other_category, null);
  // "gold" alone is the eyeshadow's own label; "golden" is not.
  assertEquals(by("violet").token_class, "color_word");
  assertEquals(by("violet").belongs_to_other_category, "eyeliner");
  assertEquals(by("rgb").token_class, "hex_or_rgb");
  assertEquals(by("rgb").field, "placement");
  assertEquals(by("#C9A227").token_class, "hex_or_rgb");
  assertEquals(by("#C9A227").field, "summary");
  assertEquals(by("#C9A227").category, null);
  assertEquals(by("gloss").token_class, "finish_word");
  assertEquals(by("gloss").finish_code, "glossy");
});

Deno.test("a category's own color and finish, and the summary's, are not reported", () => {
  const text = plan(
    {
      eyeshadow: { reasoning: "A metallic gold lid." },
      blush: { technique: "Satin orange on the apples." },
    },
    "Matte red lips, metallic gold lids and violet liner.",
  );
  assertEquals(codeOf(text), "accepted");
  assertEquals(explainPaletteConflict(text, E_PALETTE, parse).conflicts, []);
});

Deno.test("4 and 12: evidence is minimal, and a planted secret is caught before write", () => {
  const secret = "eyJhbGciOiJIUzI1NiJ9.planted-secret-value";
  const text = plan({ blush: { reasoning: `Peach glow ${secret}` } });
  const evidence = explainPaletteConflict(text, E_PALETTE, parse);
  // Never the whole response: only words, fields, and a short context.
  const serialized = JSON.stringify(evidence);
  assert(!serialized.includes("Center of the lips and blended outward"));
  for (const conflict of evidence.conflicts) {
    assert(conflict.context.length <= conflict.token.length + 80);
  }
  // record() runs this same scan on every row before writing it.
  assert(findLeak(serialized, [secret]) !== null);
});

Deno.test("5 and 6: explaining a refusal never changes it, and the guard still refuses", () => {
  const text = plan({
    lipstick: { reasoning: "Pink would suit this better." },
  });
  const before = codeOf(text);
  const copy = structuredClone(E_PALETTE);
  explainPaletteConflict(text, E_PALETTE, parse);
  assertEquals(codeOf(text), before);
  assertEquals(before, "conflicting_palette_text");
  assertEquals(E_PALETTE, copy);
  // Unparseable output is reported as such, and is refused as before.
  assertEquals(explainPaletteConflict("{not json", E_PALETTE, parse), {
    response_parsed: false,
    conflicts: [],
  });
  assertEquals(codeOf("{not json"), "invalid_ai_response");
});

// ---------------------------------------------------------------------------
// Finding B: validator failure classes
// ---------------------------------------------------------------------------

const EYELINER = [selection("eyeliner", "Red", "matte", "#C8102E")];
const features = Object.fromEntries(IDENTITY_FEATURES.map((f) => [f, "same"]));
const absentEyeliner = {
  categoryCode: "eyeliner",
  featureVisibleInOriginal: true,
  presence: "absent",
  color: "not_applicable",
  colorReason: "none",
  finish: "not_applicable",
  finishReason: "none",
};
const valid = {
  identityFeatures: features,
  identity: "preserved",
  categories: [absentEyeliner],
  introducedCategories: ["eyeshadow"],
};
const meta = (overrides = {}) => ({
  status: 200,
  candidate_count: 1,
  finish_reason: "STOP",
  block_reason: null,
  text_length: 10,
  ...overrides,
});

Deno.test("the clear-cut absent probe's expected answer is a mismatch, not a failure", () => {
  const verdict = judgeValidatorResponse(JSON.stringify(valid), EYELINER);
  assertEquals(verdict.outcome, "retryable_palette_mismatch");
  assertEquals(
    diagnoseValidatorResponse(JSON.stringify(valid), EYELINER).failure_class,
    null,
  );
});

Deno.test("7: an HTTP error is provider_http_error, with its status", () => {
  const result = classifyValidatorFailure(
    new ProviderCallFailed(503),
    meta({ status: 503 }),
    null,
    EYELINER,
  );
  assertEquals(result.failure_class, "provider_http_error");
  assertEquals(result.http_status, 503);
});

Deno.test("8: a timeout is provider_timeout", () => {
  const timeout = new DOMException("signal timed out", "TimeoutError");
  assertEquals(
    classifyValidatorFailure(timeout, null, null, EYELINER).failure_class,
    "provider_timeout",
  );
  assertEquals(
    classifyValidatorFailure(new TypeError("network"), null, null, EYELINER)
      .failure_class,
    "provider_network_error",
  );
});

Deno.test("9: an empty candidate and a blocked one are told apart", () => {
  const empty = new ProviderCallFailed(null);
  assertEquals(
    classifyValidatorFailure(empty, meta({ text_length: 0 }), null, EYELINER)
      .failure_class,
    "empty_candidate",
  );
  assertEquals(
    classifyValidatorFailure(
      empty,
      meta({ finish_reason: "SAFETY" }),
      null,
      EYELINER,
    ).failure_class,
    "blocked_candidate",
  );
  assertEquals(
    classifyValidatorFailure(
      empty,
      meta({ candidate_count: 0, block_reason: "OTHER" }),
      null,
      EYELINER,
    ).failure_class,
    "blocked_candidate",
  );
});

Deno.test("a harness stop and an unknown error are named, not hidden", () => {
  assertEquals(
    classifyValidatorFailure(
      new GuardRefusal("The run has stopped."),
      null,
      null,
      EYELINER,
    ).failure_class,
    "harness_refusal",
  );
  assertEquals(
    classifyValidatorFailure(new Error("odd"), null, null, EYELINER)
      .failure_class,
    "unknown_validator_failure",
  );
});

// Every broken response: the judge refuses it, and the diagnosis names why.
const mutate = (change: (v: Record<string, unknown>) => void) => {
  const copy = structuredClone(valid) as Record<string, unknown>;
  change(copy);
  return JSON.stringify(copy);
};
const observation = (change: Record<string, unknown>) =>
  mutate((v) => {
    v.categories = [{ ...absentEyeliner, ...change }];
  });
const broken: Array<[string, string, string]> = [
  ["not JSON", '{"identity": "pres', "malformed_validator_response"],
  ["an array", "[]", "malformed_validator_response"],
  [
    "an extra root key",
    mutate((v) => (v.notes = "x")),
    "schema_validation_failure",
  ],
  [
    "a missing root key",
    mutate((v) => delete v.introducedCategories),
    "schema_validation_failure",
  ],
  [
    "categories not an array",
    mutate((v) => (v.categories = {})),
    "schema_validation_failure",
  ],
  [
    "an observation key missing",
    observation({ finishReason: undefined }),
    "schema_validation_failure",
  ],
  [
    "an unknown presence",
    observation({ presence: "missing" }),
    "schema_validation_failure",
  ],
  [
    "a non-boolean visibility",
    observation({ featureVisibleInOriginal: "yes" }),
    "schema_validation_failure",
  ],
  [
    "absent with a color",
    observation({ color: "consistent" }),
    "parser_failure",
  ],
  [
    "absent with a finish",
    observation({ finish: "consistent" }),
    "parser_failure",
  ],
  [
    "different with no reason",
    observation({
      presence: "present",
      color: "different",
      colorReason: "none",
      finish: "consistent",
    }),
    "parser_failure",
  ],
  [
    "contradicted with no reason",
    observation({
      presence: "present",
      color: "consistent",
      finish: "contradicted",
      finishReason: "none",
    }),
    "parser_failure",
  ],
  [
    "the visible category instead of the selected one",
    observation({ categoryCode: "eyeshadow" }),
    "parser_failure",
  ],
  [
    "both categories",
    mutate((
      v,
    ) => (v.categories = [absentEyeliner, {
      ...absentEyeliner,
      categoryCode: "eyeshadow",
    }])),
    "parser_failure",
  ],
  [
    "the selected category as introduced",
    mutate((v) => (v.introducedCategories = ["eyeliner"])),
    "parser_failure",
  ],
  [
    "an unknown introduced category",
    mutate((v) => (v.introducedCategories = ["mascara"])),
    "schema_validation_failure",
  ],
  [
    "an unknown identity",
    mutate((v) => (v.identity = "same")),
    "schema_validation_failure",
  ],
  [
    "an identity feature missing",
    mutate((v) => delete (v.identityFeatures as Record<string, unknown>).mouth),
    "schema_validation_failure",
  ],
  [
    "an unknown feature value",
    mutate((
      v,
    ) => ((v.identityFeatures as Record<string, unknown>).eyes = "similar")),
    "schema_validation_failure",
  ],
];

for (const [name, text, expected] of broken) {
  Deno.test(`10, 11, 13: ${name} is ${expected}, and is never accepted`, () => {
    assertEquals(
      judgeValidatorResponse(text, EYELINER).outcome,
      "validator_failure",
    );
    const result = classifyValidatorFailure(null, meta(), text, EYELINER);
    assertEquals(result.failure_class, expected);
    assert(result.diagnosis?.rule, name);
  });
}

Deno.test("the diagnosis agrees with the production judge on every valid shape", () => {
  const shapes = [
    valid,
    { ...valid, introducedCategories: [] },
    { ...valid, identity: "uncertain" },
    {
      ...valid,
      categories: [{
        ...absentEyeliner,
        presence: "present",
        color: "different",
        colorReason: "hue_differs",
        finish: "consistent",
      }],
    },
  ];
  for (const shape of shapes) {
    const text = JSON.stringify(shape);
    assert(
      judgeValidatorResponse(text, EYELINER).outcome !== "validator_failure",
      text,
    );
    assertEquals(
      diagnoseValidatorResponse(text, EYELINER).failure_class,
      null,
      text,
    );
  }
});

Deno.test("validator response metadata reads status, finish and block reasons only", async () => {
  const ok = new Response(JSON.stringify({
    candidates: [{
      finishReason: "MAX_TOKENS",
      content: { parts: [{ text: '{"a"' }] },
    }],
  }));
  assertEquals(await validatorResponseMeta(ok), {
    status: 200,
    candidate_count: 1,
    finish_reason: "MAX_TOKENS",
    block_reason: null,
    text_length: 4,
  });
  const blocked = new Response(
    JSON.stringify({ promptFeedback: { blockReason: "SAFETY" } }),
  );
  assertEquals((await validatorResponseMeta(blocked)).block_reason, "SAFETY");
  assertEquals(
    (await validatorResponseMeta(new Response("", { status: 500 }))).status,
    500,
  );
  // Reading it leaves the body for the client.
  const again = new Response('{"candidates":[]}');
  await validatorResponseMeta(again);
  assertEquals(await again.text(), '{"candidates":[]}');
  assertThrows(() => JSON.parse("{"));
});
