-- FaceTune V4-2: tutorial persistence, normalized look-product snapshots,
-- dynamic manifest state, and guideline steps.
--
-- Purely additive. No existing table, column, constraint, policy, grant, or
-- trigger from a prior migration is altered or dropped, with one deliberate
-- exception: `ai_usage_events_operation_valid` and `public.consume_ai_quota`
-- are extended to cover the two new AI operations, following exactly the
-- pattern established by 20260813000200 and 20260813000300.
--
-- Deliberately NOT created here:
--
--   * A new My Makeup Kit product table. `public.makeup_kit_products`
--     (20260813000100) already stores user-owned products with category-aware
--     optional fields, already permits many products per category (its only
--     unique constraints are `(id)` and `(id, user_id)` — nothing constrains
--     `(user_id, category)`), and already permits an incomplete kit
--     (`product_name`, `color_label`, `foundation_depth`, and
--     `foundation_undertone` are all nullable). Adding a second kit table
--     would duplicate a working concept for no reason.
--
--   * A storage bucket or storage policy. The private `face-images` bucket and
--     its `face_images_select_own` / `_insert_own` / `_delete_own` policies
--     (20260807000200) authorize on `(storage.foldername(name))[1] = auth.uid()`,
--     which already covers every tutorial guideline path below, since all of
--     them begin with the owner's uuid. A new policy would be redundant surface.
--
--   * Any Gemini call, prompt, model selection, or generation logic.

-- ---------------------------------------------------------------------------
-- 1. Immutable normalized look-product snapshot items
-- ---------------------------------------------------------------------------
--
-- `kit_makeup_recommendations.product_snapshot_json` (20260813000200) remains
-- the authoritative immutable record written by
-- generate-kit-makeup-recommendation. This table is a normalized *projection*
-- of that JSONB array, derived from it server-side.
--
-- It exists because a tutorial step must join to the exact snapshot item(s) it
-- presents, and a JSONB array element has no stable row identity to join
-- against. Encoding several product ids into one delimited column instead is
-- explicitly forbidden and would be unqueryable anyway.
--
-- Two properties make these rows historical rather than live data:
--
--   * There is NO foreign key to `makeup_kit_products`. Deleting or editing an
--     inventory product must never rewrite or cascade into a past look. The
--     `product_id` column is provenance only.
--   * There is no UPDATE grant, no UPDATE policy, and a trigger that rejects
--     UPDATE outright. Rows are insert-once.

create table if not exists public.look_product_snapshot_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kit_recommendation_id uuid not null,
  -- Provenance reference to the inventory row this was captured from.
  -- Intentionally NOT a foreign key: the product may later be edited or
  -- deleted, and this snapshot must survive both unchanged.
  product_id uuid not null,
  position integer not null,
  category text not null,
  product_name text,
  color_hex text not null,
  color_label text,
  finish text not null,
  foundation_depth text,
  foundation_undertone text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint look_product_snapshot_items_owner_identity unique (id, user_id),
  constraint look_product_snapshot_items_recommendation_owner_fk
    foreign key (kit_recommendation_id, user_id)
    references public.kit_makeup_recommendations(id, user_id)
    on delete cascade,
  -- One row per product per recommendation, and one row per ordinal position.
  -- Together these make a re-derivation of the same snapshot idempotent.
  constraint look_product_snapshot_items_product_unique
    unique (kit_recommendation_id, product_id),
  constraint look_product_snapshot_items_position_unique
    unique (kit_recommendation_id, position),
  constraint look_product_snapshot_items_position_positive
    check (position > 0),
  -- Mirrors the inventory vocabulary of makeup_kit_products exactly.
  constraint look_product_snapshot_items_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'blush',
        'highlighter',
        'eyeshadow',
        'lipstick',
        'lip_gloss',
        'contour_bronzer',
        'eyebrow',
        'eyeliner'
      )
    ),
  constraint look_product_snapshot_items_finish_valid
    check (
      finish in (
        'matte',
        'natural',
        'dewy',
        'satin',
        'radiant',
        'shimmer',
        'metallic',
        'glitter',
        'cream',
        'glossy'
      )
    ),
  constraint look_product_snapshot_items_color_hex_valid
    check (color_hex ~ '^#[0-9A-F]{6}$'),
  constraint look_product_snapshot_items_product_name_not_blank
    check (product_name is null or char_length(btrim(product_name)) > 0),
  constraint look_product_snapshot_items_color_label_not_blank
    check (color_label is null or char_length(btrim(color_label)) > 0),
  constraint look_product_snapshot_items_foundation_depth_valid
    check (
      foundation_depth is null
      or foundation_depth in ('fair', 'light', 'medium', 'tan', 'deep')
    ),
  constraint look_product_snapshot_items_foundation_undertone_valid
    check (
      foundation_undertone is null
      or foundation_undertone in ('cool', 'neutral', 'warm')
    ),
  constraint look_product_snapshot_items_foundation_fields_scoped
    check (
      category = 'foundation'
      or (foundation_depth is null and foundation_undertone is null)
    )
);

