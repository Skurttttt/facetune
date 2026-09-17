# FaceTune Master System Handoff

**Generated:** 2026-09-15
**Repository:** `C:\Users\Kurt\facetune`
**Branch at time of writing:** `feature/subscription-v1` @ `e8c4484` ("SUB - 08") + uncommitted SUB-9 / SUB-10 work
**Method:** Read-only inspection of the actual repository (source, migrations, Edge Functions, tests, configs, docs, git). Nothing was modified, deployed, or executed against remote services. `flutter analyze` was run locally (result: **No issues found**).

**Labels used throughout:**
- **CONFIRMED** — proven directly from repository contents.
- **INFERRED** — strongly implied by code/docs but not directly provable from the repo.
- **UNKNOWN** — cannot be determined from the repository.
- **NEEDS VERIFICATION** — must be checked against a live system (Supabase dashboard, Play Console, device).

---

## 1. Executive Summary

FaceTune ("Your AI Makeup Artist") is a **Flutter (Dart 3.10 / Flutter 3.38) Android-first mobile app** backed entirely by **Supabase** (Auth, Postgres with strict RLS, private Storage, Deno Edge Functions) and **Google Gemini** (called *only* from Edge Functions, never from the client).

The user takes/uploads a selfie → Gemini analyses facial attributes → the user picks a makeup style (or "My Makeup Kit" mode using products they own) → Gemini writes a makeup plan → Gemini image model renders a **Final Makeup Preview** (the app's one billable unit, an "AI Look") → optional AI Step-by-Step Tutorial with guideline overlays → results are saved to private history / saved looks and can be shared.

A **server-authoritative subscription system** (SUB-0 → SUB-10 of a 15-phase plan) has been built: plan catalog, entitlements, an idempotent reserve/commit/release usage ledger, a Google-Play-priced paywall, Google Play Billing client integration (`in_app_purchase` 3.3.0 / Play Billing Library 8), and a server-side purchase verification Edge Function that calls the **Google Play Developer API** and activates entitlements via a `service_role`-only RPC.

**The project is currently blocked** on an external Google Play Developer API authorization problem: the service account's OAuth token exchange succeeds (HTTP 200) but Play API calls return `401 insufficient permissions` / `403 PERMISSION_DENIED`. Code inspection finds **no code-side defect** in the JWT/OAuth/API path. The problem sits in Play Console ↔ Cloud project ↔ service-account effective authorization (external). Google support has been contacted.

Two additional important findings from this audit that were not previously called out:

1. **No Free entitlement is ever provisioned** (SUB-12 not built). Once the subscription migrations are applied, `reserve_ai_look` denies every account that has no `user_entitlements` row with `ENTITLEMENT_NOT_FOUND` (HTTP 403), and the Flutter client maps 403 to the misleading message *"The original selfie or makeup plan is no longer available."* If those migrations are already on the live project (NEEDS VERIFICATION), **no new user can generate a Final Preview today**.
2. **SECURITY WARNING:** `NOTES.md` (tracked, committed in `2c728fe`, pushed to `origin`) contains a plaintext line labelled `SUPABASE PW:` — a credential. It must be rotated and purged from git history. The value is deliberately not reproduced here.

---

## 2. Current Project Status

| Area | Status | Evidence |
| --- | --- | --- |
| Core AI journey (scan → analysis → style → plan → preview) | **Working** (per repo + baseline audits; needs device re-verification) | Full feature slices, 156 test files, prior phase locks |
| My Makeup Kit mode | **Working** | MK-1…MK-14 merged to `main` (`eb6c5e3`) |
| Step-by-Step Tutorial V4 | **Working, locked** | V4-QA-8 baseline lock, `tutorial_guideline_v4_7` |
| Live scan (educational palette, LSEP) | **Working** | `feature/live-scan-educational-palette` merged |
| History / Saved Looks / Profile / Settings | **Working** | Productionization phases complete |
| Subscription domain + DB + resolver + usage ledger (SUB-1…SUB-5) | **Implemented, committed** | `e8c4484`, 3 migrations dated 2026-09-07 |
| Flutter subscription state, allowance UX, paywall (SUB-6…SUB-8) | **Implemented, committed** | `e8c4484` |
| Google Play Billing client (SUB-9) | **Implemented, UNCOMMITTED** | 15 untracked Dart files + tests |
| Server purchase verification (SUB-10) | **Implemented, UNCOMMITTED, BLOCKED externally** | `verify-google-play-purchase/`, migration `20260910000100` |
| Lifecycle/renewal/cancellation/restore (SUB-11) | **Not started** | Explicit hard stop in docs |
| Free & Salon Pilot provisioning (SUB-12) | **Not started** — see §26 | No code inserts a Free entitlement |
| Web Admin | **Not started** (spec only) | `FACETUNE_WEB_ADMIN_*.md` |
| iOS / Web / Desktop | **Scaffolding only** | Default Flutter runner dirs |
| CI/CD | **None** | No `.github/` |
| Release signing | **Configured locally** but `android/key.properties` is polluted (see §22) | |
| A release AAB was built | `build/app/outputs/bundle/release/app-release.aab` dated 2026-09-10 | Whether it was uploaded to Play: **UNKNOWN** |

---

## 3. Technology Stack

**CONFIRMED** from `pubspec.yaml` / `pubspec.lock` / configs:

| Layer | Technology | Version |
| --- | --- | --- |
| Mobile framework | Flutter (stable) | 3.38.2 (Dart SDK `^3.10.0`) |
| Language | Dart | 3.10 |
| State management | `flutter_riverpod` (StateNotifier pattern) | 2.6.1 |
| Navigation | `go_router` (StatefulShellRoute, auth redirect) | 14.8.1 |
| Backend | Supabase (`supabase_flutter`) | 2.17.1 (gotrue 2.27.1, functions_client 2.7.1) |
| Serverless | Supabase Edge Functions (Deno, TypeScript, `npm:@supabase/supabase-js@2`) | — |
| Database | Supabase Postgres, 27 migrations, RLS everywhere | — |
| Storage | Supabase Storage, private buckets `face-images`, `profile-avatars` | — |
| AI | Google Gemini via REST `generativelanguage.googleapis.com` | text: `gemini-3.6-flash`; image: `gemini-3.1-flash-image` (locked) |
| Billing | `in_app_purchase` 3.3.0 + `in_app_purchase_android` 0.5.0 (Play Billing Library 8.0.0) | — |
| Camera / images | `camera` 0.12.0+2, `image_picker` 1.2.3, `flutter_image_compress` 2.5.1, `permission_handler` 12.0.3 | — |
| Misc | `share_plus` 13.3.0, `package_info_plus` 10.2.1, `uuid` 4.6.0, `path_provider` 2.1.6 | — |
| Lint | `flutter_lints` 6.0.0 (default rule set) | — |
| Android | applicationId `io.facetune.app`, Kotlin 2.2.20, AGP 8.11.1, Java 17, R8 + resource shrink on release | — |
| Architecture | Clean Architecture, feature-first (`data/domain/presentation`), repository pattern | — |

**Supabase project ref (public, from README):** `usmlwaocafeqnspdsvmv`
**Google Cloud project (from prompt context):** `skurttttt-project` (five t's), project number `822961189701`
**Service account:** `facetune-play-billing@skurttttt-project.iam.gserviceaccount.com`

---

## 4. System Architecture

### 4.1 Top-level flow

```
User (Android device)
  ↓
Flutter app (Riverpod controllers → use cases → repositories → Supabase data sources)
  ↓  supabase_flutter (publishable key + user JWT)
Supabase Auth (email/password, Google OAuth, anonymous guest)
  ↓
Supabase Postgres (RLS: owner-only rows)  +  Supabase Storage (private, owner-prefixed paths)
  ↓  client.functions.invoke(...) with user JWT
Supabase Edge Functions (Deno)  ── re-validate JWT → check quota / AI Look → call Gemini → write Storage + DB as the user
  ↓
Google Gemini REST API (x-goog-api-key from server secret)
  ↓
Result rows + object paths → Flutter reads via RLS + short-lived signed URLs (3600 s)
```

### 4.2 Security boundaries (CONFIRMED)

- The Flutter client holds only `SUPABASE_URL` and a `sb_publishable_*` key (`SupabaseConfig.validate()` refuses anything else). **No Gemini key, no service-role key, no Play service-account material** is compiled into the app (enforced by `test/features/subscription/subscription_billing_security_test.dart`).
- Every Edge Function re-establishes identity from the caller's `Authorization: Bearer <JWT>` via `auth.getUser()` and then acts **as the user** (anon key + user JWT), so RLS applies to every table/Storage operation.
- Exactly one function — `verify-google-play-purchase` — additionally uses `SUPABASE_SERVICE_ROLE_KEY`, for exactly one RPC (`activate_verified_google_play_subscription`) that is granted to `service_role` only.
- All subscription/usage authority is in SQL `security definer` functions that derive the user from `auth.uid()`; the client can only *read* its own entitlement/ledger rows (column-restricted grants).

### 4.3 Subsystem flows

**AI Look (Final Preview) — the billable unit**
```
Flutter MakeupPreviewController.generate(recommendation)
 → functions.invoke('generate-makeup-preview', {recommendationId})
 → Edge: auth → load recommendation+analysis (RLS) → ownership check on original path
 → reserve_ai_look(operation_id)        ← DENIES if no active entitlement / no capacity
 → [parallel] download original | latest generation number | consume_ai_quota('makeup_preview')
 → Gemini image (gemini-3.1-flash-image, 2 attempts, 90 s each, 135 s budget)
 → identity check (output ≠ input bytes) → upload to face-images/{uid}/analyses/{aid}/generated/{rid}/preview_####.ext
 → insert generated_images row → commit_ai_look(operation_id, 'standard', preview_id)
 → return preview; Flutter creates 2 signed URLs and shows Before/After
 (on failure before persistence: release_ai_look; after persistence: reservation left for reconciliation)
```

**Purchase (SUB-9 + SUB-10)**
```
Paywall (SubscriptionPage) → PurchaseController.buy(plan)
 → GooglePlayBillingGateway.startPurchase → queryProductDetails → buyNonConsumable(GooglePlayPurchaseParam{offerToken, applicationUserName=userId})
 → purchaseStream → PurchaseUpdate(purchased, evidence{productId, purchaseToken})
 → SupabasePurchaseVerificationGateway.verify → functions.invoke('verify-google-play-purchase', {purchaseToken, providerProductId})
 → Edge: auth(user JWT) → GooglePlayApi: RS256 JWT → oauth2 token → GET subscriptionsv2/tokens/{token}
 → interpretPurchase (approved product, state, account id match) → sha256(token)
 → service_role RPC activate_verified_google_play_subscription(...)  → user_entitlements + provider_purchase_verifications
 → POST purchases/subscriptions/{productId}/tokens/{token}:acknowledge
 → resolve_subscription_state() as user → return {verified, acknowledged, subscription}
 → Flutter: completePurchase (client-side ack) → SubscriptionController.refresh() → phase=verified
```
**Currently fails at the `GET subscriptionsv2` step with 401/403 from Google (external).**

---

## 5. Repository Structure

```
facetune/
├── lib/
│   ├── main.dart                         # bootstrap() only
│   ├── app/
│   │   ├── app.dart                      # MaterialApp.router, theme, themeMode
│   │   ├── bootstrap/bootstrap.dart      # Supabase init → ProviderScope override
│   │   └── router/                       # go_router: shell (Home/Saved/History/Profile) + journey routes; auth redirect
│   ├── core/
│   │   ├── config/                       # AppConfig, SupabaseConfig.fromEnvironment (dart-define)
│   │   ├── constants/app_constants.dart  # routes, deep-link callback URLs, spacing
│   │   ├── data/supabase_remote_data_source.dart
│   │   ├── errors/failures.dart
│   │   └── supabase/                     # initializer, availability + client providers
│   ├── features/                         # each: data/ domain/ presentation/
│   │   ├── authentication/               # Supabase Auth (email, Google OAuth, guest), profile bootstrap
│   │   ├── scan/                         # selfie acquisition, local validation, LIVE camera educational palette
│   │   ├── analysis/                     # analyze-face invocation, Beauty Profile
│   │   ├── makeup_styles/                # style catalog (natural, everyday, office, soft_glam, full_glam, bridal, korean, clean_girl, party, date_night)
│   │   ├── recommendation/               # generate-makeup-recommendation, Makeup Plan page (+ AiLookAllowanceNotice)
│   │   ├── preview/                      # generate-makeup-preview, Final Preview page
│   │   ├── results/                      # shared result shell: before/after, breakdown, palette, share, favorite
│   │   ├── tutorial/                     # V4 manifest + per-category guideline steps
│   │   ├── makeup_kit/                   # owned products CRUD, kit recommendation/preview, kit saved looks
│   │   ├── history/                      # unified feed (Standard + Kit), filters, delete via Edge Function
│   │   ├── saved_looks/                  # favorites for Standard previews
│   │   ├── profile/                      # display name, avatar (profile-avatars bucket), links, SubscriptionSummaryCard
│   │   ├── settings/                     # theme mode, notification/analytics prefs, sign out, about
│   │   ├── home/                         # dashboard: scan hero, recent looks
│   │   └── subscription/                 # SUB-1…SUB-10 (see §14)
│   ├── shared/widgets/                   # design-system widgets (AppShell, PageFrame, AppNotice, StatusState, buttons, PrivateImage…)
│   └── theme/                            # AppColors/AppSpacing/AppRadii tokens, AppSemantics ThemeExtension, AppTheme light/dark
├── supabase/
│   ├── config.toml                       # verify_jwt=true for 8 functions (verify-google-play-purchase NOT listed)
│   ├── migrations/ (27 files)            # schema, RLS, quotas, tutorial v1-v4, subscription (SUB-2/3/4/10)
│   └── functions/
│       ├── _shared/                      # ai_quota, ai_look_usage, final_preview_model (LOCK), tutorial_* , storage_ownership, prompt_safety
│       ├── analyze-face/                 # Gemini structured face analysis
│       ├── generate-makeup-recommendation/
│       ├── generate-makeup-preview/      # canonical Final Preview (billable)
│       ├── generate-kit-makeup-recommendation/
│       ├── generate-kit-makeup-preview/  # canonical Final Preview, Kit mode (billable)
│       ├── analyze-tutorial-manifest-v4/ # what makeup is visibly present in the preview
│       ├── generate-tutorial-step-v4/    # guideline overlay image per category
│       ├── delete-history-item/          # removes Storage prefix + cascades rows
│       └── verify-google-play-purchase/  # SUB-10 (untracked)
├── android/                              # applicationId io.facetune.app; release signing from key.properties (git-ignored)
├── config/example.json                   # dart-define template; development.json/production.json git-ignored
├── tool/run_dev.ps1, build_and_install_dev.ps1
├── test/ (156 test files)                # unit, widget, contract (source-text), e2e journeys, QA matrices
├── docs/                                 # setup guides (Auth, Gemini, Supabase, Play Billing, Security, Production checklist, QA plan)
└── *.md (root)                           # CODEX_MASTER_GUIDE, Source-of-Truth + Phase-Prompt docs per track, baseline audits/locks
```

Platform folders `ios/`, `macos/`, `linux/`, `windows/`, `web/` are default Flutter scaffolding (iOS registers the `io.facetune.app` URL scheme). `build/` (4.4 GB) is untracked output.

### 5.1 Documentation authority order (project convention, CONFIRMED in `CODEX_MASTER_GUIDE.md` and phase prompts)
1. `CODEX_MASTER_GUIDE.md` — overall engineering rules (clean architecture, no God classes, no AI calls in widgets).
2. Track Source-of-Truth docs (`FACETUNE_*_SOURCE_OF_TRUTH.md`) — hard locks per track.
3. Track Phase Prompts (`FACETUNE_*_PHASE_PROMPTS.md`) — one prompt per phase, "STOP after phase".
4. Baseline audits / locks (`*_BASELINE_AUDIT.md`, `*_BASELINE_LOCK.md`, `V4_QA_*.md`).
The project was developed phase-by-phase by an AI agent ("Codex") following these prompts. Future work is expected to follow the same discipline.

---

## 6. Complete Feature Inventory

Every feature requires an authenticated Supabase session (email, Google, or **anonymous guest** — guests get the `authenticated` role). Unless stated, no premium requirement.

### 6.1 Authentication
- **Purpose:** Sign in / register / reset password / Google OAuth / continue as guest / sign out.
- **Entry:** `/auth` (`AuthenticationPage`), `/auth/email`, `/auth/register`, `/auth/forgot-password`, `/auth/reset-password`, `/auth/loading`.
- **Files:** `lib/features/authentication/**`, `lib/app/router/app_router.dart` (redirect), migration `20260808000100_auth_profile_bootstrap.sql`.
- **Frontend:** `AuthController` (StateNotifier) listens to `onAuthStateChange`; router redirects unauthenticated users to `/auth` and `passwordRecovery` state to `/auth/reset-password`.
- **Backend:** Supabase Auth; DB trigger creates `profiles` + `user_settings`; client also upserts them (`ensureProfile`) as a recovery path.
- **DB:** `profiles`, `user_settings`.
- **Status:** Working. **Limitations:** anonymous accounts cannot be recovered/linked; Google OAuth and email confirmation need dashboard config (NEEDS VERIFICATION); no account deletion feature.

### 6.2 Scan (selfie acquisition)
- **Purpose:** Take a photo (live camera with educational quality palette) or pick from gallery; validate locally; upload; trigger analysis.
- **Entry:** Home "Start scan" → `/scan` (`ScanPage`), `/scan/live` (`LiveCameraPage`).
- **Files:** `lib/features/scan/**` (`ScanController`, `LiveScanController`, `DeviceSelfieRepository`, `FlutterImageValidationRepository`, `CameraLiveSession`).
- **Frontend:** camera permission → capture/pick → copy original to temp → compress to JPEG ≤2048 px q88 (EXIF stripped) → local validation (dims 480–12000, ≤80 MP, aspect 0.4–2.5, ≤10 MiB) → `FaceAnalysisController.analyze`.
- **Live scan:** local-only luma statistics per frame (no network, no capture automation — SOT forbids auto-shutter).
- **Backend/DB:** upload to `face-images/{uid}/analyses/{analysisId}/original/{imageId}.jpg` (`upsert:false`).
- **Status:** Working.

### 6.3 Face Analysis (Beauty Profile)
- **Entry:** automatic after scan → `/analysis` (`AnalysisResultPage`).
- **Files:** `lib/features/analysis/**`, `supabase/functions/analyze-face/**`.
- **Backend:** `analyze-face` → JWT → `consume_ai_quota('face_analysis')` → Gemini `GEMINI_MODEL` (default `gemini-3.6-flash`, prompt `face_analysis_v2`, structured JSON schema) → insert `analyses` (face_shape, skin_tone, undertone, eye_shape, lip_shape, hair_color, eye_color, confidence_json, raw_ai_metadata, model metadata).
- **Status:** Working. Not billable as an AI Look (quota-limited only).

### 6.4 Makeup Style Selection
- **Entry:** `/styles` (`StyleSelectionPage`) after analysis (Standard mode) — 10 styles in `MakeupStyleCatalog`.
- **Status:** Working, static catalog.

### 6.5 Recommendation Mode Selection & Makeup Plan
- **Entry:** `/recommendation-mode` (Standard vs My Makeup Kit) → `/recommendation` (`MakeupRecommendationPage`) or `/makeup-kit/recommendation-entry`.
- **Backend:** `generate-makeup-recommendation` (`{analysisId, style}`) or `generate-kit-makeup-recommendation` → quota → Gemini text model (`makeup_recommendation_v3` / kit prompt) → insert `recommendations` / `kit_makeup_recommendations` (+ `look_product_snapshot_items` for kit).
- **UI:** plan sections + `AiLookAllowanceNotice` (remaining AI Looks) above the "Generate Final Preview" CTA.
- **Status:** Working. Not billable.

### 6.6 Final Makeup Preview (AI Look) — **billable**
- **Entry:** CTA on plan page → `/preview` (`PreviewResultPage`, uses `results/` widgets: before/after comparison, breakdown, palette, actions).
- **Backend:** `generate-makeup-preview` / `generate-kit-makeup-preview` (see §4.3). Model locked to `gemini-3.1-flash-image` (`_shared/final_preview_model.ts`).
- **DB:** `generated_images` / `kit_generated_images`, `usage_ledger` (reserve → commit).
- **Premium requirement:** **YES — an active entitlement with available AI Looks** (`reserve_ai_look`). No entitlement ⇒ HTTP 403 `ENTITLEMENT_NOT_FOUND`; exhausted ⇒ HTTP 402 `AI_LOOK_LIMIT_REACHED`.
- **Status:** Working when an entitlement exists; **effectively blocked for accounts with no entitlement** (see §26/§27). Client does not send `operationId` (server mints one) so a client-side retry is a new operation — idempotency across retries is not yet exercised (SUB-6 note in server code).
- **Variations:** "Try another" regenerates (each success = one more AI Look).

### 6.7 Step-by-Step Tutorial (V4)
- **Entry:** "Show me how" from preview/history → `/tutorial` with `TutorialPageArgs` (canonical preview ref + final preview URL).
- **Backend:** `analyze-tutorial-manifest-v4` (`{generatedImageId | kitGeneratedImageId}`) → Gemini `GEMINI_MANIFEST_MODEL` (default `gemini-3.6-flash`, `tutorial_manifest_v4_1`) → `tutorial_v4_sessions` + `tutorial_v4_manifest_items` (present/absent/uncertain per category). Then per category `generate-tutorial-step-v4` (`{tutorialSessionId, category}`) → Gemini `GEMINI_TUTORIAL_MODEL` (default `gemini-3.1-flash-image`, 1K, `tutorial_guideline_v4_7`, images A=original selfie, B=final preview) → guideline overlay image in `face-images/{uid}/analyses/{aid}/tutorials/{session}/{category}_####.ext` → `tutorial_v4_steps` (+ `tutorial_v4_step_products` for kit).
- **Categories (locked):** Foundation, Concealer, Contour & Bronzer, Blush, Highlighter, Eyebrows, Eyeshadow, Eyeliner, Lips.
- **Premium:** No — **tutorial never consumes an AI Look** (quota only).
- **Status:** Working, LOCKED (V4-QA-8). Kit mode refuses tutorial if the look uses categories not in the kit (`kitPreviewMismatch`).

### 6.8 My Makeup Kit
- **Entry:** Profile → "My Makeup Kit" → `/makeup-kit`, `/makeup-kit/add-product`, `/makeup-kit/product/:productId`.
- **Files:** `lib/features/makeup_kit/**` (23 test files), migrations `20260813*`, `20260814*`.
- **DB:** `makeup_kit_products` (category, finish, foundation depth/undertone…), `kit_makeup_recommendations`, `kit_generated_images`, `kit_saved_looks`, `look_product_snapshot_items` (immutable product snapshots).
- **Status:** Working, protected ("owned-products-only recommendation, server validation, immutable snapshot authority, no silent Standard fallback").

### 6.9 History
- **Entry:** bottom nav "History" `/history`; Home "Recent looks".
- **Backend:** reads `analyses` (+ joins) and kit records; filters (all/completed/favorites; type; sort; date groups); delete → `delete-history-item` Edge Function (removes every object under `{uid}/analyses/{analysisId}/` then deletes the analysis row; FK cascades).
- **Status:** Working. Note: deleting an analysis whose preview has a **committed** ledger row — the ledger FK is `on delete set null` for the preview id and a trigger permits that specific nulling; the committed usage remains (no refund by deletion). CONFIRMED in `subscription_foundation.sql`.

### 6.10 Saved Looks
- **Entry:** bottom nav "Saved" `/saved`; favorite action on results.
- **DB:** `saved_looks` (Standard), `kit_saved_looks` (Kit).
- **Status:** Working.

### 6.11 Profile
- **Entry:** bottom nav "Profile" `/profile`.
- **Features:** display name edit, avatar upload (`profile-avatars/{uid}/avatar.jpg`, JPEG ≤2 MiB), links to Saved/History/Kit, **SubscriptionSummaryCard** (hidden when no entitlement), **"Plans & Subscription"** row → `/subscription` (uncommitted change), Settings.
- **Status:** Working.

### 6.12 Settings
- **Entry:** `/settings` (gear on Home, Profile).
- **Features:** theme mode (system/light/dark persisted in `user_settings.theme_mode`), notification preference & analytics consent (stored flags only — no SDKs), image privacy info, "Privacy policy — Publication pending" (placeholder), About (version via `package_info_plus`), sign out (with guest warning).
- **Status:** Working; privacy policy is a placeholder.

### 6.13 Share
- `ResultShareService` → `share_plus` shares the generated image + style text. Not billable. Working.

### 6.14 Subscription / Paywall (SUB-6…SUB-9)
- **Entry:** Profile → "Plans & Subscription" → `/subscription` (`SubscriptionPage`). Also `AiLookAllowanceNotice` on plan page, `SubscriptionSummaryCard` on profile.
- **Frontend:** `SubscriptionController` (loads `resolve_subscription_state` RPC on sign-in), `PaywallController` (prices from Google Play via `GooglePlayPlanPriceSource`), `PurchaseController` (purchase lifecycle), `SubscriptionPlanCard` per plan (Plus, Pro, Salon Pro), disabled "Restore purchases" button.
- **Status:** UI working; **price loading and purchase depend on Play Console products** (`facetune_plus`, `facetune_pro`, `facetune_salon_pro`) and a Play-signed install. If store unavailable → notice "Purchasing is not available yet". Purchase → verification currently fails externally (503 "Purchase verification is temporarily unavailable.") and the purchase is deliberately left unacknowledged (Google auto-refunds in 3 days).

### 6.15 Router error page
- `errorBuilder` shows "Page unavailable" with Return Home. Working.

---

## 7. User Journey

**App launch:** `main()` → `bootstrap()` → `Supabase.initialize(url, publishableKey)` (from `--dart-define-from-file`) → `ProviderScope` → `FaceTuneApp` → `GoRouter` initial `/`. If Supabase config is missing/invalid, `AuthState.configurationMissing` and the auth page shows the configuration message (repositories swap to `Unavailable*` implementations).

**New user:** `/auth` → "Create an account" (`/auth/register`) → email confirmation (if enabled on dashboard) or immediate session → profile bootstrap → `/` Home ("Welcome back, {name}", empty Recent looks) → Start scan → `/scan` (live camera or gallery) → `/analysis` Beauty Profile → "Choose a makeup style" → `/styles` → `/recommendation-mode` → `/recommendation` (plan + allowance notice) → "Generate Final Preview" → `/preview` (before/after, breakdown, palette, favorite/share/try another/show me how) → `/tutorial`.
  - **With current backend state and no entitlement:** the Final Preview call fails with 403 and the message "The original selfie or makeup plan is no longer available." (misleading). The allowance notice is hidden because `hasEntitlement=false`.

**Existing user:** persisted session (supabase_flutter local storage) → `initialSession` event → authenticated → Home with recent looks; history/saved looks reopen previews without charge.

**Free user (intended, once SUB-12 exists):** Free plan, 1 complimentary AI Look, never replenishes; exhausted state "You have used your complimentary AI Look — Upgrade to create more AI Looks."

**Premium user (Plus 3 / Pro 8 / Salon Pro 35 per month):** allowance notice shows "N of M AI Looks remaining", reset date = `period_end`; exhausted → warning + upgrade prompt; expired/suspended/revoked → blocked copy.

**Failed authentication:** `AuthErrorMapper` → `errorMessage` + `feedbackId` → `AuthFeedbackListener` snackbar; session expiry anywhere → "Sign in again" actions call `recoverExpiredSession()` (clears local state even if remote sign-out fails).

**Failed processing:** each remote repository maps HTTP status/code → typed failure (`AnalysisFailure`, `PreviewFailure`, `TutorialFailure` …) with `retryable`; pages show `StatusState.error` with retry; preview keeps `previousPreview` for "View previous result".

**Subscription purchase:** see §4.3 and §15. Phases: idle → starting → awaitingPayment (pending) → verifying → verified | cancelled | failed.

**Subscription restore:** **Not implemented** (button disabled; SUB-11). A `PurchaseStatus.restored` event from Play would be verified like a purchase.

**Logout:** Settings → Sign out (guest warning dialog) → `signOut()` → router redirects to `/auth`; `SubscriptionController.markSignedOut()`.

---

## 8. UI/UX Architecture

**Design system (CONFIRMED `lib/theme/`, `lib/shared/widgets/`):**
- **Tokens:** `AppColors` (rose `#A94E6B`, roseDark, blush, petal, ivory `#FFFBF8`, sand, cocoa `#2E2225`, taupe, gold `#B58A52`, success, error, darkSurface `#1A1517`, darkCard; dark-mode `onTint` mapping), `AppSpacing` (4/8/12/16/24/32/48, gutter 20), `AppRadii` (12/18/24/32/pill), `AppElevation`, `AppBorders`, `AppIconSizes`, `AppDurations`, `AppCurves`.
- **Semantics:** `AppSemantics` ThemeExtension with `AppTone` (info/success/warning/error) roles; contrast-audited (`test/qa/dark_mode_contrast_test.dart`).
- **Typography:** `AppTypography` — system font (`fontFamily = null`), Material text theme.
- **Theme:** `AppTheme.lightTheme` / `darkTheme`, Material 3, `themeMode` from `user_settings`.
- **Icons:** Material `Icons.*_rounded/_outlined`.
- **Components:** `AppShell` (NavigationBar: Home, Saved, History, Profile), `PageFrame` / `PageFrame.scrolling`, `FaceTuneTopBar`, `FaceTuneBackButton`, `PrimaryButton`/`SecondaryButton`/`TertiaryButton` (+ `ButtonProgress`), `AppCard`, `AppNotice`, `StatusState` (error/empty), `LoadingState`, `SkeletonCard`, `FinalPreviewLoadingView`, `MakeupPlanLoadingView`, `PrivateImage` (signed-URL image with skeleton/unavailable states), `BeautyImage`, `AppColorSwatch`, `SectionHeader`, `DetailRow`, `LookCardMetadata`, `TopLevelPageHeader`/`HomeGreetingHeader`, `AppOverlays` (dialogs/snackbars).
- **Navigation transitions:** `app_navigation_transitions.dart` — `buildJourneyPage` for journey routes; `NoTransitionPage` within shell branches.
- **Responsive:** widget QA matrices (`test/qa/responsive_layout_test.dart`, `full_app_matrix_test.dart`), text-scale-aware sizing on Home cards.
- **Premium UI:** `SubscriptionPlanCard`, `SubscriptionSummaryCard`, `AiLookAllowanceNotice` — consistent with the design system.
- **Error/empty states:** unified via `StatusState`, `AppNotice`.

**Consistency:** Global consistency is high; two UI productionization tracks (UI_P0…P7, TUT_UI, HISTORY_UI) locked it.
**Placeholders / temporary UI:** Settings "Privacy policy — Publication pending"; paywall "Restore purchases" disabled; paywall "Purchasing is not available yet" notice when store absent; `AppConstants.placeholderTitle/Message` ("Coming soon") constants exist but no route uses them (dead constants). `AppConfig.debugShowCheckedModeBanner` is false and not env-driven. No development-only UI found.

---

## 9. Authentication System

**CONFIRMED** (`lib/features/authentication/`):
- **Signup:** `auth.signUp(email, password, data:{display_name}, emailRedirectTo: io.facetune.app://login-callback/)`; if no session returned → "Check your email to confirm…".
- **Login:** `signInWithPassword` (20 s timeout) → `bootstrapProfile` (upsert `profiles`, `user_settings`, `ignoreDuplicates`).
- **Google OAuth:** `signInWithOAuth(OAuthProvider.google, redirectTo: io.facetune.app://login-callback/)` → browser → deep link (Android intent-filter scheme `io.facetune.app`, iOS URL type). Requires dashboard redirect URLs `io.facetune.app://login-callback/**`, `io.facetune.app://reset-callback/**` (NEEDS VERIFICATION).
- **Guest:** `signInAnonymously(data:{account_type:'guest'})` — requires Anonymous Sign-Ins enabled (NEEDS VERIFICATION).
- **Password reset:** `resetPasswordForEmail(redirectTo reset-callback)` → `passwordRecovery` event → forced `/auth/reset-password` → `updateUser(password)`.
- **Validation:** email regex, name ≤80, password ≥8 with letter+digit.
- **Session persistence:** supabase_flutter default (local storage, auto refresh). Token handling is entirely inside the SDK; Edge Functions receive the JWT via `functions.invoke` automatically.
- **State:** `AuthState{status: unauthenticated|authenticated|passwordRecovery|configurationMissing, user, activeOperation, errorMessage, notice, feedbackId}`; generation counter prevents stale event races.
- **Protected routes:** everything except the 6 auth routes; redirect in `appRouterProvider`.
- **Failure handling:** `AuthErrorMapper` maps `AuthException`/timeouts/sockets to friendly messages; stream errors → "We could not refresh your session."

**Security notes:** No auth bypass found. Guest accounts can farm AI quota (documented residual risk). Email confirmation / CAPTCHA / leaked-password protection are dashboard settings (NEEDS VERIFICATION).

---

## 10. Gemini / AI Architecture

**Where:** exclusively in `supabase/functions/*/gemini_client.ts`. **No Gemini code or key exists in Flutter** (CONFIRMED; enforced by SOT and tests).

| Function | Model (env → default) | Prompt version | Endpoint | Timeout / retries |
| --- | --- | --- | --- | --- |
| `analyze-face` | `GEMINI_MODEL` → `gemini-3.6-flash` | `face_analysis_v2` | `v1beta/models/{m}:generateContent` | AbortSignal timeout, 2 attempts, backoff 400 ms×n |
| `generate-makeup-recommendation` | `GEMINI_MODEL` → `gemini-3.6-flash` | `makeup_recommendation_v3` | v1beta | same pattern |
| `generate-kit-makeup-recommendation` | `GEMINI_MODEL` → `gemini-3.6-flash` | kit prompt v? (`prompt.ts`) | v1beta | 45 s, 2 attempts |
| `generate-makeup-preview` | **LOCKED** `gemini-3.1-flash-image` (`GEMINI_IMAGE_MODEL` only validates) | `makeup_preview_v2` | v1beta | 90 s/attempt, 2 attempts, 135 s total |
| `generate-kit-makeup-preview` | **LOCKED** `gemini-3.1-flash-image` | `kit_makeup_preview_v1` | **`v1`** (inconsistent with the others — INFERRED harmless, NEEDS VERIFICATION) | 90 s, 2 attempts, budget |
| `analyze-tutorial-manifest-v4` | `GEMINI_MANIFEST_MODEL` → `gemini-3.6-flash` | `tutorial_manifest_v4_1` | v1beta | 2 attempts |
| `generate-tutorial-step-v4` | `GEMINI_TUTORIAL_MODEL` → `gemini-3.1-flash-image`, 1K | `tutorial_guideline_v4_7` | v1beta | 90 s, 2 attempts, lock 120 s, ≤5 step attempts |

- **Auth to Gemini:** header `x-goog-api-key: GEMINI_API_KEY` (server secret).
- **Image input:** base64 inline image bytes (original selfie; tutorial adds the final preview as image B). **Output:** `candidates[0].content.parts[].inlineData` → validated (`image_validation.ts`), must differ from input, uploaded to Storage.
- **Usage limits:** two layers — `consume_ai_quota(operation)` (hourly/daily per account, limits fixed in SQL, HTTP 429 `rate_limited`) and, for previews only, the AI Look ledger.
- **Error handling:** `FunctionFailure{status, code, message, retryable}`; Gemini codes surfaced as `GEMINI_TIMEOUT`, `GEMINI_NO_IMAGE_OUTPUT`, `UNCHANGED_GENERATED_IMAGE`; client maps to `PreviewFailureType.gemini`.
- **Config lock:** `_shared/final_preview_model.ts` fails closed if `GEMINI_IMAGE_MODEL` is set to anything other than `gemini-3.1-flash-image`.
- **Dependency map:** Gemini-dependent: analysis, recommendation (both modes), preview (both modes), tutorial manifest, tutorial steps. Gemini-independent: auth, scan/live scan, history, saved looks, profile, settings, subscription/billing, share, delete.
- **Security risks:** key is server-only (good). Risk is cost: quota is per account and guests are unlimited; Google-side budget cap recommended (`docs/SECURITY_HARDENING.md`).

---

## 11. Supabase Architecture

- **Init:** `SupabaseInitializer.initialize(SupabaseConfig.fromEnvironment())` — validates `https://*.supabase.co` URL and `sb_publishable_` key; result exposed via `supabaseInitializationProvider` / `supabaseAvailableProvider`; every repository provider swaps to an `Unavailable*` stub when not ready.
- **Client provider:** `supabaseClientProvider` → `Supabase.instance.client`.
- **Auth:** §9.
- **Database access from Flutter (all RLS-scoped):** `profiles`, `user_settings`, `analyses`, `saved_looks`, `kit_saved_looks`, `kit_generated_images`, `makeup_kit_products`, `tutorial_v4_sessions`, `tutorial_v4_manifest_items`, `tutorial_v4_steps` (upsert), RPC `resolve_subscription_state`.
- **Storage from Flutter:** `face-images` upload (originals) + signed URLs (3600 s); `profile-avatars` upload + signed URL.
- **Edge Functions invoked from Flutter:** `analyze-face`, `generate-makeup-recommendation`, `generate-makeup-preview`, `generate-kit-makeup-recommendation`, `generate-kit-makeup-preview`, `analyze-tutorial-manifest-v4`, `generate-tutorial-step-v4`, `delete-history-item`, `verify-google-play-purchase`.
- **RPCs (SQL functions):** `consume_ai_quota(text)`, `purge_ai_usage_events()`, `resolve_subscription_state()`, `reserve_ai_look(uuid)`, `commit_ai_look(uuid,text,uuid)`, `release_ai_look(uuid,text)`, `reconcile_stale_ai_look_reservations(interval)` (not granted to `authenticated`; needs pg_cron — NEEDS VERIFICATION), `activate_verified_google_play_subscription(...)` (service_role only), `persist_tutorial_v*` helpers.
- **config.toml:** `verify_jwt = true` for the 8 older functions; `verify-google-play-purchase` is **not listed** (CLI default applies; function validates JWT itself anyway).
- **Deployment state:** whether all 27 migrations and all 9 functions are deployed to `usmlwaocafeqnspdsvmv` is **UNKNOWN / NEEDS VERIFICATION** (`supabase migration list`, dashboard).

---

## 12. Database Model

All tables: `user_id` (or `auth_user_id`) FK → `auth.users` on delete cascade, `created_at/updated_at` with `set_updated_at` trigger, RLS enabled, owner-only policies (`auth.uid() = user_id`), composite ownership FKs `(id, user_id)` to prevent cross-owner links. **CONFIRMED FROM MIGRATIONS** (live schema may differ — NEEDS VERIFICATION).

| Table | Purpose | Key columns | Written by |
| --- | --- | --- | --- |
| `profiles` | display name, avatar path | `auth_user_id` (unique), `display_name`, `avatar_path` | trigger, client |
| `user_settings` | preferences | `theme_mode`, `dark_mode` (legacy), `notifications_enabled`, `analytics_consent` | trigger, client |
| `analyses` | one scan | `original_image_path`, face attributes, `confidence_json`, `raw_ai_metadata`, model metadata | `analyze-face` |
| `recommendations` | Standard makeup plan | `analysis_id`, `makeup_style`, `recommendation_json`, `model_name`, `prompt_version` | `generate-makeup-recommendation` |
| `generated_images` | Standard Final Preview | `analysis_id`, `recommendation_id`, `storage_path` (unique), `generation_number`, `model_name`, `prompt_version` | `generate-makeup-preview` |
| `saved_looks` | favorites (Standard) | `generated_image_id` (unique), `is_favorite` | client |
| `ai_usage_events` | quota events | operation, timestamps | `consume_ai_quota` (select-only for users) |
| `makeup_kit_products` | owned products | category, finish, shade, foundation depth/undertone … | client |
| `kit_makeup_recommendations` | Kit plan | analysis, product snapshot linkage | `generate-kit-makeup-recommendation` |
| `look_product_snapshot_items` | immutable product snapshot per look | insert-once | edge function |
| `kit_generated_images` | Kit Final Preview | as `generated_images` | `generate-kit-makeup-preview` |
| `kit_saved_looks` | Kit favorites | | client |
| `tutorial_sessions`, `tutorial_steps`, `tutorial_v2_*`, `tutorial_v3_*` | **legacy** tutorial versions (superseded, tables remain) | | not used by current client (INFERRED) |
| `tutorial_v4_sessions` | one tutorial per canonical preview | `canonical_generated_image_id` / `canonical_kit_generated_image_id`, `source_mode` | client + functions |
| `tutorial_v4_manifest_items` | present/absent/uncertain per category | | `analyze-tutorial-manifest-v4` |
| `tutorial_v4_steps` | guideline image per category | `guideline_storage_path`, attempt, status | `generate-tutorial-step-v4`, client upsert |
| `tutorial_v4_step_products` | kit products per step | | function |
| `subscription_products` | plan catalog (seeded: free, plus, pro, salon_pro, salon_pilot) | `plan_code`, `publicly_purchasable`, `billing_provider`, `provider_product_id`, `billing_interval`, `base_ai_look_allowance`, `reset_policy`, `active` | migrations only |
| `user_entitlements` | what an account has | `plan_code`, `status` (pending/active/grace_period/expired/suspended/revoked), `billing_provider`, `provider_product_id`, `provider_subscription_reference` (sha-256 of token, unique), `period_start/end`, `starts_at`, `expires_at`, `auto_renew`, `base_ai_look_allowance`, `allowance_adjustment_total`, `version`, `verified_at`; unique partial index: one active/grace row per user | `activate_verified_google_play_subscription` only |
| `usage_ledger` | AI Look transactions | `entitlement_id`, `operation_id` (unique), `status` reserved/committed/released, `source_mode`, `canonical_generated_image_id` / `canonical_kit_generated_image_id` (unique), `period_*`, `sanitized_failure_code`; committed rows immutable (trigger) | reserve/commit/release functions |
| `provider_purchase_verifications` | audit + replay/theft detection | `purchase_reference` (unique sha-256), `linked_purchase_reference`, `subscription_state`, `test_purchase`, `entitlement_id` | activation function |

Storage buckets: `face-images` (private; JPEG/PNG/WebP ≤10 MiB; path `{uid}/analyses/{analysisId}/original|generated|tutorials/...`), `profile-avatars` (private; JPEG ≤2 MiB; `{uid}/avatar.jpg`).

---

## 13. Image Processing Flow

1. **Capture/pick** (`DeviceSelfieRepository`): copy original → compress to JPEG (max 2048 px, q88, EXIF stripped) in app temp dir `facetune/selfies/`.
2. **Local validation** (`FlutterImageValidationRepository`, `SelfieFileValidator`): magic-byte/mime, size, dimensions, aspect ratio.
3. **Upload** (`SupabaseAnalysisRemoteDataSource.uploadSelfie`): `face-images/{uid}/analyses/{analysisId}/original/{imageId}.jpg`, `upsert:false`.
4. **Analysis** (`analyze-face`): validates the client's `localValidation` claims against the stored object, checks ownership path (`_shared/storage_ownership.ts`), Gemini → `analyses`.
5. **Preview** (§4.3): server downloads the original, Gemini renders, `image_validation.ts` validates output mime/size, identity check, upload under `generated/`, row insert.
6. **Display**: `PrivateImage` loads signed URLs (1 h) with skeleton/unavailable states.
7. **Tutorial**: server resolves the canonical preview (`_shared/tutorial_source_resolver.ts`), sends original + preview to Gemini, stores overlays under `tutorials/`.
8. **Deletion**: `delete-history-item` lists and removes all objects under the analysis prefix (batches of 100, cap 10 000), then deletes the row.

---

## 14. Premium / Subscription Architecture

**Plans (locked, CONFIRMED in catalog + SQL seed + SOT):**

| Plan code | Display | Price (SOT, PHP) | AI Looks | Reset | Purchasable | Provider |
| --- | --- | --- | --- | --- | --- | --- |
| `free` | FaceTune Free | 0 | 1 one-time | none | no | none |
| `plus` | FaceTune Plus | 399/mo | 3 | billing period | yes | google_play `facetune_plus` |
| `pro` | FaceTune Pro | 899/mo | 8 | billing period | yes | google_play `facetune_pro` |
| `salon_pro` | Salon Pro | 2,999/mo | 35 | billing period | yes | google_play `facetune_salon_pro` |
| `salon_pilot` | Salon Pilot | complimentary | 30 (admin-editable) | none, `expires_at` required | no | admin_granted |

Prices are **never** hardcoded in runtime UI; the paywall shows Google Play's localized price string.

**AI Look definition:** 1 successfully generated **and persisted** Final Makeup Preview (Standard or Kit). Tutorial, reopen, history, share, analysis, recommendation never consume one.

**Entitlement resolution (`resolve_subscription_state`, SQL):** picks the best row (active > grace > suspended > pending > expired > revoked), computes `effectiveAllowance = base + adjustment`, counts committed/reserved ledger rows since `period_start`, returns `generationAuthorized` + `denialReason` (`ENTITLEMENT_NOT_FOUND`, `ENTITLEMENT_PENDING`, `ENTITLEMENT_EXPIRED`, `SALON_PILOT_EXPIRED`, `ENTITLEMENT_SUSPENDED`, `ENTITLEMENT_REVOKED`, `ENTITLEMENT_INACTIVE`, `AI_LOOK_LIMIT_REACHED`). **No entitlement row ⇒ `hasEntitlement=false`, `planCode='free'`, `effectiveAllowance=0`, denied.**

**Usage engine:** `reserve_ai_look` (advisory lock per user, idempotent on `operation_id`, replays existing state), `commit_ai_look` (binds canonical preview, refuses double billing), `release_ai_look` (only from reserved; never releases committed), `reconcile_stale_ai_look_reservations(interval)` (commits from persisted evidence or releases; needs scheduling — NEEDS VERIFICATION).

**Flutter side:**
- `SubscriptionController` → `resolve_subscription_state` on sign-in / after purchase; state cached; session failures clear it.
- `AiLookAllowanceCopy` renders remaining/exhausted/blocked copy; hidden when `hasEntitlement=false`.
- **No client-side gate** before invoking preview generation; the server is the gate. **Gap:** `SupabaseMakeupPreviewRepository` maps 403 → "original selfie or makeup plan is no longer available" and 402 → generic server error; the `AI_LOOK_LIMIT_REACHED` / `ENTITLEMENT_*` codes are not surfaced with upgrade guidance (SUB-7 presentation not wired into the preview failure path). CONFIRMED.
- Client does not send `operationId` (server mints; SUB-6 note).

**Dev/mock premium modes:** none exist (CONFIRMED — tests forbid local plan grants). Fakes exist only in `test/helpers/fake_billing.dart`.

**Edge Functions involved:** `generate-makeup-preview`, `generate-kit-makeup-preview` (enforcement), `verify-google-play-purchase` (activation).

---

## 15. Google Play Billing Integration

**Client (SUB-9, uncommitted, CONFIRMED):**
- `GooglePlayBillingDataSource` wraps `InAppPurchase.instance` (isAvailable, queryProductDetails, purchaseStream, buyNonConsumable, completePurchase).
- `GooglePlayBillingGateway` maps `PurchaseDetails` → `PurchaseUpdate{pending|purchased|restored|cancelled|failed, evidence{productId, purchaseToken=serverVerificationData}, awaitingCompletion}`; picks the offer with fewest pricing phases; builds `PlanPrice{formattedPrice, currencyCode, billingPeriodLabel}`; `startPurchase` re-queries product details and passes `offerToken` + `applicationUserName = Supabase user id` (becomes `obfuscatedExternalAccountId`).
- `PurchaseController`: verified-before-acknowledge ordering enforced (test checks source order). On verification failure the purchase is **not** completed (Google refunds unacknowledged purchases after 3 days).
- Product IDs live only in `StoreProductCatalog`.
- Android: no manual BillingClient dependency, `BILLING` permission merged from the AAR; `key.properties` + Play-signed build required for real store availability.

**Server (SUB-10, uncommitted, CONFIRMED):** `verify-google-play-purchase` (§4.3, §16). Google Play Developer API v3: `purchases.subscriptionsv2.get` (read) and `purchases.subscriptions.acknowledge` (v1-style acknowledge, still current).

**Play Console requirements (from `docs/GOOGLE_PLAY_BILLING_SETUP.md`; done-state per user's context, not verifiable from repo):** three monthly subscriptions with the exact product IDs; service account invited under Users & permissions with *View financial data* + *Manage orders and subscriptions* on the FaceTune app; Android Developer API enabled in the Cloud project; license testers; internal testing track upload. **Note:** the setup doc's header "Nothing here has been done yet" is stale relative to the user's reported state.

**Not built:** renewal/cancel/grace/hold/refund reconciliation, RTDN (Pub/Sub), restore purchases, Free provisioning.

---

## 16. Current Google Play 401/403 Problem

### Known symptoms (from user context; not reproducible from the repo)
- OAuth JWT-bearer exchange: **HTTP 200**.
- `monetization.subscriptions.list` for `io.facetune.app`: **403 PERMISSION_DENIED "The caller does not have permission"**.
- `purchases.subscriptionsv2.get` with a fake token: **401 "The current user has insufficient permissions to perform the requested operation."** (a bogus token should yield 400/404 once authorized).
- Persisting for days; Google support contacted; Cloud API confirmed ENABLED; Play Console SA status ACTIVE with app-level permissions.

### CODE-SIDE FINDINGS (CONFIRMED from `supabase/functions/verify-google-play-purchase/google_play_api.ts`)
| Item | Implementation | Assessment |
| --- | --- | --- |
| Credential source | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` (env) → `client_email`, `private_key` | Correct; nothing else read |
| JWT header | `{alg:"RS256", typ:"JWT"}` | Correct |
| JWT claims | `iss=client_email`, `scope=https://www.googleapis.com/auth/androidpublisher`, `aud=https://oauth2.googleapis.com/token`, `iat`, `exp=iat+3600` | Correct; no `sub` (correct — no domain-wide delegation) |
| Signing | WebCrypto `RSASSA-PKCS1-v1_5`/SHA-256 over PKCS#8 PEM | Correct; tests sign with a real generated key |
| Token exchange | POST form `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=…` | Correct; token cached per isolate with 60 s margin |
| Package name | `GOOGLE_PLAY_PACKAGE_NAME` env, URL-encoded into path | Correct if secret equals `io.facetune.app` (NEEDS VERIFICATION of the secret value) |
| Read endpoint | `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{pkg}/purchases/subscriptionsv2/tokens/{token}` | Correct (no productId needed for v2) |
| Ack endpoint | `POST …/applications/{pkg}/purchases/subscriptions/{productId}/tokens/{token}:acknowledge` body `{}` | Correct |
| Product / plan | from provider `lineItems[].productId` ∩ approved set; client claim discarded | Correct |
| Purchase token | request body `purchaseToken` (regex `^[A-Za-z0-9._~-]{1,1024}$`), sha-256 stored | Correct |
| Error logging | 401/403 from Google → collapsed to `503 TEMPORARY_BACKEND_FAILURE`; **the HTTP status and Google error body are neither logged nor returned** | Deliberate for secrecy, but it means the function itself yields **zero diagnostics**; the 401/403 facts came from external probes. Future improvement (not now): log `status=` only. |
| `config.toml` | function not listed | Default `verify_jwt` applies; harmless because the function verifies the JWT itself |

**Conclusion (code side):** No defect found in JWT generation, scope, token exchange, endpoint construction, or parameter supply. The Deno unit tests (`google_play_api_test.ts`, 11 tests; `verification_test.ts`, 30+ tests) cover URL shape, RS256 assertion, status mapping, and ordering.

### GOOGLE-CONSOLE / EXTERNAL CONFIGURATION FINDINGS
Nothing external is verifiable from the repository. The following are **INFERRED** hypotheses consistent with the symptom pattern "token OK, every Play API call denied", ordered by how often they explain exactly this:

1. **Service-account ↔ Play Console linkage not effective for this app** despite showing ACTIVE — e.g. the invitation was accepted but app-level permissions were saved on a different app entry, or the invited e-mail differs from the credential's `client_email` by one character (the project id has *five* t's; a typo in the invited address would show a valid-looking but different user). Compare the exact `client_email` inside the JSON secret with the Play Console user list.
2. **Propagation delay after granting/changing permissions** (Google documents up to 24 h; community reports up to 48 h). A common accelerator is to make any edit-and-save on the app's in-app products or the user's permissions to force a refresh.
3. **App has never had a build published to any track** (even Internal testing). Several Play API methods return permission errors for apps without a first release/for products not yet active. The AAB in `build/` (2026-09-10) suggests one was built; whether it was uploaded and *rolled out* is UNKNOWN.
4. **Play Console "API access" page linked to a different Cloud project** than `skurttttt-project`. The API must be enabled in the project that owns the service account (confirmed by user), and the service account must be visible/granted in Play Console; if Play Console is linked to another project, re-check the linkage page.
5. **Wrong developer account** — the service account was granted on a different Play developer account than the one that owns `io.facetune.app`.
6. **Key rotation mismatch** — the JSON secret in Supabase belongs to a deleted/disabled key or to a different service account than the one invited (a token still mints for any valid key). Verify `client_email` + `private_key_id` of the deployed secret vs Cloud Console keys.
7. **`monetization.subscriptions.list` 403 specifically** can also require *View app information* and product read rights; the SA has only two app-level permissions. This would not explain the 401 on `subscriptionsv2.get`, so it is secondary.

**What has already been eliminated (per user's forensic prompt):** OAuth exchange, correct SA/project identity, API enablement, SA ACTIVE in Play Console, app access present, both app-level permissions, Flutter, Supabase, AAB.

**What the next AI must NOT repeat:** re-verifying OAuth; re-enabling the API; rewriting the JWT code; adding account-level financial permission "just to try" (explicitly forbidden by the user); acknowledging or making real purchases; touching SUB-11.

**Useful next diagnostic (read-only, not yet in repo):** call `edits.insert`/`applications.get`-style low-privilege endpoints, or `inappproducts.list`, with the same token to triangulate whether *any* Play API call succeeds for this package; compare against a different app in the same developer account if one exists.

---

## 17. Environment Variables

**No secret values are printed.** `config/development.json` exists locally (git-ignored) with real values; `config/example.json` is the template.

| Variable | Used by | Purpose | Side | Required | Sensitivity | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `SUPABASE_URL` | Flutter (`String.fromEnvironment`), all Edge Functions | Project API URL | client + server | yes | low (public) | present in dev config; platform-injected in functions |
| `SUPABASE_PUBLISHABLE_KEY` | Flutter | anon/publishable key (`sb_publishable_*` enforced) | client | yes | low (public) | present in dev config |
| `SUPABASE_ANON_KEY` | Edge Functions | user-scoped client | server | yes | low | platform-injected |
| `SUPABASE_SERVICE_ROLE_KEY` | `verify-google-play-purchase` only | activation RPC | server | yes (for SUB-10) | **CRITICAL** | platform-injected |
| `GEMINI_API_KEY` | 7 AI functions | Gemini auth | server | yes | **HIGH** | NEEDS VERIFICATION |
| `GEMINI_MODEL` | analyze-face, both recommendation functions | text model override | server | optional (default `gemini-3.6-flash`) | low | UNKNOWN |
| `GEMINI_IMAGE_MODEL` | both preview functions (validator only) | must be unset or exactly `gemini-3.1-flash-image`, else fail-closed | server | optional | low | UNKNOWN |
| `GEMINI_MANIFEST_MODEL` | analyze-tutorial-manifest-v4 | override (default `gemini-3.6-flash`) | server | optional | low | UNKNOWN |
| `GEMINI_TUTORIAL_MODEL` | generate-tutorial-step-v4 | override (default `gemini-3.1-flash-image`) | server | optional | low | UNKNOWN |
| `GOOGLE_PLAY_PACKAGE_NAME` | verify-google-play-purchase | `io.facetune.app` | server | yes | low | NEEDS VERIFICATION |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | verify-google-play-purchase | SA credential JSON | server | yes | **CRITICAL** | NEEDS VERIFICATION (which key/email) |
| `android/key.properties`: `storeFile`, `storePassword`, `keyAlias`, `keyPassword` | Gradle release signing | upload keystore | build | for release | **HIGH** | present locally, git-ignored, **polluted** (see §22) |
| `android/local.properties`: `sdk.dir`, `flutter.sdk` | Gradle | SDK paths | build | yes | low | present |

**SECURITY WARNING:** `NOTES.md` line 1 contains a plaintext credential labelled `SUPABASE PW:` (tracked, committed `2c728fe`, on `origin`). Treat as compromised; rotate the database password in the Supabase dashboard and rewrite history/remove the line.

---

## 18. External APIs and Services

| Service | Purpose | Where used | Auth | Files | Failure impact | Config |
| --- | --- | --- | --- | --- | --- | --- |
| Supabase Auth | identity | Flutter, functions (`auth.getUser`) | publishable key + JWT | `features/authentication`, every function | app unusable | dashboard providers, redirect URLs |
| Supabase Postgres | all data | Flutter (RLS), functions, SQL RPCs | JWT / service_role (1 fn) | migrations | app unusable | `supabase db push` |
| Supabase Storage | images | Flutter, functions | JWT | `face-images`, `profile-avatars` | no images | bucket migrations |
| Supabase Edge Functions | AI + delete + verify | Flutter `functions.invoke` | JWT | `supabase/functions/*` | AI/billing unusable | `supabase functions deploy`, secrets |
| Google Gemini | analysis, plans, image render | 7 functions | `x-goog-api-key` | `*/gemini_client.ts` | AI journey stops | `GEMINI_API_KEY`, billing budget |
| Google Play Billing (device) | products, purchase | Flutter | Play services / signed app | `google_play_billing_*` | paywall shows unavailable | Play Console products, testers |
| Google Play Developer API | purchase verify + ack | `verify-google-play-purchase` | SA OAuth (`androidpublisher` scope) | `google_play_api.ts` | purchases cannot be verified (**current blocker**) | SA, Play Console permissions, Cloud API |
| Google OAuth (sign-in) | social login | Flutter via Supabase | Supabase-managed | `auth_remote_data_source.dart` | Google login unavailable | Supabase provider config |
| Android share sheet | share results | `share_plus` | — | `results/` | share unavailable | — |
| Analytics / crash reporting | **none integrated** (flags stored only) | — | — | — | — | — |

---

## 19. Data Flows

1. **Authentication:** credentials → Supabase Auth → session (JWT + refresh) persisted on device → `AuthController` state → router → `ensureProfile` upserts → `SubscriptionController.load()`.
2. **Image upload:** device file → compressed temp JPEG → Storage `face-images/{uid}/analyses/{id}/original/…` → path stored in `analyses.original_image_path`.
3. **Image processing:** function downloads original by path (RLS), validates ownership prefix, sends bytes to Gemini, validates result, uploads to `generated/`, inserts row; originals are never overwritten.
4. **AI request:** Flutter → `functions.invoke(name, body)` with JWT → function → quota RPC → Gemini REST.
5. **AI result:** row + storage path → Flutter DTO → signed URL (1 h) → `PrivateImage`.
6. **Saving user data:** direct table writes under RLS (`saved_looks`, `kit_*`, `profiles`, `user_settings`, `makeup_kit_products`, `tutorial_v4_steps`).
7. **Premium check:** Flutter `resolve_subscription_state` (display only) ⟂ server `reserve_ai_look` inside preview functions (authoritative).
8. **Google Play purchase:** paywall → Play Billing → `PurchaseDetails` (token) → in-memory `PurchaseEvidence` (never logged; `toString` redacts).
9. **Purchase verification:** token → function → Google API → `interpretPurchase` → sha-256 → `activate_verified_google_play_subscription` → `user_entitlements`, `provider_purchase_verifications` → ack → `resolve_subscription_state` → Flutter refresh.
10. **App initialization:** `bootstrap()` → `Supabase.initialize` → providers → `GoRouter` → auth redirect → Home loads history + profile + subscription.

---

## 20. Deployment Architecture

- **Client:** Android APK/AAB built locally; distribution via Google Play (Internal testing / production) — no CI. Dart-defines injected at build time from `config/*.json`.
- **Backend:** Supabase hosted project `usmlwaocafeqnspdsvmv`; migrations via `supabase db push`; functions via `supabase functions deploy`; secrets via `supabase secrets set`.
- **GitHub:** remote `origin` with branches listed in §23; no workflows.
- **Deno tests:** `supabase/functions/deno.json` (`nodeModulesDir: auto`, strict); run with `deno test` inside `supabase/functions` — exact invocation NEEDS VERIFICATION (a `node_modules/` directory exists there, git-ignored).
- **Android ↔ Play:** applicationId `io.facetune.app`; release signing from `android/key.properties` (upload keystore path inside it — location on disk NEEDS VERIFICATION); R8 enabled with `proguard-rules.pro`; `versionName 1.0.0`, `versionCode` from `pubspec` (`1.0.0+1`) but `android/gradle.properties` also sets `flutter.versionCode=4` (INFERRED: the last AAB was built as versionCode 4 — confirm which wins for your next upload).

---

## 21. Android Configuration

- `android/app/build.gradle.kts`: namespace/applicationId `io.facetune.app`, Java 17, release signing fallback to debug with warning, minify + shrink.
- `AndroidManifest.xml`: permissions `INTERNET`, `CAMERA`; `usesCleartextTraffic=false`; launcher activity `singleTop`, deep-link intent filter scheme `io.facetune.app`.
- Gradle: AGP 8.11.1, Kotlin 2.2.20, `org.gradle.jvmargs=-Xmx8G`.
- `android/.gitignore` ignores `key.properties`, `*.jks`, `*.keystore`, `local.properties`.
- `android/key.properties.example` documents keystore creation.
- Play Billing Library 8.0.0 arrives via `in_app_purchase_android` 0.5.0 (pinned; 0.5.0+1 needs Dart 3.12).
- Build outputs present locally: `app-release.aab` (2026-09-10), split release APKs (2026-09-04), debug/profile APKs.

---

## 22. Security Assessment

| Rank | Finding | Location | Notes |
| --- | --- | --- | --- |
| **CRITICAL** | Plaintext credential committed: `SUPABASE PW: …` | `NOTES.md` line 1 (commit `2c728fe`, pushed) | Rotate DB password; purge from history (`git filter-repo`) and force-push after coordinating; value not reproduced here. |
| **HIGH** | `android/key.properties` (git-ignored) contains signing passwords **and 1,223 lines of pasted prompt text** (`401 and 403 PROMPT.yaml` content appended, mtime 2026-09-14) | `android/key.properties` | Java `Properties` will parse extra lines as junk keys; may break or silently alter release signing. Clean the file back to 4 lines. Confirm the file is never committed (it is ignored — CONFIRMED). |
| **HIGH (product)** | No Free entitlement provisioning; new accounts denied all Final Previews with a misleading client message | `resolve_subscription_state`, `reserve_ai_look`, `supabase_makeup_preview_repository.dart` | If migrations are live, onboarding is broken. SUB-12 + client 402/403 mapping needed. |
| MEDIUM | Guest (anonymous) accounts unlimited → AI quota farming | Auth config | Enable CAPTCHA/rate limits on dashboard; Gemini budget cap. |
| MEDIUM | `reconcile_stale_ai_look_reservations` and `purge_ai_usage_events` are not scheduled in repo | migrations | Needs pg_cron (NEEDS VERIFICATION). Unreconciled reservations permanently reduce `availableAiLooks` for the period. |
| LOW | `verify-google-play-purchase` absent from `config.toml` | `supabase/config.toml` | Function self-verifies JWT; add entry for consistency. |
| LOW | Google 401/403 collapsed to 503 without status logging | `google_play_api.ts` | Hampers diagnosis; consider logging status code only. |
| LOW | CORS `Access-Control-Allow-Origin: *` on all functions | functions | Acceptable for mobile-only; JWT still required. |
| LOW | Stale `docs/GOOGLE_PLAY_BILLING_SETUP.md` claims nothing is done | docs | Misleads future agents. |
| INFO (good) | No client secrets; RLS on every table; column-level grants on entitlement tables; service_role confined to one RPC; purchase tokens hashed; provider payloads not stored; no purchase-token logging; model locked fail-closed | — | Strong posture. |

No authentication bypass, no client-side entitlement grant, no exposed keys in `lib/` or functions found.

---

## 23. Error Handling and Logging

- **Flutter:** each feature has a typed failure (`AuthFailure`, `SelfieFailure`, `ImageValidationFailure`, `AnalysisFailure`, `RecommendationFailure`, `PreviewFailure`, `TutorialFailure`, `SubscriptionStateFailure`, `SubscriptionFailure`) mapped from `FunctionException.details.error{code,message,retryable}` / `PostgrestException` / `StorageException` / `TimeoutException` / `SocketException`. Controllers use generation/epoch counters to drop stale results. UI shows `StatusState.error` with retry and session-expired recovery. No global error boundary/crash reporter (`docs/PRODUCTION_CHECKLIST.md` "Crash reporting strategy" — none integrated). Flutter logs: only `SupabaseInitializer._log` in debug mode.
- **Edge Functions:** uniform `{error:{code,message,retryable}}` JSON; `console.log/error` with **sanitized** tags — never tokens, paths, or payloads. Useful log markers: `[Phase10] …` and `[Phase10Timing] outcome=… stage_ms=…` in preview functions (stage timings), `[ai-look-usage]`, `[ai-quota]`, `[verify-google-play-purchase] request_failed code=…`, `acknowledgement_failed`, `client_product_mismatch`.
- **Weak spots:** preview client maps 402/403 poorly (§14); Google API status not logged (§16); Gemini block reasons surface as generic `GEMINI_NO_IMAGE_OUTPUT`.
- **Where to look when debugging:** Supabase Dashboard → Edge Functions → Logs (filter by tag above); Postgres logs for RPC errors; `adb logcat` for `Supabase initialization:` lines (`tool/build_and_install_dev.ps1` checks this).

---

## 24. Dependencies

**Core framework:** `flutter`, `flutter_riverpod` 2.6.1, `go_router` 14.8.1.
**UI:** `cupertino_icons` (unused in practice — INFERRED), Material 3 built-in.
**AI:** none client-side (server uses raw `fetch`).
**Backend/Supabase:** `supabase_flutter` 2.17.1 (transitive `gotrue`, `postgrest`, `storage_client`, `functions_client`, `realtime_client`, `app_links` 7.0.0 for deep links).
**Billing:** `in_app_purchase` 3.3.0, `in_app_purchase_android` 0.5.0 (**critical, pinned; do not bump without Dart 3.12**).
**Native/mobile:** `camera` 0.12.0+2, `image_picker` 1.2.3, `permission_handler` 12.0.3, `flutter_image_compress` 2.5.1, `path_provider` 2.1.6, `share_plus` 13.3.0, `package_info_plus` 10.2.1.
**Utilities:** `path`, `uuid`.
**Dev tooling:** `flutter_test`, `flutter_lints` 6.0.0.
**Server (Deno):** `npm:@supabase/supabase-js@2`, `jsr:@std/assert@1` (tests), `jsr:@supabase/functions-js/edge-runtime.d.ts`; lockfile `deno.lock`.

**Observations:** no duplicate libraries; `realtime_client` present transitively but unused; `uuid` usage limited (server mints most ids); dependency set is lean and current. **Must not be casually replaced:** `supabase_flutter`, `in_app_purchase*`, `go_router`, `flutter_riverpod`, `camera`.

---

## 25. Completed Features

Authentication (all modes); scan (gallery, camera, live educational palette); face analysis; style catalog; Standard and Kit makeup plans; Final Makeup Preview (both modes, when entitled); Step-by-Step Tutorial V4; My Makeup Kit CRUD + looks; History (feed, filters, delete); Saved Looks (both modes); Profile (name, avatar); Settings (theme, prefs, sign out, about); Share; design system + dark mode; subscription domain/DB/resolver/usage ledger; allowance UX; paywall with live Play prices; Play Billing client; purchase verification function + activation RPC (code complete, externally blocked); 156 Flutter test files + Deno tests; `flutter analyze` clean.

---

## 26. Incomplete Features

| Feature | State | Blocking on |
| --- | --- | --- |
| Google Play purchase end-to-end | code complete, **fails at Google API authorization** | external (§16) |
| Free plan provisioning (SUB-12) | **not started** — no code creates a `free` entitlement; every new account is unentitled | design decision: trigger on `auth.users` insert vs. lazy grant in `resolve_subscription_state`/`reserve_ai_look` |
| Salon Pilot admin grant (SUB-12) | not started | Web Admin |
| Client handling of 402 / 403 entitlement denials | missing — misleading copy | small Flutter change in `supabase_makeup_preview_repository.dart` (+ kit equivalent) |
| Client `operationId` for preview idempotency (SUB-6 remainder) | not sent | small change |
| Restore purchases | button disabled | SUB-11 |
| Renewal / cancellation / expiry / grace / hold / refund reconciliation, RTDN | not started | SUB-11 |
| Stale-reservation reconciliation scheduling | function exists, not scheduled | pg_cron (dashboard) |
| Telemetry / cost measurement (SUB-13), hardening (SUB-14), device QA (SUB-15) | not started | after SUB-10 PASS |
| Web Admin | spec only | separate track |
| Privacy policy | placeholder | content |
| Crash reporting / analytics SDKs | none (flags only) | product decision |
| iOS | scaffolding only | — |
| SUB-9/SUB-10 commit | 23 untracked files + 11 modified are **uncommitted** | commit when the user decides |

---

## 27. Known Bugs

1. **Unentitled account → Final Preview fails with wrong message** ("The original selfie or makeup plan is no longer available.") because 403 `ENTITLEMENT_NOT_FOUND` is mapped as a validation failure. CONFIRMED in code; severity HIGH if migrations are live.
2. **Exhausted allowance (402)** maps to generic "could not be created right now" instead of an upgrade prompt. CONFIRMED.
3. **12 pre-existing test failures on Windows** (CRLF vs `\n` in `contains(...)` source-text assertions in tutorial contract tests) — documented in `SUB_0_BASELINE_AUDIT.md` §B; not fixed by design. Any new source-text test must normalise line endings (SUB tests do, via helpers).
4. **`android/key.properties` polluted** (see §22) — may break release signing parsing. NEEDS VERIFICATION by running a release build and checking the Gradle warning.
5. **`test/.../subscription_billing_security_test.dart` "verification is still genuinely unimplemented"** asserts the *Unavailable* gateway throws — still true, but the test name is now misleading post-SUB-10 (INFERRED harmless).
6. Kit preview uses Gemini `v1` endpoint while all others use `v1beta` — works today (INFERRED), but a divergence to watch.

---

## 28. Technical Debt

- Legacy tutorial tables/functions v1–v3 remain in migrations (superseded by v4).
- Large root-level documentation corpus (~1.2 MB of SOT/prompt docs) — authoritative but heavy; future agents must read selectively.
- Contract tests that grep source files are brittle (line endings, refactors).
- No CI; no automated Deno test run in Flutter test flow.
- Two nearly identical preview functions (Standard/Kit) and two Gemini client copies per function type — deliberate isolation, but changes must be mirrored.
- `AppConstants.placeholderTitle/Message` unused; `cupertino_icons` likely unused.
- `versionCode` defined both in `pubspec.yaml` (+1) and `android/gradle.properties` (4).
- `docs/GOOGLE_PLAY_BILLING_SETUP.md` stale header.
- `NOTES.md` mixes personal notes with a secret.

---

## 29. Current Risks

| Risk | Impact | Likelihood | Notes |
| --- | --- | --- | --- |
| Google Play API authorization never resolves without Google support | High | Medium | Blocks all revenue; consider parallel path (verify via a different SA / developer account as a test). |
| Launch with no Free entitlement → all new users blocked | High | High (if migrations applied) | Must be fixed before any tester sees the preview flow. |
| Committed credential in git | High | High (already exposed) | Rotate now. |
| Release signing file corrupted | High | Medium | Clean `key.properties`; keep keystore backups. |
| Gemini cost via guest abuse | Medium | Medium | Budget cap + CAPTCHA. |
| Entitlement outliving cancelled subscription (no SUB-11) | Medium | High once purchases work | Bounded by `period_end`. |
| Stale reservations silently reduce capacity | Medium | Medium | Schedule reconciliation. |
| Uncommitted SUB-9/10 work lost | High | Low | Commit soon (user decision). |
| Tests brittle on Windows | Low | High | Known. |
| UI regressions in locked V4 tutorial | Medium | Low | Locked by baseline tests. |

---

## 30. Do-Not-Break Areas

**DO NOT MODIFY WITHOUT UNDERSTANDING**

| Area | Why sensitive |
| --- | --- |
| `supabase/functions/_shared/final_preview_model.ts`, both preview functions' model/prompt | Final Preview is the visual authority for tutorials and QA baselines; model locked to `gemini-3.1-flash-image`, fail-closed. |
| Tutorial V4 (`generate-tutorial-step-v4`, `analyze-tutorial-manifest-v4`, `_shared/tutorial_*`, `lib/features/tutorial`) | Locked at `tutorial_guideline_v4_7`, 1K, `tutorial_manifest_v4_1`; categories, guide key, image contract fixed by SOT. Never reintroduce `v4_8`, geometry/MediaPipe/CustomPainter approaches. |
| My Makeup Kit domain + snapshots | Immutable product snapshot authority; owned-products-only. |
| Subscription migrations (`20260907*`, `20260910*`) and SQL functions | Money/authority logic; advisory locks, idempotency, immutability triggers, grants. Never grant activation to `authenticated`, never weaken RLS. |
| `verify-google-play-purchase/` | Order is verify → activate → acknowledge; the only service-role user; no token logging. |
| `StoreProductCatalog`, `SubscriptionPlanCatalog`, `subscription_products` seed | Product IDs and plan identities are contractual with Play Console. |
| `PurchaseController` ordering | `verify` before `completeVerifiedPurchase` (tested by source order). |
| Storage path conventions and `storage_ownership.ts` | RLS on Storage depends on `{uid}/…` prefix. |
| `SupabaseConfig.validate()` | Prevents shipping a secret key in the client. |
| `AuthController` event generation logic | Prevents stale-session races. |
| `android/key.properties`, keystore | Losing them blocks all future Play updates. |
| Supabase secrets (`GEMINI_API_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `GOOGLE_PLAY_*`) | Production credentials; never move to client or repo. |
| Prompt versions (`*_PROMPT_VERSION`) | Persisted on rows; changing invalidates comparability with baselines. |

---

## 31. Recommended Next Steps

**IMMEDIATE**
1. Rotate the credential exposed in `NOTES.md`; remove the line; purge history.
2. Restore `android/key.properties` to its 4 real lines (keep values); verify a release build reports no debug-signing warning.
3. Decide on committing the SUB-9/SUB-10 work (`git add` the 23 files + 11 modifications) so it cannot be lost.
4. Continue the Google Play authorization forensic path per §16 (external; no code changes). Keep the user's constraints: no permission broadening, no purchases, no SUB-11.

**SHORT TERM**
5. Implement **SUB-12 Free provisioning** (server-side; likely a `security definer` grant on first `resolve_subscription_state`/`reserve_ai_look` or an `auth.users` trigger inserting a `free` entitlement with allowance 1) — required before any tester runs the preview flow.
6. Fix client mapping of 402/403 subscription denials to allowance/upgrade copy (`supabase_makeup_preview_repository.dart` and kit counterpart) and route to `/subscription`.
7. Send a client-generated `operationId` (`AiLookOperationId`) with preview requests for retry idempotency.
8. Schedule `reconcile_stale_ai_look_reservations` and `purge_ai_usage_events` with pg_cron.
9. Add `verify-google-play-purchase` to `supabase/config.toml`; add sanitized `status=` logging to `google_play_api.ts` (after the freeze lifts).

**MEDIUM TERM**
10. SUB-11 lifecycle: RTDN (Pub/Sub → Edge Function), periodic re-verification, restore purchases, expiry handling.
11. SUB-13 telemetry & cost measurement; SUB-14 hardening; SUB-15 device QA.
12. Web Admin (Salon Pilot grants, allowance adjustments) per its SOT.

**BEFORE PRODUCTION**
13. Dashboard: email confirmation, CAPTCHA, anonymous sign-in limits, Google OAuth, redirect URLs; Gemini key restriction + budget alerts; storage retention policy.
14. Privacy policy content; crash reporting decision.
15. Full `flutter test` on a clean machine (fix CRLF assertions), Deno tests, device QA per `docs/QA_DEVICE_TEST_PLAN.md`.

---

## 32. Commands Cheat Sheet

```powershell
# Dependencies
flutter pub get

# Run (development config injected)
powershell -ExecutionPolicy Bypass -File tool/run_dev.ps1
flutter run --dart-define-from-file=config/development.json
flutter run --release --dart-define-from-file=config/development.json

# Build + install debug APK on a USB device with startup verification
powershell -ExecutionPolicy Bypass -File tool/build_and_install_dev.ps1

# Builds
flutter build apk --debug --dart-define-from-file=config/development.json
flutter build appbundle --release --dart-define-from-file=config/production.json   # needs android/key.properties

# Quality
flutter analyze
flutter test
flutter test test/features/subscription

# Supabase
supabase login
supabase link --project-ref usmlwaocafeqnspdsvmv
supabase db push
supabase functions deploy verify-google-play-purchase
supabase functions deploy analyze-face generate-makeup-recommendation generate-makeup-preview generate-kit-makeup-recommendation generate-kit-makeup-preview analyze-tutorial-manifest-v4 generate-tutorial-step-v4 delete-history-item
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=io.facetune.app
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$(Get-Content service-account.json -Raw)"   # then delete the file
supabase secrets set GEMINI_API_KEY=...

# Deno function tests (NEEDS VERIFICATION of exact flags)
cd supabase/functions; deno test --allow-env --allow-net
```

---

## 33. Important Files

| File | Purpose | Why important | Risk if modified |
| --- | --- | --- | --- |
| `lib/app/bootstrap/bootstrap.dart` | Supabase init + ProviderScope | app start | app fails to start |
| `lib/app/router/app_router.dart` | routes + auth redirect | navigation/security | route leaks |
| `lib/core/config/supabase_config.dart` | env validation | prevents secret keys in client | security regression |
| `lib/features/authentication/presentation/controllers/auth_controller.dart` | auth state machine | everything depends on it | session bugs |
| `lib/features/preview/data/repositories/supabase_makeup_preview_repository.dart` | preview call + error mapping | billable path; where 402/403 mapping must be fixed | wrong UX |
| `lib/features/subscription/domain/catalog/*.dart` | plan + product ids | contractual | store mismatch |
| `lib/features/subscription/presentation/controllers/purchase_controller.dart` | purchase lifecycle | verify-before-ack | refund/entitlement bugs |
| `lib/features/subscription/data/repositories/google_play_billing_gateway.dart` | Play SDK mapping | offers, tokens | purchase failures |
| `supabase/functions/verify-google-play-purchase/{index,google_play_api,verification}.ts` | server verification | only entitlement writer for purchases | fraud / broken billing |
| `supabase/migrations/20260907000100_subscription_foundation.sql` | entitlement schema | RLS + constraints | data integrity |
| `supabase/migrations/20260907000200_subscription_entitlement_resolver.sql` | `resolve_subscription_state` | single authority on capacity | wrong gating |
| `supabase/migrations/20260907000300_ai_look_usage_engine.sql` | reserve/commit/release | billing correctness | double charge / free looks |
| `supabase/migrations/20260910000100_google_play_purchase_verification.sql` | activation RPC + verifications table | service_role boundary | privilege escalation |
| `supabase/functions/generate-makeup-preview/index.ts`, `generate-kit-makeup-preview/index.ts` | Final Preview + usage integration | billable AI | cost / lock violations |
| `supabase/functions/_shared/final_preview_model.ts` | model lock | visual authority | baseline invalidation |
| `supabase/functions/_shared/ai_look_usage.ts`, `ai_quota.ts` | usage/quota clients | fail-closed metering | unmetered spend |
| `supabase/functions/_shared/tutorial_ai_config.ts` | tutorial lock | V4 lock | tutorial regression |
| `supabase/config.toml` | function JWT config | deploy behaviour | auth gaps |
| `android/app/build.gradle.kts` | id, signing | Play identity | unpublishable builds |
| `docs/GOOGLE_PLAY_BILLING_SETUP.md` | manual Play steps | onboarding | stale guidance |
| `FACETUNE_SUBSCRIPTION_SOURCE_OF_TRUTH.md`, `FACETUNE_SUBSCRIPTION_PHASE_PROMPTS.md`, `FACETUNE_SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md` | subscription authority docs | phases SUB-11…15 defined here | scope drift |
| `CODEX_MASTER_GUIDE.md` | engineering rules | architecture discipline | — |

---

## 34. Unknowns Requiring Verification

1. Which migrations are applied on the live Supabase project (especially `20260907*` and `20260910*`) and which functions/secrets are deployed.
2. Values (not contents) of `GOOGLE_PLAY_PACKAGE_NAME` and the `client_email`/`private_key_id` inside `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` vs. the Play Console invited user and Cloud key list.
3. Whether the 2026-09-10 AAB was uploaded and rolled out to Internal testing, and whether the three subscriptions are **active** in Play Console.
4. Whether Play Console → Setup → API access is linked to `skurttttt-project`.
5. Dashboard auth settings (email confirmation, anonymous sign-in, Google provider, redirect URLs, CAPTCHA).
6. pg_cron jobs for reconciliation/purge.
7. Location and backup status of the upload keystore referenced by `key.properties`.
8. Whether the release build still signs correctly given the polluted `key.properties`.
9. Exact Deno test invocation and pass state.
10. Effective `versionCode` for the next Play upload (pubspec `+1` vs `gradle.properties` 4).
11. Whether any prior "SUB-9/SUB-10 completion reports" or "forensic reports" exist outside the repo (none are inside it).

---

## 35. AI Handoff Context

**You are taking over development of FaceTune. Here is what you must understand before touching the code.**

**What it is.** A Flutter Android app (`io.facetune.app`) with a Supabase backend and Gemini-powered makeup analysis, plan, preview, and tutorial generation. Clean architecture, feature-first, Riverpod, go_router. All AI and all authority live server-side (Edge Functions + SQL); the client holds only a publishable key.

**What works.** The whole AI beauty journey, My Makeup Kit, Tutorial V4, history/saved/profile/settings, and the entire subscription stack up to and including the Google Play purchase verification code. `flutter analyze` is clean; ~156 test files exist (12 tutorial contract tests fail only on Windows due to CRLF).

**What does not work.**
1. **Google Play Developer API authorization** — the service account `facetune-play-billing@skurttttt-project.iam.gserviceaccount.com` mints tokens fine but Google answers 401/403 to every Play API call for `io.facetune.app`. The code (`supabase/functions/verify-google-play-purchase/google_play_api.ts`) is correct; do not rewrite it. This is an external Play Console / Cloud project linkage issue; the owner has strict rules: no permission broadening, no key regeneration, no purchases, no SUB-11 until SUB-10 passes. Google support is engaged. See §16 for the hypothesis ladder and what has already been eliminated.
2. **No Free entitlement exists** — nothing ever inserts a `user_entitlements` row for a new account, so `reserve_ai_look` denies every Final Preview with `ENTITLEMENT_NOT_FOUND`, and the client shows a misleading "selfie or plan no longer available" message. This is SUB-12 work plus a small client mapping fix; it is the first thing to do once the owner lifts the SUB-10 freeze.

**What has been attempted (do not repeat).** OAuth verification (200), Cloud API enablement (verified), SA invitation/ACTIVE (verified), app-level permissions (verified), read-only probes (`monetization.subscriptions.list` → 403, `subscriptionsv2.get` with fake token → 401).

**Architecture assumptions you must keep.** Server authority for entitlements; verify → activate → acknowledge ordering; purchase tokens are hashed, never stored or logged; only `verify-google-play-purchase` uses `service_role`; Final Preview model locked to `gemini-3.1-flash-image`; tutorial locked to `tutorial_guideline_v4_7` / `tutorial_manifest_v4_1`; plan codes `free|plus|pro|salon_pro|salon_pilot`; product ids `facetune_plus|facetune_pro|facetune_salon_pro`; Free and Salon Pilot are never store products; 1 AI Look = 1 persisted Final Preview; tutorials never bill.

**Sensitive systems.** Supabase secrets, Play service account, upload keystore (`android/key.properties` — currently polluted with pasted prompt text, fix it), the committed credential in `NOTES.md` (rotate + purge).

**Billing status.** Client and server implemented (uncommitted, 23 untracked + 11 modified files on `feature/subscription-v1`); blocked at Google authorization; restore/lifecycle not built.

**Supabase status.** 27 migrations and 9 functions in repo; live deployment state unverified — run `supabase migration list` and check the dashboard before assuming.

**Gemini status.** Working via 7 Edge Functions; key server-only; quotas enforced; cost backstop must be configured in Google Cloud.

**Deployment status.** Manual: `flutter build appbundle --release --dart-define-from-file=config/production.json`; `supabase db push`; `supabase functions deploy …`. No CI. A release AAB was built on 2026-09-10.

**Working conventions.** The project runs on strict phase prompts (`FACETUNE_*_PHASE_PROMPTS.md`) with hard STOP boundaries and completion reports; read `CODEX_MASTER_GUIDE.md` → the relevant Source of Truth → the phase prompt before coding; never touch locked V4 areas; preserve the working tree; never commit/push unless told.

**Priorities, in order.** (1) rotate leaked credential; (2) clean `key.properties`; (3) commit SUB-9/10; (4) resolve Play authorization externally; (5) SUB-12 Free provisioning + client 402/403 mapping; (6) one fresh Plus test purchase (owner authorizes); (7) SUB-11 lifecycle; (8) SUB-13–15; (9) Web Admin.

Read this document, then inspect the repository yourself before modifying anything. Do not assume previous implementation details.
