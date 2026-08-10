# FaceTune — CODEX PHASE PROMPTS

**Project root:** `C:\Users\Kurt\facetune`  
**Master guide:** `CODEX_MASTER_GUIDE.md`

## How to use this file

1. Keep this file in the project root beside `CODEX_MASTER_GUIDE.md`.
2. Run one phase at a time.
3. Paste only the prompt for the phase you are currently implementing.
4. Review and test the completed phase before proceeding.
5. Do not tell Codex to continue automatically into the next phase.

Every phase below assumes that Codex must read `CODEX_MASTER_GUIDE.md` first.

---

# PHASE 1 — Project Bootstrap & Architecture

Read `CODEX_MASTER_GUIDE.md` completely before making changes.

Work only on **Phase 1 — Project Bootstrap & Architecture**.

Inspect the existing Flutter project at `C:\Users\Kurt\facetune` before writing code. Inspect `pubspec.yaml`, `lib/`, Android configuration, existing dependencies, routing, state management, themes, tests, and any working features. Preserve valid existing functionality.

### Objective

Create a clean, production-ready technical foundation for FaceTune without implementing product features yet.

### Implement

- Clean Architecture foundation.
- Feature-first project organization.
- Riverpod application foundation.
- Maintainable dependency injection pattern.
- GoRouter-based routing unless an already-valid production routing solution should be preserved.
- Material 3 application shell.
- Light theme foundation.
- Dark-mode-ready theme architecture.
- Core constants and configuration organization.
- Core failure/error abstractions.
- Reusable base loading/error/result patterns only where architecturally justified.
- Base app bootstrap.
- Placeholder routes/screens only where required to prove navigation.
- Responsive layout foundation.
- Initial test structure.

### Do not implement

- Supabase database.
- Supabase authentication.
- Gemini.
- Gemini Image Generation.
- Camera.
- Gallery.
- AI analysis.
- Makeup recommendations.
- Final UI.
- Saved Looks.
- History.
- Production secrets.

Do not create meaningless empty layers just to imitate Clean Architecture.

### Done when

- App launches.
- Riverpod works.
- Routing works.
- Theme architecture works.
- Project structure is coherent.
- Future features have clear architectural locations.
- Project compiles.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 2 — Design System & Static UI

Read `CODEX_MASTER_GUIDE.md` completely first.

Continue the existing FaceTune project and implement only **Phase 2 — Design System & Static UI**.

Do not redo Phase 1 unless a minimal adjustment is necessary.

### Objective

Create the premium visual foundation and static application experience before backend integration.

### Implement

Create a reusable design system for:

- colors
- typography
- spacing
- radii
- elevations
- icon sizing
- input styling
- buttons
- cards
- dialogs
- bottom sheets
- loading states
- skeletons
- empty states
- error states
- image presentation

Create polished static versions of:

- Authentication entry
- Home
- Scan
- Makeup Style Selection
- Analysis Result
- AI Preview / Result
- Saved Looks
- History
- Profile
- Settings

Use mock/sample data only where necessary.

Design direction:

- premium
- luxury beauty
- elegant
- minimal
- Apple-inspired
- soft feminine
- sophisticated
- generous whitespace
- rounded cards
- strong photography/image areas
- Material 3
- responsive
- dark-mode-ready

The Start Scan action must have clear visual priority.

### Do not implement

- Supabase calls
- authentication logic
- Gemini calls
- camera logic
- actual AI analysis
- actual image generation
- persistence

### Done when

The main navigation and static screens visually demonstrate the complete product flow on Android without requiring real backend data.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# Phase 2.5 — OOP & Architecture Refactor

Read `CODEX_MASTER_GUIDE.md` and `FACETUNE_CODEX_PHASES_1_TO_26.md`.

Current status: Phase 1 and Phase 2 are complete.

Implement ONLY Phase 2.5.

## Objective
Refactor the current codebase into a modular, SOLID, feature-first Flutter architecture.

Do NOT add new functionality.

Preserve the existing UI and behavior.

## Refactor
- Reduce `main.dart` to bootstrap only
- Separate router
- Separate theme
- Extract reusable widgets
- Organize feature modules
- Remove God files
- Prepare for `data/domain/presentation`

