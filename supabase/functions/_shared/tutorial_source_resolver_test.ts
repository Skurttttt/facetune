import {
  assertEquals,
  assertRejects,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  ResolutionFailure,
  resolveProducts,
  resolveStandardPlan,
  resolveTutorialSource,
  sanitizedResolutionLog,
  type ResolverClient,
} from "./tutorial_source_resolver.ts";

const userId = "11111111-1111-4111-8111-111111111111";
const otherUserId = "22222222-2222-4222-8222-222222222222";
const sessionId = "33333333-3333-4333-8333-333333333333";
const analysisId = "44444444-4444-4444-8444-444444444444";
const recommendationId = "55555555-5555-4555-8555-555555555555";
const previewId = "66666666-6666-4666-8666-666666666666";

const originalPath = `${userId}/analyses/${analysisId}/original/` +
  `77777777-7777-4777-8777-777777777777.jpg`;
const previewPath = (folder: string) =>
  `${userId}/analyses/${analysisId}/${folder}/${recommendationId}/preview_0001.png`;

interface Fixture {
  session?: Record<string, unknown> | null;
  manifest?: Array<Record<string, unknown>>;
  step?: Record<string, unknown> | null;
  analysis?: Record<string, unknown> | null;
  preview?: Record<string, unknown> | null;
  recommendation?: Record<string, unknown> | null;
  downloadFails?: string[];
}

function blob(): { arrayBuffer: () => Promise<ArrayBuffer> } {
  return { arrayBuffer: () => Promise.resolve(new ArrayBuffer(8)) };
}

function client(fixture: Fixture): ResolverClient {
  const rows: Record<string, unknown> = {
    tutorial_v4_sessions: fixture.session === undefined
      ? standardSession()
      : fixture.session,
    tutorial_v4_manifest_items: fixture.manifest ?? presentManifest(),
    tutorial_v4_steps: fixture.step === undefined ? standardStep() : fixture.step,
    analyses: fixture.analysis === undefined ? standardAnalysis() : fixture.analysis,
    generated_images: fixture.preview === undefined
      ? { id: previewId, storage_path: previewPath("generated") }
      : fixture.preview,
    kit_generated_images: fixture.preview === undefined
      ? { id: previewId, storage_path: previewPath("kit-generated") }
      : fixture.preview,
    recommendations: fixture.recommendation === undefined
      ? standardRecommendation()
      : fixture.recommendation,
    kit_makeup_recommendations: fixture.recommendation === undefined
      ? kitRecommendation()
      : fixture.recommendation,
  };
  const builder = (table: string) => {
    const chain = {
      select: () => chain,
      eq: () => chain,
      maybeSingle: () => Promise.resolve({ data: rows[table] ?? null }),
      then: (resolve: (value: { data: unknown }) => void) =>
        resolve({ data: rows[table] ?? null }),
    };
    return chain;
  };
  return {
    from: builder,
    storage: {
      from: () => ({
        download: (path: string) =>
          Promise.resolve(
            (fixture.downloadFails ?? []).some((fragment) =>
              path.includes(fragment)
            )
              ? { data: null, error: { message: "missing" } }
              : { data: blob(), error: null },
          ),
      }),
    },
  };
}

function standardSession(): Record<string, unknown> {
  return {
    id: sessionId,
    user_id: userId,
    analysis_id: analysisId,
    source_mode: "standard",
    recommendation_id: recommendationId,
    kit_recommendation_id: null,
    canonical_generated_image_id: previewId,
    canonical_kit_generated_image_id: null,
    manifest_status: "accepted",
  };
}

function kitSession(): Record<string, unknown> {
  return {
    ...standardSession(),
    source_mode: "my_makeup_kit",
    recommendation_id: null,
    kit_recommendation_id: recommendationId,
    canonical_generated_image_id: null,
    canonical_kit_generated_image_id: previewId,
  };
}

function presentManifest(): Array<Record<string, unknown>> {
  return [
    { category: "foundation", presence: "present", product_backed: true },
    { category: "lips", presence: "present", product_backed: true },
    { category: "eyeliner", presence: "absent", product_backed: false },
  ];
}

function standardStep(): Record<string, unknown> {
  return { id: "step-1", position: 1, generation_attempt: 0 };
}

