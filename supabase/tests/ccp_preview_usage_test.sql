-- CCP-6 — attempts, accepted previews, and one charge per logical request.
--
-- Proves the real rules behind the orchestrator: the attempt bound and lease, one
-- worker and one winner per operation, immutable outcomes, and the ledger's third
-- mode through commit, replay, release and reconciliation, with Standard's path
-- still working and history deletion keeping the charge. Rolled back.
begin;

select plan(53);

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
  ('10000000-0000-4000-8000-00000000cd01'::uuid, 'ccp6-alice@example.invalid'),
  ('10000000-0000-4000-8000-00000000cd02'::uuid, 'ccp6-bob@example.invalid')
) as v(id, email);

insert into public.analyses (id, user_id, original_image_path) values
  ('40000000-0000-4000-8000-00000000cd01',
   '10000000-0000-4000-8000-00000000cd01', 'ccp6/alice.png'),
  ('40000000-0000-4000-8000-00000000cd02',
   '10000000-0000-4000-8000-00000000cd02', 'ccp6/bob.png');

insert into public.custom_palette_recommendations (
  id, user_id, analysis_id, makeup_style, palette_request_id, palette_version,
  palette_snapshot_json, palette_digest, recommendation_json, model_name,
  prompt_version
)
select v.id, v.user_id, v.analysis_id, 'soft_glam', gen_random_uuid(),
  'custom_color_palette_contract_v1',
  '[{"category_code":"blush","base_color_value":"#C8102E",
     "adjusted_color_value":"#D93A52","color_label":"Red",
     "finish_code":"matte"}]'::jsonb,
  repeat('a', 64), '{}'::jsonb, 'model', 'custom_palette_recommendation_v1'
from (values
  ('50000000-0000-4000-8000-00000000cd01'::uuid,
   '10000000-0000-4000-8000-00000000cd01'::uuid,
   '40000000-0000-4000-8000-00000000cd01'::uuid),
  ('50000000-0000-4000-8000-00000000cd02'::uuid,
   '10000000-0000-4000-8000-00000000cd02'::uuid,
   '40000000-0000-4000-8000-00000000cd02'::uuid)
) as v(id, user_id, analysis_id);

-- Helpers, so each case below names only what matters.
create function pg_temp.claim(p_operation uuid, p_lease integer default 180)
returns jsonb language sql as $$
  select public.claim_custom_palette_preview_attempt(
    '10000000-0000-4000-8000-00000000cd01', p_operation,
    '50000000-0000-4000-8000-00000000cd01', 2, p_lease,
    'custom_palette_preview_v1'
  );
$$;

create function pg_temp.finish(
  p_operation uuid, p_attempt integer, p_status text
) returns jsonb language sql as $$
  select public.finish_custom_palette_preview_attempt(
    '10000000-0000-4000-8000-00000000cd01', p_operation, p_attempt, p_status,
    array['blush'], array['blush:hue_differs'], 'custom_palette_validator_v1'
  );
$$;

create function pg_temp.finalize(
  p_operation uuid, p_attempt integer, p_path text
) returns jsonb language sql as $$
  select public.finalize_custom_palette_preview(
    '10000000-0000-4000-8000-00000000cd01', p_operation, p_attempt, p_path,
    'gemini-3.1-flash-image', 'custom_palette_preview_v1',
    'custom_palette_validator_v1'
  );
$$;

create function pg_temp.as_user(p_user uuid) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
$$;

