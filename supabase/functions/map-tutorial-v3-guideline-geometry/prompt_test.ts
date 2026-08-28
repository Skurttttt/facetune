import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  GEOMETRY_PROMPT_VERSION,
  type MapperSpec,
  geometryMapperPrompt,
} from "./prompt.ts";
import { CATEGORY_ROLES, SCOPED_ATTRIBUTES } from "./types.ts";

function spec(overrides: Partial<MapperSpec> = {}): MapperSpec {
  return {
    category: "blush",
    whereToApply: "TWO separate zones on the upper outer cheeks",
    direction: "Diagonally upward and outward toward each temple",
    technique: "Soft circular blending",
    coverage: null,
    intensity: "Soft to medium",
    visualDescription: "Two separate translucent zones with arrows.",
    faceAttributes: { face_shape: "oval" },
    ...overrides,
  };
}

const blush = geometryMapperPrompt(spec());

const indexSource = await Deno.readTextFile(
  new URL("./index.ts", import.meta.url),
);

Deno.test("the prompt version is stable", () => {
  assertEquals(GEOMETRY_PROMPT_VERSION, "v3-geometry-mapper-1");
});

// --- The mapper is not a second planner ------------------------------------

Deno.test("the model is framed as a mapper, not a designer", () => {
  assertStringIncludes(blush, "You are a GEOMETRY MAPPER");
  assertStringIncludes(blush, "You are not designing makeup.");
  assertStringIncludes(blush, "You are not choosing placement strategy.");
  assertStringIncludes(
    blush,
    "The makeup decision has ALREADY been made and is written in the",
  );
});

Deno.test("every Step Spec field reaches the prompt", () => {
  const input = spec();
  assertStringIncludes(blush, input.whereToApply);
  assertStringIncludes(blush, input.direction);
  assertStringIncludes(blush, input.technique);
  assertStringIncludes(blush, input.visualDescription!);
  assertStringIncludes(blush, "INTENSITY: Soft to medium");
});

Deno.test("absent optional fields are omitted, not emitted empty", () => {
  assertEquals(blush.includes("COVERAGE:"), false);
  const noVisual = geometryMapperPrompt(spec({ visualDescription: null }));
  assertEquals(noVisual.includes("WHAT THE DIAGRAM SHOULD SHOW"), false);
});

// --- Style-transfer pressure is kept out ------------------------------------

Deno.test("the prompt never names the look or the finished appearance", () => {
  // V3-6A.2 evidence: naming a look, or describing the finished result, is
  // style-transfer pressure in text form.
  for (const banned of ["soft glam", "selected look", "target look", "rationale", "cues"]) {
    assertEquals(
      blush.toLowerCase().includes(banned),
      false,
      `prompt must not carry "${banned}"`,
    );
  }
});

Deno.test("no canonical preview or second image is referenced", () => {
  for (
    const banned of [
      "canonical",
      "final preview",
      "image 2",
      "second image",
      "reference image",
      "previous guideline",
      "previous step",
    ]
  ) {
    assertEquals(
      blush.toLowerCase().includes(banned),
      false,
      `prompt must not mention "${banned}"`,
    );
  }
});

// --- Coordinate + output contract -------------------------------------------

Deno.test("the coordinate system is fully specified", () => {
  assertStringIncludes(blush, "normalized against the ORIGINAL image");
  assertStringIncludes(blush, "origin is the TOP-LEFT corner");
  assertStringIncludes(blush, 'coordinate_space must be exactly "normalized_original_image"');
  assertStringIncludes(blush, "between 0 and 1 inclusive");
  assertStringIncludes(blush, "never output NaN or infinity");
});

Deno.test("no image, markup, code, text or style may be returned", () => {
  for (
    const banned of [
      "image data of any kind",
      "SVG, HTML, or any markup",
      "code of any language",
      "text, labels, captions",
      "colours, opacity, stroke widths, fonts, gradients or blend modes",
      "animation or timing",
    ]
  ) {
    assertStringIncludes(blush, banned);
  }
  assertStringIncludes(blush, "The application chooses every colour and style itself.");
});

Deno.test("separate areas must stay separate", () => {
  assertStringIncludes(blush, "return TWO separate primitives");
  assertStringIncludes(blush, "Never merge them into one shape");
});

// --- Per-category role vocabulary -------------------------------------------

