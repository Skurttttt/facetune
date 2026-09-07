-- FaceTune SUB-3: server-authoritative entitlement resolution and allowance
-- calculation.
--
-- Purely additive. No existing table, column, constraint, policy, grant, or
-- trigger is altered or dropped, and nothing from SUB-2 is changed.
--
-- This migration adds exactly one read-only function. It answers, for the
-- authenticated caller and nobody else:
--
--     "What am I entitled to, how much capacity is left, and may I start a new
--      Final Makeup Preview right now?"
--
-- Deliberately NOT created here:
--
--   * Any reservation, commit, or release. This function performs no write of
--     any kind. The usage lifecycle engine is SUB-4.
--
--   * Any Free entitlement provisioning. When an account has no entitlement
--     row this function reports that honestly and refuses generation; it does
--     not conjure one. Free initialization is SUB-12. Synthesizing a
--     entitlement here would also be unusable downstream, because
--     `usage_ledger.entitlement_id` is NOT NULL and foreign-keyed — a
--     reservation cannot anchor to an entitlement that was never persisted.
--
--   * Any provider verification. The function reads verified state that
--     already exists; it never contacts a provider and never promotes an
--     entitlement on its own.
--
--   * Any stored remaining balance. Capacity is computed here on every call
--     from the ledger, so there is no second source of truth to drift.

-- ---------------------------------------------------------------------------
-- public.resolve_subscription_state()
-- ---------------------------------------------------------------------------
--
-- Takes no arguments. This is the point: the account is derived from the
-- request JWT inside the function, so there is no user parameter for a caller
-- to change. Cross-user resolution is not "blocked" by a policy that could be
-- misconfigured — it is unrepresentable, because the API offers no way to ask
-- about anybody else.
--
-- `security definer` follows `public.consume_ai_quota` (20260812000100): the
-- authority lives inside the function body rather than in its arguments, so a
-- caller invoking the RPC directly can only resolve their own state and cannot
-- influence the arithmetic. `set search_path = ''` prevents object-resolution
-- hijacking, and every reference below is schema-qualified.
--
-- Time comes from the database (`timezone('utc', now())`), never from a
-- caller-supplied timestamp, so a wrong or hostile device clock cannot extend a
-- billing period or revive an expired grant.
create or replace function public.resolve_subscription_state()
returns jsonb
language plpgsql
security definer
stable
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_ent public.user_entitlements%rowtype;
  v_display_name text;
  v_reset_policy text;
  v_effective integer;
  v_committed integer := 0;
  v_reserved integer := 0;
  v_available integer := 0;
  v_remaining integer := 0;
  v_reason text := null;
  v_authorized boolean := false;
