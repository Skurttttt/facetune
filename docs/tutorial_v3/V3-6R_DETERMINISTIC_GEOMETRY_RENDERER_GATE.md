# V3-6R — Personalized Deterministic Geometry Renderer Gate

**Phase:** V3-6R (feasibility gate — no production pipeline, no persistence)
**Date:** 2026-08-27
**Branch:** `feature/step-by-step-tutorial-v3`
**Model:** `gemini-3.6-flash` (via `TUTORIAL_V3_GEOMETRY_MODEL`)
**Endpoint:** `POST /v1beta/models/{model}:generateContent` with `responseJsonSchema`

---

## Classification

# PASS

# READY FOR EXPLICIT V3-6B GEOMETRY PIPELINE AUTHORIZATION

All ten canonical categories plus six differential specs — **16 geometry
documents** — were produced live, validated by the real Dart validator
(16/16 accepted, 0 rejected), rendered by the real Flutter `CustomPainter`,
and inspected as pixels.

The architecture works. The model can locate an instruction on a specific face
and return coordinates, and Flutter can draw them deterministically over an
untouched photograph.

---

## 1. Why this architecture, and what changed

V3-6A.1 and V3-6A.2 both failed because the image model **repaints the surface
it is asked to annotate** — transferring makeup between categories, filling
lips with colour, lightening skin. That failure was not reachable by prompt
instruction: an explicit "never fill, tint, lighten or desaturate" ban still
produced paled lips and lightened skin.

This gate removes the model's ability to touch pixels at all. It returns
numbers; Flutter draws. The failure mode is therefore not merely discouraged —
it is **structurally impossible**, because there is no code path from the
model's output to the photograph.

---

## 2. Architecture Tested

```text
ORIGINAL SELFIE + PERSISTED STEP SPEC + SCOPED FACE ATTRIBUTES
                          ↓
              TUTORIAL_V3_GEOMETRY_MODEL          (gemini-3.6-flash)
                          ↓
              STRICT NORMALIZED GEOMETRY JSON
                          ↓
              TutorialV3GeometryValidator          (Dart, reject-never-repair)
                          ↓
              TutorialV3GuidelinePainter           (Flutter CustomPainter)
                          ↓
   ORIGINAL JPG (untouched) + TRANSPARENT GUIDELINE OVERLAY
```

**One image in, JSON out.** The probe rejects `images`, `parts`, `image2`,
`canonicalPreview`, `target` and `previousGeometry` with `400` rather than
ignoring them, so a canonical preview or a previous overlay cannot be sent
even by accident. Verified live:

```
POST … {"prompt":"x","image":{…},"canonicalPreview":{}}
→ 400 {"error":"invalid_request",
       "detail":"field \"canonicalPreview\" is not accepted: the mapper takes exactly one image"}
```

The probe also refuses image output: if any response part carries
`inlineData`, it returns `unexpected_image_output` rather than passing it on.

---

## 3. Contract

**Coordinates.** `x, y ∈ [0,1]`, origin top-left, `coordinate_space` must be
exactly `normalized_original_image`. Normalized against the ORIGINAL image, not
the displayed rect, so persisted geometry is device-independent.

**Primitives (5).** `region`, `ellipse`, `polyline`, `arrow`, `marker` — a
sealed Dart hierarchy with no "other" variant.

**Roles (7).** `coverage_zone`, `placement_zone`, `application_path`,
`blend_direction`, `boundary`, `exclusion`, `focus_marker`.

**Style is entirely Flutter's.** The contract carries no colour, opacity,
stroke width, font, gradient, blend mode, z-order, animation or text — there is
no field for any of them, and unknown fields are rejected. Every visual
decision lives in `TutorialV3RoleStyle`.

Two independent compatibility rules are enforced: role → allowed primitive
kinds (a direction must be an arrow), and category → allowed roles (eyeliner
cannot emit a full-face coverage zone).

---

## 4. Results — all ten canonical categories

| Category | Primitives | Roles returned | Validated | Placement |
| --- | --- | --- | --- | --- |
| foundation | 8 | coverage_zone:region, exclusion:ellipse, blend_direction:arrow | ✅ | **excellent** |
| concealer | 4 | placement_zone:region, blend_direction:arrow | ✅ | good |
| contour_bronzer | 4 | placement_zone:region, blend_direction:arrow | ✅ | good |
| blush | 4 | placement_zone:ellipse, blend_direction:arrow | ✅ | **excellent** |
| highlighter | 4 | placement_zone:ellipse | ✅ | good |
| eyeshadow | 4 | placement_zone:region, blend_direction:arrow | ✅ | good |
| eyeliner | 4 | application_path:polyline, blend_direction:arrow | ✅ | **excellent** |
| eyebrow | 4 | application_path:polyline, blend_direction:arrow | ✅ | good |
| lipstick | 4 | boundary:region, coverage_zone:region, application_path:polyline | ✅ | **loosest** |
| lip_gloss | 4 | placement_zone:ellipse, focus_marker:marker | ✅ | good |

