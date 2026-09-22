-- FaceTune WA-12: abuse protection for the privileged admin surface.
--
-- Additive. One private counter table, one internal budget function, and the
-- four privileged writers plus the account search re-created with a single
-- added check. No business rule, transition, validation, idempotency, audit,
-- or response shape changes: each function body below is the deployed WA-5 /
-- WA-7 / WA-8 / WA-9 definition with exactly one block inserted after the
-- roster check.
--
-- ## Why here and not in the Edge Function
--
-- The writers are `security definer` RPCs an authenticated admin session can
-- call directly (the Edge Functions are the required front door for the Web
-- Admin, not the only reachable path). A limiter that lives only in the Edge
-- runtime would be bypassed by a compromised admin credential calling
-- PostgREST, and Edge isolates hold no shared state anyway. The budget is
-- therefore consumed inside the transaction, before the account lock, and a
-- refused attempt still counts — hammering the endpoint does not reset it.
--
-- ## Budget (Web Admin SOT §74)
--
--   mutation   30 privileged mutations per administrator per fixed UTC minute
--              (grant, adjust, extend, suspend/reactivate/revoke)
--   search     60 account lookups per administrator per fixed UTC minute
--
-- Both are generous for a human operator and tight for a script. Read
-- listings (users, entitlements, usage, audit, history) remain bounded by
-- their fixed 25-row pages and exact-match filters and are not counted.
--
-- ## Refusal
--
-- The Shared Contract (§71) defines no rate-limit code and WA-1 fixed the
-- vocabulary; adding one is a contract revision. A throttled request is
-- therefore answered with the contract's retryable TEMPORARY_BACKEND_FAILURE
-- plus `throttled: true`, which the Edge Function maps to 503 and the browser
-- shows as "try again". Nothing is written for a throttled request except
-- the counter itself.

create table public.admin_rate_limit_buckets (
  admin_user_id uuid not null references auth.users(id) on delete cascade,
  budget_class text not null,
  bucket_start timestamptz not null,
  hits integer not null default 0,
  primary key (admin_user_id, budget_class, bucket_start),
  constraint admin_rate_limit_buckets_class_valid
    check (budget_class in ('mutation', 'search')),
  constraint admin_rate_limit_buckets_hits_positive
    check (hits >= 0)
);

alter table public.admin_rate_limit_buckets enable row level security;
revoke all on table public.admin_rate_limit_buckets from public;
revoke all on table public.admin_rate_limit_buckets from anon;
revoke all on table public.admin_rate_limit_buckets from authenticated;
revoke all on table public.admin_rate_limit_buckets from service_role;

-- Consumes one unit of the administrator's budget for the current minute and
-- answers whether the request may proceed. Internal; not an endpoint. Expired
-- buckets are swept opportunistically so the table stays a few rows per
-- active administrator.
create or replace function public.admin_consume_budget(
  p_admin_user_id uuid,
  p_budget_class text
)
returns boolean
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_bucket timestamptz := date_trunc('minute', timezone('utc', now()));
  v_limit integer := case p_budget_class when 'mutation' then 30 when 'search' then 60 end;
  v_hits integer;
begin
  if p_admin_user_id is null or v_limit is null then
    return false;
  end if;

  delete from public.admin_rate_limit_buckets
   where admin_user_id = p_admin_user_id
     and bucket_start < v_now - interval '10 minutes';

  insert into public.admin_rate_limit_buckets (admin_user_id, budget_class, bucket_start, hits)
  values (p_admin_user_id, p_budget_class, v_bucket, 1)
  on conflict (admin_user_id, budget_class, bucket_start)
  do update set hits = public.admin_rate_limit_buckets.hits + 1
  returning hits into v_hits;

  return v_hits <= v_limit;
end;
$$;

revoke all on function public.admin_consume_budget(uuid, text) from public;
revoke all on function public.admin_consume_budget(uuid, text) from anon;
revoke all on function public.admin_consume_budget(uuid, text) from authenticated;
revoke all on function public.admin_consume_budget(uuid, text) from service_role;

