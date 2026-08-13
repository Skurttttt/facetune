import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  FunctionFailure,
  type KitProduct,
  type SelectedProduct,
} from "./types.ts";
import {
  assertProductsUnchanged,
  buildCategoryCoverage,
  parseAndValidateKitRecommendation,
  selectedProductAvailability,
} from "./validation.ts";

const lipstick: KitProduct = {
  id: "11111111-1111-4111-8111-111111111111",
  user_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
  category: "lipstick",
  product_name: "Nude lipstick",
  color_hex: "#B86F72",
  color_label: "Nude Rose",
  finish: "cream",
  foundation_depth: null,
  foundation_undertone: null,
};
const blush: KitProduct = {
  ...lipstick,
  id: "22222222-2222-4222-8222-222222222222",
  category: "blush",
  product_name: "Peach blush",
  color_hex: "#E69A7A",
  color_label: "Warm Peach",
  finish: "satin",
};

function selection(product = lipstick): SelectedProduct {
  return {
    productId: product.id,
    category: product.category,
    colorHex: product.color_hex,
    finish: product.finish,
    placement: "Apply to the lips",
    technique: "Blend in one even layer",
    intensity: "soft",
    reasoning: "Supports the selected style.",
  };
}

function response(selections: unknown[]) {
  return JSON.stringify({
    selections,
    overallIntensity: "soft",
    summary: "A soft look using owned products only.",
  });
}

Deno.test("accepts exact supplied product identity and stored attributes", () => {
  const plan = parseAndValidateKitRecommendation(
    response([selection(lipstick), selection(blush)]),
    [lipstick, blush],
  );
  assertEquals(plan.selections.map((item) => item.productId), [
    lipstick.id,
    blush.id,
  ]);
  assertEquals(
    plan.categoryCoverage.find((item) => item.category === "lipstick")?.status,
    "selected",
  );
  assertEquals(
    plan.categoryCoverage.find((item) => item.category === "foundation")
      ?.status,
    "unavailable",
  );
});

Deno.test("accepts a one-product, one-category kit", () => {
  const plan = parseAndValidateKitRecommendation(
    response([selection(lipstick)]),
    [lipstick],
  );
  assertEquals(plan.selections.length, 1);
  assertEquals(
    plan.categoryCoverage.filter((item) => item.status === "selected").map(
      (item) => item.category,
    ),
    ["lipstick"],
  );
});

Deno.test("multiple owned products in one category may leave some unused", () => {
  const secondLipstick = {
    ...lipstick,
    id: "33333333-3333-4333-8333-333333333333",
    color_hex: "#8A2635",
    finish: "matte",
  };
  const plan = parseAndValidateKitRecommendation(
    response([selection(secondLipstick)]),
    [lipstick, secondLipstick],
  );
  const coverage = plan.categoryCoverage.find((item) =>
    item.category === "lipstick"
  );
  assertEquals(coverage?.status, "selected");
  assertEquals(coverage?.selectedProductIds, [secondLipstick.id]);
});

Deno.test("partial kit distinguishes unavailable from owned but not required", () => {
  const coverage = buildCategoryCoverage(
    [lipstick, blush],
    [selection(lipstick)],
  );
  assertEquals(
    coverage.find((item) => item.category === "lipstick")?.status,
    "selected",
  );
  assertEquals(
    coverage.find((item) => item.category === "blush")?.status,
    "not_required",
  );
  for (
    const category of [
      "foundation",
      "concealer",
      "highlighter",
      "eyeshadow",
      "lip_gloss",
      "eyebrow",
      "eyeliner",
    ]
  ) {
    assertEquals(
      coverage.find((item) => item.category === category)?.status,
      "unavailable",
    );
  }
});

