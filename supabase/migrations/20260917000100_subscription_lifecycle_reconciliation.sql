-- FaceTune SUB-11: subscription lifecycle reconciliation from verified
-- provider state.
--
-- Purely additive. No table, column, constraint, policy, grant, or function
-- from a prior migration is altered or dropped. In particular
-- `activate_verified_google_play_subscription` (SUB-10) is left exactly as it
-- was written, because it is already the lifecycle writer this phase needs:
-- it maps every `SubscriptionState` Google defines onto an entitlement status,
-- advances the billing period, retires a superseded entitlement, and is
-- idempotent on the purchase reference. Reconciliation reuses it rather than
-- adding a second way to write an entitlement.
--
-- What this migration adds is the machinery around that call:
--
--   * a record of provider notifications, whose unique `message_id` is what
--     makes a redelivered notification a no-op;
--   * the owner lookup that turns a purchase reference back into the account
--     that bought it, since a notification carries no user identity;
--   * revocation, which is the one lifecycle outcome the provider's
--     `SubscriptionState` cannot express.
--
-- Deliberately NOT done here:
--
--   * No background sweep that expires entitlements on a timer. There is
--     nothing to sweep: `resolve_subscription_state` (SUB-3) already refuses
--     generation once `period_end` has passed, so a lapsed subscription is
--     never authorized while the status lags. A clock-driven job that wrote
--     entitlement state would be exactly the local guess this architecture
--     refuses — the status moves when the provider says it moved.
--
--   * No trust in a notification's `notificationType`. Nothing in this file
--     reads one. The type decides which verified read to perform; the read
--     decides what is written. See `google-play-rtdn/index.ts`.
--
--   * No rollover, no allowance arithmetic, and no second capacity
--     calculator. A renewed period resets capacity purely by moving
--     `period_start`, which SUB-3 counts usage from.
--
--   * No storage of a raw purchase token. Notifications carry one; only its
--     SHA-256 reaches this schema, exactly as in SUB-10.
--
-- ---------------------------------------------------------------------------
-- The period-transition rule
-- ---------------------------------------------------------------------------
--
-- This phase is the first thing that moves a billing period on a live
-- account, so the rule for work already in flight when it moves belongs here,
-- stated rather than left to be inferred:
--
--     An AI Look belongs to the period it was RESERVED in.
--
-- A renewal advances `period_start`. SUB-3 decides period membership by
-- `usage_ledger.reserved_at`, so a reservation opened before the renewal stays
-- attached to the period that authorized it, and commits there even if the
-- generation finishes minutes after the new period began.
--
-- The consequences, all of them intended:
--
--   * The new period starts at its full allowance. An in-flight look does not
--     eat into it, because capacity for that look was already taken from the
--     period that authorized it.
--   * Nothing is charged twice. A ledger row is counted in exactly one period,
--     because membership is one comparison against one timestamp.
--   * Nothing is lost or refunded. A reservation that is released after the
--     transition simply never counted anywhere, which is what a released
--     reservation means in any period.
--   * No row is rewritten to make this true. The previous period's usage stays
--     exactly as it was recorded, which is what "prior period usage remains
--     historical" requires.
--
-- The alternative — reassigning an open reservation to the new period — was
-- rejected. It would charge the user's fresh allowance for work their previous
-- allowance had already authorized, and it would mean rewriting ledger history
-- during a renewal, which is the one thing the ledger is built never to do.