function standardAnalysis(): Record<string, unknown> {
  return {
    id: analysisId,
    original_image_path: originalPath,
    face_shape: "oval",
    skin_tone: "medium",
    undertone: "warm",
    eye_shape: "almond",
    lip_shape: "full",
    hair_color: "brown",
    eye_color: "brown",
  };
}

function standardRecommendation(): Record<string, unknown> {
  return {
    id: recommendationId,
    makeup_style: "soft_glam",
    recommendation_json: {
      foundation: {
        name: "Warm beige",
        hex: "#E3C4A8",
        placement: "Across the face.",
        technique: "Buff outward.",
        finish: "natural",
        intensity: "soft",
        reasoning: "Matches the undertone.",
      },
      lipstick: {
        name: "Rosewood",
        hex: "#B86F72",
        placement: "Across the lips.",
        technique: "Press and blot.",
        finish: "satin",
        intensity: "medium",
        reasoning: "Suits the palette.",
      },
      lipGloss: {
        name: "Clear shine",
        hex: null,
        placement: "Centre of the lower lip.",
        technique: "Dab lightly.",
        finish: "glossy",
        intensity: "sheer",
        reasoning: "Adds dimension.",
      },
    },
  };
}

function kitRecommendation(): Record<string, unknown> {
  return {
    id: recommendationId,
    makeup_style: "soft_glam",
    product_snapshot_json: [
      {
        productId: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
        category: "foundation",
        colorHex: "#E3C4A8",
        finish: "natural",
        productName: "My Foundation",
        colorLabel: "Warm Sand",
        foundationDepth: "light",
        foundationUndertone: "warm",
      },
      {
        productId: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb",
        category: "lipstick",
        colorHex: "#B86F72",
        finish: "cream",
        productName: "My Lipstick",
      },
      {
        productId: "cccccccc-cccc-4ccc-8ccc-cccccccccccc",
        category: "lip_gloss",
        colorHex: "#D8A0A2",
        finish: "glossy",
        productName: "My Gloss",
      },
    ],
  };
}

async function expectFailure(
  fixture: Fixture,
  category: string,
  code: string,
): Promise<void> {
  const error = await assertRejects(
    () =>
      resolveTutorialSource(client(fixture), userId, {
        tutorialSessionId: sessionId,
        category,
      }),
    ResolutionFailure,
  );
  assertEquals(error.code, code);
}

Deno.test("resolves a valid Standard Mode request", async () => {
  const context = await resolveTutorialSource(client({}), userId, {
    tutorialSessionId: sessionId,
    category: "foundation",
  });

  assertEquals(context.sourceMode, "standard");
  assertEquals(context.category, "foundation");
  assertEquals(context.originalImage.path, originalPath);
  assertEquals(context.canonicalPreview.path, previewPath("generated"));
  assertEquals(context.canonicalPreview.mimeType, "image/png");
  assertEquals(context.includedCount, 2);
  assertEquals(context.products.length, 0);
  assertEquals(context.standardPlan.length, 1);
  assertEquals(context.standardPlan[0].shadeName, "Warm beige");
  assertEquals(context.faceAttributes.undertone, "warm");
});

Deno.test("resolves a valid My Makeup Kit request", async () => {
  const context = await resolveTutorialSource(
    client({ session: kitSession() }),
    userId,
    { tutorialSessionId: sessionId, category: "lips" },
  );

  assertEquals(context.sourceMode, "my_makeup_kit");
  assertEquals(context.canonicalPreview.path, previewPath("kit-generated"));
  // Lipstick and lip gloss both belong to the single Lips step.
  assertEquals(context.products.length, 2);
  assertEquals(context.products[0].productName, "My Lipstick");
  assertEquals(context.products[1].inventoryCategory, "lip_gloss");
  assertEquals(context.standardPlan.length, 0);
});

Deno.test("a missing original selfie is fatal", async () => {
  await expectFailure(
    { analysis: { ...standardAnalysis(), original_image_path: null } },
    "foundation",
    "tutorial_source_not_found",
  );
  await expectFailure(
    { downloadFails: ["/original/"] },
    "foundation",
    "source_image_unavailable",
  );
});

Deno.test("a missing canonical preview is fatal", async () => {
  await expectFailure(
    { preview: { id: previewId, storage_path: null } },
    "foundation",
    "tutorial_source_not_found",
  );
  await expectFailure(
    { downloadFails: ["/generated/"] },
    "foundation",
    "source_image_unavailable",
  );
});

