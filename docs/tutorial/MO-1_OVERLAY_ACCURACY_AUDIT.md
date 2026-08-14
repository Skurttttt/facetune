# MO-1 — Overlay Accuracy Audit & Scope Lock

## Scope

This audit covers only the Step-by-Step Tutorial feature and its
`generate-tutorial-step` Edge Function. It does not authorize changes to the
standard recommendation, final-preview, face-analysis, saved/history, or My
Makeup Kit implementations.

## Current behavior

### Coordinate source

`TutorialPlanningEngine._buildPlan` asks
`TutorialPlacementOverlayCatalog.defaultFor(category)` for every planned step.
The catalog contains literal normalized `0.0–1.0` points for each category.
They are approximate positions for a centered, front-facing portrait; they are
not derived from the current selfie or landmarks.

The renderer multiplies each normalized point by the displayed image width and
height. Consequently, overlays scale with the widget, but their face-relative
location and shape are fixed. There is no geometry provider, landmark input,
geometry confidence, side validation, or category/region validation.

### Inputs that affect placement

| Input | Written instruction | Overlay coordinates/shape | Gemini step prompt |
|---|---:|---:|---:|
| Recommendation placement/technique | Yes | No | Yes, via `instruction_json` |
| Recommendation color/HEX/finish/intensity | Yes | No | Yes, via `instruction_json` |
| Selected style | Session display only | No | No |
| Face attributes | No | No | No |
| Kit product snapshot | Yes, where available | No | Yes, via `instruction_json` |

Although `TutorialPlacementOverlay.colorHex` exists and the painter can render
it, the static catalog does not populate it from the recommendation. Product
color therefore does not normally affect the current overlay. Finish and
intensity cannot affect placement because the overlay contract has no such
semantics.

### Source-of-truth assessment

Text and Gemini currently share the persisted `TutorialInstruction` JSON.
The overlay does not: it is separately selected from a category-only static
catalog. Category identity is consistent, but WHAT/WHERE/HOW semantics are not
represented once and projected to all three consumers. Gemini receives the
instruction JSON, category label, and cumulative images, but not the session's
style or face attributes.

## Current data flow

```text
standard recommendation item OR kit recommendation selection/snapshot
  -> TutorialPlanningEngine
     -> TutorialInstruction (recommendation facts)
     -> TutorialPlacementOverlayCatalog.defaultFor(category) (fixed points)
  -> GetOrCreateTutorialSession
  -> TutorialRepository.createStep
  -> tutorial_steps.instruction_json + placement_metadata_json
  -> TutorialStepDto / SupabaseTutorialRepository / TutorialSessionState
  -> TutorialStepViewer
     -> PlacementResultComparison
        -> previous Result, or original selfie for step 1
        -> TutorialPlacementOverlayLayer (normalized points -> widget pixels)

tutorial_steps.instruction_json
  -> generate-tutorial-step
  -> tutorialStepPrompt(JSON.stringify(instruction))
  -> Gemini Result image
```

For cumulative imagery, step 1 uses the original selfie. Step N uses step
N-1's Result as the cumulative source and also sends the original selfie as an
identity anchor. The Result prompt forbids unrelated edits and instructional
graphics. This cumulative image flow is useful and should be retained.

## Root cause

The current plan has two independent representations:

1. a recommendation-derived `TutorialInstruction` for text and Gemini; and
2. a category-derived `TutorialPlacementMetadata` for rendering.

The planner never receives facial attributes or face geometry, does not apply
style-aware placement rules, and cannot express confidence. Normalization
solves display-size scaling only; it does not make the coordinates personalized
or anatomically accurate.

## Missing personalization

- No typed tutorial input combining face attributes, selected style,
  recommendation data, and immutable kit snapshot data.
- No canonical per-step WHAT / WHERE / HOW specification.
- No tutorial-only face geometry abstraction or provider.
- No face-shape, eye-shape, lip-shape, or style placement rules.
- No recommendation-driven overlay color, finish, or intensity behavior.
- No confidence level or safe fallback policy.
- No validation of bounds, side, anatomical region, bilateral symmetry,
  plausible size, or arrow path.
- No guarantee that written text, overlay, and Gemini are projections of the
  same structured placement decision.
- Existing tests prove catalog completeness, normalized serialization,
  rendering primitives, viewer behavior, persistence, and prompt basics, but
  do not prove user/style variation, anatomical proximity, confidence fallback,
  or cross-consumer semantic consistency.

## Minimal tutorial-only architecture

### `PersonalizedTutorialInput`

A domain value supplied to the tutorial planner containing:

- facial attributes and their available confidence values;
- selected style;
- source mode;
- standard recommendation data or an immutable owned-product snapshot;
- optional normalized face geometry plus geometry confidence.

It must not contain widget pixels, Flutter types, backend model names, or output
resolution. Kit mode must expose only the saved product snapshot, never live
inventory or invented products.

### `PersonalizedTutorialStepSpec`

The canonical immutable decision for one step, separated into:

- WHAT: category, product snapshot/category, color name, HEX, finish;
- WHERE: semantic region, side, normalized geometry anchors/regions;
- HOW: direction, intensity, technique, tip;
- WHY/ADJUSTMENT: face-shape and style adjustments;
- SAFETY: geometry source, placement confidence, fallback mode.

Written instructions, persisted overlay metadata, and the Gemini prompt input
must be projections of this same spec. Consumers must not independently infer
placement.

### Geometry abstraction

Introduce a tutorial-domain `TutorialFaceGeometry` expressed only in normalized
coordinates, with semantic regions for eyes, brows, nose, lips, forehead,
cheeks, jaw, chin, and face boundary. Access it through a
`TutorialFaceGeometryProvider` abstraction that can use existing FaceTune data
when available. Semantic face attributes must not be misrepresented as exact
landmarks. No new MediaPipe/OpenCV/TFLite stack is authorized.

### Placement rules

A pure tutorial-domain rule engine should consume
`PersonalizedTutorialInput + category/product` and emit the WHERE/HOW portion
of the step spec. Rules combine relevant face attributes, selected style, and
actual recommendation/product data. Category rules remain independently
testable and must never emit UI pixels or widgets.

The static catalog may remain only as an explicitly named safe fallback during
migration. It must not silently masquerade as personalized geometry.

### Confidence-aware overlay

Represent confidence independently from geometry and choose rendering detail
before the presentation layer:

- high: precise validated regions and direction paths;
- medium: broader validated safe zones and simpler direction;
- low/unavailable: no precise lines; show only a valid broad safe region when
  one can be justified, otherwise prioritize written guidance and render no
  placement geometry.

Validate normalized bounds, side, category/region compatibility, anatomical
proximity, plausible size, bilateral intent, and arrow paths before persistence
or rendering. Invalid geometry must degrade safely, never fall back to random
or falsely precise coordinates.

## Scope lock for later MO phases

Allowed implementation locations remain:

- `lib/features/step_by_step_tutorial/**`
- `supabase/functions/generate-tutorial-step/**`
- tutorial-specific tests, migrations, and documentation

The server remains the source of truth for tutorial image model and resolution.
Neither belongs in the step specification or UI. Existing standard Gemini 3 Pro
final-preview behavior is protected. Any required edit outside this scope must
stop the phase and report the exact file, reason, smallest change, and impact.

MO-1 adds documentation only. It intentionally does not implement the redesign.
