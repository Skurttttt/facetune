-- FaceTune SUB-2: subscription products, user entitlements, and the AI Look
-- usage ledger.
--
-- Purely additive. No existing table, column, constraint, policy, grant, or
-- trigger from a prior migration is altered or dropped. In particular this
-- migration does NOT touch `ai_usage_events` or `public.consume_ai_quota`.
--
-- Deliberately NOT created here:
--
--   * Any reserve / commit / release function. The usage lifecycle engine is
--     SUB-4. This migration creates the shape those functions will write into
--     and the guard rails they must satisfy, nothing more.
--
--   * Any entitlement resolution or allowance computation. That is SUB-3.
--
--   * Any purchase, receipt, provider-event, or verification table. Provider
--     verification persistence belongs to SUB-10. The only provider fields
--     here are the minimum needed to keep a *restore* or *renewal* from
--     creating a duplicate entitlement, which is a structural property of the
--     entitlement table itself and cannot be deferred without designing the
--     table twice.
--
--   * Any replacement for `ai_usage_events`. The two ledgers answer different
--     questions and both must exist. `ai_usage_events` is an abuse rate
--     limiter: it charges at request time, has no reserved/committed/released
--     status, no operation identity, and no release path, so a failed
--     generation still leaves a consumed row. That is correct for a rate
--     limiter and wrong for billing, where no usable persisted Final Makeup
--     Preview must mean no consumed AI Look. `usage_ledger` below is the
--     billing ledger. Neither is derived from the other.
--
--   * Any remaining-balance column. Available capacity is derived from this
--     ledger (effective allowance − committed − active reservations) and is
--     never stored, so there is no counter for a client or a bug to desync.

-- ---------------------------------------------------------------------------
-- 1. Subscription products — public plan configuration
-- ---------------------------------------------------------------------------
--
-- The server-side authority for what each plan grants. The Flutter plan
-- catalog added in SUB-1 describes plans for presentation; this table is what
-- the entitlement engine reads, so changing an allowance here does not require
-- a mobile release.
--
-- Product configuration is not secret — it is the plan comparison a paywall
-- renders — so authenticated users may read active rows. They may not write
-- any of it: there is no INSERT, UPDATE, or DELETE grant below.

create table if not exists public.subscription_products (
  id uuid primary key default gen_random_uuid(),
  plan_code text not null unique,
  display_name text not null,
  publicly_purchasable boolean not null default false,
  billing_provider text not null,
  -- Null until the Google Play Console subscription products exist. SUB-10
  -- populates these from verified store configuration; they must never be
  -- guessed.
  provider_product_id text,
  -- 'month' for recurring plans, null for one-time and admin-granted plans.
  billing_interval text,
  base_ai_look_allowance integer not null,
  reset_policy text not null,
  active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint subscription_products_plan_code_valid
    check (plan_code in ('free', 'plus', 'pro', 'salon_pro', 'salon_pilot')),
  constraint subscription_products_billing_provider_valid
    check (
      billing_provider in (
        'none',
        'google_play',
        'apple_app_store',
        'admin_granted'
      )
    ),
  constraint subscription_products_reset_policy_valid
    check (reset_policy in ('none', 'billing_period')),
  constraint subscription_products_billing_interval_valid
    check (billing_interval is null or billing_interval in ('month')),
  constraint subscription_products_display_name_not_blank
    check (char_length(btrim(display_name)) > 0),
  constraint subscription_products_provider_product_not_blank
    check (
      provider_product_id is null
      or char_length(btrim(provider_product_id)) > 0
    ),
  constraint subscription_products_allowance_not_negative
    check (base_ai_look_allowance >= 0),

  -- A recurring allowance needs an interval to recur on, and a plan that never
  -- resets must not claim one.
  constraint subscription_products_reset_interval_agree
    check (
      (reset_policy = 'billing_period' and billing_interval is not null)
      or (reset_policy = 'none' and billing_interval is null)
    ),

  -- Only a store-backed plan can be bought. This is what stops Salon Pilot
  -- from ever being marked purchasable, which would put a complimentary
  -- research entitlement in front of the public.
  constraint subscription_products_purchasable_requires_store
    check (
      publicly_purchasable = false
      or billing_provider in ('google_play', 'apple_app_store')
    ),
  constraint subscription_products_salon_pilot_not_public
    check (plan_code <> 'salon_pilot' or publicly_purchasable = false),
  constraint subscription_products_free_has_no_provider
    check (plan_code <> 'free' or billing_provider = 'none'),
  constraint subscription_products_salon_pilot_admin_granted
    check (plan_code <> 'salon_pilot' or billing_provider = 'admin_granted')
);

