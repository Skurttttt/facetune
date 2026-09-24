-- FaceTune WA-DASH-1: Dashboard V2 authoritative read contract.
--
-- Read-only and additive. One roster-checked `security definer` read on the
-- WA-4 / WA-6 / WA-13 pattern. No table, column, constraint, policy, grant,
-- trigger or existing function is altered, and nothing here writes.
--
-- `public.admin_dashboard_metrics()` is deliberately untouched: it has an
-- accepted client decoder and tests. This is a separate V2 contract beside
-- it, not a replacement.
--
-- ## Why this exists
--
-- WA-13.5-UI-5 (Dashboard V2) halted at its own gate having proved four
-- missing aggregates. The UI track's source of truth forbids backend work,
-- so the gaps are closed here, in a separately authorized backend phase:
--
--   B-01  a bounded daily committed series
--   B-02  Final Previews delivered, grouped by plan
--   B-03  committed usage separated by allowance *unit*
--   B-04  a global current/governing entitlement status distribution
--
-- ## What one committed ledger row means (the B-02 proof)
--
-- `usage_ledger.usage_type` is constrained to exactly one value,
-- 'final_makeup_preview' (`usage_ledger_usage_type_valid`), so every row in
-- the ledger is a Final Makeup Preview operation. A row reaches 'committed'
-- only with `committed_at` set and `released_at` null
-- (`usage_ledger_status_timestamps`), and only with a `source_mode`, because
-- "a commit is proof that a usable canonical preview was persisted"
-- (`usage_ledger_committed_requires_source_mode`).
--
-- Therefore: one committed row is one delivered Final Preview. Reserved and
-- released rows are never counted as delivered.
--
-- ## Attribution is historical, never current
--
-- `usage_ledger.plan_code` and `usage_ledger.allowance_unit` are stamped when
-- the reservation is taken and never rewritten, so grouping by them reports
-- what was true at the time of the operation. This function never joins to
-- an account's *present* plan to describe a past delivery.
--
-- Both columns are nullable: rows created before the preview-only offers
-- migration (20260921000100) carry neither. Those rows are reported in their
-- own `unattributed` counters rather than being dropped from the totals or
-- folded into a unit they never had.
--
-- ## Unit is not source
--
-- `allowance_source` ('subscription' | 'purchased_credit') says which bucket
-- paid. `allowance_unit` ('ai_look' | 'final_preview_credit') says what was
-- spent. They are independent: a purchased credit carries the unit class it
-- was granted in, and `reserve_ai_look` spends the class matching the plan's
-- own unit first. The V1 dashboard groups only by source, which is exactly
-- the ambiguity B-03 records; this function groups by unit.
--
-- ## Governing entitlement (the B-04 authority)
--
-- The one entitlement that currently governs an account is chosen by the
-- resolver's final ordering, copied here verbatim from
-- `public.resolve_subscription_state()` rather than from its earlier,
-- pre-Free-compatibility definition:
--
--     0. an in-force non-Free entitlement
--     1. the account's lifetime Free entitlement
--     2. ended or pending non-Free history
--
-- Status, starts_at and created_at break ties within those ranks. This is
-- important because Free deliberately coexists with paid/admin history after
-- SUB-12: ended paid history must not govern merely because its stored status
-- happens to sort ahead of Free. Exactly one row per account with any
-- entitlement enters the distribution, so the categories sum to the stated
-- total and superseded history is excluded by construction.
--
-- Effective status uses the rule the admin reads already share (WA-5, WA-6,
-- WA-13): a stored active/grace row whose `expires_at` has passed reports as
-- 'expired'. No status is renamed and no new state is invented; both the
-- stored and the effective distribution are returned so neither reading is
-- hidden.

