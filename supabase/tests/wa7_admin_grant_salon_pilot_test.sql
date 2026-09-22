-- WA-7 — the Salon Pilot grant: authorization, validation, Subscription-rule
-- conflicts, idempotency, audit, and authoritative returned state.
begin;

select plan(76);

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

create function pg_temp.as_nobody() returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- The grant as the fixture admin would call it through the Edge Function.
create function pg_temp.grant_pilot(
  p_target uuid,
  p_expires timestamptz default timezone('utc', now()) + interval '30 days',
  p_reason text default 'Panel research cohort A',
  p_key text default 'wa7-key-1',
  p_allowance int default 30,
  p_corr uuid default '40000000-0000-4000-8000-0000000000c1'
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('40000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot(
    p_target, p_expires, p_reason, p_key, p_allowance, p_corr);
  reset role;
  return v;
end;
$$;

create function pg_temp.state(p_user uuid) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_user);
  v := public.resolve_subscription_state();
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.audit_count(p_user uuid) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.admin_audit_events where target_user_id = p_user
$$;

create function pg_temp.pilot_rows(p_user uuid) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.user_entitlements
   where user_id = p_user and plan_code = 'salon_pilot'
$$;

-- Accounts. The auth trigger provisions each lifetime Free entitlement.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated',
  'authenticated', v.email, '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', v.anon
from (values
  ('40000000-0000-4000-8000-000000000a00'::uuid, 'wa7-admin@example.invalid', false),
  ('40000000-0000-4000-8000-000000000a01'::uuid, 'wa7-normal@example.invalid', false),
  ('40000000-0000-4000-8000-000000000001'::uuid, 'wa7-artist@example.invalid', false),
  ('40000000-0000-4000-8000-000000000002'::uuid, 'wa7-pro@example.invalid', false),
  ('40000000-0000-4000-8000-000000000003'::uuid, 'wa7-lapsed@example.invalid', false),
  ('40000000-0000-4000-8000-000000000004'::uuid, null, true)
) as v(id, email, anon);

insert into public.admin_users (user_id, note)
values ('40000000-0000-4000-8000-000000000a00', 'wa7 fixture');

-- ---------------------------------------------------------------------------
-- Authorization: the session decides, never the arguments.
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('40000000-0000-4000-8000-000000000a01');
select is((public.admin_grant_salon_pilot(
  '40000000-0000-4000-8000-000000000001', timezone('utc', now()) + interval '30 days',
  'x', 'k', 30, null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot grant Salon Pilot');
select is((public.admin_grant_salon_pilot(
  '40000000-0000-4000-8000-000000000a01', timezone('utc', now()) + interval '30 days',
  'x', 'k', 30, null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot grant themselves Salon Pilot');
select pg_temp.as_nobody();
select is((public.admin_grant_salon_pilot(
  '40000000-0000-4000-8000-000000000001', timezone('utc', now()) + interval '30 days',
  'x', 'k', 30, null))->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot grant');
reset role;
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000001'), 0::bigint,
  'refused calls created no entitlement');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000001'), 0::bigint,
  'refused calls created no audit event');

-- ---------------------------------------------------------------------------
-- Validation
-- ---------------------------------------------------------------------------
select is((pg_temp.grant_pilot('49999999-9999-4999-8999-999999999999'))->>'errorCode',
  'USER_NOT_FOUND', 'an unknown target is USER_NOT_FOUND');
select is((pg_temp.grant_pilot('40000000-0000-4000-8000-000000000004'))->>'errorCode',
  'USER_NOT_FOUND', 'an anonymous guest is not a grantable account');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', null) $$,
  '22023', null, 'a missing expiration is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001',
       timezone('utc', now()) - interval '1 day') $$,
  '22023', null, 'a past expiration is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', p_reason => '   ') $$,
  '22023', null, 'a blank reason is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', p_reason => null) $$,
  '22023', null, 'a missing reason is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', p_key => '') $$,
  '22023', null, 'a missing idempotency key is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', p_allowance => -1) $$,
  '22023', null, 'a negative initial allowance is rejected');
select throws_ok(
  $$ select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001', p_allowance => null) $$,
  '22023', null, 'a null initial allowance is rejected');
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000001'), 0::bigint,
  'invalid requests created no entitlement');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000001'), 0::bigint,
  'invalid requests created no audit event');

