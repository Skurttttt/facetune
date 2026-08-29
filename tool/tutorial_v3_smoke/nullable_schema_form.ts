/**
 * The two JSON Schema encodings of "this field may be null".
 *
 * V3-10F4.1 needs to compare them against the live Gemini API while holding
 * everything else identical, because the union form is the only construct in
 * the V3 planner schema that no request in this project has been observed to
 * have accepted — and also the only thing separating the planner from four
 * functions that work in production.
 *
 * The rewrite is derived from whichever schema is passed in rather than
 * hard-coded, so the probe keeps comparing the two encodings of the SAME
 * contract no matter which one `plan-tutorial-v3` currently ships.
 */

type Json = Record<string, unknown>;

/** Rewrites `type: [..., "null"]` into `anyOf: [<schema>, {"type":"null"}]`. */
export function toAnyOfNullable(node: unknown): unknown {
  if (Array.isArray(node)) return node.map(toAnyOfNullable);
  if (typeof node !== "object" || node === null) return node;

  const source = node as Json;
  const rewritten: Json = {};
  for (const [key, value] of Object.entries(source)) {
    rewritten[key] = toAnyOfNullable(value);
  }

  const declared = source.type;
  if (!Array.isArray(declared) || !declared.includes("null")) return rewritten;

  // `description` stays on the outer node: it documents the property, not one
  // branch of it. Every other sibling keyword belongs to the concrete branch —
  // `pattern` constrains the string, not the null.
  const { type: _dropped, description, ...rest } = rewritten;
  const branches = declared
    .filter((entry) => entry !== "null")
    .map((entry) => ({ type: entry, ...rest }));
  const result: Json = { anyOf: [...branches, { type: "null" }] };
  if (description !== undefined) result.description = description;
  return result;
}

/** Every path in `node` whose `type` is a union array. */
export function unionTypePaths(node: unknown, path = "$"): string[] {
  if (Array.isArray(node)) {
    return node.flatMap((entry, index) =>
      unionTypePaths(entry, `${path}[${index}]`)
    );
  }
  if (typeof node !== "object" || node === null) return [];
  const found: string[] = [];
  for (const [key, value] of Object.entries(node as Json)) {
    if (key === "type" && Array.isArray(value)) found.push(path);
    found.push(...unionTypePaths(value, `${path}.${key}`));
  }
  return found;
}
