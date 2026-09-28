-- OMKT — My Makeup Kit snapshot-authoritative Tutorial step eligibility.
--
-- Proves the release-gate matrix at the database layer:
--
--   Standard:        present -> step; absent -> no step; uncertain -> no step
--   My Makeup Kit:   selected + present / absent / uncertain -> step
--                    not selected + absent / uncertain -> no step
--
-- plus that product backing is My Makeup Kit only, the analyzer's own kit
-- manifest now persists, generated columns cannot be written, cascade and
-- RLS still hold, and the replaced constraints are gone.
--
-- "Not selected + present" stays step-eligible in the database, exactly as
-- before this migration; the server resolver and the Flutter planner are what
-- refuse it (see tutorial_source_resolver_test.ts and the Flutter tests).
-- Rolled back.
begin;

select plan(31);

-- ---------------------------------------------------------------------------
-- Fixtures: Alice owns one Standard and two My Makeup Kit sessions; Bob owns
-- nothing. The kit snapshot is the OMKT target example: foundation, blush,
-- eyeshadow, lipstick.
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
  ('10000000-0000-4000-8000-00000000c301'::uuid, 'omkt-alice@example.invalid'),
  ('10000000-0000-4000-8000-00000000c302'::uuid, 'omkt-bob@example.invalid')
) as v(id, email);

insert into public.analyses (id, user_id, original_image_path) values (
  '40000000-0000-4000-8000-00000000c301',
  '10000000-0000-4000-8000-00000000c301',
  '10000000-0000-4000-8000-00000000c301/analyses/40000000-0000-4000-8000-00000000c301/original/selfie.jpg'
);
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
values (
  '41000000-0000-4000-8000-00000000c301',
  '10000000-0000-4000-8000-00000000c301',
  '40000000-0000-4000-8000-00000000c301', 'natural'
);
insert into public.generated_images (
  id, user_id, analysis_id, recommendation_id, storage_path, generation_number
)
select v.id, '10000000-0000-4000-8000-00000000c301',
  '40000000-0000-4000-8000-00000000c301',
  '41000000-0000-4000-8000-00000000c301', v.path, v.n
from (values
  ('42000000-0000-4000-8000-00000000c301'::uuid, 'omkt/standard_1.png', 1),
  ('42000000-0000-4000-8000-00000000c302'::uuid, 'omkt/standard_2.png', 2)
) as v(id, path, n);
insert into public.kit_makeup_recommendations (
  id, user_id, analysis_id, makeup_style, recommendation_json,
  product_snapshot_json, model_name, prompt_version
) values (
  '43000000-0000-4000-8000-00000000c301',
  '10000000-0000-4000-8000-00000000c301',
  '40000000-0000-4000-8000-00000000c301', 'natural', '{}'::jsonb,
  '[{"productId":"p1","category":"foundation"},
    {"productId":"p2","category":"blush"},
    {"productId":"p3","category":"eyeshadow"},
    {"productId":"p4","category":"lipstick"}]'::jsonb,
  'model', 'kit_makeup_recommendation_v2'
);
insert into public.kit_generated_images (
  id, user_id, analysis_id, kit_recommendation_id, storage_path,
  generation_number, model_name, prompt_version
)
select v.id, '10000000-0000-4000-8000-00000000c301',
  '40000000-0000-4000-8000-00000000c301',
  '43000000-0000-4000-8000-00000000c301', v.path, v.n, 'model',
  'kit_makeup_preview_v1'
from (values
  ('44000000-0000-4000-8000-00000000c301'::uuid, 'omkt/kit_1.png', 1),
  ('44000000-0000-4000-8000-00000000c302'::uuid, 'omkt/kit_2.png', 2)
) as v(id, path, n);

