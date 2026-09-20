-- SUB-13B — purchased top-up credits.
--
-- Proves, against the real schema and functions, that a purchased credit is
-- granted exactly once from verified provider facts, is spent only after the
-- subscription's own allowance and only under an eligible paid plan, keeps
-- its capability class through every plan change, and survives renewal,
-- cancellation and expiry untouched. Everything runs in one transaction and
-- is rolled back.
begin;

select plan(103);

-- ---------------------------------------------------------------------------
-- Schema, privileges, and locks
-- ---------------------------------------------------------------------------

select ok(
  (select relrowsecurity from pg_class
   where oid = 'public.purchased_credit_grants'::regclass),
  'purchased_credit_grants has RLS enabled'
);

select is(
  has_table_privilege('authenticated', 'public.purchased_credit_grants', 'INSERT'),
  false,
  'authenticated cannot insert a grant'
);
select is(
  has_table_privilege('authenticated', 'public.purchased_credit_grants', 'UPDATE'),
  false,
  'authenticated cannot update a grant'
);
select is(
  has_table_privilege('authenticated', 'public.purchased_credit_grants', 'DELETE'),
  false,
  'authenticated cannot delete a grant'
);
select is(
  has_table_privilege('anon', 'public.purchased_credit_grants', 'SELECT'),
  false,
  'anonymous callers cannot read grants'
);
select is(
  has_column_privilege(
    'authenticated', 'public.purchased_credit_grants', 'purchase_reference',
    'SELECT'
  ),
  false,
  'the purchase reference is withheld from the owner'
);

select is(
  (select has_function_privilege('authenticated', p.oid, 'EXECUTE')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'grant_verified_top_up_purchase'),
  false,
  'authenticated cannot execute the grant writer'
);
select is(
  (select has_function_privilege('service_role', p.oid, 'EXECUTE')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'grant_verified_top_up_purchase'),
  true,
  'only the server role executes the grant writer'
);
select is(
  (select has_function_privilege('authenticated', p.oid, 'EXECUTE')
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'mark_top_up_purchase_consumed'),
  false,
  'authenticated cannot mark a purchase consumed'
);

select is(
  (select pg_get_function_identity_arguments(p.oid)
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname = 'grant_verified_top_up_purchase'),
  'p_user_id uuid, p_provider_product_id text, p_purchase_reference text, '
  'p_purchase_state text, p_provider_order_id text, p_test_purchase boolean',
  'quantity, class, and pack are not arguments: the server mapping decides'
);

select is(
  (select jsonb_object_agg(
     pack_code,
     jsonb_build_array(provider_product_id, credit_class, quantity,
                       to_jsonb(eligible_plan_codes))
   ) from public.top_up_packs where active),
  '{
    "extra_ai_look": ["facetune_ai_look_topup_1", "tutorial_capable_ai_look", 1,
                      ["plus", "pro", "salon_pro"]],
    "preview_boost": ["facetune_preview_credit_topup_10", "preview_only_final_preview", 10,
                      ["plus_preview", "pro_preview", "salon_preview"]]
  }'::jsonb,
  'the approved V1 top-up matrix is the only one configured'
);

select is(
  (select jsonb_object_agg(
     plan_code,
     jsonb_build_array(base_ai_look_allowance, allowance_unit, tutorial_enabled,
                       publicly_purchasable)
   ) from public.subscription_products),
  '{
    "free": [1, "ai_look", true, false],
    "plus": [3, "ai_look", true, true],
    "plus_preview": [30, "final_preview_credit", false, true],
    "pro": [8, "ai_look", true, true],
    "pro_preview": [80, "final_preview_credit", false, true],
    "salon_pro": [35, "ai_look", true, true],
    "salon_preview": [350, "final_preview_credit", false, true],
    "salon_pilot": [30, "ai_look", true, false]
  }'::jsonb,
  'the locked subscription matrix is unchanged'
);

select is(
  (select count(*)::integer
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in (
       'activate_verified_google_play_subscription',
       'revoke_google_play_subscription',
       'claim_google_play_notification',
       'finalize_google_play_notification',
       'google_play_purchase_owner',
       'commit_ai_look',
       'release_ai_look',
       'authorize_tutorial_generation'
     )
     and pg_get_functiondef(p.oid) ilike '%purchased_credit%'),
  0,
  'the subscription lifecycle, commit/release, and Tutorial authority do not depend on the credit ledger'
);

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
--
-- Four accounts. Each receives its lifetime Free entitlement from the
-- provisioning trigger; the paid ones get a store entitlement on top.
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
  ('10000000-0000-4000-8000-000000000131'::uuid, 'sub13b-plus@example.invalid'),
  ('10000000-0000-4000-8000-000000000132'::uuid, 'sub13b-free@example.invalid'),
  ('10000000-0000-4000-8000-000000000133'::uuid, 'sub13b-preview@example.invalid'),
  ('10000000-0000-4000-8000-000000000134'::uuid, 'sub13b-pilot@example.invalid')
) as v(id, email);

