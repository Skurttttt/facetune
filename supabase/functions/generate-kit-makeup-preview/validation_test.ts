import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import type { CurrentKitProduct } from "./types.ts";
import { FunctionFailure } from "./types.ts";
import { normalizeAndValidateKitPreviewPlan } from "./validation.ts";

const ownerId = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
const productId = "11111111-1111-4111-8111-111111111111";
const current: CurrentKitProduct = {
  id: productId,
  user_id: ownerId,
  category: "lipstick",
  product_name: "Rose",
  color_hex: "#A45B67",
  color_label: "Muted rose",
  finish: "matte",
  foundation_depth: null,
  foundation_undertone: null,
};
const snapshot = [{
  productId,
  category: "lipstick",
  productName: "Rose",
  colorHex: "#A45B67",
  colorLabel: "Muted rose",
  finish: "matte",
  foundationDepth: null,
  foundationUndertone: null,
}];
const plan = {
  selections: [{
    productId,
    category: "lipstick",
    colorHex: "#A45B67",
    finish: "matte",
    placement: "Across the lips",
    technique: "Apply a thin even layer",
    intensity: "soft",
    reasoning: "Owned rose shade",
  }],
  categoryCoverage: [],
  overallIntensity: "soft",
  summary: "A simple owned-product look.",
};

Deno.test("normalizes an exact persisted plan against current ownership", () => {
  const result = normalizeAndValidateKitPreviewPlan(
    plan,
    snapshot,
    [current],
    ownerId,
  );
  assertEquals(result.selections[0].colorHex, "#A45B67");
  assertEquals(result.selections[0].finish, "matte");
  assertEquals(Object.hasOwn(result.selections[0], "reasoning"), false);
});

Deno.test("rejects a deleted selected product before generation", () => {
  const error = assertThrows(
    () => normalizeAndValidateKitPreviewPlan(plan, snapshot, [], ownerId),
    FunctionFailure,
  );
  assertEquals(error.status, 409);
  assertEquals(error.code, "inventory_changed");
});

Deno.test("rejects an edited color or finish before generation", () => {
  for (
    const changed of [
      { ...current, color_hex: "#FFFFFF" },
      { ...current, finish: "satin" },
    ]
  ) {
    const error = assertThrows(
      () =>
        normalizeAndValidateKitPreviewPlan(
          plan,
          snapshot,
          [changed],
          ownerId,
        ),
      FunctionFailure,
    );
    assertEquals(error.code, "inventory_changed");
  }
});

Deno.test("rejects substituted plan color and fabricated selection IDs", () => {
  for (
    const selection of [
      { ...plan.selections[0], colorHex: "#FFFFFF" },
      {
        ...plan.selections[0],
        productId: "22222222-2222-4222-8222-222222222222",
      },
    ]
  ) {
    const error = assertThrows(
      () =>
        normalizeAndValidateKitPreviewPlan(
          { ...plan, selections: [selection] },
          snapshot,
          [current],
          ownerId,
        ),
      FunctionFailure,
    );
    assertEquals(error.code, "invalid_kit_plan");
  }
});
