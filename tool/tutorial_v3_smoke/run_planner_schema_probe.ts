/**
 * V3-10F4.1 — what exactly does Gemini reject about the planner request?
 *
 * Production logged `status=400` and nothing else, which is not a diagnosis:
 * Gemini answers 400 for an invalid schema, an unusable API key and a billing
 * precondition alike. This probe asks the real API, one construct at a time,
 * and prints only the sanitized error envelope.
 *
 * It sends NO user data: no selfie, no canonical preview, no analysis, no
 * recommendation, no persisted record. Every request carries one fixed
 * synthetic sentence. The only variable is the response schema.
 *
 * The API key is read from the environment and is never printed, never written
 * to disk and never passed as an argument, so it cannot reach shell history.
 *
 *   GEMINI_API_KEY=... npx -y deno@2 run \
 *     --allow-env=GEMINI_API_KEY,TUTORIAL_V3_PLANNER_MODEL --allow-net \
 *     tool/tutorial_v3_smoke/run_planner_schema_probe.ts
 *
 * Optional: --model=<name> (defaults to TUTORIAL_V3_PLANNER_MODEL, then
 * `gemini-3.6-flash`).
 */

import { describeGeminiError } from "../../supabase/functions/_shared/gemini_error.ts";
import { TUTORIAL_V3_PLAN_SCHEMA } from "../../supabase/functions/plan-tutorial-v3/schema.ts";
import { toAnyOfNullable } from "./nullable_schema_form.ts";

type Json = Record<string, unknown>;

/** One construct per case, so a rejection names a single suspect. */
const cases: Array<{ name: string; schema: Json | null }> = [
  { name: "no_schema_at_all", schema: null },
  {
    name: "minimal_object",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: { ok: { type: "string" } },
    },
  },
  {
    name: "anyOf_nullable_string",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: {
        ok: { anyOf: [{ type: "string" }, { type: "null" }] },
      },
    },
  },
  {
    name: "union_type_nullable_string",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: { ok: { type: ["string", "null"] } },
    },
  },
  {
    name: "union_type_nullable_object",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: {
        ok: {
          type: ["object", "null"],
          additionalProperties: false,
          properties: { inner: { type: "string" } },
        },
      },
    },
  },
  {
    name: "string_length_and_pattern",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: {
        ok: {
          type: "string",
          minLength: 3,
          maxLength: 220,
          pattern: "^#[0-9A-Fa-f]{6}$",
        },
      },
    },
  },
  {
    name: "array_item_bounds",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["ok"],
      properties: {
        ok: {
          type: "array",
          minItems: 1,
          maxItems: 4,
          items: { type: "string" },
        },
      },
    },
  },
  {
    name: "planner_schema_as_deployed",
    schema: TUTORIAL_V3_PLAN_SCHEMA as unknown as Json,
  },
  {
    name: "planner_schema_anyOf_nullable",
    schema: toAnyOfNullable(TUTORIAL_V3_PLAN_SCHEMA) as Json,
  },
];

function flagValue(name: string): string | null {
  const prefix = `--${name}=`;
  const match = Deno.args.find((argument) => argument.startsWith(prefix));
  return match ? match.slice(prefix.length) : null;
}

async function probe(
  apiKey: string,
  model: string,
  schema: Json | null,
): Promise<string> {
  const generationConfig: Json = {
    responseMimeType: "application/json",
    // Deliberately tiny: this probe asks whether the REQUEST is accepted, not
    // whether the answer is any good.
    maxOutputTokens: 64,
    temperature: 0.2,
    topP: 0.9,
    candidateCount: 1,
  };
  if (schema !== null) generationConfig.responseJsonSchema = schema;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${
      encodeURIComponent(model)
    }:generateContent`,
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({
        contents: [{ role: "user", parts: [{ text: "Reply with JSON." }] }],
        generationConfig,
      }),
      signal: AbortSignal.timeout(60000),
    },
  );
  if (response.ok) {
    // The body is discarded unread: acceptance is the whole result.
    await response.body?.cancel();
    return "ACCEPTED";
  }
  const detail = await describeGeminiError(response);
  return `REJECTED status=${detail.httpStatus} ` +
    `api_status=${detail.apiStatus ?? "none"} ` +
    `reason=${detail.reason ?? "none"} kind=${detail.kind} ` +
    `message="${detail.message}"`;
}

const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
if (!apiKey) {
  console.error(
    "GEMINI_API_KEY is not set. Export it in this shell and re-run; " +
      "the probe never prints or stores it.",
  );
  Deno.exit(2);
}
const configuredModel = flagValue("model") ??
  Deno.env.get("TUTORIAL_V3_PLANNER_MODEL")?.trim();
// Mirrors the server default in `plan-tutorial-v3/index.ts`, so the probe asks
// about the same model production asks about.
const model = configuredModel && configuredModel.length > 0
  ? configuredModel
  : "gemini-3.6-flash";

console.log(`model=${model} endpoint=/v1beta field=responseJsonSchema`);
console.log("");
for (const testCase of cases) {
  let outcome: string;
  try {
    outcome = await probe(apiKey, model, testCase.schema);
  } catch (error) {
    outcome = `ERROR ${error instanceof Error ? error.name : "unknown"}`;
  }
  console.log(`${testCase.name.padEnd(30)} ${outcome}`);
}
