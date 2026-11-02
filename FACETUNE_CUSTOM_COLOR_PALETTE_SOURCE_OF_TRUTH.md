# FaceTune Beauty
# Custom Color Palette Recommendation Track
## Industry-Ready Source of Truth
### Version 1.0.0

**Track code:** CCP  
**Track name:** Custom Color Palette  
**Status:** Planned / not yet authorized for implementation  
**Primary objective:** Add a third recommendation mode that lets the user define the makeup colors, adjusted shades, and applicable finishes that must govern the recommendation, Final Makeup Preview, Tutorial grounding, History/Saved Looks, and variation behavior without changing Standard Recommendation or My Makeup Kit semantics.

---

# 1. Executive goal

FaceTune currently has protected recommendation behavior that must remain stable. The Custom Color Palette revision is an **additive third recommendation mode**, not a redesign of Standard Recommendation and not an extension of My Makeup Kit.

The product contract is:

> **The user chooses a makeup style and explicitly controls the supported makeup colors, shade adjustments, and applicable finishes. FaceTune must preserve those selections as authoritative constraints for the new Custom Color Palette mode. AI may determine application guidance such as placement, blending, and technique, but it must not silently replace the user's selected palette with a different palette.**

The intended user journey is:

```text
Facial Analysis
↓
Select Makeup Style
↓
Choose Recommendation Mode
├─ Standard Recommendation
├─ My Makeup Kit
└─ Custom Color Palette
      ↓
   Customize Supported Categories
      ↓
   Choose Color
      ↓
   Adjust Shade
      ↓
   Choose Applicable Finish
      ↓
   Review Palette
      ↓
   Generate Custom Palette Recommendation
      ↓
   Generate Final Makeup Preview
      ↓
   Step-by-Step Tutorial
      ↓
   History / Saved Looks / Variation preserve the same palette lineage
```

---

# 2. Authority hierarchy

For the CCP track, use this authority order:

1. `CODEX_MASTER_GUIDE.md`
2. Current repository evidence on the authorized implementation branch/worktree
3. Existing protected FaceTune architecture and security contracts
4. Existing subscription / entitlement source-of-truth documents
5. Existing Final Preview protected contracts
6. Existing Tutorial V4 protected contracts
7. Existing Standard Recommendation protected behavior
8. Existing My Makeup Kit protected behavior and lineage contracts
9. This document
10. `FACETUNE_CUSTOM_COLOR_PALETTE_PHASE_PROMPTS.md`
11. Accepted CCP phase reports
12. Historical handoff/context that is not contradicted by repository evidence

If a lower authority conflicts with a higher authority:

```text
STOP
REPORT CONFLICT
DO NOT IMPROVISE
```

Repository evidence wins over stale handoff assumptions.

---

# 3. Mandatory engineering roles

Every CCP phase must be executed as if the implementation team includes:

- Principal Software Architect
- Staff Software Engineer
- Principal Flutter Engineer
- Senior Flutter / Dart Developer
- Senior Riverpod State-Management Engineer
- Senior Mobile Application Engineer
- Senior Android Engineer
- Senior Backend Engineer
- Senior Supabase Engineer
- Senior PostgreSQL Engineer
- Senior RLS / Data-Security Engineer
- Senior AI Systems Engineer
- Senior Generative-AI Engineer
- Senior Prompt Engineer
- Senior AI Evaluation Engineer
- Senior Reliability Engineer
- Senior Distributed-Systems Engineer
- Senior Application Security Engineer
- Senior Privacy Engineer
- Senior QA Automation Engineer
- Senior Integration-Test Engineer
- Senior E2E / Real-Device Test Engineer
- Senior Release Engineer
- Senior Production-Debugging Engineer
- Senior Code Reviewer
- Senior Product Engineer
- Senior UX / HCI Reviewer
- Makeup Workflow / Professional Makeup Domain Reviewer

