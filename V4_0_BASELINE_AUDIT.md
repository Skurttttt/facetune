# V4-0 — BASELINE AUDIT & DUAL-MODE INTEGRATION MAP

**Branch:** `feature/step-by-step-tutorial-v4-ai`
**HEAD:** `eb6c5e379fb9e71233f893a3edf42a9db88959ed` ("Merge My Makeup Kit feature into main")
**Audit date:** 2026-08-30
**Scope:** inspection only. No feature code, migrations, Edge Functions, or dependencies were added.

---

## 1. GIT BASELINE (PROVEN)

| Fact | Evidence |
| --- | --- |
| Current branch | `git branch --show-current` -> `feature/step-by-step-tutorial-v4-ai` |
| V4 ancestry | `git merge-base --is-ancestor main HEAD` -> true |
| Divergence from `main` | **Zero.** `git rev-parse HEAD` == `git rev-parse main` == `eb6c5e3` |
| `git diff main...HEAD --stat` | empty |
| Working tree | `M NOTES.md`, untracked `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md`, `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md` |

V4 branch ancestry is clean. No V3 branch content is present.

`feature/my-makeup-kit` (`525f178`) was inspected **read-only** with `git log`, `git show --stat`,
and `git diff` — never checked out, merged, cherry-picked, or rebased. Results:

| Check | Result |
| --- | --- |
| `git merge-base --is-ancestor feature/my-makeup-kit HEAD` | true — fully contained in HEAD |
| `git log --oneline HEAD..feature/my-makeup-kit` | empty — no unique commits |
| `git diff --stat HEAD..feature/my-makeup-kit` | empty — trees identical |

The kit code is therefore already present in the working tree and was audited directly from `lib/`
and `supabase/` rather than from the branch. There is nothing on that branch to merge, which also
means V4 has no reason to ever touch it.

The two identically-titled `MK-14` commits are **not** duplicated work:
`21be006` is the real change (19 files: repositories, controllers, pages, the
`20260814000200_makeup_kit_hardening.sql` migration, and a 688-line
`test/e2e/makeup_kit_journey_test.dart`), while `525f178` only deletes 20 lines from `NOTES.md`.
The same pattern explains the paired `MK-6` commits.

An in-repo design record already exists at `lib/features/makeup_kit/MAKEUP_KIT_ARCHITECTURE.md`
(42 KB, "My Makeup Kit — Final Architecture & Operations Contract (MK-1 through MK-14)"). It
documents the kit's typed contracts, its deliberate isolation from the frozen Makeup Recommendation
flow, and — directly relevant to V4 — a section titled "Smallest safe downstream convergence point".
Later V4 phases should read it before extending kit code.

Branches present locally: `main`, `backup/phase-22`, `feature/my-makeup-kit`,
`feature/step-by-step-tutorial` (V1), `feature/step-by-step-tutorial-v2`,
`feature/step-by-step-tutorial-v3`, `feature/step-by-step-tutorial-v4-ai`.

---

## 2. BASELINE VALIDATION RESULTS

| Command | Result |
| --- | --- |
| `flutter analyze` | **No issues found!** (18.9s, exit 0) |
| `flutter test` | **All tests passed** — 292 tests, exit 0 |

No Android build was run: this phase adds no code, so APK compilation would prove nothing new.

---

## 3. V3 / FORBIDDEN-TECHNOLOGY RESIDUE CHECK (PROVEN CLEAN)

Repo-wide grep over `lib/` and `pubspec.yaml` for
`mediapipe|opencv|tflite|CustomPainter|face_mesh|landmark`: **zero matches.**

Repo-wide grep for `tutorial` in `lib/`: **zero matching files.**

`pubspec.yaml` dependencies: `cupertino_icons, flutter_riverpod, go_router,
flutter_image_compress, image_picker, path, path_provider, permission_handler,
supabase_flutter, uuid, share_plus, package_info_plus`. No geometry/CV package exists.

**Conclusion:** there is no V3 geometry pipeline, no CustomPainter face-guideline code, and no
tutorial feature of any generation on this branch. V4 starts from a genuinely empty tutorial surface.

---

## 4. STANDARD MODE INTEGRATION MAP (FROM REAL CODE)

### 4.1 Flow

```text
scan -> analysis -> style selection -> recommendation-mode selection -> recommendation -> preview -> results / saved / history
```

