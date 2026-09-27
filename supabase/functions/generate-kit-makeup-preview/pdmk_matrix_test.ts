/**
 * PDMK-8 — the structural matrix: 8 styles × 9 kit compositions.
 *
 * Each cell builds a plan through the real rules, from a draft written the way
 * the model is instructed to write one, then proves every invariant that does
 * not need a live model: owned-only selection, a stable plan, recommendation
 * and snapshot equal to the plan, a preview prompt that is exactly the plan's
 * constraints, validator expectations that partition the categories, readiness
 * backing equal to the plan, a stored plan that verifies, and a route to v2.
 */
import { assert, assertEquals } from "jsr:@std/assert@1";

import { productBackedCategories } from "../analyze-tutorial-manifest-v4/validation.ts";
import {
  buildCanonicalPlan,
  COMPLEXION_CATEGORIES,
  type DraftOmission,
  type DraftPlan,
  type DraftSelection,
  type Intensity,
  type PlanInventoryProduct,
  ROLE_RULES,
  STYLE_PROFILES,
  verifyStoredPlan,
} from "../_shared/kit_makeup_plan.ts";
import { TUTORIAL_CATEGORIES } from "../_shared/tutorial_vocabulary.ts";
import { resolvePreviewRoute } from "./plan_route.ts";
import { ABSENCE_RULES, kitMakeupPreviewV2Prompt } from "./prompt_v2.ts";
import { expectations } from "./validator.ts";

const owner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const STYLES = [
  "soft_glam",
  "party",
  "date_night",
  "bridal",
  "full_glam",
  "natural",
  "everyday",
  "office",
];

let serial = 0;
function product(category: string, extra: Partial<PlanInventoryProduct> = {}) {
  serial++;
  const hex = (0x100000 + serial * 0x1f3d).toString(16).slice(-6).toUpperCase();
  return {
    id: `${serial.toString().padStart(8, "0")}-0000-4000-8000-000000000000`,
    user_id: owner,
    category,
    product_name: `Product ${serial}`,
    color_hex: `#${hex}`,
    color_label: null,
    finish: category === "lip_gloss" ? "glossy" : "satin",
    foundation_depth: category === "foundation" ? "medium" : null,
    foundation_undertone: category === "foundation" ? "warm" : null,
    ...extra,
  } satisfies PlanInventoryProduct;
}

const FULL = [
  "foundation",
  "concealer",
  "contour_bronzer",
  "blush",
  "highlighter",
  "eyebrow",
  "eyeshadow",
  "eyeliner",
  "lipstick",
];

const KITS: Record<string, () => PlanInventoryProduct[]> = {
  complete: () => FULL.map((category) => product(category)),
  no_foundation: () =>
    FULL.filter((c) => c !== "foundation").map((c) => product(c)),
  no_concealer: () =>
    FULL.filter((c) => c !== "concealer").map((c) => product(c)),
  neither: () =>
    FULL.filter((c) => c !== "foundation" && c !== "concealer").map((c) =>
      product(c)
    ),
  no_contour_bronzer: () =>
    FULL.filter((c) => c !== "contour_bronzer").map((c) => product(c)),
  no_highlighter: () =>
    FULL.filter((c) => c !== "highlighter").map((c) => product(c)),
  multiple_foundations: () => [
    ...FULL.map((c) => product(c)),
    product("foundation", { foundation_depth: "tan" }),
  ],
  multiple_lip_products: () => [
    ...FULL.map((c) => product(c)),
    product("lipstick"),
    product("lip_gloss"),
  ],
  minimal: () => [product("lipstick")],
};

/**
 * Writes a draft the way the model is instructed: at most one product per
 * category (first owned), the role table's first role, a gloss topcoat over a
 * lipstick, style-appropriate complexion choices, sheer/soft complexion in
 * skin-first styles, and an explicit omission for every owned complexion
 * category left out.
 */
