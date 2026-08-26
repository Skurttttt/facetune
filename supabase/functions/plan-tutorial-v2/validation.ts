import {
  ALLOWED_INTENSITIES,
  ALLOWED_STYLES,
  CATEGORY_RANKS,
  FINAL_LOOK,
  FunctionFailure,
  type OwnedProduct,
  type PlannedStep,
  type PlannedTutorial,
} from "./types.ts";

/**
 * Rejects planner output that violates the V2 plan contract.
 *
 * This mirrors `TutorialV2PlanValidator` in
 * `lib/features/tutorial_v2/domain/validation/tutorial_v2_plan_validator.dart`.
 * The client validates again when it rebuilds the plan, but the server is the
 * gate that decides what is allowed to be persisted — a model response is
 * never trusted because it parsed.
 *
 * Every violation is collected rather than thrown on first sight, so a repair
 * retry can be told about all of them at once.
 */
export class PlanRejected extends Error {
  constructor(readonly reasons: string[]) {
    super(reasons.join(" "));
  }
}

export function parseAndValidatePlan(
  raw: string,
  options: {
    style: string;
    sourceMode: "standard_recommendation" | "makeup_kit";
    ownedProducts: OwnedProduct[];
  },
): PlannedTutorial {
  let payload: unknown;
  try {
    payload = JSON.parse(stripCodeFence(raw));
  } catch {
    throw new PlanRejected(["The plan was not valid JSON."]);
  }

  if (!ALLOWED_STYLES.has(options.style)) {
    // A style the catalog does not contain cannot be taught, and would fail
    // the client's catalog lookup on reload.
    throw new FunctionFailure(
      400,
      "invalid_style",
      "Choose a supported makeup style.",
    );
  }

  if (
    typeof payload !== "object" || payload === null || Array.isArray(payload)
  ) {
    throw new PlanRejected(["The plan must be a JSON object."]);
  }
  const root = payload as Record<string, unknown>;
  const rawSteps = root.steps;
  if (!Array.isArray(rawSteps) || rawSteps.length === 0) {
    throw new PlanRejected(["The plan must contain a non-empty steps array."]);
  }

  const reasons: string[] = [];
  const isKit = options.sourceMode === "makeup_kit";
  const ownedById = new Map(
    options.ownedProducts.map((product) => [product.productId, product]),
  );

  const steps: PlannedStep[] = [];
  for (let index = 0; index < rawSteps.length; index += 1) {
    const step = normalizeStep(rawSteps[index], index, reasons);
    if (step) steps.push(step);
  }
  if (steps.length !== rawSteps.length) throw new PlanRejected(reasons);

  // --- Final Look placement -------------------------------------------------
  const finalCount = steps.filter((step) =>
    step.category === FINAL_LOOK
  ).length;
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

  // --- Ordering, duplicates, cumulative consistency -------------------------
  // Strictly increasing canonical rank enforces all of: no repeated category,
  // no concealer before foundation, no lip gloss before lip colour, and no
  // category appearing after the final look.
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

  // --- Per-step product rules ----------------------------------------------
  for (let index = 0; index < steps.length; index += 1) {
    const step = steps[index];
    const position = `Step ${index + 1} ("${step.category}")`;

    if (step.category === FINAL_LOOK) {
      if (step.productId !== null) {
        reasons.push(`${position} must not reference a product.`);
      }
      continue;
    }

    if (!isKit) {
      if (step.productId !== null) {
        reasons.push(`${position} must not reference a product in standard mode.`);
      }
      continue;
    }

    if (step.productId === null) {
      reasons.push(`${position} must reference an owned product in Kit mode.`);
      continue;
    }
    const owned = ownedById.get(step.productId);
    if (!owned) {
      // The planner named a product the server did not supply. This is the
      // one failure that must never be repaired by trusting the model.
      reasons.push(`${position} references a product the user does not own.`);
      continue;
    }
    if (owned.category !== step.category) {
      reasons.push(
        `${position} references a ${owned.category} product.`,
      );
    }
  }

  if (reasons.length > 0) throw new PlanRejected(reasons);
  return { steps };
}