-- Plus (Tutorial-enabled, 3 AI Looks), current period.
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, provider_product_id,
  provider_subscription_reference, period_start, period_end, starts_at,
  auto_renew, base_ai_look_allowance, verified_at
) values (
  '11000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131',
  'plus', 'active', 'google_play', 'facetune_plus',
  repeat('ab', 32),
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days',
  timezone('utc', now()) - interval '1 day',
  true, 3, timezone('utc', now())
);

-- Plus Preview (Preview-only, 30 credits), current period.
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, provider_product_id,
  provider_subscription_reference, period_start, period_end, starts_at,
  auto_renew, base_ai_look_allowance, verified_at
) values (
  '11000000-0000-4000-8000-000000000133',
  '10000000-0000-4000-8000-000000000133',
  'plus_preview', 'active', 'google_play', 'facetune_plus_preview',
  repeat('cd', 32),
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days',
  timezone('utc', now()) - interval '1 day',
  true, 30, timezone('utc', now())
);

-- Salon Pilot (admin-granted research access).
insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, starts_at, expires_at,
  auto_renew, base_ai_look_allowance
) values (
  '11000000-0000-4000-8000-000000000134',
  '10000000-0000-4000-8000-000000000134',
  'salon_pilot', 'active', 'admin_granted',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '60 days',
  false, 30
);

-- A previewable analysis + recommendation for the Plus account, so commits
-- can name a real persisted preview.
insert into public.analyses (id, user_id, original_image_path) values (
  '40000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131/analyses/40000000-0000-4000-8000-000000000131/original/selfie.jpg'
);
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
values (
  '41000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131',
  '40000000-0000-4000-8000-000000000131',
  'natural'
);

-- ---------------------------------------------------------------------------
-- Granting: eligibility, product mapping, provider state, replay, ownership
-- ---------------------------------------------------------------------------

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000132', 'facetune_ai_look_topup_1',
    repeat('1', 64), 'PURCHASED'
  ))->>'errorCode',
  'TOP_UP_NOT_ELIGIBLE',
  'Free cannot buy a top-up'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000134', 'facetune_preview_credit_topup_10',
    repeat('2', 64), 'PURCHASED'
  ))->>'errorCode',
  'TOP_UP_NOT_ELIGIBLE',
  'Salon Pilot cannot buy a top-up'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_plus',
    repeat('3', 64), 'PURCHASED'
  ))->>'errorCode',
  'INVALID_TOP_UP_PRODUCT',
  'a subscription product is not a top-up pack'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
    repeat('4', 64), 'PENDING'
  ))->>'errorCode',
  'TOP_UP_PENDING',
  'a pending purchase grants nothing yet'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
    repeat('5', 64), 'CANCELLED'
  ))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'a cancelled purchase is refused'
);

select is(
  (select count(*)::integer from public.purchased_credit_grants),
  0,
  'no refused purchase left a grant behind'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
    repeat('a', 64), 'PURCHASED', 'GPA.1111-2222-3333-44444'
  )) - 'grantId' - 'grantedAt',
  '{"ok": true, "replayed": false, "packCode": "extra_ai_look",
    "creditClass": "tutorial_capable_ai_look", "quantityGranted": 1,
    "providerConsumed": false}'::jsonb,
  'a verified Extra AI Look purchase grants exactly one Tutorial-capable credit'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
    repeat('a', 64), 'PURCHASED', 'GPA.1111-2222-3333-44444'
  ))->>'replayed',
  'true',
  'verifying the same purchase again replays the grant'
);

select is(
  (select count(*)::integer from public.purchased_credit_grants
   where purchase_reference = repeat('a', 64)),
  1,
  'a replayed purchase grants zero additional credits'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000133', 'facetune_ai_look_topup_1',
    repeat('a', 64), 'PURCHASED'
  ))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'a purchase bound to another account is refused'
);

select throws_ok(
  $$insert into public.purchased_credit_grants (
      user_id, provider_product_id, pack_code, credit_class, quantity_granted,
      purchase_reference, purchase_state
    ) values (
      '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
      'extra_ai_look', 'tutorial_capable_ai_look', 1, repeat('a', 64),
      'PURCHASED'
    )$$,
  '23505',
  null,
  'the unique purchase reference decides any race the lock did not'
);