## Do NOT implement
- Supabase
- Authentication
- Gemini
- Camera
- AI
- Database

## Validation
Run:
- flutter pub get
- dart format .
- flutter analyze
- flutter test
- flutter build apk --debug

Report:
- Files moved
- Files created
- Architecture improvements
- Validation results
- Next phase: Phase 3

STOP.
---

# PHASE 3 — Supabase Foundation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 3 — Supabase Foundation**.

### Objective

Establish secure Supabase infrastructure without building full feature logic.

### Implement

- Add/configure Supabase Flutter integration.
- Create environment/configuration strategy for public Supabase client configuration.
- Do not store private Gemini secrets in Flutter.
- Create initial PostgreSQL schema/migrations for:
  - profiles
  - analyses
  - recommendations
  - generated_images
  - saved_looks
  - user_settings
- Add timestamps and foreign keys.
- Add indexes where justified.
- Design and implement Row Level Security policies appropriate to user-owned records.
- Establish private storage strategy for original selfies and generated images.
- Define storage naming/path conventions.
- Add repository/data-source foundations needed for later phases.
- Document local setup requirements.

### Security

Private user content must not be publicly readable by default.

Never disable RLS simply to make development easier.

### Do not implement

- full authentication UI behavior
- Gemini
- AI generation
- camera
- complete repositories for later features unless required by this phase

### Done when

Supabase initializes safely and the project has a clear, migration-backed database/storage foundation ready for authentication.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 4 — Authentication

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 4 — Authentication**.

### Objective

Create a reliable authentication system using Supabase Auth.

### Implement

- Email registration.
- Email login.
- Forgot/reset password flow.
- Google authentication.
- Guest/anonymous flow if supported safely by the chosen Supabase configuration.
- Session persistence.
- Auth state provider/notifier.
- Routing/auth guards.
- Logout.
- Profile bootstrap after account creation.
- Friendly authentication errors.
- Loading states.
- Validation for forms.
- Guest-state handling.

Ensure authentication logic is outside UI widgets.

### Important

User-owned database and storage access must respect the Phase 3 RLS design.

If Google authentication needs platform-specific configuration that cannot be completed automatically, implement everything possible and document the exact remaining setup.

### Do not implement

- camera
- Gemini
- makeup recommendation
- AI generation

### Done when

Users can enter the app through supported auth flows, sessions restore correctly, protected routes behave correctly, and logout works.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 5 — Camera & Image Upload

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 5 — Camera & Image Upload**.

### Objective

Allow the user to capture or select a selfie safely and prepare it for later AI analysis.

### Implement

- Camera capture.
- Gallery image selection.
- Android permissions.
- Permission-denied and permanently-denied UX.
- Selfie preview.
- Retake/reselect.
- Basic file type validation.
- Reasonable size validation.
- Image compression before upload where appropriate.
- Safe temporary/local handling.
- Upload preparation architecture.
- Preserve original image separately from any future generated image.
- Scan workflow state integration.

### UI

Provide clear selfie guidance:

- one person
- face visible
- good lighting
- avoid heavy blur
- avoid extreme angles

### Do not implement

- Gemini face analysis
- computer vision with MediaPipe/OpenCV/TFLite
- makeup generation

### Done when

A user can take/select a selfie, preview it, replace it, and proceed to the next validation stage.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 6 — Image Validation Pipeline

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 6 — Image Validation Pipeline**.

### Objective

Create a robust validation layer before sending selfies to expensive AI operations.

### Implement

Client-side checks that can be performed reliably without banned computer-vision libraries:

- file exists
- supported MIME/type
- decodable image
- sensible dimensions
- sensible file size
- corruption handling

Prepare the secure backend validation contract for AI-assisted checks such as:

- exactly one visible face
- sufficient lighting
- acceptable sharpness
- face visibility
- face framing

Integrate explicit validation states into the scan state machine.

Create user-friendly failure messages and retry/reselect paths.

### Restrictions

Do not pretend local code can reliably detect faces, undertones, blur quality, or lighting if it cannot.

Do not use:

- MediaPipe
- OpenCV
- TensorFlow Lite

