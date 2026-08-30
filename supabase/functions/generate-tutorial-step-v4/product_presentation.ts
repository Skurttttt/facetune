import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";
import type {
  ResolvedProduct,
  StandardCategoryPlan,
} from "../_shared/tutorial_source_resolver.ts";

/// What the app shows beside a tutorial step.
///
/// This is the ONLY channel for product wording. None of it is ever sent to the
/// image model or baked into a rendered guideline — the image carries drawn
/// markings alone, and Flutter renders every word of this. Keeping the two
/// apart is what stops a shade name or a brand ending up burned into a picture.
export type StepProductPresentation =
  | StandardPresentation
  | MyMakeupKitPresentation;

/// Standard Mode: brand-neutral colour guidance.
///
/// Carries a shade description such as "warm peach" and a hex value, never a
/// brand, product line, retailer, or anything purchasable. One tutorial
/// category can draw on more than one plan entry — Lips is fed by both the
/// `lipstick` and `lipGloss` keys — so entries is a list.
export interface StandardPresentation {
  mode: "standard";
  category: TutorialCategory;
  entries: StandardPresentationEntry[];
}

export interface StandardPresentationEntry {
  /// A colour description, never a product to buy.
  shadeName: string;
  colorHex: string | null;
  finish: string | null;
  intensity: string | null;
  placement: string;
  technique: string;
}

/// My Makeup Kit: the user's own products, exactly as captured.
///
/// Every field comes from the immutable snapshot taken when the look was
/// validated. Nothing is re-read from live inventory, so a product edited or
/// deleted since then still displays as it was used.
export interface MyMakeupKitPresentation {
  mode: "my_makeup_kit";
  category: TutorialCategory;
  items: MyMakeupKitPresentationItem[];
}

export interface MyMakeupKitPresentationItem {
  productId: string;
  /// The inventory category, preserved so a Lips step can distinguish the
  /// lipstick from the gloss.
  inventoryCategory: string;
  /// The user's own name for the product, or null. Never substituted with a
  /// generic label — an unnamed product stays unnamed, and the app decides how
  /// to present that absence.
  productName: string | null;
  colorHex: string;
  colorLabel: string | null;
  finish: string;
  foundationDepth: string | null;
  foundationUndertone: string | null;
}

/// Builds the Standard Mode presentation for one category.
///
/// Copies only the brand-neutral fields of the validated recommendation. The
/// upstream schema has no brand, retailer, or purchase field to copy, and this
/// adapter adds none.
export function standardPresentation(
  category: TutorialCategory,
  plan: StandardCategoryPlan[],
): StandardPresentation {
  return {
    mode: "standard",
    category,
    entries: plan.map((entry) => ({
      shadeName: entry.shadeName,
      colorHex: entry.colorHex,
      // Empty strings from the upstream row become null rather than being
      // displayed as a blank field.
      finish: entry.finish.length > 0 ? entry.finish : null,
      intensity: entry.intensity.length > 0 ? entry.intensity : null,
      placement: entry.placement,
      technique: entry.technique,
    })),
  };
}

/// Builds the My Makeup Kit presentation for one category.
///
/// Preserves every resolved snapshot item in order, so a Lips step showing a
/// lipstick and a lip gloss presents both. Missing optional fields stay null.
export function myMakeupKitPresentation(
  category: TutorialCategory,
  products: ResolvedProduct[],
): MyMakeupKitPresentation {
  return {
    mode: "my_makeup_kit",
    category,
    items: products.map((product) => ({
      productId: product.productId,
      inventoryCategory: product.inventoryCategory,
      productName: product.productName,
      colorHex: product.colorHex,
      colorLabel: product.colorLabel,
      finish: product.finish,
      foundationDepth: product.foundationDepth,
      foundationUndertone: product.foundationUndertone,
    })),
  };
}

/// Selects the adapter matching the source mode.
export function stepProductPresentation(options: {
  sourceMode: "standard" | "my_makeup_kit";
  category: TutorialCategory;
  standardPlan: StandardCategoryPlan[];
  products: ResolvedProduct[];
}): StepProductPresentation {
  return options.sourceMode === "my_makeup_kit"
    ? myMakeupKitPresentation(options.category, options.products)
    : standardPresentation(options.category, options.standardPlan);
}
