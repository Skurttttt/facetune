import { assertEquals } from "jsr:@std/assert@1";

import type { CategoryProductFacts } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { parseAndValidateGeometryPlan } from "./validation.ts";

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

const blushFacts: CategoryProductFacts = {
  category: "blush",
  label: "Blush",
  colorName: "Warm Peach",
  colorHex: "#E58C87",
  finish: "satin",
  placement: "Upper cheekbones",
  technique: "Blend upward.",
  intensity: "light",
};

const lipstickFacts: CategoryProductFacts = {
  category: "lipstick",
  label: "Lipstick",
};

function validStep(overrides: Record<string, unknown> = {}) {
  return {
    category: "blush",
    placement: "Sweep color across the upper cheekbones.",
    direction: "outward",
    intensity: "medium",
    technique: "Blend with a fluffy brush.",
    confidence: 0.82,
    colorHex: "#E58C87",
    finish: "satin",
    zones: [
      {
        shape: "polygon",
        points: [{ x: 0.3, y: 0.5 }, { x: 0.35, y: 0.55 }, { x: 0.32, y: 0.6 }],
        confidence: 0.75,
      },
    ],
    paths: [],
    arrows: [],
    ...overrides,
  };
}

function planText(steps: unknown[]): string {
  return JSON.stringify({ steps });
}

function expectFailureFromText(
  requestedCategories: CategoryProductFacts[],
  text: string,
  code: string,
  sourceMode = "standard_recommendation",
) {
  try {
    parseAndValidateGeometryPlan(text, { requestedCategories, sourceMode });
  } catch (error) {
    assert(error instanceof FunctionFailure, "Expected a FunctionFailure");
    assert(
      (error as FunctionFailure).code === code,
      `Expected ${code}, received ${(error as FunctionFailure).code}`,
    );
    return;
  }
  throw new Error(`Expected ${code} but nothing was thrown`);
}

function expectFailure(
  requestedCategories: CategoryProductFacts[],
  steps: unknown[],
  code: string,
  sourceMode = "standard_recommendation",
) {
  expectFailureFromText(requestedCategories, planText(steps), code, sourceMode);
}

Deno.test("schema parse: accepts a valid, fully-covered geometry plan", () => {
  const plan = parseAndValidateGeometryPlan(planText([validStep()]), {
    requestedCategories: [blushFacts],
    sourceMode: "standard_recommendation",
  });
  assertEquals(plan.steps.length, 1);
  assertEquals(plan.steps[0].category, "blush");
  assertEquals(plan.steps[0].zones.length, 1);
  assertEquals(plan.steps[0].zones[0].points.length, 3);
});

Deno.test("schema parse: rejects malformed JSON", () => {
  expectFailureFromText([blushFacts], "{not-json", "malformed_ai_json");
});

Deno.test("schema parse: rejects a non-object root", () => {
  expectFailureFromText(
    [blushFacts],
    JSON.stringify([1, 2, 3]),
    "invalid_ai_response",
  );
});

Deno.test("category coverage: rejects an empty plan when categories were requested", () => {
  expectFailure([blushFacts], [], "CATEGORY_COVERAGE_MISMATCH");
});

Deno.test("bounds: rejects a coordinate outside the normalized 0.0-1.0 range", () => {
  expectFailure(
    [blushFacts],
    [
      validStep({
        zones: [
          {
            shape: "polygon",
            points: [{ x: 1.4, y: 0.2 }, { x: 0.2, y: 0.3 }],
            confidence: 0.7,
          },
        ],
      }),
    ],
    "INVALID_GEOMETRY_BOUNDS",
  );
});

Deno.test("bounds: rejects a path with fewer than two points", () => {
  expectFailure(
    [blushFacts],
    [
      validStep({
        zones: [],
        paths: [{ points: [{ x: 0.2, y: 0.3 }], confidence: 0.7 }],
      }),
    ],
    "INVALID_GEOMETRY_BOUNDS",
  );
});

Deno.test("bounds: rejects a step with no geometry primitives at all", () => {
  expectFailure(
    [blushFacts],
    [validStep({ zones: [], paths: [], arrows: [] })],
    "INVALID_GEOMETRY_BOUNDS",
  );
});