-- S = Standard, K = kit (target example), A = kit with a selected ABSENT lips.
insert into public.tutorial_v4_sessions (
  id, user_id, analysis_id, source_mode, recommendation_id,
  canonical_generated_image_id, kit_recommendation_id,
  canonical_kit_generated_image_id, status, manifest_status, manifest_model,
  manifest_prompt_version, manifest_schema_version, manifest_created_at
)
select v.id, '10000000-0000-4000-8000-00000000c301',
  '40000000-0000-4000-8000-00000000c301', v.mode, v.rec, v.img, v.kit_rec,
  v.kit_img, v.status, v.manifest_status, 'gemini-3.6-flash',
  'tutorial_manifest_v4_1', 'tutorial_manifest_schema_v1',
  timezone('utc', now())
from (values
  ('45000000-0000-4000-8000-00000000c301'::uuid, 'standard',
   '41000000-0000-4000-8000-00000000c301'::uuid,
   '42000000-0000-4000-8000-00000000c301'::uuid, null::uuid, null::uuid,
   'manifest_ready', 'accepted'),
  ('45000000-0000-4000-8000-00000000c302'::uuid, 'my_makeup_kit', null, null,
   '43000000-0000-4000-8000-00000000c301'::uuid,
   '44000000-0000-4000-8000-00000000c301'::uuid,
   'kit_preview_mismatch', 'kit_preview_mismatch'),
  ('45000000-0000-4000-8000-00000000c303'::uuid, 'my_makeup_kit', null, null,
   '43000000-0000-4000-8000-00000000c301'::uuid,
   '44000000-0000-4000-8000-00000000c302'::uuid,
   'manifest_ready', 'accepted')
) as v(id, mode, rec, img, kit_rec, kit_img, status, manifest_status);

-- ---------------------------------------------------------------------------
-- 1. The analyzer's own kit manifest now persists
-- ---------------------------------------------------------------------------
-- Exactly what analyze-tutorial-manifest-v4 writes for the target example:
-- product_backed follows the snapshot, whatever the verdict. The baseline
-- schema rejected this row set (tutorial_v4_manifest_items_absent_not_backed).
select lives_ok(
  $$insert into public.tutorial_v4_manifest_items
      (user_id, tutorial_session_id, category, position, presence, product_backed)
    select '10000000-0000-4000-8000-00000000c301',
           '45000000-0000-4000-8000-00000000c302', v.category, v.position,
           v.presence, v.category in ('foundation', 'blush', 'eyeshadow', 'lips')
      from (values
        ('foundation', 1, 'uncertain'), ('concealer', 2, 'present'),
        ('contour_bronzer', 3, 'absent'), ('blush', 4, 'present'),
        ('highlighter', 5, 'absent'), ('eyebrows', 6, 'absent'),
        ('eyeshadow', 7, 'uncertain'), ('eyeliner', 8, 'absent'),
        ('lips', 9, 'present')) as v(category, position, presence)$$,
  'the analyzer kit manifest with selected uncertain categories persists'
);

-- The Standard session gets the same verdicts and, as the analyzer writes for
-- Standard Mode, no backing at all.
insert into public.tutorial_v4_manifest_items
  (user_id, tutorial_session_id, category, position, presence, product_backed)
select '10000000-0000-4000-8000-00000000c301',
       '45000000-0000-4000-8000-00000000c301', v.category, v.position,
       v.presence, false
  from (values
    ('foundation', 1, 'uncertain'), ('concealer', 2, 'present'),
    ('contour_bronzer', 3, 'absent'), ('blush', 4, 'present'),
    ('highlighter', 5, 'absent'), ('eyebrows', 6, 'absent'),
    ('eyeshadow', 7, 'uncertain'), ('eyeliner', 8, 'absent'),
    ('lips', 9, 'present')) as v(category, position, presence);

-- Session A: lips is selected but judged ABSENT.
insert into public.tutorial_v4_manifest_items
  (user_id, tutorial_session_id, category, position, presence, product_backed)
select '10000000-0000-4000-8000-00000000c301',
       '45000000-0000-4000-8000-00000000c303', v.category, v.position,
       'absent', v.category = 'lips'
  from (values
    ('foundation', 1), ('concealer', 2), ('contour_bronzer', 3), ('blush', 4),
    ('highlighter', 5), ('eyebrows', 6), ('eyeshadow', 7), ('eyeliner', 8),
    ('lips', 9)) as v(category, position);

