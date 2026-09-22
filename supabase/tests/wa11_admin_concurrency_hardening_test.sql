-- WA-11 — concurrency, idempotency and stale-write hardening: the phase
-- scenarios, proven at the transaction level against the deployed writers.
--
-- pgTAP runs in one session, so true lock contention is exercised by the
-- two-session harness `supabase/tests/controlled/wa11_admin_concurrency.sh`.
-- This suite proves the invariants every interleaving must end in:
--   * a duplicate admin request (same idempotency key) applies once
--   * two admins' changes both land; nothing is lost
--   * a stale expected version is refused and applies nothing
--   * an admin change and a user reservation can never drive capacity negative
--   * a suspension or revocation during generation follows the engine's
--     reservation-time attribution: the authorized work may still commit,
--     no new work may start
--   * the same key after a "timeout" replays the original result
--   * a duplicate revocation duplicates nothing
--   * the audit trail equals the set of applied mutations, exactly
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

-- Admin A and admin B call the writers as themselves.
create function pg_temp.adjust(
  p_admin uuid, p_ent uuid, p_amount int, p_key text,
  p_reason text default 'WA-11 adjustment', p_version int default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_adjust_salon_pilot_allowance(p_ent, p_amount, p_reason, p_key, p_version, null);
  reset role;
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.lifecycle(
  p_admin uuid, p_ent uuid, p_action text, p_key text,
  p_reason text default 'WA-11 lifecycle', p_version int default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_set_salon_pilot_lifecycle(p_ent, p_action, p_reason, p_key, p_version, null);
  reset role;
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.grant_pilot(p_admin uuid, p_target uuid, p_key text) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_admin);
  set local role authenticated;
  v := public.admin_grant_salon_pilot(
    p_target, '2027-06-30T23:59:59Z', 'WA-11 fixture grant', p_key, 30, null);
  reset role;
  perform pg_temp.as_nobody();
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

create function pg_temp.reserve(p_user uuid, p_op uuid) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_user);
  v := public.reserve_ai_look(p_op);
  perform pg_temp.as_nobody();
  return v;
end;
$$;

create function pg_temp.release(p_user uuid, p_op uuid) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_user);
  v := public.release_ai_look(p_op, 'WA11_TEST');
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

create function pg_temp.commit(p_user uuid, p_op uuid) returns jsonb
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user(p_user);
  v := public.commit_ai_look(p_op, 'standard', pg_temp.new_preview(p_user));
  perform pg_temp.as_nobody();
  return v;
end;
$$;

-- The invariants every scenario must leave true.
create function pg_temp.invariants(p_user uuid) returns text
language plpgsql set search_path = '' as $$
declare s jsonb; v_total int; v_sum int; v_ok boolean;
begin
  s := pg_temp.state(p_user);
  select e.allowance_adjustment_total,
         coalesce((select sum(a.amount) from public.entitlement_allowance_adjustments a
                    where a.entitlement_id = e.id), 0)
    into v_total, v_sum
  from public.user_entitlements e
  where e.id = (s->>'entitlementId')::uuid;
  v_ok := (s->>'availableAiLooks')::int >= 0
      and (s->>'remainingAiLooks')::int >= 0
      and (s->>'effectiveAllowance')::int >= (s->>'committedUsage')::int
      and v_total is not distinct from v_sum;
  return case when v_ok then 'ok' else 'VIOLATED ' || s::text end;
end;
$$;

create function pg_temp.audits(p_ent uuid) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.admin_audit_events where target_entitlement_id = p_ent
$$;

-- Accounts: two admins and one pilot artist.
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
  ('80000000-0000-4000-8000-000000000a00'::uuid, 'wa11-admin-a@example.invalid'),
  ('80000000-0000-4000-8000-000000000a02'::uuid, 'wa11-admin-b@example.invalid'),
  ('80000000-0000-4000-8000-000000000001'::uuid, 'wa11-artist@example.invalid')
) as v(id, email);
insert into public.admin_users (user_id, note) values
  ('80000000-0000-4000-8000-000000000a00', 'wa11 admin A'),
  ('80000000-0000-4000-8000-000000000a02', 'wa11 admin B');

-- ---------------------------------------------------------------------------
-- S0 — grant twice ("network timeout, client retries"): one pilot, one audit
-- ---------------------------------------------------------------------------
create temp table g1 as select pg_temp.grant_pilot('80000000-0000-4000-8000-000000000a00',
  '80000000-0000-4000-8000-000000000001', 'wa11-grant') as r;
