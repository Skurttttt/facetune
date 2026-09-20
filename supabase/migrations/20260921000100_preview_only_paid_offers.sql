-- FaceTune SUB-12B: capability-aware paid offers — the three Preview-only
-- plans, and the capability model that makes Tutorial authorization a fact of
-- the plan rather than a branch on its name.
--
-- Additive except where stated. What is redefined, and why, at the point of
-- redefinition:
--
--   * four CHECK constraints from SUB-2 and SUB-10 that enumerated the V1
--     plan codes — widened to the eight codes the Expansion SOT locks;
--   * `public.resolve_subscription_state()` (SUB-3, SUB-12) — reports the
--     governing plan's capabilities. Precedence, arithmetic, refusal order and
--     every existing field are unchanged.
--   * `public.reserve_ai_look(uuid)` (SUB-4) — stamps the governing plan and
--     allowance unit onto the reservation row. Everything else in it is
--     byte-for-byte what SUB-4 wrote.
--
-- Deliberately NOT done here:
--
--   * No change to `activate_verified_google_play_subscription` (SUB-10/12).
--     It already resolves a plan from a verified provider product id against
--     `subscription_products`, so a Preview purchase activates through the
--     same path, the same period derivation, the same retire rule, the same
--     idempotency, and the same `service_role`-only grant. There is no second
--     lifecycle.
--   * No change to reserve / commit / release (SUB-4). One Final Preview
--     Credit and one AI Look are both "authorization for one new usable
--     persisted Final Makeup Preview"; the ledger records the preview it
--     produced, and the *unit* is a property of the entitlement's plan. The
--     ledger row is never mislabelled because it carries no label.
--   * No second Final Preview pipeline, model, prompt, or validator. Nothing
--     in this file is reachable from a generation path except through the
--     resolver those paths already call.
--   * No purchased-credit ledger, no top-up, no admin UI, no Tutorial V4
--     change. The Tutorial authorization function below is a gate in front
--     of the existing V4 functions; it does not touch how a tutorial is made.
--
-- ---------------------------------------------------------------------------
-- The capability model
-- ---------------------------------------------------------------------------
--
-- Three columns on `subscription_products`, the table the entitlement engine
-- already reads for a plan's allowance and reset policy:
--
--     allowance_unit         what one unit of allowance is
--                              'ai_look'               Tutorial-capable
--                              'final_preview_credit'  Preview-only
--     tutorial_enabled       may the plan generate NEW Tutorials
--     final_preview_enabled  may the plan generate new Final Previews
--
-- Capability lives on the product row and nowhere else. A resolver reads it,
-- an authorization function reads it, and a client is told it. No function
-- and no client decides Tutorial access by comparing a plan code to a string,
-- so adding a ninth plan is a row, not a search for every `if plan == …`.
--
-- The locked matrix (Expansion SOT §3, §12, §13):
--
--     free            1  ai_look               tutorial  (preserved V1 Free)
--     plus            3  ai_look               tutorial
--     plus_preview   30  final_preview_credit  no tutorial
--     pro             8  ai_look               tutorial
--     pro_preview    80  final_preview_credit  no tutorial
--     salon_pro      35  ai_look               tutorial
--     salon_preview 350  final_preview_credit  no tutorial
--     salon_pilot    30  ai_look               tutorial  (admin-granted)
--
-- A Final Preview Credit can never authorize a Tutorial: that is a CHECK on
-- the product table, not a convention.

-- ---------------------------------------------------------------------------
-- 1. Plan codes: five → eight
-- ---------------------------------------------------------------------------
--
-- The V1 constraints enumerated the plan codes that existed. They are
-- rewritten with the eight canonical codes. Nothing else about the four
-- constraints changes; in particular the store-only rule for paid plans and
-- the purchasable-only rule for verification rows keep their shape, with the
-- Preview codes added to the same lists as their Tutorial-enabled siblings.
alter table public.subscription_products
  drop constraint if exists subscription_products_plan_code_valid,
  add constraint subscription_products_plan_code_valid
    check (
      plan_code in (
        'free',
        'plus',
        'plus_preview',
        'pro',
        'pro_preview',
        'salon_pro',
        'salon_preview',
        'salon_pilot'
      )
    );

