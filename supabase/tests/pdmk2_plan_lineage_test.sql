-- PDMK-2 / PDMK-3 — canonical plan lineage.
--
-- Proves the persistence contract for plan-driven My Makeup Kit looks: the
-- plan group is all-or-none and frozen, plan-backed rows are server-only,
-- generations and attempts are service-role-only state machines that move
-- forward only, a failed or abandoned candidate can never become a preview, an
-- accepted preview is finalized atomically from exactly one accepted attempt,
-- and the unchanged usage engine still commits and reconciles correctly.
-- Legacy (v2) rows keep their behaviour. Rolled back.
begin;

select plan(82);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
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

create function pg_temp.can_exec(p_role text, p_fn text) returns boolean
language sql set search_path = '' as $$
  select bool_or(has_function_privilege(p_role, p.oid, 'EXECUTE'))
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = p_fn
$$;

create function pg_temp.plan_json(p_plan uuid, p_analysis uuid, p_style text)
returns jsonb language sql set search_path = '' as $$
  select jsonb_build_object(
    'plan_id', p_plan, 'plan_version', 'kit_makeup_plan_v1',
    'analysis_id', p_analysis, 'style_code', p_style,
    'source_mode', 'my_makeup_kit'
  )
$$;

create function pg_temp.rec(
  p_id uuid, p_user uuid, p_analysis uuid, p_style text,
  p_plan uuid, p_request uuid, p_json jsonb, p_version text, p_digest text
) returns void language sql set search_path = '' as $$
  insert into public.kit_makeup_recommendations (
    id, user_id, analysis_id, makeup_style, recommendation_json,
    product_snapshot_json, model_name, prompt_version,
    plan_id, plan_version, plan_json, plan_digest, plan_request_id
  ) values (
    p_id, p_user, p_analysis, p_style, '{"selections":[]}'::jsonb,
    '[]'::jsonb, 'model', 'kit_makeup_recommendation_v3',
    p_plan, p_version, p_json, p_digest, p_request
  )
$$;

create function pg_temp.generation(p_id uuid, p_op uuid, p_digest text)
returns void language sql set search_path = '' as $$
  insert into public.kit_preview_generations (
    id, user_id, operation_id, kit_recommendation_id, plan_id, plan_digest,
    max_attempts, lease_expires_at
  ) values (
    p_id, '10000000-0000-4000-8000-000000000401', p_op,
    '21000000-0000-4000-8000-000000000002',
    '22000000-0000-4000-8000-000000000002', p_digest, 3,
    timezone('utc', now()) + interval '5 minutes'
  )
$$;

create function pg_temp.attempt(p_id uuid, p_generation uuid, p_number int)
returns void language sql set search_path = '' as $$
  insert into public.kit_preview_attempts (
    id, user_id, generation_id, attempt_number, preview_prompt_version,
    model_name
  ) values (
    p_id, '10000000-0000-4000-8000-000000000401', p_generation, p_number,
    'kit_makeup_preview_v2', 'gemini-3.1-flash-image'
  )
$$;

-- A stale reservation, inserted as history (reserved rows are not backdated).
create function pg_temp.stale_reservation(p_op uuid) returns void
language sql set search_path = '' as $$
  insert into public.usage_ledger (
    user_id, entitlement_id, operation_id, status, reserved_at, created_at
  )
  select e.user_id, e.id, p_op, 'reserved',
         timezone('utc', now()) - interval '1 hour',
         timezone('utc', now()) - interval '1 hour'
    from public.user_entitlements e
   where e.user_id = '10000000-0000-4000-8000-000000000401'
   order by e.created_at desc limit 1
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
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
  ('10000000-0000-4000-8000-000000000401'::uuid, 'pdmk-alice@example.invalid'),
  ('10000000-0000-4000-8000-000000000402'::uuid, 'pdmk-bob@example.invalid')
) as v(id, email);

select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000401', 'facetune_plus', repeat('d', 64),
  'SUBSCRIPTION_STATE_ACTIVE', timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true);
