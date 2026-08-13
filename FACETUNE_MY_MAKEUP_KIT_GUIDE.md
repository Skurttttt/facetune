# FaceTune — My Makeup Kit Guide

**File:** `FACETUNE_MY_MAKEUP_KIT_GUIDE.md`  
**Parent system guide:** `CODEX_MASTER_GUIDE.md`  
**Execution roadmap:** `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`  
**Feature:** My Makeup Kit  
**Intended agents:** OpenAI Codex and Claude Code Pro

---

# 1. PURPOSE

This document is the **source of truth for the My Makeup Kit feature**.

It defines WHAT the feature is, its product behavior, UX rules, architectural boundaries, data rules, AI rules, security expectations, and non-negotiable constraints.

Implementation sequencing and phase-specific prompts belong in `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`.

Before implementing any My Makeup Kit phase, the coding agent must read:

1. `CODEX_MASTER_GUIDE.md`
2. `FACETUNE_MY_MAKEUP_KIT_GUIDE.md`
3. The requested phase in `FACETUNE_MY_MAKEUP_KIT_ROADMAP.md`

---

# 2. NON-NEGOTIABLE LEGACY PROTECTION RULE

> **The existing Makeup Recommendation flow is frozen. My Makeup Kit must be additive, isolated, and must not modify the behavior of the existing Makeup Recommendation system.**

The existing working Makeup Recommendation system is the protected baseline.

Do not rewrite or refactor it merely to make My Makeup Kit easier to implement.

Do not silently change:

- existing recommendation prompts
- existing recommendation endpoints
- existing AI model behavior
- existing recommendation schemas/contracts
- existing preview behavior
- existing scan/analysis behavior
- existing Saved Looks behavior
- existing History behavior
- existing security/RLS protections
- existing timeout/retry/duplicate-request protections

Shared infrastructure may be reused only when backward compatibility is preserved.

If a requested My Makeup Kit implementation cannot be completed without changing the behavior of the frozen system, **STOP and report the conflict before making the change.**

---

# 3. PRODUCT DEFINITION

My Makeup Kit is an optional FaceTune experience.

It allows users to register makeup products they currently own and lets FaceTune determine the best personalized makeup look that can be created using those available products.

The two experiences are conceptually:

> **Makeup Recommendation:**  
> “FaceTune, tell me what makeup would look best on me.”

> **My Makeup Kit:**  
> “FaceTune, this is the makeup I already own. Tell me the best look I can create using these products.”

My Makeup Kit does not replace Makeup Recommendation.

---

# 4. CORE USER CAPABILITIES

Users can:

- create a personal makeup inventory
- organize products by category
- register multiple products in the same category
- choose a visual shade/color
- store a normalized HEX value internally
- choose a category-appropriate finish
- provide additional relevant attributes for categories that need them
- edit products
- delete products
- use an incomplete kit
- choose My Makeup Kit as a recommendation mode
- receive a personalized look based on their facial attributes, selected style, and available products
- generate a visual preview from the kit-based look
- save and reopen kit-based results

---

# 5. SUPPORTED PRODUCT CATEGORIES

Initial categories:

1. Foundation
2. Concealer
3. Blush
4. Highlighter
5. Eyeshadow
6. Lipstick
7. Lip Gloss
8. Contour/Bronzer
9. Eyebrow
10. Eyeliner

Use stable internal identifiers/enums rather than relying on UI labels as database contracts.

---

# 6. PRODUCT INFORMATION

A registered product should support, where appropriate:

- unique product ID
- authenticated owner ID
- category
- optional custom product name
- shade/color
- normalized HEX color
- optional user-friendly color/shade label
- finish
- category-specific metadata
- created timestamp
- updated timestamp

Do not add speculative fields without a real feature requirement.

Brand is not required for the initial implementation.

---

# 7. COLOR / SHADE EXPERIENCE

Users should not be required to understand HEX codes.

