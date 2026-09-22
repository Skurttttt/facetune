-- FaceTune WA-2: admin identity — who may operate the Web Admin.
--
-- Purely additive. No existing table, column, constraint, policy, grant,
-- trigger, or function is altered. In particular nothing here touches the
-- subscription tables or any of the SUB-* functions.
--
-- ## What this is
--
-- The single server-side record of administrative privilege. The Web Admin
-- and every future privileged admin operation ask exactly one question —
-- "is this authenticated account an active admin?" — and this migration
-- provides exactly one answer to it, computed in the database from a row that
-- no client role can read or write.
--
-- Admin privilege is a table row rather than a JWT claim on purpose. A claim
-- is minted at sign-in and lives until the token is refreshed, so a revoked
-- admin would keep working for up to an hour; the Web Admin Source of Truth
-- (§9) requires revocation to take effect without waiting for anything. A row
-- is consulted on every request, so it takes effect on the next one.
--
-- ## What this is not
--
--   * Not an authorization for any admin *action*. `grant_salon_pilot`,
--     allowance adjustments, suspension and the rest arrive in WA-7 … WA-9,
--     each as its own `security definer` function that calls `is_admin`
--     before doing anything. This migration gives them the check, not the
--     capability.
--   * Not a grant/revoke RPC. Provisioning an administrator is an operator
--     action performed as the database owner (`docs/WEB_ADMIN_SETUP.md`), so
--     there is no privileged path a client could reach by mistake and no
--     bootstrap identity hardcoded anywhere in application code.
--   * Not readable by anyone. RLS is enabled with no policy and no grant. The
--     only thing a signed-in user can learn is their own answer, through
--     `current_user_is_admin()`, which returns a boolean and nothing else.
--
-- ## Anonymous accounts
--
-- Supabase anonymous sign-ins are enabled for the consumer app and those
-- sessions hold the ordinary `authenticated` role, so membership in that role
-- is not evidence of a real account. An anonymous user cannot be granted
-- (trigger below) and, belt and braces, is never reported as an admin even if
-- a row somehow existed (`is_admin` re-checks `auth.users`).

