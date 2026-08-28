import type { GuidelineSpec } from "./guideline_prompt.ts";

/**
 * The four Step Specs the gate exercises.
 *
 * They are deliberately different visual problems: broad face coverage,
 * localised placement with directional blending, a precision path around the
 * eye, and a bounded lip region. Passing only one of these would prove very
 * little, which is why §7 of the phase requires all four.
 *
 * Face attributes are scoped per category exactly as
 * `TutorialV3CategoryCatalog.relevantAttributes` requires — the values below
 * match the visible attributes of the committed test portrait.
 */
export const GATE_STEP_SPECS: GuidelineSpec[] = [
  {
    category: "foundation",
    selectedStyleCode: "soft_glam",
    whereToApply:
      "The centre of the face — forehead, nose bridge, chin and the inner cheeks — carried outward",
    direction: "Outward from the centre of the face toward the hairline and jaw",
    technique: "Press and roll with a damp sponge, building thin layers",
    coverage: "Medium, buildable",
    intensity: "Even",
    visualDescription:
      "A translucent coverage region over the central face, with arrows radiating outward toward the hairline and jaw, leaving the immediate eye area and the lips clear.",
    graphics: ["translucent_zone", "arrow"],
    faceAttributes: { skin_tone: "medium", undertone: "warm" },
    targetLookCues: [
      "An even, natural-looking base with the skin still visible through it",
      "No heavy or mask-like edges along the jaw",
    ],
    faceRationale:
      "A medium, warm-undertoned complexion needs the base carried outward thinly so the jawline does not read as a line.",
    targetRationale:
      "The finished look rests on an even base; everything after this step sits on top of it.",
  },
  {
    category: "blush",
    selectedStyleCode: "soft_glam",
    whereToApply: "The upper outer cheeks, starting outside the pupil line",
    direction: "Upward and outward toward the temples",
    technique: "Soft circular blending with a fluffy brush",
    coverage: null,
    intensity: "Soft, diffused",
    visualDescription:
      "A translucent band across the upper outer cheek, angled up toward the temple, with arrows following that upward-outward direction.",
    graphics: ["translucent_zone", "arrow", "soft_band"],
    faceAttributes: { face_shape: "oval" },
    targetLookCues: [
      "A soft flush sitting high on the cheek, not low toward the nose",
      "No hard edge where the colour starts or stops",
    ],
    faceRationale:
      "Placing the colour high and angling it toward the temple keeps an oval face balanced and lifted.",
    targetRationale:
      "The finished look shows a diffused flush high on the cheek that this placement produces.",
  },
  {
    category: "eyeliner",
    selectedStyleCode: "soft_glam",
    whereToApply:
      "Along the upper lash line, thinnest at the inner corner and thickening toward the outer third",
    direction:
      "Inner corner outward, then angled up toward the tail of the brow at the outer corner",
    technique: "Short connected strokes pressed into the lash line",
    coverage: null,
    intensity: "Defined but soft",
    visualDescription:
      "A thin path tracing the upper lash line, widening toward the outer third, with a short directional marker at the outer corner showing the upward angle toward the brow tail.",
    graphics: ["path", "marker"],
    faceAttributes: { eye_shape: "almond" },
    targetLookCues: [
      "Definition that hugs the lash line rather than sitting above it",
      "A subtle lift at the outer corner",
    ],
    faceRationale:
      "An almond eye is flattered by keeping the line tight at the inner corner and lifting only at the outer third.",
    targetRationale:
      "The finished look shows soft outer-corner definition that this path creates.",
  },
  {
    category: "lipstick",
    selectedStyleCode: "soft_glam",
    whereToApply:
      "The full lip surface, staying on the natural lip border without crossing it",
    direction:
      "From the centre of the lips outward toward each corner, upper lip then lower",
    technique: "Outline the natural border first, then fill inward",
    coverage: "Full",
    intensity: "Medium",
    visualDescription:
      "A translucent coverage zone over both lips with an outline path following the exact natural lip border, and small markers at the centre showing the outward fill direction.",
    graphics: ["translucent_zone", "path", "marker"],
    faceAttributes: { lip_shape: "medium" },
    targetLookCues: [
      "Colour that follows the natural lip line without over-drawing it",
      "An even finish from centre to corners",
    ],
    faceRationale:
      "A medium lip keeps its natural proportion when the border is followed exactly rather than extended.",
    targetRationale:
      "The finished look shows a clean, evenly filled lip that this application produces.",
  },
];

/**
 * The prompt used to synthesise a stand-in canonical final preview.
 *
 * This mirrors what the production premium-preview pipeline already does
 * (one image in, one image out) so the gate's IMAGE 2 is a realistic target
 * rather than a hand-drawn mock. It is only used when the operator does not
 * supply a real canonical preview with `--target`.
 */
export function standInCanonicalPreviewPrompt(): string {
  return [
    "Apply a complete, polished soft glam makeup look to the person in this photo.",
    "",
    "Include: an even base, softly diffused blush high on the cheeks, neutral",
    "eyeshadow with soft outer-corner definition, defined eyeliner along the upper",
    "lash line, groomed brows, and a medium rose lip.",
    "",
    "Preserve the person's identity, facial proportions, expression, hair, lighting",
    "and camera perspective exactly. Do not reshape any feature.",
    "Return a single photorealistic image of the finished look.",
  ].join("\n");
}