-- ---------------------------------------------------------------------------
-- Valid grant
-- ---------------------------------------------------------------------------
create temp table granted as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001') as r;
select is((select r->>'success' from granted), 'true', 'a valid grant succeeds');
select is((select r->>'action' from granted), 'grant_salon_pilot',
  'the response names the canonical action');
select is((select r->>'replayed' from granted), 'false', 'a first grant is not a replay');
select is((select r->>'planCode' from granted), 'salon_pilot', 'plan is salon_pilot');
select is((select r->>'status' from granted), 'active', 'the grant is active');
select is((select (r->>'effectiveAllowance')::int from granted), 30,
  'the default initial allowance is 30');
select is((select (r->>'committedUsage')::int || '/' || (r->>'reservedUsage') || '/' ||
                  (r->>'availableAiLooks') || '/' || (r->>'remainingAiLooks') from granted),
  '0/0/30/30', 'usage figures start at zero with the full pool available');
select is(
  (select array_agg(k order by k) from granted, jsonb_object_keys(r) k),
  array['action','availableAiLooks','committedUsage','contractVersion','effectiveAllowance',
        'entitlementId','expiresAt','planCode','remainingAiLooks','replayed','reservedUsage',
        'status','success','targetUserId','updatedAt','version'],
  'the response carries exactly the contract §73 fields plus replay/version');

-- Persisted shape follows the Subscription hard locks.
select is(
  (select e.plan_code || ' ' || e.status || ' ' || e.billing_provider || ' auto=' ||
          e.auto_renew::text || ' base=' || e.base_ai_look_allowance || ' adj=' ||
          e.allowance_adjustment_total || ' period=' ||
          coalesce(e.period_start::text, 'none') || ' product=' ||
          coalesce(e.provider_product_id, 'none') || ' ref=' ||
          coalesce(e.provider_subscription_reference, 'none')
   from public.user_entitlements e
   where e.id = (select (r->>'entitlementId')::uuid from granted)),
  'salon_pilot active admin_granted auto=false base=30 adj=0 period=none product=none ref=none',
  'the row is an admin-granted pilot, not a fabricated store purchase');
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000001'), 1::bigint,
  'exactly one pilot row exists');
select is(
  (select count(*) from public.user_entitlements
   where user_id = '40000000-0000-4000-8000-000000000001' and plan_code = 'free'
     and status = 'active'),
  1::bigint, 'the lifetime Free row is untouched');

-- App-facing state reflects the grant: the consumer resolver now governs by it.
select is((select s->>'planCode' from pg_temp.state('40000000-0000-4000-8000-000000000001') s),
  'salon_pilot', 'the app resolver reports the pilot as governing');
select is((select (s->>'availableAiLooks')::int from pg_temp.state('40000000-0000-4000-8000-000000000001') s),
  30, 'the app resolver reports the granted pool');
select is((select s->>'generationAuthorized' from pg_temp.state('40000000-0000-4000-8000-000000000001') s),
  'true', 'the pilot may generate');
select is((select s->>'billingProvider' from pg_temp.state('40000000-0000-4000-8000-000000000001') s),
  'admin_granted', 'the app sees the admin-granted provider');

-- Audit exactly once, with the contract's fields.
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000001'), 1::bigint,
  'exactly one audit event was written');
create temp table audit as
select a.* from public.admin_audit_events a
 where a.target_user_id = '40000000-0000-4000-8000-000000000001';
select is((select admin_user_id from audit), '40000000-0000-4000-8000-000000000a00',
  'the audit names the acting administrator from the session');
select is((select action || ' ' || source from audit), 'grant_salon_pilot admin',
  'the audit action is canonical and admin-sourced');
select is((select target_entitlement_id from audit),
  (select (r->>'entitlementId')::uuid from granted), 'the audit links the new entitlement');
select is((select reason from audit), 'Panel research cohort A', 'the reason is recorded');
select is((select request_correlation_id from audit), '40000000-0000-4000-8000-0000000000c1',
  'the request correlation id is recorded');
select is((select idempotency_key from audit), 'wa7-key-1', 'the idempotency key is recorded');
select is((select before_state->>'planCode' || ' ' || (before_state->>'status') from audit),
  'free active', 'before-state snapshots the governing Free entitlement');
