# TUT-UI-0 — Tutorial UI Baseline Audit & Protected Surface Map

Date: 2026-09-05
Branch: `feature/live-scan-educational-palette` (verified)
HEAD: `786c9dc74215d8fb2cb6affd8c587a9b3ca29f8c` — *Take photo UI pass*
Phase type: **READ-ONLY.** No product code, no test, no configuration, and no
backend file was modified. This document is the only artifact created.

---

## 1. Git state

```text
BRANCH            feature/live-scan-educational-palette   ✔ matches required
HEAD BEFORE       786c9dc  Take photo UI pass
HEAD AFTER        786c9dc  Take photo UI pass             (unchanged)
git diff          empty  (no unstaged modifications)
git diff --cached 6 files, +2338 / −254
```

### Working-tree ownership — FLAGGED, NOT OWNED BY THIS TRACK

Six files are **staged but uncommitted**, and none of them belongs to the
Tutorial UI track:

| Staged file | Track |
| --- | --- |
| `lib/features/scan/presentation/pages/scan_page.dart` | LSEP (Take-photo UI) |
| `lib/features/recommendation/presentation/pages/makeup_recommendation_page.dart` | LSEP (educational palette) |
| `lib/features/recommendation/presentation/widgets/recommendation_item_card.dart` | LSEP (educational palette) |
| `test/features/scan/scan_entry_page_test.dart` (new) | LSEP |
| `test/features/recommendation/educational_palette_page_test.dart` | LSEP |
| `test/widget_test.dart` | LSEP |

Plus two untracked files: this track's own
`FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_SOURCE_OF_TRUTH.md` and
`FACETUNE_TUTORIAL_UI_PRODUCTIONIZATION_PHASE_PROMPTS.md`.

Nothing was reset, stashed, restored, checked out, or committed. **No tutorial
file is in the staged set**, so TUT-UI-1 can proceed on disjoint files — but the
user should decide whether to commit the LSEP work first, so a later tutorial
diff is not entangled with it.

---

## 2. Protected surface map — exact paths and ownership

Every tutorial surface is presentation-only Dart under
`lib/features/tutorial/presentation/`. There is **exactly one** tutorial page in
the codebase; no separate My Makeup Kit tutorial page exists.

| Surface | Owning source | Notes |
| --- | --- | --- |
| **TUTORIAL SHELL** | `presentation/pages/tutorial_page.dart` — `TutorialPage` (52), `_TutorialPageState` (65), `_TutorialBody` (167) | `Scaffold` + raw `AppBar` + `SafeArea(PageFrame(ListView))`. One shell, both modes. |
| **PROGRESS HEADER** | `tutorial_page.dart` — `_StepProgressHeader` (450) | Private widget. Counter + `LinearProgressIndicator`, reflows to a column at large text. |
| **GUIDE HERO** | `tutorial_page.dart` — `_GuidelineView` (332) | `AspectRatio 3/4` + `PrivateImage`; owns loading / failed / retry states. |
| **TAP TO ENLARGE** | `tutorial_page.dart` — `_EnlargeHint` (541), tap target keyed `guidelineViewerTapKey` (28) | Chip over a 68 % black scrim, bottom-left, `ExcludeSemantics`. |
| **GUIDE KEY** | `presentation/widgets/tutorial_guide_key.dart` — `TutorialGuideKey` | `surfaceContainerHighest` panel, `Wrap` of glyph + name. Renders only `instructions.referencedGuideTypes`. |
| **REDRAW** | `tutorial_page.dart` `_confirmRedraw` (273) + `presentation/widgets/tutorial_redraw_sheet.dart` | `TertiaryButton`, **last child of the scroll list** (line 255). |
| **HOW TO APPLY** | `presentation/widgets/tutorial_instructions_card.dart` — `TutorialInstructionsCard` + `_InstructionRow` | One `AppCard` holding both How-to-apply and Your-goal. |
| **GOAL** | Same card; text sourced in `tutorial_page.dart` `_goal()` (288) | Standard: first non-empty `StandardLookEntry.reasoning`. My Kit: always `null` by design. |
| **STANDARD RECOMMENDATION SECTION** | `presentation/widgets/tutorial_product_cards.dart` — `StandardProductCard` (126) | Plain `AppCard`. Rows: Shade, **Hex**, Finish, Intensity, **Where to apply**, **Technique**. |
| **MY KIT RECOMMENDATION SECTION** | Same file — `MyMakeupKitProductCard` (205) | **Tinted** `AppCard(color: AppTone.info.surface)` + inventory icon + count in title. Rows: product name, Shade, **Hex**, Finish, Depth, Undertone. |
| **FINAL LOOK** | `presentation/widgets/tutorial_final_look_card.dart` — `TutorialFinalLookCard` | Two presentations of one artifact: compact row (54×72 thumb) and `expanded: true` full 3/4 image. |
| **FULLSCREEN VIEWER** | `presentation/widgets/tutorial_image_viewer.dart` — `TutorialImageViewer` | `MaterialPageRoute(fullscreenDialog: true)`, `InteractiveViewer` 1–5×, category focus from `utils/tutorial_image_focus.dart`. |
| **FOOTER / NAVIGATION** | `tutorial_page.dart` `_controls()` (298) | `SecondaryButton` Back + `PrimaryButton` Next/Finish. **Inside the `ListView`, not `Scaffold.bottomNavigationBar`.** |
| **FINAL-STEP SPECIAL CASE** | `tutorial_page.dart` lines 215–218 and 240–243 | Non-final steps get the compact card *above* the instructions; the final step instead gets `expanded: true` *below* the recommendation. |
| **EXIT (top X)** | `tutorial_page.dart` lines 155–161 | Raw `AppBar` + `Icons.close_rounded` → `Navigator.maybePop()`. **Does not use `FaceTuneTopBar`.** |
| **COPY** | `presentation/utils/tutorial_labels.dart` | Every user-facing string; no copy is inlined in a widget. |
| **ORCHESTRATION** | `presentation/controllers/tutorial_controller.dart`, `tutorial_state.dart` | `StateNotifier`. **Protected — presentation phases must not touch.** |
| **PROVIDERS** | `data/providers/tutorial_providers.dart` | Plain `Provider` / `StateNotifierProvider` deliberately, so watching starts no paid work. **Protected.** |

