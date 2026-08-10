# Supabase local setup

FaceTune reads public Supabase client configuration from compile-time Dart
defines. Values are not hardcoded in Dart or bundled as Flutter assets.

1. Copy `config/example.json` to `config/development.json`.
2. Set `SUPABASE_URL` to the project API URL from the Supabase Connect panel,
   not a dashboard URL.
3. Set `SUPABASE_PUBLISHABLE_KEY` to an `sb_publishable_...` key.
4. Run the app:

```powershell
powershell -ExecutionPolicy Bypass -File tool/run_dev.ps1
```

The repository also includes configured development launch targets:

- VS Code: select `FaceTune — Development` and press F5. Workspace settings
  also add the define file to normal Flutter runs.
- Android Studio: select the shared `FaceTune — Development` run
  configuration.
- PowerShell: use `tool/run_dev.ps1` instead of plain `flutter run`.

Plain `flutter run` does not automatically read JSON configuration files. It
creates a valid but intentionally unconfigured build, so the authentication
guard will appear. Use one of the configured launch paths above for every
development run.

Build Android with the same configuration:

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
```

To build and install the configured APK in one guarded step, use:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_and_install_dev.ps1
```

The script validates the expected property names and formats, builds with the
define file, locates `adb.exe` from `android/local.properties`, and installs
only when an authorized device is connected. It then launches the installed
package and requires the sanitized device log to report `Supabase
initialization: READY`. This prevents accidentally reinstalling or accepting an
older APK that was compiled without Supabase defines.

`config/development.json`, `config/production.json`, and `*.local.json` are
ignored by Git. `config/example.json` contains placeholders and is safe to
commit.

If no Supabase defines are supplied, the static application still starts
without initializing Supabase. This supports UI tests and compile-only
workflows. If only one value is supplied, or if the URL/key format is invalid,
startup fails before constructing a client.

Debug startup logs report only whether each value is present and whether
initialization is ready, missing, invalid, or failed. The publishable key itself
is never printed.

Apply database and Storage migrations using the instructions in
`supabase/README.md`.