begin
  if v_user is null then
    return jsonb_build_object(
      'hasEntitlement', false,
      'generationAuthorized', false,
      'denialReason', 'AUTH_REQUIRED',
      'resolvedAt', v_now
    );
  end if;

  -- Pick the one entitlement that currently governs this account.
  --
  -- At most one row can be active or in grace at a time
  -- (`user_entitlements_one_current_idx`), so the ordering below only decides
  -- which *inactive* row explains a refusal when there is no live entitlement.
  -- A suspended entitlement outranks an expired one because "your access was
  -- suspended" is the more accurate and more actionable message.
  select * into v_ent
  from public.user_entitlements as e
  where e.user_id = v_user
  order by
    case e.status
      when 'active' then 0
      when 'grace_period' then 1
      when 'suspended' then 2
      when 'pending' then 3
      when 'expired' then 4
      when 'revoked' then 5
      else 6
    end,
    e.starts_at desc,
    e.created_at desc
  limit 1;

  if not found then
    -- No entitlement has been provisioned for this account yet. Free is the
    -- default *plan*, but a plan is not a grant: without a persisted row there
    -- is nothing to charge usage against, so generation is refused rather than
    -- silently allowed against an imaginary allowance.
    select p.display_name, p.base_ai_look_allowance, p.reset_policy
      into v_display_name, v_effective, v_reset_policy
    from public.subscription_products as p
    where p.plan_code = 'free';

    return jsonb_build_object(
      'hasEntitlement', false,
      'planCode', 'free',
      'planDisplayName', v_display_name,
      'entitlementStatus', null,
      'billingProvider', 'none',
      'resetPolicy', v_reset_policy,
      'baseAllowance', coalesce(v_effective, 0),
      'effectiveAllowance', 0,
      'committedUsage', 0,
      'reservedUsage', 0,
      'availableAiLooks', 0,
      'remainingAiLooks', 0,
      'generationAuthorized', false,
      'denialReason', 'ENTITLEMENT_NOT_FOUND',
      'resolvedAt', v_now
    );
  end if;

  select p.display_name, p.reset_policy
    into v_display_name, v_reset_policy
  from public.subscription_products as p
  where p.plan_code = v_ent.plan_code;

  -- Effective allowance = base + authorized adjustments, floored at zero.
  -- Mirrors the shared contract and the SUB-1 domain exactly. Never stored.
  v_effective := greatest(
    0,
    v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total
  );

  -- Usage is counted against the *current* period only.
  --
  -- A new verified period therefore starts from zero without deleting or
  -- rewriting a single historical row: the prior period stays intact and
  -- auditable, and nothing rolls over. One-time and admin-granted entitlements
  -- have no period, so every row they own counts for their whole life.
  --
  -- Membership is decided by *when the work happened* (`reserved_at`), not by
  -- comparing the row's stamped `period_start` to the entitlement's. Those are
  -- two independently written timestamps, and equality between them is far
  -- more fragile than it looks: during development a 2.7 ms gap between two
  -- `now()` calls was enough to detach every usage row from its own
  -- entitlement, which silently reported a full, unused allowance. That is the
  -- worst shape a billing bug can take — it fails in the user's favour, costs
  -- real provider spend, and nobody reports it.
  --
  -- `reserved_at` cannot drift, because it records a real event rather than a
  -- copied value: work reserved at or after the current period began belongs
  -- to it, and work reserved before it does not. The stamped
  -- `period_start`/`period_end` columns remain the audit record of which period
  -- a row belongs to; they are simply not what capacity hinges on.
  select
    count(*) filter (where u.status = 'committed'),
    count(*) filter (where u.status = 'reserved')
  into v_committed, v_reserved
  from public.usage_ledger as u
  where u.entitlement_id = v_ent.id
    and u.user_id = v_user
    and (
      v_ent.period_start is null
      or u.reserved_at >= v_ent.period_start
    );

  -- Canonical capacity rule. Active reservations reduce what is available now,
  -- which is what stops two concurrent requests from spending the same last AI
  -- Look. Floored at zero: negative capacity is prohibited outright.
  v_available := greatest(0, v_effective - v_committed - v_reserved);

  -- The user-facing "N of M remaining" figure ignores in-flight reservations,
  -- because an in-progress generation has not been consumed yet and may still
  -- be released.
  v_remaining := greatest(0, v_effective - v_committed);

  -- Authorization, most specific refusal first.
  if v_ent.status = 'revoked' then
    v_reason := 'ENTITLEMENT_REVOKED';
  elsif v_ent.status = 'suspended' then
    v_reason := 'ENTITLEMENT_SUSPENDED';
  elsif v_ent.status = 'expired' then
    v_reason := 'ENTITLEMENT_EXPIRED';
  elsif v_ent.status = 'pending' then
    v_reason := 'ENTITLEMENT_PENDING';
  elsif v_ent.starts_at > v_now then
    -- Granted, but not yet in force.
    v_reason := 'ENTITLEMENT_PENDING';
  elsif v_ent.expires_at is not null and v_ent.expires_at <= v_now then
    -- The stored end date has passed but no lifecycle job has moved the status
    -- yet. Refuse on the authoritative persisted date rather than waiting for
    -- a background sweep to catch up. This reads a date the server was given;
    -- it does not invent one.
    v_reason := case
      when v_ent.plan_code = 'salon_pilot' then 'SALON_PILOT_EXPIRED'
      else 'ENTITLEMENT_EXPIRED'
    end;
  elsif v_ent.period_end is not null and v_ent.period_end <= v_now then
    -- Same reasoning for a verified billing period that has lapsed without a
    -- processed renewal.
    v_reason := 'ENTITLEMENT_EXPIRED';
  elsif v_ent.status not in ('active', 'grace_period') then
    v_reason := 'ENTITLEMENT_INACTIVE';
  elsif v_available <= 0 then
    v_reason := 'AI_LOOK_LIMIT_REACHED';
  else
    v_authorized := true;
  end if;

  return jsonb_build_object(
    'hasEntitlement', true,
    'entitlementId', v_ent.id,
    'planCode', v_ent.plan_code,
    'planDisplayName', v_display_name,
    'entitlementStatus', v_ent.status,
    'billingProvider', v_ent.billing_provider,
    'providerProductId', v_ent.provider_product_id,
    'periodStart', v_ent.period_start,
    'periodEnd', v_ent.period_end,
    'startsAt', v_ent.starts_at,
    'expiresAt', v_ent.expires_at,
    'autoRenew', v_ent.auto_renew,
    'resetPolicy', v_reset_policy,
    -- One field answers "when does this change?": the next verified renewal
    -- for a recurring plan, the grant's end for an admin term, null for the
    -- one-time Free look that never replenishes.
    'resetAt', case
      when v_reset_policy = 'billing_period' then v_ent.period_end
      else null
    end,
    'baseAllowance', v_ent.base_ai_look_allowance,
    'allowanceAdjustmentTotal', v_ent.allowance_adjustment_total,
    'effectiveAllowance', v_effective,
    'committedUsage', v_committed,
    'reservedUsage', v_reserved,
    'availableAiLooks', v_available,
    'remainingAiLooks', v_remaining,
    'generationAuthorized', v_authorized,
    'denialReason', v_reason,
    'verifiedAt', v_ent.verified_at,
    'resolvedAt', v_now
  );
end;
$$;

-- The response deliberately omits `provider_subscription_reference` and the
-- concurrency `version`. The former is support data held under least privilege
-- and is already withheld from clients by the column-level grant in SUB-2; the
-- latter is an internal write-path concern with no meaning to a reader.

revoke all on function public.resolve_subscription_state() from public;
revoke all on function public.resolve_subscription_state() from anon;
grant execute on function public.resolve_subscription_state() to authenticated;
