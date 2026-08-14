-- FaceTune Step-by-Step Tutorial ST-2: persistent tutorial sessions/steps.
--
-- Purely additive. Does not alter any existing table, function, trigger,
-- policy, or grant except the ai_usage_events quota vocabulary (extended,
-- not narrowed) at the bottom of this file. Face Analysis, Makeup
-- Recommendation, the existing final preview, My Makeup Kit, Saved Looks,
-- and History remain untouched.
--
-- HISTORICAL SNAPSHOT SEMANTICS (guide §11, roadmap ST-2 task 7)
-- tutorial_steps.instruction_json is a point-in-time JSONB snapshot, not a
-- live foreign key into makeup_kit_products or makeup_kit_products-derived
-- data. This mirrors kit_makeup_recommendations.product_snapshot_json
-- (20260813000200_kit_makeup_recommendations.sql). Editing or deleting a
-- My Makeup Kit product after a tutorial has been generated therefore
-- cannot silently rewrite that tutorial's already-generated instructions.
--
-- STORAGE PATH CONVENTION (guide §13, roadmap ST-2 task 6)
-- Tutorial result images are expected to live under the same private
-- face-images bucket, nested inside the existing per-analysis prefix:
--   {userId}/analyses/{analysisId}/tutorials/{tutorialSessionId}/step_{NNNN}_result.{ext}
-- Nesting under the existing `{userId}/analyses/{analysisId}` prefix is
-- deliberate: the storage.objects RLS policies added in
-- 20260807000200_private_face_images.sql only check the first path
-- segment (the user id), so they already cover this new path shape with no
-- policy changes required. It also means delete-history-item's recursive
-- `listFilesRecursively(client, historyPrefix(userId, analysisId))` sweep
-- (supabase/functions/delete-history-item/index.ts) already deletes
-- tutorial result images when a user deletes that analysis from History,
-- with no changes to that function needed either.
--
-- A step's *placement* image is never a new upload: per guide §4.1 it is
-- the previous step's already-stored result image (or, for step 1, the
-- existing analysis original), reused by reference. See
-- placement_image_path below — unlike result_image_path it is not unique,
-- because it is expected to duplicate a path already owned by another row.

create table if not exists public.tutorial_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_mode text not null,
  analysis_id uuid not null,
  recommendation_id uuid,
  kit_recommendation_id uuid,
  makeup_style text not null,
  generation_number integer not null,
  total_steps integer not null,
  generation_status text not null default 'not_started',
  tutorial_model text,
  tutorial_image_size integer,
  prompt_version text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint tutorial_sessions_owner_identity unique (id, user_id),

  constraint tutorial_sessions_source_mode_valid
    check (source_mode in ('standard_recommendation', 'makeup_kit')),

  -- Exactly one source reference must be set, matching source_mode. There
  -- is no single "kit result" row in the schema (KitLookResult is an
  -- application-level composite of a kit recommendation + kit generated
  -- image), so kit_recommendation_id is the durable anchor for the
  -- makeup_kit source, the same way recommendation_id anchors the
  -- standard source.
  constraint tutorial_sessions_source_reference_matches_mode
    check (
      (
        source_mode = 'standard_recommendation'
        and recommendation_id is not null
        and kit_recommendation_id is null
      )
      or
      (
        source_mode = 'makeup_kit'
        and kit_recommendation_id is not null
        and recommendation_id is null
      )
    ),

  constraint tutorial_sessions_makeup_style_not_blank
    check (char_length(btrim(makeup_style)) > 0),

  constraint tutorial_sessions_generation_number_positive
    check (generation_number > 0),

  constraint tutorial_sessions_total_steps_positive
    check (total_steps > 0),

  constraint tutorial_sessions_generation_status_valid
    check (
      generation_status in (
        'not_started',
        'planning',
        'queued',
        'generating',
        'partially_complete',
        'completed',
        'failed'
      )
    ),

  constraint tutorial_sessions_tutorial_model_not_blank
    check (tutorial_model is null or char_length(btrim(tutorial_model)) > 0),

  constraint tutorial_sessions_tutorial_image_size_positive
    check (tutorial_image_size is null or tutorial_image_size > 0),

  constraint tutorial_sessions_prompt_version_not_blank
    check (prompt_version is null or char_length(btrim(prompt_version)) > 0),

  constraint tutorial_sessions_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,

  -- A multi-column foreign key is not enforced when any referencing column
  -- is null (Postgres MATCH SIMPLE, the default), so these two FKs are
  -- inert whenever the corresponding source is not the active mode.
  constraint tutorial_sessions_recommendation_owner_fk
    foreign key (recommendation_id, analysis_id, user_id)
    references public.recommendations(id, analysis_id, user_id)
    on delete cascade,

  constraint tutorial_sessions_kit_recommendation_owner_fk
    foreign key (kit_recommendation_id, analysis_id, user_id)
    references public.kit_makeup_recommendations(id, analysis_id, user_id)
    on delete cascade
);

