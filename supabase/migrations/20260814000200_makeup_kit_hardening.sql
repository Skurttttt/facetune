-- FaceTune My Makeup Kit MK-12: defense-in-depth data validation.
-- The app and Edge Functions already validate these combinations. Enforcing
-- the same rule in PostgreSQL prevents a direct authenticated REST request
-- from persisting a category/finish pair the product model cannot represent.

alter table public.makeup_kit_products
  drop constraint if exists makeup_kit_products_category_finish_valid;

alter table public.makeup_kit_products
  add constraint makeup_kit_products_category_finish_valid
  check (
    (category = 'foundation' and finish in ('matte', 'natural', 'dewy', 'satin'))
    or (category = 'concealer' and finish in ('matte', 'natural', 'radiant'))
    or (category = 'blush' and finish in ('matte', 'satin', 'shimmer'))
    or (category = 'highlighter' and finish in ('natural', 'shimmer', 'metallic'))
    or (category = 'eyeshadow' and finish in ('matte', 'satin', 'shimmer', 'metallic', 'glitter'))
    or (category = 'lipstick' and finish in ('matte', 'satin', 'cream', 'glossy'))
    or (category = 'lip_gloss' and finish in ('glossy', 'shimmer'))
    or (category = 'contour_bronzer' and finish in ('matte', 'satin'))
    or (category = 'eyebrow' and finish in ('matte', 'natural'))
    or (category = 'eyeliner' and finish in ('matte', 'satin', 'glossy'))
  );
