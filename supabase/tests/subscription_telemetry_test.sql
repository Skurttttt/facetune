begin;

select plan(35);

select ok(
  (select relrowsecurity from pg_class where oid = 'public.ai_operation_metrics'::regclass),
  'telemetry table has RLS enabled'
);

select is(
  has_table_privilege('anon', 'public.ai_operation_metrics', 'INSERT'),
  false,
  'anonymous callers cannot insert telemetry'
);

select is(
  has_table_privilege('authenticated', 'public.ai_operation_metrics', 'INSERT'),
  false,
  'authenticated callers cannot insert telemetry'
);

select is(
  has_table_privilege('authenticated', 'public.ai_operation_metrics', 'UPDATE'),
  false,
  'authenticated callers cannot update telemetry'
);

select is(
  has_table_privilege('authenticated', 'public.ai_operation_metrics', 'DELETE'),
  false,
  'authenticated callers cannot delete telemetry'
);

select is(
  (
    select has_function_privilege('authenticated', p.oid, 'EXECUTE')
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'record_ai_operation_metric'
  ),
  false,
  'authenticated callers cannot forge metrics through the writer'
);

select is(
  (
    select has_function_privilege('service_role', p.oid, 'EXECUTE')
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'record_ai_operation_metric'
  ),
  true,
  'only the server role receives writer execution'
);

select is(
  has_table_privilege('service_role', 'public.ai_operation_metrics', 'UPDATE'),
  false,
  'the service writer cannot rewrite historical telemetry'
);

select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'ai_operation_metrics'
      and column_name in (
        'image_bytes', 'base64', 'signed_url', 'jwt', 'purchase_token',
        'prompt_text', 'makeup_kit_content', 'product_name', 'email'
      )
  ),
  0,
  'telemetry has no private-content or credential columns'
);

insert into auth.users (
  instance_id,
  id,
  aud,
  role,
  email,
  encrypted_password,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  confirmation_token,
  email_change,
  email_change_token_new,
  recovery_token
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-4000-8000-000000000013',
  'authenticated',
  'authenticated',
  'sub13-telemetry@example.invalid',
  '',
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{}'::jsonb,
  timezone('utc', now()),
  timezone('utc', now()),
  '',
  '',
  '',
  ''
);

select is(
  public.record_ai_operation_metric(
    '20000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000013',
    'final_preview',
    'denied',
    'AI_LOOK_LIMIT_REACHED',
    'standard',
    '30000000-0000-4000-8000-000000000013'
  ),
  true,
  'server writer accepts one controlled metric'
);

select is(
  public.record_ai_operation_metric(
    '20000000-0000-4000-8000-000000000013',
    '10000000-0000-4000-8000-000000000013',
    'final_preview',
    'denied',
    'AI_LOOK_LIMIT_REACHED',
    'standard',
    '30000000-0000-4000-8000-000000000013'
  ),
  true,
  'repeating the same telemetry event is idempotent'
);

select is(
  (
    select count(*)::integer
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000013'
  ),
  1,
  'an idempotent retry does not double-count the event'
);

select is(
  (
    select telemetry_schema_version
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000013'
  ),
  'sub13_v1',
  'every row identifies the telemetry schema version'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000014',
    p_user_id => '10000000-0000-4000-8000-000000000013',
    p_operation_kind => 'final_preview',
    p_outcome => 'failed'
  ),
  false,
  'a failed outcome without a controlled category is rejected safely'
);

select is(
  (
    select count(*)::integer
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000014'
  ),
  0,
  'a rejected metric leaves no partial telemetry row'
);

-- Two authoritative ledger outcomes. Telemetry observes these rows but cannot
-- mutate them; a deleted canonical preview is represented by a committed row
-- with a retained source mode and a null preview foreign key.
insert into public.usage_ledger (
  user_id,
  entitlement_id,
  operation_id,
  status,
  source_mode,
  committed_at,
  released_at,
  sanitized_failure_code,
  plan_code,
  allowance_unit
)
select
  '10000000-0000-4000-8000-000000000013',
  e.id,
  v.operation_id,
  v.status,
  v.source_mode,
  case when v.status = 'committed' then timezone('utc', now()) end,
  case when v.status = 'released' then timezone('utc', now()) end,
  case when v.status = 'released' then 'generation_failed' end,
  'free',
  'ai_look'
from public.user_entitlements as e
cross join (
  values
    ('30000000-0000-4000-8000-000000000014'::uuid, 'committed', 'standard'),
    ('30000000-0000-4000-8000-000000000015'::uuid, 'released', null)
) as v(operation_id, status, source_mode)
where e.user_id = '10000000-0000-4000-8000-000000000013'
  and e.plan_code = 'free';

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000015',
    p_user_id => '10000000-0000-4000-8000-000000000013',
    p_operation_kind => 'final_preview',
    p_outcome => 'succeeded',
    p_source_mode => 'standard',
    p_operation_id => '30000000-0000-4000-8000-000000000014',
    p_provider_name => 'google_gemini',
    p_model_name => 'gemini-3.1-flash-image',
    p_provider_attempt_count => 1,
    p_output_images => 1,
    p_output_image_resolution => '1K'
  ),
  true,
  'a committed delivered preview can be observed'
);

