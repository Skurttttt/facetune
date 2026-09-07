# SUB-0 — BASELINE ARCHITECTURE & SUBSCRIPTION INTEGRATION AUDIT

**Phase:** SUB-0 (READ-ONLY)
**Phase file:** `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`
**Branch:** `feature/subscription-v1`
**Parent baseline:** `feature/history-ui-productionization-v1`
**Frozen baseline tag:** `facetune-pre-subscription-v1` (present in `git tag --list`)
**Date of audit:** 2026-09-07
**Contract version referenced:** `subscription_admin_contract_v1`

This document records the *proven* technical baseline of the FaceTune repository
immediately before any Subscription V1 code exists. Every claim below was read
out of actual source, migrations, Edge Functions, configuration, or a recorded
command run. No subscription feature code was written in this phase.

---

# A. PRE-EXISTING BASELINE STATE

## A.1 Git state

```text
git branch --show-current   → feature/subscription-v1        (matches required branch)
git tag --list              → facetune-pre-subscription-v1
```

At the start of the audit:

```text
On branch feature/subscription-v1
Untracked files:
  FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md
  FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md
  FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md
  FACETUNE_WEB_ADMIN_PHASE_PROMPTS.md
  FACETUNE_WEB_ADMIN_SOURCE_OF_TRUTH.md
nothing added to commit but untracked files present
```

Recent commits at audit start:

```text
2c728fe Notes for subs
d5826a6 UI pass ready to start subscription
bcd3148 History smooth to scroll
0c34062 UI PASS
ae0d4b7 Final UI for tutorial
```

**Working-tree change observed during the audit (not performed by this phase).**
While SUB-0 was running, the five authority documents were committed and pushed
externally as:

```text
9fefcc9 SOT files    (5 files changed, 16048 insertions)
```

After that commit the tree reads `nothing to commit, working tree clean`, tracking
`origin/feature/subscription-v1`. The five files are byte-for-byte the same files
that were present as untracked at audit start (sizes and mtimes unchanged); only
their tracking status changed. **This phase executed no `git add`, `git commit`,
`git push`, or any other git write command.** No user work was cleaned, stashed,
reset, or discarded.

## A.2 Stack and architecture (proven)

```text
Flutter (Dart SDK ^3.10.0)
Clean Architecture + Repository Pattern + Feature-First
Riverpod (flutter_riverpod ^2.5.1)
go_router ^14.2.0
Supabase (supabase_flutter ^2.17.1)
Google Gemini — server-side only, via Supabase Edge Functions
```

`lib/features/` contains 14 features, each with `data/ domain/ presentation/`
where business logic exists:

```text
analysis, authentication, history, home, makeup_kit, makeup_styles,
preview, profile, recommendation, results, saved_looks, scan,
settings, tutorial
```

Shared layers: `lib/core/{config,constants,data,di,errors,supabase}`,
`lib/app/{bootstrap,router}`, `lib/shared/widgets/*`, `lib/theme`.

## A.3 Backend inventory

**Edge Functions (8, all `verify_jwt = true` in `supabase/config.toml`):**

```text
analyze-face
generate-makeup-recommendation
generate-makeup-preview                 ← BILLABLE (Standard Final Preview)
generate-kit-makeup-recommendation
generate-kit-makeup-preview             ← BILLABLE (Kit Final Preview)
analyze-tutorial-manifest-v4
generate-tutorial-step-v4
delete-history-item
```

Shared backend modules: `supabase/functions/_shared/` —
`ai_quota.ts`, `final_preview_model.ts`, `prompt_safety.ts`,
`storage_ownership.ts`, `tutorial_ai_config.ts`, `tutorial_source_resolver.ts`,
`tutorial_vocabulary.ts`.

**Migrations: 24 files**, `20260807000100_initial_schema.sql` through
`20260831000100_tutorial_session_arbiter_indexes.sql`.

**Tables relevant to Subscription lineage:**

```text
public.profiles                     (auth_user_id → auth.users)
public.analyses                     (user_id, original_image_path)
public.recommendations              (Standard plan)
public.generated_images             ← CANONICAL FINAL PREVIEW (Standard)
public.kit_makeup_recommendations   (Kit plan)
public.kit_generated_images         ← CANONICAL FINAL PREVIEW (Kit)
public.makeup_kit_products          (user inventory)
public.look_product_snapshot_items  (immutable snapshot projection)
public.saved_looks
public.user_settings
public.ai_usage_events              ← TECHNICAL rate-limit ledger (NOT billing)
public.tutorial_v4_sessions / _manifest_items / _steps / _step_products
```

Storage: one private bucket `face-images` (10 MiB limit; jpeg/png/webp), with
`face_images_select_own` / `_insert_own` / `_delete_own` policies authorizing on
`(storage.foldername(name))[1] = auth.uid()`.

## A.4 Locked AI configuration (PROTECTED — do not touch)

`supabase/functions/_shared/final_preview_model.ts`:

```text
FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image"    (locked in code, not env)
GEMINI_IMAGE_MODEL env var validates only; a disagreeing value fails closed.
```

Both Final Preview paths (Standard and Kit) resolve through this single lock, so
they cannot diverge. Prompt versions: `MAKEUP_PREVIEW_PROMPT_VERSION`,
`KIT_MAKEUP_PREVIEW_PROMPT_VERSION`.

## A.5 Android / store baseline

```text
namespace      = io.facetune.app
applicationId  = io.facetune.app
compileSdk/minSdk/targetSdk = flutter defaults
Java/Kotlin target = 17
release signing = android/key.properties (git-ignored); falls back to debug keys
release build   = isMinifyEnabled + isShrinkResources + proguard
AndroidManifest permissions = INTERNET, CAMERA only
```

**No `com.android.vending.BILLING` permission, no billing Gradle dependency, no
`in_app_purchase` / `purchases_flutter` / Play Billing package in `pubspec.yaml`.**

## A.6 Validation recorded in this phase

```powershell
git branch --show-current   → feature/subscription-v1
git status                  → (see A.1)
flutter analyze             → "No issues found! (ran in 75.2s)"   exit 0
flutter test                → "+1806 -12: Some tests failed."     (see section B)
```

`flutter test` was run twice with identical tallies (`+1806 -12`).

---

# B. PRE-EXISTING BASELINE TEST FAILURES

The baseline is **`+1806 -12`**, exactly as stated in the execution context.
These 12 failures are **pre-existing and unrelated to Subscription**. They were
reproduced on a clean tree with zero source changes.

**Root cause (diagnosed, not assumed):** all 12 are multi-line
`expect(source, contains('...\n...'))` assertions made against repository source
files read from disk. The files on this Windows checkout have **CRLF** line
endings, so a literal `\n` inside the expected substring never matches. Example
recorded from the run:

```text
Expected: contains 'grant select, insert, delete\n'
            '  on table public.look_product_snapshot_items to authenticated'
  Actual: '-- FaceTune V4-2: tutorial persistence, ...\r\n'
```

All 12 expectations are of that same form:

```text
Expected: contains 'manifestStatus: unbackedPresentCategories.length > 0\n'
Expected: contains 'export function resolveManifest(\n'
Expected: contains 'export interface ResolveRequest {\n'
Expected: contains 'Distinguishing "no such\n'
Expected: contains 'constraint tutorial_v4_sessions_analysis_owner_fk\n'
Expected: contains 'constraint look_product_snapshot_items_product_unique\n'
Expected: contains 'grant select, insert, delete\n'
Expected: contains 'constraint tutorial_v4_manifest_items_category_unique\n'
Expected: contains 'constraint tutorial_v4_steps_included_category_fk\n'
Expected: contains 'constraint tutorial_v4_steps_category_unique\n'
Expected: contains 'constraint tutorial_v4_step_products_unique\n'
Expected: contains 'guideline_storage_path like\n'
```

The 12 failing tests, by file:

| Test file | Failing test |
|---|---|
| `test/features/tutorial/manifest_analyzer_contract_test.dart` | My Makeup Kit intersection — a visible unowned category becomes kit_preview_mismatch |
| `test/features/tutorial/manifest_multi_style_test.dart` | the style has no path into the analyzer — resolution reads verdicts and ownership, and nothing else |
| `test/features/tutorial/source_resolver_contract_test.dart` | errors and logs are sanitized — one opaque message covers every not-found case |
| `test/features/tutorial/source_resolver_contract_test.dart` | the client is never trusted — the request carries only a session id and a category |
| `test/features/tutorial/tutorial_durability_test.dart` | deletion and retention — deleting the analysis cascades every tutorial record away |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | guideline storage safety — confines a guideline path to the owner tutorials folder |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | idempotency and duplicate prevention — permits one link row per step and snapshot item |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | idempotency and duplicate prevention — permits one step per category per session |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | manifest constraints — allows exactly one verdict per category per session |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | snapshot stability — snapshot items allow many products per category |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | snapshot stability — snapshot items are insert-once |
| `test/features/tutorial/tutorial_persistence_contract_test.dart` | steps exist only for included categories — foreign-keys the step to a present manifest item |

**Not fixed in SUB-0, per explicit instruction.** They are a line-ending
portability defect in the assertions, not a defect in the migrations or resolver
they assert against — the constraints they look for do exist in the files.

**Consequence for later phases:** any new Subscription contract test that asserts
`contains` against multi-line source text will fail on this Windows checkout the
same way. SUB-2 onwards must normalize line endings in the *test helper* (or
assert on single lines) rather than inherit this pattern.

---

# C. SUBSCRIPTION INTEGRATION POINTS

## C.1 Current subscription / billing implementation status

**Zero.** Proven by exhaustive search:

- No `subscriptions`, `entitlements`, `usage_ledger`, `purchases`, `receipts`,
  `billing`, or `subscription_products` table in any of the 24 migrations.
