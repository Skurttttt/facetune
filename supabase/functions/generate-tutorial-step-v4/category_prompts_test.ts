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
import {
  CATEGORY_GUIDANCE,
  categoryGuidance,
  REPRESENTATIVE_CATEGORIES,
} from "./category_prompts.ts";
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
    // V4-QA-2C rewrote the representative four from category description into
    // target extraction, so they no longer name a region and its conventional
    // placement — they name what to find in IMAGE B.
    blush: ["footprint", "bounds of the colour", "strongest"],
    highlighter: ["brow bone", "inner corner", "Cupid's bow"],
    eyebrows: ["arch", "tail", "direction"],
    eyeshadow: ["mobile lid", "crease", "outer V", "inner corner"],
    eyeliner: ["lash line", "wing", "curvature", "endpoint"],
    lips: ["Cupid's bow", "corner", "lower lip boundary", "target border"],
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
  assertEquals(TUTORIAL_GUIDELINE_PROMPT_VERSION, "tutorial_guideline_v4_7");
});

Deno.test("every prompt states the canonical-preview fidelity contract", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "Compare IMAGE A with IMAGE B");
    assertStringIncludes(
      prompt,
      "Determine what visibly changed in THIS category",
    );
    assertStringIncludes(prompt, "Do not substitute generic makeup placement.");
    assertStringIncludes(
      prompt,
      "draw the minimum useful instructional guides on IMAGE A",
    );
    assertStringIncludes(prompt, "Analyse the current category only.");
  }
});

Deno.test("every prompt states the guideline-only negative contract", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "DO NOT APPLY MAKEUP.");
    assertStringIncludes(prompt, "DO NOT beautify.");
    assertStringIncludes(prompt, "DO NOT recolor the face.");
    assertStringIncludes(prompt, "DO NOT change other categories.");
  }
});

Deno.test("every prompt prefers the fewest useful guides", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "USE THE FEWEST GUIDES THAT TEACH IT");
    assertStringIncludes(
      prompt,
      "Prefer a few meaningful guide elements over dense decorative geometry.",
    );
    assertStringIncludes(prompt, "Every mark must have a teaching purpose.");
    // Construction geometry is the specific way "thorough" goes wrong.
    assertStringIncludes(prompt, "symmetry axes, grids");
  }
});

Deno.test("the representative gate covers exactly four categories", () => {
  assertEquals([...REPRESENTATIVE_CATEGORIES], [
    "blush",
    "eyeshadow",
    "eyeliner",
    "lips",
  ]);
});

// V4-QA-3 propagated the representative architecture to all nine. These three
// tests previously asserted the opposite — that only the gate's four carried it
// — which was the correct contract while the architecture was being proven.
Deno.test("every category now carries questions and hard rules", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const guidance = CATEGORY_GUIDANCE[category];
    assertEquals(
      guidance.analysis !== undefined,
      true,
      `${category} must ask what changed`,
    );
    assertEquals(
      guidance.hardRules !== undefined,
      true,
      `${category} must carry absolute rules`,
    );
    assertStringIncludes(
      promptFor(category),
      "WHAT CHANGED — ANSWER THESE BEFORE YOU DRAW",
    );
    assertStringIncludes(
      promptFor(category),
      `ABSOLUTE RULES FOR ${category.toUpperCase()}`,
    );
  }
});

