-- OMKT — My Makeup Kit snapshot-authoritative Tutorial step eligibility.
--
-- For source_mode = 'my_makeup_kit' the exact stored product snapshot decides
-- which Tutorial steps exist, whatever the visual manifest verdict: a category
-- backed by the snapshot is step-eligible when it is present, absent, or
-- uncertain. Standard Mode is unchanged: only a visually present category can
-- carry a step.
--
-- The previous rules could not express that:
--   * tutorial_v4_manifest_items_absent_not_backed rejected a backed item that
--     was not visually present, so the analyzer's own kit manifest failed to
--     persist whenever a selected category was judged absent or uncertain;
--   * tutorial_v4_steps pinned manifest_presence to 'present' and used it in
--     the foreign key to the manifest item, so a step could exist only for a
--     present category.
--
-- Both are replaced by source-mode-aware rules that stay entirely declarative:
--   1. Product backing is a My Makeup Kit concept. A backed item must belong to
--      a my_makeup_kit session, enforced by a foreign key to the session's
--      generated mode flag. Standard items therefore can never be backed.
--   2. An item is step-eligible when it is visually present or product-backed.
--      Under rule 1 that is exactly "present" in Standard Mode, which is the
--      old invariant, and "present or selected" in My Makeup Kit.
--   3. A step must reference a step-eligible item.
--
-- The database permits a My Makeup Kit step for a present-but-unselected
-- category, as it did before. The server resolver is the authority that
-- refuses to generate one; the application never plans it.
--
-- Nothing here changes RLS, grants, or policies. The new columns are generated
-- (never written by a client) or defaulted, so existing writers keep working.

-- ---------------------------------------------------------------------------
-- 0. Preflight
-- ---------------------------------------------------------------------------
-- Standard Mode never writes product_backed = true. If a row says otherwise,
-- stop here with a clear message rather than failing on a foreign key below.
do $$
begin
  if exists (
    select 1
      from public.tutorial_v4_manifest_items as item
      join public.tutorial_v4_sessions as session
        on session.id = item.tutorial_session_id
     where item.product_backed
       and session.source_mode <> 'my_makeup_kit'
  ) then
    raise exception
      'OMKT preflight: a Standard Mode manifest item is marked product_backed';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. Sessions: an addressable source-mode flag
-- ---------------------------------------------------------------------------
alter table public.tutorial_v4_sessions
  add column is_my_makeup_kit boolean
    generated always as (source_mode = 'my_makeup_kit') stored;

alter table public.tutorial_v4_sessions
  add constraint tutorial_v4_sessions_kit_identity
    unique (id, is_my_makeup_kit);

-- ---------------------------------------------------------------------------
-- 2. Manifest items: backing is kit-only; eligibility follows backing
-- ---------------------------------------------------------------------------
-- NULL unless the item is backed. A NULL guard is not checked by the foreign
-- key (MATCH SIMPLE), so only backed items are required to belong to a
-- my_makeup_kit session.
alter table public.tutorial_v4_manifest_items
  add column product_backing_guard boolean
    generated always as (case when product_backed then true end) stored;

alter table public.tutorial_v4_manifest_items
  add constraint tutorial_v4_manifest_items_backing_is_kit_only
    foreign key (tutorial_session_id, product_backing_guard)
    references public.tutorial_v4_sessions (id, is_my_makeup_kit)
    on delete cascade;

alter table public.tutorial_v4_manifest_items
  drop constraint tutorial_v4_manifest_items_absent_not_backed;

alter table public.tutorial_v4_manifest_items
  add column step_eligible boolean
    generated always as (presence = 'present' or product_backed) stored;

-- FK target for tutorial_v4_steps below.
alter table public.tutorial_v4_manifest_items
  add constraint tutorial_v4_manifest_items_step_eligibility_identity
    unique (tutorial_session_id, category, step_eligible);

-- ---------------------------------------------------------------------------
-- 3. Steps: reference a step-eligible item instead of a present one
-- ---------------------------------------------------------------------------
alter table public.tutorial_v4_steps
  add column manifest_step_eligible boolean not null default true;

alter table public.tutorial_v4_steps
  add constraint tutorial_v4_steps_manifest_step_eligible_pinned
    check (manifest_step_eligible);

alter table public.tutorial_v4_steps
  add constraint tutorial_v4_steps_eligible_category_fk
    foreign key (tutorial_session_id, category, manifest_step_eligible)
    references public.tutorial_v4_manifest_items
      (tutorial_session_id, category, step_eligible)
    on delete cascade;

alter table public.tutorial_v4_steps
  drop constraint tutorial_v4_steps_included_category_fk;

alter table public.tutorial_v4_steps
  drop constraint tutorial_v4_steps_manifest_presence_pinned;

-- Existed only to carry the old foreign key. Kept, it would read 'present' for
-- a My Makeup Kit step whose category was judged absent or uncertain.
alter table public.tutorial_v4_steps
  drop column manifest_presence;

comment on column public.tutorial_v4_sessions.is_my_makeup_kit is
  'Generated. Foreign-key target that keeps product backing My Makeup Kit only.';
comment on column public.tutorial_v4_manifest_items.product_backing_guard is
  'Generated. True when product_backed, otherwise NULL; its foreign key requires a my_makeup_kit session.';
comment on column public.tutorial_v4_manifest_items.step_eligible is
  'Generated. Visually present or snapshot-backed; the only items a step may reference.';
comment on column public.tutorial_v4_steps.manifest_step_eligible is
  'Pinned true. Carries the foreign key to a step-eligible manifest item.';
