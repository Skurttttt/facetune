export type KitProduct = {
  id: string;
  user_id: string;
  category: string;
  product_name: string | null;
  color_hex: string;
  color_label: string | null;
  finish: string;
  foundation_depth: string | null;
  foundation_undertone: string | null;
};

export type SelectedProduct = {
  productId: string;
  category: string;
  colorHex: string;
  finish: string;
  placement: string;
  technique: string;
  intensity: "sheer" | "soft" | "medium" | "bold";
  reasoning: string;
};

export type KitRecommendationPlan = {
  selections: SelectedProduct[];
  categoryCoverage: CategoryCoverage[];
  overallIntensity: "sheer" | "soft" | "medium" | "bold";
  summary: string;
};

export type CategoryCoverage = {
  category: string;
  status: "selected" | "unavailable" | "not_required";
  selectedProductIds: string[];
};

export type SelectedProductAvailability = {
  productId: string;
  status: "available" | "deleted" | "modified";
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
