-- WA-5 â€” exact user search, keyset pagination, and sanitized detail.
begin;

select plan(39);

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

create function pg_temp.search(p_search text, p_cursor text default null)
returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('20000000-0000-4000-8000-000000000900');
  set local role authenticated;
  v := public.admin_search_users(p_search, p_cursor);
  reset role;
  return v;
end;
$$;

create function pg_temp.detail(p_user uuid)
returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('20000000-0000-4000-8000-000000000900');
  set local role authenticated;
  v := public.admin_get_user(p_user);
  reset role;
  return v;
end;
$$;

-- Active admin + normal user.
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
  ('20000000-0000-4000-8000-000000000900'::uuid, 'wa5-admin@example.invalid'),
  ('20000000-0000-4000-8000-000000000901'::uuid, 'wa5-normal@example.invalid')
) as v(id, email);

insert into public.admin_users (user_id, note)
values ('20000000-0000-4000-8000-000000000900', 'wa5 fixture');

-- Thirty accounts newer than any real/local account exercise a bounded first
-- page deterministically. The auth trigger provisions each lifetime Free row.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
)
select
  '00000000-0000-0000-0000-000000000000',
  ('20000000-0000-4000-8000-' || lpad(g::text, 12, '0'))::uuid,
  'authenticated', 'authenticated',
  'wa5-user-' || lpad(g::text, 2, '0') || '@example.invalid', '',
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  '2099-01-01 00:00:00+00'::timestamptz + g * interval '1 minute',
  timezone('utc', now()), '', '', '', '', false
from generate_series(1, 30) as g;