create index if not exists look_product_snapshot_items_recommendation_idx
  on public.look_product_snapshot_items (kit_recommendation_id, position);
create index if not exists look_product_snapshot_items_user_created_idx
  on public.look_product_snapshot_items (user_id, created_at desc);

-- Defense in depth behind the absent UPDATE policy: even a future migration
-- that mistakenly grants UPDATE cannot rewrite history through this table.
-- DELETE is deliberately NOT blocked, because deleting a look must still
-- cascade its snapshot rows away.
create or replace function public.reject_snapshot_item_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception
    'look_product_snapshot_items rows are immutable historical records';
end;
$$;

drop trigger if exists look_product_snapshot_items_immutable
  on public.look_product_snapshot_items;
create trigger look_product_snapshot_items_immutable
before update on public.look_product_snapshot_items
for each row execute function public.reject_snapshot_item_update();

-- ---------------------------------------------------------------------------
-- 2. Tutorial sessions
-- ---------------------------------------------------------------------------
--
-- A session is scoped to one canonical final preview, not to a recommendation.
-- Regenerating a preview produces a new visual target, so it must get its own
-- session rather than silently inheriting a manifest and steps that describe
-- the previous image.
--
-- Source mode is stored explicitly in `source_mode` and is never inferred from
-- which nullable reference happens to be populated. Two reference pairs exist
-- only because Standard Mode and My Makeup Kit Mode persist into separate
-- table families; `tutorial_v4_sessions_source_mode_lineage` forces the populated
-- pair to agree with the declared mode, so the two can never drift apart.

