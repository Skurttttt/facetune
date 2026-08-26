-- FaceTune Step-by-Step Tutorial V2 — V2-2: isolated V2 persistence.
--
-- These are NEW tables. The remote database still contains the V1
-- `tutorial_sessions` / `tutorial_steps` tables created by migrations
-- 20260814000300, 20260815000100 and 20260816000100, none of which have a
-- local file on this branch (see docs/tutorial_v2/V2-0_BASELINE_AUDIT.md §4).
-- V2 deliberately does not touch, extend or reuse them: a
-- `create table if not exists tutorial_sessions` here would silently bind V2
-- to V1's schema instead of creating anything.
--
-- This migration also deliberately does NOT redefine `consume_ai_quota` or
-- `ai_usage_events_operation_valid`. The remote copies of both currently
-- include V1's `tutorial_step` and `tutorial_geometry_plan` operations, which
-- no local file on this branch reproduces. Rewriting either from this branch
-- would silently strip them while V1's Edge Functions are still deployed and
-- ACTIVE. V2 quota operations are added in the phase that deploys V2's own
-- Edge Functions, as a superset of whatever is live at that time.
--
-- Storage: V2 assets live under {userId}/analyses/{analysisId}/tutorial-v2/...
-- so the existing `delete-history-item` function, which recursively lists and
-- removes everything under {userId}/analyses/{analysisId} before deleting the
-- analyses row, already cleans them up with no change required.

-- ---------------------------------------------------------------------------
-- Sessions
-- ---------------------------------------------------------------------------

create table if not exists public.tutorial_v2_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,

  source_mode text not null,

  -- Exactly one of these is set, matching source_mode.
  recommendation_id uuid,
  kit_recommendation_id uuid,

  -- The persisted style code (MakeupStyle.code), the same snake_case value
  -- stored in recommendations.makeup_style. Never a parallel style source.
  makeup_style text not null,

  -- The canonical final preview this tutorial converges on. Exactly one is
  -- set, matching source_mode. The tutorial has no target without it, so
  -- both foreign keys cascade.
  canonical_generated_image_id uuid,
  canonical_kit_generated_image_id uuid,
  canonical_image_path text not null,

  -- Equals the canonical persisted step count once the plan exists. 0 while
  -- planning: the count is derived from the selected look and the actual
  -- recommendation, never hardcoded.
  total_steps integer not null default 0,

  plan_version integer not null default 2,
  status text not null default 'pending',

  planner_model text,
  planner_prompt_version text,
  plan_error text,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint tutorial_v2_sessions_owner_identity unique (id, user_id),

  constraint tutorial_v2_sessions_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,

  -- A multi-column foreign key is not enforced when any referencing column
  -- is NULL, so the unused branch in each mode is inert rather than broken.
  constraint tutorial_v2_sessions_recommendation_owner_fk
    foreign key (recommendation_id, analysis_id, user_id)
    references public.recommendations(id, analysis_id, user_id)
    on delete cascade,

  constraint tutorial_v2_sessions_kit_recommendation_owner_fk
    foreign key (kit_recommendation_id, analysis_id, user_id)
    references public.kit_makeup_recommendations(id, analysis_id, user_id)
    on delete cascade,

  constraint tutorial_v2_sessions_canonical_image_owner_fk
    foreign key (canonical_generated_image_id, user_id)
    references public.generated_images(id, user_id)
    on delete cascade,

  constraint tutorial_v2_sessions_canonical_kit_image_owner_fk
    foreign key (canonical_kit_generated_image_id, user_id)
    references public.kit_generated_images(id, user_id)
    on delete cascade,

  constraint tutorial_v2_sessions_source_mode_valid
    check (source_mode in ('standard_recommendation', 'makeup_kit')),

  -- Exactly one recommendation reference, matching source_mode.
  constraint tutorial_v2_sessions_recommendation_matches_mode
    check (
      (
        source_mode = 'standard_recommendation'
        and recommendation_id is not null
        and kit_recommendation_id is null
      )
      or (
        source_mode = 'makeup_kit'
        and kit_recommendation_id is not null
        and recommendation_id is null
      )
    ),

  -- Exactly one canonical final preview reference, matching source_mode.
  constraint tutorial_v2_sessions_canonical_matches_mode
    check (
      (
        source_mode = 'standard_recommendation'
        and canonical_generated_image_id is not null
        and canonical_kit_generated_image_id is null
      )
      or (
        source_mode = 'makeup_kit'
        and canonical_kit_generated_image_id is not null
        and canonical_generated_image_id is null
      )
    ),

  constraint tutorial_v2_sessions_makeup_style_not_blank
    check (char_length(btrim(makeup_style)) > 0),

  -- The canonical preview is an existing premium result. It must live in the
  -- owner's own folder and must never be an original selfie.
  constraint tutorial_v2_sessions_canonical_path_owned
    check (
      canonical_image_path like (user_id::text || '/analyses/%')
      and canonical_image_path not like '%/original/%'
      and canonical_image_path not like '%..%'
    ),

  constraint tutorial_v2_sessions_total_steps_not_negative
    check (total_steps >= 0),

  -- V2 is a clean restart: version 2 is the oldest readable plan. A V1 row
  -- can never be written into this table, and a row from a newer build is
  -- rejected by the client rather than reinterpreted.
  constraint tutorial_v2_sessions_plan_version_supported
    check (plan_version >= 2),

  -- 'incompatible' is deliberately absent: it is derived at read time from
  -- plan_version, never stored.
  constraint tutorial_v2_sessions_status_valid
    check (status in ('pending', 'planning', 'plan_ready', 'plan_failed')),

  -- A ready plan has steps; anything else has not produced them yet.
  constraint tutorial_v2_sessions_ready_has_steps
    check (
      (status = 'plan_ready' and total_steps > 0)
      or (status <> 'plan_ready' and total_steps = 0)
    ),

  constraint tutorial_v2_sessions_planner_model_not_blank
    check (planner_model is null or char_length(btrim(planner_model)) > 0),

  constraint tutorial_v2_sessions_planner_prompt_not_blank
    check (
      planner_prompt_version is null
      or char_length(btrim(planner_prompt_version)) > 0
    )
);

