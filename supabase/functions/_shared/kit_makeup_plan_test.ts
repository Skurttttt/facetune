import {
  assert,
  assertEquals,
  assertNotEquals,
  assertRejects,
} from "jsr:@std/assert@1";

import {
  ALL_ROLES,
  buildCanonicalPlan,
  type BuildPlanInput,
  canonicalJson,
  deriveVisibleIntent,
  type DraftOmission,
  type DraftSelection,
  KIT_MAKEUP_PLAN_VERSION,
  PLAN_PREVIEW_PROMPT_VERSION,
  PLAN_VALIDATION_CONTRACT_VERSION,
  type PlanInventoryProduct,
  PlanViolation,
  ROLE_RULES,
  STYLE_PROFILES,
} from "./kit_makeup_plan.ts";
import { TUTORIAL_CATEGORIES } from "./tutorial_vocabulary.ts";

const owner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const planId = "99999999-9999-4999-8999-999999999999";
const analysisId = "88888888-8888-4888-8888-888888888888";

function product(
  n: number,
  category: string,
  extra: Partial<PlanInventoryProduct> = {},
): PlanInventoryProduct {
  const hex = n.toString(16).padStart(2, "0").toUpperCase();
  return {
    id: `${n.toString().padStart(8, "0")}-0000-4000-8000-000000000000`,
    user_id: owner,
    category,
    product_name: `Product ${n}`,
    color_hex: `#${hex}${hex}${hex}`,
    color_label: `Shade ${n}`,
    finish: "satin",
    foundation_depth: null,
    foundation_undertone: null,
    ...extra,
  };
}

const foundation = product(1, "foundation", {
  finish: "natural",
  foundation_depth: "medium",
  foundation_undertone: "warm",
});
const foundationB = product(2, "foundation", {
  finish: "matte",
  foundation_depth: "tan",
  foundation_undertone: "neutral",
});
const concealer = product(3, "concealer");
const contour = product(4, "contour_bronzer");
const blush = product(5, "blush");
const highlighter = product(6, "highlighter", { finish: "shimmer" });
const eyebrow = product(7, "eyebrow");
const eyeshadow = product(8, "eyeshadow");
const eyeshadowB = product(9, "eyeshadow");
const eyeliner = product(10, "eyeliner");
const lipstick = product(11, "lipstick");
const gloss = product(12, "lip_gloss", { finish: "glossy" });

const fullKit = [
  foundation,
  concealer,
  contour,
  blush,
  highlighter,
  eyebrow,
  eyeshadow,
  eyeliner,
  lipstick,
  gloss,
];

function pick(
  item: PlanInventoryProduct,
  role: string,
  intensity: DraftSelection["intensity"] = "medium",
): DraftSelection {
  return {
    productId: item.id,
    category: item.category,
    role,
    placement: "Apply where the look needs it",
    technique: "Blend in thin layers",
    intensity,
    reasoning: "Supports the selected style.",
  };
}

function input(
  styleCode: string,
  inventory: PlanInventoryProduct[],
  selections: DraftSelection[],
  complexionOmissions: DraftOmission[] = [],
): BuildPlanInput {
  return {
    planId,
    createdAt: "2026-09-27T00:00:00.000Z",
    analysisId,
    styleCode,
    recommendationPromptVersion: "kit_makeup_recommendation_v3",
    inventory,
    draft: {
      selections,
      complexionOmissions,
      overallIntensity: "medium",
      summary: "A look built from owned products.",
    },
  };
}

async function violation(value: BuildPlanInput): Promise<string> {
  const error = await assertRejects(
    () => buildCanonicalPlan(value),
    PlanViolation,
  );
  return (error as PlanViolation).code;
}

const glamSelections = [
  pick(foundation, "base_coverage"),
  pick(concealer, "under_eye_brightening", "soft"),
  pick(contour, "contour_sculpt"),
  pick(blush, "cheek_color"),
  pick(highlighter, "highlight"),
  pick(eyebrow, "brow_definition"),
  pick(eyeshadow, "lid_wash"),
  pick(eyeliner, "lash_line_definition"),
  pick(lipstick, "lip_color", "bold"),
  pick(gloss, "lip_topcoat", "soft"),
];

