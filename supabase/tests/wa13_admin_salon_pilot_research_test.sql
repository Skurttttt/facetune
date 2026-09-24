-- WA-13 — Salon Pilot research metrics: per-pilot allowance/usage figures,
-- aggregate counts from the ledger and the SUB-13 telemetry, the cost rule
-- (not available without provider cost data), authorization, and bounds.
begin;

select plan(52);

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

create function pg_temp.research() returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_salon_pilot_research_metrics();
  reset role;
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.pilots(p_cursor text default null) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_list_salon_pilot_metrics(p_cursor);
  reset role;
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.grant_pilot(p_target uuid, p_key text, p_allowance int default 30) returns uuid
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot(p_target, '2027-06-30T23:59:59Z', 'WA-13 fixture', p_key, p_allowance, null);
  reset role;
  perform pg_temp.as_nobody();
  return (v->>'entitlementId')::uuid;
end;
$$;

create function pg_temp.new_preview(p_user uuid) returns uuid
language plpgsql set search_path = '' as $$
declare v_analysis uuid; v_rec uuid; v_img uuid;
begin
  select a.id into v_analysis from public.analyses a where a.user_id = p_user limit 1;
  if v_analysis is null then
    insert into public.analyses (user_id, original_image_path)
    values (p_user, p_user::text || '/analyses/x/original/SECRETSELFIE.jpg')
    returning id into v_analysis;
    insert into public.recommendations (user_id, analysis_id, makeup_style)
    values (p_user, v_analysis, 'natural');
  end if;
  select r.id into v_rec from public.recommendations r where r.user_id = p_user limit 1;
  insert into public.generated_images
    (user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values (p_user, v_analysis, v_rec,
          p_user::text || '/previews/SECRETPREVIEW-' || gen_random_uuid()::text || '.png',
          (select coalesce(max(g.generation_number), 0) + 1
             from public.generated_images g where g.recommendation_id = v_rec))
  returning id into v_img;
  return v_img;
end;
$$;

-- Reserve → commit `p_n` looks, recording telemetry for each like the Edge
-- Function does (as the service role writer would).
create function pg_temp.deliver(p_user uuid, p_n int, p_tokens int) returns void
language plpgsql set search_path = '' as $$
declare i int; op uuid; img uuid;
begin
  for i in 1..p_n loop
    op := gen_random_uuid();
    perform pg_temp.as_user(p_user);
    perform public.reserve_ai_look(op);
    img := pg_temp.new_preview(p_user);
    perform public.commit_ai_look(op, 'standard', img);
    perform pg_temp.as_nobody();
    if not public.record_ai_operation_metric(
      gen_random_uuid(), p_user, 'final_preview', 'succeeded', null, 'standard', op,
      null, null, img, 1200, 300, 'google_gemini', 'gemini-3.1-flash-image', 'v1',
      1, 900, 100, p_tokens, 0, 0, 800, 90, 1, '1K', null, null) then
      raise exception 'fixture telemetry rejected';
    end if;
  end loop;
end;
$$;

-- Reserve → release, recording a failed telemetry event.
create function pg_temp.fail(p_user uuid) returns void
language plpgsql set search_path = '' as $$
declare op uuid := gen_random_uuid();
begin
  perform pg_temp.as_user(p_user);
  perform public.reserve_ai_look(op);
  perform public.release_ai_look(op, 'GEN_FAILED');
  perform pg_temp.as_nobody();
  perform public.record_ai_operation_metric(
    gen_random_uuid(), p_user, 'final_preview', 'failed', 'PROVIDER_ERROR', 'standard', op,
    null, null, null, 4000, null, 'google_gemini', 'gemini-3.1-flash-image', 'v1', 2);
end;
$$;

-- Accounts.
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
  ('a0000000-0000-4000-8000-000000000a00'::uuid, 'wa13-admin@example.invalid'),
  ('a0000000-0000-4000-8000-000000000a01'::uuid, 'wa13-normal@example.invalid'),
  ('a0000000-0000-4000-8000-000000000001'::uuid, 'wa13-artist-1@example.invalid'),
  ('a0000000-0000-4000-8000-000000000002'::uuid, 'wa13-artist-2@example.invalid'),
  ('a0000000-0000-4000-8000-000000000003'::uuid, 'wa13-pro@example.invalid')
) as v(id, email);
insert into public.admin_users (user_id, note) values ('a0000000-0000-4000-8000-000000000a00', 'wa13');