-- ---------------------------------------------------------------------------
-- Privileged writers and account search, re-created with the budget check
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.admin_grant_salon_pilot(p_target_user_id uuid, p_expires_at timestamp with time zone, p_reason text, p_idempotency_key text, p_initial_allowance integer DEFAULT 30, p_request_correlation_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_reason text := btrim(p_reason);
  v_key text := btrim(p_idempotency_key);
  v_target auth.users%rowtype;
  v_prior public.admin_audit_events%rowtype;
  v_prior_ent public.user_entitlements%rowtype;
  v_blocking public.user_entitlements%rowtype;
  v_before jsonb;
  v_before_state jsonb;
  v_ent public.user_entitlements%rowtype;
  v_after_state jsonb;
  v_state jsonb;
  v_replayed boolean := false;
begin
  -- 1. Authorization: the session, checked against the roster. Nothing in
  --    the arguments can name the administrator.
  if v_caller is null then
    return public.admin_mutation_failure('grant_salon_pilot', 'AUTH_REQUIRED', false);
  end if;
  if not public.is_admin(v_caller) then
    return public.admin_mutation_failure('grant_salon_pilot', 'ADMIN_UNAUTHORIZED', false);
  end if;
  -- WA-12: per-administrator mutation budget (see 20261003000100).
  if not public.admin_consume_budget(v_caller, 'mutation') then
    return public.admin_mutation_failure('grant_salon_pilot', 'TEMPORARY_BACKEND_FAILURE', true)
      || jsonb_build_object('throttled', true);
  end if;

  -- 2. Request shape. These are client defects, not business outcomes, and
  --    are refused the way the WA-5/6 reads refuse a bad filter.
  if p_target_user_id is null then
    raise exception using errcode = '22023', message = 'targetUserId is required';
  end if;
  if p_expires_at is null then
    raise exception using errcode = '22023', message = 'expiresAt is required';
  end if;
  if v_reason is null or char_length(v_reason) < 1 or char_length(v_reason) > 500 then
    raise exception using errcode = '22023', message = 'reason is required (1-500 characters)';
  end if;
  if v_key is null or char_length(v_key) < 1 or char_length(v_key) > 128 then
    raise exception using errcode = '22023', message = 'idempotencyKey is required (1-128 characters)';
  end if;
  if p_initial_allowance is null or p_initial_allowance < 0 then
    raise exception using errcode = '22023', message = 'initialAllowance must be a non-negative integer';
  end if;

  -- 3. Target: an existing, non-anonymous FaceTune account (contract §46).
  select * into v_target
  from auth.users as u
  where u.id = p_target_user_id
    and u.deleted_at is null
    and u.is_anonymous = false;
  if not found then
    return public.admin_mutation_failure('grant_salon_pilot', 'USER_NOT_FOUND', false);
  end if;

  -- 4. Serialize with every other writer for this account (reservations,
  --    adjustments, a concurrent duplicate of this very request).
  perform pg_advisory_xact_lock(hashtextextended(v_target.id::text, 0));

  -- 5. Idempotency: the same intended action, already performed.
  select * into v_prior
  from public.admin_audit_events as a
  where a.target_user_id = v_target.id
    and a.action = 'grant_salon_pilot'
    and a.idempotency_key = v_key;
  if found then
    select * into v_prior_ent
    from public.user_entitlements as e
    where e.id = v_prior.target_entitlement_id;
    if not found
       or v_prior_ent.expires_at is distinct from p_expires_at
       or v_prior_ent.base_ai_look_allowance <> p_initial_allowance
       or v_prior.reason is distinct from v_reason
    then
      return public.admin_mutation_failure('grant_salon_pilot', 'IDEMPOTENCY_CONFLICT', false);
    end if;
    v_ent := v_prior_ent;
    v_replayed := true;
  else
    -- 6. Business validation against the account's current rows.
    if p_expires_at <= v_now then
      raise exception using errcode = '22023', message = 'expiresAt must be in the future';
    end if;

    -- A paid subscription in force is never superseded by an admin grant.
    select * into v_blocking
    from public.user_entitlements as e
    where e.user_id = v_target.id
      and e.plan_code <> 'free'
      and e.billing_provider in ('google_play', 'apple_app_store')
      and e.status in ('active', 'grace_period')
    limit 1;
    if found then
      return public.admin_mutation_failure('grant_salon_pilot', 'PROVIDER_STATE_CONFLICT', false);
    end if;

    -- A Salon Pilot still in force (including a paused one) is the grant.
    select * into v_blocking
    from public.user_entitlements as e
    where e.user_id = v_target.id
      and e.plan_code = 'salon_pilot'
      and e.status in ('active', 'grace_period', 'suspended')
      and (e.expires_at is null or e.expires_at > v_now)
    limit 1;
    if found then
      return public.admin_mutation_failure('grant_salon_pilot', 'SALON_PILOT_ALREADY_GRANTED', false);
    end if;

    -- Before-state: the governing entitlement as the resolver sees it now.
    v_before := public.admin_resolve_subscription_state_for_user(v_caller, v_target.id);
    v_before_state := case
      when coalesce((v_before->>'hasEntitlement')::boolean, false) then jsonb_build_object(
        'status', v_before->'entitlementStatus',
        'planCode', v_before->'planCode',
        'effectiveAllowance', v_before->'effectiveAllowance',
        'allowanceAdjustmentTotal', v_before->'allowanceAdjustmentTotal',
        'expiresAt', v_before->'expiresAt',
        'version', (
          select e.version from public.user_entitlements as e
          where e.id = (v_before->>'entitlementId')::uuid
        )
      )
      else null
    end;

    -- A lapsed pilot still stored active/grace: retire it, as the activation
    -- writer retires a superseded row, so the one-current slot is free. The
    -- resolver already reports such a row as expired; this makes the stored
    -- status agree. History and ledger rows are untouched.
    update public.user_entitlements as e
       set status = 'expired',
           version = e.version + 1
     where e.user_id = v_target.id
       and e.plan_code = 'salon_pilot'
       and e.status in ('active', 'grace_period')
       and e.expires_at is not null
       and e.expires_at <= v_now;

    -- 7. The grant, in the exact shape the SUB-12 row constraints require.
    insert into public.user_entitlements (
      user_id, plan_code, status, billing_provider,
      provider_product_id, provider_subscription_reference,
      period_start, period_end, starts_at, expires_at, auto_renew,
      base_ai_look_allowance, allowance_adjustment_total, verified_at
    ) values (
      v_target.id, 'salon_pilot', 'active', 'admin_granted',
      null, null,
      null, null, v_now, p_expires_at, false,
      p_initial_allowance, 0, null
    )
    returning * into v_ent;

    -- 8. Exactly one audit event, in the same transaction as the grant.
    v_after_state := jsonb_build_object(
      'status', v_ent.status,
      'planCode', v_ent.plan_code,
      'effectiveAllowance', greatest(0, v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total),
      'allowanceAdjustmentTotal', v_ent.allowance_adjustment_total,
      'expiresAt', v_ent.expires_at,
      'version', v_ent.version
    );
    insert into public.admin_audit_events (
      source, admin_user_id, action, target_user_id, target_entitlement_id,
      before_state, after_state, reason, request_correlation_id, idempotency_key
    ) values (
      'admin', v_caller, 'grant_salon_pilot', v_target.id, v_ent.id,
      v_before_state, v_after_state, v_reason, p_request_correlation_id, v_key
    );
  end if;

  -- 9. Authoritative new state, from the consumer resolver itself, so the
  --    figures the admin sees are the figures the app will see.
  v_state := public.admin_resolve_subscription_state_for_user(v_caller, v_target.id);
  if not v_replayed
     and (v_state->>'entitlementId')::uuid is distinct from v_ent.id then
    -- The pilot must now govern the account; anything else is a rule the
    -- checks above missed, and the transaction is abandoned rather than
    -- reported as success.
    raise exception 'granted Salon Pilot is not the governing entitlement';
  end if;

  return jsonb_build_object(
    'success', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'action', 'grant_salon_pilot',
    'replayed', v_replayed,
    'targetUserId', v_target.id,
    'entitlementId', v_ent.id,
    'planCode', v_state->>'planCode',
    'status', case
      when v_state->>'denialReason' in ('SALON_PILOT_EXPIRED', 'ENTITLEMENT_EXPIRED')
        and v_state->>'entitlementStatus' in ('active', 'grace_period')
        then 'expired'
      else v_state->>'entitlementStatus'
    end,
    'effectiveAllowance', (v_state->>'effectiveAllowance')::integer,
    'committedUsage', (v_state->>'committedUsage')::integer,
    'reservedUsage', (v_state->>'reservedUsage')::integer,
    'availableAiLooks', (v_state->>'availableAiLooks')::integer,
    'remainingAiLooks', (v_state->>'remainingAiLooks')::integer,
    'expiresAt', v_ent.expires_at,
    'version', (
      select e.version from public.user_entitlements as e where e.id = v_ent.id
    ),
    'updatedAt', (
      select e.updated_at from public.user_entitlements as e where e.id = v_ent.id
    )
  );
end;
$function$

;
CREATE OR REPLACE FUNCTION public.admin_adjust_salon_pilot_allowance(p_entitlement_id uuid, p_amount integer, p_reason text, p_idempotency_key text, p_expected_version integer DEFAULT NULL::integer, p_request_correlation_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_reason text := btrim(p_reason);
  v_key text := btrim(p_idempotency_key);
  v_action text;
  v_user_id uuid;
  v_ent public.user_entitlements%rowtype;
  v_prior public.entitlement_allowance_adjustments%rowtype;
  v_committed integer := 0;
  v_reserved integer := 0;
  v_effective_after integer;
  v_before_state jsonb;
  v_after_state jsonb;
  v_adjustment_id uuid;
  v_state jsonb;
  v_replayed boolean := false;
begin
  -- 1. Authorization from the session only.
  if v_caller is null then
    return public.admin_mutation_failure('increase_allowance', 'AUTH_REQUIRED', false);
  end if;
  if not public.is_admin(v_caller) then
    return public.admin_mutation_failure('increase_allowance', 'ADMIN_UNAUTHORIZED', false);
  end if;
  -- WA-12: per-administrator mutation budget (see 20261003000100).
  if not public.admin_consume_budget(v_caller, 'mutation') then
    return public.admin_mutation_failure('increase_allowance', 'TEMPORARY_BACKEND_FAILURE', true)
      || jsonb_build_object('throttled', true);
  end if;

  -- 2. Request shape (client defects).
  if p_entitlement_id is null then
    raise exception using errcode = '22023', message = 'entitlementId is required';
  end if;
  if p_amount is null or p_amount = 0 then
    raise exception using errcode = '22023', message = 'amount must be a non-zero integer';
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
  v_action := case when p_amount > 0 then 'increase_allowance' else 'decrease_allowance' end;

  -- 3. Locate the target and serialize with every other writer for its account.
  select e.user_id into v_user_id
  from public.user_entitlements as e
  where e.id = p_entitlement_id;
  if not found then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_NOT_FOUND', false);
  end if;
  perform pg_advisory_xact_lock(hashtextextended(v_user_id::text, 0));

  select * into v_ent
  from public.user_entitlements as e
  where e.id = p_entitlement_id
  for update;

  if v_ent.billing_provider <> 'admin_granted' or v_ent.plan_code <> 'salon_pilot' then
    return public.admin_mutation_failure(v_action, 'INVALID_ALLOWANCE_ADJUSTMENT', false);
  end if;
  if v_ent.status = 'revoked' then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_REVOKED', false);
  end if;
  if v_ent.status = 'expired'
     or (v_ent.expires_at is not null and v_ent.expires_at <= v_now) then
    return public.admin_mutation_failure(v_action, 'ENTITLEMENT_EXPIRED', false);
  end if;

  -- 4. Idempotency: the same intended adjustment, already applied.
  select * into v_prior
  from public.entitlement_allowance_adjustments as a
  where a.entitlement_id = v_ent.id
    and a.idempotency_key = v_key;
  if found then
    if v_prior.amount <> p_amount or v_prior.reason is distinct from v_reason then
      return public.admin_mutation_failure(v_action, 'IDEMPOTENCY_CONFLICT', false);
    end if;
    v_adjustment_id := v_prior.id;
    v_replayed := true;
  else
    -- 5. Stale-write protection.
    if p_expected_version is not null and p_expected_version <> v_ent.version then
      return public.admin_mutation_failure(v_action, 'CONCURRENT_MODIFICATION', false);
    end if;

    -- 6. Safe reduction, with the trigger's own predicate under the same lock,
    --    so the refusal carries the precise contract code. Every ledger row
    --    the entitlement owns counts (no period on an admin grant).
    select
      count(*) filter (where u.status = 'committed'),
      count(*) filter (where u.status = 'reserved')
    into v_committed, v_reserved
    from public.usage_ledger as u
    where u.entitlement_id = v_ent.id;

    v_effective_after :=
      v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total + p_amount;
    if v_effective_after < v_committed then
      return public.admin_mutation_failure(v_action, 'ALLOWANCE_BELOW_COMMITTED_USAGE', false);
    end if;
    if v_effective_after < v_committed + v_reserved then
      return public.admin_mutation_failure(
        v_action, 'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION', false);
    end if;

    v_before_state := jsonb_build_object(
      'status', v_ent.status,
      'planCode', v_ent.plan_code,
      'effectiveAllowance', greatest(0, v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total),
      'allowanceAdjustmentTotal', v_ent.allowance_adjustment_total,
      'expiresAt', v_ent.expires_at,
      'version', v_ent.version
    );

    -- 7. The one write that moves the allowance: the audited ledger row. Its
    --    BEFORE INSERT trigger re-checks the rule and updates the total and
    --    version; the CHECK constraints tie sign to type.
    insert into public.entitlement_allowance_adjustments (
      entitlement_id, target_user_id, admin_user_id, adjustment_type, amount,
      reason, idempotency_key
    ) values (
      v_ent.id, v_ent.user_id, v_caller, v_action, p_amount, v_reason, v_key
    )
    returning id into v_adjustment_id;

    select * into v_ent
    from public.user_entitlements as e
    where e.id = p_entitlement_id;

    -- 8. Exactly one audit event, in the same transaction.
    v_after_state := jsonb_build_object(
      'status', v_ent.status,
      'planCode', v_ent.plan_code,
      'effectiveAllowance', greatest(0, v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total),
      'allowanceAdjustmentTotal', v_ent.allowance_adjustment_total,
      'expiresAt', v_ent.expires_at,
      'version', v_ent.version
    );
    insert into public.admin_audit_events (
      source, admin_user_id, action, target_user_id, target_entitlement_id,
      before_state, after_state, reason, request_correlation_id, idempotency_key
    ) values (
      'admin', v_caller, v_action, v_ent.user_id, v_ent.id,
      v_before_state, v_after_state, v_reason, p_request_correlation_id, v_key
    );
  end if;

  -- 9. Authoritative state from the consumer resolver.
  v_state := public.admin_resolve_subscription_state_for_user(v_caller, v_ent.user_id);
  if (v_state->>'entitlementId')::uuid is distinct from v_ent.id then
    raise exception 'adjusted Salon Pilot is not the governing entitlement';
  end if;

  return jsonb_build_object(
    'success', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'action', v_action,
    'replayed', v_replayed,
    'targetUserId', v_ent.user_id,
    'entitlementId', v_ent.id,
    'adjustmentId', v_adjustment_id,
    'amount', p_amount,
    'planCode', v_state->>'planCode',
    'status', case
      when v_state->>'denialReason' in ('SALON_PILOT_EXPIRED', 'ENTITLEMENT_EXPIRED')
        and v_state->>'entitlementStatus' in ('active', 'grace_period')
        then 'expired'
      else v_state->>'entitlementStatus'
    end,
    'baseAllowance', (v_state->>'baseAllowance')::integer,
    'allowanceAdjustmentTotal', (v_state->>'allowanceAdjustmentTotal')::integer,
    'effectiveAllowance', (v_state->>'effectiveAllowance')::integer,
    'committedUsage', (v_state->>'committedUsage')::integer,
    'reservedUsage', (v_state->>'reservedUsage')::integer,
    'availableAiLooks', (v_state->>'availableAiLooks')::integer,
    'remainingAiLooks', (v_state->>'remainingAiLooks')::integer,
    'expiresAt', v_ent.expires_at,
    'version', (
      select e.version from public.user_entitlements as e where e.id = v_ent.id
    ),
    'updatedAt', (
      select e.updated_at from public.user_entitlements as e where e.id = v_ent.id
    )
  );
end;
$function$

;
CREATE OR REPLACE FUNCTION public.admin_extend_salon_pilot_expiration(p_entitlement_id uuid, p_new_expires_at timestamp with time zone, p_reason text, p_idempotency_key text, p_expected_version integer DEFAULT NULL::integer, p_request_correlation_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- WA-12: per-administrator mutation budget (see 20261003000100).
  if not public.admin_consume_budget(v_caller, 'mutation') then
    return public.admin_mutation_failure('extend_expiration', 'TEMPORARY_BACKEND_FAILURE', true)
      || jsonb_build_object('throttled', true);
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
$function$

;
CREATE OR REPLACE FUNCTION public.admin_set_salon_pilot_lifecycle(p_entitlement_id uuid, p_action text, p_reason text, p_idempotency_key text, p_expected_version integer DEFAULT NULL::integer, p_request_correlation_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
  -- WA-12: per-administrator mutation budget (see 20261003000100).
  if not public.admin_consume_budget(v_caller, 'mutation') then
    return public.admin_mutation_failure(v_action, 'TEMPORARY_BACKEND_FAILURE', true)
      || jsonb_build_object('throttled', true);
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
$function$

;
CREATE OR REPLACE FUNCTION public.admin_search_users(p_search text DEFAULT NULL::text, p_cursor text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_search text := nullif(lower(btrim(p_search)), '');
  v_search_uuid uuid := null;
  v_cursor_payload jsonb;
  v_cursor_created_at timestamptz := null;
  v_cursor_user_id uuid := null;
  v_items jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_next_cursor text := null;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;
  -- WA-12: per-administrator search budget (see 20261003000100).
  if not public.admin_consume_budget(v_caller, 'search') then
    return jsonb_build_object('ok', false, 'errorCode', 'TEMPORARY_BACKEND_FAILURE', 'throttled', true);
  end if;

  if v_search is not null and
     v_search ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  then
    v_search_uuid := v_search::uuid;
  end if;

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_user_id := (v_cursor_payload->>'userId')::uuid;
      if (v_cursor_payload->>'search') is distinct from v_search then
        raise exception using errcode = '22023', message = 'pagination cursor does not match search';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select
      u.id,
      u.email,
      u.is_anonymous,
      u.email_confirmed_at,
      u.phone_confirmed_at,
      u.banned_until,
      u.created_at,
      public.admin_resolve_subscription_state_for_user(v_caller, u.id) as state
    from auth.users as u
    where u.deleted_at is null
      and (
        v_search is null
        or (v_search_uuid is not null and u.id = v_search_uuid)
        or (v_search_uuid is null and u.email = v_search)
      )
      and (
        v_cursor_created_at is null
        or (u.created_at, u.id) < (v_cursor_created_at, v_cursor_user_id)
      )
    order by u.created_at desc, u.id desc
    limit 26
  ), page as materialized (
    select * from candidates
    order by created_at desc, id desc
    limit 25
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'userId', p.id,
          'email', p.email,
          'accountCreatedAt', p.created_at,
          'accountStatus', case
            when p.is_anonymous then 'anonymous'
            when p.banned_until is not null and p.banned_until > v_now then 'banned'
            when p.email_confirmed_at is null and p.phone_confirmed_at is null then 'unconfirmed'
            else 'active'
          end,
          'currentPlanCode', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'planCode'
            else null
          end,
          'currentPlanDisplayName', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'planDisplayName'
            else null
          end,
          'entitlementStatus', case
            when p.state->>'denialReason' in ('SALON_PILOT_EXPIRED', 'ENTITLEMENT_EXPIRED')
              and p.state->>'entitlementStatus' in ('active', 'grace_period')
              then 'expired'
            else p.state->>'entitlementStatus'
          end,
          'remainingAiLooks', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then (p.state->>'remainingAiLooks')::integer
            else null
          end,
          'allowanceUnit', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'allowanceUnit'
            else null
          end,
          'periodEnd', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->'periodEnd'
            else null
          end,
          'expiresAt', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->'expiresAt'
            else null
          end,
          'autoRenew', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then (p.state->>'autoRenew')::boolean
            else null
          end
        )
        order by p.created_at desc, p.id desc
      ),
      '[]'::jsonb
    ),
    (select count(*) from candidates)
  into v_items, v_count
  from page as p;

  if v_count > 25 then
    select encode(
      convert_to(
        jsonb_build_object(
          'createdAt', p.created_at,
          'userId', p.id,
          'search', v_search
        )::text,
        'utf8'
      ),
      'base64'
    )
    into v_next_cursor
    from (
      select u.id, u.created_at
      from auth.users as u
      where u.deleted_at is null
        and (
          v_search is null
          or (v_search_uuid is not null and u.id = v_search_uuid)
          or (v_search_uuid is null and u.email = v_search)
        )
        and (
          v_cursor_created_at is null
          or (u.created_at, u.id) < (v_cursor_created_at, v_cursor_user_id)
        )
      order by u.created_at desc, u.id desc
      offset 24 limit 1
    ) as p;
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'accountCreatedAt', 'direction', 'desc'),
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$function$

;
