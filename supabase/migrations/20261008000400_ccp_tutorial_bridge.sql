-- CCP — Tutorial V4 bridge and Saved Looks for Custom Color Palette.
--
-- Additive to the Tutorial schema. Standard and My Makeup Kit sessions are
-- unaffected: the new columns are null or false on all their rows, and every
-- existing lineage arm now also requires the new columns to be null.
--
-- Step existence follows the frozen palette. A selected category gets a step
-- whatever the manifest's visual verdict, because in this mode the palette is the
-- authoritative intent. `palette_backed` records that, can only be set on a
-- Custom Color Palette session, and is separate from `product_backed`, which
-- stays My Makeup Kit only. This is a decision for this mode alone: Standard's
-- step rule stays "visually present", and kit's stays "snapshot-backed".
--
-- tutorial_manifest_v4_1 and tutorial_guideline_v4_7 are not touched.

-- ---------------------------------------------------------------------------
-- 1. Sessions
-- ---------------------------------------------------------------------------
alter table public.tutorial_v4_sessions
  add column custom_palette_recommendation_id uuid,
  add column canonical_custom_palette_preview_id uuid,
  add column is_custom_palette boolean
    generated always as (source_mode = 'custom_color_palette') stored;

alter table public.tutorial_v4_sessions
  add constraint tutorial_v4_sessions_custom_palette_recommendation_owner_fk
    foreign key (custom_palette_recommendation_id, user_id)
    references public.custom_palette_recommendations(id, user_id)
    on delete cascade,
  add constraint tutorial_v4_sessions_custom_palette_preview_owner_fk
    foreign key (canonical_custom_palette_preview_id, user_id)
    references public.custom_palette_generated_images(id, user_id)
    on delete cascade,
  add constraint tutorial_v4_sessions_custom_palette_identity
    unique (id, is_custom_palette);

-- Not partial: PostgREST's ON CONFLICT cannot infer a partial index. See
-- 20260831000100.
create unique index tutorial_v4_sessions_custom_palette_preview_idx
  on public.tutorial_v4_sessions (canonical_custom_palette_preview_id);

alter table public.tutorial_v4_sessions
  drop constraint tutorial_v4_sessions_source_mode_valid;
alter table public.tutorial_v4_sessions
  add constraint tutorial_v4_sessions_source_mode_valid
    check (source_mode in ('standard', 'my_makeup_kit', 'custom_color_palette'));

alter table public.tutorial_v4_sessions
  drop constraint tutorial_v4_sessions_source_mode_lineage;
alter table public.tutorial_v4_sessions
  add constraint tutorial_v4_sessions_source_mode_lineage
    check (
      (
        source_mode = 'standard'
        and recommendation_id is not null
        and canonical_generated_image_id is not null
        and kit_recommendation_id is null
        and canonical_kit_generated_image_id is null
        and custom_palette_recommendation_id is null
        and canonical_custom_palette_preview_id is null
      )
      or (
        source_mode = 'my_makeup_kit'
        and kit_recommendation_id is not null
        and canonical_kit_generated_image_id is not null
        and recommendation_id is null
        and canonical_generated_image_id is null
        and custom_palette_recommendation_id is null
        and canonical_custom_palette_preview_id is null
      )
      or (
        source_mode = 'custom_color_palette'
        and custom_palette_recommendation_id is not null
        and canonical_custom_palette_preview_id is not null
        and recommendation_id is null
        and canonical_generated_image_id is null
        and kit_recommendation_id is null
        and canonical_kit_generated_image_id is null
      )
    );

-- ---------------------------------------------------------------------------
-- 2. Manifest items and steps
-- ---------------------------------------------------------------------------
alter table public.tutorial_v4_manifest_items
  add column palette_backed boolean not null default false,
  -- NULL unless backed, so only backed items must belong to a palette session.
  add column palette_backing_guard boolean
    generated always as (case when palette_backed then true end) stored;

