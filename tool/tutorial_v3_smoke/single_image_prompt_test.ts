import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { SINGLE_IMAGE_SPECS } from "./single_image_fixtures.ts";
import {
  RENDERER_CATEGORY_RULES,
  SINGLE_IMAGE_PROMPT_VERSION,
  type RendererCategory,
  type RendererSpec,
  singleImageGuidelinePrompt,
} from "./single_image_prompt.ts";
import { promptForVariant } from "./run_single_image_gate.ts";

function specFor(category: RendererCategory): RendererSpec {
  const found = SINGLE_IMAGE_SPECS.find((spec) => spec.category === category);
  if (!found) throw new Error(`no fixture for ${category}`);
  return found;
}

const allPrompts = () =>
  SINGLE_IMAGE_SPECS.map((spec) => ({
    category: spec.category,
    text: singleImageGuidelinePrompt(spec),
  }));

const blush = singleImageGuidelinePrompt(specFor("blush"));

Deno.test("the prompt version is stable", () => {
  assertEquals(SINGLE_IMAGE_PROMPT_VERSION, "v3-guideline-single-image-1");
});

Deno.test("the gate covers the four required categories", () => {
  assertEquals(SINGLE_IMAGE_SPECS.map((spec) => spec.category), [
    "foundation",
    "blush",
    "eyeliner",
    "lipstick",
  ]);
});

// --- The rejected two-image architecture must be unreachable ---------------

Deno.test("no prompt mentions a second image or a canonical target", () => {
  const banned = [
    "image 2",
    "image2",
    "second image",
    "canonical",
    "final preview",
    "target image",
    "reference image",
    "both images",
    "two images",
  ];
  for (const { category, text } of allPrompts()) {
    const lower = text.toLowerCase();
    for (const phrase of banned) {
      assertEquals(
        lower.includes(phrase),
        false,
        `${category} prompt must not mention "${phrase}"`,
      );
    }
  }
});

Deno.test("the prompt refers to exactly one photograph", () => {
  for (const { category, text } of allPrompts()) {
    assertStringIncludes(text, "The attached photograph is the base.");
    assertEquals(
      text.includes("IMAGE 1"),
      false,
      `${category} should not need numbered images with only one input`,
    );
  }
});

Deno.test("variant reinforcement never introduces a second image", () => {
  for (const spec of SINGLE_IMAGE_SPECS) {
    for (const variant of [1, 2, 3]) {
      const lower = promptForVariant(spec, variant).toLowerCase();
      for (const phrase of ["image 2", "canonical", "second image"]) {
        assertEquals(
          lower.includes(phrase),
          false,
          `${spec.category} v${variant} leaked "${phrase}"`,
        );
      }
    }
  }
});

// --- Excluded persisted fields stay excluded --------------------------------

Deno.test("style name and finished-look prose are not sent to the renderer", () => {
  // Naming the look, or describing the finished appearance, is style-transfer
  // pressure in text form — the exact failure V3-6A.1 diagnosed.
  for (const { category, text } of allPrompts()) {
    const lower = text.toLowerCase();
    for (const phrase of [
      "soft glam",
      "selected look",
      "target look",
      "look cues",
      "rationale",
    ]) {
      assertEquals(
        lower.includes(phrase),
        false,
        `${category} prompt must not carry "${phrase}"`,
      );
    }
  }
});

Deno.test("the renderer spec type has no field for excluded prose", () => {
  const spec = specFor("blush") as unknown as Record<string, unknown>;
  for (const field of [
    "selectedStyleCode",
    "targetLookCues",
    "faceRationale",
    "targetRationale",
  ]) {
    assertEquals(field in spec, false, `${field} must not reach the renderer`);
  }
});

// --- Renderer framing -------------------------------------------------------

Deno.test("the model is framed as a renderer, not a designer", () => {
  assertStringIncludes(blush, "You are an INSTRUCTIONAL DIAGRAM RENDERER.");
  assertStringIncludes(blush, "You are not designing makeup.");
  assertStringIncludes(blush, "You are not choosing placement.");
  assertStringIncludes(blush, "You are not deciding what would suit this person.");
});