Routes (`lib/core/constants/app_constants.dart:12-33`, wired in `lib/app/router/app_router.dart`):
`/scan`, `/analysis`, `/styles`, `/recommendation-mode`, `/recommendation`, `/preview`, `/saved`,
`/history`, `/makeup-kit`, `/makeup-kit/add-product`, `/makeup-kit/product/:productId`,
`/makeup-kit/recommendation-entry`, `/profile`, `/settings`.

### 4.2 Flutter layers (Clean Architecture, feature-first, already consistent)

| Concern | Files |
| --- | --- |
| Selfie capture / validation | `lib/features/scan/**` (`scan_controller.dart`, `device_selfie_repository.dart`, `selfie_file_validator.dart`) |
| Face analysis | `lib/features/analysis/**` (`analyze_face.dart`, `supabase_face_analysis_repository.dart`, `face_analysis.dart`) |
| Style catalog | `lib/features/makeup_styles/**` |
| Recommendation | `lib/features/recommendation/**` (`generate_makeup_recommendation.dart`, `supabase_makeup_recommendation_repository.dart`) |
| Canonical preview | `lib/features/preview/**` (`generate_makeup_preview.dart`, `supabase_makeup_preview_repository.dart`, `generated_preview.dart`, `preview_result_page.dart`) |
| Result presentation / share | `lib/features/results/**` (`before_after_comparison.dart`, `makeup_breakdown.dart`, `result_actions_controller.dart`) |
| Saved looks / history | `lib/features/saved_looks/**`, `lib/features/history/**` |
| DI / Supabase | `lib/core/di/dependency_injection.dart`, `lib/core/supabase/**`, `lib/core/data/supabase_remote_data_source.dart` |

Every repository has an `unavailable_*` fallback implementation — an established pattern V4
tutorial repositories must follow.

### 4.3 Canonical preview and original-selfie lineage (PROVEN)

`lib/features/preview/domain/entities/generated_preview.dart` already carries the exact lineage V4
needs for its two mandatory image references:

```text
id, analysisId, recommendationId,
originalImagePath, generatedImagePath,
originalImageUrl, generatedImageUrl,
generationNumber, modelId, promptVersion, createdAt
```

- **Image A (original selfie)** = `analyses.original_image_path`
- **Image B (canonical final preview)** = `generated_images.storage_path` (standard) /
  `kit_generated_images.storage_path` (kit)

Both live in the private `face-images` bucket.

### 4.4 Server-authoritative input resolution (ALREADY CORRECT — REUSE, DO NOT REBUILD)

`supabase/functions/generate-makeup-preview/index.ts:169-220` is the reference implementation of
SoT section 20:

1. Client sends **only** `recommendationId`.
2. Server reads `recommendations` -> `analysis_id` (RLS-scoped).
3. Server reads `analyses` -> `original_image_path`.
4. Server calls `isOwnedOriginalPath(path, userId, analysisId, [...])`
   (`supabase/functions/_shared/storage_ownership.ts:9`), which does **segment-by-segment** path
   validation and therefore rejects traversal and extra segments.
5. Quota, source download, and generation-number lookup run in `Promise.all` **before** Gemini.
6. The output path is rejected if it collides with the original or lands under `/original/`.

**V4 must reuse this exact pattern.** The tutorial functions will additionally need an analogous
`isOwnedGeneratedPreviewPath` helper — it **does not exist yet**; `storage_ownership.ts` exports
only `isOwnedOriginalPath`. (`delete-history-item/storage_paths.ts` exports `historyPrefix`,
`isOwnedHistoryPath`, `assertOwnedHistoryPaths` — a prefix-based variant, not sufficient alone.)

---

## 5. MY MAKEUP KIT STATUS (PROVEN: FULLY IMPLEMENTED, NOT A GAP)

My Makeup Kit is **complete and merged**, not pending. This materially reduces V4-1 through V4-5
scope.

### 5.1 Database

| Table | Migration |
| --- | --- |
| `makeup_kit_products` | `20260813000100_makeup_kit_products.sql` |
| `kit_makeup_recommendations` | `20260813000200_kit_makeup_recommendations.sql` |
| `kit_generated_images` | `20260813000300_kit_generated_images.sql` |
| `kit_saved_looks` | `20260814000100_kit_saved_looks.sql` |
| category x finish hardening | `20260814000200_makeup_kit_hardening.sql` |

All have RLS enabled with per-operation `select / insert / update / delete _own` policies and
`(id, user_id)` owner-identity unique constraints used as composite FK targets — the ownership
idiom V4 tables must copy.

