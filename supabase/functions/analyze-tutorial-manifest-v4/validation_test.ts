import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  isReusableManifest,
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

Deno.test("kit mode includes exactly the snapshot-backed categories", () => {
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

Deno.test("a snapshot-backed category is included whatever its verdict", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ lips: "present", eyeliner: "uncertain" }),
    ),
    "my_makeup_kit",
    backed("lips", "eyeliner", "blush"),
  );
  // blush is absent, eyeliner uncertain, lips present: all three are selected.
  assertEquals(resolved.includedCategories, ["blush", "eyeliner", "lips"]);
  assertEquals(resolved.unbackedPresentCategories, []);
  assertEquals(resolved.manifestStatus, "accepted");
});

Deno.test("the OMKT target example resolves from the snapshot", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({
        foundation: "uncertain",
        concealer: "present",
        blush: "present",
        eyeshadow: "uncertain",
        lips: "present",
      }),
    ),
    "my_makeup_kit",
    // Snapshot: foundation, blush, eyeshadow, lipstick.
    productBackedCategories([
      { category: "foundation" },
      { category: "blush" },
      { category: "eyeshadow" },
      { category: "lipstick" },
    ]),
  );
  assertEquals(resolved.includedCategories, [
    "foundation",
    "blush",
    "eyeshadow",
    "lips",
  ]);
  // Concealer is visible but no selected product backs it: reported, never a
  // step, and no longer a reason to block the tutorial.
  assertEquals(resolved.unbackedPresentCategories, ["concealer"]);
  assertEquals(resolved.manifestStatus, "kit_preview_mismatch");
  const concealer = resolved.items.find((item) =>
    item.category === "concealer"
  );
  assertEquals(concealer?.included, false);
  assertEquals(concealer?.productBacked, false);
});

Deno.test("kit mode: the six-row step-existence truth table", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({
        foundation: "present",
        concealer: "absent",
        blush: "uncertain",
        highlighter: "present",
        eyeshadow: "absent",
        eyeliner: "uncertain",
      }),
    ),
    "my_makeup_kit",
    backed("foundation", "concealer", "blush"),
  );
  const included = (category: TutorialCategory) =>
    resolved.items.find((item) => item.category === category)?.included;
  assertEquals(included("foundation"), true, "selected + present");
  assertEquals(included("concealer"), true, "selected + absent");
  assertEquals(included("blush"), true, "selected + uncertain");
  assertEquals(included("highlighter"), false, "not selected + present");
  assertEquals(included("eyeshadow"), false, "not selected + absent");
  assertEquals(included("eyeliner"), false, "not selected + uncertain");
});

Deno.test("standard mode: present only, and backing is ignored", () => {
  const resolved = resolveManifest(
    parseManifestResponse(
      response({ foundation: "present", concealer: "uncertain" }),
    ),
    "standard",
    // Even if a caller passed a backed set, Standard Mode never uses it.
    backed("foundation", "concealer", "blush"),
  );
  assertEquals(resolved.includedCategories, ["foundation"]);
  assertEquals(
    resolved.items.every((item) => item.productBacked === false),
    true,
  );
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

const current = {
  currentPromptVersion: "tutorial_manifest_v4_1",
  currentSchemaVersion: "tutorial_manifest_schema_v1",
  promptVersion: "tutorial_manifest_v4_1",
  schemaVersion: "tutorial_manifest_schema_v1",
};

Deno.test("a complete kit manifest is reused, diagnostic mismatch included", () => {
  for (const manifestStatus of ["accepted", "kit_preview_mismatch"]) {
    assertEquals(
      isReusableManifest({
        ...current,
        sourceMode: "my_makeup_kit",
        manifestStatus,
        itemCount: 9,
      }),
      true,
    );
  }
});

Deno.test("an incomplete kit manifest is analyzed again", () => {
  for (const itemCount of [0, 4, 8]) {
    assertEquals(
      isReusableManifest({
        ...current,
        sourceMode: "my_makeup_kit",
        manifestStatus: "accepted",
        itemCount,
      }),
      false,
    );
  }
});

Deno.test("standard reuse keeps its existing rule", () => {
  // Unchanged: status and versions decide; the item count never did.
  assertEquals(
    isReusableManifest({
      ...current,
      sourceMode: "standard",
      manifestStatus: "accepted",
      itemCount: 0,
    }),
    true,
  );
  assertEquals(
    isReusableManifest({
      ...current,
      sourceMode: "standard",
      manifestStatus: "failed",
      itemCount: 9,
    }),
    false,
  );
});

Deno.test("a stale version is never reused in either mode", () => {
  for (const sourceMode of ["standard", "my_makeup_kit"] as const) {
    assertEquals(
      isReusableManifest({
        ...current,
        sourceMode,
        manifestStatus: "accepted",
        promptVersion: "tutorial_manifest_v4_0",
        itemCount: 9,
      }),
      false,
    );
  }
});
