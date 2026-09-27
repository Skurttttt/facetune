-- FaceTune PDMK: canonical makeup plan lineage for new My Makeup Kit looks.
--
-- Purely additive for existing data. No existing row is rewritten, and every
-- existing (v2) kit recommendation and kit preview keeps its current behaviour.
-- Standard Mode tables, the usage ledger, and reserve / commit / release /
-- reconciliation are not touched.
--
--   1. kit_makeup_recommendations gains the frozen canonical plan. Plan-backed
--      rows are written by the server only and are immutable for every role.
--   2. kit_preview_generations: one row per logical preview request, keyed by
--      the AI Look operation id. Also the request's lease.
--   3. kit_preview_attempts: one row per candidate, holding its validation
--      evidence. Candidate bytes are never stored here.
--   4. kit_generated_images gains lineage for accepted plan-backed previews.
--      Only a candidate whose attempt was accepted can become one, so a failed
--      candidate never reaches the table that reconciliation reads.
--   5. Two service-role-only functions that claim an accepted preview's storage
--      slot and finalize it atomically.
--
-- The remote default ACL grants anon / authenticated / service_role full rights
-- on new tables and EXECUTE on new functions, while the local stack grants
-- service_role nothing. Every privilege below is therefore explicit.

-- ---------------------------------------------------------------------------
-- 1. Canonical plan on kit_makeup_recommendations
-- ---------------------------------------------------------------------------
--
-- plan_id, plan_version, plan_json and plan_digest are the canonical plan
-- group: present together or absent together. plan_request_id is the client's
-- durable idempotency key for the request that created the plan. It is not
-- part of the plan, but a plan-backed row must carry one and a legacy row never
-- does.

alter table public.kit_makeup_recommendations
  add column if not exists plan_id uuid,
  add column if not exists plan_version text,
  add column if not exists plan_json jsonb,
  add column if not exists plan_digest text,
  add column if not exists plan_request_id uuid;

alter table public.kit_makeup_recommendations
  add constraint kit_recommendations_plan_group_all_or_none check (
    (plan_id is null and plan_version is null and plan_json is null
      and plan_digest is null)
    or (plan_id is not null and plan_version is not null
      and plan_json is not null and plan_digest is not null)
  ),
  add constraint kit_recommendations_plan_request_iff_plan check (
    (plan_request_id is null) = (plan_id is null)
  ),
  add constraint kit_recommendations_plan_version_valid check (
    plan_version is null or plan_version = 'kit_makeup_plan_v1'
  ),
  add constraint kit_recommendations_plan_json_object check (
    plan_json is null or jsonb_typeof(plan_json) = 'object'
  ),
  add constraint kit_recommendations_plan_digest_format check (
    plan_digest is null or plan_digest ~ '^[0-9a-f]{64}$'
  ),
  add constraint kit_recommendations_plan_identity_matches check (
    plan_id is null or (
      plan_json->>'plan_id' = plan_id::text
      and plan_json->>'plan_version' = plan_version
      and plan_json->>'analysis_id' = analysis_id::text
      and plan_json->>'style_code' = makeup_style
      and plan_json->>'source_mode' = 'my_makeup_kit'
    )
  ),
  add constraint kit_recommendations_plan_unique unique (plan_id),
  add constraint kit_recommendations_plan_owner_identity
    unique (id, plan_id, user_id);

create unique index if not exists kit_recommendations_plan_request_idx
  on public.kit_makeup_recommendations (user_id, plan_request_id)
  where plan_request_id is not null;

-- A plan-backed row is frozen for every role, and no plan may be attached to a
-- legacy row: historical looks are never backfilled.
create or replace function public.reject_kit_recommendation_plan_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.plan_id is not null then
    raise exception 'plan-backed kit recommendations are immutable';
  end if;
  if new.plan_id is not null
    or new.plan_version is not null
    or new.plan_json is not null
    or new.plan_digest is not null
    or new.plan_request_id is not null
  then
    raise exception 'a plan cannot be attached to an existing kit recommendation';
  end if;
  return new;
end;
$$;

