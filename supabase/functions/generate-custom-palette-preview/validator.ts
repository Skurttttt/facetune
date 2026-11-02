import type { PaletteSelection } from "../_shared/custom_palette_contract.ts";
import { CUSTOM_PALETTE_CATEGORIES } from "../_shared/custom_palette_contract.ts";
import { CUSTOM_PALETTE_VALIDATOR_VERSION } from "./validator_prompt.ts";

export type PreviewOutcome =
  | "accepted"
  | "retryable_palette_mismatch"
  | "nonretryable_palette_mismatch"
  | "validator_failure"
  | "provider_failure";

export interface CategoryReason {
  category: string;
  reason: string;
}

export type IdentityObservation = "preserved" | "changed" | "uncertain";

/** The structured result of judging one candidate. Codes only, never prose. */
export interface PreviewVerdict {
  outcome: PreviewOutcome;
  mismatch_categories: string[];
  color_mismatch_reasons: CategoryReason[];
  finish_mismatch_reasons: CategoryReason[];
  uncertain_categories: string[];
  introduced_categories: string[];
  identity: IdentityObservation | null;
  validator_version: string;
  /** A controlled code when no judgment could be made; otherwise `null`. */
  failure_code: string | null;
}

interface CategoryObservation {
  categoryCode: string;
  featureVisibleInOriginal: boolean;
  presence: "present" | "absent" | "uncertain";
  color: "consistent" | "different" | "uncertain" | "not_applicable";
  colorReason: string;
  finish: "consistent" | "contradicted" | "not_judgeable" | "not_applicable";
  finishReason: string;
}

const ROOT_KEYS = new Set(["categories", "introducedCategories", "identity"]);
const OBSERVATION_KEYS = new Set([
  "categoryCode",
  "featureVisibleInOriginal",
  "presence",
  "color",
  "colorReason",
  "finish",
  "finishReason",
]);
const PRESENCE = new Set(["present", "absent", "uncertain"]);
const COLOR = new Set([
  "consistent",
  "different",
  "uncertain",
  "not_applicable",
]);
const COLOR_REASONS = new Set([
  "none",
  "hue_differs",
  "much_lighter",
  "much_darker",
  "much_more_saturated",
  "much_less_saturated",
]);
const FINISH = new Set([
  "consistent",
  "contradicted",
  "not_judgeable",
  "not_applicable",
]);
const FINISH_REASONS = new Set([
  "none",
  "too_shiny",
  "too_flat",
  "wrong_texture",
]);
const IDENTITY = new Set(["preserved", "changed", "uncertain"]);

/** A verdict for when no judgment exists. Never `accepted`. */
export function failedVerdict(
  outcome: "validator_failure" | "provider_failure",
  failureCode: string,
): PreviewVerdict {
  return {
    outcome,
    mismatch_categories: [],
    color_mismatch_reasons: [],
    finish_mismatch_reasons: [],
    uncertain_categories: [],
    introduced_categories: [],
    identity: null,
    validator_version: CUSTOM_PALETTE_VALIDATOR_VERSION,
    failure_code: failureCode,
  };
}

class MalformedObservation extends Error {}

function record(value: unknown): Record<string, unknown> {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new MalformedObservation();
  }
  return value as Record<string, unknown>;
}

function member(value: unknown, allowed: ReadonlySet<string>): string {
  if (typeof value !== "string" || !allowed.has(value)) {
    throw new MalformedObservation();
  }
  return value;
}

function onlyKeys(
  value: Record<string, unknown>,
  allowed: ReadonlySet<string>,
) {
  const keys = Object.keys(value);
  if (keys.length !== allowed.size || keys.some((key) => !allowed.has(key))) {
    throw new MalformedObservation();
  }
}

