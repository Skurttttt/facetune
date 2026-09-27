# FaceTune Beauty
# Plan-Driven My Makeup Kit Pipeline
## Industry-Ready Source of Truth
### Version 1.0.0

**Track code:** PDMK  
**Track name:** Plan-Driven My Makeup Kit  
**Status:** Planned / not yet authorized for implementation  
**Primary objective:** Make My Makeup Kit reliably produce a reproducible Final Makeup Preview and Step-by-Step Tutorial using the products selected from the user's kit, while automatically preventing, detecting, and correcting AI inconsistencies **before the user reaches Tutorial**.

---

# 1. Executive goal

The user must not be exposed to internal disagreements between:

- the Makeup Kit recommendation,
- the immutable product snapshot,
- the Final Makeup Preview,
- the visual analyzer,
- and the Tutorial.

The industry-ready target is:

> **My Makeup Kit must operate from one canonical makeup plan. Recommendation, immutable product snapshot, Final Preview instructions, preview validation, and Tutorial grounding must all derive from that same plan. An inconsistent AI preview must be rejected or repaired before it becomes an accepted user-facing result.**

The normal user journey must be:

```text
Choose Style
↓
Choose My Makeup Kit
↓
Create Canonical Makeup Plan
↓
Generate Final Preview from that plan
↓
Validate Preview against that plan
↓
Repair / regenerate internally if inconsistent
↓
Persist only an accepted preview
↓
Tutorial is already eligible and grounded
↓
Show me how
↓
Step-by-Step Tutorial
```

`kit_preview_mismatch` remains a last-resort safety state. It must become exceptional, not a routine part of normal successful use.

---

# 2. Authority hierarchy

For this track, use the following authority order:

1. `CODEX_MASTER_GUIDE.md`
2. Existing protected FaceTune architecture and security contracts
3. Existing subscription / entitlement source-of-truth documents
4. Existing Tutorial V4 protected contracts
5. Existing My Makeup Kit protected lineage / snapshot contracts
6. This document
7. `FACETUNE_PLAN_DRIVEN_MAKEUP_KIT_PHASE_PROMPTS.md`
8. Accepted phase reports
9. Current implementation

If a lower authority conflicts with a higher authority:

```text
STOP
REPORT CONFLICT
DO NOT IMPROVISE
```

---

# 3. Mandatory engineering roles

Every phase must be executed as if the implementation team includes all of the following roles:

- Principal Software Architect
- Staff Software Engineer
- Principal Flutter Engineer
- Senior Flutter / Dart Developer
- Senior Riverpod State-Management Engineer
- Senior Android Engineer
- Senior Mobile Application Engineer
- Senior Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior RLS / Data-Security Engineer
- Senior AI Systems Engineer
- Senior Generative-AI Engineer
- Senior Prompt Engineer
- Senior AI Evaluation Engineer
- Senior ML Quality Engineer
- Senior Computer-Vision Evaluation Engineer
- Senior Reliability Engineer
- Senior Distributed-Systems Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior QA Automation Engineer
- Senior Integration-Test Engineer
- Senior E2E / Device-Test Engineer
- Senior Release Engineer
- Senior Production-Debugging Engineer
- Senior Code Reviewer
- Senior Product Engineer
- Makeup Workflow / Professional Makeup Domain Reviewer

No role may broaden scope independently. The source of truth remains authoritative.

---

# 4. Confirmed problem

Current My Makeup Kit behavior can create this sequence:

```text
User owns:
Foundation
Concealer
Eyeshadow
Blush
Highlighter
Lipstick

↓
Recommendation selects:
Eyeshadow
Blush
Highlighter
Lipstick

↓
Immutable snapshot correctly stores:
Eyeshadow
Blush
Highlighter
Lipstick

↓
Final Preview visually appears to include:
Foundation
Concealer
Eyeshadow
Blush
Highlighter
Lipstick

↓
Tutorial manifest detects:
Foundation = present, not product-backed
Concealer = present, not product-backed

↓
kit_preview_mismatch

↓
"No steps for this look"
```

The user did not cause this failure.

The system allowed multiple AI components to disagree and discovered the inconsistency too late.

---

# 5. Industry-ready architectural correction

The architecture must change from:

