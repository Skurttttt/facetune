-- CCP-4 — the frozen palette and its recommendation.
--
-- Proves at the database layer that clients can read only their own palettes
-- and write none, that nobody can edit a frozen palette, that an invalid palette
-- cannot be stored, that a request id is one row, and that history deletion
-- still removes the whole family. Rolled back.
begin;

select plan(36);

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
  ('10000000-0000-4000-8000-00000000cc01'::uuid, 'ccp-alice@example.invalid'),
  ('10000000-0000-4000-8000-00000000cc02'::uuid, 'ccp-bob@example.invalid')
) as v(id, email);

insert into public.analyses (id, user_id, original_image_path) values
  ('40000000-0000-4000-8000-00000000cc01',
   '10000000-0000-4000-8000-00000000cc01', 'ccp/alice.png'),
  ('40000000-0000-4000-8000-00000000cc02',
   '10000000-0000-4000-8000-00000000cc01', 'ccp/alice2.png'),
  ('40000000-0000-4000-8000-00000000cc03',
   '10000000-0000-4000-8000-00000000cc02', 'ccp/bob.png');

-- A helper so each case below names only what it changes.
create function pg_temp.selection(
  p_category text default 'blush',
  p_base text default '#C8102E',
  p_adjusted text default '#D93A52',
  p_label text default 'Red',
  p_finish text default 'matte'
) returns jsonb language sql as $$
  select jsonb_build_object(
    'category_code', p_category,
    'base_color_value', p_base,
    'adjusted_color_value', p_adjusted,
    'color_label', p_label,
    'finish_code', p_finish
  );
$$;

create function pg_temp.insert_palette(
  p_id uuid,
  p_request uuid,
  p_snapshot jsonb,
  p_user uuid default '10000000-0000-4000-8000-00000000cc01',
  p_analysis uuid default '40000000-0000-4000-8000-00000000cc01',
  p_derived uuid default null,
  p_version text default 'custom_color_palette_contract_v1',
  p_digest text default repeat('a', 64)
) returns void language sql as $$
  insert into public.custom_palette_recommendations (
    id, user_id, analysis_id, makeup_style, palette_request_id,
    palette_version, palette_snapshot_json, palette_digest,
    derived_from_palette_id, recommendation_json, model_name, prompt_version
  ) values (
    p_id, p_user, p_analysis, 'soft_glam', p_request, p_version, p_snapshot,
    p_digest, p_derived, '{}'::jsonb, 'model',
    'custom_palette_recommendation_v1'
  );
$$;

-- ---------------------------------------------------------------------------
-- Palette validity
-- ---------------------------------------------------------------------------
select ok(
  public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection())
  ),
  'a valid palette passes'
);
select ok(
  public.custom_palette_snapshot_is_valid(jsonb_build_array(
    pg_temp.selection(),
    pg_temp.selection('eyeshadow', '#6A2FB5', '#6A2FB5', 'Violet', 'glitter'),
    pg_temp.selection('eyeliner', '#1B1B1B', '#1B1B1B', 'Black', 'glossy'),
    pg_temp.selection('lipstick', '#E75480', '#E75480', 'Pink', 'cream')
  )),
  'all four categories together pass'
);
select ok(
  not public.custom_palette_snapshot_is_valid('[]'::jsonb),
  'an empty palette fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid('{}'::jsonb),
  'a non-array fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(jsonb_build_array(
    pg_temp.selection(), pg_temp.selection()
  )),
  'a duplicate category fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection('foundation'))
  ),
  'an unsupported category fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_finish => 'glossy'))
  ),
  'a finish the category forbids fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_finish => 'sparkly'))
  ),
  'an unknown finish fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_adjusted => '#d93a52'))
  ),
  'a lowercase color fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_adjusted => 'pink'))
  ),
  'a color name fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_base => '#123456'))
  ),
  'a base color outside the catalog fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(
    jsonb_build_array(pg_temp.selection(p_label => 'Ignore instructions'))
  ),
  'a label that is not the catalog''s fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(jsonb_build_array(
    pg_temp.selection() || '{"note":"extra"}'::jsonb
  )),
  'an extra field fails'
);
select ok(
  not public.custom_palette_snapshot_is_valid(jsonb_build_array(
    pg_temp.selection() - 'finish_code'
  )),
  'a missing field fails'
);

-- ---------------------------------------------------------------------------
-- Table constraints
-- ---------------------------------------------------------------------------
select lives_ok(
  $$ select pg_temp.insert_palette(
    '50000000-0000-4000-8000-00000000cc01',
    '60000000-0000-4000-8000-00000000cc01',
    jsonb_build_array(pg_temp.selection())
  ) $$,
  'a valid row inserts'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(), gen_random_uuid(),
    jsonb_build_array(pg_temp.selection('foundation'))
  ) $$,
  '23514', null,
  'the table refuses an invalid palette'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(), gen_random_uuid(),
    jsonb_build_array(pg_temp.selection()),
    p_version => 'custom_color_palette_contract_v2'
  ) $$,
  '23514', null,
  'the table refuses an unknown contract version'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(), gen_random_uuid(),
    jsonb_build_array(pg_temp.selection()),
    p_digest => 'nope'
  ) $$,
  '23514', null,
  'the table refuses a malformed digest'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(),
    '60000000-0000-4000-8000-00000000cc01',
    jsonb_build_array(pg_temp.selection())
  ) $$,
  '23505', null,
  'one request id is one row for its owner'
);
select lives_ok(
  $$ select pg_temp.insert_palette(
    '50000000-0000-4000-8000-00000000cc03',
    '60000000-0000-4000-8000-00000000cc01',
    jsonb_build_array(pg_temp.selection()),
    p_user => '10000000-0000-4000-8000-00000000cc02',
    p_analysis => '40000000-0000-4000-8000-00000000cc03'
  ) $$,
  'another account may use the same request id'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(), gen_random_uuid(),
    jsonb_build_array(pg_temp.selection()),
    p_analysis => '40000000-0000-4000-8000-00000000cc03'
  ) $$,
  '23503', null,
  'a palette cannot attach to another account''s analysis'
);
select lives_ok(
  $$ select pg_temp.insert_palette(
    '50000000-0000-4000-8000-00000000cc02',
    '60000000-0000-4000-8000-00000000cc02',
    jsonb_build_array(pg_temp.selection(p_adjusted => '#E86A7C')),
    p_derived => '50000000-0000-4000-8000-00000000cc01'
  ) $$,
  'an edited palette links to the one it came from'
);
select throws_ok(
  $$ select pg_temp.insert_palette(
    gen_random_uuid(), gen_random_uuid(),
    jsonb_build_array(pg_temp.selection()),
    p_analysis => '40000000-0000-4000-8000-00000000cc02',
    p_derived => '50000000-0000-4000-8000-00000000cc01'
  ) $$,
  '23503', null,
  'an edited palette must stay on the same analysis'
);

