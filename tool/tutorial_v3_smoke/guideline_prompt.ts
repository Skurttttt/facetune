/**
 * The V3 guideline prompt under evaluation by the V3-6A behavioural gate.
 *
 * This lives in `tool/` — NOT under `supabase/functions/` — so it can never be
 * picked up by `supabase functions deploy`. It is gate material. If the gate
 * passes, V3-6B promotes it into the production Edge Function; if the gate
 * fails, nothing was wired into production in the meantime.
 *
 * The single hardest requirement here is the two-image role hierarchy. Two
 * inline images are sent in a fixed order and the prompt must make their roles
 * unmistakable, because the default behaviour of an image-editing model given
 * two faces is to blend them — which is precisely the failure V3 cannot
 * tolerate (Source of Truth §6, §14).
 */

export const GUIDELINE_PROMPT_VERSION = "v3-guideline-gate-1";

/** The instructional marks a guideline may draw. Mirrors the V3 domain. */
export type GuidelineGraphic =
  | "translucent_zone"
  | "arrow"
  | "path"
  | "soft_band"
  | "marker";

export type GuidelineCategory =
  | "foundation"
  | "concealer"
  | "contour_bronzer"
  | "blush"
  | "highlighter"
  | "eyebrow"
  | "eyeshadow"
  | "eyeliner"
  | "lipstick"
  | "lip_gloss";

/** Mirrors `TutorialV3GuidelineIntent` on the Dart side. */
export interface GuidelineSpec {
  category: GuidelineCategory;
  selectedStyleCode: string;
  whereToApply: string;
  direction: string;
  technique: string;
  coverage?: string | null;
  intensity?: string | null;
  visualDescription: string;
  graphics: GuidelineGraphic[];
  /** Only the attributes this category is allowed to reason about. */
  faceAttributes: Record<string, string>;
  targetLookCues: string[];
  faceRationale: string;
  targetRationale: string;
}

interface CategoryRules {
  label: string;
  allowed: string[];
  forbidden: string[];
}

/**
 * Per-category constraints.
 *
 * `forbidden` is the important half: each category names the *finished*
 * appearance it must not produce, in the model's own visual vocabulary, plus
 * the neighbouring categories it must not stray into.
 */
export const CATEGORY_RULES: Record<GuidelineCategory, CategoryRules> = {
  foundation: {
    label: "Foundation",
    allowed: [
      "a translucent coverage region over the areas to be covered",
      "arrows showing outward blending from the centre of the face",
      "clear exclusions around the eyes and lips where the Step Spec says so",
    ],
    forbidden: [
      "any change to skin tone, evenness or texture",
      "smoothed, blurred or retouched skin",
      "a visible foundation finish of any kind",
      "complexion correction or blemish removal",
    ],
  },
  concealer: {
    label: "Concealer",
    allowed: [
      "translucent placement zones under the eyes or on the areas named",
      "small tap or press markers",
      "short blending arrows",
    ],
    forbidden: [
      "brightened or lightened under-eye areas",
      "removal of shadows, lines or discolouration",
      "a visible concealer finish",
    ],
  },
  contour_bronzer: {
    label: "Contour / Bronzer",
    allowed: [
      "soft bands along the areas named in the Step Spec",
      "directional blending arrows",
    ],
    forbidden: [
      "visible bronzed or sculpted shadow",
      "any change to facial structure, cheekbone shape or jaw shape",
      "a finished contour",
    ],
  },
  blush: {
    label: "Blush",
    allowed: [
      "a translucent zone over the cheek area named in the Step Spec",
      "arrows showing the blending direction",
    ],
    forbidden: [
      "any visible pink, rose or red colour on the cheeks",
      "a finished blush result",
      "general skin beautification",
    ],
  },
  highlighter: {
    label: "Highlighter",
    allowed: [
      "small translucent zones on the high points named",
      "soft directional markers",
    ],
    forbidden: [
      "added glow, shimmer, shine or luminosity",
      "a finished highlighter result",
    ],
  },
  eyebrow: {
    label: "Brows",
    allowed: [
      "an outline path following the brow shape named",
      "short directional strokes indicating hair direction",
    ],
    forbidden: [
      "denser, darker, reshaped or filled-in brows",
      "any change to the natural brow shape",
    ],
  },
  eyeshadow: {
    label: "Eyeshadow",
    allowed: [
      "translucent zones on the lid, crease or outer corner as named",
      "arrows showing the blending direction",
    ],
    forbidden: [
      "any visible eyeshadow colour on the lids",
      "a finished eye look",
      "eyeliner or mascara of any kind",
      "any change to eye shape or size",
    ],
  },
  eyeliner: {
    label: "Eyeliner",
    allowed: [
      "a precise thin path along the lash line described",
      "a directional marker showing where the wing or tail travels",
    ],
    forbidden: [
      "a finished black, brown or coloured liner",
      "darkened lashes or mascara",
      "eyeshadow",
      "any change to eye shape, size or spacing",
    ],
  },
  lipstick: {
    label: "Lip Colour",
    allowed: [
      "a translucent coverage zone over the lips",
      "an outline path around the lip border",
      "directional markers showing application order",
    ],
    forbidden: [
      "any visible lipstick colour on the lips",
      "reshaped, plumped, enlarged or over-lined lips",
      "changed lip texture, gloss or shine",
    ],
  },
  lip_gloss: {
    label: "Lip Gloss",
    allowed: [
      "a translucent zone over the centre of the lips or the area named",
      "small directional markers",
    ],
    forbidden: [
      "added gloss, shine or wetness",
      "any visible colour change on the lips",
      "reshaped or plumped lips",
    ],
  },
};