Deno.test("a foreign preview path is rejected", async () => {
  await expectFailure(
    {
      preview: {
        id: previewId,
        storage_path:
          `${otherUserId}/analyses/${analysisId}/generated/${recommendationId}/preview_0001.png`,
      },
    },
    "foundation",
    "invalid_preview_path",
  );
});

Deno.test("a foreign original path is rejected", async () => {
  await expectFailure(
    {
      analysis: {
        ...standardAnalysis(),
        original_image_path:
          `${otherUserId}/analyses/${analysisId}/original/77777777-7777-4777-8777-777777777777.jpg`,
      },
    },
    "foundation",
    "invalid_original_path",
  );
});

Deno.test("a session owned by another account is not found", async () => {
  await expectFailure(
    { session: { ...standardSession(), user_id: otherUserId } },
    "foundation",
    "tutorial_source_not_found",
  );
});

Deno.test("a category the manifest excluded is rejected", async () => {
  await expectFailure({}, "eyeliner", "category_not_included");
  await expectFailure({}, "blush", "category_not_included");
});

Deno.test("an unsupported category never reaches resolution", async () => {
  await expectFailure({}, "radiance_layer", "unsupported_category");
});

Deno.test("an invalid source mode is rejected", async () => {
  await expectFailure(
    { session: { ...standardSession(), source_mode: "hybrid" } },
    "foundation",
    "invalid_source_mode",
  );
});

Deno.test("an unaccepted manifest is rejected", async () => {
  await expectFailure(
    { session: { ...standardSession(), manifest_status: "pending" } },
    "foundation",
    "manifest_not_accepted",
  );
  await expectFailure(
    {
      session: { ...kitSession(), manifest_status: "kit_preview_mismatch" },
    },
    "foundation",
    "kit_preview_mismatch",
  );
});

Deno.test("a kit category with no snapshot item is a mismatch", async () => {
  await expectFailure(
    {
      session: kitSession(),
      recommendation: { ...kitRecommendation(), product_snapshot_json: [] },
    },
    "lips",
    "kit_preview_mismatch",
  );
});

Deno.test("in kit mode an unbacked category is not included", async () => {
  await expectFailure(
    {
      session: kitSession(),
      manifest: [
        { category: "lips", presence: "present", product_backed: false },
      ],
    },
    "lips",
    "category_not_included",
  );
});

Deno.test("errors never leak identifiers or paths", async () => {
  const error = await assertRejects(
    () =>
      resolveTutorialSource(
        client({ session: { ...standardSession(), user_id: otherUserId } }),
        userId,
        { tutorialSessionId: sessionId, category: "foundation" },
      ),
    ResolutionFailure,
  );
  for (const secret of [userId, otherUserId, sessionId, originalPath]) {
    assertEquals(error.message.includes(secret), false);
  }
});

Deno.test("product resolution reads only the immutable snapshot", () => {
  assertEquals(resolveProducts(kitRecommendation().product_snapshot_json, "lips").length, 2);
  assertEquals(
    resolveProducts(kitRecommendation().product_snapshot_json, "foundation")
      .length,
    1,
  );
  assertEquals(resolveProducts(null, "lips").length, 0);
  assertEquals(resolveProducts([{ category: "setting_spray" }], "lips").length, 0);
});

Deno.test("standard plan resolution merges both lip keys", () => {
  const plan = resolveStandardPlan(
    standardRecommendation().recommendation_json,
    "lips",
  );
  assertEquals(plan.length, 2);
  assertEquals(plan.map((entry) => entry.planKey), ["lipstick", "lipGloss"]);
  assertEquals(plan[1].colorHex, null);
});

Deno.test("the sanitized log carries no personal data", async () => {
  const context = await resolveTutorialSource(
    client({ session: kitSession() }),
    userId,
    { tutorialSessionId: sessionId, category: "lips" },
  );
  const line = sanitizedResolutionLog(context);

  assertEquals(line.includes(originalPath), false);
  assertEquals(line.includes("My Lipstick"), false);
  assertEquals(line.includes("#B86F72"), false);
  assertEquals(line.includes("oval"), false);
  assertEquals(line.includes(context.stepId), true);
});
