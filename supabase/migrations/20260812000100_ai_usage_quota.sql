-- FaceTune Phase 16: server-enforced AI usage quotas.
--
-- Authenticated accounts previously had unlimited access to the Gemini-backed
-- Edge Functions. A single compromised or abusive session could therefore spend
-- unbounded upstream AI capacity. Usage is now recorded server-side and every
-- AI entry point must consume quota before calling Gemini.

create table if not exists public.ai_usage_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operation text not null,
  created_at timestamptz not null default timezone('utc', now()),
  constraint ai_usage_events_operation_valid
    check (
      operation in (
        'face_analysis',
        'makeup_recommendation',
        'makeup_preview'
      )
    )
);

create index if not exists ai_usage_events_user_operation_created_idx
  on public.ai_usage_events (user_id, operation, created_at desc);

alter table public.ai_usage_events enable row level security;

revoke all on table public.ai_usage_events from anon;
revoke all on table public.ai_usage_events from authenticated;

-- Callers may review their own usage but can never insert, edit, or clear it.
-- Only public.consume_ai_quota() writes here, so a client cannot reset a quota
-- or forge usage for another account.
grant select on table public.ai_usage_events to authenticated;

drop policy if exists "ai_usage_events_select_own" on public.ai_usage_events;
create policy "ai_usage_events_select_own"
on public.ai_usage_events for select
to authenticated
using ((select auth.uid()) = user_id);

-- Records one AI request for the calling user and reports whether it is within
-- quota. Limits live inside this function rather than in its arguments so a
-- caller invoking the RPC directly cannot raise its own ceiling; doing so can
-- only consume the caller's own quota.
create or replace function public.consume_ai_quota(p_operation text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_hourly_limit integer;
  v_daily_limit integer;
  v_hourly_used integer;
  v_daily_used integer;
begin
  if v_user is null then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'authentication_required',
      'retryAfterSeconds', 0
    );
  end if;

  select limits.hourly, limits.daily
    into v_hourly_limit, v_daily_limit
  from (
    values
      ('face_analysis', 20, 100),
      ('makeup_recommendation', 40, 200),
      ('makeup_preview', 30, 120)
  ) as limits(operation, hourly, daily)
  where limits.operation = p_operation;

  if v_hourly_limit is null then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'unsupported_operation',
      'retryAfterSeconds', 0
    );
  end if;

  select
    count(*) filter (
      where events.created_at > timezone('utc', now()) - interval '1 hour'
    ),
    count(*)
    into v_hourly_used, v_daily_used
  from public.ai_usage_events as events
  where events.user_id = v_user
    and events.operation = p_operation
    and events.created_at > timezone('utc', now()) - interval '1 day';

  if v_hourly_used >= v_hourly_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'hourly_quota_exceeded',
      'retryAfterSeconds', 900
    );
  end if;

  if v_daily_used >= v_daily_limit then
    return jsonb_build_object(
      'allowed', false,
      'reason', 'daily_quota_exceeded',
      'retryAfterSeconds', 3600
    );
  end if;

  insert into public.ai_usage_events (user_id, operation)
  values (v_user, p_operation);

  return jsonb_build_object(
    'allowed', true,
    'reason', 'allowed',
    'retryAfterSeconds', 0
  );
end;
$$;

revoke all on function public.consume_ai_quota(text) from public;
revoke all on function public.consume_ai_quota(text) from anon;
grant execute on function public.consume_ai_quota(text) to authenticated;

-- Usage rows are operational metadata only (account, operation, timestamp) and
-- are not needed once they fall outside the widest quota window. Schedule this
-- from the Supabase dashboard; it is not self-scheduling.
create or replace function public.purge_ai_usage_events(
  p_retain interval default interval '30 days'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted integer;
begin
  delete from public.ai_usage_events
  where created_at < timezone('utc', now()) - p_retain;
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

revoke all on function public.purge_ai_usage_events(interval) from public;
revoke all on function public.purge_ai_usage_events(interval) from anon;
revoke all on function public.purge_ai_usage_events(interval) from authenticated;
