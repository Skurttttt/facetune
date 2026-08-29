# V3-10 — Standard Preview + History Integration

**Branch:** `feature/step-by-step-tutorial-v3`
**Date:** 2026-08-28
**Preconditions:** V3-6B, V3-7, V3-8, V3-9 complete
**Status:** Complete **as corrected by V3-10F**. **No remote mutation, nothing deployed, nothing applied.**

> **CORRECTION — 2026-08-28.** This report was first published claiming the
> preview result screen wired the tutorial action. It did not. `ResultActions`
> gained the `onOpenTutorial` slot, and no call site ever passed it, so the
> "Step-by-step tutorial" button never rendered in the running app. The defect
> and its fix are recorded in **§11 — V3-10F**. A device test then found that
> the tutorial could stay on its loading spinner forever; that defect, its
> timeout and error-boundary fix, and the corrected remote-deployment status
> are recorded in **§12 — V3-10F2**. The inaccurate claims below are
> marked in place rather than quietly rewritten. Everything else in this report
> — the resolver, the route, the entry page, the trust boundary — was and is
> accurate.

---

## 1. What this phase did

Made the tutorial reachable — and made reaching it safe.

Until now a V3 session was created from a request the **client** assembled:
the analysis id, the recommendation id, the selected style, and the canonical
preview's **storage path**. Every one of those is a server fact, and a caller
that can choose them can aim a tutorial at something it was never meant to
teach. V3-8 deferred routing to this phase precisely because wiring a screen to
that API would have shipped the hole.

That API is gone. The client now names **one premium preview** and nothing
else. Everything the tutorial is built from is resolved in the database, under
RLS, in one statement.

---

## 2. Server-side resolution

New migration `20260828000200_tutorial_v3_entry.sql` adds
`open_tutorial_v3_session(p_generated_image_id uuid, p_kit boolean)`:

```text
p_generated_image_id ──→ generated_images / kit_generated_images
                            ├── analysis_id
                            ├── recommendation_id / kit_recommendation_id
                            └── storage_path
                         recommendations / kit_makeup_recommendations
                            └── makeup_style          (the selected look)
                         tutorial_v3_sessions
                            └── reuse, or insert
```

- **SECURITY INVOKER**, `search_path` pinned, `anon` revoked. A preview
  belonging to another account is invisible, so it is indistinguishable from
  one that does not exist.
- **No `user_id` predicate anywhere.** Ownership is RLS's answer, not a
  filter a caller could influence.
- **The derived path is still checked**: it must sit in the mode's own folder
  (`/generated/` vs `/kit-generated/`, per V3-9), must not be under
  `/original/`, must not contain `..`, and must start with the caller's own
  `{uid}/analyses/{analysis}/` prefix. Defence in depth — the path was written
  by the preview generator, so this should always hold.
- **A missing preview or recommendation raises**, never invents.

The migration is purely additive: no table, column, policy or RLS change, and
no V1/V2 object touched. Asserted.

---

## 3. Reopen semantics

| Case | Behaviour |
|---|---|
| A session already exists for this preview | Returned as-is. The canonical preview is the natural key, so one preview has exactly one tutorial |
| That session is at an unreadable plan version | **Still returned.** The lookup is deliberately *not* filtered by `plan_version`, so an incompatible session is reported as incompatible rather than silently duplicated by a second tutorial for the same target |
| Ready geometry exists | Reused — V3-7's coordinator reads the persisted row before any call, and only re-maps a document whose schema version this build cannot read |
| No session exists | One is created, `status = 'planning'`, `total_steps = 0` |

Nothing here re-maps on revisit: opening a finished tutorial spends no quota
and makes no model call.

---

## 4. Routing

