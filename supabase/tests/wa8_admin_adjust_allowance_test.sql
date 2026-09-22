-- WA-8 — Salon Pilot allowance adjustments through the audited ledger:
-- increases, safe reductions, typed refusals, idempotency, stale versions,
-- audit, and immutable usage history.
begin;

select plan(58);

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

create function pg_temp.adjust(
  p_ent uuid, p_amount int, p_key text,
  p_reason text default 'Panel testing extension',
  p_version int default null,
  p_corr uuid default '50000000-0000-4000-8000-0000000000c1'
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('50000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_adjust_salon_pilot_allowance(
    p_ent, p_amount, p_reason, p_key, p_version, p_corr);
  reset role;
  return v;
end;
$$;

create function pg_temp.grant_pilot(p_target uuid, p_key text) returns uuid
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('50000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot(
    p_target, timezone('utc', now()) + interval '30 days',
    'WA-8 fixture grant', p_key, 30, null);
  reset role;
  return (v->>'entitlementId')::uuid;
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

-- Reserve → commit `p_n` AI Looks as the user.
create function pg_temp.spend(p_user uuid, p_n int) returns void
language plpgsql set search_path = '' as $$
declare i int; op uuid;
begin
  perform pg_temp.as_user(p_user);
  for i in 1..p_n loop
    op := gen_random_uuid();
    perform public.reserve_ai_look(op);
    perform public.commit_ai_look(op, 'standard', pg_temp.new_preview(p_user));
  end loop;
  perform pg_temp.as_nobody();
end;
$$;

create function pg_temp.audit_count(p_ent uuid) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.admin_audit_events where target_entitlement_id = p_ent
$$;

create function pg_temp.ledger_count(p_ent uuid) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.entitlement_allowance_adjustments where entitlement_id = p_ent
$$;

-- Accounts: admin, normal user, a pilot artist, and a Pro subscriber.
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
  ('50000000-0000-4000-8000-000000000a00'::uuid, 'wa8-admin@example.invalid'),
  ('50000000-0000-4000-8000-000000000a01'::uuid, 'wa8-normal@example.invalid'),
  ('50000000-0000-4000-8000-000000000001'::uuid, 'wa8-artist@example.invalid'),
  ('50000000-0000-4000-8000-000000000002'::uuid, 'wa8-pro@example.invalid')
) as v(id, email);

insert into public.admin_users (user_id, note)
values ('50000000-0000-4000-8000-000000000a00', 'wa8 fixture');

-- A 30-AI-Look pilot via the WA-7 writer, with 18 committed. The id is kept
-- in a transaction setting because the authorization block below runs under
-- `set local role authenticated`, which cannot read a temp table.
create temp table pilot as
select pg_temp.grant_pilot('50000000-0000-4000-8000-000000000001', 'wa8-grant') as id;
select set_config('wa8.pilot', (select id::text from pilot), true);
select pg_temp.spend('50000000-0000-4000-8000-000000000001', 18);
select is((select (s->>'effectiveAllowance') || '/' || (s->>'committedUsage') || '/' ||
                  (s->>'availableAiLooks') from pg_temp.state('50000000-0000-4000-8000-000000000001') s),
  '30/18/12', 'fixture: 30 granted, 18 committed, 12 available');

