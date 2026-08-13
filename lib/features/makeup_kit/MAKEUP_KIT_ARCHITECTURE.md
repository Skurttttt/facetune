# My Makeup Kit — Final Architecture & Operations Contract (MK-1 through MK-14)

This document records the isolated feature boundary and completed operating
contract for My Makeup Kit. It must be read before maintaining or extending
the feature.
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

**Final hardening:** MK-2 initially left per-category finish compatibility to
the typed application layer. MK-12 later added the additive
`makeup_kit_products_category_finish_valid` SQL check in migration
`20260814000200_makeup_kit_hardening.sql`. The UI, Dart validator, Edge
Functions, and PostgreSQL now enforce the same category/finish matrix so a
direct authenticated REST mutation cannot bypass the rule.

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

---

## MK-4 — Kit Overview & Category UX

The premium inventory-browsing screen, read-only. No Gemini/kit
recommendation logic, no add/edit/delete flow yet (MK-5/MK-6) — the "Add
Product" affordances intentionally show a "coming in the next update"
message rather than reaching into unbuilt scope.

### Files added

```text
lib/features/makeup_kit/presentation/
  utils/
    makeup_kit_display.dart        category/finish/depth/undertone display labels + icons,
                                    NormalizedHexColor -> Color conversion
  widgets/
    makeup_kit_color_swatch.dart   circular color preview
    makeup_kit_product_tile.dart   one product row (swatch, title, subtitle)
    makeup_kit_category_section.dart  one category's header + products/empty state
  pages/
    makeup_kit_overview_page.dart  loading / error / empty / populated states
```

Display labels/icons were deliberately withheld from the domain layer in
MK-1 pending the first phase that actually needed them — this is that
phase, and they live in `presentation/utils`, not on the domain enums
themselves, so the domain layer stays free of Flutter (`dart:ui`)
dependencies.

### Files modified (additive only)

- `lib/core/constants/app_constants.dart` — added `makeupKitRoute`.
- `lib/app/router/app_router.dart` — added one `GoRoute` entry. No
  existing route's path, name, builder, or the `redirect`/auth-guard logic
  was touched.
- `lib/features/profile/presentation/pages/profile_page.dart` — added one
  `ListTile` ("My Makeup Kit") to the existing "Your library" card,
  alongside "Saved looks" and "FaceTune history", using the same
  `context.push` pattern already used there for "Settings and privacy".
  No existing tile, card, or profile behavior was changed.

`lib/shared/widgets/app_shell.dart` (the bottom navigation bar) was
deliberately **not** touched — My Makeup Kit is a pushed sub-page like
Settings, not a fifth bottom-nav tab, so the four existing tabs and their
indices are unaffected.

### Screens / components

