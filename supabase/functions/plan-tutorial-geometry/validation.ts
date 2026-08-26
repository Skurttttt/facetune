import {
  CANONICAL_TUTORIAL_CATEGORIES,
  TUTORIAL_DIRECTION_VALUES,
  TUTORIAL_INTENSITY_VALUES,
} from "./schema.ts";
import type {
  CategoryGeometryPlan,
  CategoryProductFacts,
  GeometryArrow,
  GeometryPath,
  GeometryPlan,
  GeometryPoint,
  GeometryZone,
} from "./types.ts";
import { FunctionFailure } from "./types.ts";

const categorySet = new Set<string>(CANONICAL_TUTORIAL_CATEGORIES);
const directionSet = new Set<string>(TUTORIAL_DIRECTION_VALUES);
const intensitySet = new Set<string>(TUTORIAL_INTENSITY_VALUES);
const zoneShapeSet = new Set(["ellipse", "polygon", "soft_band", "region"]);
// Case-insensitive: Gemini's schema does not constrain casing, so this only
// rejects a genuinely malformed hex, never a correct value in the "wrong"
// case. The real equality check against the already-persisted color is
// itself case-insensitive too (see validateNoProductInvention below).
const hexPattern = /^#[0-9A-Fa-f]{6}$/;

function record(value: unknown, name: string): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      `The geometry planning service returned an invalid ${name}.`,
    );
  }
  return value as Record<string, unknown>;
}

function array(value: unknown, name: string): unknown[] {
  if (!Array.isArray(value)) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      `The geometry planning service returned an invalid ${name}.`,
    );
  }
  return value;
}

function requiredString(
  data: Record<string, unknown>,
  key: string,
  code = "invalid_ai_response",
): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new FunctionFailure(
      502,
      code,
      `The geometry planning service returned an invalid "${key}".`,
    );
  }
  return value;
}

function optionalString(data: Record<string, unknown>, key: string): string | null {
  const value = data[key];
  if (value === null || value === undefined) return null;
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      `The geometry planning service returned an invalid "${key}".`,
    );
  }
  return value;
}

function confidence(data: Record<string, unknown>, context: string): number {
  const value = data.confidence;
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0 || value > 1) {
    throw new FunctionFailure(
      502,
      "INVALID_CONFIDENCE",
      `${context} has an invalid confidence value.`,
    );
  }
  return value;
}

function point(value: unknown, context: string): GeometryPoint {
  const data = record(value, `${context} point`);
  const x = data.x;
  const y = data.y;
  if (
    typeof x !== "number" || !Number.isFinite(x) || x < 0 || x > 1 ||
    typeof y !== "number" || !Number.isFinite(y) || y < 0 || y > 1
  ) {
    throw new FunctionFailure(
      502,
      "INVALID_GEOMETRY_BOUNDS",
      `${context} has a coordinate outside the normalized 0.0-1.0 range.`,
    );
  }
  return { x, y };
}

function zone(value: unknown, context: string): GeometryZone {
  const data = record(value, `${context} zone`);
  const shape = data.shape;
  if (typeof shape !== "string" || !zoneShapeSet.has(shape)) {
    throw new FunctionFailure(
      502,
      "invalid_ai_response",
      `${context} has an unsupported zone shape.`,
    );
  }
  const points = array(data.points, `${context} zone points`).map((entry) =>
    point(entry, `${context} zone`)
  );
  if (points.length === 0) {
    throw new FunctionFailure(
      502,
      "INVALID_GEOMETRY_BOUNDS",
      `${context} has a zone with no points.`,
    );
  }
  return {
    shape: shape as GeometryZone["shape"],
    points,
    confidence: confidence(data, `${context} zone`),
  };
}

function path(value: unknown, context: string): GeometryPath {
  const data = record(value, `${context} path`);
  const points = array(data.points, `${context} path points`).map((entry) =>
    point(entry, `${context} path`)
  );
  if (points.length < 2) {
    throw new FunctionFailure(
      502,
      "INVALID_GEOMETRY_BOUNDS",
      `${context} has a path with fewer than two points.`,
    );
  }
  return { points, confidence: confidence(data, `${context} path`) };
}

function arrow(value: unknown, context: string): GeometryArrow {
  const data = record(value, `${context} arrow`);
  return {
    from: point(data.from, `${context} arrow`),
    to: point(data.to, `${context} arrow`),
    confidence: confidence(data, `${context} arrow`),
  };
}

function validateNoProductInvention(
  categoryStep: CategoryGeometryPlan,
  facts: CategoryProductFacts,
): void {
  if (categoryStep.colorHex !== null) {
    if (!hexPattern.test(categoryStep.colorHex)) {
      throw new FunctionFailure(
        502,
        "invalid_ai_response",
        `${categoryStep.category} returned a malformed colorHex.`,
      );
    }
    if (
      facts.colorHex === undefined ||
      facts.colorHex.toUpperCase() !== categoryStep.colorHex.toUpperCase()
    ) {
      throw new FunctionFailure(
        502,
        "PRODUCT_INVENTION_DETECTED",
        `${categoryStep.category} returned a color that was never provided to it.`,
      );
    }
  }
  if (categoryStep.finish !== null) {
    if (
      facts.finish === undefined ||
      facts.finish.toLowerCase() !== categoryStep.finish.toLowerCase()
    ) {
      throw new FunctionFailure(
        502,
        "PRODUCT_INVENTION_DETECTED",
        `${categoryStep.category} returned a finish that was never provided to it.`,
      );
    }
  }
}