-- A Pro subscriber: store-backed, never allowance-editable.
select public.activate_verified_google_play_subscription(
  '50000000-0000-4000-8000-000000000002',
  'facetune_pro', repeat('8', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true
);
create temp table pro as
select e.id from public.user_entitlements e
 where e.user_id = '50000000-0000-4000-8000-000000000002' and e.plan_code = 'pro';

-- ---------------------------------------------------------------------------
-- Authorization
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('50000000-0000-4000-8000-000000000a01');
select is((public.admin_adjust_salon_pilot_allowance(
  current_setting('wa8.pilot')::uuid, 10, 'x', 'k', null, null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'a normal user cannot adjust an allowance');
select pg_temp.as_user('50000000-0000-4000-8000-000000000001');
select is((public.admin_adjust_salon_pilot_allowance(
  current_setting('wa8.pilot')::uuid, 10, 'x', 'k', null, null))->>'errorCode', 'ADMIN_UNAUTHORIZED',
  'the pilot holder cannot adjust their own allowance');
select pg_temp.as_nobody();
select is((public.admin_adjust_salon_pilot_allowance(
  current_setting('wa8.pilot')::uuid, 10, 'x', 'k', null, null))->>'errorCode', 'AUTH_REQUIRED',
  'an unauthenticated caller cannot adjust');
reset role;
select is(pg_temp.ledger_count((select id from pilot)), 0::bigint,
  'refused calls wrote no adjustment');

-- ---------------------------------------------------------------------------
-- Validation and targets
-- ---------------------------------------------------------------------------
select is((pg_temp.adjust('59999999-9999-4999-8999-999999999999', 10, 'k'))->>'errorCode',
  'ENTITLEMENT_NOT_FOUND', 'an unknown entitlement is ENTITLEMENT_NOT_FOUND');
select is((pg_temp.adjust((select id from pro), 10, 'k-pro'))->>'errorCode',
  'INVALID_ALLOWANCE_ADJUSTMENT', 'a store-backed entitlement is not admin-editable');
select is((select allowance_adjustment_total from public.user_entitlements where id = (select id from pro)),
  0, 'the store entitlement is untouched');
select throws_ok(
  $$ select pg_temp.adjust((select id from pilot), 0, 'k0') $$,
  '22023', null, 'a zero amount is rejected');
select throws_ok(
  $$ select pg_temp.adjust((select id from pilot), null, 'k0') $$,
  '22023', null, 'a null amount is rejected');
select throws_ok(
  $$ select pg_temp.adjust((select id from pilot), 10, 'k0', p_reason => '  ') $$,
  '22023', null, 'a blank reason is rejected');
select throws_ok(
  $$ select pg_temp.adjust((select id from pilot), 10, '') $$,
  '22023', null, 'a missing idempotency key is rejected');
select throws_ok(
  $$ select pg_temp.adjust((select id from pilot), 10, 'k0', p_version => 0) $$,
  '22023', null, 'a non-positive expected version is rejected');
select is(pg_temp.ledger_count((select id from pilot)), 0::bigint,
  'invalid requests wrote no adjustment');
select is(pg_temp.audit_count((select id from pilot)), 1::bigint,
  'invalid requests wrote no audit event (only the grant is recorded)');

-- ---------------------------------------------------------------------------
-- +5, +10, custom positive
-- ---------------------------------------------------------------------------
create temp table plus5 as select pg_temp.adjust((select id from pilot), 5, 'wa8-plus5') as r;
select is((select r->>'success' from plus5), 'true', '+5 succeeds');
select is((select r->>'action' from plus5), 'increase_allowance', '+5 is increase_allowance');
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'allowanceAdjustmentTotal') || '/' ||
                  (r->>'committedUsage') || '/' || (r->>'remainingAiLooks') || '/' ||
                  (r->>'availableAiLooks') from plus5),
  '35/5/18/17/17', '+5: effective 35, total +5, committed unchanged, remaining 17');
select is((select (r->>'version')::int from plus5), 2, 'the version advanced once');
select is((select r->>'replayed' from plus5), 'false', 'a first adjustment is not a replay');

create temp table plus10 as
select pg_temp.adjust((select id from pilot), 10, 'wa8-plus10', p_version => 2) as r;
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'allowanceAdjustmentTotal') from plus10),
  '45/15', '+10 with the current expected version succeeds');
create temp table custom as
select pg_temp.adjust((select id from pilot), 7, 'wa8-custom7') as r;
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'allowanceAdjustmentTotal') from custom),
  '52/22', 'a custom positive amount is applied as submitted');
select is(
  (select array_agg(k order by k) from custom, jsonb_object_keys(r) k),
  array['action','adjustmentId','allowanceAdjustmentTotal','amount','availableAiLooks',
        'baseAllowance','committedUsage','contractVersion','effectiveAllowance','entitlementId',
        'expiresAt','planCode','remainingAiLooks','replayed','reservedUsage','status','success',
        'targetUserId','updatedAt','version'],
  'the response carries the contract §73 fields plus adjustment provenance');

-- The app sees exactly what the admin was told.
select is((select (s->>'effectiveAllowance') || '/' || (s->>'allowanceAdjustmentTotal') || '/' ||
                  (s->>'availableAiLooks') from pg_temp.state('50000000-0000-4000-8000-000000000001') s),
  '52/22/34', 'the consumer resolver reports the adjusted allowance');
select is((select base_ai_look_allowance from public.user_entitlements where id = (select id from pilot)),
  30, 'the base allowance is never rewritten');

-- ---------------------------------------------------------------------------
-- Valid and invalid reductions
-- ---------------------------------------------------------------------------
create temp table minus12 as select pg_temp.adjust((select id from pilot), -12, 'wa8-minus12') as r;
select is((select r->>'success' || ' ' || (r->>'action') from minus12), 'true decrease_allowance',
  'a reduction that keeps committed usage covered succeeds');
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'allowanceAdjustmentTotal') from minus12),
  '40/10', 'effective 52 - 12 = 40');