`MakeupKitOverviewPage`: `Scaffold` + `AppBar` + `FloatingActionButton.extended`
("Add Product") — same shape as `SettingsPage`, not `AppShell` (no bottom
nav, since this isn't a tab). Body switches on
`MakeupKitProductsStatus`:

- **loading** — three `SkeletonCard(imageHeight: 0)` rows (reused
  as-is, not a new skeleton component).
- **failure** — `StatusState` with a session-expiry-aware retry action,
  matching the exact pattern in `SettingsPage`/`ProfilePage`/
  `SavedLooksPage`.
- **ready, empty kit** — `StatusState` ("Your kit is empty") with an Add
  Product action.
- **ready, populated** — one `AppCard` containing all ten categories in a
  fixed, stable order (`MakeupKitCategory.values`), each rendered via
  `MakeupKitCategorySection`: category icon/label, a count (or "No
  products"), and either its product tiles or "No products in this
  category yet." Multiple products per category render as a plain list —
  no artificial one-per-category assumption anywhere.
- **guest accounts** — the same-style `AppCard(color: AppColors.petal)`
  notice used on `SavedLooksPage`, reworded for kit context, satisfying
  the master guide's "guest data must be handled safely" requirement.

### Navigation

Entry point: Profile → "Your library" → "My Makeup Kit" (`context.push`).
Route `/makeup-kit`, name `makeupKit`. Already auth-gated for free by the
router's existing global `redirect` (not in the `publicRoutes` allow-list).

### State integration

Uses MK-3's `makeupKitProductsControllerProvider` unmodified — no new
providers or state fields were needed for a read-only overview.
`RefreshIndicator` calls the existing `refresh()`.

### Bug found and fixed during testing

`MakeupKitProductTile`'s title falls back to `finish.label` when a product
has neither a name nor a color label; the initial subtitle logic still
unconditionally included `finish.label` too, so an unnamed product's card
showed the finish word twice (once as title, once as subtitle) — caught by
a widget test asserting `find.text('Satin')` was unique. Fixed by only
including the finish label in the subtitle when a title (name or color
label) is actually present, falling back to the product's HEX value in the
rare case neither is set. Also replaced a stringly-typed
`product.category.code == 'foundation'` check with a type-safe
`product.category == MakeupKitCategory.foundation` comparison while fixing
this.

### Tests

`test/features/makeup_kit/makeup_kit_overview_page_test.dart` — loading
(skeletons), empty kit (+ Add Product action), populated (category labels,
product title/subtitle, empty-category text), and retryable error (+
successful retry) states, all via a fake `MakeupKitProductsRepository`
override — no real Supabase/network involved.

### Non-goals confirmed for MK-4

No recommendation-mode selector, no Gemini call, no add/edit/delete
mutation UI (Add Product shows an honest "coming in the next update"
message instead), no change to `AppShell`'s bottom navigation, no change
to any frozen Makeup Recommendation file.

---

## MK-5 — Add Product & Visual Color Picker

Implements the real Add Product flow that MK-4 deferred. Edit/Delete
remain out of scope (MK-6).

### Files added

```text
lib/features/makeup_kit/presentation/
  utils/
    makeup_kit_curated_shades.dart   CuratedShade + per-category palette
  widgets/
    makeup_kit_color_picker.dart     curated shades + HSV sliders + advanced HEX
    makeup_kit_finish_selector.dart  single-select chips, pre-filtered by category
    makeup_kit_foundation_attributes_selector.dart  Depth + Undertone chips
  pages/
    add_makeup_kit_product_page.dart  the single reactive form
```

### Files modified

- `lib/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart`
  — the FAB and empty-state "Add Product" actions now `context.push` the
  real route instead of showing MK-4's placeholder SnackBar. This is
  completing MK-4's own documented deferral, not touching unrelated
  behavior.
- `lib/core/constants/app_constants.dart` / `lib/app/router/app_router.dart`
  — added `makeupKitAddProductRoute` and its `GoRoute`. No existing route
  changed.
- `lib/features/makeup_kit/presentation/controllers/makeup_kit_products_controller.dart`
  — see "Bug found and fixed" below. This is the one MK-3 file this phase
  had to touch, and only to fix a genuine correctness bug this phase's own
  testing surfaced — not a refactor.

### Color picker

`MakeupKitColorPicker` combines, per FACETUNE_MY_MAKEUP_KIT_GUIDE.md §7:

- **Curated shades** — `MakeupKitCuratedShades.forCategory(category)`, a
  brand-neutral, hand-picked reference palette per category (e.g. Lipstick:
  Nude Rose, Peach Nude, Soft Pink, Terracotta, Deep Red, Berry). Tapping
  one sets both the color and its label in one action — no HEX literacy
  required.
- **Selected-color preview** — swatch + "Selected: <label or HEX>".
- **Precise adjustment** — three `Slider`s (Hue/Saturation/Brightness)
  driven by `HSVColor`, with no new package dependency: Flutter's built-in
  `HSVColor`/`HSVColor.toColor()` already do the color math; only the
  reverse direction (`Color` → HEX string) needed a small helper, written
  against `Color.toARGB32()` (Flutter 3.38 — `.value`/`.red`/`.green`/
  `.blue` are deprecated in this SDK in favor of the `.r`/`.g`/`.b` double
  API and `.toARGB32()`, confirmed by reading the installed
  `dropdown.dart`/`Color` source directly rather than assuming).
- **Advanced HEX entry** — an optional `TextField`; `NormalizedHexColor.tryParse`
  gates it, so an invalid value shows an inline error and never reaches
  `onColorSelected` — invalid HEX cannot be saved, by construction.
- Adjusting a slider or entering a valid HEX clears the curated label
  (the color is no longer a named shade); tapping a curated shade always
  wins back both the color and the label together.

### Category-specific form

`AddMakeupKitProductPage` is one reactive form, not a wizard: picking a
category immediately re-filters `MakeupKitFinishSelector`'s options via
`MakeupKitFinishCatalog.allowedFinishes` (MK-1) and shows/hides
`MakeupKitFoundationAttributesSelector`. Switching category also resets
color to that category's first curated shade and clears an
now-incompatible finish/Depth/Undertone selection — this is the same
mechanism that will satisfy MK-6's "no stale foundation metadata after a
category change" requirement, since a draft is always built fresh from
current form state, never patched.

### Save behavior

- **Validation**: category/finish combinations are impossible to
  mis-select in the UI (chips are pre-filtered); `NormalizedHexColor` makes
  an invalid color unrepresentable in state; `MakeupKitProductValidator`
  (MK-1/MK-3) still re-validates in the repository as defense in depth.
- **Loading**: the Save button shows "Saving…" and disables while
  `state.isCreating`.
- **Duplicate-submit protection**: reuses MK-3's existing
  `if (state.isCreating) return` guard in the controller — no new
  mechanism needed.
- **Success feedback**: SnackBar via the same `ref.listen` pattern used on
  every other page, then the screen pops back to the kit overview (which
  already shows the new product — same shared controller state, no manual
  refresh).
- **Recoverable-failure preservation**: the form's fields live in
  `AddMakeupKitProductPage`'s own `State` and are never cleared except on
  confirmed success, so a failed save leaves every entered value in place.

### Bug found and fixed during testing

A widget test for the failure path (`a failed save keeps the user on the
page...`) caught a real race condition: `_submit()` originally awaited
`createProduct()` and then re-read `ref.read(controllerProvider).feedbackIsError`
to decide whether to pop. But the page's own `ref.listen` reacts to that
*same* state change synchronously and calls `clearFeedback()` — which
resets `feedbackIsError` back to `false` — before the `await` in `_submit`
resumes. The result: a **failed** save was incorrectly treated as
successful, popping the form. Fixed by changing
`MakeupKitProductsController.createProduct` (and, for the same reason,
`updateProduct`/`deleteProduct`) to return `Future<bool>` reporting the
outcome directly, so the caller never needs to re-read racy ambient state.
This is a backward-compatible signature change — existing MK-3 callers
that `await` without using the return value are unaffected, confirmed by
rerunning `makeup_kit_products_controller_test.dart`.

### Tests

- `makeup_kit_color_picker_test.dart` — curated shade selection, valid/invalid
  HEX entry, slider-driven custom color, category-specific palette contents.
- `add_makeup_kit_product_page_test.dart` — default Foundation state shows
  Depth/Undertone; Lipstick/Eyeshadow/Blush/Eyeliner each show exactly
  their documented finishes and nothing else; switching away from
  Foundation clears Depth/Undertone from the submitted draft; successful
  save pops back to the caller; a failed save keeps the page and entered
  values (the bug above); duplicate taps while saving submit exactly once.
- `makeup_kit_overview_page_test.dart` updated: the old "coming soon"
  assertion is replaced with a real navigation check now that MK-5 exists.

### Non-goals confirmed for MK-5

No camera-based shade detection. No Edit/Delete UI (MK-6). No brand
field. No change to any frozen Makeup Recommendation file.

---

## Final implemented system (MK-6 through MK-14)

The sections above preserve the phase-by-phase decisions through MK-5. This
section is the current maintenance contract for the completed feature and
supersedes historical “future phase” or “non-goal” wording above where later
phases implemented that capability.

### Current feature topology

```text
Profile -> My Makeup Kit
  -> inventory overview (10 typed categories)
  -> add / product details / edit / confirmed delete

Scan -> Analysis -> Style -> Recommendation mode
  -> Makeup Recommendation (existing frozen path)
  -> My Makeup Kit
       -> validate non-empty authenticated inventory
       -> generate-kit-makeup-recommendation
       -> generate-kit-makeup-preview
       -> kit result / save / favorite / variation
       -> Saved Looks / History / reopen
```

The implementation remains under `lib/features/makeup_kit/` except for the
small additive routing, Profile entry, and kit sections in the shared Saved
Looks and History pages. Standard recommendation domain models,
repositories, prompts, endpoints, preview generation, and result behavior
remain separate and unchanged.

### Presentation and UX contract

- The overview supports loading skeletons, pull-to-refresh, session-aware
  recovery, intentional empty state, a guest-retention notice, multi-product
  categories, product/category counts, and an explicit statement that
  incomplete kits are welcome.
- Add/Edit is one reactive form. Category selection limits visible finishes
  and mounts Foundation depth/undertone only for Foundation. Changing away
  from Foundation clears those fields before creating the replacement draft.
- Visual curated shades are the primary color interaction. Optional precise
  HSV controls and the technical HEX reference are collapsed under
  “Fine-tune shade”; users never need to know or enter HEX.
- Product details show the registered swatch, category, shade, finish, and
  relevant Foundation metadata. Delete is visually destructive and requires
  confirmation. Failed mutations retain the product/form and allow retry.
- Mode selection uses two explicit, mutually exclusive cards. Standard mode
  invokes the existing controller/repository path. Kit mode checks inventory,
  offers Add Product for an empty kit, and never silently falls back.
- Kit recommendation and preview states distinguish inventory loading,
  offline/load failure, session expiry, generation progress, stale inventory,
  retryable AI failure, prior valid result, and non-retryable failure. Loading
  can be cancelled back to mode selection.
- Kit results identify the mode and list only owned product snapshots with
  category, optional name, swatch/color, finish, placement, technique,
  intensity, and Foundation metadata where relevant.

### Database schema and RLS

The completed feature uses four additive owned tables:

| Table | Purpose | Ownership |
| --- | --- | --- |
| `makeup_kit_products` | Active private inventory | `user_id = auth.uid()` |
| `kit_makeup_recommendations` | Validated structured kit plans and immutable product snapshots | `user_id = auth.uid()` |
| `kit_generated_images` | Kit-mode preview metadata and private storage path | `user_id = auth.uid()` |
| `kit_saved_looks` | Save/favorite linkage for kit previews | `user_id = auth.uid()` |

Migrations, in order:

1. `20260813000100_makeup_kit_products.sql`
2. `20260813000200_kit_makeup_recommendations.sql`
3. `20260813000300_kit_generated_images.sql`
4. `20260814000100_kit_saved_looks.sql`
5. `20260814000200_makeup_kit_hardening.sql`

Every table has RLS enabled; anonymous table privileges are revoked; and
authenticated select/insert/update/delete policies use `auth.uid()` ownership
checks as applicable. Composite owner foreign keys preserve same-owner links.
The hardening migration makes the category/finish matrix a database invariant
in addition to the UI/domain validation. Client repositories also reject a
row whose `user_id` differs from the current authenticated user as defense in
depth, but client checks never replace RLS.

### Isolated AI contract

Kit recommendations use the dedicated authenticated operation
`generate-kit-makeup-recommendation` and prompt version
`kit_makeup_recommendation_v2`. The server flow is:

```text
verify JWT -> Supabase auth.getUser -> validate analysis ownership/style
-> load the caller's current kit under RLS -> structured Gemini request
-> strict parse -> validate selected ID/owner/category/color/finish
-> re-read inventory to detect mutation/deletion -> persist snapshot -> respond
```

Incomplete kits are valid. Structured category statuses distinguish selected,
unavailable, and not-required categories. Empty inventory is an intentional
non-retryable validation result. A malformed response, fabricated ID, foreign
product, unsupported category, stored-attribute substitution, duplicate ID,
or product changed during the request is rejected and never persisted as
owned inventory.

Kit previews use the separate authenticated operation
`generate-kit-makeup-preview` and prompt version `kit_makeup_preview_v1`.
The function loads the persisted validated plan, revalidates every selected
product against current ownership and attributes, loads the owner-scoped
original selfie, and asks the image model to apply only the normalized plan.
It preserves the original object and writes a unique kit-generated object and
record. Kit generation does not call or modify the standard preview endpoint.

Gemini credentials are read only in Edge Functions. Flutter contains no
Gemini secret or direct Gemini endpoint. Logs contain operation metadata, not
JWTs, signed URLs, image bytes, or raw private inventory payloads.

### Saved Looks, History, and product snapshots

Kit saved/history rows remain separate from standard saved/history records and
are composed in the UI without altering the existing record contracts. Each
kit recommendation persists an immutable product snapshot. Reopened results
therefore remain understandable if an active product is renamed, recolored,
changed, or deleted later. Current inventory is revalidated only when a new
preview is requested; historical display uses the snapshot truthfully.

Signed URLs are created for private images on demand. History and Saved Looks
are paginated. Signed URL pairs for a loaded page are hydrated concurrently
within a bounded timeout. Deletion follows the existing owner-scoped
`delete-history-item` convention so linked rows and storage objects are cleaned
without allowing a caller to target another account's paths.

### Recovery, concurrency, and state isolation

- Repository and controller operations have bounded timeouts and sanitized
  user messages for offline, Supabase, storage, authentication, quota, Gemini,
  malformed-data, and unknown failures.
- Generation controllers use operation epochs so clear/cancel/account changes
  ignore stale asynchronous completions. Product and library controllers use
  load generations and mutation locks. Duplicate taps do not create duplicate
  client requests.
- Riverpod user-scoped controllers watch the authenticated user ID. Logout or
  account switching rebuilds product, look, saved-status, Saved Looks, and
  History state rather than retaining another account's data.
- A selected product edited or deleted between plan creation and preview is
  reported as `INVENTORY_CHANGED`; it is never substituted silently.

### Deployment requirements

Local source completion is not remote deployment. For a configured Supabase
project, an authorized operator must:

```powershell
supabase db push
supabase functions deploy generate-kit-makeup-recommendation
supabase functions deploy generate-kit-makeup-preview
supabase functions deploy delete-history-item
supabase secrets set GEMINI_API_KEY=<server-only-value>
```

Also verify the project-specific model environment variables and quota
configuration expected by the existing Edge Function conventions. Both kit
functions are explicitly configured with `verify_jwt = true` in
`supabase/config.toml`. Never use `--no-verify-jwt` for these operations.

After deployment, verify migration presence, function versions, authentication,
RLS with two real accounts, private storage access, and one controlled live kit
recommendation/preview. Automated ordinary tests intentionally mock AI and do
not spend Gemini quota.

### Maintenance checklist

When adding a category or finish, update all of the following together:

1. Dart enums and `MakeupKitFinishCatalog`.
2. Curated visual shades and display labels/icons.
3. Product validator and DTO tests.
4. PostgreSQL category/finish constraints in a new additive migration.
5. Kit recommendation schemas/types/prompt/validation tests.
6. Kit preview normalization/validation tests if visually relevant.
7. Result snapshot rendering and E2E inventory coverage.

Never edit an already-applied migration. Never repurpose a standard
recommendation prompt or endpoint. Prompt changes require a new kit prompt
version and tests that retain strict supplied-ID rules.

### Regression protection and validation

`test/e2e/makeup_kit_journey_test.dart` connects authentication, inventory
CRUD, scan, analysis, style, typed mode selection, owned-product plan, preview,
save, Saved Looks, History, snapshot survival, and reopen through real
controllers with repository-boundary fakes. Empty and one-product kits are
covered without paid AI calls.

`test/e2e/scan_journey_test.dart` remains the protected standard regression:
selfie -> analysis -> style -> Makeup Recommendation -> standard preview ->
result/save -> history restoration. Backend tests separately cover partial
kits, multiple products in one category, malformed model output, fabricated
and foreign IDs, attribute substitution, deleted/modified products, storage
ownership, and standard prompt validation.

Before merging future maintenance work, run:

```powershell
dart format .
flutter analyze
flutter test
npx deno test <all relevant *_test.ts files>
npx deno check supabase/functions/generate-kit-makeup-recommendation/index.ts
npx deno check supabase/functions/generate-kit-makeup-preview/index.ts
flutter build apk --debug --dart-define-from-file=config/development.json
```

### Known limitations

- Camera-based physical product/shade recognition and barcode/catalog import
  are not part of the completed feature.
- Incomplete kits never mix in standard-mode or unregistered products. A
  hybrid purchase suggestion mode would require a separate product decision.
- Identity preservation and exact cosmetic rendering are model goals, not an
  absolute pixel-level guarantee.
- Separate devices can begin concurrent paid generation before database
  uniqueness/ownership checks resolve the race; the losing request cannot
  persist conflicting ownership, but upstream AI work may already have begun.
- Remote migrations/functions, live RLS, real Gemini output, and device UX are
  environment/deployment concerns and must not be claimed from local tests.
- Guest inventory belongs to the anonymous Supabase account and may be lost
  after sign-out, app-data clearing, or anonymous-account lifecycle cleanup.

## Final feature status

My Makeup Kit is complete in local source through MK-14: private inventory,
multi-product categories, visual shades, typed finishes, Foundation metadata,
CRUD, incomplete-kit support, explicit mode selection, isolated owned-only AI,
anti-hallucination validation, identity-conscious kit preview, Saved Looks,
History, recovery, security hardening, performance safeguards, and connected
regression coverage are implemented. Remote deployment and physical-device
acceptance remain explicit operational steps, not implied by source completion.
