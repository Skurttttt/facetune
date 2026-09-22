-- WA-12 — security, privacy and abuse hardening: negative tests over the
-- whole Web Admin surface. Everything here is an attack that must fail, or
-- a boundary that must hold, against the deployed privilege model.
begin;

select plan(71);

create function pg_temp.claims(p_json text) returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config('request.jwt.claims', p_json, true);
end;
$$;

create function pg_temp.as_user(p_user uuid) returns void
language plpgsql set search_path = '' as $$
begin
  perform pg_temp.claims(json_build_object('sub', p_user, 'role', 'authenticated')::text);
end;
$$;

create function pg_temp.adjust(p_admin uuid, p_ent uuid, p_amount int, p_key text) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_adjust_salon_pilot_allowance(p_ent, p_amount, 'WA-12', p_key, null, null);
  reset role;
  return v;
end;
$$;

create function pg_temp.search(p_admin uuid, p_q text) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_search_users(p_q, null);
  reset role;
  return v;
end;
$$;

-- Everything an admin session can read, as that session, for the privacy scan.
create function pg_temp.all_reads(p_admin uuid, p_target uuid, p_ent uuid) returns text
language plpgsql set search_path = '' as $$
declare v text; v_event uuid;
begin
  select id into v_event from public.admin_audit_events
   where target_entitlement_id = p_ent order by created_at limit 1;
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_dashboard_metrics()::text
    || public.admin_search_users(null, null)::text
    || public.admin_get_user(p_target)::text
    || public.admin_list_entitlements(p_target, null, null, null, null, null)::text
    || public.admin_list_usage(p_target, null, null, null, null, null, null, null)::text
    || public.admin_list_audit_events(null, null, p_target, null, null, null, null, null)::text
    || public.admin_list_entitlement_history(p_ent, null)::text
    || public.admin_get_audit_event(v_event)::text;
  reset role;
  return v;
end;
$$;

-- Accounts: two admins, one revoked, one banned, one anonymous roster
-- entry, a normal user, and a pilot artist with private content.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous, banned_until
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated',
  'authenticated', v.email, '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', v.anon, v.banned
from (values
  ('90000000-0000-4000-8000-000000000a00'::uuid, 'wa12-admin-a@example.invalid', false, null::timestamptz),
  ('90000000-0000-4000-8000-000000000a02'::uuid, 'wa12-admin-b@example.invalid', false, null),
  ('90000000-0000-4000-8000-000000000a03'::uuid, 'wa12-admin-revoked@example.invalid', false, null),
  ('90000000-0000-4000-8000-000000000a04'::uuid, 'wa12-admin-banned@example.invalid', false, timezone('utc', now()) + interval '1 day'),
  ('90000000-0000-4000-8000-000000000a05'::uuid, null, true, null),
  ('90000000-0000-4000-8000-000000000a01'::uuid, 'wa12-normal@example.invalid', false, null),
  ('90000000-0000-4000-8000-000000000001'::uuid, 'wa12-artist@example.invalid', false, null)
) as v(id, email, anon, banned);

insert into public.admin_users (user_id, note) values
  ('90000000-0000-4000-8000-000000000a00', 'wa12 A'),
  ('90000000-0000-4000-8000-000000000a02', 'wa12 B'),
  ('90000000-0000-4000-8000-000000000a03', 'wa12 to be revoked'),
  ('90000000-0000-4000-8000-000000000a04', 'wa12 banned');
update public.admin_users
   set revoked_at = timezone('utc', now()), revoked_by = '90000000-0000-4000-8000-000000000a00'
 where user_id = '90000000-0000-4000-8000-000000000a03';

-- The artist's private content, which no admin read may surface.
insert into public.analyses (id, user_id, original_image_path)
  values ('90000000-0000-4000-8000-0000000000c0', '90000000-0000-4000-8000-000000000001',
          '90000000-0000-4000-8000-000000000001/analyses/x/original/SECRETSELFIE.jpg');
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
  values ('90000000-0000-4000-8000-0000000000c1', '90000000-0000-4000-8000-000000000001',
          '90000000-0000-4000-8000-0000000000c0', 'natural');
