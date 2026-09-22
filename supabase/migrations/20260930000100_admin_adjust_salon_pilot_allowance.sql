-- FaceTune WA-8: adjust a Salon Pilot allowance through the audited ledger.
--
-- Additive. One transactional `security definer` writer. No existing table,
-- column, constraint, policy, grant, trigger, or function is altered.
--
-- ## What already exists and is reused as-is (SUB-12, migration 20260920000100)
--
--   entitlement_allowance_adjustments      the audited ledger; one row per change
--   apply_entitlement_allowance_adjustment BEFORE INSERT trigger: per-account
--                                          advisory lock, row lock, refuses a
--                                          non-admin-granted target, refuses a
--                                          reduction below committed + reserved,
--                                          moves allowance_adjustment_total and
--                                          bumps version — the only path that can
--   guard_allowance_adjustment_total       refuses any other write to the total
--   unique (entitlement_id, idempotency_key)
--
-- This function therefore never writes `allowance_adjustment_total`, never
-- touches `usage_ledger`, and never computes a remaining balance of its own:
-- it validates intent, inserts one ledger row, writes one audit event, and
-- returns the consumer resolver's figures (Shared Contract §31, §33, §43,
-- §44, §73, §75).
--
-- ## Path (Shared Contract §58) — identical to WA-7
--
--     Web Admin ──JWT──▶ admin-adjust-salon-pilot-allowance (Edge Function)
--                          requireAdmin · validate request shape
--                              │  AS THE CALLER
--                              ▼
--                        public.admin_adjust_salon_pilot_allowance(...)
--                          is_admin(auth.uid()) · per-account advisory lock
--                          idempotent replay / conflict on the key
--                          optimistic concurrency on expected version
--                          precise refusal codes for an unsafe reduction
--                          INSERT entitlement_allowance_adjustments (trigger applies)
--                          INSERT admin_audit_events (exactly one)
--                          RETURN the resolver's authoritative figures
--
-- ## Rules
--
--   * Target must be an admin-granted Salon Pilot (INVALID_ALLOWANCE_ADJUSTMENT
--     otherwise) that has not ended: revoked → ENTITLEMENT_REVOKED; expired or
--     past its expiry → ENTITLEMENT_EXPIRED. A suspended pilot may be adjusted
--     (suspension is a pause; the adjustment does not reactivate it).
--   * amount is a non-zero integer; positive → increase_allowance, negative →
--     decrease_allowance (contract §43). No business maximum is defined.
--   * A reduction must leave effective allowance ≥ committed usage
--     (ALLOWANCE_BELOW_COMMITTED_USAGE) and ≥ committed + reserved
--     (ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION) — the trigger's own rule,
--     evaluated here first under the same lock so the refusal is typed.
--   * expectedVersion, when supplied, must equal the row's current version
--     (CONCURRENT_MODIFICATION otherwise) — Web Admin SOT §47 stale-write
--     protection, spelled with the contract's code.
--   * Idempotency: (entitlement_id, idempotency_key) is unique on the ledger.
--     A replay with the same amount and reason returns current state with
--     `replayed = true`; the same key with different intent is
--     IDEMPOTENCY_CONFLICT. Replays skip the version check.

create or replace function public.admin_adjust_salon_pilot_allowance(
  p_entitlement_id uuid,
  p_amount integer,
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
$$;

revoke all on function public.admin_adjust_salon_pilot_allowance(uuid, integer, text, text, integer, uuid) from public;
revoke all on function public.admin_adjust_salon_pilot_allowance(uuid, integer, text, text, integer, uuid) from anon;
revoke all on function public.admin_adjust_salon_pilot_allowance(uuid, integer, text, text, integer, uuid) from service_role;
grant execute on function public.admin_adjust_salon_pilot_allowance(uuid, integer, text, text, integer, uuid) to authenticated;
