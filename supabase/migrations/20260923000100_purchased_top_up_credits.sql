-- FaceTune SUB-13B: purchased top-up credits.
--
-- Adds a second, separate source of Final Preview capacity beside the
-- subscription's included allowance: credits bought as Google Play one-time
-- products. The approved V1 matrix:
--
--   Extra AI Look     ₱149  →  +1  Tutorial-capable AI Look credit
--   Preview Boost     ₱149  →  +10 Preview-only Final Preview credits
--
-- Prices live in Play Console and are never stored here. What this migration
-- owns is the provider product → pack mapping, the auditable grant ledger,
-- and the accounting rules that decide when a purchased credit is spent.
--
-- ## Three buckets that never merge
--
--   subscription included allowance   user_entitlements.base_ai_look_allowance
--   Salon Pilot admin adjustment      user_entitlements.allowance_adjustment_total
--   purchased top-up credit           purchased_credit_grants (this migration)
--
-- A purchased credit has no period, is never reset by a renewal, is never
-- deleted by cancellation or expiry, and is never folded into either of the
-- other two figures. It is spendable only while an eligible paid plan is in
-- force, and only after that plan's own included allowance for the period is
-- exhausted.
--
-- ## Credit and debit
--
-- Grants are append-only rows. Consumption is not a counter on the grant: it
-- is the `usage_ledger` rows that name the grant they drew from. Remaining
-- credits are therefore always derived —
--
--   remaining  = quantity_granted − committed rows on the grant
--   available  = remaining         − reserved rows on the grant
--
-- — so a released reservation returns its credit by ceasing to count, and no
-- code path anywhere increments or decrements a balance.
--
-- ## Capability provenance
--
-- Each grant carries its credit class, fixed at purchase from the pack:
--
--   tutorial_capable_ai_look     spends as an `ai_look` unit
--   preview_only_final_preview   spends as a `final_preview_credit` unit
--
-- The class is stamped onto the ledger row at reservation as `allowance_unit`,
-- which is what `authorize_tutorial_generation` already reads. A Preview-only
-- credit therefore never yields a Tutorial, on any plan, ever; and a
-- Tutorial-capable credit is only ever spent under a Tutorial-enabled plan —
-- under a Preview-only plan it is preserved untouched rather than spent as a
-- lesser capability or used to smuggle a Tutorial past the plan.
--
-- ## Deterministic consumption order
--
--   1. the governing plan's included allowance for the current period
--   2. purchased credits compatible with the governing plan:
--        a. the class matching the plan's own unit, oldest grant first
--        b. any other compatible class, oldest grant first
--
-- Under a Tutorial-enabled plan both classes are compatible, Tutorial-capable
-- first. Under a Preview-only plan only Preview-only credits are compatible.
-- Free and Salon Pilot are not eligible: their credits, if any, wait.
--
-- Nothing here changes the locked subscription matrix, the Final Preview
-- model, Tutorial V4, or the SUB-10/SUB-11 subscription lifecycle writers.

-- ---------------------------------------------------------------------------
-- 1. Server-owned pack catalog
-- ---------------------------------------------------------------------------
--
-- The provider product id is the only thing a purchase brings with it, and
-- this table is the only thing that says what it is worth. A client claim
-- about quantity, class, or pack is never an input anywhere below.
create table public.top_up_packs (
  id uuid primary key default gen_random_uuid(),
  pack_code text not null,
  display_name text not null,
  billing_provider text not null default 'google_play',
  provider_product_id text not null,
  credit_class text not null,
  quantity integer not null,
  -- The plans that may buy this pack, as approved. Purchase eligibility is
  -- exact: a Tutorial plan buys Extra AI Look, a Preview-only plan buys
  -- Preview Boost. Consumption compatibility after a later plan change is a
  -- separate rule, decided by the credit's class (see the header).
  eligible_plan_codes text[] not null,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint top_up_packs_code_unique unique (pack_code),
  constraint top_up_packs_product_unique unique (provider_product_id),
  constraint top_up_packs_code_valid
    check (pack_code in ('extra_ai_look', 'preview_boost')),
  constraint top_up_packs_provider_valid
    check (billing_provider in ('google_play', 'apple_app_store')),
  constraint top_up_packs_class_valid
    check (
      credit_class in ('tutorial_capable_ai_look', 'preview_only_final_preview')
    ),
  constraint top_up_packs_quantity_positive check (quantity > 0),
  constraint top_up_packs_display_name_not_blank
    check (char_length(btrim(display_name)) > 0),
  constraint top_up_packs_product_not_blank
    check (char_length(btrim(provider_product_id)) > 0),
  -- The approved matrix, enforced by the table so a later edit cannot quietly
  -- change what a pack grants without also changing this constraint.
  constraint top_up_packs_locked_matrix
    check (
      (pack_code = 'extra_ai_look'
        and credit_class = 'tutorial_capable_ai_look'
        and quantity = 1
        and eligible_plan_codes = array['plus', 'pro', 'salon_pro'])
      or (pack_code = 'preview_boost'
        and credit_class = 'preview_only_final_preview'
        and quantity = 10
        and eligible_plan_codes
          = array['plus_preview', 'pro_preview', 'salon_preview'])
    )
);

