import {
  type DraftOmission,
  type DraftPlan,
  type DraftSelection,
  INTENSITIES,
  type Intensity,
} from "../_shared/kit_makeup_plan.ts";
import { FunctionFailure } from "./types.ts";

const selectionKeys = [
  "productId",
  "category",
  "role",
  "placement",
  "technique",
  "intensity",
  "reasoning",
];
const rootKeys = [
  "selections",
  "complexionOmissions",
  "overallIntensity",
  "summary",
];

function invalid(code = "invalid_ai_response"): FunctionFailure {
  return new FunctionFailure(
    502,
    code,
    "The kit recommendation service returned an invalid plan.",
    true,
  );
}

function record(value: unknown, keys: string[]): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalid();
  }
  const input = value as Record<string, unknown>;
  const actual = Object.keys(input);
  if (
    actual.length !== keys.length || actual.some((key) => !keys.includes(key))
  ) throw invalid();
  return input;
}

function text(input: Record<string, unknown>, key: string, max: number) {
  const value = input[key];
  if (
    typeof value !== "string" || value.trim().length < 2 || value.length > max
  ) throw invalid();
  return value.trim();
}

function intensity(value: unknown): Intensity {
  if (
    typeof value !== "string" ||
    !(INTENSITIES as readonly string[]).includes(value)
  ) throw invalid();
  return value as Intensity;
}

/**
 * Shape-checks the model's v3 answer into a [DraftPlan].
 *
 * Only structure is checked here: exact keys, types, lengths, enums of the
 * scalar fields. Whether the choices are allowed — ownership, roles, limits,
 * complexion decisions — is decided by the shared plan builder, so the rules
 * live in one place.
 */
export function parseKitRecommendationV3Draft(value: string): DraftPlan {
  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch {
    throw new FunctionFailure(
      502,
      "malformed_ai_json",
      "The kit recommendation service returned malformed data.",
      true,
    );
  }
  const root = record(decoded, rootKeys);
  if (!Array.isArray(root.selections) || root.selections.length < 1) {
    throw invalid();
  }
  if (!Array.isArray(root.complexionOmissions)) throw invalid();
  const selections: DraftSelection[] = root.selections.map((entry) => {
    const input = record(entry, selectionKeys);
    return {
      productId: text(input, "productId", 50),
      category: text(input, "category", 40),
      role: text(input, "role", 40),
      placement: text(input, "placement", 220),
      technique: text(input, "technique", 220),
      intensity: intensity(input.intensity),
      reasoning: text(input, "reasoning", 240),
    };
  });
  const complexionOmissions: DraftOmission[] = root.complexionOmissions.map(
    (entry) => {
      const input = record(entry, ["category", "reason"]);
      return {
        category: text(input, "category", 40),
        reason: text(input, "reason", 40),
      };
    },
  );
  return {
    selections,
    complexionOmissions,
    overallIntensity: intensity(root.overallIntensity),
    summary: text(root, "summary", 300),
  };
}