select public.activate_verified_google_play_subscription(
  '10000000-0000-4000-8000-000000000402', 'facetune_plus', repeat('e', 64),
  'SUBSCRIPTION_STATE_ACTIVE', timezone('utc', now()) - interval '1 day',
  timezone('utc', now()) + interval '29 days', true, null, true);

insert into public.analyses (id, user_id, original_image_path) values
  ('20000000-0000-4000-8000-000000000401',
   '10000000-0000-4000-8000-000000000401',
   '10000000-0000-4000-8000-000000000401/analyses/20000000-0000-4000-8000-000000000401/original/selfie.jpg'),
  ('20000000-0000-4000-8000-000000000402',
   '10000000-0000-4000-8000-000000000402',
   '10000000-0000-4000-8000-000000000402/analyses/20000000-0000-4000-8000-000000000402/original/selfie.jpg');

-- Alice's legacy v2 look.
insert into public.kit_makeup_recommendations (
  id, user_id, analysis_id, makeup_style, recommendation_json,
  product_snapshot_json, model_name, prompt_version
) values (
  '21000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'natural',
  '{"selections":[]}'::jsonb, '[]'::jsonb, 'model',
  'kit_makeup_recommendation_v2'
);

-- Alice's AI Look operation for the first plan-backed preview.
select pg_temp.as_user('10000000-0000-4000-8000-000000000401');
select public.reserve_ai_look('24000000-0000-4000-8000-000000000001');
-- Bob's operation, used to prove a generation cannot borrow it.
select pg_temp.as_user('10000000-0000-4000-8000-000000000402');
select public.reserve_ai_look('24000000-0000-4000-8000-000000000002');

-- ===========================================================================
-- 1. Privileges
-- ===========================================================================
select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.kit_preview_generations'::regclass),
  'generations have RLS enabled'
);
select ok(
  (select relrowsecurity from pg_class
    where oid = 'public.kit_preview_attempts'::regclass),
  'attempts have RLS enabled'
);
select is(has_table_privilege('anon', 'public.kit_preview_generations', 'SELECT'),
  false, 'anon cannot read generations');
select is(has_table_privilege('authenticated', 'public.kit_preview_generations', 'SELECT'),
  false, 'callers cannot read generations');
select is(has_table_privilege('authenticated', 'public.kit_preview_attempts', 'INSERT'),
  false, 'callers cannot write attempts');
select is(has_table_privilege('authenticated', 'public.kit_preview_attempts', 'UPDATE'),
  false, 'callers cannot update attempts');
select is(has_table_privilege('service_role', 'public.kit_preview_generations', 'INSERT'),
  true, 'the server writes generations');
select is(has_table_privilege('service_role', 'public.kit_preview_attempts', 'UPDATE'),
  true, 'the server advances attempts');
select is(has_table_privilege('service_role', 'public.kit_preview_generations', 'DELETE'),
  false, 'nothing deletes generations directly');
select is(has_table_privilege('service_role', 'public.kit_makeup_recommendations', 'INSERT'),
  true, 'the server writes plan-backed recommendations');
select is(pg_temp.can_exec('authenticated', 'pdmk_claim_preview_slot'), false,
  'callers cannot claim a preview slot');
select is(pg_temp.can_exec('anon', 'pdmk_finalize_accepted_attempt'), false,
  'anon cannot finalize');
select is(pg_temp.can_exec('authenticated', 'pdmk_finalize_accepted_attempt'), false,
  'callers cannot finalize');
select is(pg_temp.can_exec('service_role', 'pdmk_finalize_accepted_attempt'), true,
  'the server finalizes');
select hasnt_column('public', 'generated_images', 'plan_id',
  'Standard previews are untouched');
select hasnt_column('public', 'recommendations', 'plan_id',
  'Standard recommendations are untouched');

