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

## ST-8: the first phase where tapping the button actually writes rows

Every prior phase was safe to ship without touching real data — ST-8 is
the first one where `TutorialRepository.createSession`/`createStep` are
finally called from somewhere real. Get the boundaries here right; this is
the highest-consequence phase in the roadmap so far.

**Two-step controller API, not one** (task 7 — "regeneration must be an
explicit user action"): `TutorialSessionController.prepareForRecommendation`/
`prepareForKitRecommendation` (called by the two result pages right before
navigating) only *check* for an existing session — they never create one.
Creation only happens from `generate()`, wired to nothing but an explicit
"Generate my tutorial" tap in `TutorialEntryPage`. Splitting these was a
deliberate response to a bug caught during this phase's own testing (see
next point), not the original design.

**`retry()` replays what actually ran, not what might run next** — a bug
caught before it shipped. The first draft had `prepareForRecommendation`
set the *same* field `retry()` reads to the create-closure, meaning: if the
initial existence *check* failed (e.g. a network blip) and the user tapped
"Try again," `retry()` would have silently run the *create* flow instead
of re-checking — turning a failed read into an unrequested write. Fixed by
splitting `_pendingGenerate` (what `generate()` will run, set only by
`prepareFor*`) from `_lastRun` (what `_run()` actually executed, set
*inside* `_run()` itself, replayed by `retry()`). If `generate()` itself
fails partway, `retry()` correctly re-runs `generate()` — which is safe
because `GetOrCreateTutorialSession` starts every attempt with its own
existing-session check (see below), so a retried create never double-
creates whatever the failed attempt already managed to persist.

**Three layers of duplicate prevention** (task 5), each catching what the
one before it misses:
1. `TutorialSessionController._run` refuses to start a second operation
   while one is already `loading` — blocks a double-tap before any network
   call happens. Tested by asserting the repository's check method is only
   invoked once even when two `prepareForRecommendation` calls overlap.
2. `GetOrCreateTutorialSession._getOrCreate` always calls `loadExisting`
   before ever calling `createSession` — blocks the "user re-opens the
   same look on two separate app visits" case.
3. The database itself: ST-2's partial unique indexes on
   `(recommendation_id, generation_number)` /
   `(kit_recommendation_id, generation_number)` are the backstop for
   anything layers 1–2 can't see — concurrent requests from two different
   devices/sessions, which never share in-memory state. When Postgres
   rejects the losing insert with error 23505,
   `SupabaseTutorialRepository.createSession` now catches it specifically
   (`technicalCode: 'duplicate_session'`, distinct from its generic
   failure mapping) and `GetOrCreateTutorialSession` responds by re-fetching
   via `loadExisting` instead of surfacing an error — the "loser" ends up
   returning the exact session the "winner" created, and critically never
   calls `createStep`, so there is no risk of two step sets existing for
   one session. This mirrors `SupabaseSavedLooksRepository.save`'s
   existing 23505-handling pattern exactly; nothing new was invented here.

**Model/prompt-version snapshots, honestly** (task 6): `tutorial_sessions.prompt_version`
is now populated — with `TutorialPlanningEngine.planVersion`
(`'tutorial_plan_v1'`), which versions the *planning algorithm* (category
set, ordering, exclusion rule), not a Gemini prompt, because no Gemini call
happens in this phase. `tutorial_sessions.tutorial_model`/`tutorial_image_size`
stay `null` — deliberately not backfilled with the guide's `gemini-3.1-flash-image`/`512`
figures, because nothing in this phase or ST-7 actually calls that model;
writing it now would be recording a claim before the fact, which is exactly
the kind of fabrication CODEX_MASTER_GUIDE.md warns against. The one step
that *does* get real model/prompt-version data is the reused final step —
`tutorial_steps.model_name`/`prompt_version` are set from the **source
preview's own** `modelId`/`promptVersion` (`PlannedTutorialStep.reusableModelId`/
`reusablePromptVersion`, added to ST-7's output type in this phase), which
is accurate because that image really was generated by that model/prompt.

**Snapshot semantics, still preserved**: `GetOrCreateTutorialSession` reads
only the `MakeupRecommendation`/`KitMakeupRecommendation` + preview objects
it's given — nothing new queries live inventory or re-runs analysis. This
phase doesn't touch that guarantee; it just finally *uses* the planner
that already respected it (ST-7).