**Foundation** is the standout. It returned a face-shaped coverage polygon plus
**three exclusion ellipses that land on both eyes and the mouth** — exactly the
"excluding the eye sockets and the lips" clause of the Step Spec — plus blend
arrows radiating outward from centre. That is real spatial comprehension of
this specific face, not a template.

**Eyeshadow** placed lid regions on both eyes with outward blending arrows,
answering the FAIL criterion "complex categories cannot be represented".

**Lipstick** is the weakest: the boundary region is in the right area but sits
noticeably low and slightly left, cutting across the lips rather than following
the cupid's bow. It would over-line the lower lip and under-cover the upper.
Usable as guidance, not precise.

---

## 5. Personalization differential — the decisive evidence

Three category pairs, each with the **same face, same category, same model**,
differing only in the Step Spec.

### Blush — placement and direction both moved

| | `blush_high_lifted` | `blush_low_horizontal` |
| --- | --- | --- |
| Zones | high on the outer cheekbone, just below the outer eye corner | low, on the apple of the cheek at nose-tip height |
| Arrows | steeply **up and out** toward the temples | strictly **horizontal** toward the ears |

### Eyeliner — the wing appeared and disappeared on instruction

| | `eyeliner_thin_tightline` | `eyeliner_extended_wing` |
| --- | --- | --- |
| Path | hugs the lash line, **stops at the outer corner** | continues **past the outer corner**, angling up toward the brow tail |
| Arrows | horizontal, ending at the corner | angled sharply upward beyond the eye |

### Lipstick — coverage extent changed

`lipstick_full_natural` returned full-lip coverage; `lipstick_centre_gradient`
returned a single centre ellipse with only 2 primitives, leaving the outer
thirds bare.

**This is not random jitter — the geometry moved in exactly the direction each
Step Spec described.** The mapper is reading the instruction, not applying a
per-category preset. PASS criterion 7 is satisfied with direct visual evidence.

---

## 6. Original integrity — byte-identical

```
source    assets/images/beauty_portrait.png
          4f5f476036c928d4b5474201e3c716c0a8a047102c31ac645c96ec220dd2263d
gate copy build/tutorial_v3_geometry_gate/original.png
          4f5f476036c928d4b5474201e3c716c0a8a047102c31ac645c96ec220dd2263d
          → IDENTICAL
```

`git status assets/` is clean. The renderer reads the original and writes only
to `build/`; it never opens the source path for writing. The harness re-reads
and byte-compares the original after rendering all 16 overlays.

---

## 7. Validation — reject, never repair

`TutorialV3GeometryValidator` accepted all 16 live documents and is covered by
**26 unit tests** proving it refuses:

unsupported schema version · wrong coordinate space · category mismatch ·
unknown category · unknown primitive kind · unknown role · out-of-range
coordinates (**not clamped**) · NaN · infinity · non-numeric coordinates ·
too-few region vertices · too-many polyline vertices · invalid radii ·
zero-length arrows · excessive primitive counts · role/kind incompatibility ·
category/role incompatibility · unexpected document fields (`svg`, `label`) ·
unexpected primitive fields (`color`, `opacity`) · unexpected point fields.

Out-of-range coordinates are rejected rather than clamped on purpose: a
coordinate at 1.4 means the model misunderstood the space, and pulling it to
1.0 would draw a confidently wrong overlay.

---

## 8. Transform correctness

`TutorialV3GeometryTransform` uses Flutter's own `applyBoxFit` +
`Alignment.inscribe` rather than hand-rolled arithmetic, so the overlay lands
exactly where the `Image` widget above it put the picture, for any BoxFit and
alignment. Stroke widths scale from the destination's shorter edge, so the
overlay reads identically on a phone and a tablet.

The gate renders at `BoxFit.fill` into the original's native 864×1821, which is
the identity case; the transform's behaviour under `contain`/`cover` on a
differently-shaped viewport is exercised in code but **not yet visually
confirmed on a device** — see limitations.

---

## 9. PASS criteria