Deno.test("blush extracts four bounds, not a named region", () => {
  const analysis = CATEGORY_GUIDANCE.blush.analysis!;
  for (
    const question of [
      "Highest visible point",
      "Lowest visible point",
      "Innermost point",
      "Outermost point",
      "Strongest concentration",
      "Fade direction",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(
    analysis,
    "Those four bounds define the footprint. Mark the footprint, not a " +
      "cheek-shaped container drawn around it, and not the path a brush might " +
      "take to produce it.",
  );
  assertStringIncludes(analysis, "Softest fade boundary");
});

Deno.test("blush marks the footprint, never the blending route", () => {
  const landmarks = CATEGORY_GUIDANCE.blush.landmarks;
  assertStringIncludes(landmarks, "Mark the FOOTPRINT, not the ROUTE.");
  assertStringIncludes(
    landmarks,
    "The route is everywhere a brush could plausibly travel while applying it",
  );
  assertStringIncludes(
    landmarks,
    "If the visible blush is high and subtle, the guide is high and small",
  );
  assertStringIncludes(
    promptFor("blush"),
    "a long U-shaped or sweeping path through the mid and lower cheek — that " +
      "is a blending route, not the target",
  );
  assertStringIncludes(
    promptFor("blush"),
    "full mid-cheek coverage, or a generic apple-of-cheek zone",
  );
});

Deno.test("blush keeps the drawing simple however detailed the analysis", () => {
  assertStringIncludes(
    CATEGORY_GUIDANCE.blush.analysis!,
    "The analysis above is detailed; the drawing must not be.",
  );
  assertStringIncludes(
    CATEGORY_GUIDANCE.blush.analysis!,
    "Do not add a mark per question answered.",
  );
});

Deno.test("blush marks a footprint rather than outlining a cheek", () => {
  const landmarks = CATEGORY_GUIDANCE.blush.landmarks;
  assertStringIncludes(
    landmarks,
    "Do not outline a cheek; mark the bounds of the colour you can see.",
  );
  // The device failure was a footprint drawn too low and too broad.
  assertStringIncludes(
    landmarks,
    "must not reach there",
  );
  assertStringIncludes(
    CATEGORY_GUIDANCE.blush.analysis!,
    "This is the bound most often drawn too low.",
  );
});

Deno.test("eyeshadow asks for every zone and the bilateral relationship", () => {
  const analysis = CATEGORY_GUIDANCE.eyeshadow.analysis!;
  for (
    const question of [
      "Lid zone",
      "Crease",
      "Outer corner / outer V",
      "Inner corner",
      "Blend direction",
      "Bilateral relationship",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
  // Neither forced symmetry nor invented asymmetry.
  assertStringIncludes(analysis, "do not force identical geometry");
  assertStringIncludes(analysis, "do not invent an asymmetry that is not there");
});

Deno.test("eyeshadow forbids pigment, darkening, tint, and shimmer", () => {
  const prompt = promptFor("eyeshadow");
  assertStringIncludes(prompt, "ABSOLUTE RULES FOR EYESHADOW");
  for (
    const rule of [
      "DO NOT APPLY EYESHADOW PIGMENT.",
      "DO NOT DARKEN THE EYELID.",
      "DO NOT RECOLOR THE EYELID.",
      "DO NOT TINT THE CREASE.",
      "DO NOT ADD SHIMMER.",
      "DO NOT ADD GLITTER.",
      "DO NOT ADD SMOKY SHADING.",
      "DO NOT PARTIALLY RECREATE THE FINISHED EYE MAKEUP.",
    ]
  ) {
    assertStringIncludes(prompt, rule);
  }
});

Deno.test("eyeliner asks for the full wing geometry, in priority order", () => {
  const analysis = CATEGORY_GUIDANCE.eyeliner.analysis!;
  for (
    const question of [
      "Upper lash-line path",
      "Wing origin",
      "Wing angle",
      "Wing curvature",
      "Wing length",
      "Wing endpoint",
      "Thickness",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(
    analysis,
    "A short subtle flick and a long dramatic wing are different instructions",
  );
  // The wing must outrank everything else, including the lower lash line.
  assertStringIncludes(
    analysis,
    "if the guide gets only one thing right, it must be the wing",
  );
  assertStringIncludes(
    analysis,
    "1. Upper lash-line path",
    "the order is explicit, not implied by prose",
  );
});

Deno.test("eyeliner suppresses lower-eye geometry when unchanged", () => {
  const analysis = CATEGORY_GUIDANCE.eyeliner.analysis!;
  assertStringIncludes(
    analysis,
    "If the lower lash line is unchanged, draw nothing below the eye",
  );
  assertStringIncludes(
    analysis,
    "do not give lower-eye geometry equal weight merely because eyeliner can " +
      "be worn there",
  );
  assertStringIncludes(
    promptFor("eyeliner"),
    "any lower-eye guidance when IMAGE B shows no lower-liner change",
  );
});

Deno.test("eyeliner draws the path, never the liner", () => {
  const prompt = promptFor("eyeliner");
  assertStringIncludes(prompt, "ABSOLUTE RULES FOR EYELINER");
  assertStringIncludes(prompt, "DO NOT APPLY BLACK EYELINER.");
  assertStringIncludes(prompt, "DO NOT DARKEN THE LASH LINE.");
  assertStringIncludes(prompt, "DO NOT FILL THE WING.");
  assertStringIncludes(
    prompt,
    "DRAW ONLY THE INSTRUCTIONAL PATH / BOUNDARY / DIRECTION GUIDE.",
  );
});

Deno.test("lips asks for both borders and treats overline as conditional", () => {
  const analysis = CATEGORY_GUIDANCE.lips.analysis!;
  for (
    const question of [
      "Natural border",
      "Target border",
      "Cupid's bow",
      "Corners",
      "Lower lip",
      "Overline",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(
    analysis,
    "If the two are the same, mark one border, not two.",
  );
  assertStringIncludes(
    analysis,
    "Do not add an overline because a fuller lip would look better.",
  );
});

Deno.test("lips forbids lipstick, gloss, and tint", () => {
  const prompt = promptFor("lips");
  assertStringIncludes(prompt, "ABSOLUTE RULES FOR LIPS");
  for (
    const rule of [
      "DO NOT APPLY LIPSTICK.",
      "DO NOT APPLY LIP GLOSS.",
      "DO NOT ADD LIP TINT.",
      "DO NOT RECOLOR THE LIPS.",
      "DO NOT ENLARGE OR RESHAPE THE PHYSICAL LIPS.",
    ]
  ) {
    assertStringIncludes(prompt, rule);
  }
});

Deno.test("blush forbids flush as well as pigment", () => {
  const prompt = promptFor("blush");
  assertStringIncludes(prompt, "ABSOLUTE RULES FOR BLUSH");
  assertStringIncludes(prompt, "DO NOT ADD PINK PIGMENT.");
  assertStringIncludes(prompt, "DO NOT ADD ROSE PIGMENT.");
  assertStringIncludes(prompt, "DO NOT TINT THE CHEEK.");
  assertStringIncludes(prompt, "DO NOT SIMULATE APPLIED BLUSH.");
});

// ---------------------------------------------------------------------------
// V4-QA-2B — representative prompt precision refinement.
// ---------------------------------------------------------------------------

Deno.test("every prompt separates the two image authorities", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "IMAGE A is the ONLY visual base of your output.");
    // V4-QA-2D: IMAGE B grants geometry, never appearance. The v4_5 wording
    // ("the authority for what the <category> looks like ... and visible
    // intensity") was an appearance grant, and produced makeup under the guides.
    assertStringIncludes(
      prompt,
      `IMAGE B is the authority for WHERE and WHAT SHAPE only: the position, ` +
        `boundary, extent, path, curve, start and end of the ${category}. It ` +
        "is never the authority for how anything should look.",
    );
    assertEquals(
      prompt.includes("what the " + category + " looks like"),
      false,
      "the appearance grant must be gone, not merely counterbalanced",
    );
    assertStringIncludes(
      prompt,
      "You are NOT being asked to produce another beauty image.",
    );
  }
});

// --- V4-QA-2D: strict guideline-only restoration -------------------------

Deno.test("IMAGE B may never be a source of appearance", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(
      prompt,
      "IMAGE B IS A REFERENCE, NEVER A SOURCE OF APPEARANCE",
    );
    assertStringIncludes(
      prompt,
      "Do not copy pixels, colour, shading, texture, glow, gloss, pigment, " +
        "darkness, saturation, or cosmetic finish from IMAGE B onto IMAGE A.",
    );
    assertStringIncludes(
      prompt,
      "Do not blend the two photographs, and do not partially recreate IMAGE B.",
    );
    assertStringIncludes(
      prompt,
      "Read the geometry from IMAGE B. Leave its appearance in IMAGE B.",
    );
  }
});

Deno.test("a guide mark is a line, never a fill", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "GUIDE MARKS ARE LINES, NOT FILLS");
    assertStringIncludes(
      prompt,
      "Instructional colour is allowed. Cosmetic colour is not.",
    );
    assertStringIncludes(
      prompt,
      "Draw the edge of an area, never the area itself.",
    );
    assertStringIncludes(
      prompt,
      "A translucent patch over the cheek, lid, or lips is makeup, not a " +
        "guide, no matter what colour it is.",
    );
    // The v4_5 "semi-transparent" instruction described a cosmetic wash.
    assertEquals(
      prompt.includes("semi-transparent"),
      false,
      "semi-transparent marking invited exactly the wash that failed QA",
    );
  }
});