-- Plain unique index on a nullable column, not a partial one. NULLs are
-- distinct by default, so the rows without a store product still coexist while
-- two plans can never claim the same one. The partial form would be smaller
-- and would break `ON CONFLICT (provider_product_id)` inference exactly as
-- 20260831000100 documents.
create unique index if not exists subscription_products_provider_product_idx
  on public.subscription_products (provider_product_id);

drop trigger if exists subscription_products_set_updated_at
  on public.subscription_products;
create trigger subscription_products_set_updated_at
before update on public.subscription_products
for each row execute function public.set_updated_at();

-- The approved V1 baseline. `do nothing` on conflict so re-running this
-- migration cannot revert a later authorized configuration change.
insert into public.subscription_products (
  plan_code,
  display_name,
  publicly_purchasable,
  billing_provider,
  billing_interval,
  base_ai_look_allowance,
  reset_policy
)
values
  -- Free is not purchasable because there is nothing to buy: it is the default
  -- entitlement, and its single AI Look never replenishes.
  ('free', 'FaceTune Free', false, 'none', null, 1, 'none'),
  ('plus', 'FaceTune Plus', true, 'google_play', 'month', 3, 'billing_period'),
  ('pro', 'FaceTune Pro', true, 'google_play', 'month', 8, 'billing_period'),
  (
    'salon_pro',
    'Salon Pro',
    true,
    'google_play',
    'month',
    35,
    'billing_period'
  ),
  -- The default initial grant. Adjusted per entitlement by authorized admin
  -- operations, never by editing this row.
  ('salon_pilot', 'Salon Pilot', false, 'admin_granted', null, 30, 'none')
on conflict (plan_code) do nothing;

-- ---------------------------------------------------------------------------
-- 2. User entitlements
-- ---------------------------------------------------------------------------
--
-- What one account is entitled to. Allowance lives here rather than being read
-- from `subscription_products` at query time because an authorized adjustment
-- changes the entitlement, not the plan: a Salon Pilot grant raised from 30 to
-- 40 is still `salon_pilot`, and resolving its allowance through the product
-- row would silently understate it.
--
-- `base_ai_look_allowance` and `allowance_adjustment_total` are kept apart so
-- the adjustment stays auditable. "Started at 30, an admin added 10" and
-- "granted 40" are different facts and only the first can be reviewed later.
-- Effective allowance is their sum; it is not stored.
--
-- The two date pairs are not interchangeable. `period_start`/`period_end` are
-- verified provider billing periods; `starts_at`/`expires_at` are the term of
-- an administrative grant. Constraints below force each plan family to use the
-- pair that belongs to it.