drop trigger if exists kit_recommendations_plan_immutable
  on public.kit_makeup_recommendations;
create trigger kit_recommendations_plan_immutable
before update on public.kit_makeup_recommendations
for each row execute function public.reject_kit_recommendation_plan_change();

-- Callers keep their legacy rights on legacy rows only. A plan-backed row can
-- be written by the server alone (service_role bypasses RLS).
drop policy if exists "kit_recommendations_insert_own"
  on public.kit_makeup_recommendations;
create policy "kit_recommendations_insert_own"
on public.kit_makeup_recommendations for insert to authenticated
with check ((select auth.uid()) = user_id and plan_id is null);

drop policy if exists "kit_recommendations_update_own"
  on public.kit_makeup_recommendations;
create policy "kit_recommendations_update_own"
on public.kit_makeup_recommendations for update to authenticated
using ((select auth.uid()) = user_id and plan_id is null)
with check ((select auth.uid()) = user_id and plan_id is null);

grant select, insert on table public.kit_makeup_recommendations
  to service_role;

-- ---------------------------------------------------------------------------
-- 2. kit_preview_generations
-- ---------------------------------------------------------------------------

create table if not exists public.kit_preview_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  kit_recommendation_id uuid not null,
  plan_id uuid not null,
  plan_digest text not null,
  status text not null default 'in_progress',
  terminal_outcome text,
  max_attempts integer not null,
  lease_expires_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  constraint kit_preview_generations_owner_identity unique (id, user_id),
  constraint kit_preview_generations_operation_unique unique (operation_id),
  constraint kit_preview_generations_operation_fk
    foreign key (operation_id)
    references public.usage_ledger(operation_id)
    on delete cascade,
  constraint kit_preview_generations_plan_fk
    foreign key (kit_recommendation_id, plan_id, user_id)
    references public.kit_makeup_recommendations(id, plan_id, user_id)
    on delete cascade,
  constraint kit_preview_generations_status_valid
    check (status in ('in_progress', 'accepted', 'failed')),
  constraint kit_preview_generations_terminal_outcome_valid
    check (
      terminal_outcome is null or terminal_outcome in (
        'accepted',
        'nonretryable_mismatch',
        'retry_exhausted',
        'validator_failure',
        'provider_failure',
        'inventory_changed',
        'reservation_released'
      )
    ),
  constraint kit_preview_generations_terminal_iff
    check ((status = 'in_progress') = (terminal_outcome is null)),
  constraint kit_preview_generations_accepted_iff
    check ((status = 'accepted') = (terminal_outcome is not distinct from 'accepted')),
  constraint kit_preview_generations_completed_iff
    check ((status = 'in_progress') = (completed_at is null)),
  constraint kit_preview_generations_max_attempts_valid
    check (max_attempts between 1 and 3),
  constraint kit_preview_generations_plan_digest_format
    check (plan_digest ~ '^[0-9a-f]{64}$')
);

create index if not exists kit_preview_generations_recommendation_idx
  on public.kit_preview_generations (kit_recommendation_id);

-- ---------------------------------------------------------------------------
-- 3. kit_preview_attempts
-- ---------------------------------------------------------------------------
--
-- status is the in-flight phase and has exactly one terminal value,
-- 'completed'. outcome is the terminal result; 'abandoned' is one of them, so
-- an attempt whose lease expired is completed / abandoned and still counts
-- toward the generation's bound.

