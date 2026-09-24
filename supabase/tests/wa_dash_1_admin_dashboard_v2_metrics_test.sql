-- WA-DASH-1 — Dashboard V2 authoritative read contract: security posture,
-- the bounded 30-day UTC series, delivery attribution by plan and by
-- allowance unit, and the governing-entitlement status distribution.
--
-- Committed ledger rows are inserted directly with chosen `committed_at`
-- values because a committed row is trigger-immutable: history is made by
-- inserting historical rows, never by backdating live ones.
begin;

select plan(51);

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

create function pg_temp.v2() returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('d0000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_dashboard_v2_metrics();
  reset role;
  perform pg_temp.as_nobody();
  return v;
end;
$$;

-- One entitlement of a chosen plan and status for an account.
create function pg_temp.entitle(
  p_user uuid,
  p_plan text,
  p_status text,
  p_expires timestamptz default null,
  p_starts timestamptz default null
) returns uuid
language plpgsql set search_path = '' as $$
declare v_id uuid;
begin
  insert into public.user_entitlements (
    user_id, plan_code, status, billing_provider, starts_at, expires_at,
    auto_renew, base_ai_look_allowance, allowance_adjustment_total, version
  ) values (
    p_user, p_plan, p_status,
    case when p_plan = 'salon_pilot' then 'admin_granted'
         when p_plan = 'free' then 'none'
         else 'google_play' end,
    coalesce(p_starts, timezone('utc', now()) - interval '60 days'),
    p_expires, false, 30, 0, 1
  ) returning id into v_id;
  return v_id;
end;
$$;

-- A delivered Final Preview on a chosen UTC day, with chosen historical
-- attribution. `p_unit` / `p_plan` null models a row predating SUB-12B.
create function pg_temp.delivered(
  p_user uuid,
  p_entitlement uuid,
  p_day_offset int,
  p_plan text,
  p_unit text,
  p_source text default 'subscription'
) returns void
language plpgsql set search_path = '' as $$
declare
  v_at timestamptz := date_trunc('day', timezone('utc', now()))
    - (p_day_offset || ' days')::interval + interval '6 hours';
  v_grant uuid := null;
begin
  -- A purchased-credit row must name the grant that paid for it
  -- (`usage_ledger_purchased_source_pair`).
  if p_source = 'purchased_credit' then
    insert into public.purchased_credit_grants (
      user_id, billing_provider, provider_product_id, pack_code, credit_class,
      quantity_granted, purchase_reference, purchase_state, test_purchase,
      granted_at
    ) values (
      -- Pack code, class and quantity must match an approved row of
      -- `top_up_packs` (`purchased_credit_grants_pack_guard`).
      p_user, 'google_play', 'facetune_ai_look_topup_1', 'extra_ai_look',
      'tutorial_capable_ai_look',
      1, md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text),
      'PURCHASED', true, v_at
    ) returning id into v_grant;
  end if;

  insert into public.usage_ledger (
    user_id, entitlement_id, usage_type, operation_id, status, source_mode,
    reserved_at, committed_at, plan_code, allowance_unit, allowance_source,
    purchased_credit_grant_id
  ) values (
    p_user, p_entitlement, 'final_makeup_preview', gen_random_uuid(),
    'committed', 'standard', v_at, v_at, p_plan, p_unit, p_source, v_grant
  );
end;
$$;

-- A reservation that is still open, and one that was released. Neither is a
-- delivery.
create function pg_temp.not_delivered(p_user uuid, p_entitlement uuid) returns void
language plpgsql set search_path = '' as $$
declare v_at timestamptz := date_trunc('day', timezone('utc', now())) + interval '2 hours';
begin
  insert into public.usage_ledger (
    user_id, entitlement_id, usage_type, operation_id, status,
    reserved_at, plan_code, allowance_unit, allowance_source
  ) values (
    p_user, p_entitlement, 'final_makeup_preview', gen_random_uuid(),
    'reserved', v_at, 'pro', 'ai_look', 'subscription'
  );
  insert into public.usage_ledger (
    user_id, entitlement_id, usage_type, operation_id, status,
    reserved_at, released_at, sanitized_failure_code,
    plan_code, allowance_unit, allowance_source
  ) values (
    p_user, p_entitlement, 'final_makeup_preview', gen_random_uuid(),
    'released', v_at, v_at, 'GEN_FAILED', 'pro', 'ai_look', 'subscription'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Shape and security posture
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'),
  1, 'the V2 dashboard read exists, exactly once');

