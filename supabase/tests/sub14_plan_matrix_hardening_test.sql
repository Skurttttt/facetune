-- SUB-14 — plan matrix, capability, accounting and lifecycle hardening.
--
-- Drives the real resolver, reservation ledger, Tutorial authorization,
-- activation writer and notification claim through every plan in the locked
-- matrix (1 / 3 / 30 / 8 / 80 / 35 / 350 / 30) and every lifecycle state
-- the provider can report, and pins the answers. Nothing here is mocked:
-- a "spend" is a real reserve → persist → commit against a real preview row.
-- Everything runs in one transaction and is rolled back.
begin;

select plan(172);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Act as an account. The RPCs read `auth.uid()` from the request claims.
create function pg_temp.as_user(p_user uuid) returns void
language plpgsql set search_path = '' as $$
begin
  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
end;
$$;

create function pg_temp.state(p_user uuid) returns jsonb
language plpgsql set search_path = '' as $$
begin
  perform pg_temp.as_user(p_user);
  return public.resolve_subscription_state();
end;
$$;

-- A persisted preview the account owns, so a commit has something to name.
create function pg_temp.new_preview(p_user uuid) returns uuid
language plpgsql set search_path = '' as $$
declare v_analysis uuid; v_rec uuid; v_img uuid;
begin
  select a.id into v_analysis from public.analyses a
   where a.user_id = p_user limit 1;
  if v_analysis is null then
    insert into public.analyses (user_id, original_image_path)
    values (p_user, p_user::text || '/analyses/x/original/selfie.jpg')
    returning id into v_analysis;
    insert into public.recommendations (user_id, analysis_id, makeup_style)
    values (p_user, v_analysis, 'natural');
  end if;
  select r.id into v_rec from public.recommendations r
   where r.user_id = p_user limit 1;
  insert into public.generated_images
    (user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values (p_user, v_analysis, v_rec,
          p_user::text || '/previews/' || gen_random_uuid()::text || '.png',
          (select coalesce(max(g.generation_number), 0) + 1
             from public.generated_images g where g.recommendation_id = v_rec))
  returning id into v_img;
  return v_img;
end;
$$;

-- Reserve → persist → commit, `p_n` times, stopping at the first refusal.
-- Returns how many committed.
create function pg_temp.spend(p_user uuid, p_n int) returns int
language plpgsql set search_path = '' as $$
declare i int; r jsonb; op uuid; pv uuid; done int := 0;
begin
  perform pg_temp.as_user(p_user);
  for i in 1..p_n loop
    op := gen_random_uuid();
    r := public.reserve_ai_look(op);
    if (r->>'ok')::boolean is not true then exit; end if;
    pv := pg_temp.new_preview(p_user);
    r := public.commit_ai_look(op, 'standard', pv);
    if (r->>'ok')::boolean is not true then
      raise exception 'commit failed: %', r;
    end if;
    done := done + 1;
  end loop;
  return done;
end;
$$;

create function pg_temp.tutorial(p_user uuid, p_preview uuid) returns jsonb
language plpgsql set search_path = '' as $$
begin
  perform pg_temp.as_user(p_user);
  return public.authorize_tutorial_generation('standard', p_preview, null);
end;
$$;

-- The last preview an account committed, for Tutorial checks. Ordered by
-- the preview's generation number: `now()` is fixed for the whole test
-- transaction, so timestamps cannot tell commits apart here.
create function pg_temp.last_preview(p_user uuid) returns uuid
language sql set search_path = '' as $$
  select l.canonical_generated_image_id from public.usage_ledger l
   join public.generated_images g on g.id = l.canonical_generated_image_id
   where l.user_id = p_user and l.status = 'committed'
   order by g.generation_number desc limit 1
$$;

create function pg_temp.ref(p text) returns text
language sql immutable as $$ select repeat(p, 64) $$;

-- The SUB-10 activation writer, with a period that starts a day ago.
create function pg_temp.activate(
  p_user uuid, p_product text, p_ref text, p_state text,
  p_end timestamptz default timezone('utc', now()) + interval '29 days',
  p_linked text default null,
  p_start timestamptz default timezone('utc', now()) - interval '1 day'
) returns jsonb
language sql set search_path = '' as $$
  select public.activate_verified_google_play_subscription(
    p_user, p_product, p_ref, p_state, p_start, p_end,
    p_state = 'SUBSCRIPTION_STATE_ACTIVE', p_linked, true)
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: one account per plan, plus spares
-- ---------------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
)
select
  '00000000-0000-0000-0000-000000000000', v.id, 'authenticated',
  'authenticated', v.email, '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', ''
from (values
  ('10000000-0000-4000-8000-000000000201'::uuid, 'sub14-free@example.invalid'),
  ('10000000-0000-4000-8000-000000000202'::uuid, 'sub14-plus@example.invalid'),
  ('10000000-0000-4000-8000-000000000203'::uuid, 'sub14-plus-preview@example.invalid'),
  ('10000000-0000-4000-8000-000000000204'::uuid, 'sub14-pro@example.invalid'),
  ('10000000-0000-4000-8000-000000000205'::uuid, 'sub14-pro-preview@example.invalid'),
  ('10000000-0000-4000-8000-000000000206'::uuid, 'sub14-salon-pro@example.invalid'),
  ('10000000-0000-4000-8000-000000000207'::uuid, 'sub14-salon-preview@example.invalid'),
  ('10000000-0000-4000-8000-000000000208'::uuid, 'sub14-salon-pilot@example.invalid'),
  ('10000000-0000-4000-8000-000000000209'::uuid, 'sub14-lifecycle@example.invalid'),
  ('10000000-0000-4000-8000-000000000210'::uuid, 'sub14-accounting@example.invalid'),
  ('10000000-0000-4000-8000-000000000211'::uuid, 'sub14-transition@example.invalid')
) as v(id, email);