create temp table g2 as select pg_temp.grant_pilot('80000000-0000-4000-8000-000000000a00',
  '80000000-0000-4000-8000-000000000001', 'wa11-grant') as r;
select set_config('wa11.pilot', (select r->>'entitlementId' from g1), true);
select is((select r->>'replayed' from g1) || '/' || (select r->>'replayed' from g2), 'false/true',
  'S0: the retried grant is a replay');
select is((select r->>'entitlementId' from g2), (select r->>'entitlementId' from g1),
  'S0: the same entitlement is returned');
select is((select count(*) from public.user_entitlements
   where user_id = '80000000-0000-4000-8000-000000000001' and plan_code = 'salon_pilot'), 1::bigint,
  'S0: one pilot row');
select is(pg_temp.audits(current_setting('wa11.pilot')::uuid), 1::bigint, 'S0: one audit event');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S0: invariants hold');

-- ---------------------------------------------------------------------------
-- S1 — duplicate allowance action: admin double-clicks +10
-- ---------------------------------------------------------------------------
create temp table s1a as select pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 10, 'wa11-dbl') as r;
create temp table s1b as select pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 10, 'wa11-dbl') as r;
select is((select r->>'success' || '/' || (r->>'replayed') from s1a), 'true/false', 'S1: first click applies');
select is((select r->>'success' || '/' || (r->>'replayed') from s1b), 'true/true', 'S1: second click is replayed');
select is((select (r->>'effectiveAllowance')::int from s1b), 40, 'S1: +10 once → 40, not 50');
select is((select allowance_adjustment_total from public.user_entitlements where id = current_setting('wa11.pilot')::uuid),
  10, 'S1: the stored total is +10');
select is((select count(*) from public.entitlement_allowance_adjustments where entitlement_id = current_setting('wa11.pilot')::uuid),
  1::bigint, 'S1: one ledger row');
select is(pg_temp.audits(current_setting('wa11.pilot')::uuid), 2::bigint, 'S1: grant + one adjustment audited');
select is((select (r->>'version')::int from s1a) || '/' || (select (r->>'version')::int from s1b), '2/2',
  'S1: the replay reports the same version, no second bump');

-- ---------------------------------------------------------------------------
-- S2 — two admins: A +10 (done above), B +5 — no lost update
-- ---------------------------------------------------------------------------
create temp table s2 as select pg_temp.adjust('80000000-0000-4000-8000-000000000a02',
  current_setting('wa11.pilot')::uuid, 5, 'wa11-b-plus5', p_version => 2) as r;
select is((select r->>'success' from s2), 'true', 'S2: admin B applies on the current version');
select is((select (r->>'effectiveAllowance')::int || '/' || (r->>'allowanceAdjustmentTotal') || '/v' || (r->>'version') from s2),
  '45/15/v3', 'S2: both changes are present (30+10+5), version 3');
select is((select string_agg(a.admin_user_id::text || ':' || a.amount, ',' order by a.amount desc)
   from public.entitlement_allowance_adjustments a where a.entitlement_id = current_setting('wa11.pilot')::uuid),
  '80000000-0000-4000-8000-000000000a00:10,80000000-0000-4000-8000-000000000a02:5',
  'S2: each admin''s change is attributed in the ledger');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S2: invariants hold');

-- ---------------------------------------------------------------------------
-- S3 — stale write: A loaded version 2, B moved it to 3, A submits on 2
-- ---------------------------------------------------------------------------
create temp table s3 as select pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, -20, 'wa11-a-stale', p_version => 2) as r;
select is((select r->>'errorCode' from s3), 'CONCURRENT_MODIFICATION',
  'S3: the stale submission is refused, not silently applied over B''s change');
select is((select allowance_adjustment_total || '/v' || version from public.user_entitlements
   where id = current_setting('wa11.pilot')::uuid), '15/v3', 'S3: nothing changed');
select is(pg_temp.audits(current_setting('wa11.pilot')::uuid), 3::bigint, 'S3: no audit for a refused write');
-- A reloads (version 3) and resubmits: applied once, even with the same key.
create temp table s3b as select pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, -20, 'wa11-a-stale', p_version => 3) as r;
select is((select r->>'success' || '/' || (r->>'replayed') || '/' || (r->>'effectiveAllowance') from s3b),
  'true/false/25', 'S3: after reloading, the same intent applies once');
