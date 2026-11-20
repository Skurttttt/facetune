-- CCP — Custom Color Palette category parity with My Makeup Kit (contract v2).
--
-- Custom Color Palette now offers the same ten categories as My Makeup Kit, in
-- Tutorial application order, each with My Makeup Kit's own finishes. Blush,
-- Eyeshadow, Eyeliner, Lipstick and Lip Gloss keep the 24 shared colors;
-- Foundation, Concealer, Contour/Bronzer, Highlighter and Eyebrow offer only
-- My Makeup Kit's curated shades for that category.
--
-- Additive and backward compatible:
--   * New palettes are written as `custom_color_palette_contract_v2`.
--   * Every existing row is `custom_color_palette_contract_v1` and stays valid:
--     the validity function only widens, and a v1 row is still required to use
--     the original four categories (and therefore the shared colors) alone.
--   * No table, column, policy, grant on a table, usage rule or Tutorial table
--     changes. The Tutorial vocabulary already covers every category.
--
-- Labels are resolved per category: a curated shade can share a hex value with a
-- shared color (Foundation "Deep Espresso" and the shared "Brown" are both
-- #5C3A21), so a hex value alone cannot name a color.
--
-- Mirrors `_shared/custom_palette_contract.ts` and
-- `lib/features/custom_palette/domain/catalog/custom_palette_catalog.dart`;
-- a Dart test compares all three.
--
-- The remote default ACL grants anon, authenticated and service_role full rights
-- on new functions, so every privilege below is explicit.

-- ---------------------------------------------------------------------------
-- 1. Palette validity: ten categories, per-category finishes and colors
-- ---------------------------------------------------------------------------
create or replace function public.custom_palette_snapshot_is_valid(
  p_snapshot jsonb
)
returns boolean
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_entry jsonb;
  v_category text;
  v_base text;
  v_finishes text[];
  v_seen text[] := '{}';
  v_label text;
begin
  if jsonb_typeof(p_snapshot) <> 'array' then
    return false;
  end if;
  if jsonb_array_length(p_snapshot) not between 1 and 10 then
    return false;
  end if;

  for v_entry in select value from jsonb_array_elements(p_snapshot) loop
    if jsonb_typeof(v_entry) <> 'object' then
      return false;
    end if;
    -- Exactly the contract's fields: no adjustment metadata, no free text.
    if (select array_agg(key order by key) from jsonb_object_keys(v_entry) as key)
      <> array[
        'adjusted_color_value',
        'base_color_value',
        'category_code',
        'color_label',
        'finish_code'
      ]
    then
      return false;
    end if;

    v_category := v_entry->>'category_code';
    if v_category = any(v_seen) then
      return false;
    end if;
    v_seen := v_seen || v_category;

    v_finishes := case v_category
      when 'foundation' then array['matte', 'natural', 'dewy', 'satin']
      when 'concealer' then array['matte', 'natural', 'radiant']
      when 'contour_bronzer' then array['matte', 'satin']
      when 'blush' then array['matte', 'satin', 'shimmer']
      when 'highlighter' then array['natural', 'shimmer', 'metallic']
      when 'eyebrow' then array['matte', 'natural']
      when 'eyeshadow' then
        array['matte', 'satin', 'shimmer', 'metallic', 'glitter']
      when 'eyeliner' then array['matte', 'satin', 'glossy']
      when 'lipstick' then array['matte', 'satin', 'cream', 'glossy']
      when 'lip_gloss' then array['glossy', 'shimmer']
    end;
    if v_finishes is null then
      return false;
    end if;
    if not (coalesce(v_entry->>'finish_code', '') = any(v_finishes)) then
      return false;
    end if;

    if coalesce(v_entry->>'adjusted_color_value', '') !~ '^#[0-9A-F]{6}$' then
      return false;
    end if;

    v_base := v_entry->>'base_color_value';
    if v_category = 'foundation' then
      v_label := case v_base
        when '#F1DFCB' then 'Fair Ivory'
        when '#EFCBA9' then 'Light Beige'
        when '#C99578' then 'Warm Beige'
        when '#C68642' then 'Medium Honey'
        when '#A9702F' then 'Tan Caramel'
        when '#5C3A21' then 'Deep Espresso'
      end;
    elsif v_category = 'concealer' then
      v_label := case v_base
        when '#F3E1CE' then 'Fair'
        when '#EAC9A6' then 'Light'
        when '#CE9B72' then 'Medium'
        when '#B27D4B' then 'Tan'
        when '#6E4527' then 'Deep'
      end;
    elsif v_category = 'contour_bronzer' then
      v_label := case v_base
        when '#A9713D' then 'Warm Tan'
        when '#8C6C5C' then 'Cool Taupe'
        when '#7A4B2A' then 'Deep Bronze'
      end;
    elsif v_category = 'highlighter' then
      v_label := case v_base
        when '#F3D9B1' then 'Champagne'
        when '#E8B4A0' then 'Rose Gold'
        when '#E4C078' then 'Gold'
        when '#F5E9DA' then 'Pearl'
      end;
    elsif v_category = 'eyebrow' then
      v_label := case v_base
        when '#8A6E5D' then 'Soft Taupe'
        when '#6B4A3A' then 'Ash Brown'
        when '#5C3E2E' then 'Warm Brunette'
        when '#4A4038' then 'Charcoal'
      end;
    else
      -- Blush, Eyeshadow, Eyeliner, Lipstick and Lip Gloss: the shared colors.
      v_label := case v_base
        when '#1B1B1B' then 'Black'
        when '#3A3A3C' then 'Charcoal'
        when '#5C3A21' then 'Brown'
        when '#9C8574' then 'Taupe'
        when '#D9A58B' then 'Nude'
        when '#F5F2EC' then 'White'
        when '#F2A07B' then 'Peach'
        when '#E8636B' then 'Coral'
        when '#E8711A' then 'Orange'
        when '#C8102E' then 'Red'
        when '#7A2E4A' then 'Berry'
        when '#E75480' then 'Pink'
        when '#C97B84' then 'Rose'
        when '#B5179E' then 'Magenta'
        when '#6B4358' then 'Plum'
        when '#6A2FB5' then 'Violet'
        when '#1F2F6B' then 'Navy'
        when '#1F6FD6' then 'Blue'
        when '#0F8B8D' then 'Teal'
        when '#2E7D4F' then 'Green'
        when '#6E7355' then 'Olive'
        when '#C9A227' then 'Gold'
        when '#8A5A34' then 'Bronze'
        when '#B8BCC2' then 'Silver'
      end;
    end if;
    if v_label is null or v_entry->>'color_label' is distinct from v_label then
      return false;
    end if;
  end loop;

  return true;
end;
$$;

revoke all on function public.custom_palette_snapshot_is_valid(jsonb)
  from public, anon, authenticated;
-- A CHECK constraint runs with the inserting role's privileges.
grant execute on function public.custom_palette_snapshot_is_valid(jsonb)
  to service_role;

-- ---------------------------------------------------------------------------
-- 2. A v1 palette may only hold the original four categories
-- ---------------------------------------------------------------------------
create or replace function public.custom_palette_snapshot_is_legacy(
  p_snapshot jsonb
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select jsonb_typeof(p_snapshot) = 'array'
    and not exists (
      select 1
      from jsonb_array_elements(p_snapshot) as e(value)
      where e.value->>'category_code' is null
        or e.value->>'category_code' not in (
          'blush', 'eyeshadow', 'eyeliner', 'lipstick'
        )
    );
$$;

revoke all on function public.custom_palette_snapshot_is_legacy(jsonb)
  from public, anon, authenticated;
grant execute on function public.custom_palette_snapshot_is_legacy(jsonb)
  to service_role;

-- ---------------------------------------------------------------------------
-- 3. Contract versions: v1 rows stay as written, new rows are v2
-- ---------------------------------------------------------------------------
alter table public.custom_palette_recommendations
  drop constraint custom_palette_recommendations_version_valid;
alter table public.custom_palette_recommendations
  add constraint custom_palette_recommendations_version_valid
    check (
      palette_version in (
        'custom_color_palette_contract_v1',
        'custom_color_palette_contract_v2'
      )
    );
alter table public.custom_palette_recommendations
  add constraint custom_palette_recommendations_v1_is_legacy
    check (
      palette_version <> 'custom_color_palette_contract_v1'
      or public.custom_palette_snapshot_is_legacy(palette_snapshot_json)
    );
