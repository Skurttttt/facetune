# FaceTune AI quality notes (Phase 22)

Developer-facing notes on prompt versions, the changes made in Phase 22, and the
protocol for evaluating AI quality. Every prompt version is persisted on the row
it produced (`analyses.prompt_version`, `recommendations.prompt_version`,
`generated_images.prompt_version`), so output can always be traced to the prompt
that generated it.

## Prompt version history

| Stage | Version | Change |
| --- | --- | --- |
| Face analysis | `face_analysis_v1` | Initial classifier (Phase 7). |
| Face analysis | `face_analysis_v2` | Colour-judgement rules, occlusion handling, calibrated confidence bands, stricter separation of suitability from attribute certainty. Model temperature 0.1. |
| Recommendation | `makeup_recommendation_v1` | Initial plan generator (Phase 9). |
| Recommendation | `makeup_recommendation_v2` | HEX/shade-name coherence rules, undertone-appropriate hue families, per-style intensity register, placement tied to detected geometry. Model temperature 0.4. |
| Preview | `makeup_preview_v1` | Initial identity-preserving edit (Phase 10). |
| Preview | `makeup_preview_v2` | Explicit identity-carrying skin detail preservation, no-symmetrize/no-slim rules, makeup-as-translucent-layer instruction, depth preservation on deeper skin tones, variation constrained to cosmetic interpretation. |

### Cost consequence of a version bump

`generate-makeup-recommendation` reuses a cached plan only when
`prompt_version` matches. Bumping to `v2` means the next request for an
analysis+style pair that already has a `v1` plan will call Gemini again and
write a new row. This is intended — a new prompt should produce a new plan — but
it costs quota on first use after deploy. Analyses are cached by `analysisId`
rather than version, so existing scans are never re-analyzed.

## What Phase 22 changed and why

### 1. Deterministic attribute classification

Neither text function set a sampling temperature, so both ran at the API
default, which is tuned for creative writing. Face-attribute classification is a
labelling task: the same selfie should produce the same enum values on every
run. Analysis now runs at `temperature: 0.1, topP: 0.8`; recommendation runs at
`0.4` — low enough for a coherent palette, high enough that styles stay
distinguishable.

This is the single largest lever on the "facial attribute consistency"
criterion, and it required no prompt change at all.

### 2. Tiered confidence gating

Previously any attribute scoring below 0.45 rejected the entire scan with
`low_confidence`. In practice that meant eyewear, an updo, or a tight crop could
fail an otherwise perfect scan because `eyeColor` or `hairColor` was uncertain —
attributes that barely influence shade matching.

Confidence is now tiered:

| Tier | Attributes | Floor | Rationale |
| --- | --- | --- | --- |
| Core | `skinTone`, `undertone`, `faceShape` | 0.45 | Drive foundation/concealer matching and contour placement. A weak reading makes the plan unreliable. |
| Secondary | `eyeShape`, `lipShape`, `hairColor`, `eyeColor` | 0.25 | Refine the plan. Routinely occluded. Below 0.25 is a guess and still fails. |

Nothing is fabricated: the real confidence value is stored and displayed in the
beauty profile, so a 0.3 reading is shown to the user as a 30% confidence.

This is what makes "glasses where reasonably supported" work.

### 3. Colour coherence rules

`makeup_recommendation_v2` states explicitly that a HEX must be a plausible
rendering of its shade name, that foundation and concealer HEX must sit in the
detected depth range, that hue families must follow the undertone, and that
contour must read as a cool shadow rather than orange. It also pins an intensity
register per style so `overallIntensity` cannot contradict the item intensities.

### 4. Identity drift

`makeup_preview_v2` adds the failure modes that image models actually exhibit:
beautification, slimming, symmetrizing, and smoothing away freckles, moles, and
scars — the details that carry recognizability. It frames the task as a local
retouch of one photograph, instructs that makeup is a translucent layer
following existing light, and forbids lightening deeper skin under foundation.
Variation is constrained to cosmetic interpretation so regenerating cannot drift
identity to create difference.

### 5. Bounded retry alignment