select is(
  (select p.prosecdef from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'),
  true, 'it is security definer');

select is(
  (select p.provolatile::text from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'),
  's', 'it is stable, so it cannot write');

select is(
  (select array_to_string(p.proconfig, ',') from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'),
  'search_path=""', 'its search_path is locked');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'
      and (p.prosrc ~* '\minsert\M|\mupdate\M|\mdelete\M|\mtruncate\M')),
  0, 'it contains no write statement');

select ok(
  not has_function_privilege('public', 'public.admin_dashboard_v2_metrics()', 'execute'),
  'PUBLIC cannot execute it');
select ok(
  not has_function_privilege('anon', 'public.admin_dashboard_v2_metrics()', 'execute'),
  'anon cannot execute it');
select ok(
  not has_function_privilege('service_role', 'public.admin_dashboard_v2_metrics()', 'execute'),
  'service_role cannot execute it as a client');
select ok(
  has_function_privilege('authenticated', 'public.admin_dashboard_v2_metrics()', 'execute'),
  'authenticated may execute it');

-- ---------------------------------------------------------------------------
-- 2. Accounts and authorization
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
  ('d0000000-0000-4000-8000-000000000a00'::uuid, 'wadash-admin@example.invalid'),
  ('d0000000-0000-4000-8000-000000000a01'::uuid, 'wadash-normal@example.invalid'),
  ('d0000000-0000-4000-8000-000000000001'::uuid, 'wadash-pro@example.invalid'),
  ('d0000000-0000-4000-8000-000000000002'::uuid, 'wadash-preview@example.invalid'),
  ('d0000000-0000-4000-8000-000000000003'::uuid, 'wadash-pilot@example.invalid'),
  ('d0000000-0000-4000-8000-000000000004'::uuid, 'wadash-legacy@example.invalid'),
  ('d0000000-0000-4000-8000-000000000005'::uuid, 'wadash-lapsed@example.invalid')
) as v(id, email);
insert into public.admin_users (user_id, note)
values ('d0000000-0000-4000-8000-000000000a00', 'wa-dash-1');

