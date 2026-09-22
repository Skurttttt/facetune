-- FaceTune WA-10: immutable audit inspection and entitlement lifecycle history.
--
-- Read-only and additive. The existing WA-7--WA-9 writers remain the only
-- producers of admin audit events. These RPCs merely project those rows
-- through a privacy allowlist and merge entitlement-scoped provider lifecycle
-- notifications into a readable timeline. No browser role receives table
-- access, and no function in this migration inserts, updates, or deletes data.

-- ---------------------------------------------------------------------------
-- 1. Privacy and query indexes
-- ---------------------------------------------------------------------------

-- The writers already emit exactly these six fields. Lock that storage shape
-- so a future writer cannot turn an audit snapshot into an arbitrary payload.
alter table public.admin_audit_events
  add constraint admin_audit_events_before_state_privacy_safe
  check (
    before_state is null
    or (
      jsonb_typeof(before_state) = 'object'
      and before_state - array[
        'status', 'planCode', 'effectiveAllowance',
        'allowanceAdjustmentTotal', 'expiresAt', 'version'
      ]::text[] = '{}'::jsonb
    )
  );

alter table public.admin_audit_events
  add constraint admin_audit_events_after_state_privacy_safe
  check (
    after_state is null
    or (
      jsonb_typeof(after_state) = 'object'
      and after_state - array[
        'status', 'planCode', 'effectiveAllowance',
        'allowanceAdjustmentTotal', 'expiresAt', 'version'
      ]::text[] = '{}'::jsonb
    )
  );

create index admin_audit_events_admin_created_id_idx
  on public.admin_audit_events (admin_user_id, created_at desc, id desc);
create index admin_audit_events_action_created_id_idx
  on public.admin_audit_events (action, created_at desc, id desc);
create index admin_audit_events_user_created_id_idx
  on public.admin_audit_events (target_user_id, created_at desc, id desc);
create index admin_audit_events_entitlement_created_id_idx
  on public.admin_audit_events (target_entitlement_id, created_at desc, id desc);
create index admin_audit_events_source_created_id_idx
  on public.admin_audit_events (source, created_at desc, id desc);
create index provider_notification_events_entitlement_time_idx
  on public.provider_notification_events (
    entitlement_id,
    event_time desc,
    id desc
  )
  where outcome in ('reconciled', 'revoked');

