-- FaceTune SUB-13: privacy-safe technical telemetry for subscription unit
-- economics. This migration is additive. Nothing here authorizes, reserves,
-- commits, releases, activates, or reconciles an entitlement.
--
-- The table stores only controlled categories, UUID correlations, durations,
-- counts, and provider usage counters. It deliberately has no content, path,
-- URL, prompt, receipt, purchase-token, email, or free-text column.

create table public.ai_operation_metrics (
  id uuid primary key default gen_random_uuid(),
  -- Generated inside an Edge Function for one HTTP invocation. If the writer
  -- is ever retried inside that invocation, this key makes the insert safe.
  event_id uuid not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  telemetry_schema_version text not null default 'sub13_v1',

  operation_kind text not null,
  outcome text not null,
  failure_category text,
  source_mode text,

  -- Safe correlations only. The usage operation is the logical delivered
  -- Final Preview unit; provider_attempt_count is the number of billable-call
  -- attempts made while serving this invocation. They are not interchangeable.
  operation_id uuid,
  tutorial_session_id uuid,
  tutorial_step_id uuid,
  canonical_preview_id uuid,

  -- Derived inside the service-role-only writer from authoritative rows. No
  -- caller supplies plan/capability/allowance truth.
  plan_code text,
  capability_family text,
  allowance_unit text,
  usage_status text,

  generation_latency_ms integer,
  persistence_latency_ms integer,
  provider_name text,
  model_name text,
  prompt_version text,
  provider_attempt_count integer not null default 0,
  input_tokens integer,
  output_tokens integer,
  total_tokens integer,
  cached_tokens integer,
  thoughts_tokens integer,
  input_image_tokens integer,
  output_image_tokens integer,
  output_images integer,
  output_image_resolution text,

  -- Purchase vs restore is observable only in the Play client callback. It is
  -- retained as an explicitly client-claimed telemetry label and never used as
  -- provider, entitlement, or lifecycle authority.
  verification_source text,
  verification_source_trust text,

  created_at timestamptz not null default timezone('utc', now()),

  constraint ai_operation_metrics_schema_version_valid
    check (telemetry_schema_version = 'sub13_v1'),
  constraint ai_operation_metrics_operation_kind_valid
    check (
      operation_kind in (
        'final_preview',
        'tutorial_manifest',
        'tutorial_step',
        'purchase_verification'
      )
    ),
  constraint ai_operation_metrics_outcome_valid
    check (outcome in ('succeeded', 'failed', 'denied', 'duplicate')),
  constraint ai_operation_metrics_failure_category_valid
    check (
      failure_category is null
      or failure_category ~ '^[A-Za-z0-9_]{1,64}$'
    ),
  constraint ai_operation_metrics_failure_category_scoped
    check (
      (outcome in ('failed', 'denied') and failure_category is not null)
      or (outcome in ('succeeded', 'duplicate') and failure_category is null)
    ),
  constraint ai_operation_metrics_source_mode_valid
    check (source_mode is null or source_mode in ('standard', 'makeup_kit')),
  constraint ai_operation_metrics_plan_code_valid
    check (
      plan_code is null
      or plan_code in (
        'free',
        'plus',
        'plus_preview',
        'pro',
        'pro_preview',
        'salon_pro',
        'salon_preview',
        'salon_pilot'
      )
    ),
  constraint ai_operation_metrics_capability_valid
    check (
      capability_family is null
      or capability_family in ('tutorial_enabled', 'preview_only')
    ),
  constraint ai_operation_metrics_allowance_unit_valid
    check (
      allowance_unit is null
      or allowance_unit in ('ai_look', 'final_preview_credit')
    ),
  constraint ai_operation_metrics_usage_status_valid
    check (
      usage_status is null
      or usage_status in ('reserved', 'committed', 'released')
    ),
  constraint ai_operation_metrics_provider_valid
    check (provider_name is null or provider_name in ('google_gemini', 'google_play')),
  constraint ai_operation_metrics_model_valid
    check (model_name is null or model_name ~ '^[a-z0-9._-]{1,80}$'),
  constraint ai_operation_metrics_prompt_valid
    check (prompt_version is null or prompt_version ~ '^[a-z0-9._-]{1,80}$'),
  constraint ai_operation_metrics_resolution_valid
    check (
      output_image_resolution is null
      or output_image_resolution in ('0.5K', '1K', '2K', '4K')
    ),
  constraint ai_operation_metrics_verification_source_valid
    check (
      verification_source is null
      or verification_source in ('purchase', 'restore')
    ),
  constraint ai_operation_metrics_verification_source_trust
    check (
      (verification_source is null and verification_source_trust is null)
      or (
        verification_source is not null
        and verification_source_trust = 'client_claimed'
      )
    ),
  constraint ai_operation_metrics_nonnegative_counts
    check (
      provider_attempt_count between 0 and 10
      and (generation_latency_ms is null or generation_latency_ms between 0 and 900000)
      and (persistence_latency_ms is null or persistence_latency_ms between 0 and 900000)
      and (input_tokens is null or input_tokens between 0 and 100000000)
      and (output_tokens is null or output_tokens between 0 and 100000000)
      and (total_tokens is null or total_tokens between 0 and 200000000)
      and (cached_tokens is null or cached_tokens between 0 and 100000000)
      and (thoughts_tokens is null or thoughts_tokens between 0 and 100000000)
      and (input_image_tokens is null or input_image_tokens between 0 and 100000000)
      and (output_image_tokens is null or output_image_tokens between 0 and 100000000)
      and (output_images is null or output_images between 0 and 16)
    ),
  constraint ai_operation_metrics_logical_identity
    check (
      (
        operation_kind = 'final_preview'
        and operation_id is not null
        and tutorial_session_id is null
        and tutorial_step_id is null
      )
      or (
        operation_kind = 'tutorial_manifest'
        and operation_id is null
        and tutorial_step_id is null
        and (tutorial_session_id is not null or canonical_preview_id is not null)
      )
      or (
        operation_kind = 'tutorial_step'
        and operation_id is null
        and tutorial_session_id is not null
        and tutorial_step_id is not null
      )
      or (
        operation_kind = 'purchase_verification'
        and operation_id is null
        and tutorial_session_id is null
        and tutorial_step_id is null
        and canonical_preview_id is null
      )
    ),
  constraint ai_operation_metrics_tutorial_session_owner_fk
    foreign key (tutorial_session_id, user_id)
    references public.tutorial_v4_sessions(id, user_id)
    on delete cascade,
  constraint ai_operation_metrics_tutorial_step_owner_fk
    foreign key (tutorial_step_id, user_id)
    references public.tutorial_v4_steps(id, user_id)
    on delete cascade
);