create trigger top_up_packs_set_updated_at
before update on public.top_up_packs
for each row execute function public.set_updated_at();

insert into public.top_up_packs (
  pack_code, display_name, billing_provider, provider_product_id,
  credit_class, quantity, eligible_plan_codes
) values
  ('extra_ai_look', 'Extra AI Look', 'google_play',
   'facetune_ai_look_topup_1', 'tutorial_capable_ai_look', 1,
   array['plus', 'pro', 'salon_pro']),
  ('preview_boost', 'Preview Boost', 'google_play',
   'facetune_preview_credit_topup_10', 'preview_only_final_preview', 10,
   array['plus_preview', 'pro_preview', 'salon_preview']);

alter table public.top_up_packs enable row level security;
revoke all on table public.top_up_packs from anon;
revoke all on table public.top_up_packs from authenticated;
-- Catalog facts only: the same read the app already has on
-- `subscription_products`. Nothing here is a price or an entitlement.
grant select on table public.top_up_packs to authenticated;
create policy "top_up_packs_select_active"
on public.top_up_packs for select
to authenticated
using (active);

-- ---------------------------------------------------------------------------
-- 2. Purchased credit grants — the credit side of the ledger
-- ---------------------------------------------------------------------------
create table public.purchased_credit_grants (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  billing_provider text not null default 'google_play',
  provider_product_id text not null,
  pack_code text not null references public.top_up_packs(pack_code),
  credit_class text not null,
  quantity_granted integer not null,

  -- SHA-256 of the provider purchase token, lowercase hex. Never the token.
  -- One grant per purchase: this is the replay anchor.
  purchase_reference text not null,

  -- Google's order id (e.g. `GPA.1234-5678-9012-34567`). An identifier, not a
  -- credential; kept so a refund in Play Console can be matched to the grant
  -- it concerns.
  provider_order_id text,

  -- The provider state at grant. Only `PURCHASED` can ever be written; a
  -- pending or cancelled purchase grants nothing and leaves no row.
  purchase_state text not null,
  test_purchase boolean not null default false,

  -- Provenance: which plan made the account eligible when it bought. Recorded
  -- for audit; it does not decide compatibility later, the class does.
  granted_under_plan_code text,
  granted_under_entitlement_id uuid,

  -- When Google was told the purchase was delivered (consumed). One of the
  -- two facts that legitimately arrive after insert.
  provider_consumed_at timestamptz,

  -- Revocation: the provider later reported the purchase refunded, voided,
  -- or otherwise revoked. Set once, never cleared. A revoked grant is
  -- unavailable for any future reservation; credits it already paid for
  -- stay in the usage ledger as immutable history. Because remaining
  -- credits are derived rather than counted, revocation can never produce
  -- a negative figure: the grant simply stops contributing anything.
  revoked_at timestamptz,
  revocation_reason text,
  -- The provider's own reference for the revocation (e.g. a voided-purchase
  -- order id), for reconciliation. Never a token.
  revocation_reference text,

  granted_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint purchased_credit_grants_reference_unique
    unique (purchase_reference),
  constraint purchased_credit_grants_owner_identity unique (id, user_id),
  constraint purchased_credit_grants_revocation_pair
    check (
      (revoked_at is null and revocation_reason is null
        and revocation_reference is null)
      or (revoked_at is not null and revocation_reason is not null)
    ),
  constraint purchased_credit_grants_revocation_reason_valid
    check (
      revocation_reason is null
      or revocation_reason in ('refunded', 'voided', 'revoked')
    ),
  constraint purchased_credit_grants_revocation_reference_shape
    check (
      revocation_reference is null
      or revocation_reference ~ '^[A-Za-z0-9._-]{1,64}$'
    ),
  constraint purchased_credit_grants_entitlement_owner_fk
    foreign key (granted_under_entitlement_id, user_id)
    references public.user_entitlements(id, user_id)
    on delete set null (granted_under_entitlement_id),
  constraint purchased_credit_grants_provider_valid
    check (billing_provider in ('google_play', 'apple_app_store')),
  constraint purchased_credit_grants_class_valid
    check (
      credit_class in ('tutorial_capable_ai_look', 'preview_only_final_preview')
    ),
  constraint purchased_credit_grants_quantity_positive
    check (quantity_granted > 0),
  constraint purchased_credit_grants_reference_is_sha256
    check (purchase_reference ~ '^[0-9a-f]{64}$'),
  constraint purchased_credit_grants_order_id_shape
    check (
      provider_order_id is null
      or provider_order_id ~ '^[A-Za-z0-9._-]{1,64}$'
    ),
  constraint purchased_credit_grants_state_purchased
    check (purchase_state = 'PURCHASED'),
  constraint purchased_credit_grants_product_not_blank
    check (char_length(btrim(provider_product_id)) > 0),
  -- Only a paid, store-backed plan can be the plan a credit was bought under.
  constraint purchased_credit_grants_plan_paid
    check (
      granted_under_plan_code is null
      or granted_under_plan_code in (
        'plus', 'plus_preview', 'pro', 'pro_preview', 'salon_pro',
        'salon_preview'
      )
    )
);