-- ---------------------------------------------------------------------------
-- The attempt bound
-- ---------------------------------------------------------------------------
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd01')->>'status',
  'claimed', 'the first claim succeeds'
);
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd01')->>'status',
  'in_progress', 'a duplicate invocation cannot start a second attempt'
);
select is(
  (select count(*)::int from public.custom_palette_preview_attempts
   where operation_id = '60000000-0000-4000-8000-00000000cd01'),
  1, 'and it left no row'
);
select is(
  pg_temp.finish(
    '60000000-0000-4000-8000-00000000cd01', 1, 'retryable_palette_mismatch'
  )->>'ok',
  'true', 'a running attempt can finish'
);
select is(
  pg_temp.finish(
    '60000000-0000-4000-8000-00000000cd01', 1, 'provider_failure'
  )->>'status',
  'stale', 'a duplicate completion changes nothing'
);
select is(
  (select status from public.custom_palette_preview_attempts
   where operation_id = '60000000-0000-4000-8000-00000000cd01'),
  'retryable_palette_mismatch', 'the first outcome stands'
);
select results_eq(
  $$ select
       (c->>'status')::text, (c->>'attemptNumber')::int,
       (c->>'generationNumber')::int, c->'previousReasons'
     from (select pg_temp.claim('60000000-0000-4000-8000-00000000cd01') as c) s $$,
  $$ values ('claimed'::text, 2, 2, '["blush:hue_differs"]'::jsonb) $$,
  'a retry gets a new number, a new path, and the evidence'
);
select is(
  pg_temp.finish(
    '60000000-0000-4000-8000-00000000cd01', 2, 'validator_failure'
  )->>'ok',
  'true', 'the second attempt finishes'
);
select results_eq(
  $$ select (c->>'status')::text, (c->>'lastStatus')::text
     from (select pg_temp.claim('60000000-0000-4000-8000-00000000cd01') as c) s $$,
  $$ values ('exhausted'::text, 'validator_failure'::text) $$,
  'the bound holds'
);

-- A nonretryable mismatch ends the request whatever the bound allows.
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd02')->>'status',
  'claimed', 'a separate operation has its own count'
);
select pg_temp.finish(
  '60000000-0000-4000-8000-00000000cd02', 1, 'nonretryable_palette_mismatch'
);
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd02')->>'status',
  'terminal', 'a nonretryable mismatch cannot be retried'
);

-- An expired lease: the attempt counts, and a new worker can continue.
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd03', 1)->>'status',
  'claimed', 'a worker claims'
);
update public.custom_palette_preview_attempts
  set lease_expires_at = timezone('utc', now()) - interval '1 second'
  where operation_id = '60000000-0000-4000-8000-00000000cd03';
select is(
  (pg_temp.claim('60000000-0000-4000-8000-00000000cd03'))->>'attemptNumber',
  '2', 'a dead worker''s attempt counts and the next one proceeds'
);
select is(
  (select status from public.custom_palette_preview_attempts
   where operation_id = '60000000-0000-4000-8000-00000000cd03'
     and attempt_number = 1),
  'abandoned', 'and it is recorded as abandoned'
);
select is(
  pg_temp.finalize(
    '60000000-0000-4000-8000-00000000cd03', 1, 'ccp6/stale.png'
  )->>'status',
  'stale', 'the dead worker cannot finalize when it wakes up'
);

select is(
  public.claim_custom_palette_preview_attempt(
    '10000000-0000-4000-8000-00000000cd01',
    '60000000-0000-4000-8000-00000000cd03',
    '50000000-0000-4000-8000-00000000cd02', 2, 180, 'p'
  )->>'status',
  'not_found', 'a look that is not the caller''s cannot be claimed'
);
select is(
  public.claim_custom_palette_preview_attempt(
    '10000000-0000-4000-8000-00000000cd02',
    '60000000-0000-4000-8000-00000000cd03',
    '50000000-0000-4000-8000-00000000cd02', 2, 180, 'p'
  )->>'status',
  'conflict', 'an operation id cannot move to another account or look'
);

-- ---------------------------------------------------------------------------
-- One accepted preview, only with a reservation
-- ---------------------------------------------------------------------------
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd04')->>'status',
  'claimed', 'an attempt with no reservation can run'
);
select is(
  pg_temp.finalize(
    '60000000-0000-4000-8000-00000000cd04', 1, 'ccp6/none.png'
  )->>'status',
  'no_reservation', 'but it cannot become a preview'
);
select is(
  (select count(*)::int from public.custom_palette_generated_images
   where operation_id = '60000000-0000-4000-8000-00000000cd04'),
  0, 'so no preview exists'
);

-- ---------------------------------------------------------------------------
-- The ledger: commit, replay, one charge
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd01');
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd05')->>'ok',
  'true', 'the operation is reserved'
);
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd05')->>'replayed',
  'true', 'a repeat is the same reservation'
);
reset role;