create table if not exists public.kit_preview_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  generation_id uuid not null,
  attempt_number integer not null,
  status text not null default 'generating',
  outcome text,
  reason_code text,
  preview_prompt_version text not null,
  model_name text not null,
  validator_version text,
  repair_codes text[] not null default '{}',
  mismatch_categories text[] not null default '{}',
  missing_required_categories text[] not null default '{}',
  evidence_json jsonb,
  candidate_sha256 text,
  preview_generation_number integer,
  preview_storage_path text,
  generation_latency_ms integer,
  validation_latency_ms integer,
  created_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  constraint kit_preview_attempts_owner_identity unique (id, user_id),
  constraint kit_preview_attempts_number_unique
    unique (generation_id, attempt_number),
  constraint kit_preview_attempts_generation_fk
    foreign key (generation_id, user_id)
    references public.kit_preview_generations(id, user_id)
    on delete cascade,
  constraint kit_preview_attempts_number_valid
    check (attempt_number between 1 and 3),
  constraint kit_preview_attempts_status_valid
    check (status in ('generating', 'validating', 'completed')),
  constraint kit_preview_attempts_outcome_valid
    check (
      outcome is null or outcome in (
        'accepted',
        'retryable_mismatch',
        'nonretryable_mismatch',
        'validator_failure',
        'provider_failure',
        'abandoned'
      )
    ),
  constraint kit_preview_attempts_completed_iff_outcome
    check ((status = 'completed') = (outcome is not null)),
  constraint kit_preview_attempts_completed_iff_timestamp
    check ((status = 'completed') = (completed_at is not null)),
  constraint kit_preview_attempts_validating_has_candidate
    check (status <> 'validating' or candidate_sha256 is not null),
  constraint kit_preview_attempts_reason_code_format
    check (reason_code is null or reason_code ~ '^[a-z0-9_]{1,64}$'),
  constraint kit_preview_attempts_failure_needs_reason
    check (
      outcome is null
      or outcome not in ('validator_failure', 'provider_failure', 'abandoned')
      or reason_code is not null
    ),
  constraint kit_preview_attempts_accepted_evidence
    check (
      outcome is distinct from 'accepted' or (
        validator_version is not null
        and candidate_sha256 is not null
        and reason_code is null
        and preview_storage_path is not null
        and mismatch_categories = '{}'
        and missing_required_categories = '{}'
      )
    ),
  constraint kit_preview_attempts_mismatch_evidence
    check (
      outcome is null
      or outcome not in ('retryable_mismatch', 'nonretryable_mismatch')
      or (
        validator_version is not null
        and candidate_sha256 is not null
        and (cardinality(mismatch_categories) > 0
          or cardinality(missing_required_categories) > 0
          -- A changed identity is a mismatch no category names.
          or reason_code is not null)
      )
    ),
  constraint kit_preview_attempts_no_verdict_without_validation
    check (
      outcome is null
      or outcome not in ('provider_failure', 'abandoned')
      or (
        mismatch_categories = '{}'
        and missing_required_categories = '{}'
        and evidence_json is null
      )
    ),
  constraint kit_preview_attempts_mismatch_categories_valid
    check (mismatch_categories <@ array[
      'foundation', 'concealer', 'contour_bronzer', 'blush', 'highlighter',
      'eyebrows', 'eyeshadow', 'eyeliner', 'lips'
    ]::text[]),
  constraint kit_preview_attempts_missing_categories_valid
    check (missing_required_categories <@ array[
      'foundation', 'concealer', 'contour_bronzer', 'blush', 'highlighter',
      'eyebrows', 'eyeshadow', 'eyeliner', 'lips'
    ]::text[]),
  constraint kit_preview_attempts_repair_codes_format
    check (
      cardinality(repair_codes) <= 16
      and array_to_string(repair_codes, ',')
        ~ '^([a-z0-9_]{1,64}(,[a-z0-9_]{1,64})*)?$'
    ),
  constraint kit_preview_attempts_evidence_object
    check (evidence_json is null or jsonb_typeof(evidence_json) = 'object'),
  constraint kit_preview_attempts_sha_format
    check (candidate_sha256 is null or candidate_sha256 ~ '^[0-9a-f]{64}$'),
  constraint kit_preview_attempts_slot_all_or_none
    check ((preview_generation_number is null) = (preview_storage_path is null)),
  constraint kit_preview_attempts_slot_number_valid
    check (
      preview_generation_number is null
      or preview_generation_number between 1 and 9999
    ),
  constraint kit_preview_attempts_latency_valid
    check (
      (generation_latency_ms is null or generation_latency_ms >= 0)
      and (validation_latency_ms is null or validation_latency_ms >= 0)
    )
);

