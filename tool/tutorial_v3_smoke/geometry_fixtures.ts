import type { GeometrySpec } from "./geometry_prompt.ts";

/**
 * One Step Spec per canonical category — all ten, using the project's real
 * category codes. Nothing is renamed.
 *
 * Face attributes are scoped per category exactly as
 * `TutorialV3CategoryCatalog.relevantAttributes` requires.
 */
export const CATEGORY_SPECS: GeometrySpec[] = [
  {
    id: "foundation",
    category: "foundation",
    whereToApply:
      "A broad region covering the forehead, both cheeks, the nose and the chin, excluding the eye sockets and the lips",
    direction: "Outward from the centre of the face toward the hairline and jaw",
    technique: "Press and roll in thin layers",
    coverage: "Medium, buildable",
    intensity: "Even",
    faceAttributes: { skin_tone: "medium", undertone: "warm" },
  },
  {
    id: "concealer",
    category: "concealer",
    whereToApply:
      "The inner under-eye triangle beneath each eye, from the inner corner sloping outward and downward",
    direction: "Tapped downward and outward toward the outer cheek",
    technique: "Tap with the fingertip, never drag",
    coverage: "Light",
    intensity: "Soft",
    faceAttributes: { eye_shape: "almond", skin_tone: "medium" },
  },
  {
    id: "contour_bronzer",
    category: "contour_bronzer",
    whereToApply:
      "A band along the hollow beneath each cheekbone, from the top of the ear toward the middle of the cheek, stopping well before the mouth",
    direction: "Backward and upward toward the temple",
    technique: "Sweep and buff with a dense brush",
    coverage: null,
    intensity: "Soft",
    faceAttributes: { face_shape: "oval" },
  },
  {
    id: "blush",
    category: "blush",
    whereToApply:
      "TWO separate zones, one on each upper outer cheek over the lateral cheekbone, beginning below the outer half of the eye and extending toward the temple. The two zones must never touch or cross the nose.",
    direction: "Diagonally upward and outward toward each temple",
    technique: "Soft circular blending",
    coverage: null,
    intensity: "Soft to medium",
    faceAttributes: { face_shape: "oval" },
  },
  {
    id: "highlighter",
    category: "highlighter",
    whereToApply:
      "The tops of both cheekbones, the bridge of the nose and the cupid's bow",
    direction: "Upward along each high point",
    technique: "Tap and tap out with a small brush",
    coverage: null,
    intensity: "Subtle",
    faceAttributes: { face_shape: "oval" },
  },
  {
    id: "eyeshadow",
    category: "eyeshadow",
    whereToApply:
      "The mobile lid of each eye, with a slightly deeper zone in the outer third and along the crease",
    direction: "Outward and upward from the inner lid toward the outer corner",
    technique: "Pat colour on the lid, windscreen-wiper motion in the crease",
    coverage: null,
    intensity: "Medium",
    faceAttributes: { eye_shape: "almond" },
  },
  {
    id: "eyeliner",
    category: "eyeliner",
    whereToApply:
      "Along the upper lash line of each eye, thinnest at the inner corner and thickening toward the outer third",
    direction:
      "Inner corner outward, angling up toward the tail of the brow at the outer corner",
    technique: "Short connected strokes pressed into the lash line",
    coverage: null,
    intensity: "Defined but soft",
    faceAttributes: { eye_shape: "almond" },
  },
  {
    id: "eyebrow",
    category: "eyebrow",
    whereToApply:
      "Along the natural shape of each brow, from the inner head through the arch to the outer tail",
    direction: "Following the natural hair growth, inner to outer",
    technique: "Short hair-like strokes",
    coverage: null,
    intensity: "Natural",
    faceAttributes: { face_shape: "oval" },
  },
  {
    id: "lipstick",
    category: "lipstick",
    whereToApply:
      "The full lip surface, staying exactly on the natural lip border without crossing it",
    direction: "From the centre of the lips outward toward each corner",
    technique: "Outline the natural border first, then fill inward",
    coverage: "Full",
    intensity: "Medium",
    faceAttributes: { lip_shape: "medium" },
  },
  {
    id: "lip_gloss",
    category: "lip_gloss",
    whereToApply: "The centre of the lower lip and the centre of the upper lip",
    direction: "From the centre outward, stopping before the corners",
    technique: "Dab at the centre and press the lips together",
    coverage: null,
    intensity: "Light",
    faceAttributes: { lip_shape: "medium" },
  },
];

/**
 * The personalization differential.
 *
 * Each pair uses the SAME category and the SAME face, and differs only in the
 * Step Spec's placement. If the mapper is applying a static per-category
 * preset, both members of a pair will return near-identical geometry. If it is
 * genuinely reading the instruction, they must differ in the direction the
 * instruction describes.
 */
export const DIFFERENTIAL_SPECS: GeometrySpec[] = [
  {
    id: "blush_high_lifted",
    category: "blush",
    whereToApply:
      "TWO separate zones placed HIGH on the face, on the upper outer cheekbone just below the outer corner of each eye, angled up toward the temples",
    direction: "Steeply upward and outward toward each temple",
    technique: "Soft circular blending",
    coverage: null,
    intensity: "Soft",
    faceAttributes: { face_shape: "round" },
  },
  {
    id: "blush_low_horizontal",
    category: "blush",
    whereToApply:
      "TWO separate zones placed LOW and horizontally, centred on the apple of each cheek at roughly the height of the nose tip, spreading sideways rather than upward",
    direction: "Horizontally outward toward each ear, not upward",
    technique: "Soft circular blending",
    coverage: null,
    intensity: "Soft",
    faceAttributes: { face_shape: "oblong" },
  },
  {
    id: "eyeliner_thin_tightline",
    category: "eyeliner",
    whereToApply:
      "A very thin line hugging the upper lash line only, ending exactly at the outer corner of each eye with no extension beyond it",
    direction: "Inner corner straight outward, ending at the outer corner",
    technique: "Press pigment between the lashes",
    coverage: null,
    intensity: "Barely there",
    faceAttributes: { eye_shape: "hooded" },
  },
  {
    id: "eyeliner_extended_wing",
    category: "eyeliner",
    whereToApply:
      "Along the upper lash line and then extending well PAST the outer corner of each eye as a long wing that travels up toward the tail of the brow",
    direction: "Outward and sharply upward past the outer corner",
    technique: "Draw the wing first, then connect it back to the lash line",
    coverage: null,
    intensity: "Bold",
    faceAttributes: { eye_shape: "almond" },
  },
  {
    id: "lipstick_full_natural",
    category: "lipstick",
    whereToApply:
      "The full lip surface, staying exactly on the natural lip border without crossing it",
    direction: "Centre outward toward each corner",
    technique: "Outline then fill",
    coverage: "Full",
    intensity: "Medium",
    faceAttributes: { lip_shape: "medium" },
  },
  {
    id: "lipstick_centre_gradient",
    category: "lipstick",
    whereToApply:
      "ONLY the inner centre portion of both lips, leaving the outer thirds nearest each corner completely bare for a gradient effect",
    direction: "From the very centre blending slightly outward, stopping well short of the corners",
    technique: "Dab colour at the centre and blend the edge softly",
    coverage: "Partial",
    intensity: "Soft",
    faceAttributes: { lip_shape: "full" },
  },
];