select is(
  (select count(*)::int from public.usage_ledger
   where operation_id = '60000000-0000-4000-8000-00000000cd05'),
  1, 'one logical reservation'
);
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd05')->>'status',
  'claimed', 'the attempt is claimed'
);
select is(
  pg_temp.finalize(
    '60000000-0000-4000-8000-00000000cd05', 1, 'ccp6/accepted.png'
  )->>'replayed',
  'false', 'the accepted candidate becomes a preview'
);
select is(
  pg_temp.finalize(
    '60000000-0000-4000-8000-00000000cd05', 1, 'ccp6/duplicate.png'
  )->'preview'->>'storage_path',
  'ccp6/accepted.png', 'a duplicate completion returns the same preview'
);
select is(
  (select count(*)::int from public.custom_palette_generated_images
   where operation_id = '60000000-0000-4000-8000-00000000cd05'),
  1, 'one preview'
);
select is(
  (select status from public.custom_palette_preview_attempts
   where operation_id = '60000000-0000-4000-8000-00000000cd05'),
  'accepted', 'its attempt is accepted'
);
select is(
  pg_temp.claim('60000000-0000-4000-8000-00000000cd05')->>'status',
  'accepted', 'a later claim finds the result instead of generating'
);

create temp table ccp_preview as
  select id from public.custom_palette_generated_images
  where operation_id = '60000000-0000-4000-8000-00000000cd05';
grant select on ccp_preview to authenticated;

set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd01');
select is(
  (public.commit_ai_look(
    '60000000-0000-4000-8000-00000000cd05', 'custom_color_palette',
    (select id from ccp_preview)
  ))->>'replayed',
  'false', 'the first commit charges'
);
select is(
  (public.commit_ai_look(
    '60000000-0000-4000-8000-00000000cd05', 'custom_color_palette',
    (select id from ccp_preview)
  ))->>'replayed',
  'true', 'a duplicate commit does not'
);
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd05')->>'errorCode',
  'USAGE_ALREADY_COMMITTED', 'a replay sees the committed result'
);
select is(
  public.release_ai_look(
    '60000000-0000-4000-8000-00000000cd05', 'x'
  )->>'errorCode',
  'USAGE_ALREADY_COMMITTED', 'a committed operation cannot be released'
);
select is(
  (public.commit_ai_look(
    '60000000-0000-4000-8000-00000000cd05', 'standard',
    (select id from ccp_preview)
  ))->>'errorCode',
  'USAGE_STATE_CONFLICT', 'a palette preview cannot be charged as Standard'
);
select is(
  (public.commit_ai_look(
    '60000000-0000-4000-8000-00000000cd05', 'makeup_kit',
    (select id from ccp_preview)
  ))->>'errorCode',
  'USAGE_STATE_CONFLICT', 'or as My Makeup Kit'
);
select is(
  (select source_mode from public.usage_ledger
   where operation_id = '60000000-0000-4000-8000-00000000cd05'),
  'custom_color_palette', 'the ledger names the real mode'
);
reset role;

select is(
  (select canonical_custom_palette_preview_id from public.usage_ledger
   where operation_id = '60000000-0000-4000-8000-00000000cd05'),
  (select id from ccp_preview), 'and the real preview'
);

-- Committed usage stays immutable through the new column.
select throws_ok(
  $$ update public.usage_ledger
     set canonical_custom_palette_preview_id = gen_random_uuid()
     where operation_id = '60000000-0000-4000-8000-00000000cd05' $$,
  'P0001', 'committed usage_ledger rows are immutable historical records',
  'a committed charge cannot be pointed at another preview'
);

-- ---------------------------------------------------------------------------
-- Release gives capacity back
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd02');
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd06')->>'ok',
  'true', 'Bob reserves'
);
select is(
  public.release_ai_look(
    '60000000-0000-4000-8000-00000000cd06', 'retryable_palette_mismatch'
  )->>'status',
  'released', 'a terminal failure releases'
);
select results_eq(
  $$ select status, source_mode, sanitized_failure_code
     from public.usage_ledger
     where operation_id = '60000000-0000-4000-8000-00000000cd06' $$,
  $$ values (
    'released'::text, null::text, 'retryable_palette_mismatch'::text
  ) $$,
  'with no mode and no charge'
);
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd06')->>'errorCode',
  'USAGE_ALREADY_RELEASED', 'a released operation stays released'
);
select is(
  public.reserve_ai_look('60000000-0000-4000-8000-00000000cd07')->>'ok',
  'true', 'and the capacity can be used again'
);
reset role;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd01');
select throws_ok(
  $$ select public.finalize_custom_palette_preview(
    '10000000-0000-4000-8000-00000000cd01',
    '60000000-0000-4000-8000-00000000cd05', 1, 'x', 'm', 'p', 'v'
  ) $$,
  '42501', null, 'a client cannot accept its own preview'
);
select throws_ok(
  $$ select public.claim_custom_palette_preview_attempt(
    '10000000-0000-4000-8000-00000000cd01',
    '60000000-0000-4000-8000-00000000cd08',
    '50000000-0000-4000-8000-00000000cd01', 99, 180, 'p'
  ) $$,
  '42501', null, 'a client cannot claim attempts or raise the bound'
);
select throws_ok(
  $$ select * from public.custom_palette_preview_attempts $$,
  '42501', 'permission denied for table custom_palette_preview_attempts',
  'a client cannot read attempts'
);
select throws_ok(
  $$ delete from public.custom_palette_generated_images $$,
  '42501', 'permission denied for table custom_palette_generated_images',
  'a client cannot delete a preview directly'
);
select is(
  (select count(*)::int from public.custom_palette_generated_images),
  1, 'an account reads its own accepted previews'
);
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd02');
select is(
  (select count(*)::int from public.custom_palette_generated_images),
  0, 'and no other account''s'
);
reset role;