create table if not exists public.tutorial_v4_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  source_mode text not null,
  recommendation_id uuid,
  kit_recommendation_id uuid,
  canonical_generated_image_id uuid,
  canonical_kit_generated_image_id uuid,
  status text not null default 'creating_session',
  manifest_status text not null default 'pending',
  manifest_model text,
  manifest_prompt_version text,
  manifest_schema_version text,
  manifest_created_at timestamptz,
  tutorial_model text,
  tutorial_prompt_version text,
  tutorial_resolution text not null default '1K',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  constraint tutorial_v4_sessions_owner_identity unique (id, user_id),
  constraint tutorial_v4_sessions_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint tutorial_v4_sessions_recommendation_owner_fk
    foreign key (recommendation_id, user_id)
    references public.recommendations(id, user_id)
    on delete cascade,
  constraint tutorial_v4_sessions_kit_recommendation_owner_fk
    foreign key (kit_recommendation_id, user_id)
    references public.kit_makeup_recommendations(id, user_id)
    on delete cascade,
  constraint tutorial_v4_sessions_generated_image_owner_fk
    foreign key (canonical_generated_image_id, user_id)
    references public.generated_images(id, user_id)
    on delete cascade,
  constraint tutorial_v4_sessions_kit_generated_image_owner_fk
    foreign key (canonical_kit_generated_image_id, user_id)
    references public.kit_generated_images(id, user_id)
    on delete cascade,
  constraint tutorial_v4_sessions_source_mode_valid
    check (source_mode in ('standard', 'my_makeup_kit')),
  -- The declared mode and the populated lineage must agree exactly. This is
  -- what makes `source_mode` authoritative rather than decorative.
  constraint tutorial_v4_sessions_source_mode_lineage
    check (
      (
        source_mode = 'standard'
        and recommendation_id is not null
        and canonical_generated_image_id is not null
        and kit_recommendation_id is null
        and canonical_kit_generated_image_id is null
      )
      or (
        source_mode = 'my_makeup_kit'
        and kit_recommendation_id is not null
        and canonical_kit_generated_image_id is not null
        and recommendation_id is null
        and canonical_generated_image_id is null
      )
    ),
  constraint tutorial_v4_sessions_status_valid
    check (
      status in (
        'creating_session',
        'analyzing_manifest',
        'manifest_ready',
        'manifest_failed',
        'ready',
        'generating_step',
        'step_ready',
        'step_failed',
        'kit_preview_mismatch',
        'completed'
      )
    ),
  -- 'kit_preview_mismatch' is deliberately separate from 'failed'. The analysis
  -- succeeded; what failed is the agreement between the canonical preview and
  -- the validated owned-product selection. Keeping it distinct stops it being
  -- retried as a transient error and stops the preview being treated as a valid
  -- canonical My Makeup Kit result.
  constraint tutorial_v4_sessions_manifest_status_valid
    check (
      manifest_status in (
        'pending',
        'analyzing',
        'accepted',
        'failed',
        'kit_preview_mismatch'
      )
    ),
  -- Only My Makeup Kit looks can carry an ownership mismatch; Standard Mode has
  -- no ownership requirement to contradict.
  constraint tutorial_v4_sessions_mismatch_is_kit_only
    check (
      source_mode = 'my_makeup_kit'
      or (
        status <> 'kit_preview_mismatch'
        and manifest_status <> 'kit_preview_mismatch'
      )
    ),
  -- An accepted manifest must carry the provenance needed to decide later
  -- whether it is still valid. Accepting one without it would leave a manifest
  -- that cannot be invalidated when a prompt or schema version changes.
  constraint tutorial_v4_sessions_accepted_manifest_provenance
    check (
      manifest_status <> 'accepted'
      or (
        manifest_model is not null
        and manifest_prompt_version is not null
        and manifest_schema_version is not null
        and manifest_created_at is not null
      )
    ),
  constraint tutorial_v4_sessions_resolution_valid
    check (tutorial_resolution in ('0.5K', '1K', '2K', '4K')),
  constraint tutorial_v4_sessions_completed_has_timestamp
    check (status <> 'completed' or completed_at is not null)
);

-- One session per canonical preview, which is what makes session creation
-- idempotent: a repeated open returns the existing row instead of creating a
-- duplicate. Partial indexes because exactly one of the two is populated.
create unique index if not exists tutorial_v4_sessions_canonical_preview_idx
  on public.tutorial_v4_sessions (canonical_generated_image_id)
  where canonical_generated_image_id is not null;
create unique index if not exists tutorial_v4_sessions_kit_canonical_preview_idx
  on public.tutorial_v4_sessions (canonical_kit_generated_image_id)
  where canonical_kit_generated_image_id is not null;

create index if not exists tutorial_v4_sessions_user_created_idx
  on public.tutorial_v4_sessions (user_id, created_at desc);
create index if not exists tutorial_v4_sessions_analysis_idx
  on public.tutorial_v4_sessions (analysis_id);

drop trigger if exists tutorial_v4_sessions_set_updated_at
  on public.tutorial_v4_sessions;
create trigger tutorial_v4_sessions_set_updated_at
before update on public.tutorial_v4_sessions
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Dynamic manifest items
-- ---------------------------------------------------------------------------
--
-- Normalized rather than a JSON blob, so the presence verdict per category is
-- constrained by the database and joinable by tutorial_v4_steps below.
--
-- `presence` participates in a unique key specifically so a step can foreign-key
-- to it — see the note on tutorial_v4_steps.

