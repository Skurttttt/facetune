# Gemini makeup recommendation setup

Phase 9 uses the authenticated Supabase Edge Function `generate-makeup-recommendation`. Gemini credentials remain server-side.

## Deployment

Ensure the existing `GEMINI_API_KEY` Supabase secret is configured, then deploy:

```powershell
npx -y supabase functions deploy generate-makeup-recommendation
```

The function uses `GEMINI_MODEL` when configured and otherwise uses the same default model as face analysis. It reads the authenticated user's persisted analysis, validates the selected style, validates Gemini's structured response, and inserts the result into the RLS-protected `recommendations` table.

No database migration is introduced by Phase 9 because the Phase 3 schema already includes the required table, indexes, foreign keys, and owner policies.
