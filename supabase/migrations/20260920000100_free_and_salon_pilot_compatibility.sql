-- FaceTune SUB-12: first-class non-store entitlements — Free and Salon Pilot.
--
-- Additive except where stated. Every table, column, policy, and grant from a
-- prior migration is left in place. Four objects are redefined, each for a
-- reason given at the point of redefinition:
--
--   * `user_entitlements_one_current_idx` (SUB-2) — narrowed so the lifetime
--     Free entitlement can coexist with a live paid one.
--   * `public.handle_new_auth_user()` (Phase 4) — also provisions Free.
--   * `public.resolve_subscription_state()` (SUB-3) — deterministic precedence
--     between a Free entitlement and a store or admin-granted one.
--   * `public.activate_verified_google_play_subscription(...)` (SUB-10) — one
--     predicate: a purchase no longer retires the Free entitlement. Everything
--     else in that function is byte-for-byte what SUB-10 wrote.
--
-- Deliberately NOT done here:
--
--   * No admin grant, adjustment, suspend, or revoke RPC, and no public grant
--     function of any kind. Salon Pilot is created by an authorized admin
--     operation that belongs to the Web Admin phase. This migration makes the
--     entitlement fully representable and enforceable; it adds no way for a
--     client to obtain one. Test fixtures are inserted by the database owner
--     in a test database and nothing of the sort ships here.
--   * No Preview plan, no Preview product, no purchased top-up, no top-up
--     ledger. The adjustment ledger below is scoped to admin-granted
--     entitlements by construction and is not a credit wallet.
--   * No change to reserve / commit / release (SUB-4), to purchase
--     verification beyond the one predicate, or to RTDN reconciliation
--     (SUB-11). Nothing here reads a notification, contacts a provider, or
--     touches the Final Preview pipeline.
--   * No stored remaining balance. Free and Salon Pilot capacity is derived
--     from the ledger exactly as paid capacity is.
--
-- ---------------------------------------------------------------------------
-- The Free contract this migration enforces
-- ---------------------------------------------------------------------------
--
--     plan_code         free
--     billing_provider  none
--     allowance         1 AI Look, for the lifetime of the account
--     reset             never
--     auto_renew        false
--     store product     none — no purchase, restore, or RTDN can create one
--
-- One FaceTune account holds exactly one Free entitlement, provisioned once
-- when the account is created and never provisioned again. It is not a period
-- and it is not a plan the user "returns to" by being re-granted; it is a row
-- that exists for as long as the account does. Its usage ledger rows are its
-- lifetime history, so the one complimentary AI Look, once committed, stays
-- committed across month and year changes, sign-out, reinstall, new devices,
-- session refresh, purchase, renewal, cancellation, expiry, Restore Purchases,
-- and re-subscription — none of which touch the row.
--
-- ## Provisioning: the auth-user trigger
--
-- The mechanisms considered:
--
--   lazy provisioning in the resolver
--     Rejected. `resolve_subscription_state` is STABLE and read-only, and
--     making a read path write would give every client-facing read a side
--     effect to reason about.
--   provisioning inside `reserve_ai_look`
--     Rejected. A second mechanism beside the trigger would mean two places
--     that decide what a Free entitlement looks like.
--   a client-callable "initialize" RPC
--     Rejected. It would be a public grant function, idempotent or not, and
--     the account needs no client to ask for what every account gets.
--   the existing `handle_new_auth_user` trigger, plus a one-time backfill
--     Chosen. Phase 4 already provisions the profile and settings rows for
--     every account at the moment `auth.users` gains the row, before any
--     client query can run. Free is the same kind of fact — something every
--     account has — so it is provisioned in the same place and the same way.
--     One insert fires per account creation, and there is no request-driven
--     path that could race it.
--
-- Concurrency safety is nevertheless structural rather than procedural:
-- `user_entitlements_one_free_idx` makes a second Free row for an account
-- unrepresentable, and the provisioning insert is `on conflict do nothing`
-- against it, so the trigger, the backfill, and any future caller all
-- converge on the one row.
--
-- ## Coexistence with a paid or admin-granted entitlement
--
-- The precedence rule, stated once and implemented in
-- `resolve_subscription_state` below:
--
--     A store or admin-granted entitlement governs the account for as long as
--     it is IN FORCE: its status is active, grace_period, or suspended, its
--     term has started, and neither its billing period nor its expiry has
--     passed. Otherwise the account's lifetime Free entitlement governs. An
--     ended entitlement (expired or revoked, by status or by authoritative
--     date) only explains a refusal when the account has no Free row at all.
--
-- Consequences:
--
--   * A live paid plan is never shadowed by Free: it ranks first while it is
--     in force, and capacity is computed against it alone.
--   * Suspension ranks above Free. A held Google Play subscription or a
--     suspended Salon Pilot blocks generation outright; the complimentary AI
--     Look is not a way around an administrative or provider block.
--   * Pending does not rank above Free. A purchase that has not completed is
--     not yet a grant, and it must not shadow the Free entitlement
--     indefinitely if it never completes.
--   * Ending a paid plan — expiry, revocation, a lapsed period — returns the
--     account to Free with the Free ledger exactly as it was. If the
--     complimentary AI Look was used before or during the paid term it is
--     still used; if it was never used it is still available. Nothing is
--     recreated, because nothing was retired.
--   * No client input participates. The rule reads persisted rows and the
--     database clock.

