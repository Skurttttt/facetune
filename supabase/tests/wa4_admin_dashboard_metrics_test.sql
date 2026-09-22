-- WA-4 — admin dashboard metrics.
--
-- Proves that `public.admin_dashboard_metrics()` refuses everyone but an
-- active admin, that every figure it returns is the database's own count
-- (asserted as exact deltas over fixtures, so it holds on a populated dev
-- database as well as an empty one), that an empty system yields a complete
-- object of zeros, that nothing identifying leaves the function, and that
-- the time-bucketed counts have an index to use. Rolled back.
begin;

select plan(41);

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

create function pg_temp.as_nobody() returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config('request.jwt.claims', '', true);
end;
$$;

-- The metrics as the admin sees them. The function derives identity from the
-- session, so this impersonates the admin for the call.
create function pg_temp.metrics() returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform set_config(
    'request.jwt.claims',
    '{"sub":"10000000-0000-4000-8000-000000000601","role":"authenticated"}',
    true
  );
  set local role authenticated;
  v := public.admin_dashboard_metrics();
  reset role;
  return v;
end;
$$;

create function pg_temp.new_preview(p_user uuid) returns uuid
language plpgsql set search_path = '' as $$
declare v_analysis uuid; v_rec uuid; v_img uuid;
begin
  insert into public.analyses (user_id, original_image_path)
  values (p_user, p_user::text || '/analyses/x/original/selfie.jpg')
  returning id into v_analysis;
  insert into public.recommendations (user_id, analysis_id, makeup_style)
  values (p_user, v_analysis, 'natural') returning id into v_rec;
  insert into public.generated_images
    (user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values (p_user, v_analysis, v_rec,
          p_user::text || '/previews/' || gen_random_uuid()::text || '.png', 1)
  returning id into v_img;
  return v_img;
end;
$$;

-- ---------------------------------------------------------------------------
-- Baseline: the numbers before any fixture exists (whatever the dev DB holds)
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
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', v.anon
from (values
  ('10000000-0000-4000-8000-000000000601'::uuid, 'wa4-admin@example.invalid', false),
  ('10000000-0000-4000-8000-000000000602'::uuid, 'wa4-normal@example.invalid', false)
) as v(id, email, anon);
insert into public.admin_users (user_id, note)
values ('10000000-0000-4000-8000-000000000601', 'wa4 fixture');

create temp table baseline as select pg_temp.metrics() as m;

-- ===========================================================================
-- 1. Authorization
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-000000000602');
select is(public.admin_dashboard_metrics(),
  '{"ok": false, "errorCode": "ADMIN_UNAUTHORIZED"}'::jsonb,
  'a normal user gets a refusal and no metrics');
select pg_temp.as_nobody();
select is(public.admin_dashboard_metrics(),
  '{"ok": false, "errorCode": "AUTH_REQUIRED"}'::jsonb,
  'no session gets AUTH_REQUIRED and no metrics');
select pg_temp.as_user('10000000-0000-4000-8000-000000000601');
select is((public.admin_dashboard_metrics())->'ok', 'true'::jsonb, 'the admin gets metrics');
reset role;

select is(has_function_privilege('anon', 'public.admin_dashboard_metrics()', 'EXECUTE'), false,
  'anon cannot execute the metrics function');
select is(has_function_privilege('authenticated', 'public.admin_dashboard_metrics()', 'EXECUTE'), true,
  'authenticated may execute it (and is refused inside unless admin)');
select is((select pg_get_function_identity_arguments(p.oid) from pg_proc p
           join pg_namespace n on n.oid = p.pronamespace
          where n.nspname = 'public' and p.proname = 'admin_dashboard_metrics'), '',
  'the function takes no arguments: it cannot be steered at an account');

-- A revoked admin is refused on the next call.
update public.admin_users set revoked_at = timezone('utc', now())
 where user_id = '10000000-0000-4000-8000-000000000601';
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-000000000601');
select is((public.admin_dashboard_metrics())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a revoked admin is refused immediately');
reset role;
insert into public.admin_users (user_id, note)
values ('10000000-0000-4000-8000-000000000601', 're-granted');

-- ===========================================================================
-- 2. Shape: complete, numeric, and free of anything identifying
-- ===========================================================================
select is((select m->>'contractVersion' from baseline), 'subscription_admin_contract_v1.1',
  'declares the contract version');
select is(
  (select array_agg(k order by k) from baseline, jsonb_object_keys(m) k),
  array['accounts','aiLooks','asOf','contractVersion','entitlements','expiringSoonWindowDays',
        'monthStartsAt','ok','purchasedCredits','salonPilot','todayStartsAt'],
  'the top-level keys are exactly the documented set');
select is(
  (select array_agg(k order by k) from baseline, jsonb_object_keys(m->'entitlements'->'inForceByPlan') k),
  array['free','plus','plus_preview','pro','pro_preview','salon_pilot','salon_preview','salon_pro'],
  'every canonical plan code is present in inForceByPlan, zero or not');
select ok(
  (select bool_and(jsonb_typeof(v) = 'number')
     from baseline, jsonb_each(m->'entitlements'->'inForceByPlan') e(k, v)),
  'every per-plan figure is a number');
select ok(
  (select bool_and(jsonb_typeof(v) = 'number')
     from baseline, jsonb_each(m->'accounts') e(k, v)),
  'account figures are numbers');
select ok(
  (select jsonb_typeof(m->'aiLooks'->'committedToday'->'subscription') = 'number'
      and jsonb_typeof(m->'aiLooks'->'committedThisMonth'->'purchasedCredit') = 'number'
      and jsonb_typeof(m->'aiLooks'->'reservedOpen') = 'number'
      and jsonb_typeof(m->'salonPilot'->'expiringSoon') = 'number'
      and jsonb_typeof(m->'purchasedCredits'->'activeGrants') = 'number'
     from baseline),
  'activity, pilot and credit figures are numbers');
select is((select (m->'asOf')::text ~ '^"20' from baseline), true, 'asOf is a server timestamp');
select is((select (m->'todayStartsAt')::text < (m->'asOf')::text from baseline), true,
  'today starts before now');
select is((select (m->>'expiringSoonWindowDays')::int from baseline), 14, 'the expiring window is stated');

-- Nothing identifying: no email, no uuid, no path, anywhere in the payload.
select is(
  (select m::text ~* '[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}' from baseline), false,
  'no email address appears in the payload');
select is(
  (select m::text ~* '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' from baseline), false,
  'no uuid appears in the payload');
select is((select m::text ~ '/analyses/|/previews/|storage_path|purchase_reference|purchaseToken|provider_order' from baseline), false,
  'no storage path or purchase reference appears in the payload');

-- ===========================================================================
-- 3. Correctness: fixtures move each figure by exactly the expected delta
-- ===========================================================================
-- Two new real accounts were inserted above (admin + normal).
select is(
  (select (pg_temp.metrics()->'accounts'->>'totalUsers')::bigint)
    - (select (m->'accounts'->>'totalUsers')::bigint from baseline),
  0::bigint,
  'totalUsers is unchanged by re-reading (stable)');

-- A guest account.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000', '10000000-0000-4000-8000-000000000603',
  'authenticated', 'authenticated', null, '',
  '{"provider":"anonymous","providers":["anonymous"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', true
);
select is(
  (select (pg_temp.metrics()->'accounts'->>'anonymousGuests')::bigint)
    - (select (m->'accounts'->>'anonymousGuests')::bigint from baseline),
  1::bigint, 'a guest sign-up adds one anonymous guest and no user');
select is(
  (select (pg_temp.metrics()->'accounts'->>'totalUsers')::bigint)
    - (select (m->'accounts'->>'totalUsers')::bigint from baseline),
  0::bigint, 'a guest does not count as a user');

-- The admin and the normal user were already in the baseline; the guest is
-- new and the sign-up trigger gave it its lifetime Free entitlement.
select is(
  (select (pg_temp.metrics()->'entitlements'->'inForceByPlan'->>'free')::bigint)
    - (select (m->'entitlements'->'inForceByPlan'->>'free')::bigint from baseline),
  1::bigint, 'free in force counts the provisioned lifetime entitlements');

-- The normal user buys Pro. Free stays (SUB-12 coexistence); Pro +1.
select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000602', 'facetune_pro', repeat('d', 64),
  'SUBSCRIPTION_STATE_ACTIVE', timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true);
