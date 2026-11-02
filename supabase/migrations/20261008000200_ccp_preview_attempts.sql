-- CCP — accepted Custom Color Palette previews and the attempts behind them.
--
-- `custom_palette_generated_images` holds accepted previews only, so a failed
-- candidate has no row to appear through in History, Saved Looks or Tutorial.
-- Its image is never stored at all. `custom_palette_preview_attempts` records
-- codes for every provider attempt and is what makes retries bounded, traceable
-- and safe to replay.
--
-- Each attempt owns its generation number, and therefore its own `preview_NNNN`
-- path. A worker whose lease expired can clean up its own upload without any
-- risk of deleting the file of the attempt that replaced it. Numbers can have
-- gaps as a result; nothing depends on them being contiguous.
--
-- All writes go through the service-role RPCs below. As in the palette migration,
-- the remote default ACL makes every privilege explicit here.

-- ---------------------------------------------------------------------------
-- 1. Accepted previews
-- ---------------------------------------------------------------------------
create table public.custom_palette_generated_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  custom_palette_recommendation_id uuid not null,
  storage_path text not null unique,
  generation_number integer not null,
  -- One logical preview request produces at most one accepted preview.
  operation_id uuid not null unique,
  accepted_attempt_number integer not null,
  validation_outcome text not null,
  validator_version text not null,
  model_name text not null,
  prompt_version text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint custom_palette_generated_images_owner_identity
    unique (id, user_id),
  constraint custom_palette_generated_images_generation_unique
    unique (custom_palette_recommendation_id, generation_number),
  constraint custom_palette_generated_images_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint custom_palette_generated_images_recommendation_owner_fk
    foreign key (custom_palette_recommendation_id, analysis_id, user_id)
    references public.custom_palette_recommendations(id, analysis_id, user_id)
    on delete cascade,
  constraint custom_palette_generated_images_generation_positive
    check (generation_number > 0),
  constraint custom_palette_generated_images_attempt_positive
    check (accepted_attempt_number > 0),
  -- This table cannot say anything but "accepted".
  constraint custom_palette_generated_images_outcome_accepted
    check (validation_outcome = 'accepted'),
  constraint custom_palette_generated_images_path_not_blank
    check (char_length(btrim(storage_path)) > 0),
  constraint custom_palette_generated_images_validator_not_blank
    check (char_length(btrim(validator_version)) > 0),
  constraint custom_palette_generated_images_model_not_blank
    check (char_length(btrim(model_name)) > 0),
  constraint custom_palette_generated_images_prompt_not_blank
    check (char_length(btrim(prompt_version)) > 0)
);

create index custom_palette_generated_images_user_created_idx
  on public.custom_palette_generated_images (user_id, created_at desc);
create index custom_palette_generated_images_analysis_idx
  on public.custom_palette_generated_images (analysis_id);

create trigger custom_palette_generated_images_immutable
before update on public.custom_palette_generated_images
for each row execute function public.reject_custom_palette_update();

-- ---------------------------------------------------------------------------
-- 2. Attempts: codes only, never an image, a prompt, or provider text
-- ---------------------------------------------------------------------------
create table public.custom_palette_preview_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation_id uuid not null,
  custom_palette_recommendation_id uuid not null,
  attempt_number integer not null,
  generation_number integer not null,
  status text not null default 'running',
  mismatch_category_codes text[] not null default '{}',
  -- `category:reason`, from closed vocabularies. Lets a retry that runs in a
  -- later invocation tighten its instructions from what the last attempt did.
  mismatch_reason_codes text[] not null default '{}',
  validator_version text,
  prompt_version text not null,
  lease_expires_at timestamptz not null,
  started_at timestamptz not null default timezone('utc', now()),
  finished_at timestamptz,
  constraint custom_palette_preview_attempts_number_unique
    unique (operation_id, attempt_number),
  constraint custom_palette_preview_attempts_generation_unique
    unique (custom_palette_recommendation_id, generation_number),
  constraint custom_palette_preview_attempts_recommendation_owner_fk
    foreign key (custom_palette_recommendation_id, user_id)
    references public.custom_palette_recommendations(id, user_id)
    on delete cascade,
  constraint custom_palette_preview_attempts_number_positive
    check (attempt_number > 0),
  constraint custom_palette_preview_attempts_generation_positive
    check (generation_number > 0),
  constraint custom_palette_preview_attempts_status_valid
    check (status in (
      'running',
      'accepted',
      'retryable_palette_mismatch',
      'nonretryable_palette_mismatch',
      'validator_failure',
      'provider_failure',
      'abandoned'
    )),
  constraint custom_palette_preview_attempts_finish_pair
    check ((status = 'running') = (finished_at is null))
);