Deno.test("confidence: rejects an out-of-range step-level confidence", () => {
  expectFailure(
    [blushFacts],
    [validStep({ confidence: 1.5 })],
    "INVALID_CONFIDENCE",
  );
});

Deno.test("confidence: rejects an out-of-range primitive-level confidence", () => {
  expectFailure(
    [blushFacts],
    [
      validStep({
        zones: [
          {
            shape: "polygon",
            points: [{ x: 0.2, y: 0.3 }, { x: 0.25, y: 0.35 }],
            confidence: -0.1,
          },
        ],
      }),
    ],
    "INVALID_CONFIDENCE",
  );
});

Deno.test("category coverage: rejects a plan missing a requested category", () => {
  expectFailure(
    [blushFacts, lipstickFacts],
    [validStep()],
    "CATEGORY_COVERAGE_MISMATCH",
  );
});

Deno.test("category coverage: rejects a plan with an unrequested category", () => {
  expectFailure(
    [blushFacts],
    [validStep(), validStep({ category: "lipstick" })],
    "CATEGORY_COVERAGE_MISMATCH",
  );
});

Deno.test("category coverage: rejects a duplicate category", () => {
  expectFailure(
    [blushFacts, lipstickFacts],
    [validStep(), validStep()],
    "CATEGORY_COVERAGE_MISMATCH",
  );
});

Deno.test("kit integrity: rejects a kit-mode category with no owned product backing it", () => {
  expectFailure(
    [blushFacts],
    [validStep()],
    "KIT_INTEGRITY_VIOLATION",
    "makeup_kit",
  );
});

Deno.test("kit integrity: accepts a kit-mode category backed by a real owned product", () => {
  const kitFacts: CategoryProductFacts = { ...blushFacts, kitProductId: "p1" };
  const plan = parseAndValidateGeometryPlan(planText([validStep()]), {
    requestedCategories: [kitFacts],
    sourceMode: "makeup_kit",
  });
  assertEquals(plan.steps.length, 1);
});

Deno.test("no product invention: rejects a colorHex that does not match the provided facts", () => {
  expectFailure(
    [blushFacts],
    [validStep({ colorHex: "#123456" })],
    "PRODUCT_INVENTION_DETECTED",
  );
});

Deno.test("no product invention: rejects a colorHex when no color was ever provided", () => {
  const noColorFacts: CategoryProductFacts = { category: "blush", label: "Blush" };
  expectFailure(
    [noColorFacts],
    [validStep({ colorHex: "#E58C87" })],
    "PRODUCT_INVENTION_DETECTED",
  );
});

Deno.test("no product invention: rejects a finish that does not match the provided facts", () => {
  expectFailure(
    [blushFacts],
    [validStep({ finish: "matte" })],
    "PRODUCT_INVENTION_DETECTED",
  );
});

Deno.test("no product invention: accepts a null colorHex/finish even when facts have real values", () => {
  const plan = parseAndValidateGeometryPlan(
    planText([validStep({ colorHex: null, finish: null })]),
    { requestedCategories: [blushFacts], sourceMode: "standard_recommendation" },
  );
  assertEquals(plan.steps[0].colorHex, null);
  assertEquals(plan.steps[0].finish, null);
});

Deno.test("invalid-response rejection: rejects an unsupported direction value", () => {
  expectFailure(
    [blushFacts],
    [validStep({ direction: "sideways" })],
    "unsupported_ai_value",
  );
});

Deno.test("invalid-response rejection: rejects an unsupported intensity value", () => {
  expectFailure(
    [blushFacts],
    [validStep({ intensity: "extreme" })],
    "unsupported_ai_value",
  );
});

Deno.test("invalid-response rejection: rejects an unsupported zone shape", () => {
  expectFailure(
    [blushFacts],
    [
      validStep({
        zones: [
          {
            shape: "circle",
            points: [{ x: 0.2, y: 0.3 }],
            confidence: 0.7,
          },
        ],
      }),
    ],
    "invalid_ai_response",
  );
});

Deno.test("invalid-response rejection: rejects a missing required field", () => {
  const step = validStep() as Record<string, unknown>;
  delete step.placement;
  expectFailure([blushFacts], [step], "invalid_ai_response");
});