Do not implement the full Gemini analysis yet unless a minimal validation endpoint is strictly required by the architecture. Keep facial attribute analysis for Phase 7.

### Done when

Invalid/corrupt/unsupported images are rejected cleanly and the scan flow is ready to hand valid input to secure AI analysis.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 7 — Gemini Face Analysis

Read `CODEX_MASTER_GUIDE.md` completely first.

Then read the current FaceTune phase guide.

Continue the existing FaceTune project.

Implement ONLY:

PHASE 7 — Gemini Face Analysis

Do not implement Phase 8 or later phases.

Preserve the modular OOP / SOLID architecture established in Phase 2.5.

---

## OBJECTIVE

Securely analyze a user's selfie using Google Gemini and return validated, strongly typed facial attributes.

The complete flow must be:

Flutter
→ authenticated Supabase Edge Function
→ Gemini API
→ validated structured response
→ Dart repository/domain layer
→ Riverpod controller/state
→ Flutter UI
→ Supabase persistence

Gemini credentials must remain server-side.

---

## GEMINI SECRET

The Supabase project already contains the Edge Function secret:

GEMINI_API_KEY

The Edge Function must read it using server-side environment access.

Example concept:

Deno.env.get("GEMINI_API_KEY")

Do NOT:

- hardcode the Gemini key
- place the Gemini key in Flutter
- place it in `development.json`
- place it in AndroidManifest.xml
- place it in pubspec.yaml
- place it in GitHub
- print it to logs

If the secret is missing, return a sanitized server error.

---

## GEMINI MODEL

Use the currently supported production Gemini Flash model appropriate for multimodal image understanding.

Before implementation:

1. Verify the exact current model ID supported by the Gemini API.
2. Prefer the latest stable GA Flash model.
3. Do not use deprecated model IDs.
4. Keep the model ID server-side configurable.

Do not scatter the model ID throughout Flutter code.

Prefer one server-side configuration constant or environment/config abstraction.

---

## INPUT

The Edge Function receives:

- authenticated user session
- selfie image or secure image reference
- optional analysis metadata if required

Do not trust a client-supplied user ID.

Derive user identity from the authenticated Supabase session/JWT.

---

## IMAGE VALIDATION

Before extracting facial attributes, Gemini must validate that the image is suitable.

Validate:

- exactly one visible face
- face is sufficiently visible
- face is not severely obstructed
- image lighting is usable
- image is sufficiently sharp for analysis
- face framing is acceptable

Reject:

- no face
- multiple people
- unusable image
- extremely dark image
- severely blurry image
- face too obscured

Return structured validation errors.

Do not proceed to facial attribute analysis when validation fails.

---

## ANALYZE

For valid selfies, analyze:

- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color

Include confidence values where practical.

---

## STRUCTURED OUTPUT

Gemini must return structured JSON only.

Use a strict JSON schema where supported.

Example target:

{
  "imageValid": true,
  "validation": {
    "faceCount": 1,
    "lightingAcceptable": true,
    "sharpnessAcceptable": true,
    "faceVisible": true,
    "framingAcceptable": true
  },
  "analysis": {
    "faceShape": "oval",
    "skinTone": "medium",
    "undertone": "warm",
    "eyeShape": "almond",
    "lipShape": "full",
    "hairColor": "dark_brown",
    "eyeColor": "brown"
  },
  "confidence": {
    "faceShape": 0.91,
    "skinTone": 0.88,
    "undertone": 0.82,
    "eyeShape": 0.90,
    "lipShape": 0.87,
    "hairColor": 0.94,
    "eyeColor": 0.89
  }
}

Do not rely on free-form prose.

Do not blindly trust Gemini output.

---

## SERVER-SIDE VALIDATION

Validate Gemini output before returning it to Flutter.

Handle:

- malformed JSON
- missing fields
- null fields
- unsupported enum values
- impossible values
- confidence values outside expected range
- empty Gemini response
- refusal
- timeout
- rate-limit errors
- upstream API errors

Normalize values when appropriate.

Do not silently accept invalid AI output.

---

## DOMAIN / DATA ARCHITECTURE

Follow the modular architecture established in Phase 2.5.

Do not place Gemini calls inside UI code.

Expected conceptual structure:

features/analysis/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── controllers/
    ├── pages/
    └── widgets/

Responsibilities:

Presentation
→ UI and state only

Domain
→ entities, contracts, use cases

Data
→ DTOs, serialization, Edge Function calls, repository implementations

Do not create God classes.

---

## DART MODELS

Create strongly typed models/entities for:

- image validation result
- facial analysis
- confidence scores
- analysis failure/error state

Use immutable models where practical.

Do not pass raw Map<String, dynamic> throughout the application.

---

## RIVERPOD

Integrate the analysis flow using Riverpod.

Support states such as:

idle
validating
analyzing
success
validationFailure
networkFailure
serverFailure
geminiFailure

Avoid ambiguous boolean combinations.

---

## PERSISTENCE

On successful analysis:

Save the result to the existing Supabase `analyses` table.

Persist:

- authenticated user ID
- original image reference/path
- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color
- confidence JSON
- Gemini model ID
- prompt version if schema supports it
- created timestamp

Do not create duplicate tables if the Phase 3 schema already supports this.

If a schema adjustment is required, create a proper migration.

---

## PROMPT VERSIONING

The face-analysis Gemini prompt must be versioned.

Example concept:

face_analysis_v1

Do not bury the full prompt inside random UI or repository files.

Keep prompts isolated and maintainable.

---

## TIMEOUT / RETRY

Implement bounded timeout and retry behavior.

Do NOT retry endlessly.

Do not retry deterministic validation failures such as:

- no face
- multiple faces
- invalid image

Retry only appropriate transient failures.

---

## LOGGING

Log useful development diagnostics without exposing:

- Gemini API key
- full private image content
- raw user authentication tokens
- sensitive storage URLs

Sanitize Gemini/API errors before returning them to Flutter.

---

## TEST CASES

Add tests where feasible for:

1. Valid selfie
2. No-face image
3. Multiple-face image
4. Malformed Gemini JSON
5. Unsupported enum value
6. Low-confidence response
7. Timeout
8. Authentication failure
9. Edge Function error
10. Successful persistence

Use mocked Gemini responses for automated tests where appropriate.

Do not depend on live Gemini calls for every unit test.

---

## REQUIRED VALIDATION

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.

Validate Supabase Edge Function code separately where appropriate.

Deploy/test the Edge Function if the current environment is correctly linked.

If Android compilation should be verified, run:

flutter build apk --debug --dart-define-from-file=config/development.json

If a physical Android device is available, verify with:

flutter run --dart-define-from-file=config/development.json

Do not claim Phase 7 is complete merely because the project compiles.

The real success condition is:

A real authenticated user can submit a valid selfie, the request securely reaches Gemini through Supabase, Gemini returns validated structured facial attributes, the result is saved to Supabase, and Flutter receives typed analysis data.

---

## SECURITY CHECK

Before declaring completion verify:

- GEMINI_API_KEY exists only server-side.
- Flutter does not contain Gemini credentials.
- Edge Function requires authentication.
- User identity comes from authenticated session/JWT.
- AI response is validated server-side.
- RLS protects saved analyses.
- Logs do not expose secrets.

---

## COMPLETION REPORT

At the end report:

PHASE COMPLETED:
Phase 7 — Gemini Face Analysis

FILES CREATED:

FILES MODIFIED:

DEPENDENCIES ADDED:

DATABASE / STORAGE CHANGES:

EDGE FUNCTION CREATED:

GEMINI MODEL USED:

PROMPT VERSION:

AUTHENTICATION STATUS:

STRUCTURED OUTPUT STATUS:

IMAGE VALIDATION STATUS:

PERSISTENCE STATUS:

SECURITY CHECK:

TESTS / VALIDATION:

KNOWN LIMITATIONS:

MANUAL ACTION REQUIRED:
None / describe exact action

NEXT RECOMMENDED PHASE:
Phase 8 — Makeup Style Selection

Then STOP.

Do not implement Phase 8.
---

# PHASE 8 — Makeup Style Selection

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 8 — Makeup Style Selection**.

### Objective

Create a polished style-selection experience integrated into the scan workflow.

### Styles

