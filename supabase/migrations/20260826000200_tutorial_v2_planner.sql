-- FaceTune Step-by-Step Tutorial V2 — V2-4: planner quota + atomic plan write.
--
-- V2-2 deliberately left `consume_ai_quota` and `ai_usage_events_operation_valid`
-- alone because the remote copies carried V1's `tutorial_step` and
-- `tutorial_geometry_plan` operations that no local file reproduced. Those
-- three V1 migrations are now adopted locally (V2-3), so this migration can
-- extend both objects as a strict SUPERSET of what is live: every existing
-- operation is preserved and `tutorial_v2_plan` is added.
--
-- Removing an operation here would break a deployed function. The V1
-- operations stay until V1 is explicitly retired.

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
    'tutorial_v2_plan'
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
    -- One plan covers a whole tutorial, so the ceiling is closer to the
    -- recommendation rate than to the per-step image rate.
    ('tutorial_v2_plan', 30, 150)
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

-- ---------------------------------------------------------------------------
-- Atomic plan persistence
-- ---------------------------------------------------------------------------

-- An Edge Function using PostgREST cannot wrap several statements in one
-- transaction, so a planner that inserted steps and then updated the session
-- could leave a session claiming `plan_ready` with a partial step set. This
-- function does the whole write in a single statement batch instead: one
-- transaction, all-or-nothing.
--
-- SECURITY INVOKER on purpose. The function runs as the calling user, so RLS
-- still governs every row it touches and `auth.uid()` supplies the owner —
-- the caller cannot write steps into someone else's tutorial, and cannot
-- claim a different user_id than its own.
create or replace function public.persist_tutorial_v2_plan(
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
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if jsonb_typeof(p_steps) <> 'array' then
    raise exception 'steps must be a JSON array' using errcode = '22023';
  end if;

  v_total := jsonb_array_length(p_steps);
  if v_total < 2 then
    raise exception 'a plan needs at least one makeup step and a final look'
      using errcode = '22023';
  end if;

  -- RLS hides other users' sessions, so a missing row here means either the
  -- session does not exist or it is not the caller's.
  select sessions.user_id into v_owner
  from public.tutorial_v2_sessions as sessions
  where sessions.id = p_session_id;
  if v_owner is null then
    raise exception 'tutorial session not found' using errcode = 'P0002';
  end if;

  -- Replacing rather than appending: a replan must not interleave two
  -- generations of steps under one session.
  delete from public.tutorial_v2_steps
  where tutorial_v2_session_id = p_session_id;

  insert into public.tutorial_v2_steps (
    user_id,
    tutorial_v2_session_id,
    step_index,
    category,
    step_spec_json,
    product_snapshot_json,
    guideline_status,
    result_status
  )
  select
    v_user,
    p_session_id,
    (step.value ->> 'step_index')::integer,
    step.value ->> 'category',
    step.value -> 'step_spec_json',
    nullif(step.value -> 'product_snapshot_json', 'null'::jsonb),
    coalesce(step.value ->> 'guideline_status', 'pending'),
    coalesce(step.value ->> 'result_status', 'pending')
  from jsonb_array_elements(p_steps) as step(value);

  update public.tutorial_v2_sessions
  set total_steps = v_total,
      status = 'plan_ready',
      plan_error = null,
      planner_model = p_planner_model,
      planner_prompt_version = p_planner_prompt_version
  where id = p_session_id;

  return v_total;
end;
$$;

revoke all on function public.persist_tutorial_v2_plan(uuid, text, text, jsonb)
  from anon;
grant execute on function public.persist_tutorial_v2_plan(uuid, text, text, jsonb)
  to authenticated;