-- At most one attempt in flight per generation, at most one accepted, and a
-- storage slot is never shared.
create unique index if not exists kit_preview_attempts_one_in_flight
  on public.kit_preview_attempts (generation_id)
  where status <> 'completed';
create unique index if not exists kit_preview_attempts_one_accepted
  on public.kit_preview_attempts (generation_id)
  where outcome = 'accepted';
create unique index if not exists kit_preview_attempts_slot_unique
  on public.kit_preview_attempts (preview_storage_path)
  where preview_storage_path is not null;

-- ---------------------------------------------------------------------------
-- Generation and attempt state machines
-- ---------------------------------------------------------------------------

create or replace function public.guard_kit_preview_generation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ledger_user uuid;
  v_plan_digest text;
  v_max_attempt integer;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'in_progress' then
      raise exception 'a kit preview generation starts in progress';
    end if;
    select user_id into v_ledger_user
    from public.usage_ledger where operation_id = new.operation_id;
    if v_ledger_user is distinct from new.user_id then
      raise exception 'the operation belongs to another account';
    end if;
    select plan_digest into v_plan_digest
    from public.kit_makeup_recommendations
    where id = new.kit_recommendation_id;
    if v_plan_digest is distinct from new.plan_digest then
      raise exception 'the generation does not match its plan';
    end if;
    return new;
  end if;

  if old.status <> 'in_progress' then
    raise exception 'a completed kit preview generation is immutable';
  end if;
  if new.user_id <> old.user_id
    or new.operation_id <> old.operation_id
    or new.kit_recommendation_id <> old.kit_recommendation_id
    or new.plan_id <> old.plan_id
    or new.plan_digest <> old.plan_digest
    or new.max_attempts <> old.max_attempts
    or new.created_at <> old.created_at
  then
    raise exception 'kit preview generation identity is immutable';
  end if;
  if new.status <> 'in_progress' then
    if exists (
      select 1 from public.kit_preview_attempts
      where generation_id = old.id and status <> 'completed'
    ) then
      raise exception 'a generation cannot end while an attempt is in flight';
    end if;
    if new.status = 'accepted' and not exists (
      select 1 from public.kit_preview_attempts
      where generation_id = old.id and outcome = 'accepted'
    ) then
      raise exception 'a generation is accepted only through an accepted attempt';
    end if;
    if new.terminal_outcome = 'retry_exhausted' then
      select max(attempt_number) into v_max_attempt
      from public.kit_preview_attempts where generation_id = old.id;
      if v_max_attempt is distinct from old.max_attempts then
        raise exception 'retries are not exhausted';
      end if;
    end if;
  end if;
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists kit_preview_generations_guard
  on public.kit_preview_generations;
create trigger kit_preview_generations_guard
before insert or update on public.kit_preview_generations
for each row execute function public.guard_kit_preview_generation();

create or replace function public.guard_kit_preview_attempt()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_generation public.kit_preview_generations%rowtype;
  v_next integer;
begin
  if tg_op = 'INSERT' then
    select * into v_generation
    from public.kit_preview_generations
    where id = new.generation_id
    for update;
    if not found or v_generation.user_id <> new.user_id then
      raise exception 'the attempt does not belong to this generation';
    end if;
    if v_generation.status <> 'in_progress' then
      raise exception 'a completed generation cannot take another attempt';
    end if;
    if new.status <> 'generating' or new.outcome is not null
      or new.candidate_sha256 is not null
      or new.preview_storage_path is not null
    then
      raise exception 'an attempt starts generating, with no result';
    end if;
    if exists (
      select 1 from public.kit_preview_attempts
      where generation_id = new.generation_id and status <> 'completed'
    ) then
      raise exception 'the previous attempt is still in flight';
    end if;
    select coalesce(max(attempt_number), 0) + 1 into v_next
    from public.kit_preview_attempts
    where generation_id = new.generation_id;
    if new.attempt_number <> v_next
      or new.attempt_number > v_generation.max_attempts
    then
      raise exception 'attempts are sequential and bounded';
    end if;
    return new;
  end if;

  if old.status = 'completed' then
    raise exception 'a completed attempt is immutable';
  end if;
  if new.id <> old.id
    or new.user_id <> old.user_id
    or new.generation_id <> old.generation_id
    or new.attempt_number <> old.attempt_number
    or new.preview_prompt_version <> old.preview_prompt_version
    or new.model_name <> old.model_name
    or new.created_at <> old.created_at
    or (old.candidate_sha256 is not null
      and new.candidate_sha256 is distinct from old.candidate_sha256)
    or (old.preview_storage_path is not null
      and (new.preview_storage_path is distinct from old.preview_storage_path
        or new.preview_generation_number
          is distinct from old.preview_generation_number))
  then
    raise exception 'attempt identity is immutable';
  end if;
  if old.status = 'validating' and new.status = 'generating' then
    raise exception 'attempt status moves forward only';
  end if;
  if old.preview_storage_path is null and new.preview_storage_path is not null
    and (old.status <> 'validating' or new.status <> 'validating')
  then
    raise exception 'a preview slot is claimed only while validating';
  end if;
  if new.outcome = 'accepted' and old.status <> 'validating' then
    raise exception 'only a validated candidate can be accepted';
  end if;
  return new;
