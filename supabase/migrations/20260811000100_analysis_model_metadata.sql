-- FaceTune Phase 7: explicit model and prompt provenance for face analyses.

alter table public.analyses
  add column if not exists model_name text,
  add column if not exists prompt_version text;

alter table public.analyses
  add constraint analyses_model_name_not_blank
    check (model_name is null or char_length(btrim(model_name)) > 0),
  add constraint analyses_prompt_version_not_blank
    check (prompt_version is null or char_length(btrim(prompt_version)) > 0);
