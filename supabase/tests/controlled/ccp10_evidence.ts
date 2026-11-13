/**
 * CCP-10 — failure evidence, so a refusal or a validator failure says why.
 *
 * Nothing here decides an outcome. The production guard and judge stay the only
 * authority: a recommendation refusal is explained by asking the real
 * `parseCustomPaletteRecommendation` about one field, then one token, at a time,
 * and a validator failure is diagnosed against the enums of the real validator
 * schema. Tests pin both to the production behaviour.
 */
import type { PaletteSelection } from "../../functions/_shared/custom_palette_contract.ts";
import { CUSTOM_PALETTE_FINISHES } from "../../functions/_shared/custom_palette_contract.ts";
import { ProviderCallFailed } from "../../functions/generate-custom-palette-preview/gemini_client.ts";
import {
  CUSTOM_PALETTE_VALIDATOR_SCHEMA,
  IDENTITY_FEATURES,
} from "../../functions/generate-custom-palette-preview/validator_prompt.ts";
import { GuardRefusal } from "./ccp10_guards.ts";

// ---------------------------------------------------------------------------
// Finding A: which words made the recommendation guard refuse
// ---------------------------------------------------------------------------

export type ConflictTokenClass =
  | "hex_or_rgb"
  | "color_word"
  | "finish_word"
  | "other";

export interface ConflictEvidence {
  field: "placement" | "technique" | "reasoning" | "summary";
  /** The selected category whose prose it is; null for the summary. */
  category: string | null;
  token: string;
  token_class: ConflictTokenClass;
  /** For a finish word, the finish it asserts. */
  finish_code: string | null;
  /** Another selected category whose own color or finish this token is, if any. */
  belongs_to_other_category: string | null;
  /** At most 40 characters either side of the token. */
  context: string;
}

export interface RefusalExplanation {
  response_parsed: boolean;
  conflicts: ConflictEvidence[];
}

type Parse = (
  value: string,
  selections: readonly PaletteSelection[],
) => unknown;

const NEUTRAL = "Apply evenly.";
const PROSE_FIELDS = ["placement", "technique", "reasoning"] as const;
const VALUE_NOTATION = /#[0-9a-f]{3,8}\b|\b(?:rgb|hsl|hsv|hwb|cmyk)a?\s*\(/gi;

/** True when the production guard refuses this plan for its prose. */
function guardRefuses(
  parse: Parse,
  plan: unknown,
  selections: readonly PaletteSelection[],
): boolean {
  try {
    parse(JSON.stringify(plan), selections);
    return false;
  } catch (error) {
    return (error as { code?: string }).code === "conflicting_palette_text";
  }
}

/** A plan the guard accepts, with one field replaced. */
function planWith(
  selections: readonly PaletteSelection[],
  field: ConflictEvidence["field"],
  category: string | null,
  value: string,
) {
  return {
    applications: selections.map((selection) => {
      const application: Record<string, string> = {
        categoryCode: selection.category_code,
        placement: NEUTRAL,
        technique: NEUTRAL,
        intensity: "medium",
        reasoning: NEUTRAL,
      };
      if (field !== "summary" && selection.category_code === category) {
        application[field] = value;
      }
      return application;
    }),
    overallIntensity: "medium",
    summary: field === "summary" ? value : NEUTRAL,
  };
}

function candidates(value: string): string[] {
  const found = [
    ...(value.match(VALUE_NOTATION) ?? []),
    ...(value.match(/[A-Za-z]+/g) ?? []),
  ];
  return [...new Set(found)];
}

/** True when the guard allows `token` as this one selection's own prose. */
function allowedFor(
  parse: Parse,
  token: string,
  selection: PaletteSelection,
): boolean {
  return !guardRefuses(
    parse,
    planWith(
      [selection],
      "placement",
      selection.category_code,
      `Use ${token} here.`,
    ),
    [selection],
  );
}

