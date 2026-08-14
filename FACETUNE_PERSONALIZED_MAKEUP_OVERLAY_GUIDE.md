# FACETUNE_PERSONALIZED_MAKEUP_OVERLAY_GUIDE.md

## 1. Feature Name

**FaceTune Personalized Makeup Placement & Overlay System**

## 2. Core Purpose

This file is the source of truth for fixing and upgrading the Step-by-Step Tutorial overlay system.

The overlays must be real makeup instructions, not decorative lines or generic shapes.

> **Face attributes + selected look + recommended makeup = personalized instructions + personalized placement overlays + cumulative result images**

One shared personalized step specification must drive:
1. written instructions;
2. overlay rendering;
3. Gemini result-image prompting.

These three outputs must agree.

## 3. Strict Scope Boundary

This work is strictly limited to the Step-by-Step Tutorial feature.

Preferred writable scope:

```text
lib/features/step_by_step_tutorial/**
supabase/functions/<tutorial-related-functions>/**
tutorial-specific migrations
tutorial-specific tests
tutorial-specific architecture notes
```

Other FaceTune systems may be read to understand contracts but must not be modified, refactored, renamed, reorganized, optimized, or behaviorally changed unless a minimal backward-compatible tutorial integration change is absolutely required.

If an unrelated file appears to require modification:

> STOP. Report the exact file/system, why it is needed, the smallest proposed change, and wait for explicit approval.

Protected systems include:
- Face Analysis behavior
- standard Makeup Recommendation behavior
- Gemini 3 Pro final preview behavior
- My Makeup Kit recommendation/preview behavior
- authentication
- unrelated Saved Looks / History
- unrelated database/RLS/navigation/shared UI

No opportunistic refactoring.

## 4. Personalized Tutorial Input

Every step should receive, where available:

- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color
- selected style/look
- actual recommendation details
- My Makeup Kit selected product snapshot when applicable
- original selfie reference
- previous tutorial result reference
- source mode
- current category

The planner must not operate only on:

```text
category = blush
```

It should operate on context such as:

```text
oval face + warm undertone + almond eyes + Party + peach satin blush
```

## 5. PersonalizedTutorialStepSpec

Create/evolve one central typed step specification as the authoritative source for text, overlay, and AI prompt.

Conceptually:

```text
PersonalizedTutorialStepSpec
{
  stepNumber
  category
  sourceMode
  faceAttributes
  selectedStyle

  productId?
  productName?
  colorName?
  colorHex?
  finish?

  whatToApply
  placementRegion
  placementDescription
  placementSide
  placementAnchors
  direction
  intensity
  technique
  tip?

  overlayType
  overlayColor
  overlayOpacity
  overlayGeometry

  geometryConfidence
  placementConfidence

  cumulativeInstruction
}
```

Exact names may follow existing architecture, but the single-source principle is mandatory.

## 6. Separate WHAT / WHERE / HOW

Example:

```text
WHAT
Peach Rose Blush
Satin
Medium intensity

WHERE
Upper outer cheekbone
Slightly above cheek center

HOW
Blend diagonally upward toward temple
```

Product selection and placement logic must remain separate.

## 7. Dynamic Steps

Do not hardcode a fixed number of tutorial steps.

Natural may omit contour/highlighter.
Full Glam may include them.
My Makeup Kit may contain only a few products.

In kit mode, never invent missing categories.

## 8. Face-Attribute Placement Rules

Placement must change based on relevant user attributes.

Examples:

### Blush
- round face → generally higher/outward
- long face → generally more horizontal
- oval face → upper cheekbone placement

### Contour
- round face → sculpt toward temples/jaw
- square face → soften jaw/temple placement
- long face → avoid emphasizing vertical length

### Eyeshadow
- hooded eyes → visible placement above natural crease where appropriate
- almond eyes → enhance natural outer shape
- round eyes → more elongated outer placement where appropriate

### Eyeliner
Adapt path, wing direction, thickness, and intensity to eye shape + style.

### Lips
Adapt coverage/diffusion guidance to lip shape + selected look.

These are planning rules, not fixed UI coordinates.

## 9. Face Geometry / Landmark Coordinates

The tutorial needs normalized face-relative geometry for relevant anchors/regions:

```text
leftEyeAnchor
rightEyeAnchor
leftBrowRegion
rightBrowRegion
noseBridge
noseTip
noseSides
lipBoundary
foreheadRegion
leftCheekRegion
rightCheekRegion
leftJawRegion
rightJawRegion
chinRegion
faceBoundary
```

Use normalized coordinates (0.0–1.0) relative to the image/face region.

Do not store device/screen pixel coordinates in domain logic.

## 10. Geometry Provider Isolation

Hide geometry acquisition behind a tutorial-specific abstraction such as:

```text
TutorialFaceGeometryProvider
```

The rest of the tutorial should consume normalized geometry without depending on how it was obtained.

Use existing FaceTune data first.

Do NOT add MediaPipe, OpenCV, TFLite, or another face stack without explicit approval.

## 11. Recommendation → Placement Metadata

Transform the actual recommendation into structured metadata.

Example:

```text
category: blush
region: upper_cheekbone
side: bilateral
anchor: cheekbone_relative_to_eye
direction: upward_outward
intensity: medium
face_shape_adjustment: oval
style_adjustment: party
color: #E58C87
finish: satin
```

The same metadata drives:
- written instruction;
- overlay;
- Gemini prompt.

## 12. Category-Specific Overlay Types

### Foundation
- broad coverage regions
- multiple outward blending arrows
- never one generic central strip

### Concealer
- targeted under-eye/nose/forehead/chin areas when instructed
- never generic oversized circles

### Contour/Bronzer
- narrow soft bands
- cheekbone/temple/jaw guides
- optional nose guides

### Blush
- soft cheek zones
- personalized blend direction

### Highlighter
- smaller highlight regions

### Eyeshadow
- lid / crease / outer-corner / inner-corner zones

### Eyeliner
- precise eye-relative path

### Brows
- directional fill / target-shape guidance

### Lipstick/Lip Gloss
- lip-relative boundary/coverage/center-emphasis guidance

## 13. Overlay Color

Where meaningful, the overlay region color should derive from the actual recommendation HEX.

Example:

```text
Peach Rose
#E58C87
```

Do not use generic pink for every category.

Neutral guide lines/arrows may use readable contrast, but product regions should reflect the recommendation when practical.

## 14. Style-Aware Placement

Placement/intensity/technique must also depend on selected style.

Example:

```text
Korean
→ softer/high blush
→ subtle eyeliner
→ diffused lips
```

versus:

```text
Party
→ stronger cheek color
→ more defined eyes
→ stronger contour/highlight
```

Therefore:

```text
face attributes
+
selected style
+
actual recommendation/product
```

must drive placement.

## 15. Written Instruction = Overlay = Gemini Intent

Do not let three systems interpret a step independently.

Example source:

```text
placement = upper outer cheekbone
direction = upward_outward
intensity = medium
color = Peach Rose
finish = Satin
```

Written instruction:

```text
Apply Peach Rose satin blush to the upper outer cheekbones and blend upward toward the temples with medium intensity.
```

Overlay:

```text
upper-cheek zones + upward/outward arrows
```

Gemini:

```text
apply the same product, same region, same direction, same intensity
```

## 16. Cumulative Results

Every Result image must preserve previous completed makeup.

```text
Original
→ Foundation
→ + Concealer
→ + Contour
→ + Blush
→ ...
→ Final Look
```

Step N Result = previous completed makeup + current step only.

## 17. Identity Preservation

Where supported, each generation should use:

```text
original selfie
+
previous result
+
current PersonalizedTutorialStepSpec
```

The original is the permanent identity reference.
The previous result is the cumulative makeup-state reference.

Do not change:
- face shape/proportions
- skin tone
- eyes/nose/lips
- hair
- expression
- camera angle/crop
- background
except tiny unavoidable editing variation.

No unrelated beautification.

## 18. Overlay Accuracy Validation

Before rendering, validate:

- coordinates within bounds
- correct left/right side
- cheek guides near cheek geometry
- eye guides near eye geometry
- lip guides near lip geometry
- arrows do not cross unrelated regions
- sizes are plausible
- bilateral guides are reasonable when intended
- overlay category matches current step

Invalid geometry must not be shown as correct.

## 19. Confidence-Aware Fallback

### High confidence
Precise overlay.

### Medium confidence
Broader safe zone + simpler direction.

### Low confidence
Do not show misleading precise lines.
Use broad safe placement if valid and prioritize written guidance.

Accuracy is more important than visual complexity.

## 20. Personalization Requirements

Different users with the same style should receive different placement where relevant.

```text
Round face + Party
!=
Oval face + Party
```

The same user with different styles should receive different relevant guidance.

```text
Same face + Korean
!=
Same face + Full Glam
```

## 21. My Makeup Kit

Kit mode input:

```text
face attributes
+
selected style
+
selected owned product
+
product color
+
finish
```

Rules:
- never invent products;
- preserve product snapshot;
- incomplete kits valid;
- same owned-product data must drive text, overlay, and Gemini.

## 22. Persistence

Persist the personalized plan so reopening does not re-decide placement.

Persist where appropriate:
- step order
- product snapshot
- color/finish
- placement
- direction
- intensity
- technique/tip
- face/style adjustment
- overlay metadata
- confidence
- result image reference
- prompt version
- model
- resolution

