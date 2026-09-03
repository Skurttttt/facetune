# UI-P7 Production UI Baseline Lock

Date: 2026-09-03  
Branch: `feature/ui-productionization`  
Base revision: `86f8b4e`  
Artifact: `build/app/outputs/flutter-apk/app-debug.apk`  
Artifact SHA-256: `22ABEEFA52A52BAFADCC9FFF464C600FA8096ACBB2EEBDE001DB30C3A71D04A5`

## Scope and decision

UI-P7 was executed as a verification-and-lock phase. It introduced no production
code changes and no feature work. No release-blocking UI defect was exposed by
the automated evidence, so no remediation was authorized or required.

The automated baseline is accepted. Full acceptance is restricted because no
Android device or emulator was connected, so the required human real-device
visual pass and profile-mode performance observation could not be performed.

**QUALITY DECISION: UI BASELINE ACCEPTED WITH RESTRICTIONS**

## Entry gate

UI-P6 completed with the available evidence:

- 41 focused full-page matrix checks cover Light, Dark, System-light,
  System-dark, 320 logical px at 2x text, simulated POCO X3 GT at 393x873,
  Android-sized labelled touch targets, and a simulated-keyboard auth case.
- The two overflows proven by that matrix were remediated in UI-P6: style
  selection and final-preview status content now scroll safely at 320 px and
  2x text.
- The configured Android debug APK built successfully.
- Physical-device evidence was unavailable and remains an explicit restriction.

## End-to-end journey evidence

The established deterministic journey suites passed 18/18 checks.

### Standard Mode

`test/e2e/scan_journey_test.dart` passed 15/15 checks covering:

1. authenticated scan ownership and stage linkage;
2. recommendation and generated-preview linkage;
3. save, History, and reopen consistency;
4. returning and guest sessions, including account-state reset;
5. invalid-image, AI-timeout, and failed-regeneration recovery;
6. variation reuse without overwriting the original selfie; and
7. owned deletion and sanitized delete failure.

The UI portions of Auth, Selfie, Analysis, Style, Recommendation, Final
Preview, Makeup Breakdown, Tutorial, and History/Reopen are additionally
covered by feature/widget and matrix tests in the full suite. This is
deterministic automated journey evidence, not a claim of a physical tap-through.

### My Makeup Kit

`test/e2e/makeup_kit_journey_test.dart` passed 3/3 checks covering:

1. authenticated owned inventory through preview, save, History, and reopen;
2. an empty kit failing honestly without invoking preview generation; and
3. an incomplete kit selecting only the available owned product.

Mode-selection, owned-product snapshot, inventory CRUD, cross-account state,
security, Breakdown, Tutorial, and historical-snapshot contracts also passed
in the full suite. This is deterministic automated journey evidence, not a
claim of a physical tap-through.

## UI evidence

| Area | Evidence | Result |
| --- | --- | --- |
| Design language | One theme/token/typography/semantics system; shared cards, buttons, feedback, layout, and media primitives | Pass |
| Shared component reuse | `PageFrame` in 18 feature files, `PrimaryButton` in 13, `StatusState` in 14, `LoadingState` in 10, `AppNotice` in 10, and shared media components across result/library screens | Pass |
| App shell and navigation | Four labelled destinations retain their original order and routes in Light and Dark | Pass |
| Entry/Auth | Entry actions, auth recovery, auth guard, focus, labels, touch targets, narrow/large-text layout, and simulated keyboard obstruction | Pass |
| Creation flow | Selfie acquisition/validation, analysis, style selection, recommendation mode selection, and retry/cancel states | Pass |
| Results | Recommendation metadata, final-preview actions, loading/error recovery, and safe narrow/large-text presentation | Pass |
| Before/After | Final-preview matrix exercises the comparison region and image container without overflow at the required simulated sizes/themes | Automated pass; physical gesture review restricted |
| Makeup Breakdown | Exact category authority, order, Lips grouping, metadata fidelity, Light/Dark, and 320 px at 2x text | Pass |
| History | Empty/loading/content states plus standard and kit save/reopen contracts | Pass |
| My Makeup Kit | Empty/loading/content, add/detail/delete, mode entry, owned-only selection, immutable snapshots, and cross-account isolation | Pass |
| Tutorial | Step navigation, image viewer, redraw confirmation, final-look access, Standard/Kit metadata, semantics, Light/Dark/System, POCO simulation, and narrow/large text | Pass |
| Loading/empty/error | Shared semantic state primitives and feature-specific honest recovery paths | Pass |
| Image usability | Aspect-safe containers, useful semantics, full-screen tutorial viewer, bounded decode widths, and loading/error handling | Automated pass; physical visual review restricted |
| Navigation clarity | Labelled app destinations, distinct tutorial close/back behavior, route recovery, and History reopen | Pass |

