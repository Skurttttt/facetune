export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = "FunctionFailure";
  }
}

export type Intensity = "sheer" | "soft" | "medium" | "bold";

/** The AI's contribution for one category. It holds no color and no finish. */
export interface CategoryApplication {
  categoryCode: string;
  placement: string;
  technique: string;
  intensity: Intensity;
  reasoning: string;
}

export interface CustomPalettePlan {
  applications: CategoryApplication[];
  overallIntensity: Intensity;
  summary: string;
}