-- ===========================================================================
-- 2. The plan group
-- ===========================================================================
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  gen_random_uuid(), gen_random_uuid(), null, null, null) $$,
  '23514', null, 'a partial plan group is refused');
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  '22000000-0000-4000-8000-000000000009', null,
  pg_temp.plan_json('22000000-0000-4000-8000-000000000009',
    '20000000-0000-4000-8000-000000000401', 'soft_glam'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  '23514', null, 'a plan without its request id is refused');
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  null, gen_random_uuid(), null, null, null) $$,
  '23514', null, 'a request id without a plan is refused');
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  '22000000-0000-4000-8000-000000000009', gen_random_uuid(),
  pg_temp.plan_json('22000000-0000-4000-8000-000000000009',
    '20000000-0000-4000-8000-000000000401', 'natural'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  '23514', null, 'a plan whose identity disagrees with its row is refused');
select lives_ok($$ select pg_temp.rec(
  '21000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  '22000000-0000-4000-8000-000000000002', '23000000-0000-4000-8000-000000000002',
  pg_temp.plan_json('22000000-0000-4000-8000-000000000002',
    '20000000-0000-4000-8000-000000000401', 'soft_glam'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  'the server stores a complete plan');
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  '22000000-0000-4000-8000-000000000008', '23000000-0000-4000-8000-000000000002',
  pg_temp.plan_json('22000000-0000-4000-8000-000000000008',
    '20000000-0000-4000-8000-000000000401', 'soft_glam'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  '23505', null, 'one plan request id makes one plan per account');
select lives_ok($$ select pg_temp.rec(
  '21000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000402',
  '20000000-0000-4000-8000-000000000402', 'soft_glam',
  '22000000-0000-4000-8000-000000000003', '23000000-0000-4000-8000-000000000002',
  pg_temp.plan_json('22000000-0000-4000-8000-000000000003',
    '20000000-0000-4000-8000-000000000402', 'soft_glam'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  'another account may use the same request id');
select throws_ok($$ update public.kit_makeup_recommendations
  set makeup_style = 'natural'
  where id = '21000000-0000-4000-8000-000000000002' $$,
  'P0001', null, 'a plan-backed row is frozen even for the server');
select throws_ok($$ update public.kit_makeup_recommendations
  set plan_request_id = gen_random_uuid()
  where id = '21000000-0000-4000-8000-000000000001' $$,
  'P0001', null, 'a plan cannot be attached to a legacy row');
select lives_ok($$ update public.kit_makeup_recommendations
  set makeup_style = 'everyday'
  where id = '21000000-0000-4000-8000-000000000001' $$,
  'a legacy row keeps its legacy update behaviour');

-- ===========================================================================
-- 3. Callers keep legacy rights only
-- ===========================================================================
select pg_temp.as_user('10000000-0000-4000-8000-000000000401');
set local role authenticated;
select lives_ok($$ insert into public.kit_makeup_recommendations (
  user_id, analysis_id, makeup_style, recommendation_json,
  product_snapshot_json, model_name, prompt_version
) values (
  '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'office', '{}'::jsonb, '[]'::jsonb,
  'model', 'kit_makeup_recommendation_v2') $$,
  'a caller can still create a legacy recommendation');
select throws_ok($$ select pg_temp.rec(
  gen_random_uuid(), '10000000-0000-4000-8000-000000000401',
  '20000000-0000-4000-8000-000000000401', 'soft_glam',
  '22000000-0000-4000-8000-000000000007', gen_random_uuid(),
  pg_temp.plan_json('22000000-0000-4000-8000-000000000007',
    '20000000-0000-4000-8000-000000000401', 'soft_glam'),
  'kit_makeup_plan_v1', repeat('1', 64)) $$,
  '42501', null, 'a caller cannot create a plan-backed recommendation');
update public.kit_makeup_recommendations set makeup_style = 'party'
  where id = '21000000-0000-4000-8000-000000000002';
update public.kit_makeup_recommendations set makeup_style = 'korean'
  where id = '21000000-0000-4000-8000-000000000001';
reset role;
select is(
  (select makeup_style from public.kit_makeup_recommendations
    where id = '21000000-0000-4000-8000-000000000002'),
  'soft_glam', 'a caller update never reaches a plan-backed row');
select is(
  (select makeup_style from public.kit_makeup_recommendations
    where id = '21000000-0000-4000-8000-000000000001'),
  'korean', 'a caller update still reaches a legacy row');

-- ===========================================================================
-- 4. Generations
-- ===========================================================================
select throws_ok($$ select pg_temp.generation(
  gen_random_uuid(), '24000000-0000-4000-8000-000000000002', repeat('1', 64)) $$,
  'P0001', null, 'a generation cannot borrow another account''s operation');
select throws_ok($$ select pg_temp.generation(
  gen_random_uuid(), '24000000-0000-4000-8000-000000000001', repeat('2', 64)) $$,
  'P0001', null, 'a generation must match its plan digest');
select throws_ok($$ insert into public.kit_preview_generations (
  user_id, operation_id, kit_recommendation_id, plan_id, plan_digest,
  status, terminal_outcome, max_attempts, completed_at
) values (
  '10000000-0000-4000-8000-000000000401', '24000000-0000-4000-8000-000000000001',
  '21000000-0000-4000-8000-000000000002', '22000000-0000-4000-8000-000000000002',
  repeat('1', 64), 'accepted', 'accepted', 3, timezone('utc', now())) $$,
  'P0001', null, 'a generation cannot start terminal');
select lives_ok($$ select pg_temp.generation(
  '25000000-0000-4000-8000-000000000001', '24000000-0000-4000-8000-000000000001',
  repeat('1', 64)) $$, 'a generation starts for its own operation');
select throws_ok($$ select pg_temp.generation(
  gen_random_uuid(), '24000000-0000-4000-8000-000000000001', repeat('1', 64)) $$,
  '23505', null, 'one operation has one generation');

-- ===========================================================================
-- 5. Attempts
-- ===========================================================================
select throws_ok($$ select pg_temp.attempt(
  gen_random_uuid(), '25000000-0000-4000-8000-000000000001', 2) $$,
  'P0001', null, 'attempts cannot skip a number');
select lives_ok($$ select pg_temp.attempt(
  '26000000-0000-4000-8000-000000000001', '25000000-0000-4000-8000-000000000001', 1) $$,
  'the first attempt starts');
select throws_ok($$ select pg_temp.attempt(
  gen_random_uuid(), '25000000-0000-4000-8000-000000000001', 2) $$,
  'P0001', null, 'a second attempt waits for the first to finish');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'completed requires an outcome');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'validating'
  where id = '26000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'validating requires the candidate hash');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'abandoned',
      completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000001' $$,
  '23514', null, 'abandoned requires a reason');
select lives_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'abandoned', reason_code = 'lease_expired',
      completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000001' $$,
  'an expired attempt is completed as abandoned');
select throws_ok($$ update public.kit_preview_attempts
  set reason_code = 'provider_timeout'
  where id = '26000000-0000-4000-8000-000000000001' $$,
  'P0001', null, 'a completed attempt is immutable');
select lives_ok($$ select pg_temp.attempt(
  '26000000-0000-4000-8000-000000000002', '25000000-0000-4000-8000-000000000001', 2) $$,
  'the next attempt follows an abandoned one');
select is(
  (select count(*)::int from public.kit_preview_attempts
    where generation_id = '25000000-0000-4000-8000-000000000001'),
  2, 'an abandoned attempt still counts toward the bound');
select lives_ok($$ update public.kit_preview_attempts
  set status = 'validating', candidate_sha256 = repeat('2', 64)
  where id = '26000000-0000-4000-8000-000000000002' $$,
  'a generated candidate moves to validation');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'generating'
  where id = '26000000-0000-4000-8000-000000000002' $$,
  'P0001', null, 'status never moves backward');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'retryable_mismatch',
      validator_version = 'kit_preview_validator_v1',
      completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000002' $$,
  '23514', null, 'a mismatch names at least one category');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'retryable_mismatch',
      validator_version = 'kit_preview_validator_v1',
      mismatch_categories = '{lipstick}', completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000002' $$,
  '23514', null, 'mismatch categories use the tutorial vocabulary');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'provider_failure', reason_code = 'timeout',
      evidence_json = '{}'::jsonb, completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000002' $$,
  '23514', null, 'a provider failure carries no validation evidence');
