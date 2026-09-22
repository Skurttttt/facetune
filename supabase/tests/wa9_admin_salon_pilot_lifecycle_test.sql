-- WA-9 — Salon Pilot lifecycle: extend expiration, suspend, reactivate,
-- revoke. Provider boundary, transition rules, generation blocking through
-- the real usage engine, content preservation, idempotency, audit.
begin;

select plan(81);

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

create function pg_temp.extend(
  p_ent uuid, p_new timestamptz, p_key text,
  p_reason text default 'Research extension',
  p_version int default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('60000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_extend_salon_pilot_expiration(
    p_ent, p_new, p_reason, p_key, p_version, '60000000-0000-4000-8000-0000000000c1');
  reset role;
  return v;
end;
$$;

create function pg_temp.lifecycle(
  p_ent uuid, p_action text, p_key text,
  p_reason text default 'Pilot access paused for review',
  p_version int default null
) returns jsonb language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('60000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_set_salon_pilot_lifecycle(
    p_ent, p_action, p_reason, p_key, p_version, '60000000-0000-4000-8000-0000000000c1');
  reset role;
  return v;
end;
$$;

create function pg_temp.grant_pilot(p_target uuid, p_key text) returns uuid
language plpgsql set search_path = '' as $$
declare v jsonb;
begin
  perform pg_temp.as_user('60000000-0000-4000-8000-000000000a00');
  set local role authenticated;
  v := public.admin_grant_salon_pilot(
    p_target, timezone('utc', now()) + interval '30 days',
    'WA-9 fixture grant', p_key, 30, null);
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
  v := public.release_ai_look(p_op, 'generation_failed');
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

-- What the pilot holder can see of their own content, as the app would read it.
create function pg_temp.visible_previews(p_user uuid) returns bigint
language plpgsql set search_path = '' as $$
declare n bigint;
begin
  perform pg_temp.as_user(p_user);
  set local role authenticated;
  select count(*) into n from public.generated_images;
  reset role;
  perform pg_temp.as_nobody();
  return n;
end;
$$;

create function pg_temp.audit_count(p_ent uuid, p_action text) returns bigint
language sql set search_path = '' as $$
  select count(*) from public.admin_audit_events
   where target_entitlement_id = p_ent and action = p_action
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
  ('60000000-0000-4000-8000-000000000a00'::uuid, 'wa9-admin@example.invalid'),
  ('60000000-0000-4000-8000-000000000a01'::uuid, 'wa9-normal@example.invalid'),
  ('60000000-0000-4000-8000-000000000001'::uuid, 'wa9-artist@example.invalid'),
  ('60000000-0000-4000-8000-000000000002'::uuid, 'wa9-pro@example.invalid'),
  ('60000000-0000-4000-8000-000000000003'::uuid, 'wa9-lapsed@example.invalid'),
  ('60000000-0000-4000-8000-000000000004'::uuid, 'wa9-revoke@example.invalid')
) as v(id, email);

insert into public.admin_users (user_id, note)
values ('60000000-0000-4000-8000-000000000a00', 'wa9 fixture');

-- The artist: a 30-day pilot with 3 committed AI Looks (history to preserve).
create temp table pilot as
select pg_temp.grant_pilot('60000000-0000-4000-8000-000000000001', 'wa9-grant-1') as id;
select set_config('wa9.pilot', (select id::text from pilot), true);
select pg_temp.spend('60000000-0000-4000-8000-000000000001', 3);
select is(pg_temp.visible_previews('60000000-0000-4000-8000-000000000001'), 3::bigint,
  'fixture: the artist sees their three previews');

