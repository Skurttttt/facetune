import type {
  CategoryCoverage,
  KitProduct,
  KitRecommendationPlan,
  SelectedProduct,
  SelectedProductAvailability,
} from "./types.ts";
import { FunctionFailure } from "./types.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const hexPattern = /^#[0-9A-F]{6}$/;
const intensities = new Set(["sheer", "soft", "medium", "bold"]);
const allowedKeys = new Set([
  "productId",
  "category",
  "colorHex",
  "finish",
  "placement",
  "technique",
  "intensity",
  "reasoning",
]);
export const supportedCategories = [
  "foundation",
  "concealer",
  "blush",
  "highlighter",
  "eyeshadow",
  "lipstick",
  "lip_gloss",
  "contour_bronzer",
  "eyebrow",
  "eyeliner",
] as const;
const supportedCategorySet = new Set<string>(supportedCategories);

function invalid(code = "invalid_ai_response"): FunctionFailure {
  return new FunctionFailure(
    502,
    code,
    "The kit recommendation service returned invalid product selections.",
    true,
  );
}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalid();
  }
  return value as Record<string, unknown>;
}

function text(
  input: Record<string, unknown>,
  key: string,
  max: number,
): string {
  const value = input[key];
  if (
    typeof value !== "string" || value.trim().length < 2 || value.length > max
  ) {
    throw invalid();
  }
  return value.trim();
}

export function parseAndValidateKitRecommendation(
  value: string,
  inventory: KitProduct[],
): KitRecommendationPlan {
  if (inventory.length === 0) {
    throw new FunctionFailure(
      422,
      "empty_kit",
      "Add at least one product to My Makeup Kit first.",
    );
  }
  if (
    inventory.some((product) => !supportedCategorySet.has(product.category))
  ) {
    throw new FunctionFailure(
      422,
      "unsupported_inventory_category",
      "Your makeup kit contains an unsupported product category.",
    );
  }
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
  const root = record(decoded);
  if (
    Object.keys(root).length !== 3 ||
    !Object.hasOwn(root, "selections") ||
    !Object.hasOwn(root, "overallIntensity") ||
    !Object.hasOwn(root, "summary") ||
    !Array.isArray(root.selections) ||
    root.selections.length < 1 ||
    root.selections.length > Math.min(20, inventory.length)
  ) throw invalid();

  const byId = new Map(inventory.map((product) => [product.id, product]));
  const seen = new Set<string>();
  const selections: SelectedProduct[] = root.selections.map((value) => {
    const input = record(value);
    if (
      Object.keys(input).length !== allowedKeys.size ||
      Object.keys(input).some((key) => !allowedKeys.has(key))
    ) throw invalid();
    const productId = text(input, "productId", 50);
    if (!uuidPattern.test(productId) || seen.has(productId)) {
      throw invalid("fabricated_product");
    }
    seen.add(productId);
    const product = byId.get(productId);
    if (!product) throw invalid("fabricated_product");
    const category = text(input, "category", 40);
    const colorHex = text(input, "colorHex", 7);
    const finish = text(input, "finish", 40);
    if (
      category !== product.category ||
      colorHex !== product.color_hex ||
      !hexPattern.test(colorHex) ||
      finish !== product.finish
    ) throw invalid("product_mismatch");
    const intensity = input.intensity;
    if (typeof intensity !== "string" || !intensities.has(intensity)) {
      throw invalid();
    }
    return {
      productId,
      category,
      colorHex,
      finish,
      placement: text(input, "placement", 220),
      technique: text(input, "technique", 220),
      intensity: intensity as SelectedProduct["intensity"],
      reasoning: text(input, "reasoning", 240),
    };
  });
  const overall = root.overallIntensity;
  if (typeof overall !== "string" || !intensities.has(overall)) throw invalid();
  return {
    selections,
    categoryCoverage: buildCategoryCoverage(inventory, selections),
    overallIntensity: overall as KitRecommendationPlan["overallIntensity"],
    summary: text(root, "summary", 300),
  };
}

export function buildCategoryCoverage(
  inventory: KitProduct[],
  selections: SelectedProduct[],
): CategoryCoverage[] {
  const owned = new Set(inventory.map((product) => product.category));
  const selectedByCategory = new Map<string, string[]>();
  for (const selection of selections) {
    selectedByCategory.set(selection.category, [
      ...(selectedByCategory.get(selection.category) ?? []),
      selection.productId,
    ]);
  }
  return supportedCategories.map((category) => {
    const selectedProductIds = selectedByCategory.get(category) ?? [];
    return {
      category,
      status: selectedProductIds.length > 0
        ? "selected"
        : owned.has(category)
        ? "not_required"
        : "unavailable",
      selectedProductIds,
    };
  });
}

/// Reconciles an immutable recommendation snapshot against the active kit when
/// reopening or using it later. Historical advice remains understandable, but
/// callers can prevent a deleted/edited product being presented as currently
/// available.
export function selectedProductAvailability(
  selectedIds: string[],
  snapshot: KitProduct[],
  current: KitProduct[],
): SelectedProductAvailability[] {
  const before = new Map(snapshot.map((product) => [product.id, product]));
  const after = new Map(current.map((product) => [product.id, product]));
  return selectedIds.map((productId) => {
    const original = before.get(productId);
    const live = after.get(productId);
    if (!live) return { productId, status: "deleted" };
    const unchanged = original != null &&
      original.user_id === live.user_id &&
      original.category === live.category &&
      original.color_hex === live.color_hex &&
      original.finish === live.finish &&
      original.foundation_depth === live.foundation_depth &&
      original.foundation_undertone === live.foundation_undertone;
    return { productId, status: unchanged ? "available" : "modified" };
  });
}

export function assertProductsUnchanged(
  selectedIds: string[],
  original: KitProduct[],
  current: KitProduct[],
): void {
  const before = new Map(original.map((product) => [product.id, product]));
  const after = new Map(current.map((product) => [product.id, product]));
  for (const id of selectedIds) {
    const a = before.get(id);
    const b = after.get(id);
    if (
      !a || !b || a.user_id !== b.user_id || a.category !== b.category ||
      a.color_hex !== b.color_hex || a.finish !== b.finish ||
      a.foundation_depth !== b.foundation_depth ||
      a.foundation_undertone !== b.foundation_undertone
    ) {
      throw new FunctionFailure(
        409,
        "inventory_changed",
        "Your makeup kit changed while the look was being created. Please try again.",
        true,
      );
    }
  }
}