alter table public.tutorial_v4_manifest_items
  add constraint tutorial_v4_manifest_items_palette_backing_is_ccp_only
    foreign key (tutorial_session_id, palette_backing_guard)
    references public.tutorial_v4_sessions (id, is_custom_palette)
    on delete cascade;

-- A generated column cannot be altered, so `step_eligible` is rebuilt. Its value
-- is unchanged for every Standard and My Makeup Kit item: `palette_backed` is
-- false on all of them, and the foreign key above keeps it that way.
alter table public.tutorial_v4_steps
  drop constraint tutorial_v4_steps_eligible_category_fk;
alter table public.tutorial_v4_manifest_items
  drop constraint tutorial_v4_manifest_items_step_eligibility_identity;
alter table public.tutorial_v4_manifest_items
  drop column step_eligible;
alter table public.tutorial_v4_manifest_items
  add column step_eligible boolean
    generated always as (
      presence = 'present' or product_backed or palette_backed
    ) stored;
alter table public.tutorial_v4_manifest_items
  add constraint tutorial_v4_manifest_items_step_eligibility_identity
    unique (tutorial_session_id, category, step_eligible);
alter table public.tutorial_v4_steps
  add constraint tutorial_v4_steps_eligible_category_fk
    foreign key (tutorial_session_id, category, manifest_step_eligible)
    references public.tutorial_v4_manifest_items
      (tutorial_session_id, category, step_eligible)
    on delete cascade;

comment on column public.tutorial_v4_manifest_items.palette_backed is
  'The frozen palette selected this category. Custom Color Palette sessions only.';
comment on column public.tutorial_v4_manifest_items.step_eligible is
  'Generated. Visually present, snapshot-backed, or palette-backed; the only items a step may reference.';

-- ---------------------------------------------------------------------------
-- 3. Saved Looks
-- ---------------------------------------------------------------------------
create table public.custom_palette_saved_looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  custom_palette_generated_image_id uuid not null,
  is_favorite boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint custom_palette_saved_looks_preview_unique
    unique (custom_palette_generated_image_id),
  constraint custom_palette_saved_looks_preview_owner_fk
    foreign key (custom_palette_generated_image_id, user_id)
    references public.custom_palette_generated_images(id, user_id)
    on delete cascade
);

create index custom_palette_saved_looks_user_created_idx
  on public.custom_palette_saved_looks (user_id, created_at desc);

create trigger custom_palette_saved_looks_set_updated_at
before update on public.custom_palette_saved_looks
for each row execute function public.set_updated_at();

alter table public.custom_palette_saved_looks enable row level security;

revoke all on table public.custom_palette_saved_looks
  from public, anon, authenticated, service_role;
grant select, insert, update, delete on table public.custom_palette_saved_looks
  to authenticated;

create policy "custom_palette_saved_looks_select_own"
on public.custom_palette_saved_looks for select to authenticated
using ((select auth.uid()) = user_id);
create policy "custom_palette_saved_looks_insert_own"
on public.custom_palette_saved_looks for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "custom_palette_saved_looks_update_own"
on public.custom_palette_saved_looks for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "custom_palette_saved_looks_delete_own"
on public.custom_palette_saved_looks for delete to authenticated
using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 4. Tutorial authorization
-- ---------------------------------------------------------------------------
-- The existing definition with only the Custom Color Palette branch added. The
-- bare "else this must be kit" branch is now explicit, so a third mode can never
-- be judged against the wrong table.
create or replace function public.authorize_tutorial_generation(
  p_source_mode text default null,
  p_canonical_preview_id uuid default null,
  p_tutorial_session_id uuid default null
)
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_state jsonb;
  v_mode text := p_source_mode;
  v_preview uuid := p_canonical_preview_id;
  v_session public.tutorial_v4_sessions%rowtype;
  v_provenance_plan text;
  v_provenance_tutorial boolean;