## Theme, responsive, and accessibility matrix

- **Light:** Theme roles, surfaces, inputs, dividers, buttons, states, feature
  pages, Breakdown, and tutorial tests pass.
- **Dark:** Dark surfaces, card foregrounds, muted text, chips, states, feature
  pages, Breakdown, and tutorial tests pass. Contrast contracts meet the
  tested 4.5:1 body-copy threshold.
- **System:** Platform brightness resolves independently to the Light and Dark
  themes; both branches pass at the simulated POCO size.
- **Narrow width:** 320 logical px checks pass, including full pages, shared
  primitives, Breakdown, and tutorial. No blocking automated overflow remains.
- **Large text:** 2x text checks pass at 320 px, including scrolling and fixed
  action regions. The auth field remains focusable above a simulated keyboard.
- **POCO X3 GT:** 393x873 logical-pixel simulation passes for the required
  pages and themes. This is not physical POCO evidence.
- **Accessibility:** Semantic labels, progress/error announcements,
  non-color-only states, Android-sized action targets, image descriptions,
  focusability, and narrow/large-text scroll safety pass automated checks.
  TalkBack traversal and switch/keyboard behavior on Android remain part of the
  physical-device restriction.

## Protected regression evidence

The full suite passed 1,109/1,109 tests. It includes explicit coverage for:

- auth guards, session restoration, sign-out, recovery, and sanitized failures;
- selfie acquisition, file validation, secure validation, replacement, and
  cancellation;
- analysis, style, recommendation, preview, variations, and recovery;
- dynamic manifest analysis, category planning, realization, persistence, and
  durability;
- Breakdown-to-Tutorial category, order, metadata, and source consistency;
- owned-product authority, immutable snapshots, cross-account reset, and
  historical understanding;
- History save/reopen and private-image/storage ownership contracts;
- RLS/security source contracts and the absence of client-side Gemini secrets;
- model, prompt-version, and output-resolution locks.

`git diff --name-only` was empty for dependencies, `supabase/`, core code, and
feature data/domain paths. The working UI baseline is confined to presentation,
shared-widget, theme, and test paths established by UI-P1 through UI-P6, plus
this report.

## Backend and AI locks

- Backend/database/RLS/storage diff: none.
- Final preview model: `gemini-3.1-flash-image`.
- Tutorial model: `gemini-3.1-flash-image`.
- Tutorial output resolution: `1K`.
- Tutorial guideline prompt: `tutorial_guideline_v4_7`.
- Tutorial manifest prompt: `tutorial_manifest_v4_1`.
- No paid AI generation or deployment was performed for UI-P7.

## Performance observations

- No `BackdropFilter` or `ImageFilter.blur` usage exists in the reviewed UI.
- The static scan found one bounded home-hero shadow rather than repeated
  expensive blur surfaces.
- Private, beauty, selfie, and avatar images request layout-bounded decode
  widths; the thumbnail behavior is covered by tests.
- Skeleton animation is covered by a regression asserting that it does not
  rebuild its ancestors.
- The automated flow did not expose repeated paid image generation: ready
  tutorial steps do not regenerate, rebuilds do not regenerate, and rapid
  duplicate actions are guarded.
- Real frame timing, memory, GPU overdraw, camera behavior, and network-image
  behavior were not observed in Android profile mode because no Android device
  was connected.

## Validation record