-- ---------------------------------------------------------------------------
-- 1. Free is structurally singular per account
-- ---------------------------------------------------------------------------
--
-- Plain partial unique index. This is the invariant everything else leans on:
-- however a Free row comes to be inserted, there can be one.
create unique index if not exists user_entitlements_one_free_idx
  on public.user_entitlements (user_id)
  where plan_code = 'free';

-- SUB-2 allowed one active-or-grace entitlement per account, which was
-- correct while a purchase retired the Free row it superseded. A Free row
-- that is never retired must be able to sit beside a live paid one, so the
-- one-current rule now applies among the entitlements that supersede each
-- other — store-backed and admin-granted — and no longer counts Free.
-- Same name, so the SUB-10 comments that cite it still point at the right
-- object.
drop index if exists public.user_entitlements_one_current_idx;
create unique index user_entitlements_one_current_idx
  on public.user_entitlements (user_id)
  where status in ('active', 'grace_period') and plan_code <> 'free';

-- ---------------------------------------------------------------------------
-- 2. Free lifecycle guard
-- ---------------------------------------------------------------------------
--
-- Defence in depth behind the absent client write grant and the one-predicate
-- change to the activation function: no code path, including a future
-- privileged one with a bug, can retire, reset, re-plan, re-provider, or
-- re-size a Free row, or turn another row into one. The only columns a Free
-- row may change after provisioning are the bookkeeping ones (`version`,
-- `verified_at`, `updated_at`).
--
-- On insert, a Free row must be provisioned in the one shape the contract
-- allows: active, with the product's allowance and no adjustment. The SUB-2
-- `user_entitlements_free_shape` constraint already pins the provider and the
-- absence of dates; this adds what a CHECK cannot express because it reads
-- another table.
--
-- Suspending or revoking a Free entitlement is not a transition the current
-- contract defines, so it is refused here. A later approved revision that
-- adds one relaxes this trigger; nothing else needs to change.
create or replace function public.guard_free_entitlement_lifetime()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_product_allowance integer;
begin
  if tg_op = 'INSERT' then
    if new.plan_code <> 'free' then
      return new;
    end if;

    select p.base_ai_look_allowance
      into v_product_allowance
    from public.subscription_products as p
    where p.plan_code = 'free';

    if new.status <> 'active'
       or new.allowance_adjustment_total <> 0
       or v_product_allowance is null
       or new.base_ai_look_allowance <> v_product_allowance
    then
      raise exception
        'a Free entitlement is provisioned active, at the configured '
        'allowance, with no adjustment';
    end if;

    return new;
  end if;

  -- UPDATE
  if old.plan_code <> 'free' then
    if new.plan_code = 'free' then
      raise exception 'an entitlement cannot be converted into Free';
    end if;
    return new;
  end if;

  if new.plan_code <> old.plan_code
     or new.user_id <> old.user_id
     or new.status <> old.status
     or new.billing_provider <> old.billing_provider
     or new.base_ai_look_allowance <> old.base_ai_look_allowance
     or new.allowance_adjustment_total <> old.allowance_adjustment_total
     or new.starts_at <> old.starts_at
     or new.expires_at is distinct from old.expires_at
     or new.period_start is distinct from old.period_start
     or new.period_end is distinct from old.period_end
     or new.auto_renew <> old.auto_renew
     or new.provider_product_id is distinct from old.provider_product_id
     or new.provider_subscription_reference
        is distinct from old.provider_subscription_reference
  then
    raise exception
      'the Free entitlement is a lifetime record and cannot be reset, '
      'retired, or converted';
  end if;

  return new;
end;
$$;

drop trigger if exists user_entitlements_free_lifetime_guard
  on public.user_entitlements;
create trigger user_entitlements_free_lifetime_guard
before insert or update on public.user_entitlements
for each row execute function public.guard_free_entitlement_lifetime();

