import type { RendererSpec } from "./single_image_prompt.ts";

/**
 * The four Step Specs the single-image gate renders.
 *
 * These are the V3-6A.1 specs narrowed to the renderer-relevant fields, with
 * one evidence-driven correction: BLUSH is now spatially explicit, because the
 * previous wording produced medial/low placement three times out of three and
 * once merged both cheeks across the nose.
 *
 * The corrected wording is a smoke-test refinement, not a production rule. A
 * real plan would still personalize placement per face shape; what changed is
 * that the spec now states the *geometry* the planner intended, which the old
 * wording left to the renderer to guess.
 */
export const SINGLE_IMAGE_SPECS: RendererSpec[] = [
  {
    category: "foundation",
    whereToApply:
      "A broad region covering the forehead, both cheeks, the nose and the chin. Leave the eye sockets and the lips completely uncovered.",
    direction:
      "Outward from the centre of the face toward the hairline, the ears and the jaw",
    technique: "Press and roll in thin layers, building coverage gradually",
    coverage: "Medium, buildable",
    intensity: "Even",
    visualDescription:
      "One broad translucent coverage region over the central face, with arrows radiating outward from the centre toward the hairline and jaw. The eye sockets and the lips are visible gaps in the region, not covered by it.",
    graphics: ["translucent_zone", "arrow"],
    faceAttributes: { skin_tone: "medium", undertone: "warm" },
  },
  {
    // --- Corrected geometry, per V3-6A.1 evidence ---------------------------
    category: "blush",
    whereToApply: [
      "TWO SEPARATE zones, one on each cheek.",
      "Place each zone on the UPPER OUTER cheek, over the lateral cheekbone.",
      "Each zone begins below the outer half of the eye and extends outward toward the temple.",
      "Do NOT place a zone on the apple or centre of the cheek, beside the nose, on the side of the nose, or across the bridge of the nose.",
      "The left and right zones must NEVER touch or connect.",
      "There must be clearly visible untouched skin between the two zones, across the whole centre of the face.",
    ].join(" "),
    direction: "Diagonally upward and outward toward each temple",
    technique:
      "Soft circular blending while maintaining the upward and outward direction",
    coverage: null,
    intensity: "Soft to medium",
    visualDescription:
      "Two clearly separate translucent zones, one over each upper outer cheekbone, each with arrows travelling diagonally up and out toward the temple on that side. The centre of the face, including the nose and the area beside it, carries no marks at all.",
    graphics: ["translucent_zone", "arrow", "soft_band"],
    faceAttributes: { face_shape: "oval" },
  },
  {
    category: "eyeliner",
    whereToApply:
      "Along the upper lash line of each eye, thinnest at the inner corner and thickening toward the outer third",
    direction:
      "From the inner corner outward, angling up toward the tail of the brow at the outer corner",
    technique: "Short connected strokes pressed into the lash line",
    coverage: null,
    intensity: "Defined but soft",
    visualDescription:
      "One fine path tracing the upper lash line of each eye, widening slightly toward the outer third, with a small marker at each outer corner showing the upward and outward angle.",
    graphics: ["path", "marker"],
    faceAttributes: { eye_shape: "almond" },
  },
  {
    category: "lipstick",
    whereToApply:
      "The full lip surface, staying exactly on the natural lip border without crossing it",
    direction:
      "From the centre of the lips outward toward each corner, upper lip first, then lower",
    technique: "Outline the natural border first, then fill inward",
    coverage: "Full",
    intensity: "Medium",
    visualDescription:
      "A translucent boundary over both lips with the natural lip colour still clearly visible underneath, an outline path following the exact natural lip border, and small markers at the centre showing the outward fill direction.",
    graphics: ["translucent_zone", "path", "marker"],
    faceAttributes: { lip_shape: "medium" },
  },
];
