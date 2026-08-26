import {
  ALLOWED_ATTRIBUTES,
  ALLOWED_CATEGORIES,
  ALLOWED_GRAPHICS,
  ALLOWED_STYLES,
  CATEGORY_ATTRIBUTES,
  CATEGORY_RANKS,
  FINAL_LOOK,
  FunctionFailure,
  type GuidelineVisualIntent,
  type OwnedProduct,
  type PlannedStep,
  type PlannedTutorial,
  type SourceMode,
} from "./types.ts";

/**
 * Rejects planner output that violates the V3 plan contract.
 *
 * This mirrors `TutorialV3PlanValidator` in
 * `lib/features/tutorial_v3/domain/validation/tutorial_v3_plan_validator.dart`.
 * The client validates again when it rebuilds the plan, but the server is the
 * gate that decides what may be persisted — a model response is never trusted
 * because it parsed.
 *
 * Every violation is collected rather than thrown on first sight, so a repair
 * retry can be told about all of them at once.
 */
export class PlanRejected extends Error {
  constructor(readonly reasons: string[]) {
    super(reasons.join(" "));
  }
}

export interface PlanValidationOptions {
  style: string;
  sourceMode: SourceMode;
  ownedProducts: OwnedProduct[];
  /**
   * The attribute values actually stored on the analysis, keyed by the same
   * snake_case names the plan uses. A step may only cite these values, so the
   * planner cannot invent a face it was not given.
   */
  analysisAttributes: Record<string, string>;
}

export function parseAndValidatePlan(
  raw: string,
  options: PlanValidationOptions,
): PlannedTutorial {
  if (!ALLOWED_STYLES.has(options.style)) {
    // A style the catalog does not contain cannot be taught, and would fail
    // the client's catalog lookup on reload.
    throw new FunctionFailure(
      400,
      "invalid_style",
      "Choose a supported makeup style.",
    );
  }

  let payload: unknown;
  try {
    payload = JSON.parse(stripCodeFence(raw));
  } catch {
    throw new PlanRejected(["The plan was not valid JSON."]);
  }
  if (
    typeof payload !== "object" || payload === null || Array.isArray(payload)
  ) {
    throw new PlanRejected(["The plan must be a JSON object."]);
  }

  const rawSteps = (payload as Record<string, unknown>).steps;
  if (!Array.isArray(rawSteps) || rawSteps.length === 0) {
    throw new PlanRejected(["The plan must contain a non-empty steps array."]);
  }

  const reasons: string[] = [];
  const steps: PlannedStep[] = [];
  for (let index = 0; index < rawSteps.length; index += 1) {
    const step = normalizeStep(rawSteps[index], index, reasons);
    if (step) steps.push(step);
  }
  if (steps.length !== rawSteps.length) throw new PlanRejected(reasons);

  validateTermination(steps, reasons);
  validateOrdering(steps, reasons);
  for (let index = 0; index < steps.length; index += 1) {
    validateStep(steps[index], index, options, reasons);
  }

  if (reasons.length > 0) throw new PlanRejected(reasons);
  return { steps };
}

function validateTermination(steps: PlannedStep[], reasons: string[]): void {
  const finalCount = steps.filter((step) => step.category === FINAL_LOOK).length;
  if (finalCount === 0) {
    reasons.push('The plan must end with a "final_look" step.');
  } else if (finalCount > 1) {
    reasons.push('The plan must contain exactly one "final_look" step.');
  } else if (steps[steps.length - 1].category !== FINAL_LOOK) {
    reasons.push('The "final_look" step must be last.');
  }
  if (steps.every((step) => step.category === FINAL_LOOK)) {
    reasons.push("The plan must contain at least one makeup step.");
  }
}