select is(
  (
    select concat_ws('|', plan_code, capability_family, allowance_unit, usage_status, source_mode)
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000015'
  ),
  'free|tutorial_enabled|ai_look|committed|standard',
  'plan, capability, allowance, ledger outcome, and Standard mode are server-derived'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000016',
    p_user_id => '10000000-0000-4000-8000-000000000013',
    p_operation_kind => 'final_preview',
    p_outcome => 'succeeded',
    p_source_mode => 'standard',
    p_operation_id => '30000000-0000-4000-8000-000000000014'
  ),
  true,
  'a replayed successful logical operation is an idempotent no-op'
);

select is(
  (
    select count(*)::integer
    from public.ai_operation_metrics
    where operation_id = '30000000-0000-4000-8000-000000000014'
      and outcome = 'succeeded'
  ),
  1,
  'a second event id cannot double-count the same delivered preview'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000017',
    p_user_id => '10000000-0000-4000-8000-000000000013',
    p_operation_kind => 'final_preview',
    p_outcome => 'failed',
    p_failure_category => 'GENERATION_FAILED',
    p_source_mode => 'standard',
    p_operation_id => '30000000-0000-4000-8000-000000000015',
    p_provider_name => 'google_gemini',
    p_provider_attempt_count => 2
  ),
  true,
  'a released provider failure can be observed separately'
);

select is(
  (
    select concat_ws('|', usage_status, outcome, provider_attempt_count)
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000017'
  ),
  'released|failed|2',
  'released work and its provider attempts remain distinguishable'
);

select is(
  (
    select string_agg(status, ',' order by operation_id)
    from public.usage_ledger
    where operation_id in (
      '30000000-0000-4000-8000-000000000014',
      '30000000-0000-4000-8000-000000000015'
    )
  ),
  'committed,released',
  'successful and rejected telemetry writes cannot change ledger outcomes'
);

-- A Preview-only entitlement and ledger row prove capability attribution comes
-- from canonical server provenance, including the Makeup Kit discriminator.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) values (
  '00000000-0000-0000-0000-000000000000',
  '10000000-0000-4000-8000-000000000023',
  'authenticated', 'authenticated', 'sub13-preview@example.invalid', '',
  timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', ''
);

insert into public.user_entitlements (
  id, user_id, plan_code, status, billing_provider, provider_product_id,
  provider_subscription_reference, period_start, period_end, starts_at,
  auto_renew, base_ai_look_allowance, verified_at
) values (
  '11000000-0000-4000-8000-000000000023',
  '10000000-0000-4000-8000-000000000023',
  'plus_preview', 'active', 'google_play', 'facetune_plus_preview',
  'sub13-test-provider-reference',
  timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days',
  timezone('utc', now()) - interval '1 day',
  true, 30, timezone('utc', now())
);

insert into public.usage_ledger (
  user_id, entitlement_id, operation_id, status, source_mode, committed_at,
  plan_code, allowance_unit
) values (
  '10000000-0000-4000-8000-000000000023',
  '11000000-0000-4000-8000-000000000023',
  '30000000-0000-4000-8000-000000000023',
  'committed', 'makeup_kit', timezone('utc', now()),
  'plus_preview', 'final_preview_credit'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000023',
    p_user_id => '10000000-0000-4000-8000-000000000023',
    p_operation_kind => 'final_preview',
    p_outcome => 'succeeded',
    p_source_mode => 'makeup_kit',
    p_operation_id => '30000000-0000-4000-8000-000000000023'
  ),
  true,
  'a Preview-only Makeup Kit delivery can be observed'
);

select is(
  (
    select concat_ws('|', plan_code, capability_family, allowance_unit, usage_status, source_mode)
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000023'
  ),
  'plus_preview|preview_only|final_preview_credit|committed|makeup_kit',
  'Preview-only provenance is distinct from Tutorial-enabled provenance'
);

select is(
  (
    select count(distinct capability_family)::integer
    from public.ai_operation_metrics
    where event_id in (
      '20000000-0000-4000-8000-000000000015',
      '20000000-0000-4000-8000-000000000023'
    )
  ),
  2,
  'both capability families are separately measurable'
);