create index ai_operation_metrics_created_kind_idx
  on public.ai_operation_metrics (created_at desc, operation_kind);
create index ai_operation_metrics_plan_created_idx
  on public.ai_operation_metrics (plan_code, created_at desc)
  where plan_code is not null;
create index ai_operation_metrics_user_created_idx
  on public.ai_operation_metrics (user_id, created_at desc);

-- An HTTP retry receives a new telemetry event id, but it is still the same
-- logical product/technical operation. Only the first successful delivery or
-- generation is countable; later calls may be retained as `duplicate` events
-- without multiplying the delivered-unit numerator.
create unique index ai_operation_metrics_final_preview_success_idx
  on public.ai_operation_metrics (operation_id)
  where operation_kind = 'final_preview'
    and outcome = 'succeeded';
create unique index ai_operation_metrics_manifest_session_success_idx
  on public.ai_operation_metrics (tutorial_session_id)
  where operation_kind = 'tutorial_manifest'
    and outcome = 'succeeded'
    and tutorial_session_id is not null;
create unique index ai_operation_metrics_manifest_preview_success_idx
  on public.ai_operation_metrics (canonical_preview_id, source_mode)
  where operation_kind = 'tutorial_manifest'
    and outcome = 'succeeded'
    and tutorial_session_id is null;
create unique index ai_operation_metrics_step_success_idx
  on public.ai_operation_metrics (tutorial_step_id)
  where operation_kind = 'tutorial_step'
    and outcome = 'succeeded';

alter table public.ai_operation_metrics enable row level security;
revoke all on table public.ai_operation_metrics from public;
revoke all on table public.ai_operation_metrics from anon;
revoke all on table public.ai_operation_metrics from authenticated;
grant select, insert on table public.ai_operation_metrics to service_role;

-- Server-only writer. The Edge Function has already established p_user_id
-- from the caller's verified session. EXECUTE is service_role-only, so a
-- Flutter client cannot submit a different user, plan, token count, or result.
-- Plan/capability fields are then derived again from authoritative database
-- provenance rather than accepted as parameters.
create function public.record_ai_operation_metric(
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
        case when s.source_mode = 'my_makeup_kit' then 'makeup_kit' else s.source_mode end
        into v_standard_preview_id, v_kit_preview_id, v_source_mode
      from public.tutorial_v4_sessions as s
      where s.id = p_tutorial_session_id
        and s.user_id = p_user_id;
    elsif p_canonical_preview_id is not null then
      if v_source_mode = 'standard' then
        v_standard_preview_id := p_canonical_preview_id;
      elsif v_source_mode = 'makeup_kit' then
        v_kit_preview_id := p_canonical_preview_id;
      end if;
    end if;

    select l.plan_code, l.allowance_unit, l.status
      into v_plan_code, v_allowance_unit, v_usage_status
    from public.usage_ledger as l
    where l.user_id = p_user_id
      and (
        (v_standard_preview_id is not null and l.canonical_generated_image_id = v_standard_preview_id)
        or (v_kit_preview_id is not null and l.canonical_kit_generated_image_id = v_kit_preview_id)
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

revoke all on function public.record_ai_operation_metric(
  uuid, uuid, text, text, text, text, uuid, uuid, uuid, uuid,
  integer, integer, text, text, text, integer, integer, integer,
  integer, integer, integer, integer, integer, integer, text, text, text
) from public;
revoke all on function public.record_ai_operation_metric(
  uuid, uuid, text, text, text, text, uuid, uuid, uuid, uuid,
  integer, integer, text, text, text, integer, integer, integer,
  integer, integer, integer, integer, integer, integer, text, text, text
) from anon;
revoke all on function public.record_ai_operation_metric(
  uuid, uuid, text, text, text, text, uuid, uuid, uuid, uuid,
  integer, integer, text, text, text, integer, integer, integer,
  integer, integer, integer, integer, integer, integer, text, text, text
) from authenticated;
grant execute on function public.record_ai_operation_metric(
  uuid, uuid, text, text, text, text, uuid, uuid, uuid, uuid,
  integer, integer, text, text, text, integer, integer, integer,
  integer, integer, integer, integer, integer, integer, text, text, text
) to service_role;
