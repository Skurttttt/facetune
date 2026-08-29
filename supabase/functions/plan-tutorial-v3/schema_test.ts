import { assert, assertEquals } from "jsr:@std/assert@1";

import { TUTORIAL_V3_PLAN_SCHEMA } from "./schema.ts";
import {
  ALLOWED_GRAPHICS,
  CATEGORY_RANKS,
  MAXIMUM_PLAN_STEPS,
} from "./types.ts";

type Node = Record<string, unknown>;

const schema = TUTORIAL_V3_PLAN_SCHEMA as unknown as Node;

/** Every subschema in the document, with the path that reached it. */
function walk(node: unknown, path = "$"): Array<[string, Node]> {
  if (Array.isArray(node)) {
    return node.flatMap((entry, index) => walk(entry, `${path}[${index}]`));
  }
  if (typeof node !== "object" || node === null) return [];
  const current = node as Node;
  const children = Object.entries(current).flatMap(([key, value]) =>
    walk(value, `${path}.${key}`)
  );
  return [[path, current], ...children];
}

const nodes = walk(schema);

function at(path: string): Node {
  const found = nodes.find(([candidate]) => candidate === path);
  assert(found !== undefined, `no subschema at ${path}`);
  return found[1];
}

const stepProperties = at("$.properties.steps.items.properties");

/**
 * Whether a subschema admits `null`, in either JSON Schema encoding.
 *
 * Deliberately form-agnostic. The schema uses the union form, which
 * V3-10F4.4's bisection positively cleared — rewriting it to `anyOf` left the
 * request rejected, so the encoding is not the defect and must not be
 * "corrected". What these assertions pin is the Source-of-Truth contract that
 * survives either encoding: these fields may be null.
 */
function admitsNull(node: Node): boolean {
  if (Array.isArray(node.type)) return node.type.includes("null");
  if (Array.isArray(node.anyOf)) {
    return (node.anyOf as Node[]).some((branch) => branch.type === "null");
  }
  return false;
}

/** The non-null branch of a nullable subschema, in either encoding. */
function nonNullBranch(node: Node): Node | undefined {
  if (Array.isArray(node.anyOf)) {
    return (node.anyOf as Node[]).find((branch) => branch.type !== "null");
  }
  return Array.isArray(node.type) ? node : undefined;
}

Deno.test("every `type` names only real JSON Schema primitives", () => {
  const allowed = new Set([
    "string",
    "number",
    "integer",
    "boolean",
    "object",
    "array",
    "null",
  ]);
  for (const [path, node] of nodes) {
    if (node.type === undefined) continue;
    const declared = Array.isArray(node.type) ? node.type : [node.type];
    for (const entry of declared) {
      assert(
        typeof entry === "string" && allowed.has(entry),
        `${path} declares an unsupported type: ${JSON.stringify(entry)}`,
      );
    }
  }
});

Deno.test("every optional field can be null", () => {
  // `validation.ts` accepts an explicit null for each of these, and standard
  // mode depends on `product_id` being null rather than absent.
  const optional = [
    "product_id",
    "product_name",
    "shade_name",
    "color_hex",
    "finish",
    "coverage",
    "intensity",
    "amount",
    "tool_suggestion",
    "personalized_tip",
    "avoid",
    "guideline_visual_intent",
  ];
  for (const field of optional) {
    const node = stepProperties[field] as Node | undefined;
    assert(node !== undefined, `${field} is missing from the step schema`);
    assert(admitsNull(node), `${field} cannot be null`);
  }
});

Deno.test("no schema keyword can carry image, style or typography output", () => {
  // §15: the planner decides WHAT is taught; Flutter owns every pixel of how
  // it looks. A field named for colour is the shade of the product, never a
  // stroke colour, and there is no field for opacity, font or image bytes.
  const forbidden = [
    "image",
    "image_url",
    "inline_data",
    "svg",
    "html",
    "opacity",
    "stroke_width",
    "font",
    "gradient",
    "blend_mode",
    "result_image",
    "previous_step",
  ];
  const declared = new Set(Object.keys(stepProperties));
  for (const field of forbidden) {
    assert(!declared.has(field), `the step schema exposes "${field}"`);
  }
});

Deno.test("the category vocabulary still covers every canonical category", () => {
  const declared = (at("$.properties.steps.items.properties.category")
    .enum) as string[];

  // Source of Truth §31: all ten product categories must be representable,
  // plus the terminal final look.
  assertEquals([...declared].sort(), Object.keys(CATEGORY_RANKS).sort());
});

Deno.test("the personalized instruction fields are all present", () => {
  // §9 and §13: a Step Spec has to carry enough intent for the geometry mapper
  // to place a subtle natural liner differently from a dramatic party wing,
  // without the mapper making any makeup decision of its own.
  for (
    const field of [
      "where_to_apply",
      "direction",
      "technique",
      "coverage",
      "intensity",
      "finish",
      "shade_name",
      "color_hex",
      "amount",
      "tool_suggestion",
      "personalized_tip",
      "avoid",
      "face_attributes",
      "face_rationale",
      "target_rationale",
      "target_look_cues",
      "guideline_visual_intent",
    ]
  ) {
    assert(field in stepProperties, `${field} is missing from the schema`);
  }
});

Deno.test("guideline intent still pins the allowed marks", () => {
  const intent = stepProperties.guideline_visual_intent as Node;
  const objectBranch = nonNullBranch(intent);
  assert(objectBranch !== undefined, "guideline intent has no object branch");

  const properties = objectBranch.properties as Node;
  assertEquals(
    (objectBranch.required as string[]).sort(),
    ["description", "graphics"],
  );
  const graphics = (properties.graphics as Node).items as Node;
  assertEquals(
    [...(graphics.enum as string[])].sort(),
    [...ALLOWED_GRAPHICS].sort(),
  );
});

Deno.test("the scoped face attributes are exactly the five V3 allows", () => {
  const attributes = at(
    "$.properties.steps.items.properties.face_attributes.properties",
  );

  assertEquals(Object.keys(attributes).sort(), [
    "eye_shape",
    "face_shape",
    "lip_shape",
    "skin_tone",
    "undertone",
  ]);
});

Deno.test("the plan is an array of objects with no result field", () => {
  const steps = at("$.properties.steps");

  assertEquals(steps.type, "array");
  assertEquals(steps.minItems, 1);
  assertEquals(at("$.properties.steps.items").additionalProperties, false);
  assertEquals(schema.additionalProperties, false);
});

Deno.test("the step ceiling lives in the validator, not the wire schema", () => {
  // V3-10F4.4: `properties.steps.maxItems` is the construct that made
  // `gemini-3.6-flash` reject the entire request with 400 INVALID_ARGUMENT.
  // It is gone from the wire — and the rule it carried is enforced by
  // `parseAndValidatePlan` instead, which `validation_test.ts` proves. The two
  // assertions belong together: this one alone would look like a relaxation.
  assertEquals(at("$.properties.steps").maxItems, undefined);
  assertEquals(MAXIMUM_PLAN_STEPS, 12);

  // The bounds the same bisection cleared stay exactly where they were.
  assertEquals(
    at("$.properties.steps.items.properties.target_look_cues").maxItems,
    4,
  );
  const graphics = nonNullBranch(
    stepProperties.guideline_visual_intent as Node,
  );
  assertEquals(
    ((graphics?.properties as Node).graphics as Node).maxItems,
    5,
  );
});