set local role authenticated;
select pg_temp.as_user('d0000000-0000-4000-8000-000000000a01');
select is((public.admin_dashboard_v2_metrics())->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user is refused');
select pg_temp.as_nobody();
select is((public.admin_dashboard_v2_metrics())->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller is refused');
reset role;

-- The empty state must be a zero-filled contract, not an error or a gap.
create temp table empty_v2 as select pg_temp.v2() as r;
select is((select r->>'ok' from empty_v2), 'true', 'an admin may read the V2 contract');
select is((select jsonb_array_length(r->'committedDaily') from empty_v2), 30,
  'the empty state still returns exactly 30 days');
select is((select jsonb_array_length(r->'finalPreviewsByPlan30d') from empty_v2), 8,
  'the empty state still returns all eight canonical plans');
select is(
  (select count(*)::int from jsonb_array_elements(
     (select r->'committedDaily' from empty_v2)) d
   where (d->>'aiLook')::int <> 0 or (d->>'finalPreviewCredit')::int <> 0),
  0, 'the empty state is zeroes, not absent days');

-- ---------------------------------------------------------------------------
-- 3. Fixtures
-- ---------------------------------------------------------------------------
create temp table ents as
select
  pg_temp.entitle('d0000000-0000-4000-8000-000000000001', 'pro', 'active') as pro,
  pg_temp.entitle('d0000000-0000-4000-8000-000000000002', 'pro_preview', 'active') as preview,
  -- A Salon Pilot row must carry an expiry (`user_entitlements_salon_pilot_shape`).
  pg_temp.entitle('d0000000-0000-4000-8000-000000000003', 'salon_pilot', 'suspended',
                  timezone('utc', now()) + interval '30 days') as pilot,
  pg_temp.entitle('d0000000-0000-4000-8000-000000000004', 'plus', 'revoked') as legacy,
  -- Stored active, but its expiry has passed: the final resolver must rank
  -- the account's lifetime Free row ahead of this ended paid history.
  pg_temp.entitle('d0000000-0000-4000-8000-000000000005', 'plus', 'active',
                  timezone('utc', now()) - interval '1 day') as lapsed;

-- An account whose governing row must win over its own superseded history.
-- Not a Free row: the Free lifecycle guard provisions Free active or not at
-- all, so the superseded row is the plan this account held before Pro.
select pg_temp.entitle('d0000000-0000-4000-8000-000000000001', 'plus', 'expired',
                       null, timezone('utc', now()) - interval '400 days');

do $$
declare e record;
begin
  select * into e from ents;
  -- Today: two AI Look deliveries and one Final Preview Credit delivery.
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000001', e.pro, 0, 'pro', 'ai_look');
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000001', e.pro, 0, 'pro', 'ai_look');
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000002', e.preview, 0,
                            'pro_preview', 'final_preview_credit');
  -- Today, paid from a purchased top-up but still an AI Look unit: source and
  -- unit are different dimensions.
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000001', e.pro, 0,
                            'pro', 'ai_look', 'purchased_credit');
  -- Today, predating attribution.
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000004', e.legacy, 0, null, null);
  -- Inside the window.
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000003', e.pilot, 5,
                            'salon_pilot', 'ai_look');
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000002', e.preview, 29,
                            'pro_preview', 'final_preview_credit');
  -- Outside the window, on both sides.
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000001', e.pro, 30, 'pro', 'ai_look');
  perform pg_temp.delivered('d0000000-0000-4000-8000-000000000001', e.pro, 120, 'pro', 'ai_look');
  -- Not deliveries.
  perform pg_temp.not_delivered('d0000000-0000-4000-8000-000000000001', e.pro);
end;
$$;

create temp table v2 as select pg_temp.v2() as r;

-- ---------------------------------------------------------------------------
-- 4. B-01 — the bounded daily series
-- ---------------------------------------------------------------------------
select is((select jsonb_array_length(r->'committedDaily') from v2), 30,
  'the series is exactly thirty days');

select is((select r->>'reportingTimezone' from v2), 'UTC',
  'the reporting timezone is stated, and it is UTC');

select is(
  (select count(*)::int from jsonb_array_elements((select r->'committedDaily' from v2)) d
   where (d->>'day') !~ '^\d{4}-\d{2}-\d{2}$'),
  0, 'every day is an unambiguous ISO date, never a locale rendering');

select is(
  (select array_agg(d->>'day' order by ord)
     from jsonb_array_elements((select r->'committedDaily' from v2))
          with ordinality as t(d, ord)),
  (select array_agg(day order by day)
     from (select (d->>'day') as day
             from jsonb_array_elements((select r->'committedDaily' from v2)) d) s),
  'the days are in chronological order');

select is(
  (select (d->>'day')::date from jsonb_array_elements((select r->'committedDaily' from v2))
     with ordinality as t(d, ord) where ord = 30),
  (timezone('utc', now()))::date,
  'the last point is today');

select is(
  (select (d->>'day')::date from jsonb_array_elements((select r->'committedDaily' from v2))
     with ordinality as t(d, ord) where ord = 1),
  (timezone('utc', now()))::date - 29,
  'the first point is twenty-nine days before today');

