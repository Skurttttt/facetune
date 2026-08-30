import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  parseManifestResponse,
  productBackedCategories,
  resolveManifest,
} from "./validation.ts";
import {
  FunctionFailure,
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "./types.ts";

type Presence = "present" | "absent" | "uncertain";

function response(
  overrides: Partial<Record<TutorialCategory, Presence>> = {},
  fallback: Presence = "absent",
): string {
  return JSON.stringify(
    Object.fromEntries(
      TUTORIAL_CATEGORIES.map((category) => [
        category,
        {
          presence: overrides[category] ?? fallback,
          visualConfidence: null,
        },
      ]),
    ),
  );
}

function backed(...categories: TutorialCategory[]): Set<TutorialCategory> {
  return new Set(categories);
}

Deno.test("all nine categories present yields nine ordered steps", () => {
  const resolved = resolveManifest(
    parseManifestResponse(response({}, "present")),
    "standard",
    backed(),
  );
  assertEquals(resolved.includedCategories, [...TUTORIAL_CATEGORIES]);
  assertEquals(resolved.manifestStatus, "accepted");
});

Deno.test("a subset present yields only those steps", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ foundation: "present", blush: "present", lips: "present" }),
    ),
    "standard",
    backed(),
  );
  assertEquals(resolved.includedCategories, ["foundation", "blush", "lips"]);
});

Deno.test("an absent highlighter is excluded but keeps the rest ordered", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({}, "present"),
    ).map((verdict) =>
      verdict.category === "highlighter" ||
        verdict.category === "contour_bronzer"
        ? { ...verdict, presence: "absent" as const }
        : verdict
    ),
    "standard",
    backed(),
  );
  assertEquals(resolved.includedCategories, [
    "foundation",
    "concealer",
    "blush",
    "eyebrows",
    "eyeshadow",
    "eyeliner",
    "lips",
  ]);
});

Deno.test("uncertain is never silently included", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ blush: "uncertain", lips: "present" }),
    ),
    "standard",
    backed(),
  );
  assertEquals(resolved.includedCategories, ["lips"]);
});

Deno.test("nothing present yields no steps rather than a default nine", () => {
  const resolved = resolveManifest(
    parseManifestResponse(response()),
    "standard",
    backed(),
  );
  assertEquals(resolved.includedCategories, []);
  assertEquals(resolved.items.length, 9);
});

Deno.test("an invented category is rejected", () => {
  const payload = JSON.parse(response());
  payload.radiance_layer = { presence: "present", visualConfidence: 0.9 };
  const error = assertThrows(
    () => parseManifestResponse(JSON.stringify(payload)),
    FunctionFailure,
  );
  assertEquals(error.code, "unsupported_category");
});

Deno.test("a missing category is rejected rather than assumed absent", () => {
  const payload = JSON.parse(response());
  delete payload.lips;
  const error = assertThrows(
    () => parseManifestResponse(JSON.stringify(payload)),
    FunctionFailure,
  );
  assertEquals(error.code, "incomplete_manifest");
});

Deno.test("an out-of-vocabulary presence value is rejected", () => {
  const payload = JSON.parse(response());
  payload.blush.presence = "probably";
  assertThrows(
    () => parseManifestResponse(JSON.stringify(payload)),
    FunctionFailure,
  );
});

Deno.test("an out-of-range confidence is rejected", () => {
  const payload = JSON.parse(response());
  payload.blush.visualConfidence = 1.4;
  assertThrows(
    () => parseManifestResponse(JSON.stringify(payload)),
    FunctionFailure,
  );
});

Deno.test("malformed JSON is a typed failure", () => {
  const error = assertThrows(
    () => parseManifestResponse("not json"),
    FunctionFailure,
  );
  assertEquals(error.code, "malformed_ai_json");
});

Deno.test("kit mode includes only visible AND owned categories", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ foundation: "present", blush: "present", lips: "present" }),
    ),
    "my_makeup_kit",
    backed("foundation", "lips"),
  );
  assertEquals(resolved.includedCategories, ["foundation", "lips"]);
  assertEquals(resolved.unbackedPresentCategories, ["blush"]);
  assertEquals(resolved.manifestStatus, "kit_preview_mismatch");
});

Deno.test("an owned product does not force a visually absent step", () => {
  const resolved = resolveManifest(
    parseManifestResponse(response({ lips: "present" })),
    "my_makeup_kit",
    backed("lips", "eyeliner", "blush"),
  );
  assertEquals(resolved.includedCategories, ["lips"]);
  assertEquals(resolved.unbackedPresentCategories, []);
  assertEquals(resolved.manifestStatus, "accepted");
});

Deno.test("an incomplete kit is consistent when the preview matches it", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ foundation: "present", lips: "present" }),
    ),
    "my_makeup_kit",
    backed("foundation", "lips"),
  );
  assertEquals(resolved.includedCategories, ["foundation", "lips"]);
  assertEquals(resolved.manifestStatus, "accepted");
});

Deno.test("standard mode never reports a kit mismatch", () => {
  const resolved = resolveManifest(
    parseManifestResponse(response({}, "present")),
    "standard",
    backed(),
  );
  assertEquals(resolved.unbackedPresentCategories, []);
  assertEquals(resolved.manifestStatus, "accepted");
});

Deno.test("inclusion order is independent of response key order", () => {
  const verdicts = parseManifestResponse(response({}, "present"));
  const scrambled = [...verdicts].reverse();
  assertEquals(
    resolveManifest(scrambled, "standard", backed()).includedCategories,
    [...TUTORIAL_CATEGORIES],
  );
});

Deno.test("lipstick and lip gloss both back the single Lips step", () => {
  const mapped = productBackedCategories([
    { category: "lipstick" },
    { category: "lip_gloss" },
    { category: "eyebrow" },
  ]);
  assertEquals([...mapped].sort(), ["eyebrows", "lips"]);
});

Deno.test("an unmappable stored category is rejected", () => {
  const error = assertThrows(
    () => productBackedCategories([{ category: "setting_spray" }]),
    FunctionFailure,
  );
  assertEquals(error.code, "unsupported_inventory_category");
});

Deno.test("an empty snapshot backs nothing", () => {
  assertEquals(productBackedCategories([]).size, 0);
  assertEquals(productBackedCategories(null).size, 0);
});
