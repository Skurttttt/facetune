-- Phase 10: prevent duplicate variation numbers for one recommendation.
create unique index if not exists generated_images_recommendation_generation_idx
  on public.generated_images (recommendation_id, generation_number);