- Natural
- Everyday
- Office
- Soft Glam
- Full Glam
- Bridal
- Korean
- Clean Girl
- Party
- Date Night
- No Makeup Makeup
- Old Money

### Implement

- domain representation for makeup styles
- maintainable metadata/configuration so styles can be added later
- polished style cards
- short descriptions
- selection states
- selected style persistence through the current scan session
- navigation from completed face analysis to style selection
- ability to go back without unnecessarily rerunning analysis
- accessibility/semantics where appropriate

### Do not implement

- actual makeup recommendation AI
- preview generation

### Done when

The user can review their analysis, choose a style, and continue with that choice reliably preserved.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 9 — Gemini Makeup Recommendation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 9 — Gemini Makeup Recommendation**.

### Objective

Generate a complete personalized, brand-neutral makeup plan from facial analysis plus selected style.

### Inputs

- face shape
- skin tone
- undertone
- eye shape
- lip shape
- hair color
- eye color
- selected makeup style

### Recommend

- foundation tone
- concealer tone
- contour
- highlight
- blush
- eyeshadow
- eyebrow
- eyeliner
- lipstick
- lip gloss
- overall intensity

Include where appropriate:

- color name
- HEX value
- placement
- application technique
- finish/intensity
- concise reasoning

### Implement

- separate secure backend operation from face analysis
- structured output schema
- server-side validation
- typed Dart models
- repository/use case/controller integration
- prompt versioning
- persistence to recommendations table
- retry/error handling
- UI state for generation
- display-ready recommendation model

### Restrictions

Never recommend specific cosmetic brands.

Do not merge recommendation generation and preview generation into one giant AI call.

### Done when

The selected style produces a validated, structured, personalized makeup recommendation that can be displayed and later passed to image generation.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 10 — AI Makeup Preview Generation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 10 — AI Makeup Preview Generation**.

### Objective

Generate a realistic image of the same user wearing the recommended makeup.

### Highest priority

Preserve the user's identity and original photographic characteristics as much as the image model permits.

Preserve:

- facial proportions
- hairstyle
- expression
- pose
- lighting
- apparent age
- skin identity features
- background where practical

Do not intentionally alter:

- nose geometry
- eye geometry
- jaw
- face shape
- smile
- gender presentation
- hairstyle
- body shape

Allowed intentional changes:

- makeup color
- cosmetic texture
- cosmetic placement
- cosmetic finish
- makeup intensity

### Implement

- secure server-side image-generation operation
- original selfie as image reference/input where supported
- recommendation-to-generation prompt transformation
- prompt versioning
- authenticated request
- timeout handling
- generation status
- result validation
- generated image upload/storage
- generated_images database record
- generation_number/version
- regenerate/variation foundation
- protection against overwriting original selfie
- error recovery

### Important

Identity preservation is a goal, not a guaranteed outcome. The UX must support regeneration.

### Done when

A real recommendation can produce a stored AI makeup preview linked to its original analysis and recommendation.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 11 — Results & Before/After Experience

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 11 — Results & Before/After Experience**.

### Objective

Create the flagship FaceTune results screen.

### Display

- original selfie
- generated makeup preview
- before/after slider
- selected makeup style
- detected facial attributes
- confidence information where useful
- recommended palette
- makeup breakdown
- placement/technique
- concise reasoning

### Actions

- Save Look
- Favorite
- Share
- Generate Another
- Return Home

### Implement

- polished image comparison
- reliable image loading/error states
- responsive layout
- accessible labels
- proper loading during regeneration
- state restoration when returning from related screens
- safe share flow for generated result

Do not expose private storage URLs unnecessarily.

### Done when

The user can clearly understand what was detected, what was recommended, and visually compare the original with the AI makeup preview.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 12 — Saved Looks

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 12 — Saved Looks**.

### Objective

Allow users to intentionally save and organize generated looks.

### Implement

- save look
- unsave/remove
- favorite/unfavorite
- list/grid presentation
- thumbnail loading
- reopen full result
- link to original analysis/recommendation
- empty state
- loading/error states
- pagination/lazy loading where appropriate
- RLS-safe database access
- guest behavior consistent with authentication design

Avoid duplicate saved records for the same look unless the product intentionally allows them.

### Done when

