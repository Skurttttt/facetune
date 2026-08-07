# Supabase local setup

FaceTune reads public Supabase client configuration from compile-time Dart
defines. Values are not hardcoded in Dart or bundled as Flutter assets.

1. Copy `config/example.json` to `config/development.json`.
2. Set `SUPABASE_URL` to the project API URL from the Supabase Connect panel,
   not a dashboard URL.
3. Set `SUPABASE_PUBLISHABLE_KEY` to an `sb_publishable_...` key.
4. Run the app:

```powershell
flutter run --dart-define-from-file=config/development.json
```

Build Android with the same configuration:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

`config/development.json`, `config/production.json`, and `*.local.json` are
ignored by Git. `config/example.json` contains placeholders and is safe to
commit.

If no Supabase defines are supplied, the static application still starts
without initializing Supabase. This supports UI tests and compile-only
workflows. If only one value is supplied, or if the URL/key format is invalid,
startup fails before constructing a client.

Apply database and Storage migrations using the instructions in
`supabase/README.md`.