create index if not exists tutorial_v2_sessions_user_created_idx
  on public.tutorial_v2_sessions (user_id, created_at desc);
create index if not exists tutorial_v2_sessions_analysis_idx
  on public.tutorial_v2_sessions (analysis_id);

-- One tutorial per canonical final target per plan version. The canonical
-- preview IS the tutorial's target, so this is the natural key: it makes
-- get-or-create idempotent and race-safe without an advisory lock.
create unique index if not exists tutorial_v2_sessions_canonical_standard_idx
  on public.tutorial_v2_sessions (canonical_generated_image_id, plan_version)
  where canonical_generated_image_id is not null;

create unique index if not exists tutorial_v2_sessions_canonical_kit_idx
  on public.tutorial_v2_sessions (canonical_kit_generated_image_id, plan_version)
  where canonical_kit_generated_image_id is not null;

-- ---------------------------------------------------------------------------
-- Steps
-- ---------------------------------------------------------------------------

-- Guideline and result assets are strongly typed columns rather than a
-- separate table: there are exactly two per step, known statically, and the
-- V2 domain models them as one value object on the step. A third table would
-- add a join and a second ownership surface for no gain. `step_spec_json`
-- holds the single validated step specification that drives the written
-- instruction, the guideline prompt and the result prompt alike.
create table if not exists public.tutorial_v2_steps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tutorial_v2_session_id uuid not null,

  -- Zero-based, matching the V2 domain model.
  step_index integer not null,
  category text not null,

  step_spec_json jsonb not null,
  product_snapshot_json jsonb,

  guideline_status text not null default 'pending',
  result_status text not null default 'pending',
  guideline_image_path text,
  result_image_path text,
  guideline_error text,
  result_error text,
  retry_count integer not null default 0,

  model_name text,
  prompt_version text,

  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint tutorial_v2_steps_owner_identity unique (id, user_id),

  constraint tutorial_v2_steps_session_owner_fk
    foreign key (tutorial_v2_session_id, user_id)
    references public.tutorial_v2_sessions(id, user_id)
    on delete cascade,

  constraint tutorial_v2_steps_session_index_unique
    unique (tutorial_v2_session_id, step_index),

  constraint tutorial_v2_steps_index_not_negative
    check (step_index >= 0),

  constraint tutorial_v2_steps_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'contour_bronzer',
        'blush',
        'highlighter',
        'eyebrow',
        'eyeshadow',
        'eyeliner',
        'lipstick',
        'lip_gloss',
        'final_look'
      )
    ),

  constraint tutorial_v2_steps_spec_is_object
    check (jsonb_typeof(step_spec_json) = 'object'),

  constraint tutorial_v2_steps_product_snapshot_is_object
    check (
      product_snapshot_json is null
      or jsonb_typeof(product_snapshot_json) = 'object'
    ),

  -- The terminal step reuses the canonical final preview and teaches no
  -- product of its own.
  constraint tutorial_v2_steps_final_look_has_no_product
    check (category <> 'final_look' or product_snapshot_json is null),

  constraint tutorial_v2_steps_guideline_status_valid
    check (guideline_status in ('pending', 'generating', 'ready', 'failed')),

  constraint tutorial_v2_steps_result_status_valid
    check (result_status in ('pending', 'generating', 'ready', 'failed')),

  -- A ready asset has a path; a non-ready one does not claim to.
  constraint tutorial_v2_steps_guideline_ready_has_path
    check (guideline_status <> 'ready' or guideline_image_path is not null),

  constraint tutorial_v2_steps_result_ready_has_path
    check (result_status <> 'ready' or result_image_path is not null),

  -- Generated assets must land in the owner's own folder, and must never
  -- point at an original selfie.
  constraint tutorial_v2_steps_guideline_path_owned
    check (
      guideline_image_path is null
      or (
        guideline_image_path like (user_id::text || '/analyses/%')
        and guideline_image_path not like '%/original/%'
        and guideline_image_path not like '%..%'
      )
    ),

  constraint tutorial_v2_steps_result_path_owned
    check (
      result_image_path is null
      or (
        result_image_path like (user_id::text || '/analyses/%')
        and result_image_path not like '%/original/%'
        and result_image_path not like '%..%'
      )
    ),

  constraint tutorial_v2_steps_retry_count_not_negative
    check (retry_count >= 0),

  constraint tutorial_v2_steps_model_not_blank
    check (model_name is null or char_length(btrim(model_name)) > 0),

  constraint tutorial_v2_steps_prompt_not_blank
    check (prompt_version is null or char_length(btrim(prompt_version)) > 0)
);

