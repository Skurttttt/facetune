# UI-P0 — ACCEPTED BASELINE FREEZE & UI INVENTORY

**Phase:** UI-P0 (Production UI / UX Track)
**Type:** READ-ONLY audit. No application code, asset, dependency, test, or backend file was modified.
**Date captured:** 2026-09-03
**Repository:** `C:\Users\Kurt\facetune`

---

## 0. AUTHORITY FILE DISCREPANCY — READ FIRST

The Source of Truth and the Phase Prompts both name their own files as:

```text
FACETUNE_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
FACETUNE_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md
```

Neither filename exists on disk. The files actually present, and actually read for
this phase, are:

```text
FACETUNE_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md      (1514 lines, untracked)
FACETUNE_PRODUCTIONIZATION_PHASE_PROMPTS.md        (1698 lines, untracked)
```

Their content is the UI Productionization track (title line: *"FaceTune — PRODUCTION UI / UX
SOURCE OF TRUTH"*), so these are the intended documents under a different name. Nothing was
invented to fill a gap. **No file was renamed** — renaming an authority document is not in
UI-P0 scope.

**MANUAL ACTION:** decide whether to rename the two files to the `_UI_` names the documents
reference internally, or to amend the internal references. Every later phase's mandatory read
order points at names that do not resolve today.

All other mandatory authority files exist and were read:

| # | File | Lines | Status |
|---|---|---|---|
| 1 | `CODEX_MASTER_GUIDE.md` | 1708 | present |
| 2 | `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_SOURCE_OF_TRUTH.md` | 3206 | present |
| 3 | `FACETUNE_STEP_BY_STEP_TUTORIAL_V4_AI_PHASE_PROMPTS.md` | 2390 | present |
| 4 | `FACETUNE_V4_TUTORIAL_QUALITY_SOURCE_OF_TRUTH.md` | 1449 | present |
| 5 | `FACETUNE_V4_TUTORIAL_QUALITY_PHASE_PROMPTS.md` | 1612 | present |
| 6 | UI Source of Truth | 1514 | present, **misnamed** |
| 7 | UI Phase Prompts | 1698 | present, **misnamed** |
| 8 | Accepted V4 reports (`V4_0_BASELINE_AUDIT`, `V4_QA_0/6/6B/7/8`) | — | present |

---

## 1. EXACT GIT STATE

**At the start of this phase:**

```text
BRANCH                 feature/step-by-step-tutorial-v4-ai
HEAD                   0a725be  Final V4
ORIGIN HEAD            0a725be  (branch is pushed and in sync)
WORKING TREE           clean except two untracked authority documents:
                         ?? FACETUNE_PRODUCTIONIZATION_PHASE_PROMPTS.md
                         ?? FACETUNE_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md
BACKEND DIFF           git diff -- supabase/  ->  empty
```

**At the end of this phase:**

```text
BRANCH                 feature/ui-productionization      <- CHANGED MID-PHASE
HEAD                   0a725be  Final V4                 <- unchanged
TRACKED FILE DIFF      (empty)
BACKEND DIFF           (empty)
UNTRACKED              the two authority documents + UI_P0_BASELINE_AUDIT.md
```

### 1.0 The working branch changed during this phase — not by this agent

Reflog:

```text
0a725be feature/ui-productionization@{0}: branch: Created from HEAD
0a725be HEAD@{0}: checkout: moving from feature/step-by-step-tutorial-v4-ai
                            to feature/ui-productionization
```

A branch named **`feature/ui-productionization`** was created from `0a725be` and checked out
while this read-only audit was running. **This agent did not create it, did not check it out,
and ran no git command other than reads.** The change was made externally.

Two facts about it:

1. **The base is correct.** It was created from `0a725be`, which is the tip of
   `feature/step-by-step-tutorial-v4-ai` — the accepted V4 baseline. It was *not* branched from
   `main`. §1.1 explains why that distinction is the difference between keeping and discarding
   the entire V4 tutorial system. Nothing is broken.
2. **The name does not match the authority documents.** Both the Source of Truth and the Phase
   Prompts specify `feature/ui-productionization-v1`. The branch that exists is
   `feature/ui-productionization` — no `-v1` suffix. It is local only; `origin` has no copy.

Because HEAD is byte-identical (`0a725be` on both branches), every finding in this audit was
derived from exactly the same tree and remains valid.

**MANUAL ACTION:** reconcile the name before UI-P1 — either rename the branch
(`git branch -m feature/ui-productionization feature/ui-productionization-v1`) or amend the two
authority documents to name the branch that exists. Do not leave UI-P1 citing a
`BRANCH VERIFIED` value that no document specifies.

### 1.1 The UI branch base — PROVEN, and it is NOT `main`

The Source of Truth warns: *"never assume `main` already contains every accepted V4 change."*
That warning is correct here, and it is the single most consequential finding of this phase.

```text
main HEAD                            eb6c5e3  Merge My Makeup Kit feature into main
main is an ancestor of HEAD          YES
commits in main not on this branch   (none)
commits on this branch not in main   0a725be  Final V4
                                     85f5f71  V4-QA-6 — DYNAMIC MANIFEST MULTI-STYLE VALIDATION
                                     f3a30a8  Tutorial with Suggested Shades and Instructions
                                     86d79c7  Guidelines need more improvements
                                     e593772  Tutorial

files under lib/features/tutorial/ in main   0
files under lib/features/tutorial/ in HEAD   74
```

`main` contains **zero** of the accepted V4 tutorial system. The entire accepted functional
baseline — the tutorial feature, the dynamic manifest, the realized-look filter, the
final-preview model lock — exists only on `feature/step-by-step-tutorial-v4-ai`.

```text
REQUIRED UI BRANCH BASE
  feature/ui-productionization-v1  MUST branch from
  feature/step-by-step-tutorial-v4-ai @ 0a725be

BRANCHING FROM main WOULD SILENTLY DISCARD THE ENTIRE ACCEPTED V4 BASELINE.
```

`feature/ui-productionization-v1` — the name the authority documents specify — does not exist
locally or on `origin`. This agent created no branch: branch creation is a git operation, and
the phase file forbids git operations without explicit instruction.

What *does* now exist is `feature/ui-productionization` (no `-v1`), created externally during
this phase from the correct base `0a725be`. See §1.0. The base requirement above is therefore
**satisfied**; only the name is unreconciled.

### 1.2 Accepted V4 baseline status

Per `V4_QA_8_BASELINE_LOCK.md` §6.1 the recorded decision is
**BASELINE TECHNICALLY READY — PENDING POST-DEPLOY DEVICE SMOKE**, and the document's own
header note records that the user has since reported real POCO X3 GT testing as PASS.

That is the state the UI track inherits and must preserve. It is *not* a fully-signed
`BASELINE ACCEPTED` in the document's own terms. The UI track does not need it to be —
UI-P1..P7 must not change any behaviour the smoke check would measure — but no UI phase
report may cite an acceptance stronger than what this document records.

---

## 2. PROTECTED BASELINE — PROVEN FROM SOURCE, NOT FROM REPORTS

Every hard lock was verified by reading the constant in the deployed source, not by trusting
a prior completion report.

| Lock | Required | Found | File:line | Status |
|---|---|---|---|---|
| Final preview model | `gemini-3.1-flash-image` | `gemini-3.1-flash-image` | `supabase/functions/_shared/final_preview_model.ts:12` | **PASS** |
| Tutorial guideline model | `gemini-3.1-flash-image` | `gemini-3.1-flash-image` | `supabase/functions/_shared/tutorial_ai_config.ts:24-25` | **PASS** |
| Tutorial resolution | `1K` | `"1K" as const` | `supabase/functions/_shared/tutorial_ai_config.ts:33` | **PASS** |
| Tutorial prompt | `tutorial_guideline_v4_7` | `tutorial_guideline_v4_7` | `supabase/functions/_shared/tutorial_ai_config.ts:87` | **PASS** |
| Manifest prompt | `tutorial_manifest_v4_1` | `tutorial_manifest_v4_1` | `supabase/functions/analyze-tutorial-manifest-v4/prompt.ts:1` | **PASS** |

The final-preview model is enforced by a fail-closed resolver: `GEMINI_IMAGE_MODEL` no longer
*selects* a model, it only *validates* one, and any value other than the locked model raises
before a Gemini request is made. This is the V4-QA-8 §6 remediation and it is present in code.

Text models used elsewhere (`gemini-3.6-flash` in `analyze-face`,
`generate-makeup-recommendation`, `generate-kit-makeup-recommendation`,
`analyze-tutorial-manifest-v4`) are **not** covered by this track's five locks, but are equally
out of bounds for a UI phase.

---

## 3. CURRENT THEME ARCHITECTURE

Two files, 96 + 135 lines. This is genuinely a token system already, not a pile of magic numbers.

### 3.1 `lib/theme/app_tokens.dart`

| Group | Members |
|---|---|
| `AppColors` | `rose #A94E6B`, `roseDark #7C354D`, `blush #F5DDE3`, `petal #FBEFF2`, `ivory #FFFBF8`, `sand #F4ECE7`, `cocoa #2E2225`, `taupe #75686B`, `taupeLight #9C8E92`, `gold #B58A52`, `success #557A68`, `error #B64D56`, `darkSurface #1A1517`, `darkCard #261F22`, `roseLight #E08BA3`, `successLight #8FBBA6` |
| `AppColors` helpers | `onTint(context, accent)`, `muted(context)`, `onAccent(background)` |
| `AppSpacing` | `xxs 4`, `xs 8`, `sm 12`, `md 16`, `lg 24`, `xl 32`, `xxl 48` |
| `AppRadii` | `sm 12`, `md 18`, `lg 24`, `xl 32`, `pill 999` |
| `AppElevation` | `none 0`, `subtle 1`, `floating 6` |
| `AppIconSizes` | `sm 18`, `md 24`, `lg 32`, `hero 48` |
| `AppDurations` | `quick 180ms`, `standard 280ms` |

The dark-mode contrast work is documented in-code with measured ratios (`taupe` 3.4:1 on
`darkSurface` → `taupeLight` 5.8:1; `rose` 3.1:1 on `darkCard` → `roseLight` >6:1) and is
covered by `test/qa/dark_mode_contrast_test.dart`. **PASS.**

### 3.2 `lib/theme/app_theme.dart`

Material 3 (`useMaterial3: true`), `ColorScheme.fromSeed(seedColor: AppColors.rose)` per
brightness, with `surface` and `error` overridden. Themed components: `textTheme` (8 roles),
`appBarTheme`, `cardTheme`, `filledButtonTheme`, `outlinedButtonTheme`,
`inputDecorationTheme`, `navigationBarTheme`, `dialogTheme`, `bottomSheetTheme`.

Light / Dark / System are wired end to end: `AppTheme.lightTheme` + `AppTheme.darkTheme` +
`themeModeProvider` in `lib/app/app.dart:22-24`, driven by the persisted `AppThemePreference`
segmented control in Settings. **PASS.**

### 3.3 Theme findings

| Finding | Evidence | Rating |
|---|---|---|
| `fontFamily: 'sans-serif'` | `app_theme.dart:24` — a platform family string, not a shipped face. `pubspec.yaml` declares **no `fonts:` section**. Typography resolves to whatever the OS supplies, which differs across Android OEM skins and iOS. An "editorial, premium" direction cannot be built on it. | **FAIL** (UI-P1) |
| `AppElevation` declared, barely used | `subtle` and `floating` are defined; `cardTheme` uses `none` and no widget references the other two. Shadow language is ad hoc — the one real shadow in the app is hand-rolled (`home_page.dart:296-302`, `blurRadius: 30, offset (0,14)`). | **ACCEPTABLE** (UI-P1) |
| `AppDurations` declared, **never used** | Zero references outside the token file. There is no motion system; the only animation in the app is `SkeletonCard`'s hardcoded `1200ms`. | **FAIL** (UI-P1) |
| No semantic surface tokens | `petal` / `blush` are raw brand tints doing duty as "info", "success confirmation" and "error" surfaces alike (see §6.1). No `AppColors.infoSurface` / `warningSurface` layer exists. | **FAIL** (UI-P1) |
| No typography scale beyond Material defaults | `textTheme.copyWith` tunes weight/letter-spacing on 8 roles but every size is Material's default. No declared display/editorial scale. | **ACCEPTABLE** (UI-P1) |

---

## 4. SCREEN INVENTORY

22 pages, 5,851 lines of page code; 27 feature widgets, 3,049 lines; 14 shared widgets, 617
lines. 275 Dart files under `lib/`.

Navigation is `go_router` with 21 routes (`lib/app/router/app_router.dart`), a global auth
redirect, and a typed `extra` payload for the tutorial route.

| Group | Route | Page file | Lines | Chrome | Visual baseline |
|---|---|---|---|---|---|
| **ENTRY / AUTH** | `/auth` | [authentication_page.dart](lib/features/authentication/presentation/pages/authentication_page.dart) | 126 | none | **FAIL** — §7.1 |
| | `/auth/loading` | [auth_loading_page.dart](lib/features/authentication/presentation/pages/auth_loading_page.dart) | 16 | none | ACCEPTABLE |
| | `/auth/email` | [email_login_page.dart](lib/features/authentication/presentation/pages/email_login_page.dart) | 116 | `AuthFormScaffold` | ACCEPTABLE |
| | `/auth/register` | [registration_page.dart](lib/features/authentication/presentation/pages/registration_page.dart) | 138 | `AuthFormScaffold` | ACCEPTABLE |
| | `/auth/forgot-password` | [forgot_password_page.dart](lib/features/authentication/presentation/pages/forgot_password_page.dart) | 73 | `AuthFormScaffold` | ACCEPTABLE |
| | `/auth/reset-password` | [reset_password_page.dart](lib/features/authentication/presentation/pages/reset_password_page.dart) | 110 | `AuthFormScaffold` | ACCEPTABLE |
| **HOME / START** | `/` | [home_page.dart](lib/features/home/presentation/pages/home_page.dart) | 344 | `AppShell` (tab 0) | ACCEPTABLE |
| **SELFIE / VALIDATION** | `/scan` | [scan_page.dart](lib/features/scan/presentation/pages/scan_page.dart) | 450 | `AppBar` | **FAIL** — §6.1 |
| **ANALYSIS / LOADING** | `/analysis` | [analysis_result_page.dart](lib/features/analysis/presentation/pages/analysis_result_page.dart) | 138 | `AppBar` | ACCEPTABLE |
| **STYLE SELECTION** | `/styles` | [style_selection_page.dart](lib/features/makeup_styles/presentation/pages/style_selection_page.dart) | 128 | `AppBar` | ACCEPTABLE |
| **MODE SELECTION** | `/recommendation-mode` | [recommendation_mode_selection_page.dart](lib/features/makeup_kit/presentation/pages/recommendation_mode_selection_page.dart) | 177 | `AppBar` | ACCEPTABLE |
| **RECOMMENDATION** | `/recommendation` | [makeup_recommendation_page.dart](lib/features/recommendation/presentation/pages/makeup_recommendation_page.dart) | 180 | `AppBar` | ACCEPTABLE |
| **FINAL PREVIEW + BEFORE/AFTER + BREAKDOWN** | `/preview` | [preview_result_page.dart](lib/features/preview/presentation/pages/preview_result_page.dart) | 503 | `AppBar` | ACCEPTABLE |
| **KIT PREVIEW + BREAKDOWN** | `/makeup-kit/recommendation-entry` | [makeup_kit_recommendation_entry_page.dart](lib/features/makeup_kit/presentation/pages/makeup_kit_recommendation_entry_page.dart) | 618 | `AppBar` | ACCEPTABLE |
| **HISTORY** | `/history` | [history_page.dart](lib/features/history/presentation/pages/history_page.dart) | 604 | `AppShell` (tab 2) | ACCEPTABLE |
| **SAVED LOOKS** | `/saved` | [saved_looks_page.dart](lib/features/saved_looks/presentation/pages/saved_looks_page.dart) | 431 | `AppShell` (tab 1) | ACCEPTABLE |
| **MY MAKEUP KIT** | `/makeup-kit` | [makeup_kit_overview_page.dart](lib/features/makeup_kit/presentation/pages/makeup_kit_overview_page.dart) | 167 | `AppBar` + FAB | ACCEPTABLE |
| | `/makeup-kit/add-product` | [add_makeup_kit_product_page.dart](lib/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart) | 255 | `AppBar` | **FAIL** — §6.2 |
| | `/makeup-kit/product/:id` | [makeup_kit_product_page.dart](lib/features/makeup_kit/presentation/pages/makeup_kit_product_page.dart) | 213 | `AppBar` | ACCEPTABLE |
| **TUTORIAL** | `/tutorial` | [tutorial_page.dart](lib/features/tutorial/presentation/pages/tutorial_page.dart) | 410 | **none** | **FAIL** — §7.2 |
| **PROFILE** | `/profile` | [profile_page.dart](lib/features/profile/presentation/pages/profile_page.dart) | 368 | `AppShell` (tab 3) | ACCEPTABLE |
| **SETTINGS / APPEARANCE** | `/settings` | [settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart) | 286 | `AppBar` | ACCEPTABLE |

`ACCEPTABLE` means: uses the shared frame, uses tokens, has loading/error/empty coverage, and
no defect was proven by reading the code. It is **not** a statement that the screen has been
seen on a device in this track. No visual `PASS` is claimed anywhere in this report.

**Worth noting:** there is no dedicated route for `BEFORE / AFTER` — it is the
`BeforeAfterComparison` widget embedded in `/preview`. That is a design decision, not a gap,
and UI-P4 must not turn it into a route.

---

## 5. SHARED COMPONENT INVENTORY

### 5.1 `lib/shared/widgets/` — the real design system today

| Component | File | Lines | Used by | Verdict |
|---|---|---|---|---|
| `PageFrame` | `layout/page_frame.dart` | 22 | every page | Universal. `maxWidth 720` + `EdgeInsets.fromLTRB(20,8,20,32)`. The `20` horizontal padding is **not** an `AppSpacing` value. |
| `AppCard` | `surfaces/app_card.dart` | 52 | ~all | Solid. Its accent-foreground derivation is the smartest piece of theming in the codebase and is test-locked. |
| `PrimaryButton` / `SecondaryButton` | `buttons/` | 23 + 23 | ~all | Both force `width: double.infinity` and both force an icon (defaulting to `auto_awesome_rounded` / `arrow_forward_rounded`). No text-only or inline variant exists, which is why screens drop to raw `TextButton` / `FilledButton` when they need one. |
| `SectionHeader` | `content/section_header.dart` | 18 | home, preview, profile, settings | Fine. |
| `LoadingState` | `feedback/loading_state.dart` | 44 | 8 pages | Good — `Semantics(liveRegion)` + optional progress. |
| `StatusState` | `feedback/status_state.dart` | 80 | 15 files, 38 call sites | **Overloaded** — see §10. |
| `SkeletonCard` | `feedback/skeleton_card.dart` | 73 | home, makeup kit overview | Only 2 of 22 screens use skeletons. |
| `PrivateImage` | `media/private_image.dart` | 90 | preview, tutorial, home, cards | Excellent. Layout-aware decode; test-locked in `test/shared/private_image_test.dart`. Do not touch its decode logic. |
| `BeautyImage` | `media/beauty_image.dart` | 37 | **1 call site** (auth page) | Wraps the stock asset. See §7.1. |
| `showConfirmationDialog` / `showAppBottomSheet` | `overlays/app_overlays.dart` | 34 | see §6.3 | Both are **bypassed** by most call sites. |
| `AppShell` | `app_shell.dart` | 48 | home, saved, history, profile | 4-tab `NavigationBar`. **Not exported from `app_ui.dart`** — imported by path. |
| `LookCard` | `look_card.dart` | 62 | **nobody** | **DEAD CODE.** Zero references. Renders the stock asset and hard-navigates to `/preview` regardless of content. Delete in UI-P1. |

`app_ui.dart` is a barrel exporting 11 of the 14 shared widgets. `app_shell.dart` and
`look_card.dart` are excluded; `private_image.dart` is exported and also imported directly in
places. **ACCEPTABLE**, tidy in UI-P1.

### 5.2 Feature widgets (27)

Authentication 3 · History 1 · Makeup Kit 8 · Makeup Styles 1 · Recommendation 1 · Results 5 ·
Saved Looks 1 · Tutorial 7.

The Tutorial set (`tutorial_final_look_card`, `tutorial_guide_key`, `tutorial_image_viewer`,
`tutorial_instructions_card`, `tutorial_product_cards`, `tutorial_redraw_sheet`) is the most
recently built and the most carefully finished — it is the only feature that consistently
handles `MediaQuery.textScalerOf` and writes real `Semantics` labels. It is the quality bar
the rest of the app should be raised to, not the thing that needs the most work.

---

## 6. REPEATED LOCAL STYLES & DUPLICATED PATTERNS

### 6.1 The "petal notice" — 22 occurrences, no component, 3 different meanings

`AppCard(color: AppColors.petal)` (or `blush`) appears **22 times across 15 files**:
`authentication_page`, `history_page`, `home_page`, `add_makeup_kit_product_page`,
`makeup_kit_overview_page`, `makeup_kit_recommendation_entry_page`, `kit_saved_look_card`,
`style_selection_page`, `profile_page`, `beauty_profile_card`, `saved_looks_page`, `scan_page`,
`settings_page`, `tutorial_product_cards`, `status_state`.

There is no `AppNotice` / `InlineBanner` component. Each site re-assembles
`AppCard` + optional `Icon` + `Row` + `Expanded(Text)` by hand.

Worse than the duplication: **the same pink surface carries three incompatible meanings.**
In [scan_page.dart](lib/features/scan/presentation/pages/scan_page.dart) alone:

| Line | Meaning | Surface |
|---|---|---|
| 86 | success — *"Local checks passed…"* | `AppColors.petal` |
| 320 (`_ScanError`) | **error** — permission denied, validation failed | `AppColors.petal` |
| 383 (`_AnalysisError`) | **error** — *"Analysis paused"* | `AppColors.petal` |

`AppColors.error #B64D56` exists and is used **only** as a `SnackBar` background in
profile / settings / add-product. No inline error surface uses it. A user cannot distinguish
"you passed" from "this failed" by colour anywhere in the scan flow.

**Rating: FAIL.** Highest-value UI-P1/P2 item.

### 6.2 Two input systems

`inputDecorationTheme` (`app_theme.dart:92-113`) defines the global field: filled,
`AppRadii.md` (18), `borderSide: none`, rose focus ring.
[add_makeup_kit_product_page.dart:141](lib/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart#L141)
and [:166](lib/features/makeup_kit/presentation/pages/add_makeup_kit_product_page.dart#L166)
override it with a bare `border: OutlineInputBorder()` — Material's default 4px radius,
default outline. Add Product's two fields therefore look like a different app from every auth
field. **FAIL.** (UI-P4.)

### 6.3 Shared overlays bypassed

`showConfirmationDialog` exists in `app_overlays.dart` and is used by almost nobody. Raw
`showDialog` + hand-built `AlertDialog` appears in `settings_page` (sign-out plus three info
dialogs), `profile_page` (edit display name), `history_page` (two delete confirmations). Each
spells its own actions. **ACCEPTABLE** but a UI-P2 consolidation target.

### 6.4 Four colour-swatch implementations

| Implementation | Size | Border | File |
|---|---|---|---|
| `CircleAvatar` + 26px `Container` | 26 | none | `makeup_breakdown.dart:83-96` |
| `_ColorSwatch` | 42 | `Theme.dividerColor` | `recommendation_item_card.dart:85` |
| `MakeupKitColorSwatch` | 28 | `colorScheme.outlineVariant` | `makeup_kit_color_swatch.dart` |
| `_ShadeChip` | 28 | `colorScheme.outlineVariant` | `tutorial_product_cards.dart:15` |

Three sizes, three border rules. Only two of the four carry a `Semantics` label.
**FAIL** for consistency. Note: `_ShadeChip` is the best of the four (it merges swatch + hex
into one semantics node) and should be the basis of the shared component.

### 6.5 Four "label: value" detail rows

| Implementation | Treatment |
|---|---|
| `_Detail` in `makeup_breakdown.dart:111` | `Text.rich`, `w700` label |
| `_Detail` in `recommendation_item_card.dart:62` | `Text.rich`, `w600` label |
| `_Detail` in `makeup_kit_product_page.dart:193` | `Row` + fixed `SizedBox(width: 100)` label column |
| `_detailRow` in `tutorial_product_cards.dart:60` | `bodySmall`, opacity-derived label colour |

The fixed 100px label column in `makeup_kit_product_page` is a text-scaling overflow risk.
**FAIL** for consistency. (UI-P4.)

### 6.6 Non-token numeric literals

Token discipline is otherwise strong — this is a short list, not a systemic problem.

```text
Color(0x…) outside lib/theme/          1   (tutorial_product_cards.dart:24 — parses DATA, correct)
fontSize: literal                      1   (kit_saved_look_card.dart:126 — fontSize: 11)
BorderRadius.circular(non-token)       1   (beauty_image.dart:20 — parameterised, correct)
SizedBox(height|width: literal)       16
EdgeInsets.*(non-AppSpacing)          25
```

Named offenders worth fixing: `PageFrame` padding `20/8/20/32`; `_SelfieFrame` height `340`;
`_RecentLookCard` / `LookCard` width `168`; home recent-looks strip height `224`;
`_ProfileAvatar` dimension `96`; `_TipRow` vertical `6`; `_ImageLabel` padding `10/6`;
`makeup_kit_overview_page.dart:70` `SizedBox(height: 120)` used as vertical centring;
`analysis_result_page.dart` row padding `10`; breakdown swatch `26`; `style_selection_page`
grid `mainAxisExtent: 190`. **ACCEPTABLE** — UI-P1 cleanup.

---

## 7. KEY PRODUCTION-READINESS GAPS

### 7.1 The first screen a user ever sees is a stock placeholder — **FAIL**

[authentication_page.dart:46](lib/features/authentication/presentation/pages/authentication_page.dart#L46)
renders `BeautyImage(height: 250)`, which is `Image.asset('assets/images/beauty_portrait.png')`.

```text
assets/images/beauty_portrait.png    2,054,029 bytes (1.96 MB)
```

It is the **only** image asset in the project, it is ~2 MB of the APK, it is decoded at full
source resolution into a 250px box (`BeautyImage` does not use `cacheWidth`, unlike
`PrivateImage`), and it is a generic stock portrait standing in for brand art on the entry
screen. The same asset is the sole content of the dead `LookCard`.

Also on that screen: `Icons.g_mobiledata_rounded` is used as the Google sign-in mark
([authentication_page.dart:83](lib/features/authentication/presentation/pages/authentication_page.dart#L83)).
That is Material's generic "G" glyph, not the Google logo. Google's branding guidelines for
"Sign in with Google" require the official mark; shipping the generic glyph is both an
off-brand look and a policy exposure at store review.

**UI-P3 scope.** Both need a real asset decision from the product owner — this is not
something a UI phase can invent.

### 7.2 Tutorial has no way out except the system back gesture — **FAIL**

[tutorial_page.dart:130-137](lib/features/tutorial/presentation/pages/tutorial_page.dart#L130-L137)
builds `Scaffold(backgroundColor: …, body: SafeArea(PageFrame(content)))` with **no `AppBar`**.
The in-page `Back` button moves to the previous *step*, not out of the tutorial. On the first
step it is disabled. `Finish` only appears on the last step.

So a user on step 3 of 8 has no on-screen affordance to leave. Android's system back works;
that is not a substitute for a visible exit on a full-screen flow, and there is no guaranteed
iOS equivalent.

The comment at that line explains why the `Scaffold` exists (the route was transparent without
it) — the missing app bar looks like an oversight from that fix rather than a decision.
**UI-P5 scope. Presentation only — adding a leading close button changes no tutorial state,
starts no generation, and touches no controller.**

Note `authentication_page` and `auth_loading_page` also lack an `AppBar`; for those it is
correct (they are roots).

### 7.3 No shipped font — **FAIL**

`app_theme.dart:24` sets `fontFamily: 'sans-serif'`; `pubspec.yaml` declares no `fonts:`.
See §3.3. **UI-P1 scope**, and it needs a licensing decision, not just code.

### 7.4 No motion system — **FAIL**

`AppDurations.quick` / `.standard` have zero references. No `AnimatedSwitcher`, `Hero`,
page-transition theme, or staged reveal anywhere. Every state change is an instant cut. The
`SkeletonCard` shimmer is the only animation and hardcodes `1200ms`. For a product positioned
as "premium / calm / editorial" this is the largest single gap between the stated design
direction and the built artefact. **UI-P1 (tokens) + UI-P2 (application).**

### 7.5 Dead code — **ACCEPTABLE**

`lib/shared/widgets/look_card.dart` (62 lines): zero references, renders the stock asset,
navigates to `/preview` unconditionally. Delete in UI-P1.

### 7.6 Privacy-policy placeholder — **FAIL for release, out of UI scope**

[settings_page.dart](lib/features/settings/presentation/pages/settings_page.dart) ships a
"Privacy policy — Publication pending" entry whose dialog states *"This placeholder does not
represent a legal policy."* Honest, and correct to keep until a real policy exists, but it is a
hard release blocker that no UI phase can close. Flagged for the product owner, not for
UI-P1..P7.

---

## 8. RESPONSIVE FINDINGS

### 8.1 What exists

`PageFrame(maxWidth: 720)` on every page gives a universal large-screen ceiling. **PASS.**

Genuine breakpoint handling exists in exactly 6 places:

| Location | Rule |
|---|---|
| `style_selection_page.dart:43` | `maxWidth >= 720 → 3 columns, else 2` |
| `preview_result_page.dart:257` | `maxWidth >= 900 → side-by-side comparison + details` |
| `saved_looks_page.dart:209, 278` | `SliverLayoutBuilder` → responsive `crossAxisCount` |
| `tutorial_page.dart:279-296` | `maxWidth < 360` **or** `textScaler(14) > 20` → stack Back/Next vertically |
| `tutorial_final_look_card.dart:51-64` | text-scale-aware layout switch |
| `tutorial_product_cards.dart:65, 98` | text-scale-aware layout switch |

Note the `maxWidth >= 900` branch in `preview_result_page` can **never** fire — `PageFrame`
caps the child at 720. That branch is unreachable dead layout code. **FAIL** (UI-P4: either
raise `PageFrame.maxWidth` for that page or delete the branch; do not leave a lie in the file).

### 8.2 Text-scaling risk

`MediaQuery.textScalerOf` is consulted in **3 files, all in the Tutorial feature.** No other
screen adapts to large text. Concrete risks found by reading:

- `makeup_kit_product_page.dart:193` — `SizedBox(width: 100)` fixed label column.
- `kit_saved_look_card.dart:126` — `fontSize: 11` bypasses the text theme entirely.
- `style_selection_page.dart:46` — `mainAxisExtent: 190` fixed grid cell; the card inside has
  title + description and no scale awareness.
- `home_page.dart:203` — `SizedBox(height: 224)` fixed strip with a two-line text block inside.
- `analysis_result_page.dart:92-113` — attribute rows are `Row(Expanded(Text), Column(…))` with
  no wrap; seven long attribute labels beside a value + confidence line.

### 8.3 Automated coverage

`test/qa/responsive_layout_test.dart` runs 3 viewports — small phone 320×640,
**POCO X3 GT 393×873**, large tablet 800×1280 — against **3 screens only**: home, profile,
settings (plus a guest-notice variant). All pass.

Uncovered by responsive tests: scan, style selection, analysis, recommendation, mode selection,
preview, tutorial, history, saved looks, all three makeup-kit screens, all six auth screens.
**Coverage rating: FAIL for breadth, PASS for what it covers.**

There is **no text-scale test at any viewport.**

---

## 9. ACCESSIBILITY FINDINGS

### 9.1 Contrast — **PASS**

`test/qa/dark_mode_contrast_test.dart` computes real WCAG ratios and asserts ≥4.5:1 for
`muted`, `onTint`, and accent chip labels on both surfaces, plus four widget tests proving
accent cards do not inherit the dark theme's near-white `onSurface`. This is genuine, measured
evidence.

### 9.2 Semantics coverage — uneven

22 of 275 files carry `Semantics` / `semanticLabel` / `ExcludeSemantics`. By feature:

| Feature | Semantics work |
|---|---|
| Tutorial (7 widgets + page + labels util) | **thorough** — merged nodes, live regions, described tap targets |
| Shared feedback (`LoadingState`, `StatusState`, `SkeletonCard`) | good — `liveRegion`, container labels |
| Results (`before_after_comparison`, `beauty_profile_card`, `recommended_palette`) | good |
| Scan, Profile, Makeup Kit pickers, Style card, Recommendation card | partial |
| **Auth (all 6 screens), Home, History, Saved Looks, Settings, Analysis** | **none** |

### 9.3 Specific gaps found

- **`AppShell` navigation bar** has no per-destination semantics beyond the visible label, and
  the History destination is the only one with **no `selectedIcon`** (`app_shell.dart:38-41`) —
  its icon does not change on selection, so selection state is conveyed by the indicator pill
  alone.
- **`BeforeAfterComparison`** is drag/tap driven with a `Slider` fallback that *is* labelled —
  good — but the drag surface itself carries only an `image: true` label, so the primary
  interaction is not announced as adjustable.
- **`_ProfileAvatar`** is labelled *"Double tap to choose a new photo"* but the outer
  `Semantics(button: true)` wraps a `Stack` whose actual tap target is a nested `IconButton`;
  the label describes an action the labelled node does not perform.
- **Icon-only controls without tooltips:** `home_page.dart:66` settings `IconButton.filledTonal`
  has no `tooltip`. (`scan_page.dart:44`, `profile_page.dart:76` and `_ProfileAvatar`'s button
  do have tooltips.)
- **`_ImageLabel`** ("Before"/"After") draws `Colors.white` on `Colors.black54` over an
  arbitrary photograph — contrast is undefined against the image behind it.

### 9.4 Touch targets — **PASS**

`FilledButton` / `OutlinedButton` themes both set `minimumSize: Size(64, 56)`, comfortably
above the 48dp minimum. `NavigationBar` height 72.

---

## 10. LOADING / ERROR / EMPTY STATE INCONSISTENCIES

Per-page tally of the four mechanisms:

| Page | LoadingState | SkeletonCard | raw CircularProgress | StatusState | SnackBar |
|---|---|---|---|---|---|
| home | 0 | **2** | 0 | 2 | 0 |
| makeup_kit_overview | 0 | **3** | 0 | 2 | 0 |
| history | 2 | 0 | **2** | 4 | 5 |
| saved_looks | 2 | 0 | **2** | 4 | 3 |
| preview_result | 2 | 0 | 0 | 4 | 2 |
| tutorial | 2 | 0 | 0 | 6 | 0 |
| makeup_kit_recommendation_entry | 3 | 0 | 0 | 7 | 2 |
| makeup_recommendation | 1 | 0 | 0 | 3 | 0 |
| profile | 1 | 0 | **1** | 1 | 3 |
| settings | 1 | 0 | 0 | 1 | 3 |
| makeup_kit_product | 0 | 0 | **1** | 1 | 3 |
| scan | 0 | 0 | **1** | 0 | 0 |
| analysis_result | 0 | 0 | 0 | 1 | 0 |
| style_selection | 0 | 0 | 0 | 0 | 2 |
| add_makeup_kit_product | 0 | 0 | 0 | 0 | 3 |
| all 6 auth pages | 1 (loading page) | 0 | 0 | 0 | 0 |

### Findings

1. **Three unrelated loading languages coexist.** Skeletons on 2 screens, `LoadingState`
   spinner+label on 8, bare `CircularProgressIndicator` on 5 (history/saved pagination footers,
   profile avatar, kit product mutation, scan busy overlay). A user moving home → history sees a
   different idea of "loading" on each. **FAIL.** (UI-P2.)

2. **`StatusState` is doing four jobs.** 38 call sites across 15 files. It is simultaneously the
   empty state, the error state, the "not ready / wrong precondition" state, **and** a plain
   informational card — [makeup_recommendation_page.dart:155](lib/features/recommendation/presentation/pages/makeup_recommendation_page.dart#L155)
   uses it for *"Ready for your preview"*, which is neither an error nor an absence. Its icon
   circle is always `AppColors.petal` + `AppColors.rose` regardless of whether it is announcing
   success or failure. **FAIL.** (UI-P2 — split into `EmptyState` / `ErrorState` / `InfoCard`
   sharing one primitive, with no change to any call site's text or actions.)

3. **Error colour is unused inline.** See §6.1. `AppColors.error` reaches the user only via
   `SnackBar(backgroundColor:)` on 3 screens. **FAIL.**

4. **SnackBar feedback is inconsistently coloured.** `profile_page`, `settings_page` and
   `add_makeup_kit_product_page` pass `backgroundColor: feedbackIsError ? AppColors.error : null`.
   `preview_result_page`, `history_page`, `saved_looks_page`, `makeup_kit_product_page` and
   `style_selection_page` pass no colour at all — their error snackbars are theme-default.
   29 `SnackBar` sites total, no shared helper. **FAIL.** (UI-P2.)

5. **Vertical centring by magic number.** `makeup_kit_overview_page.dart:70` uses
   `SizedBox(height: 120)` to push a failure `StatusState` down the page. Other screens use
   `Center`. **ACCEPTABLE**, fix in UI-P2.

6. **Fixed-colour ground behind a themed card.** `before_after_comparison.dart:113` renders the
   image-error fallback as `ColoredBox(color: AppColors.sand)` — a light token — wrapping a
   `StatusState` whose `AppCard` is `darkCard` in dark mode. **ACCEPTABLE**, fix in UI-P4.

---

## 11. GLOBAL STATE FINDINGS

Riverpod business architecture is clean and must be preserved verbatim.

- **Theme state is business state, not UI-local:** `themeModeProvider` ←
  `settingsControllerProvider` ← `SupabaseSettingsRepository`. A theme preference round-trips to
  the database. **No UI phase may make the theme control local.**
- **Rebuild discipline is already deliberate.** `home_page.dart:28-33` uses `.select()` on auth
  and profile specifically to keep the dashboard off the rebuild path for snackbar/feedback
  churn. `add_makeup_kit_product_page.dart:76-82` does the same for mutation flags. UI-P1..P7
  must not widen these watches while "tidying".
- **Two `initState`-gated paid-work guards exist and are load-bearing:** `_RealizedBreakdownState`
  ([preview_result_page.dart:437](lib/features/preview/presentation/pages/preview_result_page.dart#L437))
  and `_TutorialPageState` ([tutorial_page.dart:66](lib/features/tutorial/presentation/pages/tutorial_page.dart#L66)).
  Both start AI work from `initState` + `addPostFrameCallback`, never from `build`, precisely
  because a build can fire for a theme change or a snackbar. **A UI phase that converts either
  page to a `ConsumerWidget` for "simplicity" would charge the user real money per rebuild.**
  This is the most dangerous refactor available in this codebase. It is forbidden.
- `_RealizedBreakdown` deliberately **refuses to fall back** to the unfiltered recommendation on
  manifest failure, and says so in a comment. UI-P4 must not "improve" that into a graceful
  degradation — it would restore the second, weaker category authority V4-QA-6B removed.
- `AppShell` selected index is passed as a literal by each of the 4 pages; there is no
  `StatefulShellRoute`. **ACCEPTABLE** — UI-P2 may polish presentation but must not restructure
  routing.

---

## 12. VALIDATION RESULTS

```text
flutter analyze          No issues found! (45.4s)                    PASS
flutter test             All tests passed!  932 tests                PASS
git diff -- supabase/    (empty)                                     NO BACKEND CHANGES
flutter build apk        NOT RUN — no code changed in this phase     N/A
Real device (POCO X3 GT) NOT RUN — read-only audit, no build produced UNAVAILABLE
Paid AI generation       NONE — no generation was triggered          PASS
```

Test suite composition: 104 test files. Notable for the UI track —
`test/qa/dark_mode_contrast_test.dart`, `test/qa/responsive_layout_test.dart`,
`test/shared/feedback_widgets_test.dart`, `test/shared/private_image_test.dart`, plus
page-render tests for home, profile, settings, style selection, makeup kit overview / product /
add-product, recommendation mode, and tutorial.

**These page tests are the UI track's regression net.** Any UI phase that changes a widget tree
must keep them green without rewriting their assertions to match new markup.

---

## 13. PROTECTED FILES — DO NOT TOUCH IN UI-P1..P7

### 13.1 Absolutely forbidden

```text
supabase/**                          entire tree — functions, migrations, RLS, storage
  _shared/final_preview_model.ts       FINAL_PREVIEW_MODEL lock
  _shared/tutorial_ai_config.ts        model / 1K / tutorial_guideline_v4_7
  analyze-tutorial-manifest-v4/        tutorial_manifest_v4_1
  generate-tutorial-step-v4/
  generate-makeup-preview/
  generate-kit-makeup-preview/
  analyze-face/
  generate-makeup-recommendation/
  generate-kit-makeup-recommendation/

lib/**/domain/**                     entities, repositories, use cases, catalogs, validation
lib/**/data/**                       data sources, models/DTOs, repositories, providers
lib/core/**                          config, DI, Supabase client/init, constants, failures
```

### 13.2 Presentation-layer files with load-bearing logic — edit only with extreme care

| File | What must survive untouched |
|---|---|
| `preview/presentation/pages/preview_result_page.dart` | `_RealizedBreakdown` `initState` gating; the `MakeupPreviewStatus.success when …` guard chain (lines 143-151) that proves analysis / recommendation / preview / style all belong to one another |
| `tutorial/presentation/pages/tutorial_page.dart` | `initState` generation gating; `_next()` prefetch-exactly-one policy; `_confirmRedraw` confirmation before spend |
| `tutorial/presentation/controllers/*` | all — business state |
| `tutorial/presentation/widgets/tutorial_redraw_sheet.dart` | the confirmation itself is a cost control, not decoration |
| `tutorial/presentation/utils/tutorial_labels.dart` | label authority used by breakdown *and* tutorial; changing a string desynchronises two screens |
| `tutorial/domain/catalog/realized_look_filter.dart` | domain — category authority |
| `results/presentation/widgets/makeup_breakdown.dart` | must stay a pure renderer; its doc comment forbids adding filtering / grouping |
| `makeup_kit/presentation/pages/makeup_kit_recommendation_entry_page.dart` | `_RealizedKitBreakdown` — same `initState` gating |
| `shared/widgets/media/private_image.dart` | `cacheWidth` / `decodeMultiplier` decode budget; test-locked |
| `app/router/app_router.dart` | redirect logic and `TutorialPageArgs` typing; presentation of the `errorBuilder` may be polished |
| `settings/presentation/controllers/theme_mode_controller.dart` | theme is persisted business state |

### 13.3 Free to change

```text
lib/theme/**
lib/shared/widgets/**              (except private_image.dart decode logic)
lib/app/app.dart                   (theme wiring only)
lib/features/**/presentation/pages/**     visual structure only
lib/features/**/presentation/widgets/**   visual structure only
pubspec.yaml                       fonts / assets sections, with justification
assets/**
```

---

## 14. UI-P1 RECOMMENDED FILE BOUNDARY

UI-P1 is *Production Design System Foundation*. It must not touch feature screens.

**Modify:**

```text
lib/theme/app_tokens.dart          add: semantic surface tokens (info/success/warning/error
                                        surface + on-surface), typography scale constants,
                                        motion curves alongside AppDurations
lib/theme/app_theme.dart           adopt the shipped font; wire semantic tokens;
                                        page-transition theme; snackBarTheme; chipTheme;
                                        segmentedButtonTheme; listTileTheme
pubspec.yaml                       fonts: section (requires a licensing decision)
assets/fonts/**                    new
```

**Create:**

```text
lib/shared/widgets/feedback/app_notice.dart    the 22-site petal-banner pattern, with variants
lib/shared/widgets/content/detail_row.dart     the 4 duplicated label:value rows
lib/shared/widgets/media/color_swatch.dart     the 4 duplicated swatches, seeded from _ShadeChip
```

**Delete:**

```text
lib/shared/widgets/look_card.dart              dead code, zero references
```

**Touch only to re-export:**

```text
lib/shared/widgets/app_ui.dart                 add app_shell.dart + the three new components
```

**Explicitly NOT in UI-P1:** any file under `lib/features/`. Adopting the new components at call
sites belongs to UI-P2 (global states) and UI-P3/P4/P5 (feature screens). Creating `AppNotice`
and rewriting 22 call sites in the same phase would make the diff unreviewable and would put the
change inside `scan_page`'s error handling, which is exactly where a regression would be least
visible.

---

## 15. FILE BOUNDARY MAP — UI-P2 THROUGH UI-P7

### UI-P2 — App shell, navigation & global states

```text
lib/shared/widgets/app_shell.dart
lib/shared/widgets/feedback/status_state.dart      split into empty / error / info variants
lib/shared/widgets/feedback/loading_state.dart
lib/shared/widgets/feedback/skeleton_card.dart
lib/shared/widgets/overlays/app_overlays.dart      + a shared snackbar helper
lib/shared/widgets/surfaces/app_card.dart
lib/shared/widgets/layout/page_frame.dart          tokenise the 20/8/20/32 padding
lib/shared/widgets/buttons/*.dart                  add text-only / non-full-width variants
lib/app/router/app_router.dart                     errorBuilder presentation ONLY
```

### UI-P3 — Entry & creation flow

```text
lib/features/authentication/presentation/**        6 pages + 3 widgets  (§7.1 assets)
lib/features/home/presentation/pages/home_page.dart
lib/features/scan/presentation/pages/scan_page.dart          (§6.1 error surfaces)
lib/features/analysis/presentation/pages/analysis_result_page.dart
lib/features/makeup_styles/presentation/**
lib/features/makeup_kit/presentation/pages/recommendation_mode_selection_page.dart
lib/features/recommendation/presentation/**
lib/shared/widgets/media/beauty_image.dart          or delete with its asset
assets/images/beauty_portrait.png                   replace or remove
```

### UI-P4 — Results, history & My Makeup Kit

```text
lib/features/preview/presentation/pages/preview_result_page.dart   (§8.1 dead >=900 branch)
lib/features/results/presentation/widgets/*.dart                   5 widgets
lib/features/history/presentation/**
lib/features/saved_looks/presentation/**
lib/features/makeup_kit/presentation/pages/*.dart                  4 pages (§6.2 inputs)
lib/features/makeup_kit/presentation/widgets/*.dart                8 widgets
```

### UI-P5 — Tutorial presentation

```text
lib/features/tutorial/presentation/pages/tutorial_page.dart        (§7.2 exit affordance)
lib/features/tutorial/presentation/widgets/*.dart                  7 widgets
lib/features/tutorial/presentation/utils/tutorial_image_focus.dart
```

Frozen inside that boundary: controllers, `tutorial_labels.dart` string values, the `initState`
gating, prefetch policy, and the redraw confirmation's existence.

### UI-P6 — Responsive / accessibility / theme QA

```text
test/qa/responsive_layout_test.dart      extend from 3 screens to full inventory
test/qa/dark_mode_contrast_test.dart     extend
test/qa/  (new) text_scale_test.dart     currently absent entirely
+ targeted remediation of proven defects only
```

### UI-P7 — Baseline lock

```text
UI_P7_BASELINE_LOCK.md   (new)
+ minimal remediation of proven release-blocking UI defects only
```

---

## 16. SUMMARY RATINGS

| Area | Rating |
|---|---|
| Clean Architecture / feature-first structure | **PASS** |
| Riverpod business-state separation | **PASS** |
| Design-token existence and discipline | **PASS** |
| Hardcoded colour discipline | **PASS** |
| Light / Dark / System wiring | **PASS** |
| Dark-mode contrast (measured) | **PASS** |
| Touch-target sizing | **PASS** |
| Image decode / memory discipline | **PASS** |
| Analyzer + test suite health | **PASS** |
| Protected AI baseline integrity | **PASS** |
| Shared component coverage | **ACCEPTABLE** |
| Responsive breakpoint handling | **ACCEPTABLE** |
| Numeric-literal spacing / sizing | **ACCEPTABLE** |
| Overlay / dialog consolidation | **ACCEPTABLE** |
| Semantic error / success surfaces | **FAIL** |
| Loading-state consistency | **FAIL** |
| `StatusState` semantic overload | **FAIL** |
| Input-decoration consistency | **FAIL** |
| Swatch / detail-row duplication | **FAIL** |
| Typography (no shipped font) | **FAIL** |
| Motion system | **FAIL** |
| Text-scaling coverage outside Tutorial | **FAIL** |
| Semantics coverage outside Tutorial / Results | **FAIL** |
| Brand assets (entry screen, Google mark) | **FAIL** |
| Tutorial exit affordance | **FAIL** |
| Responsive test breadth | **FAIL** |
| Visual polish on a real device | **NOT TESTED** |
| Every screen's rendered appearance | **NOT TESTED** |

**No visual `PASS` is claimed anywhere in this document.** Nothing in this track has been seen
on a POCO X3 GT. Every `PASS` above is a code- or test-derived fact.

---

## 17. ASSUMPTIONS NOT PROVEN

1. That `FACETUNE_PRODUCTIONIZATION_*.md` are the documents the phase prompt means by
   `FACETUNE_UI_PRODUCTIONIZATION_*.md`. Their content matches; their filenames do not.
2. That the V4 device smoke described in `V4_QA_8_BASELINE_LOCK.md` §6.1 was completed. The
   document's header records a user report of POCO X3 GT PASS; no artefact in the repository
   confirms it independently.
3. That `GEMINI_IMAGE_MODEL` remains correctly set in the deployed project. Verified in V4-QA-8
   by digest comparison; not re-verified here (verifying it is a backend action).
4. That no screen has a rendering defect invisible to the analyzer and the widget tests. 19 of
   22 screens have no responsive test and none has a text-scale test.

---

## 18. MANUAL ACTION REQUIRED

1. **Resolve the authority-filename mismatch** (§0) — rename the two files or amend their
   internal references, before UI-P1's mandatory read order is executed again.
2. **Reconcile the branch name** (§1.0). `feature/ui-productionization` was created externally
   during this phase from the correct base `0a725be`. The authority documents name
   `feature/ui-productionization-v1`. Either rename
   (`git branch -m feature/ui-productionization feature/ui-productionization-v1`) or amend the
   documents. The base is already correct — do not re-branch from `main`.
3. **Decide the typeface** (§7.3) — UI-P1 cannot ship a font without a licensing decision.
4. **Decide the entry-screen art and the Google sign-in mark** (§7.1) — UI-P3 cannot invent
   brand assets.
5. **Publish a privacy policy** (§7.6) — release blocker, outside the UI track.