select is((pg_temp.adjust((select id from pilot), -25, 'wa8-minus25'))->>'errorCode',
  'ALLOWANCE_BELOW_COMMITTED_USAGE', '40 - 25 = 15 < 18 committed is refused');
select is((select (s->>'effectiveAllowance')::int from pg_temp.state('50000000-0000-4000-8000-000000000001') s),
  40, 'a refused reduction changes nothing');

-- With one AI Look reserved, capacity held by the reservation is protected.
select pg_temp.as_user('50000000-0000-4000-8000-000000000001');
select public.reserve_ai_look('52000000-0000-4000-8000-000000000001');
select pg_temp.as_nobody();
select is((pg_temp.adjust((select id from pilot), -22, 'wa8-minus22'))->>'errorCode',
  'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
  '40 - 22 = 18 covers committed but not the held reservation');
select is((select r->>'success' from pg_temp.adjust((select id from pilot), -21, 'wa8-minus21') r), 'true',
  '40 - 21 = 19 = committed + reserved is the smallest valid allowance');
select is((select (s->>'effectiveAllowance') || '/' || (s->>'committedUsage') || '/' ||
                  (s->>'reservedUsage') || '/' || (s->>'availableAiLooks')
   from pg_temp.state('50000000-0000-4000-8000-000000000001') s),
  '19/18/1/0', 'available is exactly zero, never negative');
select pg_temp.as_user('50000000-0000-4000-8000-000000000001');
select public.release_ai_look('52000000-0000-4000-8000-000000000001', 'GEN_FAILED');
select pg_temp.as_nobody();
select is((select r->>'success' from pg_temp.adjust((select id from pilot), 11, 'wa8-restore') r), 'true',
  'restored to 30 for the remaining checks');

-- ---------------------------------------------------------------------------
-- Stale version and idempotency
-- ---------------------------------------------------------------------------
select is((pg_temp.adjust((select id from pilot), 5, 'wa8-stale', p_version => 1))->>'errorCode',
  'CONCURRENT_MODIFICATION', 'an expected version that is no longer current is refused');
select is(pg_temp.ledger_count((select id from pilot)), 6::bigint,
  'the stale submission wrote nothing');
create temp table replay as select pg_temp.adjust((select id from pilot), 5, 'wa8-plus5') as r;
select is((select r->>'replayed' from replay), 'true', 'a duplicate +5 is replayed');
select is((select r->>'adjustmentId' from replay), (select r->>'adjustmentId' from plus5),
  'the replay names the original adjustment');
select is((select (r->>'effectiveAllowance')::int from replay), 30,
  'the replay returns the current authoritative allowance, not +5 again');
select is(pg_temp.ledger_count((select id from pilot)), 6::bigint,
  'a duplicate submission applies once');
select is((pg_temp.adjust((select id from pilot), 6, 'wa8-plus5'))->>'errorCode',
  'IDEMPOTENCY_CONFLICT', 'the same key with a different amount is a conflict');
select is((pg_temp.adjust((select id from pilot), 5, 'wa8-plus5', p_reason => 'other'))->>'errorCode',
  'IDEMPOTENCY_CONFLICT', 'the same key with a different reason is a conflict');
select is((select r->>'replayed' from pg_temp.adjust((select id from pilot), 5, 'wa8-plus5', p_version => 1) r),
  'true', 'a replay ignores the expected version');

-- ---------------------------------------------------------------------------
-- Audit and immutable history
-- ---------------------------------------------------------------------------
select is(pg_temp.audit_count((select id from pilot)), 7::bigint,
  'one audit event per applied adjustment (six) plus the grant');
select is(
  (select string_agg(a.action || ':' || (a.after_state->>'effectiveAllowance'), ',' order by (a.after_state->>'version')::int)
   from public.admin_audit_events a
   where a.target_entitlement_id = (select id from pilot) and a.action <> 'grant_salon_pilot'),
  'increase_allowance:35,increase_allowance:45,increase_allowance:52,decrease_allowance:40,' ||
  'decrease_allowance:19,increase_allowance:30',
  'audit after-states trace every applied change in version order');
select is(
  (select (a.before_state->>'effectiveAllowance') || '>' || (a.after_state->>'effectiveAllowance') ||
          ' v' || (a.before_state->>'version') || '>' || (a.after_state->>'version')
   from public.admin_audit_events a
   where a.target_entitlement_id = (select id from pilot) and a.idempotency_key = 'wa8-plus5'),
  '30>35 v1>2', 'before/after snapshots record allowance and version');