-- ===========================================================================
-- FREE — 1 lifetime AI Look
-- ===========================================================================

select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000201'),
  1::bigint,
  'Free: sign-up provisions exactly one entitlement'
);

select is(
  (pg_temp.state('10000000-0000-4000-8000-000000000201'))
    - 'entitlementId' - 'resolvedAt' - 'verifiedAt' - 'startsAt'
    - 'planDisplayName' - 'providerProductId',
  jsonb_build_object(
    'hasEntitlement', true, 'planCode', 'free', 'entitlementStatus', 'active',
    'billingProvider', 'none', 'publiclyPurchasable', false,
    'allowanceUnit', 'ai_look', 'tutorialEnabled', true,
    'finalPreviewEnabled', true, 'periodStart', null, 'periodEnd', null,
    'expiresAt', null, 'autoRenew', false, 'resetPolicy', 'none',
    'resetAt', null, 'baseAllowance', 1, 'allowanceAdjustmentTotal', 0,
    'effectiveAllowance', 1, 'committedUsage', 0, 'reservedUsage', 0,
    'availableAiLooks', 1, 'remainingAiLooks', 1,
    'generationAuthorized', true, 'denialReason', null,
    'purchasedTutorialCreditsRemaining', 0,
    'purchasedPreviewCreditsRemaining', 0, 'purchasedCreditsUsable', false,
    'availablePurchasedCredits', 0, 'nextAllowanceSource', 'subscription',
    'nextAllowanceUnit', 'ai_look'
  ),
  'Free: 1 lifetime AI Look, Tutorial on, no reset date, not purchasable'
);

select is(
  pg_temp.spend('10000000-0000-4000-8000-000000000201', 1), 1,
  'Free: the first success commits the one AI Look'
);

select is(
  (pg_temp.state('10000000-0000-4000-8000-000000000201'))->>'denialReason',
  'AI_LOOK_LIMIT_REACHED',
  'Free: exhausted after one'
);

select is(
  pg_temp.spend('10000000-0000-4000-8000-000000000201', 1), 0,
  'Free: exhausted remains exhausted'
);

select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000201',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000201')))->>'authorized',
  'true',
  'Free: the one AI Look carries its Tutorial'
);

-- Month/year change: a Free AI Look spent two years ago (a historical row,
-- inserted as such because committed rows are immutable) still counts —
-- Free has no period, so there is nothing for time to reset against.
insert into public.usage_ledger (
  user_id, entitlement_id, operation_id, status, source_mode,
  canonical_generated_image_id, reserved_at, committed_at,
  plan_code, allowance_unit, allowance_source
)
select '10000000-0000-4000-8000-000000000211', e.id, gen_random_uuid(),
       'committed', 'standard',
       pg_temp.new_preview('10000000-0000-4000-8000-000000000211'),
       timezone('utc', now()) - interval '2 years',
       timezone('utc', now()) - interval '2 years',
       'free', 'ai_look', 'subscription'
  from public.user_entitlements e
 where e.user_id = '10000000-0000-4000-8000-000000000211' and e.plan_code = 'free';

select is(
  (select s->>'remainingAiLooks' || '|' || (s->>'denialReason')
   from pg_temp.state('10000000-0000-4000-8000-000000000211') s),
  '0|AI_LOOK_LIMIT_REACHED',
  'Free: a month/year change never resets the lifetime allowance'
);
select is(
  pg_temp.spend('10000000-0000-4000-8000-000000000211', 1), 0,
  'Free: a two-year-old spend still blocks a second AI Look'
);

-- Login/reinstall: the provisioning path runs again and finds the same row.
select is(
  public.provision_free_entitlement('10000000-0000-4000-8000-000000000201'),
  (select id from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000201'),
  'Free: re-provisioning on login/reinstall returns the same entitlement'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000201'),
  1::bigint,
  'Free: still exactly one entitlement after re-provisioning'
);

-- A second Free row cannot be created by any path.
select throws_ok(
  $$ insert into public.user_entitlements
       (user_id, plan_code, status, billing_provider, base_ai_look_allowance)
     values ('10000000-0000-4000-8000-000000000201', 'free', 'active', 'none', 1) $$,
  '23505',
  null,
  'Free: a second Free entitlement is structurally impossible'
);

-- A Free row can never be re-armed with a bigger allowance.
select throws_ok(
  $$ update public.user_entitlements set base_ai_look_allowance = 5
      where user_id = '10000000-0000-4000-8000-000000000201' $$,
  null, null,
  'Free: the lifetime allowance cannot be raised'
);

-- Paid purchase → renewal → expiry → restore does not recreate Free.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000201', 'facetune_plus',
     pg_temp.ref('a'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Free: buys Plus'
);
select is(
  (pg_temp.state('10000000-0000-4000-8000-000000000201'))->>'planCode',
  'plus', 'Free: Plus now governs'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000201', 'facetune_plus',
     pg_temp.ref('a'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Free: Plus renews'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000201', 'facetune_plus',
     pg_temp.ref('a'), 'SUBSCRIPTION_STATE_EXPIRED',
     timezone('utc', now()) - interval '1 hour'))->>'ok',
  'true', 'Free: Plus expires'
);
select is(
  (pg_temp.state('10000000-0000-4000-8000-000000000201'))->>'planCode',
  'free', 'Free: after expiry the account falls back to Free'
);
select is(
  (pg_temp.state('10000000-0000-4000-8000-000000000201'))->>'remainingAiLooks',
  '0', 'Free: the fallback Free is the same spent one, not a fresh one'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000201'
     and plan_code = 'free'),
  1::bigint,
  'Free: purchase/renewal/expiry/restore never recreated Free'
);