select is(
  (select (pg_temp.metrics()->'entitlements'->'inForceByPlan'->>'pro')::bigint)
    - (select (m->'entitlements'->'inForceByPlan'->>'pro')::bigint from baseline),
  1::bigint, 'an active Pro subscription is in force');
select is(
  (select (pg_temp.metrics()->'entitlements'->'inForceByPlan'->>'free')::bigint)
    - (select (m->'entitlements'->'inForceByPlan'->>'free')::bigint from baseline),
  1::bigint, 'buying a plan does not remove the Free entitlement from the count');

-- Ledger activity as the normal user: 2 committed, 1 released, 1 reserved.
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-000000000602');
select public.reserve_ai_look('40000000-0000-4000-8000-000000000001');
select public.reserve_ai_look('40000000-0000-4000-8000-000000000002');
select public.reserve_ai_look('40000000-0000-4000-8000-000000000003');
select public.reserve_ai_look('40000000-0000-4000-8000-000000000004');
select public.release_ai_look('40000000-0000-4000-8000-000000000003', 'generation_failed');
reset role;
select public.commit_ai_look('40000000-0000-4000-8000-000000000001', 'standard',
  pg_temp.new_preview('10000000-0000-4000-8000-000000000602'));
select public.commit_ai_look('40000000-0000-4000-8000-000000000002', 'standard',
  pg_temp.new_preview('10000000-0000-4000-8000-000000000602'));

