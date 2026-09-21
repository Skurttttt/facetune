-- SUB-14 — security and RLS hardening.
--
-- Proves, against the live privilege model, that a signed-in user can read
-- only their own monetization rows and can write none of them; that every
-- writer of entitlement, credit, adjustment or provider state is reachable
-- only by the server role; that every user-callable RPC takes its identity
-- from the session and never from an argument; and that no cross-account
-- operation, preview or Tutorial source is accepted. Rolled back.
begin;

select plan(74);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create function pg_temp.as_user(p_user uuid) returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
end;
$$;

create function pg_temp.new_preview(p_user uuid) returns uuid
language plpgsql set search_path = '' as $$
declare v_analysis uuid; v_rec uuid; v_img uuid;
begin
  select a.id into v_analysis from public.analyses a where a.user_id = p_user limit 1;
  if v_analysis is null then
    insert into public.analyses (user_id, original_image_path)
    values (p_user, p_user::text || '/analyses/x/original/selfie.jpg')
    returning id into v_analysis;
    insert into public.recommendations (user_id, analysis_id, makeup_style)
    values (p_user, v_analysis, 'natural');
  end if;
  select r.id into v_rec from public.recommendations r where r.user_id = p_user limit 1;
  insert into public.generated_images
    (user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values (p_user, v_analysis, v_rec,
          p_user::text || '/previews/' || gen_random_uuid()::text || '.png',
          (select coalesce(max(g.generation_number), 0) + 1
             from public.generated_images g where g.recommendation_id = v_rec))
  returning id into v_img;
  return v_img;
end;
$$;

create function pg_temp.can_exec(p_role text, p_fn text) returns boolean
language sql set search_path = '' as $$
  select bool_or(has_function_privilege(p_role, p.oid, 'EXECUTE'))
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = p_fn
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: two accounts, each with a plan, a preview and a Tutorial session
-- ---------------------------------------------------------------------------
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
  ('10000000-0000-4000-8000-000000000301'::uuid, 'sub14-alice@example.invalid'),
  ('10000000-0000-4000-8000-000000000302'::uuid, 'sub14-bob@example.invalid')
) as v(id, email);

select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000301', 'facetune_plus', repeat('a', 64),
  'SUBSCRIPTION_STATE_ACTIVE', timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true);
select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000302', 'facetune_pro', repeat('b', 64),
  'SUBSCRIPTION_STATE_ACTIVE', timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true);
select public.grant_verified_top_up_purchase(
  '10000000-0000-4000-8000-000000000302', 'facetune_ai_look_topup_1',
  repeat('c', 64), 'PURCHASED');

-- Bob reserves and commits one preview, and has a Tutorial session on it.
select pg_temp.as_user('10000000-0000-4000-8000-000000000302');
select public.reserve_ai_look('30000000-0000-4000-8000-000000000001');
select public.commit_ai_look('30000000-0000-4000-8000-000000000001', 'standard',
  pg_temp.new_preview('10000000-0000-4000-8000-000000000302'));
insert into public.tutorial_v4_sessions (
  id, user_id, analysis_id, source_mode, recommendation_id,
  canonical_generated_image_id, status, manifest_status
)
select '31000000-0000-4000-8000-000000000001', g.user_id, g.analysis_id,
       'standard', g.recommendation_id, g.id, 'ready', 'pending'
  from public.generated_images g
 where g.user_id = '10000000-0000-4000-8000-000000000302' limit 1;
-- Bob also holds an open reservation.
select public.reserve_ai_look('30000000-0000-4000-8000-000000000002');

