-- CCP — Custom Color Palette usage accounting.
--
-- Adds the third mode to the AI Look ledger and engine. Every replaced function
-- is its existing definition with only the Custom Color Palette branch added:
-- Standard and My Makeup Kit behavior is unchanged, and existing rows satisfy the
-- new constraints because the new column is null on all of them.
--
-- Also the vocabulary-only Web Admin change: `admin_list_usage` counts the new
-- column when it reports a retained preview. It exposes that true/false value
-- only, never a palette, an image, or a preview id.

-- ---------------------------------------------------------------------------
-- 1. Ledger
-- ---------------------------------------------------------------------------
alter table public.usage_ledger
  add column canonical_custom_palette_preview_id uuid;

-- Deleting a history item must not refund an AI Look, so as with the two existing
-- references only this column is cleared and the committed row survives.
alter table public.usage_ledger
  add constraint usage_ledger_canonical_custom_palette_preview_owner_fk
  foreign key (canonical_custom_palette_preview_id, user_id)
  references public.custom_palette_generated_images(id, user_id)
  on delete set null (canonical_custom_palette_preview_id);

-- One canonical preview can be billed at most once.
create unique index usage_ledger_canonical_custom_palette_preview_idx
  on public.usage_ledger (canonical_custom_palette_preview_id);

alter table public.usage_ledger
  drop constraint usage_ledger_source_mode_valid;
alter table public.usage_ledger
  add constraint usage_ledger_source_mode_valid
  check (
    source_mode is null
    or source_mode in ('standard', 'makeup_kit', 'custom_color_palette')
  );

alter table public.usage_ledger
  drop constraint usage_ledger_released_has_no_preview;
alter table public.usage_ledger
  add constraint usage_ledger_released_has_no_preview
  check (
    status <> 'released'
    or (
      source_mode is null
      and canonical_generated_image_id is null
      and canonical_kit_generated_image_id is null
      and canonical_custom_palette_preview_id is null
    )
  );

alter table public.usage_ledger
  drop constraint usage_ledger_preview_lineage;
alter table public.usage_ledger
  add constraint usage_ledger_preview_lineage
  check (
    (
      source_mode is null
      and canonical_generated_image_id is null
      and canonical_kit_generated_image_id is null
      and canonical_custom_palette_preview_id is null
    )
    or (
      source_mode = 'standard'
      and canonical_kit_generated_image_id is null
      and canonical_custom_palette_preview_id is null
    )
    or (
      source_mode = 'makeup_kit'
      and canonical_generated_image_id is null
      and canonical_custom_palette_preview_id is null
    )
    or (
      source_mode = 'custom_color_palette'
      and canonical_generated_image_id is null
      and canonical_kit_generated_image_id is null
    )
  );

alter table public.ai_operation_metrics
  drop constraint ai_operation_metrics_source_mode_valid;
alter table public.ai_operation_metrics
  add constraint ai_operation_metrics_source_mode_valid
  check (
    source_mode is null
    or source_mode in ('standard', 'makeup_kit', 'custom_color_palette')
  );