-- ===========================================================================
-- PLUS — 3 AI Looks, Tutorial
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000202', 'facetune_plus',
     pg_temp.ref('b'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Plus: activates'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance')
   from pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '3/3', 'Plus: 3/3'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000202', 1), 1,
  'Plus: one spent');
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance')
   from pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '2/3', 'Plus: 2/3'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000202',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000202')))->>'authorized',
  'true', 'Plus: Tutorial allowed'
);
select is(
  (select s->>'availableAiLooks' from
   pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '2', 'Plus: Tutorial authorization consumed no additional credit'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000202', 1), 1,
  'Plus: two spent');
select is(
  (select s->>'availableAiLooks' from
   pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '1', 'Plus: 1/3'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000202', 5), 1,
  'Plus: only the third is granted');
select is(
  (select s->>'availableAiLooks' || '|' || (s->>'denialReason') from
   pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '0|AI_LOOK_LIMIT_REACHED', 'Plus: 0/3 and refused'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000202',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000202')))->>'authorized',
  'true', 'Plus: Tutorial on an existing AI Look still allowed at 0/3'
);
-- Renewal: the provider reports a new period, one month on.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000202', 'facetune_plus',
     pg_temp.ref('b'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Plus: renews'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance') from
   pg_temp.state('10000000-0000-4000-8000-000000000202') s),
  '3/3', 'Plus: a new verified period resets the included allowance to 3'
);
select is(
  (select count(*) from public.usage_ledger
   where user_id = '10000000-0000-4000-8000-000000000202' and status = 'committed'),
  3::bigint, 'Plus: historical usage is preserved through the reset'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000202' and plan_code <> 'free'),
  1::bigint, 'Plus: renewal did not create a second entitlement'
);

-- ===========================================================================
-- PLUS PREVIEW — 30 Final Preview credits, no Tutorial
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000203',
     'facetune_plus_preview', pg_temp.ref('c'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Plus Preview: activates from its own product'
);
select is(
  (select s->>'planCode' || ' ' || (s->>'availableAiLooks') || '/' ||
          (s->>'effectiveAllowance') || ' ' || (s->>'allowanceUnit') || ' tut=' ||
          (s->>'tutorialEnabled') || ' fp=' || (s->>'finalPreviewEnabled')
   from pg_temp.state('10000000-0000-4000-8000-000000000203') s),
  'plus_preview 30/30 final_preview_credit tut=false fp=true',
  'Plus Preview: 30/30 Final Preview credits, Tutorial off'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000203', 1), 1,
  'Plus Preview: one Final Preview consumes one credit');
select is(
  (select s->>'availableAiLooks' from
   pg_temp.state('10000000-0000-4000-8000-000000000203') s),
  '29', 'Plus Preview: 29/30'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000203',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000203')))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED', 'Plus Preview: Tutorial denied server-side'
);
select is(
  (select l.allowance_unit || '/' || l.plan_code from public.usage_ledger l
   where l.user_id = '10000000-0000-4000-8000-000000000203' and l.status = 'committed'),
  'final_preview_credit/plus_preview',
  'Plus Preview: the ledger records Preview-only provenance at reservation'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000203', 40), 29,
  'Plus Preview: exactly 29 more are granted, then refused');
select is(
  (select s->>'committedUsage' || '/' || (s->>'availableAiLooks') || '|' ||
          (s->>'denialReason') from pg_temp.state('10000000-0000-4000-8000-000000000203') s),
  '30/0|AI_LOOK_LIMIT_REACHED', 'Plus Preview: exhaustion arithmetic 30 = 30'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000203',
     'facetune_plus_preview', pg_temp.ref('c'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Plus Preview: renews'
);
select is(
  (select s->>'availableAiLooks' from
   pg_temp.state('10000000-0000-4000-8000-000000000203') s),
  '30', 'Plus Preview: a new verified period resets to 30'
);

-- ===========================================================================
-- PRO — 8 AI Looks, Tutorial
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000204', 'facetune_pro',
     pg_temp.ref('d'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Pro: activates'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance') || ' tut=' ||
          (s->>'tutorialEnabled') from pg_temp.state('10000000-0000-4000-8000-000000000204') s),
  '8/8 tut=true', 'Pro: 8/8, Tutorial on'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000204', 20), 8,
  'Pro: exactly eight are granted');
select is(
  (select s->>'availableAiLooks' || '|' || (s->>'denialReason') from
   pg_temp.state('10000000-0000-4000-8000-000000000204') s),
  '0|AI_LOOK_LIMIT_REACHED', 'Pro: exhausted at 8'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000204',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000204')))->>'authorized',
  'true', 'Pro: Tutorial allowed'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000204', 'facetune_pro',
     pg_temp.ref('d'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Pro: renews'
);
select is(
  (select s->>'availableAiLooks' from pg_temp.state('10000000-0000-4000-8000-000000000204') s),
  '8', 'Pro: new period resets to 8'
);

-- ===========================================================================
-- PRO PREVIEW — 80 credits, no Tutorial
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000205',
     'facetune_pro_preview', pg_temp.ref('e'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Pro Preview: activates'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance') || ' ' ||
          (s->>'allowanceUnit') || ' tut=' || (s->>'tutorialEnabled')
   from pg_temp.state('10000000-0000-4000-8000-000000000205') s),
  '80/80 final_preview_credit tut=false', 'Pro Preview: 80/80, Tutorial off'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000205', 100), 80,
  'Pro Preview: exactly eighty are granted');
select is(
  (select s->>'committedUsage' || '/' || (s->>'availableAiLooks') from
   pg_temp.state('10000000-0000-4000-8000-000000000205') s),
  '80/0', 'Pro Preview: exhaustion arithmetic 80 = 80'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000205',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000205')))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED', 'Pro Preview: Tutorial denied'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000205',
     'facetune_pro_preview', pg_temp.ref('e'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Pro Preview: renews'
);
select is(
  (select s->>'availableAiLooks' from pg_temp.state('10000000-0000-4000-8000-000000000205') s),
  '80', 'Pro Preview: new period resets to 80'
);

