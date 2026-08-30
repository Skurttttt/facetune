-- FaceTune Step-by-Step Tutorial V3 — V3-10: server-resolved tutorial entry.
--
-- Until now a V3 session was created from a request the CLIENT assembled: the
-- analysis id, the recommendation id, the selected style and — the dangerous
-- one — the canonical preview's storage path. Every one of those is a server
-- fact that happens to be visible to the client, and a client that can choose
-- them can point a tutorial at a path of its choosing.
--
-- This function is the only supported way to start or reopen a V3 tutorial.
-- The caller supplies ONE identifier: the premium preview the tutorial targets.
-- Everything else is derived here, from rows RLS has already scoped to the
-- caller:
--
--   generated_images / kit_generated_images  →  analysis, recommendation, path
--   recommendations  / kit_makeup_recommendations  →  selected style
--
-- SECURITY INVOKER: a preview belonging to another account is invisible, so it
-- is indistinguishable from one that does not exist, and the insert is subject
-- to the same owner policy as any other write.

-- ---------------------------------------------------------------------------
-- Entry resolution
-- ---------------------------------------------------------------------------

create or replace function public.open_tutorial_v3_session(
  p_generated_image_id uuid,
  p_kit boolean
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := (select auth.uid());
  v_analysis uuid;
  v_recommendation uuid;
  v_path text;
  v_style text;
  v_folder text;
  v_session_id uuid;
begin
  if v_user is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  -- The preview row is the entry point, and the only thing the caller named.
  if p_kit then
    select images.analysis_id, images.kit_recommendation_id, images.storage_path
      into v_analysis, v_recommendation, v_path
    from public.kit_generated_images as images
    where images.id = p_generated_image_id;
  else
    select images.analysis_id, images.recommendation_id, images.storage_path
      into v_analysis, v_recommendation, v_path
    from public.generated_images as images
    where images.id = p_generated_image_id;
  end if;

  if v_analysis is null then
    raise exception 'final preview not found' using errcode = 'P0002';
  end if;

  -- The selected look is the recommendation's persisted style, never a code
  -- the client chose. Its absence means the chain behind this preview is gone.
  if p_kit then
    select recommendations.makeup_style into v_style
    from public.kit_makeup_recommendations as recommendations
    where recommendations.id = v_recommendation;
  else
    select recommendations.makeup_style into v_style
    from public.recommendations as recommendations
    where recommendations.id = v_recommendation;
  end if;

  if v_style is null then
    raise exception 'makeup plan not found' using errcode = 'P0002';
  end if;

  -- Defence in depth. The path was written by the preview generator, so this
  -- should always hold; if it ever does not, the row is not a usable target.
  v_folder := case when p_kit then '/kit-generated/' else '/generated/' end;
  if v_path not like ('%' || v_folder || '%')
     or v_path like '%/original/%'
     or v_path like '%..%'
     or v_path not like (v_user::text || '/analyses/' || v_analysis::text || '/%')
  then
    raise exception 'unsafe preview path' using errcode = '22023';
  end if;

  -- Reuse before create. The canonical preview is the tutorial's natural key,
  -- so one preview has exactly one tutorial.
  --
  -- Deliberately NOT filtered by plan version: a session this build cannot
  -- read must still be found and reported as incompatible, rather than
  -- silently duplicated by a second tutorial for the same target.
  select sessions.id into v_session_id
  from public.tutorial_v3_sessions as sessions
  where case
          when p_kit then sessions.canonical_kit_generated_image_id
          else sessions.canonical_generated_image_id
        end = p_generated_image_id
  order by sessions.plan_version desc
  limit 1;

  if v_session_id is not null then
    return v_session_id;
  end if;

  insert into public.tutorial_v3_sessions (
    user_id,
    analysis_id,
    source_mode,
    recommendation_id,
    kit_recommendation_id,
    makeup_style,
    canonical_generated_image_id,
    canonical_kit_generated_image_id,
    canonical_image_path,
    total_steps,
    plan_version,
    status
  ) values (
    v_user,
    v_analysis,
    case when p_kit then 'makeup_kit' else 'standard' end,
    case when p_kit then null else v_recommendation end,
    case when p_kit then v_recommendation else null end,
    v_style,
    case when p_kit then null else p_generated_image_id end,
    case when p_kit then p_generated_image_id else null end,
    v_path,
    0,
    3,
    'planning'
  )
  returning id into v_session_id;

  return v_session_id;
end;
$$;

revoke all on function public.open_tutorial_v3_session(uuid, boolean) from anon;
grant execute on function public.open_tutorial_v3_session(uuid, boolean)
  to authenticated;