-- The concurrency gates: one worker at a time, and one winner per operation.
create unique index custom_palette_preview_attempts_one_running
  on public.custom_palette_preview_attempts (operation_id)
  where status = 'running';
create unique index custom_palette_preview_attempts_one_accepted
  on public.custom_palette_preview_attempts (operation_id)
  where status = 'accepted';

-- An attempt's identity never changes, and a finished attempt is final. A late
-- duplicate completion therefore cannot rewrite what already happened.
create or replace function public.guard_custom_palette_attempt()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.status <> 'running' then
    raise exception 'a finished custom palette attempt is immutable';
  end if;
  if new.user_id <> old.user_id
    or new.operation_id <> old.operation_id
    or new.custom_palette_recommendation_id
      <> old.custom_palette_recommendation_id
    or new.attempt_number <> old.attempt_number
    or new.generation_number <> old.generation_number
    or new.prompt_version <> old.prompt_version
    or new.started_at <> old.started_at
  then
    raise exception 'custom palette attempt identity is immutable';
  end if;
  return new;
end;
$$;

revoke all on function public.guard_custom_palette_attempt()
  from public, anon, authenticated, service_role;

create trigger custom_palette_preview_attempts_guard
before update on public.custom_palette_preview_attempts
for each row execute function public.guard_custom_palette_attempt();

-- ---------------------------------------------------------------------------
-- 3. Row level security and privileges
-- ---------------------------------------------------------------------------
alter table public.custom_palette_generated_images enable row level security;
alter table public.custom_palette_preview_attempts enable row level security;

revoke all on table public.custom_palette_generated_images
  from public, anon, authenticated, service_role;
revoke all on table public.custom_palette_preview_attempts
  from public, anon, authenticated, service_role;

grant select on table public.custom_palette_generated_images to authenticated;
grant select on table public.custom_palette_generated_images to service_role;

create policy "custom_palette_generated_images_select_own"
on public.custom_palette_generated_images for select to authenticated
using ((select auth.uid()) = user_id);

-- Attempts have no client access at all: they are operational records.

