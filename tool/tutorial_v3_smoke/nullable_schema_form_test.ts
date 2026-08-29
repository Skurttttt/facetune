import { assert, assertEquals } from "jsr:@std/assert@1";

import { toAnyOfNullable, unionTypePaths } from "./nullable_schema_form.ts";
import { TUTORIAL_V3_PLAN_SCHEMA } from "../../supabase/functions/plan-tutorial-v3/schema.ts";

Deno.test("a nullable string becomes anyOf with a null branch", () => {
  assertEquals(
    toAnyOfNullable({ type: ["string", "null"] }),
    { anyOf: [{ type: "string" }, { type: "null" }] },
  );
});

Deno.test("sibling constraints stay on the concrete branch", () => {
  // `pattern` constrains the string. Leaving it beside `anyOf` would apply it
  // to the null branch too and change what the schema accepts.
  assertEquals(
    toAnyOfNullable({ type: ["string", "null"], pattern: "^#[0-9A-F]{6}$" }),
    {
      anyOf: [
        { type: "string", pattern: "^#[0-9A-F]{6}$" },
        { type: "null" },
      ],
    },
  );
});

Deno.test("a description documents the property, not one branch", () => {
  assertEquals(
    toAnyOfNullable({ type: ["string", "null"], description: "why" }),
    {
      description: "why",
      anyOf: [{ type: "string" }, { type: "null" }],
    },
  );
});

Deno.test("a nullable object keeps its own properties and required list", () => {
  assertEquals(
    toAnyOfNullable({
      type: ["object", "null"],
      additionalProperties: false,
      required: ["a"],
      properties: { a: { type: "string" } },
    }),
    {
      anyOf: [
        {
          type: "object",
          additionalProperties: false,
          required: ["a"],
          properties: { a: { type: "string" } },
        },
        { type: "null" },
      ],
    },
  );
});

Deno.test("a non-nullable subschema is left exactly as it was", () => {
  const untouched = {
    type: "string",
    minLength: 3,
    enum: ["a", "b"],
  };
  assertEquals(toAnyOfNullable(untouched), untouched);
});

Deno.test("the rewrite reaches nested and arrayed subschemas", () => {
  assertEquals(
    toAnyOfNullable({
      type: "array",
      items: {
        type: "object",
        properties: { a: { type: ["string", "null"] } },
      },
    }),
    {
      type: "array",
      items: {
        type: "object",
        properties: {
          a: { anyOf: [{ type: "string" }, { type: "null" }] },
        },
      },
    },
  );
});

Deno.test("rewriting the real planner schema removes every union", () => {
  // The probe compares two encodings of the SAME contract. If the rewrite left
  // a union behind, the comparison would not isolate the construct.
  const rewritten = toAnyOfNullable(TUTORIAL_V3_PLAN_SCHEMA);

  assertEquals(unionTypePaths(rewritten), []);
});

Deno.test("the rewrite changes nothing but the nullability encoding", () => {
  // Every property name, enum, bound and description must survive, or the
  // probe would be comparing two different contracts and proving nothing.
  const names = (node: unknown): string[] => {
    if (Array.isArray(node)) return node.flatMap(names);
    if (typeof node !== "object" || node === null) return [];
    const entries = Object.entries(node as Record<string, unknown>);
    return entries.flatMap(([key, value]) =>
      key === "properties" && typeof value === "object" && value !== null
        ? [...Object.keys(value as Record<string, unknown>), ...names(value)]
        : names(value)
    );
  };

  const before = names(TUTORIAL_V3_PLAN_SCHEMA).sort();
  const after = names(toAnyOfNullable(TUTORIAL_V3_PLAN_SCHEMA)).sort();

  assertEquals(after, before);
  assert(before.includes("guideline_visual_intent"));
  assert(before.includes("where_to_apply"));
});

Deno.test("the deployed schema is reported honestly either way", () => {
  // Not an assertion about which encoding is correct — that is the open
  // question. It pins that the probe can still tell the two apart: the
  // rewrite must be a genuine change while the deployed form carries unions,
  // and a harmless no-op once it does not.
  const deployed = unionTypePaths(TUTORIAL_V3_PLAN_SCHEMA);
  const rewritten = unionTypePaths(toAnyOfNullable(TUTORIAL_V3_PLAN_SCHEMA));

  assertEquals(rewritten, []);
  assert(
    deployed.length === 0 ||
      JSON.stringify(toAnyOfNullable(TUTORIAL_V3_PLAN_SCHEMA)) !==
        JSON.stringify(TUTORIAL_V3_PLAN_SCHEMA),
    "the two probe variants must differ while unions are deployed",
  );
});