`generate-makeup-recommendation` retried transient upstream failures with no
delay, and reported every transport failure as `gemini_timeout`. It now backs
off between attempts (400 ms x attempt, matching analyze-face) and distinguishes
a genuine timeout from a network error. Retries remain bounded at 2 attempts.

## Evaluation protocol

None of the changes above have been evaluated against real Gemini output — see
Limitations. Run this protocol before trusting a prompt version in production.

### Input matrix

Assemble a consented evaluation set covering, at minimum, one selfie per cell:

- **Skin tone**: very_light, light, medium, tan, deep, very_deep
- **Undertone**: warm, cool, neutral, olive
- **Face shape**: oval, round, square, heart, oblong
- **Eye shape**: almond, round, hooded, monolid
- **Lip shape**: thin, medium, full
- **Hair / eye colour**: at least one non-brown pair
- **Lighting**: daylight, warm indoor, cool indoor, dim, strong side-light
- **Occlusion**: clear glasses, tinted glasses, hair across the face
- **Pre-existing makeup**: bare face and full face

Deep and very_deep tones with olive undertones are the highest-risk cell for
both shade matching and preview lightening. Do not skip it.

### Per-stage acceptance criteria

**Face analysis**
1. Run the same selfie three times. Core attributes must be identical across
   runs; secondary attributes may vary by at most one adjacent enum value.
2. Skin tone must not shift when the same face is shot under warm versus cool
   light.
3. A face wearing foundation must not report a different undertone than the same
   face bare.
4. Glasses must not produce a suitability failure; they should lower `eyeShape`
   and `eyeColor` confidence instead.
5. Confidence must be discriminating — a set where every attribute always
   returns 0.95 indicates the model is not calibrating.

**Recommendation**
1. Every HEX must visually match its shade name. Render the swatches; do not
   read the hex codes.
2. Foundation HEX must be wearable on the detected depth. Check the deep and
   very_deep rows specifically.
3. Warm undertones must not receive a blue-red lip as the primary
   recommendation, and vice versa.
4. Generate all twelve styles for one analysis. Intensities must differ in the
   direction the style implies, and no two styles should read identically.
5. No brand, retailer, or celebrity may appear in any field.

**Preview**
1. Identity: a third party shown the original and the preview must identify them
   as the same person without hesitation.
2. Geometry: overlay original and preview. Nose, eye spacing, jaw, and hairline
   must not shift.
3. Skin detail: freckles, moles, and scars present in the original must survive.
4. Depth: deeper skin must not be lightened under foundation.
5. Makeup must match the plan's colours and intensity, and follow the
   photograph's existing light direction.
6. Generate three variations. They must differ cosmetically while identity,
   framing, and lighting stay fixed.

**Failure handling**
1. A non-face image returns `no_face`, not a fabricated analysis.
2. Two faces returns `multiple_faces`.
3. Truncating the model response mid-JSON returns `malformed_ai_json`, never a
   partial plan.
4. Timeouts and 5xx retry at most twice, then surface a retryable failure.

### Recording results

Log the prompt version, model ID, and input cell for every evaluation run.
Because both are persisted per row, a regression can be attributed to a specific
prompt version rather than guessed at.

## Limitations

- **No live evaluation was performed.** These changes are reasoned from the
  prompt and model configuration, not measured against real Gemini output. No
  Gemini call was made, and no facial-image corpus was used. The prompt versions
  are explicit and the config is deliberate, but the quality claims above are
  hypotheses until the protocol is run.
- Temperature values (0.1 / 0.4) are principled starting points, not tuned
  optima. Tune them against the input matrix.
- The tiered confidence floors (0.45 / 0.25) are judgement calls. If evaluation
  shows secondary attributes are unreliable at 0.3, raise the secondary floor
  rather than removing the tier.
- The preview function still sets no `generationConfig`. Image-model sampling
  parameters were left untouched because an unsupported field there returns a
  400 and breaks generation outright; that change needs a live request to
  validate.
- No automated regression suite exists for AI output quality, and building one
  would consume quota on every run. The protocol above is deliberately manual.