create table if not exists public.user_entitlements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null,
  status text not null,
  billing_provider text not null,
  provider_product_id text,
  -- An opaque server-side reference to the provider subscription. NOT a
  -- purchase token and not a receipt: raw provider credentials are not stored
  -- here, and this column is withheld from the client by the column-level
  -- grant below.
  provider_subscription_reference text,
  period_start timestamptz,
  period_end timestamptz,
  starts_at timestamptz not null default timezone('utc', now()),
  expires_at timestamptz,
  auto_renew boolean not null default false,
  base_ai_look_allowance integer not null,
  allowance_adjustment_total integer not null default 0,
  -- Optimistic concurrency for lifecycle transitions and allowance
  -- adjustments, so two admins editing the same entitlement cannot lose one
  -- another's update. SUB-3 and the admin write path bump it.
  version integer not null default 1,
  verified_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  -- Composite owner identity, so the usage ledger can foreign-key to
  -- (entitlement, owner) as a pair and cross-account attachment becomes
  -- structurally impossible rather than policy-dependent.
  constraint user_entitlements_owner_identity unique (id, user_id),

  constraint user_entitlements_plan_code_valid
    check (plan_code in ('free', 'plus', 'pro', 'salon_pro', 'salon_pilot')),
  constraint user_entitlements_status_valid
    check (
      status in (
        'pending',
        'active',
        'grace_period',
        'expired',
        'suspended',
        'revoked'
      )
    ),
  constraint user_entitlements_billing_provider_valid
    check (
      billing_provider in (
        'none',
        'google_play',
        'apple_app_store',
        'admin_granted'
      )
    ),
  constraint user_entitlements_allowance_not_negative
    check (base_ai_look_allowance >= 0),
  -- An adjustment may reduce an allowance but can never drive the effective
  -- grant below zero.
  constraint user_entitlements_effective_allowance_not_negative
    check (base_ai_look_allowance + allowance_adjustment_total >= 0),
  constraint user_entitlements_version_positive
    check (version > 0),
  constraint user_entitlements_provider_product_not_blank
    check (
      provider_product_id is null
      or char_length(btrim(provider_product_id)) > 0
    ),
  constraint user_entitlements_provider_reference_not_blank
    check (
      provider_subscription_reference is null
      or char_length(btrim(provider_subscription_reference)) > 0
    ),

  -- A billing period is a pair. Exactly one half is always a bug, and a
  -- pending purchase that has no verified period yet has neither.
  constraint user_entitlements_period_pair
    check (
      (period_start is null and period_end is null)
      or (period_start is not null and period_end is not null)
    ),
  constraint user_entitlements_period_ordered
    check (period_end is null or period_end > period_start),
  constraint user_entitlements_expiry_ordered
    check (expires_at is null or expires_at > starts_at),

  -- Free never renews, never expires, and has no billing period to reset on.
  constraint user_entitlements_free_shape
    check (
      plan_code <> 'free'
      or (
        billing_provider = 'none'
        and period_start is null
        and period_end is null
        and expires_at is null
        and auto_renew = false
        and provider_product_id is null
        and provider_subscription_reference is null
      )
    ),

  -- Salon Pilot is an admin-granted term with a required end date. An admin
  -- grant with no expiry is an unbounded free entitlement.
  constraint user_entitlements_salon_pilot_shape
    check (
      plan_code <> 'salon_pilot'
      or (
        billing_provider = 'admin_granted'
        and expires_at is not null
        and auto_renew = false
        and period_start is null
        and period_end is null
        and provider_product_id is null
        and provider_subscription_reference is null
      )
    ),

  -- Paid recurring plans are store-backed. `apple_app_store` is accepted as
  -- the reserved compatibility code only; nothing in the Android-only V1 scope
  -- produces it.
  constraint user_entitlements_paid_plan_shape
    check (
      plan_code not in ('plus', 'pro', 'salon_pro')
      or billing_provider in ('google_play', 'apple_app_store')
    ),

  -- `admin_granted` is for Salon Pilot. It must not become a way to hand
  -- somebody a paid plan without provider verification.
  constraint user_entitlements_admin_granted_is_salon_pilot
    check (billing_provider <> 'admin_granted' or plan_code = 'salon_pilot')
);

-- At most one entitlement per account may be currently entitled. A pending
-- purchase alongside a live Free entitlement is legitimate and is allowed;
-- two simultaneously active grants are not, which is what makes restore and
-- renewal safe to retry.
create unique index if not exists user_entitlements_one_current_idx
  on public.user_entitlements (user_id)
  where status in ('active', 'grace_period');

-- The anchor that makes restore and renewal idempotent: one provider
-- subscription resolves to one entitlement row. Plain unique index on a
-- nullable column for the reason given on subscription_products above.
create unique index if not exists user_entitlements_provider_reference_idx
  on public.user_entitlements (provider_subscription_reference);

