-- CCP — Custom Color Palette: the frozen palette and its recommendation.
--
-- One row is one logical palette: `id` is the palette_id. The palette and its
-- plan live together because they are 1:1, and variations reuse both.
-- `recommendation_json` holds no color or finish, so the snapshot is the only
-- place palette truth exists.
--
-- Standard and My Makeup Kit tables are untouched. A new table is required
-- because Standard History loads every `recommendations` row for an analysis,
-- and kit previews re-verify against live owned products. CCP rows in either
-- would be misread as that mode.
--
-- Clients can read their own rows and nothing else. Writes come only from the
-- server, and rows cannot be updated by anyone, so a plan cannot be forged and a
-- frozen palette cannot be edited.
--
-- The remote default ACL grants anon, authenticated and service_role full rights
-- on new tables and EXECUTE on new functions, while the local stack grants
-- service_role nothing. Every privilege below is therefore explicit.
--
-- Preview tables, usage and Tutorial changes are separate migrations.

-- ---------------------------------------------------------------------------
-- 1. Palette validity
-- ---------------------------------------------------------------------------
-- Mirrors `_shared/custom_palette_contract.ts`. A row can never be repaired once
-- written, so the database refuses an invalid one too, whatever the caller.
create or replace function public.custom_palette_snapshot_is_valid(
  p_snapshot jsonb
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_entry jsonb;
  v_category text;
  v_base text;
  v_finishes text[];
  v_seen text[] := '{}';
  v_label text;
begin
  if jsonb_typeof(p_snapshot) <> 'array' then
    return false;
  end if;
  if jsonb_array_length(p_snapshot) not between 1 and 4 then
    return false;
  end if;

  for v_entry in select value from jsonb_array_elements(p_snapshot) loop
    if jsonb_typeof(v_entry) <> 'object' then
      return false;
    end if;
    -- Exactly the contract's fields: no adjustment metadata, no free text.
    if (select array_agg(key order by key) from jsonb_object_keys(v_entry) as key)
      <> array[
        'adjusted_color_value',
        'base_color_value',
        'category_code',
        'color_label',
        'finish_code'
      ]
    then
      return false;
    end if;

    v_category := v_entry->>'category_code';
    if v_category = any(v_seen) then
      return false;
    end if;
    v_seen := v_seen || v_category;

    v_finishes := case v_category
      when 'blush' then array['matte', 'satin', 'shimmer']
      when 'eyeshadow' then
        array['matte', 'satin', 'shimmer', 'metallic', 'glitter']
      when 'eyeliner' then array['matte', 'satin', 'glossy']
      when 'lipstick' then array['matte', 'satin', 'cream', 'glossy']
    end;
    if v_finishes is null then
      return false;
    end if;
    if not (coalesce(v_entry->>'finish_code', '') = any(v_finishes)) then
      return false;
    end if;

    if coalesce(v_entry->>'adjusted_color_value', '') !~ '^#[0-9A-F]{6}$' then
      return false;
    end if;

    v_base := v_entry->>'base_color_value';
    v_label := case v_base
      when '#1B1B1B' then 'Black'
      when '#3A3A3C' then 'Charcoal'
      when '#5C3A21' then 'Brown'
      when '#9C8574' then 'Taupe'
      when '#D9A58B' then 'Nude'
      when '#F5F2EC' then 'White'
      when '#F2A07B' then 'Peach'
      when '#E8636B' then 'Coral'
      when '#E8711A' then 'Orange'
      when '#C8102E' then 'Red'
      when '#7A2E4A' then 'Berry'
      when '#E75480' then 'Pink'
      when '#C97B84' then 'Rose'
      when '#B5179E' then 'Magenta'
      when '#6B4358' then 'Plum'
      when '#6A2FB5' then 'Violet'
      when '#1F2F6B' then 'Navy'
      when '#1F6FD6' then 'Blue'
      when '#0F8B8D' then 'Teal'
      when '#2E7D4F' then 'Green'
      when '#6E7355' then 'Olive'
      when '#C9A227' then 'Gold'
      when '#8A5A34' then 'Bronze'
      when '#B8BCC2' then 'Silver'
    end;
    if v_label is null or v_entry->>'color_label' is distinct from v_label then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

revoke all on function public.custom_palette_snapshot_is_valid(jsonb)
  from public, anon, authenticated;
-- A CHECK constraint runs with the inserting role's privileges.
grant execute on function public.custom_palette_snapshot_is_valid(jsonb)
  to service_role;

-- ---------------------------------------------------------------------------
-- 2. The frozen palette and its plan
-- ---------------------------------------------------------------------------
create table public.custom_palette_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  makeup_style text not null,
  -- The client's idempotency key: a replay returns the row, never a second one.
  palette_request_id uuid not null,
  palette_version text not null,
  palette_snapshot_json jsonb not null,
  palette_digest text not null,
  -- Set when this palette was edited from an earlier look on the same analysis.
  derived_from_palette_id uuid,
  recommendation_json jsonb not null,
  model_name text not null,
  prompt_version text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint custom_palette_recommendations_owner_identity
    unique (id, user_id),
  constraint custom_palette_recommendations_analysis_owner_identity
    unique (id, analysis_id, user_id),
  constraint custom_palette_recommendations_request_unique
    unique (user_id, palette_request_id),
  constraint custom_palette_recommendations_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  -- Same analysis and owner only. Deleting the analysis removes the whole
  -- family in one statement, so NO ACTION holds at the end of that statement.
  constraint custom_palette_recommendations_derived_fk
    foreign key (derived_from_palette_id, analysis_id, user_id)
    references public.custom_palette_recommendations(id, analysis_id, user_id),
  constraint custom_palette_recommendations_style_not_blank
    check (char_length(btrim(makeup_style)) > 0),
  constraint custom_palette_recommendations_version_valid
    check (palette_version = 'custom_color_palette_contract_v1'),
  constraint custom_palette_recommendations_snapshot_valid
    check (public.custom_palette_snapshot_is_valid(palette_snapshot_json)),
  constraint custom_palette_recommendations_digest_valid
    check (palette_digest ~ '^[0-9a-f]{64}$'),
  constraint custom_palette_recommendations_plan_is_object
    check (jsonb_typeof(recommendation_json) = 'object'),
  constraint custom_palette_recommendations_model_not_blank
    check (char_length(btrim(model_name)) > 0),
  constraint custom_palette_recommendations_prompt_not_blank
    check (char_length(btrim(prompt_version)) > 0)
);

