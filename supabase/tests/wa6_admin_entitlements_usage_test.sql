-- WA-6 — read-only entitlement and usage-ledger listings.
begin;

select plan(72);

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

create function pg_temp.entitlements(
  p_user uuid default null, p_plan text default null, p_status text default null,
  p_provider text default null, p_days int default null, p_cursor text default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('30000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_list_entitlements(
    p_user, p_plan, p_status, p_provider, p_days, p_cursor);
  reset role;
  return v;
end;
$$;

create function pg_temp.usage(
  p_user uuid default null, p_ent uuid default null, p_status text default null,
  p_plan text default null, p_source text default null,
  p_from timestamptz default null, p_to timestamptz default null,
  p_cursor text default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('30000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_list_usage(
    p_user, p_ent, p_status, p_plan, p_source, p_from, p_to, p_cursor);
  reset role;
  return v;
end;
$$;

-- A persisted canonical preview for a commit, as in the SUB-14 suites.
create function pg_temp.new_preview(p_user uuid) returns uuid
language plpgsql set search_path = '' as $$
declare v_analysis uuid; v_rec uuid; v_img uuid;
begin
  select a.id into v_analysis from public.analyses a
   where a.user_id = p_user limit 1;
  if v_analysis is null then
    insert into public.analyses (user_id, original_image_path)
    values (p_user, p_user::text || '/analyses/x/original/selfie.jpg')
    returning id into v_analysis;
    insert into public.recommendations (user_id, analysis_id, makeup_style)
    values (p_user, v_analysis, 'natural');
  end if;
  select r.id into v_rec from public.recommendations r
   where r.user_id = p_user limit 1;
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

-- Accounts: admin, a normal user, and three subscription fixtures. The auth
-- trigger provisions each lifetime Free entitlement.
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
  ('30000000-0000-4000-8000-000000000a00'::uuid, 'wa6-admin@example.invalid'),
  ('30000000-0000-4000-8000-000000000a01'::uuid, 'wa6-normal@example.invalid'),
  ('30000000-0000-4000-8000-000000000001'::uuid, 'wa6-pro@example.invalid'),
  ('30000000-0000-4000-8000-000000000002'::uuid, 'wa6-pilot@example.invalid'),
  ('30000000-0000-4000-8000-000000000003'::uuid, 'wa6-lapsed@example.invalid')
) as v(id, email);

insert into public.admin_users (user_id, note)
values ('30000000-0000-4000-8000-000000000a00', 'wa6 fixture');

-- Thirty filler accounts so the unfiltered listings exceed one page.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000',
  ('30000000-0000-4000-8000-0000000001' || lpad(g::text, 2, '0'))::uuid,
  'authenticated', 'authenticated',
  'wa6-filler-' || lpad(g::text, 2, '0') || '@example.invalid', '',
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', false
from generate_series(1, 30) as g;

-- Pro (Google Play, active) through the real activation writer.
select public.activate_verified_google_play_subscription(
  '30000000-0000-4000-8000-000000000001',
  'facetune_pro', repeat('6', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true
);

-- Salon Pilot in force, expiring in 10 days; and one whose stored status is
-- still `active` although its term ended yesterday.
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance, allowance_adjustment_total
) values (
  '31000000-0000-4000-8000-000000000002', '30000000-0000-4000-8000-000000000002',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '10 days',
  false, 30, 5
), (
  '31000000-0000-4000-8000-000000000003', '30000000-0000-4000-8000-000000000003',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '31 days', timezone('utc', now()) - interval '1 day',
  false, 30, 0
);

-- Ledger truth for the Pro account through the real writers: two commits,
-- one open reservation, one released failure.
select pg_temp.as_user('30000000-0000-4000-8000-000000000001');
select public.reserve_ai_look('32000000-0000-4000-8000-000000000001');
select public.commit_ai_look('32000000-0000-4000-8000-000000000001', 'standard',
  pg_temp.new_preview('30000000-0000-4000-8000-000000000001'));
select public.reserve_ai_look('32000000-0000-4000-8000-000000000002');
select public.commit_ai_look('32000000-0000-4000-8000-000000000002', 'standard',
  pg_temp.new_preview('30000000-0000-4000-8000-000000000001'));
select public.reserve_ai_look('32000000-0000-4000-8000-000000000003');
select public.reserve_ai_look('32000000-0000-4000-8000-000000000004');
select public.release_ai_look('32000000-0000-4000-8000-000000000004', 'GEN_FAILED');
select pg_temp.as_nobody();

-- ---------------------------------------------------------------------------
-- Authorization
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('30000000-0000-4000-8000-000000000a01');
select is((public.admin_list_entitlements())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list entitlements');
select is((public.admin_list_usage())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list usage');
select is((public.admin_list_usage(
  '30000000-0000-4000-8000-000000000a01'))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list even their own usage through the admin read');
select pg_temp.as_nobody();
select is((public.admin_list_entitlements())->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot list entitlements');
select is((public.admin_list_usage())->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot list usage');
reset role;

-- ---------------------------------------------------------------------------
-- Entitlements: filters
-- ---------------------------------------------------------------------------
create temp table by_user as
select pg_temp.entitlements(p_user => '30000000-0000-4000-8000-000000000001') as r;
select is((select r->>'ok' from by_user), 'true', 'an admin may list entitlements');
select is((select jsonb_array_length(r->'items') from by_user), 2,
  'the user filter returns every entitlement the account holds (Pro + Free)');
select is(
  (select string_agg(i->>'planCode', ',' order by i->>'planCode')
   from by_user, jsonb_array_elements(r->'items') i),
  'free,pro', 'both the lifetime Free row and the store row are listed');

create temp table pro as select pg_temp.entitlements(p_plan => 'pro') as r;
select is((select jsonb_array_length(r->'items') from pro), 1,
  'plan filter narrows to the Pro entitlement');
select is((select r->'items'->0->>'userId' from pro),
  '30000000-0000-4000-8000-000000000001', 'the Pro row belongs to the Pro account');
select is((select r->'items'->0->>'email' from pro), 'wa6-pro@example.invalid',
  'the row carries the account email for display');
select is((select r->'items'->0->>'billingProvider' from pro), 'google_play',
  'provider is the verified store provider');
select is((select r->'items'->0->>'effectiveStatus' from pro), 'active',
  'an in-force store row reads active');
select is((select (r->'items'->0->>'effectiveAllowance')::int from pro), 8,
  'effective allowance is the server figure');
select is((select (r->'items'->0->>'committedUsage')::int from pro), 2,
  'committed counts the two committed rows');
select is((select (r->'items'->0->>'reservedUsage')::int from pro), 1,
  'reserved counts the one open reservation');
select is((select (r->'items'->0->>'remainingAiLooks')::int from pro), 6,
  'remaining = effective - committed');
select is((select (r->'items'->0->>'availableAiLooks')::int from pro), 5,
  'available = effective - committed - reserved');
select is((select (r->'items'->0->>'autoRenew')::boolean from pro), true,
  'auto-renew is reported from the row');
select is(
  (select array_agg(k order by k) from pro, jsonb_object_keys(r->'items'->0) k),
  array['allowanceAdjustmentTotal','allowanceUnit','autoRenew','availableAiLooks',
        'baseAllowance','billingProvider','committedUsage','createdAt',
        'effectiveAllowance','effectiveStatus','email','entitlementId','expiresAt',
        'periodEnd','periodStart','planCode','planDisplayName','remainingAiLooks',
        'reservedUsage','startsAt','storedStatus','updatedAt','userId','version'],
  'an entitlement row carries exactly the approved fields');

-- The resolver and the list agree on the governing row's figures.
select is(
  (select jsonb_build_object(
     'effectiveAllowance', s->'effectiveAllowance', 'committedUsage', s->'committedUsage',
     'reservedUsage', s->'reservedUsage', 'availableAiLooks', s->'availableAiLooks',
     'remainingAiLooks', s->'remainingAiLooks')
   from (select public.admin_resolve_subscription_state_for_user(
     '30000000-0000-4000-8000-000000000a00',
     '30000000-0000-4000-8000-000000000001') s) x),
  (select jsonb_build_object(
     'effectiveAllowance', i->'effectiveAllowance', 'committedUsage', i->'committedUsage',
     'reservedUsage', i->'reservedUsage', 'availableAiLooks', i->'availableAiLooks',
     'remainingAiLooks', i->'remainingAiLooks')
   from pro, jsonb_array_elements(r->'items') i),
  'the list reports the same figures as the consumer resolver');

create temp table pilots as select pg_temp.entitlements(p_plan => 'salon_pilot') as r;
select is((select jsonb_array_length(r->'items') from pilots), 2,
  'plan filter returns both Salon Pilot rows');
select is(
  (select i->>'effectiveStatus' from pilots, jsonb_array_elements(r->'items') i
   where i->>'entitlementId' = '31000000-0000-4000-8000-000000000003'),
  'expired', 'a lapsed pilot still stored active reads expired');
select is(
  (select i->>'storedStatus' from pilots, jsonb_array_elements(r->'items') i
   where i->>'entitlementId' = '31000000-0000-4000-8000-000000000003'),
  'active', 'the stored status is reported alongside, unaltered');
select is(
  (select (i->>'effectiveAllowance')::int || '/' || (i->>'baseAllowance') || '+' ||
          (i->>'allowanceAdjustmentTotal')
   from pilots, jsonb_array_elements(r->'items') i
   where i->>'entitlementId' = '31000000-0000-4000-8000-000000000002'),
  '35/30+5', 'effective allowance includes the audited adjustment total');

select is((select jsonb_array_length(pg_temp.entitlements(p_status => 'expired')->'items')), 1,
  'status filter applies to the effective status');
select is((select pg_temp.entitlements(p_status => 'expired')->'items'->0->>'entitlementId'),
  '31000000-0000-4000-8000-000000000003', 'the expired filter finds the lapsed pilot');
select is((select jsonb_array_length(pg_temp.entitlements(
  p_provider => 'admin_granted', p_status => 'active')->'items')), 1,
  'provider and status filters combine');
select is((select jsonb_array_length(pg_temp.entitlements(p_days => 14)->'items')), 1,
  'expiration window finds only the pilot expiring within 14 days');
select is((select pg_temp.entitlements(p_days => 14)->'items'->0->>'entitlementId'),
  '31000000-0000-4000-8000-000000000002', 'the expiring pilot is the one in force');
select is((select jsonb_array_length(pg_temp.entitlements(p_days => 7)->'items')), 0,
  'a shorter window excludes it');
select is((select pg_temp.entitlements(p_plan => 'salon_pro')->>'nextCursor'), null,
  'an empty result has no cursor');

select throws_ok(
  $$ select pg_temp.entitlements(p_plan => 'premium') $$, '22023', null,
  'a plan outside the vocabulary is rejected, not coerced');
select throws_ok(
  $$ select pg_temp.entitlements(p_status => 'inactive') $$, '22023', null,
  'a status outside the vocabulary is rejected');
select throws_ok(
  $$ select pg_temp.entitlements(p_provider => 'stripe') $$, '22023', null,
  'a provider outside the vocabulary is rejected');
select throws_ok(
  $$ select pg_temp.entitlements(p_days => 0) $$, '22023', null,
  'an empty expiration window is rejected');

-- ---------------------------------------------------------------------------
-- Entitlements: pagination
-- ---------------------------------------------------------------------------
create temp table ent_page1 as select pg_temp.entitlements() as r;
select is((select (r->>'pageSize')::int from ent_page1), 25, 'page size is fixed at 25');
select is((select jsonb_array_length(r->'items') from ent_page1), 25,
  'the browser receives at most 25 entitlement rows');
select isnt((select r->>'nextCursor' from ent_page1), null,
  'a further page is represented by a server cursor');
select is((select r->'sort'->>'field' || ' ' || (r->'sort'->>'direction') from ent_page1),
  'createdAt desc', 'sorting is fixed newest first');
create temp table ent_page2 as
select pg_temp.entitlements(p_cursor => (select r->>'nextCursor' from ent_page1)) as r;
select ok((select jsonb_array_length(r->'items') between 1 and 25 from ent_page2),
  'the continuation page is bounded and non-empty');
select is((
  select count(*)
  from ent_page1 a, ent_page2 b,
       jsonb_array_elements(a.r->'items') x, jsonb_array_elements(b.r->'items') y
  where x->>'entitlementId' = y->>'entitlementId'
), 0::bigint, 'keyset pages do not repeat an entitlement');
select throws_ok(
  $$ select pg_temp.entitlements(p_plan => 'free',
       p_cursor => (select r->>'nextCursor' from ent_page1)) $$,
  '22023', null, 'a cursor issued for other filters is refused');
select throws_ok(
  $$ select pg_temp.entitlements(p_cursor => 'not-a-cursor') $$, '22023', null,
  'a malformed cursor is refused');

-- ---------------------------------------------------------------------------
-- Usage: canonical states, filters, and failure visibility
-- ---------------------------------------------------------------------------
create temp table pro_usage as
select pg_temp.usage(p_user => '30000000-0000-4000-8000-000000000001') as r;
select is((select r->>'ok' from pro_usage), 'true', 'an admin may list usage');
select is((select jsonb_array_length(r->'items') from pro_usage), 4,
  'the user filter returns all four ledger rows');
select is(
  (select string_agg(i->>'status', ',' order by i->>'operationId')
   from pro_usage, jsonb_array_elements(r->'items') i),
  'committed,committed,reserved,released',
  'statuses are exactly the canonical reserved / committed / released');
select is(
  (select array_agg(k order by k) from pro_usage, jsonb_object_keys(r->'items'->0) k),
  array['allowanceSource','allowanceUnit','canonicalPreviewRetained','committedAt',
        'createdAt','email','entitlementId','operationId','periodEnd','periodStart',
        'planCode','releasedAt','reservedAt','sanitizedFailureCode','sourceMode',
        'status','updatedAt','usageId','usageType','userId'],
  'a usage row carries exactly the approved fields');
select is((select r::text ~* 'image_id|storage_path|signed.?url|prompt|gemini|makeup_kit|selfie|analysis' from pro_usage),
  false, 'usage rows carry no image reference or private content');
select is((select r::text ~* 'image_id|storage_path|signed.?url|prompt|gemini|makeup_kit|selfie|analysis' from ent_page1),
  false, 'entitlement rows carry no image reference or private content');

-- Released failure vs committed success.
create temp table released as
select pg_temp.usage(p_user => '30000000-0000-4000-8000-000000000001',
  p_status => 'released') as r;
select is((select jsonb_array_length(r->'items') from released), 1,
  'status filter isolates the released operation');
select is((select r->'items'->0->>'operationId' from released),
  '32000000-0000-4000-8000-000000000004', 'the released row is the failed operation');
select is((select r->'items'->0->>'sanitizedFailureCode' from released), 'GEN_FAILED',
  'the sanitized failure code is visible on the released row');
select is((select r->'items'->0->'committedAt' from released), 'null'::jsonb,
  'a released row has no commit timestamp');
select isnt((select r->'items'->0->>'releasedAt' from released), null,
  'a released row has its release timestamp');
select is((select r->'items'->0->'sourceMode' from released), 'null'::jsonb,
  'a released row claims no preview lineage');

create temp table committed as
select pg_temp.usage(p_user => '30000000-0000-4000-8000-000000000001',
  p_status => 'committed') as r;
select is((select jsonb_array_length(r->'items') from committed), 2,
  'status filter isolates the two committed operations');
select is(
  (select bool_and(i->>'sanitizedFailureCode' is null and i->>'committedAt' is not null
                   and i->>'releasedAt' is null and i->>'sourceMode' = 'standard'
                   and (i->>'canonicalPreviewRetained')::boolean)
   from committed, jsonb_array_elements(r->'items') i),
  true, 'committed rows carry a commit time, a source mode, retained lineage, and no failure');
select is(
  (select bool_and(i->>'planCode' = 'pro' and i->>'allowanceUnit' = 'ai_look'
                   and i->>'allowanceSource' = 'subscription')
   from pro_usage, jsonb_array_elements(r->'items') i),
  true, 'rows carry their stamped provenance');

select is((select jsonb_array_length(pg_temp.usage(
  p_ent => '31000000-0000-4000-8000-000000000002')->'items')), 0,
  'entitlement filter with no rows is an empty result');
select is((select jsonb_array_length(pg_temp.usage(
  p_plan => 'pro', p_status => 'reserved')->'items')), 1,
  'plan and status filters combine');
select is((select jsonb_array_length(pg_temp.usage(
  p_to => timezone('utc', now()) - interval '1 day')->'items')), 0,
  'a date range before the fixtures returns nothing');
select throws_ok(
  $$ select pg_temp.usage(p_status => 'spent') $$, '22023', null,
  'a usage status outside the vocabulary is rejected');
select throws_ok(
  $$ select pg_temp.usage(p_from => timezone('utc', now()),
       p_to => timezone('utc', now()) - interval '1 hour') $$, '22023', null,
  'an inverted date range is rejected');

-- ---------------------------------------------------------------------------
-- Usage: pagination (thirty historical released rows for the pilot)
-- ---------------------------------------------------------------------------
insert into public.usage_ledger (
  user_id, entitlement_id, operation_id, status, reserved_at, released_at,
  sanitized_failure_code, created_at, plan_code, allowance_unit, allowance_source
)
select
  '30000000-0000-4000-8000-000000000002', '31000000-0000-4000-8000-000000000002',
  gen_random_uuid(), 'released',
  timezone('utc', now()) - interval '1 hour' * g,
  timezone('utc', now()) - interval '1 hour' * g + interval '1 minute',
  'GEN_FAILED',
  timezone('utc', now()) - interval '1 hour' * g,
  'salon_pilot', 'ai_look', 'subscription'
from generate_series(1, 30) as g;

create temp table usage_page1 as select pg_temp.usage() as r;
select is((select jsonb_array_length(r->'items') from usage_page1), 25,
  'the browser receives at most 25 usage rows');
select isnt((select r->>'nextCursor' from usage_page1), null,
  'a further usage page is represented by a server cursor');
create temp table usage_page2 as
select pg_temp.usage(p_cursor => (select r->>'nextCursor' from usage_page1)) as r;
select is((select jsonb_array_length(r->'items') from usage_page2), 9,
  'the continuation page holds the remaining rows');
select is((select r->>'nextCursor' from usage_page2), null,
  'the last page has no cursor');
select is((
  select count(*)
  from usage_page1 a, usage_page2 b,
       jsonb_array_elements(a.r->'items') x, jsonb_array_elements(b.r->'items') y
  where x->>'usageId' = y->>'usageId'
), 0::bigint, 'keyset usage pages do not repeat a row');
select is((select jsonb_array_length(pg_temp.usage(
  p_ent => '31000000-0000-4000-8000-000000000002', p_status => 'committed')->'items')), 0,
  'the pilot has no committed rows: released failures never count as consumption');

-- ---------------------------------------------------------------------------
-- Privilege surface
-- ---------------------------------------------------------------------------
select is(has_function_privilege('anon',
  'public.admin_list_entitlements(uuid,text,text,text,integer,text)', 'EXECUTE'),
  false, 'anon cannot execute the entitlement listing');
select is(has_function_privilege('service_role',
  'public.admin_list_usage(uuid,uuid,text,text,text,timestamptz,timestamptz,text)', 'EXECUTE'),
  false, 'the usage listing is not a service-role endpoint');

select * from finish();
rollback;