create table if not exists public.tutorial_v4_manifest_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tutorial_session_id uuid not null,
  category text not null,
  position integer not null,
  presence text not null,
  -- Optional evidence score. Deliberately unconstrained beyond its range and
  -- never thresholded in SQL: SoT forbids fixing a confidence cutoff before
  -- controlled QA produces evidence for one.
  visual_confidence numeric(4, 3),
  -- Whether this category maps to at least one validated owned-product
  -- snapshot item. Always false in Standard Mode, which has no ownership
  -- requirement.
  product_backed boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  constraint tutorial_v4_manifest_items_owner_identity unique (id, user_id),
  constraint tutorial_v4_manifest_items_session_owner_fk
    foreign key (tutorial_session_id, user_id)
    references public.tutorial_v4_sessions(id, user_id)
    on delete cascade,
  -- Exactly one verdict per category per session.
  constraint tutorial_v4_manifest_items_category_unique
    unique (tutorial_session_id, category),
  constraint tutorial_v4_manifest_items_position_unique
    unique (tutorial_session_id, position),
  -- FK target for tutorial_v4_steps. Not redundant with the constraint above:
  -- this one carries `presence` into the key so a step can only reference a
  -- category the manifest marked present.
  constraint tutorial_v4_manifest_items_presence_identity
    unique (tutorial_session_id, category, presence),
  -- The controlled tutorial vocabulary. Smaller than the inventory vocabulary
  -- because several inventory categories collapse into one step (lipstick and
  -- lip_gloss both become 'lips'). A model that invents a category name fails
  -- this check rather than creating a step.
  constraint tutorial_v4_manifest_items_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrows',
        'eyeshadow',
        'eyeliner',
        'lips'
      )
    ),
  -- The deterministic logical order of the vocabulary, and its binding to the
  -- category. Order is application-owned, never chosen by the model.
  constraint tutorial_v4_manifest_items_position_matches_category
    check (
      (category = 'foundation' and position = 1)
      or (category = 'concealer' and position = 2)
      or (category = 'contour_bronzer' and position = 3)
      or (category = 'blush' and position = 4)
      or (category = 'highlighter' and position = 5)
      or (category = 'eyebrows' and position = 6)
      or (category = 'eyeshadow' and position = 7)
      or (category = 'eyeliner' and position = 8)
      or (category = 'lips' and position = 9)
    ),
  constraint tutorial_v4_manifest_items_presence_valid
    check (presence in ('present', 'absent', 'uncertain')),
  constraint tutorial_v4_manifest_items_confidence_range
    check (
      visual_confidence is null
      or (visual_confidence >= 0 and visual_confidence <= 1)
    ),
  -- A category with no owned product behind it cannot claim to be
  -- product-backed.
  constraint tutorial_v4_manifest_items_absent_not_backed
    check (presence = 'present' or product_backed = false)
);

create index if not exists tutorial_v4_manifest_items_session_idx
  on public.tutorial_v4_manifest_items (tutorial_session_id, position);

-- ---------------------------------------------------------------------------
-- 4. Tutorial steps
-- ---------------------------------------------------------------------------
--
-- A step may exist ONLY for a category the manifest marked present. That is
-- enforced structurally, not by application discipline: `manifest_presence` is
-- pinned to 'present' by a check, and the composite foreign key resolves
-- against `tutorial_v4_manifest_items (tutorial_session_id, category, presence)`.
-- A step for an absent or uncertain category therefore has no parent row to
-- point at and cannot be inserted at all.

