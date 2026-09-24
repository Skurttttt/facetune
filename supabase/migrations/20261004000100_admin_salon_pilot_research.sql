-- FaceTune WA-13: Salon Pilot research metrics.
--
-- Read-only and additive. Two roster-checked `security definer` reads on the
-- WA-4 / WA-6 pattern. No table, column, constraint, policy, grant, trigger,
-- or existing function is altered, and nothing here writes.
--
-- ## What is measured, and from where
--
-- Allowance and usage truth comes from `user_entitlements` and `usage_ledger`
-- (the same arithmetic the consumer resolver uses, per row). Operation and
-- billable-usage figures come from `ai_operation_metrics` (SUB-13), the
-- privacy-safe technical telemetry, filtered to rows the writer stamped with
-- `plan_code = 'salon_pilot'`. That table holds counts, categories, token
-- counts, image counts, latencies and attempt counts — and, deliberately, no
-- content, path, prompt, URL, receipt, or free text (SUB-13). Nothing here
-- reads `analyses`, `generated_images`, `kit_*`, tutorial content, or
-- provider payload tables.
--
-- ## The cost rule (Web Admin SOT §38–§39; phase WA-13)
--
-- No monetary cost or price is recorded anywhere in the system: the
-- telemetry tracks provider usage in tokens, images and attempts, not money,
-- and no provider price list or FX rate exists in the schema. Therefore:
--
--   * "AI/API billable usage" is reported in the units actually tracked;
--   * "effective cost per delivered AI Look" is reported as NOT AVAILABLE with
--     a stable reason (`NO_PROVIDER_COST_DATA`) and null figures;
--   * the per-look cost planning assumption from the Subscription SOT appears nowhere
--     in this migration or in the admin code — it is a planning figure the
--     research is meant to validate, not a runtime fact.
--
-- ## Privacy
--
-- Per-pilot rows carry the account email (Shared Contract §65, display) and
-- ids; no product names, prompts, images, kit contents, tutorial content, or
-- provider identifiers are read or returned. Telemetry is attributed by
-- (user, plan) because that is how the writer records it; a per-pilot row
-- therefore shows the account's Salon Pilot telemetry, which is exact while
-- an account holds one pilot at a time (the one-current rule).

-- ---------------------------------------------------------------------------
-- 1. Aggregate research metrics
-- ---------------------------------------------------------------------------
create or replace function public.admin_salon_pilot_research_metrics()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_caller uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_pilots jsonb;
  v_ai_looks jsonb;
  v_operations jsonb;
  v_usage jsonb;