- No subscription/entitlement/plan/paywall Dart file anywhere under `lib/`.
  Every `subscription` match in Dart is a Riverpod/Dart **stream** subscription
  (`live_scan_controller.dart`, `live_scan_providers.dart`). The only `premium`
  match is the icon `Icons.workspace_premium_outlined` on a style card.
- No billing dependency, no billing permission, no provider abstraction.
- No `plan_code`, `isPremium`, or allowance concept in any layer.

`public.ai_usage_events` + `public.consume_ai_quota()` exist, but they are an
**abuse rate limiter**, not billing. They cap per-hour/per-day AI calls per
operation and have no plan, entitlement, period, reserve, commit, or release
concept. See D.1 for why they must not be repurposed as the AI Look ledger.

## C.2 Exact Final Preview call path — Standard Mode

```text
preview_result_page.dart / history_page.dart
  → makeupPreviewControllerProvider (StateNotifier, guards status==generating,
      _operationEpoch monotonic counter discards stale results)
  → GenerateMakeupPreview usecase
  → MakeupPreviewRepository (domain interface)
  → SupabaseMakeupPreviewRepository
        timeout 180s (generationTimeout), 30s (signedUrlTimeout)
  → PreviewRemoteDataSource.invoke(recommendationId:)
  → client.functions.invoke('generate-makeup-preview', {recommendationId})
  ────────────────────────── network ──────────────────────────
  → supabase/functions/generate-makeup-preview/index.ts
       1. require Bearer authorization header
       2. createClient(SUPABASE_URL, SUPABASE_ANON_KEY) + user JWT   ← USER CLIENT
       3. client.auth.getUser()                                    → authData.user.id
       4. read recommendations row  (RLS-scoped)
       5. read analyses row         (RLS-scoped)
       6. isOwnedOriginalPath(...) segment-by-segment ownership check
       7. Promise.all([ storage.download(original),
                        max(generation_number) for recommendation,
                        consumeAiQuota(client, "makeup_preview") ])
       8. validate blob size / mime
       9. generationNumber = max + 1
      10. if (!quota.allowed) → 429 rate_limited            (BEFORE Gemini)
      11. finalPreviewModelConfigurationError() → fail closed (BEFORE Gemini)
      12. requestGeminiPreview(...)  ← THE PAID CALL, model gemini-3.1-flash-image
      13. imagesAreIdentical(original, generated) → 502 unchanged_generated_image
      14. candidatePath =
            {uid}/analyses/{analysisId}/generated/{recId}/preview_NNNN.ext
          rejected if == originalImagePath or contains "/original/"
      15. storage.upload(candidatePath, upsert:false)   ← STORAGE PERSISTENCE
      16. INSERT INTO generated_images (...) .select("*").single()
                                                        ← DB PERSISTENCE  ★
      17. uploadedPath = null  (disarms compensating delete)
      18. return { preview: {...} }
      catch: if uploadedPath set → storage.remove([uploadedPath]) rollback
  ────────────────────────── network ──────────────────────────
  → GeneratedPreviewDto.fromResponse  + linkage assertions
      (dto.recommendationId == request, dto.analysisId matches,
       generatedImagePath != originalImagePath)
  → createSignedUrl × 2 (original + generated), 3600s
  → GeneratedPreview entity → MakeupPreviewState.success
```

★ **Step 16 is the single authoritative moment at which a usable persisted
canonical Final Makeup Preview begins to exist for the Standard path.**

## C.3 Exact Final Preview call path — My Makeup Kit Mode

Structurally identical, different tables and one extra validation stage:

```text
makeup_kit_recommendation_entry_page.dart
  → makeupKitLookController (_generatePreview, operation-epoch guarded)
  → MakeupKitLookRepository → SupabaseMakeupKitLookRepository
  → _invoke('generate-kit-makeup-preview', {kitRecommendationId})
  → supabase/functions/generate-kit-makeup-preview/index.ts
       auth → read kit_makeup_recommendations (incl. product_snapshot_json)
            → validate style ∈ allowedStyles, analysis_id shape
            → extract selectedIds from immutable snapshot
            → Promise.all([ analyses row, makeup_kit_products .in(selectedIds) ])
            → normalizeAndValidateKitPreviewPlan(plan, snapshots,
                                                 currentProducts, userId)
                                            ← OWNERSHIP AUTHORITY (protected)
            → isOwnedOriginalPath(...)
            → Promise.all([ download, max(generation_number), consumeAiQuota
                            (client,"kit_makeup_preview") ])
            → quota gate → model lock check → requestGeminiKitPreview(...)
            → identity check
            → path {uid}/analyses/{aid}/kit-generated/{krid}/preview_NNNN.ext
            → storage.upload(upsert:false)
            → INSERT INTO kit_generated_images (...)             ★
            → return { preview: { mode:"makeup_kit", ... } }
```

★ Same meaning as C.2 step 16, for the Kit path.

**There are two Final Preview *entry points*, not two pipelines.** They share the
model lock, the ownership helper, the path-safety rules, the identity check, the
storage bucket, and the compensating-delete rollback. Subscription must wrap both
symmetrically; wrapping only one would let a user mint free AI Looks through the
other.