create table if not exists public.tutorial_v4_steps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tutorial_session_id uuid not null,
  category text not null,
  -- Pinned to 'present'. Exists solely to carry the composite foreign key
  -- below; it is not independent state.
  manifest_presence text not null default 'present',
  -- 1-based presentation position among the INCLUDED steps of this tutorial.
  -- Distinct from tutorial_v4_manifest_items.position, which is the absolute rank
  -- within the full nine-category vocabulary. A three-step tutorial numbers its
  -- steps 1,2,3 here while their vocabulary positions stay 1,4,9.
  position integer not null,
  status text not null default 'pending',
  guideline_storage_path text unique,
  model_name text,
  output_resolution text,
  prompt_version text,
  generation_attempt integer not null default 0,
  failure_code text,
  latency_ms integer,
  request_correlation_id uuid,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint tutorial_v4_steps_owner_identity unique (id, user_id),
  constraint tutorial_v4_steps_session_owner_fk
    foreign key (tutorial_session_id, user_id)
    references public.tutorial_v4_sessions(id, user_id)
    on delete cascade,
  constraint tutorial_v4_steps_included_category_fk
    foreign key (tutorial_session_id, category, manifest_presence)
    references public.tutorial_v4_manifest_items
      (tutorial_session_id, category, presence)
    on delete cascade,
  constraint tutorial_v4_steps_manifest_presence_pinned
    check (manifest_presence = 'present'),
  -- Prevents duplicate generation for the same category in one tutorial.
  constraint tutorial_v4_steps_category_unique
    unique (tutorial_session_id, category),
  constraint tutorial_v4_steps_position_unique
    unique (tutorial_session_id, position),
  constraint tutorial_v4_steps_position_positive check (position > 0),
  constraint tutorial_v4_steps_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrows',
        'eyeshadow',
        'eyeliner',
        'lips'
      )
    ),
  constraint tutorial_v4_steps_status_valid
    check (status in ('pending', 'generating', 'ready', 'failed')),
  constraint tutorial_v4_steps_resolution_valid
    check (
      output_resolution is null
      or output_resolution in ('0.5K', '1K', '2K', '4K')
    ),
  constraint tutorial_v4_steps_attempt_not_negative
    check (generation_attempt >= 0),
  constraint tutorial_v4_steps_latency_not_negative
    check (latency_ms is null or latency_ms >= 0),
  -- A ready step must carry its rendered image and full provenance. Without
  -- this, a half-written row could report success with nothing to display.
  constraint tutorial_v4_steps_ready_is_complete
    check (
      status <> 'ready'
      or (
        guideline_storage_path is not null
        and model_name is not null
        and output_resolution is not null
        and prompt_version is not null
      )
    ),
  -- The guideline must live under this user's own folder, inside a `tutorials`
  -- segment. This keeps a step from ever pointing at — and a later overwrite
  -- from ever clobbering — the original selfie (`.../original/...`) or the
  -- canonical preview (`.../generated/...`), and it cannot name another
  -- account's storage at all.
  constraint tutorial_v4_steps_guideline_path_owned
    check (
      guideline_storage_path is null
      or guideline_storage_path like
        (user_id::text || '/analyses/%/tutorials/%')
    ),
  constraint tutorial_v4_steps_failure_code_not_blank
    check (failure_code is null or char_length(btrim(failure_code)) > 0)
);

create index if not exists tutorial_v4_steps_session_idx
  on public.tutorial_v4_steps (tutorial_session_id, position);
create index if not exists tutorial_v4_steps_user_created_idx
  on public.tutorial_v4_steps (user_id, created_at desc);

drop trigger if exists tutorial_v4_steps_set_updated_at on public.tutorial_v4_steps;
create trigger tutorial_v4_steps_set_updated_at
before update on public.tutorial_v4_steps
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 5. Step to snapshot-item linkage
-- ---------------------------------------------------------------------------
--
-- A join table because one step can legitimately present several owned
-- products — a Lipstick and a Lip Gloss both applied in the Lips step. Storing
-- multiple product ids in a delimited column instead is explicitly forbidden.
--
-- Only populated in My Makeup Kit mode; Standard Mode steps have no owned
-- product behind them.

create table if not exists public.tutorial_v4_step_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tutorial_step_id uuid not null,
  look_product_snapshot_item_id uuid not null,
  position integer not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint tutorial_v4_step_products_owner_identity unique (id, user_id),
  constraint tutorial_v4_step_products_step_owner_fk
    foreign key (tutorial_step_id, user_id)
    references public.tutorial_v4_steps(id, user_id)
    on delete cascade,
  constraint tutorial_v4_step_products_snapshot_owner_fk
    foreign key (look_product_snapshot_item_id, user_id)
    references public.look_product_snapshot_items(id, user_id)
    on delete cascade,
  constraint tutorial_v4_step_products_unique
    unique (tutorial_step_id, look_product_snapshot_item_id),
  constraint tutorial_v4_step_products_position_unique
    unique (tutorial_step_id, position),
  constraint tutorial_v4_step_products_position_positive check (position > 0)
);

create index if not exists tutorial_v4_step_products_step_idx
  on public.tutorial_v4_step_products (tutorial_step_id, position);

-- ---------------------------------------------------------------------------
-- 6. Row Level Security
-- ---------------------------------------------------------------------------
--
-- Every new table holds private per-user data. RLS is enabled on all of them,
-- `anon` is revoked entirely, and every policy authorizes on
-- `(select auth.uid()) = user_id` — the same idiom used by every existing
-- FaceTune table. Server-side validation in the Edge Functions remains
-- required regardless; RLS is the backstop, not the only check.