| Piece | Detail |
|---|---|
| Route | `/tutorial/:canonicalImageId`, with `?kit=true` selecting the Kit chain |
| Builder | Reads exactly two things from the request — the path parameter and the `kit` query — asserted by counting `state.` accesses |
| Entry page | `TutorialV3EntryPage` opens the session after the first frame, then renders `TutorialV3Page`, which stays purely presentational |
| Standard entry | "Step-by-step tutorial" on the preview result screen, linking to `AppConstants.tutorialPathFor(previewId)`. **As first published this was false — the call site was never wired. True as of V3-10F (§11)** |
| History entry | History already restores a completed look into the preview result screen, so the same action serves it. The tutorial is identified by `preview.id`, which history read from the persisted row — no history UI change was needed. **Also only true as of V3-10F, since it depends on the same call site** |

A hand-edited link can still only name a preview, and only one the caller
already owns.

---

## 5. Files changed

| File | Change |
|---|---|
| `supabase/migrations/20260828000200_tutorial_v3_entry.sql` | **New** — the entry resolver |
| `lib/.../domain/repositories/tutorial_v3_repository.dart` | `TutorialV3SessionRequest` → `TutorialV3EntryPoint`; `getOrCreateSession` → `openSession` |
| `lib/.../data/data_sources/tutorial_v3_remote_data_source.dart` | `openSession` RPC; translates `P0002` / `28000` / `22023` into domain failures |
| `lib/.../data/repositories/supabase_tutorial_v3_repository.dart` | `openSession`; client-side request validation removed; read-side folder integrity check |
| `lib/.../data/repositories/unavailable_tutorial_v3_repository.dart` | Updated |
| `lib/.../presentation/controllers/tutorial_v3_session_controller.dart` | `open(TutorialV3EntryPoint)` |
| `lib/.../presentation/pages/tutorial_v3_entry_page.dart` | **New** — the routed entry |
| `lib/core/constants/app_constants.dart` | `tutorialRoute`, `tutorialPathFor` |
| `lib/app/router/app_router.dart` | Route registration |
| `lib/features/results/presentation/widgets/result_actions.dart` | Optional `onOpenTutorial` action |
| `lib/features/preview/presentation/pages/preview_result_page.dart` | ~~Wires the action~~ — **this line was wrong; the file was never touched in V3-10. Wired in V3-10F (§11)** |
| `test/.../tutorial_v3_entry_contract_test.dart` | **New** — 21 tests |
| `test/.../tutorial_v3_entry_page_test.dart` | **New** — 7 tests |
| `test/.../supabase_tutorial_v3_repository_test.dart` | Fake `open_tutorial_v3_session`; client-validation tests replaced with entry tests |
| `test/.../tutorial_v3_session_controller_test.dart`, `test/.../tutorial_v3_page_test.dart` | Fakes updated |

---

## 6. Tests and results