No role may broaden scope independently.

---

# 4. Revision boundary

CCP adds exactly one new recommendation mode:

```text
source_mode = custom_color_palette
```

It must coexist with:

```text
standard
my_makeup_kit
custom_color_palette
```

The exact existing source-mode identifiers must be audited before implementation. Do not rename existing identifiers merely to match this document.

CCP does **not**:

- convert Standard Recommendation into a user-controlled palette flow,
- convert My Makeup Kit into a color-only flow,
- require users to own products matching the chosen colors,
- create a product catalog,
- create a salon booking system,
- redesign subscriptions,
- create new Web Admin content-management capabilities.

Revision 2 / Booking is outside this track.

---

# 5. Core user-control invariant

For Custom Color Palette:

> **User-controlled visual choices are authoritative.**

The user controls, for every supported selected makeup category:

- selected color,
- final adjusted shade/color value,
- applicable finish.

The AI may control:

- placement,
- blending,
- application order where not otherwise protected,
- technique,
- descriptive guidance,
- reasonable visual intensity required to render the selected color while preserving the selected palette.

The AI must not:

- replace red lipstick with pink because it considers pink more suitable,
- replace violet eyeliner with black,
- replace orange blush with peach,
- change matte lipstick to glossy,
- introduce an unselected finish as if it were selected,
- invent unsupported palette categories,
- silently ignore a valid selected category.

---

# 6. Supported-category rule

The exact supported makeup categories must be discovered from the current repository and protected Tutorial/recommendation category contracts during CCP-1.

Examples discussed for product intent include:

- lipstick / lips,
- blush,
- eyeliner,
- eyeshadow.

These examples are **not authority to invent new categories**.

Hard rule:

> CCP may expose only categories that the current FaceTune system can consistently represent across recommendation, preview, and Tutorial or that are explicitly approved as an additive CCP category during the design phase.

---

# 7. Finish taxonomy rule

Applicable finishes may include concepts such as:

- matte,
- glossy,
- satin,
- shimmer,
- metallic.

However, the final allowed finish set must be audited and normalized in CCP-1.

Rules:

- finishes are category-aware,
- not every finish applies to every category,
- the UI must not show nonsensical combinations,
- finish identifiers must be stable machine values,
- display labels may be user-friendly,
- AI prompt text must derive from normalized finish identifiers,
- historical palette records must preserve the finish selected at generation time.

No finish enum may be finalized from this document alone without repository/domain audit.

---

# 8. Color representation rule

The color picker and color adjuster must produce a durable normalized color value.

The CCP contract should preserve enough information to reproduce the user's final selection. The minimum logical representation should support:

```text
base_color
adjusted_color
user-visible color label if applicable
adjustment metadata if needed for UI reconstruction
```

The exact storage format is determined in CCP-2.

Recommended design principle:

- use one canonical machine-readable final color value as the authoritative color,
- preserve user-facing label only as presentation metadata,
- preserve adjustment parameters only if needed to reconstruct/edit the UI,
- never make an ambiguous natural-language color name the sole source of truth.

If the current Flutter color system already has a stable representation, prefer reuse.

---

# 9. Canonical Custom Palette contract

CCP requires one authoritative immutable palette configuration for each logical generated look.

The logical contract must include at least:

```text
palette_id
palette_version
source_mode = custom_color_palette
user_id / owner lineage
analysis_id
style_code
created_at

category_selections[]
  category_code
  selected / enabled
  base_color_value
  adjusted_color_value
  color_label (optional presentation metadata)
  finish_code (nullable only where finish is not applicable)
  adjustment_metadata (optional, if needed for editing/reconstruction)

recommendation_contract_version
preview_prompt_version
validation_contract_version
tutorial_grounding_version
```

The exact field names and persistence model must be derived from repository evidence in CCP-1/CCP-2.

---

# 10. Palette immutability and lineage

For one logical generation:

