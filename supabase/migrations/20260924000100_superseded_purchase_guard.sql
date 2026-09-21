-- FaceTune SUB-13B corrective patch: superseded purchase guard.
--
-- One guard added to `activate_verified_google_play_subscription`; nothing
-- else changes. The function is otherwise the SUB-12 (20260920) definition,
-- reproduced verbatim so that the whole body is readable here.
--
-- ## The invariant this protects
--
-- After a Google Play subscription *replacement* — Plus → Plus Preview,
-- started with the old purchase's details and an immediate replacement mode
-- — Google issues a new purchase token whose `linkedPurchaseToken` names the
-- purchase it replaced, and expires that old purchase at once. SUB-11 already
-- follows the link: the activation lands on the entitlement the old purchase
-- governed and rewrites it in place, so a replacement never creates a second
-- entitlement beside the one it supersedes.
--
-- What was missing is the other direction. A verification of the *old* token
-- that read Google before the replacement completed, and reaches this
-- function after the new token has been activated, still says ACTIVE. The
-- old reference no longer matches any entitlement (the row moved to the new
-- reference), so the function inserted a fresh live entitlement for it and —
-- because one live paid entitlement is allowed per account — retired the
-- replacement. The account's plan flipped back to the old one until the new
-- token was next verified. A restore on a second device during a switch is
-- enough to do it.
--
-- ## The guard
--
-- A purchase reference that a later verification recorded as its
-- `linked_purchase_reference` has been superseded by that later purchase.
-- Google invalidates a replaced purchase permanently — a token, once linked
-- from, is never live again — so a live (active or grace) activation of a
-- superseded reference is by definition stale, and is refused with
-- `PROVIDER_STATE_CONFLICT` before anything is written. Non-live states pass
-- through unchanged: an expired read of a superseded purchase is the truth,
-- and is recorded exactly as before.
--
-- The check runs under the per-account advisory lock, after the ownership
-- checks and before the retire-and-write section, so it observes every
-- activation that committed before it and cannot interleave with one that is
-- in flight.
--
-- ## Scope note
--
-- The guard assumes immediate replacement modes, which is all V1 uses: the
-- approved equal-price switches replace WITHOUT_PRORATION, and every other
-- switch is refused by the client until its terms are approved. A *deferred*
-- replacement, where the old purchase legitimately stays live until its
-- period ends, would need this guard revisited before it could be adopted.
--
-- No table, index, policy, grant, or other function changes. The privileges
-- on the function are preserved by `create or replace`.

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
  -- SUB-13B: a superseded purchase cannot come back to life
  -- -------------------------------------------------------------------------
  --
  -- A later verification that named this reference as the purchase it
  -- replaced has already moved the entitlement on. Google never revives a
  -- replaced purchase, so a live state for it here is a stale read — most
  -- likely a restore that queried Google just before the replacement — and
  -- writing it would insert a second live entitlement and retire the
  -- replacement. Refused, and nothing is written; the verification record
  -- keeps whatever the provider last truthfully said about it.
  if v_status in ('active', 'grace_period')
     and exists (
       select 1
       from public.provider_purchase_verifications as v
       where v.linked_purchase_reference = p_purchase_reference
         and v.purchase_reference <> p_purchase_reference
     ) then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PROVIDER_STATE_CONFLICT'
    );
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
