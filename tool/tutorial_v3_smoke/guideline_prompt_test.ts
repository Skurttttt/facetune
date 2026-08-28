import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { GATE_STEP_SPECS } from "./fixtures.ts";
import {
  CATEGORY_RULES,
  GUIDELINE_PROMPT_VERSION,
  type GuidelineCategory,
  type GuidelineSpec,
  tutorialV3GuidelinePrompt,
} from "./guideline_prompt.ts";

function specFor(category: GuidelineCategory): GuidelineSpec {
  const found = GATE_STEP_SPECS.find((spec) => spec.category === category);
  if (!found) throw new Error(`no fixture for ${category}`);
  return found;
}

const blush = tutorialV3GuidelinePrompt(specFor("blush"));

Deno.test("the prompt version is stable", () => {
  assertEquals(GUIDELINE_PROMPT_VERSION, "v3-guideline-gate-1");
});

Deno.test("image 1 is established as the immutable base", () => {
  assertStringIncludes(blush, "IMAGE 1 — THE BASE IMAGE");
  assertStringIncludes(
    blush,
    "Your output MUST be IMAGE 1, unchanged, with instructional overlays drawn on top.",
  );
  for (const preserved of [
    "identity",
    "facial proportions",
    "skin tone, skin texture",
    "expression",
    "hair",
    "lighting",
  ]) {
    assertStringIncludes(blush, preserved);
  }
});

Deno.test("image 2 is established as reference only", () => {
  assertStringIncludes(blush, "IMAGE 2 — REFERENCE ONLY");
  assertStringIncludes(blush, "Do NOT copy IMAGE 2.");
  assertStringIncludes(blush, "Do NOT blend IMAGE 2 into IMAGE 1.");
  assertStringIncludes(
    blush,
    "Do NOT transfer the makeup, colour, skin finish or styling from IMAGE 2 onto IMAGE 1.",
  );
  assertStringIncludes(blush, "or a mixture of the two faces");
});

Deno.test("the image roles are restated, not stated once", () => {
  // A single mention is what lets a model drift into face-blending on a long
  // prompt, so the contract is repeated at the framing, at the target, and in
  // the closing constraints.
  const image1Mentions = blush.split("IMAGE 1").length - 1;
  const image2Mentions = blush.split("IMAGE 2").length - 1;
  assertEquals(image1Mentions >= 3, true, `IMAGE 1 mentioned ${image1Mentions}x`);
  assertEquals(image2Mentions >= 3, true, `IMAGE 2 mentioned ${image2Mentions}x`);
});

Deno.test("the Step Spec is authoritative and not open to redesign", () => {
  assertStringIncludes(blush, "The Step Spec below is the instruction");
  assertStringIncludes(
    blush,
    "Do not invent a different placement, direction, intensity or technique",
  );
  assertStringIncludes(
    blush,
    "This person has already chosen their look; you are teaching it, not designing it.",
  );
});

Deno.test("every Step Spec field reaches the prompt", () => {
  const spec = specFor("blush");
  assertStringIncludes(blush, spec.whereToApply);
  assertStringIncludes(blush, spec.direction);
  assertStringIncludes(blush, spec.technique);
  assertStringIncludes(blush, spec.visualDescription);
  assertStringIncludes(blush, spec.faceRationale);
  assertStringIncludes(blush, spec.targetRationale);
  assertStringIncludes(blush, spec.selectedStyleCode);
  for (const cue of spec.targetLookCues) assertStringIncludes(blush, cue);
});

Deno.test("optional fields are omitted rather than emitted empty", () => {
  const spec = specFor("blush");
  assertEquals(spec.coverage, null);
  assertEquals(blush.includes("COVERAGE:"), false);
  assertStringIncludes(blush, "INTENSITY: Soft, diffused");
});

Deno.test("only scoped face attributes appear", () => {
  // Scope the check to the face-context block. "skin tone" also appears in the
  // identity-preservation list ("preserve skin tone, skin texture…"), which is
  // an instruction about IMAGE 1, not personalization context.
  const start = blush.indexOf("RELEVANT FACE CONTEXT");
  const block = blush.slice(start, blush.indexOf("WHY THIS PLACEMENT", start));

  assertStringIncludes(block, "face shape: oval");
  for (const irrelevant of ["lip shape", "eye shape", "skin tone", "undertone"]) {
    assertEquals(
      block.includes(irrelevant),
      false,
      `blush must not carry ${irrelevant}`,
    );
  }
});

