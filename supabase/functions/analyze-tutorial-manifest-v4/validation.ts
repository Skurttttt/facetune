import {
  categoryPosition,
  FunctionFailure,
  INVENTORY_TO_TUTORIAL,
  type CategoryPresence,
  type ManifestItem,
  type ManifestVerdict,
  type ResolvedManifest,
  type SourceMode,
  TUTORIAL_CATEGORIES,
  TUTORIAL_CATEGORY_SET,
  type TutorialCategory,
} from "./types.ts";

const presences: ReadonlySet<string> = new Set([
  "present",
  "absent",
  "uncertain",
]);

function invalid(code = "invalid_ai_response"): FunctionFailure {
  return new FunctionFailure(
    502,
    code,
    "The tutorial analysis returned an unusable result.",
    true,
  );
}

/// Parses the model's structured verdict for every supported category.
///
/// Rejects rather than repairs. A response naming a category outside the
/// vocabulary, omitting one, or using a presence value outside the enum is a
/// failure — silently dropping the unknown key would let the model steer the
/// tutorial by omission.
export function parseManifestResponse(value: string): ManifestVerdict[] {
  let decoded: unknown;
  try {
    decoded = JSON.parse(value);
  } catch {
    throw new FunctionFailure(
      502,
      "malformed_ai_json",
      "The tutorial analysis returned malformed data.",
      true,
    );
  }
  if (
    typeof decoded !== "object" || decoded === null || Array.isArray(decoded)
  ) {
    throw invalid();
  }
  const root = decoded as Record<string, unknown>;

  for (const key of Object.keys(root)) {
    if (!TUTORIAL_CATEGORY_SET.has(key)) {
      throw invalid("unsupported_category");
    }
  }
  if (Object.keys(root).length !== TUTORIAL_CATEGORIES.length) {
    throw invalid("incomplete_manifest");
  }

  return TUTORIAL_CATEGORIES.map((category) => {
    const entry = root[category];
    if (
      typeof entry !== "object" || entry === null || Array.isArray(entry)
    ) {
      throw invalid();
    }
    const input = entry as Record<string, unknown>;
    for (const key of Object.keys(input)) {
      if (key !== "presence" && key !== "visualConfidence") throw invalid();
    }
    const presence = input.presence;
    if (typeof presence !== "string" || !presences.has(presence)) {
      throw invalid();
    }
    const confidence = input.visualConfidence;
    if (
      confidence !== null &&
      (typeof confidence !== "number" || !Number.isFinite(confidence) ||
        confidence < 0 || confidence > 1)
    ) {
      throw invalid();
    }
    return {
      category,
      presence: presence as CategoryPresence,
      visualConfidence: confidence as number | null,
    };
  });
}

/// The tutorial categories backed by at least one validated owned product.
///
/// Derived from the immutable snapshot through the server-owned mapping, never
/// from anything the model returned. An unmappable stored category is a hard
/// failure rather than a silent skip, because skipping it would understate
/// coverage and could manufacture a false mismatch.
export function productBackedCategories(
  snapshot: unknown,
): Set<TutorialCategory> {
  const backed = new Set<TutorialCategory>();
  if (!Array.isArray(snapshot)) return backed;
  for (const entry of snapshot) {
    if (typeof entry !== "object" || entry === null) continue;
    const category = (entry as Record<string, unknown>).category;
    if (typeof category !== "string") continue;
    const mapped = INVENTORY_TO_TUTORIAL[category];
    if (!mapped) {
      throw new FunctionFailure(
        422,
        "unsupported_inventory_category",
        "This look references a product category the tutorial cannot present.",
      );
    }
    backed.add(mapped);
  }
  return backed;
}

/// Turns visual verdicts into tutorial inclusion.
///
/// Standard Mode:  included = visually present.
/// My Makeup Kit:  included = visually present AND backed by an owned product.
///
/// `uncertain` is never included in either mode. A category the user owns a
/// product for but which is not visible is NOT included — owning a product is
/// not evidence that it was used. The reverse, visible but unowned, is the
/// `kit_preview_mismatch` condition: the preview promises something the kit
/// cannot reproduce, so no honest tutorial exists for it.
export function resolveManifest(
  verdicts: ManifestVerdict[],
  sourceMode: SourceMode,
  backedCategories: Set<TutorialCategory>,
): ResolvedManifest {
  const isKit = sourceMode === "my_makeup_kit";
  const items: ManifestItem[] = verdicts.map((verdict) => {
    const productBacked = isKit && backedCategories.has(verdict.category);
    const visible = verdict.presence === "present";
    return {
      ...verdict,
      position: categoryPosition(verdict.category),
      productBacked,
      included: isKit ? visible && productBacked : visible,
    };
  });

  // Sorting by the vocabulary position AFTER filtering is what keeps inclusion
  // and order independent: dropping contour and highlighter leaves everything
  // else in its original relative sequence.
  const ordered = [...items].sort((a, b) => a.position - b.position);
  const includedCategories = ordered
    .filter((item) => item.included)
    .map((item) => item.category);
  const unbackedPresentCategories = isKit
    ? ordered
      .filter((item) => item.presence === "present" && !item.productBacked)
      .map((item) => item.category)
    : [];

  return {
    items: ordered,
    includedCategories,
    unbackedPresentCategories,
    manifestStatus: unbackedPresentCategories.length > 0
      ? "kit_preview_mismatch"
      : "accepted",
  };
}