The primary interaction should be a visual color picker.

Example:

```text
COLOR / SHADE

● Nude Rose

[ Visual Color Picker ]

Selected:
● Nude Rose

Advanced / Reference:
#B86F72
```

Internally:

- normalize HEX consistently
- validate values before persistence
- prevent malformed colors from reaching the AI pipeline
- use the normalized color representation for deterministic data exchange

Camera-based physical product shade detection is outside the initial My Makeup Kit scope unless explicitly added later.

---

# 8. CATEGORY-SPECIFIC FINISHES

Finish describes how the makeup appears after application and is separate from color.

Allowed finish values:

| Category | Finish options |
| --- | --- |
| Foundation | Matte, Natural, Dewy, Satin |
| Concealer | Matte, Natural, Radiant |
| Blush | Matte, Satin, Shimmer |
| Highlighter | Natural, Shimmer, Metallic |
| Eyeshadow | Matte, Satin, Shimmer, Metallic, Glitter |
| Lipstick | Matte, Satin, Cream, Glossy |
| Lip Gloss | Glossy, Shimmer |
| Contour/Bronzer | Matte, Satin |
| Eyebrow | Matte, Natural |
| Eyeliner | Matte, Satin/Glossy |

The UI must only expose finishes valid for the selected category.

The system must reject invalid category/finish combinations.

---

# 9. FOUNDATION-SPECIFIC ATTRIBUTES

Foundation may additionally contain:

## Depth

- Fair
- Light
- Medium
- Tan
- Deep

## Undertone

- Cool
- Neutral
- Warm

These fields describe the foundation product the user owns.

Do not force foundation-only fields onto unrelated categories.

---

# 10. DYNAMIC ADD PRODUCT FORM

The form changes based on category.

## Example — Lipstick

```text
ADD PRODUCT

Category
Lipstick

Product Name (Optional)
[ My Nude Lipstick ]

COLOR / SHADE
● Nude Rose
  #B86F72

FINISH
○ Matte
○ Satin
● Cream
○ Glossy

[ Add to My Makeup Kit ]
```

## Example — Foundation

```text
ADD FOUNDATION

Product Name (Optional)
[ Everyday Foundation ]

SHADE
● Warm Beige
  #C99578

DEPTH
○ Fair
○ Light
● Medium
○ Tan
○ Deep

UNDERTONE
○ Cool
● Warm
○ Neutral

FINISH
○ Matte
● Natural
○ Dewy
○ Satin

[ Add to My Makeup Kit ]
```

The UX should remain simple even though the underlying data is structured.

---

# 11. MULTIPLE PRODUCTS PER CATEGORY

Users can own multiple products in any category.

Example:

```text
MY LIPSTICKS

● Nude Rose
  Cream

● Deep Red
  Matte

● Peach Nude
  Satin

● Soft Pink
  Glossy
```

FaceTune must treat these as available choices rather than assuming one product per category.

---

# 12. INCOMPLETE KIT RULE

A complete makeup collection is NOT required.

Examples of valid kits:

- lipstick only
- blush + lipstick
- foundation + blush + lipstick
- eyeshadow collection without foundation
- any other valid partial inventory

FaceTune should determine what look can honestly be created from what is available.

It must not silently invent missing products.

It must not silently switch to the standard Makeup Recommendation mode.

Any future hybrid/fallback behavior requires an explicit product decision.

---

# 13. RECOMMENDATION MODE UX

At the appropriate point in the existing scan/style journey, the user can choose between two mutually exclusive modes.

Conceptually:

```text
HOW WOULD YOU LIKE TO CREATE YOUR LOOK?

[ Makeup Recommendation ]
Let FaceTune choose the ideal makeup for you.

[ My Makeup Kit ]
Create a look using makeup you already own.
```

A two-card or similarly explicit selector may be preferable to a literal toggle because these are two different recommendation strategies.

