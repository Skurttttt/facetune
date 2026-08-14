export const TUTORIAL_STEP_PROMPT_VERSION = "personalized_tutorial_step_v2";

export type PersonalizedTutorialStepSpec = {
  stepNumber: number;
  category: string;
  product?: string;
  kitProductId?: string;
  colorName?: string;
  colorHex?: string;
  finish?: string;
  placement?: string;
  side?: string;
  direction?: string;
  intensity?: string;
  technique?: string;
  tip?: string;
  faceAdjustment?: string;
  styleAdjustment?: string;
  geometryConfidence?: string;
  placementConfidence?: string;
};

export type TutorialFaceAttributes = {
  faceShape?: string;
  skinTone?: string;
  undertone?: string;
  eyeShape?: string;
  lipShape?: string;
  hairColor?: string;
  eyeColor?: string;
};

export type PersonalizedTutorialPromptInput = {
  selectedStyle?: string;
  faceAttributes: TutorialFaceAttributes;
  sourceMode?: string;
  stepSpec: PersonalizedTutorialStepSpec;
};

function clean(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

/** Converts the canonical JSON projection persisted with a tutorial step into
 * the typed prompt contract. Missing optional facts stay missing: the prompt
 * builder never manufactures product or face data. */
export function personalizedPromptInput(params: {
  selectedStyle?: unknown;
  sourceMode?: unknown;
  faceAttributes?: Record<string, unknown>;
  stepNumber: number;
  category: string;
  instruction?: Record<string, unknown>;
  personalizedSpec?: Record<string, unknown>;
}): PersonalizedTutorialPromptInput {
  const instruction = params.instruction ?? {};
  const persisted = params.personalizedSpec ?? {};
  const what = objectValue(persisted.what);
  const where = objectValue(persisted.where);
  const how = objectValue(persisted.how);
  const productSnapshot = objectValue(what.productSnapshot);
  const attributes = params.faceAttributes ?? {};
  return {
    selectedStyle: clean(params.selectedStyle),
    sourceMode: clean(params.sourceMode),
    faceAttributes: {
      faceShape: clean(attributes.face_shape ?? attributes.faceShape),
      skinTone: clean(attributes.skin_tone ?? attributes.skinTone),
      undertone: clean(attributes.undertone),
      eyeShape: clean(attributes.eye_shape ?? attributes.eyeShape),
      lipShape: clean(attributes.lip_shape ?? attributes.lipShape),
      hairColor: clean(attributes.hair_color ?? attributes.hairColor),
      eyeColor: clean(attributes.eye_color ?? attributes.eyeColor),
    },
    stepSpec: {
      stepNumber: params.stepNumber,
      category: clean(what.category ?? instruction.category) ?? params.category,
      product: clean(what.productName ?? instruction.product ?? instruction.productName),
      kitProductId: clean(productSnapshot.productId ?? instruction.kitProductId),
      colorName: clean(what.colorName ?? instruction.colorName),
      colorHex: clean(what.colorHex ?? instruction.colorHex ?? instruction.hex),
      finish: clean(what.finish ?? instruction.finish),
      placement: clean(where.description ?? instruction.placement),
      side: clean(where.side ?? instruction.side),
      direction: clean(how.direction ?? instruction.direction),
      intensity: clean(how.intensity ?? instruction.intensity),
      technique: clean(how.technique ?? instruction.technique),
      tip: clean(how.tip ?? instruction.tip),
      faceAdjustment: clean(persisted.faceAdjustment ?? instruction.faceAdjustment),
      styleAdjustment: clean(persisted.styleAdjustment ?? instruction.styleAdjustment),
      geometryConfidence: clean(where.geometryConfidence ?? instruction.geometryConfidence),
      placementConfidence: clean(where.placementConfidence ?? instruction.placementConfidence),
    },
  };
}

function objectValue(value: unknown): Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : {};
}

function facts(
  values: Array<[label: string, value: string | undefined]>,
): string {
  return values
    .filter((entry): entry is [string, string] => entry[1] !== undefined)
    .map(([label, value]) => `${label}: ${value}`)
    .join("\n");
}

/** Full, versioned template from FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_GUIDE.md
 * section 24. It consumes the same PersonalizedTutorialStepSpec projection as
 * written instructions and overlays; unavailable optional values are omitted. */