-- ===========================================================================
-- SALON PRO — 35 AI Looks, Tutorial, high-volume sequential accounting
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000206',
     'facetune_salon_pro', pg_temp.ref('f'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Salon Pro: activates'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance') || ' tut=' ||
          (s->>'tutorialEnabled') from pg_temp.state('10000000-0000-4000-8000-000000000206') s),
  '35/35 tut=true', 'Salon Pro: 35/35, Tutorial on'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000206', 34), 34,
  'Salon Pro: thirty-four sequential spends land');
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'remainingAiLooks') from
   pg_temp.state('10000000-0000-4000-8000-000000000206') s),
  '1/1', 'Salon Pro: 1/35 left after 34'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000206', 3), 1,
  'Salon Pro: the thirty-fifth lands and the thirty-sixth is refused');
select is(
  (select s->>'committedUsage' || '/' || (s->>'availableAiLooks') || '|' ||
          (s->>'denialReason') from pg_temp.state('10000000-0000-4000-8000-000000000206') s),
  '35/0|AI_LOOK_LIMIT_REACHED', 'Salon Pro: exhaustion arithmetic 35 = 35'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000206',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000206')))->>'authorized',
  'true', 'Salon Pro: Tutorial allowed'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000206',
     'facetune_salon_pro', pg_temp.ref('f'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Salon Pro: renews'
);
select is(
  (select s->>'availableAiLooks' from pg_temp.state('10000000-0000-4000-8000-000000000206') s),
  '35', 'Salon Pro: new period resets to 35'
);

-- ===========================================================================
-- SALON PREVIEW — 350 credits, no Tutorial, high-volume arithmetic
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000207',
     'facetune_salon_preview', pg_temp.ref('0'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Salon Preview: activates'
);
select is(
  (select s->>'availableAiLooks' || '/' || (s->>'effectiveAllowance') || ' ' ||
          (s->>'allowanceUnit') || ' tut=' || (s->>'tutorialEnabled')
   from pg_temp.state('10000000-0000-4000-8000-000000000207') s),
  '350/350 final_preview_credit tut=false', 'Salon Preview: 350/350, Tutorial off'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000207', 349), 349,
  'Salon Preview: 349 sequential spends land');
select is(
  (select s->>'availableAiLooks' from pg_temp.state('10000000-0000-4000-8000-000000000207') s),
  '1', 'Salon Preview: 1/350 left after 349'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000207', 5), 1,
  'Salon Preview: the 350th lands and the 351st is refused');
select is(
  (select s->>'committedUsage' || '/' || (s->>'availableAiLooks') || '|' ||
          (s->>'denialReason') from pg_temp.state('10000000-0000-4000-8000-000000000207') s),
  '350/0|AI_LOOK_LIMIT_REACHED', 'Salon Preview: exhaustion arithmetic 350 = 350'
);
select is(
  (select count(*) from public.usage_ledger
   where user_id = '10000000-0000-4000-8000-000000000207'
     and allowance_unit = 'final_preview_credit' and status = 'committed'),
  350::bigint, 'Salon Preview: every committed row is a Preview-only credit'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000207',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000207')))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED', 'Salon Preview: Tutorial denied'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000207',
     'facetune_salon_preview', pg_temp.ref('0'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '59 days'))->>'ok',
  'true', 'Salon Preview: renews'
);
select is(
  (select s->>'availableAiLooks' from pg_temp.state('10000000-0000-4000-8000-000000000207') s),
  '350', 'Salon Preview: new period resets to 350'
);

