-- FaceTune My Makeup Kit MK-11: isolated saved-look persistence.
-- Standard saved_looks and its foreign keys remain unchanged.

create table if not exists public.kit_saved_looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kit_generated_image_id uuid not null,
  is_favorite boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint kit_saved_looks_generated_image_unique
    unique (kit_generated_image_id),
  constraint kit_saved_looks_generated_image_owner_fk
    foreign key (kit_generated_image_id, user_id)
    references public.kit_generated_images(id, user_id)
    on delete cascade
);

create index if not exists kit_saved_looks_user_created_idx
  on public.kit_saved_looks (user_id, created_at desc);
create index if not exists kit_saved_looks_user_favorite_created_idx
  on public.kit_saved_looks (user_id, is_favorite, created_at desc);

drop trigger if exists kit_saved_looks_set_updated_at
  on public.kit_saved_looks;
create trigger kit_saved_looks_set_updated_at
before update on public.kit_saved_looks
for each row execute function public.set_updated_at();

alter table public.kit_saved_looks enable row level security;
revoke all on table public.kit_saved_looks from anon;
grant select, insert, update, delete
  on table public.kit_saved_looks to authenticated;

create policy "kit_saved_looks_select_own"
on public.kit_saved_looks for select to authenticated
using ((select auth.uid()) = user_id);
create policy "kit_saved_looks_insert_own"
on public.kit_saved_looks for insert to authenticated
with check ((select auth.uid()) = user_id);
create policy "kit_saved_looks_update_own"
on public.kit_saved_looks for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);
create policy "kit_saved_looks_delete_own"
on public.kit_saved_looks for delete to authenticated
using ((select auth.uid()) = user_id);
