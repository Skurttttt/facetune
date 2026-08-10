-- FaceTune Phase 4: create user-owned records for every Supabase Auth user.
-- This covers email, OAuth, and anonymous registrations before client queries.

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  profile_name text;
begin
  profile_name := nullif(
    btrim(
      coalesce(
        new.raw_user_meta_data ->> 'display_name',
        new.raw_user_meta_data ->> 'full_name',
        ''
      )
    ),
    ''
  );

  insert into public.profiles (auth_user_id, display_name)
  values (new.id, profile_name)
  on conflict (auth_user_id) do nothing;

  insert into public.user_settings (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_auth_user();

-- Backfill Auth users created before this migration.
insert into public.profiles (auth_user_id, display_name)
select
  users.id,
  nullif(
    btrim(
      coalesce(
        users.raw_user_meta_data ->> 'display_name',
        users.raw_user_meta_data ->> 'full_name',
        ''
      )
    ),
    ''
  )
from auth.users as users
on conflict (auth_user_id) do nothing;

insert into public.user_settings (user_id)
select users.id
from auth.users as users
on conflict (user_id) do nothing;