## C.4 The safe integration seam

```text
                        ┌──────────────────────────────────────┐
                        │  generate-makeup-preview/index.ts    │
                        │  generate-kit-makeup-preview/index.ts│
                        └──────────────────────────────────────┘
  auth verified  ─────────────────────────────────────────────────────┐
        │                                                             │
  ownership proven (isOwnedOriginalPath, kit plan validation)         │
        │                                                             │
  ┌─────▼──────────────────────────────────────────────┐              │
  │ ★ SEAM 1 — RESERVE                                 │              │
  │ after ownership proof, BEFORE requestGemini*()     │              │
  │ naturally co-located with the existing             │              │
  │ consumeAiQuota() call in the same Promise.all      │              │
  └─────┬──────────────────────────────────────────────┘              │
        │                                                             │
  existing model lock check → Gemini call → identity check            │
  → path safety → storage.upload → INSERT INTO *_generated_images     │
        │                                                             │
  ┌─────▼──────────────────────────────────────────────┐              │
  │ ★ SEAM 2 — COMMIT                                  │              │
  │ immediately after the INSERT returns a row and     │              │
  │ before `uploadedPath = null` / the JSON response   │              │
  └─────┬──────────────────────────────────────────────┘              │
        │                                                             │
  ┌─────▼──────────────────────────────────────────────┐              │
  │ ★ SEAM 3 — RELEASE                                 │              │
  │ the existing single `catch` block, which already   │              │
  │ owns the compensating storage.remove() rollback    │              │
  │ — release ONLY on an authoritative server-side     │              │
  │   failure reached inside this function, never on   │              │
  │   client timeout                                   │              │
  └────────────────────────────────────────────────────┘
```

Why this seam is the right one:

1. **Reserve must sit after ownership proof.** Reserving before ownership is
   proven lets a caller burn capacity on a request that was never valid.
2. **Reserve must sit before the Gemini call.** That is the only point where a
   rejection costs nothing. The existing quota gate already establishes exactly
   this ordering discipline (`if (!quota.allowed)` fires before
   `requestGeminiPreview`).
3. **Commit must sit after the DB insert, not after the storage upload.** A file
   in storage with no row is not reachable by History, Saved Looks, Tutorial, or
   re-open — it is not "usable by the user" per §9 of the phase file. The
   existing code agrees: it treats a failed insert as total failure and deletes
   the uploaded object.
4. **Release belongs in the existing catch.** That block is already the single
   authoritative "this operation definitively failed on the server" point, and it
   already performs a compensating action. Nothing else in the codebase can
   authoritatively declare failure.

**No Flutter change is required to make reserve/commit/release correct.** The
Flutter layer never learns of the reservation; it only receives the existing
`{preview:{...}}` payload or a sanitized error. Later phases (SUB-6/7) add
*display* of server-derived remaining capacity — never authority over it.

## C.5 Existing precedents this repository already proves work

These are the patterns SUB-2/3/4 should extend rather than invent:

| Need | Existing precedent |
|---|---|
| Server-authoritative counter a client cannot forge | `public.consume_ai_quota()` — `security definer`, `set search_path = ''`, derives `auth.uid()` internally, limits hardcoded inside the function body so a direct RPC caller cannot raise its own ceiling |
| Client may read own metering, never write it | `ai_usage_events`: `revoke all` from anon+authenticated, then `grant select` only, plus `ai_usage_events_select_own` policy |
| Fail-closed on an unreachable privileged check | `_shared/ai_quota.ts` returns `allowed:false, reason:"quota_unavailable"` on error or malformed payload |
| Dual-mode canonical preview reference | `tutorial_v3/v4_sessions`: `source_mode text check in ('standard','makeup_kit')` + two nullable FK columns + a CHECK enforcing exactly one is set, matching `source_mode` |
| Idempotency by unique index + upsert | `tutorial_v4_sessions_canonical_preview_idx` / `_kit_canonical_preview_idx` — plain (not partial) unique indexes on nullable columns, deliberately so PostgREST `ON CONFLICT (col)` can infer them (see `20260831000100`, which documents the 42P10 failure the partial version caused) |
| Insert-once history rows | `look_product_snapshot_items`: no UPDATE grant, no UPDATE policy, plus `reject_snapshot_item_update()` trigger as defence in depth |
| Reserve/attempt/release shape | `generate-tutorial-step-v4`: `generation_attempt` counter and `releaseStep(client, stepId, reason)` called on each distinct sanitized failure (`rate_limited`, `unchanged_guideline`, `unsafe_storage_path`, `storage_upload_failed`, `persistence_failed`) |
| Composite owner-identity FKs | `unique (id, user_id)` on every owned table, referenced as `foreign key (x_id, user_id)` — makes cross-user attachment structurally impossible |
| Ownership proof by path segments | `_shared/storage_ownership.ts` — `isOwnedOriginalPath`, `isOwnedGeneratedPreviewPath`; segment-by-segment, never `startsWith` |

