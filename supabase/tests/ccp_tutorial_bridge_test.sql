-- CCP-7 — the Tutorial bridge and Saved Looks.
--
-- Proves a Custom Color Palette session has its own lineage and step rule, that
-- `palette_backed` cannot reach another mode, that Standard and My Makeup Kit step
-- rules did not move, that Tutorial authorization knows all three modes, and that
-- saved looks are private and deletion still cascades. Rolled back.
begin;

select plan(32);

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
  ('10000000-0000-4000-8000-00000000ce01'::uuid, 'ccp7-alice@example.invalid'),
  ('10000000-0000-4000-8000-00000000ce02'::uuid, 'ccp7-bob@example.invalid')
) as v(id, email);

insert into public.analyses (id, user_id, original_image_path) values
  ('40000000-0000-4000-8000-00000000ce01',
   '10000000-0000-4000-8000-00000000ce01', 'ccp7/alice.png');

insert into public.custom_palette_recommendations (
  id, user_id, analysis_id, makeup_style, palette_request_id, palette_version,
  palette_snapshot_json, palette_digest, recommendation_json, model_name,
  prompt_version
) values (
  '50000000-0000-4000-8000-00000000ce01',
  '10000000-0000-4000-8000-00000000ce01',
  '40000000-0000-4000-8000-00000000ce01', 'soft_glam', gen_random_uuid(),
  'custom_color_palette_contract_v1',
  '[{"category_code":"blush","base_color_value":"#C8102E",
     "adjusted_color_value":"#D93A52","color_label":"Red",
     "finish_code":"matte"}]'::jsonb,
  repeat('a', 64), '{}'::jsonb, 'model', 'custom_palette_recommendation_v1'
);

insert into public.custom_palette_generated_images (
  id, user_id, analysis_id, custom_palette_recommendation_id, storage_path,
  generation_number, operation_id, accepted_attempt_number, validation_outcome,
  validator_version, model_name, prompt_version
) values (
  '51000000-0000-4000-8000-00000000ce01',
  '10000000-0000-4000-8000-00000000ce01',
  '40000000-0000-4000-8000-00000000ce01',
  '50000000-0000-4000-8000-00000000ce01', 'ccp7/preview_0001.png', 1,
  gen_random_uuid(), 1, 'accepted', 'custom_palette_validator_v1',
  'gemini-3.1-flash-image', 'custom_palette_preview_v1'
);

insert into public.recommendations (id, user_id, analysis_id, makeup_style)
values (
  '52000000-0000-4000-8000-00000000ce01',
  '10000000-0000-4000-8000-00000000ce01',
  '40000000-0000-4000-8000-00000000ce01', 'natural'
);
insert into public.generated_images (
  id, user_id, analysis_id, recommendation_id, storage_path, generation_number
) values (
  '53000000-0000-4000-8000-00000000ce01',
  '10000000-0000-4000-8000-00000000ce01',
  '40000000-0000-4000-8000-00000000ce01',
  '52000000-0000-4000-8000-00000000ce01', 'ccp7/standard.png', 1
);

create function pg_temp.as_user(p_user uuid) returns void language sql as $$
  select set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user, 'role', 'authenticated')::text,
    true
  );
$$;

-- ---------------------------------------------------------------------------
-- Session lineage
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.tutorial_v4_sessions (
       id, user_id, analysis_id, source_mode,
       custom_palette_recommendation_id, canonical_custom_palette_preview_id,
       status, manifest_status, manifest_model, manifest_prompt_version,
       manifest_schema_version, manifest_created_at
     ) values (
       '60000000-0000-4000-8000-00000000ce01',
       '10000000-0000-4000-8000-00000000ce01',
       '40000000-0000-4000-8000-00000000ce01', 'custom_color_palette',
       '50000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01',
       'manifest_ready', 'accepted', 'gemini-3.6-flash',
       'tutorial_manifest_v4_1', 'tutorial_manifest_schema_v1',
       timezone('utc', now())
     ) $$,
  'a palette session is valid with its own lineage'
);
select is(
  (select is_custom_palette from public.tutorial_v4_sessions
   where id = '60000000-0000-4000-8000-00000000ce01'),
  true, 'and it reports the mode'
);
select throws_ok(
  $$ insert into public.tutorial_v4_sessions (
       user_id, analysis_id, source_mode, custom_palette_recommendation_id
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '40000000-0000-4000-8000-00000000ce01', 'custom_color_palette',
       '50000000-0000-4000-8000-00000000ce01'
     ) $$,
  '23514', null, 'a palette session needs its accepted preview'
);
select throws_ok(
  $$ insert into public.tutorial_v4_sessions (
       user_id, analysis_id, source_mode, recommendation_id,
       canonical_generated_image_id, canonical_custom_palette_preview_id
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '40000000-0000-4000-8000-00000000ce01', 'standard',
       '52000000-0000-4000-8000-00000000ce01',
       '53000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01'
     ) $$,
  '23514', null, 'a Standard session cannot carry a palette preview'
);
select throws_ok(
  $$ insert into public.tutorial_v4_sessions (
       user_id, analysis_id, source_mode, custom_palette_recommendation_id,
       canonical_custom_palette_preview_id
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '40000000-0000-4000-8000-00000000ce01', 'custom_color_palette',
       '50000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01'
     ) $$,
  '23505', null, 'one session per preview'
);
select throws_ok(
  $$ update public.tutorial_v4_sessions
     set status = 'kit_preview_mismatch',
         manifest_status = 'kit_preview_mismatch'
     where id = '60000000-0000-4000-8000-00000000ce01' $$,
  '23514', null, 'the kit mismatch status stays kit-only'
);