Deno.test("target intensity informs geometry, it is never rendered", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(
      prompt,
      "TARGET INTENSITY IS INFORMATION, NOT SOMETHING YOU RENDER",
    );
    assertStringIncludes(
      prompt,
      "Strength of target is never expressed as strength of colour.",
    );
  }
});

Deno.test("the negative contract names every cosmetic effect", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    for (
      const clause of [
        "Do NOT apply makeup even partially, even faintly, even as a hint",
        "Do NOT transfer any makeup appearance from IMAGE B.",
        "Do NOT tint or recolour the cheeks or lips",
        "Do NOT darken the lash line, add liner, or fill a wing.",
        "Do NOT add eyeshadow, darken or recolour the eyelid, or tint the crease.",
        "Do NOT add shimmer, glitter, glow, sheen, or brightening",
        "Do NOT add contour shading or bronzed warmth",
        "Do NOT fill, darken, or thicken the eyebrows.",
        "Do NOT apply foundation, even out the complexion, brighten under-eyes",
      ]
    ) {
      assertStringIncludes(prompt, clause);
    }
  }
});

Deno.test("every category carries its own no-makeup ban, not just the gate", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const guidance = CATEGORY_GUIDANCE[category];
    assertEquals(
      guidance.noMakeup.length > 0,
      true,
      `${category} must ban rendering itself`,
    );
    assertStringIncludes(
      promptFor(category),
      `NEVER RENDER ${category.toUpperCase()} ITSELF`,
    );
  }
});

