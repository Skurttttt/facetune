import {
  categoryPosition,
  type CategoryPresence,
  FunctionFailure,
  INVENTORY_TO_TUTORIAL,
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
/// Standard Mode:  included = visually present. `uncertain` and `absent` are
///                 never included.
/// My Makeup Kit:  included = backed by the look's immutable product snapshot,
///                 whatever the visual verdict. The snapshot says which products
///                 were selected; the image only says where and how.
///
/// In My Makeup Kit a category that is visible but backed by no selected
/// product is never included. It is still reported, as
/// `unbackedPresentCategories` and a `kit_preview_mismatch` status, but that
/// status is a diagnostic: it no longer blocks the tutorial.
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
      included: isKit ? productBacked : visible,
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

/// Whether a persisted manifest may be returned instead of analyzing again.
///
/// The status and both versions must match what this function would produce
/// now. In My Makeup Kit mode the manifest must also be complete — one verdict
/// for every supported category. A kit session whose item rows never landed
/// (the session row is written first) is not a manifest at all; reusing it
/// would leave the tutorial with no steps forever, so it is analyzed again.
/// Standard Mode keeps its existing rule.
export function isReusableManifest(options: {
  sourceMode: SourceMode;
  manifestStatus: unknown;
  promptVersion: unknown;
  schemaVersion: unknown;
  currentPromptVersion: string;
  currentSchemaVersion: string;
  itemCount: number;
}): boolean {
  const settled = options.manifestStatus === "accepted" ||
    options.manifestStatus === "kit_preview_mismatch";
  if (
    !settled ||
    options.promptVersion !== options.currentPromptVersion ||
    options.schemaVersion !== options.currentSchemaVersion
  ) {
    return false;
  }
  return options.sourceMode !== "my_makeup_kit" ||
    options.itemCount === TUTORIAL_CATEGORIES.length;
}
