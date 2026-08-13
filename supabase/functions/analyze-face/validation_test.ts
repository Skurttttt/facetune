import { FunctionFailure } from "./types.ts";
import { parseAndValidateGeminiText } from "./validation.ts";

const validPayload = {
  imageValid: true,
  validation: {
    faceCount: 1,
    lightingAcceptable: true,
    sharpnessAcceptable: true,
    faceVisible: true,
    framingAcceptable: true,
  },
  analysis: {
    faceShape: "oval",
    skinTone: "medium",
    undertone: "warm",
    eyeShape: "almond",
    lipShape: "full",
    hairColor: "dark_brown",
    eyeColor: "brown",
  },
  confidence: {
    faceShape: 0.91,
    skinTone: 0.88,
    undertone: 0.82,
    eyeShape: 0.9,
    lipShape: 0.87,
    hairColor: 0.94,
    eyeColor: 0.89,
  },
};

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

function expectFailure(payload: unknown, code: string) {
  try {
    parseAndValidateGeminiText(
      typeof payload === "string" ? payload : JSON.stringify(payload),
    );
    throw new Error(`Expected ${code}`);
  } catch (error) {
    assert(error instanceof FunctionFailure, "Expected FunctionFailure");
    assert(error.code === code, `Expected ${code}, received ${error.code}`);
  }
}

Deno.test("accepts a valid structured selfie analysis", () => {
  const result = parseAndValidateGeminiText(JSON.stringify(validPayload));
  assert(result.analysis.faceShape === "oval", "Expected oval face shape");
});

Deno.test("rejects a no-face image", () => {
  expectFailure({
    ...validPayload,
    imageValid: false,
    validation: { ...validPayload.validation, faceCount: 0 },
    analysis: null,
    confidence: null,
  }, "no_face");
});

Deno.test("rejects a multiple-face image", () => {
  expectFailure({
    ...validPayload,
    imageValid: false,
    validation: { ...validPayload.validation, faceCount: 2 },
    analysis: null,
    confidence: null,
  }, "multiple_faces");
});

Deno.test("rejects malformed Gemini JSON", () => {
  expectFailure("{not-json", "malformed_ai_json");
});

Deno.test("rejects an unsupported enum value", () => {
  expectFailure({
    ...validPayload,
    analysis: { ...validPayload.analysis, faceShape: "hexagon" },
  }, "unsupported_ai_value");
});

Deno.test("rejects a low-confidence response", () => {
  expectFailure({
    ...validPayload,
    confidence: { ...validPayload.confidence, undertone: 0.2 },
  }, "low_confidence");
});

Deno.test("rejects a weak reading of a shade-matching attribute", () => {
  // Skin tone, undertone, and face shape drive shade matching and placement, so
  // a weak reading there makes the whole plan unreliable.
  for (const key of ["skinTone", "undertone", "faceShape"] as const) {
    expectFailure({
      ...validPayload,
      confidence: { ...validPayload.confidence, [key]: 0.4 },
    }, "low_confidence");
  }
});

Deno.test("accepts an occluded secondary attribute", () => {
  // Eyewear, hair, or crop routinely obscure one refinement attribute. That
  // used to fail the whole scan even when shade matching was confident.
  for (
    const key of ["eyeColor", "eyeShape", "hairColor", "lipShape"] as const
  ) {
    const result = parseAndValidateGeminiText(
      JSON.stringify({
        ...validPayload,
        confidence: { ...validPayload.confidence, [key]: 0.3 },
      }),
    );
    assert(
      result.confidence[key] === 0.3,
      `Expected the low ${key} confidence to be reported honestly`,
    );
  }
});

Deno.test("still rejects a secondary attribute that is a guess", () => {
  expectFailure({
    ...validPayload,
    confidence: { ...validPayload.confidence, eyeColor: 0.1 },
  }, "low_confidence");
});
