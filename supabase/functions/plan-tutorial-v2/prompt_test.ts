import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { TUTORIAL_V2_PLANNER_PROMPT_VERSION, tutorialV2PlannerPrompt } from "./prompt.ts";
import { TUTORIAL_V2_PLAN_SCHEMA } from "./schema.ts";
import { CATEGORY_RANKS, type OwnedProduct } from "./types.ts";

const attributes = {
  faceShape: "heart",
  skinTone: "medium",
  undertone: "warm",
  eyeShape: "almond",
  lipShape: "full",
  hairColor: "dark_brown",
  eyeColor: "brown",
};

const recommendation = { overallIntensity: "medium" };

function product(overrides: Partial<OwnedProduct> = {}): OwnedProduct {
  return {
    productId: "product-1",
    category: "blush",
    colorHex: "#B86F72",
    finish: "matte",
    productName: null,
    colorLabel: "Rosewood",
    foundationDepth: null,
    foundationUndertone: null,
    ...overrides,
  };
}

/// Line wrapping in the prompt is cosmetic. Assert on the collapsed text so a
/// reflow does not fail a test about content.
function assertSays(prompt: string, phrase: string) {
  const collapse = (value: string) => value.replace(/\s+/g, " ").trim();
  assertStringIncludes(collapse(prompt), collapse(phrase));
}

function standardPrompt(): string {
  return tutorialV2PlannerPrompt({
    style: "soft_glam",
    attributes,
    recommendation,
    sourceMode: "standard_recommendation",
    ownedProducts: [],
  });
}

function kitPrompt(products: OwnedProduct[] = [product()]): string {
  return tutorialV2PlannerPrompt({
    style: "soft_glam",
    attributes,
    recommendation,
    sourceMode: "makeup_kit",
    ownedProducts: products,
  });
}

Deno.test("the prompt version is pinned", () => {
  assertEquals(TUTORIAL_V2_PLANNER_PROMPT_VERSION, "tutorial_v2_planner_v1");
});

Deno.test("states that the model is not creating a new look", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "YOU ARE NOT CREATING A NEW MAKEUP LOOK");
  assertSays(prompt, "Do not design an alternative look");
  assertSays(prompt, "Do not reinterpret the style");
});

Deno.test("states that the canonical target is being decomposed", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "DECOMPOSE that existing target");
  assertSays(prompt, "It is the\nexact target");
  assertSays(prompt, "not inspiration");
});

Deno.test("requires every step to reproduce the exact target", () => {
  assertSays(
    standardPrompt(),
    "reproduce that exact\nfinal image",
  );
  assertSays(
    standardPrompt(),
    "move the face away from the attached target, it is wrong",
  );
});

Deno.test("requires personalisation from face attributes", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "PERSONALISATION");
  assertSays(prompt, "follow the face shape");
  assertSays(prompt, "follow the eye shape");
  assertSays(prompt, "follows the lip shape");
  assertSays(
    prompt,
    "must not receive identical placement",
  );
  // The actual attributes have to reach the model, not just the instruction.
  assertSays(prompt, '"faceShape":"heart"');
  assertSays(prompt, '"eyeShape":"almond"');
});

Deno.test("requires the persisted recommendation to be the only source", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "Do not invent a parallel recommendation");
  assertSays(prompt, '"overallIntensity":"medium"');
});

Deno.test("standard mode forbids product references", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "Set productId to null on every");
  assert(!prompt.includes("MY MAKEUP KIT MODE"));
});

Deno.test("Kit mode lists only owned products and forbids anything else", () => {
  const prompt = kitPrompt();
  assertSays(prompt, "MY MAKEUP KIT MODE");
  assertSays(prompt, "You may use NOTHING else");
  assertSays(prompt, "productId=product-1");
  assertSays(prompt, "Never invent a product");
  assertSays(prompt, 'shade="Rosewood"');
});

Deno.test("Kit mode instructs omission rather than substitution", () => {
  const prompt = kitPrompt();
  assertSays(prompt, "OMIT that category entirely");
  assertSays(prompt, "An\nincomplete kit is valid");
  assertSays(prompt, "Do not substitute a different product");
});

Deno.test("an empty kit still renders a well-formed product section", () => {
  const prompt = kitPrompt([]);
  assertSays(prompt, "- (none)");
});

Deno.test("requires a dynamic step count with no filler", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "DYNAMIC LENGTH");
  assertSays(prompt, "Do NOT pad the plan");
  assertSays(prompt, "No filler");
  assertSays(prompt, "Omit any category the target look does not use");
});

Deno.test("states the ordering rule and the final look rule", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "foundation -> concealer -> contour_bronzer");
  assertSays(prompt, "lipstick -> lip_gloss");
  assertSays(prompt, "you may never reorder them");
  assertSays(prompt, 'LAST step must always be category "final_look"');
  assertSays(prompt, "teaches no new product");
});

Deno.test("requires structured JSON only", () => {
  const prompt = standardPrompt();
  assertSays(prompt, "Return JSON matching the supplied schema only");
  assertSays(prompt, "No prose, no markdown, no code");
});

Deno.test("carries repair notes only after a rejection", () => {
  assert(!standardPrompt().includes("YOUR PREVIOUS ATTEMPT WAS REJECTED"));

  const repaired = tutorialV2PlannerPrompt({
    style: "soft_glam",
    attributes,
    recommendation,
    sourceMode: "standard_recommendation",
    ownedProducts: [],
    repairNotes: ['The "final_look" step must be last.'],
  });
  assertSays(repaired, "YOUR PREVIOUS ATTEMPT WAS REJECTED");
  assertSays(repaired, 'The "final_look" step must be last.');
});

Deno.test("never names a brand or leaks a secret", () => {
  const prompt = kitPrompt();
  assertSays(prompt, "brand-neutral");
  assert(!prompt.includes("GEMINI_API_KEY"));
  assert(!prompt.includes("x-goog-api-key"));
});

Deno.test("the schema forbids a model-supplied step index", () => {
  const stepProperties =
    (TUTORIAL_V2_PLAN_SCHEMA.properties.steps.items as {
      properties: Record<string, unknown>;
      additionalProperties: boolean;
    });
  assert(!("step_index" in stepProperties.properties));
  assert(!("stepIndex" in stepProperties.properties));
  assertEquals(stepProperties.additionalProperties, false);
});

Deno.test("the schema allows every category and a dynamic length", () => {
  const items = TUTORIAL_V2_PLAN_SCHEMA.properties.steps;
  assertEquals(items.minItems, 2);
  assertEquals(items.maxItems, Object.keys(CATEGORY_RANKS).length);

  const categoryEnum =
    (items.items as { properties: { category: { enum: string[] } } }).properties
      .category.enum;
  assertEquals(new Set(categoryEnum), new Set(Object.keys(CATEGORY_RANKS)));
});

Deno.test("the category vocabulary matches the canonical order", () => {
  const ordered = Object.entries(CATEGORY_RANKS)
    .sort((a, b) => a[1] - b[1])
    .map(([category]) => category);

  assertEquals(ordered, [
    "foundation",
    "concealer",
    "contour_bronzer",
    "blush",
    "highlighter",
    "eyebrow",
    "eyeshadow",
    "eyeliner",
    "lipstick",
    "lip_gloss",
    "final_look",
  ]);
});