-- ---------------------------------------------------------------------------
-- 2. Committed usage stays immutable
-- ---------------------------------------------------------------------------
create or replace function public.reject_committed_usage_mutation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status <> 'committed' then
    return new;
  end if;

  if new.status = old.status
    and new.user_id = old.user_id
    and new.entitlement_id = old.entitlement_id
    and new.operation_id = old.operation_id
    and new.usage_type = old.usage_type
    and new.source_mode is not distinct from old.source_mode
    and new.committed_at = old.committed_at
    and new.reserved_at = old.reserved_at
    and new.released_at is not distinct from old.released_at
    and new.period_start is not distinct from old.period_start
    and new.period_end is not distinct from old.period_end
    and new.sanitized_failure_code is not distinct from
        old.sanitized_failure_code
    and (
      new.canonical_generated_image_id
        is not distinct from old.canonical_generated_image_id
      or (
        old.canonical_generated_image_id is not null
        and new.canonical_generated_image_id is null
      )
    )
    and (
      new.canonical_kit_generated_image_id
        is not distinct from old.canonical_kit_generated_image_id
      or (
        old.canonical_kit_generated_image_id is not null
        and new.canonical_kit_generated_image_id is null
      )
    )
    and (
      new.canonical_custom_palette_preview_id
        is not distinct from old.canonical_custom_palette_preview_id
      or (
        old.canonical_custom_palette_preview_id is not null
        and new.canonical_custom_palette_preview_id is null
      )
    )
  then
    return new;
  end if;

  raise exception
    'committed usage_ledger rows are immutable historical records';
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Commit
-- ---------------------------------------------------------------------------
create or replace function public.commit_ai_look(
  p_operation_id uuid,
  p_source_mode text,
  p_canonical_preview_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_row public.usage_ledger%rowtype;
  v_owned boolean;
  v_current_preview uuid;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  if p_source_mode is null
    or p_source_mode not in ('standard', 'makeup_kit', 'custom_color_palette')
  then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  if p_canonical_preview_id is null then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  select * into v_row
  from public.usage_ledger
  where operation_id = p_operation_id
  for update;

  if not found or v_row.user_id <> v_user then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_OPERATION_NOT_FOUND',
      'operationId', p_operation_id
    );
  end if;

  -- The preview must belong to the caller. Checked against the owning table so
  -- a valid-looking uuid from another account is refused with a sanitized
  -- code rather than surfacing a raw foreign-key error.
  if p_source_mode = 'standard' then
    select exists (
      select 1 from public.generated_images as g
      where g.id = p_canonical_preview_id and g.user_id = v_user
    ) into v_owned;
  elsif p_source_mode = 'makeup_kit' then
    select exists (
      select 1 from public.kit_generated_images as k
      where k.id = p_canonical_preview_id and k.user_id = v_user
    ) into v_owned;
  else
    select exists (
      select 1 from public.custom_palette_generated_images as c
      where c.id = p_canonical_preview_id and c.user_id = v_user
    ) into v_owned;
  end if;

  if not v_owned then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
  end if;

  if v_row.status = 'committed' then
    v_current_preview := coalesce(
      v_row.canonical_generated_image_id,
      v_row.canonical_kit_generated_image_id,
      v_row.canonical_custom_palette_preview_id
    );
    -- Idempotent replay: the same operation committing the same preview again.
    -- Also treated as a replay when the preview reference has since been
    -- cleared by a history deletion — the charge stands either way.
    if v_current_preview is null or v_current_preview = p_canonical_preview_id
    then
      return jsonb_build_object(
        'ok', true, 'replayed', true, 'operationId', p_operation_id,
        'status', 'committed'
      );
    end if;
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_ALREADY_COMMITTED',
      'operationId', p_operation_id, 'status', 'committed'
    );
  end if;

  -- A released operation that turns out to have produced a usable persisted
  -- preview is corrected to committed rather than left unpaid.
  --
  -- This is deliberate and it closes a real hole. `release_ai_look` has to be
  -- callable by the same authenticated identity the generation path runs as,
  -- so a client could otherwise release its own in-flight reservation, let the
  -- Edge Function finish generating, and keep a persisted preview that was
  -- never charged. The hard lock cuts both ways: no usable persisted preview
  -- means no charge, and a usable persisted preview means exactly one charge.
  -- Evidence that the work succeeded outranks a premature release.
  --
  -- The opposite transition is never allowed: `committed` is terminal, above
  -- and in the SUB-2 immutability trigger.
  update public.usage_ledger
  set status = 'committed',
      source_mode = p_source_mode,
      canonical_generated_image_id = case
        when p_source_mode = 'standard' then p_canonical_preview_id else null
      end,
      canonical_kit_generated_image_id = case
        when p_source_mode = 'makeup_kit' then p_canonical_preview_id else null
      end,
      canonical_custom_palette_preview_id = case
        when p_source_mode = 'custom_color_palette'
          then p_canonical_preview_id
        else null
      end,
      committed_at = greatest(v_now, v_row.reserved_at),
      released_at = null,
      sanitized_failure_code = null
  where id = v_row.id;

  return jsonb_build_object(
    'ok', true,
    'replayed', false,
    'operationId', p_operation_id,
    'status', 'committed',
    'correctedFromReleased', v_row.status = 'released'
  );
exception
  when unique_violation then
    -- The one-charge-per-preview indexes rejected this: some other operation
    -- has already been billed for this canonical preview.
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_STATE_CONFLICT',
      'operationId', p_operation_id
    );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Release