**Source invalidation** (task 4's last bullet): not implemented as new
code, and deliberately so — it's already structurally impossible for a
stale session to survive its source's deletion, because ST-2's
`tutorial_sessions` rows carry `on delete cascade` foreign keys to
`analyses`/`recommendations`/`kit_makeup_recommendations`. A regenerated
preview (new `generation_number`) also can't accidentally reopen an old
session, because the lookup key includes `generation_number` — a new
preview generation is a new lookup key, so `loadExisting` correctly
reports "none yet" rather than returning a stale match. No additional
invalidation logic was needed because the schema already prevents the
invalid states task 4 is asking about.

**Still true after this phase**: no Gemini call anywhere (task 8). A
freshly created session's non-final steps have real instruction/placement
data (from ST-7's planner) but `result_image_path = null` and
`generation_status = 'not_started'` — genuinely incomplete, waiting for
ST-9. `TutorialStepViewer` (ST-5) already shows "Step still generating"
for exactly this case, so no UI change was needed here either.

## ST-9: the Edge Function, and what it deliberately does not attempt

`supabase/functions/generate-tutorial-step/` is a new, self-contained Edge
Function following `generate-makeup-preview`'s file split
(`index.ts`/`gemini_client.ts`/`prompt.ts`/`types.ts`/`image_validation.ts`)
almost exactly, including its retry/timeout budget constants
(`attemptTimeoutMs`/`totalBudgetMs`/`maximumAttempts`) verbatim — task 11
asked for behavior "consistent with current project standards," and the
most consistent choice was reusing the numbers already in production
rather than inventing new ones with no evidence behind them. `types.ts`/
`image_validation.ts` are duplicated rather than imported cross-function —
see the inline comment on why: `generate-kit-makeup-preview` cross-imports
`extensionFor` from `generate-makeup-preview` because that function never
throws, but `validateGeneratedImage` *does* throw `FunctionFailure`, and a
cross-imported throw would be a different class than this function's own
`FunctionFailure`, so `error instanceof FunctionFailure` would silently
fail to match. Not a hypothetical — this was caught while designing the
file, not left as a landmine.

**Response shape is a raw table row, on purpose**: `{ step: <raw
tutorial_steps row> }`, snake_case columns included, not a client-shaped
envelope like `generate-makeup-preview`'s `{ preview: { id, analysisId,
... } }`. This is deliberate so that ST-10 (Flutter wiring) can parse the
response with `TutorialStepDto.fromRow(response['step'])` — the exact same
parser `SupabaseTutorialRepository` already uses for Postgrest rows — with
zero new DTO code. Do not "improve" this into a camelCase envelope without
updating that plan; it would silently reintroduce a second parsing path
for the same shape ST-3 already solved once.

**Duplicate-generation protection goes further than "check first"**
(task 12): the obvious guard — return early if `result_image_path` is
already set — only prevents *sequential* duplicate calls. A genuine
concurrent race (two rapid taps, or a client retry racing its own timeout)
could still pass that check twice before either write lands. The function
also does a conditional claim: `UPDATE tutorial_steps SET generation_status
= 'generating' WHERE id = :id AND generation_status IN ('not_started',
'failed')`. Only the request whose `UPDATE` actually matches a row
proceeds to call Gemini; a request that finds zero rows matched (because
another request already claimed it) re-fetches and either returns the
now-existing result or reports `GENERATION_IN_PROGRESS` (409, retryable).
Including `'failed'` in the claimable set is what makes a retry after a
genuine failure possible — excluding it would have permanently locked out
retries the first time this function itself set a step to `failed`.

**Known gap in the claim mechanism, stated plainly**: if a request crashes
between claiming a step (`generating`) and either completing or reaching
the `catch` block (Edge Function process killed, not a normal thrown
error), that step is stuck at `generation_status = 'generating'` forever —
the claim's `IN ('not_started', 'failed')` filter can never match it
again. No time-based reclaim (e.g. "steal a claim older than N minutes")
was implemented. This is a real limitation of this phase, not an oversight
being hidden — a normal failure (Gemini error, storage error, validation
error) *is* handled, via the `catch` block's best-effort `generation_status
= 'failed'` update, which makes the step claimable again immediately.

**Cumulative source + identity anchor** (task 8): step 1 sends Gemini one
reference image (the original selfie). Step N>1 sends **two**: the
original selfie first (identity anchor) and step N-1's own Result second
(the cumulative state to build on) — both as separate `inlineData` parts
in the same request, which the Gemini API supports. `prompt.ts` describes
both images explicitly so the model knows which is which, and instructs
it to preserve the makeup shown in the second image while using the first
only to resist identity drift. This is a materially different (and more
faithful to task 8's wording) design than just chaining Result→Result
images alone, which would compound drift with no anchor across many steps.

**Output size is recorded, not enforced** — an honest limitation, not a
gap I'm hiding. `TUTORIAL_IMAGE_SIZE` (default `512`, guide §5.2) is read,
persisted to `tutorial_steps.image_size`, and available to a future prompt
revision, but no `generationConfig`-style API parameter is sent to Gemini
to actually constrain output resolution — this codebase has no verified
example of that parameter's name/shape for this model, and guessing one
risks either silently doing nothing or a hard 400 from Gemini. Fabricating
an unverified API parameter would violate the roadmap's explicit
"do not fabricate" instruction more than declining to include it does.
Whoever wires real traffic through this function should confirm the
correct parameter (or that prompt-text guidance is what this model
actually responds to) against current Gemini API documentation before
assuming resolution is controlled today.

**Not implemented, matching task 8/14's own scope**: `TUTORIAL_IMAGE_MODEL`/
`TUTORIAL_IMAGE_SIZE` are new, tutorial-specific env vars — deliberately
*not* reusing `GEMINI_IMAGE_MODEL` (which `generate-makeup-preview` and
`generate-kit-makeup-preview` already read), so an operator can tune the
tutorial's cost/quality independently of the two preview functions.
`generate-makeup-preview/index.ts` and `generate-kit-makeup-preview/index.ts`
are untouched — not one line — satisfying task 14.

## ST-10: Flutter generation orchestration and progressive loading

Wires the Flutter side to the `generate-tutorial-step` Edge Function
(ST-9) for the first time — before this phase, nothing in the app ever
called it. Four layers, each additive to what already existed:

1. `TutorialRemoteDataSource.invoke({required tutorialStepId})` +
   `TutorialRemoteFailure` (`data/data_sources/tutorial_remote_data_source.dart`),
   copied from `PreviewRemoteDataSource.invoke`/`PreviewRemoteFailure`
   field-for-field — same `FunctionException` unwrapping, same
   `{error: {code, message, retryable}}` payload shape, because ST-9's
   `index.ts` returns exactly that shape on failure.
2. `TutorialStepDto.fromResponse(payload)` unwraps the `{step: <row>}`
   envelope and delegates straight to `fromRow` — this is the "zero new
   DTO code" reuse ST-9's notes explicitly asked the next phase to honor;
   there is no second parser for the same row shape.
3. `TutorialRepository.generateStepResult({required tutorialStepId})`,
   implemented in `SupabaseTutorialRepository` as invoke → parse →
   `_hydrateStep` (the same signed-URL hydration every other repository
   method already uses, so this phase does not introduce a second
   signed-URL convention). `UnavailableTutorialRepository` throws the
   same "Supabase runtime configuration is unavailable" failure as every
   other method on that class.
4. `TutorialSessionController.generateStep(tutorialStepId)` — a new
   operation alongside `prepareFor*`/`generate`/`retry`, sharing the same
   `_operationEpoch` counter (so a session reload correctly invalidates a
   stale in-flight step generation, and vice versa) but *not* going
   through `_run`/`_lastRun`: it deliberately does not become what
   `retry()` replays, because `retry()`'s contract (see ST-8's notes) is
   "repeat the session-level check/create," and conflating a per-step
   retry into that would resurrect the exact bug ST-8 fixed. Per-step
   retry is just "tap the button again," calling `generateStep` directly.

**Why per-step generation state is not `TutorialSessionStatus.loading`**
(tasks 4/8/9): reusing the existing whole-page loading status for a
single step's generation would replace the entire viewer with a spinner,
blocking the Previous/Next navigation through already-available steps
that task 8 explicitly asks for. Instead `TutorialSessionState` gained
three new, independent fields — `generatingStepId`, `stepFailureStepId`,
`stepFailureMessage`/`stepFailureRetryable` — so the viewer can keep
rendering the rest of the session normally while one step's area alone
shows generating/failed.

**Client-side ordering mirrors the server's, so failures are rare, not
just handled** (task 9): `generate-tutorial-step` rejects out-of-order
generation with `PREVIOUS_STEP_NOT_READY` (409). Rather than only
handling that error after the fact, `TutorialStepViewer` computes
`firstMissingIndex` (the earliest step without a `resultImageUrl`) and
only offers "Generate this step" when the currently-viewed step *is*
that one; every step after it shows a calm "Not yet available" with no
action, instead of a button that would just 409. The 409 path is still
handled (surfaces as a normal per-step failure) for the case where
another client/tab raced ahead in the meantime.

**Never regenerate an already-valid step** (task 3), enforced twice:
`generateStep` no-ops client-side if the target step already has a
`resultImageUrl` (avoiding the network round-trip), and independently
`generate-tutorial-step` itself already no-ops server-side and safely
(no Gemini call, no quota spent) if `result_image_path` is already set —
this phase's client-side check is a cost optimization layered on an
already-safe backend, not a correctness requirement plugging a hole.

**Merging a generated step back into the session does not reload it**
(deliberate scope limit, not an oversight): `generateStep` splices the
one updated `TutorialStep` the Edge Function returned into the session
snapshot already held in `TutorialSessionState`, rather than calling
`loadExisting` again for a fully fresh session. This means
`TutorialSession.generationStatus` (e.g. the transition to
`partially_complete`/`completed` that ST-9's server-side rollup makes)
can go briefly stale in memory until the next full
`prepareForRecommendation`/`prepareForKitRecommendation` reload. Accepted
because nothing in this feature's current UI reads that field directly —
`TutorialEntryPage`'s routing between "show the viewer" vs. "show an
empty/in-progress state" already happened once, before the viewer opened,
and doesn't re-run per step. A future phase that starts rendering
session-level status inside the viewer should replace this splice with a
full reload.

**Placement/Result slider reuse** (task 7): no new code — `ComparisonSlider`/
`PlacementResultComparison` (ST-5/ST-6) already do this; this phase only
had to keep feeding them the same `placementImageUrl`/`resultImageUrl`
once a step actually has both, which happens automatically now that
generation is wired up.

**Placement source and overlays** (task 5): also no new code. ST-9's
`index.ts` already writes `placement_image_path` on *every* successful
step, including step 1 (`cumulativePath` starts as the original selfie's
own path for step 1), so a completed step's Placement image is correct
without this phase touching that logic. `placement_metadata_json` is
still only ever set at step-creation time by ST-7's planner (ST-9 never
writes it), so `TutorialStepViewer`'s ST-6 fallback
(`step.placementMetadata ?? TutorialPlacementOverlayCatalog.defaultFor(...)`)
remains correct and mostly theoretical in practice, exactly as it was
before this phase.

**Final-preview reuse** (task 10): also no new code — ST-7/ST-8 already
pre-complete the final step with the reused preview's path at session
*creation* time, so `resultImageUrl` is non-null for it from the moment
the session exists. `TutorialStepViewer` never special-cases the final
step; it falls into the same "already has a result → show the slider"
branch as every other completed step, and — since `firstMissingIndex`
skips it automatically — is never offered a "Generate this step" action
either.

**Signed URLs** (task 11): also no new code — `SupabaseTutorialRepository._hydrateStep`
already re-signs both image paths (3600s TTL) on every method that
returns a step, and `generateStepResult` was written to go through the
same helper rather than inventing a second signed-URL path.

**Not implemented, out of this phase's scope**: bulk/background
generation of every remaining step at once. Generation stays strictly
per-step and user-initiated (one "Generate this step" tap = one step),
matching the explicit-user-action principle ST-8 established for session
creation. A "generate the rest of this tutorial" flow, if wanted later,
is a new decision — not an extension of what this phase built.

## ST-11: written instruction integration — what was already correct, what wasn't

This phase audited every place a [TutorialInstruction](domain/entities/tutorial_instruction.dart)
gets built (`TutorialPlanningEngine`'s two entry points) against the
roadmap's structured-field list and found the shape of the mapping
already correct — every step gets one, both modes read only real source
data, no field is fabricated. What was actually wrong was narrower:
terminology consistency and two genuinely-available facts that were
being silently dropped. No schema, entity, or Edge Function changed.

**Kit-sourced `finish`/`intensity` are now humanized; standard-sourced
ones are deliberately left alone** (tasks 2/3/7). Both values are
already-controlled, lowercase vocabularies from their respective sources
(kit: copied verbatim from a real product row, server-validated to match
— `generate-kit-makeup-recommendation/validation.ts`; standard: also a
fixed `sheer|soft|medium|bold` enum for intensity, freer text for
finish) — but the two *existing, frozen* result screens for these
sources already disagree on how to display them:
`kit_result_product_card.dart` title-cases both via its own `_label()`
helper; `recommendation_item_card.dart` shows them exactly as returned.
Rather than picking one convention and overriding both sources (which
would make the tutorial's copy diverge from at least one of the two
existing result screens it's meant to be consistent with), the planner
now matches each source's *own* established convention: kit-sourced
values go through a new `TutorialPlanningEngine._humanize()` (extracted
from the pre-existing `_title()`, which now just calls it), standard-
sourced values are untouched. This is presentation formatting of real
values, not new data — no fact changes, only casing.

**Foundation depth/undertone facts are no longer dropped** (tasks 1/3/5):
`KitProductSnapshot.foundationDepth`/`foundationUndertone` are real,
already-modeled snapshot fields — already surfaced in the kit's own
result UI (`kit_result_product_card.dart`) — that `TutorialPlanningEngine`
simply never read. There's no dedicated `TutorialInstruction` field for
them (the roadmap's field list doesn't name one, and adding one for two
foundation-only facts felt like the wrong shape), so `_foundationTip()`
folds them into `tip` — e.g. "Registered in your kit as Medium depth,
Warm undertone." — only when the snapshot actually carries at least one
of them, which in practice means only foundation steps ever get this
tip. Every other category's `tip` stays `null`, exactly as before.

**Considered and declined: plumbing kit selections' `reasoning` field
through for a kit-mode tip.** `generate-kit-makeup-recommendation`'s
response actually includes a per-selection `reasoning` string (see
`validation.ts`'s `SelectedProduct.reasoning`) — the kit-mode analogue of
`MakeupRecommendationItem.reasoning`, which standard mode already uses
for `tip`. It is real, non-fabricated data. It was *not* wired through,
because doing so would require adding a field to `KitMakeupSelection`
(the shared domain entity) and `KitMakeupRecommendationDto.fromResponse`
— code outside `step_by_step_tutorial/`, in the explicitly-frozen My
Makeup Kit feature every prior phase's notes have been careful not to
touch. A kit-mode step having no `tip` beyond the foundation-depth case
is not a bug: task 6 explicitly sanctions omitting fields that "genuinely
do not apply," and the client genuinely has no per-selection reasoning
wired into its domain model today. If a future phase decides this is
worth the cross-feature touch, it is additive and low-risk (the new
field would be optional, breaking no existing call site), but that
decision belongs to whoever explicitly asks for it, not to this phase.

**Task 4 (instruction ↔ overlay ↔ generated-image consistency) was
already structurally guaranteed, not newly built** — this phase added a
test (`written instruction — terminology and structured facts`, "every
planned step's instruction category matches the step's own category")
to make the guarantee explicit, but changed no code for it:
- *Instruction ↔ current step*: `TutorialStepViewer` has only ever
  rendered `steps[_index].instruction` for the currently-viewed step
  (ST-5) — there is no code path that could show step N's instruction
  next to step M's images.
- *Instruction ↔ overlay*: both derive from the same `category` on the
  same `PlannedTutorialStep` (ST-6/ST-7) — the overlay catalog is keyed
  by category, and so is the instruction that was built alongside it in
  the same loop iteration.
- *Instruction ↔ generated Result*: `generate-tutorial-step/prompt.ts`
  embeds the literal persisted `instruction_json` in the Gemini request
  (`Step instruction: ${JSON.stringify(instruction)}`, ST-9) — the model
  is prompted with the exact same structured data the card displays,
  not a re-derived or re-worded summary of it.

**Task 6 (graceful omission) and task 8 (no invented facts) were already
satisfied by `TutorialInstructionCard`'s existing conditional rendering**
(ST-5) — every optional field (`colorName`, `finish`, `direction`, `tip`)
is only shown `if (... != null)`, and nothing in this phase's changes
introduces a code path that invents a value for a field the source data
doesn't have. `direction` specifically remains always-`null` in both
modes: neither `MakeupRecommendationItem` nor `KitMakeupSelection` models
a direction field, and deriving one by parsing free-text `technique`
strings would be exactly the kind of invention task 8 warns against, so
it was deliberately left alone rather than "improved."

## ST-12: save, reopen, history & regenerate — mostly already true, one new capability

Four of this phase's seven tasks turned out to already be fully satisfied
by prior phases once actually traced end-to-end; this phase's only new
code is regeneration (tasks 3–5) and a copy fix (task 6's write-up).

**Task 1 (View Tutorial from Saved Looks/History) — already true, by
construction.** Neither Saved Looks nor History has its own detail
screen: opening a card in either one restores the same ambient
controllers the live wizard flow uses (`SavedLooksPage._openResult`/
`_openKit`, `HistoryPage._open`/`_openKit`), then pushes the *same*
`previewRoute`/`makeupKitRecommendationEntryRoute` the wizard itself
pushes — this was already the deliberate ST-4 design decision (see this
file's ST-4 section). `HowToApplyLookButton` on those two result pages
therefore reaches Saved Looks, History, and the live wizard identically;
it has no way to know or care which one populated the ambient state it
reads. No new button was added — one was already reachable from all four
surfaces the task named, and adding per-card buttons would have been the
redundant navigation ST-4 explicitly reasoned against.

**Task 2 (reopening loads stored session/steps/images, never
regenerates) — already true, since ST-3/ST-8/ST-10.**
`prepareForRecommendation`/`prepareForKitRecommendation` call
`TutorialRepository.loadExisting`, which fetches the session row *and*
calls `loadSteps` (hydrating every step's placement/result signed URLs
via `_hydrateStep`) in the same operation — nothing on this path ever
calls `generate()`/`generateStep()`/`regenerate()`. This was already
implicitly proven by every existing controller test: their fake
repositories throw `UnimplementedError` for any generation method not
explicitly stubbed, so if `prepareFor*` ever called one by accident,
every pre-ST-12 test using those fakes would already be failing.

**Task 6 (delete) — already true, via History's existing cascade, not
new code.** `delete-history-item/index.ts` recursively lists and removes
*every* object under `historyPrefix(userId, analysisId)` =
`"{userId}/analyses/{analysisId}"` (`storage_paths.ts`) before deleting
the `analyses` row — a prefix sweep, not an enumerated per-subfolder
list. Tutorial images live at
`{userId}/analyses/{analysisId}/tutorials/{tutorialSessionId}/step_NNNN_result.{ext}`
(ST-9), directly under that same prefix, so they were already being
swept with zero tutorial-specific code. On the database side,
`tutorial_sessions.analysis_id` (and `tutorial_steps.tutorial_session_id`
beneath it) both carry `on delete cascade` (ST-2's migration), so
deleting the `analyses` row already cascades away every tutorial session
and step row too. The only actual change: `history_page.dart`'s two
delete-confirmation dialogs now say "...and any generated tutorials in
this session" so the warning stays honest about what it removes — a
copy-only edit, no behavior change, no new test needed (nothing asserted
the old exact string). There is deliberately **no** standalone "delete
just this tutorial" action: neither Saved Looks nor History has any
precedent for deleting a sub-part of a session (Saved Looks' "remove"
only un-saves; History's delete is all-or-nothing for the whole
analysis), so a partial-deletion feature would be a new UX pattern this
phase didn't invent one for.

**Task 3–5 (regeneration) — the one genuinely new capability.** Before
this phase, a session had no way to redo anything once every step either
succeeded or was never attempted — the per-step "Generate this step"
(ST-10) only ever targets a step with no result yet, by design (never
regenerate an already-valid step, ST-10 task 3), and there was no
whole-session equivalent. New: `TutorialRepository.resetForRegeneration`
clears every **non-final** step's `placement_image_path`/
`result_image_path`/AI metadata back to null and `generation_status`
back to `not_started` (one bulk UPDATE via a new
`TutorialRemoteDataSource.resetSteps`, `values` built by the new
`TutorialStepDto.resetRow()`), then resets the session's own status the
same way. Steps then flow back through the exact same "Generate this
step" UI ST-10 already built — no new generation-orchestration code, no
Edge Function change, no migration.

**The task-5 decision: replace in place, not a new version — a
constraint, not a preference.** `tutorial_sessions` has a partial unique
index on `(recommendation_id, generation_number)` /
`(kit_recommendation_id, generation_number)` (ST-2) — at most one session
per source-look variation. A genuinely separate "new version" of a
tutorial for the *same* variation isn't representable in today's schema
without a migration this phase didn't make. "Prefer preserving
historical integrity" is honored at the level this app's existing
conventions actually operate at: generating a *new preview variation*
(an already-shipped, unrelated feature) gets its own independent
`generationNumber`, and therefore its own independent tutorial session
the moment the user requests one — the *old* variation's tutorial is
completely untouched by that. Regenerating *within* one variation,
by contrast, replaces that variation's own tutorial content in place;
the old step images are not retained as a "version 2" anywhere (their
storage objects are left orphaned in place, not deleted — nothing
client-side deletes storage objects outside the Edge Function's own
upload-then-fail cleanup, ST-9 — but the DB no longer references them, so
they're unreachable through the app). This is stated plainly as a real
tradeoff of the chosen approach, not hidden.

**Confirmation copy carries both required messages** (task 4) *before*
anything happens, not after: "Every step's generated image will be
cleared... each will need a fresh AI generation" (generation will be
needed) and "If you cancel, your current tutorial keeps working exactly
as it is now" (the existing tutorial is otherwise reusable — true
precisely because cancelling is a true no-op; nothing is touched until
`FilledButton` is pressed). Matches the `AlertDialog` / `TextButton`
Cancel + `FilledButton` primary-action shape `saved_looks_page.dart`/
`history_page.dart` already use, word-for-word structurally, adjusted in
severity to this operation's actual blast radius (recoverable via
re-generation, unlike History's actually-destructive delete).

**Where the action lives**: a single `IconButton` (`Icons.refresh_rounded`,
tooltip "Regenerate tutorial") in `TutorialEntryPage`'s `AppBar.actions`
— matching `scan_page.dart`'s existing "Start over" AppBar-action
precedent (also a reset-style destructive action, also a single icon,
also gated on whether there's anything to reset) rather than inventing a
new placement convention. Shown whenever the viewer itself would be
shown (`session != null && session.steps.isNotEmpty`, the same gate
`TutorialEntryPage` already uses); disabled (not hidden) while a
session-level operation or a per-step generation is already in flight,
so the button's presence/absence doesn't flicker independently of the
rest of the page's busy state.

## ST-13: resilience, security, cost & performance hardening

A full audit of the feature against the roadmap's eight review areas.
Most areas were already correct — inherited from decisions made in
ST-2/6/9/10 and never revisited until now — and are recorded below as
**verified**, not fixed. Three genuine gaps were found and fixed. One
area (offline viewing) was investigated and deliberately left alone,
with the reasoning stated plainly.

### Verified, no change needed

- **RLS**: `tutorial_sessions`/`tutorial_steps` both have the standard
  four-policy (`select`/`insert`/`update`/`delete`, `to authenticated`,
  `using`/`with check (auth.uid() = user_id)`) shape, `anon` revoked,
  matching every other table in this schema exactly. Re-read line by
  line against `20260814000300_tutorial_sessions_steps.sql` — no
  deviation found.
- **Session/storage ownership**: composite FKs (`(id, user_id)` /
  `(analysis_id, user_id)` / `(recommendation_id, analysis_id, user_id)`
  / `(kit_recommendation_id, analysis_id, user_id)`) mean a row can never
  reference another user's analysis/recommendation even if a client
  somehow supplied a foreign id. `isOwnedOriginalPath`/
  `isOwnedTutorialResultPath` (`_shared/storage_ownership.ts`) both do
  segment-by-segment comparison (not `startsWith`), rejecting path
  traversal — re-verified directly, not just re-read.
- **Edge Function validation**: `requestedStepId` requires a UUID-shaped
  string; every downstream fetch is RLS-scoped (a step belonging to
  another user simply doesn't come back — reported as `_NOT_FOUND`, not
  distinguished from "doesn't exist," matching every other function in
  this project).
- **Secrets**: `GEMINI_API_KEY` is read once via `Deno.env.get` and used
  only as an outbound `x-goog-api-key` header value — grepped every
  `console.log`/`console.error` call in `generate-tutorial-step/` and
  confirmed none references the key, image bytes, or full paths; all are
  boolean/status flags and `${stage}_ms` timing numbers, matching ST-9's
  stated logging posture. The Flutter side has zero `print`/`debugPrint`
  calls anywhere in `step_by_step_tutorial/` — nothing to leak.
- **Cost — reuse/dedupe**: re-confirmed all four mechanisms named in the
  roadmap are real, independent layers, not just documentation claims:
  client-side skip (`generateStep` no-ops if `resultImageUrl != null`),
  server-side early-return (`already_has_result` check), the conditional
  claim (`generation_status IN ('not_started','failed')`, preventing a
  concurrent duplicate Gemini call), and `loadExisting` always being what
  reopening calls (never `generate`).
- **Identity safeguards**: re-confirmed the cumulative-source +
  identity-anchor design (step 1: selfie only; step N>1: selfie *and*
  step N−1's result, as two separate `inlineData` parts) is applied
  identically at *every* step N>1, not just step 2 — so anchor strength
  doesn't degrade over a longer tutorial. `imagesAreIdentical` still
  guards against Gemini silently no-op'ing. No new drift-resistance gap
  found; the known limitation already recorded in ST-9's notes (no
  perceptual/near-duplicate check, only byte-exact) stands as documented,
  not newly discovered.
- **Broken signed URL / missing storage asset**: already fully handled —
  `PlacementResultComparison` renders through the exact same
  `ComparisonSlider` → `PrivateImage` path `BeforeAfterComparison` uses,
  including its `errorChild` fallback ("Image unavailable — Return and
  reopen this result to refresh its private link"). Verified this is the
  *same* code path for both callers, not a parallel one that could drift.
- **Image loading / decode size**: `PrivateImage` already decodes to the
  rendered box size (`cacheWidth`), and `TutorialStepViewer` only ever
  builds the *current* step's images — Previous/Next swaps which step is
  built, it does not pre-build neighbors. No wasted full-resolution
  decodes, no off-screen prefetch to avoid.
- **Controller lifecycle**: `tutorialSessionControllerProvider` is a
  plain (non-`autoDispose`) `StateNotifierProvider` that `ref.watch`es
  the authenticated user id — byte-for-byte the same declaration shape as
  `makeupPreviewControllerProvider`/`makeupKitLookControllerProvider`.
  This also closes a question this audit raised but did not need to fix:
  *is tutorial state cleared on sign-out?* No explicit `.clear()` call
  exists anywhere (confirmed no other ambient controller in this app has
  one either — this is an app-wide pattern, not a tutorial-specific
  gap), but it doesn't need one: watching the user id means Riverpod
  discards the old notifier and constructs a fresh one the moment the
  signed-in user id changes, which is what actually prevents one
  account's tutorial data from surviving into another account's session
  on the same device.
- **Duplicate taps**: `generateStep`/`regenerate`/`_run` all set their
  busy-guard state synchronously, before their first `await` — Dart runs
  an `async` function's body synchronously up to that point, and a
  second tap is a separate, later event-loop turn, so there is no frame
  where two calls both pass the guard. Traced through explicitly, not
  assumed.

### Fixed

**1. Cost protection gap: nothing stopped the final "complete look" step
from being independently generated for real.** It's designed to always
reuse the existing final preview at planning time and never call Gemini
for itself — but nothing enforced that server-side. If planning ever
left a `final_look` step without a result (a bug, not a normal runtime
state), calling `generate-tutorial-step` for it would have silently
proceeded to spend a real Gemini call and quota unit on image content
that's supposed to already exist. Fixed in
`supabase/functions/generate-tutorial-step/index.ts`: after the existing
"already has a result" early-return, a `category === "final_look"` step
that reaches that point now fails fast with `FINAL_LOOK_NOT_GENERATED`
(409, non-retryable) instead of proceeding. Validated by manual review
only — no Deno/local-functions tooling available in this environment
(same limitation ST-9 already recorded).

**2. Resilience gap: an interrupted step-creation loop left a tutorial
permanently stuck with too few steps.** `GetOrCreateTutorialSession`
creates the session row, then loops `createStep` (+ `updateStepImages`/
`updateStepStatus` for the reused final step) one `await` at a time. If
that loop was interrupted partway (a network blip after step 2 of 8, for
example), the session row existed with fewer steps than
`totalSteps` — and the *next* attempt's `loadExisting` would find that
session and return it immediately, via the original `if (existing !=
null) return existing;` short-circuit, without ever finishing the
missing steps. There was no path that would ever complete it: not a
normal user-facing error (no exception was thrown to the *second*
caller), just a tutorial permanently short of steps. Fixed by comparing
`existing.steps.length` against `existing.totalSteps`: only a session
that's actually complete short-circuits immediately; an incomplete one
(whether found up front, or discovered via the existing duplicate-session
race-loss path) falls through to the same step-creation loop, which
skips whichever `stepNumber`s already exist and creates only the rest.
Planning is a pure function of the same source data, so replanning here
reproduces the identical step list — nothing is re-derived differently
the second time. This also strengthens the pre-existing race-loss path:
previously a "lost the race" caller trusted the winner to have finished
every step; now it resumes any the winner left unfinished too, instead
of just assuming.

**3. Error-handling gap: a permanently non-retryable step failure still
offered a "Try again" button.** `TutorialSessionState.stepFailureRetryable`
was threaded correctly from both `TutorialFailure`/`FunctionFailure`
(both default `retryable: false`) all the way into the controller state,
but `_StepBody` never read it — every fresh step failure showed "Try
again," including ones where retrying is guaranteed to fail identically
every time (a deleted source, a deleted step, `FINAL_LOOK_NOT_GENERATED`
from fix 1 above). Fixed: `_StepBody` now only offers the retry action
when `state.stepFailureRetryable` is true for a fresh failure. A
*persisted* failure from an earlier app session (no fresh `retryable`
flag available, since it wasn't just reported) still defaults to
offering retry — that default was not changed, since silently trapping
a persisted failure with zero recourse would be worse than an
occasionally-futile retry button.

**4. Error-handling gap: a deleted source produced a misleading
"retryable" message.** If the source analysis/recommendation was deleted
between a caller loading it and `createSession`'s insert running, the
owner-scoped foreign keys reject the insert with Postgres `23503`. This
previously fell into the same generic bucket as a transient connection
error — `TutorialFailureType.server`, `retryable: true` — telling the
user to do the one thing guaranteed not to help. Fixed:
`SupabaseTutorialRepository.createSession` now maps `23503` to
`TutorialFailureType.notFound`, `retryable: false`, `technicalCode:
'source_deleted'`, with a message that says plainly the look no longer
exists.

### Investigated and deliberately left unchanged

**Offline saved-tutorial viewing (task 5's "where practical" hedge).**
Confirmed there is no disk image cache anywhere in this app (no
`cached_network_image` or equivalent in `pubspec.yaml`/`lib/`) —
`PrivateImage` uses `Image.network`, whose only cache is Flutter's
in-memory `ImageCache`, and signed URLs are re-minted fresh on every
hydration anyway, which defeats even that. Separately,
`TutorialSessionController._run` unconditionally resets `state` to
`loading` (discarding any already-loaded session) on every
`prepareForRecommendation`/`prepareForKitRecommendation` call, so even
re-opening a tutorial already viewed once in the same app run triggers a
fresh network round trip. Both are real, but neither was changed:
- Adding a disk cache would be an app-wide capability this feature
  alone shouldn't introduce asymmetrically — no other image in FaceTune
  (selfies, previews, kit products) is cached offline either.
- Skipping the refetch when a same-key session is already in memory
  sounds appealing, but signed URLs expire after 3600s; silently reusing
  a stale in-memory session risks showing broken images with no visible
  reason, where a fresh fetch would have refreshed them. A proper fix
  (stale-while-revalidate: show the old session immediately, replace it
  in place if a background refetch succeeds, never blank the screen to a
  spinner for a session that's already loaded) is a legitimate future
  improvement, but is a meaningfully different, riskier controller
  redesign than this hardening pass's scope — changing well-tested
  behavior from ST-3/8/10/12 needs its own deliberate phase, not a
  drive-by change bundled into an audit.
This is stated as a known limitation, not hidden as a non-issue.

### Files modified this phase

- `supabase/functions/generate-tutorial-step/index.ts` — fix 1.
- `lib/features/step_by_step_tutorial/domain/usecases/get_or_create_tutorial_session.dart` — fix 2.
- `lib/features/step_by_step_tutorial/presentation/widgets/tutorial_step_viewer.dart` — fix 3.
- `lib/features/step_by_step_tutorial/data/repositories/supabase_tutorial_repository.dart` — fix 4.
- Tests: `get_or_create_tutorial_session_test.dart` (new resume-after-interruption
  coverage, plus its `_RecordingRepository` fake made accurate enough to
  express a partially-created session), `tutorial_step_viewer_test.dart`
  (non-retryable-failure coverage), `supabase_tutorial_repository_test.dart`
  (23503 mapping coverage).

## Frozen systems reminder

Face Analysis, Makeup Recommendation, the existing final preview's
Edge Function/generation logic, My Makeup Kit's generation logic, Saved
Looks, and History remain untouched by ST-1–ST-13, with one narrow,
deliberate exception (ST-12's dialog-copy edit, noted below). Existing
presentation files were touched only additively:
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
- ST-8: `preview_result_page.dart`/`makeup_kit_recommendation_entry_page.dart`
  changed only their `onOpenTutorial` callback body (new method names on
  the same controller); `tutorial_plan.dart`/`tutorial_planning_engine.dart`
  gained new optional-output fields, additive to ST-7's public API;
  `supabase_tutorial_repository.dart`'s `createSession` gained one new
  `catch` branch ahead of its existing generic one.
- ST-9: `supabase/functions/_shared/ai_quota.ts` gained one new
  `AiOperation` union member (`tutorial_step`, matching the DB check
  constraint ST-2 already added); `_shared/storage_ownership.ts` gained one
  new exported function (`isOwnedTutorialResultPath`) alongside the
  existing `isOwnedOriginalPath`, neither touched. `supabase/config.toml`
  gained one new `[functions.generate-tutorial-step]` block.
  `generate-makeup-preview/`, `generate-kit-makeup-preview/`, and every
  other existing Edge Function directory are completely untouched.
- ST-10: `tutorial_entry_page.dart` changed only the prop it passes to
  `TutorialStepViewer` (`state:` instead of `session:`); no branch/status
  logic in that file changed. `TutorialStepViewer` itself was rewritten
  (now a `ConsumerStatefulWidget`) but its public rendering contract for
  every state ST-5/ST-6 already covered (header, slider, instruction card,
  Previous/Next) is unchanged — only new states were added, none removed
  or altered. `supabase_tutorial_repository.dart` gained one new method
  (`generateStepResult`) and one new `_failure` branch, both additive.
  `tutorial_repository.dart`'s interface gained one new method, implemented
  by both `SupabaseTutorialRepository` and `UnavailableTutorialRepository`.
  No Edge Function, migration, or RLS policy changed in this phase.
- ST-11: only `tutorial_planning_engine.dart` (plus its test) changed —
  new private helpers and two new `TutorialInstruction` field values
  (`finish`/`intensity` humanization, `tip` for foundation depth/
  undertone) for kit mode only; standard mode's mapping is byte-for-byte
  unchanged. No other file, including `KitMakeupSelection`/
  `KitMakeupRecommendationDto` (deliberately — see the ST-11 section
  above), was modified.
- ST-12: `tutorial_entry_page.dart` gained an AppBar action + a
  confirmation dialog (additive); `tutorial_repository.dart`,
  `tutorial_remote_data_source.dart`, `tutorial_step_dto.dart`,
  `supabase_tutorial_repository.dart`, `unavailable_tutorial_repository.dart`,
  and `tutorial_session_controller.dart` each gained exactly one new
  method, no existing method's behavior changed. The **one exception** to
  "existing features untouched" in this entire roadmap so far:
  `history_page.dart`'s two delete-confirmation dialog strings were
  edited to mention "generated tutorials" — copy only, the delete
  mechanism itself (cascade + storage sweep) was already correct and
  unchanged. No Edge Function, migration, or RLS policy changed.
- ST-13: all four fixes touch only files this feature already owns
  (`generate-tutorial-step/index.ts`, `get_or_create_tutorial_session.dart`,
  `tutorial_step_viewer.dart`, `supabase_tutorial_repository.dart`) — no
  file outside `step_by_step_tutorial/`/its own Edge Function was
  modified. No migration, RLS policy, or other Edge Function changed.

All other new files are additive under `lib/features/step_by_step_tutorial/`,
`shared/widgets/media/`, `supabase/migrations/`, and
`supabase/functions/generate-tutorial-step/`.

## TF-1: production planning finally invokes the personalized pipeline

Confirmed defect: `TutorialPlanningEngine.planFromRecommendation`/
`planFromKitRecommendation` built each step's `TutorialInstruction` (the
written-guidance path) directly from the recommendation/kit selection, but
always passed `placementMetadata: null` and never touched
`PersonalizedTutorialInput`/`PersonalizedTutorialMetadataPipeline`/
`PersonalizedTutorialStepSpec` at all — those types (and
`PersonalizedTutorialPlacementRules`, the MO-era placement-rule engine) were
fully built and tested in isolation but never wired to production tutorial
creation. `GetOrCreateTutorialSession` already forwarded a step's
`personalizedSpec` to `TutorialRepository.createStep`, and the persistence/
DTO/codec layer already round-tripped it — only the planner itself never
produced one. This matches
`FACETUNE_TUTORIAL_FIDELITY_AND_GUIDELINES_SOURCE_OF_TRUTH.md`'s "Missing
guidelines" root cause exactly.

**Fix, scoped narrowly**: both planning entry points gained two new required
parameters, `faceAttributes: FacialAttributes` and `attributeConfidence:
AnalysisConfidence` — the same real, already-computed `FaceAnalysis` fields
`PreviewResultPage`/`MakeupKitRecommendationEntryPage` already hold for the
recommendation's own `analysisId` (checked there for equality before "How to
Apply This Look" is ever shown). `_buildPlan` now additionally constructs a
`PersonalizedTutorialInput` from the same per-category source data already
being read to build the legacy `TutorialInstruction` (a second, parallel
`TutorialRecommendationData`/`TutorialKitProductSnapshot` map, built in the
same loop, not re-derived from the humanized/legacy instruction), runs it
through `PersonalizedTutorialMetadataPipeline.build`, and attaches each
result's `spec`/`overlayMetadata` to the matching `PlannedTutorialStep`.

**The legacy written instruction was deliberately left untouched.** The
source-of-truth's own root-cause wording ("legacy tutorial instructions" are
not themselves the bug) and TF-1's task scope (wire the pipeline "→
placement metadata", nothing about rewording written guidance) both point
the same way: `TutorialInstruction` is still built exactly as ST-11 left it.
Re-deriving it from the personalized spec instead would have silently
changed displayed intensity/technique text (the placement rules apply a
style-based intensity adjustment `TutorialInstruction` never has) — a
behavior change no test or task asked for. This also kept every pre-existing
`tutorial_planning_engine_test.dart` assertion passing unmodified.

**Geometry is `null`, on purpose, not a gap hidden from view.**
`TutorialFaceGeometryProvider` has zero implementations and nothing resolves
it anywhere in the app — TF-2 (the tutorial-only Gemini geometry planner)
does not exist yet. `PersonalizedTutorialMetadataPipeline.build` is called
with no `geometry` argument, which its own existing logic already turns into
an honest signal: every step's `spec.where.geometryConfidence` comes back
`unavailable` with zero `geometryAnchors` — not a guessed value. One
consequence worth stating plainly for whoever picks up TF-2/TF-3: because
`PersonalizedTutorialOverlayMetadataRenderer` only emits a drawable overlay
primitive for a region that has a matching geometry anchor,
`placementMetadata.overlays` comes back **empty** for every step after
TF-1 alone — the metadata *object* is now real and persisted, but nothing
visible paints yet. That is the correct, explicit "geometry dependency"
state TF-1's task description asked for, not a regression; TF-2 supplying
real anchors is what turns these already-wired overlays non-empty with zero
further planner changes.

**Stale/legacy detectability**: nothing backfills or coerces old data.
`PlannedTutorialStep.personalizedSpec`/`placementMetadata` stay nullable —
a pre-TF-1 planned step (or a persisted `tutorial_steps` row from before
this phase) has both `null`, and that remains a plain, honest, checkable
fact, not silently normalized to look personalized. TF-4 is expected to act
on this signal as part of its broader stale-session validation.

**Files modified**: `tutorial_planning_engine.dart` (the fix itself),
`get_or_create_tutorial_session.dart`/`tutorial_session_controller.dart`
(threading the two new required inputs through, `prepareForRecommendation`/
`prepareForKitRecommendation` now take a `required FaceAnalysis analysis`
parameter), and the two existing call sites
(`preview_result_page.dart`/`makeup_kit_recommendation_entry_page.dart`),
each changed only inside its existing `onOpenTutorial` closure to pass the
`analysis` object already in scope there — no new widget, route, or
rendering logic. `TutorialStepViewer`/`TutorialPlacementOverlayLayer`/the
overlay catalog fallback are untouched; standard Face Analysis and
Recommendation are untouched (read-only, via the same ambient controllers
ST-4 already established).

## TF-2: the tutorial-only Gemini geometry & placement planner — backend only, mirroring ST-9's own split

`supabase/functions/plan-tutorial-geometry/` is a new, self-contained Edge
Function (`index.ts`/`gemini_client.ts`/`prompt.ts`/`schema.ts`/
`validation.ts`/`types.ts`, plus `validation_test.ts`/`prompt_test.ts`)
that, given a `tutorialSessionId`, inspects the session's real original
selfie and returns a strict, validated, per-category geometry & placement
plan — real zones/paths/arrows in normalized 0.0–1.0 coordinates, grounded
in the actual photo, one entry per canonical step category the session
already has real (TF-1-populated) product facts for.

**Scope deliberately matches ST-9, not ST-10: zero Flutter files changed.**
ST-9 built `generate-tutorial-step` as a standalone Edge Function and left
all Flutter wiring (`TutorialRepository`, `SupabaseTutorialRepository`,
`TutorialSessionController`) to ST-10, a separate phase — "the viewer is
unreachable in a real run today" was stated as the correct, honest state of
that phase, not a gap. TF-2's own task text has the same shape: its Report
fields (FUNCTION, MODEL CONFIG, INPUT CONTRACT, OUTPUT SCHEMA, VALIDATION,
PERSISTENCE, AI CALL COUNT, SECURITY, DEPLOYMENT REQUIRED, MANUAL COMMANDS)
are all backend/infra-focused, with no "client wiring" field, unlike TF-1's
report shape. TF-3's own title — "Production Personalized Guideline
**Activation**" — is what actually consumes this function's persisted
output. Following that precedent exactly: nothing in
`lib/features/step_by_step_tutorial/` (or anywhere else in the Flutter app)
calls this function yet. It is fully built, deployable, and independently
testable, but unreachable from the running app until a later phase wires it
in — stated plainly, matching this file's own established convention for
recording real scope limits rather than hiding them.

**Input contract is one field, mirroring `generate-tutorial-step`'s own
minimalism**: `{ tutorialSessionId: string }` (UUID). Every other required
input — original selfie path, existing face attributes, selected style,
full recommendation, kit snapshot if applicable, canonical step
categories — is derived server-side from data that already exists once a
session has been planned by TF-1:
- original selfie + face attributes: the session's `analysis_id` →
  `analyses` row (same columns `generate-tutorial-step` already reads).
- selected style: `tutorial_sessions.makeup_style`.
- full recommendation / kit snapshot / canonical categories: each of the
  session's own non-`final_look` `tutorial_steps` rows, read via their
  `personalized_spec_json` (TF-1's real, already-decided WHAT/WHERE facts —
  preferred) falling back to `instruction_json` only for a legacy row that
  predates TF-1 and has no personalized spec yet. Nothing is re-derived
  from the raw `recommendations`/`kit_makeup_recommendations` tables — this
  function trusts TF-1's own already-validated per-step snapshot instead of
  re-deriving a second copy of the same facts, which is also what makes
  "no product invention"/"kit integrity" checkable at all: Gemini's
  `colorHex`/`finish` output must exactly echo what these rows already say,
  never something new.

**Output schema** (`schema.ts`, sent as Gemini's `responseJsonSchema`,
matching `analyze-face`'s structured-output pattern exactly): one entry per
requested category —
`category, placement, direction, intensity, technique, confidence,
colorHex, finish, zones[], paths[], arrows[]` — where a zone is
`{shape: ellipse|polygon|soft_band|region, points[], confidence}`, a path
is `{points[] (≥2), confidence}`, and an arrow is `{from, to, confidence}`.
`direction`/`intensity` deliberately use the *same camelCase vocabulary*
`PersonalizedTutorialStepSpecCodec` already persists for
`personalized_spec_json.how.direction`/`.intensity` (e.g. `upwardOutward`,
`followBoundary`) — not snake_case — specifically so a later mapping phase
(TF-3) can match strings directly with no case-conversion layer to get
wrong. `category` stays the existing snake_case `TutorialStepCategory.code`
vocabulary (`lip_gloss`, not `lipGloss`), matching every other
category-coded column in this schema.

**Validation is two-layered, matching `analyze-face`'s established
posture**: `responseJsonSchema` constrains Gemini's output distribution,
but `validation.ts` fully re-parses and re-validates every field
independently afterward, trusting nothing from the schema alone (JSON
parse failure, non-object shapes, and missing fields are all re-checked by
hand). Beyond structural validation, three checks are specific to this
function's own risk surface:
- **category coverage** — the returned category set must exactly equal the
  requested set: same size, no duplicates, no unrequested/missing category.
  A plan that doesn't cover everything asked, or invents an extra category,
  is rejected outright, not partially accepted.
- **no product invention** — a returned `colorHex`/`finish` must exactly
  match (case-insensitively for finish, case-insensitively for hex too via
  `.toUpperCase()`) the real value already recorded in that category's own
  `personalized_spec_json`/`instruction_json`. Returning a color that was
  never given to Gemini, or returning any color when none was given at all,
  is rejected — this is what makes "the AI cannot manufacture a shade the
  user was never actually recommended" an enforced invariant, not a prompt
  request Gemini could ignore.
- **kit integrity** — for a `makeup_kit`-mode session, every planned
  category must trace back to a real owned-product snapshot (i.e. that
  step's `personalized_spec_json.what.productSnapshot` was non-null) — a
  kit tutorial can never get a geometry plan for a category the user didn't
  actually own a product for.

No fallback coordinates are ever synthesized for a rejected field — the
*entire* plan is rejected on any single violation (never a partial
accept), matching the "reject malformed/out-of-range/impossible geometry;
never invent fallback coordinates" instruction literally.

**Persistence — one plan per session, three new nullable columns on
`tutorial_sessions`** (`20260816000100_tutorial_geometry_plan.sql`):
`geometry_plan_json` (the validated `{steps: [...]}` object),
`geometry_plan_version` (`tutorial_geometry_plan_v1`), `geometry_model`
(echoed for display/debugging only, same non-configuration convention as
the existing `tutorial_model` column). A session with a plan already
recognizable by a `steps` array in `geometry_plan_json` short-circuits
immediately on the next call — no quota spent, no Gemini call, matching
"persist once and reuse" literally. This lives on `tutorial_sessions`
rather than a new table because a plan is 1:1 with a session, the same
cardinality `prompt_version`/`tutorial_model` already have.

**Concurrency claim, adapted from `generate-tutorial-step`'s pattern**: a
conditional `UPDATE ... WHERE geometry_plan_json IS NULL` writes a
transient `{"planning": true}` marker (itself a valid object, so it costs
no schema change beyond `geometry_plan_json` itself) before the Gemini
call; a losing concurrent request sees zero rows matched and either
returns the winner's now-persisted real plan or reports
`GEOMETRY_PLANNING_IN_PROGRESS` (409, retryable). Any failure after
claiming reverts the marker back to `null` in the `catch` block
(best-effort), exactly mirroring `generate-tutorial-step`'s revert of a
claimed step back to `failed` — so a genuine failure never permanently
blocks a retry.

**AI call count**: at most one Gemini call per tutorial session, ever —
enforced by the claim + the `steps`-array short-circuit together, not by
client-side discipline alone (defense in depth, matching ST-13's stated
posture for `generate-tutorial-step`).

**Model/quota configuration, kept independent of every other tutorial AI
call**: `TUTORIAL_GEOMETRY_MODEL` (default `gemini-3.6-flash`, a text/JSON
reasoning call, not an image generation call — deliberately not
`GEMINI_MODEL`/`TUTORIAL_IMAGE_MODEL`, so an operator can tune this
independently, the same rationale ST-9 already recorded for
`TUTORIAL_IMAGE_MODEL`). `ai_usage_events`/`consume_ai_quota` gained one
new operation, `tutorial_geometry_plan` (20/hour, 100/day — deliberately
much lower than `tutorial_step`'s 80/400, since this runs at most once per
tutorial rather than once per step; a starting guess, not measured data,
matching every other limit's own stated caveat).

**Security**: identical posture to `generate-tutorial-step` —
bearer-token auth via `client.auth.getUser()`, RLS scopes every table read
to the caller's own rows (a session/step belonging to someone else is
reported as not-found, never distinguished from "doesn't exist"),
`isOwnedOriginalPath` (reused from `_shared/storage_ownership.ts`,
unmodified) re-validates the selfie path segment-by-segment before
downloading it, and `GEMINI_API_KEY` never leaves the server or appears in
any log line (only `${stage}_ms` timings and boolean/status flags are
logged, grepped to confirm).

**Deliberately not attempted here**: mapping `geometry_plan_json` into
`PersonalizedTutorialStepSpec`/placement metadata/the overlay renderer
(TF-3's explicit job); any Flutter-side repository/controller/domain
changes to read this column at all (also implicitly TF-3's concern, since
nothing consumes it yet); deciding *when* in the live app flow this
function should be automatically invoked (a UX/orchestration decision that
belongs with the phase that actually activates guidelines, not this one).

**Files created**: `supabase/functions/plan-tutorial-geometry/` (7 files)
and `supabase/migrations/20260816000100_tutorial_geometry_plan.sql`.
**Files modified**: `supabase/functions/_shared/ai_quota.ts` (one new
`AiOperation` union member, additive — `_shared/storage_ownership.ts` and
every other existing Edge Function directory untouched) and
`supabase/config.toml` (one new `[functions.plan-tutorial-geometry]`
block). No Flutter file, migration touching an existing table's *existing*
columns, RLS policy, or other Edge Function changed.

**Not independently verified by an automated test run**: same limitation
ST-9/ST-13 already recorded — no Deno/local-functions tooling is available
in this environment (confirmed: `deno --version` resolves to "command not
found" here). `validation_test.ts`/`prompt_test.ts` are real, executable
Deno tests (`Deno.test(...)`, `jsr:@std/assert@1`) covering schema parse,
bounds, confidence, category coverage, kit integrity, no product
invention, and invalid-response rejection as TF-2 required — written and
manually reviewed, not run in this session. Whoever deploys this should run
`deno test supabase/functions/plan-tutorial-geometry/` (or
`supabase functions serve` + integration test) before relying on it.

## TF-3: guideline activation — a projection, not a second decision engine

TF-2 deliberately stopped at persisting `geometry_plan_json`, stating
plainly that mapping it into `PersonalizedTutorialStepSpec`/placement
metadata/the overlay renderer, and deciding when to trigger the planning
call from the live app, were both this phase's job. This section records
how that turned out, including one real architectural finding that changed
the intended design mid-phase.

**Finding, before any code changed: the ST-6 catalog fallback no longer
exists.** ST-6's own notes (this file, above) describe
`TutorialStepViewer` falling back to `TutorialPlacementOverlayCatalog.defaultFor(step.category)`
when `step.placementMetadata` is null. That fallback was removed in the
commit that built the whole MO-era personalized pipeline (`714421d`,
oddly titled "No Guide Lines" — it is in fact the commit that *introduced*
`personalized_tutorial.dart`/`PersonalizedTutorialMetadataPipeline`/etc.):
`TutorialPlacementOverlayCatalog.defaultFor` was renamed to
`legacyFallbackFor` and marked `@Deprecated`, and
`TutorialStepViewer`/`PlacementResultComparison` now render
`step.placementMetadata` directly, with no `??` fallback at all. This is
deliberate, not a regression to route around: illustrative, unmeasured
category-typical shapes were judged worse than showing nothing once the
architecture committed to *real* personalization. Consequence for TF-3:
"no fake guides when invalid" cannot mean "fall back to the catalog" —
it means "leave the step's placement metadata exactly as TF-1 left it
(empty overlays)," which is what every fallback path below actually does.

**Architecture decision: activation bypasses the anchor/region system
entirely, rather than feeding zones/paths/arrows through it.**
`PersonalizedTutorialStepSpec.where.geometryAnchors` (populated via
`TutorialFaceGeometry`, MO-era) models a fundamentally different shape of
"geometry" than TF-2's plan: one flat per-*region* boundary polygon
(`TutorialFaceGeometry`'s eyes/brows/nose/lips/forehead/cheeks/jaw/chin),
versus TF-2's typed, confidence-scored, per-*category* zone/path/arrow
primitives with no region label at all. Reconciling the two would mean
either inventing a lossy region-assignment heuristic for TF-2's primitives,
or changing TF-2's own already-completed contract. Neither was necessary:
`PersonalizedTutorialWhat`/`where.description`/`how` already carry every
fact a category needs, and `TutorialPlacementOverlay` (the thing the
renderer actually draws) has no dependency on the anchor system at all —
it is just `{type, points, colorHex}`. `TutorialGeometryActivation`
(`domain/services/tutorial_geometry_activation.dart`) therefore projects a
`TutorialCategoryGeometryPlan` straight into `TutorialPlacementOverlay`s
(zone→zone, path→line, arrow→arrow, points passed through unchanged,
`plan.colorHex` carried onto zone/line overlays) without touching
`PersonalizedTutorialStepSpec` at all. This also avoids a real constructor
invariant `PersonalizedTutorialWhere` already enforces —
`geometryConfidence` must be `unavailable` exactly when `geometryAnchors`
is empty — which TF-2's plan has no way to satisfy without also
fabricating anchors. The spec stays exactly as TF-1 built it (an honest
"no landmark anchors yet," since `TutorialFaceGeometryProvider` is still
unimplemented); only the step's own `placementMetadata` is upgraded.

**Confidence fallback, mirrored from `PersonalizedTutorialOverlayAccuracyValidator`
without reusing its (region-specific) code.** That validator's rules —
`low`/`unavailable` → render nothing, `medium` → broader/simpler (at most
one arrow per region), `high` → precise — are the right shape but operate
on anchors/regions TF-2's plan doesn't have. `TutorialGeometryActivation`
re-implements the same three-tier behavior directly against TF-2's own
confidence fields: a category below 0.55 renders nothing; 0.55–0.79 keeps
at most one arrow (mirroring the validator's own arrow de-duplication) and
drops any individually-weak primitive; 0.8+ keeps every primitive whose
own confidence clears the same 0.55 floor. A primitive is never trusted
more than the category bucket it belongs to. "No fake guides" is
structural, not a special case: every rejection path (`overlays.isEmpty`)
returns the original `TutorialStep` unchanged — literally `identical()`
to the input — rather than constructing a new, empty-but-different
placement metadata object.

**Activation runs inside `TutorialSessionDto.fromRow`, not as a persisted
write-back.** The two inputs a category's activated overlay needs (its own
`category`, and the session's `geometry_plan_json`) are already both
persisted and already both loaded together by the time any repository
method builds a `TutorialSession`. Re-deriving placement metadata on every
load is therefore free (pure, synchronous, no AI call) and — unlike a
persisted `placement_metadata_json` write-back — can never drift out of
sync with a stale cached value if the mapping logic itself changes later.
`loadExisting`/`createSession`/`updateSessionStatus`/`resetForRegeneration`/
`planGeometry` all funnel through `TutorialSessionDto.fromRow`, so every
one of them gets activation "for free" with no per-method wiring. The one
new parsing rule this required: `geometry_plan_json` can be `null` (not
planned), the transient `{"planning": true}` claim marker TF-2's Edge
Function writes mid-flight (also "not planned yet," not malformed data),
or a real `{"steps": [...]}` plan — only the last of these is parsed via
the new `TutorialGeometryPlanCodec`.

**Client-side trigger, added because TF-3's own title says "Production."**
TF-2 explicitly deferred deciding when to call `plan-tutorial-geometry`
from the app. This phase adds `TutorialRepository.planGeometry` (mirrors
`generateStepResult`'s shape exactly: invoke → parse `{session: ...}` via
the new `TutorialSessionDto.fromResponse` → reload steps → hydrate) and
`TutorialSessionController.activateGuidelines()`, called opportunistically
from `TutorialEntryPage.build()` via `WidgetsBinding.instance.addPostFrameCallback`
every time it renders a session with steps — the same pattern
`PreviewResultPage` already uses for `loadSavedStatus`. Safe to call on
every build because `activateGuidelines()` is itself the guard: no-op if
no session, if a geometry plan already exists, if a session-level
operation is in flight, or if a step is generating. Deliberately does
**not** go through `_run`/`_lastRun` — a session that already works
(guidelines or not) must never flip to a session-level failure state just
because guideline planning itself failed; a failure here is swallowed
silently, mirroring `generateStep`'s "otherwise fully functional" posture
for a single failed step.

**"Step 1/Step N sources" and "Result has no Flutter overlay" were already
true, unchanged by this phase.** `TutorialStepViewer`'s
`step.placementImageUrl ?? (index == 0 ? originalImageUrl : previousStep.resultImageUrl)`
and `generate-tutorial-step`'s identical server-side `cumulativePath`
logic (ST-9) already implement "Step 1 = original selfie, Step N = Step
N-1's Result" — TF-3 touches neither. `ComparisonSlider` has never had a
`rightOverlay` parameter, so a Flutter overlay on the Result side is not a
behavior to prevent, it is a widget that structurally cannot exist; a new
test (`placement_result_comparison_test.dart`) makes this explicit rather
than leaving it merely implied by reading the source.

**Files created**: `domain/entities/tutorial_geometry_plan.dart`,
`data/models/tutorial_geometry_plan_codec.dart`,
`domain/services/tutorial_geometry_activation.dart`. Tests:
`tutorial_geometry_plan_test.dart`, `tutorial_geometry_plan_codec_test.dart`,
`tutorial_geometry_activation_test.dart`, `placement_result_comparison_test.dart`,
plus extensions to `tutorial_session_dto_test.dart`,
`supabase_tutorial_repository_test.dart`, `tutorial_session_controller_test.dart`.

**Files modified**: `tutorial_session.dart` (three new nullable fields —
`geometryPlan`/`geometryPlanVersion`/`geometryModel`, additive);
`tutorial_session_dto.dart` (`fromRow` now also parses geometry and applies
activation; new `fromResponse`); `tutorial_repository.dart`/
`tutorial_remote_data_source.dart`/`supabase_tutorial_repository.dart`/
`unavailable_tutorial_repository.dart` (one new method each, `planGeometry`/
`invokeGeometryPlan`, additive — every existing method's behavior
unchanged); `tutorial_session_controller.dart` (one new method,
`activateGuidelines`, additive); `tutorial_entry_page.dart` (one new
post-frame-callback block, additive). `TutorialStepViewer`,
`TutorialPlacementOverlayLayer`, `PlacementResultComparison`,
`TutorialPlacementSourceResolver`, and
`PersonalizedTutorialOverlayAccuracyValidator` are all unchanged — the
existing renderer/source-resolution/validator code is exactly what makes
this phase "wire real data into what already exists" rather than "build a
second rendering pipeline." Standard Face Analysis, Recommendation, the
existing final preview, and My Makeup Kit remain untouched.

**Correction, from the runtime bug-fix pass immediately below**:
`TutorialPlacementOverlayLayer`/`PlacementResultComparison` did turn out to
need a change once real Gemini geometry started flowing through them — see
that section for why "unchanged" above was only true until real (non-empty)
overlay data actually existed to expose the bug.

## Runtime bug fix: overlays still invisible on a real device after TF-3

TF-3 was unit-tested (224 passing tests) but never visually verified on a
real device — a real fresh tutorial still showed no guidelines at all on
Foundation and Concealer. Two real, independent gaps were found; one is
fixed here, one could not be verified or fixed from this environment and is
recorded as a blocker.

**Fixed: `TutorialPlacementOverlayLayer` assumed its own box == the whole
source image, which is only sometimes true.** `PlacementResultComparison`
renders the Placement image with `PrivateImage`'s default `fit:
BoxFit.cover` inside `ComparisonSlider`'s fixed `AspectRatio(aspectRatio: 3
/ 4)` box. `BoxFit.cover` scales the source image up until it fills the box
on *both* axes, then crops whichever axis overflows, centered. Selfies are
only validated to fall within a broad 0.4–2.5 width/height ratio
(`LocalImageValidation`, `scan/domain/entities/`) — never cropped or
resized to any fixed ratio before upload (confirmed: no `image_cropper` or
equivalent anywhere in `lib/features/scan/`) — so a typical raw
phone-camera capture (often far taller than 3:4) gets its top and bottom
significantly cropped when displayed. `TutorialGeometryActivation`'s
overlay points are normalized against the *whole* source image (matching
`plan-tutorial-geometry`'s own prompt contract), but the painter was
mapping them directly onto the box's own edges — i.e. treating the *crop*
as if it were the *whole image*. A category whose real placement happens
to sit outside the visible cropped window (a very plausible outcome for
Concealer's forehead-center zone, or any near-top/near-bottom placement,
on a tall raw photo) would be pushed off-screen and never paint at all,
independent of confidence or correctness of the geometry data itself.

Fix: `TutorialCoverTransform` (new, in `tutorial_placement_overlay_layer.dart`)
reproduces Flutter's own `BoxFit.cover` scale-and-center math as a small,
independently unit-tested pure class (no widget pump, no image mocking
needed — see its tests in `tutorial_placement_overlay_layer_test.dart`).
`TutorialPlacementOverlayLayer` became a `StatefulWidget` that optionally
resolves the same image URL its sibling Placement image renders (via a
plain `ImageStream`/`ImageStreamListener` — no new package) to learn the
source image's real intrinsic size, then uses `TutorialCoverTransform` to
map each normalized point onto the correct visible pixel instead of the
naive full-box assumption. `imageUrl` is optional and the fallback (naive
mapping) is preserved exactly when it's absent or not yet resolved — a
deliberate degrade-gracefully choice, never a crash, and it's why every
pre-existing test in `tutorial_placement_overlay_layer_test.dart` (which
never passes `imageUrl`) kept passing completely unmodified.
`PlacementResultComparison` now passes `imageUrl: placementImageUrl`
through — the one call site that needed updating.

**Not fixed, not verifiable from this environment: whether the TF-2/TF-3
Supabase backend (the `20260816000100_tutorial_geometry_plan.sql`
migration and the `plan-tutorial-geometry` Edge Function) has actually been
deployed to the live project.** No Supabase CLI is installed in this
environment (confirmed: `supabase --version` → command not found, same as
the Deno limitation already recorded for TF-2), and this session has no
sanctioned way to query the live database or invoke the live Edge Function
directly. If either piece is undeployed, `TutorialSessionController.activateGuidelines()`'s
call to `TutorialRepository.planGeometry` fails — by design, that failure
is swallowed silently (so a guideline-planning problem never turns a
working tutorial into a broken one), which means this exact failure mode
produces **zero overlays and zero visible errors**, indistinguishable from
the coordinate bug above from a screenshot alone. Diagnostic logging (`[TutorialGeometry]`
prefix, `debugPrint`, no URLs/paths/secrets ever logged) was added to
`activateGuidelines()` specifically so the next real run makes this
observable instead of silent: whether planning was attempted, whether it
succeeded or failed (and with what failure code), how many categories a
returned plan covered, and per-step category/confidence/overlay-count.
Whoever next runs the app on a real device should watch the Flutter console
for `[TutorialGeometry]` lines while opening a tutorial.

**Stale sessions need no special handling — confirmed, not just assumed.**
A session created before TF-2/TF-3 existed has `geometryPlan == null` for
exactly the same reason a brand-new session does immediately after
creation (the column/plan simply doesn't exist yet) — `activateGuidelines()`'s
only gate is that null check, so a stale session is planned exactly like a
fresh one, no separate recovery path needed. A dedicated test
(`tutorial_session_controller_test.dart`, "a stale session created before
TF-2/TF-3 existed... triggers planning exactly like a brand-new one") uses
a step with no `personalizedSpec`/`placementMetadata` at all — the exact
shape a genuinely pre-TF-1 row has — to prove this concretely rather than
by inspection alone.

**Files modified this pass**: `tutorial_placement_overlay_layer.dart` (the
coordinate fix), `placement_result_comparison.dart` (passes `imageUrl`
through), `tutorial_session_controller.dart` (diagnostic logging only, no
behavior change). **Files created**: none. **Tests added**:
`TutorialCoverTransform` unit tests (identity case, tall-image crop,
wide-image crop, exact-edge mapping) in
`tutorial_placement_overlay_layer_test.dart`; one new stale-session test in
`tutorial_session_controller_test.dart`. `flutter analyze`/`flutter test`/
`dart format` all clean; `flutter build apk --debug` succeeds. No device
was available in this environment to install and visually verify the
result (confirmed via `flutter devices`: Windows desktop and two web
targets only, no Android device or emulator) — the fix is proven correct
by unit-testing the exact transform math Flutter's own `Image` widget uses,
not by an on-device screenshot. Whoever has the physical device from the
bug report should rebuild (`tool/run_dev.ps1`) and re-check Foundation and
Concealer before this is called visually verified.
