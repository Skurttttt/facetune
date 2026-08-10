# Authentication setup

The Flutter implementation supports email/password, password recovery, Google
OAuth, anonymous guest sessions, persisted sessions, profile bootstrap, and
logout. Provider availability and redirect URLs still require project-console
configuration.

## Apply database migrations

Apply all migrations before testing registration:

```powershell
supabase login
supabase link --project-ref usmlwaocafeqnspdsvmv
supabase db push
```

The Phase 4 migration adds an `auth.users` trigger that creates `profiles` and
`user_settings` rows for email, OAuth, and anonymous users. The client also
performs an ownership-scoped upsert after session creation as a recovery path.

## Redirect URLs

In Supabase Dashboard → Authentication → URL Configuration, add:

```text
io.facetune.app://login-callback/**
io.facetune.app://reset-callback/**
```

The Android manifest and iOS URL types already register the
`io.facetune.app` scheme.

## Email authentication

Enable the Email provider. Decide whether email confirmation is required:

- When confirmation is enabled, registration shows a confirmation message and
  the user signs in after confirming.
- When disabled, registration immediately creates a persisted session.

Configure production email templates and SMTP before release. Password reset
links must preserve the configured `reset-callback` redirect.

## Anonymous guest sessions

Enable Anonymous Sign-Ins under Authentication provider settings before using
the guest button. Supabase anonymous users receive the `authenticated` database
role, so existing user-ID RLS policies isolate their rows.

Enable CAPTCHA and rate limiting before public release to reduce automated guest
account abuse. Signing out does not delete the anonymous Auth user or its
backend records; it removes the local session and therefore access to those
records. Account upgrade/linking and automatic guest cleanup belong to a later
data-management phase.

## Google OAuth

1. In Google Auth Platform, configure the consent screen and the `openid`,
   email, and profile scopes.
2. Create a Google OAuth Web application client.
3. Add the Supabase callback URL displayed on Dashboard → Authentication →
   Providers → Google to the Google client's authorized redirect URIs.
4. Put the Google Web client ID and client secret in the Supabase Google
   provider settings. Never add the Google client secret to Flutter.
5. Enable the Google provider.
6. Confirm the FaceTune callback URLs above are in the Supabase redirect allow
   list.
7. Add test users while the Google consent screen remains in testing mode.

OAuth opens through the system browser and returns through the registered
custom scheme. Release branding, domain verification, and final Google consent
screen publication require owner access to Google Cloud and Supabase Dashboard.

## Run

```powershell
flutter run --dart-define-from-file=config/development.json
```
