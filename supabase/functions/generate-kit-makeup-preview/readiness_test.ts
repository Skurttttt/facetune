import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { requestGeminiManifest } from "../analyze-tutorial-manifest-v4/gemini_client.ts";
import { productBackedCategories } from "../analyze-tutorial-manifest-v4/validation.ts";
import {
  buildCanonicalPlan,
  type CanonicalPlan,
  type DraftSelection,
  type PlanInventoryProduct,
} from "../_shared/kit_makeup_plan.ts";
import {
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "../_shared/tutorial_vocabulary.ts";
import {
  assessReadiness,
  kitManifestSupportingContext,
  manifestPreflightBody,
  requestManifestPreflight,
} from "./readiness.ts";

const owner = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";

function product(n: number, category: string): PlanInventoryProduct {
  return {
    id: `${n.toString().padStart(8, "0")}-0000-4000-8000-000000000000`,
    user_id: owner,
    category,
    product_name: null,
    color_hex: "#AA8877",
    color_label: null,
    finish: "satin",
    foundation_depth: null,
    foundation_undertone: null,
  };
}

const foundation = product(1, "foundation");
const blush = product(2, "blush");
const lipstick = product(3, "lipstick");

function pick(
  item: PlanInventoryProduct,
  role: string,
  intensity: DraftSelection["intensity"],
): DraftSelection {
  return {
    productId: item.id,
    category: item.category,
    role,
    placement: "Where the look needs it",
    technique: "Blend in thin layers",
    intensity,
    reasoning: "Suits the style.",
  };
}

// Lips are required to show; blush may stay subtle; the user owns a
// foundation this look does not use.
const built = await buildCanonicalPlan({
  planId: "99999999-9999-4999-8999-999999999999",
  createdAt: "2026-09-27T00:00:00.000Z",
  analysisId: "88888888-8888-4888-8888-888888888888",
  styleCode: "soft_glam",
  recommendationPromptVersion: "kit_makeup_recommendation_v3",
  inventory: [foundation, blush, lipstick],
  draft: {
    selections: [
      pick(lipstick, "lip_color", "soft"),
      pick(blush, "cheek_color", "sheer"),
    ],
    complexionOmissions: [
      { category: "foundation", reason: "style_not_required" },
    ],
    overallIntensity: "soft",
    summary: "Soft lips and cheeks.",
  },
});
const plan: CanonicalPlan = built.plan;
const snapshot = built.snapshot;

/** A manifest answer: every category absent unless stated. */
function manifest(
  present: Partial<Record<TutorialCategory, "present" | "uncertain">>,
): string {
  return JSON.stringify(
    Object.fromEntries(
      TUTORIAL_CATEGORIES.map((category) => [
        category,
        { presence: present[category] ?? "absent", visualConfidence: null },
      ]),
    ),
  );
}

Deno.test("the preflight sends exactly the manifest analyzer's request", async () => {
  const bodies: string[] = [];
  const realFetch = globalThis.fetch;
  globalThis.fetch = ((_input: unknown, init?: RequestInit) => {
    bodies.push(init?.body as string);
    return Promise.resolve(
      new Response(
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: manifest({}) }] } }],
        }),
        { status: 200 },
      ),
    );
  }) as typeof fetch;
  try {
    const original = {
      bytes: new Uint8Array([1, 2, 3]),
      mimeType: "image/jpeg",
    };
    const candidate = {
      bytes: new Uint8Array([4, 5, 6]),
      mimeType: "image/png",
    };
    const context = kitManifestSupportingContext(
      productBackedCategories(snapshot),
    );
    await requestGeminiManifest("key", "model", original, candidate, context);
    await requestManifestPreflight(
      "key",
      "model",
      manifestPreflightBody(original, candidate, context),
      30_000,
    );
  } finally {
    globalThis.fetch = realFetch;
  }
  assertEquals(bodies.length, 2);
  assertEquals(bodies[1], bodies[0]);
});

Deno.test("the supporting context is the manifest analyzer's, verbatim", async () => {
  const source = (await Deno.readTextFile(
    new URL("../analyze-tutorial-manifest-v4/index.ts", import.meta.url),
  )).replaceAll("\r\n", "\n");
  const context = kitManifestSupportingContext(new Set(["blush", "lips"]));
  assertStringIncludes(
    source,
    "`My Makeup Kit Mode. Categories the user owns a product for: ${",
  );
  assertStringIncludes(
    source,
    "}. This is context only and never evidence of visual presence.`",
  );
  assertEquals(
    context,
    "My Makeup Kit Mode. Categories the user owns a product for: blush, lips. This is context only and never evidence of visual presence.",
  );
});

Deno.test("an accepted-looking preview is Tutorial-ready", () => {
  const result = assessReadiness(plan, snapshot, manifest({ lips: "present" }));
  assertEquals(result.status, "ready");
  assertEquals(result.included_categories, ["lips"]);
  assertEquals(result.readiness_version, "kit_tutorial_readiness_v1");
  assertEquals(result.manifest_prompt_version, "tutorial_manifest_v4_1");
});

Deno.test("subtle planned makeup may be absent or present", () => {
  for (const blushPresence of ["present", "uncertain"] as const) {
    assertEquals(
      assessReadiness(
        plan,
        snapshot,
        manifest({ lips: "present", blush: blushPresence }),
      ).status,
      "ready",
    );
  }
});

Deno.test("a present category no product backs is still blocked", () => {
  const result = assessReadiness(
    plan,
    snapshot,
    manifest({ lips: "present", foundation: "present" }),
  );
  assertEquals(result.status, "not_ready");
  assertEquals(result.unbacked_present_categories, ["foundation"]);
});

Deno.test("owning the product is not backing: backing is the snapshot", () => {
  // The user owns a foundation, but this look's snapshot has none.
  assertEquals(
    [...productBackedCategories(snapshot)].sort(),
    ["blush", "lips"],
  );
});

Deno.test("a required step the manifest would not include is not ready", () => {
  for (const lips of [undefined, "uncertain"] as const) {
    const result = assessReadiness(
      plan,
      snapshot,
      manifest(lips ? { lips } : { blush: "present" }),
    );
    assertEquals(result.status, "not_ready");
    assertEquals(result.missing_required_categories, ["lips"]);
  }
});

Deno.test("a tutorial with no steps is never ready", () => {
  const subtleOnly = {
    ...plan,
    selected_items: plan.selected_items.map((item) => ({
      ...item,
      visible_intent: "subtle_allowed" as const,
    })),
  };
  const result = assessReadiness(subtleOnly, snapshot, manifest({}));
  assertEquals(result.status, "not_ready");
  assertEquals(result.included_categories, []);
});

Deno.test("a malformed manifest answer is a failure, not a pass", () => {
  for (
    const text of ["not json", "{}", manifest({}).replace("absent", "maybe")]
  ) {
    const result = assessReadiness(plan, snapshot, text);
    assertEquals(result.status, "failure");
    assertEquals(result.failure_code, "readiness_malformed");
  }
});

Deno.test("a snapshot that disagrees with the plan is a failure", () => {
  const result = assessReadiness(
    plan,
    [...snapshot, { ...snapshot[0], category: "foundation" }],
    manifest({ lips: "present" }),
  );
  assertEquals(result.status, "failure");
  assertEquals(result.failure_code, "plan_snapshot_disagree");
});

Deno.test("Standard Mode never reaches readiness", async () => {
  const standard = await Deno.readTextFile(
    new URL("../generate-makeup-preview/index.ts", import.meta.url),
  );
  assertEquals(standard.includes("readiness"), false);
});
