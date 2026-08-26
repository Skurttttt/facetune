import type { CategoryProductFacts } from "./types.ts";

export const TUTORIAL_GEOMETRY_PLAN_PROMPT_VERSION = "tutorial_geometry_plan_v1";

export type TutorialFaceAttributes = {
  faceShape?: string;
  skinTone?: string;
  undertone?: string;
  eyeShape?: string;
  lipShape?: string;
  hairColor?: string;
  eyeColor?: string;
};

function clean(value: unknown): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

/** Converts a raw `analyses` row into the typed prompt contract. Missing
 * optional facts stay missing -- the prompt builder never manufactures face
 * data (mirrors `generate-tutorial-step/prompt.ts`'s identical rule). */
export function tutorialFaceAttributesFromRow(
  row: Record<string, unknown>,
): TutorialFaceAttributes {
  return {
    faceShape: clean(row.face_shape),
    skinTone: clean(row.skin_tone),
    undertone: clean(row.undertone),
    eyeShape: clean(row.eye_shape),
    lipShape: clean(row.lip_shape),
    hairColor: clean(row.hair_color),
    eyeColor: clean(row.eye_color),
  };
}

function facts(
  values: Array<[label: string, value: string | undefined]>,
): string {
  return values
    .filter((entry): entry is [string, string] => entry[1] !== undefined)
    .map(([label, value]) => `${label}: ${value}`)
    .join("\n");
}

function categoryBlock(entry: CategoryProductFacts, index: number): string {
  const productFacts = facts([
    ["Product", entry.productName ?? entry.label],
    ["Color", entry.colorName],
    ["HEX", entry.colorHex],
    ["Finish", entry.finish],
    ["Intensity", entry.intensity],
    ["Recommendation placement", entry.placement],
    ["Recommendation technique", entry.technique],
  ]);
  return `${index + 1}. category="${entry.category}" (${entry.label})\n${
    productFacts || "No further product facts available for this category."
  }`;
}

/** Full, versioned prompt for the tutorial-only geometry & placement
 * planning call (TF-2). Gemini inspects the real selfie and, for each
 * category already listed below, decides real photo-grounded zones/paths/
 * arrows plus placement/direction/intensity/technique/confidence and an
 * optional color/finish echo -- never inventing a category, product, or
 * color this prompt did not already supply. */
export function tutorialGeometryPlanPrompt(params: {
  selectedStyle?: string;
  sourceMode?: string;
  faceAttributes: TutorialFaceAttributes;
  categories: CategoryProductFacts[];
}): string {
  const { selectedStyle, sourceMode, faceAttributes, categories } = params;
  const context = facts([
    ["Selected style", selectedStyle],
    ["Face shape", faceAttributes.faceShape],
    ["Skin tone", faceAttributes.skinTone],
    ["Undertone", faceAttributes.undertone],
    ["Eye shape", faceAttributes.eyeShape],
    ["Lip shape", faceAttributes.lipShape],
    ["Hair color", faceAttributes.hairColor],
    ["Eye color", faceAttributes.eyeColor],
  ]);
  const categoryList = categories.map(categoryBlock).join("\n\n");
  const kitRule = sourceMode === "makeup_kit"
    ? "KIT MODE -- STRICT\nEvery category below is backed by a real, owned kit product. Use only the color/finish facts already listed for that category. Do not invent, substitute, or infer any product, shade, HEX, or finish beyond what is given."
    : "";

  return `You are the tutorial-only geometry & placement planner for a personalized step-by-step makeup tutorial.

You are NOT generating an image. You are analyzing the supplied selfie once and returning a strict JSON placement plan.

TASK

For EVERY category listed below, inspect the actual face in the supplied selfie and decide:
- real, photo-grounded zones (regions to cover), paths (ordered guide lines), and/or arrows (blend direction) -- normalized 0.0-1.0 coordinates relative to the image width/height, never pixels;
- a short placement description grounded in what you actually see on this face;
- direction, intensity, and technique;
- your confidence (0.0-1.0) in each geometry primitive and in the category overall;
- colorHex/finish ONLY if you are directly echoing the exact value already given for that category below -- otherwise return null. Never invent a color or finish.

You must return EXACTLY one plan entry per category listed below -- the same set, no more, no fewer, no duplicates, no categories not listed.

FACE CONTEXT

${context || "No additional face attributes are available; do not infer them."}

CATEGORIES TO PLAN

${categoryList}

${kitRule}

GEOMETRY RULES -- STRICT

- Every coordinate must be between 0.0 and 1.0 inclusive, relative to the selfie's own width/height.
- A zone needs at least one point (ellipse/soft_band/region: one point as its center, or several as a boundary; polygon: three or more boundary points).
- A path needs at least two ordered points.
- An arrow needs a distinct "from" and "to" point.
- If you cannot determine real geometry for a category with reasonable confidence, still return the category with your best real observation and a lower confidence value -- never fabricate placeholder coordinates you did not actually derive from the image.

IDENTITY -- STRICT

Do not alter, describe changes to, or comment on the person's identity. This is a planning-only analysis of an unmodified reference photo.

OUTPUT

Return ONLY the structured JSON plan matching the required schema. No prose, no markdown, no commentary.`;
}