select throws_ok(
  $$insert into public.purchased_credit_grants (
      user_id, provider_product_id, pack_code, credit_class, quantity_granted,
      purchase_reference, purchase_state
    ) values (
      '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
      'extra_ai_look', 'tutorial_capable_ai_look', 5, repeat('b', 64),
      'PURCHASED'
    )$$,
  'P0001',
  'purchased_credit_grants must match the approved top-up pack matrix',
  'the table refuses a quantity that disagrees with the locked pack matrix'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000133', 'facetune_ai_look_topup_1',
    repeat('c', 64), 'PURCHASED'
  ))->>'errorCode',
  'TOP_UP_NOT_ELIGIBLE',
  'a Preview-only plan cannot buy a Tutorial-capable pack it could never spend'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000133', 'facetune_preview_credit_topup_10',
    repeat('d', 64), 'PURCHASED'
  ))->>'quantityGranted',
  '10',
  'a Preview-only plan can buy Preview Boost'
);

select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_preview_credit_topup_10',
    repeat('e', 64), 'PURCHASED'
  ))->>'errorCode',
  'TOP_UP_NOT_ELIGIBLE',
  'a Tutorial plan cannot buy Preview Boost: purchase eligibility is exact'
);

-- A Preview Boost this account bought earlier, while on a Preview-only plan,
-- and then carried into Plus. Written directly, as the grant writer would
-- have written it then, so the consumption rules below can be proven for a
-- Preview-only credit under a Tutorial plan.
insert into public.purchased_credit_grants (
  user_id, provider_product_id, pack_code, credit_class, quantity_granted,
  purchase_reference, purchase_state, granted_under_plan_code
) values (
  '10000000-0000-4000-8000-000000000131', 'facetune_preview_credit_topup_10',
  'preview_boost', 'preview_only_final_preview', 10, repeat('e', 64),
  'PURCHASED', 'plus_preview'
);

select is(
  (select concat_ws('|', granted_under_plan_code, provider_order_id,
                    purchase_state, test_purchase)
   from public.purchased_credit_grants where purchase_reference = repeat('a', 64)),
  'plus|GPA.1111-2222-3333-44444|PURCHASED|f',
  'a grant records the plan it was bought under and the provider order'
);

select is(
  public.mark_top_up_purchase_consumed(
    '10000000-0000-4000-8000-000000000131', repeat('a', 64)
  ),
  true,
  'the server can record provider consumption'
);
select is(
  public.mark_top_up_purchase_consumed(
    '10000000-0000-4000-8000-000000000131', repeat('a', 64)
  ),
  true,
  'recording consumption again is idempotent'
);
select is(
  public.mark_top_up_purchase_consumed(
    '10000000-0000-4000-8000-000000000133', repeat('a', 64)
  ),
  false,
  'another account cannot mark a grant consumed'
);

select throws_ok(
  $$update public.purchased_credit_grants
      set quantity_granted = 50 where purchase_reference = repeat('a', 64)$$,
  'P0001',
  'purchased_credit_grants rows are immutable except for provider consumption and a single revocation',
  'a granted quantity can never be rewritten'
);
select throws_ok(
  $$delete from public.purchased_credit_grants
      where purchase_reference = repeat('a', 64)$$,
  'P0001',
  'purchased_credit_grants rows cannot be deleted',
  'a grant can never be deleted directly'
);

-- ---------------------------------------------------------------------------
-- Spending, as the Plus account: subscription first, then purchased credits
-- ---------------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (select public.resolve_subscription_state()) - 'resolvedAt' - 'verifiedAt'
    - 'periodStart' - 'periodEnd' - 'startsAt' - 'resetAt' - 'entitlementId'
    - 'expiresAt' - 'planDisplayName' - 'providerProductId',
  '{"hasEntitlement": true, "planCode": "plus", "entitlementStatus": "active",
    "billingProvider": "google_play", "publiclyPurchasable": true,
    "allowanceUnit": "ai_look", "tutorialEnabled": true,
    "finalPreviewEnabled": true, "autoRenew": true,
    "resetPolicy": "billing_period", "baseAllowance": 3,
    "allowanceAdjustmentTotal": 0, "effectiveAllowance": 3,
    "committedUsage": 0, "reservedUsage": 0, "availableAiLooks": 3,
    "remainingAiLooks": 3, "generationAuthorized": true,
    "denialReason": null, "purchasedTutorialCreditsRemaining": 1,
    "purchasedPreviewCreditsRemaining": 10, "purchasedCreditsUsable": true,
    "availablePurchasedCredits": 11, "nextAllowanceSource": "subscription",
    "nextAllowanceUnit": "ai_look"}'::jsonb,
  'the resolver reports both buckets and that the subscription is spent first'
);