Deno.test("the Step Spec is stated as authoritative", () => {
  assertStringIncludes(
    blush,
    "The makeup application decision has ALREADY been made by another system.",
  );
  assertStringIncludes(blush, "Your only job is to draw that");
});

Deno.test("every Step Spec field reaches the prompt", () => {
  const spec = specFor("eyeliner");
  const text = singleImageGuidelinePrompt(spec);
  assertStringIncludes(text, spec.whereToApply);
  assertStringIncludes(text, spec.direction);
  assertStringIncludes(text, spec.technique);
  assertStringIncludes(text, spec.visualDescription);
});

Deno.test("optional fields are omitted rather than emitted empty", () => {
  assertEquals(specFor("blush").coverage, null);
  assertEquals(blush.includes("COVERAGE:"), false);
  assertStringIncludes(blush, "INTENSITY: Soft to medium");
});

// --- Invariants -------------------------------------------------------------

Deno.test("identity preservation is demanded in every prompt", () => {
  for (const { category, text } of allPrompts()) {
    for (const phrase of [
      "must survive completely unchanged",
      "Do NOT apply makeup",
      "Do NOT beautify",
      "Do NOT retouch or smooth skin",
      "Do NOT reshape the face",
    ]) {
      assertStringIncludes(text, phrase, `${category} missing "${phrase}"`);
    }
  }
});

Deno.test("finished makeup is forbidden in every prompt", () => {
  for (const { category, text } of allPrompts()) {
    assertStringIncludes(
      text,
      "Add NO finished makeup of any kind, anywhere, for any category.",
      `${category} missing the global no-makeup rule`,
    );
  }
});

Deno.test("the current category is locked in every prompt", () => {
  for (const spec of SINGLE_IMAGE_SPECS) {
    const text = singleImageGuidelinePrompt(spec);
    const label = RENDERER_CATEGORY_RULES[spec.category].label;
    assertStringIncludes(text, `Draw ONLY ${label}.`);
    assertStringIncludes(text, "No other makeup category may appear");
  }
});

Deno.test("typography is forbidden in every prompt", () => {
  for (const { category, text } of allPrompts()) {
    assertStringIncludes(
      text,
      "Add NO text, letters, numbers, labels, captions or watermarks.",
      `${category} missing the typography ban`,
    );
    assertStringIncludes(text, "words in the image are a defect");
  }
});

Deno.test("overlays must read as diagram, not pigment", () => {
  for (const { category, text } of allPrompts()) {
    assertStringIncludes(text, "The marks are NON-PHOTOGRAPHIC.");
    assertStringIncludes(
      text,
      "If a viewer could mistake your marks for actual makeup, they are wrong.",
      `${category} missing the pigment warning`,
    );
  }
});

// --- Scoped face attributes -------------------------------------------------

Deno.test("each category carries only its own scoped attributes", () => {
  const expected: Record<RendererCategory, string> = {
    foundation: "skin tone: medium",
    blush: "face shape: oval",
    eyeliner: "eye shape: almond",
    lipstick: "lip shape: medium",
  };
  for (const spec of SINGLE_IMAGE_SPECS) {
    const text = singleImageGuidelinePrompt(spec);
    const start = text.indexOf("RELEVANT FACE CONTEXT");
    const block = text.slice(start, text.indexOf("WHAT THE DIAGRAM", start));
    assertStringIncludes(block, expected[spec.category]);
    assertEquals(
      Object.keys(spec.faceAttributes).length <= 2,
      true,
      `${spec.category} carries too many attributes`,
    );
  }
});

Deno.test("face context cannot override the instruction", () => {
  assertStringIncludes(blush, "it never overrides");
});

// --- Blush geometry, the V3-6A.1 regression -------------------------------

Deno.test("blush demands two separate zones", () => {
  assertStringIncludes(blush, "TWO SEPARATE zones, one on each cheek");
  assertStringIncludes(blush, "must NEVER touch or connect");
  assertStringIncludes(blush, "clearly visible untouched skin between the two zones");
  assertStringIncludes(
    blush,
    "exactly TWO separate translucent zones, one per cheek",
  );
});

Deno.test("blush names the upper outer cheekbone explicitly", () => {
  assertStringIncludes(blush, "UPPER OUTER cheek");
  assertStringIncludes(blush, "lateral cheekbone");
  assertStringIncludes(blush, "extends outward toward the temple");
});