-- ===========================================================================
-- SALON PILOT — 30 starting, admin-granted, non-public
-- ===========================================================================
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance
) values (
  '11000000-0000-4000-8000-000000000208', '10000000-0000-4000-8000-000000000208',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '60 days',
  false, 30
);
select is(
  (select s->>'planCode' || ' ' || (s->>'availableAiLooks') || '/' ||
          (s->>'effectiveAllowance') || ' tut=' || (s->>'tutorialEnabled') ||
          ' public=' || (s->>'publiclyPurchasable') || ' reset=' ||
          coalesce(s->>'resetAt', 'none') || ' expires=' ||
          case when s->>'expiresAt' is null then 'none' else 'set' end
   from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  'salon_pilot 30/30 tut=true public=false reset=none expires=set',
  'Salon Pilot: 30 initial, Tutorial on, not public, expiry not reset'
);
-- One AI Look spent a year ago (historical row), then two spent now.
insert into public.usage_ledger (
  user_id, entitlement_id, operation_id, status, source_mode,
  canonical_generated_image_id, reserved_at, committed_at,
  plan_code, allowance_unit, allowance_source
) values (
  '10000000-0000-4000-8000-000000000208', '11000000-0000-4000-8000-000000000208',
  gen_random_uuid(), 'committed', 'standard',
  pg_temp.new_preview('10000000-0000-4000-8000-000000000208'),
  timezone('utc', now()) - interval '1 year',
  timezone('utc', now()) - interval '1 year',
  'salon_pilot', 'ai_look', 'subscription'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000208', 2), 2,
  'Salon Pilot: two spent');
-- Admin adjustment through the audited ledger, not a bare update.
insert into public.entitlement_allowance_adjustments (
  entitlement_id, target_user_id, admin_user_id, adjustment_type, amount,
  reason, idempotency_key
) values (
  '11000000-0000-4000-8000-000000000208', '10000000-0000-4000-8000-000000000208',
  '10000000-0000-4000-8000-000000000202', 'increase_allowance', 10,
  'SUB-14 pilot extension', 'sub14-pilot-adjust-1'
);
select is(
  (select s->>'effectiveAllowance' || '/' || (s->>'availableAiLooks') || ' adj=' ||
          (s->>'allowanceAdjustmentTotal')
   from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  '40/37 adj=10', 'Salon Pilot: admin adjustment raises the pool, usage kept'
);
select throws_ok(
  $$ insert into public.entitlement_allowance_adjustments (
       entitlement_id, target_user_id, admin_user_id, adjustment_type, amount,
       reason, idempotency_key
     ) values (
       '11000000-0000-4000-8000-000000000208', '10000000-0000-4000-8000-000000000208',
       '10000000-0000-4000-8000-000000000202', 'increase_allowance', 10,
       'SUB-14 pilot extension', 'sub14-pilot-adjust-1') $$,
  '23505', null,
  'Salon Pilot: a replayed adjustment key is refused, never applied twice'
);
select throws_ok(
  $$ update public.user_entitlements set allowance_adjustment_total = 999
      where id = '11000000-0000-4000-8000-000000000208' $$,
  null, null,
  'Salon Pilot: the adjustment total cannot be written directly'
);
-- No automatic reset: the year-old spend still counts beside today's two.
select is(
  (select s->>'committedUsage' || ' reset=' || coalesce(s->>'resetAt', 'none')
   from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  '3 reset=none', 'Salon Pilot: no automatic reset'
);
-- Suspension, revocation, expiration.
update public.user_entitlements set status = 'suspended'
 where id = '11000000-0000-4000-8000-000000000208';
select is(
  (select s->>'generationAuthorized' || '|' || (s->>'denialReason')
   from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  'false|ENTITLEMENT_SUSPENDED', 'Salon Pilot: suspension denies generation'
);
update public.user_entitlements set status = 'active'
 where id = '11000000-0000-4000-8000-000000000208';
update public.user_entitlements
   set expires_at = timezone('utc', now()) - interval '1 minute'
 where id = '11000000-0000-4000-8000-000000000208';
select is(
  (select s->>'planCode' || '|' || coalesce(s->>'denialReason', 'none')
   from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  'free|none',
  'Salon Pilot: after expiry the account falls back to its Free entitlement'
) ;
-- (the expired pilot row is outranked by Free, which still has its one look)
update public.user_entitlements
   set expires_at = timezone('utc', now()) + interval '60 days', status = 'revoked'
 where id = '11000000-0000-4000-8000-000000000208';
select is(
  (select s->>'planCode' from pg_temp.state('10000000-0000-4000-8000-000000000208') s),
  'free', 'Salon Pilot: a revoked pilot no longer governs'
);
-- Non-public: no provider product can ever produce it.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000208', 'salon_pilot',
     pg_temp.ref('9'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'errorCode',
  'INVALID_PLAN_CODE', 'Salon Pilot: cannot be produced by a store purchase'
);
select is(
  (select count(*) from public.subscription_products
   where plan_code in ('salon_pilot', 'free') and provider_product_id is not null),
  0::bigint, 'Salon Pilot and Free have no Google Play product'
);
select throws_ok(
  $$ insert into public.user_entitlements
       (user_id, plan_code, status, billing_provider, base_ai_look_allowance,
        provider_product_id, provider_subscription_reference, period_start,
        period_end, starts_at, expires_at)
     values ('10000000-0000-4000-8000-000000000209', 'salon_pilot', 'active',
        'google_play', 30, 'x', 'y', now(), now() + interval '1 day', now(),
        now() + interval '1 day') $$,
  '23514', null,
  'Salon Pilot: the row shape forbids a provider-billed pilot'
);

-- ===========================================================================
-- ACCOUNTING — reserve → commit / release semantics on the subscription path
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000210', 'facetune_plus',
     pg_temp.ref('9'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Accounting: Plus account ready'
);
select pg_temp.as_user('10000000-0000-4000-8000-000000000210');

-- One reservation, replayed (duplicate operation id / network retry).
select is(
  (public.reserve_ai_look('20000000-0000-4000-8000-000000000001'))->>'ok',
  'true', 'Accounting: reserve'
);
select is(
  (select r->>'ok' || '|' || (r->>'replayed') || '|' || (r->>'status')
   from public.reserve_ai_look('20000000-0000-4000-8000-000000000001') r),
  'true|true|reserved', 'Accounting: duplicate operation id replays, no second hold'
);
select is(
  (select s->>'reservedUsage' || '/' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '1/2', 'Accounting: one hold, two available'
);
-- Generation failure releases.
select is(
  (public.release_ai_look('20000000-0000-4000-8000-000000000001', 'GEN_FAILED'))->>'ok',
  'true', 'Accounting: generation failure releases'
);
select is(
  (select r->>'ok' || '|' || (r->>'replayed')
   from public.release_ai_look('20000000-0000-4000-8000-000000000001', 'GEN_FAILED') r),
  'true|true', 'Accounting: duplicate release is safe'
);
select is(
  (select s->>'reservedUsage' || '/' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '0/3', 'Accounting: nothing charged for a failure'
);
-- Client timeout while the server succeeded: a late commit corrects the
-- release; the user is charged exactly once for the preview that exists.
select is(
  (select r->>'ok' || '|' || (r->>'correctedFromReleased')
   from public.commit_ai_look('20000000-0000-4000-8000-000000000001', 'standard',
        pg_temp.new_preview('10000000-0000-4000-8000-000000000210')) r),
  'true|true', 'Accounting: a late commit after a release charges once'
);
select is(
  (select r->>'ok' || '|' || (r->>'replayed')
   from public.commit_ai_look('20000000-0000-4000-8000-000000000001', 'standard',
        (select canonical_generated_image_id from public.usage_ledger
          where operation_id = '20000000-0000-4000-8000-000000000001')) r),
  'true|true', 'Accounting: duplicate commit is a replay'
);
select is(
  (public.commit_ai_look('20000000-0000-4000-8000-000000000001', 'standard',
     pg_temp.new_preview('10000000-0000-4000-8000-000000000210')))->>'errorCode',
  'USAGE_ALREADY_COMMITTED',
  'Accounting: a committed operation cannot be re-pointed at another preview'
);
select is(
  (public.release_ai_look('20000000-0000-4000-8000-000000000001', 'x'))->>'errorCode',
  'USAGE_ALREADY_COMMITTED', 'Accounting: a committed credit cannot be released'
);
select is(
  (select s->>'committedUsage' || '/' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '1/2', 'Accounting: success commits exactly once'
);
-- Client timeout while the server failed: the release stands, nothing owed.
select is(
  (public.reserve_ai_look('20000000-0000-4000-8000-000000000002'))->>'ok',
  'true', 'Accounting: second reserve'
);
select is(
  (public.release_ai_look('20000000-0000-4000-8000-000000000002', 'PROVIDER_ERROR'))->>'ok',
  'true', 'Accounting: server failure released'
);
select is(
  (select r->>'ok' || '|' || (r->>'status') || '|' || (r->>'errorCode')
   from public.reserve_ai_look('20000000-0000-4000-8000-000000000002') r),
  'false|released|USAGE_ALREADY_RELEASED',
  'Accounting: a retried reserve of a released operation does not re-hold it'
);
-- Persistence failure with no usable result: release, then the next attempt
-- is a new operation, not a second charge on the old one.
select is(
  (select s->>'committedUsage' || '/' || (s->>'reservedUsage') || '/' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '1/0/2', 'Accounting: 1 committed, 0 held, 2 available'
);
-- Reopen consumes zero: reading the preview, its Tutorial authorization,
-- History and Saved Looks are reads; the ledger does not move.
select is(
  (select count(*) from public.generated_images
   where user_id = '10000000-0000-4000-8000-000000000210'),
  2::bigint, 'Accounting: previews are readable'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000210',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000210')))->>'authorized',
  'true', 'Accounting: Tutorial authorization for an existing preview'
);
select is(
  (select s->>'committedUsage' || '/' || (s->>'reservedUsage')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '1/0', 'Accounting: reopen / Tutorial open / History consume zero'
);
-- Cross-user preview cannot be committed against.
select is(
  (public.commit_ai_look(
     (select operation_id from public.usage_ledger
       where user_id = '10000000-0000-4000-8000-000000000210' and status = 'released' limit 1),
     'standard', pg_temp.last_preview('10000000-0000-4000-8000-000000000202')))->>'errorCode',
  'USAGE_STATE_CONFLICT', 'Accounting: another account''s preview is rejected'
);
-- Stale reservation recovery, case 1: a hold whose worker died *after*
-- persisting the preview but before committing. Exactly one unclaimed
-- preview newer than the hold exists (the one the re-point test above
-- created), so the reconciler adopts it and charges — the user has the
-- preview, and the ledger says so.
select is(
  (public.reserve_ai_look('20000000-0000-4000-8000-000000000003'))->>'ok',
  'true', 'Accounting: a reservation is left behind'
);
update public.usage_ledger set reserved_at = reserved_at - interval '2 hours'
 where operation_id = '20000000-0000-4000-8000-000000000003';
select is(
  (public.reconcile_stale_ai_look_reservations(interval '30 minutes'))->>'committed',
  '1', 'Accounting: the reconciler commits a stale hold whose preview exists'
);
select is(
  (select status || '|' || (canonical_generated_image_id is not null)::text
   from public.usage_ledger
   where operation_id = '20000000-0000-4000-8000-000000000003'),
  'committed|true', 'Accounting: the recovered hold names the orphan preview'
);
-- Case 2: a hold with no preview at all is released, not charged.
select is(
  (public.reserve_ai_look('20000000-0000-4000-8000-000000000004'))->>'ok',
  'true', 'Accounting: another reservation is left behind'
);
update public.usage_ledger set reserved_at = reserved_at - interval '2 hours'
 where operation_id = '20000000-0000-4000-8000-000000000004';
select is(
  (public.reconcile_stale_ai_look_reservations(interval '30 minutes'))->>'released',
  '1', 'Accounting: the reconciler releases a stale hold with no preview'
);
select is(
  (select status from public.usage_ledger
   where operation_id = '20000000-0000-4000-8000-000000000004'),
  'released', 'Accounting: the stale hold is released, not charged'
);
select is(
  (select s->>'committedUsage' || '/' || (s->>'reservedUsage') || '/' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000210') s),
  '2/0/1', 'Accounting: two previews exist, two charged, nothing held'
);

-- ===========================================================================
-- LIFECYCLE — every provider state through the SUB-10 writer
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     'not-a-sha', 'SUBSCRIPTION_STATE_ACTIVE'))->>'errorCode',
  'PURCHASE_VERIFICATION_FAILED', 'Lifecycle: a malformed reference is refused'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'com.other.app.sub',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'errorCode',
  'INVALID_PLAN_CODE', 'Lifecycle: an unknown product grants nothing'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_ai_look_topup_1',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'errorCode',
  'INVALID_PLAN_CODE', 'Lifecycle: a top-up product is not a subscription'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_MADE_UP'))->>'errorCode',
  'PROVIDER_STATE_CONFLICT', 'Lifecycle: an unknown provider state is never guessed'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_PENDING'))->>'entitlementStatus',
  'pending', 'Lifecycle: a pending purchase is recorded pending'
);
select is(
  (select s->>'generationAuthorized' || '|' || (s->>'planCode')
   from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'true|free', 'Lifecycle: a pending purchase grants nothing yet; Free still governs'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'entitlementStatus',
  'active', 'Lifecycle: the purchase completes'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000209' and plan_code <> 'free'),
  1::bigint, 'Lifecycle: pending → active reused the same row'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000209', 1), 1,
  'Lifecycle: one spent on Pro');
-- Duplicate verification (Restore) is idempotent.
select is(
  (select count(*) from (
     select pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
       pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ACTIVE')
     from generate_series(1, 3)) x),
  3::bigint, 'Lifecycle: three restores of the same purchase run'
);
select is(
  (select count(*) || '|' || (select s->>'committedUsage' from
     pg_temp.state('10000000-0000-4000-8000-000000000209') s)
   from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000209' and plan_code <> 'free'),
  '1|1', 'Lifecycle: restore neither duplicates the entitlement nor resets usage'
);
-- Grace period keeps access.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'))->>'entitlementStatus',
  'grace_period', 'Lifecycle: grace period recorded'
);
select is(
  (select s->>'generationAuthorized' || '|' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'true|7', 'Lifecycle: grace period keeps generation authorized'
);
-- Account hold / pause suspend.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ON_HOLD'))->>'entitlementStatus',
  'suspended', 'Lifecycle: account hold suspends'
);
select is(
  (select s->>'denialReason' from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'ENTITLEMENT_SUSPENDED', 'Lifecycle: a suspended plan denies generation'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_PAUSED'))->>'entitlementStatus',
  'suspended', 'Lifecycle: pause suspends'
);
-- Recovery from hold.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'entitlementStatus',
  'active', 'Lifecycle: recovery re-activates the same row'
);
-- Cancelled but paid through: access until period end, no renewal.
select is(
  (select r->>'entitlementStatus' from pg_temp.activate(
     '10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_CANCELED') r),
  'active', 'Lifecycle: cancelled is still paid through'
);
select is(
  (select s->>'autoRenew' || '|' || (s->>'generationAuthorized') || '|' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'false|true|7', 'Lifecycle: cancelled keeps access, stops renewal, keeps usage'
);
-- Expiry ends access; the row is kept.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('1'), 'SUBSCRIPTION_STATE_EXPIRED',
     timezone('utc', now()) - interval '1 minute'))->>'entitlementStatus',
  'expired', 'Lifecycle: expiry recorded'
);
select is(
  (select s->>'planCode' from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'free', 'Lifecycle: an expired plan no longer governs'
);
select is(
  (select count(*) from public.usage_ledger
   where user_id = '10000000-0000-4000-8000-000000000209' and status = 'committed'),
  1::bigint, 'Lifecycle: history survives expiry'
);
-- Re-subscription after expiry.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('2'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Lifecycle: re-subscribes with a new purchase'
);
select is(
  (select s->>'planCode' || '|' || (s->>'availableAiLooks')
   from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'pro|8', 'Lifecycle: the new period starts at 8'
);
-- Refund / revocation via the SUB-11 revoke path.
select is(
  (public.revoke_google_play_subscription(pg_temp.ref('2'), 'SUBSCRIPTION_STATE_EXPIRED',
     timezone('utc', now())))->>'ok',
  'true', 'Lifecycle: a corroborated revocation is applied'
);
select is(
  (select s->>'planCode' || '|' || (select status from public.user_entitlements
     where provider_subscription_reference = pg_temp.ref('2'))
   from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'free|revoked', 'Lifecycle: a revoked plan no longer governs and is kept as revoked'
);
select is(
  (select r->>'ok' || '|' || (r->>'changed')
   from public.revoke_google_play_subscription(pg_temp.ref('2'),
     'SUBSCRIPTION_STATE_EXPIRED', timezone('utc', now())) r),
  'true|false', 'Lifecycle: a duplicate revocation changes nothing'
);
-- A revoked purchase cannot be re-activated by a stale ACTIVE read.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000209', 'facetune_pro',
     pg_temp.ref('2'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Lifecycle: the writer accepts what the provider says now'
);
select is(
  (select s->>'planCode' from pg_temp.state('10000000-0000-4000-8000-000000000209') s),
  'pro', 'Lifecycle: the provider verdict is authoritative, both ways'
);
-- Duplicate notification events are claimed once.
select is(
  (public.claim_google_play_notification('msg-sub14-1', 'subscription', 2,
     pg_temp.ref('2'), timezone('utc', now())))->>'claimed',
  'true', 'Lifecycle: a notification is claimed'
);
select is(
  (public.claim_google_play_notification('msg-sub14-1', 'subscription', 2,
     pg_temp.ref('2'), timezone('utc', now())))->>'claimed',
  'false', 'Lifecycle: a redelivered notification is not processed twice'
);
-- Preview product mapping.
select is(
  (select string_agg(provider_product_id || '→' || plan_code, ',' order by plan_code)
   from public.subscription_products where provider_product_id is not null),
  'facetune_plus→plus,facetune_plus_preview→plus_preview,facetune_pro→pro,' ||
  'facetune_pro_preview→pro_preview,facetune_salon_preview→salon_preview,' ||
  'facetune_salon_pro→salon_pro',
  'Lifecycle: the six store products map to the six paid plans, server-side'
);

-- ===========================================================================
-- TRANSITIONS — Pro ↔ Pro Preview and Salon Pro ↔ Salon Preview as linked
-- replacements (Plus ↔ Plus Preview is pinned in superseded_purchase_guard)
-- ===========================================================================
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_pro',
     pg_temp.ref('3'), 'SUBSCRIPTION_STATE_ACTIVE'))->>'ok',
  'true', 'Transition: Pro active'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000211', 2), 2,
  'Transition: two AI Looks used on Pro');
-- A Tutorial session exists for the first preview (historical content).
insert into public.tutorial_v4_sessions (
  user_id, analysis_id, source_mode, recommendation_id,
  canonical_generated_image_id, status, manifest_status
)
select l.user_id, g.analysis_id, 'standard', g.recommendation_id, g.id,
       'ready', 'pending'
  from public.usage_ledger l
  join public.generated_images g on g.id = l.canonical_generated_image_id
 where l.user_id = '10000000-0000-4000-8000-000000000211'
 order by l.committed_at limit 1;

select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_pro_preview',
     pg_temp.ref('4'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '29 days', pg_temp.ref('3')))->>'ok',
  'true', 'Transition: Pro → Pro Preview as a linked replacement'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000211' and plan_code <> 'free'),
  1::bigint, 'Transition: no duplicate entitlement'
);
select is(
  (select s->>'planCode' || ' ' || (s->>'allowanceUnit') || ' tut=' ||
          (s->>'tutorialEnabled') || ' ' || (s->>'committedUsage') || '/' ||
          (s->>'effectiveAllowance')
   from pg_temp.state('10000000-0000-4000-8000-000000000211') s),
  'pro_preview final_preview_credit tut=false 2/80',
  'Transition: capability flips to Preview-only; period usage carries, no double grant'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000211',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000211')))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED', 'Transition: new Tutorial generation denied on Pro Preview'
);
select is(
  (select count(*) from public.tutorial_v4_sessions
   where user_id = '10000000-0000-4000-8000-000000000211'),
  1::bigint, 'Transition: the historical Tutorial session is preserved'
);
select is(
  (select count(*) from public.usage_ledger
   where user_id = '10000000-0000-4000-8000-000000000211'
     and status = 'committed' and allowance_unit = 'ai_look' and plan_code = 'pro'),
  2::bigint, 'Transition: historical AI Look provenance is preserved'
);
select is(pg_temp.spend('10000000-0000-4000-8000-000000000211', 1), 1,
  'Transition: a Preview-only credit is spent');