Deno.test("each category carries only its own scoped attributes", () => {
  const expected: Record<string, string> = {
    foundation: "skin tone: medium",
    blush: "face shape: oval",
    eyeliner: "eye shape: almond",
    lipstick: "lip shape: medium",
  };

  for (const spec of GATE_STEP_SPECS) {
    const prompt = tutorialV3GuidelinePrompt(spec);
    const start = prompt.indexOf("RELEVANT FACE CONTEXT");
    const block = prompt.slice(
      start,
      prompt.indexOf("WHY THIS PLACEMENT", start),
    );
    assertStringIncludes(block, expected[spec.category]);
    assertEquals(
      Object.keys(spec.faceAttributes).length <= 2,
      true,
      `${spec.category} carries too many attributes`,
    );
  }
});

Deno.test("face context cannot override the Step Spec", () => {
  assertStringIncludes(
    blush,
    "explains the placement; never overrides the Step Spec",
  );
});

Deno.test("finished makeup is forbidden globally and per category", () => {
  assertStringIncludes(blush, "Add NO finished makeup of any kind");
  assertStringIncludes(blush, "any visible pink, rose or red colour on the cheeks");
  assertStringIncludes(blush, "a finished blush result");
});

Deno.test("the current category is locked", () => {
  assertStringIncludes(
    blush,
    "Teach ONLY the current category. No other makeup category may be shown",
  );
  assertStringIncludes(blush, "CURRENT CATEGORY: Blush");
});

Deno.test("AI typography is forbidden", () => {
  assertStringIncludes(
    blush,
    "Add NO text, letters, numbers, labels, captions, watermarks or typography.",
  );
  assertStringIncludes(blush, "words in the image are a defect");
});

Deno.test("no previous guideline is referenced", () => {
  // V3 steps are independent; nothing may point at an earlier step's output.
  for (const spec of GATE_STEP_SPECS) {
    const prompt = tutorialV3GuidelinePrompt(spec);
    assertEquals(prompt.toLowerCase().includes("previous step"), false);
    assertEquals(prompt.toLowerCase().includes("previous guideline"), false);
    assertEquals(prompt.toLowerCase().includes("image 3"), false);
  }
});

Deno.test("each category carries its own allowed and forbidden rules", () => {
  for (const spec of GATE_STEP_SPECS) {
    const prompt = tutorialV3GuidelinePrompt(spec);
    const rules = CATEGORY_RULES[spec.category];
    for (const line of rules.allowed) assertStringIncludes(prompt, line);
    for (const line of rules.forbidden) assertStringIncludes(prompt, line);
    assertStringIncludes(prompt, `CURRENT CATEGORY: ${rules.label}`);
  }
});

Deno.test("neighbouring categories are explicitly excluded", () => {
  const eyeliner = tutorialV3GuidelinePrompt(specFor("eyeliner"));
  assertStringIncludes(eyeliner, "eyeshadow");
  assertStringIncludes(eyeliner, "darkened lashes or mascara");
  assertStringIncludes(eyeliner, "any change to eye shape, size or spacing");

  const lipstick = tutorialV3GuidelinePrompt(specFor("lipstick"));
  assertStringIncludes(
    lipstick,
    "reshaped, plumped, enlarged or over-lined lips",
  );

  const foundation = tutorialV3GuidelinePrompt(specFor("foundation"));
  assertStringIncludes(foundation, "smoothed, blurred or retouched skin");
});

Deno.test("only declared graphics are requested", () => {
  for (const spec of GATE_STEP_SPECS) {
    const prompt = tutorialV3GuidelinePrompt(spec);
    for (const graphic of spec.graphics) {
      assertStringIncludes(prompt, `- ${graphic.replace(/_/g, " ")}`);
    }
  }
});

Deno.test("the gate covers the four required categories", () => {
  assertEquals(GATE_STEP_SPECS.map((spec) => spec.category), [
    "foundation",
    "blush",
    "eyeliner",
    "lipstick",
  ]);
});

Deno.test("overlays must be distinguishable from real makeup", () => {
  assertStringIncludes(
    blush,
    "instructional marks on an untouched photo, not a preview of a result",
  );
});