Deno.test("blush forbids the exact placements observed in V3-6A.1", () => {
  // All three variants there put the zone low/medial, and one merged the
  // cheeks across the nose. Each of those is now named and forbidden.
  for (const phrase of [
    "apple or centre of the cheek",
    "beside the nose",
    "on the side of the nose",
    "across the bridge of the nose",
  ]) {
    assertStringIncludes(blush, phrase);
  }
  assertStringIncludes(
    blush,
    "a single zone spanning the centre of the face",
  );
  assertStringIncludes(
    blush,
    "any zone touching, crossing or connecting across the nose",
  );
});

Deno.test("blush direction stays upward and outward", () => {
  assertStringIncludes(blush, "Diagonally upward and outward toward each temple");
  assertStringIncludes(
    blush,
    "arrows travelling diagonally up and out toward each temple",
  );
});

// --- Per-category rules -----------------------------------------------------

Deno.test("each category forbids its own finished appearance", () => {
  const mustForbid: Record<RendererCategory, string> = {
    foundation: "a visible foundation finish",
    blush: "any pink, rose or red colour on the cheeks",
    eyeliner: "a finished black, brown or coloured liner",
    lipstick: "any lipstick pigment or colour change on the lips",
  };
  for (const spec of SINGLE_IMAGE_SPECS) {
    assertStringIncludes(
      singleImageGuidelinePrompt(spec),
      mustForbid[spec.category],
    );
  }
});

Deno.test("neighbouring categories are excluded per category", () => {
  const foundation = singleImageGuidelinePrompt(specFor("foundation"));
  assertStringIncludes(foundation, "any eye makeup or lip makeup");
  assertStringIncludes(foundation, "smoothed, blurred, evened or retouched skin");

  const eyeliner = singleImageGuidelinePrompt(specFor("eyeliner"));
  assertStringIncludes(eyeliner, "eyeshadow of any kind");
  assertStringIncludes(eyeliner, "mascara or darkened lashes");

  const lipstick = singleImageGuidelinePrompt(specFor("lipstick"));
  assertStringIncludes(lipstick, "natural lips still visible through it");
  assertStringIncludes(lipstick, "natural lip colour still clearly visible underneath");
  assertStringIncludes(
    lipstick,
    "desaturating, greying or otherwise altering the natural lip colour",
  );
});

// --- The probe's single-image contract, asserted against its source ---------

Deno.test("the probe enforces exactly one image", async () => {
  const source = await Deno.readTextFile(
    "supabase/functions/tutorial-v3-single-image-guideline-probe/index.ts",
  );
  assertStringIncludes(source, "imagePartCount !== 1");
  assertStringIncludes(source, "single_image_contract_violated");
  // Multi-image fields are rejected outright rather than ignored.
  for (const field of ["images", "parts", "image2", "canonicalPreview", "target"]) {
    assertStringIncludes(source, `"${field}"`);
  }
  assertStringIncludes(source, "this renderer takes exactly one image");
});

Deno.test("the probe keeps JWT verification and never logs the key", () => {
  return Deno.readTextFile(
    "supabase/functions/tutorial-v3-single-image-guideline-probe/index.ts",
  ).then((source) => {
    assertStringIncludes(source, 'Deno.env.get("GEMINI_API_KEY")');
    assertStringIncludes(source, "TUTORIAL_V3_GUIDELINE_MODEL");
    // The key is never interpolated into a log line or a response body.
    assertEquals(source.includes("console.log(apiKey"), false);
    assertEquals(source.includes("apiKey }"), false);
    // GEMINI_IMAGE_MODEL belongs to the premium preview and must stay untouched.
    assertEquals(source.includes("GEMINI_IMAGE_MODEL"), false);
  });
});

Deno.test("an unsubstituted probe token disables the probe", async () => {
  const source = await Deno.readTextFile(
    "supabase/functions/tutorial-v3-single-image-guideline-probe/index.ts",
  );
  assertStringIncludes(source, '__EPHEMERAL_PROBE_TOKEN__');
  assertStringIncludes(source, "probe_not_configured");
});