- palette configuration is frozen before AI recommendation generation,
- recommendation must derive from that frozen palette,
- Final Preview instructions must derive from that same frozen palette,
- Tutorial grounding must derive from that same frozen palette,
- History and Saved Looks must reference/preserve the same palette snapshot,
- Generate Another Variation reuses the same frozen palette unless the user explicitly edits it first,
- retries must not silently mutate the palette to obtain a provider success.

A new palette edit creates a new logical palette version/request rather than rewriting historical results.

---

# 11. Recommendation behavior

The Custom Color Palette recommendation is not an independent AI choice of colors.

For CCP:

> **Recommendation text must explain and operationalize the user's palette; it must not re-select a different palette.**

Recommendation may provide:

- placement guidance,
- blending guidance,
- technique guidance,
- category-specific application suggestions,
- order/rationale where supported.

Recommendation must preserve:

- exact selected categories,
- final adjusted color values,
- selected finishes.

If AI output contradicts those fields, server-side structured validation must reject or normalize the invalid AI fields rather than accepting them as new truth.

---

# 12. Final Makeup Preview behavior

The protected Final Preview model remains whatever the current authoritative repository contract requires. If repository authority confirms `gemini-3.1-flash-image`, it remains locked.

The Custom Color Palette preview must receive the frozen palette configuration as authoritative input.

The preview instruction must clearly require:

- selected colors remain visually faithful,
- selected finishes remain faithful where perceptually representable,
- unselected categories are not introduced merely to beautify the result unless current protected preview semantics explicitly require them,
- identity preservation remains protected,
- no live AR behavior is introduced,
- no client-side Gemini call is introduced.

Provider success alone is not proof that the result respected the palette.

---

# 13. Palette-faithfulness validation

Because CCP is specifically user-controlled, a generated result that materially ignores the chosen palette must not be treated as a fully correct CCP result.

The validation design must evaluate, at minimum where technically feasible:

- required selected categories are represented,
- selected category colors are materially consistent with the frozen palette,
- selected finishes are not contradicted where finish is visually judgeable,
- no materially different replacement color was substituted,
- preview remains compatible with protected identity/image rules.

Do not invent an arbitrary numeric color threshold without controlled evaluation.

Possible logical outcomes:

```text
accepted
retryable_palette_mismatch
nonretryable_palette_mismatch
validator_failure
provider_failure
```

Exact validator strategy is designed in CCP-5.

---

# 14. Bounded internal correction

If preview validation identifies a retryable palette mismatch, the system may perform bounded internal regeneration using the **same frozen palette**.

Target principle:

- no infinite retry loop,
- no silent palette mutation,
- no multiple user entitlement charges for one user-authorized preview request,
- every attempt traceable,
- failed candidates not exposed as accepted Final Previews.

The exact retry bound must be validated against current provider cost/latency and existing usage accounting before live implementation.

---

# 15. Tutorial behavior

CCP Tutorial must remain grounded in the same frozen user palette and accepted Final Preview.

Tutorial must:

- use the selected categories,
- use the selected colors,
- use selected finishes where applicable,
- provide application guidance consistent with the accepted look,
- not independently replace the palette,
- not mutate protected Tutorial V4 semantics globally.

`tutorial_guideline_v4_7` and `tutorial_manifest_v4_1` remain hard locked unless a CCP-specific additive bridge/version is explicitly authorized.

If the existing Tutorial V4 can consume CCP lineage without modifying protected semantics, reuse it.

---

# 16. History and Saved Looks

For CCP-generated looks:

History and Saved Looks must preserve enough lineage to show or regenerate the exact palette configuration used by the accepted look.

At minimum preserve/recover:

- source mode,
- style,
- palette snapshot/reference,
- selected category colors,
- finishes,
- accepted preview reference,
- tutorial lineage where applicable.

Never reconstruct historical palette truth from the current UI defaults.

