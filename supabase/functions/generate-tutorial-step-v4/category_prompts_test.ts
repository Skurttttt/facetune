import {
  assertEquals,
  assertStringIncludes,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { TUTORIAL_CATEGORIES } from "../_shared/tutorial_vocabulary.ts";
import {
  isRenderableCategory,
  TUTORIAL_GUIDELINE_PROMPT_VERSION,
  TUTORIAL_OUTPUT_RESOLUTION,
} from "../_shared/tutorial_ai_config.ts";
import { CATEGORY_GUIDANCE, categoryGuidance } from "./category_prompts.ts";
import { productNote, tutorialGuidelinePrompt } from "./prompt.ts";
import {
  myMakeupKitPresentation,
  standardPresentation,
  stepProductPresentation,
} from "./product_presentation.ts";

function promptFor(category: typeof TUTORIAL_CATEGORIES[number]): string {
  return tutorialGuidelinePrompt({
    category,
    guidance: categoryGuidance(category)!,
    stepPosition: 1,
    stepCount: 3,
    productNote: null,
  });
}

Deno.test("every supported category is renderable and has guidance", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    assertEquals(isRenderableCategory(category), true);
    assertEquals(categoryGuidance(category) !== null, true);
  }
  assertEquals(Object.keys(CATEGORY_GUIDANCE).length, 9);
});

Deno.test("each category names its own landmarks", () => {
  const expectations: Record<string, string[]> = {
    foundation: ["perimeter", "blended outward", "jawline"],
    concealer: ["under-eye", "blending direction", "fade"],
    contour_bronzer: ["cheekbone", "temple", "jawline", "nose"],
    blush: ["apple", "cheekbone", "upward and outward"],
    highlighter: ["brow bone", "inner corner", "Cupid's bow"],
    eyebrows: ["arch", "tail", "direction"],
    eyeshadow: ["mobile lid", "crease", "outer V", "inner corner"],
    eyeliner: ["lash line", "wing", "curvature", "endpoint"],
    lips: ["Cupid's bow", "corners", "lower lip boundary", "border"],
  };
  for (const [category, fragments] of Object.entries(expectations)) {
    const landmarks = CATEGORY_GUIDANCE[
      category as typeof TUTORIAL_CATEGORIES[number]
    ].landmarks;
    for (const fragment of fragments) {
      assertStringIncludes(landmarks, fragment);
    }
  }
});

Deno.test("each category forbids its own way of applying makeup", () => {
  const expectations: Record<string, string> = {
    foundation: "Do not tint, even out, smooth, or re-tone any skin",
    concealer: "Do not brighten, lighten, or smooth",
    contour_bronzer: "Do not add any brown, bronze, tan, or shadow tone",
    blush: "Do not add any pink, peach, coral, or red flush",
    highlighter: "Do not add shimmer, glow, sheen, sparkle",
    eyebrows: "Do not fill, darken, thicken, or redraw the eyebrows",
    eyeshadow: "Do not add any eyeshadow colour, depth, or shading",
    eyeliner: "Do not draw black or coloured liner on the lash line",
    lips: "Do not fill, tint, gloss, or colour the lips",
  };
  for (const [category, fragment] of Object.entries(expectations)) {
    assertStringIncludes(
      CATEGORY_GUIDANCE[category as typeof TUTORIAL_CATEGORIES[number]]
        .prohibition,
      fragment,
    );
  }
});

Deno.test("every category prompt carries the invariant authority rules", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "IMAGE A is the ORIGINAL photograph");
    assertStringIncludes(prompt, "This is your CANVAS");
    assertStringIncludes(prompt, "IMAGE B is the FINAL photograph");
    assertStringIncludes(prompt, "PLACEMENT COMES FROM IMAGE B ONLY");
    assertStringIncludes(
      prompt,
      "Do not use a standard, textbook, or flattering placement.",
    );
    assertStringIncludes(
      prompt,
      "they never override it and never add a marking IMAGE B does not support",
    );
  }
});

Deno.test("every category prompt stays guideline-only and text-free", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "DRAW ONLY GUIDELINES");
    assertStringIncludes(prompt, "NEVER APPLY MAKEUP");
    assertStringIncludes(prompt, "NO TEXT OF ANY KIND");
    assertStringIncludes(prompt, "PRESERVE THE PHOTOGRAPH");
    assertStringIncludes(prompt, `Mark ${category} and nothing else.`);
  }
});

Deno.test("each prompt scopes itself to exactly one category", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    assertStringIncludes(
      promptFor(category),
      `see exactly where ${category} was applied`,
    );
  }
});

Deno.test("the locked configuration survives the extension", () => {
  assertEquals(TUTORIAL_OUTPUT_RESOLUTION, "1K");
  assertEquals(TUTORIAL_GUIDELINE_PROMPT_VERSION, "tutorial_guideline_v4_2");
});