-- ---------------------------------------------------------------------------
create or replace function public.release_ai_look(
  p_operation_id uuid,
  p_failure_code text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_now timestamptz := timezone('utc', now());
  v_row public.usage_ledger%rowtype;
  v_code text;
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'errorCode', 'AUTH_REQUIRED');
  end if;

  -- Sanitized and bounded. A provider payload, stack trace, storage path, or
  -- SQL error must never reach this column, so anything unusable is dropped
  -- rather than stored.
  v_code := nullif(btrim(coalesce(p_failure_code, '')), '');
  if v_code is not null and char_length(v_code) > 64 then
    v_code := left(v_code, 64);
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));

  select * into v_row
  from public.usage_ledger
  where operation_id = p_operation_id
  for update;

  if not found or v_row.user_id <> v_user then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_OPERATION_NOT_FOUND',
      'operationId', p_operation_id
    );
  end if;

  if v_row.status = 'committed' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'USAGE_ALREADY_COMMITTED',
      'operationId', p_operation_id, 'status', 'committed'
    );
  end if;

  if v_row.status = 'released' then
    return jsonb_build_object(
      'ok', true, 'replayed', true, 'operationId', p_operation_id,
      'status', 'released'
    );
  end if;

  update public.usage_ledger
  set status = 'released',
      released_at = greatest(v_now, v_row.reserved_at),
      committed_at = null,
      source_mode = null,
      canonical_generated_image_id = null,
      canonical_kit_generated_image_id = null,
      canonical_custom_palette_preview_id = null,
      sanitized_failure_code = v_code
  where id = v_row.id;

  return jsonb_build_object(
    'ok', true, 'replayed', false, 'operationId', p_operation_id,
    'status', 'released'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Reconciliation
-- ---------------------------------------------------------------------------
create or replace function public.reconcile_stale_ai_look_reservations(
  p_older_than interval default interval '30 minutes'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_cutoff timestamptz := timezone('utc', now()) - greatest(
    p_older_than, interval '10 minutes'
  );
  v_row public.usage_ledger%rowtype;
  v_preview uuid;
  v_mode text;
  v_candidates integer;
  v_committed integer := 0;
  v_released integer := 0;
  v_skipped integer := 0;
begin
  for v_row in
    select * from public.usage_ledger
    where status = 'reserved' and reserved_at < v_cutoff
    order by reserved_at
    for update skip locked
  loop
    -- A Custom Color Palette preview names its operation, so it needs no
    -- inference: the evidence is exact, and it is checked before anything else.
    v_preview := null;
    select c.id into v_preview
    from public.custom_palette_generated_images as c
    where c.operation_id = v_row.operation_id
      and c.user_id = v_row.user_id;
    if v_preview is not null then
      update public.usage_ledger
      set status = 'committed',
          source_mode = 'custom_color_palette',
          canonical_custom_palette_preview_id = v_preview,
          committed_at = greatest(timezone('utc', now()), v_row.reserved_at),
          released_at = null
      where id = v_row.id;
      v_committed := v_committed + 1;
      continue;
    end if;
    -- Attempts with no accepted preview mean this reservation produced nothing.
    -- It must not fall through and be matched to an unrelated preview below.
    if exists (
      select 1 from public.custom_palette_preview_attempts as a
      where a.operation_id = v_row.operation_id
    ) then
      update public.usage_ledger
      set status = 'released',
          released_at = greatest(timezone('utc', now()), v_row.reserved_at),
          committed_at = null,
          sanitized_failure_code = 'stale_reservation_reconciled'
      where id = v_row.id;
      v_released := v_released + 1;
      continue;
    end if;

    -- Unclaimed Standard previews this account produced after the reservation.
    -- Counted and selected separately because there is no `min(uuid)`, and
    -- because the id is only wanted when there is exactly one candidate.
    v_mode := 'standard';
    v_preview := null;

    select count(*) into v_candidates
    from public.generated_images as g
    where g.user_id = v_row.user_id
      and g.created_at >= v_row.reserved_at
      and not exists (
        select 1 from public.usage_ledger as l
        where l.canonical_generated_image_id = g.id
      );

    if v_candidates = 0 then
      v_mode := 'makeup_kit';
      select count(*) into v_candidates
      from public.kit_generated_images as k
      where k.user_id = v_row.user_id
        and k.created_at >= v_row.reserved_at
        and not exists (
          select 1 from public.usage_ledger as l
          where l.canonical_kit_generated_image_id = k.id
        );
    end if;

    if v_candidates = 1 then
      if v_mode = 'standard' then
        select g.id into v_preview
        from public.generated_images as g
        where g.user_id = v_row.user_id
          and g.created_at >= v_row.reserved_at
          and not exists (
            select 1 from public.usage_ledger as l
            where l.canonical_generated_image_id = g.id
          )
        limit 1;
      else
        select k.id into v_preview
        from public.kit_generated_images as k
        where k.user_id = v_row.user_id
          and k.created_at >= v_row.reserved_at
          and not exists (
            select 1 from public.usage_ledger as l
            where l.canonical_kit_generated_image_id = k.id
          )
        limit 1;
      end if;
    end if;

    if v_candidates = 1 then
      update public.usage_ledger
      set status = 'committed',
          source_mode = v_mode,
          canonical_generated_image_id = case
            when v_mode = 'standard' then v_preview else null
          end,
          canonical_kit_generated_image_id = case
            when v_mode = 'makeup_kit' then v_preview else null
          end,
          committed_at = greatest(timezone('utc', now()), v_row.reserved_at),
          released_at = null
      where id = v_row.id;
      v_committed := v_committed + 1;
    elsif v_candidates = 0 then
      update public.usage_ledger
      set status = 'released',
          released_at = greatest(timezone('utc', now()), v_row.reserved_at),
          committed_at = null,
          sanitized_failure_code = 'stale_reservation_reconciled'
      where id = v_row.id;
      v_released := v_released + 1;
    else
      v_skipped := v_skipped + 1;
    end if;
  end loop;

  return jsonb_build_object(
    'committed', v_committed,
    'released', v_released,
    'skippedAmbiguous', v_skipped
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Web Admin: usage list
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
                or l.canonical_kit_generated_image_id is not null
                or l.canonical_custom_palette_preview_id is not null)
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
