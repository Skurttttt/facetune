-- FaceTune SUB-10: server-side Google Play purchase verification and
-- entitlement activation.
--
-- Purely additive. No existing table, column, constraint, policy, grant, or
-- trigger from a prior migration is altered or dropped. The one write to
-- existing data is filling `subscription_products.provider_product_id`, which
-- SUB-2 created as NULL and explicitly reserved for this phase.
--
-- Deliberately NOT done here:
--
--   * No renewal, cancellation, grace, hold, refund, or revocation
--     reconciliation loop. This migration records the provider state observed
--     at verification time and nothing more. Real Time Developer Notifications
--     and lifecycle reconciliation are SUB-11.
--
--   * No Free entitlement provisioning (SUB-12), no admin grant path, and no
--     Salon Pilot handling. Salon Pilot cannot be reached from here at all —
--     see the plan resolution in the activation function.
--
--   * No second capacity or allowance calculator. `resolve_subscription_state`
--     from SUB-3 remains the only place that answers "what am I entitled to".
--     This migration writes the entitlement; it never reports on it.
--
--   * No storage of a raw purchase token anywhere. See the note on
--     `purchase_reference` below.

-- ---------------------------------------------------------------------------
-- 1. Bind the approved Google Play products to their plans
-- ---------------------------------------------------------------------------
--
-- SUB-2 left `provider_product_id` NULL with the note that SUB-10 populates it
-- and that the values must never be guessed. These three are the approved
-- store product identifiers carried by the phase authority and already
-- compiled into the client's `StoreProductCatalog`.
--
-- This is the *server-owned* half of the mapping the Source of Truth requires:
-- a verified purchase names a provider product, and only this table decides
-- which internal plan that product grants. The client's copy of the same ids
-- exists solely so the billing SDK has something to query with.
--
-- `where provider_product_id is null` so re-running the migration cannot
-- overwrite a later authorized configuration change, matching the
-- `on conflict do nothing` posture of the SUB-2 seed.
update public.subscription_products
   set provider_product_id = 'facetune_plus'
 where plan_code = 'plus'
   and provider_product_id is null;

update public.subscription_products
   set provider_product_id = 'facetune_pro'
 where plan_code = 'pro'
   and provider_product_id is null;

update public.subscription_products
   set provider_product_id = 'facetune_salon_pro'
 where plan_code = 'salon_pro'
   and provider_product_id is null;

-- Free and Salon Pilot keep a NULL `provider_product_id` forever. They are not
-- store products, and the SUB-2 constraints already forbid marking either
-- publicly purchasable. Nothing below can resolve a plan without a provider
-- product id, so neither can be reached by a purchase.

-- ---------------------------------------------------------------------------
-- 2. Verified purchase record
-- ---------------------------------------------------------------------------
--
-- One row per provider purchase this backend has verified. It exists for three
-- reasons: replay detection, cross-account theft detection, and an audit trail
-- of what the provider said at the moment access was granted.
--
-- ## What is deliberately not stored
--
-- The raw purchase token is never written here or anywhere else in the
-- database. A purchase token is a replayable credential against Google's API,
-- and a table of them would be a far more attractive target than the
-- entitlements themselves. `purchase_reference` is a SHA-256 hash of the token
-- computed in the Edge Function, which preserves every property this table
-- needs — equality, uniqueness, linkage — while being useless to an attacker
-- who obtains it.
--
-- The raw provider response is also not stored. It carries the subscriber's
-- Google profile (`subscribeWithGoogleInfo` can include name and email), and
-- none of that is needed to decide an entitlement.
create table if not exists public.provider_purchase_verifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  billing_provider text not null default 'google_play',
  provider_product_id text not null,
  plan_code text not null,

  -- SHA-256 of the provider purchase token, lowercase hex. Never the token.
  purchase_reference text not null,

  -- SHA-256 of the provider's `linkedPurchaseToken`, when the provider said
  -- this purchase replaced an earlier one (an upgrade, downgrade, or
  -- resubscribe). It is how a replacement finds the entitlement it supersedes
  -- instead of creating a second one.
  linked_purchase_reference text,

  -- The provider's own state string, recorded verbatim for audit. It is not
  -- re-interpreted anywhere outside the activation function below.
  subscription_state text not null,

  -- Whether Google reported this as a license-tester purchase. Recorded so a
  -- test grant is always distinguishable from a paid one after the fact.
  test_purchase boolean not null default false,

  entitlement_id uuid,
  verified_at timestamptz not null default timezone('utc', now()),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  -- The replay anchor. Verifying the same purchase twice updates this row
  -- rather than inserting a second one, so a client retry, a duplicate
  -- provider callback, and a restore all converge on one record.
  constraint provider_purchase_verifications_reference_unique
    unique (purchase_reference),

  constraint provider_purchase_verifications_owner_identity
    unique (id, user_id),

  constraint provider_purchase_verifications_entitlement_owner_fk
    foreign key (entitlement_id, user_id)
    references public.user_entitlements(id, user_id)
    on delete set null (entitlement_id),

  constraint provider_purchase_verifications_provider_valid
    check (billing_provider in ('google_play', 'apple_app_store')),

  -- Only the publicly purchasable plans can ever be recorded here. A
  -- verification row naming `free` or `salon_pilot` would mean a store
  -- purchase had granted a plan that is not sold, so it is rejected by the
  -- table itself rather than only by the function that writes it.
  constraint provider_purchase_verifications_plan_purchasable
    check (plan_code in ('plus', 'pro', 'salon_pro')),

  constraint provider_purchase_verifications_reference_is_sha256
    check (purchase_reference ~ '^[0-9a-f]{64}$'),
  constraint provider_purchase_verifications_linked_reference_is_sha256
    check (
      linked_purchase_reference is null
      or linked_purchase_reference ~ '^[0-9a-f]{64}$'
    ),
  -- A purchase cannot replace itself.
  constraint provider_purchase_verifications_linked_differs
    check (
      linked_purchase_reference is null
      or linked_purchase_reference <> purchase_reference
    ),
  constraint provider_purchase_verifications_product_not_blank
    check (char_length(btrim(provider_product_id)) > 0),
  constraint provider_purchase_verifications_state_not_blank
    check (char_length(btrim(subscription_state)) between 1 and 64)
);

