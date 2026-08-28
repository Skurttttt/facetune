import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import { GEOMETRY_SCHEMA_VERSION, LIMITS } from "./types.ts";
import {
  GeometryRejected,
  parseAndValidateGeometry,
  stripCodeFence,
} from "./validation.ts";

// deno-lint-ignore no-explicit-any
type Json = Record<string, any>;

const point = (x: number, y: number) => ({ x, y });

function ellipse(overrides: Json = {}): Json {
  return {
    kind: "ellipse",
    role: "placement_zone",
    center: point(0.3, 0.4),
    radius_x: 0.08,
    radius_y: 0.05,
    ...overrides,
  };
}

function arrow(overrides: Json = {}): Json {
  return {
    kind: "arrow",
    role: "blend_direction",
    start: point(0.3, 0.4),
    end: point(0.2, 0.32),
    ...overrides,
  };
}

function document(overrides: Json = {}): string {
  return JSON.stringify({
    schema_version: GEOMETRY_SCHEMA_VERSION,
    category: "blush",
    coordinate_space: "normalized_original_image",
    primitives: [ellipse()],
    ...overrides,
  });
}

function reasons(raw: string, category = "blush"): string[] {
  try {
    parseAndValidateGeometry(raw, category);
  } catch (error) {
    if (error instanceof GeometryRejected) return error.reasons;
    throw error;
  }
  throw new Error("expected the geometry to be rejected");
}

Deno.test("accepts a valid document and normalizes it", () => {
  const geometry = parseAndValidateGeometry(
    document({ primitives: [ellipse(), arrow()] }),
    "blush",
  );
  assertEquals(geometry.schema_version, GEOMETRY_SCHEMA_VERSION);
  assertEquals(geometry.category, "blush");
  assertEquals(geometry.coordinate_space, "normalized_original_image");
  assertEquals(geometry.primitives.length, 2);
});

Deno.test("accepts a fenced response", () => {
  const raw = "```json\n" + document() + "\n```";
  assertEquals(parseAndValidateGeometry(raw, "blush").primitives.length, 1);
  assertEquals(stripCodeFence("```json\n{}\n```"), "{}");
});

Deno.test("rejects malformed payloads", () => {
  assertEquals(reasons("not json").length, 1);
  assertEquals(reasons("[]").length, 1);
  assertEquals(reasons(document({ primitives: [] })).length >= 1, true);
});

Deno.test("rejects an unsupported schema version", () => {
  assertStringIncludes(
    reasons(document({ schema_version: 2 })).join(" "),
    "Unsupported geometry schema version 2",
  );
});

Deno.test("rejects a wrong coordinate space", () => {
  assertStringIncludes(
    reasons(document({ coordinate_space: "screen_pixels" })).join(" "),
    "coordinate_space must be",
  );
});

Deno.test("rejects a category mismatch", () => {
  assertStringIncludes(
    reasons(document({ category: "lipstick" })).join(" "),
    "category mismatch",
  );
});

Deno.test("rejects style, text and code fields", () => {
  assertStringIncludes(
    reasons(document({ svg: "<svg/>", label: "Blush" })).join(" "),
    "unsupported fields: label, svg",
  );
  assertStringIncludes(
    reasons(
      document({ primitives: [{ ...ellipse(), color: "#f00", opacity: 0.5 }] }),
    ).join(" "),
    "unsupported fields: color, opacity",
  );
  assertStringIncludes(
    reasons(
      document({
        primitives: [{ ...ellipse(), center: { x: 0.3, y: 0.4, z: 0.1 } }],
      }),
    ).join(" "),
    "unsupported fields: z",
  );
});

Deno.test("rejects out-of-range coordinates without clamping", () => {
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ center: point(1.4, 0.4) })] }))
      .join(" "),
    "outside the normalized 0–1 range",
  );
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ center: point(0.3, -0.2) })] }))
      .join(" "),
    "outside the normalized 0–1 range",
  );
});

Deno.test("rejects non-finite and non-numeric coordinates", () => {
  // JSON has no NaN literal, so a string stands in for the malformed case the
  // model could realistically emit.
  assertStringIncludes(
    reasons(
      document({ primitives: [ellipse({ center: { x: "0.3", y: 0.4 } })] }),
    ).join(" "),
    "must be a number",
  );
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ radius_x: "wide" })] })).join(" "),
    "must be a number",
  );
});

Deno.test("rejects unknown primitives and roles", () => {
  assertStringIncludes(
    reasons(document({ primitives: [{ kind: "bezier", role: "placement_zone" }] }))
      .join(" "),
    'unknown kind "bezier"',
  );
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ role: "sparkle_zone" })] }))
      .join(" "),
    'unknown role "sparkle_zone"',
  );
});