Never rewrite old Standard/My Makeup Kit historical content.

---

# 17. Generate Another Variation

For CCP:

> **Generate Another Variation must retain the same palette and finishes by default.**

It may vary:

- visual execution,
- blending,
- application nuance,
- other currently supported variation dimensions.

It must not silently change:

- selected category,
- selected color,
- adjusted color,
- selected finish.

If the user wants different colors/finishes, they must explicitly edit the palette and start a new logical generation configuration.

---

# 18. Flutter UX contract

The recommendation-mode screen must present Custom Color Palette as a third additive mode without degrading the existing two modes.

The CCP customization screen must support:

- clear category list/cards,
- color picker/palette interaction,
- color adjuster,
- category-aware finish selection,
- review of final choices,
- validation of required selections,
- explicit generate action,
- back/edit behavior that does not accidentally lose confirmed choices,
- accessible labels and readable selected-state indication,
- deterministic state restoration during normal navigation/app resume where current app architecture supports it.

Do not redesign unrelated screens.

---

# 19. State-management contract

CCP client state must be explicit and testable.

The exact Riverpod/provider/state classes must be discovered from the repository.

Requirements:

- no hidden global mutable palette state,
- one authoritative in-progress palette draft in the client,
- server is authoritative for persisted/generated look lineage,
- double-tap generate does not create duplicate logical generations,
- navigation back/forward follows an explicit state policy,
- editing an accepted historical palette must create a new draft rather than mutate history.

---

# 20. Persistence principle

Prefer the smallest durable schema that gives clear lineage.

Investigate whether current recommendation/look records can safely store a versioned palette snapshot without creating competing truth.

If current tables are insufficient, use minimal additive schema only.

No schema mutation is allowed before CCP-2 design proves it necessary.

RLS must remain least-privilege.

---

# 21. Usage and subscription invariant

CCP is a recommendation mode, not a subscription redesign.

Preserve all current authoritative subscription behavior, including as applicable:

- server-authoritative entitlement state,
- plan codes,
- AI Look / Preview Credit separation,
- reserve → generate → validate → persist → commit lifecycle,
- release semantics,
- top-up accounting,
- Google Play verification,
- SUB-10 verify → activate → acknowledge,
- SUB-11 lifecycle / RTDN / Restore.

CCP internal retries must not multiply user-facing charges for one logical request.

---

# 22. Security and privacy hard locks

Never:

- expose Gemini/API secrets in Flutter,
- call Gemini directly from Flutter,
- bypass Edge/server authorization,
- weaken RLS,
- trust client-supplied user identity over authenticated JWT ownership,
- log JWTs,
- log service-role keys,
- log signed private URLs,
- expose private beauty content to Web Admin,
- expose another user's palette/history data,
- persist failed candidate images as accepted results.

User-selected palette data is not authorization data.

---

# 23. Hard locks — Standard Recommendation

CCP must not modify Standard Recommendation behavior.

Do not change unless a separately authorized non-CCP source of truth allows it:

- Standard recommendation prompt/contract,
- Standard routing,
- Standard Final Preview behavior,
- Standard Tutorial behavior,
- Standard History/Saved Looks behavior,
- Standard usage accounting.

Shared code may be refactored only if behavior remains proven identical and the current CCP phase explicitly authorizes it.

---

# 24. Hard locks — My Makeup Kit

CCP must not modify My Makeup Kit behavior.

Do not change unless separately authorized:

- owned-product eligibility logic,
- product snapshot lineage,
- My Makeup Kit recommendation semantics,
- kit preview lineage,
- `kit_preview_mismatch` semantics,
- kit Tutorial product-backing semantics,
- historical kit content.

Custom Color Palette is color/finish-driven, not owned-product-driven.

---

# 25. Hard locks — Tutorial V4

Do not overwrite or casually modify:

```text
tutorial_guideline_v4_7
tutorial_manifest_v4_1
```

