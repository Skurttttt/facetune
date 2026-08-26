-- FaceTune TF-2: tutorial-only Gemini geometry & placement planning.
--
-- Purely additive. Does not alter analyze-face, standard Makeup
-- Recommendation, the existing final preview, or My Makeup Kit generation.
-- Adds one JSONB snapshot column (plus its version/model echoes) to the
-- already-existing tutorial_sessions table -- a geometry plan is produced
-- once per tutorial session (TF-2's "one planning call per newly created
-- tutorial, persist/reuse the complete plan") and is never regenerated on
-- reopen.
--
-- geometry_plan_json holds the *validated* output of
-- supabase/functions/plan-tutorial-geometry -- real, photo-grounded zones/
-- paths/arrows in normalized 0.0-1.0 coordinates, one entry per canonical
-- step category already present on the session's own tutorial_steps rows.
-- Absence (null) means geometry has not been planned yet; nothing in this
-- migration or the function that writes this column ever fabricates a
-- fallback value for it. Mapping this plan into
-- PersonalizedTutorialStepSpec / placement metadata / the overlay renderer
-- is a later phase's job (TF-3), not this one's.

alter table public.tutorial_sessions
  add column if not exists geometry_plan_json jsonb,
  add column if not exists geometry_plan_version text,
  add column if not exists geometry_model text;

alter table public.tutorial_sessions
  drop constraint if exists tutorial_sessions_geometry_plan_is_object;
alter table public.tutorial_sessions
  add constraint tutorial_sessions_geometry_plan_is_object
  check (
    geometry_plan_json is null
    or jsonb_typeof(geometry_plan_json) = 'object'
  );

alter table public.tutorial_sessions
  drop constraint if exists tutorial_sessions_geometry_plan_version_not_blank;
alter table public.tutorial_sessions
  add constraint tutorial_sessions_geometry_plan_version_not_blank
  check (
    geometry_plan_version is null
    or char_length(btrim(geometry_plan_version)) > 0
  );

alter table public.tutorial_sessions
  drop constraint if exists tutorial_sessions_geometry_model_not_blank;
alter table public.tutorial_sessions
  add constraint tutorial_sessions_geometry_model_not_blank
  check (
    geometry_model is null
    or char_length(btrim(geometry_model)) > 0
  );

comment on column public.tutorial_sessions.geometry_plan_json is
  'TF-2: validated Gemini tutorial-only geometry & placement plan (one per session, persisted once and reused). Per-category zones/paths/arrows in normalized 0.0-1.0 coordinates. Null until planned -- never backfilled with fabricated coordinates. Consumed by a later phase (TF-3), not read for rendering yet.';

comment on column public.tutorial_sessions.geometry_plan_version is
  'Prompt/schema version of plan-tutorial-geometry that produced geometry_plan_json. Null exactly when geometry_plan_json is null.';

comment on column public.tutorial_sessions.geometry_model is
  'Gemini model that actually produced geometry_plan_json, echoed for display/debugging only -- client code must never read this as configuration (see tutorial_model on this same table for the identical existing convention).';

-- Extend the server-controlled quota vocabulary without weakening any
-- existing operation's limits (same additive pattern as
-- 20260814000300_tutorial_sessions_steps.sql adding 'tutorial_step').
-- Limits are deliberately much lower than 'tutorial_step': geometry is
-- planned at most once per tutorial session, not once per step.
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
    'tutorial_geometry_plan'
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
    ('tutorial_geometry_plan', 20, 100)
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
