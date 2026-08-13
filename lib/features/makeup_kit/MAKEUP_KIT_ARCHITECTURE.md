# My Makeup Kit — Architecture Contract (MK-1, MK-2, MK-3)

This document records the isolated feature boundary established for My
Makeup Kit and must be read before implementing any later `MK-*` phase.
Source of truth for product behavior: `FACETUNE_MY_MAKEUP_KIT_GUIDE.md`.
Phase sequencing: `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`.

## Scope of this phase (MK-1)

MK-1 establishes typed domain contracts only. It does **not** create a
database schema, product CRUD, Riverpod state, UI, or any Gemini
integration — those are later phases (MK-2 onward). No file outside
`lib/features/makeup_kit/` was modified.

## Feature boundary

Following the project's feature-first convention (see
`lib/features/makeup_styles/` for a comparable domain-first feature with no
data layer yet):

```text
lib/features/makeup_kit/
  MAKEUP_KIT_ARCHITECTURE.md
  domain/
    entities/
      makeup_kit_category.dart      MakeupKitCategory enum
      makeup_kit_finish.dart        MakeupKitFinish enum
      foundation_depth.dart         FoundationDepth enum
      foundation_undertone.dart     FoundationUndertone enum
      makeup_kit_product.dart       MakeupKitProduct entity, MakeupKitProductDraft (MK-3)
    catalog/
      makeup_kit_finish_catalog.dart  category -> allowed finishes
    value_objects/
      normalized_hex_color.dart     NormalizedHexColor
    validation/
      makeup_kit_product_validator.dart  draft validation (MK-3)
    errors/
      makeup_kit_failure.dart       MakeupKitFailure / MakeupKitFailureKind (MK-3)
    repositories/
      makeup_kit_products_repository.dart  MakeupKitProductsRepository interface (MK-3)
  data/
    models/
      makeup_kit_product_dto.dart   row <-> entity mapping, insert/update column maps (MK-3)
    data_sources/
      makeup_kit_products_remote_data_source.dart  Supabase table access (MK-3)
    repositories/
      supabase_makeup_kit_products_repository.dart  real implementation (MK-3)
      unavailable_makeup_kit_products_repository.dart  Supabase-not-configured fallback (MK-3)
    providers/
      makeup_kit_products_providers.dart  repository + revision providers (MK-3)
  presentation/
    controllers/
      makeup_kit_products_state.dart      MakeupKitProductsState (MK-3)
      makeup_kit_products_controller.dart  MakeupKitProductsController (MK-3)
```

`presentation/pages` and `presentation/widgets` do not exist yet and must
only be created when MK-4+ (the UI phases) actually need them — no empty
scaffolding.

## Typed contracts established

- **`MakeupKitCategory`** — the 10 supported product categories from
  `FACETUNE_MY_MAKEUP_KIT_GUIDE.md` §5, each with a stable `code` (e.g.
  `lip_gloss`, `contour_bronzer`) for persistence/AI payload identity.
  Mirrors the `code` pattern used by `MakeupStyle` in
  `lib/features/makeup_styles/domain/entities/makeup_style.dart`, but
  folded directly into the enum (Dart enhanced enums) since no separate
  display name/description catalog is needed until the UI phase (MK-4).
- **`MakeupKitFinish`** — the deduplicated union of finish values across
  all categories, also with a stable `code`.
- **`MakeupKitFinishCatalog`** — the authoritative
  category → allowed-finishes map from guide §8, plus
  `isValidCombination(category, finish)`. This is the single place that
  must be consulted both by future UI (to only offer valid finishes) and
  by future domain/data validation (to reject invalid combinations before
  persistence).
- **`FoundationDepth`** / **`FoundationUndertone`** — Foundation-only
  attributes from guide §9. `FoundationUndertone` is deliberately a
  separate type from the frozen analysis feature's
  `lib/features/analysis/domain/entities/facial_attributes.dart#Undertone`
  (which also has `olive`, and describes *detected skin*, not a *product
  the user owns*). Reusing that type would couple this new feature to the
  frozen recommendation/analysis domain and would be semantically wrong
  (the value sets differ). This is an intentional isolation decision, not
  an oversight.
