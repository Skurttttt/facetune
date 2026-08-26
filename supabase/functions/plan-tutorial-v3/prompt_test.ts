import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  TUTORIAL_V3_PLANNER_PROMPT_VERSION,
  type PlannerInput,
  tutorialV3PlannerPrompt,
} from "./prompt.ts";
import { type OwnedProduct } from "./types.ts";

const ownedBlush: OwnedProduct = {
  productId: "product-blush",
  category: "blush",
  colorHex: "#B86F72",
  finish: "satin",
  productName: "My blush",
  colorLabel: "Soft Rose",
  foundationDepth: null,
  foundationUndertone: null,
};

function input(overrides: Partial<PlannerInput> = {}): PlannerInput {
  return {
    style: "soft_glam",
    sourceMode: "standard",
    attributes: { face_shape: "round", skin_tone: "medium" },
    recommendation: { blush: { name: "Soft rose" } },
    ownedProducts: [],
    ...overrides,
  };
}

Deno.test("the prompt version is stable", () => {
  assertEquals(TUTORIAL_V3_PLANNER_PROMPT_VERSION, "v3-planner-1");
});

Deno.test("the selected look is mandatory and fixed", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "SELECTED LOOK (mandatory, already chosen): soft_glam");
  assertStringIncludes(prompt, "Do not propose, substitute or drift");
});

Deno.test("the attached image is framed as the destination, not inspiration", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "FINAL LOOK this user has already selected");
  assertStringIncludes(prompt, "exact destination of this tutorial");
  assertStringIncludes(prompt, "Decompose it into");
});

Deno.test("the face attributes are included verbatim", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, '"face_shape": "round"');
  assertStringIncludes(prompt, '"skin_tone": "medium"');
});

Deno.test("the persisted recommendation is included", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "PERSISTED MAKEUP PLAN");
  assertStringIncludes(prompt, "Soft rose");
});

Deno.test("dynamic length is required and filler forbidden", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "no fixed number of steps");
  assertStringIncludes(prompt, "Never pad the plan with filler steps");
});

Deno.test("canonical ordering and the terminal step are stated", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(
    prompt,
    "foundation -> concealer -> contour_bronzer -> blush -> highlighter -> " +
      "eyebrow -> eyeshadow -> eyeliner -> lipstick -> lip_gloss -> final_look",
  );
  assertStringIncludes(prompt, 'The last step must always be "final_look"');
  assertStringIncludes(prompt, "teaches no application of its own");
});

Deno.test("the attribute scope table is spelled out per category", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "- blush: face_shape");
  assertStringIncludes(prompt, "- foundation: skin_tone, undertone");
  assertStringIncludes(prompt, "- eyeshadow: eye_shape");
  assertStringIncludes(prompt, "- lipstick: lip_shape");
  assertStringIncludes(prompt, "Leave every other attribute out");
});

Deno.test("the guideline is constrained to instructional marks only", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "UNTOUCHED original selfie");
  assertStringIncludes(prompt, "teaches placement only");
  assertStringIncludes(
    prompt,
    "Never describe applied makeup, a finished result",
  );
  assertStringIncludes(
    prompt,
    "translucent_zone, arrow, path, soft_band, marker",
  );
  assertStringIncludes(prompt, "Do not rely on any text, label or number");
});

Deno.test("cumulative generation and result images are forbidden", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(
    prompt,
    "Do not describe generating, rendering or previewing a makeup result",
  );
  assertStringIncludes(
    prompt,
    "Do not make any step depend on a previous step's image",
  );
  assertStringIncludes(prompt, "Do not produce a new final look");
  assertStringIncludes(prompt, "Do not give generic universal placement");
});

Deno.test("standard mode forbids product selection", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertStringIncludes(prompt, "PRODUCTS — STANDARD MODE");
  assertStringIncludes(prompt, "Set product_id to null on every step");
  assertStringIncludes(
    prompt,
    "Do not select products independently of that plan",
  );
  assertEquals(prompt.includes("MY MAKEUP KIT MODE"), false);
});

Deno.test("kit mode lists only the owned products", () => {
  const prompt = tutorialV3PlannerPrompt(
    input({ sourceMode: "makeup_kit", ownedProducts: [ownedBlush] }),
  );

  assertStringIncludes(prompt, "PRODUCTS — MY MAKEUP KIT MODE");
  assertStringIncludes(prompt, "product_id=product-blush");
  assertStringIncludes(prompt, "category=blush");
  assertStringIncludes(prompt, "color_hex=#B86F72");
  assertStringIncludes(prompt, "You may teach only these");
  assertStringIncludes(prompt, "Never invent a product");
  assertStringIncludes(prompt, "omit that category entirely");
  assertEquals(prompt.includes("STANDARD MODE"), false);
});

Deno.test("kit mode does not leak products the user does not own", () => {
  const prompt = tutorialV3PlannerPrompt(
    input({ sourceMode: "makeup_kit", ownedProducts: [ownedBlush] }),
  );
  assertEquals(prompt.includes("product-lipstick"), false);
});

Deno.test("repair notes are appended verbatim for the retry", () => {
  const prompt = tutorialV3PlannerPrompt(
    input({ repairNotes: ['Category "blush" appears more than once.'] }),
  );

  assertStringIncludes(prompt, "YOUR PREVIOUS RESPONSE WAS REJECTED");
  assertStringIncludes(prompt, '- Category "blush" appears more than once.');
});

Deno.test("a first attempt carries no repair section", () => {
  const prompt = tutorialV3PlannerPrompt(input());
  assertEquals(prompt.includes("PREVIOUS RESPONSE WAS REJECTED"), false);
});