Deno.test("each category ban names that category's own cosmetic effect", () => {
  const expectations: Record<string, string> = {
    foundation: "DO NOT ADD VISIBLE FOUNDATION.",
    concealer: "DO NOT BRIGHTEN UNDER-EYES.",
    contour_bronzer: "DO NOT ADD BROWN SHADING.",
    blush: "DO NOT TINT THE CHEEKS.",
    highlighter: "DO NOT ADD GLOW.",
    eyebrows: "DO NOT FILL BROWS.",
    eyeshadow: "DO NOT APPLY EYESHADOW PIGMENT.",
    eyeliner: "DO NOT APPLY EYELINER.",
    lips: "DO NOT ADD LIPSTICK OR LIP GLOSS.",
  };
  for (const [category, ban] of Object.entries(expectations)) {
    assertStringIncludes(
      promptFor(category as typeof TUTORIAL_CATEGORIES[number]),
      ban,
    );
  }
});

Deno.test("the prompt states the erase-the-marks acceptance test", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "THE TEST YOUR IMAGE MUST PASS");
    assertStringIncludes(
      prompt,
      "Imagine erasing every guide mark you have drawn.",
    );
    assertStringIncludes(
      prompt,
      "If anything cosmetic would still be visible after erasing the marks, " +
        "you have applied makeup, and the image is wrong.",
    );
    // Guideline-only is binary in this phase.
    assertStringIncludes(prompt, "There is no acceptable amount of it.");
  }
});

