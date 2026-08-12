# FaceTune Supabase foundation

## Apply migrations

Install the Supabase CLI, authenticate it, and link this workspace:

```powershell
supabase login
supabase link --project-ref usmlwaocafeqnspdsvmv
supabase db push
```

The migrations create the application tables, foreign keys, indexes, update
triggers, RLS policies, and the private `face-images` and `profile-avatars`
buckets. `20260811000300_profile_settings.sql` adds the persisted theme choice,
validates owner-prefixed avatar paths, and installs owner-only avatar Storage
policies.

Do not use `--include-all` or reset a remote database without reviewing pending
migrations first.

## Storage convention

Selfies and generated previews live in the private `face-images` bucket. The
first path segment is always the authenticated Supabase user UUID so Storage
RLS can enforce ownership.

```text
{userId}/analyses/{analysisId}/original/{imageId}.jpg
{userId}/analyses/{analysisId}/generated/{recommendationId}/preview_####.{ext}
```

- Generate every `imageId` and `generatedImageId` as a UUID.
- Upload originals with `upsert: false`.
- Never overwrite an original.
- Store only the object path in PostgreSQL, never a public URL.
- Read private images using authenticated downloads or short-lived signed URLs.
- Keep generated images distinct from originals.

Profile photos use a separate private bucket and a stable owner-scoped path:

```text
bucket: profile-avatars
path:   {userId}/avatar.jpg
```

The avatar bucket accepts JPEG only with a 2 MiB limit. Store the object path
in `profiles.avatar_path`, use a short-lived signed URL for display, and never
make the bucket public. Replacing an avatar updates the stable object rather
than creating unreferenced versions.

## Profile and preference truth

The Phase 4 auth bootstrap creates one `profiles` row and one `user_settings`
row for every email, OAuth, or anonymous Auth user.

`user_settings.theme_mode` is the authoritative theme preference and accepts
`system`, `light`, or `dark`. The legacy `dark_mode` value is retained for
compatibility and is updated alongside the new value; new readers should use
`theme_mode` first. Notification and analytics fields are stored preferences
only: this phase does not configure notifications or an analytics SDK.

The app version displayed in Settings comes from the installed package through
`PackageInfo.fromPlatform()`. `pubspec.yaml` supplies the default version and
build number, while Flutter build flags may override either value.

See `docs/PROFILE_SETTINGS_SETUP.md` for the complete profile, avatar,
preference, versioning, and guest-account contract.

## History deletion

Phase 13 deletes an analysis as one user-owned session. PostgreSQL cascades
remove linked recommendations, generated-image records, and saved looks, while
the authenticated `delete-history-item` Edge Function removes every object
under the exact private analysis prefix first.

Deploy the function after linking the project:

```powershell
npx -y supabase functions deploy delete-history-item
```

The function uses the caller's JWT, existing RLS policies, and the injected
Supabase URL/anonymous client key. It does not require a service-role key.

The bucket permits JPEG, PNG, and WebP files up to 10 MiB. Later upload phases
must still validate actual content, extension, dimensions, and ownership before
uploading.

## AI usage quotas

`20260812000100_ai_usage_quota.sql` adds `public.ai_usage_events` and
`public.consume_ai_quota(text)`. Every Gemini-backed Edge Function consumes
quota after validation and before calling Gemini, so an authenticated account
cannot spend unbounded upstream AI capacity.

Limits are defined inside the SQL function rather than passed as arguments, so a
caller invoking the RPC directly cannot raise its own ceiling. `authenticated`
has `select` only and therefore cannot forge or reset usage. Exceeding a limit
returns HTTP 429 with code `rate_limited`.

`public.purge_ai_usage_events()` trims old rows but is not self-scheduling; add
a pg_cron job for it. See `docs/SECURITY_HARDENING.md` for the full Phase 16
audit and the remaining dashboard-side configuration.

## Security boundary

- The Flutter client receives only the project URL and publishable key.
- No service-role key, database password, or Gemini secret belongs in Flutter.
- Anonymous database and Storage access has no policy.
- Authenticated users can access only rows and object paths they own.
- Cross-owner foreign-key links are rejected by composite ownership keys.

Anonymous Auth users have authenticated, owner-scoped access while their
session exists. FaceTune does not yet support recovering or transferring an
anonymous account. Signing out or losing local app data can therefore make its
private records inaccessible even though sign-out does not delete those
records. Do not weaken RLS or publicize a bucket to work around that limitation.

The migrations must be applied to the remote project before client data calls
are added in later phases.