-- ---------------------------------------------------------------------------
-- 1. Provider notification events
-- ---------------------------------------------------------------------------
--
-- One row per notification the provider delivered, keyed by the transport's
-- own message id.
--
-- ## Why the message id and not the purchase token
--
-- Pub/Sub guarantees at-least-once delivery, so the same notification arrives
-- more than once as a matter of course, and a redelivery must not re-run the
-- work. Deduplicating on the purchase reference instead would be wrong in the
-- opposite direction: a subscription legitimately produces many notifications
-- over its life — renewed, cancelled, expired — all carrying the same token.
-- The message id is the only value that distinguishes "the same event again"
-- from "another event about the same subscription".
create table if not exists public.provider_notification_events (
  id uuid primary key default gen_random_uuid(),
  billing_provider text not null default 'google_play',

  -- The transport's message identifier. The replay anchor.
  message_id text not null,

  -- Which notification block the payload carried. Recorded for audit, never
  -- used to decide an entitlement.
  notification_kind text not null,

  -- The provider's own numeric notification type, when the payload had one.
  -- Recorded verbatim. Nothing in this schema branches on it.
  notification_type integer,

  -- SHA-256 of the provider purchase token, lowercase hex. Never the token.
  purchase_reference text,

  -- The provider's `eventTimeMillis`, as a timestamp.
  event_time timestamptz,

  -- How processing ended. `processing` is the claim itself: a row in that
  -- state is work in flight, and it is either finalized or deleted by the
  -- caller that claimed it.
  outcome text not null default 'processing',

  -- Resolved during processing when the purchase was recognised. Null for a
  -- notification about a purchase this backend has never verified.
  user_id uuid references auth.users(id) on delete set null,
  entitlement_id uuid,

  received_at timestamptz not null default timezone('utc', now()),
  processed_at timestamptz,

  constraint provider_notification_events_message_unique
    unique (billing_provider, message_id),

  constraint provider_notification_events_provider_valid
    check (billing_provider in ('google_play', 'apple_app_store')),

  constraint provider_notification_events_kind_valid
    check (
      notification_kind in (
        'subscription',
        'voided_purchase',
        'one_time_product',
        'pending_refund_review',
        'test',
        'unknown'
      )
    ),

  -- The full vocabulary of outcomes, so an unexpected string cannot be
  -- written and later read as if it meant something.
  constraint provider_notification_events_outcome_valid
    check (
      outcome in (
        -- In flight.
        'processing',
        -- Verified with the provider and the entitlement now matches.
        'reconciled',
        -- Verified with the provider and the entitlement was revoked.
        'revoked',
        -- A purchase this backend has no record of. Nothing was written.
        'unmatched',
        -- The provider's answer conflicted with what we hold. Nothing was
        -- written, and it is not retried, because a retry produces the same
        -- conflict.
        'conflict',
        -- Not a notification this backend acts on: another package, a test
        -- ping, or a block this phase does not handle.
        'ignored'
      )
    ),

  constraint provider_notification_events_message_not_blank
    check (char_length(btrim(message_id)) > 0),

  -- Same shape rule as `provider_purchase_verifications`: a reference is a
  -- SHA-256 hex digest or it is absent.
  constraint provider_notification_events_reference_shape
    check (
      purchase_reference is null
      or purchase_reference ~ '^[0-9a-f]{64}$'
    ),

  constraint provider_notification_events_finished_has_time
    check (outcome = 'processing' or processed_at is not null)
);

create index if not exists provider_notification_events_reference_idx
  on public.provider_notification_events (purchase_reference);
create index if not exists provider_notification_events_user_idx
  on public.provider_notification_events (user_id);
create index if not exists provider_notification_events_received_idx
  on public.provider_notification_events (received_at desc);

-- ---------------------------------------------------------------------------
-- 2. Access
-- ---------------------------------------------------------------------------
--
-- Unlike `provider_purchase_verifications`, this table has no owner-facing
-- half at all. A user has no reason to read the provider's message ids, and
-- an operational audit log that clients can enumerate is a map of the billing
-- integration. RLS is enabled with no policy, so the table is reachable only
-- through the `security definer` functions below and by `service_role`.
alter table public.provider_notification_events enable row level security;

revoke all on table public.provider_notification_events from anon;
revoke all on table public.provider_notification_events from authenticated;