*(The V3-10 run. See §11 for the corrected totals after V3-10F.)*

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` | — | **0 issues** |
| `flutter test` | **789** | **all pass** (was 761 after V3-9) |
| `deno test .../plan-tutorial-v3/` | 44 | all pass |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 | all pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 | all pass |
| `git diff --check` | — | clean |

### Required checklist coverage

| Required test | Where |
|---|---|
| Standard entry | repository "the client names a preview and nothing else"; entry page "it opens the tutorial for the preview it was routed to"; entry contract "the route carries only the preview id and the chain". **None of these touched the production call site — this is the gap that let the defect through. Closed in §11** |
| History entry | entry contract routing group + `tutorialPathFor`; history reaches the same action through the preview result screen it already restores into. **Same gap; closed in §11** |
| Ownership | entry contract "SECURITY INVOKER, so RLS decides what is visible", "anonymous execution is revoked", "it never filters ownership by a supplied user id" |
| Missing recommendation / final preview | entry contract "a missing preview or plan is reported, never invented"; repository "a preview that does not exist is not found", "a preview from the other chain is not found"; entry page "a failure to open is reported inside the screen" |
| Geometry cache reuse | V3-7 coordinator + controller suites (persisted geometry used without a call, revisiting reads the cache, moving to a prefetched step is instant); entry contract "reuse is not filtered by plan version" |
| Incompatible-version behavior | entry contract "reuse is not filtered by plan version"; controller "a session this build cannot read is reported, never guessed at"; coordinator "persisted geometry from another schema is re-mapped" |

---

## 7. A related gap closed on the way

`open_tutorial_v3_session` *raises* rather than returning a status, so its
Postgres error codes would have escaped the controller's `on TutorialV3Failure`
handling and surfaced as an unhandled crash. The data source now translates
`P0002`, `28000` and `22023` into domain failures, and lets anything it does
not recognise propagate unchanged — a failure this layer does not understand
must not be dressed up as a tidy domain error.

A second, smaller one: `didUpdateWidget` cannot modify a provider, because it
runs inside the build phase. Routing to a different preview now defers the
reopen to the next frame, exactly as `initState` does.

---

## 8. Risks and limitations

| # | Item | Severity | Notes |
|---|---|---|---|
| 1 | **Exposed legacy `service_role` credential** | **HIGH — UNRESOLVED** | Carried forward from V3-6A.2. Not touched. **Release is blocked until it is rotated/revoked outside Claude Code.** |
| 2 | ~~Two migrations unapplied; mapper undeployed~~ | **Superseded** | **This row was stale.** Verified since: `20260828000100_tutorial_v3_geometry.sql` is **APPLIED**, `plan-tutorial-v3` is **ACTIVE**, `map-tutorial-v3-guideline-geometry` is **ACTIVE**. Only `20260828000200_tutorial_v3_entry.sql` remains outstanding — see §12 |
| 3 | The Kit entry has no dedicated button | Medium | The route and the resolver support `?kit=true` and are tested, but no Kit screen links to it yet. The Kit result surface is the natural host; it was left alone to honour "no core Kit rewrite". **As first published this item understated the situation: at that point neither entry had a button** |
| 4 | The read-side folder check can refuse a legacy row | Low | A session written before the entry resolver could point at the other chain's preview. It is refused with a clear message rather than opened against the wrong look. No such rows exist yet — both V3 tables hold 0 rows |
| 5 | Four client-side validation tests were removed | Low | They exercised checks on a request shape that no longer exists. The properties they covered — mode/recommendation agreement, folder correctness — are now enforced in the RPC and covered by the entry contract tests, which is strictly stronger |
| 6 | Entry is not rate-limited | Low | `open_tutorial_v3_session` spends no AI quota; it reads two rows and may insert one. Planning and mapping remain quota-bounded |

---

## 9. Security impact

- **The client's trust surface shrank to one identifier.** `analysisId`,
  `recommendationId`, `kitRecommendationId`, `selectedStyleCode` and
  `storagePath` are no longer accepted from the client anywhere in V3 — the
  type that carried them was deleted, which is asserted.
- **Resolution happens under RLS.** No `SECURITY DEFINER`, no `service_role`,
  no `user_id` filter. A preview or recommendation the caller does not own is
  invisible, so it reads as "not found" rather than "forbidden".
- **The derived path is still validated** for folder, `/original/`, traversal
  and owner prefix before it is stored.
- **A stored session that points at the wrong chain is refused on read**, so a
  row written by an older build cannot render the wrong final look.
- **Deep links are safe by construction**: the URL can name only a preview,
  and only one the caller already owns.
- No RLS change, no table or policy change, no deployment, no secret read or
  mutated.

---

## 10. Acceptance status

| Criterion | Status |
|---|---|
| Analysis resolved server-side | Met |
| Selected style resolved server-side | Met |
| Recommendation resolved server-side | Met |
| Canonical final preview resolved server-side | Met |
| Ownership resolved server-side | Met |
| No arbitrary client URLs or paths trusted | Met |
| Reuse a valid V3 session | Met |
| Reuse compatible ready geometry | Met |
| Reject incompatible old sessions / geometry versions | Met |
| New session only through the supported flow | Met |
| No remapping every visit when compatible geometry is ready | Met |
| Required tests written and passing | Met **after V3-10F** — the V3-10 suite passed while the feature was unreachable |
| The tutorial is reachable from the app | **Not met at V3-10. Met at V3-10F (§11)** |

---

## 11. V3-10F — the missing call site

### The defect

`ResultActions` gained an optional `onOpenTutorial` and rendered the button
only `if (onOpenTutorial != null)`. **No call site ever passed it.**
`preview_result_page.dart` was never modified in V3-10 — it does not appear in
that phase's `git status` — so the parameter was null everywhere and the button
never rendered. The tutorial was reachable only by typing the URL.

`grep -rn "onOpenTutorial" lib/` returned three hits, all inside the widget's
own declaration and use. That is the whole evidence.

### Why the tests missed it

Four suites covered four pieces — the route constant, `TutorialV3EntryPage`,
the `open_tutorial_v3_session` RPC, and `ResultActions` — and every one of them
was true. The `ResultActions` widget test constructed the widget **inside the
test**, supplying its own arguments, so it proved the widget could render a
button nobody asked it to render. Nothing pumped the production widget tree.

A test that builds its own subject cannot prove the app builds it that way.
That is the lesson worth carrying into the remaining phases.

### The fix

`onOpenTutorial` is threaded through the existing hierarchy:

```text
PreviewResultPage  (success branch, links already verified)
  → _ResultContent      required VoidCallback onOpenTutorial
    → _ResultDetails    required VoidCallback onOpenTutorial
      → ResultActions   onOpenTutorial: …
        → context.push(AppConstants.tutorialPathFor(preview.id))
          → /tutorial/:canonicalImageId
            → TutorialV3EntryPage → open_tutorial_v3_session
