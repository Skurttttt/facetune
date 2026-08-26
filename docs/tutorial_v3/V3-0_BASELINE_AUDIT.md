# V3-0 — Clean Baseline + Remote Audit

**Phase:** V3-0 (read-only baseline)
**Date:** 2026-08-26
**Branch:** `feature/step-by-step-tutorial-v3`
**Linked Supabase project:** `usmlwaocafeqnspdsvmv`
**Source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md`

Everything below was re-derived from the live repository and the live remote
project during this phase. No prior report (including the V2-0 audit) was
trusted as fact; where this audit disagrees with V2-0, this document wins.

No feature code, migration, deployment, UI change, or remote write was
performed. All remote commands used were read-only (`migration list`,
`functions list`, `inspect db table-stats`).

---

## 1. Git baseline — CLEAN

| Item | Value |
| --- | --- |
| Current branch | `feature/step-by-step-tutorial-v3` |
| HEAD | `eb6c5e3` — *Merge My Makeup Kit feature into main* |
| `main` | `eb6c5e3` |
| Merge base with `main` | `eb6c5e3` |
| Commits ahead of `main` | **0** |
| Commits behind `main` | **0** |
| Upstream | `origin/feature/step-by-step-tutorial-v3` (in sync) |

**Verdict:** V3 starts from the exact clean `main` baseline. The branch carries
zero commits of its own and zero tracked diff against `main`.

### Working tree

Tracked tree is **clean**. Two untracked files are present, both of which are
the V3 specification documents this phase was handed:

- `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_PHASE_PROMPTS.md`
- `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md`

### Branch inventory

| Branch | Head | Role |
| --- | --- | --- |
| `main` | `eb6c5e3` | stable |
| `feature/step-by-step-tutorial-v3` | `eb6c5e3` | **this phase** |
| `feature/step-by-step-tutorial-v2` | `c70b00c` | V2 — docs only, frozen |
| `feature/step-by-step-tutorial` | `ff9f661` | V1 — frozen, do not modify |
| `feature/my-makeup-kit` | `525f178` | merged into `main` |
| `backup/phase-22` | `bb7c10f` | pre-Kit checkpoint |

### No V2 WIP present locally — CONFIRMED

`git diff main..feature/step-by-step-tutorial-v2` contains exactly three
documentation files and **no code**:

```
A  FACETUNE_STEP_BY_STEP_TUTORIAL_V2_PHASE_PROMPTS.md
A  FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md
A  docs/tutorial_v2/V2-0_BASELINE_AUDIT.md
```

V2 never produced implementation code on its branch. Nothing of V2 is present
in the V3 working tree.

---

## 2. Stable analysis + test state (verified green)

| Command | Result | Exit |
| --- | --- | --- |
| `flutter analyze` | **No issues found!** (88.7s) | 0 |
| `flutter test` | **All tests passed — `+292`** (1m16s) | 0 |

Suite scope: **67** `*_test.dart` files, including the E2E journeys
(`test/e2e/scan_journey_test.dart`, `test/e2e/makeup_kit_journey_test.dart`),
the storage-ownership contract (`test/e2e/storage_ownership_contract_test.dart`),
and the Kit security contract
(`test/features/makeup_kit/makeup_kit_security_contract_test.dart`).

> **V3 regression baseline: 292 passing tests, 0 analyzer findings.**
> Any V3 phase that lowers either number is a regression.

*Correction to V2-0:* that document reported "73 Dart test files". The measured
count of files matching `*_test.dart` under `test/` is **67**. The passing test
count (292) matches.

---

## 3. Local migration history (12 migrations)

```
20260807000100_initial_schema.sql
20260807000200_private_face_images.sql
20260808000100_auth_profile_bootstrap.sql
20260811000100_analysis_model_metadata.sql
20260811000200_generated_image_variations.sql
20260811000300_profile_settings.sql
20260812000100_ai_usage_quota.sql
20260813000100_makeup_kit_products.sql
20260813000200_kit_makeup_recommendations.sql
20260813000300_kit_generated_images.sql
20260814000100_kit_saved_looks.sql
20260814000200_makeup_kit_hardening.sql
```

---

## 4. Remote migration history — **DRIFT: 5 ORPHAN MIGRATIONS**

`npx -y supabase migration list --linked` returns **17** remote versions. The
last **five** have no local counterpart on `main` or on V3:

| Version | Local file | Remote | Source branch | Object created |
| --- | --- | --- | --- | --- |
| `20260807000100` … `20260814000200` (12) | present | applied | `main` | stable schema |
| `20260814000300` | **missing** | **applied** | V1 (`feature/step-by-step-tutorial`) | `tutorial_sessions`, `tutorial_steps` |
| `20260815000100` | **missing** | **applied** | V1 | `tutorial_personalized_step_snapshot` |
| `20260816000100` | **missing** | **applied** | V1 | `tutorial_geometry_plan` columns |
| `20260826000100` | **missing** | **applied** | **none — no branch** | `tutorial_v2_sessions` (inferred) |
| `20260826000200` | **missing** | **applied** | **none — no branch** | `tutorial_v2_steps` (inferred) |

### 4.1 The two Aug-26 migrations have NO source anywhere

This is the single most important finding of V3-0, and it is **new since V2-0**
(which saw only 15 remote migrations, all three orphans being V1).

`20260826000100` and `20260826000200` are applied on the remote database, but
their `.sql` source exists on **no branch in this repository** — not `main`,
not V1, not V2. V2's branch contains only its baseline-audit docs. The same is
true of the `plan-tutorial-v2` Edge Function (§5).

**Implication:** the remote database is 5 migrations ahead of every branch, and
2 of those 5 are unreproducible from version control. The remote schema cannot
currently be rebuilt from this repository.

---

## 5. Remote Edge Functions — 9 deployed, **3 are tutorial leftovers**

| Slug | Ver | Local source | Status |
| --- | --- | --- | --- |
| `analyze-face` | 2 | present | stable, keep |
| `generate-makeup-recommendation` | 2 | present | stable, keep |
| `generate-makeup-preview` | 5 | present | stable, keep — **canonical premium preview** |
| `delete-history-item` | 4 | present | stable, keep |
| `generate-kit-makeup-recommendation` | 3 | present | stable, keep |
| `generate-kit-makeup-preview` | 2 | present | stable, keep |
| `generate-tutorial-step` | 3 | **V1 branch only** | **V1 leftover — live** |
| `plan-tutorial-geometry` | 1 | **V1 branch only** | **V1 leftover — live** |
| `plan-tutorial-v2` | 1 | **no branch at all** | **orphan — live** |

All nine are `verify_jwt: true`. The three tutorial functions are `ACTIVE` and
invokable by any authenticated user.

---

## 6. Remote tutorial tables still present (live row counts)

From `npx -y supabase inspect db table-stats --linked`:

| Table | Rows | Generation |
| --- | --- | --- |
| `public.tutorial_sessions` | **6** | V1 |
| `public.tutorial_steps` | **66** | V1 |
| `public.tutorial_v2_sessions` | **0** | V2 (orphan) |
| `public.tutorial_v2_steps` | **0** | V2 (orphan) |

**V1 carries real user data (66 step rows). V2's tables are empty.**

Per source-of-truth §19 and §20, V3 **must not** reuse or reinterpret any of
these. V3 must create its own `tutorial_v3_*` objects and must not rewrite the
historical V1 rows.

### 6.1 Stable (non-tutorial) remote tables — all present and consistent with `main`

`profiles`, `analyses` (30), `recommendations` (28), `generated_images` (20),
`saved_looks` (3), `user_settings`, `ai_usage_events` (104),
`makeup_kit_products` (3), `kit_makeup_recommendations` (4),
`kit_generated_images` (2), `kit_saved_looks` (0).

---

## 7. Real persisted selected-style field — VERIFIED

There is **no** "selected style" column on `analyses`. The selected look is
persisted **only on the recommendation row**:

| Mode | Table | Column | Type / constraint |
| --- | --- | --- | --- |
| Standard | `public.recommendations` | **`makeup_style`** | `text not null`, not-blank check |
| Kit | `public.kit_makeup_recommendations` | **`makeup_style`** | `text not null`, same not-blank check |

**Persisted value = `MakeupStyle.code`**, the stable snake_case identifier from
[makeup_style_catalog.dart](lib/features/makeup_styles/domain/catalog/makeup_style_catalog.dart) —
not the enum name and not the display name.

Canonical vocabulary (12 codes):

```
natural  everyday  office  soft_glam  full_glam  bridal
korean   clean_girl  party  date_night  no_makeup_makeup  old_money
```

Server-side, `generate-makeup-preview` and `generate-kit-makeup-preview` both
re-read `makeup_style` from the persisted recommendation row and validate it
against an `allowedStyles` set before generating. On read-back, the app resolves
the code through `MakeupStyleCatalog` and **throws `FormatException('Unknown
historical makeup style.')`** if the code is unknown.

> **V3 consequence:** the tutorial's "selected look" must be sourced from the
> persisted `makeup_style` of the recommendation the tutorial is attached to.
> It must never be re-derived from client UI state, or the tutorial can drift
> from the canonical target. Any V3 style vocabulary check must use these exact
> 12 codes.

---

## 8. Recommendation relationships — VERIFIED (standard and Kit are fully isolated)

Both modes hang off `analyses` through **composite owner-scoped foreign keys**,
never a bare `id` reference. This is the project's ownership-integrity idiom and
V3 must copy it.

### 8.1 Standard chain

```
auth.users
  └─ analyses (id, user_id)                       UNIQUE (id, user_id)
       └─ recommendations (analysis_id, user_id) ──FK──> analyses(id, user_id) ON DELETE CASCADE
            │                                     UNIQUE (id, analysis_id, user_id)
            └─ generated_images (recommendation_id, analysis_id, user_id)
                 ──FK──> recommendations(id, analysis_id, user_id) ON DELETE CASCADE
                 ──FK──> analyses(id, user_id) ON DELETE CASCADE
                 UNIQUE storage_path · UNIQUE (recommendation_id, generation_number)
                 └─ saved_looks (generated_image_id, user_id) ──FK──> generated_images(id, user_id) CASCADE
```

### 8.2 Kit chain (parallel, isolated — shares only `analyses`)

```
analyses (id, user_id)
  └─ kit_makeup_recommendations (analysis_id, user_id) ──FK──> analyses(id, user_id) CASCADE
       │   makeup_style · recommendation_json · product_snapshot_json (jsonb ARRAY, not null)
       │   UNIQUE (id, analysis_id, user_id)
       └─ kit_generated_images (kit_recommendation_id, analysis_id, user_id)
            ──FK──> kit_makeup_recommendations(id, analysis_id, user_id) CASCADE
            UNIQUE storage_path · UNIQUE (kit_recommendation_id, generation_number)
            └─ kit_saved_looks (kit_generated_image_id, user_id) CASCADE
```

Key facts for V3:

- The two chains are **separate tables**, not a discriminator column. A V3
  session must therefore store **either** `recommendation_id` **or**
  `kit_recommendation_id`, plus an explicit `source_mode`.
- `kit_makeup_recommendations.product_snapshot_json` is a **not-null jsonb
  array** — the owned products are already snapshotted at recommendation time.
  Per source-of-truth §13, V3 must reuse this snapshot and must **not** re-run
  product selection.
- There is **no FK** from `kit_makeup_recommendations` to
  `makeup_kit_products`. Products are snapshotted by value, so deleting a kit
  product does not corrupt an existing kit recommendation.
- Kit product category vocabulary (enforced in SQL by
  `20260814000200_makeup_kit_hardening.sql`, with per-category finish rules):

  | Category | Allowed finishes |
  | --- | --- |
  | `foundation` | matte, natural, dewy, satin |
  | `concealer` | matte, natural, radiant |
  | `blush` | matte, satin, shimmer |
  | `highlighter` | natural, shimmer, metallic |
  | `eyeshadow` | matte, satin, shimmer, metallic, glitter |
  | `lipstick` | matte, satin, cream, glossy |
  | `lip_gloss` | glossy, shimmer |
  | `contour_bronzer` | matte, satin |
  | `eyebrow` | matte, natural |
  | `eyeliner` | matte, satin, glossy |

  These 10 category identifiers are the authoritative vocabulary for V3's
  planner validation (§23) and map directly onto the §12 attribute table.

---

## 9. Canonical premium preview — persistence and storage VERIFIED

| Mode | Table | Storage path template (bucket `face-images`) |
| --- | --- | --- |
| Standard | `generated_images` | `{userId}/analyses/{analysisId}/generated/{recommendationId}/preview_{NNNN}.{ext}` |
| Kit | `kit_generated_images` | `{userId}/analyses/{analysisId}/kit-generated/{kitRecommendationId}/preview_{NNNN}.{ext}` |

- `{NNNN}` is `generation_number` zero-padded to 4, unique per recommendation.
- `storage_path` is **globally unique** on both tables.
- Uploads use **`upsert: false`** — a preview can never silently overwrite.
- `generate-makeup-preview` additionally refuses any candidate path that equals
  the original path or contains `/original/`, returning `unsafe_storage_path`.
- On any post-upload failure the function **removes the uploaded object** so no
  orphan blob is left behind.
- The bucket is **private**; the app reads previews exclusively through
  `createSignedUrl(storagePath, 3600)` (1-hour TTL).

> **V3 consequence (§5, §29):** the canonical final preview is an existing
> `generated_images` / `kit_generated_images` row. V3 must reference that row
> and re-sign its URL. It must **not** regenerate, re-upload, or modify it, and
> must not write into the `generated/` or `kit-generated/` prefixes.
> Signed URLs expire after 1 hour — a long tutorial session must be able to
> re-sign, not cache a dead URL.

---

## 10. Original selfie — storage and ownership VERIFIED

**Path template:** `{userId}/analyses/{analysisId}/original/{imageId}.jpg`
(built in [supabase_face_analysis_repository.dart:45](lib/features/analysis/data/repositories/supabase_face_analysis_repository.dart#L45))

**Persisted as:** `analyses.original_image_path` (`text not null`, not-blank check).

### Overwrite protection — three independent layers

1. **Client upload uses `upsert: false`**
   ([analysis_remote_data_source.dart:50](lib/features/analysis/data/data_sources/analysis_remote_data_source.dart#L50)).
2. **No storage UPDATE policy exists.** `20260807000200_private_face_images.sql`
   creates only `face_images_select_own`, `face_images_insert_own` and
   `face_images_delete_own`. There is **no** update policy, so overwriting an
   existing object is impossible for any authenticated client. This is the
   strongest guarantee behind the "no original-selfie overwrite" prohibition.
3. **Server-side path validation.** `_shared/storage_ownership.ts`
   `isOwnedOriginalPath()` does a strict **segment-by-segment** check (exactly 5
   segments; `[0]==userId`, `[1]=='analyses'`, `[2]==analysisId`,
   `[3]=='original'`; filename stem must be a 36-char UUID; extension
   allow-listed). A `startsWith` prefix test is deliberately avoided because it
   accepts `..` traversal.

### Bucket policies (`face-images`)

Private (`public = false`), 10 MiB limit, MIME allow-list
`image/jpeg, image/png, image/webp`. All three policies are scoped to
`(storage.foldername(name))[1] = auth.uid()::text`, i.e. the **first path
segment must be the caller's UID**.

> **V3 consequence:** every V3 guideline asset path must begin with the owner's
> UID or the insert policy rejects it. The source-of-truth §25 template
> `{userId}/analyses/{analysisId}/tutorial-v3/{sessionId}/step_0001_guideline.png`
> satisfies this. V3 must add its own strict segment validator in the same style
> as `isOwnedOriginalPath` rather than a prefix match, and must upload with
> `upsert: false`.

---

## 11. History deletion behavior for analysis-owned storage — VERIFIED

`delete-history-item` (v4) is authenticated (`verify_jwt: true`) and acts
**entirely through the caller's own JWT** — it uses `SUPABASE_ANON_KEY` with the
caller's `Authorization` header, so RLS applies to every operation. No
service-role key is used, and no ownership check is bypassed.

Order of operations for `analysisId`:

1. `prefix = {userId}/analyses/{analysisId}`.
2. Read `analyses.original_image_path`, all `generated_images.storage_path`,
   and all `kit_generated_images.storage_path` for that analysis.
3. `assertOwnedHistoryPaths(recordedPaths, prefix)` — every recorded path must
   sit under the prefix, contain no `//`, and contain no `.` / `..` segment;
   otherwise **409 `unsafe_storage_path`** and nothing is deleted.
4. **Recursively list every object under the prefix** (paged, 100/page, hard cap
   10 000 objects → **409 `history_too_large`**).
5. Re-validate every discovered path with `isOwnedHistoryPath`.
6. Remove objects in batches of 100. On failure → **500 `storage_delete_failed`**
   and *no database rows are deleted*.
7. Re-list the prefix; if anything remains → **500 `storage_cleanup_incomplete`**.
8. Only then delete the `analyses` row, which **cascades** to
   `recommendations` → `generated_images` → `saved_looks` and
   `kit_makeup_recommendations` → `kit_generated_images` → `kit_saved_looks`.

**Storage-first, then database.** It returns `alreadyDeleted: true` when the
analysis row is already gone but still purges leftover objects.

### The critical V3 consequence

Step 4 deletes **every object under `{userId}/analyses/{analysisId}/`,
regardless of whether a database row references it.** Therefore:

- V3 guideline assets stored under
  `{userId}/analyses/{analysisId}/tutorial-v3/{sessionId}/` are **automatically
  and correctly purged** by existing history deletion. No change to
  `delete-history-item` is required for storage cleanup. **This is the correct
  prefix to use, and choosing any other prefix would leak orphan blobs.**
- Conversely, `tutorial_v3_sessions` / `tutorial_v3_steps` rows will **only** be
  removed if they cascade from `analyses`. V3 must declare its session FK as
  `(analysis_id, user_id) REFERENCES analyses(id, user_id) ON DELETE CASCADE`,
  matching the established idiom. Without it, deleting history would leave
  orphaned V3 session rows pointing at deleted assets.
- Step 7's "cleanup incomplete" guard means a V3 write that lands **during** a
  deletion could fail the deletion. V3 generation must be tied to a live session
  and must not resurrect a prefix after deletion begins.

---

## 12. Security posture at baseline — intact

| Control | State |
| --- | --- |
| RLS on all `public` tables | **enabled** (`profiles`, `analyses`, `recommendations`, `generated_images`, `saved_looks`, `user_settings`, `ai_usage_events`, all `makeup_kit_*` / `kit_*`) |
| `anon` grants | **revoked** on every table; `authenticated` only |
| Policy shape | `(select auth.uid()) = user_id` for select/insert/update/delete |
| `face-images` bucket | **private**, UID-scoped, **no UPDATE policy** |
| Gemini key | server-side only, `requiredEnvironment("GEMINI_API_KEY")`; never referenced in `lib/` |
| Edge Function auth | all 9 deployed functions `verify_jwt: true` |
| Quota | `consume_ai_quota(text)` is `security definer` with an empty `search_path`; `execute` revoked from `public`/`anon`. Limits are **server-chosen**, not client-supplied. |

### Existing AI quota operations vocabulary

`face_analysis` (20/h, 100/d) · `makeup_recommendation` (40/h, 200/d) ·
`kit_makeup_recommendation` (40/h, 200/d) · `makeup_preview` (30/h, 120/d) ·
`kit_makeup_preview` (30/h, 120/d)

Enforced by a `check` constraint on `ai_usage_events.operation` **and** a
hardcoded `values` list inside `consume_ai_quota`.

> **V3 consequence:** V3 guideline generation is a new AI operation and will be
> **rejected by `unsupported_operation`** until a V3 migration adds its
> operation name to *both* the check constraint and the `consume_ai_quota`
> values list. A tutorial generates many images per session, so the V3 limit
> must be sized deliberately — the per-image `makeup_preview` ceiling of 30/hour
> would allow roughly three 8-step tutorials per hour.

---

## 13. Gemini model reality vs. source-of-truth §21 — **BLOCKING RISK FOR V3-1**

The source of truth requests `gemini-3.6-flash` as the V3 guideline model and
requires a capability gate before it is hardcoded. The audit shows why that gate
matters:

| Env var | Default | Used by | Contract |
| --- | --- | --- | --- |
| `GEMINI_MODEL` | **`gemini-3.6-flash`** | `analyze-face`, `generate-makeup-recommendation`, `generate-kit-makeup-recommendation` | image + text **IN → text/JSON OUT** |
| `GEMINI_IMAGE_MODEL` | **`gemini-3.1-flash-image`** | `generate-makeup-preview`, `generate-kit-makeup-preview` | image + text **IN → image bytes OUT** |

**In this project, `gemini-3.6-flash` is proven only as a text/JSON model.
The only model proven to return image bytes is `gemini-3.1-flash-image`.**

This is exactly the confusion §21 warns against. The V3 guideline generator
needs `source image(s) + instruction → image bytes`, which today is served by
`GEMINI_IMAGE_MODEL`, not `GEMINI_MODEL`.

The existing image path already handles the failure mode: `gemini_client.ts`
reads `candidates[].content.parts[].inlineData.{data,mimeType}` and raises
`GEMINI_NO_IMAGE_OUTPUT` when no inline image part is returned. A V3-1
capability probe should assert on exactly that shape.

**V3-0 does not resolve this** — proving it requires a live Gemini call, which
is a remote action outside this read-only phase. It is carried into V3-1 as the
primary gate. Per §21, if `gemini-3.6-flash` cannot return image bytes for this
workflow, the correct action is to **STOP AND REPORT**, not to silently
substitute `gemini-3.1-flash-image`.

Note also §21's requirement that the model be exposed server-side as
`TUTORIAL_V3_GUIDELINE_MODEL` — a **new** variable. It does not exist today, and
V3 must not reuse `GEMINI_IMAGE_MODEL`, or a V3 model change would silently
alter the stable premium preview.

---

## 14. Risks and constraints carried into later phases

| # | Risk | Severity | Carried to |
| --- | --- | --- | --- |
| R1 | `gemini-3.6-flash` is a text/JSON model here; image-out is unproven | **Blocking** | V3-1 capability gate |
| R2 | 2 remote migrations (`20260826000100/200`) have **no source on any branch**; remote schema is not reproducible from VCS | **High** | needs an explicit decision before any V3 migration |
| R3 | Remote is 5 migrations ahead of V3; the next `db push` may behave unexpectedly | **High** | V3 migration phase |
| R4 | `plan-tutorial-v2` is deployed and live with no source anywhere | **High** | cleanup decision |
| R5 | `generate-tutorial-step` + `plan-tutorial-geometry` (V1) are ACTIVE and invokable | Medium | cleanup decision |
| R6 | `tutorial_steps` holds **66 real rows**; §20 forbids rewriting V1 data | Medium | V3 must not touch |
| R7 | V3 AI operation is absent from the quota allow-list → `unsupported_operation` | Medium | V3 migration phase |
| R8 | Signed preview URLs expire in 1 hour; tutorials may outlive that | Low | V3 UI phase |
| R9 | `TUTORIAL_V3_GUIDELINE_MODEL` secret not yet provisioned | Low | V3 deploy phase |

### On R2/R4 — recommendation, not action

The orphan V2 objects (`tutorial_v2_sessions`, `tutorial_v2_steps`,
`plan-tutorial-v2`) are **empty and unused** (0 rows). Because V3 uses its own
`tutorial_v3_*` namespace, they are inert and do not block V3. Removing them is
a remote write and therefore **out of scope for V3-0**; it also touches
migration history, so it needs explicit approval rather than a silent cleanup
(source-of-truth: "no unrelated cleanup"). **No action was taken.**

---

## 15. Acceptance checklist for V3-0

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Branch/status verified | ✅ `feature/step-by-step-tutorial-v3`, tracked tree clean |
| 2 | V3 base vs `main` confirmed | ✅ identical at `eb6c5e3`, 0 ahead / 0 behind |
| 3 | No V2 WIP present locally | ✅ V2 branch is docs-only; nothing in V3 tree |
| 4 | `flutter analyze` + `flutter test` | ✅ 0 issues, 292 passed |
| 5 | `migration list` + `functions list` | ✅ 17 remote migrations, 9 remote functions |
| 6 | V1/V2 tutorial objects still remote | ✅ 3 functions, 4 tables, 5 orphan migrations documented |
| 7 | Real persisted selected-style field | ✅ `recommendations.makeup_style` / `kit_makeup_recommendations.makeup_style`, value = `MakeupStyle.code` |
| 8 | Standard + Kit recommendation relationships | ✅ composite owner-scoped FKs, fully isolated chains |
| 9 | Canonical premium preview persistence/storage | ✅ `generated_images` / `kit_generated_images`, private bucket, `upsert:false`, 1h signed URLs |
| 10 | Original-selfie storage/ownership | ✅ 5-segment UID-scoped path, no storage UPDATE policy, strict server validator |
| 11 | History deletion for analysis-owned storage | ✅ recursive prefix purge → storage-first → cascading row delete |
| — | No feature code / migration / deploy / UI / remote write | ✅ none performed |

**V3-0: ACCEPTED.**

---

## 16. Binding constraints for V3 implementation

1. Selected look comes from the **persisted** `makeup_style` on the
   recommendation row, never from client UI state.
2. Canonical final preview is an **existing** `generated_images` /
   `kit_generated_images` row — reference and re-sign, never regenerate.
3. V3 assets belong under `{userId}/analyses/{analysisId}/tutorial-v3/{sessionId}/`
   so existing history deletion purges them automatically.
4. V3 tables must use composite owner-scoped FKs
   `(analysis_id, user_id) → analyses(id, user_id) ON DELETE CASCADE`.
5. V3 must add its AI operation to **both** the `ai_usage_events` check
   constraint and the `consume_ai_quota` values list.
6. V3 needs a **new** `TUTORIAL_V3_GUIDELINE_MODEL` env var — do not reuse
   `GEMINI_IMAGE_MODEL`.
7. V3 path validation must be **segment-by-segment**, never `startsWith`.
8. All uploads `upsert: false`; the `face-images` bucket stays private with no
   UPDATE policy.
9. V3 must not read, write, or reinterpret `tutorial_*` or `tutorial_v2_*`.
10. Baseline to preserve: **292 tests, 0 analyzer findings.**

## STOP
