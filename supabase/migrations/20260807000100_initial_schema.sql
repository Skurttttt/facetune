-- FaceTune Phase 3: user-owned application schema.
-- All public tables are RLS protected and deny anonymous access by default.

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid not null unique references auth.users(id) on delete cascade,
  display_name text,
  avatar_path text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint profiles_display_name_length
    check (display_name is null or char_length(display_name) between 1 and 80)
);

create table public.analyses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  original_image_path text not null,
  face_shape text,
  skin_tone text,
  undertone text,
  eye_shape text,
  lip_shape text,
  hair_color text,
  eye_color text,
  confidence_json jsonb not null default '{}'::jsonb,
  raw_ai_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint analyses_owner_identity unique (id, user_id),
  constraint analyses_original_path_not_blank
    check (char_length(btrim(original_image_path)) > 0),
  constraint analyses_confidence_is_object
    check (jsonb_typeof(confidence_json) = 'object'),
  constraint analyses_metadata_is_object
    check (jsonb_typeof(raw_ai_metadata) = 'object')
);

create table public.recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  makeup_style text not null,
  recommendation_json jsonb not null default '{}'::jsonb,
  model_name text,
  prompt_version text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint recommendations_owner_identity unique (id, user_id),
  constraint recommendations_analysis_owner_identity
    unique (id, analysis_id, user_id),
  constraint recommendations_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint recommendations_style_not_blank
    check (char_length(btrim(makeup_style)) > 0),
  constraint recommendations_payload_is_object
    check (jsonb_typeof(recommendation_json) = 'object')
);

create table public.generated_images (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  analysis_id uuid not null,
  recommendation_id uuid not null,
  storage_path text not null unique,
  generation_number integer not null default 1,
  model_name text,
  prompt_version text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint generated_images_owner_identity unique (id, user_id),
  constraint generated_images_analysis_owner_fk
    foreign key (analysis_id, user_id)
    references public.analyses(id, user_id)
    on delete cascade,
  constraint generated_images_recommendation_owner_fk
    foreign key (recommendation_id, analysis_id, user_id)
    references public.recommendations(id, analysis_id, user_id)
    on delete cascade,
  constraint generated_images_storage_path_not_blank
    check (char_length(btrim(storage_path)) > 0),
  constraint generated_images_generation_positive
    check (generation_number > 0)
);

create table public.saved_looks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  generated_image_id uuid not null,
  is_favorite boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint saved_looks_generated_image_unique unique (generated_image_id),
  constraint saved_looks_generated_image_owner_fk
    foreign key (generated_image_id, user_id)
    references public.generated_images(id, user_id)
    on delete cascade
);

create table public.user_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  dark_mode boolean not null default false,
  notifications_enabled boolean not null default true,
  analytics_consent boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index analyses_user_created_idx
  on public.analyses (user_id, created_at desc);
create index recommendations_user_created_idx
  on public.recommendations (user_id, created_at desc);
create index recommendations_analysis_idx
  on public.recommendations (analysis_id);
create index generated_images_user_created_idx
  on public.generated_images (user_id, created_at desc);
create index generated_images_analysis_idx
  on public.generated_images (analysis_id);
create index generated_images_recommendation_idx
  on public.generated_images (recommendation_id);
create index saved_looks_user_created_idx
  on public.saved_looks (user_id, created_at desc);
create index saved_looks_user_favorite_created_idx
  on public.saved_looks (user_id, is_favorite, created_at desc);

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

create trigger analyses_set_updated_at
before update on public.analyses
for each row execute function public.set_updated_at();

create trigger recommendations_set_updated_at
before update on public.recommendations
for each row execute function public.set_updated_at();

create trigger generated_images_set_updated_at
before update on public.generated_images
for each row execute function public.set_updated_at();

create trigger saved_looks_set_updated_at
before update on public.saved_looks
for each row execute function public.set_updated_at();

create trigger user_settings_set_updated_at
before update on public.user_settings
for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;
alter table public.analyses enable row level security;
alter table public.recommendations enable row level security;
alter table public.generated_images enable row level security;
alter table public.saved_looks enable row level security;
alter table public.user_settings enable row level security;

revoke all on table public.profiles from anon;
revoke all on table public.analyses from anon;
revoke all on table public.recommendations from anon;
revoke all on table public.generated_images from anon;
revoke all on table public.saved_looks from anon;
revoke all on table public.user_settings from anon;

grant select, insert, update, delete on table public.profiles to authenticated;
grant select, insert, update, delete on table public.analyses to authenticated;
grant select, insert, update, delete on table public.recommendations to authenticated;
grant select, insert, update, delete on table public.generated_images to authenticated;
grant select, insert, update, delete on table public.saved_looks to authenticated;
grant select, insert, update, delete on table public.user_settings to authenticated;

create policy "profiles_select_own"
on public.profiles for select
to authenticated
using ((select auth.uid()) = auth_user_id);

create policy "profiles_insert_own"
on public.profiles for insert
to authenticated
with check ((select auth.uid()) = auth_user_id);

create policy "profiles_update_own"
on public.profiles for update
to authenticated
using ((select auth.uid()) = auth_user_id)
with check ((select auth.uid()) = auth_user_id);

create policy "profiles_delete_own"
on public.profiles for delete
to authenticated
using ((select auth.uid()) = auth_user_id);

create policy "analyses_select_own"
on public.analyses for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "analyses_insert_own"
on public.analyses for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "analyses_update_own"
on public.analyses for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "analyses_delete_own"
on public.analyses for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "recommendations_select_own"
on public.recommendations for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "recommendations_insert_own"
on public.recommendations for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "recommendations_update_own"
on public.recommendations for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "recommendations_delete_own"
on public.recommendations for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "generated_images_select_own"
on public.generated_images for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "generated_images_insert_own"
on public.generated_images for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "generated_images_update_own"
on public.generated_images for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "generated_images_delete_own"
on public.generated_images for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "saved_looks_select_own"
on public.saved_looks for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "saved_looks_insert_own"
on public.saved_looks for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "saved_looks_update_own"
on public.saved_looks for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "saved_looks_delete_own"
on public.saved_looks for delete
to authenticated
using ((select auth.uid()) = user_id);

create policy "user_settings_select_own"
on public.user_settings for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "user_settings_insert_own"
on public.user_settings for insert
to authenticated
with check ((select auth.uid()) = user_id);

create policy "user_settings_update_own"
on public.user_settings for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "user_settings_delete_own"
on public.user_settings for delete
to authenticated
using ((select auth.uid()) = user_id);
