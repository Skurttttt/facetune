/**
 * The canonical My Makeup Kit plan, contract `kit_makeup_plan_v1`.
 *
 * One plan governs a new My Makeup Kit look. The model proposes only the
 * choices that need judgement — which owned products, in which role, applied
 * how, and why an owned complexion product was left out. Everything the server
 * can compute is computed here and never taken from the model: the product
 * snapshot, the tutorial category, how visible each item must be, which
 * categories the preview may and may not show, and the per-category decisions.
 *
 * The recommendation and the snapshot persisted beside the plan are derived
 * from it, so the three cannot disagree. Changing any table or rule in this
 * file changes what a plan means and requires `kit_makeup_plan_v2`; nothing
 * here may be edited in place once plans exist.
 *
 * Pure: no I/O, no clock, no randomness. `plan_id` and `created_at` are
 * injected so the same inputs always produce the same plan and digest.
 */

import {
  INVENTORY_TO_TUTORIAL,
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "./tutorial_vocabulary.ts";

export const KIT_MAKEUP_PLAN_VERSION = "kit_makeup_plan_v1";

/** The preview prompt a v1 plan is rendered by. Pinned at plan creation so a
 * renderer can refuse a plan it does not implement. */
export const PLAN_PREVIEW_PROMPT_VERSION = "kit_makeup_preview_v2";

/** The validation contract a v1 plan is judged against. */
export const PLAN_VALIDATION_CONTRACT_VERSION = "kit_preview_validator_v1";

export const PLAN_SOURCE_MODE = "my_makeup_kit";

export const INTENSITIES = ["sheer", "soft", "medium", "bold"] as const;
export type Intensity = typeof INTENSITIES[number];

export const INVENTORY_CATEGORIES = [
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
] as const;
export type InventoryCategory = typeof INVENTORY_CATEGORIES[number];

/** Roles each inventory category may play, and how many items of it one plan
 * may hold. Two items of one tutorial category must play different roles. */
export const ROLE_RULES: Readonly<
  Record<InventoryCategory, { roles: readonly string[]; maximum: number }>
> = {
  foundation: { roles: ["base_coverage"], maximum: 1 },
  concealer: {
    roles: ["spot_correction", "under_eye_brightening"],
    maximum: 2,
  },
  contour_bronzer: { roles: ["contour_sculpt", "bronze_warmth"], maximum: 1 },
  blush: { roles: ["cheek_color"], maximum: 1 },
  highlighter: { roles: ["highlight"], maximum: 1 },
  eyebrow: { roles: ["brow_definition"], maximum: 1 },
  eyeshadow: { roles: ["lid_wash", "crease_depth", "accent"], maximum: 3 },
  eyeliner: { roles: ["lash_line_definition"], maximum: 1 },
  lipstick: { roles: ["lip_color"], maximum: 1 },
  lip_gloss: { roles: ["lip_color", "lip_topcoat"], maximum: 1 },
};

/** Every role, in table order. Used for the model's response schema and for a
 * deterministic item order within one category. */
export const ALL_ROLES: readonly string[] = [
  ...new Set(Object.values(ROLE_RULES).flatMap((rule) => rule.roles)),
];

/** Roles whose colour defines the look, so they must show even at `soft`. */
const COLOR_DEFINING_ROLES = new Set([
  "cheek_color",
  "lid_wash",
  "crease_depth",
  "lash_line_definition",
  "lip_color",
]);

/** Roles that stay subtle at any intensity. */
const ALWAYS_SUBTLE_ROLES = new Set([
  "spot_correction",
  "under_eye_brightening",
  "lip_topcoat",
]);

export type VisibleIntent = "required_visible" | "subtle_allowed";

/** The complexion group the plan must explicitly decide on. */
export const COMPLEXION_CATEGORIES = [
  "foundation",
  "concealer",
  "contour_bronzer",
  "highlighter",
] as const;
export type ComplexionCategory = typeof COMPLEXION_CATEGORIES[number];

export const OMISSION_REASONS = [
  "style_not_required",
  "shade_unsuitable",
  "finish_unsuitable",
  "redundant_with_selected",
] as const;
export type OmissionReason = typeof OMISSION_REASONS[number];

export type ComplexionExpectation = "perfected" | "even" | "skin_first";

/** What each style expects of the complexion. A property of the style, not a
 * product rule: nothing here forces a product into a look. */
export const STYLE_PROFILES: Readonly<
  Record<string, { complexion_expectation: ComplexionExpectation }>
> = {
  full_glam: { complexion_expectation: "perfected" },
  bridal: { complexion_expectation: "perfected" },
  soft_glam: { complexion_expectation: "even" },
  party: { complexion_expectation: "even" },
  date_night: { complexion_expectation: "even" },
  old_money: { complexion_expectation: "even" },
  natural: { complexion_expectation: "skin_first" },
  everyday: { complexion_expectation: "skin_first" },
  office: { complexion_expectation: "skin_first" },
  korean: { complexion_expectation: "skin_first" },
  clean_girl: { complexion_expectation: "skin_first" },
  no_makeup_makeup: { complexion_expectation: "skin_first" },
};

/** Categories whose intensity is capped at `soft` in a skin-first look. */
const SKIN_FIRST_CAPPED = new Set<string>([
  "foundation",
  "concealer",
  "contour_bronzer",
  "highlighter",
]);

/** Complexion categories a `perfected` look may not drop merely by style. */
const PERFECTED_BASE = new Set<string>(["foundation", "concealer"]);

const MAXIMUM_SELECTIONS = 13;

/** An owned inventory row, exactly as read under the caller's RLS. */
export type PlanInventoryProduct = {
  id: string;
  user_id: string;
  category: string;
  product_name: string | null;
  color_hex: string;
  color_label: string | null;
  finish: string;
  foundation_depth: string | null;
  foundation_undertone: string | null;
};

/** The model's proposal, already shape-checked. */
export type DraftSelection = {
  productId: string;
  category: string;
  role: string;
  placement: string;
  technique: string;
  intensity: Intensity;
  reasoning: string;
};

export type DraftOmission = { category: string; reason: string };

export type DraftPlan = {
  selections: DraftSelection[];
  complexionOmissions: DraftOmission[];
  overallIntensity: Intensity;
  summary: string;
};

/** The v2-shaped snapshot element. Unchanged so the Tutorial resolver and the
 * manifest's product-backing read a plan-backed look exactly as a v2 look. */
export type ProductSnapshot = {
  productId: string;
  category: string;
  productName: string | null;
  colorHex: string;
  colorLabel: string | null;
  finish: string;
  foundationDepth: string | null;
  foundationUndertone: string | null;
};

export type PlanSelectedItem = {
  category_code: InventoryCategory;
  tutorial_category: TutorialCategory;
  product_id: string;
  product_snapshot: ProductSnapshot;
  intended_role: string;
  visible_intent: VisibleIntent;
  application_intent: {
    placement: string;
    technique: string;
    intensity: Intensity;
  };
};

export type CategoryDecision = {
  tutorial_category: TutorialCategory;
  status: "selected" | "owned_not_selected" | "not_owned";
  product_ids: string[];
  omission_reason: OmissionReason | null;
};

export type CanonicalPlan = {
  plan_id: string;
  plan_version: typeof KIT_MAKEUP_PLAN_VERSION;
  source_mode: typeof PLAN_SOURCE_MODE;
  analysis_id: string;
  style_code: string;
  style_profile: { complexion_expectation: ComplexionExpectation };
  created_at: string;
  overall_intensity: Intensity;
  selected_items: PlanSelectedItem[];
  category_decisions: CategoryDecision[];
  allowed_visual_categories: TutorialCategory[];
  forbidden_visual_categories: TutorialCategory[];
  considered_product_ids: string[];
  recommendation_prompt_version: string;
  preview_prompt_version: typeof PLAN_PREVIEW_PROMPT_VERSION;
  validation_contract_version: typeof PLAN_VALIDATION_CONTRACT_VERSION;
};

/** The persisted recommendation for a plan-backed look: a projection of the
 * plan in the v2 `recommendation_json` shape, plus the plan's identity. */
export type PlanRecommendation = {
  selections: Array<{
    productId: string;
    category: string;
    colorHex: string;
    finish: string;
    placement: string;
    technique: string;
    intensity: Intensity;
    reasoning: string;
  }>;
  categoryCoverage: Array<{
    category: string;
    status: "selected" | "unavailable" | "not_required";
    selectedProductIds: string[];
  }>;
  overallIntensity: Intensity;
  summary: string;
  planId: string;
  planVersion: typeof KIT_MAKEUP_PLAN_VERSION;
};

export type BuiltPlan = {
  plan: CanonicalPlan;
  planDigest: string;
  recommendation: PlanRecommendation;
  snapshot: ProductSnapshot[];
};

/** A plan the rules refuse. `code` is a sanitized token safe for logs. */
export class PlanViolation extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** How visible an item must be, from its role and intensity alone. */
export function deriveVisibleIntent(
  role: string,
  intensity: Intensity,
): VisibleIntent {
  if (intensity === "sheer") return "subtle_allowed";
  if (ALWAYS_SUBTLE_ROLES.has(role)) return "subtle_allowed";
  if (intensity === "soft") {
    return COLOR_DEFINING_ROLES.has(role)
      ? "required_visible"
      : "subtle_allowed";
  }
  return "required_visible";
}

export type BuildPlanInput = {
  planId: string;
  createdAt: string;
  analysisId: string;
  styleCode: string;
  recommendationPromptVersion: string;
  inventory: PlanInventoryProduct[];
  draft: DraftPlan;
};

/**
 * Validates the model's draft against the plan rules and derives the
 * canonical plan, its recommendation projection, and its snapshot.
 *
 * Throws [PlanViolation] when the draft breaks a rule. The caller decides how
 * to surface it; a violation is a bad model answer, never a user error.
 */
export async function buildCanonicalPlan(
  input: BuildPlanInput,
): Promise<BuiltPlan> {
  const profile = STYLE_PROFILES[input.styleCode];
  if (!profile) throw new PlanViolation("unsupported_style");
  const { draft, inventory } = input;
  const byId = new Map(inventory.map((product) => [product.id, product]));
  if (
    draft.selections.length < 1 ||
    draft.selections.length > Math.min(MAXIMUM_SELECTIONS, inventory.length)
  ) throw new PlanViolation("selection_count");

  const seenProducts = new Set<string>();
  const seenRoles = new Set<string>();
  const perCategory = new Map<string, number>();
  const items: Array<PlanSelectedItem & { reasoning: string }> = [];
  for (const selection of draft.selections) {
    const product = byId.get(selection.productId);
    if (!product) throw new PlanViolation("fabricated_product");
    if (seenProducts.has(product.id)) {
      throw new PlanViolation("duplicate_product");
    }
    seenProducts.add(product.id);
    if (selection.category !== product.category) {
      throw new PlanViolation("category_mismatch");
    }
    const category = product.category as InventoryCategory;
    const rule = ROLE_RULES[category];
    if (!rule) throw new PlanViolation("unsupported_category");
    if (!rule.roles.includes(selection.role)) {
      throw new PlanViolation("invalid_role");
    }
    const count = (perCategory.get(category) ?? 0) + 1;
    if (count > rule.maximum) throw new PlanViolation("category_limit");
    perCategory.set(category, count);
    const tutorialCategory = INVENTORY_TO_TUTORIAL[category];
    const roleKey = `${tutorialCategory}:${selection.role}`;
    if (seenRoles.has(roleKey)) throw new PlanViolation("duplicate_role");
    seenRoles.add(roleKey);
    if (!INTENSITIES.includes(selection.intensity)) {
      throw new PlanViolation("invalid_intensity");
    }
    if (
      profile.complexion_expectation === "skin_first" &&
      SKIN_FIRST_CAPPED.has(category) &&
      (selection.intensity === "medium" || selection.intensity === "bold")
    ) throw new PlanViolation("skin_first_intensity");
    items.push({
      category_code: category,
      tutorial_category: tutorialCategory,
      product_id: product.id,
      product_snapshot: snapshotOf(product),
      intended_role: selection.role,
      visible_intent: deriveVisibleIntent(selection.role, selection.intensity),
      application_intent: {
        placement: selection.placement,
        technique: selection.technique,
        intensity: selection.intensity,
      },
      reasoning: selection.reasoning,
    });
  }
  if (seenRoles.has("lips:lip_topcoat") && !seenRoles.has("lips:lip_color")) {
    throw new PlanViolation("topcoat_without_color");
  }

  const ownedCategories = new Set(inventory.map((product) => product.category));
  const selectedCategories = new Set(items.map((item) => item.category_code));
  const omissions = validateOmissions(
    draft.complexionOmissions,
    ownedCategories,
    selectedCategories,
    profile.complexion_expectation,
  );

  items.sort(compareItems);
  const selectedItems: PlanSelectedItem[] = items.map(
    ({ reasoning: _reasoning, ...item }) => item,
  );
  const allowed = TUTORIAL_CATEGORIES.filter((category) =>
    selectedItems.some((item) => item.tutorial_category === category)
  );
  const forbidden = TUTORIAL_CATEGORIES.filter((category) =>
    !allowed.includes(category)
  );

  const plan: CanonicalPlan = {
    plan_id: input.planId,
    plan_version: KIT_MAKEUP_PLAN_VERSION,
    source_mode: PLAN_SOURCE_MODE,
    analysis_id: input.analysisId,
    style_code: input.styleCode,
    style_profile: {
      complexion_expectation: profile.complexion_expectation,
    },
    created_at: input.createdAt,
    overall_intensity: draft.overallIntensity,
    selected_items: selectedItems,
    category_decisions: TUTORIAL_CATEGORIES.map((category) =>
      categoryDecision(category, selectedItems, ownedCategories, omissions)
    ),
    allowed_visual_categories: allowed,
    forbidden_visual_categories: forbidden,
    considered_product_ids: inventory.map((product) => product.id).sort(),
    recommendation_prompt_version: input.recommendationPromptVersion,
    preview_prompt_version: PLAN_PREVIEW_PROMPT_VERSION,
    validation_contract_version: PLAN_VALIDATION_CONTRACT_VERSION,
  };
  const reasoningById = new Map(
    items.map((item) => [item.product_id, item.reasoning]),
  );
  return {
    plan,
    planDigest: await planDigest(plan),
    recommendation: {
      selections: selectedItems.map((item) => ({
        productId: item.product_id,
        category: item.category_code,
        colorHex: item.product_snapshot.colorHex,
        finish: item.product_snapshot.finish,
        placement: item.application_intent.placement,
        technique: item.application_intent.technique,
        intensity: item.application_intent.intensity,
        reasoning: reasoningById.get(item.product_id)!,
      })),
      categoryCoverage: INVENTORY_CATEGORIES.map((category) => {
        const selectedProductIds = selectedItems
          .filter((item) => item.category_code === category)
          .map((item) => item.product_id);
        return {
          category,
          status: selectedProductIds.length > 0
            ? "selected"
            : ownedCategories.has(category)
            ? "not_required"
            : "unavailable",
          selectedProductIds,
        };
      }),
      overallIntensity: draft.overallIntensity,
      summary: draft.summary,
      planId: plan.plan_id,
      planVersion: KIT_MAKEUP_PLAN_VERSION,
    },
    snapshot: selectedItems.map((item) => item.product_snapshot),
  };
}

function validateOmissions(
  omissions: DraftOmission[],
  owned: Set<string>,
  selected: Set<string>,
  expectation: ComplexionExpectation,
): Map<string, OmissionReason> {
  const reasons = new Map<string, OmissionReason>();
  for (const omission of omissions) {
    if (
      !(COMPLEXION_CATEGORIES as readonly string[]).includes(omission.category)
    ) throw new PlanViolation("invalid_omission_category");
    if (!(OMISSION_REASONS as readonly string[]).includes(omission.reason)) {
      throw new PlanViolation("invalid_omission_reason");
    }
    if (reasons.has(omission.category)) {
      throw new PlanViolation("duplicate_omission");
    }
    if (!owned.has(omission.category) || selected.has(omission.category)) {
      throw new PlanViolation("omission_not_applicable");
    }
    if (
      expectation === "perfected" && PERFECTED_BASE.has(omission.category) &&
      omission.reason === "style_not_required"
    ) throw new PlanViolation("perfected_base_omitted_by_style");
    if (
      omission.reason === "redundant_with_selected" &&
      !COMPLEXION_CATEGORIES.some((category) => selected.has(category))
    ) throw new PlanViolation("redundant_without_selection");
    reasons.set(omission.category, omission.reason as OmissionReason);
  }
  for (const category of COMPLEXION_CATEGORIES) {
    if (
      owned.has(category) && !selected.has(category) && !reasons.has(category)
    ) {
      throw new PlanViolation("missing_omission");
    }
  }
  return reasons;
}

function categoryDecision(
  category: TutorialCategory,
  items: PlanSelectedItem[],
  owned: Set<string>,
  omissions: Map<string, OmissionReason>,
): CategoryDecision {
  const productIds = items
    .filter((item) => item.tutorial_category === category)
    .map((item) => item.product_id);
  if (productIds.length > 0) {
    return {
      tutorial_category: category,
      status: "selected",
      product_ids: productIds,
      omission_reason: null,
    };
  }
  const isOwned = Object.entries(INVENTORY_TO_TUTORIAL).some((
    [inventory, tutorial],
  ) => tutorial === category && owned.has(inventory));
  return {
    tutorial_category: category,
    status: isOwned ? "owned_not_selected" : "not_owned",
    product_ids: [],
    omission_reason: isOwned ? omissions.get(category) ?? null : null,
  };
}

/** Deterministic item order: tutorial order, then role-table order, then id,
 * so the model's ordering never changes the plan or its digest. */
function compareItems(a: PlanSelectedItem, b: PlanSelectedItem): number {
  const byCategory = TUTORIAL_CATEGORIES.indexOf(a.tutorial_category) -
    TUTORIAL_CATEGORIES.indexOf(b.tutorial_category);
  if (byCategory !== 0) return byCategory;
  const byRole = ALL_ROLES.indexOf(a.intended_role) -
    ALL_ROLES.indexOf(b.intended_role);
  if (byRole !== 0) return byRole;
  return a.product_id < b.product_id ? -1 : a.product_id > b.product_id ? 1 : 0;
}

function snapshotOf(product: PlanInventoryProduct): ProductSnapshot {
  return {
    productId: product.id,
    category: product.category,
    productName: product.product_name,
    colorHex: product.color_hex,
    colorLabel: product.color_label,
    finish: product.finish,
    foundationDepth: product.foundation_depth,
    foundationUndertone: product.foundation_undertone,
  };
}

/** JSON with object keys sorted at every level; arrays keep their order. */
export function canonicalJson(value: unknown): string {
  if (Array.isArray(value)) {
    return `[${value.map(canonicalJson).join(",")}]`;
  }
  if (value !== null && typeof value === "object") {
    const entries = Object.keys(value as Record<string, unknown>).sort().map(
      (key) =>
        `${JSON.stringify(key)}:${
          canonicalJson((value as Record<string, unknown>)[key])
        }`,
    );
    return `{${entries.join(",")}}`;
  }
  return JSON.stringify(value);
}

/** SHA-256 of the plan's canonical JSON, lowercase hex. */
export async function planDigest(plan: CanonicalPlan): Promise<string> {
  const bytes = new TextEncoder().encode(canonicalJson(plan));
  const hash = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return [...hash].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}