-- ---------------------------------------------------------------------------
-- 3. Provisioning
-- ---------------------------------------------------------------------------
--
-- The one definition of what a Free entitlement is. Called by the auth-user
-- trigger for every new account and by the backfill below for every existing
-- one. Idempotent by the unique index: a repeat call, from anywhere, returns
-- the existing row's id and writes nothing.
--
-- Takes the account as an argument because its callers — a trigger on
-- `auth.users` and a migration — have no request JWT. That makes it exactly
-- the kind of function no client role may hold, and none does: it is revoked
-- from `public`, `anon`, and `authenticated`, and not granted to
-- `service_role` either, because nothing in this project needs to provision
-- Free on demand. The database owner runs it from the trigger and from here.
--
-- The allowance is read from `subscription_products` rather than written as a
-- literal, so the product row stays the only place the number lives.
--
-- A missing or inactive Free product row is a broken deployment, not a
-- reason to refuse account creation: the function warns and returns null,
-- and the resolver's existing ENTITLEMENT_NOT_FOUND path refuses generation
-- for that account until the configuration is repaired. Nothing is granted
-- on a guess.
create or replace function public.provision_free_entitlement(p_user_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_allowance integer;
  v_id uuid;
begin
  if p_user_id is null then
    return null;
  end if;

  select p.base_ai_look_allowance
    into v_allowance
  from public.subscription_products as p
  where p.plan_code = 'free'
    and p.active;

  if not found then
    raise warning
      'free plan configuration missing; no Free entitlement provisioned';
    return null;
  end if;

  insert into public.user_entitlements (
    user_id,
    plan_code,
    status,
    billing_provider,
    base_ai_look_allowance,
    allowance_adjustment_total,
    auto_renew
  )
  values (
    p_user_id,
    'free',
    'active',
    'none',
    v_allowance,
    0,
    false
  )
  on conflict (user_id) where plan_code = 'free' do nothing
  returning id into v_id;

  if v_id is null then
    select e.id
      into v_id
    from public.user_entitlements as e
    where e.user_id = p_user_id
      and e.plan_code = 'free';
  end if;

  return v_id;
end;
$$;

revoke all on function public.provision_free_entitlement(uuid) from public;
revoke all on function public.provision_free_entitlement(uuid) from anon;
revoke all on function public.provision_free_entitlement(uuid)
  from authenticated;

-- Phase 4's account bootstrap, with Free added beside the profile and
-- settings rows. The profile and settings inserts are unchanged.
create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_name text;
begin
  profile_name := nullif(
    btrim(
      coalesce(
        new.raw_user_meta_data ->> 'display_name',
        new.raw_user_meta_data ->> 'full_name',
        ''
      )
    ),
    ''
  );

  insert into public.profiles (auth_user_id, display_name)
  values (new.id, profile_name)
  on conflict (auth_user_id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  -- SUB-12: every account holds its one lifetime Free entitlement from the
  -- moment it exists. Idempotent, and never repeated for an account that
  -- already has one.
  perform public.provision_free_entitlement(new.id);

  return new;
end;
$$;

-- The trigger itself is left as Phase 4 created it: `on_auth_user_created`,
-- after insert on `auth.users`, calling the function just replaced.

-- ---------------------------------------------------------------------------
-- 4. Backfill accounts that predate this migration
-- ---------------------------------------------------------------------------
--
-- Every existing account receives its one Free entitlement, in the same shape
-- and through the same function as a new account. Deterministic, idempotent
-- (re-running writes nothing), and it does not touch any other row: paid
-- entitlements keep their status, usage ledger rows keep their entitlement,
-- and nothing is expired, recreated, or re-counted.
--
-- Classification of the accounts this reaches, and what each gets:
--
--   * a brand-new account with no history            — one Free row, unused.
--   * an account with no entitlement but previews
--     made before the ledger existed                 — one Free row, unused.
--     Those previews were never reserved or committed, so there is no ledger
--     event to attribute them to, and the ledger records real events only.
--     The account has never held a Free entitlement, so this is its one
--     lifetime grant, not an additional one.
--   * a current paid subscriber                       — one Free row beside
--     the paid one. The paid one governs (it is in force); Free is what the
--     account returns to when it ends.
--   * an expired or cancelled-then-lapsed subscriber  — one Free row, which
--     now governs.
--   * a historical paid subscriber with committed
--     paid usage                                      — one Free row; the
--     paid usage stays on the paid entitlement and is not counted against
--     Free.
--   * a Salon Pilot account                           — none exist before
--     this migration; a later grant sits beside the Free row exactly as a
--     paid one does.
--
-- No account receives more than one, now or later, because the index forbids
-- it.
do $$
begin
  perform public.provision_free_entitlement(u.id)
  from auth.users as u;
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. public.resolve_subscription_state() — precedence between entitlements
-- ---------------------------------------------------------------------------
--
-- The SUB-3 resolver, with one change: which row governs when an account
-- holds more than one. Everything after the row is chosen — the allowance
-- arithmetic, period membership by `reserved_at`, the refusal order, the
-- response shape — is exactly what SUB-3 wrote and SUB-4 built on. The
-- function stays argument-free, STABLE, `security definer` with a pinned
-- search path, and reads the account from the request JWT.
--
-- One field is added to the response: `publiclyPurchasable`, from the plan's
-- product configuration, so a client can tell a non-store entitlement (Free,
-- Salon Pilot) from a store one without inferring it from the plan name.
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
  --          and expiry, where present, not yet passed. At most one of these
  --          can be active or in grace (`user_entitlements_one_current_idx`);
  --          the status order below decides among a suspended one and a live
  --          one, and `starts_at` decides among several suspended ones.
  -- Rank 1 — the account's lifetime Free entitlement.
  -- Rank 2 — everything else: ended store or admin entitlements (expired or
  --          revoked, by status or by date) and pending purchases. These only
  --          govern, and only to explain the refusal, when the account holds
  --          no Free row — which after SUB-12 means the Free product
  --          configuration is missing.
  --
  -- Suspended outranks Free so that a provider hold or an administrative
  -- suspension blocks generation outright rather than leaving the
  -- complimentary AI Look as a way around it. Pending does not outrank Free:
  -- a purchase that has not completed is not yet a grant, and must not
  -- shadow Free for as long as it stays incomplete. Ended entitlements do
  -- not outrank Free either, which is what lets an account return to its
  -- Free entitlement — used or unused, exactly as it was left — when a paid
  -- term ends.
  --
  -- Dates are compared against the database clock, never a client's. This
  -- is the same authoritative-date rule the refusal order below already
  -- applies: a lapsed period ends an entitlement's precedence the moment it
  -- ends its authorization, without waiting for a provider notification to
  -- move the stored status.
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
    -- No entitlement has been provisioned for this account. After SUB-12
    -- every account is provisioned a Free entitlement at creation and every
    -- earlier account was backfilled, so this is the state of a broken
    -- deployment rather than of a new user. Free is the default *plan*, but
    -- a plan is not a grant: without a persisted row there is nothing to
    -- charge usage against, so generation is refused rather than silently
    -- allowed against an imaginary allowance.
    select
      p.display_name,
      p.base_ai_look_allowance,
      p.reset_policy,
      p.publicly_purchasable
    into v_display_name, v_effective, v_reset_policy, v_purchasable
    from public.subscription_products as p
    where p.plan_code = 'free';

    return jsonb_build_object(
      'hasEntitlement', false,
      'planCode', 'free',
      'planDisplayName', v_display_name,
      'entitlementStatus', null,
      'billingProvider', 'none',
      'publiclyPurchasable', coalesce(v_purchasable, false),
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

  select p.display_name, p.reset_policy, p.publicly_purchasable
    into v_display_name, v_reset_policy, v_purchasable
  from public.subscription_products as p
  where p.plan_code = v_ent.plan_code;

  -- Effective allowance = base + authorized adjustments, floored at zero.
  -- Mirrors the shared contract and the SUB-1 domain exactly. Never stored.
  -- For Salon Pilot the adjustment total is maintained by the audited
  -- adjustment ledger below; for Free it is always zero.
  v_effective := greatest(
    0,
    v_ent.base_ai_look_allowance + v_ent.allowance_adjustment_total
  );

  -- Usage is counted against the *current* period only.
  --
  -- A new verified period therefore starts from zero without deleting or
  -- rewriting a single historical row: the prior period stays intact and
  -- auditable, and nothing rolls over. One-time and admin-granted entitlements
  -- have no period, so every row they own counts for their whole life — which
  -- is precisely what makes the Free AI Look a lifetime allowance and the
  -- Salon Pilot grant a total rather than a monthly one.
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

  -- Authorization, most specific refusal first. Status is checked before
  -- capacity, so remaining allowance never overrides a suspended, revoked,
  -- expired, or pending entitlement.
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
    'publiclyPurchasable', coalesce(v_purchasable, false),
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

-- The response still omits `provider_subscription_reference` and the
-- concurrency `version`, for the reasons SUB-3 gave. Grants are unchanged:
-- `authenticated` may execute; `public` and `anon` were revoked in SUB-3 and
-- `create or replace` preserves the function's ACL.

-- ---------------------------------------------------------------------------
-- 6. public.activate_verified_google_play_subscription(...) — one predicate
-- ---------------------------------------------------------------------------
--
-- Redefined verbatim from SUB-10 with a single addition to the statement that
-- retires a superseded entitlement: `and e.plan_code <> 'free'`. The
-- surrounding comment in the body explains why. Nothing else in the function
-- — argument shape, product → plan resolution, provider state mapping, period
-- derivation, purchase-reference resolution, theft checks, the upsert of the
-- verification record, the response, the exception handler — is changed, and
-- the grants (`service_role` only) are preserved by `create or replace`.
--
-- Free and Salon Pilot remain unreachable from here for the reasons SUB-10
-- gave: a plan is resolved only from a `provider_product_id` on a row that is
-- `publicly_purchasable` and `google_play`, neither has one, and the
-- verification table's own check constraint rejects either plan code.
create or replace function public.activate_verified_google_play_subscription(
  p_user_id uuid,
  p_provider_product_id text,
  p_purchase_reference text,
  p_subscription_state text,
  -- The provider's `startTime`: when the *subscription* began, which is not
  -- the same thing as when the current billing period began. See the period
  -- derivation below.
  p_subscription_start timestamptz default null,
  -- The provider's `expiryTime` for the line item: when the current period
  -- ends.
  p_period_end timestamptz default null,
  p_auto_renew boolean default false,
  p_linked_purchase_reference text default null,
  p_test_purchase boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_plan_code text;
  v_base_allowance integer;
  v_status text;
  v_period_start timestamptz;
  v_period_end timestamptz;
  v_auto_renew boolean := coalesce(p_auto_renew, false);
  v_entitlement public.user_entitlements%rowtype;
  v_entitlement_id uuid;
  v_found_entitlement boolean := false;
  v_existing_owner uuid;
begin
  -- -------------------------------------------------------------------------
  -- Argument shape
  -- -------------------------------------------------------------------------
  --
  -- Failures are returned, not raised, following `reserve_ai_look`. A raised
  -- exception would abort the caller's transaction and surface a Postgres
  -- error string through PostgREST; a returned code keeps the vocabulary the
  -- same one the client already understands.
  if p_user_id is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  if p_purchase_reference is null
     or p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PURCHASE_VERIFICATION_FAILED'
    );
  end if;

  if p_linked_purchase_reference is not null
     and (
       p_linked_purchase_reference !~ '^[0-9a-f]{64}$'
       or p_linked_purchase_reference = p_purchase_reference
     ) then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PURCHASE_VERIFICATION_FAILED'
    );
  end if;

  if p_provider_product_id is null
     or char_length(btrim(p_provider_product_id)) = 0 then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_PLAN_CODE');
  end if;

  -- Serialize per account, exactly as `reserve_ai_look` does. Two verifications
  -- arriving together for the same user — a client retry racing the original,
  -- or a restore racing a fresh purchase — must not both insert an entitlement.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text, 0));

  -- -------------------------------------------------------------------------
  -- Provider product → internal plan. Server-owned, never client-supplied.
  -- -------------------------------------------------------------------------
  --
  -- The lookup itself is the guard that a purchase can only ever produce a
  -- publicly purchasable, store-backed plan: Free and Salon Pilot carry no
  -- provider product id, so no value of `p_provider_product_id` can select
  -- them. An unrecognised product is refused rather than defaulted.
  select p.plan_code, p.base_ai_look_allowance
    into v_plan_code, v_base_allowance
  from public.subscription_products as p
  where p.provider_product_id = btrim(p_provider_product_id)
    and p.active
    and p.publicly_purchasable
    and p.billing_provider = 'google_play';

  if not found then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_PLAN_CODE');
  end if;

  -- -------------------------------------------------------------------------
  -- Provider subscription state → entitlement status
  -- -------------------------------------------------------------------------
  --
  -- Values and semantics are Google's, taken from the SubscriptionState enum
  -- of `purchases.subscriptionsv2`. An unknown or unspecified state is refused
  -- rather than guessed: a state this code has never heard of must not be
  -- allowed to fall through into a grant.
  v_status := case p_subscription_state
    when 'SUBSCRIPTION_STATE_ACTIVE' then 'active'
    -- Google keeps the user entitled while payment recovery is in progress.
    when 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' then 'grace_period'
    -- Auto-renewal is off, but the paid period is still running. Cancelled is
    -- not expired; the period end below is what ends access.
    when 'SUBSCRIPTION_STATE_CANCELED' then 'active'
    -- Account hold and pause both mean the user loses access now.
    when 'SUBSCRIPTION_STATE_ON_HOLD' then 'suspended'
    when 'SUBSCRIPTION_STATE_PAUSED' then 'suspended'
    -- Created but never paid for. Not a grant of anything.
    when 'SUBSCRIPTION_STATE_PENDING' then 'pending'
    when 'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED' then 'expired'
    when 'SUBSCRIPTION_STATE_EXPIRED' then 'expired'
    else null
  end;

  if v_status is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  -- Auto-renew is a provider fact, but a cancelled or ended subscription can
  -- never be renewing regardless of what was passed.
  if p_subscription_state in (
    'SUBSCRIPTION_STATE_CANCELED',
    'SUBSCRIPTION_STATE_EXPIRED',
    'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED'
  ) then
    v_auto_renew := false;
  end if;

  -- -------------------------------------------------------------------------
  -- Billing period
  -- -------------------------------------------------------------------------
  --
  -- The schema requires the period to be a well-formed pair or absent
  -- entirely. A pending purchase has no verified period yet, and a malformed
  -- or inverted pair is dropped rather than stored, because a bad period would
  -- corrupt every capacity calculation that hangs off it.
  --
  -- ## Why the start is derived rather than taken
  --
  -- Google's `startTime` is when the subscription *began*, and it does not
  -- move when the subscription renews — only `expiryTime` advances. Storing it
  -- as `period_start` would therefore be correct for a first purchase and
  -- silently wrong afterwards: SUB-3 counts usage from `period_start`, so a
  -- subscription renewed three times would count three months of usage against
  -- one month's allowance, and the user would appear to have spent an
  -- allowance they had not.
  --
  -- The current period is one billing interval back from the end. Every
  -- purchasable plan is monthly — `subscription_products` accepts no other
  -- `billing_interval` — so one month is the interval, and `greatest` keeps a
  -- first period anchored to the real subscription start rather than to a
  -- computed instant slightly before it.
  v_period_end := p_period_end;
  v_period_start := case
    when v_period_end is null then null
    when p_subscription_start is null then v_period_end - interval '1 month'
    else greatest(p_subscription_start, v_period_end - interval '1 month')
  end;

  if v_status = 'pending'
     or v_period_start is null
     or v_period_end is null
     or v_period_end <= v_period_start then
    v_period_start := null;
    v_period_end := null;
  end if;

  -- A live entitlement must have a period to be live within. Without one there
  -- is nothing to expire and the allowance would never reset.
  if v_status in ('active', 'grace_period') and v_period_end is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  -- -------------------------------------------------------------------------
  -- Find the entitlement this purchase governs
  -- -------------------------------------------------------------------------
  --
  -- Resolution order matters. The purchase's own reference wins, so repeat
  -- verification of the same purchase always lands on the same row. Failing
  -- that, the reference the provider said this purchase replaced is followed,
  -- which is what keeps an upgrade or a resubscribe from creating a second
  -- entitlement beside the one it supersedes.
  select * into v_entitlement
  from public.user_entitlements as e
  where e.provider_subscription_reference = p_purchase_reference;
  v_found_entitlement := found;

  if not v_found_entitlement and p_linked_purchase_reference is not null then
    select * into v_entitlement
    from public.user_entitlements as e
    where e.provider_subscription_reference = p_linked_purchase_reference;
    v_found_entitlement := found;
  end if;

  -- A purchase already bound to a different account is a stolen or replayed
  -- token. Refuse, and change nothing.
  if v_found_entitlement and v_entitlement.user_id <> p_user_id then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  -- The same guard for the verification record, which may exist even when the
  -- entitlement it pointed at has since been removed.
  select v.user_id into v_existing_owner
  from public.provider_purchase_verifications as v
  where v.purchase_reference = p_purchase_reference;

  if v_existing_owner is not null and v_existing_owner <> p_user_id then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
  end if;

  if v_found_entitlement then
    v_entitlement_id := v_entitlement.id;
  end if;

  -- -------------------------------------------------------------------------
  -- Retire any other currently-governing store or admin entitlement
  -- -------------------------------------------------------------------------
  --
  -- `user_entitlements_one_current_idx` permits one active-or-grace row per
  -- account among the entitlements that can supersede one another. Superseding
  -- the previous one is therefore structurally required, not a lifecycle
  -- policy choice: without it, upgrading from a prior subscription whose
  -- replacement Google did not link would violate the index and fail the whole
  -- activation.
  --
  -- The retired row is marked expired and kept. Its usage ledger rows stay
  -- attached to it, so the previous period's history remains intact and
  -- auditable, and nothing rolls over.
  --
  -- SUB-12: the lifetime Free entitlement is not retired. It is excluded from
  -- the index, a paid entitlement outranks it in `resolve_subscription_state`
  -- for as long as the paid one is in force, and it is the entitlement the
  -- account falls back to once the paid one ends. Retiring it here would spend
  -- the user's unused complimentary AI Look on the act of subscribing, which
  -- the Source of Truth forbids; the Free lifecycle guard trigger would also
  -- reject the write and fail the activation.
  if v_status in ('active', 'grace_period') then
    update public.user_entitlements as e
       set status = 'expired',
           auto_renew = false,
           version = e.version + 1
     where e.user_id = p_user_id
       and e.status in ('active', 'grace_period')
       and e.plan_code <> 'free'
       and (v_entitlement_id is null or e.id <> v_entitlement_id);
  end if;

  -- -------------------------------------------------------------------------
  -- Write the entitlement
  -- -------------------------------------------------------------------------
  if v_entitlement_id is null then
    insert into public.user_entitlements (
      user_id,
      plan_code,
      status,
      billing_provider,
      provider_product_id,
      provider_subscription_reference,
      period_start,
      period_end,
      starts_at,
      auto_renew,
      base_ai_look_allowance,
      verified_at
    )
    values (
      p_user_id,
      v_plan_code,
      v_status,
      'google_play',
      btrim(p_provider_product_id),
      p_purchase_reference,
      v_period_start,
      v_period_end,
      -- The term of the grant starts when the subscription did, not when the
      -- current period did. `starts_at` is never rewritten on renewal.
      coalesce(p_subscription_start, v_period_start, v_now),
      v_auto_renew,
      v_base_allowance,
      v_now
    )
    returning id into v_entitlement_id;
  else
    -- `allowance_adjustment_total` is deliberately not written. An authorized
    -- administrative adjustment belongs to the account, not to the purchase,
    -- and a renewal must not silently erase one.
    update public.user_entitlements as e
       set plan_code = v_plan_code,
           status = v_status,
           billing_provider = 'google_play',
           provider_product_id = btrim(p_provider_product_id),
           provider_subscription_reference = p_purchase_reference,
           period_start = v_period_start,
           period_end = v_period_end,
           auto_renew = v_auto_renew,
           base_ai_look_allowance = v_base_allowance,
           verified_at = v_now,
           version = e.version + 1
     where e.id = v_entitlement_id;
  end if;

  -- -------------------------------------------------------------------------
  -- Record the verification
  -- -------------------------------------------------------------------------
  --
  -- Upsert on the purchase reference, so verifying the same purchase again
  -- refreshes what the provider last said instead of accumulating rows.
  insert into public.provider_purchase_verifications (
    user_id,
    billing_provider,
    provider_product_id,
    plan_code,
    purchase_reference,
    linked_purchase_reference,
    subscription_state,
    test_purchase,
    entitlement_id,
    verified_at
  )
  values (
    p_user_id,
    'google_play',
    btrim(p_provider_product_id),
    v_plan_code,
    p_purchase_reference,
    p_linked_purchase_reference,
    p_subscription_state,
    coalesce(p_test_purchase, false),
    v_entitlement_id,
    v_now
  )
  on conflict (purchase_reference) do update
    set provider_product_id = excluded.provider_product_id,
        plan_code = excluded.plan_code,
        linked_purchase_reference = excluded.linked_purchase_reference,
        subscription_state = excluded.subscription_state,
        test_purchase = excluded.test_purchase,
        entitlement_id = excluded.entitlement_id,
        verified_at = excluded.verified_at;

  -- A deliberately small answer. The authoritative subscription state is read
  -- back by the caller through `resolve_subscription_state()` as the user, so
  -- there is exactly one shape of "what am I entitled to" in the system and
  -- this is not a second one.
  return jsonb_build_object(
    'ok', true,
    'planCode', v_plan_code,
    'entitlementStatus', v_status,
    'entitlementId', v_entitlement_id,
    'verifiedAt', v_now
  );
