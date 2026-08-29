import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { FunctionFailure, type OwnedProduct } from "./types.ts";
import {
  PlanRejected,
  parseAndValidatePlan,
  planRows,
  stripCodeFence,
} from "./validation.ts";

const analysisAttributes: Record<string, string> = {
  face_shape: "round",
  skin_tone: "medium",
  undertone: "warm",
  eye_shape: "almond",
  lip_shape: "full",
};

const ownedBlush: OwnedProduct = {
  productId: "product-blush",
  category: "blush",
  colorHex: "#B86F72",
  finish: "satin",
  productName: "My blush",
  colorLabel: "Soft Rose",
  foundationDepth: null,
  foundationUndertone: null,
};

// deno-lint-ignore no-explicit-any
type Json = Record<string, any>;

function step(category: string, overrides: Json = {}): Json {
  const attributesFor: Record<string, Json> = {
    foundation: { skin_tone: "medium", undertone: "warm" },
    concealer: { eye_shape: "almond", skin_tone: "medium" },
    contour_bronzer: { face_shape: "round" },
    blush: { face_shape: "round" },
    highlighter: { face_shape: "round" },
    eyebrow: { face_shape: "round" },
    eyeshadow: { eye_shape: "almond" },
    eyeliner: { eye_shape: "almond" },
    lipstick: { lip_shape: "full" },
    lip_gloss: { lip_shape: "full" },
    final_look: {},
  };
  const base: Json = {
    category,
    product_id: null,
    where_to_apply: "Upper outer cheeks",
    direction: "Upward toward the temples",
    technique: "Soft circular blending",
    face_attributes: attributesFor[category] ?? {},
    face_rationale: "Lifted placement adds length to a round face.",
    target_rationale: "Matches the soft flush in the target look.",
    target_look_cues: ["Soft diffused flush"],
    guideline_visual_intent: {
      description: "Translucent band across the upper outer cheek.",
      graphics: ["translucent_zone", "arrow"],
    },
  };
  if (category === "final_look") {
    base.where_to_apply = undefined;
    base.direction = undefined;
    base.technique = undefined;
    base.guideline_visual_intent = null;
  }
  return { ...base, ...overrides };
}

function planOf(steps: Json[]): string {
  return JSON.stringify({ steps });
}

function validate(
  raw: string,
  options: {
    style?: string;
    sourceMode?: "standard" | "makeup_kit";
    ownedProducts?: OwnedProduct[];
  } = {},
) {
  return parseAndValidatePlan(raw, {
    style: options.style ?? "soft_glam",
    sourceMode: options.sourceMode ?? "standard",
    ownedProducts: options.ownedProducts ?? [],
    analysisAttributes,
  });
}

function rejectionReasons(raw: string, options = {}): string[] {
  try {
    validate(raw, options);
  } catch (error) {
    if (error instanceof PlanRejected) return error.reasons;
    throw error;
  }
  throw new Error("expected the plan to be rejected");
}

Deno.test("accepts a minimal valid plan", () => {
  const plan = validate(planOf([step("blush"), step("final_look")]));
  assertEquals(plan.steps.length, 2);
  assertEquals(plan.steps[0].stepIndex, 1);
  assertEquals(plan.steps[1].stepIndex, 2);
});

Deno.test("accepts dynamic plan lengths", () => {
  const short = validate(planOf([step("lipstick"), step("final_look")]));
  assertEquals(short.steps.length, 2);

  const long = validate(
    planOf([
      step("foundation"),
      step("concealer"),
      step("contour_bronzer"),
      step("blush"),
      step("highlighter"),
      step("eyebrow"),
      step("eyeshadow"),
      step("eyeliner"),
      step("lipstick"),
      step("lip_gloss"),
      step("final_look"),
    ]),
  );
  assertEquals(long.steps.length, 11);
});

Deno.test("accepts a response wrapped in a markdown fence", () => {
  const raw = "```json\n" + planOf([step("blush"), step("final_look")]) +
    "\n```";
  assertEquals(validate(raw).steps.length, 2);
  assertEquals(stripCodeFence("```json\n{}\n```"), "{}");
});