end;
$$;

drop trigger if exists kit_preview_attempts_guard
  on public.kit_preview_attempts;
create trigger kit_preview_attempts_guard
before insert or update on public.kit_preview_attempts
for each row execute function public.guard_kit_preview_attempt();

-- Deleting is left to cascades (a deleted look takes its generations and
-- attempts with it); nothing else may delete.
alter table public.kit_preview_generations enable row level security;
revoke all on table public.kit_preview_generations from public;
revoke all on table public.kit_preview_generations from anon;
revoke all on table public.kit_preview_generations from authenticated;
grant select, insert, update on table public.kit_preview_generations
  to service_role;

alter table public.kit_preview_attempts enable row level security;
revoke all on table public.kit_preview_attempts from public;
revoke all on table public.kit_preview_attempts from anon;
revoke all on table public.kit_preview_attempts from authenticated;
grant select, insert, update on table public.kit_preview_attempts
  to service_role;

-- ---------------------------------------------------------------------------
-- 4. Lineage on kit_generated_images
-- ---------------------------------------------------------------------------

alter table public.kit_generated_images
  add column if not exists plan_id uuid,
  add column if not exists plan_digest text,
  add column if not exists operation_id uuid,
  add column if not exists accepted_attempt_id uuid,
  add column if not exists content_sha256 text;

alter table public.kit_generated_images
  add constraint kit_generated_images_lineage_all_or_none check (
    (plan_id is null and plan_digest is null and operation_id is null
      and accepted_attempt_id is null and content_sha256 is null)
    or (plan_id is not null and plan_digest is not null
      and operation_id is not null and accepted_attempt_id is not null
      and content_sha256 is not null)
  ),
  add constraint kit_generated_images_plan_digest_format
    check (plan_digest is null or plan_digest ~ '^[0-9a-f]{64}$'),
  add constraint kit_generated_images_content_sha_format
    check (content_sha256 is null or content_sha256 ~ '^[0-9a-f]{64}$'),
  add constraint kit_generated_images_plan_fk
    foreign key (kit_recommendation_id, plan_id, user_id)
    references public.kit_makeup_recommendations(id, plan_id, user_id)
    on delete cascade,
  add constraint kit_generated_images_accepted_attempt_fk
    foreign key (accepted_attempt_id, user_id)
    references public.kit_preview_attempts(id, user_id)
    on delete cascade;

create unique index if not exists kit_generated_images_operation_idx
  on public.kit_generated_images (operation_id)
  where operation_id is not null;
create unique index if not exists kit_generated_images_accepted_attempt_idx
  on public.kit_generated_images (accepted_attempt_id)
  where accepted_attempt_id is not null;

-- A plan-backed preview exists only as the product of one accepted attempt of
-- the same operation, plan, and bytes.
create or replace function public.guard_kit_generated_image_lineage()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.kit_preview_attempts%rowtype;
  v_generation public.kit_preview_generations%rowtype;