create index purchased_credit_grants_user_granted_idx
  on public.purchased_credit_grants (user_id, granted_at, id);

create trigger purchased_credit_grants_set_updated_at
before update on public.purchased_credit_grants
for each row execute function public.set_updated_at();

-- A grant is a historical record. Two facts legitimately arrive later —
-- provider consumption, and a provider revocation — and each may be written
-- once, from null. Everything else is fixed at insert, and a revocation is
-- never cleared or changed: the audit trail of what the provider said stays.
create function public.reject_purchased_credit_grant_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id = old.id
    and new.user_id = old.user_id
    and new.billing_provider = old.billing_provider
    and new.provider_product_id = old.provider_product_id
    and new.pack_code = old.pack_code
    and new.credit_class = old.credit_class
    and new.quantity_granted = old.quantity_granted
    and new.purchase_reference = old.purchase_reference
    and new.provider_order_id is not distinct from old.provider_order_id
    and new.purchase_state = old.purchase_state
    and new.test_purchase = old.test_purchase
    and new.granted_under_plan_code
      is not distinct from old.granted_under_plan_code
    and new.granted_under_entitlement_id
      is not distinct from old.granted_under_entitlement_id
    and new.granted_at = old.granted_at
    and new.created_at = old.created_at
    and (
      old.provider_consumed_at is null
      or new.provider_consumed_at = old.provider_consumed_at
    )
    -- A revocation is written once, from null; the pair constraint on the
    -- table guarantees its shape. Once written it is never cleared or edited.
    and (
      old.revoked_at is null
      or (
        new.revoked_at = old.revoked_at
        and new.revocation_reason = old.revocation_reason
        and new.revocation_reference
          is not distinct from old.revocation_reference
      )
    )
  then
    return new;
  end if;

  raise exception
    'purchased_credit_grants rows are immutable except for provider '
    'consumption and a single revocation';
end;
$$;

create trigger purchased_credit_grants_immutable
before update on public.purchased_credit_grants
for each row execute function public.reject_purchased_credit_grant_mutation();

-- A grant can only ever say what its pack says. The writer below copies the
-- pack's class and quantity, but the table checks the copy too, so no other
-- writer — present or future — can mint a quantity or class the approved
-- matrix does not contain.
create function public.guard_purchased_credit_grant_pack()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1
    from public.top_up_packs as t
    where t.pack_code = new.pack_code
      and t.credit_class = new.credit_class
      and t.quantity = new.quantity_granted
  ) then
    raise exception
      'purchased_credit_grants must match the approved top-up pack matrix';
  end if;
  return new;
end;
$$;

create trigger purchased_credit_grants_pack_guard
before insert on public.purchased_credit_grants
for each row execute function public.guard_purchased_credit_grant_pack();

-- Direct deletion is refused. A cascade — the account itself being deleted —
-- arrives through the referential-integrity trigger at depth one and is the
-- one deletion that is allowed, so removing an account still removes its
-- grants rather than failing on them.
create function public.reject_purchased_credit_grant_delete()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if pg_trigger_depth() > 1 then
    return old;
  end if;
  raise exception 'purchased_credit_grants rows cannot be deleted';
end;
$$;

create trigger purchased_credit_grants_no_delete
before delete on public.purchased_credit_grants
for each row execute function public.reject_purchased_credit_grant_delete();

alter table public.purchased_credit_grants enable row level security;
revoke all on table public.purchased_credit_grants from anon;
revoke all on table public.purchased_credit_grants from authenticated;

-- Owners may read their own grants, minus the purchase reference, which is a
-- correlation identifier with no use in the app. No write privilege of any
-- kind: the row owner is exactly the party who benefits from forging it.
grant select (
  id,
  user_id,
  billing_provider,
  provider_product_id,
  pack_code,
  credit_class,
  quantity_granted,
  provider_order_id,
  purchase_state,
  test_purchase,
  granted_under_plan_code,
  granted_under_entitlement_id,
  provider_consumed_at,
  granted_at,
  created_at,
  updated_at
) on table public.purchased_credit_grants to authenticated;