exception
  when unique_violation then
    -- Belt and braces behind the advisory lock. If two verifications for the
    -- same purchase ever did race past it, the unique constraint on
    -- `provider_subscription_reference` or `purchase_reference` decides, and
    -- the loser reports a benign conflict rather than a server error. Nothing
    -- is granted twice because the winner already wrote the single row.
    return jsonb_build_object(
      'ok', false, 'errorCode', 'CONCURRENT_MODIFICATION'
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Salon Pilot — the audited allowance adjustment ledger
-- ---------------------------------------------------------------------------
--
-- The Salon Pilot contract this migration makes enforceable:
--
--     plan_code             salon_pilot
--     billing_provider      admin_granted
--     publicly_purchasable  false
--     base allowance        30 (the product default; per grant)
--     adjustment            audited, admin only
--     auto_renew            false
--     reset                 never
--     expires_at            required, admin-controlled
--     store product         none
--
-- SUB-2 already pins all of that shape: `user_entitlements_salon_pilot_shape`
-- requires `admin_granted`, a non-null `expires_at`, no auto-renew, no period,
-- and no provider reference, and `user_entitlements_admin_granted_is_salon_pilot`
-- keeps `admin_granted` from being used for anything else. SUB-3 already
-- refuses generation on `expires_at`, on `suspended`, and on `revoked`, before
-- it looks at capacity. What was missing is the audit trail behind
-- `allowance_adjustment_total`, which SUB-2 created as a bare integer with the
-- note that the base and the adjustment are kept apart *so the adjustment
-- stays auditable* — and nothing yet made it so.
--
-- ## What this table is
--
-- One row per administrative allowance change, in the shape the Shared
-- Contract gives for an adjustment: target, administrator, type, amount,
-- reason, idempotency key, time. `user_entitlements.allowance_adjustment_total`
-- is maintained from these rows by the trigger below and cannot be written
-- any other way, so the total on an entitlement is always the sum of an
-- audited history. "Started at 30, an admin added 10" is recorded as exactly
-- that; committed usage is never touched.
--
-- ## What this table is not
--
-- It is not a purchased-credit ledger and cannot become one. Rows may only
-- target an `admin_granted` entitlement (the trigger refuses any other), they
-- carry an administrator and a reason rather than a provider and a purchase
-- reference, and they change the entitlement's *allowance*, not a balance
-- that survives it. Purchased top-up credits, when a later phase adds them,
-- need provider verification, purchase-token idempotency, capability
-- provenance, and a consumption order relative to subscription allowance —
-- none of which belongs on an admin adjustment, and none of which is here.
-- Keeping the two apart is what stops an admin correction and a paid credit
-- from collapsing into one untraceable number.
--
-- ## What this migration does not add
--
-- Any way to insert a row from a client. There is no RPC, no policy, and no
-- grant: `authenticated` cannot read or write this table, and the future
-- admin write path (Web Admin, via a `security definer` function that checks
-- admin authorization) is the only intended writer. A test inserts rows as
-- the database owner in a test database.
create table if not exists public.entitlement_allowance_adjustments (
  id uuid primary key default gen_random_uuid(),
  entitlement_id uuid not null,
  target_user_id uuid not null references auth.users(id) on delete cascade,
  -- The administrator who made the change. Required at insert (enforced by
  -- the trigger, since a CHECK cannot distinguish an insert from the
  -- referential SET NULL that runs if that account is later deleted). The
  -- audit row outlives the administrator's account; the fact that a
  -- now-deleted admin made the change is still a fact.
  admin_user_id uuid references auth.users(id) on delete set null,
  adjustment_type text not null,
  -- Signed. Positive for an increase, negative for a decrease, never zero.
  -- Sign and type must agree so a row cannot say one thing and do another.
  amount integer not null,
  reason text not null,
  -- Repeat-safe identity for one intended business action. Scoped to the
  -- entitlement so keys minted by different admin sessions cannot collide
  -- across accounts.
  idempotency_key text not null,
  created_at timestamptz not null default timezone('utc', now()),

  -- The same composite owner key the usage ledger uses: an adjustment cannot
  -- be attached to an entitlement another account owns.
  constraint entitlement_allowance_adjustments_entitlement_owner_fk
    foreign key (entitlement_id, target_user_id)
    references public.user_entitlements(id, user_id)
    on delete cascade,

  constraint entitlement_allowance_adjustments_idempotency_unique
    unique (entitlement_id, idempotency_key),

  constraint entitlement_allowance_adjustments_type_valid
    check (adjustment_type in ('increase_allowance', 'decrease_allowance')),
  constraint entitlement_allowance_adjustments_amount_sign_agrees
    check (
      (adjustment_type = 'increase_allowance' and amount > 0)
      or (adjustment_type = 'decrease_allowance' and amount < 0)
    ),
  constraint entitlement_allowance_adjustments_reason_not_blank
    check (char_length(btrim(reason)) between 1 and 500),
  constraint entitlement_allowance_adjustments_key_not_blank
    check (char_length(btrim(idempotency_key)) between 1 and 128)
);

create index if not exists entitlement_allowance_adjustments_entitlement_idx
  on public.entitlement_allowance_adjustments (entitlement_id, created_at);
create index if not exists entitlement_allowance_adjustments_target_idx
  on public.entitlement_allowance_adjustments (target_user_id);

-- ---------------------------------------------------------------------------
-- 8. Applying an adjustment
-- ---------------------------------------------------------------------------
--
-- BEFORE INSERT, so an adjustment that would be invalid is refused before any
-- audit row exists for it. Under the same per-account advisory lock that
-- `reserve_ai_look` takes, so an adjustment and a reservation for the same
-- account serialize: the reduction check below sees every reservation that
-- has been taken, and a reservation that starts after this commits sees the
-- new allowance.
--
-- Safe reduction follows the Shared Contract: the effective allowance after
-- the change must still cover committed usage AND currently reserved usage.
-- A reduction that would strand a held reservation or drive available
-- capacity negative is rejected outright. Nothing is ever deleted to make a
-- reduction fit.
--
-- The write to `allowance_adjustment_total` is made under a transaction-local
-- setting that the total guard (section 9) checks, so this trigger is the one
-- path that can move the total.
create or replace function public.apply_entitlement_allowance_adjustment()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ent public.user_entitlements%rowtype;
  v_committed integer := 0;
  v_reserved integer := 0;
  v_effective_after integer;
begin
  if new.admin_user_id is null then
    raise exception
      'an allowance adjustment must record the administrator who made it';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.target_user_id::text, 0));

  select * into v_ent
  from public.user_entitlements as e
  where e.id = new.entitlement_id
    and e.user_id = new.target_user_id
  for update;

  if not found then
    raise exception 'adjustment target entitlement not found';
  end if;

  -- Admin-editable allowance is a property of how the entitlement was
  -- granted, not of its plan name: an administrator may adjust what an
  -- administrator granted. Store-backed and Free entitlements are refused.
  if v_ent.billing_provider <> 'admin_granted' then
    raise exception
      'only an admin-granted entitlement has an admin-editable allowance';
  end if;

  v_effective_after :=
    v_ent.base_ai_look_allowance
    + v_ent.allowance_adjustment_total
    + new.amount;

  -- Admin-granted entitlements have no period, so every ledger row they own
  -- counts, exactly as the resolver counts them.
  select
    count(*) filter (where u.status = 'committed'),
    count(*) filter (where u.status = 'reserved')
  into v_committed, v_reserved
  from public.usage_ledger as u
  where u.entitlement_id = v_ent.id;

  if v_effective_after < v_committed + v_reserved then
    raise exception
      'allowance reduction would invalidate committed or reserved usage';
  end if;

  perform set_config('facetune.applying_allowance_adjustment', 'on', true);

  update public.user_entitlements as e
     set allowance_adjustment_total = e.allowance_adjustment_total + new.amount,
         version = e.version + 1
   where e.id = v_ent.id;

  perform set_config('facetune.applying_allowance_adjustment', '', true);

  return new;
