-- Phase 14: persisted theme preference and private profile avatars.

alter table public.user_settings
  add column if not exists theme_mode text not null default 'system';

update public.user_settings
set theme_mode = 'dark'
where dark_mode = true
  and theme_mode = 'system';

alter table public.user_settings
  drop constraint if exists user_settings_theme_mode_valid;

alter table public.user_settings
  add constraint user_settings_theme_mode_valid
  check (theme_mode in ('system', 'light', 'dark'));

alter table public.profiles
  drop constraint if exists profiles_avatar_owner_path;

alter table public.profiles
  add constraint profiles_avatar_owner_path
  check (
    avatar_path is null
    or avatar_path like auth_user_id::text || '/%'
  );

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'profile-avatars',
  'profile-avatars',
  false,
  2097152,
  array['image/jpeg']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "profile_avatars_select_own" on storage.objects;
create policy "profile_avatars_select_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "profile_avatars_insert_own" on storage.objects;
create policy "profile_avatars_insert_own"
on storage.objects for insert
to authenticated
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "profile_avatars_update_own" on storage.objects;
create policy "profile_avatars_update_own"
on storage.objects for update
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

drop policy if exists "profile_avatars_delete_own" on storage.objects;
create policy "profile_avatars_delete_own"
on storage.objects for delete
to authenticated
using (
  bucket_id = 'profile-avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);