alter table public.look_product_snapshot_items enable row level security;
alter table public.tutorial_v4_sessions enable row level security;
alter table public.tutorial_v4_manifest_items enable row level security;
alter table public.tutorial_v4_steps enable row level security;
alter table public.tutorial_v4_step_products enable row level security;

revoke all on table public.look_product_snapshot_items from anon;
revoke all on table public.tutorial_v4_sessions from anon;
revoke all on table public.tutorial_v4_manifest_items from anon;
revoke all on table public.tutorial_v4_steps from anon;
revoke all on table public.tutorial_v4_step_products from anon;

-- Snapshot items are insert-once: no UPDATE grant is issued, so historical
-- product data cannot be rewritten when the user later edits their kit.
grant select, insert, delete
  on table public.look_product_snapshot_items to authenticated;
grant select, insert, update, delete
  on table public.tutorial_v4_sessions to authenticated;
grant select, insert, update, delete
  on table public.tutorial_v4_manifest_items to authenticated;
grant select, insert, update, delete
  on table public.tutorial_v4_steps to authenticated;
grant select, insert, delete
  on table public.tutorial_v4_step_products to authenticated;

drop policy if exists "look_product_snapshot_items_select_own"
  on public.look_product_snapshot_items;
create policy "look_product_snapshot_items_select_own"
on public.look_product_snapshot_items for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "look_product_snapshot_items_insert_own"
  on public.look_product_snapshot_items;
create policy "look_product_snapshot_items_insert_own"
on public.look_product_snapshot_items for insert
to authenticated
with check ((select auth.uid()) = user_id);

-- No UPDATE policy: these rows are immutable historical records.

drop policy if exists "look_product_snapshot_items_delete_own"
  on public.look_product_snapshot_items;
create policy "look_product_snapshot_items_delete_own"
on public.look_product_snapshot_items for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_sessions_select_own" on public.tutorial_v4_sessions;
create policy "tutorial_v4_sessions_select_own"
on public.tutorial_v4_sessions for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_sessions_insert_own" on public.tutorial_v4_sessions;
create policy "tutorial_v4_sessions_insert_own"
on public.tutorial_v4_sessions for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_sessions_update_own" on public.tutorial_v4_sessions;
create policy "tutorial_v4_sessions_update_own"
on public.tutorial_v4_sessions for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_sessions_delete_own" on public.tutorial_v4_sessions;
create policy "tutorial_v4_sessions_delete_own"
on public.tutorial_v4_sessions for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_manifest_items_select_own"
  on public.tutorial_v4_manifest_items;
create policy "tutorial_v4_manifest_items_select_own"
on public.tutorial_v4_manifest_items for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_manifest_items_insert_own"
  on public.tutorial_v4_manifest_items;
create policy "tutorial_v4_manifest_items_insert_own"
on public.tutorial_v4_manifest_items for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_manifest_items_update_own"
  on public.tutorial_v4_manifest_items;
create policy "tutorial_v4_manifest_items_update_own"
on public.tutorial_v4_manifest_items for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_manifest_items_delete_own"
  on public.tutorial_v4_manifest_items;
create policy "tutorial_v4_manifest_items_delete_own"
on public.tutorial_v4_manifest_items for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_steps_select_own" on public.tutorial_v4_steps;
create policy "tutorial_v4_steps_select_own"
on public.tutorial_v4_steps for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_steps_insert_own" on public.tutorial_v4_steps;
create policy "tutorial_v4_steps_insert_own"
on public.tutorial_v4_steps for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_steps_update_own" on public.tutorial_v4_steps;
create policy "tutorial_v4_steps_update_own"
on public.tutorial_v4_steps for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_steps_delete_own" on public.tutorial_v4_steps;
create policy "tutorial_v4_steps_delete_own"
on public.tutorial_v4_steps for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_step_products_select_own"
  on public.tutorial_v4_step_products;
create policy "tutorial_v4_step_products_select_own"
on public.tutorial_v4_step_products for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v4_step_products_insert_own"
  on public.tutorial_v4_step_products;
create policy "tutorial_v4_step_products_insert_own"
on public.tutorial_v4_step_products for insert
to authenticated
with check ((select auth.uid()) = user_id);