Deno.test("rejects malformed responses", () => {
  assertEquals(rejectionReasons("not json at all").length, 1);
  assertEquals(rejectionReasons("[]").length, 1);
  assertEquals(rejectionReasons('{"steps": []}').length, 1);
  assertEquals(rejectionReasons('{"steps": "blush"}').length, 1);
  assertEquals(rejectionReasons(planOf(["blush" as unknown as Json])).length, 1);
});

Deno.test("rejects an unsupported style outright", () => {
  assertThrows(
    () => validate(planOf([step("blush"), step("final_look")]), {
      style: "glam_supreme",
    }),
    FunctionFailure,
    "supported makeup style",
  );
});

Deno.test("rejects an unknown category", () => {
  const reasons = rejectionReasons(
    planOf([step("foundation_result"), step("final_look")]),
  );
  assertEquals(reasons.some((r) => r.includes("unsupported category")), true);
});

Deno.test("requires exactly one terminal final look", () => {
  assertEquals(
    rejectionReasons(planOf([step("blush")])).some((r) =>
      r.includes('must end with a "final_look"')
    ),
    true,
  );
  assertEquals(
    rejectionReasons(planOf([step("final_look"), step("blush")])).some((r) =>
      r.includes("must be last")
    ),
    true,
  );
  assertEquals(
    rejectionReasons(planOf([step("final_look")])).some((r) =>
      r.includes("at least one makeup step")
    ),
    true,
  );
});

Deno.test("rejects duplicate categories", () => {
  const reasons = rejectionReasons(
    planOf([step("blush"), step("blush"), step("final_look")]),
  );
  assertEquals(reasons.some((r) => r.includes("more than once")), true);
});

Deno.test("enforces canonical ordering", () => {
  assertEquals(
    rejectionReasons(
      planOf([step("blush"), step("foundation"), step("final_look")]),
    ).some((r) => r.includes("cannot follow")),
    true,
  );
  assertEquals(
    rejectionReasons(
      planOf([step("lip_gloss"), step("lipstick"), step("final_look")]),
    ).some((r) => r.includes("cannot follow")),
    true,
  );
});

Deno.test("requires the placement fields on every makeup step", () => {
  for (const field of ["where_to_apply", "direction", "technique"]) {
    const reasons = rejectionReasons(
      planOf([step("blush", { [field]: "  " }), step("final_look")]),
    );
    assertEquals(
      reasons.some((r) => r.includes(field)),
      true,
      `expected ${field} to be required`,
    );
  }
});

Deno.test("requires both rationales and at least one target cue", () => {
  assertEquals(
    rejectionReasons(
      planOf([step("blush", { face_rationale: "" }), step("final_look")]),
    ).some((r) => r.includes("face_rationale")),
    true,
  );
  assertEquals(
    rejectionReasons(
      planOf([step("blush", { target_look_cues: [] }), step("final_look")]),
    ).some((r) => r.includes("target_look_cues")),
    true,
  );
});

Deno.test("the final look carries no guideline and no product", () => {
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush"),
        step("final_look", {
          guideline_visual_intent: {
            description: "Draw the finished look.",
            graphics: ["arrow"],
          },
        }),
      ]),
    ).some((r) => r.includes("must not carry a guideline")),
    true,
  );
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush"),
        step("final_look", { product_id: "product-blush" }),
      ]),
    ).some((r) => r.includes("must not reference a product")),
    true,
  );
});

Deno.test("a makeup step must describe a guideline it is allowed to draw", () => {
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush", { guideline_visual_intent: null }),
        step("final_look"),
      ]),
    ).some((r) => r.includes("guideline visual intent")),
    true,
  );
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush", {
          guideline_visual_intent: {
            description: "Show the finished blush.",
            graphics: ["finished_makeup"],
          },
        }),
        step("final_look"),
      ]),
    ).some((r) => r.includes("unsupported mark")),
    true,
  );
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush", {
          guideline_visual_intent: {
            description: "Nothing in particular.",
            graphics: [],
          },
        }),
        step("final_look"),
      ]),
    ).some((r) => r.includes("at least one instructional mark")),
    true,
  );
});

