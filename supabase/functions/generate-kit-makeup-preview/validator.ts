import type { UsageSink } from "../_shared/ai_telemetry.ts";
import {
  type CanonicalPlan,
  PLAN_VALIDATION_CONTRACT_VERSION,
} from "../_shared/kit_makeup_plan.ts";
import {
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "../_shared/tutorial_vocabulary.ts";
import {
  requestGeminiKitPreviewValidation,
  type ValidatorImage,
  ValidatorProviderError,
} from "./validator_client.ts";

export const KIT_PREVIEW_VALIDATOR_VERSION = "kit_preview_validator_v1";

export type ValidationOutcome =
  | "accepted"
  | "retryable_mismatch"
  | "nonretryable_mismatch"
  | "validator_failure"
  | "provider_failure";

export type Presence = "present" | "absent" | "uncertain";

export type CategoryVerdict = {
  category: TutorialCategory;
  inOriginal: Presence;
  inCandidate: Presence;
  evidence: string;
};

export type ParsedVerdicts = {
  categories: Map<TutorialCategory, CategoryVerdict>;
  identity: "preserved" | "changed" | "uncertain";
};

export type MismatchCode =
  | "unplanned_makeup_present"
  | "required_not_visible"
  | "preexisting_forbidden_makeup"
  | "identity_changed";

export type MismatchReason = {
  code: MismatchCode;
  category: TutorialCategory | null;
};

/** What the plan expects of a category. */
export type Expectation = "required_visible" | "subtle_allowed" | "forbidden";

export type ValidationResult = {
  outcome: ValidationOutcome;
  validator_version: typeof KIT_PREVIEW_VALIDATOR_VERSION;
  planned_present_categories: TutorialCategory[];
  unexpected_present_categories: TutorialCategory[];
  missing_required_categories: TutorialCategory[];
  uncertain_categories: TutorialCategory[];
  mismatch_reasons: MismatchReason[];
  /** Sanitized code for a failure outcome; null otherwise. */
  failure_code: string | null;
  /** Per-category evidence, or null when no trustworthy verdict exists. */
  evidence: Record<string, unknown> | null;
};

/** A validator answer that cannot be trusted. Never accepted. */
class MalformedVerdict extends Error {}

const PRESENCE = new Set(["present", "absent", "uncertain"]);
const IDENTITY = new Set(["preserved", "changed", "uncertain"]);
const CONTROL = /[\x00-\x1F\x7F]/g;

/**
 * Parses the model's answer. Anything short of exactly one well-formed verdict
 * for each of the nine categories is malformed, and malformed never accepts.
 */
export function parseValidatorVerdicts(text: string): ParsedVerdicts {
  let decoded: unknown;
  try {
    decoded = JSON.parse(text);
  } catch {
    throw new MalformedVerdict();
  }
  if (typeof decoded !== "object" || decoded === null) {
    throw new MalformedVerdict();
  }
  const root = decoded as Record<string, unknown>;
  if (
    Object.keys(root).length !== 2 || !Array.isArray(root.categories) ||
    typeof root.identity !== "string" || !IDENTITY.has(root.identity)
  ) throw new MalformedVerdict();
  const categories = new Map<TutorialCategory, CategoryVerdict>();
  for (const entry of root.categories) {
    if (typeof entry !== "object" || entry === null) {
      throw new MalformedVerdict();
    }
    const value = entry as Record<string, unknown>;
    const category = value.category as TutorialCategory;
    if (
      Object.keys(value).length !== 4 ||
      !TUTORIAL_CATEGORIES.includes(category) || categories.has(category) ||
      typeof value.inOriginal !== "string" || !PRESENCE.has(value.inOriginal) ||
      typeof value.inCandidate !== "string" ||
      !PRESENCE.has(value.inCandidate) ||
      typeof value.evidence !== "string" || value.evidence.trim().length < 3
    ) throw new MalformedVerdict();
    categories.set(category, {
      category,
      inOriginal: value.inOriginal as Presence,
      inCandidate: value.inCandidate as Presence,
      evidence: value.evidence.replace(CONTROL, " ").trim().slice(0, 200),
    });
  }
  if (categories.size !== TUTORIAL_CATEGORIES.length) {
    throw new MalformedVerdict();
  }
  return {
    categories,
    identity: root.identity as ParsedVerdicts["identity"],
  };
}

/** The plan's expectation for every tutorial category. */
export function expectations(
  plan: CanonicalPlan,
): Map<TutorialCategory, Expectation> {
  const result = new Map<TutorialCategory, Expectation>();
  for (const category of TUTORIAL_CATEGORIES) {
    const items = plan.selected_items.filter((item) =>
      item.tutorial_category === category
    );
    result.set(
      category,
      items.length === 0
        ? "forbidden"
        : items.some((item) => item.visible_intent === "required_visible")
        ? "required_visible"
        : "subtle_allowed",
    );
  }
  return result;
}

/**
 * Judges the verdicts against the plan. Evidence-based and categorical: each
 * category's expectation meets its observed presence, and the outcome follows
 * from the combination, not from a score.
 *
 *   forbidden        + present in candidate  → unplanned makeup (retry),
 *                                              or pre-existing makeup the
 *                                              preview may not remove (no
 *                                              retry can fix it)
 *   forbidden        + uncertain             → recorded; accepted, matching
 *                                              the Tutorial's own rule that
 *                                              uncertain is never a mismatch
 *   required_visible + absent or uncertain   → required makeup not visible
 *   subtle_allowed   + absent or uncertain   → allowed
 *   identity changed                         → retry
 *   identity uncertain                       → cannot judge safety: failure
 */
export function decideValidation(
  plan: CanonicalPlan,
  verdicts: ParsedVerdicts,
): ValidationResult {
  const expected = expectations(plan);
  const planned: TutorialCategory[] = [];
  const unexpected: TutorialCategory[] = [];
  const missing: TutorialCategory[] = [];
  const uncertain: TutorialCategory[] = [];
  const reasons: MismatchReason[] = [];
  let preexisting = false;
  const evidence: Record<string, unknown> = {};

  for (const category of TUTORIAL_CATEGORIES) {
    const verdict = verdicts.categories.get(category)!;
    const expectation = expected.get(category)!;
    evidence[category] = {
      expected: expectation,
      inOriginal: verdict.inOriginal,
      inCandidate: verdict.inCandidate,
      evidence: verdict.evidence,
    };
    if (verdict.inCandidate === "uncertain") uncertain.push(category);
    if (expectation === "forbidden") {
      if (verdict.inCandidate !== "present") continue;
      unexpected.push(category);
      if (verdict.inOriginal === "present") {
        preexisting = true;
        reasons.push({ code: "preexisting_forbidden_makeup", category });
      } else {
        reasons.push({ code: "unplanned_makeup_present", category });
      }
      continue;
    }
    if (verdict.inCandidate === "present") {
      planned.push(category);
    } else if (expectation === "required_visible") {
      missing.push(category);
      reasons.push({ code: "required_not_visible", category });
    }
  }
  if (verdicts.identity === "changed") {
    reasons.push({ code: "identity_changed", category: null });
  }

  const base = {
    validator_version: KIT_PREVIEW_VALIDATOR_VERSION,
    planned_present_categories: planned,
    unexpected_present_categories: unexpected,
    missing_required_categories: missing,
    uncertain_categories: uncertain,
    mismatch_reasons: reasons,
    evidence: { identity: verdicts.identity, categories: evidence },
  } as const;
  if (preexisting) {
    return { ...base, outcome: "nonretryable_mismatch", failure_code: null };
  }
  if (reasons.length > 0) {
    return { ...base, outcome: "retryable_mismatch", failure_code: null };
  }
  if (verdicts.identity !== "preserved") {
    return {
      ...base,
      outcome: "validator_failure",
      failure_code: "identity_uncertain",
    };
  }
  return { ...base, outcome: "accepted", failure_code: null };
}

function failure(
  outcome: "validator_failure" | "provider_failure",
  code: string,
): ValidationResult {
  return {
    outcome,
    validator_version: KIT_PREVIEW_VALIDATOR_VERSION,
    planned_present_categories: [],
    unexpected_present_categories: [],
    missing_required_categories: [],
    uncertain_categories: [],
    mismatch_reasons: [],
    failure_code: code,
    evidence: null,
  };
}

export type ValidatorRequest = (
  original: ValidatorImage,
  candidate: ValidatorImage,
) => Promise<string>;

/**
 * Validates one candidate against its plan. Never throws for a model or
 * provider problem, and never returns `accepted` unless a complete, well-formed
 * verdict proved it: every other path is a failure outcome.
 */
export async function validateKitCandidate(
  plan: CanonicalPlan,
  original: ValidatorImage,
  candidate: ValidatorImage,
  request: ValidatorRequest,
): Promise<ValidationResult> {
  if (plan.validation_contract_version !== PLAN_VALIDATION_CONTRACT_VERSION) {
    return failure("validator_failure", "unsupported_validation_contract");
  }
  let text: string;
  try {
    text = await request(original, candidate);
  } catch (error) {
    return failure(
      "provider_failure",
      error instanceof ValidatorProviderError
        ? error.code
        : "validator_provider_error",
    );
  }
  let verdicts: ParsedVerdicts;
  try {
    verdicts = parseValidatorVerdicts(text);
  } catch {
    return failure("validator_failure", "malformed_verdict");
  }
  return decideValidation(plan, verdicts);
}

/** The production request: Gemini, server-side, with the given key. */
export function geminiValidatorRequest(
  apiKey: string,
  model: string,
  budgetMs: number,
  usageSink?: UsageSink,
): ValidatorRequest {
  return (original, candidate) =>
    requestGeminiKitPreviewValidation(
      apiKey,
      model,
      original,
      candidate,
      usageSink,
      budgetMs,
    );
}

/** The columns a finished `kit_preview_attempts` row takes from a result.
 *
 * Shaped to satisfy the table's checks for every outcome, so a result can
 * never be recorded as something it is not. An accepted result is recorded
 * only through the finalize function, which is why `accepted` maps to no
 * failure columns here. */
export function attemptColumns(result: ValidationResult): {
  outcome: ValidationOutcome;
  reason_code: string | null;
  validator_version: string | null;
  mismatch_categories: TutorialCategory[];
  missing_required_categories: TutorialCategory[];
  evidence_json: Record<string, unknown> | null;
} {
  switch (result.outcome) {
    case "accepted":
      return {
        outcome: "accepted",
        reason_code: null,
        validator_version: result.validator_version,
        mismatch_categories: [],
        missing_required_categories: [],
        evidence_json: result.evidence,
      };
    case "retryable_mismatch":
    case "nonretryable_mismatch":
      return {
        outcome: result.outcome,
        reason_code:
          result.mismatch_reasons.some((reason) =>
              reason.code === "identity_changed"
            )
            ? "identity_changed"
            : null,
        validator_version: result.validator_version,
        mismatch_categories: result.unexpected_present_categories,
        missing_required_categories: result.missing_required_categories,
        evidence_json: result.evidence,
      };
    case "validator_failure":
      return {
        outcome: "validator_failure",
        reason_code: result.failure_code,
        validator_version: result.validator_version,
        mismatch_categories: [],
        missing_required_categories: [],
        evidence_json: result.evidence,
      };
    case "provider_failure":
      return {
        outcome: "provider_failure",
        reason_code: result.failure_code,
        validator_version: null,
        mismatch_categories: [],
        missing_required_categories: [],
        evidence_json: null,
      };
  }
}