## C.6 Tutorial non-billable boundary (proven)

- `analyze-tutorial-manifest-v4` **reads** `generated_images` / `kit_generated_images`
  (`const previewTable = isKit ? "kit_generated_images" : "generated_images"`).
- `generate-tutorial-step-v4` writes only guideline objects, and explicitly
  **rejects** any path equal to the original, equal to the canonical preview, or
  containing `/original/` or `/generated/`.
- **Neither tutorial function ever inserts into `generated_images` or
  `kit_generated_images`.**

Therefore, if the usage ledger commits **only** at C.2 step 16 / C.3 ★, the
Tutorial hard-lock of §10 (Tutorial = 0 additional AI Looks, reopening = 0) is
satisfied *structurally*, with no tutorial code change and no special-casing.
Tutorial's separate technical cost remains visible via `ai_usage_events`
operations `tutorial_manifest_analysis` and `tutorial_step_generation`.

## C.7 Reopen / History / Saved Looks boundary (proven)

`history_remote_data_source.dart` performs plain `select` reads on `analyses`,
`recommendations`, `generated_images`, `saved_looks` and creates signed URLs.
`makeupPreviewController.restore(...)` sets success state from an existing
entity. **No reopen path invokes a preview Edge Function**, so reopening cannot
consume an AI Look. `generateVariation() => retry() => generate(...)` *does*
re-invoke the function and *does* create a new `generated_images` row — correctly
billable under §9.

---

# D. CONTRACT / SCHEMA GAPS

## D.1 `ai_usage_events` is NOT the AI Look ledger — do not extend it

The current metering table:

```sql
ai_usage_events (id, user_id, operation, created_at)
```

Latest `consume_ai_quota` vocabulary (from `20260830000100_tutorial_persistence.sql`):

```text
face_analysis 20/100        makeup_recommendation 40/200
kit_makeup_recommendation 40/200
makeup_preview 30/120       kit_makeup_preview 30/120
tutorial_step 80/400        tutorial_geometry_plan 20/100
tutorial_v2_plan 30/150     tutorial_v3_plan 30/150
tutorial_v3_geometry 120/600
tutorial_manifest_analysis 20/80
tutorial_step_generation 90/360
```

It cannot serve as the AI Look ledger because it has **no**:

- status (`reserved` / `committed` / `released`) — it is insert-only, immediate
- `operation_id` / idempotency key — a retry inserts a second row
- link to the resulting canonical preview
- entitlement or plan linkage
- period linkage
- release semantics — a failed generation still leaves a consumed row
- concept of capacity vs. rate

Critically, it **charges at request time, not at persisted-success time**. Its own
migration comment concedes the trade-off: "a request that fails source validation
can still spend one unit." That is correct for a rate limiter and **flatly
violates §13 of the Subscription SoT** for billing. Keep both. They answer
different questions: `ai_usage_events` = "is this account hammering the API?",
usage ledger = "did this account consume an AI Look?"

## D.2 Missing schema (all of it)

Nothing exists for: `subscription_products`, `user_entitlements`, `usage_ledger`,
allowance adjustments, provider purchase/receipt records, or audit events.

## D.3 Canonical preview identity is dual-table — the ledger must model it

There is no single "canonical preview id" domain. `generated_images.id` and
`kit_generated_images.id` are distinct tables with distinct owner-composite FKs.
The contract's `canonical_preview_id` (§42) therefore **cannot** be one FK column.
The proven repository answer is the `tutorial_v4_sessions` shape:

```text
source_mode text not null check (source_mode in ('standard','makeup_kit'))
canonical_generated_image_id      uuid   -- FK (id, user_id) → generated_images
canonical_kit_generated_image_id  uuid   -- FK (id, user_id) → kit_generated_images
check ( (source_mode='standard'    and generated is not null and kit is null)
     or (source_mode='makeup_kit' and kit is not null and generated is null) )
```

Any other shape either loses referential integrity or duplicates a concept.

## D.4 Deletion vs. committed-usage immutability — direct conflict

`delete-history-item` deletes the `analyses` row, and `generated_images` /
`kit_generated_images` cascade away via `on delete cascade`. Shared Contract §62
requires committed usage to be historically immutable.

If `usage_ledger.canonical_generated_image_id` carries a plain
`on delete cascade`, **a user deletes one history item and their committed AI
Look silently vanishes — a free look on demand, repeatable.**

The repository already solved this exact class of problem once, for
`look_product_snapshot_items.product_id`: *"Intentionally NOT a foreign key: the
product may later be edited or deleted, and this snapshot must survive both
unchanged."* SUB-2 must make a deliberate, documented choice here
(`on delete set null` while retaining `status='committed'`, or provenance-only
columns) — not inherit a cascade by default.

## D.5 RLS gaps for subscription data

Existing RLS is uniformly correct for *ownership* but is built on the assumption
that "the user owns their rows, so the user may write them". Every owned table
grants `select, insert, update, delete` to `authenticated`. That model is wrong
for entitlements and usage, where the user is the adversary:

1. **`generated_images` is client-insertable today.** RLS permits
   `insert ... with check (auth.uid() = user_id)`. A user can create a
   `generated_images` row from Flutter without any Edge Function. So *"a canonical
   preview row exists"* is **not** by itself proof that FaceTune generated one.
   Commit must be performed by the server inside the generation path, never
   derived from the mere existence of a row a client can forge.
2. **No Edge Function uses the service role.** Verified: zero matches for
   `SERVICE_ROLE` / `service_role` across `supabase/functions/`. Every function
   runs as the *user* (anon key + user JWT). Consequently the reserve / commit /
   release operations **cannot** be plain table writes from the Edge Function —
   they must be `security definer` RPCs in the `consume_ai_quota` mould, with
   `revoke all ... from anon/authenticated` on the tables and `grant select` only.
3. Entitlement tables need `select`-own only for users; **no** user
   `insert/update/delete` grant at all.
4. Committed ledger rows need the insert-once treatment
   (`look_product_snapshot_items` precedent: no UPDATE grant, no UPDATE policy,
   plus a rejecting trigger).

## D.6 Domain-model gaps (Flutter)

Nothing exists. Established conventions to follow:

- Enum-with-stable-`code` + `fromCode` returning nullable, e.g.
  `MakeupKitCategory` — *"UI display labels must never be used as the identity
  contract"*. This is exactly the shape for `SubscriptionPlanCode`,
  `EntitlementStatus`, `UsageStatus`, `BillingProvider`, `UsageType`, `ResetPolicy`.
- Typed failures: `PreviewFailure(type, message, {retryable, technicalCode})` with
  a `PreviewFailureType` enum; base `Failure` in `lib/core/errors/failures.dart`.
- Immutable `const`-constructor entities with `required` named fields.
- DTO ↔ entity separation: `data/models/*_dto.dart` with `fromResponse` +
  linkage validation, never raw maps into presentation.

## D.7 Flutter-state gaps

No subscription provider, repository, controller, or state exists. Auth exposes
`authControllerProvider` with `AuthUser(isAnonymous, ...)`; preview and kit
controllers already key off `authControllerProvider.select((s) => s.user?.id)`
so state resets across accounts — the same idiom a subscription controller must
use. `lib/features/profile/presentation/pages/profile_page.dart` (360 lines,
`ListView` of `AppCard`s, already branches on `isGuest`) is the natural host for
a remaining-AI-Looks card in SUB-7, and `AppConstants` + `app_router.dart` are
where a `/subscription` route would slot in SUB-8.

## D.8 Provider / billing gaps

Everything: no Play Billing dependency, no `BILLING` permission, no purchase
adapter, no `subscription_products` mapping table, no verification function, no
RTDN/webhook endpoint, no Play Console product configuration evidence in-repo.

---

# E. RISKS

**E.1 — Anonymous accounts vs. the one-time Free AI Look. (Highest business risk.)**
`signInAnonymously(data: {'account_type':'guest'})` is a first-class entry point
("Explore as a guest"), and `handle_new_auth_user()` bootstraps a profile for
*every* auth user including anonymous ones. Free grants 1 non-replenishing AI
Look per account, so **a guest can sign out, tap "Explore as a guest" again, and
receive another free AI Look, indefinitely** — at the full planning cost of PHP 45
each. Neither `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` nor
`FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` contains the word "guest" or
"anonymous" anywhere (verified by search). **This is an unresolved authority gap,
not an implementation detail, and it needs a product decision before SUB-3.**

**E.2 — Wrapping only one preview path.** Two billable entry points exist. Gating
`generate-makeup-preview` alone leaves `generate-kit-makeup-preview` as a free
channel. Both must be wrapped in the same phase (SUB-5).

**E.3 — Cascade deletion erasing committed usage.** See D.4. Repeatable free
looks if a plain cascade is inherited.

**E.4 — Committing on a client-forgeable signal.** See D.5.1.

**E.5 — Client-timeout double-charging.** `SupabaseMakeupPreviewRepository`
already documents this failure mode: its 180s budget was raised *because* "the
client could abandon a request the server was still paying for. The user then saw
a failure, retried, and triggered a second billed generation." With reservations,
the same race becomes a stuck reservation. §14/§18 forbid releasing on client
timeout, so SUB-4 needs a reconciliation strategy that inspects persisted state
first — not an elapsed-time sweeper.

**E.6 — `generation_number` race is a real concurrency probe.** Both functions
compute `generationNumber = max(existing) + 1` with a non-atomic read, then
`storage.upload(..., upsert:false)` and insert against
`generated_images.storage_path UNIQUE`. Two concurrent identical requests compute
the same number and the same path; one wins, the other fails at
`storage_upload_failed` — *after* both have paid Gemini. Today that is a cost bug;
under subscriptions the loser must reliably RELEASE, or the user is charged for a
preview they never received.