create function pg_temp.step_sql(p_session text, p_category text, p_position int)
returns text language sql as $$
  select format(
    'insert into public.tutorial_v4_steps (user_id, tutorial_session_id, category, position) '
    'values (%L, %L, %L, %s)',
    '10000000-0000-4000-8000-00000000c301', p_session, p_category, p_position)
$$;

-- ---------------------------------------------------------------------------
-- 2. Standard Mode — unchanged: present -> step, absent/uncertain -> no step
-- ---------------------------------------------------------------------------
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c301', 'blush', 1),
  'Standard: present -> step allowed'
);
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c301', 'concealer', 2),
  'Standard: present (never product-backed) -> step allowed'
);
select throws_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c301', 'eyeliner', 3),
  '23503', null,
  'Standard: absent -> step rejected'
);
select throws_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c301', 'foundation', 4),
  '23503', null,
  'Standard: uncertain -> step rejected'
);
select throws_ok(
  $$update public.tutorial_v4_manifest_items set product_backed = true
     where tutorial_session_id = '45000000-0000-4000-8000-00000000c301'
       and category = 'eyeshadow'$$,
  '23503', null,
  'Standard: an item cannot be marked product-backed (backing is kit only)'
);
select throws_ok(
  $$insert into public.tutorial_v4_manifest_items
      (user_id, tutorial_session_id, category, position, presence, product_backed)
    values ('10000000-0000-4000-8000-00000000c301',
            '45000000-0000-4000-8000-00000000c301', 'lips', 9, 'uncertain', true)$$,
  '23505', null,
  'Standard: one verdict per category still holds'
);
select is(
  (select array_agg(category order by position)
     from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c301'
      and step_eligible),
  array['concealer', 'blush', 'lips']::text[],
  'Standard: step-eligible set is exactly the visually present set'
);

-- ---------------------------------------------------------------------------
-- 3. My Makeup Kit — selected categories get steps whatever the verdict
-- ---------------------------------------------------------------------------
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c302', 'foundation', 1),
  'Kit: selected + uncertain (foundation) -> step allowed'
);
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c302', 'blush', 2),
  'Kit: selected + present (blush) -> step allowed'
);
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c302', 'eyeshadow', 3),
  'Kit: selected + uncertain (eyeshadow) -> step allowed'
);
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c302', 'lips', 4),
  'Kit: selected + present (lips) -> step allowed'
);
select lives_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c303', 'lips', 1),
  'Kit: selected + absent -> step allowed'
);
select throws_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c302', 'eyeliner', 5),
  '23503', null,
  'Kit: not selected + absent -> step rejected'
);
select throws_ok(
  pg_temp.step_sql('45000000-0000-4000-8000-00000000c303', 'blush', 2),
  '23503', null,
  'Kit: not selected + absent (other session) -> step rejected'
);
select is(
  (select array_agg(category order by position)
     from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'
      and product_backed),
  array['foundation', 'blush', 'eyeshadow', 'lips']::text[],
  'Kit: the backed set is exactly the snapshot set, concealer excluded'
);
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'
      and category = 'concealer'),
  true,
  'Kit: not selected + present stays DB-eligible as before; the resolver and planner refuse it'
);

