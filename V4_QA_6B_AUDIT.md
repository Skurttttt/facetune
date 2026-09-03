# V4-QA-6B — Manifest ↔ Makeup Breakdown Consistency: Audit & Cost Measurement

**Branch:** `feature/step-by-step-tutorial-v4-ai` · **Baseline:** `85f5f71`
**Status:** audit complete, **implementation deliberately not started** — blocked on a
cost decision that requires a real number.
**Prompts/models/schema touched:** none.

---

## 1. The defect, and why it happens

Device QA on a Natural look: the tutorial shows 8 categories, the Makeup
Breakdown lists Contour/Bronzer as a 9th.

`MakeupBreakdown` renders the recommendation directly:

```dart
// lib/features/results/presentation/widgets/makeup_breakdown.dart:14
children: recommendation.items.entries.map(...)
```

`MakeupRecommendation` is the **intent**, produced by the recommendation call
*before* the canonical final preview exists. The tutorial filters through
`manifest.includedCategories`, the **realized look**. Two authorities, one
preview.

**The breakdown is not filtering incorrectly — it has never filtered at all.**

Same defect class in two more places:

- **History reopen** restores the recommendation and routes back through
  `PreviewResultPage`, rendering the identical unfiltered breakdown.
- **My Makeup Kit** entry page builds its breakdown from
  `recommendation.selections`, also unfiltered.

## 2. Manifest lifecycle

```text
PreviewResultPage renders          <- Makeup Breakdown here. NO MANIFEST YET.
        |
   user presses "Start Tutorial"
        |
TutorialPage.initState
  -> TutorialController.open()
  -> ResolveTutorialManifest
       |- sessions.loadForCanonicalPreview()   free read
       |- manifests.loadAccepted()             free read
       `- manifests.analyze()                  PAID, only if neither hit
        |
tutorial_v4_sessions + tutorial_v4_manifest_items persisted
        |
TutorialStepPlanner consumes manifest.includedCategories
```

`TutorialManifestRepository` deliberately separates `loadAccepted()` (never any
AI) from `analyze()` (paid), so reuse is already correct and cheap. The problem
is not reuse — it is that on a first visit **there is nothing to reuse**.

## 3. The blocker

Making the breakdown manifest-accurate on first render requires the manifest to
exist before the result page draws, which means analysing it at preview
generation — i.e. for **every** generated preview, including those whose
tutorial is never opened.

Per-preview call count does not change (1 → 1). What changes is the
**population**: from *previews whose tutorial is opened* to *all previews*.

```text
MULTIPLIER = previews generated / previews whose tutorial was opened
```

That number is not knowable from the code. `TutorialUsageTelemetry` is
in-memory per session and there is no product analytics in the repo — so it is
measured below from data already in the database.

---

## 4. Measurement

No instrumentation is required and none was added. The answer is already in
`tutorial_v4_sessions`, which records `manifest_prompt_version` only once an
analysis has actually completed.

Run in the **Supabase SQL editor** (service role bypasses RLS, giving global
counts). Returns aggregate integers only — no user ids, image paths, or
prompts.

```sql
with previews as (
  select id, 'standard'      as mode from public.generated_images
  union all
  select id, 'my_makeup_kit' as mode from public.kit_generated_images
),
analysed as (
  select distinct
    coalesce(canonical_generated_image_id, canonical_kit_generated_image_id)
      as preview_id
  from public.tutorial_v4_sessions
  -- Set only after an analysis completed, so this counts paid work, not
  -- sessions that merely exist.
  where manifest_prompt_version is not null
)
select
  coalesce(p.mode, 'ALL')                              as mode,
  count(*)                                             as previews_generated,
  count(a.preview_id)                                  as previews_analysed,
  count(*) - count(a.preview_id)                       as previews_never_analysed,
  round(100.0 * count(a.preview_id) / nullif(count(*), 0), 1)
                                                       as tutorial_open_rate_pct,
  round(1.0 * count(*) / nullif(count(a.preview_id), 0), 2)
                                                       as cost_multiplier
from previews p
left join analysed a on a.preview_id = p.id
group by rollup (p.mode)
order by mode;
```

**Reading the result.** `cost_multiplier` is the factor by which manifest
analysis spend would rise under Option C. `previews_never_analysed` is the
count of extra paid analyses that would have run historically.

> If `previews_generated` is small (early-stage project, mostly your own
> testing), the ratio is not yet representative of real users. Say so rather
> than treating it as a product metric.

## 5. Decision matrix

| Measured `cost_multiplier` | Reading | Suggested path |
|---|---|---|
| **≈ 1.0–1.5** | Most previews already lead to a tutorial. The extra spend is marginal. | **Option C** — analyse at preview generation. Fully fixes the defect, satisfies the count invariant. |
| **≈ 1.5–3** | A real but bounded increase. | Judgement call. Option C if breakdown accuracy matters more than the spend; otherwise the copy reframe. |
| **> 3** | Most previews never reach a tutorial; Option C multiplies manifest spend for no user benefit. | **Reframe the copy** — label the breakdown as the recommendation, name the tutorial as the authority for the realized look. Zero AI cost. |
| **Sample too small** | Not yet answerable. | Reframe the copy now (cheap, honest, reversible), revisit after real usage. |

### The option I recommend against either way

Filtering *only when a manifest happens to exist* would make the same screen
show 9 categories before the tutorial is opened and 8 after. That is less
trustworthy than today's consistently-wrong breakdown, and it fails the count
invariant non-deterministically.

## 6. What is already proven and ready to build on

Whichever path is chosen, the inclusion authority itself is settled and tested
(V4-QA-6, `manifest_multi_style_test.dart`): `manifest.includedCategories` is a
pure function of the verdicts, carries no style input, and no fixed-nine
behaviour exists. A shared inclusion abstraction for both consumers would reuse
that, not duplicate it.