function tokenClass(
  parse: Parse,
  token: string,
  base: PaletteSelection,
): { token_class: ConflictTokenClass; finish_code: string | null } {
  if (new RegExp(VALUE_NOTATION.source, "i").test(token)) {
    return { token_class: "hex_or_rgb", finish_code: null };
  }
  // The guard refuses only value notation, finish words and color words. A token
  // some finish allows is that finish's word; any other refused token is allowed
  // only as a selection's own color label, so it is a color word.
  const finishes = new Set(Object.values(CUSTOM_PALETTE_FINISHES).flat());
  for (const finish of finishes) {
    const other = { ...base, color_label: "-", finish_code: finish } as never;
    if (allowedFor(parse, token, other)) {
      return { token_class: "finish_word", finish_code: finish };
    }
  }
  if (allowedFor(parse, token, { ...base, color_label: token })) {
    return { token_class: "color_word", finish_code: null };
  }
  return { token_class: "other", finish_code: null };
}

function contextOf(value: string, token: string): string {
  const at = value.toLowerCase().indexOf(token.toLowerCase());
  if (at < 0) return "";
  return value.slice(Math.max(0, at - 40), at + token.length + 40);
}

/**
 * Explains a `conflicting_palette_text` refusal from the model's raw JSON. The
 * production parser is passed in and is the only judge of what conflicts.
 */
export function explainPaletteConflict(
  text: string,
  selections: readonly PaletteSelection[],
  parse: Parse,
): RefusalExplanation {
  let root: Record<string, unknown>;
  try {
    root = JSON.parse(text);
    if (typeof root !== "object" || root === null) throw new Error();
  } catch {
    return { response_parsed: false, conflicts: [] };
  }
  const fields: Array<
    { field: ConflictEvidence["field"]; category: string | null; value: string }
  > = [];
  for (
    const entry of Array.isArray(root.applications) ? root.applications : []
  ) {
    const application = entry as Record<string, unknown>;
    if (!selections.some((s) => s.category_code === application.categoryCode)) {
      continue;
    }
    for (const field of PROSE_FIELDS) {
      if (typeof application[field] === "string") {
        fields.push({
          field,
          category: application.categoryCode as string,
          value: application[field] as string,
        });
      }
    }
  }
  if (typeof root.summary === "string") {
    fields.push({ field: "summary", category: null, value: root.summary });
  }

  const conflicts: ConflictEvidence[] = [];
  for (const { field, category, value } of fields) {
    if (
      !guardRefuses(
        parse,
        planWith(selections, field, category, value),
        selections,
      )
    ) {
      continue;
    }
    for (const token of candidates(value)) {
      const alone = planWith(selections, field, category, `Use ${token} here.`);
      if (!guardRefuses(parse, alone, selections)) continue;
      const own = selections.find((s) =>
        s.category_code !== category && allowedFor(parse, token, s)
      );
      conflicts.push({
        field,
        category,
        token,
        ...tokenClass(parse, token, selections[0]),
        belongs_to_other_category: field === "summary"
          ? null
          : own?.category_code ?? null,
        context: contextOf(value, token),
      });
    }
  }
  return { response_parsed: true, conflicts };
}

// ---------------------------------------------------------------------------
// Finding B: why a validator call produced no judgment
// ---------------------------------------------------------------------------

export type ValidatorFailureClass =
  | "provider_http_error"
  | "provider_timeout"
  | "provider_network_error"
  | "empty_candidate"
  | "blocked_candidate"
  | "malformed_validator_response"
  | "schema_validation_failure"
  | "parser_failure"
  | "harness_refusal"
  | "unknown_validator_failure";

/** What the harness saw of one validator response, before the client read it. */
export interface ValidatorResponseMeta {
  status: number;
  candidate_count: number | null;
  finish_reason: string | null;
  block_reason: string | null;
  text_length: number | null;
}

export interface ValidatorDiagnosis {
  /** Null when the response parses and satisfies every structural rule. */
  failure_class:
    | "malformed_validator_response"
    | "schema_validation_failure"
    | "parser_failure"
    | null;
  rule: string | null;
  selected_categories: string[];
  reported_categories: string[] | null;
  introduced_categories: string[] | null;
  identity_feature_count: number | null;
  observation_keys: string[] | null;
}

