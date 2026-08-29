# V3-8 — Tutorial UI

**Branch:** `feature/step-by-step-tutorial-v3`
**Date:** 2026-08-28
**Preconditions:** V3-6R = PASS, V3-6B = complete, V3-7 = complete
**Status:** Implementation complete. **No remote mutation, nothing deployed, nothing applied.**

---

## 1. What this phase built

The V3 tutorial screen: the untouched original selfie with a deterministic
Flutter overlay, the canonical premium preview as the target reference, and
every word taken from the persisted Step Spec.

```text
STEP 1 OF 3
Foundation

┌──────────────────────────┐
│ Stack                    │
│  ├── original selfie     │   ← displayed, never rewritten
│  └── CustomPaint(geometry)│  ← Flutter-drawn, Flutter-styled
└──────────────────────────┘

TARGET LOOK
[ canonical final preview — tap to enlarge ]

APPLY / WHERE / DIRECTION / TECHNIQUE
WHY THIS PLACEMENT / HOW THIS BUILDS THE LOOK / TIP

← Previous                            Next →
```

---

## 2. Files changed

### New — presentation

| File | Role |
|---|---|
| `presentation/pages/tutorial_v3_page.dart` | The screen: phases, layout, step image, target reference, navigation |
| `presentation/widgets/tutorial_v3_guideline_view.dart` | `Stack(Image, CustomPaint)` that resolves the selfie's intrinsic size before attaching the painter |
| `presentation/widgets/tutorial_v3_target_reference.dart` | TARGET LOOK thumbnail, expandable to the full preview |
| `presentation/widgets/tutorial_v3_step_details.dart` | The labelled instruction blocks |
| `presentation/widgets/tutorial_v3_step_navigation.dart` | ← Previous / Next → |
| `presentation/utils/tutorial_v3_display.dart` | Category display labels, reusing the Kit's |

### New — domain / data (minimal additions the screen required)

| File | Role |
|---|---|
| `domain/entities/tutorial_v3_session_images.dart` | The two signed URLs a tutorial displays |
| `TutorialV3Repository.loadImages(session)` | Resolves the selfie path from the session's analysis and signs both images |
| `TutorialV3RemoteDataSource.findOriginalImagePath(analysisId)` | Reads `analyses.original_image_path` under RLS |

### New — tests

| File | Tests |
|---|---|
| `test/.../tutorial_v3_geometry_transform_test.dart` | 16 |
| `test/.../tutorial_v3_guideline_view_test.dart` | 8 |
| `test/.../tutorial_v3_page_test.dart` | 30 |
| `test/.../tutorial_v3_overlay_compositor.dart` | (moved out of `lib/` — see §4.5) |

### Modified

| File | Change |
|---|---|
| `presentation/controllers/tutorial_v3_session_state.dart` | `TutorialV3ImagesPhase`, `images`, `hasImages` |
| `presentation/controllers/tutorial_v3_session_controller.dart` | Signs images after the plan is known; `retryImages()`; `_stepState` carries image state across a step change |
| `presentation/painters/tutorial_v3_guideline_painter.dart` | `renderGuidelineOverlay` removed from `lib/` |
| `data/repositories/supabase_tutorial_v3_repository.dart` | `loadImages` |
| `data/repositories/unavailable_tutorial_v3_repository.dart` | `loadImages` stand-in |
| `test/.../tutorial_v3_no_intermediate_result_contract_test.dart` | +5 UI contract tests |
| `test/.../tutorial_v3_geometry_render_harness.dart` | Imports the compositor from the test tree |
| `test/.../supabase_tutorial_v3_repository_test.dart`, `test/.../tutorial_v3_session_controller_test.dart` | Fakes implement the new methods |

---

## 3. Required layout — where each element lives

| Layout element | Implementation |
|---|---|
| `STEP N OF TOTAL` | `_Tutorial`, from `step.stepIndex` and `state.totalSteps` — both read off the persisted plan |
| `CATEGORY` | `step.spec.category.label` |
| `Stack(selfie, CustomPaint)` | `TutorialV3GuidelineView` |
| `TARGET LOOK` | `_TargetLook` + `TutorialV3TargetReference` |
| `APPLY … TIP` | `TutorialV3StepDetails`, from `TutorialV3StepInstructions.fromSpec` |
| `← Previous / Next →` | `TutorialV3StepNavigation` |

---

## 4. Architecture decisions

### 4.1 The painter is attached only once the real image size is known

Geometry is normalized against the ORIGINAL image, so
`TutorialV3GeometryTransform` needs that image's true pixel dimensions to place
it inside whatever rect the photograph occupies. `TutorialV3GuidelineView`
resolves the `ImageStream` first and attaches the `CustomPaint` only after the
intrinsic size arrives. Painting against a guessed size would misplace every
primitive on any selfie that is not exactly the widget's shape.

