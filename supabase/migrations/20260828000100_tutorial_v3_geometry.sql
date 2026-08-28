-- FaceTune Step-by-Step Tutorial V3 — V3-6B: deterministic geometry persistence.
--
-- Architecture change, evidenced by V3-6A.1, V3-6A.2 and V3-6R.
--
-- V3-2 modelled a step's output as a GENERATED GUIDELINE IMAGE stored in the
-- private bucket. Two live gates proved that architecture unusable: the image
-- model repaints the surface it is asked to annotate, transferring makeup
-- between categories and recolouring lips and skin, and no prompt instruction
-- stopped it (V3-6A.2, FAIL).
--
-- V3-6R proved the replacement: the model returns validated NORMALIZED
-- GEOMETRY and Flutter renders the overlay deterministically over the
-- untouched original. No pixels are ever generated, so surface corruption is
-- structurally impossible.
--
-- This migration therefore replaces the image-asset columns with geometry
-- columns. It does NOT repurpose them: `guideline_image_path`,
-- `guideline_status` and `guideline_error` describe an artifact V3 no longer
-- produces, and leaving them beside a real geometry lifecycle would create two
-- competing sources of truth for one step's state.
--
-- Safe to drop: `tutorial_v3_steps` holds 0 rows (verified against the linked
-- project before writing this migration), and no client has shipped against
-- these columns.
--
-- `attempt_count`, `model_name` and `prompt_version` are RETAINED and reused —
-- they are generic per-step generation metadata with no image-specific
-- meaning, so reusing them is not ambiguous.
--
-- Historical applied migrations are untouched; this is a forward migration.

-- ---------------------------------------------------------------------------
-- Remove the superseded image-asset model
-- ---------------------------------------------------------------------------

drop index if exists tutorial_v3_steps_guideline_path_unique;

alter table public.tutorial_v3_steps
  drop constraint if exists tutorial_v3_steps_guideline_status_valid,
  drop constraint if exists tutorial_v3_steps_final_look_needs_no_guideline,
  drop constraint if exists tutorial_v3_steps_guideline_ready_has_path,
  drop constraint if exists tutorial_v3_steps_guideline_unready_has_no_path,
  drop constraint if exists tutorial_v3_steps_guideline_path_owned;

alter table public.tutorial_v3_steps
  drop column if exists guideline_image_path,
  drop column if exists guideline_status,
  drop column if exists guideline_error;

-- ---------------------------------------------------------------------------
-- Geometry
-- ---------------------------------------------------------------------------

alter table public.tutorial_v3_steps
  -- Matches TutorialV3GeometryStatus.code.
  add column if not exists geometry_status text not null default 'pending',
  -- The validated geometry document. Written only after
  -- TutorialV3GeometryValidator (client) / validateGeometry (server) accepts
  -- it, so an invalid document can never reach storage.
  add column if not exists geometry_json jsonb,
  -- The schema the stored document was written against. A row at any other
  -- version is surfaced as incompatible and re-mapped, never reinterpreted.
  add column if not exists geometry_schema_version integer,
  add column if not exists geometry_error text;

alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_geometry_status_valid
    check (
      geometry_status in (
        'not_required',
        'pending',
        'generating',
        'ready',
        'failed'
      )
    );

-- `not_required` belongs to the final look and to nothing else: the final step
-- reuses the canonical preview and maps no geometry, and every other step must.
alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_final_look_needs_no_geometry
    check (
      (category = 'final_look' and geometry_status = 'not_required')
      or (category <> 'final_look' and geometry_status <> 'not_required')
    );

-- A ready step carries a document and its schema version.
alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_geometry_ready_has_payload
    check (
      geometry_status <> 'ready'
      or (geometry_json is not null and geometry_schema_version is not null)
    );

-- An unready step never keeps a stale document: a failed mapping must show as
-- missing rather than silently rendering the previous attempt.
alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_geometry_unready_has_no_payload
    check (
      geometry_status = 'ready'
      or (geometry_json is null and geometry_schema_version is null)
    );

alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_geometry_is_object
    check (geometry_json is null or jsonb_typeof(geometry_json) = 'object');

alter table public.tutorial_v3_steps
  add constraint tutorial_v3_steps_geometry_schema_version_positive
    check (geometry_schema_version is null or geometry_schema_version >= 1);

create index if not exists tutorial_v3_steps_geometry_status_idx
  on public.tutorial_v3_steps (tutorial_v3_session_id, geometry_status);

-- ---------------------------------------------------------------------------
-- Atomic plan write, updated for geometry
-- ---------------------------------------------------------------------------