select is(
  (select (d->>'aiLook') || '/' || (d->>'finalPreviewCredit')
     from jsonb_array_elements((select r->'committedDaily' from v2))
          with ordinality as t(d, ord) where ord = 30),
  '3/1', 'today counts three AI Looks and one Final Preview Credit, kept apart');

select is(
  (select (d->>'unattributed') from jsonb_array_elements((select r->'committedDaily' from v2))
     with ordinality as t(d, ord) where ord = 30),
  '1', 'a delivery predating attribution is reported, not silently dropped');

select is(
  (select (d->>'aiLook') || '/' || (d->>'finalPreviewCredit')
     from jsonb_array_elements((select r->'committedDaily' from v2))
          with ordinality as t(d, ord) where ord = 25),
  '1/0', 'a day inside the window carries its own delivery');

select is(
  (select count(*)::int from jsonb_array_elements((select r->'committedDaily' from v2)) d
   where (d->>'aiLook')::int = 0 and (d->>'finalPreviewCredit')::int = 0
     and (d->>'unattributed')::int = 0),
  27, 'quiet days are present as explicit zeroes');

select is(
  (select sum((d->>'aiLook')::int) from jsonb_array_elements((select r->'committedDaily' from v2)) d),
  4::bigint, 'deliveries older than the window are excluded');

-- ---------------------------------------------------------------------------
-- 5. Reserved and released are not deliveries
-- ---------------------------------------------------------------------------
select is(
  (select (r->'committedTodayByUnit'->>'aiLook')::int from v2), 3,
  'an open reservation is not counted as delivered');

select is(
  (select sum((d->>'aiLook')::int + (d->>'finalPreviewCredit')::int + (d->>'unattributed')::int)
     from jsonb_array_elements((select r->'committedDaily' from v2)) d),
  7::bigint, 'a released reservation is not counted as delivered');

-- ---------------------------------------------------------------------------
-- 6. B-02 — delivery by plan
-- ---------------------------------------------------------------------------
select is((select jsonb_array_length(r->'finalPreviewsByPlan30d') from v2), 8,
  'the plan distribution is exactly the eight canonical plans');

select is(
  (select array_agg(p->>'planCode' order by ord)
     from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2))
          with ordinality as t(p, ord)),
  array['free','plus','plus_preview','pro','pro_preview','salon_pilot','salon_preview','salon_pro'],
  'the canonical plan codes are present and unrenamed');

select is(
  (select p->>'delivered' from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2)) p
    where p->>'planCode' = 'pro'),
  '3', 'Pro deliveries inside the window are counted');

select is(
  (select p->>'delivered' from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2)) p
    where p->>'planCode' = 'pro_preview'),
  '2', 'Pro Preview deliveries are counted under their own plan');

select is(
  (select count(*)::int from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2)) p
    where (p->>'delivered')::int = 0),
  5, 'plans with no deliveries are present with zero');

select is((select r->>'finalPreviewsUnattributed30d' from v2), '1',
  'deliveries predating plan attribution are reported separately');

-- Historical attribution: the Pro account also holds a superseded Plus row.
-- Its deliveries are attributed to the plan the ledger recorded, so nothing
-- lands under Plus and nothing is re-attributed to a current plan either.
select is(
  (select p->>'delivered' from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2)) p
    where p->>'planCode' = 'plus'),
  '0', 'a delivery keeps the plan recorded when it happened, not another row of the same account');

select is(
  (select p->>'delivered' from jsonb_array_elements((select r->'finalPreviewsByPlan30d' from v2)) p
    where p->>'planCode' = 'salon_pilot'),
  '1', 'a Salon Pilot delivery is attributed to Salon Pilot');

-- ---------------------------------------------------------------------------
-- 7. B-03 — today by allowance unit, not by source
-- ---------------------------------------------------------------------------
select is(
  (select (r->'committedTodayByUnit'->>'aiLook') || '/' ||
          (r->'committedTodayByUnit'->>'finalPreviewCredit') || '/' ||
          (r->'committedTodayByUnit'->>'unattributed') from v2),
  '3/1/1', 'today is separated by unit, including the unattributed row');