create index if not exists tutorial_v2_steps_session_index_idx
  on public.tutorial_v2_steps (tutorial_v2_session_id, step_index);
create index if not exists tutorial_v2_steps_user_created_idx
  on public.tutorial_v2_steps (user_id, created_at desc);

-- Nullable + unique is safe in PostgreSQL: NULLs never collide, so unattached
-- assets do not conflict while a stored path can never be claimed twice.
create unique index if not exists tutorial_v2_steps_guideline_path_unique
  on public.tutorial_v2_steps (guideline_image_path)
  where guideline_image_path is not null;

create unique index if not exists tutorial_v2_steps_result_path_unique
  on public.tutorial_v2_steps (result_image_path)
  where result_image_path is not null;

-- ---------------------------------------------------------------------------
-- Triggers
-- ---------------------------------------------------------------------------

drop trigger if exists tutorial_v2_sessions_set_updated_at
  on public.tutorial_v2_sessions;
create trigger tutorial_v2_sessions_set_updated_at
before update on public.tutorial_v2_sessions
for each row execute function public.set_updated_at();

drop trigger if exists tutorial_v2_steps_set_updated_at
  on public.tutorial_v2_steps;
create trigger tutorial_v2_steps_set_updated_at
before update on public.tutorial_v2_steps
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table public.tutorial_v2_sessions enable row level security;
alter table public.tutorial_v2_steps enable row level security;

revoke all on table public.tutorial_v2_sessions from anon;
revoke all on table public.tutorial_v2_steps from anon;

grant select, insert, update, delete
  on table public.tutorial_v2_sessions to authenticated;
grant select, insert, update, delete
  on table public.tutorial_v2_steps to authenticated;

drop policy if exists "tutorial_v2_sessions_select_own"
  on public.tutorial_v2_sessions;
create policy "tutorial_v2_sessions_select_own"
on public.tutorial_v2_sessions for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_sessions_insert_own"
  on public.tutorial_v2_sessions;
create policy "tutorial_v2_sessions_insert_own"
on public.tutorial_v2_sessions for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_sessions_update_own"
  on public.tutorial_v2_sessions;
create policy "tutorial_v2_sessions_update_own"
on public.tutorial_v2_sessions for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_sessions_delete_own"
  on public.tutorial_v2_sessions;
create policy "tutorial_v2_sessions_delete_own"
on public.tutorial_v2_sessions for delete
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_steps_select_own" on public.tutorial_v2_steps;
create policy "tutorial_v2_steps_select_own"
on public.tutorial_v2_steps for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_steps_insert_own" on public.tutorial_v2_steps;
create policy "tutorial_v2_steps_insert_own"
on public.tutorial_v2_steps for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_steps_update_own" on public.tutorial_v2_steps;
create policy "tutorial_v2_steps_update_own"
on public.tutorial_v2_steps for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_v2_steps_delete_own" on public.tutorial_v2_steps;
create policy "tutorial_v2_steps_delete_own"
on public.tutorial_v2_steps for delete
to authenticated
using ((select auth.uid()) = user_id);
