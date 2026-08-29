# V3-7 — Hybrid Geometry Mapping + Prefetch

**Branch:** `feature/step-by-step-tutorial-v3`
**Date:** 2026-08-28
**Preconditions:** V3-6R = PASS, V3-6B = complete
**Status:** Implementation complete. **No remote mutation, nothing deployed, nothing applied.**

---

## 1. What this phase built

The client-side orchestration that makes guideline geometry responsive without
mapping the whole tutorial upfront.

```text
open ─→ session ─→ plan (only when missing) ─→ show step 1
                                                  │
                                     current geometry — cache first
                                                  │
                                     prefetch step 2 in background
```

The **plan** is generated and persisted in full upfront: it is one call, and
every step's instruction text has to be readable immediately. **Geometry** is
not: it is one model call per step, so it is acquired for the step being read
and, speculatively, for the one after it.

No UI screen was built. That is V3-8.

---

## 2. Files changed

### New — domain

| File | Role |
|---|---|
| `domain/repositories/tutorial_v3_geometry_mapper.dart` | Port: map one step's geometry. Identifiers only. |
| `domain/repositories/tutorial_v3_planner.dart` | Port: plan and persist a tutorial. Session id only. |
| `domain/services/tutorial_v3_geometry_cache.dart` | In-memory validated-geometry store, keyed by session + step |
| `domain/services/tutorial_v3_geometry_coordinator.dart` | `tutorialV3PrefetchDepth = 1`, reuse, deduplication, prefetch |

### New — data

| File | Role |
|---|---|
| `data/data_sources/tutorial_v3_function_data_source.dart` | The only two Edge Function calls; maps `{error:{code,message,retryable}}` → `TutorialV3Failure` |
| `data/repositories/supabase_tutorial_v3_geometry_mapper.dart` | Invokes the mapper, revalidates the document client-side |
| `data/repositories/supabase_tutorial_v3_planner.dart` | Invokes the planner, discards the body |
| `data/repositories/unavailable_tutorial_v3_repository.dart` | Stand-in when Supabase is unconfigured |
| `data/repositories/unavailable_tutorial_v3_services.dart` | Planner + mapper stand-ins |
| `data/providers/tutorial_v3_providers.dart` | Riverpod wiring |

### New — presentation

| File | Role |
|---|---|
| `presentation/controllers/tutorial_v3_session_state.dart` | `TutorialV3Phase`, `TutorialV3StepGeometryPhase`, immutable state |
| `presentation/controllers/tutorial_v3_session_controller.dart` | The flow: open / reopen / goToStep / next / previous / retry |

### New — tests

| File | Tests |
|---|---|
| `test/.../tutorial_v3_geometry_cache_test.dart` | 10 |
| `test/.../tutorial_v3_geometry_coordinator_test.dart` | 27 |
| `test/.../tutorial_v3_session_controller_test.dart` | 24 |

### Modified

| File | Change |
|---|---|
| `test/.../tutorial_v3_fixtures.dart` | `testSession`, `testStep`, `loadedSession` helpers |
| `test/.../tutorial_v3_geometry_mapper_contract_test.dart` | +5 tests pinning the Flutter request bodies to the function's trust boundary |

---

## 3. Architecture decisions

### 3.1 Two domain ports, not a data-layer dependency

The coordinator is domain logic, so it depends on
`TutorialV3GeometryMapper` — a domain port — rather than on the Edge Function
data source. The first draft had the coordinator importing
`data/data_sources/...`, which would have been the **only** domain→data import
in the entire codebase. It was replaced with the port before anything was
built on it.

`TutorialV3Planner` is a second port for the same reason. Both are implemented
in the data layer over one shared `TutorialV3FunctionDataSource`.

### 3.2 The cache filters on read, not on write

`TutorialV3GeometryCache.read` rejects and evicts any document whose
`schemaVersion` is not this build's. Filtering on read is what makes a schema
bump self-healing: entries left by the previous build stop being served the
moment the constant changes, with nothing having to remember to clear them.

