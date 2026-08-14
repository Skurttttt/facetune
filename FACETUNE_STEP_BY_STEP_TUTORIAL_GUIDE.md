# FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md

## 1. Feature Name

**FaceTune Step-by-Step Tutorial**

---

## 2. Feature Purpose

The Step-by-Step Tutorial teaches the user how to recreate a generated FaceTune look on their own face through progressive visual and written guidance.

This is **not** a generic beauty tutorial.

It is personalized using:

- the user's uploaded selfie;
- the selected makeup style;
- the generated FaceTune recommendation or My Makeup Kit result;
- the colors, finishes, placements, and products involved in that look.

The feature should extend the existing FaceTune experience from:

> “This is the makeup look that suits you.”

to:

> “This is how to recreate that exact look, step by step, on your own face.”

---

## 3. Core Product Principles

### 3.1 Personalized Tutorial Using the Same User

The tutorial must use the user's own face.

Identity should remain consistent throughout the entire tutorial:

```text
Original Selfie
      ↓
Step 1
Same person
      ↓
Step 2
Same person
      ↓
Step 3
Same person
      ↓
...
      ↓
Final Result
Same person
```

The system must preserve as closely as possible:

- face shape;
- facial proportions;
- skin tone;
- eyes;
- nose;
- lips;
- hair;
- camera angle;
- crop;
- expression;
- lighting continuity.

The tutorial must not generate unrelated faces from step to step.

---

### 3.2 Progressive / Cumulative Makeup

Each step must build on the previous completed step.

Example:

```text
STEP 1
Foundation

STEP 2
Foundation
+ Concealer

STEP 3
Foundation
+ Concealer
+ Contour

STEP 4
Foundation
+ Concealer
+ Contour
+ Blush

...

FINAL
Complete recommended look
```

This is a strict requirement.

The system must not produce independent, unrelated makeup images for each step.

Each result image should represent:

> previous completed makeup state + current makeup step

---

### 3.3 Every Tutorial Step Has Two Views

Each tutorial step contains:

- **Placement**
- **Result**

#### Placement

Shows the same user **before the current makeup product is blended**, while preserving all previously completed makeup steps.

Placement may include:

- translucent color zones;
- placement lines;
- directional arrows;
- dots;
- product coverage guides;
- category-specific instructional shapes.

Placement answers:

> “Where do I put this makeup?”

#### Result

Shows the same user after the current step is correctly applied and blended.

Result answers:

> “What should this step look like after application?”

---

### 3.4 Reuse the Existing Draggable Comparison Interaction

The tutorial should reuse or adapt the current FaceTune comparison slider interaction.

Existing final preview:

```text
BEFORE  ←────●────→  AFTER
```

Tutorial:

```text
PLACEMENT  ←────●────→  RESULT
```

This keeps the interaction model consistent across FaceTune.

#### Strict Alignment Requirement

Both sides of the tutorial slider should align as closely as possible:

- same face position;
- same crop;
- same angle;
- same expression;
- same lighting;
- same previous makeup state.

The intended visual difference should be:

- left = placement guidance for the current step;
- right = completed current step.

---

## 4. Cost-Efficient Image Strategy

### 4.1 One New AI Result Image Per Step

For V1, the tutorial should not require a separate AI-generated Placement image.

Instead:

```text
Previous Step Result
        ↓ reused

Current Step Placement
Previous result image
+ instructional overlays

        ↔ slider

Current Step Result
One new Gemini-generated image
```

Example:

```text
STEP 3 RESULT
Foundation + Concealer + Contour

        ↓ reused

STEP 4 PLACEMENT
Same image
+ blush placement zones
+ arrows
+ dots

        ↔ slider

STEP 4 RESULT
Foundation + Concealer + Contour + Blush
```

Therefore, one new AI generation per tutorial step is sufficient for V1.

---

### 4.2 Final Tutorial Step Reuse

If the last tutorial step is simply the complete final makeup look, the tutorial should reuse the existing premium FaceTune final preview where appropriate instead of generating another identical final image.

Example:

```text
7 tutorial result images
using Gemini 3.1 Flash Image

+

1 existing final preview
using Gemini 3 Pro Image
```

This reduces unnecessary generation cost.

---

## 5. Model Strategy

### 5.1 Existing Final Makeup Preview

Use:

**Gemini 3 Pro Image**

Purpose:

- premium final Before/After result;
- highest visual quality;
- existing FaceTune preview behavior remains unchanged.

---

### 5.2 Step-by-Step Tutorial Result Images

Use:

**Gemini 3.1 Flash Image**

Initial target resolution:

**512px**

Reason:

- lower cost;
- faster generation;
- suitable for instructional images;
- better cost-to-quality balance for multiple tutorial steps.