select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000001'))->>'allowanceSource',
  'subscription',
  'the first reservation draws from the subscription'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000002'))->>'allowanceSource',
  'subscription',
  'the second reservation draws from the subscription'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000003'))->>'allowanceSource',
  'subscription',
  'the third reservation draws from the subscription'
);

select is(
  (select jsonb_build_array(
     s->>'availableAiLooks', s->>'generationAuthorized',
     s->>'nextAllowanceSource', s->>'nextAllowanceUnit',
     s->>'availablePurchasedCredits')
   from public.resolve_subscription_state() as s),
  '["0", "true", "purchased_credit", "ai_look", "11"]'::jsonb,
  'with the included allowance held, the next reservation is a Tutorial-capable purchased credit'
);

select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000004'))->>'allowanceSource',
  'purchased_credit',
  'the fourth reservation draws from a purchased credit'
);

select is(
  (select concat_ws('|', l.allowance_source, l.allowance_unit, l.plan_code,
                    g.pack_code, l.period_start is null)
   from public.usage_ledger as l
   join public.purchased_credit_grants as g on g.id = l.purchased_credit_grant_id
   where l.operation_id = '30000000-0000-4000-8000-000000000004'),
  'purchased_credit|ai_look|plus|extra_ai_look|t',
  'a purchased-credit reservation names its grant, keeps the credit class as its unit, and has no period'
);

select is(
  (select jsonb_build_array(
     s->>'committedUsage', s->>'reservedUsage', s->>'availableAiLooks',
     s->>'purchasedTutorialCreditsRemaining', s->>'availablePurchasedCredits',
     s->>'nextAllowanceUnit')
   from public.resolve_subscription_state() as s),
  '["0", "3", "0", "1", "10", "final_preview_credit"]'::jsonb,
  'a purchased-credit hold does not count against the subscription, and the next credit is Preview-only'
);

select is(
  (public.release_ai_look('30000000-0000-4000-8000-000000000004', 'generation_failed'))->>'status',
  'released',
  'a failed generation releases the purchased-credit reservation'
);
select is(
  (select jsonb_build_array(
     s->>'purchasedTutorialCreditsRemaining', s->>'availablePurchasedCredits',
     s->>'nextAllowanceUnit')
   from public.resolve_subscription_state() as s),
  '["1", "11", "ai_look"]'::jsonb,
  'the released credit is available again, without any balance being incremented'
);

select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000005'))->>'allowanceSource',
  'purchased_credit',
  'the credit is reserved again by a new operation'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000005'))->>'replayed',
  'true',
  'replaying the same operation does not take a second credit'
);

reset role;
insert into public.generated_images (
  id, user_id, analysis_id, recommendation_id, storage_path, generation_number
) values (
  '42000000-0000-4000-8000-000000000005',
  '10000000-0000-4000-8000-000000000131',
  '40000000-0000-4000-8000-000000000131',
  '41000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131/analyses/40000000-0000-4000-8000-000000000131/generated/41000000-0000-4000-8000-000000000131/preview_0005.png',
  5
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;

select is(
  (public.commit_ai_look(
    '30000000-0000-4000-8000-000000000005', 'standard',
    '42000000-0000-4000-8000-000000000005'
  ))->>'status',
  'committed',
  'a persisted preview commits the purchased-credit reservation'
);
select is(
  (public.commit_ai_look(
    '30000000-0000-4000-8000-000000000005', 'standard',
    '42000000-0000-4000-8000-000000000005'
  ))->>'replayed',
  'true',
  'committing the same operation again is a replay, not a second spend'
);
select is(
  (public.release_ai_look('30000000-0000-4000-8000-000000000005'))->>'errorCode',
  'USAGE_ALREADY_COMMITTED',
  'a committed purchased credit can never be released back'
);

select is(
  (select jsonb_build_array(
     s->>'purchasedTutorialCreditsRemaining',
     s->>'purchasedPreviewCreditsRemaining', s->>'availablePurchasedCredits',
     s->>'committedUsage', s->>'remainingAiLooks')
   from public.resolve_subscription_state() as s),
  '["0", "10", "10", "0", "3"]'::jsonb,
  'the committed credit is spent exactly once and the subscription figures are untouched'
);

-- The committed preview was paid for by a Tutorial-capable credit, so the
-- Tutorial authority grants it exactly as it would a subscription AI Look.
select is(
  (public.authorize_tutorial_generation(
    'standard', '42000000-0000-4000-8000-000000000005'
  ))->>'authorized',
  'true',
  'a preview paid for by a Tutorial-capable credit may have its Tutorial'
);

-- Spend the ten Preview-only credits down to prove the exhausted refusal.
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000006'))->>'allowanceSource',
  'purchased_credit',
  'with the Tutorial-capable credit spent, Preview-only credits are next'
);
select is(
  (select l.allowance_unit from public.usage_ledger as l
   where l.operation_id = '30000000-0000-4000-8000-000000000006'),
  'final_preview_credit',
  'a Preview-only credit spent under a Tutorial plan is still Preview-only'
);