### 5.2 Inventory category vocabulary (DB-enforced, 10 values)

```text
foundation, concealer, blush, highlighter, eyeshadow,
lipstick, lip_gloss, contour_bronzer, eyebrow, eyeliner
```

Finishes: `matte, natural, dewy, satin, radiant, shimmer, metallic, glitter, cream, glossy`,
further constrained per category by `makeup_kit_products_category_finish_valid`
(`20260814000200`). Foundation-only fields (`foundation_depth`, `foundation_undertone`) are scoped
by `makeup_kit_products_foundation_fields_scoped`.

Mirrored in Dart at `lib/features/makeup_kit/domain/entities/makeup_kit_category.dart`,
`makeup_kit_finish.dart`, `domain/catalog/makeup_kit_finish_catalog.dart`, and in TypeScript at
`supabase/functions/generate-kit-makeup-recommendation/validation.ts:24-35`
(`supportedCategories`).

### 5.3 Immutable product snapshot (ALREADY EXISTS)

`kit_makeup_recommendations.product_snapshot_json jsonb not null`, constrained to a JSON array and
written at `generate-kit-makeup-recommendation/index.ts:237-249` with
`{productId, category, productName, colorHex, colorLabel, finish, foundationDepth, foundationUndertone}`.

This satisfies SoT section 7.6 in substance today.

### 5.4 Server-side product validation (ALREADY EXISTS)

`generate-kit-makeup-recommendation/index.ts`:

- loads inventory through the RLS-scoped **user** client (`:165-169`)
- rejects an empty kit -> `422 empty_kit` (`:176`)
- rejects any row whose `user_id` is not the caller -> `403 ownership_mismatch` (`:185`)
- rejects unsupported inventory categories -> `422 unsupported_inventory_category`
  (`validation.ts:74`)
- `parseAndValidateKitRecommendation` enforces strict key sets, UUID format, no duplicate ids, and
  membership in the owned inventory map -> `502 fabricated_product` (`validation.ts:108-120`)
- **re-reads the selected rows after the AI call** and calls `assertProductsUnchanged` to detect
  edit/delete races (`index.ts:220-236`)

There is **no** silent fallback from kit mode to standard mode anywhere in this function.

### 5.5 Dual mode already exists in Flutter

`lib/features/makeup_kit/domain/entities/makeup_recommendation_mode.dart:3`

```dart
enum MakeupRecommendationMode { standard, makeupKit }
```

with `recommendation_mode_selection_page.dart`, `makeup_recommendation_mode_controller.dart`, and
route `/recommendation-mode`. `history_page.dart` already renders both standard and kit entries.

### 5.6 Kit preview path

`supabase/functions/generate-kit-makeup-preview/index.ts` mirrors the standard preview but resolves
inputs from `kit_makeup_recommendations` plus `product_snapshot_json`, re-validates snapshot product
ids against `makeup_kit_products` (`:200-226`), and reuses `isOwnedOriginalPath` (`:228-233`).

---

## 6. AI CONFIGURATION BASELINE (PROVEN FROM CODE)

| Function | Model env var | Default in code |
| --- | --- | --- |
| `analyze-face` | `GEMINI_MODEL` | `gemini-3.6-flash` (`index.ts:123`) |
| `generate-makeup-recommendation` | `GEMINI_MODEL` | `gemini-3.6-flash` (`index.ts:142`) |
| `generate-kit-makeup-recommendation` | `GEMINI_MODEL` | `gemini-3.6-flash` (`index.ts:210`) |
| `generate-makeup-preview` | `GEMINI_IMAGE_MODEL` | `gemini-3.1-flash-image` (`index.ts:298`) |
| `generate-kit-makeup-preview` | `GEMINI_IMAGE_MODEL` | `gemini-3.1-flash-image` (`index.ts:297`) |

**No output-resolution / `imageConfig` / `aspectRatio` setting exists anywhere in the preview
functions.** Resolution is currently whatever the model returns by default. The SoT section 11
"one maintainable server-side location" for model + resolution + prompt version does not exist yet;
today model IDs are per-function env lookups with inline string defaults.

### 6.1 CONTRADICTION REQUIRING A DECISION (see section 13)

SoT section 10.1 states the final makeup preview model is **`gemini-3-pro-image`** and instructs
"keep the working final preview model". The repository's actual default is
**`gemini-3.1-flash-image`** — the *same* model SoT section 10.2 locks for tutorial guideline
rendering. `NOTES.md` also names `gemini-3-pro-image`, while
`docs/GEMINI_MAKEUP_PREVIEW_SETUP.md:8` names `gemini-3.1-flash-image`.

