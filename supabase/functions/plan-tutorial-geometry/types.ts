export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

export type GeometryPoint = { x: number; y: number };

export type GeometryZone = {
  shape: "ellipse" | "polygon" | "soft_band" | "region";
  points: GeometryPoint[];
  confidence: number;
};

export type GeometryPath = {
  points: GeometryPoint[];
  confidence: number;
};

export type GeometryArrow = {
  from: GeometryPoint;
  to: GeometryPoint;
  confidence: number;
};

/** One canonical step category's validated, photo-grounded placement plan.
 * Deliberately not `PersonalizedTutorialStepSpec`-shaped: this is raw Gemini
 * output (TF-2). Mapping it into the canonical spec is TF-3's job. */
export type CategoryGeometryPlan = {
  category: string;
  placement: string;
  direction: string;
  intensity: string;
  technique: string;
  confidence: number;
  colorHex: string | null;
  finish: string | null;
  zones: GeometryZone[];
  paths: GeometryPath[];
  arrows: GeometryArrow[];
};

export type GeometryPlan = {
  steps: CategoryGeometryPlan[];
};

/** The real, already-persisted per-category facts this function validates
 * Gemini's output against -- sourced from each session's own
 * `tutorial_steps.personalized_spec_json`/`instruction_json` (TF-1), never
 * re-derived. Used to reject "no product invention" / "kit integrity"
 * violations: Gemini may only echo a color/finish that was already given to
 * it, never invent one. */
export type CategoryProductFacts = {
  category: string;
  label: string;
  productName?: string;
  colorName?: string;
  colorHex?: string;
  finish?: string;
  placement?: string;
  technique?: string;
  intensity?: string;
  /** Set only for a My Makeup Kit step -- the owned product snapshot's id,
   * present precisely when `personalized_spec_json.what.productSnapshot`
   * is non-null. Used for the "kit integrity" check: every kit-mode
   * category the plan covers must trace back to a real owned product. */
  kitProductId?: string;
};
