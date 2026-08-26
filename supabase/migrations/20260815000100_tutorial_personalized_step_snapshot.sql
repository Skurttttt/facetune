-- MO-9: persist the canonical personalized tutorial step decision.
-- Additive and tutorial-only. Existing prompt/image/overlay columns remain the
-- source of truth for generated artifacts; this snapshot prevents reopening
-- from re-running placement rules.
alter table public.tutorial_steps
  add column if not exists personalized_spec_json jsonb;

alter table public.tutorial_steps
  drop constraint if exists tutorial_steps_personalized_spec_is_object;

alter table public.tutorial_steps
  add constraint tutorial_steps_personalized_spec_is_object
  check (
    personalized_spec_json is null
    or jsonb_typeof(personalized_spec_json) = 'object'
  );

comment on column public.tutorial_steps.personalized_spec_json is
  'Immutable tutorial-owned PersonalizedTutorialStepSpec snapshot. Includes WHAT/WHERE/HOW, product snapshot, geometry anchors, adjustments, and confidence so reopening never re-decides placement.';