end;
$$;

drop trigger if exists entitlement_allowance_adjustments_apply
  on public.entitlement_allowance_adjustments;
create trigger entitlement_allowance_adjustments_apply
before insert on public.entitlement_allowance_adjustments
for each row execute function public.apply_entitlement_allowance_adjustment();

-- Adjustment rows are immutable history, like committed usage. The single
-- permitted change is the referential SET NULL of `admin_user_id` when that
-- account is deleted. There is deliberately no DELETE trigger, for the
-- reason given on `usage_ledger` in SUB-2: it would abort the `auth.users`
-- cascade. Deletion is prevented by privilege instead.
create or replace function public.reject_allowance_adjustment_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id = old.id
    and new.entitlement_id = old.entitlement_id
    and new.target_user_id = old.target_user_id
    and new.adjustment_type = old.adjustment_type
    and new.amount = old.amount
    and new.reason = old.reason
    and new.idempotency_key = old.idempotency_key
    and new.created_at = old.created_at
    and (
      new.admin_user_id is not distinct from old.admin_user_id
      or (old.admin_user_id is not null and new.admin_user_id is null)
    )
  then
    return new;
  end if;

  raise exception 'allowance adjustments are immutable audit records';
end;
$$;

drop trigger if exists entitlement_allowance_adjustments_immutable
  on public.entitlement_allowance_adjustments;
