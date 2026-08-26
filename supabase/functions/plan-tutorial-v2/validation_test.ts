import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";

import { FunctionFailure, type OwnedProduct } from "./types.ts";
import { planRows, parseAndValidatePlan, PlanRejected } from "./validation.ts";

function step(
  category: string,
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    category,
    title: "Blush",
    whatToApply: "A soft rose blush",
    whereToApply: "Upper cheeks",
    direction: "Upward toward the temples",
    technique: "Soft circular blending",
    intensity: "soft",
    faceRationale: "Heart-shaped faces balance with upper-cheek colour.",
    targetLookCues: "Matches the warm flush in the final look.",
    amount: null,
    toolSuggestion: null,
    personalizedTip: null,
    avoid: null,
    productId: null,
    ...overrides,
  };
}

function plan(steps: Record<string, unknown>[]): string {
  return JSON.stringify({ steps });
}

function standard(categories: string[]): string {
  return plan([...categories.map((category) => step(category)), step("final_look")]);
}

function product(overrides: Partial<OwnedProduct> = {}): OwnedProduct {
  return {
    productId: "product-1",
    category: "blush",
    colorHex: "#B86F72",
    finish: "matte",
    productName: null,
    colorLabel: "Rosewood",
    foundationDepth: null,
    foundationUndertone: null,
    ...overrides,
  };
}

const standardOptions = {
  style: "soft_glam",
  sourceMode: "standard_recommendation" as const,
  ownedProducts: [] as OwnedProduct[],
};

function kitOptions(products: OwnedProduct[]) {
  return {
    style: "soft_glam",
    sourceMode: "makeup_kit" as const,
    ownedProducts: products,
  };
}

function rejection(raw: string, options = standardOptions): PlanRejected {
  return assertThrows(
    () => parseAndValidatePlan(raw, options),
    PlanRejected,
  ) as PlanRejected;
}

function assertReason(error: PlanRejected, fragment: string) {
  assert(
    error.reasons.some((reason) => reason.includes(fragment)),
    `expected a reason containing "${fragment}", got: ${error.reasons.join(" | ")}`,
  );
}

// --- Dynamic plans ----------------------------------------------------------

Deno.test("accepts a short natural plan", () => {
  const result = parseAndValidatePlan(
    standard(["foundation", "lipstick"]),
    standardOptions,
  );
  assertEquals(result.steps.length, 3);
  assertEquals(result.steps[2].category, "final_look");
});

Deno.test("accepts a long full-glam plan", () => {
  const result = parseAndValidatePlan(
    standard([
      "foundation",
      "concealer",
      "contour_bronzer",
      "blush",
      "highlighter",
      "eyebrow",
      "eyeshadow",
      "eyeliner",
      "lipstick",
      "lip_gloss",
    ]),
    standardOptions,
  );
  assertEquals(result.steps.length, 11);
});

Deno.test("accepts a single makeup step plus the final look", () => {
  const result = parseAndValidatePlan(standard(["lipstick"]), standardOptions);
  assertEquals(result.steps.length, 2);
});

Deno.test("accepts plans of differing lengths — no fixed count", () => {
  const lengths = [
    parseAndValidatePlan(standard(["lipstick"]), standardOptions).steps.length,
    parseAndValidatePlan(standard(["foundation", "blush", "lipstick"]), standardOptions)
      .steps.length,
  ];
  assertEquals(lengths, [2, 4]);
});

Deno.test("accepts a plan that omits categories entirely", () => {
  const result = parseAndValidatePlan(
    standard(["foundation", "eyeliner"]),
    standardOptions,
  );
  assertEquals(result.steps.map((item) => item.category), [
    "foundation",
    "eyeliner",
    "final_look",
  ]);
});

// --- Final Look -------------------------------------------------------------

Deno.test("rejects a plan with no final look", () => {
  assertReason(
    rejection(plan([step("blush")])),
    'must end with a "final_look" step',
  );
});

Deno.test("rejects a final look that is not last", () => {
  assertReason(
    rejection(plan([step("final_look"), step("blush")])),
    'must be last',
  );
});

Deno.test("rejects more than one final look", () => {
  assertReason(
    rejection(plan([step("blush"), step("final_look"), step("final_look")])),
    "exactly one",
  );
});