-- No UPDATE policy: a link row is created or removed, never edited.

drop policy if exists "tutorial_v4_step_products_delete_own"
  on public.tutorial_v4_step_products;
create policy "tutorial_v4_step_products_delete_own"
on public.tutorial_v4_step_products for delete
to authenticated
using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 7. AI quota vocabulary
-- ---------------------------------------------------------------------------
--
-- Both the check constraint and the in-function limits table are REPLACED by
-- this section, not appended to. That makes the full list load-bearing: any
-- operation omitted here stops being insertable, and the Edge Function that
-- uses it starts failing as `unsupported_operation`.
--
-- Five of the operations below belong to earlier tutorial generations
-- (20260814000300 through 20260828000100) and are live in production today.
-- Their limits are copied verbatim from 20260828000100 so that adding V4 does
-- not quietly retune or revoke them.

alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_operation_valid;
alter table public.ai_usage_events
  add constraint ai_usage_events_operation_valid
  check (operation in (
    'face_analysis',
    'makeup_recommendation',
    'kit_makeup_recommendation',
    'makeup_preview',
    'kit_makeup_preview',
    'tutorial_step',
    'tutorial_geometry_plan',
    'tutorial_v2_plan',
    'tutorial_v3_plan',
    'tutorial_v3_geometry',
    'tutorial_manifest_analysis',
    'tutorial_step_generation'
  ));

create or replace function public.consume_ai_quota(p_operation text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_hourly_limit integer;
  v_daily_limit integer;
  v_hourly_used integer;
  v_daily_used integer;
begin
  if v_user is null then
    return jsonb_build_object('allowed', false, 'reason', 'authentication_required', 'retryAfterSeconds', 0);
  end if;
  select limits.hourly, limits.daily into v_hourly_limit, v_daily_limit
  from (values
    ('face_analysis', 20, 100),
    ('makeup_recommendation', 40, 200),
    ('kit_makeup_recommendation', 40, 200),
    ('makeup_preview', 30, 120),
    ('kit_makeup_preview', 30, 120),
    -- Earlier tutorial generations, verbatim from 20260828000100.
    ('tutorial_step', 80, 400),
    ('tutorial_geometry_plan', 20, 100),
    ('tutorial_v2_plan', 30, 150),
    ('tutorial_v3_plan', 30, 150),
    ('tutorial_v3_geometry', 120, 600),
    -- V4: one manifest analysis per canonical preview, and one guideline per
    -- included category with bounded retries.
    ('tutorial_manifest_analysis', 20, 80),
    ('tutorial_step_generation', 90, 360)
  ) as limits(operation, hourly, daily)
  where limits.operation = p_operation;

  -- Defence in depth against a future migration this file has not seen: an
  -- operation already recorded in ai_usage_events is treated as legitimate and
  -- given a conservative ceiling rather than being revoked outright. A
  -- genuinely novel string has no history and is still rejected below.
  if v_hourly_limit is null then
    select 20, 80 into v_hourly_limit, v_daily_limit
    where exists (
      select 1 from public.ai_usage_events as known
      where known.operation = p_operation
    );
  end if;

  if v_hourly_limit is null then
    return jsonb_build_object('allowed', false, 'reason', 'unsupported_operation', 'retryAfterSeconds', 0);
  end if;
  select
    count(*) filter (where events.created_at > timezone('utc', now()) - interval '1 hour'),
    count(*)
  into v_hourly_used, v_daily_used
  from public.ai_usage_events as events
  where events.user_id = v_user
    and events.operation = p_operation
    and events.created_at > timezone('utc', now()) - interval '1 day';
  if v_hourly_used >= v_hourly_limit then
    return jsonb_build_object('allowed', false, 'reason', 'hourly_quota_exceeded', 'retryAfterSeconds', 900);
  end if;
  if v_daily_used >= v_daily_limit then
    return jsonb_build_object('allowed', false, 'reason', 'daily_quota_exceeded', 'retryAfterSeconds', 3600);
  end if;
  insert into public.ai_usage_events (user_id, operation) values (v_user, p_operation);
  return jsonb_build_object('allowed', true, 'reason', 'allowed', 'retryAfterSeconds', 0);
end;
$$;
