/** The three grounded explanations shown behind one Palette card's
 * "Why this works for you".
 *
 * Carried on the item rather than on the plan because each category is
 * explained on its own terms: the blush explanation must talk about the blush
 * shade actually recommended, not about the look in general.
 *
 * This is *what and why*, deliberately not *where and how*. Placement and
 * technique already answer where and how, and the Step-by-Step tutorial is the
 * surface that teaches them. Education that repeated them would duplicate the
 * tutorial rather than explain the recommendation.
 */
export type RecommendationEducation = {
  /** Which actually-detected facial attributes drove this choice. */
  features: string;
  /** What this shade, finish, and intensity do visually. */
  effect: string;
  /** Why this supports the style the user actually selected. */
  style: string;
};

export type RecommendationItem = {
  name: string;
  hex: string | null;
  placement: string;
  technique: string;
  finish: string;
  intensity: string;
  reasoning: string;
  education: RecommendationEducation;
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