select is((select after_state->>'planCode' || ' ' || (after_state->>'status') || ' ' ||
                  (after_state->>'effectiveAllowance') from audit),
  'salon_pilot active 30', 'after-state snapshots the new pilot');
select is(
  (select array_agg(k order by k) from audit, jsonb_object_keys(after_state) k),
  array['allowanceAdjustmentTotal','effectiveAllowance','expiresAt','planCode','status','version'],
  'snapshots carry only the six privacy-safe fields');
select is((select audit::text ~* 'selfie|storage_path|signed.?url|prompt|gemini|makeup_kit|token' from audit),
  false, 'the audit row carries no private content');

-- ---------------------------------------------------------------------------
-- Idempotency
-- ---------------------------------------------------------------------------
create temp table replay as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001') as r;
select is((select r->>'success' from replay), 'true', 'a duplicate submission succeeds');
select is((select r->>'replayed' from replay), 'true', 'and is reported as a replay');
select is((select r->>'entitlementId' from replay), (select r->>'entitlementId' from granted),
  'the replay returns the same entitlement');
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000001'), 1::bigint,
  'a duplicate submission created no second pilot');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000001'), 1::bigint,
  'a duplicate submission created no second audit event');
select is((pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001',
  p_allowance => 40))->>'errorCode', 'IDEMPOTENCY_CONFLICT',
  'the same key with different intent is a conflict');
select is((pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001',
  p_key => 'wa7-key-2'))->>'errorCode', 'SALON_PILOT_ALREADY_GRANTED',
  'a new key while a pilot is in force is refused as already granted');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000001'), 1::bigint,
  'conflicts write no audit event');

-- Replay remains stable after the pool is partly spent.
select pg_temp.as_user('40000000-0000-4000-8000-000000000001');
select public.reserve_ai_look('42000000-0000-4000-8000-000000000001');
select pg_temp.as_nobody();
select is((select (r->>'availableAiLooks')::int || '/' || (r->>'reservedUsage')
   from pg_temp.grant_pilot('40000000-0000-4000-8000-000000000001') r),
  '29/1', 'a replay returns the current authoritative balance, not a cached one');

-- ---------------------------------------------------------------------------
-- Conflicts handled by Subscription rules
-- ---------------------------------------------------------------------------
-- A live Google Play subscription is never superseded by an admin grant.
select public.activate_verified_google_play_subscription(
  '40000000-0000-4000-8000-000000000002',
  'facetune_pro', repeat('7', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true
);
select is((pg_temp.grant_pilot('40000000-0000-4000-8000-000000000002',
  p_key => 'wa7-key-pro'))->>'errorCode', 'PROVIDER_STATE_CONFLICT',
  'an account with a live store subscription cannot be granted a pilot');
select is((select s->>'planCode' from pg_temp.state('40000000-0000-4000-8000-000000000002') s),
  'pro', 'the store subscription still governs');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000002'), 0::bigint,
  'the refused grant wrote no audit event');

-- A lapsed pilot still stored active is retired, and the new grant governs.
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance
) values (
  '41000000-0000-4000-8000-000000000003', '40000000-0000-4000-8000-000000000003',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '40 days', timezone('utc', now()) - interval '1 day',
  false, 30
);
create temp table regrant as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000003', p_key => 'wa7-key-regrant') as r;
select is((select r->>'success' from regrant), 'true', 'a lapsed pilot can be re-granted');
select is((select status from public.user_entitlements
   where id = '41000000-0000-4000-8000-000000000003'), 'expired',
  'the lapsed row is retired as expired, not deleted or rewritten');
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000003'), 2::bigint,
  'history keeps the old pilot beside the new one');
select is((select s->>'entitlementId' from pg_temp.state('40000000-0000-4000-8000-000000000003') s),
  (select r->>'entitlementId' from regrant), 'the new pilot governs the account');
select is((select before_state->>'planCode' || ' ' || (before_state->>'status')
   from public.admin_audit_events where target_user_id = '40000000-0000-4000-8000-000000000003'),
  'free active', 'before-state records what governed before the re-grant');