select throws_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'accepted',
      validator_version = 'kit_preview_validator_v1',
      completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000002' $$,
  '23514', null, 'acceptance requires a claimed preview slot');
select lives_ok($$ update public.kit_preview_attempts
  set status = 'completed', outcome = 'retryable_mismatch',
      validator_version = 'kit_preview_validator_v1',
      mismatch_categories = '{foundation}',
      evidence_json = '{"foundation":{"expected":"forbidden","observed":"present"}}'::jsonb,
      completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000002' $$,
  'a mismatch is recorded with its evidence');
select throws_ok($$ update public.kit_preview_generations
  set status = 'failed', terminal_outcome = 'retry_exhausted',
      completed_at = timezone('utc', now())
  where id = '25000000-0000-4000-8000-000000000001' $$,
  'P0001', null, 'retries are not exhausted before the bound');
select throws_ok($$ update public.kit_preview_generations
  set status = 'accepted', terminal_outcome = 'accepted',
      completed_at = timezone('utc', now())
  where id = '25000000-0000-4000-8000-000000000001' $$,
  'P0001', null, 'a generation is accepted only through an accepted attempt');

-- ===========================================================================
-- 6. Slot, masquerade, finalize
-- ===========================================================================
select lives_ok($$ select pg_temp.attempt(
  '26000000-0000-4000-8000-000000000003', '25000000-0000-4000-8000-000000000001', 3) $$,
  'the last attempt starts');