create index if not exists user_entitlements_user_status_idx
  on public.user_entitlements (user_id, status);
create index if not exists user_entitlements_plan_status_idx
  on public.user_entitlements (plan_code, status);
create index if not exists user_entitlements_period_end_idx
  on public.user_entitlements (period_end)
  where period_end is not null;
create index if not exists user_entitlements_expires_at_idx
  on public.user_entitlements (expires_at)
  where expires_at is not null;

drop trigger if exists user_entitlements_set_updated_at
  on public.user_entitlements;
create trigger user_entitlements_set_updated_at
before update on public.user_entitlements
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- 3. Usage ledger — the AI Look billing record
-- ---------------------------------------------------------------------------
--
-- One row per AI Look operation, moving reserved → committed or
-- reserved → released. Available capacity is derived from these rows:
--
--   effective_allowance − committed − active reservations = available
--
-- Reservations count against capacity, which is what stops two concurrent
-- requests from spending the same last AI Look.
--
-- The canonical Final Makeup Preview a commit produced lives in one of two
-- tables — `generated_images` for Standard Mode, `kit_generated_images` for My
-- Makeup Kit — so a single id column cannot reference it. `source_mode` is the
-- explicit discriminator and is never inferred from which id happens to be
-- populated, following `tutorial_v4_sessions`.
--
-- Deleting a history item must not refund an AI Look. Both preview references
-- therefore use `ON DELETE SET NULL` restricted to the preview column, so a
-- deleted preview clears the provenance link while the committed row, its
-- `committed_at`, and its `source_mode` all survive. Without the column list
-- the referential action would try to null `user_id` too and the constraint
-- would be rejected. The composite `(preview_id, user_id)` foreign key is what
-- makes attaching another account's preview impossible at write time.

