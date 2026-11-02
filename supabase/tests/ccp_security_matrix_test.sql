-- CCP-8 — the privilege matrix for every Custom Color Palette object.
--
-- Complements the behavioural RLS tests with the catalog itself: row level
-- security is on, only saved looks are client-writable, server-only functions
-- cannot be called by a client, and no policy opens a CCP table to anon or to
-- everyone. The cross-account behaviour runs against the real stack in
-- `controlled/ccp6_local_e2e_test.ts`. Rolled back.
begin;

select plan(16);

select is(
  (select count(*)::int from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and c.relname like 'custom\_palette\_%' and c.relrowsecurity),
  (select count(*)::int from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and c.relname like 'custom\_palette\_%'),
  'row level security is on for every CCP table'
);
select is(
  (select count(*)::int from pg_class c
   join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'
     and c.relname like 'custom\_palette\_%'),
  4, 'the CCP tables are the four this matrix covers'
);

select is(
  (select count(*)::int from unnest(array[
     'custom_palette_recommendations',
     'custom_palette_generated_images',
     'custom_palette_preview_attempts',
     'custom_palette_saved_looks'
   ]) as t(name), unnest(array[
     'SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
   ]) as p(privilege)
   where has_table_privilege('anon', 'public.' || t.name, p.privilege)),
  0, 'anon holds no privilege on any CCP table'
);
select is(
  (select count(*)::int from unnest(array[
     'custom_palette_recommendations',
     'custom_palette_generated_images',
     'custom_palette_preview_attempts'
   ]) as t(name), unnest(array[
     'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE'
   ]) as p(privilege)
   where has_table_privilege('authenticated', 'public.' || t.name, p.privilege)),
  0, 'a client cannot write a palette, a preview, or an attempt'
);
select ok(
  not has_table_privilege('authenticated',
    'public.custom_palette_preview_attempts', 'SELECT'),
  'a client cannot read attempts, which hold private evidence'
);
select ok(
  has_table_privilege('authenticated',
    'public.custom_palette_recommendations', 'SELECT')
  and has_table_privilege('authenticated',
    'public.custom_palette_generated_images', 'SELECT'),
  'a client reads palettes and previews, scoped by policy'
);
select ok(
  has_table_privilege('authenticated',
    'public.custom_palette_saved_looks', 'INSERT')
  and has_table_privilege('authenticated',
    'public.custom_palette_saved_looks', 'DELETE'),
  'saved looks are the one client-writable CCP table'
);
select ok(
  not has_table_privilege('service_role',
    'public.custom_palette_recommendations', 'UPDATE')
  and not has_table_privilege('service_role',
    'public.custom_palette_recommendations', 'DELETE'),
  'even the server cannot edit or delete a frozen palette'
);

select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename like 'custom\_palette\_%'
     and (roles && array['anon', 'public']::name[])),
  0, 'no CCP policy reaches anon or everyone'
);
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public' and tablename like 'custom\_palette\_%'
     and coalesce(qual, '') !~ 'auth\.uid\(\)'
     and coalesce(with_check, '') !~ 'auth\.uid\(\)'),
  0, 'every CCP policy is bound to the caller'
);
select is(
  (select count(*)::int from pg_policies
   where schemaname = 'public'
     and tablename = 'custom_palette_preview_attempts'),
  0, 'attempts have no policy at all'
);

select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in (
       'claim_custom_palette_preview_attempt',
       'finish_custom_palette_preview_attempt',
       'finalize_custom_palette_preview'
     )),
  3, 'the three server-only preview functions exist'
);
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   cross join unnest(array['anon', 'authenticated', 'public']) as r(name)
   where n.nspname = 'public'
     and p.proname in (
       'claim_custom_palette_preview_attempt',
       'finish_custom_palette_preview_attempt',
       'finalize_custom_palette_preview'
     )
     and case r.name
       when 'public' then exists (
         select 1 from aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) a
         where a.grantee = 0 and a.privilege_type = 'EXECUTE')
       else has_function_privilege(r.name, p.oid, 'EXECUTE')
     end),
  0, 'no client can claim, finish, or finalize a preview'
);
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in (
       'claim_custom_palette_preview_attempt',
       'finish_custom_palette_preview_attempt',
       'finalize_custom_palette_preview'
     )
     and has_function_privilege('service_role', p.oid, 'EXECUTE')),
  3, 'the server can'
);
select is(
  (select count(*)::int from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in (
       'claim_custom_palette_preview_attempt',
       'finish_custom_palette_preview_attempt',
       'finalize_custom_palette_preview',
       'authorize_tutorial_generation',
       'record_ai_operation_metric'
     )
     and p.prosecdef
     and not exists (
       select 1 from unnest(coalesce(p.proconfig, array[]::text[])) c
       where c like 'search\_path=%'
     )),
  0, 'every definer function pins its search path'
);

select is(
  (select public from storage.buckets where id = 'face-images'),
  false, 'the image bucket stays private'
);

select * from finish();
rollback;