**E.7 — Pre-existing plaintext credential in the repository.** `NOTES.md` (tracked,
in the repo root) contains a plaintext Supabase password on its first line. Not
introduced by this phase and not modified by it. It should be rotated and removed
from the working tree before any subscription/billing secret work begins; note
that removal from HEAD does not remove it from history.

**E.8 — Windows CRLF test pattern.** See section B. New Subscription contract
tests that copy the existing multi-line `contains` idiom will fail identically.

**E.9 — Play Billing library currency.** No billing package is pinned yet, so
SUB-9/10 start from zero. §16 requires verifying current official Google Play
documentation and library compatibility at implementation time rather than
relying on remembered APIs.

---

# F. ASSUMPTIONS NOT PROVEN

1. **Deployed Supabase state.** The linked project ref is
   `usmlwaocafeqnspdsvmv` (`supabase/.temp/linked-project.json`). Whether all 24
   migrations are actually applied there, and whether the deployed
   `consume_ai_quota` matches the latest local definition, was **not** verified —
   no remote command was run (read-only phase, no deployment authorization).
2. **Deployed Edge Function set.** `supabase/config.toml` declares 8 functions
   with `verify_jwt = true`. Actual deployed names/versions were not queried.
3. **Google Play Console state.** No evidence in-repo of a Play Console app,
   subscription products, base plans, offers, licence testers, or an internal
   test track. Product IDs for `plus` / `pro` / `salon_pro` do not exist yet as
   far as this repository can prove.
4. **Google Play service-account / RTDN configuration.** Unproven; nothing in-repo.
5. **Guest/anonymous entitlement policy.** Genuinely absent from both authority
   documents (E.1). Requires a decision, not an inference.
6. **Whether `gemini-3.1-flash-image` is currently reachable in production** was
   not exercised; the lock is proven in code only.
7. **Real-device behavior.** Nothing was run on the POCO X3 GT in this phase.
8. **Backend test suite health.** Deno tests exist alongside the functions
   (`*_test.ts`) and `docs/GEMINI_FACE_ANALYSIS_SETUP.md` documents
   `npx -y deno test ...` / `deno check`, but no aggregate Deno task exists in
   `supabase/functions/deno.json` and the Deno suite was **not** run in SUB-0.
9. **`ai_usage_events` retention.** `purge_ai_usage_events()` exists but is
   explicitly "not self-scheduling"; whether it is actually scheduled in the
   dashboard is unknown.

---

# G. MANUAL ACTIONS REQUIRED

Nothing is required to *complete SUB-0* — it is finished. The following are
prerequisites for later phases and are listed so they are not discovered late:

| # | Action | Needed by | Owner |
|---|---|---|---|
| G1 | **Decide the guest/anonymous Free-entitlement policy** and record it as an approved revision of `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md` | before SUB-3 | Product / document owner |
| G2 | Confirm migration + function deployment state of project `usmlwaocafeqnspdsvmv` | before SUB-2 deployment | Kurt |
| G3 | Authorize (or withhold) remote migration deployment, explicitly, per phase | SUB-2 onward | Kurt |
| G4 | Create Google Play Console subscription products for `plus` / `pro` / `salon_pro`, record exact product IDs and base-plan IDs | before SUB-9 | Kurt |
| G5 | Configure a Play service account + Real-time Developer Notifications for server-side verification | before SUB-10 | Kurt |
| G6 | Set up an internal test track and licence testers so sandbox purchases never hit production | before SUB-15 | Kurt |
| G7 | Rotate the Supabase password exposed in `NOTES.md` and remove it from the working tree (history remains) | before billing secret work | Kurt |
| G8 | Decide the deletion-vs-committed-usage rule (D.4) so SUB-2 encodes it deliberately | before SUB-2 | Kurt + document owner |

---

# H. RECOMMENDED SUB-1 SCOPE

SUB-1 is **domain types only** — no persistence, no provider, no UI, no Final
Preview change. Following the existing enum/entity/failure conventions of D.6.

## H.1 Likely minimum files