Deno.test("rejects a plan with no makeup step", () => {
  assertReason(
    rejection(plan([step("final_look")])),
    "at least one makeup step",
  );
});

// --- Ordering and duplicates ------------------------------------------------

Deno.test("rejects concealer before foundation", () => {
  assertReason(
    rejection(standard(["concealer", "foundation"])),
    "cannot follow",
  );
});

Deno.test("rejects lip gloss before lip colour", () => {
  assertReason(rejection(standard(["lip_gloss", "lipstick"])), "cannot follow");
});

Deno.test("accepts lip gloss immediately after lip colour", () => {
  const result = parseAndValidatePlan(
    standard(["lipstick", "lip_gloss"]),
    standardOptions,
  );
  assertEquals(result.steps.length, 3);
});

Deno.test("rejects a duplicated category", () => {
  assertReason(
    rejection(standard(["blush", "blush"])),
    "appears more than once",
  );
});

Deno.test("rejects an unknown category", () => {
  assertReason(
    rejection(plan([step("glitter_beard"), step("final_look")])),
    "unknown category",
  );
});

// --- Required instructional fields ------------------------------------------

Deno.test("rejects a step missing where to apply", () => {
  assertReason(
    rejection(plan([step("blush", { whereToApply: "  " }), step("final_look")])),
    "missing whereToApply",
  );
});

Deno.test("rejects a step missing a direction", () => {
  assertReason(
    rejection(plan([step("blush", { direction: "" }), step("final_look")])),
    "missing direction",
  );
});

Deno.test("rejects a step missing a face rationale", () => {
  assertReason(
    rejection(plan([step("blush", { faceRationale: "" }), step("final_look")])),
    "missing faceRationale",
  );
});

Deno.test("rejects an unsupported intensity", () => {
  assertReason(
    rejection(plan([step("blush", { intensity: "extreme" }), step("final_look")])),
    "unsupported intensity",
  );
});

Deno.test("rejects a blank optional field rather than storing it", () => {
  assertReason(
    rejection(plan([step("blush", { personalizedTip: "   " }), step("final_look")])),
    "blank personalizedTip",
  );
});

Deno.test("the final look is exempt from placement fields", () => {
  const result = parseAndValidatePlan(
    plan([
      step("blush"),
      step("final_look", { whereToApply: "", direction: "", faceRationale: "" }),
    ]),
    standardOptions,
  );
  assertEquals(result.steps.length, 2);
});

Deno.test("reports every field violation at once for the repair retry", () => {
  const error = rejection(
    plan([
      step("foundation", { direction: "" }),
      step("blush", { intensity: "extreme", personalizedTip: "  " }),
      step("final_look"),
    ]),
  );

  assertReason(error, "Step 1 is missing direction");
  assertReason(error, "Step 2 has an unsupported intensity");
  assertReason(error, "Step 2 has a blank personalizedTip");
});

Deno.test("structural violations are reported together too", () => {
  const error = rejection(standard(["blush", "blush"]));

  assertReason(error, "appears more than once");
  assert(error.reasons.length >= 1, error.reasons.join(" | "));
});

// --- Kit ownership ----------------------------------------------------------

Deno.test("Kit mode accepts a step backed by an owned product", () => {
  const result = parseAndValidatePlan(
    plan([step("blush", { productId: "product-1" }), step("final_look")]),
    kitOptions([product()]),
  );
  assertEquals(result.steps[0].productId, "product-1");
});

Deno.test("Kit mode rejects a product the user does not own", () => {
  assertReason(
    rejection(
      plan([step("blush", { productId: "not-owned" }), step("final_look")]),
      kitOptions([product()]),
    ),
    "does not own",
  );
});

Deno.test("Kit mode rejects a step with no product", () => {
  assertReason(
    rejection(
      plan([step("blush"), step("final_look")]),
      kitOptions([product()]),
    ),
    "must reference an owned product",
  );
});

Deno.test("Kit mode rejects a product from the wrong category", () => {
  assertReason(
    rejection(
      plan([step("blush", { productId: "product-1" }), step("final_look")]),
      kitOptions([product({ category: "lipstick" })]),
    ),
    "references a lipstick product",
  );
});

Deno.test("Kit mode rejects a product on the final look", () => {
  assertReason(
    rejection(
      plan([
        step("blush", { productId: "product-1" }),
        step("final_look", { productId: "product-1" }),
      ]),
      kitOptions([product()]),
    ),
    "must not reference a product",
  );
});