If standard Makeup Recommendation is selected, the application must enter the existing frozen flow.

If My Makeup Kit is selected, the application enters the isolated kit-based flow.

---

# 14. HIGH-LEVEL ARCHITECTURE

```text
                   FACETUNE
                       │
                       ↓
                 Choose Mode
                       │
          ┌────────────┴────────────┐
          ↓                         ↓
 MAKEUP RECOMMENDATION        MY MAKEUP KIT
    Existing/Frozen              New/Isolated
          │                         │
          │                    User's Products
          │                         │
          │                 Color + Finish +
          │                 relevant metadata
          │                         │
          │                    Face Analysis
          │                         │
          │                    Selected Style
          │                         │
          │                         ↓
          │                 AI chooses the best
          │                 products user owns
          │                         │
          ↓                         ↓
 Existing Recommended         Kit-Based
       Look                 Personalized Look
```

The implementation should prefer a dedicated feature boundary such as:

```text
lib/features/makeup_kit/
    data/
    domain/
    presentation/
```

but the coding agent must inspect and follow the actual current repository architecture rather than forcing an incompatible structure.

---

# 15. KIT-AWARE AI ARCHITECTURE

My Makeup Kit should use an isolated AI recommendation operation.

Conceptually:

```text
Flutter
   ↓
Authenticated Supabase Edge Function
   ↓
Validate user/session
   ↓
Load/validate face analysis
   ↓
Load/validate selected style
   ↓
Load authenticated user's kit
   ↓
Gemini receives structured inventory
   ↓
Gemini selects suitable owned products
   ↓
Server validates AI output
   ↓
Persist validated kit recommendation
   ↓
Return structured result
```

Prefer a dedicated operation such as:

`generate-kit-makeup-recommendation`

if this preserves isolation from the existing recommendation function.

The standard recommendation function must not be transformed into a dual-purpose implementation if that risks changing its behavior.

---

# 16. AI INPUT RULES

The kit recommendation may use:

- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color
- selected makeup style
- authenticated user's available kit products
- product IDs
- categories
- shade/color
- finish
- foundation depth/undertone where available

Use structured inputs.

Do not rely on uncontrolled prose for inventory identity.

---

# 17. STRICT ANTI-HALLUCINATION RULE

This is a critical feature requirement.

> **FaceTune must never claim that the user owns a makeup product that is not registered in My Makeup Kit.**

The AI is not authoritative about inventory.

Every selected product returned by Gemini must be validated server-side.

At minimum:

1. Parse structured model output.
2. Validate the product ID exists.
3. Validate it belongs to the authenticated user.
4. Validate the category matches.
5. Validate the stored shade/color.
6. Validate the stored finish.
7. Reject, repair, or safely retry malformed/fabricated selections.
8. Never persist fabricated ownership.

Example:

If the user owns:

```text
Lipstick:
- Nude Rose
- Deep Red
- Peach Nude
```

Gemini may choose one or more of those products as allowed by the look design.

Gemini may NOT return:

```text
Berry Pink Lipstick
```

and present it as something the user owns.

---

# 18. SECURITY

My Makeup Kit is private user data.

Requirements:

- Supabase authentication
- RLS on kit tables
- users read only their own products
- users create only their own products
- users update only their own products
- users delete only their own products
- prevent user-ID spoofing
- Edge Functions independently verify ownership
- never trust client-supplied product ownership
- Gemini API key remains server-side
- logs must not expose JWTs, secrets, image bytes, signed URLs, or unnecessary private data
- cross-account state must clear correctly on logout/session change

Never weaken existing RLS or security controls for implementation convenience.

---

# 19. DATA PERSISTENCE PRINCIPLES

A likely core persistence model is conceptually:

```text
makeup_kit_products
```

Exact schema decisions must follow the current database conventions.

Kit-based recommendation persistence must remain distinguishable from standard recommendations without breaking historical rows.

