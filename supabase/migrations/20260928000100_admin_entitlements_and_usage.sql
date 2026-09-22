-- FaceTune WA-6: read-only, bounded entitlement and usage-ledger reads.
--
-- Additive. Two `security definer` RPCs and two keyset indexes. Nothing here
-- inserts, updates, deletes, reserves, commits, releases, grants, adjusts,
-- suspends, or revokes anything; no existing table, column, constraint,
-- policy, grant, trigger, or function is altered.
--
-- Both RPCs follow WA-4/WA-5 exactly: granted to `authenticated`, called with
-- the admin's own session, and the first thing each does is ask
-- `public.is_admin(auth.uid())`. A caller who is not on the active roster
-- receives a sanitized refusal and no rows. Filters are optional and are
-- validated against the Shared Contract vocabulary; a value outside it is a
-- client defect and is rejected, never coerced.
--
-- ## Entitlements
--
-- One row per `user_entitlements` row — every entitlement an account has ever
-- held, not only the governing one — so an admin can see a superseded, lapsed,
-- pending, or revoked grant next to the current one. Each page row carries
-- the same figures the consumer resolver reports for the governing row,
-- computed here with the resolver's own arithmetic (Shared Contract §29, §41,
-- §74) and only for the 25 rows that leave the server:
--
--   effective_allowance = max(0, base + adjustment_total)
--   committed / reserved = subscription-sourced ledger rows for this
--                          entitlement in its current period (by reserved_at)
--   available = max(0, effective − committed − reserved)
--   remaining = max(0, effective − committed)
--
-- `effectiveStatus` applies the rule WA-5 fixed for the read model: a row
-- stored `active` / `grace_period` whose `expires_at` or `period_end` has
-- passed reads `expired`, exactly the cases where the resolver would deny
-- with SALON_PILOT_EXPIRED / ENTITLEMENT_EXPIRED. Every other status is the
-- stored one. The status filter applies to this effective status, because it
-- is the status the admin is shown.
--
-- ## Usage
--
-- One row per `usage_ledger` row, in the canonical states reserved /
-- committed / released, with the row's stamped provenance (plan, unit,
-- source) and lifecycle timestamps. The canonical Final Preview lineage is
-- reported only as `sourceMode` plus whether the preview row still exists;
-- no image row id, storage path, URL, prompt, or analysis field is read.
--
-- `usage_ledger` has no request-correlation column and Shared Contract §42
-- does not define one; `operationId` is the only cross-layer identifier and
-- nothing is invented to stand in for a second.

-- ---------------------------------------------------------------------------
-- 1. Keyset indexes for the unfiltered, newest-first listings
-- ---------------------------------------------------------------------------
create index if not exists user_entitlements_created_at_id_idx
  on public.user_entitlements (created_at desc, id desc);
create index if not exists usage_ledger_created_at_id_idx
  on public.usage_ledger (created_at desc, id desc);

