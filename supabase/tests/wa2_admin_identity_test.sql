-- WA-2 — admin identity.
--
-- Proves, against the live privilege model, that admin privilege is a
-- server-side fact: only a real, live, un-revoked account on the roster is
-- an admin; a session learns only its own yes/no; no client role can read or
-- write the roster; forged JWT claims change nothing; revocation takes
-- effect on the next call; and the roster is immutable history. Rolled back.
begin;

select plan(41);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create function pg_temp.as_user(p_user uuid, p_claims jsonb default '{}'::jsonb)
returns void language plpgsql set search_path = '' as $$
begin
  perform set_config(
    'request.jwt.claims',
    (jsonb_build_object('sub', p_user, 'role', 'authenticated') || p_claims)::text,
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

create function pg_temp.can_exec(p_role text, p_fn text) returns boolean
language sql set search_path = '' as $$
  select bool_or(has_function_privilege(p_role, p.oid, 'EXECUTE'))
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = p_fn
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: an admin, a normal user, an anonymous guest, a banned user
-- ---------------------------------------------------------------------------
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
  timezone('utc', now()), timezone('utc', now()), '', '', '', '',
  v.anon, v.banned
from (values
  ('10000000-0000-4000-8000-000000000501'::uuid, 'wa2-admin@example.invalid', false, null::timestamptz),
  ('10000000-0000-4000-8000-000000000502'::uuid, 'wa2-normal@example.invalid', false, null),
  ('10000000-0000-4000-8000-000000000503'::uuid, null, true, null),
  ('10000000-0000-4000-8000-000000000504'::uuid, 'wa2-banned@example.invalid', false,
     timezone('utc', now()) + interval '1 day')
) as v(id, email, anon, banned);

-- Operator bootstrap, exactly as docs/WEB_ADMIN_SETUP.md describes it.
insert into public.admin_users (user_id, note)
values ('10000000-0000-4000-8000-000000000501', 'bootstrap');

-- ===========================================================================
-- 1. Schema posture
-- ===========================================================================
select ok(
  (select c.relrowsecurity from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'admin_users'),
  'admin_users has RLS enabled');
select is(
  (select count(*) from pg_policies where schemaname = 'public' and tablename = 'admin_users'),
  0::bigint, 'admin_users has no policy: nothing is client-readable');
select is(has_table_privilege('anon', 'public.admin_users', 'SELECT'), false, 'anon cannot select admin_users');
select is(has_table_privilege('authenticated', 'public.admin_users', 'SELECT'), false, 'authenticated cannot select admin_users');
select is(has_table_privilege('authenticated', 'public.admin_users', 'INSERT'), false, 'authenticated cannot insert admin_users');
select is(has_table_privilege('authenticated', 'public.admin_users', 'UPDATE'), false, 'authenticated cannot update admin_users');
select is(has_table_privilege('authenticated', 'public.admin_users', 'DELETE'), false, 'authenticated cannot delete admin_users');
select is(has_table_privilege('service_role', 'public.admin_users', 'SELECT'), false, 'service_role cannot select admin_users either — only the owner');

select is(pg_temp.can_exec('authenticated', 'current_user_is_admin'), true, 'authenticated may ask about itself');
select is(pg_temp.can_exec('anon', 'current_user_is_admin'), false, 'anon may not');
select is(pg_temp.can_exec('authenticated', 'is_admin'), false, 'authenticated cannot ask about another account');
select is(pg_temp.can_exec('anon', 'is_admin'), false, 'anon cannot ask about any account');
select is(pg_temp.can_exec('service_role', 'is_admin'), true, 'service_role (server code) may ask about an account');

-- ===========================================================================
-- 2. The one question, answered from the session
-- ===========================================================================
set local role authenticated;

select pg_temp.as_user('10000000-0000-4000-8000-000000000501');
select is(public.current_user_is_admin(), true, 'the admin is an admin');

select pg_temp.as_user('10000000-0000-4000-8000-000000000502');
select is(public.current_user_is_admin(), false, 'a normal user is not');

select pg_temp.as_user('10000000-0000-4000-8000-000000000502',
  '{"app_metadata":{"role":"admin","is_admin":true},"user_metadata":{"isAdmin":true},"is_admin":true}');
select is(public.current_user_is_admin(), false, 'forged admin claims in the JWT change nothing');

select pg_temp.as_user('10000000-0000-4000-8000-000000000502', '{"role":"service_role"}');
select is(public.current_user_is_admin(), false, 'a forged role claim changes nothing');

select pg_temp.as_user('10000000-0000-4000-8000-000000000503');
select is(public.current_user_is_admin(), false, 'an anonymous guest is not');

select pg_temp.as_nobody();
select is(public.current_user_is_admin(), false, 'no session is not');

select pg_temp.as_user('10000000-0000-4000-8000-000000000501');
select throws_ok(
  $$ select * from public.admin_users $$, '42501',
  'permission denied for table admin_users',
  'even the admin cannot read the roster from a client session');
select throws_ok(
  $$ insert into public.admin_users (user_id) values ('10000000-0000-4000-8000-000000000502') $$,
  '42501', 'permission denied for table admin_users',
  'an admin session cannot grant admin to another account directly');
select throws_ok(
  $$ update public.admin_users set revoked_at = now() $$,
  '42501', 'permission denied for table admin_users',
  'an admin session cannot revoke directly');
select throws_ok(
  $$ delete from public.admin_users $$,
  '42501', 'permission denied for table admin_users',
  'an admin session cannot delete directly');
select throws_ok(
  $$ select public.is_admin('10000000-0000-4000-8000-000000000501') $$, '42501',
  'permission denied for function is_admin',
  'an admin session cannot call the account-addressed form');

reset role;

-- ===========================================================================
-- 3. Grant guard: only a real, live account
-- ===========================================================================
select throws_ok(
  $$ insert into public.admin_users (user_id) values ('10000000-0000-4000-8000-000000000503') $$,
  'P0001', 'an anonymous account cannot be granted admin privilege',
  'an anonymous account cannot be granted');
select throws_ok(
  $$ insert into public.admin_users (user_id) values ('10000000-0000-4000-8000-000000000999') $$,
  'P0001', 'admin grant target does not exist',
  'a non-existent account cannot be granted');
select throws_ok(
  $$ insert into public.admin_users (user_id, revoked_at, revoked_by)
     values ('10000000-0000-4000-8000-000000000502', now(), '10000000-0000-4000-8000-000000000501') $$,
  'P0001', 'an admin grant cannot be created already revoked',
  'a grant is born active');
select throws_ok(
  $$ insert into public.admin_users (user_id) values ('10000000-0000-4000-8000-000000000501') $$,
  '23505', null,
  'a second active grant for the same account is refused');

-- A banned account is on the roster but is not an admin while the ban holds.
insert into public.admin_users (user_id, note)
values ('10000000-0000-4000-8000-000000000504', 'banned fixture');
select is(public.is_admin('10000000-0000-4000-8000-000000000504'), false,
  'a banned account is not an admin even with an active grant');
update auth.users set banned_until = timezone('utc', now()) - interval '1 second'
 where id = '10000000-0000-4000-8000-000000000504';
select is(public.is_admin('10000000-0000-4000-8000-000000000504'), true,
  'an expired ban no longer blocks');
update auth.users set deleted_at = timezone('utc', now())
 where id = '10000000-0000-4000-8000-000000000504';
select is(public.is_admin('10000000-0000-4000-8000-000000000504'), false,
  'a soft-deleted account is not an admin');

-- ===========================================================================
-- 4. Revocation takes effect immediately and is history
-- ===========================================================================
update public.admin_users
   set revoked_at = timezone('utc', now()),
       revoked_by = '10000000-0000-4000-8000-000000000501'
 where user_id = '10000000-0000-4000-8000-000000000501' and revoked_at is null;

set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-000000000501');
select is(public.current_user_is_admin(), false, 'a revoked admin is refused on the very next call');
reset role;

select throws_ok(
  $$ update public.admin_users set revoked_at = null
      where user_id = '10000000-0000-4000-8000-000000000501' $$,
  'P0001', 'a revoked admin grant cannot be changed',
  'a revocation cannot be undone in place');
select throws_ok(
  $$ update public.admin_users set user_id = '10000000-0000-4000-8000-000000000502'
      where user_id = '10000000-0000-4000-8000-000000000501' $$,
  'P0001', 'admin grants are immutable audit records',
  'a grant cannot be moved to another account');
select throws_ok(
  $$ update public.admin_users set note = 'edited'
      where user_id = '10000000-0000-4000-8000-000000000501' $$,
  'P0001', 'admin grants are immutable audit records',
  'a grant note cannot be rewritten');

-- Re-grant is a new row; the revoked one stays.
insert into public.admin_users (user_id, granted_by, note)
values ('10000000-0000-4000-8000-000000000501', '10000000-0000-4000-8000-000000000501', 're-grant');
select is(
  (select count(*) from public.admin_users where user_id = '10000000-0000-4000-8000-000000000501'),
  2::bigint, 'the revoked grant and the new grant both exist');
select is(public.is_admin('10000000-0000-4000-8000-000000000501'), true, 'the re-granted admin is an admin again');

-- The referential SET NULL when the granting account disappears is allowed;
-- the grant itself survives.
delete from auth.users where id = '10000000-0000-4000-8000-000000000502';
select lives_ok(
  $$ update public.admin_users set granted_by = null
      where user_id = '10000000-0000-4000-8000-000000000501' and revoked_at is null $$,
  'clearing granted_by (the referential action) is permitted');

-- Deleting the admin account cascades the roster rows (erasure obligation).
delete from auth.users where id = '10000000-0000-4000-8000-000000000501';
select is(
  (select count(*) from public.admin_users where user_id = '10000000-0000-4000-8000-000000000501'),
  0::bigint, 'account deletion removes the roster rows');

-- ===========================================================================
-- 5. Nothing about the answer is derived from email or metadata
-- ===========================================================================
select is(public.is_admin('10000000-0000-4000-8000-000000000503'), false,
  'an anonymous account with no row is not an admin');
select is(public.is_admin(null), false, 'a null account is not an admin');

select * from finish();
rollback;