create policy "purchased_credit_grants_select_own"
on public.purchased_credit_grants for select
to authenticated
using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 3. Usage ledger — the debit side
-- ---------------------------------------------------------------------------
--
-- Every reservation now records which bucket it drew from. Existing rows are
-- subscription rows: that is what every one of them was.
alter table public.usage_ledger
  add column allowance_source text not null default 'subscription',
  add column purchased_credit_grant_id uuid;

alter table public.usage_ledger
  add constraint usage_ledger_allowance_source_valid
    check (allowance_source in ('subscription', 'purchased_credit')),
  add constraint usage_ledger_purchased_source_pair
    check (
      (allowance_source = 'subscription'
        and purchased_credit_grant_id is null)
      or (allowance_source = 'purchased_credit'
        and purchased_credit_grant_id is not null)
    ),
  add constraint usage_ledger_purchased_grant_owner_fk
    foreign key (purchased_credit_grant_id, user_id)
    references public.purchased_credit_grants(id, user_id);

create index usage_ledger_purchased_grant_status_idx
  on public.usage_ledger (purchased_credit_grant_id, status)
  where purchased_credit_grant_id is not null;

-- The source is provenance, fixed at reservation exactly like the plan and
-- unit stamps. Superset of the SUB-12B guard.
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

  if new.allowance_source is distinct from old.allowance_source
     or new.purchased_credit_grant_id
       is distinct from old.purchased_credit_grant_id
  then
    raise exception
      'usage_ledger allowance source is fixed at reservation and cannot be '
      'rewritten';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. public.resolve_subscription_state()
-- ---------------------------------------------------------------------------
--
-- Unchanged in everything it already said. Three things are added:
--
--   * the subscription figures (`committedUsage`, `reservedUsage`,
--     `availableAiLooks`, `remainingAiLooks`) now count only rows drawn from
--     the subscription, so a purchased credit never appears to spend the
--     included allowance;
--   * `generationAuthorized` is also true when the included allowance is
--     exhausted but a compatible purchased credit is available under an
--     eligible paid plan, and `nextAllowanceSource` / `nextAllowanceUnit`
--     say which bucket and capability the next reservation will use;
--   * the purchased-credit figures are reported per class, with whether they
--     are spendable right now.
create or replace function public.resolve_subscription_state()
returns jsonb
language plpgsql
stable
security definer
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
  -- Purchased credits, per class.
  v_tut_granted integer := 0;
  v_tut_committed integer := 0;
  v_tut_reserved integer := 0;
  v_prev_granted integer := 0;
  v_prev_committed integer := 0;
  v_prev_reserved integer := 0;
  v_tut_remaining integer := 0;
  v_tut_available integer := 0;
  v_prev_remaining integer := 0;
  v_prev_available integer := 0;
  v_credits_usable boolean := false;
  v_compatible_available integer := 0;
  v_next_source text := null;
  v_next_unit text := null;
