-- FaceTune My Makeup Kit MK-10: isolated kit-preview persistence.
-- Standard generated_images and generate-makeup-preview remain unchanged.

alter table public.kit_makeup_recommendations
  add constraint kit_recommendations_analysis_owner_identity
  unique (id, analysis_id, user_id);

create table if not exists public.kit_generated_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  kit_recommendation_id uuid not null,
  storage_path text not null unique,
  generation_number integer not null default 1,
  model_name text not null,
  prompt_version text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint kit_generated_images_owner_identity unique (id, user_id),
  constraint kit_generated_images_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint kit_generated_images_recommendation_owner_fk
    foreign key (kit_recommendation_id, analysis_id, user_id)
    references public.kit_makeup_recommendations(id, analysis_id, user_id)
    on delete cascade,
  constraint kit_generated_images_storage_path_not_blank
    check (char_length(btrim(storage_path)) > 0),
  constraint kit_generated_images_generation_positive
    check (generation_number > 0),
  constraint kit_generated_images_model_not_blank
    check (char_length(btrim(model_name)) > 0),
  constraint kit_generated_images_prompt_not_blank
    check (char_length(btrim(prompt_version)) > 0),
  constraint kit_generated_images_recommendation_generation_unique
    unique (kit_recommendation_id, generation_number)
);

create index if not exists kit_generated_images_user_created_idx
  on public.kit_generated_images (user_id, created_at desc);
create index if not exists kit_generated_images_analysis_idx
  on public.kit_generated_images (analysis_id);

alter table public.kit_generated_images enable row level security;
revoke all on table public.kit_generated_images from anon;
grant select, insert, update, delete
  on table public.kit_generated_images to authenticated;

create policy "kit_generated_images_select_own"
on public.kit_generated_images for select to authenticated
using ((select auth.uid()) = user_id);
create policy "kit_generated_images_insert_own"
on public.kit_generated_images for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "kit_generated_images_update_own"
on public.kit_generated_images for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "kit_generated_images_delete_own"
on public.kit_generated_images for delete to authenticated
using ((select auth.uid()) = user_id);

alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_operation_valid;
alter table public.ai_usage_events
  add constraint ai_usage_events_operation_valid
  check (operation in (
    'face_analysis',
    'makeup_recommendation',
    'kit_makeup_recommendation',
    'makeup_preview',
    'kit_makeup_preview'
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
    ('kit_makeup_preview', 30, 120)
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