```text
GENERATE
↓
SHOW / PERSIST
↓
TUTORIAL ANALYZES
↓
MISMATCH DISCOVERED
↓
USER BLOCKED
```

to:

```text
LIVE MAKEUP KIT
↓
CANONICAL MAKEUP PLAN
↓
PLAN-DERIVED RECOMMENDATION
↓
IMMUTABLE PLAN / PRODUCT SNAPSHOT
↓
PLAN-CONSTRAINED PREVIEW GENERATION
↓
PRE-PERSIST PREVIEW VALIDATION
↓
ACCEPTED?
├─ YES → PERSIST ACCEPTED RESULT → TUTORIAL READY
└─ NO  → BOUNDED REPAIR / REGENERATION → VALIDATE AGAIN
```

The user should normally see only an accepted, reproducible look.

---

# 6. The canonical makeup plan

The canonical makeup plan is the authoritative representation of what the generated look is supposed to contain.

It must be:

- server-authored,
- immutable once accepted for the generation attempt,
- versioned,
- source-mode scoped to `my_makeup_kit`,
- grounded in eligible products the user actually owns,
- style-aware,
- reproducible,
- persistently linkable to recommendation, preview, and Tutorial,
- historically preserved.

The plan must not be inferred later from the image.

The image is generated **from the plan**.

---

# 7. Canonical makeup plan minimum contract

The exact storage design is determined in PDMK-1/PDMK-2, but the logical contract must contain at least:

```text
plan_id
plan_version
source_mode = my_makeup_kit
analysis_id
style_code
created_at

selected_items[]
  category_code
  tutorial_category
  product_id
  product_snapshot
  intended_role
  visible_intent
  application_intent

allowed_visual_categories[]
forbidden_visual_categories[]

recommendation_prompt_version
preview_prompt_version
validation_contract_version
```

Recommended meanings:

### `category_code`
Product-level category, for example:

- foundation
- concealer
- contour_bronzer
- blush
- highlighter
- eyebrow
- eyeshadow
- eyeliner
- lipstick
- lip_gloss

### `tutorial_category`
Tutorial-normalized category, for example:

- foundation
- concealer
- contour_bronzer
- blush
- highlighter
- eyebrows
- eyeshadow
- eyeliner
- lips

### `visible_intent`
At minimum:

- `required_visible`
- `subtle_allowed`

This prevents the validator from treating every selected cosmetic as equally visually obvious.

### `allowed_visual_categories`
The categories the preview is allowed to visibly contain.

### `forbidden_visual_categories`
Categories that must not be visually introduced because they are not part of the plan.

---

# 8. Plan creation rules

The plan generator must:

1. consider the selected style,
2. consider face-analysis context that is already authorized for recommendation,
3. consider only eligible products in the user's current Makeup Kit,
4. choose products that are appropriate for the intended look,
5. explicitly evaluate complexion categories,
6. include Foundation and Concealer when the intended look reasonably requires visible complexion coverage and suitable owned products exist,
7. evaluate Contour/Bronzer and Highlighter similarly,
8. not force complexion products into lighter looks where they are unnecessary,
9. never invent an unowned product,
10. never select a product merely to make Tutorial pass,
11. ensure every selected category has an intended role in the generated look,
12. define which categories are visually allowed and forbidden.

The plan must describe the makeup actually intended to appear in the Final Preview.

---

# 9. Plan-derived recommendation

The recommendation is no longer an independent AI opinion after plan creation.

For new PDMK looks:

> **The user-facing My Makeup Kit recommendation must be a presentation of the canonical makeup plan, not a second independently generated product set.**

This removes one source of disagreement.

The recommendation may contain explanatory text, order, reasons, or presentation metadata, but its selected product/category identity must derive from the plan.

---

# 10. Immutable product snapshot

The look-specific immutable product snapshot remains authoritative.

Hard rule:

> **The snapshot must represent the exact products in the accepted canonical plan.**

Do not:

- substitute the current live kit,
- retroactively add products,
- rewrite old looks,
- treat ownership as proof of use.

Historical content remains frozen to the snapshot/plan that created it.

---

# 11. Plan-constrained Final Preview generation

The My Makeup Kit preview generator must receive the canonical plan as authoritative input.

The generator must be told:

- apply only planned makeup categories,
- use the planned product/category intent,
- do not invent absent categories,
- do not create forbidden cosmetic effects through generic retouching,
- preserve identity,
- preserve protected image constraints,
- preserve natural skin characteristics where complexion products are absent.

Example:

```text
Foundation not in plan
→ do not create foundation-like global complexion coverage
→ do not cosmetically even skin tone
→ do not create foundation-like smoothing/airbrushing

Concealer not in plan
→ do not create localized concealer-like coverage
→ do not brighten/correct under-eyes as a cosmetic effect

Eyeliner not in plan
→ do not invent visible eyeliner
```

The protected Final Preview model remains:

```text
gemini-3.1-flash-image
```

unless separately authorized in a different source of truth.

---

# 12. Pre-persist preview validation

A new My Makeup Kit preview must not become an accepted user-facing result merely because image generation technically succeeded.

Before acceptance, validate:

```text
ORIGINAL SELFIE
+
CANONICAL MAKEUP PLAN
+
GENERATED CANDIDATE PREVIEW
```

The validator must answer:

1. Are planned `required_visible` categories visibly represented?
2. Are `subtle_allowed` categories at least not contradicted?
3. Is any forbidden/unplanned makeup category visibly present?
4. Does the candidate remain consistent with the plan?
5. Is the candidate safe to expose as a reproducible My Makeup Kit look?
6. Is the candidate suitable for Tutorial grounding?

The validator must be fail-closed.

A provider success response is not equivalent to an accepted preview.

---

# 13. Validation result contract

Recommended logical outcomes:

```text
accepted
retryable_mismatch
nonretryable_mismatch
validator_failure
provider_failure
```

### `accepted`
Candidate is consistent enough with the plan to persist and expose.

### `retryable_mismatch`
Candidate is visually inconsistent but can reasonably be regenerated with tighter constraints.

### `nonretryable_mismatch`
The plan itself is invalid, unsupported, or cannot be faithfully rendered under the current constraints.

### `validator_failure`
Validation could not produce a trustworthy decision.

### `provider_failure`
Generation/validation provider failed authoritatively.

No candidate with a failed validation result may be persisted as the accepted Final Preview.

---

# 14. Bounded automatic repair / regeneration

The system must automatically reconcile retryable inconsistencies.

Recommended default bound:

```text
Initial attempt: 1
Automatic repair/regeneration attempts: up to 2
Maximum candidate attempts per user preview request: 3
```

This exact bound must be verified against current provider cost and latency before production rollout.

The system must never loop indefinitely.

Each retry must use evidence from the prior mismatch to tighten the next generation request.

Example:

```text
Attempt 1:
Unplanned foundation detected

Attempt 2 prompt delta:
Foundation is explicitly forbidden by the plan.
Preserve natural complexion variation.
Do not smooth, even, cover, retouch, or brighten skin in a way that resembles
foundation.
```

Failed candidates must not become History/Saved Looks results.

---

# 15. Usage and billing invariant

Automatic internal correction must not punish the user for the model's own inconsistency.

Target invariant:

> **One user-authorized Final Preview request consumes the same user-facing AI Look / Preview entitlement that a normal successful request consumes, even if the server internally performs bounded retry attempts.**

Internal provider calls may increase provider cost, but they must not silently consume multiple user entitlements for one user action.

This track must preserve:

- reservation-time usage attribution,
- server-authoritative entitlements,
- reserve → generate → validate → persist → commit,
- release only on authoritative failure,
- AI Look vs Preview Credit separation,
- top-up accounting,
- plan limits.

If the current accounting architecture cannot safely support bounded internal retries under one reservation, stop in the designated design phase and report the conflict before implementation.

---

# 16. Persist only accepted results

For new PDMK flow:

```text
reserve
↓
create/freeze plan
↓
generate candidate
↓
validate candidate
↓
if retryable: repair/regenerate within bound
↓
accepted candidate only
↓
persist accepted preview + lineage + validation evidence
↓
commit usage
```

Intermediate failed candidates:

- must not appear in History,
- must not appear in Saved Looks,
- must not be treated as accepted previews,
- must not become Tutorial sources,
- must not overwrite historical accepted content.

---

# 17. Tutorial readiness must be established upstream