export function tutorialStepPrompt(params: {
  isFirstStep: boolean;
  totalSteps: number;
  input: PersonalizedTutorialPromptInput;
}): string {
  const { isFirstStep, totalSteps, input } = params;
  const spec = input.stepSpec;
  const context = facts([
    ["Selected style", input.selectedStyle],
    ["Face shape", input.faceAttributes.faceShape],
    ["Skin tone", input.faceAttributes.skinTone],
    ["Undertone", input.faceAttributes.undertone],
    ["Eye shape", input.faceAttributes.eyeShape],
    ["Lip shape", input.faceAttributes.lipShape],
    ["Hair color", input.faceAttributes.hairColor],
    ["Eye color", input.faceAttributes.eyeColor],
  ]);
  const what = facts([
    ["Product", spec.product ?? spec.category],
    ["Color", spec.colorName],
    ["HEX", spec.colorHex],
    ["Finish", spec.finish],
    ["Intensity", spec.intensity],
  ]);
  const where = facts([
    ["Placement", spec.placement],
    ["Side", spec.side],
    ["Face-shape adjustment", spec.faceAdjustment],
    ["Style adjustment", spec.styleAdjustment],
    ["Placement confidence", spec.placementConfidence],
    ["Geometry confidence", spec.geometryConfidence],
  ]);
  const how = facts([
    ["Direction", spec.direction],
    ["Technique", spec.technique],
    ["Tip", spec.tip],
  ]);
  const sourceRule = isFirstStep
    ? "Only the original selfie is supplied. Use it as both the permanent identity reference and the makeup-free starting state."
    : "Both images are supplied. The FIRST image is the original selfie: use it as the permanent identity reference. The SECOND image is the previous Result: use it as the cumulative makeup-state reference and the image to edit.";
  const kitRule = input.sourceMode === "makeup_kit" || input.sourceMode === "kit"
    ? "KIT MODE — STRICT\nUse only the owned product facts listed in WHAT TO APPLY. Do not invent, substitute, or infer any kit product, shade, HEX, or finish."
    : "";

  return `You are generating ONE image for a personalized step-by-step makeup tutorial.

PRIMARY OBJECTIVE

Create a realistic cumulative makeup edit of the SAME PERSON shown in the provided identity/source image(s).

This is an instructional makeup step, not a new portrait and not a general beauty transformation.

IDENTITY PRESERVATION — STRICT

Preserve the person's identity.

Do NOT change:
- face shape
- facial proportions
- skin tone
- ethnicity
- eye shape
- eye color
- nose
- lips
- hair
- hairstyle
- expression
- camera angle
- crop
- head position
- background
- lighting except tiny unavoidable editing variation

Do not make the person thinner, younger, smoother, more symmetrical, or more conventionally attractive.

Do not perform unrelated retouching.

TUTORIAL CONTEXT

${context || "No additional face attributes are available; do not infer them."}

CURRENT STEP

Step number: ${spec.stepNumber} of ${totalSteps}
Category: ${spec.category}

WHAT TO APPLY

${what}

${kitRule}

WHERE TO APPLY

${where || "Follow only the available current-step instruction; do not invent precise placement."}

HOW TO APPLY

${how || "Apply conservatively without inventing a technique."}

CUMULATIVE MAKEUP RULE — STRICT

The previous tutorial Result contains all completed makeup before this step.

Preserve ALL correctly applied previous makeup.

Apply ONLY the current makeup step described above.

Do not remove, replace, restyle, or intensify previous makeup unless the current instruction explicitly requires blending in an overlapping region.

ORIGINAL IDENTITY REFERENCE

${sourceRule}

The output must clearly remain the same person.

PLACEMENT ACCURACY

Apply the current product according to the personalized placement instruction.

Do not fall back to generic makeup placement when a more specific placement instruction is provided.

Respect:
- face attributes
- selected style
- actual recommendation/product
- placement
- direction
- intensity

REALISM

Keep:
- natural skin texture
- realistic pores/texture where visible
- realistic pigmentation
- realistic blending
- realistic makeup boundaries
- realistic highlights/shadows

Avoid:
- plastic skin
- face replacement
- excessive smoothing
- distorted features
- doubled features
- unrelated accessories
- added text

RESULT IMAGE MUST BE CLEAN

Do NOT draw:
- arrows
- overlay lines
- dots
- labels
- diagrams
- instructional shapes
- text

Those are rendered separately by FaceTune on the Placement side.

OUTPUT

Return ONE clean cumulative RESULT image representing:

previous completed makeup
+
the current personalized makeup step

while preserving the same person.`;
}