insert into public.generated_images (id, user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values ('90000000-0000-4000-8000-0000000000c2', '90000000-0000-4000-8000-000000000001',
          '90000000-0000-4000-8000-0000000000c0', '90000000-0000-4000-8000-0000000000c1',
          '90000000-0000-4000-8000-000000000001/previews/SECRETPREVIEW.png', 1);

-- A pilot granted by admin A, with one committed AI Look on the private preview.
do $$
declare v jsonb;
begin
  perform pg_temp.as_user('90000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot('90000000-0000-4000-8000-000000000001',
        '2027-06-30T23:59:59Z', 'WA-12 fixture', 'wa12-grant', 30, null);
  reset role;
  perform set_config('wa12.pilot', v->>'entitlementId', true);
  perform pg_temp.as_user('90000000-0000-4000-8000-000000000001');
  perform public.reserve_ai_look('92000000-0000-4000-8000-000000000001');
  perform public.commit_ai_look('92000000-0000-4000-8000-000000000001', 'standard',
    '90000000-0000-4000-8000-0000000000c2');
  perform pg_temp.claims('');
end $$;

-- ===========================================================================
-- 1. Authentication / authorization: who is refused
-- ===========================================================================
set local role authenticated;

-- 1a. Unauthenticated (no claims).
select pg_temp.claims('');
select is(public.current_user_is_admin(), false, 'no session is not an admin');
select is((public.admin_dashboard_metrics())->>'errorCode', 'AUTH_REQUIRED', 'no session: reads refused');
select is((public.admin_adjust_salon_pilot_allowance(current_setting('wa12.pilot')::uuid, 1, 'x', 'k', null, null))->>'errorCode',
  'AUTH_REQUIRED', 'no session: writers refused');

-- 1b. Normal user.
select pg_temp.as_user('90000000-0000-4000-8000-000000000a01');
select is(public.current_user_is_admin(), false, 'a normal user is not an admin');
select is((public.admin_search_users('wa12-artist@example.invalid', null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'normal user: search refused');
select is((public.admin_get_user('90000000-0000-4000-8000-000000000001'))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'normal user: detail refused');
select is((public.admin_list_audit_events())->>'errorCode', 'ADMIN_UNAUTHORIZED', 'normal user: audit refused');
select is((public.admin_grant_salon_pilot('90000000-0000-4000-8000-000000000a01', '2027-01-01T00:00:00Z', 'x', 'k', 30, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'normal user: cannot grant themselves a pilot');
select is((public.admin_set_salon_pilot_lifecycle(current_setting('wa12.pilot')::uuid, 'revoke_entitlement', 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'normal user: cannot revoke another account''s pilot (cross-user mutation impossible)');

-- 1c. Forged browser claims: the roster, not the token, decides.
select pg_temp.claims('{"sub":"90000000-0000-4000-8000-000000000a01","role":"service_role"}');
select is(public.current_user_is_admin(), false, 'a forged role claim does not make an admin');
select is((public.admin_dashboard_metrics())->>'errorCode', 'ADMIN_UNAUTHORIZED', 'forged role claim: reads refused');
select pg_temp.claims('{"sub":"90000000-0000-4000-8000-000000000a01","role":"authenticated","app_metadata":{"role":"admin"},"is_admin":true,"user_metadata":{"admin":true}}');
select is(public.current_user_is_admin(), false, 'forged app_metadata / is_admin claims are ignored');
select is((public.admin_adjust_salon_pilot_allowance(current_setting('wa12.pilot')::uuid, 1, 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'forged claims: writers refused');
select pg_temp.claims('{"sub":"90000000-0000-4000-8000-000000000a00","role":"anon"}');
select is(public.current_user_is_admin(), true,
  'sanity: the roster answers for the subject; the role claim is irrelevant to it (PostgREST, not this function, maps role to privileges)');

-- 1d. Revoked, banned, and anonymous roster entries.
select pg_temp.as_user('90000000-0000-4000-8000-000000000a03');
select is(public.current_user_is_admin(), false, 'a revoked admin is not an admin');
select is((public.admin_get_user('90000000-0000-4000-8000-000000000001'))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'revoked admin: reads refused immediately, no rebuild or token refresh needed');
select is((public.admin_adjust_salon_pilot_allowance(current_setting('wa12.pilot')::uuid, 1, 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'revoked admin: writers refused');
select pg_temp.as_user('90000000-0000-4000-8000-000000000a04');
select is(public.current_user_is_admin(), false, 'a banned account is not an admin even if on the roster');
reset role;
select throws_ok(
  $$ insert into public.admin_users (user_id, note) values ('90000000-0000-4000-8000-000000000a05', 'anon') $$,
  'P0001', null, 'an anonymous guest cannot even be placed on the roster (WA-2 guard)');
set local role authenticated;
select pg_temp.as_user('90000000-0000-4000-8000-000000000a05');
select is(public.current_user_is_admin(), false, 'an anonymous guest is not an admin');

-- 1e. The admin roster cannot be written by any client role.
select pg_temp.as_user('90000000-0000-4000-8000-000000000a01');
select throws_ok(
  $$ insert into public.admin_users (user_id, note) values ('90000000-0000-4000-8000-000000000a01', 'self') $$,
  '42501', null, 'a user cannot grant themselves admin');
select throws_ok(
  $$ select count(*) from public.admin_users $$,
  '42501', null, 'a user cannot even read the roster');
select pg_temp.as_user('90000000-0000-4000-8000-000000000a00');
select throws_ok(
  $$ insert into public.admin_users (user_id, note) values ('90000000-0000-4000-8000-000000000a01', 'promote') $$,
  '42501', null, 'an admin session cannot promote another account through the API either (provisioning is operator SQL)');
select throws_ok(
  $$ update public.admin_users set revoked_at = null where user_id = '90000000-0000-4000-8000-000000000a03' $$,
  '42501', null, 'an admin session cannot un-revoke through the API');
reset role;
set local role service_role;
select throws_ok(
  $$ insert into public.admin_users (user_id, note) values ('90000000-0000-4000-8000-000000000a01', 'svc') $$,
  '42501', null, 'the service role holds no roster write either');
reset role;

-- ===========================================================================
-- 2. RLS / backend: users cannot touch monetization or audit rows
-- ===========================================================================
set local role authenticated;
select pg_temp.as_user('90000000-0000-4000-8000-000000000001');
select throws_ok(
  $$ update public.user_entitlements set base_ai_look_allowance = 999 where user_id = '90000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'a user cannot edit their entitlement');
select throws_ok(
  $$ update public.user_entitlements set status = 'active' where user_id = '90000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'a user cannot change their entitlement status');
select throws_ok(
  $$ update public.usage_ledger set status = 'released' where user_id = '90000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'a user cannot rewrite their usage ledger');
select throws_ok(
  $$ delete from public.usage_ledger where user_id = '90000000-0000-4000-8000-000000000001' $$,
  '42501', null, 'a user cannot delete usage history');
select throws_ok(
  $$ insert into public.entitlement_allowance_adjustments (entitlement_id, target_user_id, admin_user_id, adjustment_type, amount, reason, idempotency_key)
     values (current_setting('wa12.pilot')::uuid, '90000000-0000-4000-8000-000000000001', '90000000-0000-4000-8000-000000000a00', 'increase_allowance', 100, 'x', 'k') $$,
  '42501', null, 'a user cannot write an allowance adjustment');
select throws_ok(
  $$ select count(*) from public.admin_audit_events $$,
  '42501', null, 'a user cannot read the audit log');
select throws_ok(
  $$ update public.admin_audit_events set reason = 'x' $$,
  '42501', null, 'a user cannot edit the audit log');
select throws_ok(
  $$ delete from public.admin_audit_events $$,
  '42501', null, 'a user cannot delete the audit log');
select throws_ok(
  $$ select count(*) from public.admin_rate_limit_buckets $$,
  '42501', null, 'a user cannot read the rate-limit counters');
select throws_ok(
  $$ delete from public.admin_rate_limit_buckets $$,
  '42501', null, 'a user cannot reset the rate-limit counters');
-- An admin session has the same table posture: privilege comes only through RPCs.
select pg_temp.as_user('90000000-0000-4000-8000-000000000a00');
select throws_ok(
  $$ update public.user_entitlements set base_ai_look_allowance = 999 where id = current_setting('wa12.pilot')::uuid $$,
  '42501', null, 'an admin session cannot edit an entitlement directly');
select throws_ok(
  $$ update public.admin_audit_events set reason = 'x' $$,
  '42501', null, 'an admin session cannot edit the audit log');
select throws_ok(
  $$ delete from public.admin_rate_limit_buckets $$,
  '42501', null, 'an admin session cannot reset its own budget');
reset role;
select is(
  (select string_agg(c.relname, ',' order by c.relname)
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  null, 'RLS is enabled on every public table, including the WA-12 counter table');
select is(has_function_privilege('authenticated', 'public.admin_consume_budget(uuid,text)', 'EXECUTE'), false,
  'the budget function is not client-callable');
select is(has_function_privilege('service_role', 'public.admin_consume_budget(uuid,text)', 'EXECUTE'), false,
  'the budget function is not a service-role endpoint');

-- ===========================================================================
-- 3. Privacy: no admin read surfaces private content
-- ===========================================================================
create temp table reads as
select pg_temp.all_reads('90000000-0000-4000-8000-000000000a00', '90000000-0000-4000-8000-000000000001',
  current_setting('wa12.pilot')::uuid) as t;
select ok((select length(t) > 2000 from reads), 'the scan covers substantial output from all eight admin reads');
select is((select t ~ 'SECRETSELFIE|SECRETPREVIEW' from reads), false,
  'no admin read returns a selfie or preview storage path');
select is((select t ~* 'storage_path|storagePath|signed.?url|original_image_path|analysis_id|recommendation_id' from reads), false,
  'no admin read returns image lineage or storage fields');
select is((select t ~* 'canonical_generated_image_id|canonicalGeneratedImageId|kit_generated|makeup_kit_items' from reads), false,
  'no admin read returns a canonical image id or kit inventory');
select is((select t ~* 'prompt|gemini|model_name|provider_subscription_reference|purchase_?token|purchase_?reference|message_id' from reads), false,
  'no admin read returns prompts, Gemini data, provider references, or purchase tokens');
select is((select t ~ 'eyJ[A-Za-z0-9_-]{20,}' from reads), false, 'no admin read returns a JWT');

-- ===========================================================================
-- 4. Abuse: per-administrator budgets
-- ===========================================================================
-- Admin A has used 1 mutation (the fixture grant). 29 more succeed; the 31st
-- in the same minute is throttled and writes nothing.
do $$
declare i int; v jsonb;
begin
  for i in 1..29 loop
    v := pg_temp.adjust('90000000-0000-4000-8000-000000000a00', current_setting('wa12.pilot')::uuid,
           case when i % 2 = 0 then -1 else 1 end, 'wa12-budget-' || i);
    if (v->>'success')::boolean is not true then
      raise exception 'mutation % unexpectedly refused: %', i, v;
    end if;
  end loop;
end $$;
select is((select count(*) from public.entitlement_allowance_adjustments where entitlement_id = current_setting('wa12.pilot')::uuid),
  29::bigint, '29 adjustments applied within budget');
create temp table throttled as
select pg_temp.adjust('90000000-0000-4000-8000-000000000a00', current_setting('wa12.pilot')::uuid, 1, 'wa12-budget-31') as r;
select is((select r->>'success' || '/' || (r->>'errorCode') || '/' || (r->>'retryable') || '/' || (r->>'throttled') from throttled),
  'false/TEMPORARY_BACKEND_FAILURE/true/true', 'the 31st mutation in the minute is throttled: retryable, marked throttled');
select is((select count(*) from public.entitlement_allowance_adjustments where entitlement_id = current_setting('wa12.pilot')::uuid),
  29::bigint, 'a throttled mutation writes no ledger row');
select is((select count(*) from public.admin_audit_events where target_entitlement_id = current_setting('wa12.pilot')::uuid),
  30::bigint, 'a throttled mutation writes no audit event (grant + 29)');
select is((pg_temp.adjust('90000000-0000-4000-8000-000000000a00', current_setting('wa12.pilot')::uuid, 1, 'wa12-budget-31'))->>'throttled',
  'true', 'retrying while throttled stays throttled (attempts count)');
select is((pg_temp.adjust('90000000-0000-4000-8000-000000000a00', current_setting('wa12.pilot')::uuid, 1, 'wa12-budget-1'))->>'throttled',
  'true', 'even a would-be replay is throttled: the budget is checked before any work');
select is((select hits from public.admin_rate_limit_buckets
   where admin_user_id = '90000000-0000-4000-8000-000000000a00' and budget_class = 'mutation'), 33,
  'refused attempts are counted (30 + 3 refused)');
-- Admin B is unaffected; the budget is per administrator.
select is((select r->>'success' from pg_temp.adjust('90000000-0000-4000-8000-000000000a02',
  current_setting('wa12.pilot')::uuid, 1, 'wa12-b-1') r), 'true', 'another administrator has their own budget');
-- Lifecycle writers draw from the same mutation budget as adjustments.
do $$ begin perform pg_temp.as_user('90000000-0000-4000-8000-000000000a00'); set local role authenticated; end $$;
select is((public.admin_set_salon_pilot_lifecycle(current_setting('wa12.pilot')::uuid, 'suspend_entitlement', 'x', 'wa12-susp', null, null))->>'throttled',
  'true', 'a throttled admin cannot suspend either');
select is((public.admin_extend_salon_pilot_expiration(current_setting('wa12.pilot')::uuid, '2027-12-31T00:00:00Z', 'x', 'wa12-ext', null, null))->>'throttled',
  'true', 'a throttled admin cannot extend either');
select is((public.admin_grant_salon_pilot('90000000-0000-4000-8000-000000000a01', '2027-12-31T00:00:00Z', 'x', 'wa12-g2', 30, null))->>'throttled',
  'true', 'a throttled admin cannot grant either');
reset role;
select is((select status from public.user_entitlements where id = current_setting('wa12.pilot')::uuid), 'active',
  'nothing was applied while throttled');
-- Reads are bounded by design, not budgeted: a throttled admin still reads.
select is((select r->>'ok' from (select public.admin_get_user('90000000-0000-4000-8000-000000000001') r
   from (select pg_temp.as_user('90000000-0000-4000-8000-000000000a00')) x) y), 'true',
  'read RPCs remain available to a throttled admin (they are bounded, not counted)');
-- Search budget: 60 lookups, then throttled; replay-safe error shape.
do $$
declare i int; v jsonb;
begin
  for i in 1..60 loop
    v := pg_temp.search('90000000-0000-4000-8000-000000000a02', 'wa12-artist@example.invalid');
    if v->>'ok' <> 'true' then raise exception 'search % unexpectedly refused: %', i, v; end if;
  end loop;
end $$;
select is((select r->>'ok' || '/' || (r->>'errorCode') || '/' || (r->>'throttled')
   from pg_temp.search('90000000-0000-4000-8000-000000000a02', 'wa12-artist@example.invalid') r),
  'false/TEMPORARY_BACKEND_FAILURE/true', 'the 61st account lookup in the minute is throttled');
select is((select r->>'ok' from pg_temp.search('90000000-0000-4000-8000-000000000a00', 'wa12-artist@example.invalid') r),
  'true', 'search budget is per administrator too');
select is((select count(*) from public.admin_rate_limit_buckets), 4::bigint,
  'counters are one row per administrator and class per minute (A+B mutation, A+B search)');

-- Old buckets are swept when an administrator next acts.
insert into public.admin_rate_limit_buckets (admin_user_id, budget_class, bucket_start, hits)
  values ('90000000-0000-4000-8000-000000000a02', 'mutation', timezone('utc', now()) - interval '1 hour', 30);
select pg_temp.adjust('90000000-0000-4000-8000-000000000a02', current_setting('wa12.pilot')::uuid, -1, 'wa12-b-2');
select is((select count(*) from public.admin_rate_limit_buckets
   where admin_user_id = '90000000-0000-4000-8000-000000000a02' and bucket_start < timezone('utc', now()) - interval '10 minutes'),
  0::bigint, 'expired buckets are swept and never count against the current minute');

-- ===========================================================================
-- 5. Direct API invocation and the privileged path are the same gate
-- ===========================================================================
select is(
  (select bool_and(p.proconfig::text like '%search_path=%')
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'),
  true, 'every admin function has a locked search_path');
select is(
  (select bool_and(p.prosecdef)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  true, 'every client-callable admin function is security definer');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and p.prosrc not like '%public.is_admin(v_caller)%'
      and p.proname <> 'current_user_is_admin'),
  0::bigint, 'every client-callable admin RPC checks the roster inside (direct invocation is gated identically)');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
      and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0::bigint, 'anon can execute no admin function');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'admin\_%'
      and has_function_privilege('service_role', p.oid, 'EXECUTE')),
  0::bigint, 'service_role can execute no admin function (no privileged key is useful to the browser path)');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in (
      'admin_grant_salon_pilot', 'admin_adjust_salon_pilot_allowance',
      'admin_extend_salon_pilot_expiration', 'admin_set_salon_pilot_lifecycle')
      and p.prosrc like '%admin_consume_budget(v_caller, ''mutation'')%'),
  4::bigint, 'all four privileged writers consume the mutation budget');
select is(
  (select p.prosrc like '%admin_consume_budget(v_caller, ''search'')%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_search_users'),
  true, 'account search consumes the search budget');

select * from finish();
rollback;