-- A Standard session to compare against.
insert into public.tutorial_v4_sessions (
  id, user_id, analysis_id, source_mode, recommendation_id,
  canonical_generated_image_id, status, manifest_status, manifest_model,
  manifest_prompt_version, manifest_schema_version, manifest_created_at
) values (
  '60000000-0000-4000-8000-00000000ce02',
  '10000000-0000-4000-8000-00000000ce01',
  '40000000-0000-4000-8000-00000000ce01', 'standard',
  '52000000-0000-4000-8000-00000000ce01',
  '53000000-0000-4000-8000-00000000ce01',
  'manifest_ready', 'accepted', 'gemini-3.6-flash',
  'tutorial_manifest_v4_1', 'tutorial_manifest_schema_v1',
  timezone('utc', now())
);

-- ---------------------------------------------------------------------------
-- palette_backed and step eligibility
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ insert into public.tutorial_v4_manifest_items (
       user_id, tutorial_session_id, category, position, presence,
       palette_backed
     ) values
       ('10000000-0000-4000-8000-00000000ce01',
        '60000000-0000-4000-8000-00000000ce01', 'blush', 4, 'absent', true),
       ('10000000-0000-4000-8000-00000000ce01',
        '60000000-0000-4000-8000-00000000ce01', 'lips', 9, 'uncertain', true),
       ('10000000-0000-4000-8000-00000000ce01',
        '60000000-0000-4000-8000-00000000ce01', 'eyeliner', 8, 'absent', false)
  $$,
  'selected categories persist whatever the visual verdict'
);
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
   where tutorial_session_id = '60000000-0000-4000-8000-00000000ce01'
     and category = 'blush'),
  true, 'selected and judged absent is step-eligible'
);
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
   where tutorial_session_id = '60000000-0000-4000-8000-00000000ce01'
     and category = 'lips'),
  true, 'selected and uncertain is step-eligible'
);
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
   where tutorial_session_id = '60000000-0000-4000-8000-00000000ce01'
     and category = 'eyeliner'),
  false, 'not selected and absent is not'
);
select lives_ok(
  $$ insert into public.tutorial_v4_steps (
       user_id, tutorial_session_id, category, position
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '60000000-0000-4000-8000-00000000ce01', 'blush', 1
     ) $$,
  'a step exists for a selected category judged absent'
);
select throws_ok(
  $$ insert into public.tutorial_v4_steps (
       user_id, tutorial_session_id, category, position
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '60000000-0000-4000-8000-00000000ce01', 'eyeliner', 2
     ) $$,
  '23503', null, 'no step for a category neither selected nor present'
);

select throws_ok(
  $$ insert into public.tutorial_v4_manifest_items (
       user_id, tutorial_session_id, category, position, presence,
       palette_backed
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '60000000-0000-4000-8000-00000000ce02', 'blush', 4, 'absent', true
     ) $$,
  '23503', null, 'palette_backed cannot be set on a Standard session'
);
select throws_ok(
  $$ insert into public.tutorial_v4_manifest_items (
       user_id, tutorial_session_id, category, position, presence,
       product_backed
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '60000000-0000-4000-8000-00000000ce01', 'eyeshadow', 7, 'absent', true
     ) $$,
  '23503', null, 'product_backed cannot be set on a palette session'
);