-- ---------------------------------------------------------------------------
-- Custom initial allowance: any non-negative integer; no business maximum.
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated',
  'authenticated', v.email, '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', false
from (values
  ('40000000-0000-4000-8000-000000000005'::uuid, 'wa7-zero@example.invalid'),
  ('40000000-0000-4000-8000-000000000006'::uuid, 'wa7-custom@example.invalid')
) as v(id, email);

-- Zero: a valid entitlement state (Shared Contract §76) with nothing available.
create temp table zero as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000005',
  p_key => 'wa7-key-zero', p_allowance => 0) as r;
select is((select r->>'success' from zero), 'true', 'an explicit zero allowance is accepted');
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'availableAiLooks') || '/' ||
                  (r->>'remainingAiLooks') from zero),
  '0/0/0', 'a zero-allowance grant returns authoritative zero capacity');
select is((select s->>'planCode' || ' ' || (s->>'availableAiLooks') || ' ' || (s->>'generationAuthorized')
   from pg_temp.state('40000000-0000-4000-8000-000000000005') s),
  'salon_pilot 0 false', 'the app resolver governs by the zero pilot and refuses generation');
create temp table zero_replay as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000005',
  p_key => 'wa7-key-zero', p_allowance => 0) as r;
select is((select r->>'replayed' from zero_replay), 'true',
  'a duplicate zero-allowance submission is replayed');
select is((select r->>'entitlementId' from zero_replay), (select r->>'entitlementId' from zero),
  'the replay names the same zero-allowance entitlement');
select is(pg_temp.pilot_rows('40000000-0000-4000-8000-000000000005'), 1::bigint,
  'a zero-allowance grant exists exactly once');
select is(pg_temp.audit_count('40000000-0000-4000-8000-000000000005'), 1::bigint,
  'a zero-allowance grant is audited exactly once');

-- A custom positive allowance above the default is accepted as submitted.
create temp table custom as
select pg_temp.grant_pilot('40000000-0000-4000-8000-000000000006',
  p_key => 'wa7-key-custom', p_allowance => 5000) as r;
select is((select r->>'success' from custom), 'true', 'a custom positive allowance is accepted');
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'availableAiLooks') from custom),
  '5000/5000', 'the custom allowance is persisted and returned as submitted');
select is((select base_ai_look_allowance from public.user_entitlements
   where id = (select (r->>'entitlementId')::uuid from custom)), 5000,
  'the base allowance on the row is the submitted value');

-- ---------------------------------------------------------------------------
-- Audit immutability and privilege surface
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.admin_audit_events set reason = 'edited'
     where target_user_id = '40000000-0000-4000-8000-000000000001' $$,
  'P0001', 'admin audit events are immutable', 'an audit reason cannot be edited');
select throws_ok(
  $$ update public.admin_audit_events set created_at = timezone('utc', now()) - interval '1 year'
     where target_user_id = '40000000-0000-4000-8000-000000000001' $$,
  'P0001', 'admin audit events are immutable', 'an audit timestamp cannot be rewritten');
select throws_ok(
  $$ update public.admin_audit_events set admin_user_id = '40000000-0000-4000-8000-000000000a01'
     where target_user_id = '40000000-0000-4000-8000-000000000001' $$,
  'P0001', 'admin audit events are immutable', 'the historical actor cannot be rewritten');
select is(
  (select bool_and(not has_table_privilege(r, 'public.admin_audit_events', p))
   from unnest(array['anon','authenticated','service_role']) r,
        unnest(array['SELECT','INSERT','UPDATE','DELETE']) p),
  true, 'no client role can read or write audit events');
select is(has_function_privilege('anon',
  'public.admin_grant_salon_pilot(uuid,timestamptz,text,text,integer,uuid)', 'EXECUTE'),
  false, 'anon cannot execute the grant');
select is(has_function_privilege('service_role',
  'public.admin_grant_salon_pilot(uuid,timestamptz,text,text,integer,uuid)', 'EXECUTE'),
  false, 'the grant is not a service-role endpoint');
select is(has_function_privilege('authenticated',
  'public.admin_grant_salon_pilot(uuid,timestamptz,text,text,integer,uuid)', 'EXECUTE'),
  true, 'authenticated reaches the grant and is checked inside');

select * from finish();
rollback;
