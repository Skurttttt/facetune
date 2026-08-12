# FaceTune QA & device test plan (Phase 18)

Primary target: **Android — POCO X3 GT** (1080x2400, ~2.75x DPR, ~393x873 logical).

This plan covers every item in the Phase 18 checklist. Each item is marked:

- **[AUTO]** — verified by `flutter test`, re-run on every change.
- **[DEVICE]** — requires a physical Android device or emulator; cannot be
  executed from the development workstation and must be run by a human.

No Android device or emulator was attached when this plan was written, so every
**[DEVICE]** item below is **untested**, not passed.

## Build and install

```powershell
flutter build apk --debug --dart-define-from-file=config/development.json
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

Prerequisites: the Supabase migrations are pushed, the Edge Functions are
deployed (including the Phase 16 quota migration), and `config/development.json`
holds the project URL and publishable key.

## 1. Install and launch

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 1.1 | Clean install | DEVICE | `adb uninstall io.facetune.app` then install | Installs with no crash |
| 1.2 | Cold launch | DEVICE | Launch from the launcher | Auth screen within ~3 s, no white flash, no red error screen |
| 1.3 | Missing config | AUTO | `supabase_config_test`, `supabase_initializer_test` | Friendly "configuration missing" state, no crash |

## 2. Authentication

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 2.1 | Registration | DEVICE | Register with a new email | Account created; confirmation copy if confirmation is on |
| 2.2 | Email login | DEVICE | Sign in with valid credentials | Lands on Home |
| 2.3 | Wrong password | DEVICE | Sign in with a bad password | Friendly message, no raw Supabase text, form stays usable |
| 2.4 | Validation | AUTO | `auth_validators_test` | Email/password/name rules enforced |
| 2.5 | Google auth | DEVICE | Tap Google sign-in | Browser/one-tap opens; returning completes sign-in |
| 2.6 | Guest flow | DEVICE | Continue as guest | Home loads; guest notices appear in Settings/History |
| 2.7 | Session restore | AUTO + DEVICE | `auth_controller_test` covers restore; on device force-quit and relaunch | Still signed in, no re-login |
| 2.8 | Logout | AUTO + DEVICE | `auth_controller_test`; on device sign out from Settings | Returns to auth; guest warned first |
| 2.9 | Expired session | AUTO | `auth_resilience_test`, `auth_recovery_ui_test`, profile/settings resilience | "Sign in again" recovery, never a dead spinner |
| 2.10 | Auth guard | AUTO | `auth_guard_test` | Protected routes redirect when signed out |

## 3. Permissions, camera, gallery

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 3.1 | Camera permission prompt | DEVICE | First capture attempt | System prompt appears |
| 3.2 | Permission denied once | DEVICE | Deny the prompt | Explains, offers retry and gallery; no dead end |
| 3.3 | Permission permanently denied | DEVICE | Deny with "don't ask again", retry | Offers "Open Settings"; deep-links to app settings |
| 3.4 | Gallery selection | DEVICE | Pick a photo | Preview appears |
| 3.5 | Cancelled picker | DEVICE | Open the picker and back out | Returns cleanly, no stuck spinner |
| 3.6 | Camera capture | DEVICE | Take a selfie with the front camera | Preview appears right-side up |
| 3.7 | Image replacement | AUTO + DEVICE | `scan_controller_test` covers replace/cancel/cleanup; on device replace a chosen image | Old preview swapped only after success |
| 3.8 | Invalid image | AUTO + DEVICE | `selfie_file_validator_test`, `flutter_image_validation_repository_test`; on device pick a non-image or corrupt file | Clear reason, reselect offered, no crash |
| 3.9 | Oversized image | AUTO | `selfie_file_validator_test` | Rejected over 20 MB with a clear message |

## 4. AI pipeline

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 4.1 | Face analysis | AUTO + DEVICE | `face_analysis_*` tests; on device run a real scan | Attributes returned and persisted |
| 4.2 | No face / multiple faces | AUTO | `face_analysis_repository_test` | Deterministic message, no endless retry |
| 4.3 | Style selection | AUTO + DEVICE | `makeup_style_*`, `style_selection_page_test` | Selection persists through the workflow |
| 4.4 | Recommendation | AUTO + DEVICE | `makeup_recommendation_*` tests; on device generate a plan | Structured plan with colours, HEX, placement, reasoning; no brands |
| 4.5 | Preview generation | AUTO + DEVICE | `makeup_preview_controller_test`; on device generate a preview | Identity-conscious image; original never overwritten |
| 4.6 | Malformed AI output | AUTO | `*_dto_test`, validation tests | Sanitized failure, no crash |
| 4.7 | AI timeout | AUTO | `face_analysis_repository_test` bounded-timeout tests | Bounded, retryable, friendly copy |
| 4.8 | Quota exhaustion | AUTO | `face_analysis_repository_test` 429 test | "Reached the limit" copy; internal quota state hidden |
| 4.9 | Regenerate variation | DEVICE | Generate another variation | New generation number; previous result retained on failure |

## 5. Results, saving, history

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 5.1 | Before/after | AUTO + DEVICE | `result_actions_widget_test`; on device drag the slider | Smooth reveal, both images sharp |
| 5.2 | Save | AUTO + DEVICE | `result_actions_controller_test` | Appears in Saved Looks |
| 5.3 | Favorite | AUTO + DEVICE | `saved_looks_controller_test` | Toggles; duplicate taps ignored while mutating |
| 5.4 | Share | DEVICE | Tap Share | Android sheet opens with the image |
| 5.5 | History list | AUTO + DEVICE | `history_controller_test`, `supabase_history_repository_test` | Newest first, paginates, thumbnails load |
| 5.6 | Deletion | AUTO + DEVICE | `history_controller_test`; on device delete a session | Confirmation, then row and storage objects removed |
| 5.7 | Pagination failure | AUTO | `history_controller_test`, `saved_looks_controller_test` | Stops and offers retry; never loops |
| 5.8 | Empty states | AUTO | `home_page_test`, history/saved tests | Honest empty copy, no fabricated content |

## 6. Profile and settings

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 6.1 | Profile load/update | AUTO + DEVICE | `profile_controller_test`, `profile_page_test` | Name and avatar update and persist |
| 6.2 | Avatar upload | DEVICE | Choose a new photo | Uploads, replaces the stable object, displays via signed URL |
| 6.3 | Settings persistence | AUTO + DEVICE | `settings_controller_test`, `supabase_settings_repository_test` | Theme and preferences survive relaunch |
| 6.4 | Failure handling | AUTO | `profile_resilience_test`, `settings_resilience_test` | Rollback, retry, no raw backend text |

## 7. Network and failure conditions

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 7.1 | Offline start | DEVICE | Enable airplane mode, open Home | Honest offline state; Start Scan still reachable |
| 7.2 | Offline mid-scan | DEVICE | Disable network during analysis | Bounded failure with retry, no infinite spinner |
| 7.3 | Slow network | DEVICE | `adb shell settings put global captive_portal_mode 0` plus a throttling proxy, or Android Studio's network throttle | Progress states remain honest; timeouts bounded |
| 7.4 | Backend failure | AUTO | Repository failure-mapping tests across features | Sanitized message plus a recovery action |
| 7.5 | Signed URL expiry | DEVICE | Leave a result open >1 h, return | "Image unavailable — reopen to refresh" rather than a blank tile |

## 8. Platform behaviour

| # | Item | Mode | Procedure | Expected |
| --- | --- | --- | --- | --- |
| 8.1 | Back button — navigation | DEVICE | Press back on each screen | Predictable pop; never exits mid-workflow unexpectedly |
| 8.2 | Back button — during AI work | DEVICE | Press back while analysis/generation runs | Leaves cleanly; a late result never resurrects the old screen (guarded by generation counters, `scan_controller_test`, `makeup_preview_controller_test`) |
| 8.3 | Keyboard | AUTO + DEVICE | Auth forms use a scrollable `ListView`; on device focus each field | Fields scroll above the keyboard; no overflow stripes |
| 8.4 | Input actions | DEVICE | Use next/done on the keyboard | Focus advances; done submits |
| 8.5 | Screen sizes | AUTO | `responsive_layout_test` at 320x640, 393x873, 800x1280 | No overflow on Home, Profile, Settings |
| 8.6 | Lifecycle pause/resume | DEVICE | Background mid-scan, return after a few minutes | State intact or an honest recovery path; no crash |
| 8.7 | Process death | DEVICE | Enable "Don't keep activities", background and return | Relaunches to a valid screen |
| 8.8 | Rotation | DEVICE | Rotate on each screen if rotation is enabled | No overflow or lost input |
| 8.9 | Dark mode | AUTO + DEVICE | `dark_mode_contrast_test`; on device switch system theme and toggle in Settings | All text readable; accent cards keep dark foreground |

## Known gaps

- Every **[DEVICE]** row is unverified. Automated coverage cannot substitute for
  camera hardware, real permission dialogs, Google sign-in, the share sheet,
  process death, or real network conditions.
- There is no `integration_test/` suite. Adding one would let the end-to-end scan
  flow run on-device via `flutter drive`, but it needs a real Supabase project
  and live Gemini credentials, so it would consume AI quota on every run.
- Widget tests approximate screen size with `tester.view.physicalSize`. This
  catches layout overflow but not font scaling, system insets, gesture bars, or
  display cutouts.
