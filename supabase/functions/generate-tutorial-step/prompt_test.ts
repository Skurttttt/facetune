import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  personalizedPromptInput,
  TUTORIAL_STEP_PROMPT_VERSION,
  tutorialStepPrompt,
} from "./prompt.ts";

const input = personalizedPromptInput({
  selectedStyle: "Korean",
  sourceMode: "standard",
  faceAttributes: {
    face_shape: "round",
    skin_tone: "medium",
    undertone: "warm",
    eye_shape: "hooded",
    lip_shape: "full",
    hair_color: "dark brown",
    eye_color: "brown",
  },
  stepNumber: 4,
  category: "Blush",
  instruction: {
    product: "Cloud Cheek",
    colorName: "Peach Rose",
    colorHex: "#E58C87",
    finish: "satin",
    placement: "Upper outer cheek",
    side: "bilateral",
    direction: "outward_upward",
    intensity: "light",
    technique: "soft_diffused_sweep",
    faceAdjustment: "Keep color lifted away from the center of a round face.",
    styleAdjustment: "Use a soft Korean-style diffused edge.",
  },
});

Deno.test("builds the complete versioned prompt from personalized spec", () => {
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    totalSteps: 8,
    input,
  });

  assertEquals(TUTORIAL_STEP_PROMPT_VERSION, "personalized_tutorial_step_v2");
  for (const expected of [
    "Selected style: Korean",
    "Face shape: round",
    "Eye shape: hooded",
    "Category: Blush",
    "Product: Cloud Cheek",
    "Color: Peach Rose",
    "HEX: #E58C87",
    "Finish: satin",
    "Placement: Upper outer cheek",
    "Side: bilateral",
    "Direction: outward_upward",
    "Intensity: light",
    "Technique: soft_diffused_sweep",
    "Keep color lifted away from the center of a round face.",
    "Use a soft Korean-style diffused edge.",
  ]) assertStringIncludes(prompt, expected);
});

Deno.test("later steps preserve identity and cumulative makeup and stay clean", () => {
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    totalSteps: 8,
    input,
  });

  assertStringIncludes(prompt, "FIRST image is the original selfie");
  assertStringIncludes(prompt, "SECOND image is the previous Result");
  assertStringIncludes(prompt, "Preserve ALL correctly applied previous makeup");
  assertStringIncludes(prompt, "Apply ONLY the current makeup step");
  assertStringIncludes(prompt, "Do NOT draw:\n- arrows\n- overlay lines\n- dots");
});

Deno.test("first step uses the original selfie as identity and starting state", () => {
  const first = personalizedPromptInput({
    stepNumber: 1,
    category: "Foundation",
    instruction: { placement: "Thin coverage across the face" },
  });
  const prompt = tutorialStepPrompt({
    isFirstStep: true,
    totalSteps: 6,
    input: first,
  });

  assertStringIncludes(prompt, "makeup-free starting state");
  assertStringIncludes(prompt, "Step number: 1 of 6");
  assertEquals(prompt.includes("undefined"), false);
  assertEquals(prompt.includes("null"), false);
});

Deno.test("kit mode never authorizes invented product facts", () => {
  const kit = personalizedPromptInput({
    selectedStyle: "Full Glam",
    sourceMode: "makeup_kit",
    stepNumber: 2,
    category: "Lipstick",
    instruction: {
      productName: "Owned Red Lipstick",
      kitProductId: "kit-product-7",
      hex: "#A3132A",
    },
  });
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    totalSteps: 4,
    input: kit,
  });

  assertStringIncludes(prompt, "Product: Owned Red Lipstick");
  assertStringIncludes(prompt, "HEX: #A3132A");
  assertStringIncludes(prompt, "Do not invent, substitute, or infer any kit product");
});

Deno.test("unavailable optional values are omitted instead of fabricated", () => {
  const sparse = personalizedPromptInput({
    stepNumber: 3,
    category: "Brows",
    instruction: {},
  });
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    totalSteps: 5,
    input: sparse,
  });

  assertStringIncludes(prompt, "Product: Brows");
  assertEquals(prompt.includes("Color:"), false);
  assertEquals(prompt.includes("HEX:"), false);
  assertEquals(prompt.includes("Finish:"), false);
  assertEquals(prompt.includes("undefined"), false);
});

Deno.test("reopened persisted spec wins over legacy instruction projection", () => {
  const reopened = personalizedPromptInput({
    stepNumber: 4,
    category: "Blush",
    instruction: { placement: "Legacy generic cheeks", intensity: "medium" },
    personalizedSpec: {
      what: {
        category: "blush",
        productName: "Saved Owned Blush",
        colorHex: "#E58C87",
        productSnapshot: { productId: "owned-7" },
      },
      where: {
        description: "Saved upper outer cheek placement",
        side: "bilateral",
        placementConfidence: "high",
      },
      how: {
        direction: "upwardOutward",
        intensity: "light",
        technique: "Saved diffused sweep",
      },
      faceAdjustment: "Saved round-face lift.",
      styleAdjustment: "Saved Korean diffusion.",
    },
  });

  assertEquals(reopened.stepSpec.placement, "Saved upper outer cheek placement");
  assertEquals(reopened.stepSpec.intensity, "light");
  assertEquals(reopened.stepSpec.product, "Saved Owned Blush");
  assertEquals(reopened.stepSpec.kitProductId, "owned-7");
});