Consistent with V3-6B, where the claim RPC reuses a stored document only at the
version the calling build declares.

### 3.3 Deduplication lives with the cache

`ensureGeometry` keeps a map of in-flight futures keyed by
`(sessionId, stepIndex)`. Two callers asking for the same step share one call.

The server's atomic claim is the real guard against duplicate mapping; this
stops the app from provoking it, which is what keeps a rejected
`already_mapping` off the screen when the user taps Next twice while a prefetch
for that same step is still running.

### 3.4 Prefetch failures are structurally silent

`prefetch` catches `TutorialV3Failure` and completes normally. It writes only to
the cache — it never touches controller state — so a failed background map
cannot disturb the step being read. The step is simply mapped normally on
arrival.

### 3.5 The final step makes no call at all

`ensureGeometry` returns `null` for the final look before the cache is
consulted and before any in-flight record is created, and `prefetchTargets`
skips it. Not a skipped call, not a cached empty result: no call.

### 3.6 An epoch guard on every state write

Paging quickly through steps starts overlapping requests. Each entry point
increments `_epoch`, and every state write checks it, so a slow response for
step 1 cannot land on step 4. Matches the existing
`MakeupPreviewController._operationEpoch` idiom.

### 3.7 A failed overlay is not a failed tutorial

`TutorialV3Phase` (the tutorial) and `TutorialV3StepGeometryPhase` (the current
step's overlay) are separate. A step whose geometry failed keeps its
instruction text, its target reference, its navigation, and a retry — a missing
overlay is always preferable to a wrong one, and to a blank screen.

### 3.8 The plan is read back from the database

`SupabaseTutorialV3Planner` discards the function's response body. The function
has already written the plan through `persist_tutorial_v3_plan`, so the
controller reloads the session rather than reconstructing it from a payload it
would then have to validate a second time. The coordinator's cache for that
session is invalidated first, because a replan can change what step 2 teaches.

---

## 4. Rule compliance

| Rule | How it is met |
|---|---|
| default prefetch depth = 1 | `tutorialV3PrefetchDepth = 1`; asserted, and `prefetchTargets` is capped by it |
| no duplicate concurrent mapping | in-flight future map; two callers share one call; released on success *and* failure |
| every geometry request starts from original selfie + persisted Step Spec | client sends `{sessionId, stepIndex}` only; everything else is resolved server-side (V3-6B) |
| previous geometry never becomes AI input | no request body has a geometry field; asserted against the data source source |
| revisiting uses compatible cached geometry | cache read, then the persisted row, before any call |
| failed prefetch does not break current step | `prefetch` swallows failures and writes only to the cache |
| final step has no geometry-mapping call | early return in `ensureGeometry`; excluded from `prefetchTargets` |
| no generated guideline JPG cache | the cache holds `TutorialV3Geometry` only — no bytes, no files, no paths |

---

## 5. Tests and results

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` | — | **0 issues** |
| `flutter test` | **674** | **all pass** (was 608 after V3-6B) |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 | all pass |
| `deno test .../plan-tutorial-v3/` | 38 | all pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 | all pass |
| `git diff --check` | — | clean |

### Required checklist coverage

| Required test | Where |
|---|---|
| Current + 1 | coordinator "only the next step is targeted", "prefetching maps exactly the current step plus one"; controller "the next step is warmed while the current one is read" |
| Duplicate prevention | coordinator "two concurrent requests for one step share a single call", "a prefetch already in flight is not started twice", "the in-flight record is released once a call settles", "a failed call releases its in-flight record too" |
| Resume | controller "reopening resumes an existing tutorial by id"; coordinator "persisted geometry is used without a call" |
| Failed prefetch | coordinator "a failed prefetch is swallowed", "a failed prefetch leaves the current step untouched"; controller "a failed prefetch does not disturb the current step", "a step whose prefetch failed is mapped normally on arrival" |
| Cached revisit | coordinator "revisiting a mapped step reads the cache"; controller "cached geometry appears with no loading state at all", "moving to a prefetched step is instant", "revisiting an earlier step reuses its geometry" |
| Version invalidation | cache "a document from another schema version is never served", "a stale entry is evicted on the read that rejects it"; coordinator "persisted geometry from another schema is re-mapped", "a stale document is never written into the cache", "invalidating a session drops its cached work" |
| Final-step no-op | coordinator "it resolves to no geometry without calling the mapper", "it is never cached"; controller "it maps no geometry at all", "nothing is prefetched past the last guideline step" |

---

## 6. Defect found and fixed during the phase

`ensureGeometry` originally released its in-flight record with
`whenComplete(() => _inFlight.remove(key))`. `Map.remove` returns the removed
value — here the `Future` itself — and a `whenComplete` callback that *returns*
a future is waited on. The future therefore waited on itself and **never
completed**: every `ensureGeometry` call deadlocked.

It was caught by the coordinator tests timing out, isolated with a minimal
reproduction, and fixed by giving the callback a block body. The comment at the
call site records why the arrow form is wrong, because the two read almost
identically.

This is exactly the class of bug that would have looked like an intermittent
network hang in production.

---

## 7. Risks and limitations

| # | Item | Severity | Notes |
|---|---|---|---|
| 1 | **Exposed legacy `service_role` credential** | **HIGH — UNRESOLVED** | Carried forward from V3-6A.2. Not touched in this phase. **Release is blocked until it is rotated/revoked outside Claude Code.** |
| 2 | Nothing is wired to a route yet | Expected | The providers exist and are unreferenced until V3-8 builds the screen. |
| 3 | `_prefetchAfter` is awaited, not detached | Low | State is published as `ready` before it starts, so the screen is interactive. It makes the work observable and keeps tests deterministic; a caller that moves on invalidates the epoch. |
| 4 | The cache is per-provider-scope and in-memory only | By design | The database holds the durable copy. A second on-disk copy would be a source of truth that could outlive a schema bump. It is rebuilt when the signed-in user changes. |
| 5 | Prefetch spends quota for a step the user may never reach | Accepted | Bounded by depth 1 and by the server's 120/h, 600/day `tutorial_v3_geometry` ceiling. Revisiting never re-spends. |
| 6 | Migration `20260828000100` still unapplied; mapper function still undeployed | Expected | V3-6B risks 2 and 3, unchanged. The client cannot be exercised end to end until both land. |

---

## 8. Security impact

- **No new trust surface.** The client gained exactly two outbound calls, both
  carrying identifiers only. The V3-6B server-side trust boundary — sixteen
  refused fields, server-resolved context, re-verified Kit ownership — is
  unchanged and now has a client-side counterpart asserted in tests.
- **Responses are revalidated on this side.** `SupabaseTutorialV3GeometryMapper`
  runs the returned document through `TutorialV3GeometryValidator` with the
  category taken from the caller's own persisted Step Spec. The renderer does
  not trust a payload it did not check.
- **The server keeps its retry verdict.** The client never decides that a
  failure is retryable, so it cannot retry a validation failure into a step's
  bounded attempt budget.
- **Cache is user-scoped.** The coordinator provider watches the signed-in user
  id, so one account's geometry is never served to another.
- **No credentials, secrets, storage paths or image bytes** are read, written,
  logged or cached by anything added in this phase.
- No RLS change, no migration, no deployment, no secret mutation.

---

## 9. Acceptance status

| Criterion | Status |
|---|---|
| Plan generated/loaded once, persisted, reused | Met |
| Geometry mapped for the current step only, plus depth-1 prefetch | Met |
| No duplicate concurrent mapping | Met |
| Every request starts from the original selfie + persisted Step Spec | Met |
| Previous geometry never an AI input | Met |
| Revisiting uses compatible cached geometry | Met |
| Failed prefetch does not break the current step | Met |
| Final step makes no geometry-mapping call | Met |
| No generated guideline JPG cache | Met |
| Required tests written and passing | Met |

**V3-7 is complete. STOPPING HERE. V3-8 is not authorized and has not been started.**