function validateOrdering(steps: PlannedStep[], reasons: string[]): void {
  // Strictly increasing canonical rank enforces all of: no repeated category,
  // foundation first when present, lip gloss after lip colour, and nothing
  // after the final look.
  const seen = new Set<string>();
  for (let index = 0; index < steps.length; index += 1) {
    const category = steps[index].category;
    if (seen.has(category)) {
      reasons.push(`Category "${category}" appears more than once.`);
      continue;
    }
    seen.add(category);
    if (index === 0) continue;
    const previous = steps[index - 1].category;
    if (CATEGORY_RANKS[category] <= CATEGORY_RANKS[previous]) {
      reasons.push(
        `Step ${index + 1} ("${category}") cannot follow "${previous}".`,
      );
    }
  }
}

function validateStep(
  step: PlannedStep,
  index: number,
  options: PlanValidationOptions,
  reasons: string[],
): void {
  const position = `Step ${index + 1} ("${step.category}")`;
  const isFinal = step.category === FINAL_LOOK;
  const isKit = options.sourceMode === "makeup_kit";

  // --- Guideline intent ----------------------------------------------------
  if (isFinal) {
    if (step.guidelineVisualIntent !== null) {
      reasons.push(
        `${position} must not carry a guideline: it reuses the final preview.`,
      );
    }
  } else if (step.guidelineVisualIntent === null) {
    reasons.push(`${position} must describe its guideline visual intent.`);
  } else {
    const graphics = step.guidelineVisualIntent.graphics;
    if (graphics.length === 0) {
      reasons.push(`${position} must draw at least one instructional mark.`);
    }
    for (const graphic of graphics) {
      if (!ALLOWED_GRAPHICS.has(graphic)) {
        reasons.push(`${position} requests an unsupported mark "${graphic}".`);
      }
    }
  }

  // --- Facial attribute scope ---------------------------------------------
  const allowed = CATEGORY_ATTRIBUTES[step.category] ?? new Set<string>();
  const present = Object.keys(step.faceAttributes);
  const extra = present.filter((key) => !allowed.has(key));
  if (extra.length > 0) {
    reasons.push(
      `${position} uses facial attributes that are not relevant to it: ` +
        `${extra.sort().join(", ")}.`,
    );
  }
  if (allowed.size > 0 && present.length === 0) {
    reasons.push(
      `${position} must be personalized by at least one relevant facial attribute.`,
    );
  }
  // Cited attributes must be this analysis's real values. Without this a
  // planner could describe a face the user does not have and the tutorial
  // would look personalized while being fiction.
  for (const [key, value] of Object.entries(step.faceAttributes)) {
    const actual = options.analysisAttributes[key];
    if (actual !== undefined && actual !== value) {
      reasons.push(
        `${position} cites ${key} "${value}" but this analysis is "${actual}".`,
      );
    }
  }

  // --- Products ------------------------------------------------------------
  if (isFinal) {
    if (step.productId !== null) {
      reasons.push(`${position} must not reference a product.`);
    }
    return;
  }

  if (!isKit) {
    if (step.productId !== null) {
      reasons.push(
        `${position} must not reference an owned product in standard mode.`,
      );
    }
    return;
  }

  if (step.productId === null) {
    reasons.push(`${position} must reference an owned product in Kit mode.`);
    return;
  }
  const owned = options.ownedProducts.find(
    (product) => product.productId === step.productId,
  );
  if (!owned) {
    // The planner named a product the server did not supply. This is the one
    // failure that must never be repaired by trusting the model.
    reasons.push(`${position} references a product the user does not own.`);
    return;
  }
  if (owned.category !== step.category) {
    reasons.push(`${position} references a ${owned.category} product.`);
  }
}