```text
lib/features/subscription/domain/entities/subscription_plan_code.dart
    enum: free, plus, pro, salonPro('salon_pro'), salonPilot('salon_pilot')
    stable `code`, nullable `fromCode`, plus `isPubliclyPurchasable`

lib/features/subscription/domain/entities/billing_provider.dart
    enum: none, googlePlay('google_play'),
          appleAppStore('apple_app_store')   ← reserved, iOS NOT implemented
          adminGranted('admin_granted')

lib/features/subscription/domain/entities/entitlement_status.dart
    enum: pending, active, gracePeriod('grace_period'),
          expired, suspended, revoked

lib/features/subscription/domain/entities/usage_type.dart
    enum: finalMakeupPreview('final_makeup_preview')   ← the only V1 member

lib/features/subscription/domain/entities/usage_status.dart
    enum: reserved, committed, released

lib/features/subscription/domain/entities/reset_policy.dart
    enum: none, billingPeriod('billing_period')

lib/features/subscription/domain/entities/subscription_plan_definition.dart
    plan_code + displayName + publiclyPurchasable + baseAiLookAllowance
    + resetPolicy + billingProvider compatibility.
    THE single place 1 / 3 / 8 / 35 / 30 may appear in Flutter.

lib/features/subscription/domain/entities/subscription_period.dart
    recurring: periodStart / periodEnd
    admin-granted: startsAt / expiresAt
    modelled as distinct constructors or a sealed hierarchy — NOT four
    nullable DateTimes on one class

lib/features/subscription/domain/entities/subscription_allowance.dart
    baseAllowance + effectiveAllowance (Salon Pilot adjustments land here later)

lib/features/subscription/domain/entities/subscription_usage_summary.dart
    committed, activeReserved, and DERIVED remaining/available.
    Remaining must be clamped at 0 — a negative user-facing remaining
    must be unrepresentable, per §12.

lib/features/subscription/domain/entities/subscription_entitlement.dart
    id, userId, planCode, status, billingProvider, providerProductId?,
    providerSubscriptionReference?, period, allowance, autoRenew, verifiedAt

lib/features/subscription/domain/entities/ai_look_operation.dart
    the operation_id value object (idempotency identity)

lib/features/subscription/domain/entities/generation_authorization.dart
    the access decision: allowed vs. a typed denial reason

lib/features/subscription/domain/errors/subscription_failure.dart
    SubscriptionFailureType enum aligned to Shared Contract §71 codes
    (AI_LOOK_LIMIT_REACHED, ENTITLEMENT_EXPIRED, …), mirroring the shape of
    lib/features/preview/domain/errors/preview_failure.dart
```

```text
test/features/subscription/subscription_plan_code_test.dart
test/features/subscription/entitlement_status_test.dart
test/features/subscription/usage_status_test.dart
test/features/subscription/subscription_plan_definition_test.dart
test/features/subscription/subscription_period_test.dart
test/features/subscription/subscription_usage_summary_test.dart
```

## H.2 SUB-1 boundary

**In scope:** immutable Dart domain types + their unit tests; `dart format .`,
`flutter analyze`, `flutter test`.

**Out of scope:** every migration, every RLS policy, every Edge Function change,
any repository/data source, any provider SDK, any widget, any change to the two
preview functions, any Web Admin file.

**Must hold at the end of SUB-1:** `flutter analyze` still clean;
`flutter test` still exactly `-12` (the section-B failures) and nothing more; no
allowance or price literal anywhere outside
`subscription_plan_definition.dart`; no `bool isPremium` anywhere.

## H.3 Protected — later phases must not modify

```text
supabase/functions/_shared/final_preview_model.ts        (model lock)
supabase/functions/_shared/tutorial_ai_config.ts
supabase/functions/_shared/tutorial_source_resolver.ts
supabase/functions/_shared/tutorial_vocabulary.ts
supabase/functions/_shared/prompt_safety.ts
supabase/functions/_shared/storage_ownership.ts          (read-only reuse OK)
supabase/functions/generate-makeup-preview/{gemini_client,prompt,image_validation}.ts
supabase/functions/generate-kit-makeup-preview/{gemini_client,prompt,validation}.ts
supabase/functions/analyze-tutorial-manifest-v4/**
supabase/functions/generate-tutorial-step-v4/**
supabase/functions/analyze-face/**
supabase/functions/generate-*-recommendation/**
all 24 existing migrations (extend by NEW migration only; never edit in place)
lib/features/tutorial/**
lib/features/makeup_kit/domain/validation/**
```

`generate-makeup-preview/index.ts` and `generate-kit-makeup-preview/index.ts` are
**additive-only** in SUB-5: insert the three seam calls of C.4 and nothing else.
No reordering, no model change, no prompt change, no retry change.

## H.4 Existing tests reusable as regression anchors

```text
test/features/preview/final_preview_model_lock_test.dart   ← model lock guard
test/features/preview/makeup_preview_controller_test.dart  ← epoch/duplicate guard
test/features/preview/generated_preview_dto_test.dart      ← DTO linkage contract
test/features/preview/preview_result_page_test.dart
test/features/makeup_kit/makeup_kit_look_controller_test.dart
test/features/makeup_kit/makeup_kit_security_contract_test.dart
test/features/makeup_kit/makeup_kit_cross_account_state_test.dart
test/features/makeup_kit/kit_makeup_preview_dto_test.dart
test/features/tutorial/canonical_preview_contract_test.dart
test/features/tutorial/kit_preview_consistency_test.dart
test/features/tutorial/realized_look_cost_test.dart
test/features/tutorial/v4_security_audit_test.dart
test/e2e/storage_ownership_contract_test.dart
test/e2e/makeup_kit_journey_test.dart
test/e2e/scan_journey_test.dart
test/helpers/generated_preview_response_fixture.dart       ← reusable fixture
test/helpers/fake_auth_repository.dart                     ← reusable fake
```

---

**End of SUB-0 audit. No SUB-1 work was performed.**