### Entry points (two callers, one page)

| Caller | Ref constructed |
| --- | --- |
| `lib/features/preview/presentation/pages/preview_result_page.dart:135` | `CanonicalPreviewRef.standard(result.preview.id)` |
| `lib/features/makeup_kit/presentation/pages/makeup_kit_recommendation_entry_page.dart:113` | `CanonicalPreviewRef.myMakeupKit(preview!.id)` |

Both `context.push(AppConstants.tutorialRoute, extra: TutorialPageArgs(...))`;
the single `GoRoute` is `lib/app/router/app_router.dart:141-155`.

**History / reopen:** `history_page.dart:467` restores a Standard look and pushes
`previewRoute`; `history_page.dart:478` (`_openKit`) restores a kit look and
pushes `makeupKitRecommendationEntryRoute`. Each screen then offers its own
"Show me how" CTA into the same `TutorialPage`. Reopen costs nothing —
`TutorialController.open` short-circuits on `_opened`, and
`TutorialSession.hasReusableManifest` reuses the accepted manifest.

---

## 3. Hard locks — proven from current source

| Lock | Required | Proven at |
| --- | --- | --- |
| Final preview model | `gemini-3.1-flash-image` | `supabase/functions/_shared/final_preview_model.ts:12` — `export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image";` (fails closed on any other `GEMINI_IMAGE_MODEL`). Guarded by `test/features/preview/final_preview_model_lock_test.dart:57`. |
| Tutorial guideline model | `gemini-3.1-flash-image` | `supabase/functions/_shared/tutorial_ai_config.ts:24-25` — `GEMINI_TUTORIAL_MODEL` env, fallback **is** the locked model. |
| Tutorial resolution | `1K` | `tutorial_ai_config.ts:33` — `export const TUTORIAL_OUTPUT_RESOLUTION = "1K" as const;` Client mirror: `TutorialAiConfiguration.defaultOutputResolution = TutorialOutputResolution.oneK`. |
| Tutorial prompt | `tutorial_guideline_v4_7` | `tutorial_ai_config.ts:87`; asserted in `generate-tutorial-step-v4/prompt_test.ts:180` and `category_prompts_test.ts:128`. |
| Manifest prompt | `tutorial_manifest_v4_1` | `supabase/functions/analyze-tutorial-manifest-v4/prompt.ts:1`. |
| Manifest analyzer model | `gemini-3.6-flash` (multimodal, *not* the image renderer) | `analyze-tutorial-manifest-v4/index.ts:126-127`. Distinct responsibility; not the "tutorial model" the SoT locks. |
| Guide semantics | `● ━ - - →` | `domain/entities/tutorial_guide_type.dart` — `startAnchor('start_anchor','●')`, `placementBoundary('placement_boundary','━')`, `blendZone('blend_zone','- -')`, `direction('direction','→')`. |
| No hardcoded step count | — | `TutorialViewState.stepCount => categories.length`, from `manifest.includedCategories`. No literal `9` anywhere in `lib/features/tutorial`. |
| No hardcoded Lips-last | — | `isLastStep => stepCount > 0 && currentIndex == stepCount - 1` (`tutorial_state.dart:152`). No `TutorialCategory.lips` comparison exists in `presentation/` outside display-name and image-focus switches. |
| Category order | deterministic, AI never chooses | `TutorialCategory.order` 1–9 + `orderedSubset()`; `TutorialManifest.includedCategories` filters then sorts. |
| No paid work from `build()` | — | Generation is started from `initState` → `addPostFrameCallback` (`tutorial_page.dart:67-80`). Providers are `Provider`/`StateNotifierProvider`, never `FutureProvider` — commented as deliberate in `tutorial_providers.dart:53-57` and `:88-92`. |

