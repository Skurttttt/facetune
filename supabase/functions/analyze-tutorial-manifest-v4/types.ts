// The category vocabulary and its mappings live in `_shared/tutorial_vocabulary.ts`
// so the analyzer and the source resolver read one definition. Re-exported here
// so existing imports in this function keep working unchanged.
export {
  asTutorialCategory,
  categoryPosition,
  INVENTORY_TO_TUTORIAL,
  STANDARD_KEY_TO_TUTORIAL,
  TUTORIAL_CATEGORIES,
  TUTORIAL_CATEGORY_SET,
} from "../_shared/tutorial_vocabulary.ts";
export type {
  CategoryPresence,
  SourceMode,
  TutorialCategory,
} from "../_shared/tutorial_vocabulary.ts";

import type {
  CategoryPresence,
  TutorialCategory,
} from "../_shared/tutorial_vocabulary.ts";

export interface ManifestVerdict {
  category: TutorialCategory;
  presence: CategoryPresence;
  /** Optional model-reported evidence score in 0..1. Never thresholded. */
  visualConfidence: number | null;
}

export interface ManifestItem extends ManifestVerdict {
  position: number;
  /** True only when an owned product maps to this category. */
  productBacked: boolean;
  /** True when this category becomes a tutorial step. */
  included: boolean;
}

export interface ResolvedManifest {
  items: ManifestItem[];
  includedCategories: TutorialCategory[];
  unbackedPresentCategories: TutorialCategory[];
  manifestStatus: "accepted" | "kit_preview_mismatch";
}

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
