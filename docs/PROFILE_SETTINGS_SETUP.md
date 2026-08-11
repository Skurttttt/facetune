# Profile and settings setup

Phase 14 stores profile and preference data in the existing user-owned
`profiles` and `user_settings` tables. Apply the Phase 14 migration before
using these screens against a Supabase project:

```powershell
npx -y supabase db push
```

The relevant migration is
`supabase/migrations/20260811000300_profile_settings.sql`. It:

- adds the validated `user_settings.theme_mode` preference;
- migrates an existing `dark_mode = true` preference to `theme_mode = 'dark'`;
- constrains profile avatar paths to the owning user's UUID prefix;
- creates the private `profile-avatars` Storage bucket; and
- installs owner-only select, insert, update, and delete Storage policies.

No Edge Function or private server credential is required for profile and
settings access. Flutter uses the signed-in user's session, and the existing
table and Storage RLS policies remain the authorization boundary.

## Profile avatars

Profile avatars use a bucket separate from selfies and generated previews:

```text
bucket: profile-avatars
object: {authUserId}/avatar.jpg
database: profiles.avatar_path = {authUserId}/avatar.jpg
```

The bucket is private, accepts JPEG only, and limits objects to 2 MiB. The
client resizes and converts the selected image to JPEG, removes EXIF metadata,
and verifies that the prepared bytes fit the same limit before upload. The
stable `avatar.jpg` name is updated in place so replacing an avatar does not
create abandoned versions.

Only the object path is stored in PostgreSQL. The UI obtains a short-lived
signed URL when loading a profile; do not persist that URL or convert this
bucket to public access. Both the database constraint and Storage policies
require the first path segment to equal the authenticated user's UUID.

## Profile name truth

`profiles.display_name` is the application profile value. A successful edit
also updates Supabase Auth `user_metadata.display_name` so future session and
profile bootstrap behavior stays consistent. Display names are trimmed and
must contain between 1 and 80 characters.

The Phase 4 auth bootstrap trigger creates one `profiles` row and one
`user_settings` row for email, OAuth, and anonymous users. If either row is
missing for an older account, reapply the existing migrations or repair the
bootstrap data before treating a client error as an RLS problem.

## Preference truth

`user_settings.theme_mode` is the authoritative appearance preference. Its
allowed values are:

```text
system
light
dark
```

`system` follows the platform appearance. `light` and `dark` select a fixed
Flutter `ThemeMode`. The older `dark_mode` column remains for compatibility;
the client writes it alongside `theme_mode`, but new code should read
`theme_mode` first. If a legacy row has no usable theme value, the client falls
back to `dark_mode = true` or otherwise to `system`.

The following fields are also persisted per user:

- `notifications_enabled`: a stored preference only; FaceTune does not send
  notifications yet.
- `analytics_consent`: the user's stored consent choice; no analytics SDK is
  active in this phase.

Do not interpret either preference as proof that a future notification or
analytics integration is configured. Those integrations must honor the saved
choice when they are implemented.

## App version truth

The default application version is declared by `version` in `pubspec.yaml`.
Flutter builds may override it with `--build-name` and `--build-number`, so the
Settings screen reads the installed package metadata through
`PackageInfo.fromPlatform()` and displays `{version}+{buildNumber}`. This makes
the value shown in the app describe the installed artifact rather than a
hardcoded label.

## Guest accounts

Supabase anonymous users receive a normal user UUID and an authenticated
session. Their profile, preferences, avatar, history, and saved looks therefore
use the same owner-only RLS rules as registered accounts.

Guest access is still temporary:

- signing out does not itself delete backend records, but the anonymous
  account cannot currently be recovered or transferred in FaceTune;
- clearing app data or otherwise losing the anonymous session can permanently
  remove the user's ability to access those private records;
- creating a separate registered account does not automatically move guest
  records; and
- the app must warn guests before sign-out and must not promise account
  recovery, merging, or a retention period.

Do not weaken RLS or publish private buckets to work around guest-session
loss. Account linking or transfer requires a dedicated, securely designed
future flow.

## Safe verification

After applying migrations, verify without printing tokens or signed URLs:

1. Sign in with a test account and confirm its `profiles` and `user_settings`
   rows exist.
2. Change among System, Light, and Dark, restart the app, and confirm the saved
   selection restores.
3. Change notification and analytics preferences and confirm their stored
   values update for only that user.
4. Upload an avatar and confirm the stored path is exactly
   `{userId}/avatar.jpg` in the private `profile-avatars` bucket.
5. Confirm another authenticated user cannot read the first user's profile,
   settings, or avatar object.

Never place a service-role key, database password, or any other private secret
in Flutter configuration or setup documentation.
