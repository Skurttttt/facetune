-- SUB-13B corrective patch — Google Play subscription replacement.
--
-- Proves, against the real activation function and resolver, that a proper
-- provider replacement (new token linked to the old one) moves the account's
-- entitlement in place, and that the replaced purchase can never afterwards
-- overwrite it — not from a stale ACTIVE re-verification, not from a
-- restore, not from a late notification — so authoritative entitlement does
-- not oscillate between the old and the replacement plan. Purchased credits
-- are shown to survive the switch untouched. Everything runs in one
-- transaction and is rolled back.
begin;

select plan(43);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
--
-- Two accounts. A switches Plus → Plus Preview and back; B is a bystander
-- whose subscription must not be touched by anything A does.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated',
  'authenticated', v.email, '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', ''
from (values
  ('10000000-0000-4000-8000-000000000141'::uuid, 'sub13b-switch@example.invalid'),
  ('10000000-0000-4000-8000-000000000142'::uuid, 'sub13b-bystander@example.invalid')
) as v(id, email);

-- Resolve as a given account. The resolver is `security definer` and takes
-- its caller from `auth.uid()`, which reads the request claims, so setting
-- the claims is what makes the call the user's.
create function pg_temp.plan_of(p_user uuid) returns jsonb
language plpgsql set search_path = '' as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
  return public.resolve_subscription_state();
end;
$$;

-- The provider's answers, abbreviated. References are SHA-256 shaped.
create function pg_temp.ref(p text) returns text
language sql immutable as $$ select repeat(p, 64) $$;

-- ---------------------------------------------------------------------------
-- 1. Plus, bought new
-- ---------------------------------------------------------------------------

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus', pg_temp.ref('a'),
    'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, null, true
  ))->>'ok',
  'true',
  'Plus activates as a new subscription'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus',
  'the account resolves to plus'
);

-- A purchased Preview Boost and an Extra AI Look, so the switch below can be
-- shown not to touch them.
select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000141', 'facetune_ai_look_topup_1',
    pg_temp.ref('1'), 'PURCHASED'
  ))->>'ok',
  'true',
  'an Extra AI Look is granted to the Plus account'
);

select is(
  (select count(*) from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000141'),
  1::bigint,
  'one purchased grant exists before the switch'
);

-- The bystander, on Pro.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000142', 'facetune_pro', pg_temp.ref('e'),
    'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, null, true
  ))->>'ok',
  'true',
  'the bystander activates Pro'
);

-- ---------------------------------------------------------------------------
-- 2. Plus → Plus Preview, as Google reports a WITHOUT_PRORATION replacement:
--    a new token, linked to the old, same period.
-- ---------------------------------------------------------------------------

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus_preview',
    pg_temp.ref('b'), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, pg_temp.ref('a'), true
  ))->>'ok',
  'true',
  'the linked replacement activates'
);

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'),
  1::bigint,
  'the replacement moved the one paid entitlement rather than adding one'
);

select is(
  (select plan_code from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'),
  'plus_preview',
  'the entitlement now carries the replacement plan'
);

select is(
  (select provider_subscription_reference from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'),
  pg_temp.ref('b'),
  'the entitlement is governed by the new purchase reference'
);

select is(
  (select linked_purchase_reference from public.provider_purchase_verifications
   where purchase_reference = pg_temp.ref('b')),
  pg_temp.ref('a'),
  'the verification record links the new purchase to the one it replaced'
);

-- The capability transition the Source of Truth fixes for this switch.
select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus_preview',
  'the account resolves to plus_preview'
);
select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'allowanceUnit',
  'final_preview_credit',
  'the allowance unit is final_preview_credit'
);
select is(
  ((pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'tutorialEnabled')::boolean,
  false,
  'Tutorial is off on Plus Preview'
);
select is(
  ((pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'finalPreviewEnabled')::boolean,
  true,
  'Final Preview is on'
);

-- Purchased credits are independent of the subscription and untouched.
select is(
  (select count(*) from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000141'),
  1::bigint,
  'the purchased grant still exists after the switch'
);
select is(
  (select credit_class from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000141'),
  'tutorial_capable_ai_look',
  'the purchased grant keeps its Tutorial-capable provenance on a Preview plan'
);
select is(
  (select revoked_at from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000141'),
  null,
  'the purchased grant is not revoked by the switch'
);

-- ---------------------------------------------------------------------------
-- 3. The replaced purchase cannot come back
-- ---------------------------------------------------------------------------
--
-- A verification of the OLD token that read Google before the replacement
-- completed and reaches the database after it: a restore on a second device
-- during the switch. It still says ACTIVE. Before this patch it inserted a
-- second live Plus entitlement and retired the replacement.

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus', pg_temp.ref('a'),
    'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, null, true
  ))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'a stale ACTIVE re-verification of the replaced purchase is refused'
);

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'),
  1::bigint,
  'no second paid entitlement was created'
);

select is(
  (select plan_code || '/' || status from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'),
  'plus_preview/active',
  'the replacement is still the live entitlement'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus_preview',
  'the account still resolves to plus_preview'
);

-- The same, in grace: still live, still refused.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus', pg_temp.ref('a'),
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, null, true
  ))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'a stale grace-period re-verification of the replaced purchase is refused'
);

