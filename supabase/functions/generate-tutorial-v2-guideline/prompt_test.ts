import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  relevantAttributes,
  TUTORIAL_V2_GUIDELINE_PROMPT_VERSION,
  tutorialV2GuidelinePrompt,
  type GuidelineInput,
} from "./prompt.ts";
import type { ProductSnapshot, StepSpec } from "./types.ts";

const attributes = {
  faceShape: "heart",
  skinTone: "medium",
  undertone: "warm",
  eyeShape: "almond",
  lipShape: "full",
  hairColor: "dark_brown",
  eyeColor: "brown",
};

function spec(overrides: Partial<StepSpec> = {}): StepSpec {
  return {
    category: "blush",
    title: "Blush",
    whatToApply: "A soft rose blush",
    whereToApply: "Upper outer cheeks",
    direction: "Blend upward and outward toward the temples",
    technique: "Soft circular blending",
    intensity: "soft",
    faceRationale: "Heart-shaped faces balance with upper-cheek colour.",
    targetLookCues: "Matches the warm flush in the final look.",
    amount: null,
    toolSuggestion: null,
    personalizedTip: null,
    avoid: null,
    ...overrides,
  };
}

function input(overrides: Partial<GuidelineInput> = {}): GuidelineInput {
  return {
    spec: spec(),
    styleCode: "soft_glam",
    attributes,
    product: null,
    stepNumber: 2,
    totalSteps: 5,
    baseIsOriginalSelfie: false,
    completedCategories: ["foundation"],
    futureCategories: ["eyeliner", "lipstick"],
    ...overrides,
  };
}

/// Line wrapping is cosmetic. Assert on collapsed text so a reflow does not
/// fail a test about content.
function assertSays(prompt: string, phrase: string) {
  const collapse = (value: string) => value.replace(/\s+/g, " ").trim();
  assertStringIncludes(collapse(prompt), collapse(phrase));
}

Deno.test("the prompt version is pinned", () => {
  assertEquals(TUTORIAL_V2_GUIDELINE_PROMPT_VERSION, "tutorial_v2_guideline_v1");
});

// --- Canonical target -------------------------------------------------------

Deno.test("the canonical final target is named as the exact target", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "IMAGE 3 — CANONICAL FINAL TARGET");
  assertSays(prompt, "it is the exact end state");
  assertSays(prompt, "not inspiration and not a suggestion");
});

Deno.test("states the model is not creating a new look", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "YOU ARE NOT CREATING A NEW MAKEUP LOOK");
  assertSays(prompt, "Do not design an alternative look");
  assertSays(prompt, "do not reinterpret the style");
});

Deno.test("forbids copying the finished target into the output", () => {
  assertSays(
    tutorialV2GuidelinePrompt(input()),
    "Do NOT copy its finished makeup into your output",
  );
});

// --- Step Spec fidelity -----------------------------------------------------

Deno.test("the persisted Step Spec is carried verbatim", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "Apply: A soft rose blush");
  assertSays(prompt, "Where: Upper outer cheeks");
  assertSays(prompt, "Direction: Blend upward and outward toward the temples");
  assertSays(prompt, "Technique: Soft circular blending");
  assertSays(prompt, "Intensity: soft");
});

Deno.test("forbids reinterpreting the instruction", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "VISUALIZE THIS EXACT INSTRUCTION — DO NOT REINTERPRET IT");
  assertSays(prompt, "Your only job is to draw what it says");
  assertSays(prompt, "you are wrong for this task");
  assertSays(prompt, "never toward the nose, never downward");
});

Deno.test("optional spec fields appear only when present", () => {
  const without = tutorialV2GuidelinePrompt(input());
  assert(!without.includes("Amount:"));
  assert(!without.includes("Tool:"));
  assert(!without.includes("Avoid:"));

  const with_ = tutorialV2GuidelinePrompt(
    input({
      spec: spec({
        amount: "One light sweep",
        toolSuggestion: "Fluffy brush",
        avoid: "Do not drag toward the nose",
      }),
    }),
  );
  assertSays(with_, "Amount: One light sweep");
  assertSays(with_, "Tool: Fluffy brush");
  assertSays(with_, "Avoid: Do not drag toward the nose");
});

// --- Category lock ----------------------------------------------------------

Deno.test("locks the image to the current category", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "CURRENT CATEGORY LOCK — BLUSH ONLY");
  assertSays(prompt, "This image teaches Blush and nothing else");
  assertSays(
    prompt,
    "Drawing an arrow, zone, or marker for any category other than Blush makes this image wrong",
  );
});

Deno.test("names completed categories as untouchable", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(
    prompt,
    "Already applied in IMAGE 2 and must be left exactly as they are",
  );
  assertSays(prompt, "Foundation");
});

Deno.test("names future categories as forbidden", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "Not yet reached");
  assertSays(prompt, "Eyeliner, Lip Colour");
});

Deno.test("handles a first step with nothing completed", () => {
  const prompt = tutorialV2GuidelinePrompt(
    input({ completedCategories: [], baseIsOriginalSelfie: true }),
  );
  assertSays(prompt, "No makeup has been applied yet");
  assertSays(prompt, "the original selfie, because this is the first step");
});

