# FaceTune production readiness checklist (Phase 19)

What Phase 19 configured in the repository, and what a human still has to do
before a real release. **Nothing here publishes the app.**

## Configured in this repository

| Item | Value | Where |
| --- | --- | --- |
| Application ID | `io.facetune.app` | `android/app/build.gradle.kts` |
| Namespace | `io.facetune.app` | `android/app/build.gradle.kts` |
| Kotlin package | `io.facetune.app` | `android/app/src/main/kotlin/io/facetune/app/MainActivity.kt` |
| Display name | `FaceTune` | `AndroidManifest.xml` (`android:label`) |
| Version | `1.0.0+1` (versionName 1.0.0, versionCode 1) | `pubspec.yaml` |
| minSdk / targetSdk | 24 / 36 (Flutter defaults) | `android/app/build.gradle.kts` |
| Java / Kotlin target | 17 | `android/app/build.gradle.kts` |
| Release signing | Reads `android/key.properties`; falls back to debug keys with a build warning | `android/app/build.gradle.kts` |
| R8 / resource shrinking | Enabled for release | `android/app/build.gradle.kts` |
| ProGuard rules | Plugin keep-rules, line numbers preserved | `android/app/proguard-rules.pro` |
| Cleartext traffic | Disabled explicitly | `AndroidManifest.xml` |
| Permissions | `INTERNET`, `CAMERA` only | `AndroidManifest.xml` |
| Splash background | Brand ivory, dark variant `#1A1517` | `res/values*/colors.xml`, `res/drawable*/launch_background.xml` |
| Deep-link scheme | `io.facetune.app://` (now matches the application ID) | `AndroidManifest.xml` |
| Secrets | `config/*.json`, `key.properties`, `*.jks` all git-ignored | `.gitignore`, `android/.gitignore` |

## Environment separation

The client takes only a project URL and publishable key, supplied at build time:

```powershell
# Development
flutter build apk --debug --dart-define-from-file=config/development.json

# Production
flutter build appbundle --release --dart-define-from-file=config/production.json
```

`config/example.json` is the committed template. `config/development.json` and
`config/production.json` are git-ignored and must be created locally.
`SupabaseConfig.validate()` rejects any key that is not `sb_publishable_`, so a
service-role or secret key cannot be shipped by accident.

If production uses a separate Supabase project, its migrations and Edge Functions
must be deployed there too — including the Phase 16 quota migration.

## Manual steps before release

### 1. Signing (required)

```powershell
keytool -genkey -v -keystore facetune-upload.jks -storetype JKS `
  -keyalg RSA -keysize 2048 -validity 10000 -alias facetune
```

Copy `android/key.properties.example` to `android/key.properties` and fill it in.
Back up the keystore and its passwords offline — losing them permanently blocks
app updates on Play. Never commit either file.

Verify the release artifact is signed with the upload key, not the debug key:

```powershell
flutter build apk --release --dart-define-from-file=config/production.json
apksigner verify --print-certs build\app\outputs\flutter-apk\app-release.apk
```

### 2. App icon (required)

The launcher icon is still the stock Flutter icon in
`android/app/src/main/res/mipmap-*/ic_launcher.png`. Supply a real 1024x1024
brand icon and generate the densities — for example by adding
`flutter_launcher_icons` as a dev dependency, or by exporting the mipmaps from a
design tool. Adaptive icons (`mipmap-anydpi-v26`) are recommended for Android 8+.

### 3. Backend configuration

- Push migrations to the production project (`supabase db push`).
- Deploy all four Edge Functions.
- Set the `GEMINI_API_KEY`, `GEMINI_MODEL`, and `GEMINI_IMAGE_MODEL` secrets.
- Schedule `public.purge_ai_usage_events()` with pg_cron.
- Complete the remaining items in `docs/SECURITY_HARDENING.md`.

### 4. Authentication

- Add `io.facetune.app://login-callback/**` and `io.facetune.app://reset-callback/**`
  to the Supabase redirect allow list.
- Enable email confirmation and configure production SMTP and templates.
- Publish the Google consent screen (currently testing mode).
- Enable CAPTCHA and auth rate limiting before public launch.

### 5. Other platforms (only if targeted)

iOS, macOS, and Linux still carry the template identifier `com.example.facetune`
(`ios/Runner.xcodeproj`, `macos/Runner/Configs/AppInfo.xcconfig`,
`linux/CMakeLists.txt`). Android is the primary and only validated platform, so
these were deliberately left untouched — the Xcode project files cannot be
verified from this workstation. Update them before building for those platforms.

### 6. Store listing (do not publish yet)

Privacy policy URL, data-safety form (this app collects photos and account data),
content rating, screenshots, feature graphic, and a Play Console entry. The
privacy policy is a **blocker**: the app processes facial images, and the
in-app Settings link is still a placeholder.

## Crash reporting strategy

No crash reporter is integrated, and Phase 19 deliberately did not add one —
introducing an SDK that transmits data off-device is a product and privacy
decision, not a build-configuration one.

Recommendation when it is added:

- Firebase Crashlytics or Sentry, initialized in `bootstrap()` behind the
  existing `analyticsConsent` preference in `user_settings`.
- Wire `FlutterError.onError` and `PlatformDispatcher.instance.onError`.
- Upload the R8 `mapping.txt` from
  `build/app/outputs/mapping/release/mapping.txt` for every release; without it
  release stack traces are unreadable. Archive it per versionCode.
- Never attach selfies, generated previews, signed URLs, tokens, or storage
  paths to a crash report. The sanitized failure types from Phase 15 are safe to
  attach; raw exceptions are not.

## Analytics strategy

No analytics SDK is active. `user_settings.analytics_consent` already stores the
user's choice, and the Settings screen states honestly that no SDK is running.

When analytics is added, gate every event behind that stored consent, default to
off, collect no image content or identifiers beyond the Supabase user ID, and
update the Play data-safety form to match.

## Secure logging

Release logging was audited in Phase 16: Edge Functions log operation names,
model IDs, status codes, and error *types* only — never image bytes, storage
paths, user IDs, tokens, or raw upstream bodies. Client repositories map failures
to sanitized, user-facing messages and never surface raw backend text.

`debugPrint` output is stripped from release builds by Flutter. Before shipping,
re-check that no `print` call was added that logs a URL, token, or file path.

## Release build validation

```powershell
flutter clean
flutter pub get
dart format .
flutter analyze
flutter test
flutter build appbundle --release --dart-define-from-file=config/production.json
```

Then install the release build on the POCO X3 GT and run the **[DEVICE]** rows of
`docs/QA_DEVICE_TEST_PLAN.md`. R8 and resource shrinking are only active in
release builds, so a release-mode smoke test is mandatory — minification can
break reflective code paths that debug builds never exercise.