-- Standard's rule did not move.
insert into public.tutorial_v4_manifest_items (
  user_id, tutorial_session_id, category, position, presence
) values
  ('10000000-0000-4000-8000-00000000ce01',
   '60000000-0000-4000-8000-00000000ce02', 'lips', 9, 'present'),
  ('10000000-0000-4000-8000-00000000ce01',
   '60000000-0000-4000-8000-00000000ce02', 'blush', 4, 'absent');
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
   where tutorial_session_id = '60000000-0000-4000-8000-00000000ce02'
     and category = 'lips'),
  true, 'Standard: present is step-eligible'
);
select is(
  (select step_eligible from public.tutorial_v4_manifest_items
   where tutorial_session_id = '60000000-0000-4000-8000-00000000ce02'
     and category = 'blush'),
  false, 'Standard: absent is still not'
);
select throws_ok(
  $$ insert into public.tutorial_v4_steps (
       user_id, tutorial_session_id, category, position
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '60000000-0000-4000-8000-00000000ce02', 'blush', 1
     ) $$,
  '23503', null, 'Standard: an absent category still cannot have a step'
);
select throws_ok(
  $$ update public.tutorial_v4_manifest_items set step_eligible = true
     where tutorial_session_id = '60000000-0000-4000-8000-00000000ce02' $$,
  '428C9', null, 'step_eligible is still generated'
);

-- ---------------------------------------------------------------------------
-- Tutorial authorization: the third mode is judged against its own table
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000ce01');
select is(
  public.authorize_tutorial_generation(
    'custom_color_palette', '51000000-0000-4000-8000-00000000ce01', null
  )->>'authorized',
  'true', 'a palette preview the caller owns is authorized'
);
select is(
  public.authorize_tutorial_generation(
    null, null, '60000000-0000-4000-8000-00000000ce01'
  )->>'authorized',
  'true', 'and so is its session'
);
select is(
  public.authorize_tutorial_generation(
    'custom_color_palette', '53000000-0000-4000-8000-00000000ce01', null
  )->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'a Standard preview is not a palette preview'
);
select is(
  public.authorize_tutorial_generation(
    'standard', '53000000-0000-4000-8000-00000000ce01', null
  )->>'authorized',
  'true', 'Standard still authorizes as before'
);
select is(
  public.authorize_tutorial_generation(
    'standard', '51000000-0000-4000-8000-00000000ce01', null
  )->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'a palette preview is not a Standard preview'
);
select is(
  public.authorize_tutorial_generation(
    'makeup_kit', '51000000-0000-4000-8000-00000000ce01', null
  )->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'and it is not a kit preview'
);
select pg_temp.as_user('10000000-0000-4000-8000-00000000ce02');
select is(
  public.authorize_tutorial_generation(
    'custom_color_palette', '51000000-0000-4000-8000-00000000ce01', null
  )->>'denialReason',
  'TUTORIAL_SOURCE_NOT_FOUND', 'another account''s preview is not found'
);
reset role;

-- ---------------------------------------------------------------------------
-- Saved Looks
-- ---------------------------------------------------------------------------
set local role authenticated;
select pg_temp.as_user('10000000-0000-4000-8000-00000000ce01');
select lives_ok(
  $$ insert into public.custom_palette_saved_looks (
       id, user_id, custom_palette_generated_image_id, is_favorite
     ) values (
       '70000000-0000-4000-8000-00000000ce01',
       '10000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01', true
     ) $$,
  'an owner can save a look'
);
select throws_ok(
  $$ insert into public.custom_palette_saved_looks (
       user_id, custom_palette_generated_image_id
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01'
     ) $$,
  '23505', null, 'one saved look per preview'
);
select pg_temp.as_user('10000000-0000-4000-8000-00000000ce02');
select is(
  (select count(*)::int from public.custom_palette_saved_looks),
  0, 'another account cannot see it'
);
select throws_ok(
  $$ insert into public.custom_palette_saved_looks (
       user_id, custom_palette_generated_image_id
     ) values (
       '10000000-0000-4000-8000-00000000ce01',
       '51000000-0000-4000-8000-00000000ce01'
     ) $$,
  '42501', null, 'or save on someone''s behalf'
);
reset role;

set local role anon;
select throws_ok(
  $$ select * from public.custom_palette_saved_looks $$,
  '42501', null, 'anon has no access'
);
reset role;

-- ---------------------------------------------------------------------------
-- Deleting the analysis removes everything in the session
-- ---------------------------------------------------------------------------
delete from public.analyses
  where id = '40000000-0000-4000-8000-00000000ce01';
select is(
  (select count(*)::int from public.tutorial_v4_sessions
   where user_id = '10000000-0000-4000-8000-00000000ce01'),
  0, 'sessions are gone'
);
select is(
  (select count(*)::int from public.custom_palette_saved_looks
   where user_id = '10000000-0000-4000-8000-00000000ce01'),
  0, 'saved looks are gone'
);

select * from finish();
rollback;