-- ---------------------------------------------------------------------------
-- 4. Claim one attempt
-- ---------------------------------------------------------------------------
-- The caller passes the bound and the lease; the rules live here. Serialized per
-- account with the same lock the usage engine takes, so generation numbers and
-- the one-running rule hold under concurrent invocations.
create or replace function public.claim_custom_palette_preview_attempt(
  p_user_id uuid,
  p_operation_id uuid,
  p_recommendation_id uuid,
  p_max_attempts integer,
  p_lease_seconds integer,
  p_prompt_version text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_count integer;
  v_last public.custom_palette_preview_attempts%rowtype;
  v_generation integer;
  v_preview uuid;
begin
  if p_user_id is null or p_operation_id is null or p_recommendation_id is null
    or coalesce(p_max_attempts, 0) < 1 or coalesce(p_lease_seconds, 0) < 1
  then
    raise exception using errcode = '22023', message = 'invalid attempt claim';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  if not exists (
    select 1 from public.custom_palette_recommendations as r
    where r.id = p_recommendation_id and r.user_id = p_user_id
  ) then
    return jsonb_build_object('status', 'not_found');
  end if;

  if exists (
    select 1 from public.custom_palette_preview_attempts as a
    where a.operation_id = p_operation_id
      and (
        a.user_id <> p_user_id
        or a.custom_palette_recommendation_id <> p_recommendation_id
      )
  ) then
    return jsonb_build_object('status', 'conflict');
  end if;

  select i.id into v_preview
  from public.custom_palette_generated_images as i
  where i.operation_id = p_operation_id and i.user_id = p_user_id;
  if v_preview is not null then
    return jsonb_build_object('status', 'accepted', 'previewId', v_preview);
  end if;

  -- A worker that outlived its lease is gone. Its attempt still counts.
  update public.custom_palette_preview_attempts as a
  set status = 'abandoned', finished_at = v_now
  where a.operation_id = p_operation_id
    and a.status = 'running'
    and a.lease_expires_at <= v_now;

  if exists (
    select 1 from public.custom_palette_preview_attempts as a
    where a.operation_id = p_operation_id and a.status = 'running'
  ) then
    return jsonb_build_object('status', 'in_progress');
  end if;

  select count(*) into v_count
  from public.custom_palette_preview_attempts as a
  where a.operation_id = p_operation_id;

  select * into v_last
  from public.custom_palette_preview_attempts as a
  where a.operation_id = p_operation_id
  order by a.attempt_number desc
  limit 1;

  if v_last.status = 'nonretryable_palette_mismatch' then
    return jsonb_build_object(
      'status', 'terminal',
      'lastStatus', v_last.status,
      'mismatchCategories', to_jsonb(v_last.mismatch_category_codes)
    );
  end if;
  if v_count >= p_max_attempts then
    return jsonb_build_object(
      'status', 'exhausted',
      'lastStatus', v_last.status,
      'mismatchCategories', to_jsonb(v_last.mismatch_category_codes)
    );
  end if;

  select greatest(
    coalesce((
      select max(a.generation_number)
      from public.custom_palette_preview_attempts as a
      where a.custom_palette_recommendation_id = p_recommendation_id
    ), 0),
    coalesce((
      select max(i.generation_number)
      from public.custom_palette_generated_images as i
      where i.custom_palette_recommendation_id = p_recommendation_id
    ), 0)
  ) + 1 into v_generation;

  insert into public.custom_palette_preview_attempts (
    user_id, operation_id, custom_palette_recommendation_id, attempt_number,
    generation_number, prompt_version, lease_expires_at, started_at
  ) values (
    p_user_id, p_operation_id, p_recommendation_id, v_count + 1, v_generation,
    p_prompt_version, v_now + make_interval(secs => p_lease_seconds), v_now
  );

  return jsonb_build_object(
    'status', 'claimed',
    'attemptNumber', v_count + 1,
    'generationNumber', v_generation,
    'previousReasons', to_jsonb(coalesce(
      v_last.mismatch_reason_codes, '{}'::text[]
    ))
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Finish an attempt that did not produce an accepted preview
-- ---------------------------------------------------------------------------
-- Only a running attempt can finish. A duplicate or late completion gets
-- `stale` and changes nothing.
create or replace function public.finish_custom_palette_preview_attempt(
  p_user_id uuid,
  p_operation_id uuid,
  p_attempt_number integer,
  p_status text,
  p_mismatch_category_codes text[] default '{}',
  p_mismatch_reason_codes text[] default '{}',
  p_validator_version text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_status not in (
    'retryable_palette_mismatch',
    'nonretryable_palette_mismatch',
    'validator_failure',
    'provider_failure',
    'abandoned'
  ) or p_status is null then
    raise exception using errcode = '22023', message = 'invalid attempt status';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  update public.custom_palette_preview_attempts as a
  set status = p_status,
      mismatch_category_codes = coalesce(p_mismatch_category_codes, '{}'),
      mismatch_reason_codes = coalesce(p_mismatch_reason_codes, '{}'),
      validator_version = p_validator_version,
      finished_at = timezone('utc', now())
  where a.operation_id = p_operation_id
    and a.attempt_number = p_attempt_number
    and a.user_id = p_user_id
    and a.status = 'running';

  if not found then
    return jsonb_build_object('ok', false, 'status', 'stale');
  end if;
  return jsonb_build_object('ok', true, 'status', p_status);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Finalize the accepted candidate
-- ---------------------------------------------------------------------------
-- The only way a preview row can exist. One transaction: the row appears exactly
-- when its attempt becomes accepted, and only for a reservation that exists. A
-- replay returns the existing row, so duplicate completions make one preview.
create or replace function public.finalize_custom_palette_preview(
  p_user_id uuid,
  p_operation_id uuid,
  p_attempt_number integer,
  p_storage_path text,
  p_model_name text,
  p_prompt_version text,
  p_validator_version text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing public.custom_palette_generated_images%rowtype;
  v_attempt public.custom_palette_preview_attempts%rowtype;
  v_analysis uuid;
  v_inserted public.custom_palette_generated_images%rowtype;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  select * into v_existing
  from public.custom_palette_generated_images as i
  where i.operation_id = p_operation_id and i.user_id = p_user_id;
  if found then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'preview', to_jsonb(v_existing)
    );
  end if;

  select * into v_attempt
  from public.custom_palette_preview_attempts as a
  where a.operation_id = p_operation_id
    and a.attempt_number = p_attempt_number
    and a.user_id = p_user_id
    and a.status = 'running';
  if not found then
    return jsonb_build_object('ok', false, 'status', 'stale');
  end if;

  if not exists (
    select 1 from public.usage_ledger as l
    where l.operation_id = p_operation_id and l.user_id = p_user_id
  ) then
    return jsonb_build_object('ok', false, 'status', 'no_reservation');
  end if;

  select r.analysis_id into v_analysis
  from public.custom_palette_recommendations as r
  where r.id = v_attempt.custom_palette_recommendation_id
    and r.user_id = p_user_id;

  insert into public.custom_palette_generated_images (
    user_id, analysis_id, custom_palette_recommendation_id, storage_path,
    generation_number, operation_id, accepted_attempt_number,
    validation_outcome, validator_version, model_name, prompt_version
  ) values (
    p_user_id, v_analysis, v_attempt.custom_palette_recommendation_id,
    p_storage_path, v_attempt.generation_number, p_operation_id,
    v_attempt.attempt_number, 'accepted', p_validator_version, p_model_name,
    p_prompt_version
  )
  returning * into v_inserted;

  update public.custom_palette_preview_attempts as a
  set status = 'accepted',
      validator_version = p_validator_version,
      finished_at = timezone('utc', now())
  where a.id = v_attempt.id;

  return jsonb_build_object(
    'ok', true, 'replayed', false, 'preview', to_jsonb(v_inserted)
  );
end;
$$;

revoke all on function public.claim_custom_palette_preview_attempt(
  uuid, uuid, uuid, integer, integer, text
) from public, anon, authenticated;
revoke all on function public.finish_custom_palette_preview_attempt(
  uuid, uuid, integer, text, text[], text[], text
) from public, anon, authenticated;
revoke all on function public.finalize_custom_palette_preview(
  uuid, uuid, integer, text, text, text, text
) from public, anon, authenticated;

grant execute on function public.claim_custom_palette_preview_attempt(
  uuid, uuid, uuid, integer, integer, text
) to service_role;
grant execute on function public.finish_custom_palette_preview_attempt(
  uuid, uuid, integer, text, text[], text[], text
) to service_role;
grant execute on function public.finalize_custom_palette_preview(
  uuid, uuid, integer, text, text, text, text
) to service_role;