begin
  if v_user is null then
    return jsonb_build_object(
      'hasEntitlement', false,
      'generationAuthorized', false,
      'denialReason', 'AUTH_REQUIRED',
      'resolvedAt', v_now
    );
  end if;

  -- Purchased credits belong to the account, not to any entitlement, so they
  -- are read before the governing entitlement is chosen and reported whatever
  -- it turns out to be — including when there is none.
  --
  -- A revoked grant contributes nothing on either side: not its quantity, and
  -- not the rows it paid for. Its consumed credits stay in the ledger as
  -- history; its unused credits simply stop being counted. Subtraction never
  -- runs across grants, so no figure here can go below zero.
  select
    coalesce(sum(g.quantity_granted) filter (
      where g.credit_class = 'tutorial_capable_ai_look'), 0),
    coalesce(sum(g.quantity_granted) filter (
      where g.credit_class = 'preview_only_final_preview'), 0)
  into v_tut_granted, v_prev_granted
  from public.purchased_credit_grants as g
  where g.user_id = v_user
    and g.revoked_at is null;

  select
    count(*) filter (where g.credit_class = 'tutorial_capable_ai_look'
      and l.status = 'committed'),
    count(*) filter (where g.credit_class = 'tutorial_capable_ai_look'
      and l.status = 'reserved'),
    count(*) filter (where g.credit_class = 'preview_only_final_preview'
      and l.status = 'committed'),
    count(*) filter (where g.credit_class = 'preview_only_final_preview'
      and l.status = 'reserved')
  into v_tut_committed, v_tut_reserved, v_prev_committed, v_prev_reserved
  from public.usage_ledger as l
  join public.purchased_credit_grants as g
    on g.id = l.purchased_credit_grant_id and g.user_id = l.user_id
  where l.user_id = v_user
    and l.allowance_source = 'purchased_credit'
    and g.revoked_at is null;

  v_tut_remaining := greatest(0, v_tut_granted - v_tut_committed);
  v_tut_available := greatest(0, v_tut_remaining - v_tut_reserved);
  v_prev_remaining := greatest(0, v_prev_granted - v_prev_committed);
  v_prev_available := greatest(0, v_prev_remaining - v_prev_reserved);

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
    -- than silently allowed against an imaginary allowance — and purchased
    -- credits, which need an eligible paid plan, cannot change that.
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
      'purchasedTutorialCreditsRemaining', v_tut_remaining,
      'purchasedPreviewCreditsRemaining', v_prev_remaining,
      'purchasedCreditsUsable', false,
      'availablePurchasedCredits', 0,
      'nextAllowanceSource', null,
      'nextAllowanceUnit', null,
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
  --
  -- SUB-13B: only rows drawn from the subscription count here. A purchased
  -- credit spent while this plan governed names the plan on its row, but it
  -- was paid for separately and must not consume the included allowance.
  select
    count(*) filter (where u.status = 'committed'),
    count(*) filter (where u.status = 'reserved')
  into v_committed, v_reserved
  from public.usage_ledger as u
  where u.entitlement_id = v_ent.id
    and u.user_id = v_user
    and u.allowance_source = 'subscription'
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
  end if;

  -- Purchased credits are spendable only under an eligible paid plan that is
  -- otherwise able to generate. Free and Salon Pilot are not eligible, and a
  -- blocked or lapsed paid plan is not either: the credits simply wait.
  v_credits_usable := v_reason is null
    and v_ent.plan_code in (
      'plus', 'plus_preview', 'pro', 'pro_preview', 'salon_pro',
      'salon_preview'
    )
    and v_ent.billing_provider in ('google_play', 'apple_app_store');

  -- Which classes are compatible with this plan. A Tutorial-capable credit
  -- is never spent under a plan that forbids the Tutorial: it would either
  -- be spent as a lesser thing or smuggle a Tutorial past the plan.
  if v_credits_usable then
    v_compatible_available := v_prev_available
      + case when coalesce(v_tutorial_enabled, false)
          then v_tut_available else 0 end;
  end if;

  if v_reason is not null then
    v_authorized := false;
  elsif v_available > 0 then
    v_authorized := true;
    v_next_source := 'subscription';
    v_next_unit := coalesce(v_allowance_unit, 'ai_look');
  elsif v_compatible_available > 0 then
    v_authorized := true;
    v_next_source := 'purchased_credit';
    -- The class matching the plan's own unit is spent first; see the order
    -- in `reserve_ai_look`, which this mirrors exactly.
    v_next_unit := case
      when coalesce(v_tutorial_enabled, false) and v_tut_available > 0
        then 'ai_look'
      else 'final_preview_credit'
    end;
  else
    v_reason := 'AI_LOOK_LIMIT_REACHED';
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
    'purchasedTutorialCreditsRemaining', v_tut_remaining,
    'purchasedPreviewCreditsRemaining', v_prev_remaining,
    'purchasedCreditsUsable', v_credits_usable,
    'availablePurchasedCredits', v_compatible_available,
    'nextAllowanceSource', v_next_source,
    'nextAllowanceUnit', v_next_unit,
    'verifiedAt', v_ent.verified_at,
    'resolvedAt', v_now
  );
end;
$$;

