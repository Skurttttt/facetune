-- FaceTune SUB-4: the atomic AI Look usage engine.
--
-- Purely additive. No existing table, column, constraint, policy, grant, or
-- trigger is altered or dropped. Nothing from SUB-2 or SUB-3 is changed.
--
-- Four functions implement the whole usage lifecycle:
--
--     reserve_ai_look   hold capacity before any paid work begins
--     commit_ai_look    charge exactly one AI Look once a usable preview exists
--     release_ai_look   return capacity when the operation definitively failed
--     reconcile_stale_ai_look_reservations
--                       resolve reservations abandoned mid-flight, safely
--
-- Deliberately NOT done here:
--
--   * No Final Preview wiring. Neither preview Edge Function is touched;
--     calling these from the generation path is SUB-5.
--   * No new AI call, no provider work, no UI.
--   * No duplicate capacity calculator. Every authorization and capacity
--     decision defers to `public.resolve_subscription_state()` from SUB-3, so
--     there is exactly one place where "may I generate, and how many are left"
--     is decided.
--
-- ---------------------------------------------------------------------------
-- Why these are database functions rather than Edge Function transactions
-- ---------------------------------------------------------------------------
--
-- No Edge Function in this project holds the service-role key, and clients hold
-- no write privilege on `usage_ledger` at all (SUB-2). A `security definer`
-- function is therefore the only path that can write the ledger, and it is also
-- the only place where "check capacity" and "insert the reservation" can share
-- one transaction. Doing this over PostgREST from an Edge Function would leave
-- a gap between the read and the write that two concurrent requests could both
-- slip through. This follows `public.consume_ai_quota` (20260812000100).

-- ---------------------------------------------------------------------------
-- 1. Reserve
-- ---------------------------------------------------------------------------
--
-- Holds one AI Look before any paid generation starts.
--
-- Concurrency is handled with a transaction-scoped advisory lock keyed on the
-- account. Two simultaneous reserve calls for the same user serialize on it, so
-- the capacity check and the insert cannot interleave — which is precisely the
-- race that would let two requests spend the same last AI Look. The lock is
-- keyed on the *user* rather than the entitlement row because a renewal can
-- swap which entitlement is current mid-flight; the account is the stable
-- identity. Different accounts never contend, and `pg_advisory_xact_lock`
-- releases automatically when the transaction ends, including on error.
--
-- Idempotency comes from `operation_id`, which is globally unique. A repeated
-- reserve for the same operation returns the existing reservation rather than
-- creating a second one or reporting an error, so a duplicate tap, a client
-- retry, or a lost response all converge on one logical hold.
create or replace function public.reserve_ai_look(p_operation_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_existing public.usage_ledger%rowtype;
  v_state jsonb;
  v_entitlement_id uuid;
  v_period_start timestamptz;
  v_period_end timestamptz;
begin
  if v_user is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'AUTH_REQUIRED', 'operationId', p_operation_id
    );
  end if;

  if p_operation_id is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_OPERATION_NOT_FOUND'
    );
  end if;

  -- Serialize this account's reservations for the rest of the transaction.
  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  -- Idempotent replay. Checked inside the lock so two concurrent identical
  -- operations cannot both miss it and race to insert.
  select * into v_existing
  from public.usage_ledger
  where operation_id = p_operation_id;

  if found then
    if v_existing.user_id <> v_user then
      -- Another account owns this operation. Report it as absent rather than
      -- as a conflict: confirming that an id exists elsewhere would leak the
      -- existence of another account's operation.
      return jsonb_build_object(
        'ok', false,
        'errorCode', 'USAGE_OPERATION_NOT_FOUND',
        'operationId', p_operation_id
      );
    end if;

    return jsonb_build_object(
      'ok', v_existing.status = 'reserved',
      'replayed', true,
      'operationId', p_operation_id,
      'status', v_existing.status,
      'entitlementId', v_existing.entitlement_id,
      'errorCode', case
        when v_existing.status = 'committed' then 'USAGE_ALREADY_COMMITTED'
        when v_existing.status = 'released' then 'USAGE_ALREADY_RELEASED'
        else null
      end
    );
  end if;

  -- One authority for eligibility and capacity: the SUB-3 resolver. It already
  -- accounts for status, lapsed dates, future start dates, adjustments, and
  -- active reservations, so none of that logic is repeated here.
  v_state := public.resolve_subscription_state();

  if (v_state->>'generationAuthorized')::boolean is not true then
    return jsonb_build_object(
      'ok', false,
      'operationId', p_operation_id,
      'errorCode', coalesce(v_state->>'denialReason', 'ENTITLEMENT_INACTIVE'),
      'availableAiLooks', coalesce((v_state->>'availableAiLooks')::int, 0)
    );
  end if;

  v_entitlement_id := (v_state->>'entitlementId')::uuid;

  select e.period_start, e.period_end
    into v_period_start, v_period_end
  from public.user_entitlements as e
  where e.id = v_entitlement_id and e.user_id = v_user;

  -- `reserved_at` is written in the same statement that the capacity check
  -- authorized, and is what period membership is later decided by.
  insert into public.usage_ledger (
    user_id, entitlement_id, operation_id, status,
    period_start, period_end, reserved_at
  )
  values (
    v_user, v_entitlement_id, p_operation_id, 'reserved',
    v_period_start, v_period_end, v_now
  );

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'operationId', p_operation_id,
    'status', 'reserved',
    'entitlementId', v_entitlement_id,
    -- Recomputed after the insert, so the caller sees capacity that already
    -- accounts for the hold it just took.
    'availableAiLooks',
      coalesce(
        (public.resolve_subscription_state()->>'availableAiLooks')::int, 0
      )
  );