- **`NormalizedHexColor`** — a validated value object normalizing to the
  exact `^#[0-9A-F]{6}$` shape the existing (frozen)
  `MakeupRecommendationDto` already relies on
  (`lib/features/recommendation/data/models/makeup_recommendation_dto.dart`),
  so a normalized kit color is always compatible with that shape if ever
  compared or reused downstream. This is a **new, additive** type — no
  existing hex-parsing call site (the recommendation DTO or the three
  widgets that convert hex to `Color`) was touched or refactored.

## Isolation from the frozen Makeup Recommendation flow

No file under `lib/features/makeup_kit/` imports from
`lib/features/recommendation/`, `lib/features/analysis/`,
`lib/features/preview/`, `lib/features/saved_looks/`, or
`lib/features/history/`, and no existing file was modified to accommodate
this feature. The only intentional conceptual relationship is documented
above (why `FoundationUndertone` does *not* reuse `Undertone`).

## Smallest safe downstream convergence point (for future MK-8/MK-10)

Audited existing convergence surface for preview/results:

- Preview generation has exactly one entry point:
  `MakeupPreviewRepository.generate({required MakeupRecommendation recommendation})`
  (`lib/features/preview/domain/repositories/makeup_preview_repository.dart`).
  It takes a whole `MakeupRecommendation` and derives everything else
  (original image, etc.) server-side from `recommendation.analysisId`.
- `SavedLook` and `HistoryEntry`
  (`lib/features/saved_looks/domain/entities/saved_look.dart`,
  `lib/features/history/domain/entities/history_entry.dart`) both compose
  `FaceAnalysis` + `MakeupRecommendation` + `MakeupStyle` + `GeneratedPreview`
  as denormalized snapshots assembled by the repository layer, not raw DB
  joins.

This means a future kit-aware recommendation has two possible integration
strategies, both of which stay backward compatible with the frozen types
above:

1. Produce output that maps into the **existing** `MakeupRecommendation`
   shape unchanged, so it flows through the existing preview/saved/history
   types with zero modification to those types; or
2. Introduce a sibling kit-result type and a parallel (not
   dual-purpose-mutated) preview/results path.

Choosing between these is explicitly **out of scope for MK-1** and is
deferred to MK-8 (kit-aware AI recommendation backend) and MK-10 (kit-based
preview integration), per the roadmap. Recording the decision point here
satisfies the MK-1 requirement to "identify the smallest safe downstream
convergence point" without prematurely committing to an implementation.

## Non-goals confirmed for MK-1

Not implemented, per roadmap instruction: database schema/migrations,
product CRUD, any Gemini call, kit recommendation logic, kit preview
logic, and no refactor of existing recommendation architecture for
abstraction purity.

---

## MK-2 — Database Schema & RLS

Migration: `supabase/migrations/20260813000100_makeup_kit_products.sql`.
Purely additive — no existing table, function, trigger, policy, or grant
was modified.

### Table: `public.makeup_kit_products`

One row per registered product. Follows the exact conventions established
in `supabase/migrations/20260807000100_initial_schema.sql` and
`supabase/migrations/20260812000100_ai_usage_quota.sql`:

| Column | Type | Notes |
| --- | --- | --- |
| `id` | `uuid` | PK, `gen_random_uuid()` |
| `user_id` | `uuid` | FK `auth.users(id)`, `on delete cascade` |
| `category` | `text` | allow-listed to the 10 `MakeupKitCategory` codes |
| `product_name` | `text` (nullable) | optional, non-blank if present |
| `color_hex` | `text` | required, `^#[0-9A-F]{6}$` — matches `NormalizedHexColor` output and the existing recommendation DTO's hex shape |
| `color_label` | `text` (nullable) | optional user-friendly shade label, non-blank if present |
| `finish` | `text` | allow-listed to the 10 `MakeupKitFinish` codes (category-specific compatibility is *not* enforced here — see below) |
| `foundation_depth` | `text` (nullable) | allow-listed to `FoundationDepth` codes; must be `null` unless `category = 'foundation'` |
| `foundation_undertone` | `text` (nullable) | allow-listed to `FoundationUndertone` codes; must be `null` unless `category = 'foundation'` |
| `created_at` / `updated_at` | `timestamptz` | UTC defaults; `updated_at` kept fresh by the existing shared `public.set_updated_at()` trigger function (reused, not redefined) |

`constraint makeup_kit_products_owner_identity unique (id, user_id)` is
added from creation — mirroring `analyses`/`recommendations`/
`generated_images` — so a future child table (e.g. a kit recommendation's
selected-product references in MK-8/MK-9) can FK-chain
`(product_id, user_id) references makeup_kit_products(id, user_id)` the
same way `generated_images` chains through `recommendations`, guaranteeing
at the database level that a referenced product can never belong to a
different user.