-- ---------------------------------------------------------------------------
-- 4. Generated columns and source-mode integrity
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(distinct product_backing_guard)
     from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c301'),
  array[null]::boolean[],
  'Standard items carry a NULL backing guard'
);
select is(
  (select is_my_makeup_kit from public.tutorial_v4_sessions
    where id = '45000000-0000-4000-8000-00000000c302'),
  true,
  'a kit session reports is_my_makeup_kit'
);
select throws_ok(
  $$update public.tutorial_v4_sessions
       set source_mode = 'standard',
           recommendation_id = '41000000-0000-4000-8000-00000000c301',
           canonical_generated_image_id = '42000000-0000-4000-8000-00000000c302',
           kit_recommendation_id = null,
           canonical_kit_generated_image_id = null
     where id = '45000000-0000-4000-8000-00000000c303'$$,
  '23503', null,
  'a session holding backed items cannot be switched to Standard Mode'
);
select throws_ok(
  $$update public.tutorial_v4_manifest_items set step_eligible = true
     where tutorial_session_id = '45000000-0000-4000-8000-00000000c301'$$,
  '428C9', null,
  'step_eligible cannot be written directly'
);
select throws_ok(
  $$update public.tutorial_v4_steps set manifest_step_eligible = false
     where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'$$,
  '23514', null,
  'a step cannot opt out of the eligibility pin'
);

-- ---------------------------------------------------------------------------
-- 5. Constraint inventory
-- ---------------------------------------------------------------------------
select hasnt_column('public', 'tutorial_v4_steps', 'manifest_presence',
  'the presence pin column is gone');
select is(
  (select count(*)::int from pg_constraint
    where conname in (
      'tutorial_v4_manifest_items_absent_not_backed',
      'tutorial_v4_steps_included_category_fk',
      'tutorial_v4_steps_manifest_presence_pinned')),
  0,
  'the three replaced constraints are dropped'
);
select is(
  (select count(*)::int from pg_constraint
    where conname in (
      'tutorial_v4_sessions_kit_identity',
      'tutorial_v4_manifest_items_backing_is_kit_only',
      'tutorial_v4_manifest_items_step_eligibility_identity',
      'tutorial_v4_steps_manifest_step_eligible_pinned',
      'tutorial_v4_steps_eligible_category_fk')),
  5,
  'the five replacement constraints exist'
);
select is(
  (select count(*)::int from pg_constraint
    where conname in (
      'tutorial_v4_sessions_mismatch_is_kit_only',
      'tutorial_v4_sessions_source_mode_lineage',
      'tutorial_v4_manifest_items_category_unique',
      'tutorial_v4_manifest_items_presence_valid',
      'tutorial_v4_steps_category_unique',
      'tutorial_v4_steps_position_unique',
      'tutorial_v4_steps_ready_is_complete',
      'tutorial_v4_steps_guideline_path_owned')),
  8,
  'unrelated tutorial integrity constraints are untouched'
);

-- ---------------------------------------------------------------------------
-- 6. RLS — the client write path still enforces ownership
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-00000000c301","role":"authenticated"}', true);
select lives_ok(
  $$insert into public.tutorial_v4_steps (user_id, tutorial_session_id, category, position)
    values ('10000000-0000-4000-8000-00000000c301',
            '45000000-0000-4000-8000-00000000c303', 'lips', 1)
    on conflict (tutorial_session_id, category) do nothing$$,
  'owner: the Flutter step insert works for a selected absent category'
);

select set_config('request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-00000000c302","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.tutorial_v4_steps (user_id, tutorial_session_id, category, position)
    values ('10000000-0000-4000-8000-00000000c301',
            '45000000-0000-4000-8000-00000000c302', 'blush', 9)$$,
  '42501', null,
  'another user cannot insert a step into the owner''s session'
);
select is(
  (select count(*)::int from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'),
  0,
  'another user sees none of the owner''s manifest items'
);
reset role;

-- ---------------------------------------------------------------------------
-- 7. Cascade
-- ---------------------------------------------------------------------------
delete from public.tutorial_v4_sessions
 where id = '45000000-0000-4000-8000-00000000c302';
select is(
  (select count(*)::int from public.tutorial_v4_manifest_items
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'),
  0,
  'deleting a kit session removes its manifest items'
);
select is(
  (select count(*)::int from public.tutorial_v4_steps
    where tutorial_session_id = '45000000-0000-4000-8000-00000000c302'),
  0,
  'deleting a kit session removes its steps, including non-present ones'
);

select * from finish();
rollback;