create index custom_palette_recommendations_user_created_idx
  on public.custom_palette_recommendations (user_id, created_at desc);
create index custom_palette_recommendations_analysis_idx
  on public.custom_palette_recommendations (analysis_id);

-- ---------------------------------------------------------------------------
-- 3. Immutability
-- ---------------------------------------------------------------------------
-- Defence in depth behind the absent UPDATE grant. DELETE is left alone: a
-- trigger there would also fire on the analysis and account-deletion cascades.
create or replace function public.reject_custom_palette_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'custom palette records are immutable';
end;
$$;

revoke all on function public.reject_custom_palette_update()
  from public, anon, authenticated, service_role;

create trigger custom_palette_recommendations_immutable
before update on public.custom_palette_recommendations
for each row execute function public.reject_custom_palette_update();

-- ---------------------------------------------------------------------------
-- 4. Row level security and privileges
-- ---------------------------------------------------------------------------
alter table public.custom_palette_recommendations enable row level security;

revoke all on table public.custom_palette_recommendations
  from public, anon, authenticated, service_role;
grant select on table public.custom_palette_recommendations to authenticated;
grant select, insert on table public.custom_palette_recommendations
  to service_role;

create policy "custom_palette_recommendations_select_own"
on public.custom_palette_recommendations for select to authenticated
using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 5. Quota vocabulary
-- ---------------------------------------------------------------------------
-- Every existing operation and limit is copied verbatim from 20260830000100.
-- Only the two Custom Color Palette rows are new, at the My Makeup Kit limits.
alter table public.ai_usage_events
  drop constraint if exists ai_usage_events_operation_valid;
alter table public.ai_usage_events
  add constraint ai_usage_events_operation_valid
  check (operation in (
    'face_analysis',
    'makeup_recommendation',
    'kit_makeup_recommendation',
    'custom_palette_recommendation',
    'makeup_preview',
    'kit_makeup_preview',
    'custom_palette_preview',
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
    ('custom_palette_recommendation', 40, 200),
    ('makeup_preview', 30, 120),
    ('kit_makeup_preview', 30, 120),
    ('custom_palette_preview', 30, 120),
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
