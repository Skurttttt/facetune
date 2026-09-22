-- FaceTune WA-4: read-only operational metrics for the Web Admin dashboard.
--
-- Purely additive. No existing table, column, constraint, policy, grant,
-- trigger, or function is altered. Nothing here writes anything.
--
-- ## What this is
--
-- One `security definer` function that returns the dashboard's numbers,
-- aggregated in the database, for an authenticated session that the admin
-- roster (WA-2) says is an administrator. The browser receives totals and
-- nothing else: no rows, no ids, no emails, no user content. Every figure is
-- a COUNT over a table the client roles cannot read, computed at call time
-- against the server clock (Shared Contract §100), so there is no cached
-- number to go stale and no client arithmetic to disagree with the server.
--
-- ## Authorization
--
-- The function is granted to `authenticated` so the Web Admin can call it
-- with the admin's own session — exactly like `current_user_is_admin()`
-- and `resolve_subscription_state()`, and with no service-role key anywhere
-- in the path. It decides for itself: the first thing it does is ask
-- `public.is_admin(auth.uid())`, and a caller who is not an active admin
-- gets a sanitized refusal with no metrics in it. The Edge Function
-- middleware (`_shared/admin_auth.ts`) remains the gate for privileged
-- *mutations*; this read has the same check one layer down.
--
-- ## What it deliberately does not do
--
--   * No per-user or per-entitlement rows. Detail belongs to the Users,
--     Entitlements, Usage and Audit sections (WA-5, WA-6, WA-10), paginated.
--   * No arguments. There is nothing for a caller to steer, and therefore no
--     way to use it as a lookup oracle about a particular account.
--   * No percentages, trends or history. Only counts the schema actually
--     holds, as of now.
--   * No revenue, price, or provider figures. Money is Google Play's truth.
--
-- ## Definitions (fixed here so the dashboard and later sections agree)
--
--   in force        status in ('active','grace_period'), starts_at <= now,
--                   and neither expires_at nor period_end has passed —
--                   the same predicate `resolve_subscription_state` uses to
--                   pick the governing entitlement (rank 0), with Free counted
--                   too so the plan table sums to something meaningful.
--   today / month   UTC calendar day and month, by the row's own event
--                   timestamp (committed_at / released_at), never created_at.
--   expiring soon   an in-force Salon Pilot whose expires_at falls within the
--                   next 14 days.

-- ---------------------------------------------------------------------------
-- 1. Indexes for the two time-bucketed counts
-- ---------------------------------------------------------------------------
--
-- `usage_ledger` is indexed by owner, entitlement and reservation age, none
-- of which serves "committed this month". Two small partial indexes keep the
-- dashboard from scanning every committed row each time it is opened; both
-- are also what the Usage section (WA-6) will sort by.
create index if not exists usage_ledger_committed_at_idx
  on public.usage_ledger (committed_at)
  where status = 'committed';

create index if not exists usage_ledger_released_at_idx
  on public.usage_ledger (released_at)
  where status = 'released';