```

Three decisions worth stating:

- **Required, not optional, on the two private widgets.** That branch only
  renders for a preview whose analysis, recommendation and style links are
  already verified, so the target is always valid. Making the parameter
  required turns "someone drops the wiring" into a compile error rather than a
  silently missing button — the exact failure mode being corrected.
- **`push`, not `go`,** so back returns to the result the user came from.
- **`preview.id` and nothing else.** The V3-10 trust boundary is untouched: no
  analysis id, no recommendation id, no storage path, no signed URL crosses
  into the route, and `TutorialV3SessionRequest` stays deleted.

The action is absent, correctly, in the two states that have no usable preview:
"Result links unavailable" and "Result unavailable" render no `ResultActions`
at all. No id is fabricated or substituted.

### History

Unchanged and unchanged deliberately. `HistoryPage._open` restores the
analysis, style, recommendation and the persisted `GeneratedPreview`, then
pushes `AppConstants.previewRoute` — the same screen. It therefore inherits the
same action, resolving the same persisted `generated_images.id`. There is no
separate history tutorial implementation, and a test asserts there is none.

### Kit

Out of scope, per the phase instruction. No Kit surface links to the route yet;
`?kit=true` remains supported and tested but unlinked. Carried forward as
risk #3 above.

### Files changed

| File | Change |
|---|---|
| `lib/features/preview/presentation/pages/preview_result_page.dart` | The actual fix — callback constructed and threaded to `ResultActions` |
| `test/features/preview/preview_result_tutorial_entry_test.dart` | **New** — 12 tests against the production widget tree |
| `docs/tutorial_v3/V3-10_STANDARD_PREVIEW_HISTORY_ENTRY_REPORT.md` | This correction |

No other file changed. No migration, no Edge Function, no server behaviour.

### The regression test

`test/features/preview/preview_result_tutorial_entry_test.dart` pumps the real
`PreviewResultPage` under a real `GoRouter` whose tutorial route is registered
at `AppConstants.tutorialRoute` and records the location it receives. Removing
`onOpenTutorial` from the `ResultActions(...)` call was tried, and **7 of the
12 tests fail** — including `the production call site supplies the callback`,
which reads `onOpenTutorial` off the `ResultActions` instance the app actually
built, and `tapping it navigates to the tutorial route`, which asserts the
pushed location equals `AppConstants.tutorialPathFor(preview.id)`.

The suite also asserts the pushed location contains none of the analysis id,
the recommendation id, either storage path, or `http`.

### Verification after V3-10F

| Check | Result |
|---|---|
| `dart format` (V3-10F files) | clean, 0 changed |
| `flutter analyze` | **0 issues** |
| `flutter test` | **801** pass, 0 fail (789 + 12) |
| `deno test .../plan-tutorial-v3/` | 44 pass |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 pass |
| `git diff --check` | clean (exit 0) |

Two notes on how those were run, so the next phase is not surprised:

- **`deno` is not on PATH in this environment.** All three suites were run as
  `npx -y deno@2 test …` (deno 2.9.6). No TypeScript or SQL changed in V3-10F,
  so these suites are unaffected by the fix; they were run to confirm that.
- **`dart format .` reformatted 17 files that V3-10F does not touch** — older
  V3 sources committed under a previous formatter style. That churn was
  reverted with `git checkout --` so this correction stays reviewable; the two
  V3-10F files are format-clean. Those 17 files remain unformatted in `HEAD`
  and will resurface on the next repo-wide `dart format .`. Left alone
  deliberately, under "no unrelated cleanup" — worth a dedicated pass later.

---

## 12. V3-10F2 — the tutorial that never stopped loading

Found by running the app on a device: tapping "Step-by-step tutorial" left the
screen on *"Opening your tutorial…"* indefinitely. Not slow — permanent.

### Defect 1 — no error boundary

Every asynchronous path in `TutorialV3SessionController` caught
`TutorialV3Failure` and nothing else:

```dart
} on TutorialV3Failure catch (failure) {
  _fail(failure, epoch);
}
```

`open_tutorial_v3_session` is not applied yet, so PostgREST answered with a
`PostgrestException` — deliberately rethrown unchanged by V3-10's translation,
which was right on its own but left nothing above to catch it. The exception
escaped `open()`, `_fail` never ran, the state stayed `opening`, and
`TutorialV3Page` renders `opening` as a bare spinner. **The same hole existed
on every other path**: reopen, planning, image signing, geometry mapping and
prefetch. Any network drop or malformed row would have done it too — the
missing migration only made it certain.

### Defect 2 — no timeout

`grep -rn "timeout(" lib/features/tutorial_v3/` returned nothing, while
`result_actions_controller.dart` bounds comparable work at 25s and
`saved_looks_controller.dart` at 30s. A call that never answered spun forever
even with the boundary in place.

### Why the earlier tests missed both

Every fake in the V3 suites threw `TutorialV3Failure` — the type the controller
already handled. The tests proved the app handles failures it was designed for,
and never asked what happens to one it was not. Same shape as the V3-10F
defect: **the tests kept exercising the parts that were already right.**

### The fix

One boundary, `_bounded`, wrapping every awaited operation. Three outcomes and
no fourth: the value; the original `TutorialV3Failure` **rethrown untouched**,
so a server's own wording, kind and retry verdict survive; or a failure this
method constructs, for a timeout or for anything else.

Converting at the orchestration boundary — rather than adding Postgres-code
branches to the data sources — keeps the data layer authoritative about what it
understands and silent about what it does not.

| Operation | Timeout |
|---|---|
| `openSession`, `findSessionById`, `loadImages` | `session` — **20s** |
| `plan`, `ensureGeometry`, `prefetch` | `ai` — **150s** |

`TutorialV3Timeouts` carries both. 150s is not arbitrary: the Edge Function
allows **two Gemini attempts at 60s each plus backoff**, so a healthy but slow
generation can legitimately take just over two minutes. A shorter client
timeout would abort work the server was about to finish, spend the quota
anyway, and look exactly like a bug. A test asserts `ai > 121s`.

Both are injectable, so the timeout path is tested in milliseconds while
production keeps its defaults.

### What is sanitized

The user sees a fixed string. The exception's own text never reaches the
screen — it can carry SQL, RPC names, storage URLs or tokens. Diagnostics are
debug-only and record the **type and call site only**, never the message,
matching `supabase_initializer.dart`.

### Race safety

Unchanged and preserved: every write still goes through the epoch check, and
the new failures are raised inside the same captured-epoch paths. A timeout
from an abandoned open cannot fail a tutorial that has since opened — asserted
in both directions.

### Prefetch

`prefetch` was documented as never completing with an error but caught only
`TutorialV3Failure`. It now swallows everything, and `_prefetchAfter` catches
again and bounds the wait. A background miss leaves the cache cold, so the step
is mapped normally on arrival — V3-7's behaviour, now actually guaranteed.

### A third defect found on the way

`retryOpen` read `state.snapshot?.sessionId` and returned when it was null —
which is exactly the case after a failed open. **"Try again" rendered and did
nothing.** The controller now remembers its entry point and reopens from it.

### Files changed

| File | Change |
|---|---|
| `lib/.../domain/services/tutorial_v3_timeouts.dart` | **New** — the two named timeouts and their reasoning |
| `lib/.../presentation/controllers/tutorial_v3_session_controller.dart` | `_bounded` boundary on every await; catch-alls on `open`/`reopen`/`_prefetchAfter`/cache read; `retryOpen` entry fallback; sanitized debug logging |
| `lib/.../domain/services/tutorial_v3_geometry_coordinator.dart` | `prefetch` swallows every exception, as documented |
| `test/.../tutorial_v3_loading_recovery_test.dart` | **New** — 21 tests |
| `test/.../tutorial_v3_page_test.dart` | +2: the converted failure renders, and its retry works |

No migration, Edge Function, schema, planner, geometry, Kit or preview change.

### Regression tests

Removing the boundary (both layers) fails **9 of 21**. Removing `.timeout(...)`
hangs the suite and fails **11**. The two layers are deliberately redundant on
the open path — `_bounded` converts, and the outer `catch` is the net for any
future unbounded code — so removing either one alone does not regress. That is
defence in depth, and it is stated here rather than implied.

### Verification

| Check | Result |
|---|---|
| `dart format` (V3-10F2 files) | clean, 0 changed |
| `flutter analyze` | **0 issues** |
| `flutter test` | **824** pass, 0 fail (801 → 824) |
| `deno test .../plan-tutorial-v3/` | 44 pass |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 pass |
| `git diff --check` | clean (exit 0) |

Deno was again run via `npx -y deno@2` (not on PATH). Repo-wide
`dart format .` churn on 17 unrelated files was reverted again, as in V3-10F.

### Remote state

| Item | Status |
|---|---|
| `20260828000100_tutorial_v3_geometry.sql` | **APPLIED** |
| `plan-tutorial-v3` | **ACTIVE** |
| `map-tutorial-v3-guideline-geometry` | **ACTIVE** |
| `20260828000200_tutorial_v3_entry.sql` | **NOT VERIFIED FROM HERE** — no remote read was performed. The device symptom is consistent with it being unapplied, but that is inference, not verification |

---

## 13. V3-10F3 — diagnosing the real device failure

With `20260828000200` applied, the device stopped hanging and started failing
fast:

```text
Premium preview → Step-by-step tutorial → ~1s
  "This tutorial could not be opened"
  "The tutorial service is temporarily unavailable."