-- What Google actually says about a replaced purchase, once it has caught
-- up: EXPIRED. That is the truth and is recorded as before.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus', pg_temp.ref('a'),
    'SUBSCRIPTION_STATE_EXPIRED',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    false, null, true
  ))->>'ok',
  'true',
  'the provider''s expired verdict on the replaced purchase is accepted'
);

select is(
  (select subscription_state from public.provider_purchase_verifications
   where purchase_reference = pg_temp.ref('a')),
  'SUBSCRIPTION_STATE_EXPIRED',
  'the replaced purchase''s verification record reads EXPIRED'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus_preview',
  'an expired old purchase does not disturb the replacement'
);

-- Pre-existing SUB-11 behaviour, pinned rather than changed: an expired
-- verdict for a reference that no longer governs a row is recorded on a row
-- of its own, already retired. It is never live, so it can neither be
-- resolved to nor collide with the replacement in the one-live-row index.
select is(
  (select plan_code || '/' || status from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and provider_subscription_reference = pg_temp.ref('a')),
  'plus/expired',
  'the expired verdict lands on a retired row of its own'
);

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'
     and status in ('active', 'grace_period')),
  1::bigint,
  'exactly one live paid entitlement, and it is the replacement'
);

-- A late notification for the old token takes the revocation path. Whatever
-- it finds under the old reference is already retired; the replacement is
-- governed by the new reference and is not what it revokes.
select is(
  (public.revoke_google_play_subscription(
    pg_temp.ref('a'), 'SUBSCRIPTION_STATE_EXPIRED', timezone('utc', now())
  ))->>'ok',
  'true',
  'a late revocation of the replaced purchase is accepted'
);

select is(
  (select plan_code || '/' || status from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and provider_subscription_reference = pg_temp.ref('b')),
  'plus_preview/active',
  'the replacement is not what the late revocation revoked'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus_preview',
  'the replacement survives the late notification'
);

-- Ownership lookups for the old token still answer, so a notification for
-- it is attributed rather than dropped as unmatched.
select is(
  public.google_play_purchase_owner(pg_temp.ref('a'), null),
  '10000000-0000-4000-8000-000000000141'::uuid,
  'the replaced purchase is still attributed to its owner'
);

-- ---------------------------------------------------------------------------
-- 4. Re-verifying the replacement itself is idempotent
-- ---------------------------------------------------------------------------

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus_preview',
    pg_temp.ref('b'), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, pg_temp.ref('a'), true
  ))->>'ok',
  'true',
  'restoring the replacement re-verifies it'
);

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'
     and status in ('active', 'grace_period')),
  1::bigint,
  'still exactly one live paid entitlement'
);

-- ---------------------------------------------------------------------------
-- 5. Plus Preview → Plus, the reverse switch: a third token linked to the
--    second. The second is now superseded in its turn.
-- ---------------------------------------------------------------------------

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus', pg_temp.ref('c'),
    'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, pg_temp.ref('b'), true
  ))->>'ok',
  'true',
  'the reverse replacement activates'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus',
  'the account resolves to plus again'
);
select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'allowanceUnit',
  'ai_look',
  'the allowance unit is ai_look again'
);
select is(
  ((pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'tutorialEnabled')::boolean,
  true,
  'Tutorial is on again'
);

select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000141', 'facetune_plus_preview',
    pg_temp.ref('b'), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 day',
    timezone('utc', now()) + interval '29 days',
    true, pg_temp.ref('a'), true
  ))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'the now-superseded Preview purchase cannot come back either'
);

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000141'))->>'planCode',
  'plus',
  'the account does not oscillate back to plus_preview'
);

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and plan_code <> 'free'
     and status in ('active', 'grace_period')),
  1::bigint,
  'one live paid entitlement through the whole round trip'
);

select is(
  (select provider_subscription_reference from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000141'
     and status in ('active', 'grace_period')
     and plan_code <> 'free'),
  pg_temp.ref('c'),
  'the live entitlement is governed by the newest purchase'
);

-- ---------------------------------------------------------------------------
-- 6. Nobody else was touched
-- ---------------------------------------------------------------------------

select is(
  (pg_temp.plan_of('10000000-0000-4000-8000-000000000142'))->>'planCode',
  'pro',
  'the bystander is still on Pro'
);

select is(
  (select count(*) from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000141'
     and revoked_at is null),
  1::bigint,
  'the purchased grant survived the round trip unrevoked'
);

select * from finish();
rollback;