function normalizeStep(
  value: unknown,
  index: number,
  reasons: string[],
): PlannedStep | null {
  const position = `Step ${index + 1}`;
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    reasons.push(`${position} must be an object.`);
    return null;
  }
  const step = value as Record<string, unknown>;

  const category = step.category;
  if (typeof category !== "string" || !(category in CATEGORY_RANKS)) {
    reasons.push(`${position} has an unknown category.`);
    return null;
  }

  const required = (key: string): string | null => {
    const item = step[key];
    if (typeof item !== "string" || item.trim().length === 0) {
      reasons.push(`${position} is missing ${key}.`);
      return null;
    }
    return item;
  };

  const optional = (key: string): string | null | undefined => {
    const item = step[key];
    if (item === null || item === undefined) return null;
    if (typeof item !== "string" || item.trim().length === 0) {
      reasons.push(`${position} has a blank ${key}.`);
      return undefined;
    }
    return item;
  };

  const title = required("title");
  const whatToApply = required("whatToApply");
  const technique = required("technique");
  const targetLookCues = required("targetLookCues");
  const intensity = required("intensity");

  // The final look teaches no placement of its own, so it is not held to the
  // placement fields — matching the client's validator.
  const isFinal = category === FINAL_LOOK;
  const whereToApply = isFinal
    ? (typeof step.whereToApply === "string" ? step.whereToApply : "")
    : required("whereToApply");
  const direction = isFinal
    ? (typeof step.direction === "string" ? step.direction : "")
    : required("direction");
  const faceRationale = isFinal
    ? (typeof step.faceRationale === "string" ? step.faceRationale : "")
    : required("faceRationale");

  if (
    intensity !== null && !ALLOWED_INTENSITIES.includes(intensity)
  ) {
    reasons.push(`${position} has an unsupported intensity.`);
  }

  const amount = optional("amount");
  const toolSuggestion = optional("toolSuggestion");
  const personalizedTip = optional("personalizedTip");
  const avoid = optional("avoid");

  const productIdValue = step.productId;
  let productId: string | null = null;
  if (typeof productIdValue === "string" && productIdValue.trim().length > 0) {
    productId = productIdValue;
  } else if (productIdValue !== null && productIdValue !== undefined) {
    reasons.push(`${position} has an invalid productId.`);
    return null;
  }

  if (
    title === null || whatToApply === null || technique === null ||
    targetLookCues === null || intensity === null || whereToApply === null ||
    direction === null || faceRationale === null ||
    amount === undefined || toolSuggestion === undefined ||
    personalizedTip === undefined || avoid === undefined
  ) {
    return null;
  }

  return {
    category,
    title,
    whatToApply,
    whereToApply,
    direction,
    technique,
    intensity,
    faceRationale,
    targetLookCues,
    amount,
    toolSuggestion,
    personalizedTip,
    avoid,
    productId,
  };
}

/** Some models wrap JSON in a fenced block despite a JSON response type. */
function stripCodeFence(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed.startsWith("```")) return trimmed;
  return trimmed
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/\s*```$/, "")
    .trim();
}

/**
 * Turns a validated plan into the row payload
 * `public.persist_tutorial_v2_plan` expects.
 *
 * Step indexes are assigned here from array order, so they are sequential and
 * zero-based by construction. The product snapshot is built from the server's
 * own owned-product record, never from anything the model wrote.
 */
export function planRows(
  plan: PlannedTutorial,
  ownedProducts: OwnedProduct[],
): Record<string, unknown>[] {
  const ownedById = new Map(
    ownedProducts.map((product) => [product.productId, product]),
  );
  return plan.steps.map((step, index) => {
    const owned = step.productId ? ownedById.get(step.productId) : undefined;
    return {
      step_index: index,
      category: step.category,
      step_spec_json: {
        schema: 1,
        category: step.category,
        title: step.title,
        whatToApply: step.whatToApply,
        whereToApply: step.whereToApply,
        direction: step.direction,
        technique: step.technique,
        intensity: step.intensity,
        faceRationale: step.faceRationale,
        targetLookCues: step.targetLookCues,
        amount: step.amount,
        toolSuggestion: step.toolSuggestion,
        personalizedTip: step.personalizedTip,
        avoid: step.avoid,
      },
      product_snapshot_json: owned
        ? {
          productId: owned.productId,
          category: owned.category,
          colorHex: owned.colorHex,
          finish: owned.finish,
          productName: owned.productName,
          colorLabel: owned.colorLabel,
          foundationDepth: owned.foundationDepth,
          foundationUndertone: owned.foundationUndertone,
        }
        : null,
      // The final look reuses the canonical preview, so it needs no guideline
      // asset generated for it.
      guideline_status: step.category === FINAL_LOOK ? "ready" : "pending",
      result_status: "pending",
    };
  });
}