create table if not exists public.tutorial_steps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tutorial_session_id uuid not null,
  step_number integer not null,
  category text not null,
  title text not null,
  instruction_json jsonb not null,
  placement_metadata_json jsonb not null default '[]'::jsonb,
  placement_image_path text,
  result_image_path text,
  model_name text,
  image_size integer,
  prompt_version text,
  generation_status text not null default 'not_started',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint tutorial_steps_owner_identity unique (id, user_id),

  constraint tutorial_steps_session_owner_fk
    foreign key (tutorial_session_id, user_id)
    references public.tutorial_sessions(id, user_id)
    on delete cascade,

  constraint tutorial_steps_step_number_positive
    check (step_number > 0),

  -- Prevents a duplicate/retried planning pass from creating two rows for
  -- the same step of the same session.
  constraint tutorial_steps_session_step_unique
    unique (tutorial_session_id, step_number),

  constraint tutorial_steps_title_not_blank
    check (char_length(btrim(title)) > 0),

  constraint tutorial_steps_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'contour',
        'highlighter',
        'blush',
        'eyeshadow',
        'eyebrow',
        'eyeliner',
        'lipstick',
        'lip_gloss',
        'final_look'
      )
    ),

  constraint tutorial_steps_instruction_is_object
    check (jsonb_typeof(instruction_json) = 'object'),

  constraint tutorial_steps_placement_metadata_is_array
    check (jsonb_typeof(placement_metadata_json) = 'array'),

  constraint tutorial_steps_placement_image_path_not_blank
    check (
      placement_image_path is null
      or char_length(btrim(placement_image_path)) > 0
    ),

  constraint tutorial_steps_result_image_path_not_blank
    check (
      result_image_path is null
      or char_length(btrim(result_image_path)) > 0
    ),

  -- Unlike placement_image_path (expected to duplicate an earlier row's
  -- path), a completed step's result image is always a fresh upload, so
  -- its path must be unique across the table. Nullable + unique is safe:
  -- Postgres treats multiple NULLs (steps not yet generated) as distinct.
  constraint tutorial_steps_result_image_path_unique
    unique (result_image_path),

  constraint tutorial_steps_model_name_not_blank
    check (model_name is null or char_length(btrim(model_name)) > 0),

  constraint tutorial_steps_image_size_positive
    check (image_size is null or image_size > 0),

  constraint tutorial_steps_prompt_version_not_blank
    check (prompt_version is null or char_length(btrim(prompt_version)) > 0),

  constraint tutorial_steps_generation_status_valid
    check (
      generation_status in (
        'not_started',
        'queued',
        'generating',
        'completed',
        'failed'
      )
    )
);

create index if not exists tutorial_sessions_user_created_idx
  on public.tutorial_sessions (user_id, created_at desc);
create index if not exists tutorial_sessions_analysis_idx
  on public.tutorial_sessions (analysis_id);

-- At most one tutorial session per generated look variation, so a caller
-- that finds-or-creates a session (guide §12 — reuse instead of
-- regenerating) is backed by a database guarantee, not just application
-- discipline.
create unique index if not exists tutorial_sessions_recommendation_variation_unique
  on public.tutorial_sessions (recommendation_id, generation_number)
  where recommendation_id is not null;
create unique index if not exists tutorial_sessions_kit_recommendation_variation_unique
  on public.tutorial_sessions (kit_recommendation_id, generation_number)
  where kit_recommendation_id is not null;

create index if not exists tutorial_steps_session_idx
  on public.tutorial_steps (tutorial_session_id, step_number);
create index if not exists tutorial_steps_user_created_idx
  on public.tutorial_steps (user_id, created_at desc);

drop trigger if exists tutorial_sessions_set_updated_at
  on public.tutorial_sessions;
create trigger tutorial_sessions_set_updated_at
before update on public.tutorial_sessions
for each row execute function public.set_updated_at();

drop trigger if exists tutorial_steps_set_updated_at
  on public.tutorial_steps;
create trigger tutorial_steps_set_updated_at
before update on public.tutorial_steps
for each row execute function public.set_updated_at();

alter table public.tutorial_sessions enable row level security;
alter table public.tutorial_steps enable row level security;

revoke all on table public.tutorial_sessions from anon;
revoke all on table public.tutorial_steps from anon;

grant select, insert, update, delete
  on table public.tutorial_sessions to authenticated;
grant select, insert, update, delete
  on table public.tutorial_steps to authenticated;

drop policy if exists "tutorial_sessions_select_own" on public.tutorial_sessions;
create policy "tutorial_sessions_select_own"
on public.tutorial_sessions for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_sessions_insert_own" on public.tutorial_sessions;
create policy "tutorial_sessions_insert_own"
on public.tutorial_sessions for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_sessions_update_own" on public.tutorial_sessions;
create policy "tutorial_sessions_update_own"
on public.tutorial_sessions for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_sessions_delete_own" on public.tutorial_sessions;
create policy "tutorial_sessions_delete_own"
on public.tutorial_sessions for delete to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_steps_select_own" on public.tutorial_steps;
create policy "tutorial_steps_select_own"
on public.tutorial_steps for select to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "tutorial_steps_insert_own" on public.tutorial_steps;
create policy "tutorial_steps_insert_own"
on public.tutorial_steps for insert to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_steps_update_own" on public.tutorial_steps;
create policy "tutorial_steps_update_own"
on public.tutorial_steps for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "tutorial_steps_delete_own" on public.tutorial_steps;
create policy "tutorial_steps_delete_own"
on public.tutorial_steps for delete to authenticated
using ((select auth.uid()) = user_id);

-- Extend the server-controlled quota vocabulary without weakening existing
-- operation limits or allowing clients to choose their own ceilings
-- (same rationale as 20260813000200_kit_makeup_recommendations.sql).
-- Limits are a starting point sized for an 8-step tutorial using the
-- cheaper Gemini 3.1 Flash Image model (guide §5.2); revisit once real
-- generation cost/usage data exists.
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
    'tutorial_step'
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
    ('tutorial_step', 80, 400)
  ) as limits(operation, hourly, daily)
  where limits.operation = p_operation;
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

revoke all on function public.consume_ai_quota(text) from public;
revoke all on function public.consume_ai_quota(text) from anon;
grant execute on function public.consume_ai_quota(text) to authenticated;