Do not weaken:

- Tutorial safety,
- accepted-source lineage,
- historical tutorial stability,
- product-backing semantics for My Makeup Kit.

If CCP needs new metadata, prefer an additive CCP bridge/contract.

---

# 26. Hard locks — Final Preview

Do not change:

- protected identity-preservation rules,
- private storage rules,
- server-side-only Gemini,
- historical preview records,
- accepted-source lineage,
- current authoritative image model without separate authorization,
- existing Standard/My Makeup Kit prompt semantics.

Use additive CCP-specific prompt/version routing.

---

# 27. Hard locks — Web Admin and Booking

CCP does not authorize changes to:

- Web Admin scope,
- provider application,
- provider profile,
- booking module,
- provider schedule,
- salon communications,
- Revision 2 data model.

If CCP implementation appears to require Booking changes:

```text
STOP
REPORT SCOPE VIOLATION
```

---

# 28. Historical preservation

Never silently rewrite:

- old Standard recommendations,
- old My Makeup Kit recommendations,
- old previews,
- old tutorials,
- old history entries,
- old saved looks.

CCP applies only to new CCP-generated content unless a future migration is explicitly authorized.

---

# 29. Additive versioning strategy

Do not overwrite existing prompt/contracts.

Recommended CCP identifiers, subject to repository audit:

```text
custom_color_palette_contract_v1
custom_palette_recommendation_v1
custom_palette_preview_v1
custom_palette_validator_v1
custom_palette_tutorial_bridge_v1
```

Exact identifiers must be confirmed in CCP-0/CCP-1.

No current prompt version may have its semantics overwritten.

---

# 30. Idempotency and concurrency

CCP must be safe under:

- double tap,
- network retry,
- app resume,
- duplicate Edge invocation,
- provider timeout,
- validation timeout,
- retry replay,
- repeated save/favorite action.

Requirements:

- one logical palette request has one frozen palette,
- one logical preview request cannot double-commit usage,
- accepted preview persistence is idempotent,
- retries preserve the same palette,
- historical palette lineage cannot drift,
- duplicate callbacks cannot create conflicting accepted previews.

---

# 31. Observability

Capture only non-sensitive structured operational metadata needed to evaluate CCP correctness.

Recommended fields:

```text
request_id
palette_id
palette_version
source_mode
style_code
selected_category_codes
recommendation_version
preview_prompt_version
validator_version
attempt_number
validation_outcome
mismatch_category_codes
accepted_attempt_number
latency bucket
provider error class
```

Avoid logging:

- image bytes,
- full private prompts containing personal information,
- signed URLs,
- JWTs,
- secrets,
- service-role keys.

Do not log full palette payloads if operational metrics only require category identifiers.

---

# 32. Quality evaluation matrix

Controlled CCP validation must include a representative matrix across:

- supported makeup styles discovered in repository,
- supported CCP categories,
- light/dark/saturated/desaturated adjusted colors,
- category-appropriate finishes,
- single-category and multi-category palettes where allowed,
- Generate Another Variation,
- History/Saved Looks restoration,
- Tutorial grounding,
- subscription/usage states.

Do not invent numeric acceptance thresholds before controlled evaluation.

---

# 33. UX validation principles

The user must be able to answer these questions at a glance:

- Which recommendation mode am I using?
- Which categories am I customizing?
- What is the final selected color for each category?
- What finish is selected?
- Which finishes are unavailable for this category?
- Can I edit before generation?
- Will another variation preserve my palette?

The UI must not imply that AI may override explicit user selections.

---

# 34. Acceptance principles

A CCP result is acceptable only when:

