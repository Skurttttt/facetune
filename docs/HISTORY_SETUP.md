# History infrastructure

Phase 13 reads user-owned analyses, recommendations, generated images, and
saved looks through existing Row Level Security policies. Images remain in the
private `face-images` bucket and are displayed with short-lived signed URLs.

## Deploy safe deletion

Database cascades cannot remove Storage objects. Deploy the authenticated
history deletion function so a session's private object prefix is cleaned
before its analysis row is deleted:

```powershell
npx -y supabase functions deploy delete-history-item
```

The function validates the caller, the analysis UUID, all recorded paths, and
the exact convention below before deleting anything:

```text
{userId}/analyses/{analysisId}/original/{imageId}.{ext}
{userId}/analyses/{analysisId}/generated/{recommendationId}/preview_####.{ext}
```

It recursively removes only that analysis prefix, verifies cleanup, and then
deletes the analysis. Existing foreign keys cascade to recommendations,
generated-image rows, and saved/favorite records. Missing files and an already
deleted analysis are handled safely on retry.

No Gemini secret, service-role key, or database password belongs in Flutter or
is required by this function.

## Current status model

The current schema persists successful stages only. History therefore reports
`Analysis`, `Plan ready`, or `Complete`. Failed AI attempts cannot be shown as
historical sessions until a later phase introduces a durable session/event
status model; the client does not invent failure records.