create table if not exists public.usage_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entitlement_id uuid not null,
  usage_type text not null default 'final_makeup_preview',
  -- The idempotency key. Supplied by the caller as an opaque uuid, never a
  -- storage path, an email, or any other user content.
  operation_id uuid not null,
  status text not null default 'reserved',
  -- Set when the operation commits, and never cleared afterwards, so a row
  -- whose preview was later deleted still records which pipeline produced it.
  source_mode text,
  canonical_generated_image_id uuid,
  canonical_kit_generated_image_id uuid,
  -- The billing period this usage belongs to, captured at reservation time.
  -- Usage stays linked to the period it happened in; a renewal never rewrites
  -- it into the new one.
  period_start timestamptz,
  period_end timestamptz,
  reserved_at timestamptz not null default timezone('utc', now()),
  committed_at timestamptz,
  released_at timestamptz,
  -- A short controlled reason such as 'generation_failed'. Never a provider
  -- payload, stack trace, SQL error, or storage path.
  sanitized_failure_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),

  constraint usage_ledger_owner_identity unique (id, user_id),

  -- One row per logical operation, globally. This single constraint is what
  -- makes a duplicate tap, a client retry, a lost response, or a repeated
  -- callback resolve to the same reservation instead of a second deduction.
  constraint usage_ledger_operation_unique unique (operation_id),

  constraint usage_ledger_entitlement_owner_fk
    foreign key (entitlement_id, user_id)
    references public.user_entitlements(id, user_id)
    on delete cascade,

  constraint usage_ledger_canonical_preview_owner_fk
    foreign key (canonical_generated_image_id, user_id)
    references public.generated_images(id, user_id)
    on delete set null (canonical_generated_image_id),

  constraint usage_ledger_canonical_kit_preview_owner_fk
    foreign key (canonical_kit_generated_image_id, user_id)
    references public.kit_generated_images(id, user_id)
    on delete set null (canonical_kit_generated_image_id),

  constraint usage_ledger_usage_type_valid
    check (usage_type in ('final_makeup_preview')),
  constraint usage_ledger_status_valid
    check (status in ('reserved', 'committed', 'released')),
  constraint usage_ledger_source_mode_valid
    check (source_mode is null or source_mode in ('standard', 'makeup_kit')),
  constraint usage_ledger_failure_code_not_blank
    check (
      sanitized_failure_code is null
      or char_length(btrim(sanitized_failure_code)) between 1 and 64
    ),

  -- Each status implies exactly which timestamps exist. A committed row can
  -- never also look released, and a reserved row can never carry either.
  constraint usage_ledger_status_timestamps
    check (
      (status = 'reserved' and committed_at is null and released_at is null)
      or (
        status = 'committed'
        and committed_at is not null
        and released_at is null
      )
      or (
        status = 'released'
        and released_at is not null
        and committed_at is null
      )
    ),

  -- A commit is proof that a usable canonical preview was persisted, so it
  -- must record which pipeline produced it. The preview id itself may later
  -- become null when the user deletes that history item; `source_mode` does
  -- not, so the commit stays self-describing.
  constraint usage_ledger_committed_requires_source_mode
    check (status <> 'committed' or source_mode is not null),

  -- A released reservation produced nothing, so it must not point at a
  -- preview or claim a mode.
  constraint usage_ledger_released_has_no_preview
    check (
      status <> 'released'
      or (
        source_mode is null
        and canonical_generated_image_id is null
        and canonical_kit_generated_image_id is null
      )
    ),

  -- A failure reason belongs only to a released operation.
  constraint usage_ledger_failure_code_scoped
    check (sanitized_failure_code is null or status = 'released'),

  -- The populated preview reference must agree with the declared mode, and the
  -- two can never both be set. A committed row with a mode and no id is the
  -- deleted-history case and is allowed.
  constraint usage_ledger_preview_lineage
    check (
      (
        source_mode is null
        and canonical_generated_image_id is null
        and canonical_kit_generated_image_id is null
      )
      or (
        source_mode = 'standard'
        and canonical_kit_generated_image_id is null
      )
      or (
        source_mode = 'makeup_kit'
        and canonical_generated_image_id is null
      )
    ),

  -- Reservation happens before commit or release, never after.
  constraint usage_ledger_committed_after_reserved
    check (committed_at is null or committed_at >= reserved_at),
  constraint usage_ledger_released_after_reserved
    check (released_at is null or released_at >= reserved_at),

  constraint usage_ledger_period_pair
    check (
      (period_start is null and period_end is null)
      or (period_start is not null and period_end is not null)
    ),
  constraint usage_ledger_period_ordered
    check (period_end is null or period_end > period_start)
);

-- One canonical preview can be billed at most once. Plain unique indexes on
-- nullable columns: the many rows holding NULL coexist because NULLs are
-- distinct, while a second commit against the same preview is rejected.
create unique index if not exists usage_ledger_canonical_preview_idx
  on public.usage_ledger (canonical_generated_image_id);
create unique index if not exists usage_ledger_canonical_kit_preview_idx
  on public.usage_ledger (canonical_kit_generated_image_id);

-- Capacity is computed per entitlement and status, and the reservation-recovery
-- sweep in SUB-4 scans reserved rows by age.
create index if not exists usage_ledger_entitlement_status_idx
  on public.usage_ledger (entitlement_id, status);
create index if not exists usage_ledger_user_status_idx
  on public.usage_ledger (user_id, status);
create index if not exists usage_ledger_user_created_idx
  on public.usage_ledger (user_id, created_at desc);
create index if not exists usage_ledger_active_reservations_idx
  on public.usage_ledger (reserved_at)
  where status = 'reserved';

drop trigger if exists usage_ledger_set_updated_at on public.usage_ledger;
create trigger usage_ledger_set_updated_at
before update on public.usage_ledger
for each row execute function public.set_updated_at();

-- Committed usage is immutable historical record. Defence in depth behind the
-- absent UPDATE grant: even a future migration that mistakenly grants UPDATE,
-- or a privileged function with a bug, cannot rewrite a consumed AI Look into
-- a released one.
--
-- The single permitted change is the referential SET NULL that runs when a
-- user deletes the history item holding the preview. That fires as an UPDATE
-- and would otherwise be blocked here, which would make history deletion fail
-- outright. Only the transition from a set preview id to null is allowed, and
-- only when nothing else about the row moves.
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
  then
    return new;
  end if;

  raise exception
    'committed usage_ledger rows are immutable historical records';