reset role;
insert into public.generated_images (
  id, user_id, analysis_id, recommendation_id, storage_path, generation_number
) values (
  '42000000-0000-4000-8000-000000000006',
  '10000000-0000-4000-8000-000000000131',
  '40000000-0000-4000-8000-000000000131',
  '41000000-0000-4000-8000-000000000131',
  '10000000-0000-4000-8000-000000000131/analyses/40000000-0000-4000-8000-000000000131/generated/41000000-0000-4000-8000-000000000131/preview_0006.png',
  6
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (public.commit_ai_look(
    '30000000-0000-4000-8000-000000000006', 'standard',
    '42000000-0000-4000-8000-000000000006'
  ))->>'status',
  'committed',
  'the Preview-only credit commits'
);
select is(
  (public.authorize_tutorial_generation(
    'standard', '42000000-0000-4000-8000-000000000006'
  ))->>'denialReason',
  'TUTORIAL_NOT_INCLUDED',
  'a preview paid for by a Preview-only credit never gets a Tutorial, even on a Tutorial plan'
);

-- Nine more holds exhaust the Preview Boost; the tenth attempt is refused.
select is(
  (select count(*)::integer from (
     select (public.reserve_ai_look(
       ('30000000-0000-4000-8000-00000000001' || n)::uuid))->>'ok' as ok
     from generate_series(0, 8) as n
   ) as r where r.ok = 'true'),
  9,
  'the remaining nine Preview-only credits can each be held once'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000099'))->>'errorCode',
  'AI_LOOK_LIMIT_REACHED',
  'with both buckets held, the last purchased credit cannot be double-spent'
);
select is(
  (select jsonb_build_array(
     s->>'generationAuthorized', s->>'denialReason',
     s->>'availablePurchasedCredits', s->>'purchasedPreviewCreditsRemaining')
   from public.resolve_subscription_state() as s),
  '["false", "AI_LOOK_LIMIT_REACHED", "0", "9"]'::jsonb,
  'the resolver refuses on capacity while still reporting the held credits as remaining'
);

reset role;

-- ---------------------------------------------------------------------------
-- Renewal, cancellation, expiry, re-subscription: storage is untouched
-- ---------------------------------------------------------------------------

-- Renewal: the SUB-10 activation writer re-plans the same entitlement for a
-- new period. The subscription allowance resets; the credits do not move.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000131', 'facetune_plus',
    repeat('ab', 32), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '31 days',
    timezone('utc', now()) + interval '59 days',
    true
  ))->>'ok',
  'true',
  'a renewal activates through the unchanged SUB-10 writer'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'purchasedTutorialCreditsRemaining',
     s->>'purchasedPreviewCreditsRemaining')
   from public.resolve_subscription_state() as s),
  '["0", "9"]'::jsonb,
  'renewal neither resets nor deletes purchased credits'
);
select is(
  (select count(*)::integer from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000131'),
  2,
  'renewal does not turn purchased credits into included allowance'
);
reset role;

-- Cancellation: auto-renew off, period still running.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000131', 'facetune_plus',
    repeat('ab', 32), 'SUBSCRIPTION_STATE_CANCELED',
    timezone('utc', now()) - interval '31 days',
    timezone('utc', now()) + interval '59 days',
    false
  ))->>'ok',
  'true',
  'a cancellation is recorded through the unchanged SUB-10 writer'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'purchasedPreviewCreditsRemaining', s->>'purchasedCreditsUsable')
   from public.resolve_subscription_state() as s),
  '["9", "true"]'::jsonb,
  'cancellation preserves stored credits and, while the period runs, their use'
);
reset role;

-- Expiry: the period ends. Free governs; the credits wait.
update public.user_entitlements
   set period_start = timezone('utc', now()) - interval '40 days',
       period_end = timezone('utc', now()) - interval '10 days',
       status = 'expired'
 where id = '11000000-0000-4000-8000-000000000131';

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'planCode', s->>'purchasedPreviewCreditsRemaining',
     s->>'purchasedCreditsUsable', s->>'availablePurchasedCredits',
     s->>'nextAllowanceSource')
   from public.resolve_subscription_state() as s),
  '["free", "9", "false", "0", "subscription"]'::jsonb,
  'after expiry the credits are stored but not spendable, and Free spends only its own AI Look'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000041'))->>'allowanceSource',
  'subscription',
  'Free spends its complimentary AI Look, never a stored paid credit'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-000000000042'))->>'errorCode',
  'AI_LOOK_LIMIT_REACHED',
  'Free cannot reach the stored credits once its own allowance is held'
);
reset role;

