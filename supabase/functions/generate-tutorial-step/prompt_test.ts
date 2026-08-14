import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { TUTORIAL_STEP_PROMPT_VERSION, tutorialStepPrompt } from "./prompt.ts";

Deno.test("the first step describes a bare face, not prior makeup", () => {
  const prompt = tutorialStepPrompt({
    isFirstStep: true,
    stepNumber: 1,
    totalSteps: 6,
    categoryLabel: "Foundation",
    instruction: { placement: "All over", intensity: "light" },
  });

  assertEquals(TUTORIAL_STEP_PROMPT_VERSION, "tutorial_step_v1");
  assertStringIncludes(prompt, "no makeup applied yet");
  assertStringIncludes(prompt, "step 1 of 6");
  assertStringIncludes(
    prompt,
    "Preserve the same person's recognizable identity",
  );
});

Deno.test("a later step instructs preserving every prior step", () => {
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    stepNumber: 4,
    totalSteps: 8,
    categoryLabel: "Blush",
    instruction: {
      colorName: "Peach Rose",
      hex: "#E58C87",
      placement: "Upper cheekbones",
    },
  });

  assertStringIncludes(prompt, "previous 3 steps");
  assertStringIncludes(prompt, "do not remove, fade, blend away");
  assertStringIncludes(prompt, "step 4 of 8");
  assertStringIncludes(prompt, "#E58C87");
});

Deno.test("a second step uses singular \"step\" for the single prior step", () => {
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    stepNumber: 2,
    totalSteps: 5,
    categoryLabel: "Concealer",
    instruction: { placement: "Under-eye" },
  });

  assertStringIncludes(prompt, "previous 1 step of this tutorial");
});

Deno.test("never lists specific prior-step colors or products in the text", () => {
  // The prompt only ever describes the CURRENT step's instruction — the
  // reference image, not text, is the source of truth for prior steps.
  const prompt = tutorialStepPrompt({
    isFirstStep: false,
    stepNumber: 3,
    totalSteps: 6,
    categoryLabel: "Contour",
    instruction: { placement: "Cheekbones and jawline" },
  });

  assertStringIncludes(prompt, "Contour");
  assertEquals(prompt.includes("Foundation"), false);
});