function draftFor(style: string, inventory: PlanInventoryProduct[]): DraftPlan {
  const expectation = STYLE_PROFILES[style].complexion_expectation;
  const skinFirst = expectation === "skin_first";
  const selections: DraftSelection[] = [];
  const omissions: DraftOmission[] = [];
  const seen = new Set<string>();
  for (const item of inventory) {
    if (seen.has(item.category)) continue;
    seen.add(item.category);
    const complexion = (COMPLEXION_CATEGORIES as readonly string[]).includes(
      item.category,
    );
    // Skin-first looks leave foundation and concealer out; every other
    // style uses what it owns.
    if (
      skinFirst &&
      (item.category === "foundation" || item.category === "concealer")
    ) {
      omissions.push({ category: item.category, reason: "style_not_required" });
      continue;
    }
    const lipGlossOverLipstick = item.category === "lip_gloss" &&
      inventory.some((p) => p.category === "lipstick");
    const intensity: Intensity = skinFirst && complexion
      ? "soft"
      : skinFirst
      ? "soft"
      : "medium";
    selections.push({
      productId: item.id,
      category: item.category,
      role: lipGlossOverLipstick
        ? "lip_topcoat"
        : ROLE_RULES[item.category as keyof typeof ROLE_RULES].roles[0],
      placement: "Where the look needs it",
      technique: "Build in thin layers",
      intensity,
      reasoning: "Suits the style.",
    });
  }
  return {
    // The model returns items in any order; the plan must not care.
    selections: selections.reverse(),
    complexionOmissions: omissions,
    overallIntensity: skinFirst ? "soft" : "medium",
    summary: "A look built from owned products.",
  };
}

for (const style of STYLES) {
  for (const [kit, make] of Object.entries(KITS)) {
    Deno.test(`matrix: ${style} × ${kit}`, async () => {
      const inventory = make();
      const draft = draftFor(style, inventory);
      const input = {
        planId: "99999999-9999-4999-8999-999999999999",
        createdAt: "2026-09-27T00:00:00.000Z",
        analysisId: "88888888-8888-4888-8888-888888888888",
        styleCode: style,
        recommendationPromptVersion: "kit_makeup_recommendation_v3",
        inventory,
        draft,
      };
      const built = await buildCanonicalPlan(input);
      const { plan } = built;
      const owned = new Map(inventory.map((p) => [p.id, p]));

      // Owned only, and every snapshot copied from the owned row.
      for (const item of plan.selected_items) {
        const row = owned.get(item.product_id);
        assert(row, "selected product is owned");
        assertEquals(item.product_snapshot.colorHex, row.color_hex);
        assertEquals(item.product_snapshot.category, row.category);
      }

      // Stable: the model's ordering never changes the plan or its digest.
      const again = await buildCanonicalPlan({
        ...input,
        inventory: [...inventory].reverse(),
        draft: { ...draft, selections: [...draft.selections].reverse() },
      });
      assertEquals(again.planDigest, built.planDigest);

      // Recommendation and snapshot equal the plan.
      assertEquals(
        built.recommendation.selections.map((s) => s.productId),
        plan.selected_items.map((i) => i.product_id),
      );
      assertEquals(
        built.snapshot,
        plan.selected_items.map((i) => i.product_snapshot),
      );

      // Skin-first styles never force complexion products.
      if (STYLE_PROFILES[style].complexion_expectation === "skin_first") {
        assertEquals(
          plan.selected_items.some((i) =>
            i.category_code === "foundation" || i.category_code === "concealer"
          ),
          false,
        );
      }

      // The preview prompt is exactly the plan's constraints.
      const prompt = kitMakeupPreviewV2Prompt(plan, 1);
      for (const item of plan.selected_items) {
        assert(prompt.includes(item.product_snapshot.colorHex));
      }
      for (const product of inventory) {
        if (!plan.selected_items.some((i) => i.product_id === product.id)) {
          assertEquals(prompt.includes(product.color_hex), false);
          assertEquals(prompt.includes(product.id), false);
        }
        assertEquals(prompt.includes(product.product_name ?? "\u0000"), false);
      }
      for (const category of TUTORIAL_CATEGORIES) {
        assertEquals(
          prompt.includes(ABSENCE_RULES[category]),
          plan.forbidden_visual_categories.includes(category),
          `absence rule for ${category}`,
        );
      }

      // The validator's expectations partition all nine categories.
      const expected = expectations(plan);
      assertEquals(expected.size, TUTORIAL_CATEGORIES.length);
      for (const category of TUTORIAL_CATEGORIES) {
        assertEquals(
          expected.get(category) === "forbidden",
          plan.forbidden_visual_categories.includes(category),
        );
      }

      // Readiness backing is the snapshot, and it equals the plan.
      assertEquals(
        [...productBackedCategories(built.snapshot)].sort(),
        [...plan.allowed_visual_categories].sort(),
      );

      // The stored plan verifies and routes to v2.
      await verifyStoredPlan(structuredClone(plan), built.planDigest);
      const route = await resolvePreviewRoute({
        plan_id: plan.plan_id,
        plan_json: structuredClone(plan),
        plan_digest: built.planDigest,
        analysis_id: plan.analysis_id,
        makeup_style: style,
        product_snapshot_json: structuredClone(built.snapshot),
      });
      assertEquals(route.kind, "plan_v2");
    });
  }
}