function parseObservation(value: unknown): CategoryObservation {
  const input = record(value);
  onlyKeys(input, OBSERVATION_KEYS);
  if (typeof input.featureVisibleInOriginal !== "boolean") {
    throw new MalformedObservation();
  }
  const observation: CategoryObservation = {
    categoryCode: member(
      input.categoryCode,
      new Set(CUSTOM_PALETTE_CATEGORIES),
    ),
    featureVisibleInOriginal: input.featureVisibleInOriginal,
    presence: member(
      input.presence,
      PRESENCE,
    ) as CategoryObservation["presence"],
    color: member(input.color, COLOR) as CategoryObservation["color"],
    colorReason: member(input.colorReason, COLOR_REASONS),
    finish: member(input.finish, FINISH) as CategoryObservation["finish"],
    finishReason: member(input.finishReason, FINISH_REASONS),
  };
  // An answer that contradicts itself is not evidence of anything.
  const applied = observation.presence === "present";
  if (applied === (observation.color === "not_applicable")) {
    throw new MalformedObservation();
  }
  if (applied === (observation.finish === "not_applicable")) {
    throw new MalformedObservation();
  }
  if (
    (observation.color === "different") !== (observation.colorReason !== "none")
  ) {
    throw new MalformedObservation();
  }
  if (
    (observation.finish === "contradicted") !==
      (observation.finishReason !== "none")
  ) {
    throw new MalformedObservation();
  }
  return observation;
}

/**
 * Turns the validator model's observations into an outcome.
 *
 * The rule is positive: a candidate is accepted only when every selected
 * category is seen present with a consistent color, no finish is contradicted,
 * no unselected category was added, and identity is preserved. Anything else,
 * including "uncertain", does not pass. Malformed output of any kind is a
 * validator failure, which is also not a pass.
 *
 * A finish the image cannot show is not held against the candidate. Complexion
 * is not judged at all: no evidence yet supports a rule for it (CCP-1).
 */
export function judgeValidatorResponse(
  text: string,
  selections: readonly PaletteSelection[],
): PreviewVerdict {
  let observations: CategoryObservation[];
  let introduced: string[];
  let identity: IdentityObservation;
  try {
    const root = record(JSON.parse(text));
    onlyKeys(root, ROOT_KEYS);
    if (
      !Array.isArray(root.categories) ||
      !Array.isArray(root.introducedCategories)
    ) {
      throw new MalformedObservation();
    }
    observations = root.categories.map(parseObservation);
    const selected = new Set(selections.map((s) => s.category_code as string));
    const reported = new Set(observations.map((o) => o.categoryCode));
    if (
      observations.length !== selected.size ||
      reported.size !== selected.size ||
      [...reported].some((code) => !selected.has(code))
    ) {
      throw new MalformedObservation();
    }
    introduced = root.introducedCategories.map((code) =>
      member(code, new Set(CUSTOM_PALETTE_CATEGORIES))
    );
    if (introduced.some((code) => selected.has(code))) {
      throw new MalformedObservation();
    }
    identity = member(root.identity, IDENTITY) as IdentityObservation;
  } catch {
    return failedVerdict("validator_failure", "malformed_validator_response");
  }

  const mismatches: string[] = [];
  const colorReasons: CategoryReason[] = [];
  const finishReasons: CategoryReason[] = [];
  const uncertain: string[] = [];
  let featureHidden = false;
  for (const selection of selections) {
    const category = selection.category_code;
    const seen = observations.find((o) => o.categoryCode === category)!;
    let mismatch = false;
    if (!seen.featureVisibleInOriginal) {
      featureHidden = true;
      mismatch = true;
      colorReasons.push({ category, reason: "feature_not_visible" });
    } else if (seen.presence === "absent") {
      mismatch = true;
      colorReasons.push({ category, reason: "not_applied" });
    }
    if (seen.color === "different") {
      mismatch = true;
      colorReasons.push({ category, reason: seen.colorReason });
    }
    if (seen.finish === "contradicted") {
      mismatch = true;
      finishReasons.push({ category, reason: seen.finishReason });
    }
    if (mismatch) mismatches.push(category);
    if (seen.presence === "uncertain" || seen.color === "uncertain") {
      uncertain.push(category);
    }
  }

  const passes = mismatches.length === 0 && uncertain.length === 0 &&
    introduced.length === 0 && identity === "preserved";
  return {
    // A retry cannot put makeup on a feature the photograph does not show.
    outcome: featureHidden
      ? "nonretryable_palette_mismatch"
      : passes
      ? "accepted"
      : "retryable_palette_mismatch",
    mismatch_categories: mismatches,
    color_mismatch_reasons: colorReasons,
    finish_mismatch_reasons: finishReasons,
    uncertain_categories: uncertain,
    introduced_categories: introduced,
    identity,
    validator_version: CUSTOM_PALETTE_VALIDATOR_VERSION,
    failure_code: null,
  };
}