alter table public.user_entitlements
  drop constraint if exists user_entitlements_plan_code_valid,
  add constraint user_entitlements_plan_code_valid
    check (
      plan_code in (
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
  drop constraint if exists user_entitlements_paid_plan_shape,
  -- Paid recurring plans are store-backed. `apple_app_store` remains the
  -- reserved compatibility code only.
  add constraint user_entitlements_paid_plan_shape
    check (
      plan_code not in (
        'plus',
        'plus_preview',
        'pro',
        'pro_preview',
        'salon_pro',
        'salon_preview'
      )
      or billing_provider in ('google_play', 'apple_app_store')
    );

alter table public.provider_purchase_verifications
  drop constraint if exists provider_purchase_verifications_plan_purchasable,
  -- Only the publicly purchasable plans can ever be recorded as verified
  -- purchases. Free and Salon Pilot stay unrepresentable here.
  add constraint provider_purchase_verifications_plan_purchasable
    check (
      plan_code in (
        'plus',
        'plus_preview',
        'pro',
        'pro_preview',
        'salon_pro',
        'salon_preview'
      )
    );

-- ---------------------------------------------------------------------------
-- 2. Capability columns
-- ---------------------------------------------------------------------------
--
-- Added with defaults that describe every existing row correctly — all five
-- V1 plans are AI Look plans with Tutorial — so the backfill is the default.
-- The defaults are then dropped: a future product row must state its
-- capability explicitly. A plan that forgot to say whether it includes the
-- Tutorial must fail to insert, not quietly include it.
alter table public.subscription_products
  add column if not exists allowance_unit text not null default 'ai_look',
  add column if not exists tutorial_enabled boolean not null default true,
  add column if not exists final_preview_enabled boolean not null default true;

alter table public.subscription_products
  alter column allowance_unit drop default,
  alter column tutorial_enabled drop default,
  alter column final_preview_enabled drop default;

alter table public.subscription_products
  drop constraint if exists subscription_products_allowance_unit_valid,
  add constraint subscription_products_allowance_unit_valid
    check (allowance_unit in ('ai_look', 'final_preview_credit')),
  -- The distinction that defines the Preview-only family. A Final Preview
  -- Credit authorizes a Final Preview and nothing more, whatever else a row
  -- says about itself.
  drop constraint if exists subscription_products_preview_credit_no_tutorial,
  add constraint subscription_products_preview_credit_no_tutorial
    check (allowance_unit <> 'final_preview_credit' or tutorial_enabled = false),
  -- An allowance is an allowance of Final Previews. A plan with a positive
  -- allowance that cannot generate them would be a plan that sells nothing.
  drop constraint if exists subscription_products_allowance_requires_preview,
  add constraint subscription_products_allowance_requires_preview
    check (base_ai_look_allowance = 0 or final_preview_enabled = true);

-- ---------------------------------------------------------------------------
-- 3. The three Preview-only products
-- ---------------------------------------------------------------------------
--
-- Provider product ids are the target ids the Expansion SOT (§5, §13) fixes
-- for these plans. As with SUB-10, the server-owned mapping is the authority:
-- a verified purchase names a provider product, and this table alone decides
-- which plan it grants. Until the products exist in Play Console nothing can
-- be verified against them, so the rows are inert; once they exist, the
-- existing activation function grants them with no further change.
--
-- `do nothing` on conflict, so re-running cannot revert a later authorized
-- configuration change — the same posture as the SUB-2 seed.
insert into public.subscription_products (
  plan_code,
  display_name,
  publicly_purchasable,
  billing_provider,
  provider_product_id,
  billing_interval,
  base_ai_look_allowance,
  reset_policy,
  allowance_unit,
  tutorial_enabled,
  final_preview_enabled
)
values
  (
    'plus_preview',
    'FaceTune Plus Preview',
    true,
    'google_play',
    'facetune_plus_preview',
    'month',
    30,
    'billing_period',
    'final_preview_credit',
    false,
    true
  ),
  (
    'pro_preview',
    'FaceTune Pro Preview',
    true,
    'google_play',
    'facetune_pro_preview',
    'month',
    80,
    'billing_period',
    'final_preview_credit',
    false,
    true
  ),
  (
    'salon_preview',
    'Salon Preview',
    true,
    'google_play',
    'facetune_salon_preview',
    'month',
    350,
    'billing_period',
    'final_preview_credit',
    false,
    true
  )
on conflict (plan_code) do nothing;

-- ---------------------------------------------------------------------------
-- 4. public.resolve_subscription_state() — reports capability
-- ---------------------------------------------------------------------------
--
-- The SUB-12 resolver with three fields added to both response shapes:
--
--     allowanceUnit         'ai_look' | 'final_preview_credit'
--     tutorialEnabled       boolean
--     finalPreviewEnabled   boolean
--
-- all read from the governing plan's product row. The precedence rule, the
-- capacity arithmetic, period membership by `reserved_at`, and the refusal
-- order are exactly what SUB-12 wrote; the function stays argument-free,
-- STABLE, `security definer` with a pinned search path, and reads the
-- account from the request JWT.
--
-- `remainingAiLooks` / `availableAiLooks` keep their names: they are the
-- shared-contract field names for "remaining allowance units", and every
-- existing reader depends on them. `allowanceUnit` is what says which unit
-- they count. A client that shows "N AI Looks" for a Preview plan is
-- ignoring a field it was given, and the Flutter copy in this phase does not.
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
  v_purchasable boolean;
  v_allowance_unit text;
  v_tutorial_enabled boolean;
  v_final_preview_enabled boolean;
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
  -- Rank 0 — a store or admin-granted entitlement that is IN FORCE: status
  --          active, grace_period, or suspended; term started; billing period
  --          and expiry, where present, not yet passed.
  -- Rank 1 — the account's lifetime Free entitlement.
  -- Rank 2 — everything else: ended store or admin entitlements and pending
  --          purchases, which only explain a refusal when no Free row exists.
  --
  -- See the SUB-12 migration for the reasoning behind each rank.
  select * into v_ent
  from public.user_entitlements as e
  where e.user_id = v_user
  order by
    case
      when e.plan_code <> 'free'
       and e.status in ('active', 'grace_period', 'suspended')
       and e.starts_at <= v_now
       and (e.expires_at is null or e.expires_at > v_now)
       and (e.period_end is null or e.period_end > v_now)
      then 0
      when e.plan_code = 'free' then 1
      else 2
    end,
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
    -- No entitlement has been provisioned for this account: a broken
    -- deployment, not a new user, after SUB-12. Generation is refused rather
    -- than silently allowed against an imaginary allowance.
    select
      p.display_name,
      p.base_ai_look_allowance,
      p.reset_policy,
      p.publicly_purchasable,
      p.allowance_unit,
      p.tutorial_enabled,
      p.final_preview_enabled
    into
      v_display_name,
      v_effective,
      v_reset_policy,
      v_purchasable,
      v_allowance_unit,
      v_tutorial_enabled,
      v_final_preview_enabled
    from public.subscription_products as p
    where p.plan_code = 'free';

    return jsonb_build_object(
      'hasEntitlement', false,
      'planCode', 'free',
      'planDisplayName', v_display_name,
      'entitlementStatus', null,
      'billingProvider', 'none',
      'publiclyPurchasable', coalesce(v_purchasable, false),
      'allowanceUnit', coalesce(v_allowance_unit, 'ai_look'),
      -- Capability is reported as the plan's, but nothing is authorized:
      -- there is no entitlement to authorize against.
      'tutorialEnabled', coalesce(v_tutorial_enabled, false),
      'finalPreviewEnabled', coalesce(v_final_preview_enabled, false),
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

  select
    p.display_name,
    p.reset_policy,
    p.publicly_purchasable,
    p.allowance_unit,
    p.tutorial_enabled,
    p.final_preview_enabled
  into
    v_display_name,
    v_reset_policy,
    v_purchasable,
    v_allowance_unit,
    v_tutorial_enabled,
    v_final_preview_enabled
  from public.subscription_products as p
  where p.plan_code = v_ent.plan_code;

  -- Effective allowance = base + authorized adjustments, floored at zero.
  v_effective := greatest(
    0,
    v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total
  );

  -- Usage is counted against the *current* period only, by `reserved_at`.
  -- One-time and admin-granted entitlements have no period, so every row
  -- they own counts for their whole life. See SUB-3 for why membership is
  -- decided by when the work happened rather than by a copied timestamp.
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

  -- Canonical capacity rule. Active reservations reduce what is available
  -- now. Floored at zero: negative capacity is prohibited outright.
  v_available := greatest(0, v_effective - v_committed - v_reserved);

  -- The user-facing "N of M remaining" figure ignores in-flight reservations.
  v_remaining := greatest(0, v_effective - v_committed);

  -- Authorization, most specific refusal first. Status is checked before
  -- capacity, so remaining allowance never overrides a blocked entitlement.
  if v_ent.status = 'revoked' then
    v_reason := 'ENTITLEMENT_REVOKED';
  elsif v_ent.status = 'suspended' then
    v_reason := 'ENTITLEMENT_SUSPENDED';
  elsif v_ent.status = 'expired' then
    v_reason := 'ENTITLEMENT_EXPIRED';
  elsif v_ent.status = 'pending' then
    v_reason := 'ENTITLEMENT_PENDING';
  elsif v_ent.starts_at > v_now then
    v_reason := 'ENTITLEMENT_PENDING';
  elsif v_ent.expires_at is not null and v_ent.expires_at <= v_now then
    v_reason := case
      when v_ent.plan_code = 'salon_pilot' then 'SALON_PILOT_EXPIRED'
      else 'ENTITLEMENT_EXPIRED'
    end;
  elsif v_ent.period_end is not null and v_ent.period_end <= v_now then
    v_reason := 'ENTITLEMENT_EXPIRED';
  elsif v_ent.status not in ('active', 'grace_period') then
    v_reason := 'ENTITLEMENT_INACTIVE';
  elsif coalesce(v_final_preview_enabled, false) is not true then
    -- No current plan is configured this way; the branch exists so a plan
    -- that cannot generate Final Previews is refused by capability rather
    -- than by an allowance that happens to be zero.
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
    'publiclyPurchasable', coalesce(v_purchasable, false),
    'allowanceUnit', coalesce(v_allowance_unit, 'ai_look'),
    'tutorialEnabled', coalesce(v_tutorial_enabled, false),
    'finalPreviewEnabled', coalesce(v_final_preview_enabled, false),
    'periodStart', v_ent.period_start,
    'periodEnd', v_ent.period_end,
    'startsAt', v_ent.starts_at,
    'expiresAt', v_ent.expires_at,
    'autoRenew', v_ent.auto_renew,
    'resetPolicy', v_reset_policy,
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

revoke all on function public.resolve_subscription_state() from public;
revoke all on function public.resolve_subscription_state() from anon;
grant execute on function public.resolve_subscription_state() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Usage ledger provenance: which plan and unit paid for a preview
-- ---------------------------------------------------------------------------
--
-- A verified plan change that Google links to the previous purchase — an
-- upgrade, a downgrade, Plus ↔ Plus Preview — re-plans the existing
-- entitlement row in place (SUB-10). That is correct for the entitlement:
-- one subscription, one row, no duplicate. But it means the row can no
-- longer say which plan a *past* preview was made under, and Tutorial
-- provenance needs exactly that: a preview bought with a Final Preview
-- Credit must stay Preview-only after the account moves to a Tutorial plan,
-- and a preview bought with an AI Look keeps its Tutorial after a move the
-- other way.
--
-- So the ledger row records it, at reservation time — the same instant the
-- capacity check authorized the work, which reservation-time attribution
-- already makes the authoritative moment. Two columns:
--
--     plan_code       the governing plan when the reservation was taken
--     allowance_unit  what one unit of that plan's allowance is
--
-- The unit is the capability class. `ai_look` carries the Tutorial;
-- `final_preview_credit` never does. Provenance reads the unit, so it
-- depends on no plan name and survives any later product renaming.
--
-- Nullable, because rows written before this migration have no stamp. They
-- are backfilled below from the entitlement's plan, which is correct for
-- every existing row: no linked plan change has ever been processed, so
-- each entitlement still carries the plan its rows were made under.
alter table public.usage_ledger
  add column if not exists plan_code text,
  add column if not exists allowance_unit text;

alter table public.usage_ledger
  drop constraint if exists usage_ledger_plan_code_valid,
  add constraint usage_ledger_plan_code_valid
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
  drop constraint if exists usage_ledger_allowance_unit_valid,
  add constraint usage_ledger_allowance_unit_valid
    check (
      allowance_unit is null
      or allowance_unit in ('ai_look', 'final_preview_credit')
    ),
  -- A stamp is a pair. Half a stamp would be a row that names a plan but
  -- not what its unit authorized.
  drop constraint if exists usage_ledger_provenance_pair,
  add constraint usage_ledger_provenance_pair
    check (
      (plan_code is null and allowance_unit is null)
      or (plan_code is not null and allowance_unit is not null)
    );

-- Backfill. Touches only the two new columns, which the SUB-2 committed-row
-- immutability trigger does not guard (it compares the columns that carry
-- billing meaning, all of which stay exactly as they are). Idempotent: rows
-- already stamped are left alone.
update public.usage_ledger as l
   set plan_code = e.plan_code,
       allowance_unit = p.allowance_unit
  from public.user_entitlements as e
  join public.subscription_products as p on p.plan_code = e.plan_code
 where e.id = l.entitlement_id
   and l.plan_code is null;

-- Once stamped, a row's provenance never changes — on any row, in any
-- status. The SUB-2 trigger protects committed rows' billing columns; this
-- protects the provenance pair on every row, so a reservation cannot be
-- re-stamped between reserve and commit either.
create or replace function public.guard_usage_ledger_provenance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.plan_code is not null
     and (
       new.plan_code is distinct from old.plan_code
       or new.allowance_unit is distinct from old.allowance_unit
     )
  then
    raise exception
      'usage_ledger provenance (plan_code, allowance_unit) is fixed at '
      'reservation and cannot be rewritten';
  end if;
  return new;
end;
$$;

drop trigger if exists usage_ledger_provenance_guard on public.usage_ledger;
create trigger usage_ledger_provenance_guard
before update on public.usage_ledger
for each row execute function public.guard_usage_ledger_provenance();

-- The provenance columns are readable by the owner like the rest of the
-- row: `authenticated` holds table-level SELECT on `usage_ledger` (SUB-2),
-- which covers new columns. No write privilege is granted; none exists.

-- ---------------------------------------------------------------------------
-- 6. public.reserve_ai_look(uuid) — stamps provenance
-- ---------------------------------------------------------------------------
--
-- Redefined verbatim from SUB-4 with one addition: the reservation row is
-- written with the governing plan's code and allowance unit. The advisory
-- lock, the idempotent replay, the single authority for capacity
-- (`resolve_subscription_state`), the response shape and the exception
-- handler are unchanged, and the grants are preserved by `create or replace`.
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
  v_plan_code text;
  v_allowance_unit text;
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

  select e.period_start, e.period_end, e.plan_code, p.allowance_unit
    into v_period_start, v_period_end, v_plan_code, v_allowance_unit
  from public.user_entitlements as e
  join public.subscription_products as p on p.plan_code = e.plan_code
  where e.id = v_entitlement_id and e.user_id = v_user;

  -- `reserved_at` is written in the same statement that the capacity check
  -- authorized, and is what period membership is later decided by.
  --
  -- SUB-12B: the plan and allowance unit that authorized this reservation
  -- are stamped here too. A linked plan change re-plans the entitlement row
  -- in place, so the row cannot say later which plan paid for a given
  -- preview; the ledger row can, and it is what Tutorial provenance reads.
  insert into public.usage_ledger (
    user_id, entitlement_id, operation_id, status,
    period_start, period_end, reserved_at,
    plan_code, allowance_unit
  )
  values (
    v_user, v_entitlement_id, p_operation_id, 'reserved',
    v_period_start, v_period_end, v_now,
    v_plan_code, v_allowance_unit
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

revoke all on function public.reserve_ai_look(uuid) from public;
revoke all on function public.reserve_ai_look(uuid) from anon;
grant execute on function public.reserve_ai_look(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. public.authorize_tutorial_generation(...) — server-side Tutorial gate
-- ---------------------------------------------------------------------------
--
-- Answers, for the authenticated caller: "may a NEW Tutorial be generated for
-- this Final Preview right now?" The two Tutorial V4 Edge Functions call it
-- before any paid work — after they have returned an already-generated
-- manifest or step, so reopening historical Tutorial content is never gated
-- and never charged.
--
-- Two questions, both answered from product capability, never from a plan
-- name:
--
--   1. Does the entitlement governing the account right now include the
--      Tutorial? A Preview-only plan does not, so a Preview-only subscriber
--      is refused new Tutorials while that plan is in force, whatever they
--      held before.
--
--   2. Was the preview itself produced under a Tutorial-capable unit? Every
--      committed Final Preview's ledger row is stamped, at reservation, with
--      the plan and allowance unit that paid for it (section 5). A preview
--      bought with a Final Preview Credit stays a Preview-only result for
--      life: switching to a Tutorial plan later, or falling back to Free when
--      the Preview plan ends, does not turn it into one. Capability
--      provenance is the ledger's, not the current plan's — and not the
--      entitlement row's either, since a linked plan change re-plans that
--      row in place.
--
--   A preview with no committed ledger row — one made before the ledger
--   existed, or whose History item was deleted and whose commit row now
--   carries no preview id — has no provenance to check, and question 1
--   alone decides. That preserves every pre-subscription Tutorial exactly
--   as it works today.
--
-- Nothing about entitlement validity or capacity is checked here beyond what
-- question 1 needs. A Tutorial consumes no allowance, and an expired
-- Tutorial-plan subscriber's Tutorial access is governed by the same
-- historical-content rules as before this phase: this function narrows
-- nothing for them, because their governing entitlement (Free) includes the
-- Tutorial and their previews carry Tutorial-capable provenance.
--
-- Identity: `auth.uid()` from the request JWT, security definer, pinned
-- search path — the SUB-3 pattern. The preview or session named by the
-- caller is resolved only among rows the caller owns.
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
      else v_session.canonical_generated_image_id
    end;
  end if;

  if v_mode = 'my_makeup_kit' then
    v_mode := 'makeup_kit';
  end if;

  if v_mode not in ('standard', 'makeup_kit') or v_preview is null then
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
  elsif not exists (
    select 1 from public.kit_generated_images as k
    where k.id = v_preview and k.user_id = v_user
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

-- Executable by `authenticated`, like the resolver it wraps: it reads only
-- the caller's own state and grants nothing. It is the server's answer; the
-- Edge Functions refuse when it says so, and a client that skips it gains
-- nothing because the Edge Functions are the only path to generation.
revoke all on function public.authorize_tutorial_generation(text, uuid, uuid)
  from public;
revoke all on function public.authorize_tutorial_generation(text, uuid, uuid)
  from anon;
grant execute on function public.authorize_tutorial_generation(text, uuid, uuid)
  to authenticated;
