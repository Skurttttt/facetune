-- FaceTune WA-9: Salon Pilot lifecycle — extend expiration, suspend,
-- reactivate, revoke.
--
-- Additive. Two transactional `security definer` writers on the WA-7/WA-8
-- template. No existing table, column, constraint, policy, grant, trigger,
-- or function is altered. No ledger row, preview, tutorial, history item,
-- saved look, or account is touched: a lifecycle change is a status or
-- expiry write on one `user_entitlements` row plus one audit event.
--
-- ## Provider boundary (Shared Contract §47–§51; Subscription authority)
--
-- The deployed provider writers (`activate_verified_google_play_subscription`,
-- RTDN reconciliation, revoke_google_play_entitlement) own the status of a
-- store-backed row: every verified provider event rewrites `status` from
-- Google's SubscriptionState, and `suspended` is itself Google's ON_HOLD /
-- PAUSED mapping. An administrative suspension of such a row would be
-- silently reverted by the next renewal, and an administrative reactivation
-- would contradict Google's truth. Both are therefore refused here with
-- PROVIDER_STATE_CONFLICT: in V1 every lifecycle action below targets an
-- admin-granted entitlement (`billing_provider = admin_granted`, which the
-- SUB-2 row shape ties to `salon_pilot`). The lifetime Free row is never a
-- target either (SUB-12 guard; INVALID_ENTITLEMENT_TRANSITION).
--
-- ## Transitions (Shared Contract §12–§18, §47–§50; Web Admin SOT §27–§31)
--
--   extend_expiration    active | grace_period | suspended  → same status,
--                        expires_at := new value, which must be in the future
--                        and later than the current expiry. A pilot whose
--                        stored status is still active but whose expiry has
--                        passed may be extended (this is the deliberate way to
--                        revive it); a row retired to `expired` or `revoked`
--                        cannot.
--   suspend_entitlement  active | grace_period → suspended; the pilot must not
--                        have lapsed (ENTITLEMENT_EXPIRED otherwise).
--   reactivate_entitlement  suspended → active, only while expires_at is in
--                        the future (contract §49: reactivation still respects
--                        expires_at; extend first if it lapsed).
--   revoke_entitlement   active | grace_period | suspended → revoked.
--                        Terminal. Revocation is not cancellation (§51).
--
-- Any other stored status for the requested action is
-- INVALID_ENTITLEMENT_TRANSITION, except that a `revoked` target always
-- answers ENTITLEMENT_REVOKED and an `expired` target ENTITLEMENT_EXPIRED.
--
-- ## What a suspension / revocation does and does not do
--
-- The consumer resolver (SUB-3/SUB-12) already refuses new generation for a
-- suspended (ENTITLEMENT_SUSPENDED) or revoked (ENTITLEMENT_REVOKED) row, so
-- no generation path is changed here. Nothing is deleted: ledger rows,
-- generated images, tutorials, history and saved looks are untouched and
-- remain readable under their own RLS. An AI Look that is reserved at the
-- moment of suspension completes or is released by the existing usage engine
-- rules; the admin action neither commits nor releases it.
--
-- ## Idempotency and concurrency
--
-- `(target_user_id, action, idempotency_key)` is unique on the audit table.
-- A replay with the same intent returns the current state with
-- `replayed = true`; the same key with different intent is
-- IDEMPOTENCY_CONFLICT. `expectedVersion`, when supplied, must match the row
-- (CONCURRENT_MODIFICATION). Every writer takes the per-account advisory lock
-- the usage engine and the adjustment ledger use.

-- ---------------------------------------------------------------------------
-- 1. Shared target resolution
-- ---------------------------------------------------------------------------
--
-- Locks the account, loads the row FOR UPDATE, and answers the refusals every
-- lifecycle action shares. Internal; not an endpoint.
create or replace function public.admin_lock_salon_pilot_target(
  p_entitlement_id uuid,
  p_action text,
  out o_failure jsonb,
  out o_ent public.user_entitlements
)
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_user_id uuid;
begin
  o_failure := null;
  select e.user_id into v_user_id
  from public.user_entitlements as e
  where e.id = p_entitlement_id;
  if not found then
    o_failure := public.admin_mutation_failure(p_action, 'ENTITLEMENT_NOT_FOUND', false);
    return;
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select * into o_ent
  from public.user_entitlements as e
  where e.id = p_entitlement_id
  for update;

  if o_ent.billing_provider in ('google_play', 'apple_app_store') then
    o_failure := public.admin_mutation_failure(p_action, 'PROVIDER_STATE_CONFLICT', false);
  elsif o_ent.billing_provider <> 'admin_granted' then
    o_failure := public.admin_mutation_failure(p_action, 'INVALID_ENTITLEMENT_TRANSITION', false);
  end if;
end;
$$;