Per the phase rule "production evidence wins over stale documentation", the code is the stronger
evidence — but the deployed `GEMINI_IMAGE_MODEL` secret could override it, so this is recorded as
unproven rather than decided.

---

## 7. QUOTA / SECURITY BASELINE

`public.ai_usage_events` plus `public.consume_ai_quota(p_operation)` (SECURITY DEFINER,
`set search_path = ''`), latest definition in `20260813000300_kit_generated_images.sql:76-120`.

Operation vocabulary is enforced by a check constraint **and** an in-function limits table:

```text
face_analysis              20/h  100/d
makeup_recommendation      40/h  200/d
kit_makeup_recommendation  40/h  200/d
makeup_preview             30/h  120/d
kit_makeup_preview         30/h  120/d
```

An unknown operation returns `unsupported_operation` and is denied. `consumeAiQuota`
(`_shared/ai_quota.ts:37`) **fails closed** on error. `authenticated` has no insert/update/delete
grant on `ai_usage_events`; only the definer function writes to it.

**Pattern V4 must follow:** a new tutorial migration must extend the check constraint *and* the
`values (...)` limits table *and* the `AiOperation` union in `_shared/ai_quota.ts`, exactly as
`20260813000200` and `20260813000300` did.

Storage buckets, both private:

| Bucket | Size limit | MIME |
| --- | --- | --- |
| `face-images` | 10 MiB | jpeg, png, webp |
| `profile-avatars` | 2 MiB | jpeg |

`face-images` policies are `face_images_select_own`, `face_images_insert_own`,
`face_images_delete_own` — there is no update policy.

---

## 8. SCHEMA GAPS FOR V4 (NOTHING EXISTS YET)

Missing entirely — each must be created by V4-2:

| Needed | SoT ref | Status |
| --- | --- | --- |
| `tutorial_sessions` | 22.4 | **absent** |
| `tutorial_steps` | 22.5 | **absent** |
| manifest persistence (session columns or normalized manifest items) | 22.3 | **absent** |
| tutorial storage prefix and policies under `face-images` | 24 | **absent** |
| quota operations for manifest and step generation | 42 | **absent** |
| `look_product_snapshots` / `look_product_snapshot_items` | 22.2 | **superseded — see 8.1** |

### 8.1 Snapshot normalization decision needed

SoT section 22.2 proposes normalized `look_product_snapshots` and `look_product_snapshot_items`.
Working production code already persists `kit_makeup_recommendations.product_snapshot_json` as a
JSONB array.

SoT section 22.5 requires a tutorial step to "resolve the exact immutable product snapshot item(s)"
and forbids comma-separated product ids, which implies a joinable row per snapshot item. A JSONB
array has no stable row identity to join against.

Smallest production-safe option (recommended for V4-2): keep `product_snapshot_json` as the
authoritative immutable record and add a **derived, additive** `look_product_snapshot_items` table
populated from it, rather than migrating or rewriting the working kit recommendation path. This
preserves SoT section 45 (existing feature preservation) while satisfying section 22.5's join
requirement.

---

## 9. RLS / STORAGE / SECURITY GAPS FOR V4

These are not defects in current code — they are gaps for the work V4 will add:

1. No tutorial tables exist, so no tutorial RLS policies exist.
2. `face-images` has no `update` policy, so V4 tutorial step regeneration must write a new path
   rather than overwrite — consistent with the existing `generation_number` idiom.
3. No `isOwnedGeneratedPreviewPath` helper exists. V4 needs one to prove Image B ownership with the
   same segment-by-segment rigor as `isOwnedOriginalPath`.
4. `delete-history-item` currently knows nothing about tutorial artifacts. V4-13 must extend its
   path allow-list or tutorial storage objects will leak when history is deleted.