-- Replaces the V3-2 definition, which inserted `guideline_status`. Same
-- transactional guarantees and the same SECURITY INVOKER posture: the function
-- runs as the caller, so RLS governs every row and `auth.uid()` supplies the
-- owner.
create or replace function public.persist_tutorial_v3_plan(
  p_session_id uuid,
  p_planner_model text,
  p_planner_prompt_version text,
  p_steps jsonb
)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_owner uuid;
  v_total integer;
  v_final_count integer;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if jsonb_typeof(p_steps) <> 'array' then
    raise exception 'steps must be a JSON array' using errcode = '22023';
  end if;

  v_total := jsonb_array_length(p_steps);
  if v_total < 1 then
    raise exception 'a plan needs at least a final look step'
      using errcode = '22023';
  end if;

  select count(*) into v_final_count
  from jsonb_array_elements(p_steps) as step(value)
  where step.value ->> 'category' = 'final_look';
  if v_final_count <> 1 then
    raise exception 'a plan must contain exactly one final look step'
      using errcode = '22023';
  end if;
  if (p_steps -> (v_total - 1) ->> 'category') <> 'final_look' then
    raise exception 'the final look must be the last step'
      using errcode = '22023';
  end if;

  select sessions.user_id into v_owner
  from public.tutorial_v3_sessions as sessions
  where sessions.id = p_session_id;
  if v_owner is null then
    raise exception 'tutorial session not found' using errcode = 'P0002';
  end if;

  delete from public.tutorial_v3_steps
  where tutorial_v3_session_id = p_session_id;

  insert into public.tutorial_v3_steps (
    user_id,
    tutorial_v3_session_id,
    step_index,
    category,
    step_spec_json,
    product_snapshot_json,
    geometry_status
  )
  select
    v_user,
    p_session_id,
    (step.value ->> 'step_index')::integer,
    step.value ->> 'category',
    step.value -> 'step_spec_json',
    nullif(step.value -> 'product_snapshot_json', 'null'::jsonb),
    case
      when step.value ->> 'category' = 'final_look' then 'not_required'
      else 'pending'
    end
  from jsonb_array_elements(p_steps) as step(value);

  update public.tutorial_v3_sessions
  set total_steps = v_total,
      status = 'ready',
      plan_error = null,
      planner_model = p_planner_model,
      planner_prompt_version = p_planner_prompt_version
  where id = p_session_id;

  return v_total;
end;
$$;

revoke all on function public.persist_tutorial_v3_plan(uuid, text, text, jsonb)
  from anon;
grant execute on function public.persist_tutorial_v3_plan(uuid, text, text, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Atomic geometry claim
-- ---------------------------------------------------------------------------

-- Claiming is a read-then-write, which two concurrent callers would both win
-- if done through PostgREST. This does it in one statement: the UPDATE only
-- matches a row still in a claimable state, so exactly one caller can move a
-- step to `generating`.
--
-- SECURITY INVOKER: RLS still hides other users' steps, so a caller can only
-- ever claim a step in their own session.
--
-- `p_schema_version` is the geometry schema the CALLING BUILD can interpret.
-- Passing it in keeps the version contract in one place — the app — instead of
-- freezing it into a migration that would need replacing on every bump.
create or replace function public.claim_tutorial_v3_geometry(
  p_session_id uuid,
  p_step_index integer,
  p_max_attempts integer,
  p_schema_version integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_row public.tutorial_v3_steps%rowtype;
  v_stale boolean := false;
  v_claimable text[];
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into v_row
  from public.tutorial_v3_steps as steps
  where steps.tutorial_v3_session_id = p_session_id
    and steps.step_index = p_step_index;

  if v_row.id is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;
  if v_row.category = 'final_look' then
    return jsonb_build_object('outcome', 'final_look');
  end if;

  if v_row.geometry_status = 'ready' and v_row.geometry_json is not null then
    -- Reuse before claim: a step that already holds geometry THIS BUILD CAN
    -- READ is returned untouched, so revisiting never re-spends quota.
    if v_row.geometry_schema_version is not distinct from p_schema_version then
      return jsonb_build_object(
        'outcome', 'reused',
        'schema_version', v_row.geometry_schema_version
      );
    end if;
    -- Anything else is a document written by a different build. It is
    -- discarded and re-mapped rather than reused or rendered, because a
    -- primitive vocabulary this build cannot interpret would either fail to
    -- draw or, worse, draw something wrong.
    v_stale := true;
  end if;

  if not v_stale and v_row.geometry_status = 'generating' then
    return jsonb_build_object('outcome', 'in_flight');
  end if;
  if v_row.attempt_count >= p_max_attempts then
    return jsonb_build_object(
      'outcome', 'exhausted',
      'attempt_count', v_row.attempt_count
    );
  end if;

  v_claimable := case
    when v_stale then array['pending', 'failed', 'ready']
    else array['pending', 'failed']
  end;

  update public.tutorial_v3_steps
  set geometry_status = 'generating',
      geometry_error = null,
      -- A claim always starts from an empty payload, so a half-written or
      -- stale document can never survive into the next attempt.
      geometry_json = null,
      geometry_schema_version = null
  where id = v_row.id
    and geometry_status = any(v_claimable);

  if not found then
    -- Another caller claimed it between the read and the write.
    return jsonb_build_object('outcome', 'in_flight');
  end if;

  return jsonb_build_object(
    'outcome', 'claimed',
    'replaced_schema_version',
      case when v_stale then v_row.geometry_schema_version end
  );
end;
$$;
revoke all on function public.claim_tutorial_v3_geometry(uuid, integer, integer, integer)
  from anon;
grant execute on function public.claim_tutorial_v3_geometry(uuid, integer, integer, integer)
  to authenticated;

-- ---------------------------------------------------------------------------
-- AI quota — strict superset
-- ---------------------------------------------------------------------------

-- Every operation currently valid is preserved and `tutorial_v3_geometry` is
-- added. Removing any of them would break a deployed Edge Function with
-- `unsupported_operation`; the V1 and V2 operations stay until those versions
-- are explicitly retired.

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
    'tutorial_v3_geometry'
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
    ('tutorial_step', 80, 400),
    ('tutorial_geometry_plan', 20, 100),
    ('tutorial_v2_plan', 30, 150),
    ('tutorial_v3_plan', 30, 150),
    -- One mapping per step, and a tutorial has up to ten of them. The ceiling
    -- allows several complete tutorials plus bounded retries per hour without
    -- letting a stuck client map without limit.
    ('tutorial_v3_geometry', 120, 600)
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
