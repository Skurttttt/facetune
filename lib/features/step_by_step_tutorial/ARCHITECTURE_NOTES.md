# Step-by-Step Tutorial — Architecture Notes

Written during ST-1. Records decisions later ST phases must respect or
explicitly revisit. Source of truth for product behavior remains
`FACETUNE_STEP_BY_STEP_TUTORIAL_GUIDE.md`; this file only covers
implementation choices not dictated by that document.

## Module boundary

**As of ST-3**: `domain/`, `data/` (models, data_sources, repositories,
providers), and `presentation/controllers/` all exist. There is still no
`presentation/pages|widgets/` — no route, button, or screen exists yet, and
`CODEX_MASTER_GUIDE.md` §20 explicitly forbids empty folders created to
imitate architecture. `tutorialRepositoryProvider` now resolves to a real
`SupabaseTutorialRepository` (gated on `supabaseAvailableProvider`, falling
back to `UnavailableTutorialRepository`), exactly the pattern ST-1's doc
comment asked the future phase to switch to. ST-1's
`UnimplementedTutorialRepository` ("no implementation exists yet") has been
deleted — it is superseded, not merely deprecated.

Nothing calls `TutorialRepository.createSession` / `createStep` /
`updateStepImages` / `updateStepStatus` anywhere in the app yet.
`TutorialSessionController` only calls `loadExisting` (read-only). See the
ST-3 section below for why.

## Category vocabulary is not shared across sources

Standard recommendations key items on camelCase strings (`highlight`,
`contour`, `lipGloss` — see `makeup_recommendation_dto.dart`). My Makeup Kit
selections key on `MakeupKitCategory.code`, which differs in three places
(`highlighter`, `contour_bronzer`, `lip_gloss`). `TutorialStepCategory` is a
third, canonical vocabulary — it is not a re-export of either. Whichever
phase builds the planning engine (turns a recommendation or kit result into
an ordered list of `TutorialStep`s) must write an explicit mapping from both
source vocabularies into `TutorialStepCategory`. Do not assume string
equality will work.

## Placement image reuse (cost strategy)

Per guide §4.1, a step's placement image is the *previous* step's result
image plus overlay metadata — not a separate AI generation.
`TutorialStep.placementImagePath` / `placementImageUrl` are therefore
expected to hold a copy of the prior step's `resultImagePath` /
`resultImageUrl` (null only for step 1). Whatever writes these fields must
preserve that reuse; do not let the persistence layer independently generate
or fetch a placement image.

## Placement overlays use normalized coordinates

`TutorialPlacementPoint` is `0.0`–`1.0`, not pixels. The guide notes the
tutorial image size is configurable and may move from 512px to 1K without
restructuring the feature (§5.2); pixel coordinates would break that
promise, so overlays must stay resolution-independent.

## Session/step generation status are intentionally different shapes

`TutorialGenerationStatus` (session) has `planning`/`queued` states that
`TutorialStepGenerationStatus` (step) does not, because planning happens
once per session before any step generation starts. Do not collapse these
into one enum — the guide (§14) asks for progressive loading and per-step
retry, which needs the step-level status to move independently of the
session-level status.

## Server-side model/size configuration stays server-side

`TutorialSession.tutorialModel` / `tutorialImageSize` and the matching
per-step fields on `TutorialStep` are for **display/debugging only** — they
echo whatever the Edge Function actually used. Client code must never read
them as configuration. This follows the existing precedent in
`generate-makeup-preview/index.ts`, which reads `GEMINI_IMAGE_MODEL` from
`Deno.env` with a hardcoded fallback rather than accepting a model name from
the client. The roadmap's strict engineering rule ("the tutorial
image-generation model and output resolution must be configurable
server-side and must not be tightly coupled to tutorial business logic or
UI") applies to whatever env vars/config table ST-2 or later introduces, not
to these Flutter-side fields.

## Comparison slider reuse

**As of ST-5**: implemented. The drag/tap-reveal mechanic was extracted
from `BeforeAfterComparison` into `shared/widgets/media/comparison_slider.dart`
(`ComparisonSlider`), parameterized on `leftImageUrl`/`rightImageUrl`/
`leftLabel`/`rightLabel`/`leftSemanticLabel`/`rightSemanticLabel`/
`semanticsLabel`. `BeforeAfterComparison` is now a thin `StatelessWidget`
wrapper passing its original hardcoded values (`Before`/`After`,
`Original selfie`/`Generated makeup preview`) — its public constructor,
external behavior, and every existing call site
(`preview_result_page.dart`, `makeup_kit_recommendation_entry_page.dart`)
are byte-for-byte unchanged. `PlacementResultComparison`
(`step_by_step_tutorial/presentation/widgets/`) is the tutorial's thin
wrapper, passing `Placement`/`Result`. Placed under `shared/widgets/media/`
(next to `PrivateImage`, which it already depended on) rather than left in
`results/`, since it is no longer results-specific — this mirrors
`CODEX_MASTER_GUIDE.md` §20's `shared/widgets/` role and was exported
through `shared/widgets/app_ui.dart` alongside `PrivateImage`/`BeautyImage`.

