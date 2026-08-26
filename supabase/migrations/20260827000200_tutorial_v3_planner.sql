-- FaceTune Step-by-Step Tutorial V3 — V3-4: planner quota.
--
-- V3-2 deliberately left `consume_ai_quota` and
-- `ai_usage_events_operation_valid` alone, because V3 had no Edge Function of
-- its own yet and rewriting either object from an older definition would have
-- stripped operations belonging to functions that are still deployed.
--
-- This migration is a strict SUPERSET of what is live. Every operation
-- currently valid is preserved and `tutorial_v3_plan` is added:
--
--   face_analysis, makeup_recommendation, kit_makeup_recommendation,
--   makeup_preview, kit_makeup_preview            -- main
--   tutorial_step, tutorial_geometry_plan         -- V1, functions still ACTIVE
--   tutorial_v2_plan                              -- V2, function still ACTIVE
--   tutorial_v3_plan                              -- added here
--
-- Removing any of them would break a deployed Edge Function with
-- `unsupported_operation`. The V1 and V2 operations stay until those versions
-- are explicitly retired.
--
-- No table, policy or index is touched. `persist_tutorial_v3_plan` was created
-- by V3-2 and is left exactly as it is.

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
    'tutorial_v3_plan'
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
    -- One plan covers a whole tutorial, so the ceiling sits closer to the
    -- recommendation rate than to any per-image rate. A user replanning the
    -- same look repeatedly is the case this bounds.
    ('tutorial_v3_plan', 30, 150)
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