exception
  when unique_violation then
    -- Belt and braces behind the advisory lock: if two identical operations
    -- ever did race past it, the unique constraint on `operation_id` decides,
    -- and the loser reports the winner's reservation rather than an error.
    return jsonb_build_object(
      'ok', true, 'replayed', true,
      'operationId', p_operation_id, 'status', 'reserved'
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Commit
-- ---------------------------------------------------------------------------
--
-- Charges exactly one AI Look, and only once a usable canonical Final Makeup
-- Preview has been persisted for the caller.
--
-- Ownership of the preview is enforced twice: explicitly here for a clean
-- sanitized error, and structurally by the composite `(preview_id, user_id)`
-- foreign key from SUB-2, which cannot be talked out of it.
--
-- A repeat of the same commit is idempotent when it names the same preview.
-- Naming a *different* preview for an already-committed operation is a
-- conflict, not a replay — that would be two AI Looks wearing one operation id.
create or replace function public.commit_ai_look(
  p_operation_id uuid,
  p_source_mode text,
  p_canonical_preview_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_row public.usage_ledger%rowtype;
  v_owned boolean;
  v_current_preview uuid;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  if p_source_mode is null or p_source_mode not in ('standard', 'makeup_kit')
  then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  if p_canonical_preview_id is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  select * into v_row
  from public.usage_ledger
  where operation_id = p_operation_id
  for update;

  if not found or v_row.user_id <> v_user then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_OPERATION_NOT_FOUND',
      'operationId', p_operation_id
    );
  end if;

  -- The preview must belong to the caller. Checked against the owning table so
  -- a valid-looking uuid from another account is refused with a sanitized
  -- code rather than surfacing a raw foreign-key error.
  if p_source_mode = 'standard' then
    select exists (
      select 1 from public.generated_images as g
      where g.id = p_canonical_preview_id and g.user_id = v_user
    ) into v_owned;
  else
    select exists (
      select 1 from public.kit_generated_images as k
      where k.id = p_canonical_preview_id and k.user_id = v_user
    ) into v_owned;
  end if;

  if not v_owned then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  if v_row.status = 'committed' then
    v_current_preview := coalesce(
      v_row.canonical_generated_image_id,
      v_row.canonical_kit_generated_image_id
    );
    -- Idempotent replay: the same operation committing the same preview again.
    -- Also treated as a replay when the preview reference has since been
    -- cleared by a history deletion — the charge stands either way.
    if v_current_preview is null or v_current_preview = p_canonical_preview_id
    then
      return jsonb_build_object(
        'ok', true, 'replayed', true, 'operationId', p_operation_id,
        'status', 'committed'
      );
    end if;
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_ALREADY_COMMITTED',
      'operationId', p_operation_id, 'status', 'committed'
    );
  end if;

  -- A released operation that turns out to have produced a usable persisted
  -- preview is corrected to committed rather than left unpaid.
  --
  -- This is deliberate and it closes a real hole. `release_ai_look` has to be
  -- callable by the same authenticated identity the generation path runs as,
  -- so a client could otherwise release its own in-flight reservation, let the
  -- Edge Function finish generating, and keep a persisted preview that was
  -- never charged. The hard lock cuts both ways: no usable persisted preview
  -- means no charge, and a usable persisted preview means exactly one charge.
  -- Evidence that the work succeeded outranks a premature release.
  --
  -- The opposite transition is never allowed: `committed` is terminal, above
  -- and in the SUB-2 immutability trigger.
  update public.usage_ledger
  set status = 'committed',
      source_mode = p_source_mode,
      canonical_generated_image_id = case
        when p_source_mode = 'standard' then p_canonical_preview_id else null
      end,
      canonical_kit_generated_image_id = case
        when p_source_mode = 'makeup_kit' then p_canonical_preview_id else null
      end,
      committed_at = greatest(v_now, v_row.reserved_at),
      released_at = null,
      sanitized_failure_code = null
  where id = v_row.id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'operationId', p_operation_id,
    'status', 'committed',
    'correctedFromReleased', v_row.status = 'released'
  );