-- ---------------------------------------------------------------------------
-- Authorization, and the empty state before any pilot exists
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('a0000000-0000-4000-8000-000000000a01');
select is((public.admin_salon_pilot_research_metrics())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot read research metrics');
select is((public.admin_list_salon_pilot_metrics(null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list pilot metrics');
select pg_temp.as_nobody();
select is((public.admin_salon_pilot_research_metrics())->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot read research metrics');
reset role;

create temp table empty_agg as select pg_temp.research() as r;
select is((select r->>'ok' from empty_agg), 'true', 'an admin may read research metrics');
select is((select (r->'pilots'->>'users') || '/' || (r->'pilots'->>'entitlements') || '/' || (r->'pilots'->>'inForce') from empty_agg),
  '0/0/0', 'empty pilot data: zero pilots, not an error');
select is((select (r->'aiLooks'->>'effectiveAllowance') || '/' || (r->'aiLooks'->>'committed') || '/' || (r->'aiLooks'->>'released') from empty_agg),
  '0/0/0', 'empty pilot data: zero AI Look figures');
select is((select (r->'operations'->>'telemetryEvents') || '/' || (r->'billableUsage'->>'totalTokens') from empty_agg),
  '0/0', 'empty pilot data: zero operations and usage');
select is((select jsonb_array_length(r->'items') || '/' || coalesce(r->>'nextCursor', 'none') from pg_temp.pilots() r),
  '0/none', 'empty pilot list: no rows, no cursor');

-- The cost rule: no provider cost data exists, so the metric is not available.
select is((select (r->'cost'->>'available') || '/' || (r->'cost'->>'reason') from empty_agg),
  'false/NO_PROVIDER_COST_DATA', 'cost per AI Look is reported as not available with a stable reason');
select is((select r->'cost'->'effectiveCostPerDeliveredAiLook' from empty_agg), 'null'::jsonb,
  'no cost figure is fabricated');
select is((select r->'cost'->'totalBillableCost' from empty_agg), 'null'::jsonb,
  'no spend figure is fabricated');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_salon_pilot_research_metrics', 'admin_list_salon_pilot_metrics')
      and (p.prosrc ~ '\m45\M' or p.prosrc ~* 'php|peso|₱')),
  0::bigint, 'no ₱45 planning assumption is hardcoded in the research functions');

-- ---------------------------------------------------------------------------
-- Fixtures: two pilots with usage and telemetry, and a Pro subscriber whose
-- activity must not be counted as pilot research.
-- ---------------------------------------------------------------------------
create temp table p1 as select pg_temp.grant_pilot('a0000000-0000-4000-8000-000000000001', 'wa13-g1') as id;
create temp table p2 as select pg_temp.grant_pilot('a0000000-0000-4000-8000-000000000002', 'wa13-g2', 10) as id;
-- +10 on pilot 1 through the audited ledger.
do $$
declare v_p1 uuid := (select id from p1);
begin
  perform pg_temp.as_user('a0000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  perform public.admin_adjust_salon_pilot_allowance(v_p1, 10, 'Panel extension', 'wa13-adj', null, null);
  reset role;
  perform pg_temp.as_nobody();
end $$;
select pg_temp.deliver('a0000000-0000-4000-8000-000000000001', 27, 1000);
select pg_temp.fail('a0000000-0000-4000-8000-000000000001');
select pg_temp.fail('a0000000-0000-4000-8000-000000000001');
select pg_temp.fail('a0000000-0000-4000-8000-000000000001');
select pg_temp.deliver('a0000000-0000-4000-8000-000000000002', 4, 500);
-- One open reservation on pilot 2.
select pg_temp.as_user('a0000000-0000-4000-8000-000000000002');
select public.reserve_ai_look('a2000000-0000-4000-8000-000000000001');
select pg_temp.as_nobody();
-- Tutorial telemetry for pilot 1 (two manifests succeeded, one manifest failed),
-- attributed through the canonical preview the way the Edge helper does.
create temp table previews as
select l.canonical_generated_image_id as id, row_number() over (order by l.committed_at, l.id) as n
  from public.usage_ledger l
 where l.user_id = 'a0000000-0000-4000-8000-000000000001' and l.status = 'committed';
select public.record_ai_operation_metric(gen_random_uuid(), 'a0000000-0000-4000-8000-000000000001',
  'tutorial_manifest', 'succeeded', null, 'standard', null, null, null, (select id from previews where n = 1), 800, null,
  'google_gemini', 'gemini-2.5-flash', 'tutorial_manifest_v4_1', 1, 400, 200, 600);
select public.record_ai_operation_metric(gen_random_uuid(), 'a0000000-0000-4000-8000-000000000001',
  'tutorial_manifest', 'succeeded', null, 'standard', null, null, null, (select id from previews where n = 2), 800, null,
  'google_gemini', 'gemini-2.5-flash', 'tutorial_manifest_v4_1', 1, 400, 200, 600);
select public.record_ai_operation_metric(gen_random_uuid(), 'a0000000-0000-4000-8000-000000000001',
  'tutorial_manifest', 'failed', 'PROVIDER_ERROR', 'standard', null, null, null, (select id from previews where n = 3), 3000, null,
  'google_gemini', 'gemini-2.5-flash', 'tutorial_manifest_v4_1', 2);
-- A Pro subscriber generating: never pilot research.
select public.activate_verified_google_play_subscription(
  'a0000000-0000-4000-8000-000000000003', 'facetune_pro', repeat('a', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '29 days', true, null, true);
select pg_temp.deliver('a0000000-0000-4000-8000-000000000003', 2, 700);

-- Telemetry rows must carry the pilot plan for the fixture to be meaningful.
select is((select count(*) from public.ai_operation_metrics where plan_code = 'salon_pilot'), 37::bigint,
  'fixture: 27 + 4 delivered, 3 failed, 3 tutorial events are stamped salon_pilot');
select is((select count(*) from public.ai_operation_metrics where plan_code = 'pro'), 2::bigint,
  'fixture: the Pro activity is stamped pro');

-- ---------------------------------------------------------------------------
-- Aggregate research metrics
-- ---------------------------------------------------------------------------
create temp table agg as select pg_temp.research() as r;
select is((select (r->'pilots'->>'users') || '/' || (r->'pilots'->>'entitlements') || '/' || (r->'pilots'->>'inForce') || '/' ||
                  (r->'pilots'->>'suspended') || '/' || (r->'pilots'->>'revoked') || '/' || (r->'pilots'->>'lapsedOrExpired') from agg),
  '2/2/2/0/0/0', 'two pilot users, two entitlements in force');
select is((select (r->'aiLooks'->>'grantedBase') || '/' || (r->'aiLooks'->>'adminAdjustmentsTotal') || '/' || (r->'aiLooks'->>'effectiveAllowance') from agg),
  '40/10/50', 'granted 30 + 10, adjustments +10, effective 50');
select is((select (r->'aiLooks'->>'committed') || '/' || (r->'aiLooks'->>'reserved') || '/' || (r->'aiLooks'->>'released') || '/' || (r->'aiLooks'->>'remaining') from agg),
  '31/1/3/19', 'committed 31 (27+4), 1 reserved, 3 released, remaining 19 (13 + 6)');
select is((select (r->'operations'->'finalPreview'->>'succeeded') || '/' || (r->'operations'->'finalPreview'->>'failed') from agg),
  '31/3', 'delivered and failed Final Preview operations from telemetry');
select is((select (r->'operations'->'tutorialManifest'->>'succeeded') || '/' || (r->'operations'->'tutorialManifest'->>'failed') || '/' || (r->'operations'->'tutorialStep'->>'succeeded') from agg),
  '2/1/0', 'tutorial operations by kind and outcome');
select is((select (r->'operations'->>'telemetryEvents') from agg), '37', 'only pilot-stamped telemetry is counted');
select is((select (r->'billableUsage'->>'providerAttempts') || '/' || (r->'billableUsage'->>'totalTokens') || '/' ||
                  (r->'billableUsage'->>'outputImages') from agg),
  '41/30200/31', 'billable usage in tracked units: attempts 31+6+4, tokens 27000+2000+1200, images 31');
select is((select (r->'billableUsage'->>'eventsWithTokenData') || '/' || (r->'billableUsage'->>'eventsWithoutTokenData') from agg),
  '33/4', 'events without usage metadata are counted apart, never silently zero');
select is((select (r->'cost'->>'available') from agg), 'false',
  'even with real usage data the cost metric stays unavailable: there is no price data');
select is((select r->'cost'->'effectiveCostPerDeliveredAiLook' from agg), 'null'::jsonb, 'no cost is derived from usage');
select is((select array_agg(k order by k) from agg, jsonb_object_keys(r) k),
  array['aiLooks','asOf','billableUsage','contractVersion','cost','ok','operations','pilots'],
  'the aggregate carries exactly the documented sections');
select is((select r::text ~* 'SECRETSELFIE|SECRETPREVIEW|storage_path|prompt|makeup_kit|product|email|user_id|canonical' from agg),
  false, 'the aggregate carries no content, product, prompt, or identity');

-- ---------------------------------------------------------------------------
-- Per-pilot metrics
-- ---------------------------------------------------------------------------
create temp table rows_ as select pg_temp.pilots() as r;
select is((select jsonb_array_length(r->'items') from rows_), 2, 'both pilots are listed');
select is(
  (select bool_and((a.i->>'createdAt', a.i->>'entitlementId') >= (b.i->>'createdAt', b.i->>'entitlementId'))
   from rows_, jsonb_array_elements(r->'items') with ordinality a(i, n)
   join (select * from rows_, jsonb_array_elements(r->'items') with ordinality b(i, n)) b on b.n = a.n + 1),
  true, 'rows are ordered newest grant first with a stable tie-break');
create temp table row1 as select i from rows_, jsonb_array_elements(r->'items') i
 where i->>'entitlementId' = (select id::text from p1);
select is((select (i->>'initialAllowance') || '/' || (i->>'adminAdjustmentsTotal') || '/' || (i->>'effectiveAllowance') from row1),
  '30/10/40', 'pilot 1: initial 30, adjustments +10, effective 40 (SOT §39 example shape)');
select is((select (i->>'committed') || '/' || (i->>'reserved') || '/' || (i->>'remaining') || '/' || (i->>'available') from row1),
  '27/0/13/13', 'pilot 1: committed 27, remaining 13');
select is((select (i->>'deliveredFinalPreviews') || '/' || (i->>'releasedOperations') from row1), '27/3',
  'pilot 1: 27 delivered Final Previews, 3 released operations');
select is((select (i->>'finalPreviewFailures') || '/' || (i->>'tutorialOperations') || '/' || (i->>'tutorialFailures') from row1),
  '3/2/1', 'pilot 1: telemetry failures and tutorial operations');
select is((select (i->>'providerAttempts') || '/' || (i->>'totalTokens') || '/' || (i->>'outputImages') from row1),
  '37/28200/27', 'pilot 1: billable usage in tracked units');
select is((select i->>'effectiveStatus' from row1), 'active', 'pilot 1 is active');
select is((select (i->>'expiresAt')::timestamptz from row1), '2027-06-30T23:59:59Z'::timestamptz, 'expiration is shown');
select isnt((select i->>'lastActivityAt' from row1), null, 'last activity is derived from the ledger');
create temp table row2 as select i from rows_, jsonb_array_elements(r->'items') i
 where i->>'entitlementId' = (select id::text from p2);
select is((select (i->>'effectiveAllowance') || '/' || (i->>'committed') || '/' || (i->>'reserved') || '/' || (i->>'available') from row2),
  '10/4/1/5', 'pilot 2: 10 granted, 4 committed, 1 open reservation, 5 available');
select is((select (i->>'tutorialOperations') || '/' || (i->>'finalPreviewFailures') from row2), '0/0',
  'pilot 2: telemetry is attributed per account, never mixed across pilots');
select is(
  (select array_agg(k order by k) from row1, jsonb_object_keys(i) k),
  array['adminAdjustmentsTotal','available','committed','createdAt','deliveredFinalPreviews','effectiveAllowance',
        'effectiveStatus','email','entitlementId','expiresAt','finalPreviewFailures','initialAllowance',
        'lastActivityAt','outputImages','providerAttempts','releasedOperations','remaining','reserved',
        'startsAt','storedStatus','totalTokens','tutorialFailures','tutorialOperations','userId'],
  'a pilot row carries exactly the approved fields');
select is((select r::text ~* 'SECRETSELFIE|SECRETPREVIEW|storage_path|prompt|makeup_kit|product_name|canonical|model_name|gemini' from rows_),
  false, 'pilot rows carry no content, product, prompt, or provider detail');
select is((select count(*) from rows_, jsonb_array_elements(r->'items') i where i->>'userId' = 'a0000000-0000-4000-8000-000000000003'),
  0::bigint, 'the Pro subscriber never appears in pilot research');

-- Pagination: thirty more pilots exceed one page; pages are bounded and disjoint.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token, is_anonymous
)
select '00000000-0000-0000-0000-000000000000', ('a0000000-0000-4000-8000-0000000001' || lpad(g::text, 2, '0'))::uuid,
  'authenticated', 'authenticated', 'wa13-filler-' || g || '@example.invalid', '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, timezone('utc', now()), timezone('utc', now()),
  '', '', '', '', false
from generate_series(1, 30) g;
insert into public.user_entitlements (user_id, plan_code, status, billing_provider, starts_at, expires_at, auto_renew, base_ai_look_allowance)
select ('a0000000-0000-4000-8000-0000000001' || lpad(g::text, 2, '0'))::uuid, 'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '30 days', false, 30
from generate_series(1, 30) g;
create temp table page1 as select pg_temp.pilots() as r;
select is((select jsonb_array_length(r->'items') from page1), 25, 'the first page is bounded to 25 pilots');
select isnt((select r->>'nextCursor' from page1), null, 'a further page is represented by a cursor');
create temp table page2 as select pg_temp.pilots((select r->>'nextCursor' from page1)) as r;
select is((select jsonb_array_length(r->'items') from page2), 7, 'the second page holds the remaining seven');
select is((select r->>'nextCursor' from page2), null, 'the last page has no cursor');
select is((select count(*) from page1 a, page2 b, jsonb_array_elements(a.r->'items') x, jsonb_array_elements(b.r->'items') y
   where x->>'entitlementId' = y->>'entitlementId'), 0::bigint, 'pages do not repeat a pilot');
select throws_ok($$ select pg_temp.pilots('not-a-cursor') $$, '22023', null, 'a malformed cursor is refused');
select is((select (r->'pilots'->>'entitlements') || '/' || (r->'aiLooks'->>'effectiveAllowance') from pg_temp.research() r),
  '32/950', 'aggregates reflect every pilot (32 entitlements, 50 + 30·30 effective)');

-- Performance: the aggregate reads use the indexes already in place and
-- return in one statement each; no unbounded row set leaves the server.
select is(
  (select count(*) from pg_indexes
    where schemaname = 'public'
      and indexname in ('user_entitlements_plan_status_idx', 'usage_ledger_entitlement_status_idx',
                        'ai_operation_metrics_plan_created_idx', 'ai_operation_metrics_user_created_idx')),
  4::bigint, 'the plan, entitlement-status, and telemetry indexes the reads rely on exist');

-- Privilege surface.
select is(has_function_privilege('anon', 'public.admin_salon_pilot_research_metrics()', 'EXECUTE'), false,
  'anon cannot read research metrics');
select is(has_function_privilege('service_role', 'public.admin_list_salon_pilot_metrics(text)', 'EXECUTE'), false,
  'the pilot list is not a service-role endpoint');
select is(has_function_privilege('authenticated', 'public.admin_salon_pilot_research_metrics()', 'EXECUTE'), true,
  'authenticated reaches research metrics and is checked inside');

select * from finish();
rollback;