create index if not exists provider_purchase_verifications_user_idx
  on public.provider_purchase_verifications (user_id, verified_at desc);
create index if not exists provider_purchase_verifications_entitlement_idx
  on public.provider_purchase_verifications (entitlement_id)
  where entitlement_id is not null;
create index if not exists provider_purchase_verifications_linked_idx
  on public.provider_purchase_verifications (linked_purchase_reference)
  where linked_purchase_reference is not null;

drop trigger if exists provider_purchase_verifications_set_updated_at
  on public.provider_purchase_verifications;
create trigger provider_purchase_verifications_set_updated_at
before update on public.provider_purchase_verifications
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Row level security
-- ---------------------------------------------------------------------------
--
-- Same model as SUB-2: the row owner is exactly the party who benefits from
-- forging it, so `authenticated` receives no write privilege at all. Reads are
-- allowed for the owner's own rows so a support conversation can be grounded
-- in what the user can also see.
alter table public.provider_purchase_verifications enable row level security;

revoke all on table public.provider_purchase_verifications from anon;
revoke all on table public.provider_purchase_verifications from authenticated;

-- `purchase_reference` and `linked_purchase_reference` are withheld by
-- column-level grant. They are not secrets — a hash is not a credential — but
-- they are correlation identifiers with no use in the app, and least privilege
-- is the cheaper default.
grant select (
  id,
  user_id,
  billing_provider,
  provider_product_id,
  plan_code,
  subscription_state,
  test_purchase,
  entitlement_id,
  verified_at,
  created_at,
  updated_at
) on table public.provider_purchase_verifications to authenticated;

drop policy if exists "provider_purchase_verifications_select_own"
  on public.provider_purchase_verifications;
create policy "provider_purchase_verifications_select_own"
on public.provider_purchase_verifications for select
to authenticated
using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- 4. public.activate_verified_google_play_subscription(...)
-- ---------------------------------------------------------------------------
--
-- Writes an entitlement from facts a caller has *already verified* against
-- Google. It performs no verification of its own and cannot: Postgres makes no
-- outbound HTTPS calls. Everything it receives is therefore treated as
-- privileged input, which is why the execute grant below is the narrowest in
-- the schema.
--
-- ## Why this is not granted to `authenticated`
--
-- Every other subscription function in this project is safe to expose because
-- it derives its authority from `auth.uid()` and reads only server-held state
-- — `resolve_subscription_state` takes no arguments at all, precisely so no
-- caller can influence it. This one is different in kind: its arguments *are*
-- the authority. A user able to invoke it directly could name any plan, any
-- period, and any account and grant themselves a subscription without ever
-- contacting Google.
--
-- So it is granted to `service_role` only, and explicitly revoked from
-- `public`, `anon`, and `authenticated`. The `verify-google-play-purchase`
-- Edge Function is the sole caller, it establishes the user's identity with
-- the user's own JWT before calling, and it uses its privileged client for
-- this one RPC and nothing else.
--
-- This is a deliberate, documented departure from the note in SUB-2 that no
-- Edge Function needs the service-role key. That was true while every write
-- path could derive its own authority; verification is the first that cannot,
-- because the authority lives at Google. The alternative — granting this to
-- `authenticated` — would be a self-service entitlement generator.
--
-- ## Provider state mapping
--
-- The mapping from Google's `SubscriptionState` to a FaceTune entitlement
-- status lives here, in one auditable place, rather than in the Edge Function.
-- The Edge Function relays what Google said; this decides what it means. Both
-- halves are needed and neither is authoritative alone, but only this one can
-- write.
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
  -- Retire any other currently-governing entitlement
  -- -------------------------------------------------------------------------
  --
  -- `user_entitlements_one_current_idx` permits one active-or-grace row per
  -- account. Superseding the previous one is therefore structurally required,
  -- not a lifecycle policy choice: without it, upgrading from a Free grant, or
  -- from a prior subscription whose replacement Google did not link, would
  -- violate the index and fail the whole activation.
  --
  -- The retired row is marked expired and kept. Its usage ledger rows stay
  -- attached to it, so the previous period's history remains intact and
  -- auditable, and nothing rolls over.
  if v_status in ('active', 'grace_period') then
    update public.user_entitlements as e
       set status = 'expired',
           auto_renew = false,
           version = e.version + 1
     where e.user_id = p_user_id
       and e.status in ('active', 'grace_period')
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

-- The narrowest execute grant in the schema. See the rationale above the
-- function: its arguments carry its authority, so no client role may hold it.
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