end;
$$;

drop trigger if exists usage_ledger_committed_immutable on public.usage_ledger;
create trigger usage_ledger_committed_immutable
before update on public.usage_ledger
for each row execute function public.reject_committed_usage_mutation();

-- There is deliberately NO trigger blocking DELETE on this table.
--
-- The obvious mirror of the immutability trigger above would be a BEFORE
-- DELETE that rejects committed rows. It would be actively harmful: BEFORE
-- DELETE triggers fire for cascaded deletes too, so it would abort the
-- `auth.users` cascade and make account deletion — an erasure obligation, not
-- an optional feature — fail outright. Protecting a usage row by trapping a
-- user inside the product is the wrong trade.
--
-- Deletion is instead prevented by privilege. `authenticated` holds no DELETE
-- grant on this table or on `user_entitlements`, so no client can reach either
-- the direct delete or the entitlement cascade. Account deletion via
-- `auth.users` remains the one path that removes this history, which is
-- correct.

-- ---------------------------------------------------------------------------
-- 4. Row level security
-- ---------------------------------------------------------------------------
--
-- These three tables use a stricter model than the rest of the schema. Every
-- other owned table grants `select, insert, update, delete` to `authenticated`
-- on the reasoning that a user owns their own rows. That reasoning does not
-- hold for entitlements and usage, where the row owner is precisely the party
-- who benefits from forging it.
--
-- So no write privilege is granted to `authenticated` at all. Every "a user
-- cannot grant themselves a paid plan / raise their own allowance / insert
-- fake committed usage / release real usage / attach another account's
-- preview" requirement is enforced by the absent GRANT first and the RLS
-- policy second — a missing privilege cannot be bypassed by a policy mistake.
--
-- Privileged writes run through `security definer` functions owned by a
-- superuser role, following `public.consume_ai_quota` (20260812000100). No
-- Edge Function in this project holds the service-role key, and none needs to.

alter table public.subscription_products enable row level security;
alter table public.user_entitlements enable row level security;
alter table public.usage_ledger enable row level security;

revoke all on table public.subscription_products from anon;
revoke all on table public.subscription_products from authenticated;
revoke all on table public.user_entitlements from anon;
revoke all on table public.user_entitlements from authenticated;
revoke all on table public.usage_ledger from anon;
revoke all on table public.usage_ledger from authenticated;

-- Plan configuration is public product information — the comparison a paywall
-- renders — so it is readable, and only readable.
grant select on table public.subscription_products to authenticated;

-- Column-level grant. `provider_subscription_reference` is withheld from the
-- client entirely: a provider reference is support data held under least
-- privilege, and the app has no use for it. A `select *` by an ordinary user
-- therefore fails rather than leaking it, so client reads must name their
-- columns.
grant select (
  id,
  user_id,
  plan_code,
  status,
  billing_provider,
  provider_product_id,
  period_start,
  period_end,
  starts_at,
  expires_at,
  auto_renew,
  base_ai_look_allowance,
  allowance_adjustment_total,
  version,
  verified_at,
  created_at,
  updated_at
) on table public.user_entitlements to authenticated;

grant select on table public.usage_ledger to authenticated;

drop policy if exists "subscription_products_select_active"
  on public.subscription_products;
create policy "subscription_products_select_active"
on public.subscription_products for select
to authenticated
using (active);

drop policy if exists "user_entitlements_select_own" on public.user_entitlements;
create policy "user_entitlements_select_own"
on public.user_entitlements for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "usage_ledger_select_own" on public.usage_ledger;
create policy "usage_ledger_select_own"
on public.usage_ledger for select
to authenticated
using ((select auth.uid()) = user_id);

-- No INSERT, UPDATE, or DELETE policy is created for any of the three tables,
-- and no such privilege is granted. This is deliberate and is the security
-- boundary of the whole subscription system, not an omission to be filled in
-- by a later phase.