**Deliberate scope decision:** per-category finish validity (e.g. Lipstick
cannot be Metallic) is enforced only in the Dart domain layer
(`MakeupKitFinishCatalog.isValidCombination`, MK-1), not as a per-category
SQL matrix. The database only enforces that `finish` is one of the 10 known
finish codes overall. This follows the MK-2 instruction to avoid brittle
category-specific SQL where typed application validation already owns the
rule.

### Indexes

- `(user_id, created_at desc)` — pagination, matching every other owned
  table.
- `(user_id, category)` — supports "load/filter by category" (MK-3) and
  the category-organized kit overview (MK-4) without a sequential scan.

### RLS

Identical shape to every existing owned table: RLS enabled, `anon`
fully revoked, `authenticated` granted `select/insert/update/delete`, and
four `_own` policies (`select`/`insert`/`update`/`delete`) each gated on
`(select auth.uid()) = user_id`. Both `using` and `with check` are present
on `update`; `insert` and `update` policies prevent a client from writing a
row with someone else's `user_id` — a spoofed `user_id` fails the RLS
`with check`, not merely a UI-side omission.

### Deployment

**Not applied to any remote project.** This environment has no Supabase
CLI, Docker, or local Postgres available, so the migration could not be
run or syntax-checked against a live server — only carefully hand-verified
against the two migrations above, whose equivalent syntax is already
proven to have applied successfully. Modifying live shared database
infrastructure is also outside what should happen without explicit,
separate authorization.

To apply:

```powershell
supabase db push
```

(or `supabase migration up` against a local dev stack first, if one is
set up, before pushing to the linked remote project).

### Manual verification (run after deployment, in the Supabase SQL editor or via `psql`)

These were **not executed** — no live database was available in this
environment. Run them after deploying to confirm the RLS contract:

```sql
-- As user A (via a client authenticated as A):
insert into public.makeup_kit_products (user_id, category, color_hex, finish)
values (auth.uid(), 'lipstick', '#B86F72', 'matte')
returning id; -- succeeds

-- Attempting to insert a row owned by someone else must fail the RLS check:
insert into public.makeup_kit_products (user_id, category, color_hex, finish)
values ('00000000-0000-0000-0000-000000000000', 'lipstick', '#B86F72', 'matte');
-- expect: new row violates row-level security policy

-- As user B (a different authenticated client), attempting to read/update/
-- delete user A's product id from above must each return zero affected rows:
select * from public.makeup_kit_products where id = '<user-A-product-id>'; -- 0 rows
update public.makeup_kit_products set product_name = 'x' where id = '<user-A-product-id>'; -- 0 rows updated
delete from public.makeup_kit_products where id = '<user-A-product-id>'; -- 0 rows deleted

-- As user A, the same operations on their own row succeed.
```

### Known limitation

This repository has no existing SQL/pgTAP test harness convention (the
project's backend tests are Deno unit tests for Edge Function validation
logic, e.g. `supabase/functions/generate-makeup-recommendation/validation_test.ts`
— none of which this phase touches). No equivalent automated database test
was added; the manual verification steps above are the honest substitute
until a live environment is available.

---

## MK-3 — Domain, Repository & State Foundation

Adds the typed Flutter data/domain/state layer for CRUD against
`makeup_kit_products` (MK-2). No UI and no Gemini call — both remain out of
scope until MK-4+ / MK-8.

### Architectural precedent followed

This is the project's first feature needing full user-authored CRUD
(create/update/delete, not just read + one mutation), so no single existing
feature is a perfect match. Two conventions were deliberately combined:

- **Direct-table CRUD shape** from `settings` and `saved_looks` (not the
  AI-response features `recommendation`/`analysis`/`preview`): a plain
  repository interface with no `usecases/` layer, a `Supabase*Repository`
  that owns exception-to-failure mapping, an `Unavailable*Repository`
  fallback selected via `supabaseAvailableProvider`, and a
  `StateNotifier`-based controller with a `mutatingIds`/generation-guarded
  pattern (`saved_looks`'s `mutatingIds` set and `_loadGeneration` counter
  are reused verbatim as the concurrency-safety idiom). `settings` and
  `saved_looks` have no `domain/usecases/` folder, so neither does
  `makeup_kit` — the project's usecase-wrapper pattern is reserved for the
  AI features, and inventing one here for CRUD would just be an indirection
  with no behavior.