begin
  if v_caller is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;
  if not public.is_admin(v_caller) then
    return jsonb_build_object('ok', false, 'errorCode', 'ADMIN_UNAUTHORIZED');
  end if;

  -- Pilot entitlements by effective state. "In force" is the resolver's
  -- rank-0 predicate for a pilot: active / grace / suspended and not lapsed.
  select jsonb_build_object(
    'users', count(distinct e.user_id),
    'entitlements', count(*),
    'inForce', count(*) filter (
      where e.status in ('active', 'grace_period')
        and e.starts_at <= v_now
        and (e.expires_at is null or e.expires_at > v_now)),
    'suspended', count(*) filter (
      where e.status = 'suspended'
        and (e.expires_at is null or e.expires_at > v_now)),
    'lapsedOrExpired', count(*) filter (
      where e.status = 'expired'
        or (e.status in ('active', 'grace_period', 'suspended')
            and e.expires_at is not null and e.expires_at <= v_now)),
    'revoked', count(*) filter (where e.status = 'revoked'),
    'expiringWithin14Days', count(*) filter (
      where e.status in ('active', 'grace_period')
        and e.expires_at > v_now
        and e.expires_at <= v_now + interval '14 days')
  )
  into v_pilots
  from public.user_entitlements as e
  where e.plan_code = 'salon_pilot';

  -- AI Look pool and ledger truth across every pilot entitlement (all time;
  -- admin grants have no billing period).
  select jsonb_build_object(
    'grantedBase', coalesce(sum(e.base_ai_look_allowance), 0),
    'adminAdjustmentsTotal', coalesce(sum(e.allowance_adjustment_total), 0),
    'effectiveAllowance', coalesce(sum(greatest(0, e.base_ai_look_allowance + e.allowance_adjustment_total)), 0),
    'committed', coalesce(sum(l.committed), 0),
    'reserved', coalesce(sum(l.reserved), 0),
    'released', coalesce(sum(l.released), 0),
    'remaining', coalesce(sum(greatest(0,
      greatest(0, e.base_ai_look_allowance + e.allowance_adjustment_total) - l.committed)), 0)
  )
  into v_ai_looks
  from public.user_entitlements as e
  left join lateral (
    select
      count(*) filter (where u.status = 'committed') as committed,
      count(*) filter (where u.status = 'reserved') as reserved,
      count(*) filter (where u.status = 'released') as released
    from public.usage_ledger as u
    where u.entitlement_id = e.id
  ) as l on true
  where e.plan_code = 'salon_pilot';

  -- Technical operations from telemetry, by kind and outcome.
  select jsonb_build_object(
    'finalPreview', jsonb_build_object(
      'succeeded', count(*) filter (where m.operation_kind = 'final_preview' and m.outcome = 'succeeded'),
      'failed', count(*) filter (where m.operation_kind = 'final_preview' and m.outcome = 'failed'),
      'denied', count(*) filter (where m.operation_kind = 'final_preview' and m.outcome = 'denied'),
      'duplicate', count(*) filter (where m.operation_kind = 'final_preview' and m.outcome = 'duplicate')),
    'tutorialManifest', jsonb_build_object(
      'succeeded', count(*) filter (where m.operation_kind = 'tutorial_manifest' and m.outcome = 'succeeded'),
      'failed', count(*) filter (where m.operation_kind = 'tutorial_manifest' and m.outcome = 'failed'),
      'denied', count(*) filter (where m.operation_kind = 'tutorial_manifest' and m.outcome = 'denied'),
      'duplicate', count(*) filter (where m.operation_kind = 'tutorial_manifest' and m.outcome = 'duplicate')),
    'tutorialStep', jsonb_build_object(
      'succeeded', count(*) filter (where m.operation_kind = 'tutorial_step' and m.outcome = 'succeeded'),
      'failed', count(*) filter (where m.operation_kind = 'tutorial_step' and m.outcome = 'failed'),
      'denied', count(*) filter (where m.operation_kind = 'tutorial_step' and m.outcome = 'denied'),
      'duplicate', count(*) filter (where m.operation_kind = 'tutorial_step' and m.outcome = 'duplicate')),
    'telemetryEvents', count(*)
  )
  into v_operations
  from public.ai_operation_metrics as m
  where m.plan_code = 'salon_pilot';

  -- Billable usage in the units the provider actually meters. Token fields
  -- are null on events that carried no usage metadata; those events are
  -- counted separately so a total is never mistaken for complete.
  select jsonb_build_object(
    'providerAttempts', coalesce(sum(m.provider_attempt_count), 0),
    'inputTokens', coalesce(sum(m.input_tokens), 0),
    'outputTokens', coalesce(sum(m.output_tokens), 0),
    'totalTokens', coalesce(sum(m.total_tokens), 0),
    'cachedTokens', coalesce(sum(m.cached_tokens), 0),
    'thoughtsTokens', coalesce(sum(m.thoughts_tokens), 0),
    'inputImageTokens', coalesce(sum(m.input_image_tokens), 0),
    'outputImageTokens', coalesce(sum(m.output_image_tokens), 0),
    'outputImages', coalesce(sum(m.output_images), 0),
    'eventsWithTokenData', count(*) filter (where m.total_tokens is not null),
    'eventsWithoutTokenData', count(*) filter (where m.total_tokens is null)
  )
  into v_usage
  from public.ai_operation_metrics as m
  where m.plan_code = 'salon_pilot'
    and m.operation_kind in ('final_preview', 'tutorial_manifest', 'tutorial_step');

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'asOf', v_now,
    'pilots', v_pilots,
    'aiLooks', v_ai_looks,
    'operations', v_operations,
    'billableUsage', v_usage,
    -- No provider price, invoice, or FX data exists in the system. The
    -- figures are null on purpose; the client shows "Not available".
    'cost', jsonb_build_object(
      'available', false,
      'reason', 'NO_PROVIDER_COST_DATA',
      'currency', null,
      'totalBillableCost', null,
      'effectiveCostPerDeliveredAiLook', null
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Per-pilot metrics: newest grant first, fixed pages of 25
-- ---------------------------------------------------------------------------
create or replace function public.admin_list_salon_pilot_metrics(
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

  if p_cursor is not null then
    begin
      v_cursor_payload := convert_from(decode(p_cursor, 'base64'), 'utf8')::jsonb;
      v_cursor_created_at := (v_cursor_payload->>'createdAt')::timestamptz;
      v_cursor_id := (v_cursor_payload->>'id')::uuid;
      if (v_cursor_payload->>'scope') is distinct from 'salon_pilot' then
        raise exception 'cursor scope mismatch';
      end if;
    exception
      when others then
        raise exception using errcode = '22023', message = 'invalid pagination cursor';
    end;
  end if;

  with candidates as materialized (
    select e.*
    from public.user_entitlements as e
    where e.plan_code = 'salon_pilot'
      and (
        v_cursor_created_at is null
        or (e.created_at, e.id) < (v_cursor_created_at, v_cursor_id)
      )
    order by e.created_at desc, e.id desc
    limit 26
  ), page as materialized (
    select * from candidates order by created_at desc, id desc limit 25
  ), figures as materialized (
    select
      p.*,
      u.email,
      greatest(0, p.base_ai_look_allowance + p.allowance_adjustment_total) as effective_allowance,
      coalesce(l.committed, 0) as committed,
      coalesce(l.reserved, 0) as reserved,
      coalesce(l.released, 0) as released,
      l.last_activity_at,
      coalesce(t.final_preview_failed, 0) as final_preview_failed,
      coalesce(t.tutorial_succeeded, 0) as tutorial_succeeded,
      coalesce(t.tutorial_failed, 0) as tutorial_failed,
      coalesce(t.provider_attempts, 0) as provider_attempts,
      coalesce(t.total_tokens, 0) as total_tokens,
      coalesce(t.output_images, 0) as output_images
    from page as p
    left join auth.users as u on u.id = p.user_id
    left join lateral (
      select
        count(*) filter (where x.status = 'committed') as committed,
        count(*) filter (where x.status = 'reserved') as reserved,
        count(*) filter (where x.status = 'released') as released,
        max(x.updated_at) as last_activity_at
      from public.usage_ledger as x
      where x.entitlement_id = p.id
    ) as l on true
    left join lateral (
      select
        count(*) filter (where m.operation_kind = 'final_preview' and m.outcome = 'failed') as final_preview_failed,
        count(*) filter (where m.operation_kind in ('tutorial_manifest', 'tutorial_step') and m.outcome = 'succeeded') as tutorial_succeeded,
        count(*) filter (where m.operation_kind in ('tutorial_manifest', 'tutorial_step') and m.outcome = 'failed') as tutorial_failed,
        coalesce(sum(m.provider_attempt_count), 0) as provider_attempts,
        coalesce(sum(m.total_tokens), 0) as total_tokens,
        coalesce(sum(m.output_images), 0) as output_images
      from public.ai_operation_metrics as m
      where m.user_id = p.user_id
        and m.plan_code = 'salon_pilot'
        and m.created_at >= p.created_at
    ) as t on true
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'entitlementId', f.id,
          'userId', f.user_id,
          'email', f.email,
          'storedStatus', f.status,
          'effectiveStatus', case
            when f.status in ('active', 'grace_period')
              and f.expires_at is not null and f.expires_at <= v_now
              then 'expired'
            else f.status
          end,
          'initialAllowance', f.base_ai_look_allowance,
          'adminAdjustmentsTotal', f.allowance_adjustment_total,
          'effectiveAllowance', f.effective_allowance,
          'committed', f.committed,
          'reserved', f.reserved,
          'remaining', greatest(0, f.effective_allowance - f.committed),
          'available', greatest(0, f.effective_allowance - f.committed - f.reserved),
          'deliveredFinalPreviews', f.committed,
          'releasedOperations', f.released,
          'finalPreviewFailures', f.final_preview_failed,
          'tutorialOperations', f.tutorial_succeeded,
          'tutorialFailures', f.tutorial_failed,
          'providerAttempts', f.provider_attempts,
          'totalTokens', f.total_tokens,
          'outputImages', f.output_images,
          'startsAt', f.starts_at,
          'expiresAt', f.expires_at,
          'lastActivityAt', f.last_activity_at,
          'createdAt', f.created_at
        )
        order by f.created_at desc, f.id desc
      ),
      '[]'::jsonb
    ),
    (select count(*) from candidates),
    (
      select jsonb_build_object('createdAt', p2.created_at, 'id', p2.id)
      from page as p2 order by p2.created_at asc, p2.id asc limit 1
    )
  into v_items, v_count, v_last
  from figures as f;

  if v_count > 25 then
    v_next_cursor := encode(
      convert_to((v_last || jsonb_build_object('scope', 'salon_pilot'))::text, 'utf8'),
      'base64'
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'contractVersion', 'subscription_admin_contract_v1.1',
    'pageSize', 25,
    'sort', jsonb_build_object('field', 'createdAt', 'direction', 'desc'),
    'items', v_items,
    'nextCursor', v_next_cursor
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Access
-- ---------------------------------------------------------------------------
revoke all on function public.admin_salon_pilot_research_metrics() from public;
revoke all on function public.admin_salon_pilot_research_metrics() from anon;
revoke all on function public.admin_salon_pilot_research_metrics() from service_role;
grant execute on function public.admin_salon_pilot_research_metrics() to authenticated;

revoke all on function public.admin_list_salon_pilot_metrics(text) from public;
revoke all on function public.admin_list_salon_pilot_metrics(text) from anon;
revoke all on function public.admin_list_salon_pilot_metrics(text) from service_role;
grant execute on function public.admin_list_salon_pilot_metrics(text) to authenticated;