```

### The failing layer, proven rather than inferred

That sentence is not written anywhere in Dart — asserted by a test that scans
every `.dart` file under `lib/`. It exists in exactly three TypeScript files:
`plan-tutorial-v2` (not in this flow), `map-tutorial-v3-guideline-geometry`,
and `plan-tutorial-v3`.

The geometry mapper is excluded by the screen itself: a geometry failure sets
`geometryPhase: failed` and leaves `phase: ready`, so the tutorial stays
readable. The device showed **"This tutorial could not be opened"**, which is
`_Failure`, rendered only for `TutorialV3Phase.failed`.

So the message came from `plan-tutorial-v3/gemini_client.ts`, from this branch:

```ts
const transient = response.status === 429 || response.status >= 500;
...
throw new FunctionFailure(
  response.status === 429 ? 503 : 502,
  response.status === 429 ? "gemini_rate_limited" : "gemini_upstream_error",
  "The tutorial service is temporarily unavailable.",
  transient,
);
```

Reaching it requires `fetch` to have **returned a response** that was neither
ok nor 404. That single fact settles the whole chain:

| Stage | Verdict |
|---|---|
| Route identifier | Correct — a wrong id raises `P0002`, a different message |
| `open_tutorial_v3_session` | **Succeeded** |
| Session created without a plan | Yes — otherwise the planner is never invoked |
| `plan-tutorial-v3` invoked | **Yes** |
| Gemini contacted | **Yes, and it answered** — with an error status |

### Route identifier

| | |
|---|---|
| **Expected** | `generated_images.id` |
| **Actual** | `GeneratedPreview.id` ← `previewResponse.preview.id = row.id`, the row from `generated_images.insert(...).select("*").single()` |

Match. Corroborated independently: a wrong identifier would have been refused
by the resolver as `P0002` → *"The final look for this tutorial is no longer
available."*, which is not what appeared.

### RPC contract, field by field

| | SQL | Dart |
|---|---|---|
| Name | `public.open_tutorial_v3_session` | `'open_tutorial_v3_session'` |
| Param 1 | `p_generated_image_id uuid` | `'p_generated_image_id': canonicalImageId` |
| Param 2 | `p_kit boolean` | `'p_kit': kit` |
| Returns | `uuid` scalar | `'$id'` |

No mismatch. No enum, folder, ownership or compatibility rejection was
involved — all of those raise before the planner is ever reached.

### Did Gemini execute?

**FAILURE OCCURS DURING GEMINI PLANNING.**

### Root cause

**Upstream, not local.** Gemini refused the planner's request. Given the
account's negative prepaid balance, a 429 `RESOURCE_EXHAUSTED` — surfacing as
`gemini_rate_limited` — is the expected shape, but the exact code is not
recorded anywhere the device could show, so this report does not assert which
of the two it was.

**It can be confirmed right now without changing anything**, because the
function already logs it server-side:

```text
[plan-tutorial-v3] Gemini request failed status=<429|5xx> attempt=<n>
[plan-tutorial-v3] request_failed code=<gemini_rate_limited|gemini_upstream_error>
```

Read them with `npx -y supabase functions logs plan-tutorial-v3`, or in the
dashboard. `status=429` confirms billing; `status=5xx` means a genuine Gemini
outage and nothing to do but retry.

### The local defect that *was* proven

**The failure was invisible.** V3-10F2's boundary logs only *unexpected*
exceptions. This failure was translated correctly by the function data source,
carried correctly by the boundary, and reported correctly to the user — and
logged by nobody. A correctly handled failure left an empty console, which is
why the root cause could not be read off the device.

Three debug-only breadcrumbs, all `kDebugMode`-guarded:

| Layer | Records |
|---|---|
| `tutorial_v3_function_data_source.dart` | `status`, server `code`, derived `kind`, `retryable` |
| `tutorial_v3_remote_data_source.dart` | the entry RPC's SQLSTATE only |
| `tutorial_v3_session_controller.dart` | stage (`openSession` / `plan` / `ensureGeometry` / `loadImages`), `kind`, `retryable` |

The stage label is what answers "before, during, or after the RPC". Nothing
logs a token, header, request, response body, signed URL or exception message —
asserted by a test that reads the log methods and rejects those identifiers.

**No production behaviour changed.** User-facing messages, kinds, retry
verdicts and state transitions are byte-for-byte as they were.

### Remote change required

**No migration and no function change.** The chain is correct end to end. What
is required is outside this repository:

1. **Restore the Gemini prepaid balance** on the API key `plan-tutorial-v3`
   uses, then retry.
2. **Confirm from the function logs** which code it was, per above.

Not applied, not deployed, nothing rotated.

**V3-10 is complete as corrected. STOPPING HERE. V3-11 is not authorized and has not been started.**