Deno.test("rejects a kind the role does not allow", () => {
  assertStringIncludes(
    reasons(
      document({
        primitives: [{
          kind: "region",
          role: "blend_direction",
          vertices: [point(0.3, 0.3), point(0.5, 0.3), point(0.4, 0.4)],
        }],
      }),
    ).join(" "),
    "which only accepts",
  );
});

Deno.test("rejects a role the category does not allow", () => {
  assertStringIncludes(
    reasons(
      document({
        category: "eyeliner",
        primitives: [{
          kind: "region",
          role: "coverage_zone",
          vertices: [point(0.3, 0.3), point(0.5, 0.3), point(0.4, 0.4)],
        }],
      }),
      "eyeliner",
    ).join(" "),
    "does not allow",
  );
});

Deno.test("enforces complexity limits", () => {
  assertStringIncludes(
    reasons(
      document({
        primitives: Array.from(
          { length: LIMITS.maxPrimitives + 1 },
          () => ellipse(),
        ),
      }),
    ).join(" "),
    "too many primitives",
  );
  assertStringIncludes(
    reasons(
      document({
        primitives: [{
          kind: "region",
          role: "placement_zone",
          vertices: [point(0.3, 0.4), point(0.4, 0.4)],
        }],
      }),
    ).join(" "),
    "region needs",
  );
  assertStringIncludes(
    reasons(
      document({
        category: "eyeliner",
        primitives: [{
          kind: "polyline",
          role: "application_path",
          vertices: Array.from(
            { length: LIMITS.maxPolylineVertices + 1 },
            (_, i) => point(i / 100, 0.3),
          ),
        }],
      }),
      "eyeliner",
    ).join(" "),
    "polyline needs",
  );
});

Deno.test("rejects invalid radii and zero-length arrows", () => {
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ radius_x: 0 })] })).join(" "),
    "radius_x 0 is outside",
  );
  assertStringIncludes(
    reasons(document({ primitives: [ellipse({ radius_y: 0.95 })] })).join(" "),
    "radius_y 0.95 is outside",
  );
  assertStringIncludes(
    reasons(
      document({
        primitives: [arrow({ start: point(0.3, 0.4), end: point(0.3, 0.4) })],
      }),
    ).join(" "),
    "shows no direction",
  );
});

Deno.test("the returned document is rebuilt, not echoed", () => {
  // Category, schema version and coordinate space come from the server's own
  // constants, so a model cannot smuggle different values through.
  const geometry = parseAndValidateGeometry(document(), "blush");
  assertEquals(geometry.category, "blush");
  assertEquals(geometry.schema_version, GEOMETRY_SCHEMA_VERSION);
  assertEquals("svg" in geometry, false);
});

Deno.test("optional rotation is preserved only when non-zero", () => {
  const withRotation = parseAndValidateGeometry(
    document({ primitives: [ellipse({ rotation: 0.5 })] }),
    "blush",
  );
  assertEquals(withRotation.primitives[0].rotation, 0.5);

  const withoutRotation = parseAndValidateGeometry(
    document({ primitives: [ellipse({ rotation: 0 })] }),
    "blush",
  );
  assertEquals("rotation" in withoutRotation.primitives[0], false);
});

Deno.test("every canonical category can express geometry", () => {
  const byCategory: Record<string, Json> = {
    foundation: {
      kind: "region",
      role: "coverage_zone",
      vertices: [point(0.3, 0.3), point(0.7, 0.3), point(0.5, 0.8)],
    },
    concealer: ellipse(),
    contour_bronzer: ellipse(),
    blush: ellipse(),
    highlighter: ellipse(),
    eyebrow: {
      kind: "polyline",
      role: "application_path",
      vertices: [point(0.3, 0.3), point(0.4, 0.28)],
    },
    eyeshadow: ellipse(),
    eyeliner: {
      kind: "polyline",
      role: "application_path",
      vertices: [point(0.3, 0.4), point(0.4, 0.38)],
    },
    lipstick: {
      kind: "polyline",
      role: "boundary",
      vertices: [point(0.4, 0.6), point(0.6, 0.6)],
    },
    lip_gloss: ellipse(),
  };
  for (const [category, primitive] of Object.entries(byCategory)) {
    const geometry = parseAndValidateGeometry(
      document({ category, primitives: [primitive] }),
      category,
    );
    assertEquals(geometry.category, category, `${category} failed`);
  }
});
