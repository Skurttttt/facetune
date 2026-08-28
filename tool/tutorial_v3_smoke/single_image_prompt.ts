/**
 * V3-6A.2 — single-image guideline renderer prompt.
 *
 * V3-6A.1 proved that handing the canonical final preview to the image model
 * creates style-transfer pressure it cannot resist: finished makeup leaked into
 * categories the step was not teaching, in all three prompt variants. So the
 * canonical preview is removed from the RENDERER call. It still reaches the
 * tutorial through the planner (which produces the Step Spec) and through the
 * UI (which shows it as the target). Only this one request loses it.
 *
 * The framing here is deliberately different from V3-6A.1: the model is
 * addressed as a RENDERER, not a makeup artist. It is told the design decision
 * has already been made elsewhere and its only job is to draw it.
 */

export const SINGLE_IMAGE_PROMPT_VERSION = "v3-guideline-single-image-1";

export type GuidelineGraphic =
  | "translucent_zone"
  | "arrow"
  | "path"
  | "soft_band"
  | "marker";

export type RendererCategory =
  | "foundation"
  | "blush"
  | "eyeliner"
  | "lipstick";

/**
 * The MINIMUM SUFFICIENT Step Spec the renderer needs.
 *
 * Deliberately excluded, and why (see report §14):
 * - `selectedStyleCode` — naming a look ("soft glam") invites the model to
 *   render that look rather than draw an instruction.
 * - `targetLookCues` — these describe the FINISHED appearance ("a soft flush
 *   sitting high on the cheek"), which is style-transfer pressure in text form.
 * - `faceRationale` / `targetRationale` — explanation written for the user and
 *   rendered by Flutter; the renderer does not need to know *why*.
 *
 * Those fields remain on the persisted Step Spec and remain used by the
 * planner and the UI. They are simply not sent to the image model.
 */
export interface RendererSpec {
  category: RendererCategory;
  whereToApply: string;
  direction: string;
  technique: string;
  coverage?: string | null;
  intensity?: string | null;
  visualDescription: string;
  graphics: GuidelineGraphic[];
  /** Only the attributes relevant to this category. */
  faceAttributes: Record<string, string>;
}

interface CategoryRules {
  label: string;
  allowed: string[];
  forbidden: string[];
}

export const RENDERER_CATEGORY_RULES: Record<RendererCategory, CategoryRules> = {
  foundation: {
    label: "Foundation",
    allowed: [
      "one broad translucent coverage region over the areas named",
      "arrows travelling outward from the centre of the face",
      "clearly visible gaps where the eyes and lips are excluded",
    ],
    forbidden: [
      "smoothed, blurred, evened or retouched skin",
      "any change to skin tone or complexion",
      "a visible foundation finish",
      "a concealer or brightening effect",
      "any eye makeup or lip makeup",
    ],
  },
  blush: {
    label: "Blush",
    allowed: [
      "exactly TWO separate translucent zones, one per cheek",
      "each zone over the upper outer cheek and lateral cheekbone",
      "arrows travelling diagonally up and out toward each temple",
    ],
    forbidden: [
      "any pink, rose or red colour on the cheeks",
      "a single zone spanning the centre of the face",
      "any zone touching, crossing or connecting across the nose",
      "a zone on the apple of the cheek or beside the nose",
    ],
  },
  eyeliner: {
    label: "Eyeliner",
    allowed: [
      "one fine instructional path following the upper lash line",
      "a small marker showing the outward and upward direction at the outer corner",
    ],
    forbidden: [
      "a finished black, brown or coloured liner",
      "eyeshadow of any kind",
      "mascara or darkened lashes",
      "any change to eye shape, size, colour or spacing",
    ],
  },
  lipstick: {
    label: "Lip Colour",
    allowed: [
      "a translucent coverage boundary over the lips with the natural lips still visible through it",
      "an outline path following the natural lip border",
      "small markers showing the application direction",
    ],
    forbidden: [
      "any lipstick pigment or colour change on the lips",
      "filling the lips with a solid colour",
      "desaturating, greying or otherwise altering the natural lip colour",
      "reshaped, plumped, over-lined or re-textured lips",
    ],
  },
};