select throws_ok($$ select public.pdmk_claim_preview_slot(
  '26000000-0000-4000-8000-000000000003', 'png') $$,
  'P0001', null, 'a slot is claimed only while validating');
update public.kit_preview_attempts
  set status = 'validating', candidate_sha256 = repeat('3', 64)
  where id = '26000000-0000-4000-8000-000000000003';
select is(
  public.pdmk_claim_preview_slot('26000000-0000-4000-8000-000000000003', 'png')
    ->> 'storagePath',
  '10000000-0000-4000-8000-000000000401/analyses/20000000-0000-4000-8000-000000000401/kit-generated/21000000-0000-4000-8000-000000000002/preview_0001.png',
  'the slot follows the Tutorial path contract');
select is(
  public.pdmk_claim_preview_slot('26000000-0000-4000-8000-000000000003', 'png')
    ->> 'generationNumber',
  '1', 'claiming the slot again returns the same slot');
select throws_ok($$ insert into public.kit_generated_images (
  user_id, analysis_id, kit_recommendation_id, storage_path, generation_number,
  model_name, prompt_version, plan_id, plan_digest, operation_id,
  accepted_attempt_id, content_sha256
) values (
  '10000000-0000-4000-8000-000000000401', '20000000-0000-4000-8000-000000000401',
  '21000000-0000-4000-8000-000000000002', 'x/forged.png', 1,
  'gemini-3.1-flash-image', 'kit_makeup_preview_v2',
  '22000000-0000-4000-8000-000000000002', repeat('1', 64),
  '24000000-0000-4000-8000-000000000001',
  '26000000-0000-4000-8000-000000000001', repeat('3', 64)) $$,
  'P0001', null, 'an abandoned attempt can never become a preview');
select throws_ok($$ insert into public.kit_generated_images (
  user_id, analysis_id, kit_recommendation_id, storage_path, generation_number,
  model_name, prompt_version, plan_id, plan_digest, operation_id,
  accepted_attempt_id, content_sha256
) values (
  '10000000-0000-4000-8000-000000000401', '20000000-0000-4000-8000-000000000401',
  '21000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000401/analyses/20000000-0000-4000-8000-000000000401/kit-generated/21000000-0000-4000-8000-000000000002/preview_0001.png',
  1, 'gemini-3.1-flash-image', 'kit_makeup_preview_v2',
  '22000000-0000-4000-8000-000000000002', repeat('1', 64),
  '24000000-0000-4000-8000-000000000001',
  '26000000-0000-4000-8000-000000000003', repeat('3', 64)) $$,
  'P0001', null, 'an unvalidated candidate can never become a preview');
