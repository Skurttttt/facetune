export const TUTORIAL_MANIFEST_PROMPT_VERSION = "tutorial_manifest_v4_1";

/// Builds the visual-comparison prompt.
///
/// [supportingContext] carries the already-validated look plan. It is passed
/// only so genuine visual ambiguity can be resolved, and the prompt says so
/// explicitly and repeatedly: it must never be able to add a category the
/// images do not support. Passing it at all is a deliberate trade — it helps
/// with borderline cases like distinguishing subtle contour from natural
/// shadow, at the cost of needing very firm wording to stop it becoming a
/// checklist to copy.
export function tutorialManifestPrompt(supportingContext: string): string {
  return `
You are comparing two photographs of the SAME person to determine which makeup categories were actually applied.

IMAGE A is the ORIGINAL photograph, before any makeup was added.
IMAGE B is the FINAL photograph, after makeup was applied.

YOUR ONLY TASK
For each supported category below, decide whether that category is VISIBLY PRESENT in IMAGE B as a change from IMAGE A.

- present: you can see a clear, specific visual difference in IMAGE B that this category explains.
- absent: you cannot see a difference this category would explain.
- uncertain: you genuinely cannot tell from these two images.

SUPPORTED CATEGORIES (judge every one, add none)
foundation, concealer, contour_bronzer, blush, highlighter, eyebrows, eyeshadow, eyeliner, lips

HOW TO COMPARE
- Always compare against IMAGE A. The question is never "does this face have lips" but "did the lips CHANGE between A and B".
- Natural features are not makeup. Naturally rosy cheeks in both images are not blush. Naturally dark lashes in both are not eyeliner. Existing shadow under the cheekbone in both is not contour.
- Judge only what you can see. Skin that merely looks smoother may be foundation, but if you cannot distinguish it from lighting, answer uncertain.
- concealer is present only when you can see targeted coverage that foundation alone does not explain, such as under-eye or a specific blemish evened out.
- contour_bronzer is a deliberate deepening along cheekbones, jaw, temples, or nose that is not present in IMAGE A.
- highlighter is a deliberate added light reflection on high points that is not present in IMAGE A.
- eyebrows is present only when brow shape, density, or definition changed.
- lips covers any lip colour, gloss, or liner change.

RULES YOU MUST NOT BREAK
- Never invent, rename, merge, or split a category. Judge exactly the nine listed names.
- Never mark a category present because a makeup style usually includes it.
- Never mark a category present because of face shape, skin tone, or what would be flattering.
- Never mark a category present because it appears in the supporting context below.
- Never guess to be helpful. "uncertain" is a correct and useful answer; a wrong "present" creates a tutorial step for makeup that was never applied.
- Do not assume every category was used. Many real looks use only a few.

SUPPORTING CONTEXT — TIE-BREAKER ONLY
The following is what was intended. Use it ONLY to break a genuine visual tie where you are already between two answers. It is not evidence, it is not a checklist, and it can never move a category to present on its own. If the images do not support a category, it is absent or uncertain no matter what this context says.

${supportingContext}

OUTPUT
Return JSON matching the supplied schema exactly. For every category give a presence value and either a visualConfidence between 0 and 1 or null.
`.trim();
}