Saved looks persist correctly for authenticated users and can be reopened, favorited, and removed.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 13 — History

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 13 — History**.

### Objective

Provide a reliable record of previous FaceTune sessions.

### Include

- past analyses
- selected makeup styles
- generated previews
- timestamps
- completion/failure status where relevant

### Implement

- chronological history
- thumbnails
- search where useful
- filtering/favorites integration
- open previous result
- delete history item with confirmation
- regenerate from a valid historical analysis/recommendation where architecture permits
- pagination
- loading/error/empty states

Deletion must respect linked data and storage ownership. Do not leave obvious orphan files/records.

### Done when

Users can navigate previous FaceTune activity and reopen or manage past looks safely.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 14 — Profile & Settings

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 14 — Profile & Settings**.

### Objective

Complete the account and settings experience.

### Implement

Profile:

- display name
- email/account info where applicable
- avatar/profile photo where appropriate
- account type
- saved looks shortcut
- history shortcut

Settings:

- theme preference
- notification preference placeholder/config only if notifications are not implemented
- analytics consent setting
- privacy/about links or placeholders
- app version display
- logout

Account behavior:

- guest account explanation
- safe transition considerations from guest to registered user
- session state handling

Do not fake unsupported settings.

### Done when

Users can manage basic account information and application preferences with clear guest/authenticated behavior.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 15 — Loading, Errors & Recovery

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 15 — Loading, Errors & Recovery**.

### Objective

Audit the entire app for resilient user experience.

### Review every major flow

- auth
- home
- image capture
- gallery
- validation
- image upload
- face analysis
- recommendation
- preview generation
- results
- saved looks
- history
- profile

### Implement/improve

- consistent loaders
- progress states
- skeletons
- retry buttons
- offline handling
- timeout messages
- expired session handling
- camera permission errors
- upload failures
- Supabase failures
- Gemini failures
- malformed model output
- generation failure
- storage errors
- empty states
- safe cancellation/back navigation where practical

Do not expose internal stack traces or raw backend errors to end users.

### Done when

Common failures have intentional recovery paths instead of dead ends or indefinite spinners.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 16 — Security Hardening

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 16 — Security Hardening**.

### Objective

Perform a security-focused audit before production testing.

### Audit and fix

- Gemini API key exposure
- client-side secrets
- Supabase RLS
- storage bucket policies
- signed/private image access
- Edge Function authentication
- authorization checks
- user ID spoofing
- file MIME/type validation
- file-size enforcement
- malicious/invalid request payloads
- structured AI response validation
- prompt/input bounds
- rate limiting strategy
- abuse controls
- excessive AI request prevention
- logs containing private data
- error-message leakage
- SQL/data access patterns
- account isolation
- deletion authorization

### Important

Never solve an authorization problem by disabling RLS.

Document remaining security items requiring Supabase dashboard/provider configuration.

### Done when

No obvious high-risk secret, authorization, storage, or AI abuse issue remains in the application code and backend functions.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 17 — Performance Optimization

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 17 — Performance Optimization**.

### Objective

Improve measured or clearly justified performance problems without damaging maintainability.

### Audit

- startup
- image decoding
- image compression
- uploads
- history grids
- saved look grids
- result screen
- Riverpod rebuilds
- network request duplication
- Gemini request duplication
- Supabase queries
- thumbnail usage
- pagination
- cache strategy
- memory lifecycle
- controller disposal
- animations

### Implement

Only optimizations that are justified by observed architecture or profiling.

Prefer:

- thumbnails over full-resolution images in lists
- pagination
- caching reusable results
- Riverpod selectors where useful
- avoiding duplicate requests
- safe image sizing

Do not introduce complicated optimization frameworks without evidence.

### Done when

Primary flows remain smooth and avoid obvious unnecessary memory, network, or rebuild costs.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 18 — QA & Device Testing

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 18 — QA & Device Testing**.

### Primary target

Android — POCO X3 GT.

### Objective

Systematically test the application on real/representative Android conditions.

### Test