-- The exact email target has an active Pro entitlement so summary and detail
-- prove the same governing-row precedence as the consumer resolver.
select public.activate_verified_google_play_subscription(
  '20000000-0000-4000-8000-000000000001',
  'facetune_pro', repeat('5', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true
);

-- Authorization: no rows ever leave before the roster check.
set local role authenticated;
select pg_temp.as_user('20000000-0000-4000-8000-000000000901');
select is((public.admin_search_users(null, null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot list accounts');
select is((public.admin_get_user('20000000-0000-4000-8000-000000000001'))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'a normal user cannot read account detail');
select pg_temp.as_nobody();
select is((public.admin_search_users(null, null))->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot search');
reset role;

-- Exact email only, case-insensitive input; no partial matching.
create temp table exact_email as
select pg_temp.search('WA5-USER-01@EXAMPLE.INVALID') as r;
select is((select r->>'ok' from exact_email), 'true', 'an admin may search');
select is((select jsonb_array_length(r->'items') from exact_email), 1,
  'exact email returns one account');
select is((select r->'items'->0->>'userId' from exact_email),
  '20000000-0000-4000-8000-000000000001', 'email resolves the stable user id');
select is((select r->'items'->0->>'currentPlanCode' from exact_email), 'pro',
  'summary uses the governing Pro entitlement instead of lifetime Free');
select is((select r->'items'->0->>'entitlementStatus' from exact_email), 'active',
  'summary reports effective entitlement status');
select is((select jsonb_array_length(pg_temp.search('wa5-user-01')->'items')), 0,
  'partial email lookup is not enabled');

-- User-id search and no-result state.
select is((select jsonb_array_length(pg_temp.search(
  '20000000-0000-4000-8000-000000000001')->'items')), 1,
  'exact user id returns one account');
select is((select pg_temp.search(
  '20000000-0000-4000-8000-000000000001')->'items'->0->>'email'),
  'wa5-user-01@example.invalid', 'user id lookup returns the matching email');
select is((select jsonb_array_length(pg_temp.search(
  'nobody@example.invalid')->'items')), 0, 'unknown exact email is an empty result');
select is((select pg_temp.search('nobody@example.invalid')->>'nextCursor'), null,
  'an empty result has no cursor');

-- Fixed page size, fixed sort, and keyset continuation.
create temp table first_page as select pg_temp.search(null) as r;
select is((select (r->>'pageSize')::integer from first_page), 25,
  'the page size is fixed at 25');
select is((select jsonb_array_length(r->'items') from first_page), 25,
  'the browser receives at most the first 25 rows');
select isnt((select r->>'nextCursor' from first_page), null,
  'a further page is represented by a server cursor');
select is((select r->'sort'->>'field' from first_page), 'accountCreatedAt',
  'the only sort field is explicit');
select is((select r->'sort'->>'direction' from first_page), 'desc',
  'sorting is fixed newest first');
select is((select r->'items'->0->>'userId' from first_page),
  '20000000-0000-4000-8000-000000000030', 'newest fixture is first');

create temp table second_page as
select pg_temp.search(null, (select r->>'nextCursor' from first_page)) as r;
select ok((select jsonb_array_length(r->'items') <= 25 from second_page),
  'the continuation page is also bounded');
select is((
  select count(*)
  from first_page f, second_page s,
       jsonb_array_elements(f.r->'items') a,
       jsonb_array_elements(s.r->'items') b
  where a->>'userId' = b->>'userId'
), 0::bigint, 'keyset pages do not repeat an account');
select is((
  select count(*) from first_page, jsonb_array_elements(r->'items')
), 25::bigint, 'large datasets never produce more than one browser page');

-- Detail, not found, and sanitized exact shapes.
select is((pg_temp.detail('29999999-9999-4999-8999-999999999999'))->>'errorCode',
  'USER_NOT_FOUND', 'missing detail returns the stable not-found code');
create temp table detail as
select pg_temp.detail('20000000-0000-4000-8000-000000000001') as r;
select is((select r->>'ok' from detail), 'true', 'existing user detail succeeds');
select is(
  (select array_agg(k order by k) from detail, jsonb_object_keys(r->'user') k),
  array['accountCreatedAt','accountStatus','email','userId'],
  'account identity contains only the four approved fields');
select is(
  (select array_agg(k order by k) from detail, jsonb_object_keys(r->'entitlement') k),
  array['allowanceUnit','autoRenew','availableAiLooks','billingProvider','committedUsage',
        'createdAt','effectiveAllowance','effectiveStatus','entitlementId','expiresAt',
        'periodEnd','periodStart','planCode','planDisplayName','remainingAiLooks',
        'reservedUsage','startsAt','storedStatus','updatedAt','version'],
  'entitlement detail contains only subscription-relevant fields');
select is((select r->'entitlement'->>'planCode' from detail), 'pro',
  'detail shows the current plan');
select is((select (r->'entitlement'->>'effectiveAllowance')::integer from detail), 8,
  'detail shows the server-resolved allowance');
select is((select (r->'entitlement'->>'committedUsage')::integer from detail), 0,
  'detail shows committed usage');
select is((select (r->'entitlement'->>'reservedUsage')::integer from detail), 0,
  'detail shows reserved usage');
select is((select (r->'entitlement'->>'remainingAiLooks')::integer from detail), 8,
  'detail shows server-authoritative remaining usage');
select is((select r::text ~* 'selfie|storage_path|signed.?url|prompt|gemini|makeup_kit|raw_ai|analysis' from detail),
  false, 'detail contains no private facial or AI data');
select is((select r::text ~* 'selfie|storage_path|signed.?url|prompt|gemini|makeup_kit|raw_ai|analysis' from first_page),
  false, 'list contains no private facial or AI data');

-- The temporary resolver impersonation restores the caller exactly.
set local role authenticated;
select pg_temp.as_user('20000000-0000-4000-8000-000000000900');
select public.admin_search_users('wa5-user-01@example.invalid', null);
select is(public.current_user_is_admin(), true,
  'target subscription resolution restores the real admin claims');
reset role;

-- Privilege surface: the reads are session-callable and self-authorizing;
-- the target resolver is not an API endpoint.
select is(has_function_privilege('anon', 'public.admin_search_users(text,text)', 'EXECUTE'),
  false, 'anon cannot execute search');
select is(has_function_privilege('authenticated', 'public.admin_search_users(text,text)', 'EXECUTE'),
  true, 'authenticated reaches search and is checked inside');
select is(has_function_privilege('authenticated', 'public.admin_get_user(uuid)', 'EXECUTE'),
  true, 'authenticated reaches detail and is checked inside');
select is(has_function_privilege('authenticated',
  'public.admin_resolve_subscription_state_for_user(uuid,uuid)', 'EXECUTE'),
  false, 'the target resolver is not client-callable');
select is(has_function_privilege('service_role',
  'public.admin_resolve_subscription_state_for_user(uuid,uuid)', 'EXECUTE'),
  false, 'the target resolver is not a service-role endpoint either');

select * from finish();
rollback;
