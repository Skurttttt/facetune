-- FaceTune — My Makeup Kit (MK-2): private per-user makeup inventory.
--
-- Purely additive. Does not alter any existing table, function, trigger,
-- policy, or grant from prior migrations. The frozen Makeup Recommendation
-- schema (profiles / analyses / recommendations / generated_images /
-- saved_looks / user_settings) is untouched.
--
-- Category and finish values are the stable identifiers defined in
-- lib/features/makeup_kit/domain/entities/{makeup_kit_category,makeup_kit_finish}.dart
-- (MK-1). Only the overall category and finish vocabulary is enforced here
-- as a simple allow-list; which finishes are valid *per category* is
-- intentionally left to typed application validation
-- (MakeupKitFinishCatalog) rather than a brittle per-category SQL matrix,
-- per MK-2 guidance to avoid over-constraining the database with rules
-- better owned by the domain layer.

create table if not exists public.makeup_kit_products (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  product_name text,
  color_hex text not null,
  color_label text,
  finish text not null,
  foundation_depth text,
  foundation_undertone text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint makeup_kit_products_owner_identity unique (id, user_id),
  constraint makeup_kit_products_category_valid
    check (
      category in (
        'foundation',
        'concealer',
        'blush',
        'highlighter',
        'eyeshadow',
        'lipstick',
        'lip_gloss',
        'contour_bronzer',
        'eyebrow',
        'eyeliner'
      )
    ),
  constraint makeup_kit_products_finish_valid
    check (
      finish in (
        'matte',
        'natural',
        'dewy',
        'satin',
        'radiant',
        'shimmer',
        'metallic',
        'glitter',
        'cream',
        'glossy'
      )
    ),
  constraint makeup_kit_products_color_hex_valid
    check (color_hex ~ '^#[0-9A-F]{6}$'),
  constraint makeup_kit_products_product_name_not_blank
    check (product_name is null or char_length(btrim(product_name)) > 0),
  constraint makeup_kit_products_color_label_not_blank
    check (color_label is null or char_length(btrim(color_label)) > 0),
  constraint makeup_kit_products_foundation_depth_valid
    check (
      foundation_depth is null
      or foundation_depth in ('fair', 'light', 'medium', 'tan', 'deep')
    ),
  constraint makeup_kit_products_foundation_undertone_valid
    check (
      foundation_undertone is null
      or foundation_undertone in ('cool', 'neutral', 'warm')
    ),
  -- Foundation-only fields must never carry data for other categories, so a
  -- product cannot be edited (per MK-6) into e.g. Lipstick while silently
  -- retaining stale foundation metadata.
  constraint makeup_kit_products_foundation_fields_scoped
    check (
      category = 'foundation'
      or (foundation_depth is null and foundation_undertone is null)
    )
);

create index if not exists makeup_kit_products_user_created_idx
  on public.makeup_kit_products (user_id, created_at desc);
create index if not exists makeup_kit_products_user_category_idx
  on public.makeup_kit_products (user_id, category);

drop trigger if exists makeup_kit_products_set_updated_at
  on public.makeup_kit_products;
create trigger makeup_kit_products_set_updated_at
before update on public.makeup_kit_products
for each row execute function public.set_updated_at();

alter table public.makeup_kit_products enable row level security;

revoke all on table public.makeup_kit_products from anon;

grant select, insert, update, delete
  on table public.makeup_kit_products to authenticated;

drop policy if exists "makeup_kit_products_select_own"
  on public.makeup_kit_products;
create policy "makeup_kit_products_select_own"
on public.makeup_kit_products for select
to authenticated
using ((select auth.uid()) = user_id);

drop policy if exists "makeup_kit_products_insert_own"
  on public.makeup_kit_products;
create policy "makeup_kit_products_insert_own"
on public.makeup_kit_products for insert
to authenticated
with check ((select auth.uid()) = user_id);

drop policy if exists "makeup_kit_products_update_own"
  on public.makeup_kit_products;
create policy "makeup_kit_products_update_own"
on public.makeup_kit_products for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

drop policy if exists "makeup_kit_products_delete_own"
  on public.makeup_kit_products;
create policy "makeup_kit_products_delete_own"
on public.makeup_kit_products for delete
to authenticated
using ((select auth.uid()) = user_id);