select is(
  (select r->>'replayed' from pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
     current_setting('wa11.pilot')::uuid, -20, 'wa11-a-stale', p_version => 2) r),
  'true', 'S3: a later retry of the applied key replays even with the old version');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S3: invariants hold');

-- Lifecycle writers honour the same stale-write rule.
select is((pg_temp.lifecycle('80000000-0000-4000-8000-000000000a02', current_setting('wa11.pilot')::uuid,
  'suspend_entitlement', 'wa11-stale-susp', p_version => 1))->>'errorCode', 'CONCURRENT_MODIFICATION',
  'S3: a stale lifecycle submission is refused too');

-- ---------------------------------------------------------------------------
-- S4 — user generating during adjustment: capacity never negative
-- ---------------------------------------------------------------------------
-- effective 25, committed 0. The user commits 20 and reserves 1 (holding).
select pg_temp.as_user('80000000-0000-4000-8000-000000000001');
do $$
declare i int; op uuid;
begin
  for i in 1..20 loop
    op := gen_random_uuid();
    perform public.reserve_ai_look(op);
    perform public.commit_ai_look(op, 'standard', pg_temp.new_preview('80000000-0000-4000-8000-000000000001'));
  end loop;
end $$;
select pg_temp.as_nobody();
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001'))->>'ok',
  'true', 'S4: the user holds one AI Look (25 effective, 20 committed, 1 reserved)');
select is((select (s->>'availableAiLooks') || '/' || (s->>'remainingAiLooks')
   from pg_temp.state('80000000-0000-4000-8000-000000000001') s), '4/5', 'S4: 4 available, 5 remaining');
-- A reduction that would leave the held look uncovered is refused; one that
-- exactly covers committed + reserved is the floor and leaves 0 available.
select is((pg_temp.adjust('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
  -5, 'wa11-cut5'))->>'errorCode', 'ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION',
  'S4: 25 - 5 = 20 < 20 committed + 1 reserved is refused');
select is((pg_temp.adjust('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
  -6, 'wa11-cut6'))->>'errorCode', 'ALLOWANCE_BELOW_COMMITTED_USAGE',
  'S4: 25 - 6 = 19 < 20 committed is refused with the stronger code');
select is((select r->>'success' || '/' || (r->>'availableAiLooks') || '/' || (r->>'remainingAiLooks')
   from pg_temp.adjust('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
     -4, 'wa11-cut4') r), 'true/0/1', 'S4: 25 - 4 = 21 = committed + reserved: available exactly 0');
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000002'))->>'errorCode',
  'AI_LOOK_LIMIT_REACHED', 'S4: with 0 available a new reservation is refused, never negative');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S4: invariants hold at the floor');
-- Releasing the hold restores capacity; the admin can then reduce further.
select is((pg_temp.release('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000001'))->>'ok',
  'true', 'S4: the hold is released');
select is((select (s->>'availableAiLooks') from pg_temp.state('80000000-0000-4000-8000-000000000001') s), '1',
  'S4: the released capacity is available again');
select is((select r->>'success' || '/' || (r->>'availableAiLooks') from pg_temp.adjust(
  '80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid, -1, 'wa11-cut1') r),
  'true/0', 'S4: reducing to exactly committed usage is the hard floor (20/20)');
select is((pg_temp.adjust('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
  -1, 'wa11-cut-below'))->>'errorCode', 'ALLOWANCE_BELOW_COMMITTED_USAGE',
  'S4: one below committed usage is refused');
select is((select count(*) from public.usage_ledger where entitlement_id = current_setting('wa11.pilot')::uuid and status = 'committed'),
  20::bigint, 'S4: committed history untouched throughout');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S4: invariants hold');

-- ---------------------------------------------------------------------------
-- S5 — suspend during generation: reservation-time attribution
-- ---------------------------------------------------------------------------
-- Give the pilot room again, take a reservation, then suspend.
select is((select r->>'success' from pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 10, 'wa11-room') r), 'true', 'S5: +10 → 30 effective, 10 available');
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000005'))->>'ok',
  'true', 'S5: generation starts (reservation held)');
create temp table s5 as select pg_temp.lifecycle('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 'suspend_entitlement', 'wa11-susp') as r;
select is((select r->>'success' || '/' || (r->>'status') || '/' || (r->>'reservedUsage') from s5), 'true/suspended/1',
  'S5: suspension lands while the reservation is held; the hold is reported, not cancelled');
select is((select status from public.usage_ledger where operation_id = '82000000-0000-4000-8000-000000000005'),
  'reserved', 'S5: the in-flight reservation is untouched by the suspension');
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000006'))->>'errorCode',
  'ENTITLEMENT_SUSPENDED', 'S5: no NEW generation may start');