select isnt(
  public.pdmk_finalize_accepted_attempt(
    '26000000-0000-4000-8000-000000000003', 'kit_preview_validator_v1',
    '{"blush":{"expected":"required_visible","observed":"present"}}'::jsonb),
  null, 'finalize accepts the attempt and writes the preview');
select is(
  public.pdmk_finalize_accepted_attempt(
    '26000000-0000-4000-8000-000000000003', 'kit_preview_validator_v1', '{}'::jsonb),
  (select id from public.kit_generated_images
    where accepted_attempt_id = '26000000-0000-4000-8000-000000000003'),
  'finalize is idempotent');
select is(
  (select status || '/' || terminal_outcome from public.kit_preview_generations
    where id = '25000000-0000-4000-8000-000000000001'),
  'accepted/accepted', 'the generation is accepted with its attempt');
select is(
  (select content_sha256 || ' ' || generation_number from public.kit_generated_images
    where operation_id = '24000000-0000-4000-8000-000000000001'),
  repeat('3', 64) || ' 1', 'the preview carries the accepted bytes and slot');
select is(
  (select count(*)::int from public.kit_generated_images
    where kit_recommendation_id = '21000000-0000-4000-8000-000000000002'),
  1, 'failed and abandoned candidates never became previews');
select throws_ok($$ select pg_temp.attempt(
  gen_random_uuid(), '25000000-0000-4000-8000-000000000001', 4) $$,
  'P0001', null, 'an accepted generation takes no further attempt');
select throws_ok($$ update public.kit_generated_images set generation_number = 2
  where operation_id = '24000000-0000-4000-8000-000000000001' $$,
  'P0001', null, 'a plan-backed preview is immutable');
select pg_temp.as_user('10000000-0000-4000-8000-000000000401');
set local role authenticated;
select throws_ok($$ insert into public.kit_generated_images (
  user_id, analysis_id, kit_recommendation_id, storage_path, generation_number,
  model_name, prompt_version, plan_id, plan_digest, operation_id,
  accepted_attempt_id, content_sha256
) values (
  '10000000-0000-4000-8000-000000000401', '20000000-0000-4000-8000-000000000401',
  '21000000-0000-4000-8000-000000000002',
  '10000000-0000-4000-8000-000000000401/analyses/20000000-0000-4000-8000-000000000401/kit-generated/21000000-0000-4000-8000-000000000002/preview_0001.png',
  1, 'gemini-3.1-flash-image', 'kit_makeup_preview_v2',
  '22000000-0000-4000-8000-000000000002', repeat('1', 64),
  '24000000-0000-4000-8000-000000000001',
  '26000000-0000-4000-8000-000000000003', repeat('3', 64)) $$,
  '42501', null, 'a caller cannot write a plan-backed preview, even a faithful copy');
reset role;

-- ===========================================================================
-- 7. The unchanged usage engine
-- ===========================================================================
select pg_temp.as_user('10000000-0000-4000-8000-000000000401');
select is(
  public.commit_ai_look('24000000-0000-4000-8000-000000000001', 'makeup_kit',
    (select id from public.kit_generated_images
      where operation_id = '24000000-0000-4000-8000-000000000001')) ->> 'ok',
  'true', 'the accepted preview commits the operation');
select is(
  public.commit_ai_look('24000000-0000-4000-8000-000000000001', 'makeup_kit',
    (select id from public.kit_generated_images
      where operation_id = '24000000-0000-4000-8000-000000000001')) ->> 'replayed',
  'true', 'committing again is a replay, never a second charge');

-- A stale reservation whose accepted preview was persisted but never committed.
select pg_temp.stale_reservation('24000000-0000-4000-8000-000000000003');
select pg_temp.generation('25000000-0000-4000-8000-000000000002',
  '24000000-0000-4000-8000-000000000003', repeat('1', 64));
select pg_temp.attempt('26000000-0000-4000-8000-000000000021',
  '25000000-0000-4000-8000-000000000002', 1);