-- ---------------------------------------------------------------------------
-- 1. The admin roster
-- ---------------------------------------------------------------------------
--
-- One row per grant. Revocation sets `revoked_at` rather than deleting, and a
-- later re-grant is a new row, so the history of who was an admin when, and
-- who granted or revoked it, is never erased. At most one grant per account
-- is active at a time (partial unique index).
create table public.admin_users (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  granted_at timestamptz not null default timezone('utc', now()),
  -- The administrator who granted it, when granted through a later admin
  -- operation; null for an operator bootstrap. `on delete set null` so the
  -- fact survives the granting account.
  granted_by uuid references auth.users(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references auth.users(id) on delete set null,
  -- A short operational note ("bootstrap", "pilot programme lead"). Never a
  -- credential and never private user content.
  note text,

  constraint admin_users_note_length
    check (note is null or char_length(btrim(note)) between 1 and 200),
  constraint admin_users_revocation_after_grant
    check (revoked_at is null or revoked_at >= granted_at),
  -- A revocation is recorded as a pair or not at all; `revoked_by` alone is
  -- meaningless and `revoked_at` alone loses who did it.
  constraint admin_users_revocation_pair
    check (revoked_at is not null or revoked_by is null)
);

create unique index admin_users_one_active_idx
  on public.admin_users (user_id)
  where revoked_at is null;

create index admin_users_user_idx
  on public.admin_users (user_id, granted_at desc);

-- ---------------------------------------------------------------------------
-- 2. Only a real, live account can be granted
-- ---------------------------------------------------------------------------
create or replace function public.guard_admin_grant()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user auth.users%rowtype;
begin
  select * into v_user from auth.users as u where u.id = new.user_id;
  if not found then
    raise exception 'admin grant target does not exist';
  end if;
  if v_user.is_anonymous then
    raise exception 'an anonymous account cannot be granted admin privilege';
  end if;
  if v_user.deleted_at is not null then
    raise exception 'a deleted account cannot be granted admin privilege';
  end if;
  -- A grant is born active. Revocation is a later, separate change.
  if new.revoked_at is not null or new.revoked_by is not null then
    raise exception 'an admin grant cannot be created already revoked';
  end if;
  return new;
end;
$$;

create trigger admin_users_guard_grant
before insert on public.admin_users
for each row execute function public.guard_admin_grant();

-- ---------------------------------------------------------------------------
-- 3. Grants are history: the only permitted update is a revocation
-- ---------------------------------------------------------------------------
--
-- Same posture as `entitlement_allowance_adjustments`: the identity of the
-- grant never moves, a revocation can be recorded once and never undone (a
-- re-grant is a new row), and the referential SET NULL that runs when a
-- granting or revoking account is deleted is allowed through. There is
-- deliberately no DELETE trigger, for the reason given on `usage_ledger` in
-- SUB-2: it would abort the `auth.users` cascade. Deletion is prevented by
-- privilege instead.
create or replace function public.reject_admin_grant_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.id <> old.id
     or new.user_id <> old.user_id
     or new.granted_at <> old.granted_at
     or new.note is distinct from old.note
  then
    raise exception 'admin grants are immutable audit records';
  end if;

  if not (
    new.granted_by is not distinct from old.granted_by
    or (old.granted_by is not null and new.granted_by is null)
  ) then
    raise exception 'admin grants are immutable audit records';
  end if;

  if old.revoked_at is not null then
    -- Already revoked: nothing but the referential SET NULL may move.
    -- `is distinct from`, not `<>`: clearing the timestamp must be caught
    -- here, and `null <> x` is null, which would let it through.
    if new.revoked_at is distinct from old.revoked_at
       or not (
         new.revoked_by is not distinct from old.revoked_by
         or (old.revoked_by is not null and new.revoked_by is null)
       )
    then
      raise exception 'a revoked admin grant cannot be changed';
    end if;
  end if;

  return new;
end;
$$;

create trigger admin_users_immutable
before update on public.admin_users
for each row execute function public.reject_admin_grant_mutation();

-- ---------------------------------------------------------------------------
-- 4. The one question
-- ---------------------------------------------------------------------------
--
-- `is_admin(uuid)` is the internal answer for privileged server code: future
-- admin write functions (which run as the database owner via `security
-- definer`) call it with the admin id the Edge Function established from the
-- verified JWT, and an Edge Function holding the service-role key may call it
-- directly. It is granted to `service_role` alone; an ordinary user cannot
-- ask about another account.
--
-- The account must be a current, real one: an anonymous session, a soft-
-- deleted account, or an account under an active ban is never an admin,
-- whatever the roster says.
create or replace function public.is_admin(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.admin_users as a
    join auth.users as u on u.id = a.user_id
    where a.user_id = p_user_id
      and a.revoked_at is null
      and u.is_anonymous = false
      and u.deleted_at is null
      and (u.banned_until is null or u.banned_until <= timezone('utc', now()))
  );
$$;

-- `current_user_is_admin()` is the caller-bound form: it answers only for the
-- session it is called from (`auth.uid()`), takes no argument, and returns a
-- boolean and nothing else. The Web Admin calls it with the admin's own
-- session — no service-role key is needed to find out whether a session is
-- administrative — and every protected Edge Function calls it as the caller
-- before doing any privileged work. Unauthenticated callers get `false`.
create or replace function public.current_user_is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_admin((select auth.uid()));
$$;

-- ---------------------------------------------------------------------------
-- 5. Access
-- ---------------------------------------------------------------------------
--
-- Explicit, because the remote project's default ACLs would otherwise hand
-- `anon`, `authenticated` and `service_role` full rights on a new table and
-- EXECUTE on a new function.
alter table public.admin_users enable row level security;

revoke all on table public.admin_users from public;
revoke all on table public.admin_users from anon;
revoke all on table public.admin_users from authenticated;
revoke all on table public.admin_users from service_role;

revoke all on function public.guard_admin_grant() from public;
revoke all on function public.guard_admin_grant() from anon;
revoke all on function public.guard_admin_grant() from authenticated;
revoke all on function public.guard_admin_grant() from service_role;
revoke all on function public.reject_admin_grant_mutation() from public;
revoke all on function public.reject_admin_grant_mutation() from anon;
revoke all on function public.reject_admin_grant_mutation() from authenticated;
revoke all on function public.reject_admin_grant_mutation() from service_role;

revoke all on function public.is_admin(uuid) from public;
revoke all on function public.is_admin(uuid) from anon;
revoke all on function public.is_admin(uuid) from authenticated;
grant execute on function public.is_admin(uuid) to service_role;

revoke all on function public.current_user_is_admin() from public;
revoke all on function public.current_user_is_admin() from anon;
revoke all on function public.current_user_is_admin() from service_role;
grant execute on function public.current_user_is_admin() to authenticated;

-- No policy is created. This is deliberate: the roster is operator data, and
-- the only client-reachable fact is a session's own yes/no above.
