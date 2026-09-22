-- FaceTune WA-5: bounded account search and sanitized user detail.
--
-- Read-only and additive. The two browser-callable RPCs check the active
-- admin roster before touching auth.users. They return only account identity
-- metadata and subscription fields approved by the Web Admin SOT; no image,
-- storage, prompt, Gemini, analysis, or My Makeup Kit table is referenced.
--
-- Search is deliberately exact: a UUID matches auth.users.id and any other
-- non-empty value matches the normalized auth.users.email. Partial email
-- enumeration is not approved. An empty search lists accounts in fixed,
-- newest-first keyset pages of 25. Sorting and page size are server-owned.

-- ---------------------------------------------------------------------------
-- 1. Reuse the canonical self-scoped subscription resolver for a target.
-- ---------------------------------------------------------------------------
--
-- resolve_subscription_state() correctly owns entitlement precedence,
-- effective status denial, allowance arithmetic, reservations, and purchased
-- credits, but intentionally derives its user from auth.uid(). This internal
-- helper temporarily substitutes only the `sub` used by that resolver, then
-- restores the caller's exact claims in both success and exception paths.
-- It is not executable by any API role. The public admin RPC captures and
-- verifies the real caller before invoking it.
create or replace function public.admin_resolve_subscription_state_for_user(
  p_admin_user_id uuid,
  p_target_user_id uuid
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_original_claims text := current_setting('request.jwt.claims', true);
  v_target_claims jsonb;
  v_state jsonb;
begin
  if p_admin_user_id is null or not public.is_admin(p_admin_user_id) then
    return jsonb_build_object(
      'hasEntitlement', false,
      'generationAuthorized', false,
      'denialReason', 'ADMIN_UNAUTHORIZED',
      'resolvedAt', timezone('utc', now())
    );
  end if;
  if p_target_user_id is null then
    return jsonb_build_object(
      'hasEntitlement', false,
      'generationAuthorized', false,
      'denialReason', 'USER_NOT_FOUND',
      'resolvedAt', timezone('utc', now())
    );
  end if;

  v_target_claims := jsonb_build_object(
    'sub', p_target_user_id,
    'role', 'authenticated'
  );
  perform set_config('request.jwt.claims', v_target_claims::text, true);
  v_state := public.resolve_subscription_state();
  perform set_config(
    'request.jwt.claims',
    coalesce(v_original_claims, ''),
    true
  );
  return v_state;
exception
  when others then
    perform set_config(
      'request.jwt.claims',
      coalesce(v_original_claims, ''),
      true
    );
    raise;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Exact search / bounded account list.
-- ---------------------------------------------------------------------------
create or replace function public.admin_search_users(
  p_search text default null,
  p_cursor text default null
)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_search text := nullif(lower(btrim(p_search)), '');
  v_search_uuid uuid := null;
  v_cursor_payload jsonb;
  v_cursor_created_at timestamptz := null;
  v_cursor_user_id uuid := null;
  v_items jsonb := '[]'::jsonb;
  v_count integer := 0;
  v_next_cursor text := null;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  if v_search is not null and
     v_search ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
  then
    v_search_uuid := v_search::uuid;
  end if;

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_user_id := (v_cursor_payload->>'userId')::uuid;
      if (v_cursor_payload->>'search') is distinct from v_search then
        raise exception using errcode = '22023', message = 'pagination cursor does not match search';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select
      u.id,
      u.email,
      u.is_anonymous,
      u.email_confirmed_at,
      u.phone_confirmed_at,
      u.banned_until,
      u.created_at,
      public.admin_resolve_subscription_state_for_user(v_caller, u.id) as state
    from auth.users as u
    where u.deleted_at is null
      and (
        v_search is null
        or (v_search_uuid is not null and u.id = v_search_uuid)
        or (v_search_uuid is null and u.email = v_search)
      )
      and (
        v_cursor_created_at is null
        or (u.created_at, u.id) < (v_cursor_created_at, v_cursor_user_id)
      )
    order by u.created_at desc, u.id desc
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
          'userId', p.id,
          'email', p.email,
          'accountCreatedAt', p.created_at,
          'accountStatus', case
            when p.is_anonymous then 'anonymous'
            when p.banned_until is not null and p.banned_until > v_now then 'banned'
            when p.email_confirmed_at is null and p.phone_confirmed_at is null then 'unconfirmed'
            else 'active'
          end,
          'currentPlanCode', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'planCode'
            else null
          end,
          'currentPlanDisplayName', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'planDisplayName'
            else null
          end,
          'entitlementStatus', case
            when p.state->>'denialReason' in ('SALON_PILOT_EXPIRED', 'ENTITLEMENT_EXPIRED')
              and p.state->>'entitlementStatus' in ('active', 'grace_period')
              then 'expired'
            else p.state->>'entitlementStatus'
          end,
          'remainingAiLooks', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then (p.state->>'remainingAiLooks')::integer
            else null
          end,
          'allowanceUnit', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->>'allowanceUnit'
            else null
          end,
          'periodEnd', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->'periodEnd'
            else null
          end,
          'expiresAt', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then p.state->'expiresAt'
            else null
          end,
          'autoRenew', case
            when coalesce((p.state->>'hasEntitlement')::boolean, false)
              then (p.state->>'autoRenew')::boolean
            else null
          end
        )
        order by p.created_at desc, p.id desc
      ),
      '[]'::jsonb
    ),
    (select count(*) from candidates)
  into v_items, v_count
  from page as p;

  if v_count > 25 then
    select encode(
      convert_to(
        jsonb_build_object(
          'createdAt', p.created_at,
          'userId', p.id,
          'search', v_search
        )::text,
        'utf8'
      ),
      'base64'
    )
    into v_next_cursor
    from (
      select u.id, u.created_at
      from auth.users as u
      where u.deleted_at is null
        and (
          v_search is null
          or (v_search_uuid is not null and u.id = v_search_uuid)
          or (v_search_uuid is null and u.email = v_search)
        )
        and (
          v_cursor_created_at is null
          or (u.created_at, u.id) < (v_cursor_created_at, v_cursor_user_id)
        )
      order by u.created_at desc, u.id desc
      offset 24 limit 1
    ) as p;
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'accountCreatedAt', 'direction', 'desc'),
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. One sanitized account + authoritative subscription detail.
-- ---------------------------------------------------------------------------
create or replace function public.admin_get_user(p_user_id uuid)
returns jsonb
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_user auth.users%rowtype;
  v_state jsonb;
  v_ent public.user_entitlements%rowtype;
  v_entitlement jsonb := null;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  select * into v_user
  from auth.users as u
  where u.id = p_user_id and u.deleted_at is null;

  if not found then
    return jsonb_build_object('ok', false, 'errorCode', 'USER_NOT_FOUND');
  end if;

  v_state := public.admin_resolve_subscription_state_for_user(v_caller, v_user.id);
  if coalesce((v_state->>'hasEntitlement')::boolean, false) then
    select * into v_ent
    from public.user_entitlements as e
    where e.id = (v_state->>'entitlementId')::uuid
      and e.user_id = v_user.id;

    if found then
      v_entitlement := jsonb_build_object(
        'entitlementId', v_ent.id,
        'planCode', v_state->>'planCode',
        'planDisplayName', v_state->>'planDisplayName',
        'storedStatus', v_state->>'entitlementStatus',
        'effectiveStatus', case
          when v_state->>'denialReason' in ('SALON_PILOT_EXPIRED', 'ENTITLEMENT_EXPIRED')
            and v_state->>'entitlementStatus' in ('active', 'grace_period')
            then 'expired'
          else v_state->>'entitlementStatus'
        end,
        'billingProvider', v_state->>'billingProvider',
        'allowanceUnit', v_state->>'allowanceUnit',
        'effectiveAllowance', (v_state->>'effectiveAllowance')::integer,
        'committedUsage', (v_state->>'committedUsage')::integer,
        'reservedUsage', (v_state->>'reservedUsage')::integer,
        'availableAiLooks', (v_state->>'availableAiLooks')::integer,
        'remainingAiLooks', (v_state->>'remainingAiLooks')::integer,
        'periodStart', v_state->'periodStart',
        'periodEnd', v_state->'periodEnd',
        'startsAt', v_state->'startsAt',
        'expiresAt', v_state->'expiresAt',
        'autoRenew', (v_state->>'autoRenew')::boolean,
        'version', v_ent.version,
        'createdAt', v_ent.created_at,
        'updatedAt', v_ent.updated_at
      );
    end if;
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'user', jsonb_build_object(
      'userId', v_user.id,
      'email', v_user.email,
      'accountCreatedAt', v_user.created_at,
      'accountStatus', case
        when v_user.is_anonymous then 'anonymous'
        when v_user.banned_until is not null and v_user.banned_until > v_now then 'banned'
        when v_user.email_confirmed_at is null and v_user.phone_confirmed_at is null then 'unconfirmed'
        else 'active'
      end
    ),
    'entitlement', v_entitlement
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Access: only the two roster-checking reads are client-callable.
-- ---------------------------------------------------------------------------
revoke all on function public.admin_resolve_subscription_state_for_user(uuid, uuid) from public;
revoke all on function public.admin_resolve_subscription_state_for_user(uuid, uuid) from anon;
revoke all on function public.admin_resolve_subscription_state_for_user(uuid, uuid) from authenticated;
revoke all on function public.admin_resolve_subscription_state_for_user(uuid, uuid) from service_role;

revoke all on function public.admin_search_users(text, text) from public;
revoke all on function public.admin_search_users(text, text) from anon;
revoke all on function public.admin_search_users(text, text) from service_role;
grant execute on function public.admin_search_users(text, text) to authenticated;

revoke all on function public.admin_get_user(uuid) from public;
revoke all on function public.admin_get_user(uuid) from anon;
revoke all on function public.admin_get_user(uuid) from service_role;
grant execute on function public.admin_get_user(uuid) to authenticated;