const SCHEMA = CUSTOM_PALETTE_VALIDATOR_SCHEMA.properties;
const OBSERVATION = SCHEMA.categories.items.properties;
const ENUMS: Record<string, ReadonlySet<string>> = {
  categoryCode: new Set(OBSERVATION.categoryCode.enum),
  presence: new Set(OBSERVATION.presence.enum),
  color: new Set(OBSERVATION.color.enum),
  colorReason: new Set(OBSERVATION.colorReason.enum),
  finish: new Set(OBSERVATION.finish.enum),
  finishReason: new Set(OBSERVATION.finishReason.enum),
};
const ROOT_KEYS = [...CUSTOM_PALETTE_VALIDATOR_SCHEMA.required].sort();
const OBSERVATION_KEYS = [...SCHEMA.categories.items.required].sort();
const IDENTITY_VALUES = new Set(SCHEMA.identity.enum);
const FEATURE_VALUES = new Set(
  // deno-lint-ignore no-explicit-any
  (SCHEMA.identityFeatures.properties as any)[IDENTITY_FEATURES[0]].enum,
);

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);
const sameKeys = (value: Record<string, unknown>, keys: readonly string[]) =>
  JSON.stringify(Object.keys(value).sort()) ===
    JSON.stringify([...keys].sort());

/**
 * The first structural rule a validator response breaks, in the order the
 * production judge checks them. Diagnostic only: the judge alone decides.
 */
export function diagnoseValidatorResponse(
  text: string,
  selections: readonly PaletteSelection[],
): ValidatorDiagnosis {
  const selected = selections.map((s) => s.category_code as string).sort();
  const out: ValidatorDiagnosis = {
    failure_class: null,
    rule: null,
    selected_categories: selected,
    reported_categories: null,
    introduced_categories: null,
    identity_feature_count: null,
    observation_keys: null,
  };
  const fail = (
    failure_class: ValidatorDiagnosis["failure_class"],
    rule: string,
  ) => ({
    ...out,
    failure_class,
    rule,
  });
  let root: unknown;
  try {
    root = JSON.parse(text);
  } catch {
    return fail("malformed_validator_response", "not_json");
  }
  if (!isRecord(root)) {
    return fail("malformed_validator_response", "not_object");
  }
  if (isRecord(root.identityFeatures)) {
    out.identity_feature_count = Object.keys(root.identityFeatures).length;
  }
  if (Array.isArray(root.categories)) {
    out.reported_categories = root.categories.map((c) =>
      isRecord(c) ? String(c.categoryCode) : "?"
    );
    const first = root.categories.find(isRecord);
    out.observation_keys = first ? Object.keys(first).sort() : null;
  }
  if (Array.isArray(root.introducedCategories)) {
    out.introduced_categories = root.introducedCategories.map(String);
  }
  if (!sameKeys(root, ROOT_KEYS)) {
    return fail("schema_validation_failure", "root_keys");
  }
  if (
    !Array.isArray(root.categories) || !Array.isArray(root.introducedCategories)
  ) {
    return fail("schema_validation_failure", "arrays");
  }
  for (const item of root.categories) {
    if (!isRecord(item) || !sameKeys(item, OBSERVATION_KEYS)) {
      return fail("schema_validation_failure", "observation_keys");
    }
    if (typeof item.featureVisibleInOriginal !== "boolean") {
      return fail("schema_validation_failure", "feature_visible_type");
    }
    for (const [key, allowed] of Object.entries(ENUMS)) {
      if (typeof item[key] !== "string" || !allowed.has(item[key] as string)) {
        return fail("schema_validation_failure", `enum:${key}`);
      }
    }
    const applied = item.presence === "present";
    if (applied === (item.color === "not_applicable")) {
      return fail("parser_failure", "presence_vs_color");
    }
    if (applied === (item.finish === "not_applicable")) {
      return fail("parser_failure", "presence_vs_finish");
    }
    if ((item.color === "different") !== (item.colorReason !== "none")) {
      return fail("parser_failure", "color_vs_reason");
    }
    if ((item.finish === "contradicted") !== (item.finishReason !== "none")) {
      return fail("parser_failure", "finish_vs_reason");
    }
  }
  const reported = root.categories.map((c) =>
    (c as { categoryCode: string }).categoryCode
  );
  if (
    reported.length !== selected.length ||
    new Set(reported).size !== selected.length ||
    reported.some((code) => !selected.includes(code))
  ) {
    return fail("parser_failure", "category_set");
  }
  for (const code of root.introducedCategories) {
    if (typeof code !== "string" || !ENUMS.categoryCode.has(code)) {
      return fail("schema_validation_failure", "enum:introducedCategories");
    }
    if (selected.includes(code)) {
      return fail("parser_failure", "introduced_is_selected");
    }
  }
  if (
    typeof root.identity !== "string" || !IDENTITY_VALUES.has(root.identity)
  ) {
    return fail("schema_validation_failure", "enum:identity");
  }
  if (
    !isRecord(root.identityFeatures) ||
    !sameKeys(root.identityFeatures, IDENTITY_FEATURES)
  ) {
    return fail("schema_validation_failure", "identity_feature_keys");
  }
  for (const key of IDENTITY_FEATURES) {
    const value = root.identityFeatures[key];
    if (typeof value !== "string" || !FEATURE_VALUES.has(value)) {
      return fail("schema_validation_failure", `enum:identityFeatures.${key}`);
    }
  }
  return out;
}

