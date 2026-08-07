# FaceTune Supabase foundation

## Apply migrations

Install the Supabase CLI, authenticate it, and link this workspace:

```powershell
supabase login
supabase link --project-ref usmlwaocafeqnspdsvmv
supabase db push
```

The migrations create the application tables, foreign keys, indexes, update
triggers, RLS policies, and the private `face-images` bucket.

Do not use `--include-all` or reset a remote database without reviewing pending
migrations first.

## Storage convention

All objects live in the private `face-images` bucket. The first path segment is
always the authenticated Supabase user UUID so Storage RLS can enforce
ownership.

```text
{userId}/analyses/{analysisId}/original/{imageId}.jpg
{userId}/analyses/{analysisId}/generated/{generatedImageId}.jpg
```

- Generate every `imageId` and `generatedImageId` as a UUID.
- Upload originals with `upsert: false`.
- Never overwrite an original.
- Store only the object path in PostgreSQL, never a public URL.
- Read private images using authenticated downloads or short-lived signed URLs.
- Keep generated images distinct from originals.

The bucket permits JPEG, PNG, and WebP files up to 10 MiB. Later upload phases
must still validate actual content, extension, dimensions, and ownership before
uploading.

## Security boundary

- The Flutter client receives only the project URL and publishable key.
- No service-role key, database password, or Gemini secret belongs in Flutter.
- Anonymous database and Storage access has no policy.
- Authenticated users can access only rows and object paths they own.
- Cross-owner foreign-key links are rejected by composite ownership keys.

The migrations must be applied to the remote project before client data calls
are added in later phases.