5. `config/development.json` exposes only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` — correct;
   no Gemini key reaches Flutter. V4 must keep it that way.

---

## 10. EXACT FILES LATER PHASES SHOULD EXTEND

| Phase | Extend |
| --- | --- |
| V4-1 (domain / contracts) | new `lib/features/tutorial/domain/**`; reuse `makeup_recommendation_mode.dart`, `makeup_kit_category.dart`, `generated_preview.dart`, `kit_look_result.dart` |
| V4-2 (persistence / RLS) | new `supabase/migrations/2026083*_tutorial_*.sql`, modeled on the `20260813000300_kit_generated_images.sql` composite-FK + RLS idiom; extend the `ai_usage_events` constraint and `consume_ai_quota` limits |
| V4-3 (kit inventory flow) | already implemented — expect near-zero change to `lib/features/makeup_kit/**` |
| V4-4 (dual-mode recommendation + validation) | already implemented — verify only `generate-kit-makeup-recommendation/{index,validation}.ts` |
| V4-5 (canonical preview integration) | `generate-makeup-preview/index.ts`, `generate-kit-makeup-preview/index.ts`, `lib/features/preview/**` |
| V4-6 (manifest analyzer) | new `supabase/functions/analyze-tutorial-manifest/**`, patterned on `analyze-face/{index,prompt,schema,validation}.ts`, which already performs strict structured-output validation |
| V4-7 / V4-8 (repository + source resolution) | new `lib/features/tutorial/data/**`; reuse `_shared/storage_ownership.ts` |
| V4-9 / V4-10 (guideline renderer) | new `supabase/functions/generate-tutorial-step/**`, patterned on `generate-makeup-preview/**` |
| V4-11 (orchestration / cost) | `_shared/ai_quota.ts` (`AiOperation` union) |
| V4-12 (UI) | new `lib/features/tutorial/presentation/**`; register the route in `app_constants.dart` and `app_router.dart`; entry points in `preview_result_page.dart` and `makeup_kit_recommendation_entry_page.dart` |
| V4-13 (history / deletion) | `history_page.dart`, `makeup_kit_history_controller.dart`, `supabase/functions/delete-history-item/**` |
| V4-14 (hardening) | `_shared/ai_quota.ts`, `_shared/storage_ownership.ts`, migrations |

Centralized AI config (SoT section 11) has no home today. Recommend a new
`supabase/functions/_shared/tutorial_ai_config.ts` in V4-9 rather than per-function string defaults.

---

## 11. ASSUMPTIONS REQUIRING RUNTIME PROOF (NOT PROVEN BY THIS AUDIT)

1. **Which image model production actually uses.** Code defaults to `gemini-3.1-flash-image`, but
   `GEMINI_IMAGE_MODEL` may be set to `gemini-3-pro-image` in deployed Supabase secrets. Only
   inspecting the deployed function secrets, or reading a live generation's persisted
   `generated_images.model_name`, can settle this. **Unproven.**
2. **`gemini-3.1-flash-image` availability and API contract** for guideline rendering, and whether
   it accepts an explicit `1K` output-resolution parameter. SoT section 10.2 requires verifying this
   before the first production integration. **Unproven.**
3. **Which Gemini model the manifest analyzer should use.** SoT section 11A says prefer the existing
   approved structured-output model, which is `gemini-3.6-flash` (`analyze-face`). **Not yet
   approved by the user.**
4. **Whether migrations `20260813*` and `20260814*` are applied to the live project.** Local
   migration files are not proof of deployed state.
5. **Device behavior on POCO X3 GT.** No device run was performed in this phase.

Resolved during this audit and therefore no longer an open assumption: the paired `MK-6` / `MK-14`
commits are not duplicated work (see section 1).

---

## 12. SMALLEST V4-1 IMPLEMENTATION BOUNDARY

Because dual mode, kit inventory, snapshots, and server-side product validation already exist, V4-1
should be **additive only**:

- create `lib/features/tutorial/domain/` containing: the tutorial category enum (the nine-value
  tutorial vocabulary from SoT section 17), the inventory-category to tutorial-category mapping
  (`lipstick | lip_gloss -> lips`, `contour_bronzer -> contour_bronzer`, `eyebrow -> eyebrows`),
  tutorial session / step / manifest entities, failure types, and repository interfaces
- **reuse** `MakeupRecommendationMode` rather than introduce a second mode enum
- do **not** touch `lib/features/makeup_kit/**`, `lib/features/preview/**`, or any Edge Function
- the mapping must be duplicated server-side in TypeScript and covered by tests in both languages,
  per SoT section 17 ("server-owned and tested")

---

## 13. OPEN DECISIONS FOR THE USER

1. **Final preview model.** Is `gemini-3-pro-image` (SoT 10.1) or `gemini-3.1-flash-image` (code)
   correct? If the SoT is right, production is already off-contract and V4-5 must reconcile it.
2. **Snapshot normalization.** Derived additive table versus rewriting the working kit path
   (section 8.1).
3. **Manifest analyzer model approval** (SoT section 11A).
