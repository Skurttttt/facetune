export type RecommendationItem = {
  name: string;
  hex: string | null;
  placement: string;
  technique: string;
  finish: string;
  intensity: string;
  reasoning: string;
};

export type RecommendationPlan = {
  foundation: RecommendationItem;
  concealer: RecommendationItem;
  contour: RecommendationItem;
  highlight: RecommendationItem;
  blush: RecommendationItem;
  eyeshadow: RecommendationItem;
  eyebrow: RecommendationItem;
  eyeliner: RecommendationItem;
  lipstick: RecommendationItem;
  lipGloss: RecommendationItem;
  overallIntensity: string;
};

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
