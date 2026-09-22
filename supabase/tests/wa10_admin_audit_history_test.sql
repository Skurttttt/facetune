-- WA-10 — authorized, immutable audit inspection and entitlement history.
begin;

select plan(62);

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

create function pg_temp.audit_list(
  p_admin uuid default null, p_action text default null,
  p_user uuid default null, p_from timestamptz default null,
  p_to timestamptz default null, p_ent uuid default null,
  p_source text default null, p_cursor text default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('70000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_list_audit_events(
    p_admin, p_action, p_user, p_from, p_to, p_ent, p_source, p_cursor);
  reset role;
  return v;
end;
$$;

create function pg_temp.audit_detail(p_event uuid) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('70000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_get_audit_event(p_event);
  reset role;
  return v;
end;
$$;

create function pg_temp.history(p_ent uuid, p_cursor text default null)
returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('70000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_list_entitlement_history(p_ent, p_cursor);
  reset role;
  return v;
end;
$$;

create function pg_temp.grant_once() returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('70000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot(
    '70000000-0000-4000-8000-000000000001',
    timezone('utc', now()) + interval '30 days',
    'WA-10 exact-once fixture', 'wa10-grant-once', 30,
    '70000000-0000-4000-8000-0000000000c1'
  );
  reset role;
  return v;
end;
$$;

-- Admin, normal caller, mutation target, audit filler target, history target.
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
  ('70000000-0000-4000-8000-000000000a00'::uuid, 'wa10-admin@example.invalid'),
  ('70000000-0000-4000-8000-000000000a01'::uuid, 'wa10-normal@example.invalid'),
  ('70000000-0000-4000-8000-000000000001'::uuid, 'wa10-grant@example.invalid'),
  ('70000000-0000-4000-8000-000000000002'::uuid, 'wa10-pages@example.invalid'),
  ('70000000-0000-4000-8000-000000000003'::uuid, 'wa10-history@example.invalid')
) as v(id, email);

insert into public.admin_users (user_id, note)
values ('70000000-0000-4000-8000-000000000a00', 'wa10 fixture');

insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance, allowance_adjustment_total
) values (
  '71000000-0000-4000-8000-000000000003',
  '70000000-0000-4000-8000-000000000003',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '10 days',
  timezone('utc', now()) + interval '20 days', false, 30, 10
);

-- A complete, deliberately ordered admin lifecycle for the history target.
insert into public.admin_audit_events (
  id, source, admin_user_id, action, target_user_id, target_entitlement_id,
  before_state, after_state, reason, request_correlation_id,
  idempotency_key, created_at
)
select
  v.id, 'admin', '70000000-0000-4000-8000-000000000a00', v.action,
  '70000000-0000-4000-8000-000000000003',
  '71000000-0000-4000-8000-000000000003',
  v.before_state, v.after_state, v.reason, v.correlation, v.key, v.created_at
from (values
  (
    '72000000-0000-4000-8000-000000000001'::uuid, 'grant_salon_pilot',
    null::jsonb,
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":30,"allowanceAdjustmentTotal":0,"expiresAt":"2026-10-20T00:00:00Z","version":1}'::jsonb,
    'Pilot cohort granted', '72000000-0000-4000-8000-0000000000c1'::uuid,
    'wa10-history-1', timezone('utc', now()) - interval '6 days'
  ),
  (
    '72000000-0000-4000-8000-000000000002'::uuid, 'increase_allowance',
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":30,"allowanceAdjustmentTotal":0,"expiresAt":"2026-10-20T00:00:00Z","version":1}'::jsonb,
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-10-20T00:00:00Z","version":2}'::jsonb,
    'Panel extension', '72000000-0000-4000-8000-0000000000c2'::uuid,
    'wa10-history-2', timezone('utc', now()) - interval '5 days'
  ),
  (
    '72000000-0000-4000-8000-000000000003'::uuid, 'extend_expiration',
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-10-20T00:00:00Z","version":2}'::jsonb,
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":3}'::jsonb,
    'Approved pilot extension', '72000000-0000-4000-8000-0000000000c3'::uuid,
    'wa10-history-3', timezone('utc', now()) - interval '4 days'
  ),
  (
    '72000000-0000-4000-8000-000000000004'::uuid, 'suspend_entitlement',
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":3}'::jsonb,
    '{"status":"suspended","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":4}'::jsonb,
    'Temporary hold', '72000000-0000-4000-8000-0000000000c4'::uuid,
    'wa10-history-4', timezone('utc', now()) - interval '3 days'
  ),
  (
    '72000000-0000-4000-8000-000000000005'::uuid, 'reactivate_entitlement',
    '{"status":"suspended","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":4}'::jsonb,
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":5}'::jsonb,
    'Research resumed', '72000000-0000-4000-8000-0000000000c5'::uuid,
    'wa10-history-5', timezone('utc', now()) - interval '2 days'
  ),
  (
    '72000000-0000-4000-8000-000000000006'::uuid, 'revoke_entitlement',
    '{"status":"active","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":5}'::jsonb,
    '{"status":"revoked","planCode":"salon_pilot","effectiveAllowance":40,"allowanceAdjustmentTotal":10,"expiresAt":"2026-11-20T00:00:00Z","version":6}'::jsonb,
    'Cohort ended', '72000000-0000-4000-8000-0000000000c6'::uuid,
    'wa10-history-6', timezone('utc', now()) - interval '1 day'
  )
) as v(id, action, before_state, after_state, reason, correlation, key, created_at);

-- Only these sanitized provider columns participate in history. The message
-- id and purchase reference below are canaries that must never leave the RPC.
insert into public.provider_notification_events (
  id, billing_provider, message_id, notification_kind, notification_type,
  purchase_reference, event_time, outcome, user_id, entitlement_id,
  received_at, processed_at
) values (
  '73000000-0000-4000-8000-000000000001', 'google_play',
  'provider-secret-message', 'subscription', 2, repeat('f', 64),
  timezone('utc', now()) - interval '3 days 12 hours', 'reconciled',
  '70000000-0000-4000-8000-000000000003',
  '71000000-0000-4000-8000-000000000003',
  timezone('utc', now()) - interval '3 days 12 hours',
  timezone('utc', now()) - interval '3 days 11 hours'
);

-- Thirty rows under one target prove bounded keyset pagination.
insert into public.admin_audit_events (
  id, source, admin_user_id, action, target_user_id, target_entitlement_id,
  before_state, after_state, reason, request_correlation_id,
  idempotency_key, created_at
)
select
  ('74000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
  'admin', '70000000-0000-4000-8000-000000000a00', 'increase_allowance',
  '70000000-0000-4000-8000-000000000002', null,
  '{"status":"active","planCode":"salon_pilot","effectiveAllowance":30,"allowanceAdjustmentTotal":0,"expiresAt":null,"version":1}'::jsonb,
  '{"status":"active","planCode":"salon_pilot","effectiveAllowance":31,"allowanceAdjustmentTotal":1,"expiresAt":null,"version":2}'::jsonb,
  'Pagination fixture ' || g,
  ('75000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
  'wa10-page-' || g,
  timezone('utc', now()) - make_interval(mins => g)
from generate_series(1, 30) as g;

-- ---------------------------------------------------------------------------
-- Authorization
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('70000000-0000-4000-8000-000000000a01');
select is((public.admin_list_audit_events())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list audit events');
select is((public.admin_get_audit_event('72000000-0000-4000-8000-000000000001'))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'a normal user cannot read audit detail');
select is((public.admin_list_entitlement_history('71000000-0000-4000-8000-000000000003'))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'a normal user cannot read entitlement history');
select pg_temp.as_nobody();
select is((public.admin_list_audit_events())->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot list audit events');
select is((public.admin_get_audit_event('72000000-0000-4000-8000-000000000001'))->>'errorCode',
  'AUTH_REQUIRED', 'an unauthenticated caller cannot read audit detail');
select is((public.admin_list_entitlement_history('71000000-0000-4000-8000-000000000003'))->>'errorCode',
  'AUTH_REQUIRED', 'an unauthenticated caller cannot read history');
reset role;

-- ---------------------------------------------------------------------------
-- A real mutation and its retry appear exactly once
-- ---------------------------------------------------------------------------
create temp table first_grant as select pg_temp.grant_once() as r;
create temp table replay_grant as select pg_temp.grant_once() as r;
select is((select r->>'success' from first_grant), 'true', 'the fixture mutation succeeds');
select is((select r->>'replayed' from replay_grant), 'true', 'the duplicate is replayed');
select is((select count(*) from public.user_entitlements
  where user_id = '70000000-0000-4000-8000-000000000001' and plan_code = 'salon_pilot'),
  1::bigint, 'the duplicate request creates one entitlement');
select is((select count(*) from public.admin_audit_events
  where target_user_id = '70000000-0000-4000-8000-000000000001'
    and action = 'grant_salon_pilot'), 1::bigint,
  'the duplicate request creates one audit event');

-- ---------------------------------------------------------------------------
-- Audit list pagination and filters
-- ---------------------------------------------------------------------------
create temp table page1 as
select pg_temp.audit_list(p_user => '70000000-0000-4000-8000-000000000002') as r;
create temp table page2 as
select pg_temp.audit_list(
  p_user => '70000000-0000-4000-8000-000000000002',
  p_cursor => (select r->>'nextCursor' from page1)
) as r;
select is((select jsonb_array_length(r->'items') from page1), 25,
  'the first audit page is bounded to 25');
select isnt((select r->>'nextCursor' from page1), null,
  'the first page has a next cursor');
select is((select jsonb_array_length(r->'items') from page2), 5,
  'the second page returns the remaining five events');
select is((select r->>'nextCursor' from page2), null,
  'the last page has no cursor');
select is((select count(*) from page1 p1, page2 p2,
  jsonb_array_elements(p1.r->'items') a,
  jsonb_array_elements(p2.r->'items') b where a->>'id' = b->>'id'),
  0::bigint, 'keyset pages do not overlap');
select is((select bool_and(
    (a.value->>'createdAt')::timestamptz >= (b.value->>'createdAt')::timestamptz)
  from page1, jsonb_array_elements(r->'items') with ordinality a(value, n)
  join jsonb_array_elements((select r->'items' from page1)) with ordinality b(value, n)
    on b.n = a.n + 1), true, 'audit results are newest first');
select throws_ok(
  format($q$select pg_temp.audit_list(
    p_user => '70000000-0000-4000-8000-000000000002',
    p_action => 'revoke_entitlement', p_cursor => %L)$q$,
    (select r->>'nextCursor' from page1)),
  '22023', null, 'a cursor cannot be reused with different filters');

select ok(jsonb_array_length(pg_temp.audit_list(
  p_admin => '70000000-0000-4000-8000-000000000a00')->'items') > 0,
  'admin identity filter returns that administrator');
select is(jsonb_array_length(pg_temp.audit_list(p_action => 'revoke_entitlement')->'items'),
  1, 'action filter finds the revoke event');
select is(jsonb_array_length(pg_temp.audit_list(
  p_user => '70000000-0000-4000-8000-000000000002')->'items'),
  25, 'target-user filter applies before pagination');
select is(jsonb_array_length(pg_temp.audit_list(
  p_ent => '71000000-0000-4000-8000-000000000003')->'items'),
  6, 'target-entitlement filter finds its six admin events');
select is(jsonb_array_length(pg_temp.audit_list(
  p_from => timezone('utc', now()) - interval '25 hours',
  p_to => timezone('utc', now()) - interval '23 hours')->'items'),
  1, 'date filters use a half-open range');
select ok(jsonb_array_length(pg_temp.audit_list(p_source => 'admin')->'items') > 0,
  'event-source filter applies');
select is(jsonb_array_length(pg_temp.audit_list(
  p_user => '70000000-0000-4000-8000-000000000002',
  p_action => 'increase_allowance')->'items'),
  25, 'filters combine on the server');
select throws_ok($$select pg_temp.audit_list(p_action => 'adjust_allowance')$$,
  '22023', null, 'an invented action is rejected');
select throws_ok($$select pg_temp.audit_list(p_source => 'browser')$$,
  '22023', null, 'an invented source is rejected');
select throws_ok($$select pg_temp.audit_list(
  p_from => timezone('utc', now()), p_to => timezone('utc', now()) - interval '1 day')$$,
  '22023', null, 'an inverted date range is rejected');

-- ---------------------------------------------------------------------------
-- Detail is complete but privacy-minimal
-- ---------------------------------------------------------------------------
create temp table detail as
select pg_temp.audit_detail('72000000-0000-4000-8000-000000000002') as r;
select is((select r->>'ok' from detail), 'true', 'an admin may read audit detail');
select is((select r->'event'->>'action' from detail), 'increase_allowance',
  'detail names the canonical action');
select is((select r->'event'->>'adminEmail' from detail), 'wa10-admin@example.invalid',
  'detail identifies the administrator');
select is((select r->'event'->>'targetEmail' from detail), 'wa10-history@example.invalid',
  'detail identifies the target account');
select is((select r->'event'->>'reason' from detail), 'Panel extension',
  'detail contains the required reason');
select is((select r->'event'->>'requestCorrelationId' from detail),
  '72000000-0000-4000-8000-0000000000c2', 'detail contains request correlation');
select is((select array_agg(k order by k) from detail,
  jsonb_object_keys(r->'event'->'beforeState') k),
  array['allowanceAdjustmentTotal','effectiveAllowance','expiresAt','planCode','status','version'],
  'before state exposes only the six reviewed fields');
select is((select array_agg(k order by k) from detail,
  jsonb_object_keys(r->'event'->'afterState') k),
  array['allowanceAdjustmentTotal','effectiveAllowance','expiresAt','planCode','status','version'],
  'after state exposes only the six reviewed fields');
select is((select r::text ~* 'selfie|storage.?path|signed.?url|prompt|gemini|purchase.?token|jwt|service.?role'
  from detail), false, 'detail leaks no sensitive payload');
select is((pg_temp.audit_detail('72999999-9999-4999-8999-999999999999')->'event')::text,
  'null',
  'an unknown audit id returns no event');
select throws_ok($$
  insert into public.admin_audit_events (
    source, admin_user_id, action, target_user_id, before_state
  ) values (
    'admin', '70000000-0000-4000-8000-000000000a00', 'increase_allowance',
    '70000000-0000-4000-8000-000000000002',
    '{"status":"active","purchaseToken":"secret"}'::jsonb
  )$$, '23514', null, 'snapshot storage rejects an unreviewed key');
select is((select bool_and(not has_table_privilege(r, 'public.admin_audit_events', p))
  from unnest(array['anon','authenticated','service_role']) r,
       unnest(array['SELECT','INSERT','UPDATE','DELETE']) p),
  true, 'no client role can read or mutate the audit table');

-- ---------------------------------------------------------------------------
-- Entitlement history is meaningful, ordered and provider-safe
-- ---------------------------------------------------------------------------
create temp table history as
select pg_temp.history('71000000-0000-4000-8000-000000000003') as r;
select is((select jsonb_array_length(r->'items') from history), 7,
  'history includes six admin events and one provider event');
select is((select string_agg(i->>'eventType', ',' order by n)
  from history, jsonb_array_elements(r->'items') with ordinality x(i, n)),
  'revoke_entitlement,reactivate_entitlement,suspend_entitlement,provider_state_change,extend_expiration,increase_allowance,grant_salon_pilot',
  'lifecycle events are newest first across both authoritative sources');
select is((select count(*) from history,
  jsonb_array_elements(r->'items') i where i->>'source' = 'provider'),
  1::bigint, 'provider-driven state is distinguished from admin actions');
select is((select array_agg(k order by k) from history,
  jsonb_array_elements(r->'items') i, jsonb_object_keys(i) k
  where i->>'source' = 'provider'),
  array['action','actorEmail','actorUserId','afterState','beforeState','eventType','id','occurredAt','provider','reason','requestCorrelationId','source'],
  'provider history exposes only the reviewed event shape');
select is((select r::text ~ ('provider-secret-message|' || repeat('f', 64)) from history),
  false, 'provider message and purchase references do not leak');
select is((select r->>'nextCursor' from history), null,
  'a short history has no next cursor');
select throws_ok($$select pg_temp.history(
  '71000000-0000-4000-8000-000000000003', 'not-a-cursor')$$,
  '22023', null, 'an invalid history cursor is rejected');
select is(jsonb_array_length(pg_temp.history(
  '71999999-9999-4999-8999-999999999999')->'items'),
  0, 'an unrelated entitlement has no history');
select is((select i->>'reason' from history,
  jsonb_array_elements(r->'items') i where i->>'eventType' = 'increase_allowance'),
  'Panel extension', 'timeline preserves the operational reason');
select is((select array_agg(k order by k) from history,
  jsonb_array_elements(r->'items') i,
  jsonb_object_keys(i->'afterState') k
  where i->>'eventType' = 'increase_allowance'),
  array['allowanceAdjustmentTotal','effectiveAllowance','expiresAt','planCode','status','version'],
  'timeline snapshots stay inside the privacy allowlist');
select is((select (i->'afterState')::text from history,
  jsonb_array_elements(r->'items') i where i->>'source' = 'provider'),
  'null', 'a reconciliation does not fabricate provider before/after state');

-- ---------------------------------------------------------------------------
-- Execute surface and immutability
-- ---------------------------------------------------------------------------
select is(has_function_privilege('anon',
  'public.admin_list_audit_events(uuid,text,uuid,timestamptz,timestamptz,uuid,text,text)', 'EXECUTE'),
  false, 'anon cannot execute the audit list');
select is(has_function_privilege('service_role',
  'public.admin_list_audit_events(uuid,text,uuid,timestamptz,timestamptz,uuid,text,text)', 'EXECUTE'),
  false, 'service_role does not own the session audit endpoint');
select is(has_function_privilege('authenticated',
  'public.admin_list_audit_events(uuid,text,uuid,timestamptz,timestamptz,uuid,text,text)', 'EXECUTE'),
  true, 'authenticated reaches the self-authorizing audit list');
select is(has_function_privilege('anon', 'public.admin_get_audit_event(uuid)', 'EXECUTE'),
  false, 'anon cannot execute audit detail');
select is(has_function_privilege('service_role', 'public.admin_get_audit_event(uuid)', 'EXECUTE'),
  false, 'service_role does not own audit detail');
select is(has_function_privilege('authenticated', 'public.admin_get_audit_event(uuid)', 'EXECUTE'),
  true, 'authenticated reaches self-authorizing audit detail');
select is(has_function_privilege('anon',
  'public.admin_list_entitlement_history(uuid,text)', 'EXECUTE'),
  false, 'anon cannot execute entitlement history');
select is(has_function_privilege('service_role',
  'public.admin_list_entitlement_history(uuid,text)', 'EXECUTE'),
  false, 'service_role does not own entitlement history');
select is(has_function_privilege('authenticated',
  'public.admin_list_entitlement_history(uuid,text)', 'EXECUTE'),
  true, 'authenticated reaches self-authorizing entitlement history');
select is(has_function_privilege('authenticated',
  'public.admin_safe_audit_snapshot(jsonb)', 'EXECUTE'),
  false, 'the snapshot helper is not a client endpoint');
select throws_ok($$update public.admin_audit_events set reason = 'rewritten'
  where id = '72000000-0000-4000-8000-000000000002'$$,
  'P0001', 'admin audit events are immutable', 'an audit reason remains immutable');
select throws_ok($$update public.admin_audit_events set created_at = timezone('utc', now())
  where id = '72000000-0000-4000-8000-000000000002'$$,
  'P0001', 'admin audit events are immutable', 'an audit timestamp remains immutable');

select * from finish();
rollback;