function validateKitIntegrity(
  categoryStep: CategoryGeometryPlan,
  facts: CategoryProductFacts,
  sourceMode: string,
): void {
  if (sourceMode !== "makeup_kit") return;
  if (!facts.kitProductId || facts.kitProductId.trim().length === 0) {
    throw new FunctionFailure(
      502,
      "KIT_INTEGRITY_VIOLATION",
      `${categoryStep.category} has no owned kit product backing it.`,
    );
  }
}

function categoryPlan(
  value: unknown,
  facts: CategoryProductFacts,
  sourceMode: string,
): CategoryGeometryPlan {
  const data = record(value, "geometry plan step");
  const category = requiredString(data, "category");
  if (!categorySet.has(category)) {
    throw new FunctionFailure(
      502,
      "unsupported_ai_value",
      `The geometry planning service returned an unsupported category "${category}".`,
    );
  }
  if (category !== facts.category) {
    throw new FunctionFailure(
      502,
      "CATEGORY_COVERAGE_MISMATCH",
      `The geometry plan returned "${category}" where "${facts.category}" was requested.`,
    );
  }
  const direction = requiredString(data, "direction");
  if (!directionSet.has(direction)) {
    throw new FunctionFailure(
      502,
      "unsupported_ai_value",
      `${category} returned an unsupported direction.`,
    );
  }
  const intensity = requiredString(data, "intensity");
  if (!intensitySet.has(intensity)) {
    throw new FunctionFailure(
      502,
      "unsupported_ai_value",
      `${category} returned an unsupported intensity.`,
    );
  }
  const zones = array(data.zones, `${category} zones`).map((entry) =>
    zone(entry, category)
  );
  const paths = array(data.paths, `${category} paths`).map((entry) =>
    path(entry, category)
  );
  const arrows = array(data.arrows, `${category} arrows`).map((entry) =>
    arrow(entry, category)
  );
  if (zones.length === 0 && paths.length === 0 && arrows.length === 0) {
    throw new FunctionFailure(
      502,
      "INVALID_GEOMETRY_BOUNDS",
      `${category} has no geometry primitives at all.`,
    );
  }
  const plan: CategoryGeometryPlan = {
    category,
    placement: requiredString(data, "placement"),
    direction,
    intensity,
    technique: requiredString(data, "technique"),
    confidence: confidence(data, category),
    colorHex: optionalString(data, "colorHex"),
    finish: optionalString(data, "finish"),
    zones,
    paths,
    arrows,
  };
  validateNoProductInvention(plan, facts);
  validateKitIntegrity(plan, facts, sourceMode);
  return plan;
}

/**
 * Parses and strictly re-validates Gemini's structured JSON response,
 * independent of `responseJsonSchema` already having constrained it
 * upstream -- the same defense-in-depth posture `analyze-face/validation.ts`
 * already takes for face attributes.
 *
 * Rejects the ENTIRE plan (no partial acceptance) on any malformed,
 * out-of-range, category-mismatched, or product-inventing entry. Never
 * fabricates a fallback value for a rejected field.
 */
export function parseAndValidateGeometryPlan(
  text: string,
  params: {
    /** The session's own ordered, deduplicated category list -- exactly
     * what the plan must cover, no more, no fewer. */
    requestedCategories: CategoryProductFacts[];
    sourceMode: string;
  },
): GeometryPlan {
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new FunctionFailure(
      502,
      "malformed_ai_json",
      "The geometry planning service returned malformed data.",
    );
  }
  const root = record(decoded, "geometry plan");
  const rawSteps = array(root.steps, "geometry plan steps");

  const { requestedCategories, sourceMode } = params;
  if (rawSteps.length !== requestedCategories.length) {
    throw new FunctionFailure(
      502,
      "CATEGORY_COVERAGE_MISMATCH",
      "The geometry plan did not cover exactly the requested categories.",
    );
  }
  const factsByCategory = new Map(
    requestedCategories.map((facts) => [facts.category, facts]),
  );
  const seenCategories = new Set<string>();
  const steps: CategoryGeometryPlan[] = [];
  for (const rawStep of rawSteps) {
    const stepData = record(rawStep, "geometry plan step");
    const category = requiredString(stepData, "category");
    const facts = factsByCategory.get(category);
    if (!facts) {
      throw new FunctionFailure(
        502,
        "CATEGORY_COVERAGE_MISMATCH",
        `The geometry plan returned an unrequested category "${category}".`,
      );
    }
    if (seenCategories.has(category)) {
      throw new FunctionFailure(
        502,
        "CATEGORY_COVERAGE_MISMATCH",
        `The geometry plan returned "${category}" more than once.`,
      );
    }
    seenCategories.add(category);
    steps.push(categoryPlan(rawStep, facts, sourceMode));
  }
  if (seenCategories.size !== requestedCategories.length) {
    throw new FunctionFailure(
      502,
      "CATEGORY_COVERAGE_MISMATCH",
      "The geometry plan is missing one or more requested categories.",
    );
  }
  return { steps };
}