-- Re-subscription: a new purchase of a Tutorial plan makes the preserved
-- credits spendable again without minting any.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000131', 'facetune_pro',
    repeat('9', 64), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '30 days',
    true
  ))->>'ok',
  'true',
  're-subscribing activates through the unchanged SUB-10 writer'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'planCode', s->>'availableAiLooks',
     s->>'purchasedPreviewCreditsRemaining', s->>'purchasedCreditsUsable',
     s->>'availablePurchasedCredits')
   from public.resolve_subscription_state() as s),
  '["pro", "8", "9", "true", "0"]'::jsonb,
  're-subscription restores eligibility; the held credits are neither duplicated nor freed'
);
reset role;

-- ---------------------------------------------------------------------------
-- Capability provenance across plan changes
-- ---------------------------------------------------------------------------

-- The Plus Preview account's Preview Boost stays Preview-only after an
-- upgrade to a Tutorial plan.
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000133', 'facetune_plus',
    repeat('8', 64), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '30 days',
    true, repeat('cd', 32)
  ))->>'ok',
  'true',
  'the Preview-only account upgrades to Plus'
);
select is(
  (select credit_class from public.purchased_credit_grants
   where purchase_reference = repeat('d', 64)),
  'preview_only_final_preview',
  'the upgrade does not rewrite the stored credit class'
);

-- Spend Plus's three included AI Looks, then prove the next unit is a
-- Preview-only credit.
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000133","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::integer from (
     select (public.reserve_ai_look(
       ('30000000-0000-4000-8000-00000000005' || n)::uuid))->>'allowanceSource' as src
     from generate_series(0, 2) as n
   ) as r where r.src = 'subscription'),
  3,
  'the upgraded plan spends its own three AI Looks first'
);
select is(
  (select jsonb_build_array(s->>'nextAllowanceSource', s->>'nextAllowanceUnit')
   from public.resolve_subscription_state() as s),
  '["purchased_credit", "final_preview_credit"]'::jsonb,
  'a Preview-only credit never becomes Tutorial-capable on a Tutorial plan'
);
reset role;

-- A Tutorial-capable credit under a Preview-only plan is preserved, not
-- spent: downgrade the Plus account (which holds none now) after granting it
-- one, then prove the resolver will not offer it.
select is(
  (public.grant_verified_top_up_purchase(
    '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
    repeat('7', 64), 'PURCHASED'
  ))->>'quantityGranted',
  '1',
  'the Pro account buys a second Tutorial-capable credit'
);
select is(
  (public.activate_verified_google_play_subscription(
    '10000000-0000-4000-8000-000000000131', 'facetune_pro_preview',
    repeat('6', 64), 'SUBSCRIPTION_STATE_ACTIVE',
    timezone('utc', now()) - interval '1 hour',
    timezone('utc', now()) + interval '30 days',
    true, repeat('9', 64)
  ))->>'ok',
  'true',
  'the account switches to Pro Preview'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'planCode', s->>'tutorialEnabled',
     s->>'purchasedTutorialCreditsRemaining', s->>'availablePurchasedCredits')
   from public.resolve_subscription_state() as s),
  '["pro_preview", "false", "1", "0"]'::jsonb,
  'a Tutorial-capable credit is preserved, not offered, under a Preview-only plan'
);
select is(
  (select count(*)::integer from (
     select (public.reserve_ai_look(
       ('30000000-0000-4000-8000-0000000000' || lpad(n::text, 2, '0'))::uuid
     ))->>'allowanceSource' as src
     from generate_series(60, 79) as n
   ) as r where r.src = 'purchased_credit'),
  0,
  'eighty holds on Pro Preview never touch the Tutorial-capable credit'
);
reset role;
select is(
  (select count(*)::integer from public.usage_ledger as l
   join public.purchased_credit_grants as g on g.id = l.purchased_credit_grant_id
   where g.purchase_reference = repeat('7', 64)),
  0,
  'the preserved credit has no ledger rows at all'
);