## "How to Apply This Look" entry points

**As of ST-4**: wired. `HowToApplyLookButton` was added to both
`PreviewResultPage._ResultDetails` (after `ResultActions`) and
`MakeupKitRecommendationEntryPage._KitPreviewContent` (after "Generate
another variation"). See the ST-4 section below for why this covers Saved
Looks and History too without a third integration point.

## Storage/signed URL convention

Settled by ST-2's schema (`supabase/migrations/20260814000300_tutorial_sessions_steps.sql`):
tutorial images live in the existing private `face-images` bucket at
`{userId}/analyses/{analysisId}/tutorials/{tutorialSessionId}/step_{NNNN}_result.{ext}`,
nested under the existing per-analysis prefix so the existing
`storage.objects` RLS policies and `delete-history-item`'s recursive
per-analysis sweep already cover it with no changes. `TutorialRemoteDataSource.createSignedUrl`
(ST-3) calls `client.storage.from('face-images').createSignedUrl(path, 3600)`,
matching `preview_remote_data_source.dart` exactly. Still not implemented:
whatever actually uploads a result image — that requires an Edge Function
(a later phase; see below).

## AI quota

Settled by ST-2: `consume_ai_quota` and `ai_usage_events_operation_valid`
now include a `tutorial_step` operation (80/hour, 400/day — a starting
guess, not a measured value). No code calls `consume_ai_quota('tutorial_step')`
yet, because nothing calls Gemini yet (ST-3 explicitly excludes this).

## Edge Function conventions for the phase that adds generation

Not implemented here — ST-3 is explicitly forbidden from calling Gemini.
Whichever phase adds tutorial generation should follow
`generate-makeup-preview/index.ts`'s pattern: kebab-case function name,
shared `FunctionFailure` type, bearer-token auth via `client.auth.getUser()`,
composite-FK ownership checks, and the `[PhaseN]`/timing log conventions
already in place. It should call `TutorialRepository.createStep` /
`updateStepImages` / `updateStepStatus` (ST-3) to persist its work rather
than inventing new persistence — those methods exist for exactly this.

## ST-3: repository shape, ownership boundary, and controller scope

`TutorialRepository` (revised from ST-1's provisional version now that the
schema exists) has seven methods: `loadExisting`, `createSession`,
`loadSteps`, `createStep`, `updateStepImages`, `updateSessionStatus`,
`updateStepStatus`. None call Gemini or an Edge Function — every one is
Postgrest CRUD against `tutorial_sessions`/`tutorial_steps` via
`TutorialRemoteDataSource`, matching the direct-table-access pattern used by
`SavedLooksRemoteDataSource` / `MakeupKitProductsRemoteDataSource` (as
opposed to the Edge-Function-invocation pattern used by
`PreviewRemoteDataSource`, which exists because preview generation calls
Gemini and this doesn't).

**Ownership**: no `TutorialRepository` method accepts a `userId` parameter.
`SupabaseTutorialRepository._ownerId()` derives it from
`TutorialRemoteDataSource.currentUserId` (i.e. the authenticated session),
never from a caller-supplied value — matching
`SupabaseSavedLooksRepository.save`. Row Level Security enforces the same
rule again, server-side, regardless of what the app sends.

**Snapshot semantics carried through**: `TutorialStepDto` serializes
`TutorialInstruction` into `tutorial_steps.instruction_json` as a plain
JSONB object, not a live reference to `makeup_kit_products` — this is the
Dart-side half of the snapshot guarantee ST-2's schema comment documents.

**Controller scope is deliberately narrow**: `TutorialSessionController`
only calls `loadExisting`. It does not call `createSession` or any
step-mutating method, and it is not referenced by any route or widget. Task
8 of ST-3 ("do not expose unfinished tutorial UI as if generation already
works") is satisfied by this being unreachable from the app, not by a
feature flag — there is nothing to flag off yet. The six controller states
(`initial`/`loading`/`loaded`/`generating`/`partiallyComplete`/`failed`) are
a direct translation of `TutorialSession.generationStatus` via
`TutorialSessionState.statusFor` — the controller does not invent its own
independent state machine, so a session written by some future
generation-orchestrating phase is immediately representable here without
this file changing.

## ST-4: entry points cover Saved Looks/History without a third integration point

Saved Looks and History have no separate "detail" screen. Opening a card in
either one (`SavedLooksPage._openResult`/`_openKit`,
`HistoryPage._open`/`_openKit`) works by calling `.restore(...)` on the same
ambient controllers the live wizard flow uses
(`faceAnalysisControllerProvider`, `makeupRecommendationControllerProvider`
or `makeupKitLookControllerProvider`, `makeupPreviewControllerProvider`),
then pushing the *same* `previewRoute` / `makeupKitRecommendationEntryRoute`
the wizard itself pushes. So by the time a user reaches
`PreviewResultPage`/`MakeupKitRecommendationEntryPage` — whether from the
live wizard, a saved look, or a history entry — the ambient controllers are
already correctly populated. One button in each of those two pages
therefore reaches all four surfaces the task asked for; adding separate
buttons to `SavedLookCard`/`KitSavedLookCard`/`HistoryCard`/`KitHistoryCard`
would have been redundant navigation, not better coverage.

**How IDs are passed** ("stable IDs, not raw state blobs" — task 4): no
route param or `extra` was introduced — that would be a new pattern nothing
else in this router uses (checked: no route in `app_router.dart` passes
`extra` today). Instead, each button's `onPressed` calls
`tutorialSessionControllerProvider.notifier.load(sourceMode: ..., analysisId:
..., recommendationId/kitRecommendationId: ..., generationNumber: ...)` —
reading only scalar `.id`/`.generationNumber` fields off the
already-in-scope domain objects — *before* calling `context.push(AppConstants.tutorialRoute)`.
This is the same "restore ambient state, then navigate" shape as
`HistoryPage._regenerate`. `TutorialEntryPage` itself never re-derives which
look it's for; it only renders whatever `tutorialSessionControllerProvider`
reports.

**Graceful unavailable-context handling** (task 5): if `/tutorial` is ever
reached without a prior `load()` call (e.g. an unexpected direct
navigation), the controller is still in its default `initial` state, and
`TutorialEntryPage` shows "Tutorial unavailable — we could not identify
which look to build a tutorial for" with a Return action, rather than
hanging on a spinner or crashing.

**Honesty about generation** (task 6, and the same principle ST-3 task 8
established): `TutorialEntryPage` never claims a tutorial is being built or
viewable when it isn't. A `loaded` result with `session == null` (the only
real outcome today, since nothing anywhere calls `createSession`) renders
as "Coming soon." As of ST-5, a session that *does* have generated steps
opens the real `TutorialStepViewer` — see the ST-5 section below for why
that is still honest and not "exposing unfinished UI."

**Not touched**: `before_after_comparison.dart`'s public behavior (task 7 —
see the Comparison slider reuse section for what did change underneath it),
`ResultActions` (the shared fixed-shape widget backing
`result_actions_widget_test.dart` — the new button is a sibling rendered
next to it, not a change to it), and no existing navigation call site was
modified — only new calls were added.

## ST-5: the viewer opens on real data only, which today means it never opens

`TutorialStepViewer` (`step_by_step_tutorial/presentation/widgets/`) renders
directly from `TutorialSession`/`TutorialStep` — the same domain types
ST-1–3 defined and ST-3's repository already persists/loads. Nothing about
it is a mock or a fixture; the "safe placeholder/domain data only"
instruction in the ST-5 prompt is satisfied by testing it with constructed
`TutorialStep` fixtures (see `tutorial_step_viewer_test.dart`), not by
having the running app show fabricated content. Because nothing anywhere in
the app calls `TutorialRepository.createSession`/`createStep` (ST-3's
scope explicitly excluded this, and no later phase has added it yet), the
viewer is unreachable in a real run today — `TutorialEntryPage` always
lands on "Coming soon" in practice. The moment a future phase's generation
pipeline persists a real session with steps, this UI renders it correctly
with zero changes needed here.

**Progressive loading, not "wait for 100%"**: `TutorialEntryPage` opens the
viewer whenever `session.steps.isNotEmpty`, regardless of whether the whole
session has finished (`loaded`/`partiallyComplete`/`generating`-with-some-
steps all qualify). This directly follows the guide's progressive-loading
intent (§14) and re-uses the exact same session data already threaded
through by ST-3/ST-4 rather than introducing a second data path.

**Dynamic step count** (task 5): `_Header` derives its step count from
`session.totalSteps` (falling back to `session.steps.length` only if
`totalSteps` is somehow `0`), and `TutorialStepViewer`'s Previous/Next
bounds navigation by `session.steps.length` — the actual number of
persisted steps, which may be fewer than `totalSteps` for a
still-generating session. Nothing hardcodes a step count anywhere.

**Per-step missing images**: a step's `placementImageUrl`/`resultImageUrl`
are nullable on the domain type (ST-1) because a step can exist before its
image finishes generating. `TutorialStepViewer` checks both are non-null
before rendering `PlacementResultComparison`; if either is missing it shows
"Step still generating" instead of crashing on a null `!`.

**Not touched**: `MakeupBreakdown`/`RecommendedPalette`/`KitResultProductCard`
(the existing result-detail widgets `TutorialInstructionCard` is styled
to match, not replacing or importing from). `ComparisonSlider`'s extraction
is the only change to previously-existing preview-rendering code, and it is
behavior-preserving (see above).

## ST-6: overlay coordinates are illustrative, not measured

**Read this before trusting the catalog's numbers for anything beyond a
rough visual guide.** `TutorialPlacementOverlayCatalog` (domain/catalog/)
provides default, category-typical overlay shapes for every
`TutorialStepCategory` except `finalLook`. The coordinates are
hand-authored approximations for a roughly front-facing, centered portrait
— **not** derived from any real face landmark data, because this app has
none: Gemini's face analysis (CODEX_MASTER_GUIDE.md §8) returns categorical
attributes (face shape, skin tone, undertone, ...), not per-pixel or
normalized landmark coordinates. The catalog exists so the viewer has
*some* honest, conservative guidance today rather than nothing; a future
phase with a real landmark source should replace it with precise,
per-user coordinates. Right now it is the only source `TutorialStepViewer`
falls back to when a step's own `placementMetadata` is null — which, since
no planning engine persists real per-step overlay data yet, means it is
what every step will show if the viewer is ever reached.

**Rendering approach**: `TutorialPlacementOverlayLayer`
(`presentation/widgets/`) is a `CustomPainter` that maps each overlay's
normalized `0.0`–`1.0` points to the actual displayed box size at paint
time (via `LayoutBuilder` → `CustomPaint.size`), never reading a fixed
pixel value from the domain data. Five primitives cover every category:
`zone` (one point → soft circle, two points → rounded capsule, three+ →
filled polygon), `boundary` (stroked closed polygon, e.g. lip outline),
`line` (stroked open polyline, e.g. lash line), `arrow` (a stroked segment
plus a small triangular head, e.g. blend direction), and `dot` (small
filled circles, e.g. highlighter points). `label` (a 6th type inherited
from ST-1's domain enum but not in ST-6's own primitive list) renders as a
small text chip so it degrades gracefully rather than being unhandled.
Colors default to a translucent rose (zones) or white (strokes/dots) for
legibility against varied skin tones, overridable per-overlay via
`colorHex`.

**Integration**: `ComparisonSlider` (shared/widgets/media/) gained one new
optional parameter, `leftOverlay`, stacked *inside* the same reveal
`ClipRect` as the left image — so the overlay reveals/clips in sync with
the Placement image as the user drags, rather than staying fixed.
`BeforeAfterComparison` never passes it (stays `null`, unchanged
behavior); `PlacementResultComparison` passes a
`TutorialPlacementOverlayLayer` built from its `placementMetadata`
parameter.

**Placement source rule** (task 8): `TutorialPlacementSourceResolver`
(domain/services/) is a pure function encoding "step 1 reuses the original
selfie; step N reuses step N-1's result" — not wired to anything yet,
since nothing generates steps. It exists so the phase that eventually
writes `tutorial_steps.placement_image_path` (see `TutorialRepository.createStep`,
ST-3) has one correct, tested place to get that path from instead of
re-deriving the rule inline.

## ST-7: planning is pure, reads only the two source objects it's given, and does not persist

`TutorialPlanningEngine` (domain/services/) has two entry points,
`planFromRecommendation` and `planFromKitRecommendation`, each taking the
already-generated recommendation plus its matching preview and returning a
`TutorialPlan` (domain/entities/tutorial_plan.dart — `PlannedTutorialStep`
+ `TutorialPlan`, both new, deliberately distinct from the persisted
`TutorialStep`/`TutorialSession` types since they exist *before* any row
is written). Nothing about this class is async, and nothing calls
`TutorialRepository`, an Edge Function, or Gemini — it is pure input →
output, which is what makes it fully unit-testable without mocks (see
`tutorial_planning_engine_test.dart`, 12 tests). ST-8 ("Tutorial
Persistence, Cache & Duplicate Prevention") is expected to be the caller
that turns a `TutorialPlan` into real `createSession`/`createStep` calls;
this phase deliberately stops at producing the plan.

**Category vocabulary reconciliation, finally implemented**: ST-1 flagged
that standard recommendation keys (`highlight`, `contour`, `lipGloss`,
camelCase) and `MakeupKitCategory.code` (`highlighter`, `contour_bronzer`,
`lip_gloss`, snake_case) disagree with each other and with
`TutorialStepCategory.code`. `_recommendationKeyToCategory` and
`_kitCategoryToTutorialCategory` are the two explicit mapping tables that
resolve this — deliberately two separate maps, not one, because the two
input vocabularies are different string sets pointing at the same output
enum, and conflating them into a single lookup would let one source's
casing accidentally match the other's.

**Standard-mode exclusion is real code with no real trigger yet**: every
recommendation the current Edge Function returns fills all ten category
keys (`makeup_recommendation_dto.dart` parses all ten unconditionally,
required), so `_notApplicableIntensities` (an item whose `intensity` is an
explicit "none"/"skip"/"n/a"/empty sentinel is excluded) has no live data
to ever actually trigger today. It is still real, tested logic — task 7
("do not force every tutorial to have the same number of steps") requires
the *capability* to exclude, and this is the honest, non-speculative way
to provide it without guessing at a backend contract that doesn't exist
yet. If the Edge Function is ever changed to omit or null out a
style-inappropriate category, this already handles it; until then, a
standard-mode plan will in practice always be 10 steps + 1 final step.

**Kit-mode inclusion needs no such rule**: `recommendation.selections` is
already exactly the sparse set of categories the kit-recommendation Edge
Function chose from the user's owned inventory (guide §11) — the planner
trusts that completely and produces one step per selection, no filtering
logic needed. This is also what keeps snapshot semantics intact: the
planner reads only `selections`/`productSnapshots` (both already frozen at
generation time per `kit_makeup_recommendations.product_snapshot_json`),
never `makeup_kit_products` (live, editable inventory) — see the class
doc comment on `TutorialPlanningEngine` for the full reasoning.

**Ordering** (task 8): `_canonicalOrder` is one fixed 10-category list
(foundation → concealer → contour → blush → highlighter → eyebrow →
eyeshadow → eyeliner → lipstick → lip gloss, matching guide §9's Full Glam
example), shared by both modes. Both planning paths build an unordered
`Map<TutorialStepCategory, TutorialInstruction>` first, then filter
`_canonicalOrder` down to the keys present — so omission is just "not in
the map," never a separate branch, and order is never a function of
selection/map iteration order (Dart `Map`/`List` iteration order is
insertion order, which the test suite deliberately scrambles to prove the
output doesn't depend on it).

**Final-preview reuse decision** (task 3's last bullet): `reusesFinalPreview`
is `true` whenever at least one category step exists — the final step's
`reusableResultImagePath`/`reusableResultImageUrl` are set to the passed-in
preview's own paths, meaning a future generation phase should skip
calling Gemini for that one step and just persist a reference to what
already exists. It is `false` only for the degenerate case of zero
applicable categories (nothing to show a "final look" of) — not reachable
by kit mode today (an empty-selections kit recommendation isn't a state
the kit Edge Function produces), but reachable by standard mode once the
exclusion rule above has real data to act on. Both cases are tested.

## Frozen systems reminder

Face Analysis, Makeup Recommendation, the existing final preview's
Edge Function/generation logic, My Makeup Kit's generation logic, Saved
Looks, and History remain untouched by ST-1–ST-7. Existing presentation
files were touched only additively:
- ST-4: `preview_result_page.dart`, `makeup_kit_recommendation_entry_page.dart`,
  `app_constants.dart`, `app_router.dart` — each edit adds a new optional
  callback/widget/route rather than changing existing behavior.
- ST-5: `before_after_comparison.dart` was rewritten internally to delegate
  to the new shared `ComparisonSlider`, but its public constructor,
  rendered labels, and behavior are unchanged (see the Comparison slider
  reuse section) — verified by re-running every test that exercises it
  transitively (no dedicated test existed before this phase; none broke).
  `shared/widgets/app_ui.dart` gained one export line.
- ST-6: `ComparisonSlider` gained one optional parameter (`leftOverlay`,
  default `null`) — `BeforeAfterComparison` never sets it, so its behavior
  is unchanged.
- ST-7: no existing file modified at all — every file this phase touched
  is new (`domain/entities/tutorial_plan.dart`,
  `domain/services/tutorial_planning_engine.dart`, and their tests).

All other new files are additive under `lib/features/step_by_step_tutorial/`,
`shared/widgets/media/`, and `supabase/migrations/`.