select is(
  (select (pg_temp.metrics()->'aiLooks'->'committedToday'->>'subscription')::bigint)
    - (select (m->'aiLooks'->'committedToday'->>'subscription')::bigint from baseline),
  2::bigint, 'two commits today from the subscription bucket');
select is(
  (select (pg_temp.metrics()->'aiLooks'->'committedThisMonth'->>'subscription')::bigint)
    - (select (m->'aiLooks'->'committedThisMonth'->>'subscription')::bigint from baseline),
  2::bigint, 'the same two commits this month');
select is(
  (select (pg_temp.metrics()->'aiLooks'->'committedToday'->>'purchasedCredit')::bigint)
    - (select (m->'aiLooks'->'committedToday'->>'purchasedCredit')::bigint from baseline),
  0::bigint, 'no purchased-credit commits: the buckets are not mixed');
select is(
  (select (pg_temp.metrics()->'aiLooks'->>'reservedOpen')::bigint)
    - (select (m->'aiLooks'->>'reservedOpen')::bigint from baseline),
  1::bigint, 'one reservation is still open');
select is(
  (select (pg_temp.metrics()->'aiLooks'->>'releasedToday')::bigint)
    - (select (m->'aiLooks'->>'releasedToday')::bigint from baseline),
  1::bigint, 'one release today');
select is(
  (select (pg_temp.metrics()->'aiLooks'->>'releasedThisMonth')::bigint)
    - (select (m->'aiLooks'->>'releasedThisMonth')::bigint from baseline),
  1::bigint, 'one release this month');

-- A committed row from last month is not "this month": backdate by insert.
insert into public.usage_ledger (
  user_id, entitlement_id, operation_id, status, source_mode, plan_code,
  allowance_unit, allowance_source, reserved_at, committed_at, created_at
)
select e.user_id, e.id, '40000000-0000-4000-8000-000000000005', 'committed', 'standard',
       'pro', 'ai_look', 'subscription',
       timezone('utc', now()) - interval '40 days',
       timezone('utc', now()) - interval '40 days',
       timezone('utc', now()) - interval '40 days'
  from public.user_entitlements e
 where e.user_id = '10000000-0000-4000-8000-000000000602' and e.plan_code = 'pro';