---

## 4. Standard / My Makeup Kit parity classification

| Surface | Classification | Evidence |
| --- | --- | --- |
| Tutorial shell | **IDENTICAL** | One `TutorialPage`; mode never branches the scaffold. |
| Progress header | **IDENTICAL** | `_StepProgressHeader` takes only ints. |
| Guide hero + tap-to-enlarge | **IDENTICAL** | `_GuidelineView` reads no mode. |
| Guide key | **IDENTICAL** | Driven by category instructions, not mode. |
| Redraw | **IDENTICAL** | Same button, same sheet, same confirmation. |
| How to apply | **IDENTICAL** | `TutorialInstructionCatalog.forCategory(category)` — category-keyed, mode-independent. |
| Your goal | **DATA-AUTHORITY DIFFERENT AS EXPECTED** | `_goal()` reads `standardEntriesFor(...)`, which `ValidatedLookPlan` returns empty for `MyMakeupKitLookPlanSource`. A kit step shows no goal by design. |
| Recommendation section | **VISUALLY DIFFERENT** | Standard = plain `AppCard`, heading "Suggested shades". Kit = tinted `AppTone.info.surface` card + `Icons.inventory_2_outlined` + "From your kit (n products)". Different field sets *and* different surfaces. **This is the single largest parity gap.** |
| Final look (compact and expanded) | **IDENTICAL** | Same widget, same signed URL, no mode branch. |
| Fullscreen viewer | **IDENTICAL** | One `TutorialImageViewer`. |
| Footer / navigation | **IDENTICAL** | `_controls()` reads no mode. |
| Final-step special case | **IDENTICAL** | Same `isLastStep` branch for both. |
| Exit (top X) | **IDENTICAL** | Same `AppBar`. |

**No cross-authority leak found.** `standardEntriesFor` returns `const []` for a
kit plan, and `productSnapshot` returns `LookProductSnapshot.empty` for a
Standard plan — both by exhaustive `switch` on a sealed `LookPlanSource`, so the
mode cannot be inferred from a nullable field. The apparent "fallback" at
`tutorial_page.dart:228-231` falls back from the *step's* snapshot items to the
*session's* snapshot items — two views of the same immutable kit snapshot, never
Standard data.

---

## 5. Gaps against the Tutorial UI Source of Truth

Read as the work TUT-UI-1…6 exists to do, not as defects in the accepted V4
system.

| SoT | Requirement | Current state |
| --- | --- | --- |
| §12, §29 | Footer persistent in reserved layout space | **NOT MET.** `_controls()` is child #16 of the `ListView` (`tutorial_page.dart:245`); Back/Next scroll away. The app already has the correct pattern — `ResultBottomCta` in `Scaffold.bottomNavigationBar` (`results/presentation/widgets/result_shell.dart:192`), used by both result screens. |
| §28 | Final step must not show a giant second Final Look | **NOT MET.** `tutorial_page.dart:240-243` renders `TutorialFinalLookCard(expanded: true)`. The widget's own doc-comment defends this as intentional QA-5 behaviour — a documented conflict the SoT overrides. |
| §17 | Compact "Guide key" | **PARTIAL.** Already compact and correctly filtered, but the heading is `'What the guides mean'` (`tutorial_labels.dart:28`) and it is a tinted panel, not inline content. |
| §18 | Redraw near the guide, labelled "Redraw guide" | **NOT MET.** It is the last element on the page; label is `'Draw this step again'` (`tutorial_labels.dart:37`). Placement only — every business guard already satisfies §18's preservation list. |
| §22, §24 | Shade/swatch/finish/intensity primary; hex not primary | **NOT MET.** `_hexDetailRow` renders a labelled "Hex" row with the raw string in **both** cards (`tutorial_product_cards.dart:88-119`). |
| §23 | Label "From your makeup kit" | **NOT MET.** `'From your kit'` / `'From your kit (n products)'`. |
| §25 | No duplicate Where-to-apply / Technique in the recommendation section | **NOT MET.** `StandardProductCard` lines 168-191 render both. **See §6 — removing them is not free.** |
| §26 | Fewer giant cards | **PARTIAL.** Current rhythm on a non-final step: guide-key panel → final-look card → instructions card → product card (+ a second expanded final look on the last step). |
| §19 | How-to as an editorial numbered rail | **PARTIAL.** Already numbered, ordered, and symbol-linked with correct semantics — it is a card, not a rail. |
| §32 | Reuse global components | **PARTIAL.** The page builds a raw `AppBar` instead of `FaceTuneTopBar` (`tutorial_page.dart:155`), so the tutorial is the one route-level screen outside the shared top-bar system. |
| §14 | Progress header compact, runtime counts | **MET.** |
| §15, §16 | Guide hero, tap to enlarge, viewer | **MET.** |
| §27 | Compact reusable Final Look on every step | **MET** for non-final steps. |