revoke all on function public.resolve_subscription_state() from public;
revoke all on function public.resolve_subscription_state() from anon;
grant execute on function public.resolve_subscription_state() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. public.reserve_ai_look(uuid)
-- ---------------------------------------------------------------------------
--
-- Unchanged in its contract. When the resolver authorizes a reservation from
-- a purchased credit, the row now names the grant it draws from, carries no
-- billing period, and is stamped with the credit's own unit rather than the
-- plan's. Everything else — the per-account lock, the idempotent replay, the
-- unique-constraint backstop — is exactly as before.
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
  v_tutorial_enabled boolean;
  v_source text;
  v_grant_id uuid;
  v_grant_class text;
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
  -- The same lock guards the top-up grant writer, so a grant and a spend
  -- cannot interleave either.
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
      'allowanceSource', v_existing.allowance_source,
      'errorCode', case
        when v_existing.status = 'committed' then 'USAGE_ALREADY_COMMITTED'
        when v_existing.status = 'released' then 'USAGE_ALREADY_RELEASED'
        else null
      end
    );
  end if;

  -- One authority for eligibility and capacity: the SUB-3 resolver. It already
  -- accounts for status, lapsed dates, future start dates, adjustments, active
  -- reservations, and — since SUB-13B — which bucket the next reservation
  -- draws from, so none of that logic is repeated here.
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
  v_source := coalesce(v_state->>'nextAllowanceSource', 'subscription');

  select e.period_start, e.period_end, e.plan_code, p.allowance_unit,
         p.tutorial_enabled
    into v_period_start, v_period_end, v_plan_code, v_allowance_unit,
         v_tutorial_enabled
  from public.user_entitlements as e
  join public.subscription_products as p on p.plan_code = e.plan_code
  where e.id = v_entitlement_id and e.user_id = v_user;

  if v_source = 'purchased_credit' then
    -- The oldest grant with a credit left, in the class order the resolver
    -- promised: the plan's own unit first, then any other compatible class.
    -- Under a Preview-only plan the Tutorial-capable class is simply not a
    -- candidate, so such a credit is preserved rather than spent.
    select g.id, g.credit_class
      into v_grant_id, v_grant_class
    from public.purchased_credit_grants as g
    where g.user_id = v_user
      and g.revoked_at is null
      and (
        g.credit_class = 'preview_only_final_preview'
        or (
          g.credit_class = 'tutorial_capable_ai_look'
          and coalesce(v_tutorial_enabled, false)
        )
      )
      and g.quantity_granted > (
        select count(*)
        from public.usage_ledger as l
        where l.purchased_credit_grant_id = g.id
          and l.status in ('reserved', 'committed')
      )
    order by
      case
        when g.credit_class = 'tutorial_capable_ai_look'
         and coalesce(v_tutorial_enabled, false) then 0
        else 1
      end,
      g.granted_at,
      g.id
    limit 1;

    if v_grant_id is null then
      -- The resolver saw a credit that this query could not find. Nothing
      -- is reserved; the caller sees the ordinary exhausted refusal.
      return jsonb_build_object(
        'ok', false,
        'operationId', p_operation_id,
        'errorCode', 'AI_LOOK_LIMIT_REACHED',
        'availableAiLooks', 0
      );
    end if;

    -- A purchased credit has no billing period. The plan is stamped for
    -- provenance (which plan made the spend eligible); the unit is the
    -- credit's own class, which is what the Tutorial authority reads.
    insert into public.usage_ledger (
      user_id, entitlement_id, operation_id, status,
      period_start, period_end, reserved_at,
      plan_code, allowance_unit,
      allowance_source, purchased_credit_grant_id
    )
    values (
      v_user, v_entitlement_id, p_operation_id, 'reserved',
      null, null, v_now,
      v_plan_code,
      case
        when v_grant_class = 'tutorial_capable_ai_look' then 'ai_look'
        else 'final_preview_credit'
      end,
      'purchased_credit', v_grant_id
    );
  else
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
      plan_code, allowance_unit,
      allowance_source, purchased_credit_grant_id
    )
    values (
      v_user, v_entitlement_id, p_operation_id, 'reserved',
      v_period_start, v_period_end, v_now,
      v_plan_code, v_allowance_unit,
      'subscription', null
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'operationId', p_operation_id,
    'status', 'reserved',
    'entitlementId', v_entitlement_id,
    'allowanceSource', v_source,
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
-- 6. public.grant_verified_top_up_purchase(...)
-- ---------------------------------------------------------------------------
--
-- Writes a grant from facts a caller has *already verified* against Google.
-- It performs no verification of its own and cannot; that is why, like the
-- SUB-10 activation function, it is executable by `service_role` alone. Its
-- arguments name the user — established by the Edge Function from the
-- request JWT — and the purchase; nothing about quantity, class, or pack is
-- an argument, because none of those are the caller's to say.
--
-- Exactly once per purchase: the grant is keyed on the purchase reference,
-- the account is serialized by the same advisory lock as the usage engine,
-- and the unique constraint decides any race the lock did not.
create function public.grant_verified_top_up_purchase(
  p_user_id uuid,
  p_provider_product_id text,
  p_purchase_reference text,
  p_purchase_state text,
  p_provider_order_id text default null,
  p_test_purchase boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_pack public.top_up_packs%rowtype;
  v_existing public.purchased_credit_grants%rowtype;
  v_ent public.user_entitlements%rowtype;
  v_grant_id uuid;
begin
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  if p_purchase_reference is null
     or p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PURCHASE_VERIFICATION_FAILED'
    );
  end if;

  if p_provider_product_id is null
     or char_length(btrim(p_provider_product_id)) = 0 then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'INVALID_TOP_UP_PRODUCT'
    );
  end if;

  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  -- Replay first, before any eligibility check: a purchase that was already
  -- granted stays granted, whatever the account's plan has become since.
  select * into v_existing
  from public.purchased_credit_grants as g
  where g.purchase_reference = p_purchase_reference;

  if found then
    if v_existing.user_id <> p_user_id then
      -- A purchase bound to another account. Refuse, and change nothing.
      return jsonb_build_object(
        'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
      );
    end if;
    return jsonb_build_object(
      'ok', true,
      'replayed', true,
      'grantId', v_existing.id,
      'packCode', v_existing.pack_code,
      'creditClass', v_existing.credit_class,
      'quantityGranted', v_existing.quantity_granted,
      'providerConsumed', v_existing.provider_consumed_at is not null,
      'grantedAt', v_existing.granted_at
    );
  end if;

  -- Provider product → pack. Server-owned; an unrecognised product is refused
  -- rather than defaulted, and a subscription product is not a pack.
  select * into v_pack
  from public.top_up_packs as t
  where t.provider_product_id = btrim(p_provider_product_id)
    and t.active
    and t.billing_provider = 'google_play';

  if not found then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'INVALID_TOP_UP_PRODUCT'
    );
  end if;

  -- Only a completed purchase grants. Pending is reported as such so the
  -- client can wait; anything else is refused and, being unconsumed, is
  -- refunded by Google on its own schedule.
  if p_purchase_state = 'PENDING' then
    return jsonb_build_object('ok', false, 'errorCode', 'TOP_UP_PENDING');
  elsif p_purchase_state is distinct from 'PURCHASED' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  -- Eligibility: the account must be governed, right now, by a paid store
  -- plan in force, and that plan must be one the pack is approved for. Free
  -- and Salon Pilot cannot buy; a Tutorial plan buys Extra AI Look and a
  -- Preview-only plan buys Preview Boost, exactly as the pack row says. The
  -- ranking is the resolver's.
  select * into v_ent
  from public.user_entitlements as e
  where e.user_id = p_user_id
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

  if not found
     or v_ent.plan_code not in (
       'plus', 'plus_preview', 'pro', 'pro_preview', 'salon_pro',
       'salon_preview'
     )
     or v_ent.billing_provider not in ('google_play', 'apple_app_store')
     or v_ent.status not in ('active', 'grace_period')
     or v_ent.starts_at > v_now
     or (v_ent.expires_at is not null and v_ent.expires_at <= v_now)
     or (v_ent.period_end is not null and v_ent.period_end <= v_now)
  then
    return jsonb_build_object('ok', false, 'errorCode', 'TOP_UP_NOT_ELIGIBLE');
  end if;

  if not (v_ent.plan_code = any (v_pack.eligible_plan_codes)) then
    return jsonb_build_object('ok', false, 'errorCode', 'TOP_UP_NOT_ELIGIBLE');
  end if;

  insert into public.purchased_credit_grants (
    user_id,
    billing_provider,
    provider_product_id,
    pack_code,
    credit_class,
    quantity_granted,
    purchase_reference,
    provider_order_id,
    purchase_state,
    test_purchase,
    granted_under_plan_code,
    granted_under_entitlement_id,
    granted_at
  )
  values (
    p_user_id,
    'google_play',
    v_pack.provider_product_id,
    v_pack.pack_code,
    v_pack.credit_class,
    v_pack.quantity,
    p_purchase_reference,
    case
      when p_provider_order_id ~ '^[A-Za-z0-9._-]{1,64}$'
        then p_provider_order_id
      else null
    end,
    'PURCHASED',
    coalesce(p_test_purchase, false),
    v_ent.plan_code,
    v_ent.id,
    v_now
  )
  returning id into v_grant_id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'grantId', v_grant_id,
    'packCode', v_pack.pack_code,
    'creditClass', v_pack.credit_class,
    'quantityGranted', v_pack.quantity,
    'providerConsumed', false,
    'grantedAt', v_now
  );