Deno.test("handles a last makeup step with nothing ahead", () => {
  const prompt = tutorialV2GuidelinePrompt(input({ futureCategories: [] }));
  assertSays(prompt, "No categories remain after this one");
});

// --- Instructional, not a beauty result -------------------------------------

Deno.test("forbids producing a finished beauty result", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "THIS IS AN INSTRUCTIONAL DIAGRAM, NOT A BEAUTY RESULT");
  assertSays(prompt, "Do NOT apply the finished Blush to the face");
  assertSays(prompt, "must still look exactly like IMAGE 2");
  assertSays(prompt, "it has failed");
});

Deno.test("permits exactly the intended annotation vocabulary", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  for (
    const allowed of [
      "translucent shaded zones",
      "directional arrows",
      "thin paths or dashed lines",
      "soft gradient bands",
      "small dots or ticks",
    ]
  ) {
    assertSays(prompt, allowed);
  }
});

// --- No AI typography -------------------------------------------------------

Deno.test("forbids rendering text into the image", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "DO NOT WRITE WORDS");
  assertSays(
    prompt,
    "Do not render text, numbers, labels, captions, legends, callouts, watermarks",
  );
  assertSays(prompt, "Every written instruction is displayed separately by the app");
  assertSays(prompt, "Return exactly one edited image and no text");
});

// --- Identity ---------------------------------------------------------------

Deno.test("requires identity and framing preservation", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "PRESERVE IDENTITY AND FRAMING");
  assertSays(prompt, "Do not beautify, slim, reshape, symmetrize");
  assertSays(prompt, "Do not change skin tone");
  assertSays(
    prompt,
    "The only difference between IMAGE 2 and your output is the instructional overlay",
  );
});

Deno.test("forbids unrelated beautification", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "Do not remove freckles, moles, scars, or pores");
  assertSays(prompt, "Do not add jewellery, lashes, filters, borders");
});

// --- Personalisation --------------------------------------------------------

Deno.test("sends only the attributes that govern this category", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, '"faceShape":"heart"');
  assertSays(prompt, '"undertone":"warm"');
  // Eye and lip attributes do not govern blush placement, and inviting the
  // model to consider them invites unrelated changes.
  assert(!prompt.includes('"eyeShape"'));
  assert(!prompt.includes('"lipShape"'));
});

Deno.test("eye categories receive eye attributes", () => {
  const prompt = tutorialV2GuidelinePrompt(
    input({ spec: spec({ category: "eyeliner" }) }),
  );
  assertSays(prompt, '"eyeShape":"almond"');
  assert(!prompt.includes('"lipShape"'));
});

Deno.test("lip categories receive lip attributes", () => {
  const prompt = tutorialV2GuidelinePrompt(
    input({ spec: spec({ category: "lipstick" }) }),
  );
  assertSays(prompt, '"lipShape":"full"');
  assert(!prompt.includes('"eyeShape"'));
});

Deno.test("relevantAttributes selects per category", () => {
  assertEquals(relevantAttributes("blush", attributes), {
    faceShape: "heart",
    skinTone: "medium",
    undertone: "warm",
  });
  assertEquals(relevantAttributes("eyeliner", attributes), {
    eyeShape: "almond",
  });
  assertEquals(relevantAttributes("unknown_category", attributes), {});
});

Deno.test("carries the persisted rationale and target cues", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assertSays(prompt, "Heart-shaped faces balance with upper-cheek colour.");
  assertSays(prompt, "Matches the warm flush in the final look.");
  assertSays(prompt, "Selected look: soft_glam");
});

Deno.test("states the step position", () => {
  assertSays(tutorialV2GuidelinePrompt(input()), "step 2 of 5");
});

// --- Kit product ------------------------------------------------------------

Deno.test("omits the product section outside Kit mode", () => {
  assert(!tutorialV2GuidelinePrompt(input()).includes("OWNED PRODUCT"));
});

Deno.test("includes the validated owned product in Kit mode", () => {
  const product: ProductSnapshot = {
    productId: "product-1",
    category: "blush",
    colorHex: "#B86F72",
    finish: "matte",
    productName: "Studio Blush",
    colorLabel: "Rosewood",
  };
  const prompt = tutorialV2GuidelinePrompt(input({ product }));

  assertSays(prompt, "OWNED PRODUCT FOR THIS STEP");
  assertSays(prompt, "(Studio Blush)");
  assertSays(prompt, 'shade "Rosewood"');
  assertSays(prompt, "#B86F72, matte finish");
  assertSays(prompt, "Do not substitute a different colour or product");
});

Deno.test("does not invite the model to choose a product", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assert(!prompt.toLowerCase().includes("choose a product"));
  assert(!prompt.toLowerCase().includes("select a product"));
});

// --- Secrets ----------------------------------------------------------------

Deno.test("never leaks a credential", () => {
  const prompt = tutorialV2GuidelinePrompt(input());
  assert(!prompt.includes("GEMINI_API_KEY"));
  assert(!prompt.includes("x-goog-api-key"));
  assert(!prompt.includes("SUPABASE_SERVICE_ROLE_KEY"));
});