select is((pg_temp.commit('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000005'))->>'ok',
  'true', 'S5: the already-authorized work still commits (engine semantics: attribution at reservation time)');
select is((select (s->>'committedUsage') || '/' || (s->>'reservedUsage') || '/' || (s->>'generationAuthorized')
   from pg_temp.state('80000000-0000-4000-8000-000000000001') s), '21/0/false',
  'S5: the commit is charged, nothing is held, and generation stays blocked');
-- Duplicate suspension after the fact replays; a fresh key is refused.
select is((pg_temp.lifecycle('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
  'suspend_entitlement', 'wa11-susp'))->>'replayed', 'true', 'S5: a retried suspension replays');
select is((pg_temp.lifecycle('80000000-0000-4000-8000-000000000a02', current_setting('wa11.pilot')::uuid,
  'suspend_entitlement', 'wa11-susp-b'))->>'errorCode', 'INVALID_ENTITLEMENT_TRANSITION',
  'S5: a second admin''s suspension of a suspended pilot is refused');
select is(pg_temp.audits(current_setting('wa11.pilot')::uuid), 8::bigint,
  'S5: audit = grant + 6 applied adjustments + 1 suspension');
-- An adjustment while suspended is still possible (WA-8) and remains safe.
select is((select r->>'success' || '/' || (r->>'availableAiLooks') from pg_temp.adjust(
  '80000000-0000-4000-8000-000000000a02', current_setting('wa11.pilot')::uuid, -9, 'wa11-susp-cut') r),
  'true/0', 'S5: a reduction to the floor while suspended is applied, available 0');
select is(pg_temp.invariants('80000000-0000-4000-8000-000000000001'), 'ok', 'S5: invariants hold');
select is((pg_temp.lifecycle('80000000-0000-4000-8000-000000000a00', current_setting('wa11.pilot')::uuid,
  'reactivate_entitlement', 'wa11-react'))->>'status', 'active', 'S5: reactivated');