Deno.test("no instruction tells the model to reproduce the change itself", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(
      prompt,
      "You are not reproducing the change; you are drawing the instructions " +
        "for it.",
    );
    assertStringIncludes(
      prompt,
      "The marks indicate the differences; they never depict them.",
    );
  }
});

Deno.test("every prompt declares its current category explicitly", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    assertStringIncludes(
      promptFor(category),
      `CURRENT CATEGORY = ${category.toUpperCase()}`,
    );
  }
});

Deno.test("convention never outranks the target", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    assertStringIncludes(
      promptFor(category),
      "Where a common makeup convention disagrees with what is visible in " +
        "IMAGE B, follow IMAGE B.",
    );
  }
});

Deno.test("every mark must answer a practical application question", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(
      prompt,
      "where do I start? where does the product go? what boundary do I " +
        "follow? where do I stop? where do I blend or fade? which direction " +
        "do I move?",
    );
    assertStringIncludes(prompt, "If a mark answers none of those, do not draw it.");
  }
});

Deno.test("the guide vocabulary is named and small", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    assertStringIncludes(
      promptFor(category),
      "a dot marks a start or anchor point; a solid line marks a placement " +
        "boundary or path to follow; a dashed line marks a blend or fade " +
        "zone; an arrow marks a direction to move",
    );
  }
});

Deno.test("the negative contract covers beautification and reshaping", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    for (
      const clause of [
        "do NOT partially recreate the final beauty image",
        "Do NOT smooth the skin, retouch it, alter skin tone, or alter skin texture.",
        "Do NOT beautify the face, and do NOT reshape the face, eyes, nose, or mouth.",
        "Do NOT alter the hair, the clothing, the background, or the lighting.",
      ]
    ) {
      assertStringIncludes(prompt, clause);
    }
  }
});

Deno.test("paired features are coherent without forced symmetry", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "PAIRED FEATURES");
    assertStringIncludes(
      prompt,
      "rather than forcing mirrored geometry, and preserve any genuine " +
        "asymmetry visible in IMAGE B",
    );
    assertStringIncludes(
      prompt,
      "Do not correct natural asymmetry, and do not invent one.",
    );
  }
});

Deno.test("every category names a good and a bad result", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "WHAT A GOOD RESULT CONTAINS");
    assertStringIncludes(prompt, "WHAT A BAD RESULT LOOKS LIKE");
  }
  // The gate constant still records which four proved the architecture.
  assertEquals([...REPRESENTATIVE_CATEGORIES], [
    "blush",
    "eyeshadow",
    "eyeliner",
    "lips",
  ]);
});

Deno.test("each representative category names the diagram it must not become", () => {
  assertStringIncludes(
    promptFor("blush"),
    "an oversized generic rectangle or oval covering most of the cheek",
  );
  assertStringIncludes(
    promptFor("eyeshadow"),
    "a generic semicircular eye template",
  );
  assertStringIncludes(promptFor("eyeliner"), "a generic symmetrical cat-eye");
  assertStringIncludes(
    promptFor("lips"),
    "a generic diamond or textbook lip diagram",
  );
});

Deno.test("blush refuses every default placement equally", () => {
  const analysis = CATEGORY_GUIDANCE.blush.analysis!;
  for (const question of ["Lift", "Centre cheek"]) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(
    analysis,
    "Do not assume apple-of-cheek, lifted, temple-swept, horizontal, or nose " +
      "placement",
  );
});