-- A Pro subscriber (provider-backed) and a Free-only account's Free row.
select public.activate_verified_google_play_subscription(
  '60000000-0000-4000-8000-000000000002',
  'facetune_pro', repeat('9', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true
);
create temp table pro as
select e.id from public.user_entitlements e
 where e.user_id = '60000000-0000-4000-8000-000000000002' and e.plan_code = 'pro';
create temp table free_row as
select e.id from public.user_entitlements e
 where e.user_id = '60000000-0000-4000-8000-000000000a01' and e.plan_code = 'free';

-- ---------------------------------------------------------------------------
-- Authorization
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('60000000-0000-4000-8000-000000000a01');
select is((public.admin_set_salon_pilot_lifecycle(
  current_setting('wa9.pilot')::uuid, 'suspend_entitlement', 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'a normal user cannot suspend');
select is((public.admin_extend_salon_pilot_expiration(
  current_setting('wa9.pilot')::uuid, timezone('utc', now()) + interval '90 days', 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'a normal user cannot extend');
select pg_temp.as_user('60000000-0000-4000-8000-000000000001');
select is((public.admin_set_salon_pilot_lifecycle(
  current_setting('wa9.pilot')::uuid, 'reactivate_entitlement', 'x', 'k', null, null))->>'errorCode',
  'ADMIN_UNAUTHORIZED', 'the holder cannot change their own pilot');
select pg_temp.as_nobody();
select is((public.admin_set_salon_pilot_lifecycle(
  current_setting('wa9.pilot')::uuid, 'revoke_entitlement', 'x', 'k', null, null))->>'errorCode',
  'AUTH_REQUIRED', 'an unauthenticated caller cannot revoke');
reset role;

-- ---------------------------------------------------------------------------
-- Validation and the provider boundary
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select pg_temp.lifecycle((select id from pilot), 'delete_entitlement', 'k') $$,
  '22023', null, 'an action outside the contract vocabulary is rejected');
select throws_ok(
  $$ select pg_temp.lifecycle((select id from pilot), 'suspend_entitlement', 'k', p_reason => ' ') $$,
  '22023', null, 'a blank reason is rejected');
select throws_ok(
  $$ select pg_temp.extend((select id from pilot), null, 'k') $$,
  '22023', null, 'a missing new expiration is rejected');
select throws_ok(
  $$ select pg_temp.extend((select id from pilot), timezone('utc', now()) - interval '1 day', 'k') $$,
  '22023', null, 'a past expiration is rejected');
select throws_ok(
  $$ select pg_temp.extend((select id from pilot), timezone('utc', now()) + interval '10 days', 'k') $$,
  '22023', null, 'an expiration earlier than the current one is not an extension');
select is((pg_temp.lifecycle('69999999-9999-4999-8999-999999999999', 'suspend_entitlement', 'k'))->>'errorCode',
  'ENTITLEMENT_NOT_FOUND', 'an unknown entitlement is ENTITLEMENT_NOT_FOUND');
select is((pg_temp.lifecycle((select id from pro), 'suspend_entitlement', 'k-pro'))->>'errorCode',
  'PROVIDER_STATE_CONFLICT', 'a Google Play entitlement cannot be administratively suspended');
select is((pg_temp.lifecycle((select id from pro), 'revoke_entitlement', 'k-pro-r'))->>'errorCode',
  'PROVIDER_STATE_CONFLICT', 'a Google Play entitlement cannot be administratively revoked');
select is((pg_temp.extend((select id from pro), timezone('utc', now()) + interval '90 days', 'k-pro-e'))->>'errorCode',
  'PROVIDER_STATE_CONFLICT', 'a Google Play entitlement cannot be extended with pilot semantics');
select is((select status || ' v' || version from public.user_entitlements where id = (select id from pro)),
  'active v1', 'the store row is untouched');
select is((pg_temp.lifecycle((select id from free_row), 'suspend_entitlement', 'k-free'))->>'errorCode',
  'INVALID_ENTITLEMENT_TRANSITION', 'the lifetime Free row is not a lifecycle target');
select is((select count(*) from public.admin_audit_events), 1::bigint,
  'refusals wrote no audit event (only the fixture grant is recorded)');

-- ---------------------------------------------------------------------------
-- Extend expiration
-- ---------------------------------------------------------------------------
create temp table ext as
select pg_temp.extend((select id from pilot), '2027-03-31T23:59:59Z', 'wa9-ext-1') as r;
select is((select r->>'success' || ' ' || (r->>'action') from ext), 'true extend_expiration',
  'a later expiration is accepted');
select is((select (r->>'expiresAt')::timestamptz from ext), '2027-03-31T23:59:59Z'::timestamptz,
  'the response carries the new expiration');
select is((select r->>'status' from ext), 'active', 'extension leaves the status unchanged');
select is((select (r->>'version')::int from ext), 2, 'the version advanced');
select is((select expires_at from public.user_entitlements where id = (select id from pilot)),
  '2027-03-31T23:59:59Z'::timestamptz, 'the row holds the new expiration');
select is((select (a.before_state->>'expiresAt')::timestamptz < (a.after_state->>'expiresAt')::timestamptz
   from public.admin_audit_events a where a.idempotency_key = 'wa9-ext-1'),
  true, 'the audit records the old and new expiration');
select is((select reason from public.admin_audit_events where idempotency_key = 'wa9-ext-1'),
  'Research extension', 'the reason is recorded');
select is((select r->>'replayed' from pg_temp.extend((select id from pilot), '2027-03-31T23:59:59Z', 'wa9-ext-1') r),
  'true', 'a duplicate extension is replayed');
select is((pg_temp.extend((select id from pilot), '2027-04-30T23:59:59Z', 'wa9-ext-1'))->>'errorCode',
  'IDEMPOTENCY_CONFLICT', 'the same key with a different date is a conflict');
select is(pg_temp.audit_count((select id from pilot), 'extend_expiration'), 1::bigint,
  'extension is audited exactly once');
select is((pg_temp.extend((select id from pilot), '2027-06-30T23:59:59Z', 'wa9-ext-stale', p_version => 1))->>'errorCode',
  'CONCURRENT_MODIFICATION', 'a stale expected version is refused');
select is((select (s->>'expiresAt')::timestamptz from pg_temp.state('60000000-0000-4000-8000-000000000001') s),
  (select expires_at from public.user_entitlements where id = (select id from pilot)),
  'the app resolver reports the extended expiration');

-- ---------------------------------------------------------------------------
-- Suspend: generation blocked, content preserved
-- ---------------------------------------------------------------------------
select is((pg_temp.lifecycle((select id from pilot), 'reactivate_entitlement', 'k-react-early'))->>'errorCode',
  'INVALID_ENTITLEMENT_TRANSITION', 'an active pilot cannot be reactivated');
select is((pg_temp.reserve('60000000-0000-4000-8000-000000000001',
  '62000000-0000-4000-8000-000000000010'))->>'ok', 'true',
  'fixture: one generation is already reserved before suspension');
create temp table susp as
select pg_temp.lifecycle((select id from pilot), 'suspend_entitlement', 'wa9-susp-1') as r;
select is((select r->>'success' || ' ' || (r->>'status') from susp), 'true suspended',
  'an active pilot is suspended');
select is((select r->>'generationAuthorized' || ' ' || (r->>'denialReason') from susp),
  'false ENTITLEMENT_SUSPENDED', 'the response says generation is blocked and why');
select is((select s->>'entitlementStatus' || ' ' || (s->>'generationAuthorized') || ' ' || (s->>'denialReason')
   from pg_temp.state('60000000-0000-4000-8000-000000000001') s),
  'suspended false ENTITLEMENT_SUSPENDED', 'the app resolver refuses generation');
select is((pg_temp.reserve('60000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000001'))->>'errorCode',
  'ENTITLEMENT_SUSPENDED', 'the usage engine refuses a new reservation');
select is(pg_temp.visible_previews('60000000-0000-4000-8000-000000000001'), 3::bigint,
  'the artist still sees every existing preview');
select is((select count(*) from public.usage_ledger where entitlement_id = (select id from pilot) and status = 'committed'),
  3::bigint, 'committed history is untouched');
select is((select count(*) from public.usage_ledger where entitlement_id = (select id from pilot) and status = 'reserved'),
  1::bigint, 'suspension does not release an already-running reservation');
select is((pg_temp.release('60000000-0000-4000-8000-000000000001',
  '62000000-0000-4000-8000-000000000010'))->>'ok', 'true',
  'the existing usage engine can release that failed operation normally');
select is((select count(*) from auth.users where id = '60000000-0000-4000-8000-000000000001' and deleted_at is null),
  1::bigint, 'the account remains');
select is((select (r->>'committedUsage')::int || '/' || (r->>'effectiveAllowance') from susp), '3/30',
  'the response still reports the pilot figures');
select is((pg_temp.lifecycle((select id from pilot), 'suspend_entitlement', 'k-susp-again'))->>'errorCode',
  'INVALID_ENTITLEMENT_TRANSITION', 'a suspended pilot cannot be suspended again under a new key');
select is((select r->>'replayed' from pg_temp.lifecycle((select id from pilot), 'suspend_entitlement', 'wa9-susp-1') r),
  'true', 'a duplicate suspension is replayed');
select is(pg_temp.audit_count((select id from pilot), 'suspend_entitlement'), 1::bigint,
  'suspension is audited exactly once');
select is((select a.before_state->>'status' || '>' || (a.after_state->>'status')
   from public.admin_audit_events a where a.idempotency_key = 'wa9-susp-1'),
  'active>suspended', 'the audit records the transition');

-- ---------------------------------------------------------------------------
-- Reactivate
-- ---------------------------------------------------------------------------
create temp table react as
select pg_temp.lifecycle((select id from pilot), 'reactivate_entitlement', 'wa9-react-1',
  p_reason => 'Review complete') as r;
select is((select r->>'success' || ' ' || (r->>'status') from react), 'true active',
  'a suspended pilot with a valid expiry is reactivated');
select is((select r->>'generationAuthorized' from react), 'true', 'generation is allowed again');
select is((pg_temp.reserve('60000000-0000-4000-8000-000000000001', '62000000-0000-4000-8000-000000000002'))->>'ok',
  'true', 'the usage engine accepts a reservation again');
select is((select (r->>'reservedUsage')::int from pg_temp.lifecycle((select id from pilot), 'reactivate_entitlement', 'wa9-react-1', p_reason => 'Review complete') r),
  1, 'a replayed reactivation returns current figures');
select is(pg_temp.audit_count((select id from pilot), 'reactivate_entitlement'), 1::bigint,
  'reactivation is audited exactly once');

-- Reactivation must respect expires_at: a suspended pilot whose term has
-- ended stays blocked until extended.
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance
) values (
  '61000000-0000-4000-8000-000000000003', '60000000-0000-4000-8000-000000000003',
  'salon_pilot', 'suspended', 'admin_granted',
  timezone('utc', now()) - interval '40 days', timezone('utc', now()) - interval '1 day', false, 30
);
select is((pg_temp.lifecycle('61000000-0000-4000-8000-000000000003', 'reactivate_entitlement', 'k-react-lapsed'))->>'errorCode',
  'ENTITLEMENT_EXPIRED', 'a lapsed suspended pilot cannot be reactivated');
select is((pg_temp.lifecycle('61000000-0000-4000-8000-000000000003', 'suspend_entitlement', 'k-susp-lapsed'))->>'errorCode',
  'INVALID_ENTITLEMENT_TRANSITION', 'a suspended pilot cannot be suspended');
select is((select r->>'success' from pg_temp.extend('61000000-0000-4000-8000-000000000003',
  timezone('utc', now()) + interval '14 days', 'k-ext-lapsed') r), 'true',
  'a lapsed pilot can be extended first');
select is((select r->>'status' from pg_temp.lifecycle('61000000-0000-4000-8000-000000000003', 'reactivate_entitlement', 'k-react-after-ext') r),
  'active', 'and then reactivated');
select is((select s->>'planCode' || ' ' || (s->>'generationAuthorized')
   from pg_temp.state('60000000-0000-4000-8000-000000000003') s),
  'salon_pilot true', 'the revived pilot governs the account again');

-- ---------------------------------------------------------------------------
-- Revoke: terminal, generation blocked, content preserved
-- ---------------------------------------------------------------------------
create temp table pilot2 as
select pg_temp.grant_pilot('60000000-0000-4000-8000-000000000004', 'wa9-grant-4') as id;
select pg_temp.spend('60000000-0000-4000-8000-000000000004', 2);
select pg_temp.lifecycle((select id from pilot2), 'suspend_entitlement', 'wa9-susp-4');
create temp table rev as
select pg_temp.lifecycle((select id from pilot2), 'revoke_entitlement', 'wa9-rev-4',
  p_reason => 'Pilot terminated: terms breached') as r;
select is((select r->>'success' || ' ' || (r->>'status') from rev), 'true revoked',
  'a suspended pilot is revoked');
select is((select r->>'governing' || ' ' || (r->>'generationAuthorized') || ' ' || (r->>'denialReason') from rev),
  'false false ENTITLEMENT_REVOKED', 'the revoked pilot no longer governs and generation is blocked');
select is((select s->>'planCode' || ' ' || (s->>'generationAuthorized')
   from pg_temp.state('60000000-0000-4000-8000-000000000004') s),
  'free true', 'the account falls back to its lifetime Free row (its one complimentary AI Look was never spent)');
create temp table after_revoke as
select pg_temp.reserve('60000000-0000-4000-8000-000000000004', '62000000-0000-4000-8000-000000000004') as r;
select is((select (r->>'entitlementId')::uuid = (select id from pilot2) from after_revoke), false,
  'a reservation after revocation never draws from the revoked pilot');
select is((select r->>'entitlementId' from after_revoke),
  (select id::text from public.user_entitlements where user_id = '60000000-0000-4000-8000-000000000004' and plan_code = 'free'),
  'it draws from the Free row the user still owns');
select is((select count(*) from public.usage_ledger where entitlement_id = (select id from pilot2) and status = 'reserved'), 0::bigint,
  'the revoked pilot holds no new reservation');
select is(pg_temp.visible_previews('60000000-0000-4000-8000-000000000004'), 2::bigint,
  'the revoked artist still sees every existing preview');
select is((select count(*) from public.usage_ledger where entitlement_id = (select id from pilot2)),
  2::bigint, 'ledger history survives revocation');
select is((select (r->>'committedUsage')::int from rev), 2,
  'the response reports the revoked row''s own committed history');
select is((pg_temp.lifecycle((select id from pilot2), 'reactivate_entitlement', 'k-react-revoked'))->>'errorCode',
  'ENTITLEMENT_REVOKED', 'a revoked pilot cannot be reactivated');
select is((pg_temp.lifecycle((select id from pilot2), 'suspend_entitlement', 'k-susp-revoked'))->>'errorCode',
  'ENTITLEMENT_REVOKED', 'a revoked pilot cannot be suspended');
select is((pg_temp.extend((select id from pilot2), timezone('utc', now()) + interval '90 days', 'k-ext-revoked'))->>'errorCode',
  'ENTITLEMENT_REVOKED', 'a revoked pilot cannot be extended');
select is((pg_temp.lifecycle((select id from pilot2), 'revoke_entitlement', 'k-rev-again'))->>'errorCode',
  'ENTITLEMENT_REVOKED', 'a revoked pilot cannot be revoked again under a new key');
select is((select r->>'replayed' || ' ' || (r->>'status') from pg_temp.lifecycle((select id from pilot2), 'revoke_entitlement', 'wa9-rev-4',
  p_reason => 'Pilot terminated: terms breached') r), 'true revoked', 'a duplicate revocation is replayed');
select is((pg_temp.lifecycle((select id from pilot2), 'revoke_entitlement', 'wa9-rev-4', p_reason => 'other'))->>'errorCode',
  'IDEMPOTENCY_CONFLICT', 'the same key with a different reason is a conflict');
select is(pg_temp.audit_count((select id from pilot2), 'revoke_entitlement'), 1::bigint,
  'revocation is audited exactly once');
select is((select a.admin_user_id::text || ' ' || (a.before_state->>'status') || '>' || (a.after_state->>'status') || ' ' || a.reason
   from public.admin_audit_events a where a.idempotency_key = 'wa9-rev-4'),
  '60000000-0000-4000-8000-000000000a00 suspended>revoked Pilot terminated: terms breached',
  'the revocation audit names the admin, the transition, and the reason');
-- A revoked pilot does not block a fresh grant (WA-7 rule: revoked is history).
select isnt(pg_temp.grant_pilot('60000000-0000-4000-8000-000000000004', 'wa9-grant-4c'), null,
  'a new pilot can be granted after revocation');
select is((select s->>'planCode' from pg_temp.state('60000000-0000-4000-8000-000000000004') s),
  'salon_pilot', 'a new pilot can be granted after revocation; the revoked row stays as history');
select is((select count(*) from public.user_entitlements
   where user_id = '60000000-0000-4000-8000-000000000004' and plan_code = 'salon_pilot'),
  2::bigint, 'the revoked row was not deleted or rewritten');

-- ---------------------------------------------------------------------------
-- Response shape and privilege surface
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(k order by k) from rev, jsonb_object_keys(r) k),
  array['action','availableAiLooks','committedUsage','contractVersion','denialReason',
        'effectiveAllowance','entitlementId','expiresAt','generationAuthorized','governing',
        'planCode','remainingAiLooks','replayed','reservedUsage','status','success',
        'targetUserId','updatedAt','version'],
  'the response carries the contract §73 fields plus governing/authorization');
select is((select rev.r::text ~* 'selfie|storage_path|signed.?url|prompt|gemini|makeup_kit|token' from rev),
  false, 'the response carries no private content');
select is(has_function_privilege('anon',
  'public.admin_set_salon_pilot_lifecycle(uuid,text,text,text,integer,uuid)', 'EXECUTE'),
  false, 'anon cannot execute the lifecycle writer');
select is(has_function_privilege('service_role',
  'public.admin_extend_salon_pilot_expiration(uuid,timestamptz,text,text,integer,uuid)', 'EXECUTE'),
  false, 'the extension writer is not a service-role endpoint');
select is(has_function_privilege('authenticated',
  'public.admin_lock_salon_pilot_target(uuid,text)', 'EXECUTE'),
  false, 'the internal target lock is not client-callable');
select is(has_function_privilege('authenticated',
  'public.admin_lifecycle_response(uuid,text,boolean,uuid)', 'EXECUTE'),
  false, 'the internal response builder is not client-callable');

select * from finish();
rollback;