```text
dart format .
PASS — 394 files formatted, 0 changed

flutter analyze
PASS — No issues found

flutter test test/e2e/scan_journey_test.dart test/e2e/makeup_kit_journey_test.dart --reporter expanded
PASS — 18 tests

flutter test
PASS — 1,109 tests

flutter build apk --debug --dart-define-from-file=config/development.json
PASS — build/app/outputs/flutter-apk/app-debug.apk

flutter devices
Windows, Chrome, and Edge only; no Android target

flutter run --dart-define-from-file=config/development.json
NOT RUN — no Android device or emulator available

git diff --check
PASS — no whitespace errors; informational LF-to-CRLF warnings only
```

## Restrictions required to lift the decision

On a physical Android handset, preferably POCO X3 GT, a human reviewer must:

1. complete both required journeys with real auth, camera/gallery, generated
   images, Breakdown, Tutorial, History, and reopen;
2. inspect Light, Dark, and System at default and larger Android font sizes;
3. inspect 320-class/narrow behavior if the device or emulator supports it;
4. exercise the keyboard, safe areas, scrolling, Before/After interaction,
   image zoom/pan, tutorial redraw confirmation, and navigation recovery;
5. perform a TalkBack traversal of primary routes and verify focus order,
   labels, announcements, and touch comfort; and
6. observe profile-mode frame pacing, repeated image loading, memory pressure,
   and scrolling/animation smoothness.

Any failure in that pass reopens UI-P7 only for minimal remediation of a proven
release-blocking UI defect. Until then, this document locks the automated
production UI baseline with the stated restrictions.

## Completion report

```text
DESIGN SYSTEM: PASS — coherent theme, typography, semantics, spacing, radius, controls, feedback, and media primitives; shared reuse verified.
APP SHELL: PASS — four labelled destinations retain route behavior and ordering in Light and Dark.
ENTRY / AUTH: PASS — entry, guard, recovery, focus, semantics, touch targets, narrow/large text, and simulated keyboard checks pass.
CREATION FLOW: PASS — Selfie → Analysis → Style → Recommendation contracts and UI states pass.
RESULTS: PASS — recommendation, preview, actions, recovery, and responsive presentation pass automated checks.
BEFORE / AFTER: PASS WITH RESTRICTION — responsive container coverage passes; physical gesture/visual review unavailable.
MAKEUP BREAKDOWN: PASS — category authority, ordering, metadata fidelity, themes, narrow width, and large text pass.
HISTORY: PASS — states, save, reopen, and restored-workflow consistency pass.
MY MAKEUP KIT: PASS — owned-only authority, CRUD/states, immutable snapshots, preview, save, history, and reopen pass.
TUTORIAL: PASS — navigation, artifacts, viewer, redraw, metadata, themes, semantics, responsive layout, and no-extra-generation contracts pass.
LOADING / EMPTY / ERROR: PASS — shared and feature-specific honest states and recovery actions pass.
LIGHT: PASS — automated theme and feature-page evidence.
DARK: PASS — automated theme, contrast, and feature-page evidence.
SYSTEM: PASS — automated platform-light and platform-dark resolution evidence.
NARROW WIDTH: PASS — automated 320 logical-pixel evidence; no known blocking overflow.
LARGE TEXT: PASS — automated 2x evidence with scroll and keyboard safety.
POCO X3 GT: PASS WITH RESTRICTION — 393x873 simulation passes; no physical POCO run.
ACCESSIBILITY: PASS WITH RESTRICTION — automated semantics, non-color states, contrast, targets, focus, and scrolling pass; Android TalkBack/manual traversal unavailable.
PERFORMANCE: PASS WITH RESTRICTION — no obvious static/widget regression; Android profile-mode observation unavailable.
PROTECTED V4 REGRESSION: PASS — full suite and protected-path audit cover auth, selfie, analysis, style, recommendation, preview, manifest, Breakdown/Tutorial, My Kit, History/reopen, private storage, and RLS.
BACKEND DIFF: NONE.
AI LOCKS: PASS — final preview/tutorial models, 1K resolution, and prompt versions unchanged; no paid AI call performed.
QUALITY DECISION: UI BASELINE ACCEPTED WITH RESTRICTIONS
UI BASELINE ACCEPTED WITH RESTRICTIONS
```