| # | Criterion | Result |
| --- | --- | --- |
| 1 | original selfie byte-identical | ✅ SHA-256 match, git clean |
| 2 | strict normalized geometry returned | ✅ 16/16 |
| 3 | invalid geometry rejected | ✅ 26 validator tests |
| 4 | Flutter deterministic rendering works | ✅ 16 overlays rendered by the production painter |
| 5 | all canonical categories representable | ✅ 10/10 |
| 6 | geometry reasonably matches Step Spec | ✅ 9/10 good-to-excellent; lipstick loose |
| 7 | personalization differential proves non-static | ✅ 3 pairs, all moved as instructed |
| 8 | no AI replacement selfie exists | ✅ structurally impossible; probe rejects image output |
| 9 | no AI typography/style control | ✅ no field exists; unknown fields rejected |
| 10 | BoxFit/coordinate transform correct | ✅ in code via `applyBoxFit`; device confirmation pending |

---

## 10. Limitations and risks

1. **Lip boundary precision is the weakest result.** In the right region but
   offset low and left. V3-6B should expect lip guidance to read as
   approximate, and may want a boundary-only visual treatment rather than a
   filled coverage zone — the translucent fill over lips reads poorly.
2. **Coverage polygons are generous.** The foundation outline included a little
   hair at the left edge. Harmless as guidance, but not a precise face mask.
3. **One transient upstream 503.** Foundation failed on the first pass with
   `UNAVAILABLE — high demand` and succeeded on retry. Production needs bounded
   retry for this; it is not a capability limit.
4. **Schema constructs are constrained.** `type: "integer"`, integer `enum`,
   `minimum`/`maximum`, `minItems`/`maxItems` all cause `400 INVALID_ARGUMENT`
   from this API. The schema uses only the constructs
   `generate-makeup-recommendation` proves in production; **all range and count
   enforcement therefore lives in the Dart validator**, which is why that
   validator is not optional.
5. **Latency is ~10–23 s per step**, meaningfully slower than a text plan.
   V3-6B's prefetch and caching design should assume this.
6. **One face, one gate.** All evidence comes from a single stock portrait at
   one orientation. EXIF-rotated, mirrored front-camera, off-centre and
   non-portrait-ratio inputs are **not** covered here.
7. **`BoxFit.contain`/`cover` not visually confirmed** on a real viewport.

---

## 11. Security

| Item | State |
| --- | --- |
| `service_role` | not used, not read, not printed |
| `supabase secrets set` / `unset` | **never run** — no shared secret mutated |
| Gemini key | server-side only; never read, logged or returned |
| Probe auth | JWT verification **ON** (legacy anon JWT) + ephemeral second-factor token |
| Ephemeral token delivery | **whole-file replacement** of `probe_token.ts`, not string substitution — the V3-6A.2 failure where a regex rewrote the fail-safe guard cannot recur here |
| Fail-safe | placeholder token is 5 chars; the guard rejects anything under 32, so an unconfigured deploy accepts nothing |
| Deploy scope | only `map-tutorial-v3-guideline-geometry-probe`, explicit slug, `--use-api`, never `--prune` |
| Database | no migration, no SQL, no RLS change |

### OPEN HIGH-PRIORITY SECURITY ITEM

> The previously exposed legacy Supabase `service_role` credential **remains
> active** and must be migrated or revoked before production/release. Verified
> again this phase via non-secret `hash`/`prefix`: unchanged.

Per Source of Truth §4 this is a **release blocker**, though it is unrelated to
renderer feasibility and is not evidence for or against this result.

---

## 12. Cleanup

| Check | Result |
| --- | --- |
| `map-tutorial-v3-guideline-geometry-probe` deleted | ✅ absent |
| Production functions | ✅ all 9 present, unmodified |
| `GEMINI_API_KEY` | ✅ untouched |
| Shared secrets | ✅ none created or changed |
| Database / migrations / RLS | ✅ untouched |
| Local anon JWT + probe token | ✅ destroyed |
| `probe_token.ts` | ✅ placeholder restored |

---

## 13. Evidence

`build/tutorial_v3_geometry_gate/` (gitignored):

```
original.png                      byte-identical to the source asset
<id>_geometry.json                16 validated geometry documents
<id>_overlay.png                  16 overlays from the production painter
<id>_prompt.txt                   16 exact prompts
render_report.json                validation summary, 16/16 accepted
```

---

## 14. Recommendation

# READY FOR EXPLICIT V3-6B GEOMETRY PIPELINE AUTHORIZATION

The hypothesis holds: a text model can locate a persisted Step Spec on a real
face accurately enough to teach from, and Flutter can render it deterministically
over an untouched photograph. The two failures that killed the image-renderer
architecture — makeup transfer and surface recolouring — cannot occur here,
because the model never produces pixels.

V3-6B should carry forward: the Dart validator is load-bearing (the schema
cannot express ranges); lip guidance needs a boundary-only treatment; bounded
retry is required for transient 503s; and prefetch should assume ~10–23 s per
step. Robustness across orientation, mirroring and aspect ratio remains
untested and should be addressed before shipping.

## STOP