Deno.test("full kit: every selected category is allowed and backed", async () => {
  const built = await buildCanonicalPlan(
    input("full_glam", fullKit, glamSelections),
  );
  const { plan } = built;
  assertEquals(plan.plan_version, KIT_MAKEUP_PLAN_VERSION);
  assertEquals(plan.source_mode, "my_makeup_kit");
  assertEquals(plan.preview_prompt_version, PLAN_PREVIEW_PROMPT_VERSION);
  assertEquals(
    plan.validation_contract_version,
    PLAN_VALIDATION_CONTRACT_VERSION,
  );
  assertEquals(plan.allowed_visual_categories, [...TUTORIAL_CATEGORIES]);
  assertEquals(plan.forbidden_visual_categories, []);
  assertEquals(
    plan.category_decisions.map((decision) => decision.status),
    TUTORIAL_CATEGORIES.map(() => "selected"),
  );
  assertEquals(plan.considered_product_ids, fullKit.map((p) => p.id).sort());
  assertEquals(built.planDigest.length, 64);
});

Deno.test("owned-only: a product outside the inventory is refused", async () => {
  const stranger = product(50, "blush");
  assertEquals(
    await violation(
      input("natural", [blush], [pick(stranger, "cheek_color")]),
    ),
    "fabricated_product",
  );
});

Deno.test("owned-only: the category echo must match the owned row", async () => {
  assertEquals(
    await violation(
      input("natural", [blush], [{
        ...pick(blush, "cheek_color"),
        category: "lipstick",
      }]),
    ),
    "category_mismatch",
  );
});

Deno.test("a product can be selected only once", async () => {
  assertEquals(
    await violation(
      input("natural", [eyeshadow, eyeshadowB], [
        pick(eyeshadow, "lid_wash"),
        pick(eyeshadow, "crease_depth"),
      ]),
    ),
    "duplicate_product",
  );
});

Deno.test("no invalid duplicate category or role", async () => {
  // Two lip colours, one from lipstick and one from gloss, feed one Lips step.
  assertEquals(
    await violation(
      input("party", [lipstick, gloss], [
        pick(lipstick, "lip_color"),
        pick(gloss, "lip_color"),
      ]),
    ),
    "duplicate_role",
  );
  // Two eyeshadows in the same role.
  assertEquals(
    await violation(
      input("party", [eyeshadow, eyeshadowB], [
        pick(eyeshadow, "lid_wash"),
        pick(eyeshadowB, "lid_wash"),
      ]),
    ),
    "duplicate_role",
  );
  // A role that belongs to another category.
  assertEquals(
    await violation(
      input("party", [blush], [pick(blush, "highlight")]),
    ),
    "invalid_role",
  );
  // A topcoat needs a colour beneath it.
  assertEquals(
    await violation(input("party", [gloss], [pick(gloss, "lip_topcoat")])),
    "topcoat_without_color",
  );
  // Distinct roles within one category are allowed.
  const built = await buildCanonicalPlan(
    input("party", [eyeshadow, eyeshadowB], [
      pick(eyeshadowB, "crease_depth"),
      pick(eyeshadow, "lid_wash"),
    ]),
  );
  assertEquals(
    built.plan.selected_items.map((item) => item.intended_role),
    ["lid_wash", "crease_depth"],
  );
});

Deno.test("multiple foundations: one may be used, never two", async () => {
  const inventory = [foundation, foundationB, blush];
  assertEquals(
    await violation(
      input("soft_glam", inventory, [
        pick(foundation, "base_coverage"),
        pick(foundationB, "base_coverage"),
      ]),
    ),
    "category_limit",
  );
  const built = await buildCanonicalPlan(
    input("soft_glam", inventory, [
      pick(foundationB, "base_coverage"),
      pick(blush, "cheek_color"),
    ]),
  );
  assertEquals(
    built.snapshot.filter((item) => item.category === "foundation").map((
      item,
    ) => item.productId),
    [foundationB.id],
  );
});

Deno.test("no foundation owned: foundation is forbidden, not omitted", async () => {
  const inventory = [concealer, blush, lipstick];
  const built = await buildCanonicalPlan(
    input("full_glam", inventory, [
      pick(concealer, "spot_correction", "soft"),
      pick(blush, "cheek_color"),
      pick(lipstick, "lip_color"),
    ]),
  );
  const decision = built.plan.category_decisions.find((item) =>
    item.tutorial_category === "foundation"
  )!;
  assertEquals(decision.status, "not_owned");
  assertEquals(decision.omission_reason, null);
  assert(built.plan.forbidden_visual_categories.includes("foundation"));
  // The model may not claim an omission for something the user does not own.
  assertEquals(
    await violation(
      input("full_glam", inventory, [pick(blush, "cheek_color")], [
        { category: "foundation", reason: "shade_unsuitable" },
        { category: "concealer", reason: "shade_unsuitable" },
      ]),
    ),
    "omission_not_applicable",
  );
});