/**
 * Short role notes placed IMMEDIATELY BEFORE their image part.
 *
 * Variant 1 states the roles only in the preamble. Variants 2 and 3 also wrap
 * each image with its own note, so the role is adjacent to the pixels rather
 * than several hundred tokens away.
 */
export const IMAGE_ONE_ADJACENT_NOTE =
  "The NEXT image is IMAGE 1 — the BASE. This exact person, this exact photo, " +
  "is what your output must show. Preserve it unchanged and draw the " +
  "instructional overlays on top of it.";

export const IMAGE_TWO_ADJACENT_NOTE =
  "The NEXT image is IMAGE 2 — REFERENCE ONLY. It is NOT the output. Do not " +
  "copy it, do not blend it, do not take its makeup, colour or skin finish. " +
  "Look at it only to understand where the current category ends up in the " +
  "finished look, then return to IMAGE 1.";

/** Variant 2: overlays are a diagram layer, not cosmetic pigment. */
export const NON_PHOTOGRAPHIC_NOTE = [
  "RENDER THE OVERLAYS AS A DIAGRAM LAYER.",
  "The overlays are non-photographic instructional graphics placed ABOVE an",
  "untouched photograph — like a coach drawing on a still frame.",
  "Do NOT render them as cosmetic pigment sitting on skin.",
  "Do NOT make them look like product that has been applied.",
  "They should read as a semi-transparent annotation layer that could be",
  "switched off to reveal the original photo completely unchanged underneath.",
].join("\n");

/** Variant 3: explicit colour-transfer ban and tighter category lock. */
export const COLOUR_TRANSFER_NOTE = [
  "NO COLOUR TRANSFER.",
  "Do not sample, reuse or approximate any makeup colour from IMAGE 2 on the",
  "skin, cheeks, eyes or lips of IMAGE 1.",
  "The only colour you may add is the colour of the instructional overlay",
  "shapes themselves, and those must be obviously graphical rather than",
  "cosmetic.",
  "Every facial surface in IMAGE 1 must keep exactly the colour it already has.",
  "If any part of the face ends up a different colour than it is in IMAGE 1,",
  "the output is wrong.",
].join("\n");

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
 * Builds the guideline prompt for one step.
 *
 * The image-role contract is stated three times on purpose — once up front as
 * the framing, once inline where the target is described, and once in the
 * closing constraints. Stating it only once is what lets a model quietly drift
 * into face-blending on a long prompt.
 */
