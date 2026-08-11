# Gemini makeup preview setup

Phase 10 uses the authenticated `generate-makeup-preview` Supabase Edge Function. The original selfie and generated variations stay in the private `face-images` bucket.

## Required server configuration

- Keep `GEMINI_API_KEY` configured as a Supabase secret.
- Optionally configure `GEMINI_IMAGE_MODEL`. The default is `gemini-3.1-flash-image`.
- Never add either value to Flutter source or `config/development.json`.

## Apply and deploy

```powershell
npx -y supabase db push
npx -y supabase functions deploy generate-makeup-preview
```

The migration adds a uniqueness guarantee for variation numbers. Generated images follow this private path convention:

```text
{userId}/analyses/{analysisId}/generated/{recommendationId}/preview_0001.png
```

The authenticated user UUID is the first segment because bucket RLS uses it for ownership checks.

## Privacy behavior

The function reads the authenticated user's persisted recommendation and analysis, downloads the original from private storage, sends it to Gemini server-side, validates returned image bytes, stores a new generated object, and creates a linked `generated_images` record. It never overwrites the original object.