create trigger entitlement_allowance_adjustments_immutable
before update on public.entitlement_allowance_adjustments
for each row execute function public.reject_allowance_adjustment_mutation();

-- ---------------------------------------------------------------------------
-- 9. The adjustment total moves only through the ledger
-- ---------------------------------------------------------------------------
--
-- Closes the loop: a direct write to `allowance_adjustment_total` from any
-- path other than the trigger above is refused, so the column is always the
-- sum of the audited rows and a "silent numeric mutation" is not possible
-- even for a privileged caller. The Free guard already refuses any change
-- to the column on a Free row; this covers every other row.
create or replace function public.guard_allowance_adjustment_total()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.allowance_adjustment_total <> old.allowance_adjustment_total
     and coalesce(
       current_setting('facetune.applying_allowance_adjustment', true), ''
     ) <> 'on'
  then
    raise exception
      'allowance_adjustment_total is maintained by the allowance adjustment '
      'ledger and cannot be written directly';
  end if;

  return new;
end;
$$;

drop trigger if exists user_entitlements_adjustment_total_guard
  on public.user_entitlements;
create trigger user_entitlements_adjustment_total_guard
before update on public.user_entitlements
for each row execute function public.guard_allowance_adjustment_total();

-- ---------------------------------------------------------------------------
-- 10. Access
-- ---------------------------------------------------------------------------
--
-- The same posture as `provider_notification_events`: an administrative audit
-- table with no owner-facing half. The user sees the *result* — effective
-- allowance and adjustment total — through `resolve_subscription_state`;
-- the trail of who changed what and why is admin data. RLS is enabled with no
-- policy, and no privilege is granted to any client role.
alter table public.entitlement_allowance_adjustments enable row level security;

revoke all on table public.entitlement_allowance_adjustments from anon;
revoke all on table public.entitlement_allowance_adjustments from authenticated;

-- Explicit restatement of the ACLs that `create or replace` preserved above,
-- so this file is self-evidently correct about who may call what.
revoke all on function public.resolve_subscription_state() from public;
revoke all on function public.resolve_subscription_state() from anon;
grant execute on function public.resolve_subscription_state() to authenticated;

revoke all on function public.activate_verified_google_play_subscription(
  uuid, text, text, text, timestamptz, timestamptz, boolean, text, boolean
) from public;
revoke all on function public.activate_verified_google_play_subscription(
  uuid, text, text, text, timestamptz, timestamptz, boolean, text, boolean
) from anon;
revoke all on function public.activate_verified_google_play_subscription(
  uuid, text, text, text, timestamptz, timestamptz, boolean, text, boolean
) from authenticated;
grant execute on function public.activate_verified_google_play_subscription(
  uuid, text, text, text, timestamptz, timestamptz, boolean, text, boolean
) to service_role;