-- ===========================================================================
-- 1. RLS is on, everywhere it matters
-- ===========================================================================
select is(
  (select string_agg(c.relname, ',' order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  null,
  'RLS is enabled on every public table'
);

-- ===========================================================================
-- 2. Table privileges: a signed-in user writes nothing, anon reads nothing
-- ===========================================================================
select is(
  (select string_agg(table_name || ':' || privilege_type, ',' order by 1)
     from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated'
      and privilege_type in ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')
      and table_name in (
        'user_entitlements', 'usage_ledger', 'purchased_credit_grants',
        'entitlement_allowance_adjustments', 'provider_purchase_verifications',
        'provider_notification_events', 'ai_operation_metrics',
        'subscription_products', 'top_up_packs', 'ai_usage_events')),
  null,
  'authenticated holds no write privilege on any monetization table'
);
select is(
  (select string_agg(table_name || ':' || privilege_type, ',' order by 1)
     from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'anon'
      and table_name in (
        'user_entitlements', 'usage_ledger', 'purchased_credit_grants',
        'entitlement_allowance_adjustments', 'provider_purchase_verifications',
        'provider_notification_events', 'ai_operation_metrics',
        'subscription_products', 'top_up_packs', 'ai_usage_events')),
  null,
  'anon holds no privilege at all on any monetization table'
);
-- Column-level grants are the only reads, and they withhold references.
select is(
  (select string_agg(column_name, ',')
     from information_schema.column_privileges
    where table_schema = 'public' and grantee = 'authenticated'
      and privilege_type = 'SELECT'
      and column_name in ('provider_subscription_reference', 'purchase_reference',
                          'linked_purchase_reference')),
  null,
  'no provider purchase reference column is readable by a user'
);
select is(
  (select count(*) from information_schema.column_privileges
    where table_schema = 'public' and grantee = 'authenticated'
      and table_name in ('entitlement_allowance_adjustments',
                         'provider_notification_events', 'ai_operation_metrics')),
  0::bigint,
  'admin adjustments, notification events and telemetry are not user-readable'
);

-- ===========================================================================
-- 3. Function privileges: writers are server-only; readers need a session
-- ===========================================================================
select is(pg_temp.can_exec('authenticated', 'activate_verified_google_play_subscription'), false,
  'user cannot activate a subscription');
select is(pg_temp.can_exec('authenticated', 'revoke_google_play_subscription'), false,
  'user cannot revoke a subscription');
select is(pg_temp.can_exec('authenticated', 'grant_verified_top_up_purchase'), false,
  'user cannot grant purchased credits');
select is(pg_temp.can_exec('authenticated', 'revoke_top_up_purchase'), false,
  'user cannot revoke purchased credits');
select is(pg_temp.can_exec('authenticated', 'mark_top_up_purchase_consumed'), false,
  'user cannot mark a purchase consumed');
select is(pg_temp.can_exec('authenticated', 'claim_google_play_notification'), false,
  'user cannot claim provider notifications');
select is(pg_temp.can_exec('authenticated', 'finalize_google_play_notification'), false,
  'user cannot finalize provider notifications');
select is(pg_temp.can_exec('authenticated', 'google_play_purchase_owner'), false,
  'user cannot look up purchase owners');
select is(pg_temp.can_exec('authenticated', 'provision_free_entitlement'), false,
  'user cannot provision Free');
select is(pg_temp.can_exec('authenticated', 'reconcile_stale_ai_look_reservations'), false,
  'user cannot run the reservation reconciler');
select is(pg_temp.can_exec('authenticated', 'purge_ai_usage_events'), false,
  'user cannot purge usage events');
select is(pg_temp.can_exec('authenticated', 'record_ai_operation_metric'), false,
  'user cannot write telemetry');
-- Trigger functions carry Postgres's default PUBLIC execute, but a function
-- returning `trigger` cannot be invoked by anyone except the trigger
-- machinery, so they are excluded below and proven inert right after.
select is(
  (select string_agg(p.proname, ',' order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and p.prorettype <> 'trigger'::regtype
      and has_function_privilege('anon', p.oid, 'EXECUTE')),
  null,
  'anon can execute no callable security-definer function'
);
select throws_ok(
  $$ select public.guard_free_entitlement_lifetime() $$,
  '0A000', null,
  'a trigger function cannot be called directly (no bypass through it)'
);
-- Every user-callable security-definer RPC identifies the caller from the
-- session: none takes a user id as an argument.
select is(
  (select string_agg(p.proname, ',' order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and pg_get_function_identity_arguments(p.oid) ~* 'user'),
  null,
  'no user-callable RPC accepts a user identity argument (no JWT bypass)'
);
select is(
  (select string_agg(p.proname, ',' order by p.proname)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prosecdef
      and p.prorettype <> 'trigger'::regtype
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  'authorize_tutorial_generation,commit_ai_look,consume_ai_quota,release_ai_look,' ||
  'reserve_ai_look,resolve_subscription_state',
  'the user-callable security-definer surface is exactly the six known RPCs'
);
-- No hidden special-casing of an account inside any function body.
select is(
  (select string_agg(p.proname, ',')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and (p.prosrc ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}'
           or p.prosrc ~* 'is_?premium|bypass|backdoor|pilot_email|test_account')),
  null,
  'no function body names an email, a premium flag or a bypass'
);

-- ===========================================================================
-- 4. Session identity is required
-- ===========================================================================
select set_config('request.jwt.claims', '{"role":"authenticated"}', true);
select is((public.resolve_subscription_state())->>'denialReason', 'AUTH_REQUIRED',
  'no subject: state read denied');
select is((public.reserve_ai_look(gen_random_uuid()))->>'errorCode', 'AUTH_REQUIRED',
  'no subject: reserve denied');
select is((public.commit_ai_look('30000000-0000-4000-8000-000000000001', 'standard',
  gen_random_uuid()))->>'errorCode', 'AUTH_REQUIRED', 'no subject: commit denied');
select is((public.release_ai_look('30000000-0000-4000-8000-000000000002', null))->>'errorCode',
  'AUTH_REQUIRED', 'no subject: release denied');
select is((public.authorize_tutorial_generation('standard', gen_random_uuid(), null))->>'denialReason',
  'AUTH_REQUIRED', 'no subject: Tutorial denied');

-- ===========================================================================
-- 5. Cross-account reads are empty, cross-account writes are refused
-- ===========================================================================
select pg_temp.as_user('10000000-0000-4000-8000-000000000301');
set local role authenticated;

select is((select count(*) from public.user_entitlements), 2::bigint,
  'Alice sees exactly her own two entitlements (Free + Plus)');
select is((select count(*) from public.user_entitlements
  where user_id = '10000000-0000-4000-8000-000000000302'), 0::bigint,
  'Alice cannot read Bob''s entitlement');
select is((select count(*) from public.usage_ledger), 0::bigint,
  'Alice cannot read Bob''s usage');
select is((select count(*) from public.purchased_credit_grants), 0::bigint,
  'Alice cannot read Bob''s purchased credits');
select is((select count(*) from public.provider_purchase_verifications
  where user_id <> '10000000-0000-4000-8000-000000000301'), 0::bigint,
  'Alice cannot read Bob''s purchase verifications');
select is((select count(*) from public.tutorial_v4_sessions), 0::bigint,
  'Alice cannot read Bob''s Tutorial sessions');
select is((select count(*) from public.generated_images), 0::bigint,
  'Alice cannot read Bob''s previews');

-- Direct writes as a user: insufficient privilege, every table.
select throws_ok($$ insert into public.user_entitlements
  (user_id, plan_code, status, billing_provider, base_ai_look_allowance)
  values ('10000000-0000-4000-8000-000000000301', 'plus', 'active', 'google_play', 3) $$,
  '42501', null, 'user cannot grant own entitlement');
select throws_ok($$ insert into public.user_entitlements
  (user_id, plan_code, status, billing_provider, base_ai_look_allowance, expires_at)
  values ('10000000-0000-4000-8000-000000000301', 'salon_pilot', 'active',
          'admin_granted', 30, now() + interval '1 day') $$,
  '42501', null, 'user cannot grant own Salon Pilot');
select throws_ok($$ update public.user_entitlements set base_ai_look_allowance = 99 $$,
  '42501', null, 'user cannot raise own allowance');
select throws_ok($$ delete from public.user_entitlements $$,
  '42501', null, 'user cannot delete own entitlement');
select throws_ok($$ update public.usage_ledger set status = 'released' $$,
  '42501', null, 'user cannot edit own usage ledger');
select throws_ok($$ delete from public.usage_ledger $$,
  '42501', null, 'user cannot delete own usage');
select throws_ok($$ insert into public.usage_ledger (user_id, entitlement_id, operation_id)
  values ('10000000-0000-4000-8000-000000000301',
          (select id from public.user_entitlements where plan_code = 'plus'), gen_random_uuid()) $$,
  '42501', null, 'user cannot insert usage');
select throws_ok($$ insert into public.purchased_credit_grants
  (user_id, billing_provider, provider_product_id, pack_code, credit_class,
   quantity_granted, purchase_reference, purchase_state)
  values ('10000000-0000-4000-8000-000000000301', 'google_play', 'facetune_ai_look_topup_1',
   'extra_ai_look', 'tutorial_capable_ai_look', 1, repeat('9', 64), 'PURCHASED') $$,
  '42501', null, 'user cannot grant own purchased credits');
select throws_ok($$ update public.purchased_credit_grants set quantity_granted = 100 $$,
  '42501', null, 'user cannot edit purchased-credit ledger');
select throws_ok($$ insert into public.entitlement_allowance_adjustments
  (entitlement_id, target_user_id, admin_user_id, adjustment_type, amount, reason, idempotency_key)
  values ((select id from public.user_entitlements where plan_code = 'plus'),
          '10000000-0000-4000-8000-000000000301', '10000000-0000-4000-8000-000000000301',
          'increase_allowance', 10, 'self', 'self-1') $$,
  '42501', null, 'user cannot write an admin adjustment');
select throws_ok($$ select * from public.entitlement_allowance_adjustments $$,
  '42501', null, 'user cannot read admin adjustments');
select throws_ok($$ update public.subscription_products set base_ai_look_allowance = 999 $$,
  '42501', null, 'user cannot edit the plan catalog');
select throws_ok($$ update public.top_up_packs set quantity = 999 $$,
  '42501', null, 'user cannot edit the pack catalog');
select throws_ok($$ select purchase_reference from public.purchased_credit_grants $$,
  '42501', null, 'the purchase reference column is withheld even from the owner');
select throws_ok($$ select provider_subscription_reference from public.user_entitlements $$,
  '42501', null, 'the subscription reference column is withheld even from the owner');

-- Server-only RPCs are not even callable.
select throws_ok($$ select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000301', 'facetune_salon_pro', repeat('d', 64),
  'SUBSCRIPTION_STATE_ACTIVE', now(), now() + interval '30 days', true, null, true) $$,
  '42501', null, 'user cannot call the activation writer');
select throws_ok($$ select public.grant_verified_top_up_purchase(
  '10000000-0000-4000-8000-000000000301', 'facetune_ai_look_topup_1', repeat('e', 64), 'PURCHASED') $$,
  '42501', null, 'user cannot call the credit writer');
select throws_ok($$ select public.revoke_google_play_subscription(repeat('b', 64), null, null) $$,
  '42501', null, 'user cannot call the revoker');
select throws_ok($$ select public.provision_free_entitlement('10000000-0000-4000-8000-000000000301') $$,
  '42501', null, 'user cannot re-provision Free');

-- Cross-account operations through the RPCs.
select is((public.reserve_ai_look('30000000-0000-4000-8000-000000000002'))->>'errorCode',
  'USAGE_OPERATION_NOT_FOUND', 'Alice cannot replay Bob''s reservation');
select is((public.release_ai_look('30000000-0000-4000-8000-000000000002', 'x'))->>'errorCode',
  'USAGE_OPERATION_NOT_FOUND', 'Alice cannot release Bob''s reservation');
select is((public.commit_ai_look('30000000-0000-4000-8000-000000000002', 'standard',
  '31000000-0000-4000-8000-000000000001'))->>'errorCode',
  'USAGE_OPERATION_NOT_FOUND', 'Alice cannot commit Bob''s reservation');
select is((public.authorize_tutorial_generation('standard',
  (select canonical_generated_image_id from public.tutorial_v4_sessions
     where id = '31000000-0000-4000-8000-000000000001'), null))->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'Alice cannot authorize a Tutorial on Bob''s preview (RLS hides it)');
reset role;
-- The same check with the preview id known (as an attacker who learned it).
select pg_temp.as_user('10000000-0000-4000-8000-000000000301');
select is((public.authorize_tutorial_generation('standard',
  (select l.canonical_generated_image_id from public.usage_ledger l
     where l.operation_id = '30000000-0000-4000-8000-000000000001'), null))->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'Alice cannot authorize a Tutorial on Bob''s preview by id');
select is((public.authorize_tutorial_generation(null, null,
  '31000000-0000-4000-8000-000000000001'))->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'Alice cannot authorize Bob''s Tutorial session');
-- Alice reserves, then tries to commit against Bob's preview.
select is((public.reserve_ai_look('30000000-0000-4000-8000-000000000003'))->>'ok', 'true',
  'Alice reserves her own AI Look');
select is((public.commit_ai_look('30000000-0000-4000-8000-000000000003', 'standard',
  (select l.canonical_generated_image_id from public.usage_ledger l
     where l.operation_id = '30000000-0000-4000-8000-000000000001')))->>'errorCode',
  'USAGE_STATE_CONFLICT', 'cross-user preview association is rejected');
select is((select status from public.usage_ledger
  where operation_id = '30000000-0000-4000-8000-000000000003'), 'reserved',
  'the refused commit left the reservation untouched');
-- Alice cannot spend Bob's purchased credit.
select is((select s->>'purchasedTutorialCreditsRemaining' || '/' || (s->>'availablePurchasedCredits')
  from public.resolve_subscription_state() s), '0/0',
  'Bob''s purchased credit is invisible to Alice''s resolver');

-- ===========================================================================
-- 6. Immutability that even the server role cannot bypass
-- ===========================================================================
select throws_ok($$ update public.usage_ledger set status = 'released', released_at = now(),
  committed_at = null, source_mode = null, canonical_generated_image_id = null
  where operation_id = '30000000-0000-4000-8000-000000000001' $$,
  null, null, 'a committed usage row cannot be rewritten by anyone');
select throws_ok($$ update public.usage_ledger set allowance_source = 'purchased_credit'
  where operation_id = '30000000-0000-4000-8000-000000000002' $$,
  null, null, 'a reservation''s allowance source cannot be rewritten');
select throws_ok($$ update public.purchased_credit_grants set credit_class = 'preview_only_final_preview' $$,
  null, null, 'a purchased credit''s class cannot be rewritten');
select throws_ok($$ update public.user_entitlements set plan_code = 'free'
  where user_id = '10000000-0000-4000-8000-000000000301' and plan_code = 'plus' $$,
  null, null, 'a paid entitlement cannot be converted into Free');
select throws_ok($$ update public.user_entitlements set plan_code = 'salon_pilot'
  where user_id = '10000000-0000-4000-8000-000000000301' and plan_code = 'plus' $$,
  '23514', null, 'a store entitlement cannot be turned into Salon Pilot');

-- ===========================================================================
-- 7. Token secrecy at rest
-- ===========================================================================
select is(
  (select count(*) from public.provider_purchase_verifications
    where purchase_reference !~ '^[0-9a-f]{64}$'
       or (linked_purchase_reference is not null and linked_purchase_reference !~ '^[0-9a-f]{64}$')),
  0::bigint, 'every stored purchase reference is a SHA-256 digest, never a token'
);
select is(
  (select count(*) from public.purchased_credit_grants where purchase_reference !~ '^[0-9a-f]{64}$'),
  0::bigint, 'every stored top-up reference is a SHA-256 digest'
);
select is(
  (select count(*) from public.user_entitlements
    where provider_subscription_reference is not null
      and provider_subscription_reference !~ '^[0-9a-f]{64}$'),
  0::bigint, 'every entitlement reference is a SHA-256 digest'
);

-- ===========================================================================
-- 8. Sanity: the fixtures actually exercised what the assertions claim
-- ===========================================================================
select is((select count(*) from public.usage_ledger
  where user_id = '10000000-0000-4000-8000-000000000302'), 2::bigint,
  'Bob''s rows exist (so the empty reads above were RLS, not absence)');
select is((select count(*) from public.tutorial_v4_sessions
  where user_id = '10000000-0000-4000-8000-000000000302'), 1::bigint,
  'Bob''s Tutorial session exists');
select is((select count(*) from public.purchased_credit_grants
  where user_id = '10000000-0000-4000-8000-000000000302'), 1::bigint,
  'Bob''s purchased credit exists');

select * from finish();
rollback;