begin
  if tg_op = 'UPDATE' then
    if old.plan_id is not null then
      raise exception 'plan-backed kit previews are immutable';
    end if;
    if new.plan_id is not null or new.plan_digest is not null
      or new.operation_id is not null or new.accepted_attempt_id is not null
      or new.content_sha256 is not null
    then
      raise exception 'lineage cannot be attached to an existing kit preview';
    end if;
    return new;
  end if;

  if new.plan_id is null then
    return new;
  end if;
  select * into v_attempt
  from public.kit_preview_attempts where id = new.accepted_attempt_id;
  select * into v_generation
  from public.kit_preview_generations where id = v_attempt.generation_id;
  if v_attempt.id is null
    or v_attempt.outcome is distinct from 'accepted'
    or v_generation.operation_id is distinct from new.operation_id
    or v_generation.plan_id is distinct from new.plan_id
    or v_generation.plan_digest is distinct from new.plan_digest
    or v_generation.kit_recommendation_id
      is distinct from new.kit_recommendation_id
    or v_attempt.candidate_sha256 is distinct from new.content_sha256
    or v_attempt.preview_prompt_version is distinct from new.prompt_version
    or v_attempt.model_name is distinct from new.model_name
    or v_attempt.preview_storage_path is distinct from new.storage_path
    or v_attempt.preview_generation_number
      is distinct from new.generation_number
  then
    raise exception 'a plan-backed preview requires its accepted attempt';
  end if;
  return new;
end;
$$;

drop trigger if exists kit_generated_images_lineage_guard
  on public.kit_generated_images;
create trigger kit_generated_images_lineage_guard
before insert or update on public.kit_generated_images
for each row execute function public.guard_kit_generated_image_lineage();

drop policy if exists "kit_generated_images_insert_own"
  on public.kit_generated_images;
create policy "kit_generated_images_insert_own"
on public.kit_generated_images for insert to authenticated
with check ((select auth.uid()) = user_id and plan_id is null);

drop policy if exists "kit_generated_images_update_own"
  on public.kit_generated_images;
create policy "kit_generated_images_update_own"
on public.kit_generated_images for update to authenticated
using ((select auth.uid()) = user_id and plan_id is null)
with check ((select auth.uid()) = user_id and plan_id is null);

grant select on table public.kit_generated_images to service_role;

-- ---------------------------------------------------------------------------
-- 5. Accepted-preview slot and finalize
-- ---------------------------------------------------------------------------
--
-- The Tutorial path contract names an accepted object `preview_NNNN.<ext>`, so
-- its path must be known before the bytes are uploaded. The slot is claimed
-- first, the bytes are uploaded to it, and only then is the attempt accepted
-- and the preview row written, in one transaction. A crash between claim and
-- finalize leaves the attempt validating; the next lease holder abandons it and
-- removes the object at the recorded path.