Deno.test("facial attributes are scoped to the category", () => {
  const reasons = rejectionReasons(
    planOf([
      step("blush", {
        face_attributes: { face_shape: "round", lip_shape: "full" },
      }),
      step("final_look"),
    ]),
  );
  assertEquals(reasons.some((r) => r.includes("not relevant")), true);
  assertEquals(reasons.some((r) => r.includes("lip_shape")), true);
});

Deno.test("a makeup step must be personalized by something", () => {
  assertEquals(
    rejectionReasons(
      planOf([step("blush", { face_attributes: {} }), step("final_look")]),
    ).some((r) => r.includes("at least one relevant facial attribute")),
    true,
  );
});

Deno.test("a step cannot invent a face the user does not have", () => {
  const reasons = rejectionReasons(
    planOf([
      step("blush", { face_attributes: { face_shape: "heart" } }),
      step("final_look"),
    ]),
  );
  assertEquals(reasons.some((r) => r.includes('this analysis is "round"')), true);
});

Deno.test("standard mode never references an owned product", () => {
  assertEquals(
    rejectionReasons(
      planOf([
        step("blush", { product_id: "product-blush" }),
        step("final_look"),
      ]),
    ).some((r) => r.includes("must not reference an owned product")),
    true,
  );
});

Deno.test("kit mode accepts only owned products", () => {
  const options = {
    sourceMode: "makeup_kit" as const,
    ownedProducts: [ownedBlush],
  };

  const accepted = validate(
    planOf([
      step("blush", { product_id: "product-blush" }),
      step("final_look"),
    ]),
    options,
  );
  assertEquals(accepted.steps[0].productId, "product-blush");

  assertEquals(
    rejectionReasons(
      planOf([step("blush"), step("final_look")]),
      options,
    ).some((r) => r.includes("must reference an owned product")),
    true,
  );

  assertEquals(
    rejectionReasons(
      planOf([
        step("blush", { product_id: "product-invented" }),
        step("final_look"),
      ]),
      options,
    ).some((r) => r.includes("does not own")),
    true,
  );

  assertEquals(
    rejectionReasons(
      planOf([
        step("lipstick", { product_id: "product-blush" }),
        step("final_look"),
      ]),
      options,
    ).some((r) => r.includes("references a blush product")),
    true,
  );
});