Deno.test("no concealer owned: concealer is forbidden", async () => {
  const built = await buildCanonicalPlan(
    input("bridal", [foundation, blush], [
      pick(foundation, "base_coverage"),
      pick(blush, "cheek_color"),
    ]),
  );
  assert(built.plan.forbidden_visual_categories.includes("concealer"));
  assertEquals(
    built.plan.category_decisions.find((item) =>
      item.tutorial_category === "concealer"
    )!.status,
    "not_owned",
  );
});

for (const style of ["natural", "everyday", "office"]) {
  Deno.test(`${style}: complexion is never forced`, async () => {
    assertEquals(STYLE_PROFILES[style].complexion_expectation, "skin_first");
    const built = await buildCanonicalPlan(
      input(style, [foundation, concealer, blush, lipstick], [
        pick(blush, "cheek_color", "soft"),
        pick(lipstick, "lip_color", "soft"),
      ], [
        { category: "foundation", reason: "style_not_required" },
        { category: "concealer", reason: "style_not_required" },
      ]),
    );
    assert(built.plan.forbidden_visual_categories.includes("foundation"));
    assert(built.plan.forbidden_visual_categories.includes("concealer"));
    assertEquals(
      built.plan.category_decisions.find((item) =>
        item.tutorial_category === "foundation"
      )!.omission_reason,
      "style_not_required",
    );
  });

  Deno.test(`${style}: selected complexion stays sheer or soft`, async () => {
    assertEquals(
      await violation(
        input(style, [foundation], [pick(foundation, "base_coverage")]),
      ),
      "skin_first_intensity",
    );
    const built = await buildCanonicalPlan(
      input(style, [foundation], [pick(foundation, "base_coverage", "sheer")]),
    );
    assertEquals(
      built.plan.selected_items[0].visible_intent,
      "subtle_allowed",
    );
  });
}

for (const style of ["full_glam", "bridal"]) {
  Deno.test(`${style}: an owned base may not be dropped by style alone`, async () => {
    const inventory = [foundation, concealer, blush];
    assertEquals(
      await violation(
        input(style, inventory, [pick(blush, "cheek_color")], [
          { category: "foundation", reason: "style_not_required" },
          { category: "concealer", reason: "shade_unsuitable" },
        ]),
      ),
      "perfected_base_omitted_by_style",
    );
    const built = await buildCanonicalPlan(
      input(style, inventory, [pick(blush, "cheek_color")], [
        { category: "foundation", reason: "shade_unsuitable" },
        { category: "concealer", reason: "finish_unsuitable" },
      ]),
    );
    assertEquals(
      built.plan.category_decisions.find((item) =>
        item.tutorial_category === "foundation"
      )!.omission_reason,
      "shade_unsuitable",
    );
  });
}

for (const style of ["soft_glam", "party", "date_night"]) {
  Deno.test(`${style}: glam intent is evaluated, not forced`, async () => {
    const inventory = [foundation, concealer, contour, highlighter, blush];
    // Every owned complexion category must carry an explicit decision.
    assertEquals(
      await violation(input(style, inventory, [pick(blush, "cheek_color")])),
      "missing_omission",
    );
    const built = await buildCanonicalPlan(
      input(style, inventory, [pick(blush, "cheek_color")], [
        { category: "foundation", reason: "style_not_required" },
        { category: "concealer", reason: "style_not_required" },
        { category: "contour_bronzer", reason: "style_not_required" },
        { category: "highlighter", reason: "style_not_required" },
      ]),
    );
    assertEquals(built.plan.allowed_visual_categories, ["blush"]);
  });
}

Deno.test("an omission for a selected category is refused", async () => {
  assertEquals(
    await violation(
      input("soft_glam", [foundation], [pick(foundation, "base_coverage")], [
        { category: "foundation", reason: "style_not_required" },
      ]),
    ),
    "omission_not_applicable",
  );
});

Deno.test("redundant_with_selected needs a selected complexion product", async () => {
  assertEquals(
    await violation(
      input("soft_glam", [concealer, blush], [pick(blush, "cheek_color")], [
        { category: "concealer", reason: "redundant_with_selected" },
      ]),
    ),
    "redundant_without_selection",
  );
  await buildCanonicalPlan(
    input("soft_glam", [foundation, concealer], [
      pick(foundation, "base_coverage"),
    ], [{ category: "concealer", reason: "redundant_with_selected" }]),
  );
});