export function tutorialV3GuidelinePrompt(spec: GuidelineSpec): string {
  const rules = CATEGORY_RULES[spec.category];

  return [
    "You are producing an INSTRUCTIONAL MAKEUP APPLICATION GUIDE image.",
    "",
    "You are given TWO images. Their roles are different and must not be confused.",
    "",
    "=== IMAGE 1 — THE BASE IMAGE (the output subject) ===",
    "IMAGE 1 is the person this guide is for.",
    "Your output MUST be IMAGE 1, unchanged, with instructional overlays drawn on top.",
    "Preserve exactly, from IMAGE 1:",
    "- the person's identity and recognisable features",
    "- facial proportions and bone structure",
    "- skin tone, skin texture and every blemish, line and mark",
    "- expression, gaze and head position",
    "- hair, hairline and stray hairs",
    "- lighting, shadows, colour balance and camera perspective",
    "- the background",
    "",
    "Do NOT beautify. Do NOT retouch. Do NOT smooth or even out skin.",
    "Do NOT reshape the face, eyes, nose, lips, jaw or brows.",
    "Do NOT change the expression. Do NOT apply any finished makeup.",
    "If you change the person in IMAGE 1 in any way other than adding overlays, the output is wrong.",
    "",
    "=== IMAGE 2 — REFERENCE ONLY (never part of the output) ===",
    "IMAGE 2 shows the completed makeup look this person is working toward.",
    "IMAGE 2 is REFERENCE ONLY. It is evidence of the destination, nothing more.",
    "Do NOT copy IMAGE 2. Do NOT blend IMAGE 2 into IMAGE 1.",
    "Do NOT transfer the makeup, colour, skin finish or styling from IMAGE 2 onto IMAGE 1.",
    "Do NOT output IMAGE 2, any part of IMAGE 2, or a mixture of the two faces.",
    "Use IMAGE 2 ONLY to understand where and how strongly the CURRENT category",
    "sits in the finished look, so your overlays point at the right destination.",
    "",
    "=== THE AUTHORITATIVE INSTRUCTION ===",
    "The Step Spec below is the instruction. Visualise it exactly.",
    "Do not invent a different placement, direction, intensity or technique,",
    "and do not choose what you think would suit this person better.",
    "This person has already chosen their look; you are teaching it, not designing it.",
    "",
    `SELECTED LOOK: ${spec.selectedStyleCode}`,
    `CURRENT CATEGORY: ${rules.label}`,
    "",
    `WHERE: ${spec.whereToApply}`,
    `DIRECTION: ${spec.direction}`,
    `TECHNIQUE: ${spec.technique}`,
    ...optional("COVERAGE", spec.coverage),
    ...optional("INTENSITY", spec.intensity),
    "",
    "RELEVANT FACE CONTEXT (explains the placement; never overrides the Step Spec):",
    attributeLines(spec.faceAttributes),
    "",
    `WHY THIS PLACEMENT: ${spec.faceRationale}`,
    `HOW IT BUILDS THE LOOK: ${spec.targetRationale}`,
    "",
    "WHAT TO LOOK FOR IN IMAGE 2 FOR THIS CATEGORY:",
    ...spec.targetLookCues.map((cue) => `- ${cue}`),
    "",
    "GUIDELINE VISUAL INTENT:",
    spec.visualDescription,
    "",
    "=== WHAT TO DRAW ===",
    `Draw ONLY overlays for ${rules.label}. Use only these mark types:`,
    ...spec.graphics.map((graphic) => `- ${graphic.replace(/_/g, " ")}`),
    "",
    `For ${rules.label}, appropriate overlays are:`,
    ...rules.allowed.map((line) => `- ${line}`),
    "",
    `For ${rules.label}, the output must NOT contain:`,
    ...rules.forbidden.map((line) => `- ${line}`),
    "",
    "=== ABSOLUTE CONSTRAINTS ===",
    "- Teach ONLY the current category. No other makeup category may be shown or hinted at.",
    "- Add NO finished makeup of any kind, for any category.",
    "- Add NO text, letters, numbers, labels, captions, watermarks or typography.",
    "  All wording is rendered separately by the app; words in the image are a defect.",
    "- Add NO decorative graphics, borders, frames, callouts or beauty-app styling.",
    "- The overlays must be clearly distinguishable from real makeup:",
    "  they are instructional marks on an untouched photo, not a preview of a result.",
    "- The face beneath the overlays must remain exactly the face from IMAGE 1.",
    "",
    "Return a single image: IMAGE 1 with the instructional overlays described above.",
  ].join("\n");
}