---

## 6. Documentation conflicts to resolve before TUT-UI-3 / TUT-UI-4

These are places where the Source of Truth and the code disagree. Per §41,
they are reported rather than silently resolved.

**(a) How-to-apply copy is not Gemini text.** SoT §19-§20 govern "accepted
tutorial instruction text" and forbid Flutter from rewriting or summarising it.
In the actual system, `TutorialStep` carries **no instruction field**, the DTO
layer parses none, and the numbered instructions come from
`domain/catalog/tutorial_instruction_catalog.dart` — a static Dart catalog
describing the *guide vocabulary* per category, deliberately look-agnostic. §20
therefore has no runtime subject today. Restyling How-to-apply is safe; there is
no Gemini prose to preserve or truncate.

**(b) §25 would delete the only look-specific placement wording.** Because of
(a), `StandardLookEntry.placement` and `.technique` are the *only* per-look
"where / how" text the tutorial has. Removing them from the recommendation card
without moving them into the How-to-apply rail would lose authoritative content
rather than de-duplicate it — and the two are not actually duplicates: the rail
is generic-per-category, the recommendation rows are specific-per-look. Note
also that My Kit has no equivalent fields, so any move affects parity.
**Recommend explicit direction from the user before TUT-UI-4.**

**(c) §28 contradicts the accepted QA-5 rationale** recorded in
`tutorial_final_look_card.dart:21-25`. The SoT is the higher authority for
presentation, so §28 governs — recorded here so the change is a decision, not an
accident. Note `test/features/tutorial/tutorial_page_test.dart:598` ("the last
step shows the existing final look") and `tutorial_viewing_experience_test.dart:305`
("the expanded form shows the same single artifact") assert the current
behaviour and will need updating with it.

---

## 7. Minimum file set likely touched by later phases

Presentation only. No domain, repository, controller, provider, or backend file
appears in this list.

| Phase | Likely files |
| --- | --- |
| TUT-UI-1 shell + persistent footer | `pages/tutorial_page.dart`; new `widgets/tutorial_bottom_navigation.dart`; possibly `FaceTuneTopBar` adoption |
| TUT-UI-2 hero + key + redraw | `pages/tutorial_page.dart`, `widgets/tutorial_guide_key.dart`, `utils/tutorial_labels.dart` |
| TUT-UI-3 how-to rail + goal | `widgets/tutorial_instructions_card.dart`, `utils/tutorial_labels.dart` |
| TUT-UI-4 recommendation parity | `widgets/tutorial_product_cards.dart`, `utils/tutorial_labels.dart` |
| TUT-UI-5 final look | `widgets/tutorial_final_look_card.dart`, `pages/tutorial_page.dart` |
| TUT-UI-6 polish / a11y | any of the above |

Tests that will need updating alongside: `test/features/tutorial/tutorial_page_test.dart`
(1308 lines), `tutorial_instructional_ux_test.dart`, `tutorial_viewing_experience_test.dart`,
`tutorial_redraw_feedback_test.dart`, `test/qa/full_app_matrix_test.dart`.

Reuse targets already in the shared system: `AppCard`, `PageFrame`,
`PrimaryButton` / `SecondaryButton` / `TertiaryButton`, `StatusState`,
`LoadingState`, `PrivateImage`, `AppColorSwatch`, `SectionHeader`,
`FaceTuneTopBar`, `AppSpacing` / `AppRadii` / `AppIconSizes`, `AppTone`, and the
`ResultBottomCta` footer pattern.

---

## 8. Validation

```text
flutter analyze        No issues found! (8.6s)              PASS
flutter test           +1500: All tests passed! (1m 09s)    PASS
git diff -- supabase/  empty                                NO BACKEND CHANGES
git diff --cached -- supabase/  empty                       NO BACKEND CHANGES
```

No paid AI was generated for this audit. No APK was built — this phase changed
no product code, so a debug build would prove nothing the analyzer and the suite
do not already prove.

**REAL DEVICE STATUS: PENDING USER / DEVICE VERIFICATION.** No device or emulator
was used. Nothing in this document claims visual quality; §5 records structural
gaps read from source, not screenshots.

---

## 9. Privacy

No user image, selfie, signed URL, storage path, product name, brand, kit
contents, user id, session id, or secret value appears in this document. Model
names, prompt versions, and file paths are configuration and code identifiers,
not user data. No secret was read or printed.