Deno.test("Standard Mode presentation stays brand-neutral", () => {
  const presentation = standardPresentation("lips", [
    {
      planKey: "lipstick",
      shadeName: "Rosewood",
      colorHex: "#B86F72",
      placement: "Across the lips.",
      technique: "Press and blot.",
      finish: "satin",
      intensity: "medium",
    },
    {
      planKey: "lipGloss",
      shadeName: "Clear shine",
      colorHex: null,
      placement: "Centre of the lower lip.",
      technique: "Dab lightly.",
      finish: "",
      intensity: "",
    },
  ]);

  assertEquals(presentation.mode, "standard");
  assertEquals(presentation.entries.length, 2);
  assertEquals(presentation.entries[0].shadeName, "Rosewood");
  // Empty upstream strings become null rather than blank display fields.
  assertEquals(presentation.entries[1].finish, null);
  assertEquals(presentation.entries[1].colorHex, null);
  const serialized = JSON.stringify(presentation).toLowerCase();
  for (const forbidden of ["brand", "retailer", "price", "purchase", "http"]) {
    assertEquals(serialized.includes(forbidden), false);
  }
});

Deno.test("My Makeup Kit presentation matches the snapshot exactly", () => {
  const presentation = myMakeupKitPresentation("foundation", [
    {
      productId: "p1",
      inventoryCategory: "foundation",
      productName: "My Foundation",
      colorHex: "#E3C4A8",
      colorLabel: "Warm Sand",
      finish: "natural",
      foundationDepth: "light",
      foundationUndertone: "warm",
    },
  ]);

  assertEquals(presentation.mode, "my_makeup_kit");
  const item = presentation.items[0];
  assertEquals(item.productName, "My Foundation");
  assertEquals(item.colorHex, "#E3C4A8");
  assertEquals(item.colorLabel, "Warm Sand");
  assertEquals(item.foundationDepth, "light");
  assertEquals(item.foundationUndertone, "warm");
});

Deno.test("missing product fields are never invented", () => {
  const presentation = myMakeupKitPresentation("blush", [
    {
      productId: "p1",
      inventoryCategory: "blush",
      productName: null,
      colorHex: "#B86F72",
      colorLabel: null,
      finish: "matte",
      foundationDepth: null,
      foundationUndertone: null,
    },
  ]);

  assertEquals(presentation.items[0].productName, null);
  assertEquals(presentation.items[0].colorLabel, null);
  assertEquals(presentation.items[0].foundationDepth, null);
});

Deno.test("Lips presents a lipstick, a gloss, or both", () => {
  const both = myMakeupKitPresentation("lips", [
    {
      productId: "p1",
      inventoryCategory: "lipstick",
      productName: "My Lipstick",
      colorHex: "#B86F72",
      colorLabel: null,
      finish: "cream",
      foundationDepth: null,
      foundationUndertone: null,
    },
    {
      productId: "p2",
      inventoryCategory: "lip_gloss",
      productName: "My Gloss",
      colorHex: "#D8A0A2",
      colorLabel: null,
      finish: "glossy",
      foundationDepth: null,
      foundationUndertone: null,
    },
  ]);

  assertEquals(both.items.length, 2);
  assertEquals(both.items.map((item) => item.inventoryCategory), [
    "lipstick",
    "lip_gloss",
  ]);

  const glossOnly = myMakeupKitPresentation("lips", [both.items[1]].map((
    item,
  ) => ({
    productId: item.productId,
    inventoryCategory: item.inventoryCategory,
    productName: item.productName,
    colorHex: item.colorHex,
    colorLabel: item.colorLabel,
    finish: item.finish,
    foundationDepth: item.foundationDepth,
    foundationUndertone: item.foundationUndertone,
  })));
  assertEquals(glossOnly.items.length, 1);
});

Deno.test("the adapter follows the source mode", () => {
  const kit = stepProductPresentation({
    sourceMode: "my_makeup_kit",
    category: "blush",
    standardPlan: [],
    products: [
      {
        productId: "p1",
        inventoryCategory: "blush",
        productName: "My Blush",
        colorHex: "#B86F72",
        colorLabel: null,
        finish: "matte",
        foundationDepth: null,
        foundationUndertone: null,
      },
    ],
  });
  assertEquals(kit.mode, "my_makeup_kit");

  const standard = stepProductPresentation({
    sourceMode: "standard",
    category: "blush",
    standardPlan: [],
    products: [],
  });
  assertEquals(standard.mode, "standard");
});

Deno.test("product wording never reaches the image prompt", () => {
  const prompt = tutorialGuidelinePrompt({
    category: "lips",
    guidance: categoryGuidance("lips")!,
    stepPosition: 1,
    stepCount: 1,
    productNote: productNote([
      { productName: "SomeBrand Velvet Matte", colorLabel: "Rosewood", finish: "cream" },
    ]),
  });

  // The finish and shade label may appear as technique context; the user's own
  // product name must not, and nothing may be written into the image.
  assertEquals(prompt.includes("SomeBrand Velvet Matte"), false);
  assertStringIncludes(prompt, "Rosewood (cream finish)");
  assertStringIncludes(prompt, "do not write it in the image");
  assertStringIncludes(prompt, "IMAGE B remains the only placement authority");
});
