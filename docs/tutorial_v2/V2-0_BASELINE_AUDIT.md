# V2-0 — Repository + Remote-State Revalidation (Baseline Audit)

**Phase:** V2-0 (read-only baseline)
**Date:** 2026-08-26
**Branch:** `feature/step-by-step-tutorial-v2`
**Linked Supabase project:** `usmlwaocafeqnspdsvmv` ("facetune"), Postgres `17.6.1.155`
**Source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md`

This document records the *verified* state of the repository and the remote
Supabase project at the moment V2 implementation begins. Everything below was
re-derived from the live repo and the live project. No prior report was trusted.

---

## 1. Git baseline

| Item | Value |
| --- | --- |
| Current branch | `feature/step-by-step-tutorial-v2` |
| HEAD | `eb6c5e3` — *Merge My Makeup Kit feature into main* |
| Merge base with `main` | `eb6c5e3` |
| `git diff main...HEAD` | **empty** |
| `git diff main HEAD` | **empty** |
| Upstream | `origin/feature/step-by-step-tutorial-v2` (in sync) |

**Exact V2 branch base:** the V2 branch is currently *identical* to `main` at
`eb6c5e3`. It carries zero commits of its own. `main`, `origin/main`,
`origin/HEAD` and both V2 refs all point at the same commit.

### Clean / dirty state

The tracked working tree is **clean**. Three untracked files are present:

- `FACETUNE_STEP_BY_STEP_TUTORIAL_V2_PHASE_PROMPTS.md`
- `FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md`
- `V2-0 – Baseline Audit.md`

> **Note.** The root-level `V2-0 – Baseline Audit.md` is *not* an audit — it is a
> one-paragraph-per-phase roadmap summary of V2-0 … V2-14. It is **not** the
> deliverable this phase requires and sits at a different path. It has been left
> untouched.

### Branch inventory

| Branch | Head | Role |
| --- | --- | --- |
| `main` | `eb6c5e3` | stable |
| `feature/step-by-step-tutorial-v2` | `eb6c5e3` | **this phase** |
| `feature/step-by-step-tutorial` | `ff9f661` | **V1 — frozen, do not modify** |
| `feature/my-makeup-kit` | `525f178` | merged into `main` |
| `backup/phase-22` | `bb7c10f` | pre-Kit checkpoint |

---

## 2. Stable test + analysis state (verified green)

| Command | Result |
| --- | --- |
| `flutter analyze` | **No issues found!** (46.7s), exit 0 |
| `flutter test` | **All tests passed** — `+292`, exit 0 |

Scope of the suite: 73 Dart test files, including the two E2E journeys
(`test/e2e/scan_journey_test.dart`, `test/e2e/makeup_kit_journey_test.dart`),
the storage-ownership contract (`test/e2e/storage_ownership_contract_test.dart`),
and the Kit security contract
(`test/features/makeup_kit/makeup_kit_security_contract_test.dart`).

Baseline for V2: **292 passing tests, zero analyzer findings.** Any V2 phase
that lowers either number is a regression.

---

## 3. Local Supabase migration history (12 migrations)

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

## 4. Remote migration history — **DRIFT DETECTED**

`npx -y supabase migration list --linked` returns **15** remote versions. The
last three have **no local counterpart** (empty `local` field):

| Version | Local file | Remote | Origin |
| --- | --- | --- | --- |
| `20260807000100` … `20260814000200` | present (12) | applied | `main` |
| `20260814000300` | **missing** | **applied** | V1 — `tutorial_sessions_steps` |
| `20260815000100` | **missing** | **applied** | V1 — `tutorial_personalized_step_snapshot` |
| `20260816000100` | **missing** | **applied** | V1 — `tutorial_geometry_plan` |

> **This is the single most important finding of V2-0.** The remote database is
> three migrations *ahead* of the V2 branch, and those three migrations belong
> to the abandoned V1 tutorial. Their source exists only on
> `feature/step-by-step-tutorial`, which is frozen.

---

## 5. Existing V1 remote tutorial objects

### 5.1 Tables (live in the remote database, RLS enabled)

**`public.tutorial_sessions`** — columns:
`id`, `user_id`, `source_mode`, `analysis_id`, `recommendation_id`,
`kit_recommendation_id`, `makeup_style`, `generation_number`, `total_steps`,
`generation_status` (default `'not_started'`), `tutorial_model`,
`tutorial_image_size`, `prompt_version`, `created_at`, `updated_at`,
plus `geometry_plan_json` and geometry plan version/model columns added by
`20260816000100`.

Notable constraints:
- `tutorial_sessions_source_mode_valid` — `source_mode in ('standard_recommendation', 'makeup_kit')`
- exactly-one-source check tying `recommendation_id` / `kit_recommendation_id` to `source_mode`
- composite FKs `(analysis_id, user_id) → analyses(id, user_id)`,
  `(recommendation_id, analysis_id, user_id) → recommendations(...)`,
  `(kit_recommendation_id, analysis_id, user_id) → kit_makeup_recommendations(...)`, all `on delete cascade`
- `tutorial_sessions_owner_identity unique (id, user_id)`

**`public.tutorial_steps`** — columns:
`id`, `user_id`, `tutorial_session_id`, `step_number`, `category`, `title`,
`instruction_json`, `placement_metadata_json` (default `'[]'`),
`placement_image_path`, `result_image_path`, `model_name`, `image_size`,
`prompt_version`, `generation_status`, `created_at`, `updated_at`,
plus `personalized_spec_json` added by `20260815000100`.

Notable constraints:
- `tutorial_steps_session_step_unique unique (tutorial_session_id, step_number)`
- `tutorial_steps_result_image_path_unique unique (result_image_path)` (nullable + unique)
- composite FK `(tutorial_session_id, user_id) → tutorial_sessions(id, user_id)`

Both tables carry full own-row RLS (`select`/`insert`/`update`/`delete` on
`auth.uid() = user_id`) and `set_updated_at` triggers.

### 5.2 Edge Functions — 8 deployed, 2 are V1 leftovers

| Slug | Status | Version | Origin |
| --- | --- | --- | --- |
| `analyze-face` | ACTIVE | 2 | stable |
| `generate-makeup-recommendation` | ACTIVE | 2 | stable |
| `generate-makeup-preview` | ACTIVE | 5 | stable |
| `delete-history-item` | ACTIVE | 4 | stable |
| `generate-kit-makeup-recommendation` | ACTIVE | 3 | stable |
| `generate-kit-makeup-preview` | ACTIVE | 2 | stable |
| **`generate-tutorial-step`** | **ACTIVE** | 3 | **V1 leftover** |
| **`plan-tutorial-geometry`** | **ACTIVE** | 1 | **V1 leftover** |

Both V1 functions are `verify_jwt = true`. Neither has local source on this
branch and neither is declared in this branch's `supabase/config.toml`.

### 5.3 Shared-object contamination (highest-risk finding)

V1's `20260816000100` **rewrote two objects the stable app depends on**:

`ai_usage_events_operation_valid` — the remote check constraint currently allows:

```
face_analysis, makeup_recommendation, kit_makeup_recommendation,
makeup_preview, kit_makeup_preview, tutorial_step, tutorial_geometry_plan
```

This branch's newest local definition (`20260813000300`) allows only the first
five.

`public.consume_ai_quota(p_operation text)` — remote limits table currently:

| operation | hourly | daily |
| --- | --- | --- |
| `face_analysis` | 20 | 100 |
| `makeup_recommendation` | 40 | 200 |
| `kit_makeup_recommendation` | 40 | 200 |
| `makeup_preview` | 30 | 120 |
| `kit_makeup_preview` | 30 | 120 |
| **`tutorial_step`** | **80** | **400** |
| **`tutorial_geometry_plan`** | **20** | **100** |

This branch's local definition stops at `kit_makeup_preview`.

> **Constraint V2 must respect:** any future migration that redefines
> `consume_ai_quota` or `ai_usage_events_operation_valid` must be written as a
> *superset* of the remote state, or must deliberately and explicitly retire the
> V1 operations. Replaying this branch's local `20260813000300` body against
> remote would silently strip `tutorial_step` and `tutorial_geometry_plan`.

---

## 6. The actual persisted selected-style field

**There is no `style` column on any image or session table in the stable app.**
Style is persisted in exactly two places:

| Table | Column | Written by |
| --- | --- | --- |
| `public.recommendations` | `makeup_style text not null` | `generate-makeup-recommendation` |
| `public.kit_makeup_recommendations` | `makeup_style text not null` | `generate-kit-makeup-recommendation` |

Both are guarded by a `char_length(btrim(makeup_style)) > 0` check.

**Stored value = `MakeupStyle.code`** — the snake_case code from
[makeup_style_catalog.dart](lib/features/makeup_styles/domain/catalog/makeup_style_catalog.dart),
**not** the Dart enum name. The 12 valid values are:

```
natural, everyday, office, soft_glam, full_glam, bridal,
korean, clean_girl, party, date_night, no_makeup_makeup, old_money
```

Read-back (identical in all three consumers) is a join through the
recommendation row, then a catalog lookup **by `code`**:

- [supabase_history_repository.dart:136](lib/features/history/data/repositories/supabase_history_repository.dart#L136)
- [supabase_saved_looks_repository.dart:161](lib/features/saved_looks/data/repositories/supabase_saved_looks_repository.dart#L161)
- [supabase_makeup_kit_library_repository.dart:259](lib/features/makeup_kit/data/repositories/supabase_makeup_kit_library_repository.dart#L259)

An unmatched code raises `FormatException('Unknown historical makeup style.')` —
so V2 must never write a style string outside the catalog.

**In-session selection is not persisted.**
[makeup_style_selection_controller.dart](lib/features/makeup_styles/presentation/controllers/makeup_style_selection_controller.dart)
is an in-memory Riverpod `StateNotifier` (`select` / `confirm` / `clear` /
`restore`). History and Kit entry pages re-hydrate it via `.restore(style)` from
the persisted recommendation row. **V2 must derive style from the recommendation
row, never from controller state alone**, or a resumed tutorial will lose it.

---

## 7. Canonical final-preview storage & persistence flow

### 7.1 Standard flow

`generate-makeup-preview` (remote v5) writes:

```
{userId}/analyses/{analysisId}/generated/{recommendationId}/preview_{NNNN}.{ext}
```

(`NNNN` = `generation_number` zero-padded to 4.) It then inserts into
`public.generated_images`:
`user_id, analysis_id, recommendation_id, storage_path, generation_number,
model_name, prompt_version`.

Guards already in place:
- refuses any candidate path equal to `originalImagePath` or containing `/original/` → `unsafe_storage_path`
- `upsert: false` on upload
- `imagesAreIdentical` check → `unchanged_generated_image` (502, retryable)
- on DB-insert failure the uploaded object is removed (compensating delete)

Schema guards: `generated_images.storage_path` is `unique`;
`generated_images_recommendation_generation_idx` is a unique index on
`(recommendation_id, generation_number)`.

### 7.2 Kit flow (fully isolated)

`generate-kit-makeup-preview` writes to a **different** prefix:

```
{userId}/analyses/{analysisId}/kit-generated/{kitRecommendationId}/preview_{NNNN}.{ext}
```

and inserts into `public.kit_generated_images` (here `model_name` and
`prompt_version` are both `not null`, unlike the standard table).

### 7.3 The canonical reference

**The canonical final preview is a `storage_path` on a generated-image row, not
a bare file.** V2 must anchor to:

- standard → `generated_images.id` + `.storage_path`
- kit → `kit_generated_images.id` + `.storage_path`

`saved_looks.generated_image_id` (unique) and
`kit_saved_looks.kit_generated_image_id` (unique) both FK to those rows with
`on delete cascade`, so a saved look *is* a pointer to the same canonical
preview. Domain shapes:
[generated_preview.dart](lib/features/preview/domain/entities/generated_preview.dart)
and [kit_look_result.dart](lib/features/makeup_kit/domain/entities/kit_look_result.dart).

---

## 8. Recommendation persistence (standard and Kit)

| | Standard | Kit |
| --- | --- | --- |
| Table | `public.recommendations` | `public.kit_makeup_recommendations` |
| Plan payload | `recommendation_json jsonb` | `recommendation_json jsonb` |
| Extra payload | — | `product_snapshot_json` (owned-product snapshot) |
| Style | `makeup_style` | `makeup_style` |
| Provenance | `model_name`, `prompt_version` | `model_name`, `prompt_version` |
| Owner identity | `unique (id, user_id)` | `unique (id, user_id)` |
| Analysis identity | `unique (id, analysis_id, user_id)` | `kit_recommendations_analysis_owner_identity unique (id, analysis_id, user_id)` |

**Idempotency (standard):** before generating, the function looks up an existing
row by `(analysis_id, makeup_style, prompt_version)` ordered by `created_at desc`
and returns it if found. Bumping `MAKEUP_RECOMMENDATION_PROMPT_VERSION` therefore
forks a new recommendation row — and, because previews hang off
`recommendation_id`, a new preview lineage. V2 must not assume one recommendation
per `(analysis, style)`.

**Kit ownership:** `product_snapshot_json` snapshots the user's owned products at
generation time. Per the global prohibitions, V2 consumes this snapshot and the
`kit_recommendation_id` — it must not re-derive product ownership or invent
products.

---

## 9. Original selfie source and ownership path

**Path construction** — [supabase_face_analysis_repository.dart:45](lib/features/analysis/data/repositories/supabase_face_analysis_repository.dart#L45):

```dart
final storagePath = '$userId/analyses/$analysisId/original/$imageId.jpg';
```

Upload is client-side into the **private** `face-images` bucket
(`contentType: 'image/jpeg'`, `upsert: false`), then `analyze-face` is invoked
with `{analysisId, storagePath, localValidation}`. The path is persisted as
`analyses.original_image_path` (`not null`, non-blank check).

**Bucket** (`20260807000200_private_face_images.sql`):
`face-images`, `public = false`, 10 MiB limit, MIME allowlist
`image/jpeg, image/png, image/webp`. Storage RLS on `storage.objects` requires
`(storage.foldername(name))[1] = auth.uid()::text` for select/insert/delete.
**There is no storage `update` policy** — objects are effectively write-once from
the client, which is what keeps originals from being overwritten.

**Server-side ownership gate** —
[storage_ownership.ts](supabase/functions/_shared/storage_ownership.ts)
`isOwnedOriginalPath`: an exact **5-segment** match,
`{userId}/analyses/{analysisId}/original/{uuid}.jpg`, compared
segment-by-segment (deliberately not `startsWith`, which would accept `..`
traversal), with a 36-char hex-UUID filename test and an extension allowlist
defaulting to `["jpg"]`.

> V1 added a sibling `isOwnedTutorialResultPath` for a 6-segment
> `{userId}/analyses/{analysisId}/tutorials/{sessionId}/step_{NNNN}_result.{ext}`
> shape. That helper exists **only on the frozen V1 branch**, not here. V2 will
> need its own equivalent — written fresh, not cherry-picked blindly.

---

## 10. Remote constraints V2 must coexist with

1. **Migration drift is real.** Remote is at `20260816000100`; this branch's
   local history stops at `20260814000200`. Any new V2 migration must be
   timestamped **after `20260816000100`** or the CLI will refuse / mis-order it.
   V2-2 must decide explicitly whether to (a) adopt the three V1 migrations as
   local files, (b) supersede them with a V2 migration, or (c) drop the V1
   objects. **This is a decision for V2-2 with the user, not an assumption.**

2. **`consume_ai_quota` and `ai_usage_events_operation_valid` are shared and
   currently V1-flavored.** Redefining either from this branch's local bodies
   would remove `tutorial_step` / `tutorial_geometry_plan`. New V2 operations
   must be added as a superset of the live remote list.

3. **Two V1 Edge Functions are ACTIVE and JWT-verified.** They are reachable by
   any authenticated client and they write to the live `tutorial_sessions` /
   `tutorial_steps` tables. V2 must either replace them by slug or use new slugs;
   leaving both generations live and writing to the same tables would corrupt
   sessions. Not resolved in this phase.

4. **The `face-images` bucket must stay private,** with the
   `foldername(name)[1] = auth.uid()` prefix rule. All V2 artifacts belong under
   `{userId}/analyses/{analysisId}/...`.

5. **History deletion already covers the whole analysis prefix.**
   `delete-history-item` calls
   `listFilesRecursively(client, "{userId}/analyses/{analysisId}")`, removes every
   object found, then re-lists and fails with `storage_cleanup_incomplete` if
   anything remains — *before* deleting the `analyses` row. **Consequence: if V2
   stores its images under that prefix, the existing function cleans them up with
   no change required.** Storing them anywhere else would create orphans and
   could break deletion. Note the `maximumObjects` cap → `history_too_large`
   (409); a high per-session step count multiplied by guideline + result images
   pushes toward that cap, which is a V2-12 concern.

6. **Composite owner-identity FKs are the ownership idiom.** Every table uses
   `unique (id, user_id)` plus composite FKs carrying `user_id` through, so
   ownership is enforced by the schema, not only by RLS. V2 tables must follow
   the same pattern.

7. **Analysis attributes available to the planner** (`public.analyses`):
   `face_shape`, `skin_tone`, `undertone`, `eye_shape`, `lip_shape`,
   `hair_color`, `eye_color`, `confidence_json`, `raw_ai_metadata`.

8. **`recommendations.model_name` / `prompt_version` are nullable**; history
   read-back substitutes `'unknown'` / `'legacy'`. V2 must tolerate legacy rows
   with absent provenance.

---

## 11. Documentation gap

The phase prompt instructs reading `ARCHITECTURE_NOTES.md`. **That file does not
exist anywhere in the repository** (full tree searched, excluding `.git` and
`build`). `CODEX_MASTER_GUIDE.md` and
`FACETUNE_STEP_BY_STEP_TUTORIAL_V2_SOURCE_OF_TRUTH.md` are present and were used.
Later phases should not block waiting for `ARCHITECTURE_NOTES.md`.

---

## 12. Phase compliance

| Prohibition | Status |
| --- | --- |
| No migrations created | ✅ none |
| No functions deployed | ✅ read-only CLI calls only (`migration list`, `functions list`) |
| No UI implemented | ✅ |
| No stable app behavior modified | ✅ only this file added |
| `main` untouched | ✅ |
| `feature/step-by-step-tutorial` untouched | ✅ read via `git show` only |
| No reset / force push / branch deletion | ✅ |

**Acceptance criteria: met.** All ten required audit items are answered above
with evidence from the live repository and the live project.