exception
  when unique_violation then
    -- The one-charge-per-preview indexes rejected this: some other operation
    -- has already been billed for this canonical preview.
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Release
-- ---------------------------------------------------------------------------
--
-- Returns held capacity when an operation definitively ended without a usable
-- persisted canonical preview.
--
-- A committed operation is never released. That is the one transition the whole
-- ledger exists to forbid, and it is refused here as well as by the SUB-2
-- trigger.
create or replace function public.release_ai_look(
  p_operation_id uuid,
  p_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_row public.usage_ledger%rowtype;
  v_code text;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  -- Sanitized and bounded. A provider payload, stack trace, storage path, or
  -- SQL error must never reach this column, so anything unusable is dropped
  -- rather than stored.
  v_code := nullif(btrim(coalesce(p_failure_code, '')), '');
  if v_code is not null and char_length(v_code) > 64 then
    v_code := left(v_code, 64);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  select * into v_row
  from public.usage_ledger
  where operation_id = p_operation_id
  for update;

  if not found or v_row.user_id <> v_user then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_OPERATION_NOT_FOUND',
      'operationId', p_operation_id
    );
  end if;

  if v_row.status = 'committed' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_ALREADY_COMMITTED',
      'operationId', p_operation_id, 'status', 'committed'
    );
  end if;

  if v_row.status = 'released' then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'operationId', p_operation_id,
      'status', 'released'
    );
  end if;

  update public.usage_ledger
  set status = 'released',
      released_at = greatest(v_now, v_row.reserved_at),
      committed_at = null,
      source_mode = null,
      canonical_generated_image_id = null,
      canonical_kit_generated_image_id = null,
      sanitized_failure_code = v_code
  where id = v_row.id;

  return jsonb_build_object(
    'ok', true, 'replayed', false, 'operationId', p_operation_id,
    'status', 'released'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Stale reservation reconciliation
-- ---------------------------------------------------------------------------
--
-- A reservation can be abandoned mid-flight: the Edge Function times out, the
-- container is recycled, the network drops the response. The held capacity must
-- not stay held forever, and it must not be handed back wrongly either.
--
-- This is NOT a timer that releases anything that has been sitting a while.
-- A client timeout, a lost connection, or a closed app proves nothing about
-- whether the server finished the work. So before returning capacity, this
-- looks for evidence that the work actually succeeded:
--
--   * exactly one canonical preview owned by the same account, created at or
--     after the reservation began, that no ledger row has claimed
--       → the generation succeeded and only the commit call was lost.
--         COMMIT it. Releasing here would hand the user a free AI Look for a
--         preview they can still open.
--
--   * no such preview
--       → nothing usable was persisted. RELEASE.
--
--   * more than one candidate
--       → genuinely ambiguous. Leave it alone and count it as skipped, so a
--         human can look. Guessing risks charging the wrong preview.
--
-- `p_older_than` must comfortably exceed the longest possible server-side
-- generation. The Final Preview path's own documented worst case is about 144
-- seconds of backend work behind a 180 second client budget, so the default
-- here is deliberately an order of magnitude beyond that. It is not
-- self-scheduling — run it from the Supabase dashboard or an authorized
-- server-side job, exactly like `public.purge_ai_usage_events`.
create or replace function public.reconcile_stale_ai_look_reservations(
  p_older_than interval default interval '30 minutes'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cutoff timestamptz := timezone('utc', now()) - greatest(
    p_older_than, interval '10 minutes'
  );
  v_row public.usage_ledger%rowtype;
  v_preview uuid;
  v_mode text;
  v_candidates integer;
  v_committed integer := 0;
  v_released integer := 0;
  v_skipped integer := 0;
begin
  for v_row in
    select * from public.usage_ledger
    where status = 'reserved' and reserved_at < v_cutoff
    order by reserved_at
    for update skip locked
  loop
    -- Unclaimed Standard previews this account produced after the reservation.
    -- Counted and selected separately because there is no `min(uuid)`, and
    -- because the id is only wanted when there is exactly one candidate.
    v_mode := 'standard';
    v_preview := null;

    select count(*) into v_candidates
    from public.generated_images as g
    where g.user_id = v_row.user_id
      and g.created_at >= v_row.reserved_at
      and not exists (
        select 1 from public.usage_ledger as l
        where l.canonical_generated_image_id = g.id
      );

    if v_candidates = 0 then
      v_mode := 'makeup_kit';
      select count(*) into v_candidates
      from public.kit_generated_images as k
      where k.user_id = v_row.user_id
        and k.created_at >= v_row.reserved_at
        and not exists (
          select 1 from public.usage_ledger as l
          where l.canonical_kit_generated_image_id = k.id
        );
    end if;

    if v_candidates = 1 then
      if v_mode = 'standard' then
        select g.id into v_preview
        from public.generated_images as g
        where g.user_id = v_row.user_id
          and g.created_at >= v_row.reserved_at
          and not exists (
            select 1 from public.usage_ledger as l
            where l.canonical_generated_image_id = g.id
          )
        limit 1;
      else
        select k.id into v_preview
        from public.kit_generated_images as k
        where k.user_id = v_row.user_id
          and k.created_at >= v_row.reserved_at
          and not exists (
            select 1 from public.usage_ledger as l
            where l.canonical_kit_generated_image_id = k.id
          )
        limit 1;
      end if;
    end if;

    if v_candidates = 1 then
      update public.usage_ledger
      set status = 'committed',
          source_mode = v_mode,
          canonical_generated_image_id = case
            when v_mode = 'standard' then v_preview else null
          end,
          canonical_kit_generated_image_id = case
            when v_mode = 'makeup_kit' then v_preview else null
          end,
          committed_at = greatest(timezone('utc', now()), v_row.reserved_at),
          released_at = null
      where id = v_row.id;
      v_committed := v_committed + 1;
    elsif v_candidates = 0 then
      update public.usage_ledger
      set status = 'released',
          released_at = greatest(timezone('utc', now()), v_row.reserved_at),
          committed_at = null,
          sanitized_failure_code = 'stale_reservation_reconciled'
      where id = v_row.id;
      v_released := v_released + 1;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'committed', v_committed,
    'released', v_released,
    'skippedAmbiguous', v_skipped
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Privileges
-- ---------------------------------------------------------------------------
--
-- Reserve, commit, and release are executable by `authenticated` because the
-- Final Preview Edge Functions run as the calling user — no Edge Function in
-- this project holds a service-role key. That is safe because none of the three
-- can be turned to a caller's advantage: reserving spends the caller's own
-- capacity, committing charges them for a preview they already own, and
-- releasing an operation whose preview exists is corrected back to committed.
--
-- Reconciliation is not client-callable. It reads and rewrites other people's
-- reservations by design, so `authenticated` is explicitly revoked.
revoke all on function public.reserve_ai_look(uuid) from public;
revoke all on function public.reserve_ai_look(uuid) from anon;
grant execute on function public.reserve_ai_look(uuid) to authenticated;

revoke all on function public.commit_ai_look(uuid, text, uuid) from public;
revoke all on function public.commit_ai_look(uuid, text, uuid) from anon;
grant execute on function public.commit_ai_look(uuid, text, uuid)
  to authenticated;

revoke all on function public.release_ai_look(uuid, text) from public;
revoke all on function public.release_ai_look(uuid, text) from anon;
grant execute on function public.release_ai_look(uuid, text) to authenticated;

revoke all on function public.reconcile_stale_ai_look_reservations(interval)
  from public;
revoke all on function public.reconcile_stale_ai_look_reservations(interval)
  from anon;
revoke all on function public.reconcile_stale_ai_look_reservations(interval)
  from authenticated;