Deno.test("eyeshadow will not draw a crease that is not there", () => {
  const analysis = CATEGORY_GUIDANCE.eyeshadow.analysis!;
  assertStringIncludes(analysis, "If not, do not draw a crease line.");
  for (
    const question of [
      "Crease height",
      "Upper transition",
      "Lower lash line",
      "Intensity structure",
      "Softest edge",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
});

Deno.test("eyeshadow separates where colour is from where it is heaviest", () => {
  const landmarks = CATEGORY_GUIDANCE.eyeshadow.landmarks;
  assertStringIncludes(
    landmarks,
    "Separate two different things: where eyeshadow exists at all, and where " +
      "it is most intense.",
  );
  assertStringIncludes(landmarks, "one even zone would misrepresent it");
  assertStringIncludes(
    CATEGORY_GUIDANCE.eyeshadow.analysis!,
    "the single most important thing your marking must communicate",
  );
  // Weighting is shown through boundary placement, never by shading.
  assertStringIncludes(
    CATEGORY_GUIDANCE.eyeshadow.analysis!,
    "never by shading anything",
  );
});

Deno.test("eyeliner will not draw a wing that is not there", () => {
  const analysis = CATEGORY_GUIDANCE.eyeliner.analysis!;
  assertStringIncludes(analysis, "If there is no wing in IMAGE B, do not draw one.");
  for (const question of ["Inner line", "Bilateral relationship"]) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(
    CATEGORY_GUIDANCE.eyeliner.landmarks,
    "If IMAGE B shows no wing, do not draw one.",
  );
});

Deno.test("lips distinguishes overlining from underlining", () => {
  const analysis = CATEGORY_GUIDANCE.lips.analysis!;
  for (
    const question of [
      "Upper-lip peaks",
      "Centre dip",
      "Corner extension",
      "Underline",
      "Fullness",
    ]
  ) {
    assertStringIncludes(analysis, question);
  }
  assertStringIncludes(analysis, "Do not output a generic lip-outline diagram");
});

Deno.test("lips targets IMAGE B's border, not IMAGE A's anatomy", () => {
  const landmarks = CATEGORY_GUIDANCE.lips.landmarks;
  // The v4_4 fragment listed the natural border first and unconditionally,
  // which is what produced the traced-anatomy failure on device.
  assertStringIncludes(
    landmarks,
    "The target is the lip shape in IMAGE B, not the lip anatomy in IMAGE A.",
  );
  assertStringIncludes(
    landmarks,
    "Use the natural border from IMAGE A only where it differs from the target",
  );
  assertStringIncludes(
    landmarks,
    "Do not simply trace the lips that are already there.",
  );
  assertStringIncludes(
    CATEGORY_GUIDANCE.lips.analysis!,
    "where would the user need to draw outside, inside, or along the natural " +
      "lip boundary to reproduce IMAGE B?",
  );
  assertStringIncludes(
    promptFor("lips"),
    "a trace of the natural lip outline when the target border differs from it",
  );
});

// --- shared V4-QA-2C contracts ------------------------------------------

Deno.test("every prompt compares before it draws", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "WORK IN THIS ORDER");
    assertStringIncludes(
      prompt,
      `6. Discard every convention about ${category} that IMAGE B does not ` +
        "visibly support, however standard it is.",
    );
    assertStringIncludes(
      prompt,
      "Do not go straight from knowing the category to drawing a familiar " +
        "diagram for it.",
    );
  }
});

Deno.test("every prompt extracts bounds rather than naming a region", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "FIND THE TARGET'S BOUNDS");
    assertStringIncludes(
      prompt,
      "its highest visible point; its lowest; its innermost; its outermost",
    );
    assertStringIncludes(
      prompt,
      "Marking a named region is what produces a generic result",
    );
  }
});

Deno.test("the generic description is demoted to orientation", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "THAT DESCRIPTION IS ORIENTATION, NOT INSTRUCTION");
    assertStringIncludes(prompt, "It does not tell you what to draw.");
    assertStringIncludes(
      prompt,
      "it may never supply a mark on its own",
    );
  }
});

Deno.test("every prompt marks the difference, not the anatomy", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "MARK THE DIFFERENCE, NOT THE ANATOMY");
    assertStringIncludes(
      prompt,
      "The user does not need a diagram of their own face.",
    );
    assertStringIncludes(
      prompt,
      "Where IMAGE A already matches IMAGE B, little or no guidance is needed",
    );
  }
});