update public.kit_preview_attempts
  set status = 'validating', candidate_sha256 = repeat('4', 64)
  where id = '26000000-0000-4000-8000-000000000021';
select public.pdmk_claim_preview_slot('26000000-0000-4000-8000-000000000021', 'png');
select public.pdmk_finalize_accepted_attempt(
  '26000000-0000-4000-8000-000000000021', 'kit_preview_validator_v1', '{}'::jsonb);
select is(
  public.reconcile_stale_ai_look_reservations(interval '30 minutes') ->> 'committed',
  '1', 'reconciliation commits a lost commit from the accepted preview');
select is(
  (select l.canonical_kit_generated_image_id from public.usage_ledger l
    where l.operation_id = '24000000-0000-4000-8000-000000000003'),
  (select k.id from public.kit_generated_images k
    where k.operation_id = '24000000-0000-4000-8000-000000000003'),
  'the reconciled charge points at that operation''s preview');
select is(
  (select generation_number from public.kit_generated_images
    where operation_id = '24000000-0000-4000-8000-000000000003'),
  2, 'a second preview of one look takes the next slot');

-- A stale reservation whose only attempt failed.
select pg_temp.stale_reservation('24000000-0000-4000-8000-000000000004');
select pg_temp.generation('25000000-0000-4000-8000-000000000003',
  '24000000-0000-4000-8000-000000000004', repeat('1', 64));
select pg_temp.attempt('26000000-0000-4000-8000-000000000031',
  '25000000-0000-4000-8000-000000000003', 1);
update public.kit_preview_attempts
  set status = 'completed', outcome = 'provider_failure',
      reason_code = 'provider_timeout', completed_at = timezone('utc', now())
  where id = '26000000-0000-4000-8000-000000000031';
select is(
  public.reconcile_stale_ai_look_reservations(interval '30 minutes') ->> 'released',
  '1', 'failed attempts leave nothing to charge, so the hold is released');
select lives_ok($$ update public.kit_preview_generations
  set status = 'failed', terminal_outcome = 'reservation_released',
      completed_at = timezone('utc', now()), lease_expires_at = null
  where id = '25000000-0000-4000-8000-000000000003' $$,
  'a released operation ends its generation as reservation_released');

-- ===========================================================================
-- 8. Legacy previews and cascades
-- ===========================================================================
select pg_temp.as_user('10000000-0000-4000-8000-000000000401');
set local role authenticated;
select lives_ok($$ insert into public.kit_generated_images (
  user_id, analysis_id, kit_recommendation_id, storage_path, generation_number,
  model_name, prompt_version
) values (
  '10000000-0000-4000-8000-000000000401', '20000000-0000-4000-8000-000000000401',
  '21000000-0000-4000-8000-000000000001', 'legacy/preview_0001.png', 1,
  'gemini-3.1-flash-image', 'kit_makeup_preview_v1') $$,
  'a caller can still write a legacy kit preview');
reset role;

delete from public.analyses where id = '20000000-0000-4000-8000-000000000401';
select is(
  (select count(*)::int from public.kit_preview_generations
    where user_id = '10000000-0000-4000-8000-000000000401'),
  0, 'deleting a look removes its generations');
select is(
  (select count(*)::int from public.kit_preview_attempts
    where user_id = '10000000-0000-4000-8000-000000000401'),
  0, 'deleting a look removes its attempts');
select is(
  (select count(*)::int from public.kit_generated_images
    where user_id = '10000000-0000-4000-8000-000000000401'),
  0, 'deleting a look removes its previews');
select is(
  (select status || '/' || coalesce(canonical_kit_generated_image_id::text, 'none')
     from public.usage_ledger
    where operation_id = '24000000-0000-4000-8000-000000000001'),
  'committed/none', 'the charge stands after the look is deleted');
select is(
  (select count(*)::int from public.kit_makeup_recommendations
    where user_id = '10000000-0000-4000-8000-000000000402'),
  1, 'another account''s plan is untouched');
select ok(
  has_table_privilege('authenticated', 'public.kit_makeup_recommendations', 'SELECT'),
  'callers still read their own recommendations');

select * from finish();
rollback;