function attributeLines(attributes: Record<string, string>): string {
  const entries = Object.entries(attributes);
  if (entries.length === 0) return "(none relevant to this category)";
  return entries
    .map(([key, value]) => `- ${key.replace(/_/g, " ")}: ${value}`)
    .join("\n");
}

function optional(label: string, value?: string | null): string[] {
  if (value === undefined || value === null || value.trim().length === 0) {
    return [];
  }
  return [`${label}: ${value}`];
}

/**
 * Builds the renderer prompt for one step.
 *
 * There is exactly one image. The prompt contains no reference to a second
 * image, a target image, or a canonical preview — a contract test enforces
 * that, so a future edit cannot quietly reintroduce the rejected architecture.
 */
export function singleImageGuidelinePrompt(spec: RendererSpec): string {
  const rules = RENDERER_CATEGORY_RULES[spec.category];

  return [
    "You are an INSTRUCTIONAL DIAGRAM RENDERER.",
    "",
    "You are not designing makeup.",
    "You are not choosing placement.",
    "You are not interpreting a makeup style.",
    "You are not deciding what would suit this person.",
    "",
    "The makeup application decision has ALREADY been made by another system.",
    "It is written in the INSTRUCTION below. Your only job is to draw that",
    "instruction as a diagram on top of the photograph.",
    "",
    "=== THE PHOTOGRAPH ===",
    "The attached photograph is the base. It must survive completely unchanged.",
    "Preserve exactly: the person's identity and recognisable features, facial",
    "proportions and bone structure, skin tone, skin texture and every blemish,",
    "line and mark, expression and gaze, hair including stray strands, lighting,",
    "shadows, colour balance, camera perspective and the background.",
    "",
    "Do NOT apply makeup. Do NOT beautify. Do NOT retouch or smooth skin.",
    "Do NOT reshape the face, eyes, nose, lips, jaw or brows.",
    "Do NOT change the expression, the lighting or the framing.",
    "",
    "Think of it as drawing on a printed photo with a marker: the photo",
    "underneath is untouched, and everything you add sits visibly on top of it.",
    "",
    "=== THE INSTRUCTION TO DRAW ===",
    `CATEGORY: ${rules.label}`,
    "",
    `WHERE: ${spec.whereToApply}`,
    `DIRECTION: ${spec.direction}`,
    `TECHNIQUE: ${spec.technique}`,
    ...optional("COVERAGE", spec.coverage),
    ...optional("INTENSITY", spec.intensity),
    "",
    "RELEVANT FACE CONTEXT (context for the placement above; it never overrides",
    "the instruction):",
    attributeLines(spec.faceAttributes),
    "",
    "WHAT THE DIAGRAM SHOULD SHOW:",
    spec.visualDescription,
    "",
    "=== HOW TO DRAW IT ===",
    "Use only these mark types:",
    ...spec.graphics.map((graphic) => `- ${graphic.replace(/_/g, " ")}`),
    "",
    `For ${rules.label}, the diagram should show:`,
    ...rules.allowed.map((line) => `- ${line}`),
    "",
    `For ${rules.label}, the output must NOT contain:`,
    ...rules.forbidden.map((line) => `- ${line}`),
    "",
    "=== ABSOLUTE CONSTRAINTS ===",
    "- The marks are NON-PHOTOGRAPHIC. They must read as a diagram layer drawn",
    "  over a photo, never as cosmetic product sitting on skin.",
    "  If a viewer could mistake your marks for actual makeup, they are wrong.",
    `- Draw ONLY ${rules.label}. No other makeup category may appear, be hinted`,
    "  at, or be added anywhere on the face.",
    "- Add NO finished makeup of any kind, anywhere, for any category.",
    "- Add NO text, letters, numbers, labels, captions or watermarks.",
    "  All wording is rendered separately by the app; words in the image are a defect.",
    "- Add NO decorative graphics, borders, frames or beauty-app styling.",
    "- Every part of the face that the diagram does not cover must be pixel-for-pixel",
    "  the same as the photograph you were given.",
    "",
    "Return one image: the photograph with the diagram drawn on top.",
  ].join("\n");
}
