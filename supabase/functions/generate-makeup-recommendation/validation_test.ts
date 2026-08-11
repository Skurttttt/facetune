import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { parseAndValidateRecommendation } from "./validation.ts";

function validItem() {
  return {
    name: "Warm peach",
    hex: "#E69A7A",
    placement: "Upper cheekbones",
    technique: "Blend upward with a soft brush",
    finish: "satin",
    intensity: "soft",
    reasoning: "Adds balanced warmth to the complexion.",
  };
}

Deno.test("accepts a complete structured plan", () => {
  const categories = ["foundation", "concealer", "contour", "highlight", "blush", "eyeshadow", "eyebrow", "eyeliner", "lipstick", "lipGloss"];
  const payload = Object.fromEntries(categories.map((key) => [key, validItem()]));
  const result = parseAndValidateRecommendation(JSON.stringify({ ...payload, overallIntensity: "soft" }));
  assertEquals(result.blush.hex, "#E69A7A");
});

Deno.test("rejects malformed HEX colors", () => {
  const categories = ["foundation", "concealer", "contour", "highlight", "blush", "eyeshadow", "eyebrow", "eyeliner", "lipstick", "lipGloss"];
  const payload = Object.fromEntries(categories.map((key) => [key, validItem()]));
  payload.blush = { ...validItem(), hex: "peach" };
  assertThrows(() => parseAndValidateRecommendation(JSON.stringify({ ...payload, overallIntensity: "soft" })));
});