-- ---------------------------------------------------------------------------
-- Immutability
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.custom_palette_preview_attempts set status = 'accepted'
     where operation_id = '60000000-0000-4000-8000-00000000cd01'
       and attempt_number = 1 $$,
  'P0001', 'a finished custom palette attempt is immutable',
  'a failed attempt cannot be turned into an accepted one'
);

-- ---------------------------------------------------------------------------
-- Reconciliation resolves CCP reservations from exact evidence
-- ---------------------------------------------------------------------------
-- Attempts but no preview: released, never matched to an unrelated preview.
select public.claim_custom_palette_preview_attempt(
  '10000000-0000-4000-8000-00000000cd02',
  '60000000-0000-4000-8000-00000000cd07',
  '50000000-0000-4000-8000-00000000cd02', 2, 180, 'p'
);
select public.finish_custom_palette_preview_attempt(
  '10000000-0000-4000-8000-00000000cd02',
  '60000000-0000-4000-8000-00000000cd07', 1, 'provider_failure'
);
update public.usage_ledger
  set reserved_at = timezone('utc', now()) - interval '1 hour'
  where operation_id = '60000000-0000-4000-8000-00000000cd07';
select public.reconcile_stale_ai_look_reservations();
select results_eq(
  $$ select status, sanitized_failure_code from public.usage_ledger
     where operation_id = '60000000-0000-4000-8000-00000000cd07' $$,
  $$ values ('released'::text, 'stale_reservation_reconciled'::text) $$,
  'a stale reservation that produced nothing is released'
);

-- A preview whose commit never landed: charged, by its own operation id.
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000cd02');
select public.reserve_ai_look('60000000-0000-4000-8000-00000000cd08');
reset role;
select public.claim_custom_palette_preview_attempt(
  '10000000-0000-4000-8000-00000000cd02',
  '60000000-0000-4000-8000-00000000cd08',
  '50000000-0000-4000-8000-00000000cd02', 2, 180, 'p'
);
select public.finalize_custom_palette_preview(
  '10000000-0000-4000-8000-00000000cd02',
  '60000000-0000-4000-8000-00000000cd08', 1, 'ccp6/bob.png', 'm', 'p', 'v'
);
update public.usage_ledger
  set reserved_at = timezone('utc', now()) - interval '1 hour'
  where operation_id = '60000000-0000-4000-8000-00000000cd08';
select public.reconcile_stale_ai_look_reservations();
select results_eq(
  $$ select l.status, l.source_mode, l.canonical_custom_palette_preview_id
     from public.usage_ledger as l
     where l.operation_id = '60000000-0000-4000-8000-00000000cd08' $$,
  $$ select 'committed'::text, 'custom_color_palette'::text, i.id
     from public.custom_palette_generated_images as i
     where i.operation_id = '60000000-0000-4000-8000-00000000cd08' $$,
  'a preview with a lost commit is charged exactly once, by operation id'
);

-- ---------------------------------------------------------------------------
-- Deleting history keeps the charge and removes the look
-- ---------------------------------------------------------------------------
delete from public.analyses
  where id = '40000000-0000-4000-8000-00000000cd01';
select results_eq(
  $$ select status, source_mode, canonical_custom_palette_preview_id
     from public.usage_ledger
     where operation_id = '60000000-0000-4000-8000-00000000cd05' $$,
  $$ values ('committed'::text, 'custom_color_palette'::text, null::uuid) $$,
  'the charge survives and only the link clears'
);

select * from finish();
rollback;
