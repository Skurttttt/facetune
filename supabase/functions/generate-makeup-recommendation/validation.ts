import type {
  RecommendationEducation,
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
  "education",
]);
const allowedEducationKeys = new Set(["features", "effect", "style"]);

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

/** The three education strings, validated exactly as strictly as every other
 * generated field.
 *
 * Strict rather than tolerant on purpose. This parses a *fresh* v3 response, so
 * a missing or malformed education object means the model did not honour the
 * schema — the same class of failure as a malformed HEX, and treated the same
 * way. Historical rows that predate education are a different problem, handled
 * where they are actually read: the Flutter DTO decodes education as optional,
 * so a stored v2 plan still opens.
 *
 * The 240-character ceiling matches `reasoning` and the JSON schema. Enforcing
 * it here as well means a model that ignores the schema cannot quietly inflate
 * one response past the output-token budget.
 */
function education(value: unknown): RecommendationEducation {
  const input = record(value);
  if (
    Object.keys(input).length !== allowedEducationKeys.size ||
    Object.keys(input).some((key) => !allowedEducationKeys.has(key))
  ) throw invalidResponse();
  return {
    features: text(input, "features", 240),
    effect: text(input, "effect", 240),
    style: text(input, "style", 240),
  };
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
    education: education(input.education),
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