For saved/history results, preserve enough snapshot information that an old look remains understandable if the user later:

- edits a product
- changes its color
- changes its finish
- deletes it from the active kit

Do not create fragile historical records that become meaningless after inventory changes.

---

# 20. KIT-BASED PREVIEW

A validated kit recommendation may feed the existing preview capability through the smallest safe backward-compatible integration point.

The preview should respect:

- selected owned-product colors
- finish where visually relevant
- placement/intensity
- existing identity-preservation protections
- original selfie integrity

The image model must not substitute unrelated colors and then label them as owned products.

The original selfie must never be overwritten.

The existing standard preview behavior remains protected.

---

# 21. UX STATES

Every My Makeup Kit screen/flow should intentionally handle:

- loading
- skeletons where appropriate
- empty kit
- empty category
- incomplete kit
- save in progress
- mutation failure
- offline state
- timeout
- session expiry
- AI failure
- malformed AI output
- quota/rate-limit failure
- preview failure
- safe retry
- safe back/cancel behavior

No indefinite spinners.

No raw stack traces or backend diagnostics shown to users.

---

# 22. VISUAL DIRECTION

My Makeup Kit must look like part of FaceTune.

Maintain:

- premium beauty aesthetic
- modern minimal design
- soft feminine presentation
- Material 3
- consistent typography
- consistent spacing
- consistent radii
- accessible contrast
- clear color swatches
- responsive Android-first layout

Do not create a visually disconnected mini-application.

---

# 23. ENGINEERING RULES

Always follow `CODEX_MASTER_GUIDE.md`.

Continue using the established project architecture and conventions, including where applicable:

- Flutter/Dart
- Riverpod
- Clean Architecture
- feature-first organization
- Repository Pattern
- SOLID
- typed domain models
- Supabase Auth/PostgreSQL/RLS
- secure Edge Functions
- server-side Gemini secrets
- structured AI output
- defensive validation
- tests
- safe error mapping

Avoid:

- God classes
- business logic in widgets
- duplicated AI calls
- unnecessary broad refactors
- hardcoded secrets
- arbitrary strings when typed values are practical
- fabricated successful tests or deployments

---

# 24. REGRESSION CONTRACT

Whenever a My Makeup Kit phase touches shared scan, style, preview, results, saved, history, routing, backend, or data infrastructure, verify the protected standard journey:

```text
Selfie
→ Face Analysis
→ Select Style
→ Makeup Recommendation
→ AI Preview
→ Results
→ Save
→ History
```

My Makeup Kit is not considered successful if it breaks the existing Makeup Recommendation experience.

---

# 25. DEFINITION OF DONE

My Makeup Kit is feature-complete when:

- authenticated users can maintain a private kit
- all supported categories work
- multiple products per category work
- visual color selection works
- category-specific finishes work
- foundation-specific metadata works
- add/edit/delete work
- incomplete kits are accepted
- users can explicitly choose My Makeup Kit mode
- AI uses the user's face analysis + selected style + available inventory
- AI output is structured
- every selected product is validated against real user-owned inventory
- fabricated products are never presented as owned
- kit-based preview works
- kit results can be saved/reopened
- security/RLS are validated
- failure/recovery UX is intentional
- Android build and relevant tests pass
- the original Makeup Recommendation flow remains behaviorally intact

---

# 26. FINAL PRINCIPLE

**My Makeup Kit is an extension, not a rewrite.**

Prefer:

- isolated additions over broad refactors
- typed data over free-form inventory
- visual UX over technical HEX entry
- server validation over trusting AI
- authenticated product IDs over inferred ownership
- honest incomplete-kit results over fabricated completeness
- backward compatibility over architectural cleverness
- regression testing over assumptions

At every implementation decision, ask:

> **Can this capability be added while keeping the working FaceTune system exactly as reliable as it was before?**

If not, stop and redesign the integration boundary before proceeding.