-- Defense in depth on presentation: even if an older or manually repaired row
-- somehow contains another key, only the reviewed fields can leave Postgres.
create or replace function public.admin_safe_audit_snapshot(p_snapshot jsonb)
returns jsonb
language sql
immutable
set search_path = ''
as $$
  select case
    when p_snapshot is null then null
    else jsonb_build_object(
      'status', p_snapshot->'status',
      'planCode', p_snapshot->'planCode',
      'effectiveAllowance', p_snapshot->'effectiveAllowance',
      'allowanceAdjustmentTotal', p_snapshot->'allowanceAdjustmentTotal',
      'expiresAt', p_snapshot->'expiresAt',
      'version', p_snapshot->'version'
    )
  end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Audit list: newest-first, fixed pages of 25, filter-bound cursor
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_audit_events(
  p_admin_user_id uuid default null,
  p_action text default null,
  p_target_user_id uuid default null,
  p_from timestamptz default null,
  p_to timestamptz default null,
  p_target_entitlement_id uuid default null,
  p_source text default null,
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
  v_action text := nullif(btrim(p_action), '');
  v_source text := nullif(btrim(p_source), '');
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

  if v_action is not null and v_action not in (
    'grant_salon_pilot', 'increase_allowance', 'decrease_allowance',
    'extend_expiration', 'suspend_entitlement',
    'reactivate_entitlement', 'revoke_entitlement'
  ) then
    raise exception using errcode = '22023', message = 'invalid audit action filter';
  end if;
  if v_source is not null and v_source not in ('admin', 'provider', 'system') then
    raise exception using errcode = '22023', message = 'invalid audit source filter';
  end if;
  if p_from is not null and p_to is not null and p_to <= p_from then
    raise exception using errcode = '22023', message = 'invalid date range';
  end if;

  v_filters := jsonb_build_object(
    'adminUserId', p_admin_user_id,
    'action', v_action,
    'targetUserId', p_target_user_id,
    'from', p_from,
    'to', p_to,
    'targetEntitlementId', p_target_entitlement_id,
    'source', v_source
  );

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_id := (v_cursor_payload->>'id')::uuid;
      if (v_cursor_payload->'filters') is distinct from v_filters then
        raise exception 'cursor filter mismatch';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select
      a.id, a.source, a.admin_user_id, au.email as admin_email,
      a.action, a.target_user_id, tu.email as target_email,
      a.target_entitlement_id, a.created_at
    from public.admin_audit_events as a
    left join auth.users as au on au.id = a.admin_user_id
    left join auth.users as tu on tu.id = a.target_user_id
    where (p_admin_user_id is null or a.admin_user_id = p_admin_user_id)
      and (v_action is null or a.action = v_action)
      and (p_target_user_id is null or a.target_user_id = p_target_user_id)
      and (p_target_entitlement_id is null or a.target_entitlement_id = p_target_entitlement_id)
      and (v_source is null or a.source = v_source)
      and (p_from is null or a.created_at >= p_from)
      and (p_to is null or a.created_at < p_to)
      and (
        v_cursor_created_at is null
        or (a.created_at, a.id) < (v_cursor_created_at, v_cursor_id)
      )
    order by a.created_at desc, a.id desc
    limit 26
  ), page as materialized (
    select * from candidates order by created_at desc, id desc limit 25
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', p.id,
      'source', p.source,
      'adminUserId', p.admin_user_id,
      'adminEmail', p.admin_email,
      'action', p.action,
      'targetUserId', p.target_user_id,
      'targetEmail', p.target_email,
      'targetEntitlementId', p.target_entitlement_id,
      'createdAt', p.created_at
    ) order by p.created_at desc, p.id desc), '[]'::jsonb),
    (select count(*) from candidates),
    (
      select jsonb_build_object('createdAt', p2.created_at, 'id', p2.id)
      from page as p2 order by p2.created_at asc, p2.id asc limit 1
    )
  into v_items, v_count, v_last
  from page as p;

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
-- 3. Audit detail: one immutable event, snapshots projected through allowlist
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_audit_event(p_event_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_event jsonb;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;
  if p_event_id is null then
    raise exception using errcode = '22023', message = 'eventId is required';
  end if;

  select jsonb_build_object(
    'id', a.id,
    'source', a.source,
    'adminUserId', a.admin_user_id,
    'adminEmail', au.email,
    'action', a.action,
    'targetUserId', a.target_user_id,
    'targetEmail', tu.email,
    'targetEntitlementId', a.target_entitlement_id,
    'beforeState', public.admin_safe_audit_snapshot(a.before_state),
    'afterState', public.admin_safe_audit_snapshot(a.after_state),
    'reason', a.reason,
    'requestCorrelationId', a.request_correlation_id,
    'idempotencyKey', a.idempotency_key,
    'createdAt', a.created_at
  ) into v_event
  from public.admin_audit_events as a
  left join auth.users as au on au.id = a.admin_user_id
  left join auth.users as tu on tu.id = a.target_user_id
  where a.id = p_event_id;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'event', v_event
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Entitlement history: admin audit + sanitized provider lifecycle events
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_entitlement_history(
  p_entitlement_id uuid,
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
  v_cursor_payload jsonb;
  v_cursor_at timestamptz := null;
  v_cursor_key text := null;
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
  if p_entitlement_id is null then
    raise exception using errcode = '22023', message = 'entitlementId is required';
  end if;

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_at := (v_cursor_payload->>'occurredAt')::timestamptz;
      v_cursor_key := v_cursor_payload->>'eventKey';
      if (v_cursor_payload->>'entitlementId')::uuid is distinct from p_entitlement_id then
        raise exception 'cursor entitlement mismatch';
      end if;
      if v_cursor_key is null or char_length(v_cursor_key) = 0 then
        raise exception 'cursor key missing';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with all_events as materialized (
    select
      'admin:' || a.id::text as event_key,
      a.id as event_id,
      'admin'::text as source,
      a.action as event_type,
      a.action,
      a.admin_user_id as actor_user_id,
      au.email as actor_email,
      a.reason,
      public.admin_safe_audit_snapshot(a.before_state) as before_state,
      public.admin_safe_audit_snapshot(a.after_state) as after_state,
      a.request_correlation_id,
      a.created_at as occurred_at,
      null::text as provider
    from public.admin_audit_events as a
    left join auth.users as au on au.id = a.admin_user_id
    where a.target_entitlement_id = p_entitlement_id

    union all

    select
      'provider:' || n.id::text as event_key,
      n.id as event_id,
      'provider'::text as source,
      'provider_state_change'::text as event_type,
      null::text as action,
      null::uuid as actor_user_id,
      null::text as actor_email,
      null::text as reason,
      null::jsonb as before_state,
      case when n.outcome = 'revoked'
        then jsonb_build_object(
          'status', 'revoked', 'planCode', null,
          'effectiveAllowance', null, 'allowanceAdjustmentTotal', null,
          'expiresAt', null, 'version', null
        )
        else null::jsonb
      end as after_state,
      null::uuid as request_correlation_id,
      coalesce(n.event_time, n.processed_at, n.received_at) as occurred_at,
      n.billing_provider as provider
    from public.provider_notification_events as n
    where n.entitlement_id = p_entitlement_id
      and n.outcome in ('reconciled', 'revoked')
  ), candidates as materialized (
    select * from all_events as e
    where v_cursor_at is null
       or (e.occurred_at, e.event_key) < (v_cursor_at, v_cursor_key)
    order by e.occurred_at desc, e.event_key desc
    limit 26
  ), page as materialized (
    select * from candidates order by occurred_at desc, event_key desc limit 25
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'id', p.event_id,
      'source', p.source,
      'eventType', p.event_type,
      'action', p.action,
      'actorUserId', p.actor_user_id,
      'actorEmail', p.actor_email,
      'reason', p.reason,
      'beforeState', p.before_state,
      'afterState', p.after_state,
      'requestCorrelationId', p.request_correlation_id,
      'provider', p.provider,
      'occurredAt', p.occurred_at
    ) order by p.occurred_at desc, p.event_key desc), '[]'::jsonb),
    (select count(*) from candidates),
    (
      select jsonb_build_object('occurredAt', p2.occurred_at, 'eventKey', p2.event_key)
      from page as p2 order by p2.occurred_at asc, p2.event_key asc limit 1
    )
  into v_items, v_count, v_last
  from page as p;

  if v_count > 25 then
    v_next_cursor := encode(
      convert_to((v_last || jsonb_build_object('entitlementId', p_entitlement_id))::text, 'utf8'),
      'base64'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'createdAt', 'direction', 'desc'),
    'entitlementId', p_entitlement_id,
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Access: session-callable, self-authorizing; never service-role endpoints
-- ---------------------------------------------------------------------------
revoke all on function public.admin_safe_audit_snapshot(jsonb) from public;
revoke all on function public.admin_safe_audit_snapshot(jsonb) from anon;
revoke all on function public.admin_safe_audit_snapshot(jsonb) from authenticated;
revoke all on function public.admin_safe_audit_snapshot(jsonb) from service_role;

revoke all on function public.admin_list_audit_events(uuid, text, uuid, timestamptz, timestamptz, uuid, text, text) from public;
revoke all on function public.admin_list_audit_events(uuid, text, uuid, timestamptz, timestamptz, uuid, text, text) from anon;
revoke all on function public.admin_list_audit_events(uuid, text, uuid, timestamptz, timestamptz, uuid, text, text) from service_role;
grant execute on function public.admin_list_audit_events(uuid, text, uuid, timestamptz, timestamptz, uuid, text, text) to authenticated;

revoke all on function public.admin_get_audit_event(uuid) from public;
revoke all on function public.admin_get_audit_event(uuid) from anon;
revoke all on function public.admin_get_audit_event(uuid) from service_role;
grant execute on function public.admin_get_audit_event(uuid) to authenticated;

revoke all on function public.admin_list_entitlement_history(uuid, text) from public;
revoke all on function public.admin_list_entitlement_history(uuid, text) from anon;
revoke all on function public.admin_list_entitlement_history(uuid, text) from service_role;
grant execute on function public.admin_list_entitlement_history(uuid, text) to authenticated;