-- ---------------------------------------------------------------------------
-- 2. Entitlements
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_entitlements(
  p_user_id uuid default null,
  p_plan_code text default null,
  p_status text default null,
  p_billing_provider text default null,
  p_expires_within_days integer default null,
  p_cursor text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_plan text := nullif(btrim(p_plan_code), '');
  v_status text := nullif(btrim(p_status), '');
  v_provider text := nullif(btrim(p_billing_provider), '');
  v_expires_before timestamptz := null;
  v_filters jsonb;
  v_cursor_payload jsonb;
  v_cursor_created_at timestamptz := null;
  v_cursor_id uuid := null;
  v_items jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_last jsonb := null;
  v_next_cursor text := null;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  -- Filters are vocabulary members or nothing. The plan list is the product
  -- table, the single source of plan codes.
  if v_plan is not null and not exists (
    select 1 from public.subscription_products as p where p.plan_code = v_plan
  ) then
    raise exception using errcode = '22023', message = 'invalid plan filter';
  end if;
  if v_status is not null and v_status not in (
    'pending', 'active', 'grace_period', 'expired', 'suspended', 'revoked'
  ) then
    raise exception using errcode = '22023', message = 'invalid status filter';
  end if;
  if v_provider is not null and v_provider not in (
    'none', 'google_play', 'apple_app_store', 'admin_granted'
  ) then
    raise exception using errcode = '22023', message = 'invalid provider filter';
  end if;
  if p_expires_within_days is not null then
    if p_expires_within_days < 1 or p_expires_within_days > 365 then
      raise exception using errcode = '22023', message = 'invalid expiration window';
    end if;
    v_expires_before := v_now + make_interval(days => p_expires_within_days);
  end if;

  v_filters := jsonb_build_object(
    'userId', p_user_id,
    'planCode', v_plan,
    'status', v_status,
    'billingProvider', v_provider,
    'expiresWithinDays', p_expires_within_days
  );

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_id := (v_cursor_payload->>'id')::uuid;
      if (v_cursor_payload->'filters') is distinct from v_filters then
        raise exception using errcode = '22023', message = 'pagination cursor does not match filters';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select
      e.id,
      e.user_id,
      e.plan_code,
      e.status,
      case
        when e.status in ('active', 'grace_period')
          and (
            (e.expires_at is not null and e.expires_at <= v_now)
            or (e.period_end is not null and e.period_end <= v_now)
          )
          then 'expired'
        else e.status
      end as effective_status,
      e.billing_provider,
      e.period_start,
      e.period_end,
      e.starts_at,
      e.expires_at,
      e.auto_renew,
      e.base_ai_look_allowance,
      e.allowance_adjustment_total,
      e.version,
      e.created_at,
      e.updated_at
    from public.user_entitlements as e
    where (p_user_id is null or e.user_id = p_user_id)
      and (v_plan is null or e.plan_code = v_plan)
      and (v_provider is null or e.billing_provider = v_provider)
      and (
        v_status is null
        or v_status = case
          when e.status in ('active', 'grace_period')
            and (
              (e.expires_at is not null and e.expires_at <= v_now)
              or (e.period_end is not null and e.period_end <= v_now)
            )
            then 'expired'
          else e.status
        end
      )
      and (
        v_expires_before is null
        or (e.expires_at is not null
            and e.expires_at > v_now
            and e.expires_at <= v_expires_before)
      )
      and (
        v_cursor_created_at is null
        or (e.created_at, e.id) < (v_cursor_created_at, v_cursor_id)
      )
    order by e.created_at desc, e.id desc
    limit 26
  ), page as materialized (
    select * from candidates
    order by created_at desc, id desc
    limit 25
  ), figures as materialized (
    select
      p.*,
      u.email,
      pr.display_name,
      pr.allowance_unit,
      greatest(0, p.base_ai_look_allowance + p.allowance_adjustment_total)
        as effective_allowance,
      coalesce(l.committed, 0) as committed,
      coalesce(l.reserved, 0) as reserved
    from page as p
    left join auth.users as u on u.id = p.user_id
    left join public.subscription_products as pr on pr.plan_code = p.plan_code
    left join lateral (
      select
        count(*) filter (where l.status = 'committed') as committed,
        count(*) filter (where l.status = 'reserved') as reserved
      from public.usage_ledger as l
      where l.entitlement_id = p.id
        and l.user_id = p.user_id
        and l.allowance_source = 'subscription'
        and (p.period_start is null or l.reserved_at >= p.period_start)
    ) as l on true
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'entitlementId', f.id,
          'userId', f.user_id,
          'email', f.email,
          'planCode', f.plan_code,
          'planDisplayName', f.display_name,
          'storedStatus', f.status,
          'effectiveStatus', f.effective_status,
          'billingProvider', f.billing_provider,
          'allowanceUnit', f.allowance_unit,
          'baseAllowance', f.base_ai_look_allowance,
          'allowanceAdjustmentTotal', f.allowance_adjustment_total,
          'effectiveAllowance', f.effective_allowance,
          'committedUsage', f.committed,
          'reservedUsage', f.reserved,
          'availableAiLooks',
            greatest(0, f.effective_allowance - f.committed - f.reserved),
          'remainingAiLooks', greatest(0, f.effective_allowance - f.committed),
          'periodStart', f.period_start,
          'periodEnd', f.period_end,
          'startsAt', f.starts_at,
          'expiresAt', f.expires_at,
          'autoRenew', f.auto_renew,
          'version', f.version,
          'createdAt', f.created_at,
          'updatedAt', f.updated_at
        )
        order by f.created_at desc, f.id desc
      ),
      '[]'::jsonb
    ),
    (select count(*) from candidates),
    (
      select jsonb_build_object('createdAt', p.created_at, 'id', p.id)
      from page as p
      order by p.created_at asc, p.id asc
      limit 1
    )
  into v_items, v_count, v_last
  from figures as f;

  if v_count > 25 then
    v_next_cursor := encode(
      convert_to((v_last || jsonb_build_object('filters', v_filters))::text, 'utf8'),
      'base64'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'createdAt', 'direction', 'desc'),
    'filters', v_filters,
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Usage ledger
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_usage(
  p_user_id uuid default null,
  p_entitlement_id uuid default null,
  p_status text default null,
  p_plan_code text default null,
  p_allowance_source text default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_cursor text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_status text := nullif(btrim(p_status), '');
  v_plan text := nullif(btrim(p_plan_code), '');
  v_source text := nullif(btrim(p_allowance_source), '');
  v_filters jsonb;
  v_cursor_payload jsonb;
  v_cursor_created_at timestamptz := null;
  v_cursor_id uuid := null;
  v_items jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_last jsonb := null;
  v_next_cursor text := null;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  if v_status is not null and v_status not in ('reserved', 'committed', 'released') then
    raise exception using errcode = '22023', message = 'invalid status filter';
  end if;
  if v_plan is not null and not exists (
    select 1 from public.subscription_products as p where p.plan_code = v_plan
  ) then
    raise exception using errcode = '22023', message = 'invalid plan filter';
  end if;
  if v_source is not null and v_source not in ('subscription', 'purchased_credit') then
    raise exception using errcode = '22023', message = 'invalid allowance source filter';
  end if;
  if p_from is not null and p_to is not null and p_to <= p_from then
    raise exception using errcode = '22023', message = 'invalid date range';
  end if;

  v_filters := jsonb_build_object(
    'userId', p_user_id,
    'entitlementId', p_entitlement_id,
    'status', v_status,
    'planCode', v_plan,
    'allowanceSource', v_source,
    'from', p_from,
    'to', p_to
  );

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_id := (v_cursor_payload->>'id')::uuid;
      if (v_cursor_payload->'filters') is distinct from v_filters then
        raise exception using errcode = '22023', message = 'pagination cursor does not match filters';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select
      l.id,
      l.user_id,
      l.entitlement_id,
      l.usage_type,
      l.operation_id,
      l.status,
      l.plan_code,
      l.allowance_unit,
      l.allowance_source,
      l.source_mode,
      -- Lineage presence only. The preview row id itself never leaves the
      -- server; an admin cannot fetch the image either way, and does not
      -- need to in order to read the ledger.
      case
        when l.status = 'committed'
          then (l.canonical_generated_image_id is not null
                or l.canonical_kit_generated_image_id is not null)
        else null
      end as canonical_preview_retained,
      l.period_start,
      l.period_end,
      l.reserved_at,
      l.committed_at,
      l.released_at,
      l.sanitized_failure_code,
      l.created_at,
      l.updated_at
    from public.usage_ledger as l
    where (p_user_id is null or l.user_id = p_user_id)
      and (p_entitlement_id is null or l.entitlement_id = p_entitlement_id)
      and (v_status is null or l.status = v_status)
      and (v_plan is null or l.plan_code = v_plan)
      and (v_source is null or l.allowance_source = v_source)
      and (p_from is null or l.created_at >= p_from)
      and (p_to is null or l.created_at < p_to)
      and (
        v_cursor_created_at is null
        or (l.created_at, l.id) < (v_cursor_created_at, v_cursor_id)
      )
    order by l.created_at desc, l.id desc
    limit 26
  ), page as materialized (
    select * from candidates
    order by created_at desc, id desc
    limit 25
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'usageId', p.id,
          'userId', p.user_id,
          'email', u.email,
          'entitlementId', p.entitlement_id,
          'usageType', p.usage_type,
          'operationId', p.operation_id,
          'status', p.status,
          'planCode', p.plan_code,
          'allowanceUnit', p.allowance_unit,
          'allowanceSource', p.allowance_source,
          'sourceMode', p.source_mode,
          'canonicalPreviewRetained', p.canonical_preview_retained,
          'periodStart', p.period_start,
          'periodEnd', p.period_end,
          'reservedAt', p.reserved_at,
          'committedAt', p.committed_at,
          'releasedAt', p.released_at,
          'sanitizedFailureCode', p.sanitized_failure_code,
          'createdAt', p.created_at,
          'updatedAt', p.updated_at
        )
        order by p.created_at desc, p.id desc
      ),
      '[]'::jsonb
    ),
    (select count(*) from candidates),
    (
      select jsonb_build_object('createdAt', p.created_at, 'id', p.id)
      from page as p
      order by p.created_at asc, p.id asc
      limit 1
    )
  into v_items, v_count, v_last
  from page as p
  left join auth.users as u on u.id = p.user_id;

  if v_count > 25 then
    v_next_cursor := encode(
      convert_to((v_last || jsonb_build_object('filters', v_filters))::text, 'utf8'),
      'base64'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'createdAt', 'direction', 'desc'),
    'filters', v_filters,
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Access: session-callable, self-authorizing; not a service-role endpoint.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_list_entitlements(uuid, text, text, text, integer, text) from public;
revoke all on function public.admin_list_entitlements(uuid, text, text, text, integer, text) from anon;
revoke all on function public.admin_list_entitlements(uuid, text, text, text, integer, text) from service_role;
grant execute on function public.admin_list_entitlements(uuid, text, text, text, integer, text) to authenticated;

revoke all on function public.admin_list_usage(uuid, uuid, text, text, text, timestamptz, timestamptz, text) from public;
revoke all on function public.admin_list_usage(uuid, uuid, text, text, text, timestamptz, timestamptz, text) from anon;
revoke all on function public.admin_list_usage(uuid, uuid, text, text, text, timestamptz, timestamptz, text) from service_role;
grant execute on function public.admin_list_usage(uuid, uuid, text, text, text, timestamptz, timestamptz, text) to authenticated;