select is(
  (select (pg_temp.metrics()->'aiLooks'->'committedThisMonth'->>'subscription')::bigint)
    - (select (m->'aiLooks'->'committedThisMonth'->>'subscription')::bigint from baseline),
  2::bigint, 'a commit from 40 days ago is not counted this month');

-- Salon Pilot: one in force expiring in 5 days, one in force expiring in 60,
-- one already expired by date. Only the first is "expiring soon"; the third
-- is not in force at all.
insert into public.user_entitlements
  (user_id, plan_code, status, billing_provider, starts_at, expires_at, base_ai_look_allowance)
values
  ('10000000-0000-4000-8000-000000000601', 'salon_pilot', 'active', 'admin_granted',
   timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '5 days', 30);
select is(
  (select (pg_temp.metrics()->'salonPilot'->>'inForce')::bigint)
    - (select (m->'salonPilot'->>'inForce')::bigint from baseline),
  1::bigint, 'one Salon Pilot in force');
select is(
  (select (pg_temp.metrics()->'salonPilot'->>'expiringSoon')::bigint)
    - (select (m->'salonPilot'->>'expiringSoon')::bigint from baseline),
  1::bigint, 'a pilot ending in 5 days is expiring soon');
select is(
  (select (pg_temp.metrics()->'entitlements'->'inForceByPlan'->>'salon_pilot')::bigint)
    - (select (m->'entitlements'->'inForceByPlan'->>'salon_pilot')::bigint from baseline),
  1::bigint, 'and it appears in the per-plan table');

-- Move it to 60 days out: still in force, no longer soon.
update public.user_entitlements
   set expires_at = timezone('utc', now()) + interval '60 days'
 where user_id = '10000000-0000-4000-8000-000000000601' and plan_code = 'salon_pilot';
select is(
  (select (pg_temp.metrics()->'salonPilot'->>'expiringSoon')::bigint)
    - (select (m->'salonPilot'->>'expiringSoon')::bigint from baseline),
  0::bigint, 'a pilot ending in 60 days is not expiring soon');

-- Suspend it: out of the in-force figures, into suspended.
update public.user_entitlements set status = 'suspended'
 where user_id = '10000000-0000-4000-8000-000000000601' and plan_code = 'salon_pilot';
select is(
  (select (pg_temp.metrics()->'salonPilot'->>'inForce')::bigint)
    - (select (m->'salonPilot'->>'inForce')::bigint from baseline),
  0::bigint, 'a suspended pilot is not in force');
select is(
  (select (pg_temp.metrics()->'entitlements'->>'suspended')::bigint)
    - (select (m->'entitlements'->>'suspended')::bigint from baseline),
  1::bigint, 'and is counted as suspended');

-- Purchased credits: one live grant, then revoked.
select public.grant_verified_top_up_purchase(
  '10000000-0000-4000-8000-000000000602', 'facetune_ai_look_topup_1', repeat('e', 64), 'PURCHASED');
select is(
  (select (pg_temp.metrics()->'purchasedCredits'->>'activeGrants')::bigint)
    - (select (m->'purchasedCredits'->>'activeGrants')::bigint from baseline),
  1::bigint, 'a verified top-up is an active grant');
select public.revoke_top_up_purchase(repeat('e', 64), 'refunded', 'GPA.TEST');
select is(
  (select (pg_temp.metrics()->'purchasedCredits'->>'activeGrants')::bigint)
    - (select (m->'purchasedCredits'->>'activeGrants')::bigint from baseline),
  0::bigint, 'a refunded top-up is no longer active');

-- ===========================================================================
-- 4. The time-bucketed counts have an index to use
-- ===========================================================================
select ok(
  (select count(*) = 2 from pg_indexes
    where schemaname = 'public' and tablename = 'usage_ledger'
      and indexname in ('usage_ledger_committed_at_idx', 'usage_ledger_released_at_idx')),
  'the committed_at / released_at partial indexes exist');

select * from finish();
rollback;