- **DTO/mapper as a dedicated class** from `analysis`/`recommendation`
  (`FaceAnalysisDto`, `MakeupRecommendationDto`): `settings`/`saved_looks`
  parse rows inline in the repository because their shape is simple (a few
  booleans/strings). `makeup_kit_products` has the same enum-heavy shape as
  `FaceAnalysisDto` (7 typed fields, several nullable), so
  `MakeupKitProductDto` follows that file's defensive
  `_requiredString`/`_requiredEnum`/optional-variant helper style rather
  than inlining parsing into the repository.

### Typed contracts added

- **`MakeupKitProduct`** (`domain/entities/makeup_kit_product.dart`) — the
  persisted entity, and **`MakeupKitProductDraft`** in the same file — the
  editable-fields input shared by `create` and `update`. A draft is always
  a *full replacement*, not a sparse patch: `MakeupKitProductValidator`
  therefore re-validates every field on every write, which is what
  guarantees a category change can never leave stale foundation metadata
  behind (the concern MK-6 names explicitly) — this falls out of the
  design for free rather than needing dedicated MK-6 logic later.
- **`MakeupKitProductValidator`** (`domain/validation/`) — enforces
  category/finish compatibility via `MakeupKitFinishCatalog` (MK-1),
  rejects foundation-only fields on non-foundation categories, and rejects
  blank (but non-null) optional text fields. Runs before any network call
  in both `create` and `update`.
- **`MakeupKitFailure`** / **`MakeupKitFailureKind`**
  (`domain/errors/makeup_kit_failure.dart`) — one failure type for the
  whole feature (mirrors `SettingsFailure`'s `kind` + `retryable` shape,
  not `RecommendationFailure`'s or `SavedLooksFailure`'s shape), covering
  `offline` / `timeout` / `sessionExpired` / `validation` / `notFound` /
  `unavailable` / `unknown`. `notFound` specifically covers a product
  disappearing between load and mutation (deleted elsewhere, or RLS
  hiding a row that never belonged to the caller) via PostgREST's
  `PGRST116` "no rows" code on `.single()`.

### Repository

`MakeupKitProductsRepository` (`domain/repositories/`): `loadAll()`,
`loadByCategory(category)`, `create(draft)`, `update(id, draft)`,
`delete(id)`. `SupabaseMakeupKitProductsRepository` never lets a raw
`PostgrestException`/`StorageException`/`FormatException` reach the
caller — every catch path maps to a `MakeupKitFailure` with a safe,
user-facing message (verified by a test that asserts the raw Postgres
error code/message text does not appear in the mapped failure's
`toString()`). A malformed row from the database (should be prevented by
the MK-2 constraints, but never trusted blindly) surfaces as
`MakeupKitFailureKind.validation`, not a crash.

`loadByCategory` exists on the repository (and is tested) to satisfy the
"load/filter by category" requirement at the persistence layer, but the
controller does not call it for normal browsing — `MakeupKitProductsState`
loads the full kit once and exposes `byCategory(category)` as a pure
in-memory filter, avoiding a duplicate network round trip per category tab
(CODEX guide §24: avoid duplicate network calls). `loadByCategory` remains
available for a future large-kit pagination need.

### State / controller

`MakeupKitProductsController` (`presentation/controllers/`): `load()` /
`refresh()`, `createProduct(draft)`, `updateProduct(id, draft)`,
`deleteProduct(id)`. Concurrency safety mirrors `SavedLooksController`
exactly: an incrementing `_loadGeneration` discards a stale `load()`
response if a newer one has since started, and `mutatingIds` /
`isCreating` guard against duplicate taps on the same in-flight operation.
Every outcome — success or failure — is surfaced through
`state.feedback` / `state.feedbackIsError`, never a raw exception.

### Validation coverage confirmed

Category, finish/category compatibility, normalized HEX, category-specific
(foundation) fields, and foundation depth/undertone are each covered by
dedicated tests at the value-object (MK-1), validator, and DTO-parsing
layers — see Files Created below.

### Non-goals confirmed for MK-3

No UI (`presentation/pages`, `presentation/widgets` do not exist), no
Gemini/kit-recommendation logic, and no change to any existing feature.