Deno.test("a reasonably complete kit remains valid without selecting everything", () => {
  const categories = [
    "foundation",
    "concealer",
    "blush",
    "highlighter",
    "eyeshadow",
    "lipstick",
    "eyebrow",
    "eyeliner",
  ];
  const inventory = categories.map((category, index) => ({
    ...lipstick,
    id: `0000000${index + 1}-0000-4000-8000-00000000000${index + 1}`,
    category,
  }));
  const chosen = [inventory[2], inventory[4], inventory[5]];
  const plan = parseAndValidateKitRecommendation(
    response(chosen.map((product) => selection(product))),
    inventory,
  );
  assertEquals(plan.selections.length, 3);
  assertEquals(
    plan.categoryCoverage.find((item) => item.category === "foundation")
      ?.status,
    "not_required",
  );
});

Deno.test("rejects a hallucinated or malicious product ID", () => {
  const malicious = {
    ...selection(),
    productId: "99999999-9999-4999-8999-999999999999",
  };
  const error = assertThrows(
    () => parseAndValidateKitRecommendation(response([malicious]), [lipstick]),
    FunctionFailure,
  );
  assertEquals(error.code, "fabricated_product");
});

Deno.test("rejects a selected product owned by another user", () => {
  const otherUsersProduct = {
    ...blush,
    user_id: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
  };
  // The authenticated inventory never contains cross-account rows because of
  // RLS, so referencing that ID is indistinguishable from fabrication.
  const error = assertThrows(
    () =>
      parseAndValidateKitRecommendation(
        response([selection(otherUsersProduct)]),
        [lipstick],
      ),
    FunctionFailure,
  );
  assertEquals(error.code, "fabricated_product");
});

Deno.test("rejects category, color, and finish substitutions", () => {
  for (
    const changed of [
      { ...selection(), category: "eyeshadow" },
      { ...selection(), colorHex: "#000000" },
      { ...selection(), finish: "matte" },
    ]
  ) {
    const error = assertThrows(
      () => parseAndValidateKitRecommendation(response([changed]), [lipstick]),
      FunctionFailure,
    );
    assertEquals(error.code, "product_mismatch");
  }
});

Deno.test("rejects duplicate IDs and unsupported extra fields", () => {
  assertThrows(() =>
    parseAndValidateKitRecommendation(
      response([selection(), selection()]),
      [lipstick, blush],
    )
  );
  assertThrows(() =>
    parseAndValidateKitRecommendation(
      response([{ ...selection(), userId: lipstick.user_id }]),
      [lipstick],
    )
  );
});

Deno.test("rejects malformed JSON and an empty selection", () => {
  assertThrows(() => parseAndValidateKitRecommendation("not-json", [lipstick]));
  assertThrows(() =>
    parseAndValidateKitRecommendation(response([]), [lipstick])
  );
});

Deno.test("empty kit has an intentional non-retryable validation error", () => {
  const error = assertThrows(
    () => parseAndValidateKitRecommendation(response([selection()]), []),
    FunctionFailure,
  );
  assertEquals(error.code, "empty_kit");
  assertEquals(error.retryable, false);
});

Deno.test("detects product deletion or mutation during the AI request", () => {
  const deleted = assertThrows(
    () => assertProductsUnchanged([lipstick.id], [lipstick], []),
    FunctionFailure,
  );
  assertEquals(deleted.code, "inventory_changed");
  const edited = assertThrows(
    () =>
      assertProductsUnchanged(
        [lipstick.id],
        [lipstick],
        [{ ...lipstick, color_hex: "#000000" }],
      ),
    FunctionFailure,
  );
  assertEquals(edited.code, "inventory_changed");
});

Deno.test("later use distinguishes available, deleted, and modified products", () => {
  const availability = selectedProductAvailability(
    [lipstick.id, blush.id],
    [lipstick, blush],
    [lipstick, { ...blush, finish: "matte" }],
  );
  assertEquals(availability, [
    { productId: lipstick.id, status: "available" },
    { productId: blush.id, status: "modified" },
  ]);
  assertEquals(
    selectedProductAvailability([lipstick.id], [lipstick], []),
    [{ productId: lipstick.id, status: "deleted" }],
  );
});