Deno.test("an empty kit cannot produce a plan", () => {
  assertReason(
    rejection(
      plan([step("blush", { productId: "product-1" }), step("final_look")]),
      kitOptions([]),
    ),
    "does not own",
  );
});

Deno.test("standard mode rejects a smuggled Kit product", () => {
  assertReason(
    rejection(plan([step("blush", { productId: "product-1" }), step("final_look")])),
    "must not reference a product in standard mode",
  );
});

// --- Style ------------------------------------------------------------------

Deno.test("rejects an unsupported style outright", () => {
  assertThrows(
    () =>
      parseAndValidatePlan(standard(["blush"]), {
        ...standardOptions,
        style: "disco_glam",
      }),
    FunctionFailure,
  );
});

// --- Malformed responses ----------------------------------------------------

Deno.test("rejects output that is not JSON", () => {
  assertReason(rejection("Here is your tutorial!"), "not valid JSON");
});

Deno.test("rejects a JSON array at the root", () => {
  assertReason(rejection("[]"), "must be a JSON object");
});

Deno.test("rejects a missing steps array", () => {
  assertReason(rejection('{"tutorial":[]}'), "non-empty steps array");
});

Deno.test("rejects an empty steps array", () => {
  assertReason(rejection('{"steps":[]}'), "non-empty steps array");
});

Deno.test("rejects a non-object step", () => {
  assertReason(rejection('{"steps":["blush"]}'), "must be an object");
});

Deno.test("rejects a non-string productId", () => {
  assertReason(
    rejection(plan([step("blush", { productId: 42 }), step("final_look")])),
    "invalid productId",
  );
});

Deno.test("tolerates a fenced code block around valid JSON", () => {
  const fenced = "```json\n" + standard(["blush"]) + "\n```";
  const result = parseAndValidatePlan(fenced, standardOptions);
  assertEquals(result.steps.length, 2);
});

// --- Row projection ---------------------------------------------------------

Deno.test("assigns sequential zero-based step indexes", () => {
  const validated = parseAndValidatePlan(
    standard(["foundation", "blush", "lipstick"]),
    standardOptions,
  );
  const rows = planRows(validated, []);

  assertEquals(rows.map((row) => row.step_index), [0, 1, 2, 3]);
});

Deno.test("marks the final look as needing no guideline asset", () => {
  const rows = planRows(
    parseAndValidatePlan(standard(["blush"]), standardOptions),
    [],
  );

  assertEquals(rows[0].guideline_status, "pending");
  assertEquals(rows[0].result_status, "pending");
  assertEquals(rows[1].guideline_status, "ready");
  assertEquals(rows[1].product_snapshot_json, null);
});

Deno.test("never persists derived instructions", () => {
  const rows = planRows(
    parseAndValidatePlan(standard(["blush"]), standardOptions),
    [],
  );
  const spec = rows[0].step_spec_json as Record<string, unknown>;

  for (
    const key of [
      "guidelineInstruction",
      "resultInstruction",
      "stepIndex",
      "cumulativeCategories",
      "productId",
    ]
  ) {
    assert(!(key in spec), `${key} must not be persisted in the step spec`);
  }
  assertEquals(spec.schema, 1);
});

Deno.test("the product snapshot comes from the server, not the model", () => {
  const validated = parseAndValidatePlan(
    plan([step("blush", { productId: "product-1" }), step("final_look")]),
    kitOptions([product({ colorLabel: "Rosewood", colorHex: "#B86F72" })]),
  );
  const rows = planRows(validated, [
    product({ colorLabel: "Rosewood", colorHex: "#B86F72" }),
  ]);
  const snapshot = rows[0].product_snapshot_json as Record<string, unknown>;

  assertEquals(snapshot.productId, "product-1");
  assertEquals(snapshot.colorHex, "#B86F72");
  assertEquals(snapshot.colorLabel, "Rosewood");
  assertEquals(snapshot.category, "blush");
});

Deno.test("standard rows carry no product snapshot", () => {
  const rows = planRows(
    parseAndValidatePlan(standard(["foundation", "blush"]), standardOptions),
    [],
  );
  for (const row of rows) assertEquals(row.product_snapshot_json, null);
});