-- One of today's three AI Looks was paid from a purchased top-up. Grouping by
-- unit must not turn a purchased credit into a different unit.
select is(
  (select count(*)::int from public.usage_ledger u
    where u.status = 'committed' and u.allowance_source = 'purchased_credit'
      and u.allowance_unit = 'ai_look'
      and u.committed_at >= date_trunc('day', timezone('utc', now()))),
  1, 'the fixture really does contain a purchased-credit AI Look today');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'
      and p.prosrc ~ 'committedTodayByUnit'
      and p.prosrc ~ 'allowance_unit'),
  1, 'the unit figures are grouped on allowance_unit');

-- ---------------------------------------------------------------------------
-- 8. B-04 — the governing entitlement distribution
-- ---------------------------------------------------------------------------
select is(
  (select (r->'entitlementStatusDistribution'->>'total')::int from v2), 7,
  'one governing entitlement per account with any entitlement');

select is(
  (select count(*)::int from public.user_entitlements), 13,
  'thirteen Free, paid and historical rows reduce to seven governing rows');

select is(
  (select (r->'entitlementStatusDistribution'->'byStoredStatus'->>'active')::int
     + (r->'entitlementStatusDistribution'->'byStoredStatus'->>'grace_period')::int
     + (r->'entitlementStatusDistribution'->'byStoredStatus'->>'suspended')::int
     + (r->'entitlementStatusDistribution'->'byStoredStatus'->>'pending')::int
     + (r->'entitlementStatusDistribution'->'byStoredStatus'->>'expired')::int
     + (r->'entitlementStatusDistribution'->'byStoredStatus'->>'revoked')::int from v2),
  (select (r->'entitlementStatusDistribution'->>'total')::int from v2),
  'the stored categories sum to the stated total');

select is(
  (select (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'active')::int
     + (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'grace_period')::int
     + (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'suspended')::int
     + (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'pending')::int
     + (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'expired')::int
     + (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'revoked')::int from v2),
  (select (r->'entitlementStatusDistribution'->>'total')::int from v2),
  'the effective categories sum to the same total');

select is(
  (select array(select jsonb_object_keys(r->'entitlementStatusDistribution'->'byStoredStatus')
                order by 1) from v2),
  array['active','expired','grace_period','pending','revoked','suspended'],
  'the categories are the canonical entitlement states, unrenamed');

select is(
  (select (r->'entitlementStatusDistribution'->'byStoredStatus'->>'active')::int from v2), 6,
  'live paid rows and lifetime Free fallbacks govern six accounts');

select is(
  (select (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'active')::int from v2), 6,
  'ended non-Free history cannot displace the active Free fallback');

select is(
  (select (r->'entitlementStatusDistribution'->'byEffectiveStatus'->>'suspended')::int from v2), 1,
  'an in-force suspended admin entitlement outranks Free and remains visible');

-- ---------------------------------------------------------------------------
-- 9. Privacy, bounds, and the untouched V1 contract
-- ---------------------------------------------------------------------------
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_v2_metrics'
      and p.prosrc ~* 'generated_images|storage_path|signed|prompt|purchase_token|provider_message|raw_payload|analyses'),
  0, 'the V2 read names no image, path, prompt, receipt or provider payload');

select is(
  (select count(*)::int from jsonb_object_keys((select r from v2)) k
    where k in ('users','items','rows','ledger','emails')),
  0, 'it returns no per-user or per-row list');

select is(
  (select (r->>'contractVersion') from v2), 'admin_dashboard_v2_contract_v1',
  'it carries its own contract version, distinct from the V1 dashboard');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'admin_dashboard_metrics'
      and p.prosrc ~ 'subscription_admin_contract_v1.1'),
  1, 'the existing V1 dashboard contract is untouched');

rollback;