The tutorial image model and output size should be configurable rather than hardcoded throughout the app.

Conceptually:

```text
FINAL_PREVIEW_MODEL
= gemini-3-pro-image

TUTORIAL_IMAGE_MODEL
= gemini-3.1-flash-image

TUTORIAL_IMAGE_SIZE
= 512
```

If 512px is not sufficient after testing, the tutorial can move to 1K without restructuring the feature.

---

## 6. Placement Overlay Strategy

For V1, instructional placement graphics should be rendered by FaceTune on top of the placement source image.

Possible overlay primitives:

- translucent zones;
- lines;
- arrows;
- dots;
- boundaries;
- optional labels.

This avoids paying for a second Gemini image for every step.

The overlay system should be data-driven and category-specific.

---

## 7. Category-Specific Placement Graphics

The same overlay pattern must not be used for every makeup category.

### Foundation

Possible guides:

- whole-face coverage zones;
- center-to-outward blending arrows.

### Concealer

Possible guides:

- under-eye zones;
- center forehead;
- around the nose;
- chin;
- targeted brightening areas.

### Contour / Bronzer

Possible guides:

- temples;
- under cheekbones;
- jawline;
- optional nose contour;
- blend direction arrows.

### Blush

Possible guides:

- upper cheek placement;
- cheek zones;
- upward arrows toward temples.

### Highlighter

Possible guides:

- tops of cheekbones;
- bridge or tip of nose;
- cupid's bow;
- brow bone where relevant.

### Eyeshadow

Possible guides:

- eyelid;
- crease;
- outer corner;
- inner-corner highlight;
- multiple shade zones.

Example:

```text
LIGHT SHADE
████ Lid

MEDIUM SHADE
//// Crease

DARK SHADE
●●● Outer corner

SHIMMER
✦ Inner corner
```

### Eyeliner

Possible guides:

- lash-line path;
- wing length;
- wing direction.

### Eyebrows

Possible guides:

- fill direction;
- target shape;
- sparse-area guidance.

### Lipstick / Lip Gloss

Possible guides:

- lip boundary;
- coverage area;
- optional emphasis zones.

---

## 8. Written Instructions

Every tutorial step should include written guidance in addition to the image.

Example:

```text
STEP 4 — BLUSH

COLOR
Peach Rose
#E58C87

FINISH
Satin

WHERE
Upper cheekbones

DIRECTION
Blend upward toward temples

INTENSITY
Light

TECHNIQUE
Start with a small amount and build gradually.
```

Suggested instruction fields:

- category;
- product name when applicable;
- color name;
- HEX where available;
- finish;
- placement;
- direction;
- intensity;
- technique;
- optional tip.

The feature should provide:

> visual instruction + written instruction

---

## 9. Dynamic Tutorial Steps

Tutorials must not be hardcoded to exactly eight steps.

The actual steps should be based on the generated look.

Example — Natural:

```text
1. Foundation
2. Concealer
3. Blush
4. Brows
5. Eyes
6. Lips
```

Example — Full Glam:

```text
1. Foundation
2. Concealer
3. Contour
4. Blush
5. Highlighter
6. Brows
7. Eyeshadow
8. Eyeliner
9. Lips
10. Final Look
```

The planning engine should determine:

- required categories;
- step count;
- step order;
- current product;
- previous cumulative state;
- written instructions;
- overlay metadata.

---

## 10. Standard Recommendation Support

The tutorial must support the normal FaceTune Makeup Recommendation flow.

Conceptual flow:

```text
Face Analysis
      ↓
Makeup Recommendation
      ↓
Final Preview
      ↓
How to Apply This Look
      ↓
Personalized Tutorial
```

The existing Makeup Recommendation behavior must remain unchanged.

---

## 11. My Makeup Kit Support

The tutorial must also support My Makeup Kit results.

Conceptual flow:

```text
Face Analysis
      ↓
My Makeup Kit
      ↓
Kit-Based Recommendation
      ↓
Kit Preview
      ↓
How to Apply This Look
      ↓
Personalized Tutorial
using owned products only
```

For My Makeup Kit:

- do not invent products;
- use only authenticated user's owned products;
- incomplete kits are valid;
- tutorial steps should reflect only the products/categories actually used;
- deleted or edited inventory should not silently rewrite historical tutorial snapshots.

---

## 12. Tutorial Persistence and Reuse

Tutorials should be saved so users can revisit them.

Possible UX:

```text
SAVED LOOK

Office Look

[ View Result ]
[ View Tutorial ]
```

Once generated:

```text
Tutorial
   ↓
Step 1
Step 2
Step 3
...
```

the app should store and reuse those outputs.

