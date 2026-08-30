import {
  assertEquals,
  assertStringIncludes,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import { FunctionFailure } from "./types.ts";
import {
  isUnchanged,
  validateGuidelineImage,
} from "./gemini_client.ts";
import { categoryIntent, productNote, tutorialGuidelinePrompt } from "./prompt.ts";
import {
  guidelineStoragePath,
  isPilotCategory,
  TUTORIAL_GUIDELINE_PROMPT_VERSION,
  TUTORIAL_OUTPUT_RESOLUTION,
} from "../_shared/tutorial_ai_config.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const analysisId = "44444444-4444-4444-8444-444444444444";
const sessionId = "33333333-3333-4333-8333-333333333333";

function blushPrompt(products: Parameters<typeof productNote>[0] = []): string {
  return tutorialGuidelinePrompt({
    category: "blush",
    intent: categoryIntent("blush")!,
    stepPosition: 2,
    stepCount: 4,
    productNote: productNote(products),
  });
}

Deno.test("only the pilot category is enabled", () => {
  assertEquals(isPilotCategory("blush"), true);
  for (
    const category of [
      "foundation",
      "concealer",
      "contour_bronzer",
      "highlighter",
      "eyebrows",
      "eyeshadow",
      "eyeliner",
      "lips",
    ] as const
  ) {
    assertEquals(isPilotCategory(category), false);
  }
  assertEquals(categoryIntent("lips"), null);
});

Deno.test("the prompt assigns Image A and Image B their roles", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "IMAGE A is the ORIGINAL photograph");
  assertStringIncludes(prompt, "This is your CANVAS");
  assertStringIncludes(prompt, "IMAGE B is the FINAL photograph");
  assertStringIncludes(prompt, "This is your REFERENCE");
});

Deno.test("the prompt forbids applying pigment", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "NEVER APPLY MAKEUP");
  assertStringIncludes(prompt, "same bare skin");
  assertStringIncludes(prompt, "Draw thin outlines, boundary lines");
});

Deno.test("the prompt forbids any text in the image", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "NO TEXT OF ANY KIND");
  assertStringIncludes(prompt, "brand names, product names, shade names");
  assertStringIncludes(prompt, "All wording is shown outside the image");
});

Deno.test("the prompt restricts the rendering to one category", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "Mark blush and nothing else.");
  assertStringIncludes(prompt, "Ignore every other makeup category");
});

Deno.test("the prompt makes Image B the placement authority", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "PLACEMENT COMES FROM IMAGE B ONLY");
  assertStringIncludes(prompt, "Do not use a standard, textbook, or flattering");
  assertStringIncludes(prompt, "mark the smaller, more conservative area");
});

Deno.test("the prompt preserves the photograph", () => {
  const prompt = blushPrompt();
  assertStringIncludes(prompt, "Preserve identity, facial proportions, pose");
  assertStringIncludes(prompt, "Do not beautify, smooth, reshape");
});

Deno.test("the step counter reflects the included count", () => {
  assertStringIncludes(blushPrompt(), "This is step 2 of 4.");
});

Deno.test("Standard Mode adds no product note", () => {
  assertEquals(productNote([]), null);
  assertEquals(blushPrompt().includes("CONTEXT ONLY"), false);
});

Deno.test("product context is subordinated to Image B", () => {
  const prompt = blushPrompt([
    { productName: "My Blush", colorLabel: "Rose Glow", finish: "satin" },
  ]);
  assertStringIncludes(prompt, "CONTEXT ONLY");
  assertStringIncludes(prompt, "Rose Glow (satin finish)");
  assertStringIncludes(prompt, "It does NOT change where the markings go");
  assertStringIncludes(prompt, "IMAGE B remains the only placement authority");
  assertStringIncludes(prompt, "do not write it in the image");
});

Deno.test("several owned products are described together", () => {
  const note = productNote([
    { productName: "A", colorLabel: "Rose", finish: "satin" },
    { productName: "B", colorLabel: "Coral", finish: "matte" },
  ]);
  assertStringIncludes(note!, "Rose (satin finish) and Coral (matte finish)");
});

Deno.test("an unnamed shade is described without inventing one", () => {
  const note = productNote([
    { productName: null, colorLabel: null, finish: "matte" },
  ]);
  assertStringIncludes(note!, "an owned shade (matte finish)");
});

Deno.test("the guideline path is owner-scoped and never collides", () => {
  const path = guidelineStoragePath({
    userId,
    analysisId,
    tutorialSessionId: sessionId,
    category: "blush",
    attempt: 1,
    extension: "png",
  });

  assertEquals(
    path,
    `${userId}/analyses/${analysisId}/tutorials/${sessionId}/blush_0001.png`,
  );
  assertEquals(path.startsWith(`${userId}/`), true);
  assertEquals(path.includes("/tutorials/"), true);
  assertEquals(path.includes("/original/"), false);
  assertEquals(path.includes("/generated/"), false);
});

Deno.test("each attempt writes a new object", () => {
  const first = guidelineStoragePath({
    userId,
    analysisId,
    tutorialSessionId: sessionId,
    category: "blush",
    attempt: 1,
    extension: "png",
  });
  const second = guidelineStoragePath({
    userId,
    analysisId,
    tutorialSessionId: sessionId,
    category: "blush",
    attempt: 2,
    extension: "png",
  });
  assertEquals(first === second, false);
});

Deno.test("the locked configuration is 1K and a versioned prompt", () => {
  assertEquals(TUTORIAL_OUTPUT_RESOLUTION, "1K");
  assertEquals(TUTORIAL_GUIDELINE_PROMPT_VERSION, "tutorial_guideline_v4_1");
});

Deno.test("a non-image or malformed payload is rejected", () => {
  assertThrows(() => validateGuidelineImage("", "image/png"), FunctionFailure);
  assertThrows(
    () => validateGuidelineImage("abc", "text/plain"),
    FunctionFailure,
  );
  assertThrows(() => validateGuidelineImage("!!!", "image/png"), FunctionFailure);
});

Deno.test("an unchanged image is detected", () => {
  const original = new Uint8Array([1, 2, 3, 4]);
  assertEquals(isUnchanged(original, new Uint8Array([1, 2, 3, 4])), true);
  assertEquals(isUnchanged(original, new Uint8Array([1, 2, 3, 5])), false);
  assertEquals(isUnchanged(original, new Uint8Array([1, 2, 3])), false);
});