begin
  if v_user is null then
    return jsonb_build_object(
      'ok', false, 'authorized', false, 'denialReason', 'AUTH_REQUIRED'
    );
  end if;

  -- Question 1: the governing entitlement's capability.
  v_state := public.resolve_subscription_state();

  if (v_state->>'hasEntitlement')::boolean is not true then
    return jsonb_build_object(
      'ok', false,
      'authorized', false,
      'denialReason', 'ENTITLEMENT_NOT_FOUND',
      'planCode', v_state->>'planCode'
    );
  end if;

  if (v_state->>'tutorialEnabled')::boolean is not true then
    return jsonb_build_object(
      'ok', false,
      'authorized', false,
      'denialReason', 'TUTORIAL_NOT_INCLUDED',
      'planCode', v_state->>'planCode',
      'planDisplayName', v_state->>'planDisplayName'
    );
  end if;

  -- Resolve the preview from a session when the caller named one. The
  -- session's own mode vocabulary is the Tutorial's ('my_makeup_kit'); the
  -- ledger's is the usage engine's ('makeup_kit'). Translated here, once.
  if p_tutorial_session_id is not null then
    select * into v_session
    from public.tutorial_v4_sessions as s
    where s.id = p_tutorial_session_id
      and s.user_id = v_user;

    if not found then
      return jsonb_build_object(
        'ok', false,
        'authorized', false,
        'denialReason', 'TUTORIAL_SOURCE_NOT_FOUND'
      );
    end if;

    v_mode := v_session.source_mode;
    v_preview := case
      when v_session.source_mode = 'my_makeup_kit'
        then v_session.canonical_kit_generated_image_id
      when v_session.source_mode = 'custom_color_palette'
        then v_session.canonical_custom_palette_preview_id
      else v_session.canonical_generated_image_id
    end;
  end if;

  if v_mode = 'my_makeup_kit' then
    v_mode := 'makeup_kit';
  end if;

  if v_mode not in ('standard', 'makeup_kit', 'custom_color_palette')
    or v_preview is null
  then
    return jsonb_build_object(
      'ok', false,
      'authorized', false,
      'denialReason', 'TUTORIAL_SOURCE_NOT_FOUND'
    );
  end if;

  -- The preview must be the caller's own. The Edge Functions have already
  -- resolved it through RLS before asking; this repeats the check inside the
  -- authority so the answer cannot be obtained for another account's preview
  -- by calling the RPC directly. Reported as absent, not as foreign.
  if v_mode = 'standard' then
    if not exists (
      select 1 from public.generated_images as g
      where g.id = v_preview and g.user_id = v_user
    ) then
      return jsonb_build_object(
        'ok', false,
        'authorized', false,
        'denialReason', 'TUTORIAL_SOURCE_NOT_FOUND'
      );
    end if;
  elsif v_mode = 'makeup_kit' then
    if not exists (
      select 1 from public.kit_generated_images as k
      where k.id = v_preview and k.user_id = v_user
    ) then
      return jsonb_build_object(
        'ok', false,
        'authorized', false,
        'denialReason', 'TUTORIAL_SOURCE_NOT_FOUND'
      );
    end if;
  elsif not exists (
    select 1 from public.custom_palette_generated_images as c
    where c.id = v_preview and c.user_id = v_user
  ) then
    return jsonb_build_object(
      'ok', false,
      'authorized', false,
      'denialReason', 'TUTORIAL_SOURCE_NOT_FOUND'
    );
  end if;

  -- Question 2: the preview's provenance, from the ledger stamp taken at
  -- reservation (section 5). The unit is the capability class: an AI Look
  -- carries the Tutorial, a Final Preview Credit never does. A committed row
  -- with no stamp cannot exist after the backfill, but if one did it would
  -- read as Tutorial-capable only through its entitlement's current unit —
  -- the pre-SUB-12B meaning of every row.
  select
    coalesce(l.plan_code, e.plan_code),
    coalesce(l.allowance_unit, p.allowance_unit) = 'ai_look'
    into v_provenance_plan, v_provenance_tutorial
  from public.usage_ledger as l
  join public.user_entitlements as e
    on e.id = l.entitlement_id and e.user_id = l.user_id
  join public.subscription_products as p
    on p.plan_code = e.plan_code
  where l.user_id = v_user
    and l.status = 'committed'
    and (
      (v_mode = 'standard' and l.canonical_generated_image_id = v_preview)
      or (v_mode = 'makeup_kit' and l.canonical_kit_generated_image_id = v_preview)
      or (
        v_mode = 'custom_color_palette'
        and l.canonical_custom_palette_preview_id = v_preview
      )
    )
  limit 1;

  if found and v_provenance_tutorial is not true then
    return jsonb_build_object(
      'ok', false,
      'authorized', false,
      'denialReason', 'TUTORIAL_NOT_INCLUDED',
      'planCode', v_state->>'planCode',
      'planDisplayName', v_state->>'planDisplayName',
      'previewPlanCode', v_provenance_plan
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'authorized', true,
    'denialReason', null,
    'planCode', v_state->>'planCode',
    'previewPlanCode', v_provenance_plan
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Telemetry: attribute Tutorial operations to a palette preview's usage
-- ---------------------------------------------------------------------------
create or replace function public.record_ai_operation_metric(
  p_event_id uuid,
  p_user_id uuid,
  p_operation_kind text,
  p_outcome text,
  p_failure_category text default null,
  p_source_mode text default null,
  p_operation_id uuid default null,
  p_tutorial_session_id uuid default null,
  p_tutorial_step_id uuid default null,
  p_canonical_preview_id uuid default null,
  p_generation_latency_ms integer default null,
  p_persistence_latency_ms integer default null,
  p_provider_name text default null,
  p_model_name text default null,
  p_prompt_version text default null,
  p_provider_attempt_count integer default 0,
  p_input_tokens integer default null,
  p_output_tokens integer default null,
  p_total_tokens integer default null,
  p_cached_tokens integer default null,
  p_thoughts_tokens integer default null,
  p_input_image_tokens integer default null,
  p_output_image_tokens integer default null,
  p_output_images integer default null,
  p_output_image_resolution text default null,
  p_verification_source text default null,
  p_purchase_reference text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_plan_code text;
  v_allowance_unit text;
  v_usage_status text;
  v_tutorial_enabled boolean;
  v_outcome text := p_outcome;
  v_purchase_replay boolean := false;
  v_source_mode text := case
    when p_source_mode = 'my_makeup_kit' then 'makeup_kit'
    else p_source_mode
  end;
  v_standard_preview_id uuid;
  v_kit_preview_id uuid;
  v_palette_preview_id uuid;
begin
  if p_event_id is null or p_user_id is null then
    return false;
  end if;

  -- Final Preview provenance is fixed on the usage row at reservation time.
  if p_operation_kind = 'final_preview' and p_operation_id is not null then
    select l.plan_code, l.allowance_unit, l.status
      into v_plan_code, v_allowance_unit, v_usage_status
    from public.usage_ledger as l
    where l.operation_id = p_operation_id
      and l.user_id = p_user_id;

  -- Tutorial provenance resolves through its canonical preview and then the
  -- committed usage row that created that preview.
  elsif p_operation_kind in ('tutorial_manifest', 'tutorial_step') then
    if p_tutorial_session_id is not null then
      select
        case when s.source_mode = 'standard' then s.canonical_generated_image_id end,
        case when s.source_mode = 'my_makeup_kit' then s.canonical_kit_generated_image_id end,
        case when s.source_mode = 'custom_color_palette' then s.canonical_custom_palette_preview_id end,
        case when s.source_mode = 'my_makeup_kit' then 'makeup_kit' else s.source_mode end
        into v_standard_preview_id, v_kit_preview_id, v_palette_preview_id, v_source_mode
      from public.tutorial_v4_sessions as s
      where s.id = p_tutorial_session_id
        and s.user_id = p_user_id;
    elsif p_canonical_preview_id is not null then
      if v_source_mode = 'standard' then
        v_standard_preview_id := p_canonical_preview_id;
      elsif v_source_mode = 'makeup_kit' then
        v_kit_preview_id := p_canonical_preview_id;
      elsif v_source_mode = 'custom_color_palette' then
        v_palette_preview_id := p_canonical_preview_id;
      end if;
    end if;

    select l.plan_code, l.allowance_unit, l.status
      into v_plan_code, v_allowance_unit, v_usage_status
    from public.usage_ledger as l
    where l.user_id = p_user_id
      and (
        (v_standard_preview_id is not null and l.canonical_generated_image_id = v_standard_preview_id)
        or (v_kit_preview_id is not null and l.canonical_kit_generated_image_id = v_kit_preview_id)
        or (v_palette_preview_id is not null and l.canonical_custom_palette_preview_id = v_palette_preview_id)
      )
    limit 1;

  -- A raw purchase token is never accepted. The already-persisted SHA-256
  -- reference is used only for this lookup and is not copied to telemetry.
  elsif p_operation_kind = 'purchase_verification'
    and p_purchase_reference ~ '^[0-9a-f]{64}$'
  then
    select v.plan_code, v.verified_at > v.created_at
      into v_plan_code, v_purchase_replay
    from public.provider_purchase_verifications as v
    where v.purchase_reference = p_purchase_reference
      and v.user_id = p_user_id;

    if p_outcome in ('succeeded', 'duplicate') then
      v_outcome := case
        when v_purchase_replay then 'duplicate'
        else 'succeeded'
      end;
    end if;
  end if;

  if v_plan_code is not null then
    select p.allowance_unit, p.tutorial_enabled
      into v_allowance_unit, v_tutorial_enabled
    from public.subscription_products as p
    where p.plan_code = v_plan_code;
  end if;

  insert into public.ai_operation_metrics (
    event_id,
    user_id,
    operation_kind,
    outcome,
    failure_category,
    source_mode,
    operation_id,
    tutorial_session_id,
    tutorial_step_id,
    canonical_preview_id,
    plan_code,
    capability_family,
    allowance_unit,
    usage_status,
    generation_latency_ms,
    persistence_latency_ms,
    provider_name,
    model_name,
    prompt_version,
    provider_attempt_count,
    input_tokens,
    output_tokens,
    total_tokens,
    cached_tokens,
    thoughts_tokens,
    input_image_tokens,
    output_image_tokens,
    output_images,
    output_image_resolution,
    verification_source,
    verification_source_trust
  ) values (
    p_event_id,
    p_user_id,
    p_operation_kind,
    v_outcome,
    p_failure_category,
    v_source_mode,
    p_operation_id,
    p_tutorial_session_id,
    p_tutorial_step_id,
    p_canonical_preview_id,
    v_plan_code,
    case
      when v_plan_code is null then null
      when v_tutorial_enabled then 'tutorial_enabled'
      else 'preview_only'
    end,
    v_allowance_unit,
    v_usage_status,
    p_generation_latency_ms,
    p_persistence_latency_ms,
    p_provider_name,
    p_model_name,
    p_prompt_version,
    coalesce(p_provider_attempt_count, 0),
    p_input_tokens,
    p_output_tokens,
    p_total_tokens,
    p_cached_tokens,
    p_thoughts_tokens,
    p_input_image_tokens,
    p_output_image_tokens,
    p_output_images,
    p_output_image_resolution,
    p_verification_source,
    case when p_verification_source is null then null else 'client_claimed' end
  )
  -- No conflict target is intentional: event retries and a second `succeeded`
  -- observation for the same logical operation are both safe no-ops.
  on conflict do nothing;

  return true;
exception
  when check_violation or foreign_key_violation or invalid_text_representation then
    -- Telemetry rejects malformed facts without surfacing database detail to
    -- the product operation. The Edge helper also catches transport failures.
    return false;
end;
$$;
