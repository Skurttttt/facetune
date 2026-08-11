import type {
  RecommendationItem,
  RecommendationPlan,
} from "./types.ts";
import { FunctionFailure } from "./types.ts";

const categories = [
  "foundation",
  "concealer",
  "contour",
  "highlight",
  "blush",
  "eyeshadow",
  "eyebrow",
  "eyeliner",
  "lipstick",
  "lipGloss",
] as const;
const intensities = new Set(["sheer", "soft", "medium", "bold"]);
const hexPattern = /^#[0-9A-F]{6}$/;
const allowedItemKeys = new Set([
  "name",
  "hex",
  "placement",
  "technique",
  "finish",
  "intensity",
  "reasoning",
]);

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalidResponse();
  }
  return value as Record<string, unknown>;
}

function invalidResponse(): FunctionFailure {
  return new FunctionFailure(
    502,
    "invalid_ai_response",
    "The recommendation service returned invalid data.",
    true,
  );
}

function text(
  input: Record<string, unknown>,
  key: string,
  maximum: number,
): string {
  const value = input[key];
  if (
    typeof value !== "string" || value.trim().length < 2 ||
    value.length > maximum
  ) throw invalidResponse();
  return value.trim();
}

function item(value: unknown): RecommendationItem {
  const input = record(value);
  if (
    Object.keys(input).length !== allowedItemKeys.size ||
    Object.keys(input).some((key) => !allowedItemKeys.has(key))
  ) throw invalidResponse();
  const hex = input.hex;
  if (hex !== null && (typeof hex !== "string" || !hexPattern.test(hex))) {
    throw invalidResponse();
  }
  const intensity = input.intensity;
  if (typeof intensity !== "string" || !intensities.has(intensity)) {
    throw invalidResponse();
  }
  return {
    name: text(input, "name", 80),
    hex,
    placement: text(input, "placement", 220),
    technique: text(input, "technique", 220),
    finish: text(input, "finish", 80),
    intensity,
    reasoning: text(input, "reasoning", 240),
  };
}

export function parseAndValidateRecommendation(textValue: string): RecommendationPlan {
  let decoded: unknown;
  try {
    decoded = JSON.parse(textValue);
  } catch {
    throw new FunctionFailure(
      502,
      "malformed_ai_json",
      "The recommendation service returned malformed data.",
      true,
    );
  }
  const input = record(decoded);
  const expectedKeys = new Set([...categories, "overallIntensity"]);
  if (
    Object.keys(input).length !== expectedKeys.size ||
    Object.keys(input).some((key) => !expectedKeys.has(key))
  ) throw invalidResponse();
  const overallIntensity = input.overallIntensity;
  if (
    typeof overallIntensity !== "string" ||
    !intensities.has(overallIntensity)
  ) throw invalidResponse();
  return {
    foundation: item(input.foundation),
    concealer: item(input.concealer),
    contour: item(input.contour),
    highlight: item(input.highlight),
    blush: item(input.blush),
    eyeshadow: item(input.eyeshadow),
    eyebrow: item(input.eyebrow),
    eyeliner: item(input.eyeliner),
    lipstick: item(input.lipstick),
    lipGloss: item(input.lipGloss),
    overallIntensity,
  };
}