-- ---------------------------------------------------------------------------
-- Salon Pilot administrative adjustments remain a separate bucket
-- ---------------------------------------------------------------------------
insert into public.entitlement_allowance_adjustments (
  entitlement_id, target_user_id, admin_user_id, adjustment_type, amount,
  reason, idempotency_key
) values (
  '11000000-0000-4000-8000-000000000134',
  '10000000-0000-4000-8000-000000000134',
  '10000000-0000-4000-8000-000000000131',
  'increase_allowance', 5, 'SUB-13B test adjustment', 'sub13b-adjust-1'
);
select is(
  (select allowance_adjustment_total from public.user_entitlements
   where id = '11000000-0000-4000-8000-000000000134'),
  5,
  'an admin adjustment moves the administrative bucket'
);
select is(
  (select count(*)::integer from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000134'),
  0,
  'an admin adjustment creates no purchased credit'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000134","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'effectiveAllowance', s->>'purchasedCreditsUsable',
     s->>'purchasedTutorialCreditsRemaining')
   from public.resolve_subscription_state() as s),
  '["35", "false", "0"]'::jsonb,
  'Salon Pilot sees its adjusted allowance and no purchased-credit eligibility'
);
reset role;

-- ---------------------------------------------------------------------------
-- Refund / void: unused credits revoked, consumed history kept, never negative
-- ---------------------------------------------------------------------------
--
-- The Plus-Preview-turned-Plus account holds a Preview Boost (10) with three
-- subscription holds already taken. Spend three credits from the grant, then
-- have the provider void the purchase.
insert into public.analyses (id, user_id, original_image_path) values (
  '40000000-0000-4000-8000-000000000133',
  '10000000-0000-4000-8000-000000000133',
  '10000000-0000-4000-8000-000000000133/analyses/40000000-0000-4000-8000-000000000133/original/selfie.jpg'
);
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
values (
  '41000000-0000-4000-8000-000000000133',
  '10000000-0000-4000-8000-000000000133',
  '40000000-0000-4000-8000-000000000133',
  'natural'
);
insert into public.generated_images (
  id, user_id, analysis_id, recommendation_id, storage_path, generation_number
)
select
  ('42000000-0000-4000-8000-00000000013' || n)::uuid,
  '10000000-0000-4000-8000-000000000133',
  '40000000-0000-4000-8000-000000000133',
  '41000000-0000-4000-8000-000000000133',
  '10000000-0000-4000-8000-000000000133/analyses/40000000-0000-4000-8000-000000000133/generated/41000000-0000-4000-8000-000000000133/preview_000' || n || '.png',
  n
from generate_series(1, 3) as n;

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000133","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select count(*)::integer from (
     select (public.commit_ai_look(
       ('30000000-0000-4000-8000-0000000001a' || n)::uuid, 'standard',
       ('42000000-0000-4000-8000-00000000013' || n)::uuid
     ))->>'status' as status
     from generate_series(1, 3) as n,
     lateral (select public.reserve_ai_look(
       ('30000000-0000-4000-8000-0000000001a' || n)::uuid)) as held
   ) as r where r.status = 'committed'),
  3,
  'three Preview-only credits are reserved and committed from the grant'
);
select is(
  (select jsonb_build_array(
     s->>'purchasedPreviewCreditsRemaining', s->>'availablePurchasedCredits')
   from public.resolve_subscription_state() as s),
  '["7", "7"]'::jsonb,
  'before the void, seven credits remain on the grant'
);
reset role;

select is(
  (public.revoke_top_up_purchase(repeat('d', 64), 'voided', 'GPA.9999-8888-7777-66666'))
    - 'grantId',
  '{"ok": true, "replayed": false, "quantityGranted": 10, "consumed": 3,
    "inFlight": 0, "revokedUnused": 7, "availableFromGrant": 0}'::jsonb,
  'voiding the purchase revokes the seven unused credits and reports the three consumed'
);
select is(
  (public.revoke_top_up_purchase(repeat('d', 64), 'voided', 'GPA.9999-8888-7777-66666'))
    - 'grantId',
  '{"ok": true, "replayed": true, "quantityGranted": 10, "consumed": 3,
    "inFlight": 0, "revokedUnused": 7, "availableFromGrant": 0}'::jsonb,
  'processing the same revocation again is idempotent'
);
select is(
  (select concat_ws('|', revocation_reason, revocation_reference,
                    revoked_at is not null)
   from public.purchased_credit_grants where purchase_reference = repeat('d', 64)),
  'voided|GPA.9999-8888-7777-66666|t',
  'the revocation is recorded on the grant for audit'
);
select is(
  (select count(*)::integer from public.usage_ledger as l
   join public.purchased_credit_grants as g on g.id = l.purchased_credit_grant_id
   where g.purchase_reference = repeat('d', 64) and l.status = 'committed'),
  3,
  'the three consumed credits remain immutable history'
);