-- ---------------------------------------------------------------------------
-- S6 — revoke during generation, and revoke duplicates
-- ---------------------------------------------------------------------------
select is((select r->>'success' from pg_temp.adjust('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 5, 'wa11-room2') r), 'true', 'S6: +5 → room for one more');
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000007'))->>'ok',
  'true', 'S6: generation starts');
create temp table s6a as select pg_temp.lifecycle('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 'revoke_entitlement', 'wa11-rev', p_reason => 'Pilot terminated') as r;
create temp table s6b as select pg_temp.lifecycle('80000000-0000-4000-8000-000000000a00',
  current_setting('wa11.pilot')::uuid, 'revoke_entitlement', 'wa11-rev', p_reason => 'Pilot terminated') as r;
select is((select r->>'success' || '/' || (r->>'status') || '/' || (r->>'replayed') from s6a), 'true/revoked/false',
  'S6: the revocation lands');
select is((select r->>'success' || '/' || (r->>'status') || '/' || (r->>'replayed') from s6b), 'true/revoked/true',
  'S6: the duplicate revocation is a replay');
select is((select count(*) from public.admin_audit_events
   where target_entitlement_id = current_setting('wa11.pilot')::uuid and action = 'revoke_entitlement'), 1::bigint,
  'S6: exactly one revocation audit event');
select is((pg_temp.lifecycle('80000000-0000-4000-8000-000000000a02', current_setting('wa11.pilot')::uuid,
  'revoke_entitlement', 'wa11-rev-b', p_reason => 'again'))->>'errorCode', 'ENTITLEMENT_REVOKED',
  'S6: a second admin''s revocation of a revoked pilot is refused');
select is((select status from public.usage_ledger where operation_id = '82000000-0000-4000-8000-000000000007'),
  'reserved', 'S6: the in-flight reservation survives the revocation');
select is((pg_temp.commit('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000007'))->>'ok',
  'true', 'S6: the authorized work still commits against the revoked row (history, not new access)');
select is((select s->>'planCode' || '/' || (s->>'generationAuthorized') from pg_temp.state('80000000-0000-4000-8000-000000000001') s),
  'free/true', 'S6: the account now governs by its Free row; the pilot grants nothing');
select is((pg_temp.reserve('80000000-0000-4000-8000-000000000001', '82000000-0000-4000-8000-000000000008'))->>'entitlementId',
  (select id::text from public.user_entitlements where user_id = '80000000-0000-4000-8000-000000000001' and plan_code = 'free'),
  'S6: a new reservation draws from Free, never from the revoked pilot');
select is((select count(*) from public.usage_ledger where entitlement_id = current_setting('wa11.pilot')::uuid),
  23::bigint, 'S6: the pilot''s ledger history is intact (22 committed + 1 released)');
select is((select count(*) from public.usage_ledger where entitlement_id = current_setting('wa11.pilot')::uuid and status = 'committed'),
  22::bigint, 'S6: committed count is exact');

-- ---------------------------------------------------------------------------
-- S7 — the audit trail equals the applied mutations, exactly once each
-- ---------------------------------------------------------------------------
select is(
  (select string_agg(a.action, ',' order by (a.after_state->>'version')::int)
   from public.admin_audit_events a where a.target_entitlement_id = current_setting('wa11.pilot')::uuid),
  'grant_salon_pilot,increase_allowance,increase_allowance,decrease_allowance,decrease_allowance,' ||
  'decrease_allowance,increase_allowance,suspend_entitlement,decrease_allowance,reactivate_entitlement,' ||
  'increase_allowance,revoke_entitlement',
  'S7: one audit per applied mutation, in version order, none for replays or refusals');
select is((select count(distinct (a.after_state->>'version')::int) || '/' || count(*)
   from public.admin_audit_events a where a.target_entitlement_id = current_setting('wa11.pilot')::uuid), '12/12',
  'S7: every applied mutation advanced the version exactly once');
select is((select version from public.user_entitlements where id = current_setting('wa11.pilot')::uuid), 12,
  'S7: the row version equals the number of applied mutations');
select is((select allowance_adjustment_total from public.user_entitlements where id = current_setting('wa11.pilot')::uuid),
  (select sum(amount)::int from public.entitlement_allowance_adjustments where entitlement_id = current_setting('wa11.pilot')::uuid),
  'S7: the adjustment total is the ledger sum');
select is((select count(*) from public.entitlement_allowance_adjustments where entitlement_id = current_setting('wa11.pilot')::uuid),
  8::bigint, 'S7: eight applied adjustments, none duplicated');
select is((select bool_and(a.idempotency_key is not null and a.admin_user_id is not null)
   from public.admin_audit_events a where a.target_entitlement_id = current_setting('wa11.pilot')::uuid), true,
  'S7: every event carries its key and actor');
select is((select count(*) from (select target_user_id, action, idempotency_key
   from public.admin_audit_events group by 1, 2, 3 having count(*) > 1) d), 0::bigint,
  'S7: no (target, action, key) appears twice');

-- ---------------------------------------------------------------------------
-- S8 — the guards that make the above hold
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ insert into public.admin_audit_events (source, admin_user_id, action, target_user_id, target_entitlement_id, idempotency_key)
     values ('admin', '80000000-0000-4000-8000-000000000a00', 'revoke_entitlement',
             '80000000-0000-4000-8000-000000000001', current_setting('wa11.pilot')::uuid, 'wa11-rev') $$,
  '23505', null, 'S8: the audit uniqueness key refuses a second event for the same action key');
select throws_ok(
  $$ insert into public.entitlement_allowance_adjustments (entitlement_id, target_user_id, admin_user_id, adjustment_type, amount, reason, idempotency_key)
     values (current_setting('wa11.pilot')::uuid, '80000000-0000-4000-8000-000000000001',
             '80000000-0000-4000-8000-000000000a00', 'increase_allowance', 10, 'dup', 'wa11-dbl') $$,
  '23505', null, 'S8: the adjustment ledger refuses a second row for the same key');
select throws_ok(
  $$ update public.user_entitlements set allowance_adjustment_total = 0 where id = current_setting('wa11.pilot')::uuid $$,
  'P0001', null, 'S8: the total cannot be moved outside the ledger');
select is(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('admin_grant_salon_pilot', 'admin_adjust_salon_pilot_allowance',
                        'admin_lock_salon_pilot_target', 'reserve_ai_look', 'commit_ai_look',
                        'release_ai_look', 'apply_entitlement_allowance_adjustment')
      and p.prosrc like '%pg_advisory_xact_lock(hashtextextended(%'),
  7::bigint, 'S8: every admin writer and the usage engine serialize on the same per-account lock');

select * from finish();
rollback;