-- The six privacy-safe snapshot fields WA-1 fixed (Shared Contract §63).
create or replace function public.admin_entitlement_snapshot(p_ent public.user_entitlements)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'status', p_ent.status,
    'planCode', p_ent.plan_code,
    'effectiveAllowance', greatest(0, p_ent.base_ai_look_allowance + p_ent.allowance_adjustment_total),
    'allowanceAdjustmentTotal', p_ent.allowance_adjustment_total,
    'expiresAt', p_ent.expires_at,
    'version', p_ent.version
  );
$$;

-- The contract §73 response, from the consumer resolver, for a target that
-- may or may not be governing (a revoked pilot no longer governs; the account
-- has fallen back to Free, and the admin is shown the target row's own
-- status with the resolver's figures for the account).
create or replace function public.admin_lifecycle_response(
  p_caller uuid,
  p_action text,
  p_replayed boolean,
  p_entitlement_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_ent public.user_entitlements%rowtype;
  v_state jsonb;
  v_governing boolean;
begin
  select * into v_ent from public.user_entitlements as e where e.id = p_entitlement_id;
  v_state := public.admin_resolve_subscription_state_for_user(p_caller, v_ent.user_id);
  v_governing := coalesce((v_state->>'entitlementId')::uuid = v_ent.id, false);
  return jsonb_build_object(
    'success', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'action', p_action,
    'replayed', p_replayed,
    'targetUserId', v_ent.user_id,
    'entitlementId', v_ent.id,
    'planCode', v_ent.plan_code,
    'status', v_ent.status,
    'governing', v_governing,
    'effectiveAllowance', greatest(0, v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total),
    'committedUsage', case when v_governing then (v_state->>'committedUsage')::integer else (
      select count(*)::integer from public.usage_ledger u
      where u.entitlement_id = v_ent.id and u.status = 'committed') end,
    'reservedUsage', case when v_governing then (v_state->>'reservedUsage')::integer else (
      select count(*)::integer from public.usage_ledger u
      where u.entitlement_id = v_ent.id and u.status = 'reserved') end,
    'availableAiLooks', case when v_governing then (v_state->>'availableAiLooks')::integer else 0 end,
    'remainingAiLooks', case when v_governing then (v_state->>'remainingAiLooks')::integer else 0 end,
    'generationAuthorized', v_governing and coalesce((v_state->>'generationAuthorized')::boolean, false),
    'denialReason', case
      when v_governing then v_state->'denialReason'
      when v_ent.status = 'revoked' then to_jsonb('ENTITLEMENT_REVOKED'::text)
      when v_ent.status = 'suspended' then to_jsonb('ENTITLEMENT_SUSPENDED'::text)
      when v_ent.expires_at is not null and v_ent.expires_at <= timezone('utc', now())
        then to_jsonb('SALON_PILOT_EXPIRED'::text)
      else to_jsonb('ENTITLEMENT_INACTIVE'::text)
    end,
    'expiresAt', v_ent.expires_at,
    'version', v_ent.version,
    'updatedAt', v_ent.updated_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Extend expiration
-- ---------------------------------------------------------------------------
create or replace function public.admin_extend_salon_pilot_expiration(
  p_entitlement_id uuid,
  p_new_expires_at timestamptz,
  p_reason text,
  p_idempotency_key text,
  p_expected_version integer default null,
  p_request_correlation_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_reason text := btrim(p_reason);
  v_key text := btrim(p_idempotency_key);
  v_lock record;
  v_failure jsonb;
  v_ent public.user_entitlements%rowtype;
  v_prior public.admin_audit_events%rowtype;
  v_before jsonb;
begin
  if v_caller is null then
    return public.admin_mutation_failure('extend_expiration', 'AUTH_REQUIRED', false);
  end if;
  if not public.is_admin(v_caller) then
    return public.admin_mutation_failure('extend_expiration', 'ADMIN_UNAUTHORIZED', false);
  end if;
  if p_entitlement_id is null then
    raise exception using errcode = '22023', message = 'entitlementId is required';
  end if;
  if p_new_expires_at is null then
    raise exception using errcode = '22023', message = 'newExpiresAt is required';
  end if;
  if v_reason is null or char_length(v_reason) < 1 or char_length(v_reason) > 500 then
    raise exception using errcode = '22023', message = 'reason is required (1-500 characters)';
  end if;
  if v_key is null or char_length(v_key) < 1 or char_length(v_key) > 128 then
    raise exception using errcode = '22023', message = 'idempotencyKey is required (1-128 characters)';
  end if;
  if p_expected_version is not null and p_expected_version < 1 then
    raise exception using errcode = '22023', message = 'expectedVersion must be a positive integer';
  end if;

  select * into v_lock
  from public.admin_lock_salon_pilot_target(p_entitlement_id, 'extend_expiration');
  v_failure := v_lock.o_failure;
  v_ent := v_lock.o_ent;
  if v_failure is not null then
    return v_failure;
  end if;

  -- Replay?
  select * into v_prior
  from public.admin_audit_events as a
  where a.target_user_id = v_ent.user_id
    and a.action = 'extend_expiration'
    and a.idempotency_key = v_key;
  if found then
    if v_prior.target_entitlement_id is distinct from v_ent.id
       or (v_prior.after_state->>'expiresAt')::timestamptz is distinct from p_new_expires_at
       or v_prior.reason is distinct from v_reason then
      return public.admin_mutation_failure('extend_expiration', 'IDEMPOTENCY_CONFLICT', false);
    end if;
    return public.admin_lifecycle_response(v_caller, 'extend_expiration', true, v_ent.id);
  end if;

  if v_ent.status = 'revoked' then
    return public.admin_mutation_failure('extend_expiration', 'ENTITLEMENT_REVOKED', false);
  end if;
  if v_ent.status = 'expired' then
    return public.admin_mutation_failure('extend_expiration', 'ENTITLEMENT_EXPIRED', false);
  end if;
  if v_ent.status not in ('active', 'grace_period', 'suspended') then
    return public.admin_mutation_failure('extend_expiration', 'INVALID_ENTITLEMENT_TRANSITION', false);
  end if;
  if p_expected_version is not null and p_expected_version <> v_ent.version then
    return public.admin_mutation_failure('extend_expiration', 'CONCURRENT_MODIFICATION', false);
  end if;
  -- The new date must be a real extension: in the future and later than the
  -- current expiry. Anything else is a client defect, not a business outcome.
  if p_new_expires_at <= v_now then
    raise exception using errcode = '22023', message = 'newExpiresAt must be in the future';
  end if;
  if v_ent.expires_at is not null and p_new_expires_at <= v_ent.expires_at then
    raise exception using errcode = '22023', message = 'newExpiresAt must be later than the current expiration';
  end if;

  v_before := public.admin_entitlement_snapshot(v_ent);
  update public.user_entitlements as e
     set expires_at = p_new_expires_at,
         version = e.version + 1
   where e.id = v_ent.id
  returning * into v_ent;

  insert into public.admin_audit_events (
    source, admin_user_id, action, target_user_id, target_entitlement_id,
    before_state, after_state, reason, request_correlation_id, idempotency_key
  ) values (
    'admin', v_caller, 'extend_expiration', v_ent.user_id, v_ent.id,
    v_before, public.admin_entitlement_snapshot(v_ent), v_reason,
    p_request_correlation_id, v_key
  );

  return public.admin_lifecycle_response(v_caller, 'extend_expiration', false, v_ent.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Suspend / reactivate / revoke
-- ---------------------------------------------------------------------------
create or replace function public.admin_set_salon_pilot_lifecycle(
  p_entitlement_id uuid,
  p_action text,
  p_reason text,
  p_idempotency_key text,
  p_expected_version integer default null,
  p_request_correlation_id uuid default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_action text := btrim(p_action);
  v_reason text := btrim(p_reason);
  v_key text := btrim(p_idempotency_key);
  v_lock record;
  v_failure jsonb;
  v_ent public.user_entitlements%rowtype;
  v_prior public.admin_audit_events%rowtype;
  v_before jsonb;
  v_new_status text;
begin
  if v_action is null or v_action not in (
    'suspend_entitlement', 'reactivate_entitlement', 'revoke_entitlement'
  ) then
    raise exception using errcode = '22023', message = 'action must be suspend_entitlement, reactivate_entitlement, or revoke_entitlement';
  end if;
  if v_caller is null then
    return public.admin_mutation_failure(v_action, 'AUTH_REQUIRED', false);
  end if;
  if not public.is_admin(v_caller) then
    return public.admin_mutation_failure(v_action, 'ADMIN_UNAUTHORIZED', false);
  end if;
  if p_entitlement_id is null then
    raise exception using errcode = '22023', message = 'entitlementId is required';
  end if;
  if v_reason is null or char_length(v_reason) < 1 or char_length(v_reason) > 500 then
    raise exception using errcode = '22023', message = 'reason is required (1-500 characters)';
  end if;
  if v_key is null or char_length(v_key) < 1 or char_length(v_key) > 128 then
    raise exception using errcode = '22023', message = 'idempotencyKey is required (1-128 characters)';
  end if;
  if p_expected_version is not null and p_expected_version < 1 then
    raise exception using errcode = '22023', message = 'expectedVersion must be a positive integer';
  end if;

  select * into v_lock
  from public.admin_lock_salon_pilot_target(p_entitlement_id, v_action);
  v_failure := v_lock.o_failure;
  v_ent := v_lock.o_ent;
  if v_failure is not null then
    return v_failure;
  end if;

  -- Replay?
  select * into v_prior
  from public.admin_audit_events as a
  where a.target_user_id = v_ent.user_id
    and a.action = v_action
    and a.idempotency_key = v_key;
  if found then
    if v_prior.target_entitlement_id is distinct from v_ent.id
       or v_prior.reason is distinct from v_reason then
      return public.admin_mutation_failure(v_action, 'IDEMPOTENCY_CONFLICT', false);
    end if;
    return public.admin_lifecycle_response(v_caller, v_action, true, v_ent.id);
  end if;

  -- Terminal and ended rows first, so the answer names the real reason.
  if v_ent.status = 'revoked' then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_REVOKED', false);
  end if;
  if v_ent.status = 'expired' then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_EXPIRED', false);
  end if;

  v_new_status := case v_action
    when 'suspend_entitlement' then
      case when v_ent.status in ('active', 'grace_period') then 'suspended' end
    when 'reactivate_entitlement' then
      case when v_ent.status = 'suspended' then 'active' end
    when 'revoke_entitlement' then
      case when v_ent.status in ('active', 'grace_period', 'suspended') then 'revoked' end
  end;
  if v_new_status is null then
    return public.admin_mutation_failure(v_action, 'INVALID_ENTITLEMENT_TRANSITION', false);
  end if;

  -- A lapsed pilot cannot be suspended or reactivated: it has no access to
  -- pause or restore. Extend it first. Revocation of a lapsed pilot is
  -- allowed: it makes the end explicit and terminal.
  if v_action in ('suspend_entitlement', 'reactivate_entitlement')
     and v_ent.expires_at is not null and v_ent.expires_at <= v_now then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_EXPIRED', false);
  end if;

  if p_expected_version is not null and p_expected_version <> v_ent.version then
    return public.admin_mutation_failure(v_action, 'CONCURRENT_MODIFICATION', false);
  end if;

  v_before := public.admin_entitlement_snapshot(v_ent);
  update public.user_entitlements as e
     set status = v_new_status,
         auto_renew = false,
         version = e.version + 1
   where e.id = v_ent.id
  returning * into v_ent;

  insert into public.admin_audit_events (
    source, admin_user_id, action, target_user_id, target_entitlement_id,
    before_state, after_state, reason, request_correlation_id, idempotency_key
  ) values (
    'admin', v_caller, v_action, v_ent.user_id, v_ent.id,
    v_before, public.admin_entitlement_snapshot(v_ent), v_reason,
    p_request_correlation_id, v_key
  );

  return public.admin_lifecycle_response(v_caller, v_action, false, v_ent.id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Access
-- ---------------------------------------------------------------------------
revoke all on function public.admin_lock_salon_pilot_target(uuid, text) from public;
revoke all on function public.admin_lock_salon_pilot_target(uuid, text) from anon;
revoke all on function public.admin_lock_salon_pilot_target(uuid, text) from authenticated;
revoke all on function public.admin_lock_salon_pilot_target(uuid, text) from service_role;

revoke all on function public.admin_entitlement_snapshot(public.user_entitlements) from public;
revoke all on function public.admin_entitlement_snapshot(public.user_entitlements) from anon;
revoke all on function public.admin_entitlement_snapshot(public.user_entitlements) from authenticated;
revoke all on function public.admin_entitlement_snapshot(public.user_entitlements) from service_role;

revoke all on function public.admin_lifecycle_response(uuid, text, boolean, uuid) from public;
revoke all on function public.admin_lifecycle_response(uuid, text, boolean, uuid) from anon;
revoke all on function public.admin_lifecycle_response(uuid, text, boolean, uuid) from authenticated;
revoke all on function public.admin_lifecycle_response(uuid, text, boolean, uuid) from service_role;

revoke all on function public.admin_extend_salon_pilot_expiration(uuid, timestamptz, text, text, integer, uuid) from public;
revoke all on function public.admin_extend_salon_pilot_expiration(uuid, timestamptz, text, text, integer, uuid) from anon;
revoke all on function public.admin_extend_salon_pilot_expiration(uuid, timestamptz, text, text, integer, uuid) from service_role;
grant execute on function public.admin_extend_salon_pilot_expiration(uuid, timestamptz, text, text, integer, uuid) to authenticated;

revoke all on function public.admin_set_salon_pilot_lifecycle(uuid, text, text, text, integer, uuid) from public;
revoke all on function public.admin_set_salon_pilot_lifecycle(uuid, text, text, text, integer, uuid) from anon;
revoke all on function public.admin_set_salon_pilot_lifecycle(uuid, text, text, text, integer, uuid) from service_role;
grant execute on function public.admin_set_salon_pilot_lifecycle(uuid, text, text, text, integer, uuid) to authenticated;