Deno.test("every mark must be justified by visible evidence", () => {
  for (const category of TUTORIAL_CATEGORIES) {
    const prompt = promptFor(category);
    assertStringIncludes(prompt, "CHECK EVERY MARK BEFORE YOU DRAW IT");
    assertStringIncludes(
      prompt,
      'This mark exists because IMAGE B shows ______ compared with IMAGE A.',
    );
    assertStringIncludes(
      prompt,
      'If the blank can only be filled with "this is where this product ' +
        'usually goes", do not draw the mark.',
    );
    // Fidelity must not be bought with clutter.
    assertStringIncludes(
      prompt,
      "Being more faithful does not mean drawing more.",
    );
    assertStringIncludes(prompt, "choose the truthful one");
  }
});

Deno.test("the evidence check is the last thing before generating", () => {
  const prompt = promptFor("blush");
  const check = prompt.indexOf("CHECK EVERY MARK BEFORE YOU DRAW IT");
  const preserve = prompt.indexOf("PRESERVE THE PHOTOGRAPH");
  const ret = prompt.indexOf("Return exactly one edited image.");
  assertEquals(check > preserve, true, "the gate sits after the body");
  assertEquals(check < ret, true, "and immediately before generation");
});

Deno.test("the five propagated categories do target extraction too", () => {
  // Replaces the V4-QA-2 test that locked these five verbatim. That lock was
  // correct while the architecture was unproven; V4-QA-3 is the phase
  // authorised to move them, so the contract is now what they must say.
  const expectations: Record<string, string> = {
    foundation: "Compare the complexion in IMAGE A against IMAGE B",
    concealer: "Compare IMAGE A and IMAGE B and mark only the discrete areas",
    contour_bronzer:
      "Compare IMAGE A and IMAGE B and mark only the regions that were",
    highlighter:
      "Compare IMAGE A and IMAGE B and outline only the small areas that",
    eyebrows: "Compare the brows in IMAGE A and IMAGE B and mark only what",
  };
  for (const [category, opening] of Object.entries(expectations)) {
    assertStringIncludes(
      CATEGORY_GUIDANCE[category as typeof TUTORIAL_CATEGORIES[number]]
        .landmarks,
      opening,
    );
  }
});

Deno.test("each propagated category names the diagram it must not become", () => {
  const expectations: Record<string, string> = {
    foundation: "a full-face perimeter drawn by default",
    concealer: "the standard under-eye triangle drawn from habit",
    contour_bronzer: "the standard three-shape contour map drawn as a set",
    highlighter: "the classic five-point map marked as a set",
    eyebrows: "the three-line brow mapping, or any line projected from the nose",
  };
  for (const [category, diagram] of Object.entries(expectations)) {
    assertStringIncludes(
      promptFor(category as typeof TUTORIAL_CATEGORIES[number]),
      diagram,
    );
  }
});

Deno.test("each propagated category has a conditional gate on its default", () => {
  const gates: Record<string, string> = {
    foundation:
      "DO NOT OUTLINE THE WHOLE FACE UNLESS IMAGE B SHOWS COVERAGE ACROSS ALL OF IT.",
    concealer:
      "DO NOT DRAW AN UNDER-EYE TRIANGLE UNLESS IMAGE B IS VISIBLY BRIGHTER THERE.",
    contour_bronzer:
      "DO NOT DRAW THE STANDARD CONTOUR MAP. MARK ONLY BANDS YOU CAN SEE.",
    highlighter:
      "DO NOT DRAW THE CLASSIC FIVE-POINT HIGHLIGHT MAP. MARK ONLY POINTS YOU CAN SEE.",
    eyebrows:
      "DO NOT DRAW BROW CONSTRUCTION GEOMETRY — NO MAPPING LINES FROM THE NOSE, NO CROSS-HAIRS.",
  };
  for (const [category, gate] of Object.entries(gates)) {
    assertStringIncludes(
      promptFor(category as typeof TUTORIAL_CATEGORIES[number]),
      gate,
    );
  }
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