function normalizeStep(
  value: unknown,
  index: number,
  reasons: string[],
): PlannedStep | null {
  const position = `Step ${index + 1}`;
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    reasons.push(`${position} is not an object.`);
    return null;
  }
  const raw = value as Record<string, unknown>;

  const category = raw.category;
  if (typeof category !== "string" || !ALLOWED_CATEGORIES.has(category)) {
    reasons.push(`${position} has an unsupported category.`);
    return null;
  }

  const isFinal = category === FINAL_LOOK;
  const whereToApply = requiredText(raw.where_to_apply);
  const direction = requiredText(raw.direction);
  const technique = requiredText(raw.technique);
  const faceRationale = requiredText(raw.face_rationale);
  const targetRationale = requiredText(raw.target_rationale);

  // The final look teaches no application, so its placement fields are
  // allowed to be absent; every other step must supply them.
  if (!isFinal) {
    if (whereToApply === null) reasons.push(`${position} is missing where_to_apply.`);
    if (direction === null) reasons.push(`${position} is missing direction.`);
    if (technique === null) reasons.push(`${position} is missing technique.`);
  }
  if (faceRationale === null) {
    reasons.push(`${position} is missing face_rationale.`);
  }
  if (targetRationale === null) {
    reasons.push(`${position} is missing target_rationale.`);
  }

  const cues = normalizeCues(raw.target_look_cues);
  if (cues === null) {
    reasons.push(`${position} is missing target_look_cues.`);
  }

  const attributes = normalizeAttributes(raw.face_attributes, position, reasons);
  if (attributes === null) return null;

  const intent = normalizeIntent(raw.guideline_visual_intent, position, reasons);
  if (intent === undefined) return null;

  if (
    faceRationale === null || targetRationale === null || cues === null ||
    (!isFinal && (whereToApply === null || direction === null ||
      technique === null))
  ) {
    return null;
  }

  return {
    stepIndex: index + 1,
    category,
    productId: optionalText(raw.product_id),
    productName: optionalText(raw.product_name),
    shadeName: optionalText(raw.shade_name),
    colorHex: normalizeHex(raw.color_hex),
    finish: optionalText(raw.finish),
    coverage: optionalText(raw.coverage),
    intensity: optionalText(raw.intensity),
    whereToApply: whereToApply ?? "",
    direction: direction ?? "",
    technique: technique ?? "",
    amount: optionalText(raw.amount),
    toolSuggestion: optionalText(raw.tool_suggestion),
    personalizedTip: optionalText(raw.personalized_tip),
    avoid: optionalText(raw.avoid),
    faceAttributes: attributes,
    faceRationale,
    targetRationale,
    targetLookCues: cues,
    guidelineVisualIntent: intent,
  };
}

function normalizeAttributes(
  value: unknown,
  position: string,
  reasons: string[],
): Record<string, string> | null {
  if (value === undefined || value === null) return {};
  if (typeof value !== "object" || Array.isArray(value)) {
    reasons.push(`${position} has malformed face_attributes.`);
    return null;
  }
  const result: Record<string, string> = {};
  for (const [key, entry] of Object.entries(value as Record<string, unknown>)) {
    if (entry === null || entry === undefined) continue;
    if (!ALLOWED_ATTRIBUTES.has(key)) {
      reasons.push(`${position} uses an unknown facial attribute "${key}".`);
      continue;
    }
    const text = requiredText(entry);
    if (text === null) {
      reasons.push(`${position} has a blank value for "${key}".`);
      continue;
    }
    result[key] = text;
  }
  return result;
}

/**
 * Returns the intent, `null` when absent, or `undefined` when malformed.
 *
 * The three-way result matters: an absent intent is legal for the final look
 * and rejected elsewhere by `validateStep`, whereas a malformed one is never
 * legal and drops the whole step.
 */
function normalizeIntent(
  value: unknown,
  position: string,
  reasons: string[],
): GuidelineVisualIntent | null | undefined {
  if (value === undefined || value === null) return null;
  if (typeof value !== "object" || Array.isArray(value)) {
    reasons.push(`${position} has a malformed guideline_visual_intent.`);
    return undefined;
  }
  const raw = value as Record<string, unknown>;
  const description = requiredText(raw.description);
  if (description === null) {
    reasons.push(`${position} is missing a guideline description.`);
    return undefined;
  }
  if (!Array.isArray(raw.graphics)) {
    reasons.push(`${position} is missing guideline graphics.`);
    return undefined;
  }
  const graphics: string[] = [];
  for (const entry of raw.graphics) {
    const text = requiredText(entry);
    if (text === null) {
      reasons.push(`${position} has a blank guideline mark.`);
      return undefined;
    }
    graphics.push(text);
  }
  return { description, graphics };
}

