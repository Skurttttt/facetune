import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  tutorialFaceAttributesFromRow,
  tutorialGeometryPlanPrompt,
  TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION,
} from "./prompt.ts";

Deno.test("tutorialFaceAttributesFromRow reads snake_case analyses columns only", () => {
  const attributes = tutorialFaceAttributesFromRow({
    face_shape: "round",
    skin_tone: "medium",
    undertone: "warm",
    eye_shape: "hooded",
    lip_shape: "full",
    hair_color: "dark brown",
    eye_color: "brown",
  });
  assertEquals(attributes.faceShape, "round");
  assertEquals(attributes.eyeShape, "hooded");
});

Deno.test("tutorialFaceAttributesFromRow never fabricates a missing attribute", () => {
  const attributes = tutorialFaceAttributesFromRow({ face_shape: "oval" });
  assertEquals(attributes.faceShape, "oval");
  assertEquals(attributes.skinTone, undefined);
  assertEquals(attributes.undertone, undefined);
});

Deno.test("builds the versioned prompt with per-category product facts", () => {
  const prompt = tutorialGeometryPlanPrompt({
    selectedStyle: "Korean",
    sourceMode: "standard_recommendation",
    faceAttributes: {
      faceShape: "round",
      skinTone: "medium",
      undertone: "warm",
    },
    categories: [
      {
        category: "blush",
        label: "Blush",
        colorName: "Warm Peach",
        colorHex: "#E58C87",
        finish: "satin",
        placement: "Upper cheekbones",
        technique: "Blend upward.",
        intensity: "light",
      },
    ],
  });

  assertEquals(
    TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION,
    "tutorial_geometry_plan_v1",
  );
  for (
    const expected of [
      "Selected style: Korean",
      "Face shape: round",
      'category="blush"',
      "Color: Warm Peach",
      "HEX: #E58C87",
      "EXACTLY one plan entry per category",
      "never fabricate placeholder coordinates",
    ]
  ) {
    assertStringIncludes(prompt, expected);
  }
});

Deno.test("includes the kit-mode strict rule only for makeup_kit sessions", () => {
  const kitPrompt = tutorialGeometryPlanPrompt({
    sourceMode: "makeup_kit",
    faceAttributes: {},
    categories: [{ category: "lipstick", label: "Lipstick" }],
  });
  assertStringIncludes(kitPrompt, "KIT MODE -- STRICT");

  const standardPrompt = tutorialGeometryPlanPrompt({
    sourceMode: "standard_recommendation",
    faceAttributes: {},
    categories: [{ category: "lipstick", label: "Lipstick" }],
  });
  assertEquals(standardPrompt.includes("KIT MODE -- STRICT"), false);
});
