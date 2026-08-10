import type {
  AttributePayload,
  ConfidencePayload,
  ValidatedGeminiResult,
  ValidationPayload,
} from "./types.ts";
import { FunctionFailure } from "./types.ts";

const allowed = {
  faceShape: new Set([
    "oval",
    "round",
    "square",
    "heart",
    "oblong",
    "diamond",
    "triangle",
  ]),
  skinTone: new Set([
    "very_light",
    "light",
    "medium",
    "tan",
    "deep",
    "very_deep",
  ]),
  undertone: new Set(["warm", "cool", "neutral", "olive"]),
  eyeShape: new Set([
    "almond",
    "round",
    "hooded",
    "monolid",
    "upturned",
    "downturned",
    "deep_set",
    "protruding",
  ]),
  lipShape: new Set([
    "thin",
    "medium",
    "full",
    "heart_shaped",
    "wide",
    "round",
  ]),
  hairColor: new Set([
    "black",
    "dark_brown",
    "brown",
    "light_brown",
    "blonde",
    "red",
    "gray",
    "white",
    "other",
  ]),
  eyeColor: new Set([
    "dark_brown",
    "brown",
    "hazel",
    "amber",
    "green",
    "blue",
    "gray",
    "other",
  ]),
} satisfies Record<keyof AttributePayload, Set<string>>;

const attributeKeys = Object.keys(allowed) as (keyof AttributePayload)[];
const minimumConfidence = 0.45;

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      "The analysis service returned an invalid response.",
    );
  }
  return value as Record<string, unknown>;
}

function validationPayload(value: unknown): ValidationPayload {
  const input = record(value);
  const faceCount = input.faceCount;
  if (
    !Number.isInteger(faceCount) || (faceCount as number) < 0 ||
    (faceCount as number) > 10
  ) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      "The analysis service returned invalid validation data.",
    );
  }
  for (
    const key of [
      "lightingAcceptable",
      "sharpnessAcceptable",
      "faceVisible",
      "framingAcceptable",
    ] as const
  ) {
    if (typeof input[key] !== "boolean") {
      throw new FunctionFailure(
        502,
        "invalid_ai_response",
        "The analysis service returned incomplete validation data.",
      );
    }
  }
  return input as ValidationPayload;
}

function validationFailure(
  validation: ValidationPayload,
): FunctionFailure | null {
  if (validation.faceCount === 0) {
    return new FunctionFailure(
      422,
      "no_face",
      "No visible face was found. Choose a clear selfie.",
    );
  }
  if (validation.faceCount > 1) {
    return new FunctionFailure(
      422,
      "multiple_faces",
      "More than one face was found. Choose a selfie with one person.",
    );
  }
  if (!validation.faceVisible) {
    return new FunctionFailure(
      422,
      "face_obscured",
      "Your face is too obscured for analysis. Choose a clearer selfie.",
    );
  }
  if (!validation.lightingAcceptable) {
    return new FunctionFailure(
      422,
      "insufficient_lighting",
      "The lighting is too dark or uneven. Choose a brighter selfie.",
    );
  }
  if (!validation.sharpnessAcceptable) {
    return new FunctionFailure(
      422,
      "excessive_blur",
      "The selfie is too blurry for analysis. Choose a sharper photo.",
    );
  }
  if (!validation.framingAcceptable) {
    return new FunctionFailure(
      422,
      "poor_framing",
      "Center your full face in the frame and try again.",
    );
  }
  return null;
}

export function parseAndValidateGeminiText(
  text: string,
): ValidatedGeminiResult {
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new FunctionFailure(
      502,
      "malformed_ai_json",
      "The analysis service returned malformed data.",
    );
  }
  const root = record(decoded);
  if (typeof root.imageValid !== "boolean") {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      "The analysis service returned incomplete data.",
    );
  }
  const validation = validationPayload(root.validation);
  const suitabilityFailure = validationFailure(validation);
  if (suitabilityFailure) throw suitabilityFailure;
  if (root.imageValid !== true) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      "The image validation result was inconsistent.",
    );
  }

  const analysisInput = record(root.analysis);
  const confidenceInput = record(root.confidence);
  const analysis = {} as AttributePayload;
  const confidence = {} as ConfidencePayload;
  for (const key of attributeKeys) {
    const value = analysisInput[key];
    if (typeof value !== "string" || !allowed[key].has(value)) {
      throw new FunctionFailure(
        502,
        "unsupported_ai_value",
        "The analysis service returned an unsupported attribute.",
      );
    }
    const score = confidenceInput[key];
    if (
      typeof score !== "number" || !Number.isFinite(score) || score < 0 ||
      score > 1
    ) {
      throw new FunctionFailure(
        502,
        "invalid_confidence",
        "The analysis service returned invalid confidence values.",
      );
    }
    if (score < minimumConfidence) {
      throw new FunctionFailure(
        422,
        "low_confidence",
        "The selfie is not clear enough for a reliable analysis. Try another photo.",
      );
    }
    analysis[key] = value;
    confidence[key] = score;
  }
  return { imageValid: true, validation, analysis, confidence };
}