`fit` and `alignment` are passed to the `Image` and to the painter from the same
two fields, so the two can never disagree.

### 4.2 The view takes an `ImageProvider`, not a URL

The page supplies `NetworkImage(signedUrl)`. This is what Flutter's own `Image`
does, it decouples the widget from how the photograph is fetched, and it makes
the overlay's alignment testable against real decoded bytes rather than a
mocked HTTP layer.

### 4.3 Three independent phases

`TutorialV3Phase` (the tutorial) · `TutorialV3ImagesPhase` (the two signed
URLs) · `TutorialV3StepGeometryPhase` (this step's overlay).

They fail separately because they are separately recoverable. A geometry
failure keeps the instruction text, the target reference and the navigation on
screen with a retry over the photograph. A signing failure keeps the whole
tutorial readable with a retry in the image area. Only a failure to open or
plan takes the screen.

### 4.4 The geometry scrim is a sibling of the photograph, not a child

First draft passed the loading/retry affordance into `TutorialV3GuidelineView`
as an `overlayBuilder`, which the widget rendered *inside* its success path.
A selfie that failed to load therefore swallowed the retry for a guideline that
had failed for an entirely unrelated reason. The page now stacks them itself,
so the two failures stay independent. The `overlayBuilder` parameter was
removed rather than left unused.

### 4.5 The off-screen compositor left `lib/`

`renderGuidelineOverlay` — the V3-6R gate's evidence renderer — was the one
function in the app that composited the overlay *into* pixels. It is now
`test/features/tutorial_v3/tutorial_v3_overlay_compositor.dart`.

Nothing in the shipping app can reach for it any more, which is what lets the
"the tutorial UI writes nothing" contract be absolute rather than carrying a
documented exception. The gate still uses the same painter, so what it inspects
is still what a user sees.

### 4.6 Overlay style stays centralized

Every colour, opacity, stroke width and dash pattern lives in
`TutorialV3RoleStyle.byRole` in the painter. A contract test asserts no other
presentation file constructs a `TutorialV3RoleStyle`. The model supplies shape
and meaning; Flutter decides how any of it looks.

### 4.7 The target reference is the preview, unmodified

Thumbnail and expanded view both render the stored canonical preview with no
crop, filter, overlay or recolouring, and the expanded view uses
`BoxFit.contain` so nothing is cut off. MVP shows the full preview; a
category-focused crop is a later refinement and must be derived from these
pixels, never redrawn.

---

## 5. Rule compliance

| Rule | How it is met |
|---|---|
| no Guidelines ↔ Result slider | Asserted: no `Slider`, no before/after widget, no such text anywhere in `presentation/` |
| no intermediate makeup-result UI | The only two images are the untouched selfie and the canonical preview; nothing labels a per-step appearance |
| all text from persisted Step Spec | `TutorialV3StepDetails` renders `instructions.*` only; the labels are the sole strings the file contributes |
| canonical preview exact and unmodified | `PrivateImage` with `BoxFit.contain`, no crop or filter |
| dynamic total count | `state.totalSteps` from the persisted plan; tested at 2, 3 and 5 steps |
| loading/error/retry states for geometry | `TutorialV3StepGeometryPhase` → spinner scrim / retry scrim, tested end to end |
| cached geometry appears immediately | V3-7 skips the loading phase for cached geometry; the page test asserts no spinner and no retry on a ready step |
| final screen reuses premium canonical preview | `_StepImage` renders the canonical preview for the final look; no overlay, no mapping call |
| overlay style controlled centrally by Flutter | `TutorialV3RoleStyle.byRole`, asserted unique |
| original selfie never modified/overwritten | No write API anywhere in `presentation/`; asserted |
| geometry transform from V3-6R/6B | `TutorialV3GeometryTransform` unchanged; alignment pinned across sizes, aspect ratios and fits |
| target crop: full preview, no AI crop | Full preview only |

---

## 6. Tests and results

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` | — | **0 issues** |
| `flutter test` | **733** | **all pass** (was 674 after V3-7) |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 | all pass |
| `deno test .../plan-tutorial-v3/` | 38 | all pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 | all pass |
| `git diff --check` | — | clean |

### Required checklist coverage

| Required test | Where |
|---|---|
| Dynamic steps | page "a three-step plan reads STEP 1 OF 3", "a longer plan reports its own length", "the count is never hard-coded to a shorter plan" |
| Loading / error / retry | page "it shows a loading state…", "it shows a planning state…", "a tutorial-level failure offers a retry", "a mapping in flight shows progress over the photo", "a failed mapping keeps the step readable and offers retry", "retrying a failed overlay recovers it", "a signing failure offers its own retry", "retrying reloads the images" |
| Target reference | page "the canonical preview is offered on a guideline step", "it is not repeated on the final step", "it expands to a full view" |
| Geometry alignment | transform (16 tests: letterbox/pillarbox/cover/fill/alignment, point mapping invariant across four device sizes and three aspect ratios, radii, stroke scale); view "the painter receives the image's real intrinsic size", "the painter is given the same fit and alignment as the image", "the overlay stays aligned across screen sizes", "a different portrait aspect ratio is honoured" |
| Final screen | page "it shows the finished look, not a guideline", "it has no instruction blocks" |
| Previous / Next | page "Previous is disabled on the first step", "Next advances through the plan", "Previous goes back", "Next is disabled on the last step" |
| Kit / standard text | page "a standard step recommends a shade the user does not own", "a Kit step says the product is one the user owns" |
| Accessibility | page "the step position and category are headers", "the target reference is an actionable, labelled control", "a geometry failure is announced"; view "a semantic label describes the photograph" |

---

## 7. Two problems found while testing

**A real UI defect.** The geometry retry was nested inside the guideline view's
success path, so a selfie that failed to load also hid the retry for a
guideline that had failed independently — the user would have seen a broken
image icon and no way to recover either. Caught by the page tests (where the
signed URLs are unreachable and every photograph fails to decode) and fixed by
making the scrim a sibling. See §4.4.

**A test-infrastructure trap worth recording.** `ui.Image.toByteData` is real
async work and never completes inside `testWidgets`, whose clock is faked. A
helper that encoded a PNG inside a test body hung the whole file for its full
timeout. Fixtures are now encoded in `setUpAll`, and the pump helper uses
`tester.runAsync` so the codec can actually finish before the frame that
attaches the painter.

---

## 8. Risks and limitations

| # | Item | Severity | Notes |
|---|---|---|---|
| 1 | **Exposed legacy `service_role` credential** | **HIGH — UNRESOLVED** | Carried forward from V3-6A.2. Not touched in this phase. **Release is blocked until it is rotated/revoked outside Claude Code.** |
| 2 | The screen is not routed yet | Expected | No `GoRoute` was added. Reaching the tutorial requires resolving analysis + recommendation + canonical preview server-side, which is V3-10's stated goal. A route added now would open a page permanently stuck in `idle`. |
| 3 | Alignment is verified in widget tests, not on a device | Medium | The transform is pinned mathematically across four device sizes, three aspect ratios and four fits, and the painter is verified to receive the real intrinsic size. Actual on-device rendering — including selfie orientation and any front-camera mirroring — is V3-11's device QA. |
| 4 | Migration `20260828000100` unapplied; mapper function undeployed | Expected | V3-6B risks 2 and 3, unchanged. The screen has never displayed a real mapped guideline. |
| 5 | `loadImages` costs one extra query per open | Low | `analyses.original_image_path` is not on the session row. Denormalising it would have meant editing an applied migration. |
| 6 | Target reference is the full preview | By design | Category-focused crops are explicitly out of MVP scope and must never be model-generated. |

---

## 9. Security impact

- **No new outbound calls and no new trust surface.** The screen reads state
  from the V3-7 controller and displays it.
- **The selfie path is server-resolved.** `loadImages` reads
  `analyses.original_image_path` for the session's own analysis under RLS; the
  caller never supplies a path, so a tutorial cannot be pointed at another
  photograph, and another user's analysis is invisible rather than forbidden.
- **Signed URLs only.** Both images are short-lived signed URLs over the
  private bucket. No public URL, no storage-policy change.
- **Nothing is written.** No upload, no file write, no byte encoding anywhere
  in `presentation/` — now asserted, and enforceable because the one
  compositing function left `lib/` entirely.
- **No model is contacted from the UI.** Asserted: no `gemini`,
  `generateContent` or `prompt` anywhere in the presentation layer.
- No RLS change, no migration, no deployment, no secret read or mutated.

---

## 10. Acceptance status

| Criterion | Status |
|---|---|
| Required layout implemented | Met |
| No slider, no intermediate makeup-result UI | Met |
| All text from the persisted Step Spec | Met |
| Canonical preview exact and unmodified | Met |
| Dynamic total count | Met |
| Loading / error / retry for geometry | Met |
| Cached geometry appears immediately | Met |
| Final screen reuses the premium canonical preview | Met |
| Overlay style controlled centrally by Flutter | Met |
| Original selfie never modified or overwritten | Met |
| V3-6R/6B image-space transform used, alignment verified | Met |
| Full canonical preview as target, no AI crop | Met |
| Required tests written and passing | Met |

**V3-8 is complete. STOPPING HERE. V3-9 is not authorized and has not been started.**