exception
  when unique_violation then
    -- Two verifications of the same purchase raced past the lock. The unique
    -- constraint on `purchase_reference` decided; the loser reports a benign
    -- conflict and the client re-verifies, which replays the winner's grant.
    return jsonb_build_object(
      'ok', false, 'errorCode', 'CONCURRENT_MODIFICATION'
    );
end;
$$;

revoke all on function public.grant_verified_top_up_purchase(
  uuid, text, text, text, text, boolean
) from public;
revoke all on function public.grant_verified_top_up_purchase(
  uuid, text, text, text, text, boolean
) from anon;
revoke all on function public.grant_verified_top_up_purchase(
  uuid, text, text, text, text, boolean
) from authenticated;
grant execute on function public.grant_verified_top_up_purchase(
  uuid, text, text, text, text, boolean
) to service_role;

-- ---------------------------------------------------------------------------
-- 7. public.mark_top_up_purchase_consumed(...)
-- ---------------------------------------------------------------------------
--
-- Records that Google accepted the consumption of a granted purchase. Not
-- part of the grant: a consumption that fails after a committed grant is
-- retried by the client's next verification, which replays the grant and
-- tries the consumption again — never a second grant. Idempotent.
create function public.mark_top_up_purchase_consumed(
  p_user_id uuid,
  p_purchase_reference text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_updated integer;
begin
  if p_user_id is null
     or p_purchase_reference is null
     or p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return false;
  end if;

  update public.purchased_credit_grants as g
     set provider_consumed_at = timezone('utc', now())
   where g.purchase_reference = p_purchase_reference
     and g.user_id = p_user_id
     and g.provider_consumed_at is null;
  get diagnostics v_updated = row_count;

  return v_updated = 1 or exists (
    select 1 from public.purchased_credit_grants as g
    where g.purchase_reference = p_purchase_reference
      and g.user_id = p_user_id
      and g.provider_consumed_at is not null
  );
end;
$$;

revoke all on function public.mark_top_up_purchase_consumed(uuid, text)
  from public;
revoke all on function public.mark_top_up_purchase_consumed(uuid, text)
  from anon;
revoke all on function public.mark_top_up_purchase_consumed(uuid, text)
  from authenticated;
grant execute on function public.mark_top_up_purchase_consumed(uuid, text)
  to service_role;

-- ---------------------------------------------------------------------------
-- 8. public.revoke_top_up_purchase(...)
-- ---------------------------------------------------------------------------
--
-- Records that the provider authoritatively reported a granted purchase as
-- refunded, voided, or revoked. Locked accounting policy:
--
--   * credits already consumed (committed usage rows) stay exactly as they
--     are — immutable history, never clawed back, never negative;
--   * the grant's unused credits stop being available, at once and forever;
--   * nothing else moves: the subscription's included allowance, every other
--     grant, and Salon Pilot adjustments are untouched;
--   * repeating the same revocation is a no-op that reports the same answer.
--
-- The model makes this trivially safe: remaining credits are derived per
-- grant and revoked grants are excluded from every sum, so "revoke the unused
-- part" is one flag and no arithmetic. A reservation already in flight on the
-- grant when the revocation lands may still commit or release on its own
-- terms; it is reported here as `inFlight` so the caller can see it.
--
-- Nothing calls this yet. Provider ingestion — Google Play RTDN
-- `oneTimeProductNotification` (type ONE_TIME_PRODUCT_CANCELED) or the
-- Voided Purchases API — belongs to a later hardening step; when it arrives
-- it needs only sha256(purchaseToken) and a reason to connect here.
create function public.revoke_top_up_purchase(
  p_purchase_reference text,
  p_reason text,
  p_revocation_reference text default null,
  p_revoked_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grant public.purchased_credit_grants%rowtype;
  v_committed integer := 0;
  v_reserved integer := 0;
begin
  if p_purchase_reference is null
     or p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PURCHASE_VERIFICATION_FAILED'
    );
  end if;

  if p_reason is null or p_reason not in ('refunded', 'voided', 'revoked') then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  select * into v_grant
  from public.purchased_credit_grants as g
  where g.purchase_reference = p_purchase_reference
  for update;

  if not found then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'TOP_UP_GRANT_NOT_FOUND'
    );
  end if;

  -- Serialize with this account's reservations, so the figures reported
  -- below are the ones the revocation actually froze.
  perform pg_advisory_xact_lock(hashtextextended(v_grant.user_id::text, 0));

  select
    count(*) filter (where l.status = 'committed'),
    count(*) filter (where l.status = 'reserved')
  into v_committed, v_reserved
  from public.usage_ledger as l
  where l.purchased_credit_grant_id = v_grant.id;

  if v_grant.revoked_at is null then
    update public.purchased_credit_grants as g
       set revoked_at = coalesce(p_revoked_at, timezone('utc', now())),
           revocation_reason = p_reason,
           revocation_reference = case
             when p_revocation_reference ~ '^[A-Za-z0-9._-]{1,64}$'
               then p_revocation_reference
             else null
           end
     where g.id = v_grant.id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'replayed', v_grant.revoked_at is not null,
    'grantId', v_grant.id,
    'quantityGranted', v_grant.quantity_granted,
    'consumed', v_committed,
    'inFlight', v_reserved,
    'revokedUnused',
      greatest(0, v_grant.quantity_granted - v_committed - v_reserved),
    'availableFromGrant', 0
  );
end;
$$;

revoke all on function public.revoke_top_up_purchase(
  text, text, text, timestamptz
) from public;
revoke all on function public.revoke_top_up_purchase(
  text, text, text, timestamptz
) from anon;
revoke all on function public.revoke_top_up_purchase(
  text, text, text, timestamptz
) from authenticated;
grant execute on function public.revoke_top_up_purchase(
  text, text, text, timestamptz
) to service_role;