Tutorial must no longer be the normal place where plan mismatch is first discovered.

Before the accepted preview is exposed as tutorial-capable, the system must establish Tutorial readiness using:

```text
canonical plan
+
accepted preview
+
look-specific product snapshot
+
validated category evidence
```

The exact implementation may reuse existing Tutorial manifest infrastructure if doing so does not alter protected Standard Mode behavior.

The important invariant is:

> **A preview presented as a valid My Makeup Kit result should already have passed the reproducibility checks required for Tutorial.**

---

# 18. Tutorial behavior

Tutorial remains an independent safety layer.

For My Makeup Kit:

```text
present + product-backed
→ tutorial-capable

present + not product-backed
→ mismatch / block

absent
→ no step

uncertain
→ no step, no mismatch
```

However, under the new pipeline, an accepted preview should rarely reach Tutorial with an unbacked `present` category.

`kit_preview_mismatch` remains protected as a last defense.

Do not delete it.

Do not bypass it.

Do not use live-kit ownership as backing.

---

# 19. Tutorial generation

Once a PDMK preview is accepted:

- Tutorial grounding must use the same canonical plan and immutable snapshot.
- Tutorial must not invent unplanned products.
- Tutorial step order may be generated according to existing Tutorial V4 rules.
- Historical Tutorial sessions must remain historically stable.
- Existing Tutorial V4 protected versions must not be overwritten.

Whether full Tutorial steps are pre-generated immediately or generated on `Show me how` may remain an implementation optimization, **but eligibility/reproducibility must already be established before the user can reach a normal accepted preview state**.

---

# 20. Graceful fallback

If all bounded attempts fail, do not falsely tell the user:

> "This look uses makeup that is not in your kit yet."

when the actual problem is generation inconsistency.

Use a truthful user-facing state such as:

> **We couldn't create a reliable tutorial-ready version of this look. Your Makeup Kit is unchanged. Please try generating another preview.**

Exact copy is a UX phase decision.

The fallback must:

- preserve the user's kit,
- not blame missing products unless they are genuinely missing,
- not expose internal prompt/analyzer language,
- not persist a broken preview as accepted,
- not silently charge multiple user entitlements.

---

# 21. Hard locks — Standard Mode

PDMK is **My Makeup Kit only**.

Do not modify:

- Standard Mode recommendation prompt
- Standard Mode recommendation routing
- Standard Mode product selection
- Standard Mode Final Preview prompt
- Standard Mode Final Preview validation
- Standard Mode Tutorial eligibility
- Standard Mode Tutorial generation
- Standard Mode Tutorial UI
- Standard Mode History behavior
- Standard Mode Saved Looks behavior
- Standard Mode usage accounting

Shared code may be refactored only if behavior is proven identical and the change is explicitly authorized by a PDMK phase.

---

# 22. Hard locks — Tutorial V4

Do not casually modify:

- Tutorial V4 architecture
- `tutorial_guideline_v4_7`
- `tutorial_manifest_v4_1`
- `kit_preview_mismatch`
- product-backing semantics
- look-specific snapshot authority
- historical Tutorial sessions
- source-mode lineage

If analyzer false positives remain after upstream plan and preview alignment, a new additive version such as:

```text
tutorial_manifest_v4_2
```

may be designed only in a specifically authorized conditional phase.

Never overwrite `tutorial_manifest_v4_1`.

---

# 23. Hard locks — Final Preview

Do not modify:

- model `gemini-3.1-flash-image`
- fail-closed philosophy
- protected identity constraints
- protected storage privacy
- historical preview records
- reservation-time usage attribution
- server-side-only Gemini
- accepted-source lineage

A new additive My Makeup Kit prompt version may be introduced, for example:

```text
kit_makeup_preview_v2
```

Historical `kit_makeup_preview_v1` records remain unchanged.

---

# 24. Hard locks — subscription and entitlement system

Do not change:

- plan codes
- Free lifetime allowance semantics
- Plus / Pro / Salon Pro allowances
- Preview Credit semantics
- top-up semantics
- Salon Pilot accounting
- SUB-10 verify → activate → acknowledge
- SUB-11 RTDN / lifecycle / Restore
- entitlement resolution
- Google Play verification
- provider-authoritative subscription state