Deno.test("kit mode may omit categories the user cannot cover", () => {
  const plan = validate(
    planOf([
      step("blush", { product_id: "product-blush" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );
  assertEquals(plan.steps.map((s) => s.category), ["blush", "final_look"]);
});

Deno.test("a one-product kit is a complete tutorial", () => {
  // An incomplete kit is normal, not an error state. One owned product plus
  // the final look is the shortest legitimate plan there is.
  const plan = validate(
    planOf([
      step("blush", { product_id: "product-blush" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );
  const rows = planRows(plan, {
    style: "soft_glam",
    sourceMode: "makeup_kit",
    ownedProducts: [ownedBlush],
  });

  assertEquals(rows.length, 2);
  assertEquals(rows[1].category, "final_look");
});

Deno.test("a kit step may not teach a category the product is not", () => {
  // The model chose a real owned id but attached it to the wrong step. Its
  // own category claim is not what decides.
  const reasons = rejectionReasons(
    planOf([
      step("lipstick", { product_id: "product-blush" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );

  assertEquals(
    reasons.some((reason) => reason.includes("references a blush product")),
    true,
    reasons.join(" "),
  );
});

Deno.test("a product owned by another account is simply not owned here", () => {
  // The server hands the validator only what came back from an RLS-scoped
  // read, so another account's product is indistinguishable from one that
  // does not exist. There is no branch that could treat it differently.
  const reasons = rejectionReasons(
    planOf([
      step("blush", { product_id: "product-belonging-to-someone-else" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );

  assertEquals(
    reasons.some((reason) =>
      reason.includes("references a product the user does not own")
    ),
    true,
    reasons.join(" "),
  );
});


Deno.test("every violation is collected for one repair round", () => {
  const reasons = rejectionReasons(
    planOf([
      step("blush", { face_attributes: { lip_shape: "full" } }),
      step("foundation"),
      step("final_look"),
    ]),
  );
  assertEquals(reasons.length > 1, true);
});

Deno.test("planRows shapes the atomic plan write", () => {
  const plan = validate(
    planOf([
      step("blush", { coverage: "Medium", personalized_tip: "Build slowly." }),
      step("final_look"),
    ]),
  );
  const rows = planRows(plan, { style: "soft_glam", sourceMode: "standard" });

  assertEquals(rows.length, 2);
  assertEquals(rows[0].step_index, 1);
  assertEquals(rows[0].category, "blush");
  assertEquals(rows[0].geometry_status, "pending");

  const spec = rows[0].step_spec_json as Record<string, unknown>;
  assertEquals(spec.selected_style_code, "soft_glam");
  assertEquals(spec.source_mode, "standard");
  assertEquals(spec.plan_version, 3);
  assertEquals(spec.target_reference_mode, "full_canonical_preview");
  assertEquals(spec.coverage, "Medium");
  assertEquals(spec.personalized_tip, "Build slowly.");
  // The product snapshot lives in its own column, never inside the spec.
  assertEquals("product_snapshot" in spec, false);
  assertEquals("product_id" in spec, false);

  assertEquals(rows[1].step_index, 2);
  assertEquals(rows[1].category, "final_look");
  assertEquals(rows[1].geometry_status, "not_required");
  assertEquals(rows[1].product_snapshot_json, null);
  const finalSpec = rows[1].step_spec_json as Record<string, unknown>;
  assertEquals("guideline_visual_intent" in finalSpec, false);
});

Deno.test("a kit snapshot is copied from the user's inventory, not the model", () => {
  // The model is shown the real product and told to echo its id. Everything
  // else it writes about that product is discarded: the persisted snapshot is
  // what the user actually owns, so a paraphrased shade or a mistyped hex can
  // never be stored and taught back to them.
  const plan = validate(
    planOf([
      step("blush", {
        product_id: "product-blush",
        product_name: "Something else entirely",
        shade_name: "Invented Shade",
        color_hex: "#FF0000",
        finish: "matte",
      }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );
  const rows = planRows(plan, {
    style: "soft_glam",
    sourceMode: "makeup_kit",
    ownedProducts: [ownedBlush],
  });
  const snapshot = rows[0].product_snapshot_json as Record<string, unknown>;

  assertEquals(snapshot.product_id, ownedBlush.productId);
  assertEquals(snapshot.category, ownedBlush.category);
  assertEquals(snapshot.color_hex, ownedBlush.colorHex);
  assertEquals(snapshot.finish, ownedBlush.finish);
  assertEquals(snapshot.product_name, ownedBlush.productName);
  assertEquals(snapshot.shade_name, ownedBlush.colorLabel);
});

Deno.test("a kit product with no name or shade snapshots neither", () => {
  // An inventory row may legitimately carry only a colour and a finish.
  // Nothing is invented to fill the gap.
  const sparse: OwnedProduct = {
    ...ownedBlush,
    productName: null,
    colorLabel: null,
  };
  const plan = validate(
    planOf([
      step("blush", { product_id: "product-blush", product_name: "Guessed" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [sparse] },
  );
  const rows = planRows(plan, {
    style: "soft_glam",
    sourceMode: "makeup_kit",
    ownedProducts: [sparse],
  });
  const snapshot = rows[0].product_snapshot_json as Record<string, unknown>;

  assertEquals("product_name" in snapshot, false);
  assertEquals("shade_name" in snapshot, false);
  assertEquals(snapshot.color_hex, sparse.colorHex);
});

Deno.test("kit rows are refused rather than written from model text", () => {
  // Belt and braces for the one path that must never fall back: if the owned
  // inventory is not supplied, the rows are rejected instead of being built
  // from whatever the model claimed.
  const plan = validate(
    planOf([
      step("blush", { product_id: "product-blush" }),
      step("final_look"),
    ]),
    { sourceMode: "makeup_kit", ownedProducts: [ownedBlush] },
  );

  assertThrows(
    () => planRows(plan, { style: "soft_glam", sourceMode: "makeup_kit" }),
    PlanRejected,
  );
});

Deno.test("a standard snapshot still describes the recommended shade", () => {
  // Standard mode has no inventory row to copy, so the description comes from
  // the persisted makeup plan by way of the prompt — and carries no id.
  const plan = validate(
    planOf([
      step("blush", {
        product_name: "Recommended shade",
        shade_name: "Soft Rose",
        color_hex: "#b86f72",
        finish: "satin",
      }),
      step("final_look"),
    ]),
  );
  const rows = planRows(plan, { style: "soft_glam", sourceMode: "standard" });
  const snapshot = rows[0].product_snapshot_json as Record<string, unknown>;

  assertEquals(snapshot.shade_name, "Soft Rose");
  assertEquals(snapshot.color_hex, "#B86F72");
  assertEquals("product_id" in snapshot, false);
});

Deno.test("no row carries any result state", () => {
  const plan = validate(planOf([step("blush"), step("final_look")]));
  const rows = planRows(plan, { style: "soft_glam", sourceMode: "standard" });

  for (const row of rows) {
    assertEquals("result_status" in row, false);
    assertEquals("result_image_path" in row, false);
    const spec = row.step_spec_json as Record<string, unknown>;
    for (const key of Object.keys(spec)) {
      assertEquals(key.includes("result"), false, `unexpected key ${key}`);
    }
  }
});

// --- V3-10F4.4: the step ceiling moved from the wire schema to here ---------

Deno.test("a plan at the twelve-step ceiling is not rejected for its length", () => {
  // `properties.steps.maxItems` had to leave the Gemini schema — it is the
  // construct that made the model reject the whole request. The rule itself
  // did not leave: it moved to `parseAndValidatePlan`. Twelve must therefore
  // still be allowed through the length gate.
  const twelve = [
    ...Array.from({ length: 11 }, (_, index) => step(`filler_${index}`)),
    step("final_look"),
  ];
  const rejected = assertThrows(
    () => validate(planOf(twelve)),
    PlanRejected,
  ) as PlanRejected;

  // It fails on the invented categories, never on the count.
  for (const reason of rejected.reasons) {
    assertEquals(
      reason.includes("at most"),
      false,
      `length must not be the complaint: ${reason}`,
    );
  }
});

Deno.test("a thirteen-step plan is rejected for its length", () => {
  const thirteen = [
    ...Array.from({ length: 12 }, () => step("blush")),
    step("final_look"),
  ];
  const rejected = assertThrows(
    () => validate(planOf(thirteen)),
    PlanRejected,
  ) as PlanRejected;

  assertEquals(rejected.reasons.length, 1, "the count is refused on its own");
  assertEquals(
    rejected.reasons[0],
    "The plan has 13 steps; at most 12 are allowed.",
  );
});

Deno.test("an absurd plan is refused before any step is examined", () => {
  // The point of an outer ceiling: a runaway response costs one comparison,
  // not a thousand validations, and nothing reaches persistence.
  const runaway = Array.from({ length: 500 }, () => step("blush"));
  const rejected = assertThrows(
    () => validate(planOf(runaway)),
    PlanRejected,
  ) as PlanRejected;

  assertEquals(rejected.reasons.length, 1);
  assertEquals(
    rejected.reasons[0],
    "The plan has 500 steps; at most 12 are allowed.",
  );
});

Deno.test("a real dynamic plan well under the ceiling still validates", () => {
  // The ceiling must not have narrowed ordinary behaviour: §10 requires a
  // dynamic count, and a short Natural-style plan is the common case.
  const plan = validate(
    planOf([step("foundation"), step("blush"), step("final_look")]),
  );

  assertEquals(plan.steps.length, 3);
  assertEquals(plan.steps[2].category, "final_look");
});

Deno.test("an empty plan is still refused", () => {
  const rejected = assertThrows(
    () => validate(planOf([])),
    PlanRejected,
  ) as PlanRejected;

  assertEquals(
    rejected.reasons[0],
    "The plan must contain a non-empty steps array.",
  );
});