select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000133","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'purchasedPreviewCreditsRemaining', s->>'availablePurchasedCredits',
     s->>'committedUsage', s->>'remainingAiLooks', s->>'generationAuthorized',
     s->>'denialReason')
   from public.resolve_subscription_state() as s),
  '["0", "0", "0", "3", "false", "AI_LOOK_LIMIT_REACHED"]'::jsonb,
  'after the void the grant contributes nothing, never a negative figure, and the subscription figures (three held, three remaining) are untouched'
);
select is(
  (public.reserve_ai_look('30000000-0000-4000-8000-0000000001a9'))->>'errorCode',
  'AI_LOOK_LIMIT_REACHED',
  'a revoked grant cannot be reserved from again'
);
select throws_ok(
  $$select public.revoke_top_up_purchase(repeat('d', 64), 'refunded')$$,
  '42501',
  'permission denied for function revoke_top_up_purchase',
  'a signed-in user cannot revoke or replay a revocation'
);
reset role;

select throws_ok(
  $$update public.purchased_credit_grants set revoked_at = null,
      revocation_reason = null, revocation_reference = null
    where purchase_reference = repeat('d', 64)$$,
  'P0001',
  null,
  'a revocation can never be cleared'
);
select is(
  (public.revoke_top_up_purchase(repeat('d', 64), 'chargeback'))->>'errorCode',
  'PROVIDER_STATE_CONFLICT',
  'an unknown revocation reason is refused'
);
select is(
  (public.revoke_top_up_purchase(repeat('0', 64), 'refunded'))->>'errorCode',
  'TOP_UP_GRANT_NOT_FOUND',
  'revoking an unknown purchase changes nothing'
);
select is(
  (select count(*)::integer from public.purchased_credit_grants
   where revoked_at is not null),
  1,
  'no other grant, on any account, was revoked'
);
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;
select is(
  (select jsonb_build_array(
     s->>'purchasedTutorialCreditsRemaining',
     s->>'purchasedPreviewCreditsRemaining')
   from public.resolve_subscription_state() as s),
  '["1", "9"]'::jsonb,
  'another account''s grants are untouched by the revocation'
);
reset role;

-- ---------------------------------------------------------------------------
-- The client cannot grant, spend, or alter credits directly
-- ---------------------------------------------------------------------------
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-000000000131","role":"authenticated"}',
  true
);
set local role authenticated;

select throws_ok(
  $$select public.grant_verified_top_up_purchase(
      '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
      repeat('0', 64), 'PURCHASED'
    )$$,
  '42501',
  'permission denied for function grant_verified_top_up_purchase',
  'a signed-in user cannot grant themselves credits through the writer'
);
select throws_ok(
  $$insert into public.purchased_credit_grants (
      user_id, provider_product_id, pack_code, credit_class, quantity_granted,
      purchase_reference, purchase_state
    ) values (
      '10000000-0000-4000-8000-000000000131', 'facetune_ai_look_topup_1',
      'extra_ai_look', 'tutorial_capable_ai_look', 1, repeat('0', 64),
      'PURCHASED'
    )$$,
  '42501',
  'permission denied for table purchased_credit_grants',
  'a signed-in user cannot insert a grant'
);
select throws_ok(
  $$update public.purchased_credit_grants set quantity_granted = 99$$,
  '42501',
  'permission denied for table purchased_credit_grants',
  'a signed-in user cannot update a grant'
);
select throws_ok(
  $$select public.mark_top_up_purchase_consumed(
      '10000000-0000-4000-8000-000000000131', repeat('a', 64)
    )$$,
  '42501',
  'permission denied for function mark_top_up_purchase_consumed',
  'a signed-in user cannot mark a purchase consumed'
);
select is(
  (select count(*)::integer from public.purchased_credit_grants),
  (select count(*)::integer from public.purchased_credit_grants
   where user_id = '10000000-0000-4000-8000-000000000131'),
  'RLS shows an account only its own grants'
);
select throws_ok(
  $$select purchase_reference from public.purchased_credit_grants limit 1$$,
  '42501',
  null,
  'the purchase reference column is not readable by the owner'
);
select is(
  (select count(*)::integer from public.top_up_packs),
  2,
  'the pack catalog is readable by a signed-in user'
);
reset role;

select is(
  (select count(*)::integer from public.usage_ledger
   where allowance_source = 'purchased_credit'
     and purchased_credit_grant_id is null),
  0,
  'every purchased-credit ledger row names its grant'
);
select throws_ok(
  $$update public.usage_ledger set allowance_source = 'subscription'
      where operation_id = '30000000-0000-4000-8000-000000000006'$$,
  'P0001',
  null,
  'the allowance source of a ledger row is fixed at reservation'
);

select * from finish();
rollback;
