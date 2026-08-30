import type { TutorialCategory } from "../_shared/tutorial_vocabulary.ts";

/// Per-category guideline guidance.
///
/// [landmarks] names the facial structures to mark and what "correct" looks
/// like for that category. [prohibition] names the specific way this category
/// tends to get rendered wrong — every one of them is a way of accidentally
/// applying makeup instead of annotating it, and each is phrased in that
/// category's own vocabulary because a generic "do not apply pigment" has
/// already proven too abstract to bind a model reliably.
///
/// The set is exhaustive over the vocabulary: a missing entry would be a
/// compile-time gap rather than a silent fallback to generic wording.
export interface CategoryGuidance {
  landmarks: string;
  prohibition: string;
}

export const CATEGORY_GUIDANCE: Record<TutorialCategory, CategoryGuidance> = {
  foundation: {
    landmarks:
      "Foundation covers the complexion. Outline the perimeter of the area " +
      "that was evened out in the FINAL image, and mark the direction it was " +
      "blended outward — typically from the centre of the face toward the " +
      "hairline, jaw, and neck. Mark the boundaries where coverage must fade " +
      "out rather than stop abruptly: the jawline, the hairline, and the ears. " +
      "If an area was deliberately left uncovered, outline that too.",
    prohibition:
      "Do not tint, even out, smooth, or re-tone any skin. The skin beneath " +
      "your markings must keep every freckle, mole, pore, and unevenness " +
      "visible in IMAGE A.",
  },
  concealer: {
    landmarks:
      "Concealer covers specific areas rather than the whole face. Outline " +
      "only the discrete zones that were brightened or evened in the FINAL " +
      "image — commonly the under-eye triangle, the inner corner, around the " +
      "nose, or an individual blemish. Mark the blending direction outward " +
      "from each zone, and show where each zone must fade into the surrounding " +
      "skin.",
    prohibition:
      "Do not brighten, lighten, or smooth the under-eye area or any blemish. " +
      "Every mark you draw must be an outline or an arrow, never a lightened " +
      "patch.",
  },
  contour_bronzer: {
    landmarks:
      "Contour and bronzer add depth. Mark only the regions actually deepened " +
      "in the FINAL image — which may include the hollow beneath the " +
      "cheekbone, the temple, the jawline, or the sides of the nose, but only " +
      "those you can genuinely see. Show the upper and lower boundary of each " +
      "band and the direction it was blended so it has no hard edge.",
    prohibition:
      "Do not add any brown, bronze, tan, or shadow tone to the face. Do not " +
      "darken, slim, or sculpt the face. Mark a region that is unclear in the " +
      "FINAL image only if you can see it; otherwise leave it unmarked.",
  },
  blush: {
    landmarks:
      "Blush occupies the cheek area. Outline the region where colour was " +
      "added in the FINAL image — typically over the cheekbone and the apple " +
      "of the cheek — and indicate the direction it was blended, usually " +
      "upward and outward toward the temple. Follow the exact extent, height, " +
      "and angle visible in the FINAL image rather than any standard " +
      "placement.",
    prohibition:
      "Do not add any pink, peach, coral, or red flush to the cheeks. The " +
      "cheeks beneath your markings must stay exactly the colour they are in " +
      "IMAGE A.",
  },
  highlighter: {
    landmarks:
      "Highlighter catches light on high points. Outline only the small areas " +
      "that visibly gained brightness in the FINAL image — which may include " +
      "the tops of the cheekbones, the brow bone, the inner corner of the eye, " +
      "the bridge of the nose, or the Cupid's bow. Keep each outline tight, " +
      "since highlighter sits in narrow traces rather than broad regions.",
    prohibition:
      "Do not add shimmer, glow, sheen, sparkle, or any brightening to the " +
      "skin. Draw the boundary of where the light sits; never draw the light " +
      "itself.",
  },
  eyebrows: {
    landmarks:
      "Eyebrows were shaped or defined. Mark the start of the brow at the " +
      "inner end, the position of the arch at its highest point, and the tail " +
      "where the brow ends. Show the direction the hairs were groomed or " +
      "drawn, and outline any area where the brow shape was extended or " +
      "filled compared with IMAGE A.",
    prohibition:
      "Do not fill, darken, thicken, or redraw the eyebrows themselves. The " +
      "brows beneath your markings must remain exactly as they are in IMAGE A.",
  },
  eyeshadow: {
    landmarks:
      "Eyeshadow sits across the eye area. Outline the zones actually used in " +
      "the FINAL image — which may include the mobile lid, the crease, the " +
      "outer V, the inner corner, and the area beneath the lower lash line. " +
      "Show where one zone blends into the next and the direction of that " +
      "blending. Mark only the zones you can see were used.",
    prohibition:
      "Do not add any eyeshadow colour, depth, or shading to the lids. Draw " +
      "zone boundaries and blending arrows only.",
  },
  eyeliner: {
    landmarks:
      "Eyeliner follows the lash line. Mark where the line starts at the " +
      "inner end, the path it takes along the lash line, where it changes " +
      "thickness, and where it ends. If there is a wing, mark its direction, " +
      "its endpoint, its length, and the curvature of its upper edge. If the " +
      "lower lash line was lined, mark that separately.",
    prohibition:
      "Do not draw black or coloured liner on the lash line. Your marking must " +
      "sit beside or above the lash line as an annotation, clearly " +
      "distinguishable from liner itself, and must never look like makeup.",
  },
  lips: {
    landmarks:
      "Lips were coloured or reshaped. Mark the natural lip border visible in " +
      "IMAGE A and, where they differ, the target border in the FINAL image. " +
      "Mark the Cupid's bow, both corners, and the lower lip boundary. If the " +
      "border was overlined or brought inward, show the direction and extent " +
      "of that change.",
    prohibition:
      "Do not fill, tint, gloss, or colour the lips. The lips beneath your " +
      "markings must stay exactly the colour they are in IMAGE A.",
  },
};

export function categoryGuidance(
  category: TutorialCategory,
): CategoryGuidance | null {
  return CATEGORY_GUIDANCE[category] ?? null;
}