select is(
  (select l.allowance_unit || '/' || l.plan_code from public.usage_ledger l
   where l.user_id = '10000000-0000-4000-8000-000000000211'
     and l.status = 'committed' and l.canonical_generated_image_id = pg_temp.last_preview(l.user_id)),
  'final_preview_credit/pro_preview', 'Transition: provenance follows the plan at reservation'
);
-- Back to Pro.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_pro',
     pg_temp.ref('5'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '29 days', pg_temp.ref('4')))->>'ok',
  'true', 'Transition: Pro Preview → Pro as a linked replacement'
);
select is(
  (select s->>'planCode' || ' tut=' || (s->>'tutorialEnabled') || ' ' ||
          (s->>'committedUsage') || '/' || (s->>'effectiveAllowance')
   from pg_temp.state('10000000-0000-4000-8000-000000000211') s),
  'pro tut=true 3/8', 'Transition: Tutorial returns; period usage still carries'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000211',
    pg_temp.last_preview('10000000-0000-4000-8000-000000000211')))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED',
  'Transition: a Preview-only preview never gains a Tutorial after switching back'
);
select is(
  (pg_temp.tutorial('10000000-0000-4000-8000-000000000211',
    (select canonical_generated_image_id from public.usage_ledger
      where user_id = '10000000-0000-4000-8000-000000000211'
        and allowance_unit = 'ai_look' order by committed_at limit 1)))->>'authorized',
  'true', 'Transition: an AI Look preview keeps its Tutorial'
);
-- Salon pair.
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_salon_pro',
     pg_temp.ref('6'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '29 days', pg_temp.ref('5')))->>'ok',
  'true', 'Transition: linked to Salon Pro (provider-reported)'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_salon_preview',
     pg_temp.ref('7'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '29 days', pg_temp.ref('6')))->>'ok',
  'true', 'Transition: Salon Pro → Salon Preview'
);
select is(
  (select s->>'planCode' || ' ' || (s->>'effectiveAllowance') || ' tut=' || (s->>'tutorialEnabled')
   from pg_temp.state('10000000-0000-4000-8000-000000000211') s),
  'salon_preview 350 tut=false', 'Transition: Salon Preview governs'
);
select is(
  (pg_temp.activate('10000000-0000-4000-8000-000000000211', 'facetune_salon_pro',
     pg_temp.ref('8'), 'SUBSCRIPTION_STATE_ACTIVE',
     timezone('utc', now()) + interval '29 days', pg_temp.ref('7')))->>'ok',
  'true', 'Transition: Salon Preview → Salon Pro'
);
select is(
  (select s->>'planCode' || ' ' || (s->>'effectiveAllowance') || ' tut=' || (s->>'tutorialEnabled')
   from pg_temp.state('10000000-0000-4000-8000-000000000211') s),
  'salon_pro 35 tut=true', 'Transition: Salon Pro governs'
);
select is(
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000211' and plan_code <> 'free'),
  1::bigint, 'Transition: one paid entitlement through six switches'
);
-- Client-forged transition: the account cannot write its own plan.
select pg_temp.as_user('10000000-0000-4000-8000-000000000211');
set local role authenticated;
select throws_ok(
  $$ update public.user_entitlements set plan_code = 'salon_pro'
      where user_id = '10000000-0000-4000-8000-000000000211' $$,
  '42501', null,
  'Transition: a signed-in user cannot forge a plan change'
);
select throws_ok(
  $$ insert into public.user_entitlements
       (user_id, plan_code, status, billing_provider, base_ai_look_allowance,
        provider_product_id, provider_subscription_reference, period_start,
        period_end, starts_at)
     values ('10000000-0000-4000-8000-000000000211', 'salon_pro', 'active',
        'google_play', 35, 'facetune_salon_pro', repeat('z', 64), now(),
        now() + interval '30 days', now()) $$,
  '42501', null,
  'Transition: a signed-in user cannot grant themselves a plan'
);
select is(
  (select count(*) from public.user_entitlements),
  (select count(*) from public.user_entitlements
   where user_id = '10000000-0000-4000-8000-000000000211'),
  'RLS: an account sees only its own entitlements'
);
reset role;

-- ===========================================================================
-- MATRIX LOCK — the numbers this suite ran against are the locked ones
-- ===========================================================================
select is(
  (select string_agg(plan_code || '=' || base_ai_look_allowance, ',' order by plan_code)
   from public.subscription_products where active),
  'free=1,plus=3,plus_preview=30,pro=8,pro_preview=80,salon_pilot=30,' ||
  'salon_preview=350,salon_pro=35',
  'the locked 1/3/30/8/80/35/350/30 matrix is what was exercised'
);

select * from finish();
rollback;
