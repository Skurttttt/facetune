/** The controlled tutorial category vocabulary, in deterministic logical order.
 *
 * Mirrors `lib/features/tutorial/domain/entities/tutorial_category.dart`, and
 * lives in `_shared` so every server-side consumer reads one copy. A second
 * definition beside a consumer would be free to drift; this one cannot.
 *
 * Array order IS the deterministic presentation order. Position is derived from
 * the index rather than stored separately, so the two can never disagree.
 */
export const TUTORIAL_CATEGORIES = [
  "foundation",
  "concealer",
  "contour_bronzer",
  "blush",
  "highlighter",
  "eyebrows",
  "eyeshadow",
  "eyeliner",
  "lips",
] as const;

export type TutorialCategory = typeof TUTORIAL_CATEGORIES[number];

export const TUTORIAL_CATEGORY_SET: ReadonlySet<string> = new Set(
  TUTORIAL_CATEGORIES,
);

/** 1-based deterministic position of a category in the full vocabulary. */
export function categoryPosition(category: TutorialCategory): number {
  return TUTORIAL_CATEGORIES.indexOf(category) + 1;
}

export function asTutorialCategory(value: unknown): TutorialCategory | null {
  return typeof value === "string" && TUTORIAL_CATEGORY_SET.has(value)
    ? value as TutorialCategory
    : null;
}

/** My Makeup Kit inventory category -> tutorial category.
 *
 * Mirrors `TutorialCategoryMapping` in Dart. Many-to-one by design: lipstick
 * and lip_gloss both become one Lips step.
 */
export const INVENTORY_TO_TUTORIAL: Readonly<Record<string, TutorialCategory>> =
  {
    foundation: "foundation",
    concealer: "concealer",
    contour_bronzer: "contour_bronzer",
    blush: "blush",
    highlighter: "highlighter",
    eyebrow: "eyebrows",
    eyeshadow: "eyeshadow",
    eyeliner: "eyeliner",
    lipstick: "lips",
    lip_gloss: "lips",
  };

/** Standard Mode recommendation plan key -> tutorial category.
 *
 * These are the keys of the frozen Standard Mode recommendation schema, which
 * differ from the inventory vocabulary (`contour` vs `contour_bronzer`,
 * `highlight` vs `highlighter`, camelCase `lipGloss`). The mapping is explicit
 * precisely because it is not an identity transform.
 */
export const STANDARD_KEY_TO_TUTORIAL: Readonly<
  Record<string, TutorialCategory>
> = {
  foundation: "foundation",
  concealer: "concealer",
  contour: "contour_bronzer",
  highlight: "highlighter",
  blush: "blush",
  eyeshadow: "eyeshadow",
  eyebrow: "eyebrows",
  eyeliner: "eyeliner",
  lipstick: "lips",
  lipGloss: "lips",
};

/** The Standard Mode plan keys that feed one tutorial category, in order. */
export function standardKeysFor(category: TutorialCategory): string[] {
  return Object.keys(STANDARD_KEY_TO_TUTORIAL).filter(
    (key) => STANDARD_KEY_TO_TUTORIAL[key] === category,
  );
}

/** The inventory categories that feed one tutorial category, in order. */
export function inventoryCategoriesFor(category: TutorialCategory): string[] {
  return Object.keys(INVENTORY_TO_TUTORIAL).filter(
    (key) => INVENTORY_TO_TUTORIAL[key] === category,
  );
}

export type CategoryPresence = "present" | "absent" | "uncertain";
export type SourceMode = "standard" | "my_makeup_kit";