select is(
  (select a.admin_user_id::text || ' ' || a.reason || ' ' || a.request_correlation_id::text
   from public.admin_audit_events a
   where a.target_entitlement_id = (select id from pilot) and a.idempotency_key = 'wa8-plus5'),
  '50000000-0000-4000-8000-000000000a00 Panel testing extension 50000000-0000-4000-8000-0000000000c1',
  'the audit names the acting admin, the reason, and the correlation id');
select is(
  (select a.admin_user_id::text || ' ' || a.adjustment_type || ' ' || a.amount
   from public.entitlement_allowance_adjustments a
   where a.entitlement_id = (select id from pilot) and a.idempotency_key = 'wa8-minus12'),
  '50000000-0000-4000-8000-000000000a00 decrease_allowance -12',
  'the ledger row is signed and attributed');
select is((select count(*) from public.usage_ledger
   where entitlement_id = (select id from pilot) and status = 'committed'), 18::bigint,
  'committed usage history is unchanged by every adjustment');
select is((select count(*) from public.usage_ledger
   where entitlement_id = (select id from pilot)), 19::bigint,
  'no ledger row was deleted (18 committed + 1 released)');
select is((select allowance_adjustment_total from public.user_entitlements where id = (select id from pilot)),
  (select coalesce(sum(amount), 0)::int from public.entitlement_allowance_adjustments
    where entitlement_id = (select id from pilot)),
  'the adjustment total is exactly the sum of the audited rows');
select throws_ok(
  $$ update public.user_entitlements set allowance_adjustment_total = 99
     where id = (select id from pilot) $$,
  'P0001', null, 'the total cannot be written outside the ledger');
select throws_ok(
  $$ update public.admin_audit_events set after_state = '{}'::jsonb
     where target_entitlement_id = (select id from pilot) $$,
  'P0001', 'admin audit events are immutable', 'audit snapshots cannot be rewritten');

-- ---------------------------------------------------------------------------
-- Ended entitlements are not adjustable
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token,
  is_anonymous
) values (
  '00000000-0000-0000-0000-000000000000', '50000000-0000-4000-8000-000000000003',
  'authenticated', 'authenticated', 'wa8-lapsed@example.invalid', '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', '', false
);
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance
) values
  ('51000000-0000-4000-8000-000000000003', '50000000-0000-4000-8000-000000000003',
   'salon_pilot', 'active', 'admin_granted',
   timezone('utc', now()) - interval '40 days', timezone('utc', now()) - interval '1 day', false, 30),
  ('51000000-0000-4000-8000-000000000004', '50000000-0000-4000-8000-000000000003',
   'salon_pilot', 'revoked', 'admin_granted',
   timezone('utc', now()) - interval '80 days', timezone('utc', now()) + interval '10 days', false, 30);
select is((pg_temp.adjust('51000000-0000-4000-8000-000000000003', 5, 'k-lapsed'))->>'errorCode',
  'ENTITLEMENT_EXPIRED', 'a lapsed pilot cannot be adjusted');
select is((pg_temp.adjust('51000000-0000-4000-8000-000000000004', 5, 'k-revoked'))->>'errorCode',
  'ENTITLEMENT_REVOKED', 'a revoked pilot cannot be adjusted');

-- ---------------------------------------------------------------------------
-- Privilege surface
-- ---------------------------------------------------------------------------
select is(has_function_privilege('anon',
  'public.admin_adjust_salon_pilot_allowance(uuid,integer,text,text,integer,uuid)', 'EXECUTE'),
  false, 'anon cannot execute the adjustment');
select is(has_function_privilege('service_role',
  'public.admin_adjust_salon_pilot_allowance(uuid,integer,text,text,integer,uuid)', 'EXECUTE'),
  false, 'the adjustment is not a service-role endpoint');
select is(has_function_privilege('authenticated',
  'public.admin_adjust_salon_pilot_allowance(uuid,integer,text,text,integer,uuid)', 'EXECUTE'),
  true, 'authenticated reaches the adjustment and is checked inside');
select is(
  (select bool_and(not has_table_privilege(r, 'public.entitlement_allowance_adjustments', p))
   from unnest(array['anon','authenticated','service_role']) r,
        unnest(array['SELECT','INSERT','UPDATE','DELETE']) p),
  true, 'no client role can read or write the adjustment ledger');

select * from finish();
rollback;