Deno.test("allowed and forbidden partition all nine categories", async () => {
  const built = await buildCanonicalPlan(
    input("everyday", [blush, lipstick, eyebrow], [
      pick(lipstick, "lip_color", "soft"),
      pick(eyebrow, "brow_definition", "soft"),
      pick(blush, "cheek_color", "soft"),
    ]),
  );
  const {
    allowed_visual_categories: allowed,
    forbidden_visual_categories: forbidden,
  } = built.plan;
  assertEquals(allowed, ["blush", "eyebrows", "lips"]);
  assertEquals(
    [...allowed, ...forbidden].sort(),
    [...TUTORIAL_CATEGORIES].sort(),
  );
  assertEquals(allowed.filter((c) => forbidden.includes(c)), []);
});

Deno.test("visible intent is derived from role and intensity only", () => {
  assertEquals(deriveVisibleIntent("cheek_color", "sheer"), "subtle_allowed");
  assertEquals(deriveVisibleIntent("cheek_color", "soft"), "required_visible");
  assertEquals(deriveVisibleIntent("base_coverage", "soft"), "subtle_allowed");
  assertEquals(
    deriveVisibleIntent("base_coverage", "medium"),
    "required_visible",
  );
  assertEquals(
    deriveVisibleIntent("spot_correction", "bold"),
    "subtle_allowed",
  );
  assertEquals(deriveVisibleIntent("lip_topcoat", "bold"), "subtle_allowed");
  assertEquals(deriveVisibleIntent("lip_color", "soft"), "required_visible");
});

Deno.test("recommendation equals the plan's selections", async () => {
  const built = await buildCanonicalPlan(
    input("full_glam", fullKit, [...glamSelections].reverse()),
  );
  const { plan, recommendation } = built;
  assertEquals(
    recommendation.selections.map((item) => item.productId),
    plan.selected_items.map((item) => item.product_id),
  );
  plan.selected_items.forEach((item, index) => {
    const selection = recommendation.selections[index];
    assertEquals(selection.category, item.category_code);
    assertEquals(selection.colorHex, item.product_snapshot.colorHex);
    assertEquals(selection.finish, item.product_snapshot.finish);
    assertEquals(selection.intensity, item.application_intent.intensity);
    assertEquals(selection.placement, item.application_intent.placement);
  });
  assertEquals(recommendation.planId, plan.plan_id);
  assertEquals(recommendation.planVersion, KIT_MAKEUP_PLAN_VERSION);
  assertEquals(recommendation.overallIntensity, plan.overall_intensity);
});

Deno.test("snapshot is derived from the owned rows in plan order", async () => {
  const built = await buildCanonicalPlan(
    input("full_glam", fullKit, glamSelections),
  );
  assertEquals(
    built.snapshot,
    built.plan.selected_items.map((item) => item.product_snapshot),
  );
  const first = built.snapshot[0];
  assertEquals(Object.keys(first).sort(), [
    "category",
    "colorHex",
    "colorLabel",
    "finish",
    "foundationDepth",
    "foundationUndertone",
    "productId",
    "productName",
  ]);
  assertEquals(first, {
    productId: foundation.id,
    category: "foundation",
    productName: foundation.product_name,
    colorHex: foundation.color_hex,
    colorLabel: foundation.color_label,
    finish: foundation.finish,
    foundationDepth: "medium",
    foundationUndertone: "warm",
  });
});

Deno.test("the plan and its digest do not depend on the model's ordering", async () => {
  const a = await buildCanonicalPlan(
    input("full_glam", fullKit, glamSelections),
  );
  const b = await buildCanonicalPlan(
    input("full_glam", [...fullKit].reverse(), [...glamSelections].reverse()),
  );
  assertEquals(canonicalJson(a.plan), canonicalJson(b.plan));
  assertEquals(a.planDigest, b.planDigest);
});

Deno.test("any change to the plan changes its digest", async () => {
  const a = await buildCanonicalPlan(
    input("full_glam", fullKit, glamSelections),
  );
  const changed = glamSelections.map((item, index) =>
    index === 0 ? { ...item, intensity: "bold" as const } : item
  );
  const b = await buildCanonicalPlan(input("full_glam", fullKit, changed));
  assertNotEquals(a.planDigest, b.planDigest);
});

Deno.test("the role table covers every inventory category", () => {
  assertEquals(Object.keys(ROLE_RULES).length, 10);
  for (const rule of Object.values(ROLE_RULES)) {
    assert(rule.maximum >= 1 && rule.maximum <= rule.roles.length);
  }
  assertEquals(new Set(ALL_ROLES).size, ALL_ROLES.length);
});

Deno.test("an unsupported style is refused", async () => {
  assertEquals(
    await violation(input("grunge", [blush], [pick(blush, "cheek_color")])),
    "unsupported_style",
  );
});