- clean install
- app launch
- registration/login
- Google auth
- guest flow
- logout
- session restore
- camera permissions
- gallery permissions
- camera capture
- image replacement
- invalid images
- face analysis
- makeup style selection
- recommendation
- preview generation
- before/after
- save
- favorite
- share
- history
- deletion
- profile
- slow network
- offline behavior
- backend failure
- AI timeout
- Android back button
- keyboard/input behavior
- multiple screen sizes
- lifecycle resume/pause
- dark-mode readiness

### Testing

Add/improve unit/widget/integration tests for critical logic where feasible.

Document issues found and fix issues that belong to existing product scope.

### Done when

Core user flows are repeatably testable and no known blocker prevents a complete session on the primary Android target.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 19 — Production Readiness

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 19 — Production Readiness**.

### Objective

Prepare the application technically for a real release build without publishing it.

### Review/configure

- app package/application ID
- app display name
- version/versionCode
- Android min/target SDK compatibility
- release build configuration
- signing documentation
- environment separation
- production vs development backend configuration
- app icon
- splash screen
- permissions
- cleartext/network security
- ProGuard/R8 implications if applicable
- crash reporting strategy
- analytics strategy
- secure logging
- release build validation

Create a production-readiness checklist for settings that must be completed manually.

### Restrictions

Do not publish to Google Play.

Do not commit private signing keys or secrets.

### Done when

A release-oriented build can be prepared predictably and remaining manual production configuration is documented.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 20 — Final UI/UX Polish

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 20 — Final UI/UX Polish**.

### Objective

Perform a complete visual and interaction-quality audit.

### Review

- visual hierarchy
- spacing
- typography
- icon consistency
- radius consistency
- cards
- buttons
- inputs
- loading
- error states
- empty states
- image presentation
- home dashboard
- scan journey
- style selection
- analysis
- results
- before/after slider
- saved looks
- history
- profile
- dark-mode readiness
- responsive behavior

Improve transitions and micro-interactions only when they meaningfully improve UX.

Keep the design premium, elegant, feminine, minimal, and mature.

Do not redesign working flows without a UX reason.

### Done when

The application looks and behaves like one coherent premium product rather than separate feature screens.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 21 — End-to-End System Validation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 21 — End-to-End System Validation**.

### Objective

Validate the real system as one connected product after all primary features exist.

### Execute complete journeys

At minimum:

1. New authenticated user → selfie → analysis → style → recommendation → preview → save → history → reopen.
2. Returning user → session restoration → new scan → generation → favorite.
3. Guest user → scan flow → expected data behavior.
4. Failure journey → bad image / offline / AI timeout → recovery.
5. Regenerate journey → same original analysis → new preview variation.
6. Delete journey → remove user-owned content safely.

### Validate data integrity

Confirm:

- analyses point to correct user
- recommendations point to correct analysis
- generated images point to correct recommendation
- saved looks point to correct generated image
- storage paths match ownership
- no obvious orphan records/files
- RLS prevents cross-user access

Fix integration defects discovered during validation.

Do not introduce new product features.

### Done when

The entire production-intended workflow works coherently from start to finish.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 22 — AI Quality & Prompt Optimization

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 22 — AI Quality & Prompt Optimization**.

### Objective

Improve the quality, consistency, and reliability of FaceTune's AI behavior using controlled prompt/schema revisions.

### Evaluate

Test varied valid inputs covering:

- light to deep skin tones
- warm/cool/neutral undertones
- different face shapes
- different eye shapes
- different lip shapes
- different hair/eye colors
- different lighting
- glasses where reasonably supported
- multiple makeup styles

Evaluate:

- facial attribute consistency
- recommendation usefulness
- HEX/color coherence
- placement advice
- style adherence
- preview identity preservation
- unwanted facial changes
- makeup intensity
- malformed responses
- refusals/timeouts

### Implement

- versioned prompt improvements
- stronger structured schemas
- validation improvements
- bounded retries where justified
- model configuration refinements
- generation instructions that minimize identity drift
- developer-facing AI quality test notes

Do not hardcode outputs to make test cases pass.

### Done when

AI behavior is more consistent and prompt versions are explicit and maintainable.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 23 — Privacy, Legal & Data Management

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 23 — Privacy, Legal & Data Management**.

### Objective

Prepare the product's privacy and data-management behavior for real users, especially because facial images are processed.

### Implement/productize