-- ---------------------------------------------------------------------------
-- 2. The metrics
-- ---------------------------------------------------------------------------
create or replace function public.admin_dashboard_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_today_start timestamptz := date_trunc('day', v_now);
  v_month_start timestamptz := date_trunc('month', v_now);
  v_soon timestamptz := v_now + interval '14 days';

  v_total_users bigint;
  v_anonymous_guests bigint;

  v_in_force_by_plan jsonb;
  v_pending bigint;
  v_suspended bigint;

  v_committed_today jsonb;
  v_committed_month jsonb;
  v_reserved_open bigint;
  v_released_today bigint;
  v_released_month bigint;

  v_pilot_in_force bigint;
  v_pilot_expiring_soon bigint;

  v_credit_grants_active bigint;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  -- Accounts. Guests are counted apart: they hold the `authenticated` role
  -- but are not people who signed up, and they can never be admins.
  select
    count(*) filter (where u.is_anonymous = false),
    count(*) filter (where u.is_anonymous = true)
  into v_total_users, v_anonymous_guests
  from auth.users as u
  where u.deleted_at is null;

  -- Entitlements in force, per plan. Every canonical plan code is present
  -- in the object, with 0 where nothing is in force, so the client never
  -- infers "no key" as anything.
  select jsonb_object_agg(p.plan_code, coalesce(c.n, 0) order by p.plan_code)
  into v_in_force_by_plan
  from public.subscription_products as p
  left join (
    select e.plan_code, count(*) as n
    from public.user_entitlements as e
    where e.status in ('active', 'grace_period')
      and e.starts_at <= v_now
      and (e.expires_at is null or e.expires_at > v_now)
      and (e.period_end is null or e.period_end > v_now)
    group by e.plan_code
  ) as c on c.plan_code = p.plan_code;

  select
    count(*) filter (where e.status = 'pending'),
    count(*) filter (where e.status = 'suspended')
  into v_pending, v_suspended
  from public.user_entitlements as e;

  -- AI Look activity. Committed rows are split by the bucket they drew from
  -- (Shared Contract §42, §74a): a purchased credit is never an included
  -- AI Look, so the two are never summed here into one misleading number.
  select jsonb_build_object(
    'subscription', count(*) filter (where u.allowance_source = 'subscription'),
    'purchasedCredit', count(*) filter (where u.allowance_source = 'purchased_credit')
  )
  into v_committed_today
  from public.usage_ledger as u
  where u.status = 'committed' and u.committed_at >= v_today_start;

  select jsonb_build_object(
    'subscription', count(*) filter (where u.allowance_source = 'subscription'),
    'purchasedCredit', count(*) filter (where u.allowance_source = 'purchased_credit')
  )
  into v_committed_month
  from public.usage_ledger as u
  where u.status = 'committed' and u.committed_at >= v_month_start;

  select count(*) into v_reserved_open
  from public.usage_ledger as u
  where u.status = 'reserved';

  select
    count(*) filter (where u.released_at >= v_today_start),
    count(*)
  into v_released_today, v_released_month
  from public.usage_ledger as u
  where u.status = 'released' and u.released_at >= v_month_start;

  -- Salon Pilot: in force now, and in force but ending within 14 days.
  select
    count(*),
    count(*) filter (where e.expires_at <= v_soon)
  into v_pilot_in_force, v_pilot_expiring_soon
  from public.user_entitlements as e
  where e.plan_code = 'salon_pilot'
    and e.status in ('active', 'grace_period')
    and e.starts_at <= v_now
    and e.expires_at > v_now;

  select count(*) into v_credit_grants_active
  from public.purchased_credit_grants as g
  where g.revoked_at is null;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'asOf', v_now,
    'todayStartsAt', v_today_start,
    'monthStartsAt', v_month_start,
    'expiringSoonWindowDays', 14,
    'accounts', jsonb_build_object(
      'totalUsers', v_total_users,
      'anonymousGuests', v_anonymous_guests
    ),
    'entitlements', jsonb_build_object(
      'inForceByPlan', v_in_force_by_plan,
      'pending', v_pending,
      'suspended', v_suspended
    ),
    'aiLooks', jsonb_build_object(
      'committedToday', v_committed_today,
      'committedThisMonth', v_committed_month,
      'reservedOpen', v_reserved_open,
      'releasedToday', v_released_today,
      'releasedThisMonth', v_released_month
    ),
    'salonPilot', jsonb_build_object(
      'inForce', v_pilot_in_force,
      'expiringSoon', v_pilot_expiring_soon
    ),
    'purchasedCredits', jsonb_build_object(
      'activeGrants', v_credit_grants_active
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Access
-- ---------------------------------------------------------------------------
revoke all on function public.admin_dashboard_metrics() from public;
revoke all on function public.admin_dashboard_metrics() from anon;
revoke all on function public.admin_dashboard_metrics() from service_role;
grant execute on function public.admin_dashboard_metrics() to authenticated;