When the user returns later:

```text
load saved tutorial
→ do not regenerate
```

Regeneration should happen only when:

- the user explicitly requests it;
- the source look changed;
- the tutorial is missing or invalid;
- a generation failed and the user retries.

---

## 13. Suggested Data Model Direction

Names may be adapted after repository inspection.

### tutorial_sessions

Suggested responsibilities:

- id;
- user_id;
- source_mode;
- source_analysis_id;
- source_recommendation_id;
- source_kit_result_id;
- style;
- variation;
- total_steps;
- generation_status;
- prompt_version;
- tutorial_model;
- tutorial_image_size;
- created_at;
- updated_at.

### tutorial_steps

Suggested responsibilities:

- id;
- tutorial_session_id;
- step_number;
- category;
- title;
- instruction payload;
- placement metadata;
- placement source image path/reference;
- result image path/reference;
- model name;
- image size;
- prompt version;
- generation status;
- created_at;
- updated_at.

Storage structure should follow authenticated ownership and private storage rules already used by FaceTune.

---

## 14. Generation State Requirements

Tutorial generation should support clear states such as:

- not_started;
- planning;
- queued;
- generating;
- partially_complete;
- completed;
- failed.

Individual tutorial steps should also have their own generation status.

This allows:

- progressive loading;
- retrying one failed step;
- reopening partially generated tutorials;
- avoiding duplicate requests.

---

## 15. Error and Recovery Principles

The tutorial feature should gracefully handle:

- AI timeout;
- AI generation failure;
- broken storage references;
- partially completed tutorials;
- offline access to already cached/saved data where practical;
- stale signed URLs;
- deleted source data;
- invalid tutorial step data;
- duplicate user requests.

Never expose:

- Gemini API keys;
- raw backend stack traces;
- sensitive storage details.

---

## 16. Frozen Existing Systems

This feature is additive.

The following existing systems are considered frozen unless a tutorial phase explicitly extends them safely:

- Face Analysis;
- Makeup Recommendation;
- existing final makeup preview;
- My Makeup Kit;
- Saved Looks;
- History;
- authentication;
- existing storage/security behavior.

Do not rewrite these systems merely to implement the tutorial.

---

## 17. V1 Non-Goals

Do not include these in the first version unless explicitly requested later:

- AI video tutorials;
- real-time AR;
- voice coaching;
- live camera tracking;
- animated brush strokes;
- full manual face annotation editing;
- social sharing system;
- collaborative tutorials.

---

## 18. UX Direction

The Step-by-Step Tutorial should follow the established FaceTune visual language:

- premium beauty aesthetic;
- Material 3;
- soft feminine palette;
- clean spacing;
- rounded surfaces;
- clear hierarchy;
- minimal clutter;
- modern mobile-first interaction.

Representative tutorial screen:

```text
How to Apply This Look

STEP 4 OF 8 — BLUSH

PLACEMENT  ←────●────→  RESULT

[ same user, aligned comparison ]

Color       Peach Rose
Finish      Satin
Placement   Upper cheekbones
Direction   Blend upward toward temples
Intensity   Light

[ Previous ]              [ Next Step ]
```

---

## 19. Engineering Principles

Continue following FaceTune's existing engineering standards:

- Flutter / Dart;
- Riverpod;
- Clean Architecture;
- Repository Pattern;
- feature-first structure;
- Supabase Auth;
- Supabase Postgres;
- Supabase Storage;
- Supabase Edge Functions;
- server-side Gemini calls only;
- RLS;
- private user data;
- no API keys in Flutter;
- typed domain models;
- explicit state handling;
- no fabricated test/build/deployment claims.
- The tutorial image-generation model and output resolution must be configurable server-side and must not be tightly coupled to tutorial business logic or UI.

---

## 20. Success Definition

The feature is complete when a user can:

1. open a generated FaceTune look;
2. choose **How to Apply This Look**;
3. receive a dynamic tutorial based on that actual look;
4. see their own face throughout the tutorial;
5. see cumulative makeup across steps;
6. drag between **Placement** and **Result**;
7. understand where and how to apply each product;
8. read structured written instructions;
9. move backward and forward through steps;
10. revisit the tutorial later without unnecessary regeneration;
11. use the feature with both standard recommendations and My Makeup Kit;
12. complete the tutorial without breaking the existing FaceTune flows.

---

## 21. Non-Negotiable Feature Rule

> The existing Makeup Recommendation and My Makeup Kit flows are protected. The Step-by-Step Tutorial must be additive, isolated, identity-preserving, cumulative, cost-aware, and must not modify the existing recommendation or final-preview behavior unless a specific tutorial phase explicitly requires a backward-compatible integration point.