- privacy screen/page
- terms screen/page
- consent language before facial image processing where appropriate
- clear explanation of AI-generated results
- account deletion flow or implementation plan where platform/backend work is required
- delete-my-data flow
- original/generated image deletion handling
- user-owned database cleanup strategy
- retention policy configuration/documentation
- guest-data behavior
- analytics consent behavior
- links/config placeholders for final hosted legal documents

### Important

Do not invent legal guarantees.

Clearly separate implemented behavior from text that requires final legal review.

### Done when

Users have clear visibility and control over relevant personal data and the engineering behavior supports deletion/privacy requirements.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 24 — Closed Beta & User Acceptance Testing

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 24 — Closed Beta & User Acceptance Testing**.

### Objective

Prepare FaceTune for testing by real users and resolve verified usability/product defects.

### Prepare

- beta build configuration
- tester-friendly feedback pathway
- diagnostics/version information
- concise test checklist

### UAT scenarios

Ask testers to evaluate:

- onboarding clarity
- login
- selfie instructions
- camera/gallery
- scan duration expectations
- analysis credibility
- style selection
- recommendation readability
- preview resemblance
- before/after interaction
- save/favorite/history
- error recovery
- visual polish

### Engineering work

Use actual collected findings if available.

Fix:

- crashes
- blockers
- high-severity confusion
- reproducible bugs
- clearly poor UX

If no real tester feedback has been provided yet, prepare the beta/UAT system and checklist but do not fabricate findings.

### Done when

The project is ready for controlled tester distribution and known beta blockers are documented or fixed.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 25 — Google Play Release Preparation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 25 — Google Play Release Preparation**.

### Objective

Prepare all technical and content requirements needed to submit FaceTune to Google Play, but do not publish automatically.

### Prepare/check

- release app bundle workflow
- package/application ID
- versioning
- app signing documentation
- icons
- splash
- supported Android versions
- permissions declaration
- privacy policy URL placeholder/config
- account deletion requirements
- Data Safety inputs/checklist
- AI/facial image data disclosure considerations
- store screenshots checklist
- feature graphic checklist
- short description draft placeholder
- full description draft placeholder
- contact/support details placeholders
- internal/closed testing track checklist
- release notes template

Run a release build check where safe.

### Restrictions

Do not upload or publish without explicit instruction and proper credentials.

Do not fabricate Play Console declarations; document what the owner must confirm.

### Done when

A clear submission checklist exists and the build is technically ready for Play Console preparation.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

# PHASE 26 — Launch & Maintenance Foundation

Read `CODEX_MASTER_GUIDE.md` first.

Implement only **Phase 26 — Launch & Maintenance Foundation**.

### Objective

Transition FaceTune from a build project into a maintainable product.

### Establish/document

- production monitoring strategy
- crash/exception review workflow
- Gemini usage monitoring
- AI cost monitoring
- Supabase usage monitoring
- rate-limit review
- storage-growth review
- database maintenance considerations
- prompt version tracking
- app version/release process
- hotfix process
- bug triage levels
- support workflow
- privacy/data deletion support workflow
- backup/recovery considerations
- dependency update cadence
- security update cadence
- regression testing checklist

Create a `MAINTENANCE.md` or equivalent if appropriate.

Define the transition from phases to releases:

- v1.0.x = fixes
- v1.1 = minor improvements
- v1.x = incremental features
- v2.0 = major architecture/product expansion

Do not begin speculative v1.1 features.

### Done when

FaceTune has an explicit maintenance and release-management process after v1.0.

### Required validation

After implementation:

- Run `flutter pub get` if dependencies changed.
- Run `dart format .`.
- Run `flutter analyze`.
- Run relevant `flutter test` tests.
- Run `flutter build apk --debug` when Android compilation should be verified.
- Fix errors introduced by this phase.
- Do not hide or suppress genuine errors just to make checks appear green.

### Completion report

At the end, report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE / STORAGE CHANGES:
EDGE FUNCTION / AI CHANGES:
TESTS / VALIDATION:
KNOWN LIMITATIONS:
NEXT RECOMMENDED PHASE:
```

Then STOP.

Do not implement the next phase until explicitly instructed.

---

