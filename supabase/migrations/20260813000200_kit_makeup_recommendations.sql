-- FaceTune My Makeup Kit MK-8: isolated kit-aware recommendation persistence.
-- The standard recommendations table and function remain unchanged.

create table if not exists public.kit_makeup_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  makeup_style text not null,
  recommendation_json jsonb not null,
  product_snapshot_json jsonb not null,
  model_name text not null,
  prompt_version text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint kit_recommendations_owner_identity unique (id, user_id),
  constraint kit_recommendations_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint kit_recommendations_style_not_blank
    check (char_length(btrim(makeup_style)) > 0),
  constraint kit_recommendations_payload_is_object
    check (jsonb_typeof(recommendation_json) = 'object'),
  constraint kit_recommendations_snapshot_is_array
    check (jsonb_typeof(product_snapshot_json) = 'array'),
  constraint kit_recommendations_model_not_blank
    check (char_length(btrim(model_name)) > 0),
  constraint kit_recommendations_prompt_not_blank
    check (char_length(btrim(prompt_version)) > 0)
);

create index if not exists kit_recommendations_user_created_idx
  on public.kit_makeup_recommendations (user_id, created_at desc);
create index if not exists kit_recommendations_analysis_idx
  on public.kit_makeup_recommendations (analysis_id);

alter table public.kit_makeup_recommendations enable row level security;
revoke all on table public.kit_makeup_recommendations from anon;
grant select, insert, update, delete
  on table public.kit_makeup_recommendations to authenticated;

create policy "kit_recommendations_select_own"
on public.kit_makeup_recommendations for select to authenticated
using ((select auth.uid()) = user_id);
create policy "kit_recommendations_insert_own"
on public.kit_makeup_recommendations for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "kit_recommendations_update_own"
on public.kit_makeup_recommendations for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "kit_recommendations_delete_own"
on public.kit_makeup_recommendations for delete to authenticated
using ((select auth.uid()) = user_id);

-- Extend the server-controlled quota vocabulary without weakening existing
-- operation limits or allowing clients to choose their own ceilings.
alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_operation_valid;
alter table public.ai_usage_events
  add constraint ai_usage_events_operation_valid
  check (operation in (
    'face_analysis',
    'makeup_recommendation',
    'kit_makeup_recommendation',
    'makeup_preview'
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
    ('makeup_preview', 30, 120)
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