Deno.test("each category is offered only its own roles", () => {
  for (const [category, roles] of Object.entries(CATEGORY_ROLES)) {
    if (category === "final_look") continue;
    const prompt = geometryMapperPrompt(spec({ category }));
    for (const role of roles) assertStringIncludes(prompt, `"${role}"`);

    const forbidden = Object.keys(
      Object.fromEntries(
        Object.entries(CATEGORY_ROLES).flatMap(([, all]) => all.map((r) => [r, true])),
      ),
    ).filter((role) => !roles.includes(role as never));
    for (const role of forbidden) {
      assertEquals(
        prompt.includes(`- "${role}" —`),
        false,
        `${category} must not offer ${role}`,
      );
    }
  }
});

Deno.test("scoped attributes match the category catalog", () => {
  assertEquals(SCOPED_ATTRIBUTES.blush, ["face_shape"]);
  assertEquals(SCOPED_ATTRIBUTES.eyeliner, ["eye_shape"]);
  assertEquals(SCOPED_ATTRIBUTES.lipstick, ["lip_shape"]);
  assertEquals(SCOPED_ATTRIBUTES.foundation, ["skin_tone", "undertone"]);
  assertStringIncludes(blush, "face shape: oval");
  assertEquals(blush.includes("lip shape"), false);
});

// --- The client trust boundary, asserted against index.ts -------------------

Deno.test("the client may send identifiers only", () => {
  assertStringIncludes(indexSource, "invalid_session_id");
  assertStringIncludes(indexSource, "invalid_step_index");
  for (
    const forbidden of [
      '"prompt"',
      '"stepSpec"',
      '"category"',
      '"faceAttributes"',
      '"selectedStyle"',
      '"analysisId"',
      '"storagePath"',
      '"geometry"',
    ]
  ) {
    assertStringIncludes(indexSource, forbidden);
  }
  assertStringIncludes(indexSource, "unsupported_field");
  assertStringIncludes(
    indexSource,
    "is resolved by the server and may not be supplied",
  );
});

Deno.test("the server resolves context from persisted records", () => {
  for (
    const table of [
      "tutorial_v3_sessions",
      "tutorial_v3_steps",
      "analyses",
      "makeup_kit_products",
    ]
  ) {
    assertStringIncludes(indexSource, table);
  }
  assertStringIncludes(indexSource, "step_spec_mismatch");
  assertStringIncludes(indexSource, "source_mode_mismatch");
  assertStringIncludes(indexSource, "recommendation_mismatch");
  assertStringIncludes(indexSource, "incompatible_plan_version");
});

Deno.test("kit ownership is re-verified against live inventory", () => {
  assertStringIncludes(indexSource, "inventory_changed");
  assertStringIncludes(indexSource, "This step teaches a product you no longer own.");
});

Deno.test("the selfie path is validated segment-by-segment", () => {
  assertStringIncludes(indexSource, "isOwnedOriginalPath");
  assertStringIncludes(indexSource, "unsafe_storage_path");
});

Deno.test("the caller JWT drives every read, never service_role", () => {
  assertStringIncludes(indexSource, "SUPABASE_ANON_KEY");
  assertEquals(indexSource.includes("SERVICE_ROLE"), false);
});

Deno.test("the lifecycle is claim, map, validate, persist", () => {
  assertStringIncludes(indexSource, "claim_tutorial_v3_geometry");
  assertStringIncludes(indexSource, "parseAndValidateGeometry");
  assertStringIncludes(indexSource, '.eq("geometry_status", "generating")');
  assertStringIncludes(indexSource, "releaseClaim");
});

Deno.test("idempotency and bounded retry are explicit", () => {
  assertStringIncludes(indexSource, 'outcome === "reused"');
  assertStringIncludes(indexSource, 'outcome === "in_flight"');
  assertStringIncludes(indexSource, 'outcome === "exhausted"');
  assertStringIncludes(indexSource, "maxMappingAttempts = 3");
  assertStringIncludes(indexSource, "incompatible_geometry_version");
});

Deno.test("the mapper uses its own model variable", () => {
  assertStringIncludes(indexSource, 'Deno.env.get("TUTORIAL_V3_GEOMETRY_MODEL")');
  assertEquals(indexSource.includes("GEMINI_IMAGE_MODEL"), false);
});

Deno.test("no canonical preview reaches the mapper", () => {
  assertEquals(indexSource.includes("canonical_image_path"), false);
  assertEquals(indexSource.includes("canonical_generated_image_id"), false);
});

Deno.test("image output from the model is treated as a fault", async () => {
  const clientSource = await Deno.readTextFile(
    new URL("./gemini_client.ts", import.meta.url),
  );
  assertStringIncludes(clientSource, "unexpected_image_output");
  assertStringIncludes(clientSource, "parts.some((part) => part.inlineData)");
  // Text endpoint, not the image endpoint.
  assertStringIncludes(clientSource, "/v1beta/models/");
  assertEquals(clientSource.includes("/v1/models/"), false);
});
