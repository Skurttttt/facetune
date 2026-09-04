import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { parseAndValidateRecommendation } from "./validation.ts";

const categories = [
  "foundation",
  "concealer",
  "contour",
  "highlight",
  "blush",
  "eyeshadow",
  "eyebrow",
  "eyeliner",
  "lipstick",
  "lipGloss",
];

function validEducation() {
  return {
    features: "Your warm undertone and medium depth guided this peach choice.",
    effect: "A soft satin peach adds warmth without flattening the cheek.",
    style: "It keeps the soft glam register bright rather than heavy.",
  };
}

function validItem() {
  return {
    name: "Warm peach",
    hex: "#E69A7A",
    placement: "Upper cheekbones",
    technique: "Blend upward with a soft brush",
    finish: "satin",
    intensity: "soft",
    reasoning: "Adds balanced warmth to the complexion.",
    education: validEducation(),
  };
}

function plan(overrides: Record<string, unknown> = {}) {
  const payload = Object.fromEntries(
    categories.map((key) => [key, validItem()]),
  );
  return JSON.stringify({
    ...payload,
    overallIntensity: "soft",
    ...overrides,
  });
}

Deno.test("accepts a complete structured plan", () => {
  const result = parseAndValidateRecommendation(plan());
  assertEquals(result.blush.hex, "#E69A7A");
});

Deno.test("rejects malformed HEX colors", () => {
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({ blush: { ...validItem(), hex: "peach" } }),
    )
  );
});

Deno.test("preserves placement and technique alongside education", () => {
  const result = parseAndValidateRecommendation(plan());
  assertEquals(result.blush.placement, "Upper cheekbones");
  assertEquals(result.blush.technique, "Blend upward with a soft brush");
  assertEquals(result.foundation.finish, "satin");
  assertEquals(result.foundation.intensity, "soft");
  assertEquals(result.foundation.name, "Warm peach");
});

Deno.test("parses the three education sections", () => {
  const result = parseAndValidateRecommendation(plan());
  assertEquals(result.blush.education.features, validEducation().features);
  assertEquals(result.blush.education.effect, validEducation().effect);
  assertEquals(result.blush.education.style, validEducation().style);
});

Deno.test("rejects a fresh response with no education object", () => {
  const withoutEducation = validItem() as Record<string, unknown>;
  delete withoutEducation.education;
  assertThrows(() =>
    parseAndValidateRecommendation(plan({ blush: withoutEducation }))
  );
});

Deno.test("rejects a partial education object", () => {
  const partial = validEducation() as Record<string, unknown>;
  delete partial.style;
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({ blush: { ...validItem(), education: partial } }),
    )
  );
});

Deno.test("rejects an education section that is not a string", () => {
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({
        blush: {
          ...validItem(),
          education: { ...validEducation(), effect: 42 },
        },
      }),
    )
  );
});

Deno.test("rejects an unknown education key", () => {
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({
        blush: {
          ...validItem(),
          education: { ...validEducation(), extra: "unexpected" },
        },
      }),
    )
  );
});

Deno.test("rejects an education section past the length ceiling", () => {
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({
        blush: {
          ...validItem(),
          education: { ...validEducation(), effect: "a".repeat(241) },
        },
      }),
    )
  );
});

Deno.test("rejects an education object that is not an object", () => {
  assertThrows(() =>
    parseAndValidateRecommendation(
      plan({ blush: { ...validItem(), education: "warm peach suits you" } }),
    )
  );
});