const BLOCKING_FINISH = new Set([
  "SAFETY",
  "PROHIBITED_CONTENT",
  "BLOCKLIST",
  "SPII",
  "RECITATION",
  "IMAGE_SAFETY",
]);

/**
 * Names the failure class of a validator call that produced no verdict, from the
 * error the client threw (or none), the response the harness saw, and the text.
 */
export function classifyValidatorFailure(
  error: unknown,
  meta: ValidatorResponseMeta | null,
  text: string | null,
  selections: readonly PaletteSelection[],
): {
  failure_class: ValidatorFailureClass;
  http_status: number | null;
  error_class: string | null;
  response_present: boolean;
  diagnosis: ValidatorDiagnosis | null;
} {
  const base = {
    http_status: meta?.status ?? null,
    error_class: error === null || error === undefined
      ? null
      : (error as Error).name ?? typeof error,
    response_present: meta !== null,
    diagnosis: null as ValidatorDiagnosis | null,
  };
  if (error !== null && error !== undefined) {
    if (error instanceof GuardRefusal) {
      return { ...base, failure_class: "harness_refusal" };
    }
    if (error instanceof ProviderCallFailed) {
      if (error.status !== null) {
        return {
          ...base,
          http_status: error.status,
          failure_class: "provider_http_error",
        };
      }
      const blocked =
        meta?.block_reason !== null && meta?.block_reason !== undefined ||
        BLOCKING_FINISH.has(meta?.finish_reason ?? "");
      return {
        ...base,
        failure_class: blocked ? "blocked_candidate" : "empty_candidate",
      };
    }
    const name = (error as { name?: string }).name;
    if (name === "TimeoutError" || name === "AbortError") {
      return { ...base, failure_class: "provider_timeout" };
    }
    if (error instanceof TypeError) {
      return { ...base, failure_class: "provider_network_error" };
    }
    return { ...base, failure_class: "unknown_validator_failure" };
  }
  if (text === null) {
    return { ...base, failure_class: "unknown_validator_failure" };
  }
  const diagnosis = diagnoseValidatorResponse(text, selections);
  return {
    ...base,
    diagnosis,
    failure_class: diagnosis.failure_class ?? "unknown_validator_failure",
  };
}

/** Reads what the harness may record about one validator response. */
export async function validatorResponseMeta(
  response: Response,
): Promise<ValidatorResponseMeta> {
  if (!response.ok) {
    return {
      status: response.status,
      candidate_count: null,
      finish_reason: null,
      block_reason: null,
      text_length: null,
    };
  }
  try {
    const body = await response.clone().json() as {
      candidates?: Array<
        {
          finishReason?: string;
          content?: { parts?: Array<{ text?: string }> };
        }
      >;
      promptFeedback?: { blockReason?: string };
    };
    const text = body.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? "").join("") ?? "";
    return {
      status: response.status,
      candidate_count: body.candidates?.length ?? 0,
      finish_reason: body.candidates?.[0]?.finishReason ?? null,
      block_reason: body.promptFeedback?.blockReason ?? null,
      text_length: text.length,
    };
  } catch {
    return {
      status: response.status,
      candidate_count: null,
      finish_reason: null,
      block_reason: null,
      text_length: null,
    };
  }
}