## 23. Model Configuration

Strict engineering rule:

> The tutorial image-generation model and output resolution must be configurable server-side and must not be tightly coupled to tutorial business logic or UI.

Current intended defaults may remain:

```text
model = gemini-3.1-flash-image
output = 512px
```

Do not change the existing Gemini 3 Pro final-preview flow.

## 24. Gemini Step Image Prompt — Source of Truth

The backend should generate the final prompt from structured step data, not arbitrary UI strings.

Use a versioned template.

```text
You are generating ONE image for a personalized step-by-step makeup tutorial.

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

Selected style:
{{selected_style}}

Relevant face attributes:
- Face shape: {{face_shape}}
- Skin tone: {{skin_tone}}
- Undertone: {{undertone}}
- Eye shape: {{eye_shape}}
- Lip shape: {{lip_shape}}
- Hair color: {{hair_color}}
- Eye color: {{eye_color}}

CURRENT STEP

Step number:
{{step_number}}

Category:
{{category}}

WHAT TO APPLY

Product:
{{product_name_or_category}}

Color:
{{color_name}}

HEX:
{{color_hex}}

Finish:
{{finish}}

Intensity:
{{intensity}}

WHERE TO APPLY

Placement:
{{placement_description}}

Side:
{{placement_side}}

Face-shape adjustment:
{{face_shape_adjustment}}

Style adjustment:
{{style_adjustment}}

HOW TO APPLY

Direction:
{{direction}}

Technique:
{{technique}}

CUMULATIVE MAKEUP RULE — STRICT

The previous tutorial Result contains all completed makeup before this step.

Preserve ALL correctly applied previous makeup.

Apply ONLY the current makeup step described above.

Do not remove, replace, restyle, or intensify previous makeup unless the current instruction explicitly requires blending in an overlapping region.

ORIGINAL IDENTITY REFERENCE

If both original selfie and previous Result are supplied:
- use original selfie as permanent identity reference;
- use previous Result as cumulative makeup-state reference.

The output must clearly remain the same person.

PLACEMENT ACCURACY

Apply the current product according to the personalized placement instruction.

Do not fall back to generic makeup placement when a more specific placement instruction is provided.

Respect:
- face attributes;
- selected style;
- actual recommendation/product;
- placement;
- direction;
- intensity.

REALISM

Keep:
- natural skin texture;
- realistic pores/texture where visible;
- realistic pigmentation;
- realistic blending;
- realistic makeup boundaries;
- realistic highlights/shadows.

Avoid:
- plastic skin;
- face replacement;
- excessive smoothing;
- distorted features;
- doubled features;
- unrelated accessories;
- added text.

RESULT IMAGE MUST BE CLEAN

Do NOT draw:
- arrows;
- overlay lines;
- dots;
- labels;
- diagrams;
- instructional shapes;
- text.

Those are rendered separately by FaceTune on the Placement side.

OUTPUT

Return ONE clean cumulative RESULT image representing:

previous completed makeup
+
the current personalized makeup step

while preserving the same person.
```

Prompt construction rules:
- omit genuinely unavailable optional values cleanly;
- never fabricate attributes/products;
- do not send misleading placeholders as real data.

## 25. Placement vs Result Responsibilities

Placement:

```text
previous Result
+
personalized FaceTune overlay
```

Result:

```text
previous cumulative makeup
+
current personalized step via Gemini
```

Gemini must not generate tutorial lines in V1.

## 26. QA Requirements

At minimum test:

```text
round-face blush != long-face blush
hooded-eye eyeshadow != almond-eye eyeshadow
Natural intensity < Full Glam intensity where appropriate
kit tutorial uses owned-product snapshot only
```

Also test:
- normalized geometry
- invalid geometry rejection
- confidence fallback
- HEX-driven overlay color
- text matches metadata
- prompt matches metadata
- Step N Placement uses Step N-1 Result
- Result contains no instructional graphics
- protected FaceTune flows unchanged

## 27. Success Definition

Complete when:

1. overlays are personalized rather than fixed;
2. facial attributes affect relevant placement;
3. selected style affects relevant placement/intensity;
4. overlays use face-relative geometry;
5. written instruction and overlay agree;
6. Gemini receives the same instruction;
7. cumulative Result images preserve previous makeup;
8. identity stays consistent;
9. kit mode uses only owned products;
10. low-confidence geometry does not show false precision;
11. existing FaceTune systems remain unchanged;
12. Placement ↔ Result slider continues working.

## 28. Non-Negotiable Rule

> The Personalized Makeup Placement & Overlay System is a Step-by-Step Tutorial-only enhancement. Unrelated FaceTune code must not be modified without explicit approval.