function normalizeCues(value: unknown): string[] | null {
  if (!Array.isArray(value) || value.length === 0) return null;
  const cues: string[] = [];
  for (const entry of value) {
    const text = requiredText(entry);
    if (text === null) return null;
    cues.push(text);
  }
  return cues;
}

function normalizeHex(value: unknown): string | null {
  const text = optionalText(value);
  if (text === null) return null;
  return /^#[0-9A-Fa-f]{6}$/.test(text) ? text.toUpperCase() : null;
}

function requiredText(value: unknown): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

function optionalText(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  return requiredText(value);
}

/** Models sometimes wrap JSON in a markdown fence despite the schema. */
export function stripCodeFence(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("```")) return trimmed;
  return trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

/** The rows `persist_tutorial_v3_plan` expects. */
export function planRows(
  plan: PlannedTutorial,
  context: { style: string; sourceMode: SourceMode },
): Record<string, unknown>[] {
  return plan.steps.map((step) => {
    const isFinal = step.category === FINAL_LOOK;
    return {
      step_index: step.stepIndex,
      category: step.category,
      step_spec_json: stepSpecOf(step, context),
      product_snapshot_json: isFinal ? null : productSnapshotOf(step),
      guideline_status: isFinal ? "not_required" : "pending",
    };
  });
}

function productSnapshotOf(step: PlannedStep): Record<string, unknown> | null {
  const hasProduct = step.productId !== null || step.productName !== null ||
    step.shadeName !== null || step.colorHex !== null;
  if (!hasProduct) return null;
  const snapshot: Record<string, unknown> = { category: step.category };
  if (step.productId !== null) snapshot.product_id = step.productId;
  if (step.productName !== null) snapshot.product_name = step.productName;
  if (step.shadeName !== null) snapshot.shade_name = step.shadeName;
  if (step.colorHex !== null) snapshot.color_hex = step.colorHex;
  if (step.finish !== null) snapshot.finish = step.finish;
  return snapshot;
}

/**
 * The `step_spec_json` payload, in the exact shape
 * `TutorialV3StepSpecCodec.decode` reads.
 *
 * The product snapshot is deliberately excluded: it is stored in its own
 * column, so one copy exists and the two can never disagree.
 */
function stepSpecOf(
  step: PlannedStep,
  context: { style: string; sourceMode: SourceMode },
): Record<string, unknown> {
  const base: Record<string, unknown> = {
    step_index: step.stepIndex,
    category: step.category,
    // Taken from the session, never from the model: the selected look and the
    // recommendation source are server facts, not something a plan may claim.
    selected_style_code: context.style,
    source_mode: context.sourceMode,
    plan_version: 3,
    target_reference_mode: "full_canonical_preview",
    target_rationale: step.targetRationale,
  };
  if (step.category === FINAL_LOOK) return base;

  return {
    ...base,
    where_to_apply: step.whereToApply,
    direction: step.direction,
    technique: step.technique,
    ...(step.coverage !== null ? { coverage: step.coverage } : {}),
    ...(step.intensity !== null ? { intensity: step.intensity } : {}),
    ...(step.amount !== null ? { amount: step.amount } : {}),
    ...(step.toolSuggestion !== null
      ? { tool_suggestion: step.toolSuggestion }
      : {}),
    ...(step.personalizedTip !== null
      ? { personalized_tip: step.personalizedTip }
      : {}),
    ...(step.avoid !== null ? { avoid: step.avoid } : {}),
    face_attributes: step.faceAttributes,
    face_rationale: step.faceRationale,
    target_look_cues: step.targetLookCues,
    guideline_visual_intent: {
      description: step.guidelineVisualIntent!.description,
      graphics: step.guidelineVisualIntent!.graphics,
    },
  };
}