insert into public.provider_purchase_verifications (
  user_id, provider_product_id, plan_code, purchase_reference,
  subscription_state, entitlement_id, verified_at, created_at
) values (
  '10000000-0000-4000-8000-000000000023',
  'facetune_plus_preview',
  'plus_preview',
  repeat('a', 64),
  'SUBSCRIPTION_STATE_ACTIVE',
  '11000000-0000-4000-8000-000000000023',
  timezone('utc', now()),
  timezone('utc', now()) - interval '1 day'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000027',
    p_user_id => '10000000-0000-4000-8000-000000000023',
    p_operation_kind => 'purchase_verification',
    p_outcome => 'succeeded',
    p_provider_name => 'google_play',
    p_verification_source => 'restore',
    p_purchase_reference => repeat('a', 64)
  ),
  true,
  'a purchase replay can be observed without a pre-activation telemetry query'
);

select is(
  (
    select concat_ws('|', outcome, plan_code, capability_family, verification_source_trust)
    from public.ai_operation_metrics
    where event_id = '20000000-0000-4000-8000-000000000027'
  ),
  'duplicate|plus_preview|preview_only|client_claimed',
  'replay is server-derived while purchase-versus-restore remains client-claimed'
);

select is(
  public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000024',
    p_user_id => '10000000-0000-4000-8000-000000000013',
    p_operation_kind => 'tutorial_manifest',
    p_outcome => 'succeeded',
    p_source_mode => 'standard',
    p_canonical_preview_id => '40000000-0000-4000-8000-000000000013',
    p_provider_name => 'google_gemini',
    p_model_name => 'gemini-3.6-flash',
    p_prompt_version => 'tutorial_manifest_v4_1',
    p_provider_attempt_count => 1
  ),
  true,
  'a Tutorial manifest is recorded as its own technical operation'
);

select is(
  (
    select count(distinct operation_kind)::integer
    from public.ai_operation_metrics
    where event_id in (
      '20000000-0000-4000-8000-000000000015',
      '20000000-0000-4000-8000-000000000024'
    )
  ),
  2,
  'Preview delivery and Tutorial manifest generation are not collapsed'
);

select is(
  (
    select jsonb_object_agg(
      plan_code,
      jsonb_build_array(base_ai_look_allowance, allowance_unit, tutorial_enabled)
    )
    from public.subscription_products
  ),
  '{
    "free": [1, "ai_look", true],
    "plus": [3, "ai_look", true],
    "plus_preview": [30, "final_preview_credit", false],
    "pro": [8, "ai_look", true],
    "pro_preview": [80, "final_preview_credit", false],
    "salon_pro": [35, "ai_look", true],
    "salon_preview": [350, "final_preview_credit", false],
    "salon_pilot": [30, "ai_look", true]
  }'::jsonb,
  'the locked eight-plan allowance and capability matrix is unchanged'
);

select is(
  (
    select concat_ws('|', base_ai_look_allowance, allowance_unit, tutorial_enabled, publicly_purchasable)
    from public.subscription_products where plan_code = 'free'
  ),
  '1|ai_look|t|f',
  'Free retains one lifetime Tutorial-capable AI Look and is not sold'
);

select is(
  (
    select concat_ws('|', base_ai_look_allowance, allowance_unit, tutorial_enabled, publicly_purchasable)
    from public.subscription_products where plan_code = 'salon_pilot'
  ),
  '30|ai_look|t|f',
  'Salon Pilot retains its starting allowance and non-public capability'
);

select is(
  (
    select count(*)::integer
    from pg_proc as p
    join pg_namespace as n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'resolve_subscription_state',
        'reserve_ai_look',
        'commit_ai_look',
        'release_ai_look',
        'activate_verified_google_play_purchase',
        'authorize_tutorial_generation'
      )
      and pg_get_functiondef(p.oid) ilike '%ai_operation_metrics%'
  ),
  0,
  'telemetry is not an entitlement, purchase, or Tutorial authorization dependency'
);

set local role authenticated;

select throws_ok(
  $$select public.record_ai_operation_metric(
    p_event_id => '20000000-0000-4000-8000-000000000025',
    p_user_id => '10000000-0000-4000-8000-000000000023',
    p_operation_kind => 'final_preview',
    p_outcome => 'succeeded',
    p_operation_id => '30000000-0000-4000-8000-000000000023'
  )$$,
  '42501',
  'permission denied for function record_ai_operation_metric',
  'an authenticated caller cannot forge another user metric through the RPC'
);

select throws_ok(
  $$insert into public.ai_operation_metrics (
    event_id, user_id, operation_kind, outcome
  ) values (
    '20000000-0000-4000-8000-000000000026',
    '10000000-0000-4000-8000-000000000023',
    'purchase_verification',
    'succeeded'
  )$$,
  '42501',
  'permission denied for table ai_operation_metrics',
  'an authenticated caller cannot bypass the RPC with a direct insert'
);

reset role;

select * from finish();
rollback;