-- ---------------------------------------------------------------------------
-- 3. public.google_play_purchase_owner(text, text)
-- ---------------------------------------------------------------------------
--
-- Resolves the account a purchase belongs to.
--
-- A provider notification identifies a subscription and says nothing about who
-- owns it, because the provider has no idea what a FaceTune account is. The
-- binding exists only because a purchase was once verified against a signed-in
-- user, so this reads that binding back and never creates one: a notification
-- for a purchase nobody has verified resolves to null, and the caller records
-- it as unmatched rather than inventing an owner.
--
-- Resolution order mirrors the activation function. The purchase's own
-- reference wins; the reference it replaced is followed only if the first
-- finds nothing, which is what lets an upgrade's notification reach the
-- entitlement the upgrade superseded.
create or replace function public.google_play_purchase_owner(
  p_purchase_reference text,
  p_linked_purchase_reference text default null
)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select owner from (
    select e.user_id as owner, 0 as match_rank
      from public.user_entitlements as e
     where e.provider_subscription_reference = p_purchase_reference
    union all
    select v.user_id as owner, 1 as match_rank
      from public.provider_purchase_verifications as v
     where v.purchase_reference = p_purchase_reference
    union all
    select e.user_id as owner, 2 as match_rank
      from public.user_entitlements as e
     where p_linked_purchase_reference is not null
       and e.provider_subscription_reference = p_linked_purchase_reference
    union all
    select v.user_id as owner, 3 as match_rank
      from public.provider_purchase_verifications as v
     where p_linked_purchase_reference is not null
       and v.purchase_reference = p_linked_purchase_reference
  ) as candidates
  order by match_rank
  limit 1;
$$;