create or replace function public.pdmk_claim_preview_slot(
  p_attempt_id uuid,
  p_extension text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.kit_preview_attempts%rowtype;
  v_generation public.kit_preview_generations%rowtype;
  v_analysis_id uuid;
  v_number integer;
  v_path text;
begin
  if p_extension is null or p_extension not in ('jpg', 'png', 'webp') then
    raise exception 'unsupported preview extension';
  end if;
  select * into v_attempt
  from public.kit_preview_attempts where id = p_attempt_id for update;
  if not found then
    raise exception 'attempt not found';
  end if;
  if v_attempt.preview_storage_path is not null then
    return jsonb_build_object(
      'generationNumber', v_attempt.preview_generation_number,
      'storagePath', v_attempt.preview_storage_path
    );
  end if;
  if v_attempt.status <> 'validating' then
    raise exception 'a preview slot is claimed only while validating';
  end if;
  select * into v_generation
  from public.kit_preview_generations where id = v_attempt.generation_id;
  select analysis_id into v_analysis_id
  from public.kit_makeup_recommendations
  where id = v_generation.kit_recommendation_id;

  perform pg_advisory_xact_lock(
    hashtextextended(v_generation.kit_recommendation_id::text, 0)
  );
  select greatest(
    coalesce((
      select max(k.generation_number) from public.kit_generated_images as k
      where k.kit_recommendation_id = v_generation.kit_recommendation_id
    ), 0),
    coalesce((
      select max(a.preview_generation_number)
      from public.kit_preview_attempts as a
      join public.kit_preview_generations as g on g.id = a.generation_id
      where g.kit_recommendation_id = v_generation.kit_recommendation_id
    ), 0)
  ) + 1 into v_number;
  if v_number > 9999 then
    raise exception 'preview slots exhausted for this look';
  end if;
  v_path := v_attempt.user_id::text || '/analyses/' || v_analysis_id::text
    || '/kit-generated/' || v_generation.kit_recommendation_id::text
    || '/preview_' || lpad(v_number::text, 4, '0') || '.' || p_extension;

  update public.kit_preview_attempts
  set preview_generation_number = v_number,
      preview_storage_path = v_path
  where id = p_attempt_id;

  return jsonb_build_object(
    'generationNumber', v_number,
    'storagePath', v_path
  );
end;
$$;

create or replace function public.pdmk_finalize_accepted_attempt(
  p_attempt_id uuid,
  p_validator_version text,
  p_evidence jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_attempt public.kit_preview_attempts%rowtype;
  v_generation public.kit_preview_generations%rowtype;
  v_analysis_id uuid;
  v_preview_id uuid;
  v_now timestamptz := timezone('utc', now());
begin
  select * into v_attempt
  from public.kit_preview_attempts where id = p_attempt_id for update;
  if not found then
    raise exception 'attempt not found';
  end if;
  select * into v_generation
  from public.kit_preview_generations
  where id = v_attempt.generation_id for update;

  if v_attempt.outcome = 'accepted' then
    select id into v_preview_id
    from public.kit_generated_images where accepted_attempt_id = p_attempt_id;
    return v_preview_id;
  end if;
  if v_attempt.status <> 'validating'
    or v_attempt.preview_storage_path is null
  then
    raise exception 'only a validating attempt with a claimed slot can be accepted';
  end if;

  update public.kit_preview_attempts
  set status = 'completed',
      outcome = 'accepted',
      validator_version = p_validator_version,
      evidence_json = p_evidence,
      mismatch_categories = '{}',
      missing_required_categories = '{}',
      reason_code = null,
      completed_at = v_now
  where id = p_attempt_id;

  select analysis_id into v_analysis_id
  from public.kit_makeup_recommendations
  where id = v_generation.kit_recommendation_id;

  insert into public.kit_generated_images (
    user_id, analysis_id, kit_recommendation_id, storage_path,
    generation_number, model_name, prompt_version,
    plan_id, plan_digest, operation_id, accepted_attempt_id, content_sha256
  ) values (
    v_attempt.user_id, v_analysis_id, v_generation.kit_recommendation_id,
    v_attempt.preview_storage_path, v_attempt.preview_generation_number,
    v_attempt.model_name, v_attempt.preview_prompt_version,
    v_generation.plan_id, v_generation.plan_digest, v_generation.operation_id,
    p_attempt_id, v_attempt.candidate_sha256
  )
  returning id into v_preview_id;

  update public.kit_preview_generations
  set status = 'accepted',
      terminal_outcome = 'accepted',
      completed_at = v_now,
      lease_expires_at = null
  where id = v_generation.id;

  return v_preview_id;
end;
$$;

revoke all on function public.pdmk_claim_preview_slot(uuid, text) from public;
revoke all on function public.pdmk_claim_preview_slot(uuid, text) from anon;
revoke all on function public.pdmk_claim_preview_slot(uuid, text)
  from authenticated;
grant execute on function public.pdmk_claim_preview_slot(uuid, text)
  to service_role;

revoke all on function public.pdmk_finalize_accepted_attempt(uuid, text, jsonb)
  from public;
revoke all on function public.pdmk_finalize_accepted_attempt(uuid, text, jsonb)
  from anon;
revoke all on function public.pdmk_finalize_accepted_attempt(uuid, text, jsonb)
  from authenticated;
grant execute on function public.pdmk_finalize_accepted_attempt(uuid, text, jsonb)
  to service_role;