1. source mode is correctly `custom_color_palette` using the repository's exact identifier,
2. the palette contract is valid,
3. every selected category is supported,
4. every selected color is normalized and valid,
5. every selected finish is allowed for its category,
6. recommendation derives from the frozen palette,
7. Final Preview generation receives the frozen palette,
8. the accepted preview is materially faithful to the palette under the approved validator contract,
9. Tutorial grounding uses the same palette lineage,
10. History/Saved Looks preserve the palette,
11. Generate Another Variation preserves palette constraints,
12. usage is committed exactly once per logical request,
13. Standard Recommendation remains unchanged,
14. My Makeup Kit remains unchanged,
15. RLS/privacy/security remain intact.

---

# 35. Prohibited shortcuts

Never solve CCP by:

- converting Standard Mode into Custom Color Palette,
- attaching palette controls to My Makeup Kit without authorization,
- letting AI choose replacement colors after user selection,
- storing only human color names without a canonical value,
- accepting invalid category/finish combinations,
- using current UI state as historical truth,
- rewriting historical looks,
- accepting provider success as palette-faithfulness proof,
- changing Tutorial V4 globally just to make CCP easier,
- weakening RLS,
- calling Gemini from Flutter,
- charging the user for each internal retry,
- retrying indefinitely,
- implementing Booking/Revision 2 inside this track,
- adding product-catalog/e-commerce behavior.

---

# 36. Git / branch safety

Before any CCP source implementation:

- record current branch,
- record HEAD,
- record working-tree status,
- inspect existing untracked/modified files,
- identify the authoritative baseline branch/worktree,
- create/use a separate authorized CCP branch only when explicitly permitted,
- never use destructive Git commands without explicit authorization.

Do not assume historical branch names from older tracks are still current.

Repository evidence must determine the baseline.

---

# 37. Phase model

```text
CCP-0   Baseline, authority, and protected-system audit
CCP-1   Custom Palette product/UX/contract design
CCP-2   Persistence, schema, RLS, and lineage design
CCP-3   Flutter mode entry + palette editor + client-state implementation
CCP-4   Server-side Custom Palette recommendation contract implementation
CCP-5   Palette-constrained Final Preview + faithfulness validator
CCP-6   Bounded retry / idempotency / usage integration
CCP-7   Tutorial + History + Saved Looks + Variation lineage integration
CCP-8   Automated regression / security / accounting validation
CCP-9   Controlled AI evaluation plan
CCP-10  Controlled live AI evaluation
CCP-11  Real-device / E2E / UX / failure-state QA
CCP-12  Production-readiness review and checkpoint readiness
```

No phase auto-starts the next phase.

Every phase ends with:

```text
REPORT
STOP
```

---

# 38. Definition of done

CCP is complete only when:

- Custom Color Palette is visible as an additive third recommendation mode,
- Standard Recommendation behavior is unchanged,
- My Makeup Kit behavior is unchanged,
- the user can select supported category colors,
- the user can adjust color/shade using the approved control,
- the user can choose category-appropriate finishes,
- invalid category/finish/color state is blocked before generation,
- one frozen palette contract governs each logical CCP generation,
- recommendation derives from the palette,
- Final Preview is constrained by the palette,
- palette faithfulness is validated under the approved contract,
- internal retries never mutate the palette,
- user-facing usage is not double-charged by internal retries,
- Tutorial uses the same palette lineage,
- History and Saved Looks preserve palette lineage,
- Generate Another Variation preserves colors/finishes by default,
- historical content remains unchanged,
- RLS/privacy/security remain intact,
- automated regression passes,
- controlled AI evaluation passes,
- real-device QA passes,
- no Booking/Revision 2 scope leaked into CCP,
- no destructive Git operation occurred without authorization.

---

# 39. Final product principle

FaceTune must not ask the user to fight the AI for control of a palette they explicitly selected.

The final CCP contract is:

> **The user chooses the style, supported makeup colors, adjusted shades, and applicable finishes. FaceTune freezes that palette, derives the recommendation and preview instructions from it, verifies the result against it, keeps Tutorial and historical lineage grounded to it, and preserves the same palette across variations unless the user explicitly edits it.**
