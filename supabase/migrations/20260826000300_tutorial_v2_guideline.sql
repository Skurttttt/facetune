-- FaceTune Step-by-Step Tutorial V2 — V2-5: guideline generation quota.
--
-- Strict SUPERSET of what is live. Every operation already deployed is
-- preserved and `tutorial_v2_guideline` is added. Removing any operation here
-- would break a deployed Edge Function.

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
    'tutorial_v2_guideline'
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
    -- One guideline per step, and a tutorial can run to eleven steps. The
    -- ceiling has to clear a full tutorial plus retries without letting a
    -- stuck client burn image quota indefinitely.
    ('tutorial_v2_guideline', 80, 400)
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
-- Guideline asset claim
-- ---------------------------------------------------------------------------

-- Moves one step's guideline from a non-generating state to 'generating' and
-- reports whether this caller won the claim.
--
-- Two concurrent requests for the same (session, step) would otherwise both
-- call the image model and both write an asset. A conditional UPDATE is
-- atomic, so exactly one caller sees a row returned.
--
-- SECURITY INVOKER: RLS still decides which rows the caller can touch, so a
-- claim can never be taken on another user's step.
create or replace function public.claim_tutorial_v2_guideline(
  p_session_id uuid,
  p_step_index integer
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_claimed uuid;
  v_status text;
  v_path text;
begin
  select steps.guideline_status, steps.guideline_image_path
  into v_status, v_path
  from public.tutorial_v2_steps as steps
  where steps.tutorial_v2_session_id = p_session_id
    and steps.step_index = p_step_index;

  if v_status is null then
    return jsonb_build_object('outcome', 'not_found');
  end if;

  -- Already generated: reuse rather than spend image quota again.
  if v_status = 'ready' and v_path is not null then
    return jsonb_build_object('outcome', 'ready', 'path', v_path);
  end if;

  update public.tutorial_v2_steps as steps
  set guideline_status = 'generating',
      guideline_error = null
  where steps.tutorial_v2_session_id = p_session_id
    and steps.step_index = p_step_index
    and steps.guideline_status <> 'generating'
  returning steps.id into v_claimed;

  if v_claimed is null then
    return jsonb_build_object('outcome', 'in_flight');
  end if;
  return jsonb_build_object('outcome', 'claimed', 'step_id', v_claimed);
end;
$$;

revoke all on function public.claim_tutorial_v2_guideline(uuid, integer) from anon;
grant execute on function public.claim_tutorial_v2_guideline(uuid, integer)
  to authenticated;
