# Gemini face analysis setup

Phase 7 uses the authenticated `analyze-face` Supabase Edge Function. Flutter
never receives the Gemini credential and never calls Gemini directly.

## Server configuration

The function requires these server-side environment variables:

- `SUPABASE_URL` and `SUPABASE_ANON_KEY`, supplied automatically by Supabase
  Edge Functions.
- `GEMINI_API_KEY`, already configured as an Edge Function secret for this
  project.
- Optional `GEMINI_MODEL`. When absent, the function uses the stable
  `gemini-3.6-flash` model.

Never add `GEMINI_API_KEY` to Flutter configuration, source files, manifests,
assets, logs, or CI output.

## Apply and deploy

Install the Supabase CLI, authenticate, and link the project before running:

```powershell
npx supabase login
npx supabase link --project-ref usmlwaocafeqnspdsvmv
npx supabase db push
npx supabase functions deploy analyze-face
```

The database push adds model and prompt provenance columns to `analyses`. The
function configuration keeps JWT verification enabled. The function also calls
`auth.getUser()` and derives ownership from the verified session rather than a
client-supplied user ID.

## Validation

Run deterministic server tests without a live Gemini request:

```powershell
npx -y deno test supabase/functions/analyze-face/validation_test.ts
npx -y deno check --config supabase/functions/deno.json supabase/functions/analyze-face/index.ts
```

For an end-to-end check, sign in on a physical device, choose a clear selfie,
run local validation, and tap **Analyze selfie**. Confirm that:

1. A private object is created under
   `{userId}/analyses/{analysisId}/original/{imageId}.jpg`.
2. The function returns typed attributes or a friendly suitability failure.
3. A successful request creates exactly one RLS-protected `analyses` row with
   `gemini-3.6-flash` (or the configured override) and the current
   `FACE_ANALYSIS_PROMPT_VERSION` (`face_analysis_v2`). Rows written by an
   earlier prompt keep their original version; see `docs/AI_QUALITY_NOTES.md`.

Do not use a service-role key in Flutter or disable RLS for testing.