-- ---------------------------------------------------------------------------
-- 4. public.claim_google_play_notification(...)
-- ---------------------------------------------------------------------------
--
-- Claims a notification for processing, or reports that it is already spoken
-- for.
--
-- The insert itself is the lock: the unique constraint on
-- (billing_provider, message_id) means exactly one caller can create the row,
-- and `on conflict do nothing` turns the losers into a cheap, side-effect-free
-- "already handled". That matters for quota as much as for correctness —
-- Google asks that redeliveries not produce redundant API calls, and a claim
-- that fails here returns before any call to the provider is made.
--
-- A claim is not a completion. The caller must follow it with
-- `finalize_google_play_notification`, which either records the outcome or
-- releases the claim so a redelivery can retry. A row left in `processing`
-- therefore means the worker died mid-flight, and is visible as exactly that.
create or replace function public.claim_google_play_notification(
  p_message_id text,
  p_notification_kind text,
  p_notification_type integer default null,
  p_purchase_reference text default null,
  p_event_time timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid;
  v_existing public.provider_notification_events%rowtype;
begin
  if p_message_id is null or char_length(btrim(p_message_id)) = 0 then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_NOTIFICATION');
  end if;

  if p_purchase_reference is not null
     and p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_NOTIFICATION');
  end if;

  -- Checked here rather than left to the table constraint. A raised exception
  -- would reach the caller as a database error, which it would read as
  -- transient and retry — forever, because the value never becomes valid. A
  -- returned code is refused once and recorded.
  if p_notification_kind is null
     or p_notification_kind not in (
       'subscription',
       'voided_purchase',
       'one_time_product',
       'pending_refund_review',
       'test',
       'unknown'
     ) then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_NOTIFICATION');
  end if;

  insert into public.provider_notification_events (
    billing_provider,
    message_id,
    notification_kind,
    notification_type,
    purchase_reference,
    event_time,
    outcome
  )
  values (
    'google_play',
    btrim(p_message_id),
    p_notification_kind,
    p_notification_type,
    p_purchase_reference,
    p_event_time,
    'processing'
  )
  on conflict (billing_provider, message_id) do nothing
  returning id into v_id;

  if v_id is not null then
    return jsonb_build_object('ok', true, 'claimed', true, 'eventId', v_id);
  end if;

  select * into v_existing
  from public.provider_notification_events as e
  where e.billing_provider = 'google_play'
    and e.message_id = btrim(p_message_id);

  -- A claim nobody finished.
  --
  -- The claim and the completion are two statements, so a worker can die
  -- between them — an isolate evicted, a deploy mid-request. Left alone, that
  -- row would answer "already handled" to every redelivery and the event would
  -- be lost precisely when something had already gone wrong. After a grace
  -- period long enough that no live request could still be running, the claim
  -- is taken over instead.
  --
  -- Safe to re-run: the work behind it is idempotent end to end. The verified
  -- read is a read, and the activation is keyed on the purchase reference.
  if v_existing.outcome = 'processing'
     and v_existing.received_at < timezone('utc', now()) - interval '5 minutes'
  then
    update public.provider_notification_events as e
       set received_at = timezone('utc', now()),
           notification_kind = p_notification_kind,
           notification_type = coalesce(p_notification_type, e.notification_type),
           purchase_reference = coalesce(p_purchase_reference, e.purchase_reference),
           event_time = coalesce(p_event_time, e.event_time)
     where e.id = v_existing.id
       and e.outcome = 'processing';

    return jsonb_build_object(
      'ok', true,
      'claimed', true,
      'eventId', v_existing.id,
      'reclaimed', true
    );
  end if;

  return jsonb_build_object(
    'ok', true,
    'claimed', false,
    'eventId', v_existing.id,
    'previousOutcome', v_existing.outcome
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. public.finalize_google_play_notification(...)
-- ---------------------------------------------------------------------------
--
-- Closes a claim.
--
-- `p_outcome = 'retry'` deletes the row instead of writing an outcome, which
-- is the whole reason a claim and a completion are separate operations. A
-- transient failure — the provider unreachable, a database error — must leave
-- the notification eligible for redelivery, and a dedup row left behind would
-- instead make the retry a silent no-op and lose the event permanently.
--
-- Every other outcome is terminal by design, including `conflict` and
-- `unmatched`: both mean the notification was understood and deliberately not
-- acted on, and retrying either produces the same answer forever.
create or replace function public.finalize_google_play_notification(
  p_message_id text,
  p_outcome text,
  p_user_id uuid default null,
  p_entitlement_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
begin
  if p_message_id is null or char_length(btrim(p_message_id)) = 0 then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_NOTIFICATION');
  end if;

  if p_outcome = 'retry' then
    delete from public.provider_notification_events as e
     where e.billing_provider = 'google_play'
       and e.message_id = btrim(p_message_id)
       and e.outcome = 'processing';
    return jsonb_build_object('ok', true, 'released', true);
  end if;

  if p_outcome is null
     or p_outcome not in (
       'reconciled', 'revoked', 'unmatched', 'conflict', 'ignored'
     ) then
    return jsonb_build_object('ok', false, 'errorCode', 'INVALID_NOTIFICATION');
  end if;

  update public.provider_notification_events as e
     set outcome = p_outcome,
         user_id = coalesce(p_user_id, e.user_id),
         entitlement_id = coalesce(p_entitlement_id, e.entitlement_id),
         processed_at = v_now
   where e.billing_provider = 'google_play'
     and e.message_id = btrim(p_message_id);

  return jsonb_build_object('ok', true, 'released', false);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. public.revoke_google_play_subscription(...)
-- ---------------------------------------------------------------------------
--
-- Revokes the entitlement behind a purchase.
--
-- ## Why this cannot go through the activation function
--
-- Revocation is the one lifecycle outcome `SubscriptionState` does not
-- express. A refunded-and-revoked subscription reads back as
-- `SUBSCRIPTION_STATE_EXPIRED`, which is indistinguishable from a subscription
-- that simply ran its course — and the two are not the same thing to a user or
-- to support. The distinction comes from a second verified provider read (the
-- voided purchases record, or the revocation notification corroborated by the
-- subscription's own state), so it needs a writer of its own.
--
-- What it deliberately does not do: delete anything. Usage ledger rows, the
-- verification record, History, Saved Looks and Tutorials all survive a
-- revocation untouched. Revocation ends the right to generate; it does not
-- reach back and erase what was already made, and the Source of Truth is
-- explicit that historical content is not held hostage.
create or replace function public.revoke_google_play_subscription(
  p_purchase_reference text,
  p_provider_state text default null,
  p_revoked_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_now timestamptz := timezone('utc', now());
  v_entitlement public.user_entitlements%rowtype;
begin
  if p_purchase_reference is null
     or p_purchase_reference !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object(
      'ok', false, 'errorCode', 'PURCHASE_VERIFICATION_FAILED'
    );
  end if;

  select * into v_entitlement
  from public.user_entitlements as e
  where e.provider_subscription_reference = p_purchase_reference;

  if not found then
    -- Nothing to revoke. Reported rather than raised: a revocation for a
    -- purchase this backend never granted is a legitimate thing to be told,
    -- and the caller records it as unmatched.
    return jsonb_build_object(
      'ok', false, 'errorCode', 'ENTITLEMENT_NOT_FOUND'
    );
  end if;

  -- Serialize per account exactly as the activation function does, so a
  -- revocation arriving beside a renewal cannot interleave with it.
  perform pg_advisory_xact_lock(hashtextextended(v_entitlement.user_id::text, 0));

  -- Re-read under the lock: a concurrent activation may have moved the row
  -- between the lookup above and the lock being granted.
  select * into v_entitlement
  from public.user_entitlements as e
  where e.id = v_entitlement.id;

  if v_entitlement.status = 'revoked' then
    -- Already revoked. Idempotent by design: the same revocation notification
    -- redelivered, or a revocation racing the voided-purchase sweep, must not
    -- bump the version or move the timestamps a second time.
    return jsonb_build_object(
      'ok', true,
      'changed', false,
      'userId', v_entitlement.user_id,
      'entitlementId', v_entitlement.id
    );
  end if;

  update public.user_entitlements as e
     set status = 'revoked',
         auto_renew = false,
         -- The period is left exactly as it was. It is the record of what was
         -- paid for and when, and rewriting it would destroy the evidence that
         -- explains the refund.
         verified_at = coalesce(p_revoked_at, v_now),
         version = e.version + 1
   where e.id = v_entitlement.id;

  -- Keep the verification record's view of the provider in step, so the audit
  -- trail does not still read ACTIVE for a purchase that was taken back.
  update public.provider_purchase_verifications as v
     set subscription_state = coalesce(
           p_provider_state, v.subscription_state
         ),
         verified_at = coalesce(p_revoked_at, v_now),
         updated_at = v_now
   where v.purchase_reference = p_purchase_reference;

  return jsonb_build_object(
    'ok', true,
    'changed', true,
    'userId', v_entitlement.user_id,
    'entitlementId', v_entitlement.id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Grants
-- ---------------------------------------------------------------------------
--
-- The same posture as `activate_verified_google_play_subscription`: every
-- function here takes its authority from its arguments rather than from
-- `auth.uid()`, so none of them may be held by a client role. A user able to
-- call `revoke_google_play_subscription` could revoke somebody else's plan
-- given only a reference; a user able to call
-- `finalize_google_play_notification` could mark a real notification handled
-- and suppress the reconciliation it was meant to trigger.
revoke all on function public.google_play_purchase_owner(text, text)
  from public;
revoke all on function public.google_play_purchase_owner(text, text)
  from anon;
revoke all on function public.google_play_purchase_owner(text, text)
  from authenticated;
grant execute on function public.google_play_purchase_owner(text, text)
  to service_role;

revoke all on function public.claim_google_play_notification(
  text, text, integer, text, timestamptz
) from public;
revoke all on function public.claim_google_play_notification(
  text, text, integer, text, timestamptz
) from anon;
revoke all on function public.claim_google_play_notification(
  text, text, integer, text, timestamptz
) from authenticated;
grant execute on function public.claim_google_play_notification(
  text, text, integer, text, timestamptz
) to service_role;

revoke all on function public.finalize_google_play_notification(
  text, text, uuid, uuid
) from public;
revoke all on function public.finalize_google_play_notification(
  text, text, uuid, uuid
) from anon;
revoke all on function public.finalize_google_play_notification(
  text, text, uuid, uuid
) from authenticated;
grant execute on function public.finalize_google_play_notification(
  text, text, uuid, uuid
) to service_role;

revoke all on function public.revoke_google_play_subscription(
  text, text, timestamptz
) from public;
revoke all on function public.revoke_google_play_subscription(
  text, text, timestamptz
) from anon;
revoke all on function public.revoke_google_play_subscription(
  text, text, timestamptz
) from authenticated;
grant execute on function public.revoke_google_play_subscription(
  text, text, timestamptz
) to service_role;