create or replace function public.admin_dashboard_v2_metrics()
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
  -- Today plus the preceding 29 UTC calendar days: 30 points exactly.
  v_window_start timestamptz := date_trunc('day', v_now) - interval '29 days';
  -- Exclusive upper bound, so "today" is whole and nothing lands twice.
  v_window_end timestamptz := date_trunc('day', v_now) + interval '1 day';
  v_daily jsonb;
  v_by_plan jsonb;
  v_plan_unattributed integer;
  v_today_units jsonb;
  v_status jsonb;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  -- -------------------------------------------------------------------------
  -- B-01. Committed deliveries per UTC day, 30 rows, zero-filled.
  --
  -- The calendar is generated server-side and left-joined onto the counts, so
  -- a day with no activity is a zero the server stated rather than a gap the
  -- browser has to notice and invent. Supported by
  -- `usage_ledger_committed_at_idx`, the partial index on committed rows.
  -- -------------------------------------------------------------------------
  select jsonb_agg(
    jsonb_build_object(
      'day', to_char(d.day, 'YYYY-MM-DD'),
      'aiLook', coalesce(c.ai_look, 0),
      'finalPreviewCredit', coalesce(c.final_preview_credit, 0),
      'unattributed', coalesce(c.unattributed, 0)
    )
    order by d.day
  )
  into v_daily
  from generate_series(v_window_start, v_today_start, interval '1 day') as d(day)
  left join (
    select
      date_trunc('day', u.committed_at) as day,
      count(*) filter (where u.allowance_unit = 'ai_look') as ai_look,
      count(*) filter (where u.allowance_unit = 'final_preview_credit')
        as final_preview_credit,
      count(*) filter (where u.allowance_unit is null) as unattributed
    from public.usage_ledger as u
    where u.status = 'committed'
      and u.committed_at >= v_window_start
      and u.committed_at < v_window_end
    group by 1
  ) as c on c.day = d.day;

  -- -------------------------------------------------------------------------
  -- B-02. Final Previews delivered by plan over the same 30-day window.
  --
  -- Driven from the product catalogue so every canonical plan is present with
  -- a zero rather than absent, and grouped on the ledger's own historical
  -- `plan_code`. Exactly 8 rows.
  -- -------------------------------------------------------------------------
  select jsonb_agg(
    jsonb_build_object('planCode', p.plan_code, 'delivered', coalesce(c.n, 0))
    order by p.plan_code
  )
  into v_by_plan
  from public.subscription_products as p
  left join (
    select u.plan_code, count(*) as n
    from public.usage_ledger as u
    where u.status = 'committed'
      and u.committed_at >= v_window_start
      and u.committed_at < v_window_end
      and u.plan_code is not null
    group by u.plan_code
  ) as c on c.plan_code = p.plan_code;

  -- Deliveries in the window that predate plan attribution. Reported beside
  -- the eight rows so the array stays exactly the canonical catalogue while
  -- the total remains honest.
  select count(*)
  into v_plan_unattributed
  from public.usage_ledger as u
  where u.status = 'committed'
    and u.committed_at >= v_window_start
    and u.committed_at < v_window_end
    and u.plan_code is null;

  -- -------------------------------------------------------------------------
  -- B-03. Today's committed deliveries by allowance unit, not by source.
  -- -------------------------------------------------------------------------
  select jsonb_build_object(
    'aiLook', count(*) filter (where u.allowance_unit = 'ai_look'),
    'finalPreviewCredit',
      count(*) filter (where u.allowance_unit = 'final_preview_credit'),
    'unattributed', count(*) filter (where u.allowance_unit is null)
  )
  into v_today_units
  from public.usage_ledger as u
  where u.status = 'committed'
    and u.committed_at >= v_today_start
    and u.committed_at < v_window_end;

  -- -------------------------------------------------------------------------
  -- B-04. The governing entitlement of every account that has one.
  --
  -- One row per account, chosen by the resolver's ordering. Every canonical
  -- status is present with a zero, so the object is a whole distribution and
  -- its parts sum to `total`.
  -- -------------------------------------------------------------------------
  with governing as (
    select distinct on (e.user_id)
      e.user_id,
      e.status,
      e.expires_at
    from public.user_entitlements as e
    order by
      e.user_id,
      case
        when e.plan_code <> 'free'
         and e.status in ('active', 'grace_period', 'suspended')
         and e.starts_at <= v_now
         and (e.expires_at is null or e.expires_at > v_now)
         and (e.period_end is null or e.period_end > v_now)
        then 0
        when e.plan_code = 'free' then 1
        else 2
      end,
      case e.status
        when 'active' then 0
        when 'grace_period' then 1
        when 'suspended' then 2
        when 'pending' then 3
        when 'expired' then 4
        when 'revoked' then 5
        else 6
      end,
      e.starts_at desc,
      e.created_at desc
  ), classified as (
    select
      g.status as stored_status,
      case
        when g.status in ('active', 'grace_period')
          and g.expires_at is not null
          and g.expires_at <= v_now
          then 'expired'
        else g.status
      end as effective_status
    from governing as g
  )
  select jsonb_build_object(
    'total', count(*),
    'byStoredStatus', jsonb_build_object(
      'pending', count(*) filter (where stored_status = 'pending'),
      'active', count(*) filter (where stored_status = 'active'),
      'grace_period', count(*) filter (where stored_status = 'grace_period'),
      'expired', count(*) filter (where stored_status = 'expired'),
      'suspended', count(*) filter (where stored_status = 'suspended'),
      'revoked', count(*) filter (where stored_status = 'revoked')
    ),
    'byEffectiveStatus', jsonb_build_object(
      'pending', count(*) filter (where effective_status = 'pending'),
      'active', count(*) filter (where effective_status = 'active'),
      'grace_period', count(*) filter (where effective_status = 'grace_period'),
      'expired', count(*) filter (where effective_status = 'expired'),
      'suspended', count(*) filter (where effective_status = 'suspended'),
      'revoked', count(*) filter (where effective_status = 'revoked')
    )
  )
  into v_status
  from classified;

  return jsonb_build_object(
    'ok', true,
    -- Owned by this function. Deliberately not the V1 dashboard's version:
    -- the two contracts are siblings, not revisions of one another.
    'contractVersion', 'admin_dashboard_v2_contract_v1',
    'asOf', v_now,
    'reportingTimezone', 'UTC',
    'todayStartsAt', v_today_start,
    -- Inclusive first day, exclusive upper bound.
    'window30dStart', v_window_start,
    'window30dEnd', v_window_end,
    'committedDaily', coalesce(v_daily, '[]'::jsonb),
    'finalPreviewsByPlan30d', coalesce(v_by_plan, '[]'::jsonb),
    'finalPreviewsUnattributed30d', coalesce(v_plan_unattributed, 0),
    'committedTodayByUnit', v_today_units,
    'entitlementStatusDistribution', v_status
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Access. Same posture as every other admin read: the browser calls it as the
-- signed-in administrator and nothing else may call it at all.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_dashboard_v2_metrics() from public;
revoke all on function public.admin_dashboard_v2_metrics() from anon;
revoke all on function public.admin_dashboard_v2_metrics() from service_role;
grant execute on function public.admin_dashboard_v2_metrics() to authenticated;