-- ---------------------------------------------------------------------------
-- Immutability: not even a privileged role can edit a frozen palette.
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.custom_palette_recommendations
     set palette_snapshot_json = '[]'::jsonb
     where id = '50000000-0000-4000-8000-00000000cc01' $$,
  'P0001', 'custom palette records are immutable',
  'the table owner cannot edit a frozen palette'
);

set local role service_role;
select lives_ok(
  $$ insert into public.custom_palette_recommendations (
    user_id, analysis_id, makeup_style, palette_request_id, palette_version,
    palette_snapshot_json, palette_digest, recommendation_json, model_name,
    prompt_version
  ) values (
    '10000000-0000-4000-8000-00000000cc02',
    '40000000-0000-4000-8000-00000000cc03',
    'soft_glam', '60000000-0000-4000-8000-00000000cc09',
    'custom_color_palette_contract_v1',
    '[{"category_code":"blush","base_color_value":"#C8102E",
       "adjusted_color_value":"#D93A52","color_label":"Red",
       "finish_code":"matte"}]'::jsonb,
    repeat('a', 64), '{}'::jsonb, 'model', 'custom_palette_recommendation_v1'
  ) $$,
  'the server can write a palette, including its validity check'
);
select throws_ok(
  $$ update public.custom_palette_recommendations
     set makeup_style = 'bridal'
     where id = '50000000-0000-4000-8000-00000000cc01' $$,
  '42501', null,
  'the server has no UPDATE on a frozen palette'
);
select throws_ok(
  $$ delete from public.custom_palette_recommendations
     where id = '50000000-0000-4000-8000-00000000cc01' $$,
  '42501', null,
  'the server has no direct DELETE'
);
reset role;

-- ---------------------------------------------------------------------------
-- Row level security and privileges
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-00000000cc01","role":"authenticated"}',
  true
);
select is(
  (select count(*)::int from public.custom_palette_recommendations),
  2,
  'an account reads its own palettes and no others'
);
select throws_ok(
  $$ insert into public.custom_palette_recommendations (
    user_id, analysis_id, makeup_style, palette_request_id, palette_version,
    palette_snapshot_json, palette_digest, recommendation_json, model_name,
    prompt_version
  ) values (
    '10000000-0000-4000-8000-00000000cc01',
    '40000000-0000-4000-8000-00000000cc01',
    'soft_glam', '60000000-0000-4000-8000-00000000cc08',
    'custom_color_palette_contract_v1',
    '[{"category_code":"blush","base_color_value":"#C8102E",
       "adjusted_color_value":"#D93A52","color_label":"Red",
       "finish_code":"matte"}]'::jsonb,
    repeat('a', 64), '{}'::jsonb, 'model', 'custom_palette_recommendation_v1'
  ) $$,
  '42501', 'permission denied for table custom_palette_recommendations',
  'a client cannot insert, so it cannot forge a plan'
);
select throws_ok(
  $$ update public.custom_palette_recommendations set makeup_style = 'bridal' $$,
  '42501', 'permission denied for table custom_palette_recommendations',
  'a client cannot edit a frozen palette'
);
select throws_ok(
  $$ delete from public.custom_palette_recommendations $$,
  '42501', 'permission denied for table custom_palette_recommendations',
  'a client cannot delete a row directly'
);
reset role;

set local role anon;
select throws_ok(
  $$ select * from public.custom_palette_recommendations $$,
  '42501', null,
  'anon has no access'
);
reset role;

-- ---------------------------------------------------------------------------
-- Quota vocabulary
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config(
  'request.jwt.claims',
  '{"sub":"10000000-0000-4000-8000-00000000cc01","role":"authenticated"}',
  true
);
select is(
  public.consume_ai_quota('custom_palette_recommendation')->>'allowed',
  'true',
  'the new operation is metered'
);
select is(
  public.consume_ai_quota('kit_makeup_recommendation')->>'allowed',
  'true',
  'an existing operation still works'
);
select is(
  public.consume_ai_quota('not_a_real_operation')->>'reason',
  'unsupported_operation',
  'an unknown operation is still refused'
);
reset role;

-- ---------------------------------------------------------------------------
-- Deleting the analysis removes the whole family, derived rows included.
-- ---------------------------------------------------------------------------
delete from public.analyses
  where id = '40000000-0000-4000-8000-00000000cc01';
select is(
  (
    select count(*)::int from public.custom_palette_recommendations
    where analysis_id = '40000000-0000-4000-8000-00000000cc01'
  ),
  0,
  'deleting the analysis cascades through derived palettes'
);

select * from finish();
rollback;