PDMK internal retry is an AI orchestration concern, not a subscription redesign.

---

# 25. Hard locks — security and privacy

Do not:

- expose Gemini/API secrets client-side,
- make Gemini calls from Flutter,
- bypass Edge/server authorization,
- weaken RLS,
- log private images,
- log signed URLs,
- log JWTs,
- log service-role keys,
- expose private beauty content to Web Admin,
- fetch user images during diagnosis without explicit authorization,
- persist failed candidate images longer than technically necessary unless current retention contracts require it.

---

# 26. Historical preservation

Old content remains governed by the versions that created it.

Never:

- rewrite old recommendations,
- rewrite old snapshots,
- regenerate old previews silently,
- rerun old Tutorial manifests silently,
- attach a new plan to an old look unless a separate migration is explicitly authorized,
- convert v1/v2 historical semantics into PDMK semantics.

Historical reproducibility is mandatory.

---

# 27. Versioning strategy

Existing protected/current versions may include:

```text
kit_makeup_recommendation_v2
kit_makeup_preview_v1
tutorial_manifest_v4_1
tutorial_guideline_v4_7
```

Planned PDMK versions should be additive.

Recommended names:

```text
kit_makeup_plan_v1
kit_makeup_recommendation_v3
kit_makeup_preview_v2
kit_preview_validator_v1
kit_tutorial_readiness_v1
```

Conditional only:

```text
tutorial_manifest_v4_2
```

Exact identifiers must be audited before implementation.

No existing prompt version may have its semantics overwritten.

---

# 28. Data model principle

Prefer the smallest durable schema that creates clear authoritative lineage.

The architecture must support:

```text
analysis
↓
style
↓
canonical makeup plan
↓
recommendation / snapshot
↓
accepted preview
↓
validation evidence
↓
Tutorial readiness / manifest
```

The implementation must not introduce duplicate competing sources of truth.

If current tables can safely store the canonical plan with immutable versioning, reuse may be preferable.

If they cannot, a minimal new table/column set may be proposed.

No schema mutation is authorized until the schema-design phase explicitly approves it.

---

# 29. Concurrency and idempotency

The PDMK pipeline must be safe under:

- double tap,
- network retry,
- app resume,
- duplicate server request,
- provider timeout,
- validator timeout,
- retry attempt replay.

Requirements:

- one logical user request must not create multiple committed usages,
- one plan must not drift across retries,
- retries must reference the same plan,
- accepted preview persistence must be idempotent,
- duplicate callbacks must not create duplicate accepted previews,
- interrupted flows must resume or fail safely.

---

# 30. Observability

Industry-ready behavior requires structured non-sensitive telemetry.

At minimum capture:

```text
request_id
plan_id
plan_version
recommendation_version
preview_prompt_version
validator_version
attempt_number
validation_outcome
mismatch_categories
accepted_attempt_number
tutorial_readiness_outcome
latency buckets
provider error class
```

Do not log:

- image bytes,
- full private prompts containing personal data,
- secrets,
- signed URLs,
- authentication tokens.

Telemetry must be sufficient to measure:

- retry rate,
- acceptance on first attempt,
- mismatch categories,
- terminal failure rate,
- Tutorial readiness rate,
- provider cost amplification.

---

# 31. Reliability targets

Before calling the pipeline production-ready, measure at minimum:

- first-attempt preview acceptance rate,
- acceptance within bounded retry rate,
- terminal reconciliation failure rate,
- Tutorial readiness rate for accepted previews,
- false block rate,
- retry latency,
- provider call amplification,
- entitlement correctness.

Do not invent numeric SLAs before controlled evaluation.

PDMK evaluation phases must propose thresholds based on evidence.

---

# 32. Quality evaluation matrix

Minimum style matrix:

### Glam / complexion-likely
- Soft Glam
- Party
- Date Night
- Bridal
- Full Glam

### Lighter / control
- Natural
- Everyday
- Office

Minimum kit composition matrix:

- complete kit
- no Foundation
- no Concealer
- no Foundation and no Concealer
- no Contour/Bronzer
- no Highlighter
- multiple Foundations
- multiple lip products
- minimal eligible kit

---

# 33. Acceptance principles

A successful accepted preview must satisfy all of the following:

1. The plan is valid.
2. Every selected product is owned/eligible.
3. The immutable snapshot matches the plan.
4. The preview is generated from the plan.
5. The preview contains no material forbidden/unplanned makeup.
6. Required-visible planned categories are represented sufficiently.
7. Validation is accepted.
8. Tutorial readiness is established.
9. User entitlement is committed exactly once.
10. Historical records remain untouched.

---

# 34. Prohibited shortcuts

Never solve PDMK by:

- treating the entire live kit as Tutorial backing,
- auto-including every owned cosmetic,
- hard-coding Foundation/Concealer into every glam style,
- ignoring mismatch categories,
- disabling `kit_preview_mismatch`,
- accepting provider success as preview success,
- persisting failed candidates as final results,
- charging the user for each internal retry,
- changing Standard Mode,
- changing the Final Preview model,
- overwriting historical prompt versions,
- raising/lowering confidence thresholds blindly,
- marking ambiguous categories absent just to pass validation,
- allowing Flutter to decide server-authoritative makeup plan truth,
- making Tutorial infer missing products from the live kit,
- retrying indefinitely.

---

# 35. Git / branch safety

Known protected checkpoint:

```text
WA-15:
00090928daecdbcce7fbe37451710c3f21ea01ea
```

Known backup:

```text
backup/wa15-complete-20260927
```

Known My Makeup Kit preview-lineage branch:

```text
fix/my-makeup-kit-preview-lineage
```

Before PDMK source implementation begins:

- the preview-lineage fix must be checkpointed or explicitly adopted as baseline,
- the working tree state must be recorded,
- PDMK work must use a separate authorized branch or clean checkpoint,
- no destructive Git command is authorized by this source of truth.

---

# 36. Phase model

```text
PDMK-0   Baseline, authority, and checkpoint gate
PDMK-1   Canonical Makeup Plan architecture + contract design
PDMK-2   Persistence / schema / lineage design
PDMK-3   Plan generator + Recommendation V3 implementation
PDMK-4   Plan-constrained Preview V2 implementation
PDMK-5   Pre-persist Validator V1 implementation
PDMK-6   Bounded repair/regeneration orchestrator
PDMK-7   Tutorial readiness bridge
PDMK-8   Automated regression + security + accounting validation
PDMK-9   Controlled AI evaluation plan
PDMK-10  Controlled live AI evaluation
PDMK-11  Conditional analyzer refinement only if evidence requires it
PDMK-12  Real-device / end-to-end / failure UX QA
PDMK-13  Production-readiness review and checkpoint readiness
```

No phase auto-starts the next phase.

Every phase ends with:

```text
REPORT
STOP
```

---

# 37. Conditional analyzer gate

`PDMK-11` is conditional.

It may run only if:

1. the canonical plan is correct,
2. the preview generator is plan-constrained,
3. preview validation evidence shows the candidate is visually faithful,
4. Tutorial/manifest analysis still repeatedly false-detects absent categories.

Only then may a new additive analyzer version be considered.

PDMK-11 must not be used to hide an unresolved generator defect.

---

# 38. Definition of done

PDMK is complete only when:

- one canonical makeup plan governs each new My Makeup Kit generation,
- recommendation derives from the plan,
- snapshot equals the plan,
- preview is generated from the plan,
- preview is validated before acceptance,
- retryable inconsistencies are automatically reconciled within a bounded attempt count,
- only accepted previews are persisted as final results,
- Tutorial readiness is established upstream,
- `kit_preview_mismatch` remains as last-resort safety,
- Standard Mode is unchanged,
- Standard Tutorial is unchanged,
- historical looks are unchanged,
- AI Look / Preview usage is committed once per logical user request,
- RLS/privacy/security remain intact,
- idempotency/concurrency tests pass,
- controlled AI evaluation passes,
- real-device QA passes,
- graceful fallback is truthful,
- no hidden multiple charging occurs,
- no unbounded AI loop exists.

---

# 39. Final product principle

FaceTune must not ask the user to debug its AI pipeline.

The product contract is:

> **The user chooses a look and supplies a kit. FaceTune creates one authoritative makeup plan, renders that plan, verifies that the result matches the plan, repairs model inconsistency internally when reasonable, and only then presents a tutorial-ready result.**
