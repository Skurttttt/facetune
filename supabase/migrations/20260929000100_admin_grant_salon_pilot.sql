-- FaceTune WA-7: the first privileged Web Admin mutation — grant Salon Pilot.
--
-- Additive. One audit table, one immutability trigger, one transactional
-- `security definer` writer. No existing table, column, constraint, policy,
-- grant, trigger, or function is altered. The consumer resolver, the usage
-- engine, the activation writer, and every Free / Salon Pilot guard from
-- SUB-12 are reused as they are.
--
-- ## Path (Shared Contract §58)
--
--     Web Admin ──JWT──▶ admin-grant-salon-pilot (Edge Function)
--                          requireAdmin(): auth.getUser + current_user_is_admin
--                          validate request shape
--                              │  AS THE CALLER (anon key + admin's own JWT)
--                              ▼
--                        public.admin_grant_salon_pilot(...)
--                          is_admin(auth.uid()) again — the function is its
--                          own gate, exactly like every WA-4/5/6 read
--                          per-account advisory lock
--                          validate target / expiration / allowance / reason
--                          idempotent replay or conflict on the key
--                          Subscription-rule conflict checks
--                          INSERT user_entitlements (salon_pilot, admin_granted)
--                          INSERT admin_audit_events (exactly one)
--                          RETURN the resolver's authoritative figures
--
-- No service-role key exists anywhere on this path. The browser sends intent
-- (target, expiration, allowance, reason, idempotency key); the server
-- resolves and validates every trusted fact.
--
-- ## Subscription rules applied (Shared Contract §32, §46; SUB-12)
--
--   plan_code            salon_pilot            billing_provider   admin_granted
--   auto_renew           false                  period             none
--   expires_at           required, in future    base allowance     integer >= 0, default 30
--                                               (no business maximum is defined by any authority)
--
--   * A Salon Pilot currently in force (active / grace_period / suspended and
--     not past its expiry) → SALON_PILOT_ALREADY_GRANTED. Suspension is a
--     pause, not an end; reactivation belongs to a later phase.
--   * A store-backed subscription that is active or in grace → the grant is
--     refused with PROVIDER_STATE_CONFLICT. `user_entitlements_one_current_idx`
--     allows one such row per account and only the provider lifecycle may
--     retire a paid one; an administrator never supersedes a subscription
--     the user is paying Google for.
--   * A Salon Pilot still stored active / grace_period whose expires_at has
--     passed is retired as `expired` (the same supersession the activation
--     writer performs, and the status the resolver already reports for it)
--     so the new grant can hold the one-current slot. Its ledger rows stay
--     attached to it: history is never rewritten.
--   * The lifetime Free row is never touched (SUB-12 guard trigger).
--   * A previously expired or revoked pilot is history; a re-grant is a new row.
--
-- ## Idempotency (Shared Contract §59)
--
-- `(target_user_id, action, idempotency_key)` is unique on the audit table.
-- A replay with the same key returns the original grant's authoritative
-- current state with `replayed = true` and creates nothing. The same key with
-- different intent (expiration, allowance, or reason) is IDEMPOTENCY_CONFLICT.
-- The advisory lock serializes two concurrent submissions so the second
-- always sees the first's rows.

-- ---------------------------------------------------------------------------
-- 1. Audit events
-- ---------------------------------------------------------------------------
--
-- The immutable trail behind every privileged admin mutation (Shared
-- Contract §63; WA-1 `AuditEvent`). Snapshots hold only the six
-- privacy-safe entitlement fields WA-1 fixed for the read model: status,
-- planCode, effectiveAllowance, allowanceAdjustmentTotal, expiresAt, version.
-- No image, prompt, provider, or token data can be placed here by the writer
-- below, and no client role can write here at all.
create table public.admin_audit_events (
  id uuid primary key default gen_random_uuid(),
  -- Where the event originated. Admin actions are the only writer today;
  -- `provider` and `system` are reserved by WA-1 for later ingestion.
  source text not null default 'admin',
  -- Required for an admin event at insert (trigger-enforced, as on
  -- `entitlement_allowance_adjustments`); the referential SET NULL that runs
  -- if that account is later deleted keeps the event.
  admin_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  target_entitlement_id uuid references public.user_entitlements(id) on delete set null,
  before_state jsonb,
  after_state jsonb,
  reason text,
  request_correlation_id uuid,
  idempotency_key text,
  created_at timestamptz not null default timezone('utc', now()),

  constraint admin_audit_events_source_valid
    check (source in ('admin', 'provider', 'system')),
  constraint admin_audit_events_action_valid
    check (
      action in (
        'grant_salon_pilot',
        'increase_allowance',
        'decrease_allowance',
        'extend_expiration',
        'suspend_entitlement',
        'reactivate_entitlement',
        'revoke_entitlement'
      )
    ),
  constraint admin_audit_events_reason_shape
    check (reason is null or char_length(btrim(reason)) between 1 and 500),
  constraint admin_audit_events_key_shape
    check (
      idempotency_key is null
      or char_length(btrim(idempotency_key)) between 1 and 128
    ),
  -- One event per intended business action. Scoped to the target so keys
  -- minted by different admin sessions cannot collide across accounts.
  constraint admin_audit_events_idempotency_unique
    unique (target_user_id, action, idempotency_key)
);

create index admin_audit_events_target_created_idx
  on public.admin_audit_events (target_user_id, created_at desc);
create index admin_audit_events_created_id_idx
  on public.admin_audit_events (created_at desc, id desc);

alter table public.admin_audit_events enable row level security;
-- No policy: RLS on with nothing granted means no client role reads or
-- writes a row. Reads arrive in a later phase through a roster-checked RPC.
revoke all on table public.admin_audit_events from public;
revoke all on table public.admin_audit_events from anon;
revoke all on table public.admin_audit_events from authenticated;
revoke all on table public.admin_audit_events from service_role;

-- Immutable: nothing but the referential SET NULL of a deleted
-- administrator or entitlement may change a row. No DELETE trigger, for the
-- reason given on `usage_ledger` in SUB-2 (it would abort the auth.users
-- cascade); deletion is prevented by privilege.
create or replace function public.reject_admin_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.source = 'admin' and new.admin_user_id is null then
      raise exception
        'an admin audit event must record the administrator who acted';
    end if;
    return new;
  end if;

  if new.id <> old.id
     or new.source <> old.source
     or new.action <> old.action
     or new.target_user_id <> old.target_user_id
     or new.before_state is distinct from old.before_state
     or new.after_state is distinct from old.after_state
     or new.reason is distinct from old.reason
     or new.request_correlation_id is distinct from old.request_correlation_id
     or new.idempotency_key is distinct from old.idempotency_key
     or new.created_at <> old.created_at
  then
    raise exception 'admin audit events are immutable';
  end if;
  if not (
    new.admin_user_id is not distinct from old.admin_user_id
    or (old.admin_user_id is not null and new.admin_user_id is null)
  ) then
    raise exception 'admin audit events are immutable';
  end if;
  if not (
    new.target_entitlement_id is not distinct from old.target_entitlement_id
    or (old.target_entitlement_id is not null and new.target_entitlement_id is null)
  ) then
    raise exception 'admin audit events are immutable';
  end if;
  return new;
end;
$$;

create trigger admin_audit_events_immutable
before insert or update on public.admin_audit_events
for each row execute function public.reject_admin_audit_mutation();

revoke all on function public.reject_admin_audit_mutation() from public;
revoke all on function public.reject_admin_audit_mutation() from anon;
revoke all on function public.reject_admin_audit_mutation() from authenticated;
revoke all on function public.reject_admin_audit_mutation() from service_role;


-- The one failure shape every admin mutation returns (Shared Contract §73;
-- WA-1 `AdminMutationFailure`). Internal helper; not an endpoint.
create or replace function public.admin_mutation_failure(
  p_action text,
  p_error_code text,
  p_retryable boolean
)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select jsonb_build_object(
    'success', false,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'action', p_action,
    'errorCode', p_error_code,
    'retryable', p_retryable
  );
$$;

-- ---------------------------------------------------------------------------
-- 2. The grant
-- ---------------------------------------------------------------------------
create or replace function public.admin_grant_salon_pilot(
  p_target_user_id uuid,
  p_expires_at timestamptz,
  p_reason text,
  p_idempotency_key text,
  p_initial_allowance integer default 30,
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
$$;

-- ---------------------------------------------------------------------------
-- 3. Access
-- ---------------------------------------------------------------------------
revoke all on function public.admin_mutation_failure(text, text, boolean) from public;
revoke all on function public.admin_mutation_failure(text, text, boolean) from anon;
revoke all on function public.admin_mutation_failure(text, text, boolean) from authenticated;
revoke all on function public.admin_mutation_failure(text, text, boolean) from service_role;

revoke all on function public.admin_grant_salon_pilot(uuid, timestamptz, text, text, integer, uuid) from public;
revoke all on function public.admin_grant_salon_pilot(uuid, timestamptz, text, text, integer, uuid) from anon;
revoke all on function public.admin_grant_salon_pilot(uuid, timestamptz, text, text, integer, uuid) from service_role;
grant execute on function public.admin_grant_salon_pilot(uuid, timestamptz, text, text, integer, uuid) to authenticated;
