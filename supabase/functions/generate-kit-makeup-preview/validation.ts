import type {
  CurrentKitProduct,
  KitPreviewSelection,
  KitProductSnapshot,
  NormalizedKitPreviewPlan,
} from "./types.ts";
import { FunctionFailure } from "./types.ts";

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const hexPattern = /^#[0-9A-F]{6}$/;
const intensities = new Set(["sheer", "soft", "medium", "bold"]);

function staleKit(): FunctionFailure {
  return new FunctionFailure(
    409,
    "inventory_changed",
    "A selected product was edited or removed. Create a new kit-based look.",
  );
}

function invalidPlan(): FunctionFailure {
  return new FunctionFailure(
    422,
    "invalid_kit_plan",
    "The saved kit-based makeup plan is invalid.",
  );
}

function object(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw invalidPlan();
  }
  return value as Record<string, unknown>;
}

function requiredText(
  value: Record<string, unknown>,
  key: string,
  maximum: number,
): string {
  const candidate = value[key];
  if (
    typeof candidate !== "string" || candidate.trim().length < 2 ||
    candidate.length > maximum
  ) throw invalidPlan();
  return candidate.trim();
}

function nullableText(value: unknown, maximum: number): string | null {
  if (value === null) return null;
  if (typeof value !== "string" || value.length > maximum) throw invalidPlan();
  return value;
}

export function normalizeAndValidateKitPreviewPlan(
  planValue: unknown,
  snapshotValue: unknown,
  currentProducts: CurrentKitProduct[],
  ownerId: string,
): NormalizedKitPreviewPlan {
  const plan = object(planValue);
  if (!Array.isArray(plan.selections) || plan.selections.length < 1) {
    throw invalidPlan();
  }
  if (!Array.isArray(snapshotValue) || snapshotValue.length < 1) {
    throw invalidPlan();
  }

  const snapshots = snapshotValue.map(parseSnapshot);
  const snapshotById = new Map(
    snapshots.map((snapshot) => [snapshot.productId, snapshot]),
  );
  const currentById = new Map(
    currentProducts.map((product) => [product.id, product]),
  );
  const seen = new Set<string>();
  const selections: KitPreviewSelection[] = plan.selections.map((value) => {
    const input = object(value);
    const productId = requiredText(input, "productId", 50);
    if (!uuidPattern.test(productId) || seen.has(productId)) {
      throw invalidPlan();
    }
    seen.add(productId);
    const snapshot = snapshotById.get(productId);
    if (!snapshot) throw invalidPlan();
    const category = requiredText(input, "category", 40);
    const colorHex = requiredText(input, "colorHex", 7);
    const finish = requiredText(input, "finish", 40);
    if (
      category !== snapshot.category || colorHex !== snapshot.colorHex ||
      finish !== snapshot.finish || !hexPattern.test(colorHex)
    ) throw invalidPlan();
    const intensity = input.intensity;
    if (typeof intensity !== "string" || !intensities.has(intensity)) {
      throw invalidPlan();
    }
    return {
      productId,
      category,
      colorHex,
      finish,
      placement: requiredText(input, "placement", 220),
      technique: requiredText(input, "technique", 220),
      intensity: intensity as KitPreviewSelection["intensity"],
    };
  });

  // Reconcile every selected snapshot with the active owner-scoped kit. This
  // happens immediately before generation so edited/deleted products cannot be
  // presented as currently owned.
  for (const selection of selections) {
    const snapshot = snapshotById.get(selection.productId)!;
    const current = currentById.get(selection.productId);
    if (
      !current || current.user_id !== ownerId ||
      current.category !== snapshot.category ||
      current.product_name !== snapshot.productName ||
      current.color_hex !== snapshot.colorHex ||
      current.color_label !== snapshot.colorLabel ||
      current.finish !== snapshot.finish ||
      current.foundation_depth !== snapshot.foundationDepth ||
      current.foundation_undertone !== snapshot.foundationUndertone
    ) throw staleKit();
  }

  const overallIntensity = plan.overallIntensity;
  if (
    typeof overallIntensity !== "string" ||
    !intensities.has(overallIntensity)
  ) throw invalidPlan();
  return {
    selections,
    overallIntensity:
      overallIntensity as NormalizedKitPreviewPlan["overallIntensity"],
  };
}

function parseSnapshot(value: unknown): KitProductSnapshot {
  const input = object(value);
  const productId = requiredText(input, "productId", 50);
  const colorHex = requiredText(input, "colorHex", 7);
  if (!uuidPattern.test(productId) || !hexPattern.test(colorHex)) {
    throw invalidPlan();
  }
  return {
    productId,
    category: requiredText(input, "category", 40),
    productName: nullableText(input.productName, 120),
    colorHex,
    colorLabel: nullableText(input.colorLabel, 80),
    finish: requiredText(input, "finish", 40),
    foundationDepth: nullableText(input.foundationDepth, 40),
    foundationUndertone: nullableText(input.foundationUndertone, 40),
  };
}
