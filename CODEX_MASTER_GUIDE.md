# FaceTune — CODEX MASTER GUIDE

**Project Path:** `C:\Users\Kurt\facetune`  
**Project Name:** FaceTune  
**Tagline:** Your AI Makeup Artist  
**Primary Platform:** Android  
**Primary Test Device:** POCO X3 GT  
**Framework:** Flutter  
**Language:** Dart  
**Backend:** Supabase  
**AI:** Google Gemini  
**State Management:** Riverpod  
**Architecture:** Clean Architecture + Repository Pattern + Feature-First Structure  

---

Insert a new **Phase 2.5 — OOP & Architecture Refactor** between Phase 2 and Phase 3.

## Goal
Refactor the Phase 1–2 implementation into a modular, maintainable OOP architecture before backend integration.

### Tasks
- Inspect existing Dart files
- Split oversized files
- Reduce `main.dart` to app bootstrap only
- Move routing into `app/router/`
- Move theme into `theme/`
- Extract shared widgets into `shared/widgets/`
- Move screens into feature-first modules
- Preserve all UI and navigation
- Prepare features to evolve into `data/domain/presentation`

### Permanent Architecture Rule
Starting with Phase 2.5, every future phase must preserve modular OOP.

Rules:
- No God classes
- No God widgets
- No God repositories
- No business logic in UI
- No Supabase/Gemini calls in widgets
- One responsibility per class
- Use feature/data/domain/presentation when business logic is introduced.


# 1. SYSTEM ROLE

You are acting as a senior software engineering team composed of:

- Senior Flutter Engineer
- Senior Mobile Software Architect
- Senior Google Gemini AI Engineer
- Senior Supabase Backend Engineer
- Senior Mobile UI/UX Designer
- Senior Prompt Engineer
- Senior Security Engineer
- Senior Performance Engineer
- Senior QA Engineer

Your job is to build a production-quality Flutter application.

This is not a demo, mockup, disposable prototype, or hackathon project.

Every implementation decision must prioritize:

1. Maintainability
2. Scalability
3. Security
4. Reliability
5. Readability
6. Performance
7. Testability
8. Good user experience

Never sacrifice architecture for short-term convenience unless explicitly instructed.

---

# 2. PROJECT OBJECTIVE

Build an AI-powered mobile application called **FaceTune**.

FaceTune helps users discover personalized makeup looks based on their facial attributes.

The application must allow the user to:

1. Sign in or continue as a guest.
2. Capture or upload a selfie.
3. Validate the selected image.
4. Analyze facial attributes using Google Gemini.
5. Let the user choose a makeup style.
6. Generate personalized makeup recommendations.
7. Generate an AI makeup preview using the user's own image.
8. Compare the original and generated result.
9. Save looks.
10. View history.
11. Favorite looks.
12. Regenerate alternative makeup previews.
13. Manage profile and settings.

The application must remain brand-neutral.

Do not recommend specific makeup brands.

Recommendations must focus on:

- Colors
- HEX values
- Makeup intensity
- Placement
- Application style
- Makeup techniques
- Reasoning

---

# 3. NON-NEGOTIABLE AI ARCHITECTURE

Do NOT use:

- MediaPipe
- OpenCV
- TensorFlow Lite
- Real-time AR face filters

Gemini must be the primary system used for image understanding and facial attribute analysis.

The system is NOT a live AR makeup filter.

The system generates a new AI image showing the user wearing the recommended makeup.

---

# 4. SECURITY ARCHITECTURE

Never expose the Gemini API key inside the Flutter application.

Do NOT place production secrets inside:

- Dart source code
- Flutter assets
- APK
- hardcoded constants
- client-side `.env` files

Use this architecture:

```text
Flutter App
    ↓
Supabase Authentication
    ↓
Supabase Edge Function / Secure AI Gateway
    ↓
Google Gemini API
    ↓
Validated Structured Response
    ↓
Supabase Database / Storage
    ↓
Flutter UI
```

Gemini requests must be performed server-side.

The secure AI gateway must eventually support:

- authentication verification
- request validation
- image validation
- rate limiting
- request logging
- response validation
- timeout handling
- Gemini model configuration
- abuse protection
- usage tracking
- retry policy

Never make direct production Gemini calls from the Flutter UI.

---

# 5. TECHNOLOGY STACK

## Frontend

Flutter

## Language

Dart

## Backend

Supabase

## Authentication

Supabase Auth

Support:

- Google Login
- Email Login
- Guest Login
- Forgot Password
- Logout
- Profile Management

## Database

Supabase PostgreSQL

## Storage

Supabase Storage

## AI

Google Gemini API

Use Gemini for:

- selfie analysis
- facial attribute extraction
- makeup recommendations
- image generation / image transformation where supported

## State Management

Riverpod

## Navigation

Use a maintainable routing solution suitable for production Flutter applications.

Prefer GoRouter unless the existing project already uses a valid alternative.

## Architecture

- Clean Architecture
- Repository Pattern
- Feature-first directory structure
- Dependency Injection
- Strongly typed models
- Centralized error handling

## UI

- Material 3
- Responsive layouts
- Dark-mode ready
- Premium beauty aesthetic

---

# 6. APPLICATION FLOW

```text
Launch
↓
Authentication
↓
Home
↓
Start Scan
↓
Take Photo OR Upload Image
↓
Image Validation
↓
Gemini Face Analysis
↓
Select Makeup Style
↓
Gemini Makeup Recommendation
↓
Gemini Makeup Preview Generation
↓
Result Screen
↓
Save / Favorite / Share / Regenerate
↓
History
```

---

# 7. CORE FEATURES

## Authentication

Implement:

- Google Login
- Email Login
- Registration
- Guest Login
- Forgot Password
- Persistent session
- Logout
- Profile Management

Do not place authentication logic directly inside widgets.

---

## Home

Create a premium dashboard containing:

- Greeting
- Start Scan
- Recent Looks
- Saved Looks
- AI Recommendations
- Quick access to History
- Quick access to Profile

The Start Scan action should be visually dominant.

---

## Camera and Image Upload

Allow:

- Take Photo
- Upload from Gallery

Validate:

- supported file type
- image size
- image quality
- exactly one visible face
- acceptable lighting
- acceptable sharpness
- face visibility
- face centered enough for analysis

If validation fails, explain the problem clearly.

Do not silently continue with a poor input image.

---

# 8. GEMINI FACE ANALYSIS

Gemini should detect or estimate:

- Face Shape
- Skin Tone
- Undertone
- Eye Shape
- Lip Shape
- Hair Color
- Eye Color

The AI must return structured data only.

Example target schema:

```json
{
  "faceShape": "oval",
  "skinTone": "medium",
  "undertone": "warm",
  "eyeShape": "almond",
  "lipShape": "full",
  "hairColor": "dark_brown",
  "eyeColor": "brown",
  "confidence": {
    "faceShape": 0.91,
    "skinTone": 0.88,
    "undertone": 0.81,
    "eyeShape": 0.89,
    "lipShape": 0.86,
    "hairColor": 0.94,
    "eyeColor": 0.90
  }
}
```

Do not trust raw AI output blindly.

Validate every AI response before converting it into application models.

Handle:

- malformed JSON
- missing fields
- unsupported enum values
- low confidence
- timeout
- Gemini refusal
- empty response
- invalid image response

Use strongly typed Dart models.

---

# 9. MAKEUP STYLES

The app should support:

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

The architecture must make it easy to add more styles later.

Do not hardwire business logic to exactly twelve styles.

---

# 10. AI MAKEUP RECOMMENDATION

Generate recommendations based on:

- Face Shape
- Skin Tone
- Undertone
- Eye Shape
- Lip Shape
- Hair Color
- Eye Color
- Selected Makeup Style

Recommend:

- Foundation tone
- Concealer tone
- Contour
- Highlight
- Blush
- Eyeshadow
- Eyebrow
- Eyeliner
- Lipstick
- Lip Gloss
- Overall makeup intensity

For appropriate fields include:

- color name
- HEX color
- application style
- intensity
- placement
- short reasoning

Never recommend cosmetic brands.

Example recommendation concept:

```json
{
  "style": "soft_glam",
  "foundation": {
    "tone": "medium warm beige",
    "hex": "#C99573",
    "reason": "Complements the detected warm undertone."
  },
  "blush": {
    "color": "warm peach",
    "hex": "#E69A7A",
    "placement": "Upper cheekbones blended toward the temples",
    "reason": "Adds warmth while visually lifting the face."
  }
}
```

Use structured schemas rather than free-form prose whenever practical.

---

# 11. AI MAKEUP PREVIEW

The AI image generation stage must use the original selfie as the primary identity reference.

Highest-priority goal:

**Apply makeup while changing as little else as possible.**

Preserve as closely as possible:

- identity
- facial proportions
- hairstyle
- expression
- pose
- lighting
- skin identity features
- age appearance

Do not intentionally alter:

- face shape
- nose geometry
- eye geometry
- jaw structure
- smile
- hairstyle
- apparent age
- gender presentation
- body shape
- background unless technically unavoidable

Allowed intentional changes:

- makeup colors
- cosmetic texture
- cosmetic placement
- cosmetic finish
- cosmetic intensity

Identity preservation is a generation goal, not an absolute guarantee.

The UI must therefore support:

- Regenerate Preview
- Generate Another Variation

Never overwrite the original selfie.

---

# 12. RESULT SCREEN

Display:

- Original Image
- AI Generated Image
- Before/After Slider
- Selected Makeup Style
- Detected Facial Attributes
- Recommended Color Palette
- Makeup Breakdown
- Recommendation Reasoning

Actions:

- Save Look
- Favorite
- Share
- Generate Another
- Return Home

---

# 13. SAVED LOOKS

Save:

- user ID
- analysis ID
- recommendation ID
- generated image ID
- style
- created date
- favorite state

Allow:

- reopening
- favoriting
- deleting
- viewing analysis
- viewing recommendation
- regenerating another version

---

# 14. HISTORY

Maintain historical records of:

- analyses
- generated looks
- selected styles
- timestamps

Support:

- search
- favorites
- delete
- open result
- regenerate

Use pagination or lazy loading when the data set becomes large.

---

# 15. PROFILE

Profile should contain:

- user information
- account type
- profile photo
- saved looks
- history
- settings
- about
- privacy information
- logout

Guest users must be handled safely.

If guest data will be deleted after logout or uninstall, clearly communicate the behavior.

---

# 16. DATABASE DESIGN

Create a scalable schema.

Suggested core entities:

## profiles

- id
- auth_user_id
- display_name
- avatar_url
- created_at
- updated_at

## analyses

- id
- user_id
- original_image_path
- face_shape
- skin_tone
- undertone
- eye_shape
- lip_shape
- hair_color
- eye_color
- confidence_json
- raw_ai_metadata
- created_at

## recommendations

- id
- user_id
- analysis_id
- makeup_style
- recommendation_json
- model_name
- prompt_version
- created_at

## generated_images

- id
- user_id
- analysis_id
- recommendation_id
- storage_path
- generation_number
- model_name
- prompt_version
- created_at

## saved_looks

- id
- user_id
- generated_image_id
- is_favorite
- created_at

## user_settings

- id
- user_id
- dark_mode
- notifications_enabled
- analytics_consent
- created_at
- updated_at

Adjust the schema when necessary, but preserve normalization and scalability.

Use foreign keys.

Use indexes where justified.

Use Supabase Row Level Security.

Never rely solely on client-side permission checks.

---

# 17. STORAGE DESIGN

Never overwrite original images.

Suggested structure:

```text
users/{userId}/analyses/{analysisId}/original.jpg
users/{userId}/analyses/{analysisId}/preview_01.jpg
users/{userId}/analyses/{analysisId}/preview_02.jpg
users/{userId}/analyses/{analysisId}/preview_03.jpg
```

Use unique IDs rather than user-provided filenames where possible.

Validate:

- content type
- file extension
- maximum size
- authenticated ownership

---

# 18. API LAYER

Never call Gemini from widgets.

Required flow:

```text
UI
↓
Controller / Notifier
↓
Use Case
↓
Repository
↓
Remote Data Source / Secure Backend API
↓
Supabase Edge Function
↓
Gemini
```

Separate AI responsibilities.

Prefer services such as:

```text
FaceAnalysisRepository
MakeupRecommendationRepository
MakeupPreviewRepository
```

Server-side AI operations should also be separated logically:

```text
analyzeFace
generateMakeupRecommendation
generateMakeupPreview
```

Do not build one giant AI function responsible for the entire workflow.

---

# 19. SCAN STATE MACHINE

Use explicit states.

Example:

```text
idle
↓
imageSelected
↓
validatingImage
↓
imageValidated
↓
analyzingFace
↓
analysisComplete
↓
selectingStyle
↓
generatingRecommendation
↓
recommendationComplete
↓
generatingPreview
↓
previewComplete
```

Possible error states:

```text
invalidImage
noFaceDetected
multipleFacesDetected
analysisFailed
recommendationFailed
generationFailed
networkError
storageError
authenticationError
```

Do not represent the entire scan process using a few ambiguous booleans.

---

# 20. FOLDER STRUCTURE

Prefer feature-first organization.

Example:

```text
lib/
├── app/
│   ├── app.dart
│   ├── router/
│   └── bootstrap/
│
├── core/
│   ├── constants/
│   ├── errors/
│   ├── network/
│   ├── utils/
│   ├── extensions/
│   └── config/
│
├── features/
│   ├── authentication/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── home/
│   ├── scan/
│   ├── analysis/
│   ├── recommendation/
│   ├── preview/
│   ├── saved/
│   ├── history/
│   └── profile/
│
├── shared/
│   ├── widgets/
│   ├── models/
│   └── providers/
│
├── theme/
│
└── main.dart
```

Do not create empty folders merely to imitate architecture.

Create directories only when they have an actual purpose.

---

# 21. UI / UX DESIGN SYSTEM

Design direction:

- Premium
- Elegant
- Luxury Beauty
- Minimal
- Apple-inspired
- Feminine without becoming childish
- Soft pink accents
- Neutral backgrounds
- Strong image presentation
- Generous whitespace
- Large rounded cards
- Refined typography
- Consistent spacing
- Material 3

Avoid:

- clutter
- excessive gradients
- excessive shadows
- tiny text
- crowded dashboards
- inconsistent spacing
- excessive animation
- generic default Flutter styling

Build reusable design tokens for:

- spacing
- radius
- typography
- colors
- elevations
- transitions

Dark mode must be considered architecturally even if final dark mode polish occurs later.

---

# 22. REUSABLE COMPONENTS

Create reusable widgets when repetition justifies them.

Examples:

- PrimaryButton
- SecondaryButton
- AppCard
- EmptyState
- ErrorState
- LoadingState
- SkeletonCard
- ImageViewer
- ColorPaletteCard
- MakeupRecommendationCard
- ConfirmationDialog
- AppBottomSheet
- BeforeAfterSlider
- ScanProgressIndicator

Do not create abstractions for widgets used only once unless the abstraction has architectural value.

---

# 23. ERROR HANDLING

Handle:

- no internet
- timeout
- Supabase failure
- Gemini failure
- malformed Gemini response
- image upload failure
- storage failure
- unsupported image
- no face
- multiple faces
- image too dark
- image too blurry
- authentication failure
- expired session
- permission denied
- camera permission denied

Errors shown to users must be understandable.

Avoid exposing stack traces, raw API responses, HTTP internals, SQL details, or secret information.

Log technical details appropriately in development environments.

---

# 24. PERFORMANCE

Requirements:

- Compress images before upload where appropriate.
- Avoid uploading unnecessarily huge images.
- Use lazy loading.
- Cache previous results where reasonable.
- Avoid duplicate Gemini calls.
- Avoid unnecessary Riverpod rebuilds.
- Use selectors where useful.
- Dispose controllers correctly.
- Paginate large collections.
- Use thumbnails for history lists.
- Keep animations lightweight.
- Target smooth 60 FPS interactions.

Do not prematurely optimize at the cost of readability.

Measure before making complex optimizations.

---

# 25. PRIVACY

This app processes facial images.

Treat user images as sensitive application data.

Apply privacy-first design.

Requirements:

- Do not expose another user's files.
- Use RLS.
- Use signed URLs/private buckets where appropriate.
- Store only required information.
- Clearly separate original images from generated images.
- Make deletion possible.
- Do not use user photos for unrelated purposes.
- Do not log image binary data or secret URLs.

Future production versions should include:

- Privacy Policy
- Terms of Service
- Image retention policy
- Account deletion
- Data deletion

---

# 26. CODE QUALITY RULES

Every implementation must:

- follow SOLID principles where practical
- separate business logic from presentation
- avoid duplicated business logic
- use meaningful names
- minimize global mutable state
- avoid giant widgets
- avoid giant service classes
- avoid giant repositories
- avoid magic numbers
- avoid hardcoded strings that belong in configuration
- document important architectural decisions
- use async code safely
- avoid unhandled exceptions
- use null safety correctly
- preserve working functionality

Do not rewrite working modules without a concrete reason.

---

# 27. CODEX OPERATING RULES

Before changing code:

1. Inspect the existing project.
2. Understand the current architecture.
3. Inspect `pubspec.yaml`.
4. Inspect current dependencies.
5. Inspect relevant feature files.
6. Check for existing implementations before creating duplicates.
7. Preserve working behavior.

When implementing a phase:

1. State the objective.
2. Identify files likely to change.
3. Implement only what belongs to the current phase.
4. Run formatting.
5. Run static analysis.
6. Run tests when tests exist.
7. Fix issues caused by the current phase.
8. Summarize what changed.
9. Stop.

Do NOT automatically begin the next phase.

Wait for the next explicit phase instruction.

---

# 28. COMMANDS CODEX SHOULD USE

When appropriate:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

If Android build validation is required:

```powershell
flutter build apk --debug
```

Do not run destructive commands without a clear reason.

Never delete unrelated project files.

Never reset Git history.

Never remove configuration files merely to fix a temporary error.

---

# 29. DEVELOPMENT PHASES

The application must be developed incrementally.

---

## PHASE 1 — Project Bootstrap & Architecture

Goal:

Establish the production-ready Flutter foundation.

Tasks:

- inspect current Flutter project
- verify Flutter compatibility
- organize architecture
- configure Riverpod
- configure routing
- establish app theme
- establish core error structure
- establish constants/configuration pattern
- add only essential dependencies
- create base feature-first folders
- create placeholder routes/screens where needed
- ensure project compiles

Do NOT integrate Gemini.

Do NOT build full Supabase features.

Do NOT implement final UI.

Completion criteria:

- app starts
- routing works
- architecture is organized
- `flutter analyze` has no phase-created critical errors
- project compiles

STOP after Phase 1.

---

## PHASE 2 — Design System & Static UI

Goal:

Build the visual foundation.

Create:

- color system
- typography
- spacing
- radius
- reusable buttons
- cards
- loaders
- error widgets
- empty states
- static Home
- static History
- static Saved Looks
- static Profile
- static Scan
- static Result

No real backend data required.

Use realistic mock models where needed.

STOP after Phase 2.

---

## PHASE 3 — Supabase Foundation

Goal:

Connect backend infrastructure.

Implement:

- Supabase initialization
- environment/config pattern
- initial database schema
- RLS planning
- storage bucket strategy
- repositories/data sources required for upcoming auth

Do NOT expose secrets.

STOP after Phase 3.

---

## PHASE 4 — Authentication

Implement:

- email signup
- email login
- forgot password
- Google login
- guest flow
- session persistence
- logout
- auth guards

STOP after Phase 4.

---

## PHASE 5 — Camera & Image Upload

Implement:

- camera capture
- gallery selection
- permissions
- preview
- basic file validation
- compression
- upload preparation

Do not integrate Gemini analysis yet.

STOP after Phase 5.

---

## PHASE 6 — Image Validation Pipeline

Implement reliable pre-analysis checks.

Validate:

- supported image
- reasonable size
- obvious corruption
- expected image properties

Prepare backend validation contract for:

- one face
- lighting
- blur
- face visibility

Do not create fake computer-vision claims using unsupported local libraries.

STOP after Phase 6.

---

## PHASE 7 — Gemini Face Analysis

Implement:

- Supabase Edge Function / secure AI gateway
- authenticated request
- Gemini image analysis
- structured response schema
- validation
- typed Dart model
- confidence handling
- error recovery
- persistence of analysis

Never expose Gemini key.

STOP after Phase 7.

---

## PHASE 8 — Makeup Style Selection

Implement polished style selection.

Support:

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

Persist selected style through the scan workflow.

STOP after Phase 8.

---

## PHASE 9 — Gemini Makeup Recommendation

Implement secure recommendation generation.

Input:

- face analysis
- selected style

Output:

- typed structured recommendation
- color names
- HEX values
- placement
- intensity
- reasoning

Never recommend brands.

Persist recommendation.

STOP after Phase 9.

---

## PHASE 10 — AI Makeup Preview Generation

Implement:

- secure image-generation request
- identity-preserving prompt strategy
- result validation
- Supabase Storage
- preview record
- regenerate flow

Never overwrite the original image.

STOP after Phase 10.

---

## PHASE 11 — Result & Before/After Experience

Build complete Result Screen.

Include:

- original
- generated
- before/after slider
- detected attributes
- palette
- recommendation breakdown
- save
- favorite
- share
- regenerate

STOP after Phase 11.

---

## PHASE 12 — Saved Looks

Implement:

- save
- favorite
- reopen
- remove
- preview
- pagination if needed

STOP after Phase 12.

---

## PHASE 13 — History

Implement:

- analyses history
- generated previews
- timestamps
- search
- favorites filtering
- delete
- regenerate

STOP after Phase 13.

---

## PHASE 14 — Profile & Settings

Implement:

- user profile
- account state
- settings
- theme readiness
- privacy links/placeholders
- logout
- guest-state handling

STOP after Phase 14.

---

## PHASE 15 — Loading, Errors & Recovery

Audit the complete application.

Improve:

- retry paths
- loaders
- skeletons
- timeouts
- offline states
- validation messages
- session expiry
- empty states
- recovery from failed AI generation

STOP after Phase 15.

---

## PHASE 16 — Security Hardening

Audit:

- Gemini secrets
- RLS
- buckets
- storage permissions
- Edge Functions
- input validation
- auth verification
- file validation
- logging
- rate limiting
- abuse cases

Fix high-risk problems.

STOP after Phase 16.

---

## PHASE 17 — Performance Optimization

Audit:

- image sizes
- rebuilds
- scrolling
- memory
- cache
- duplicate network calls
- duplicate Gemini calls
- pagination
- thumbnails
- startup

Optimize only verified issues.

STOP after Phase 17.

---

## PHASE 18 — QA & Device Testing

Primary Android target:

POCO X3 GT

Test:

- install
- launch
- auth
- permissions
- photo capture
- gallery
- scan flow
- Gemini errors
- slow network
- navigation
- back button
- rotation behavior if supported
- different Android screen sizes

Add or improve tests for important business logic.

STOP after Phase 18.

---

## PHASE 19 — Production Readiness

Prepare:

- release configuration
- environment separation
- app icons
- splash
- versioning
- release build checks
- crash logging strategy
- analytics strategy
- privacy requirements
- account deletion requirements
- store readiness checklist

Do not publish automatically.

STOP after Phase 19.

---

## PHASE 20 — Final UI/UX Polish

Final visual audit.

Improve:

- spacing
- typography
- transitions
- empty states
- card hierarchy
- result presentation
- image handling
- loading experience
- consistency
- responsiveness

Do not redesign working flows unnecessarily.

STOP after Phase 20.

---

# 30. DEFINITION OF DONE FOR EVERY PHASE

A phase is complete only when:

- scope is implemented
- existing functionality remains working
- changed files are formatted
- static analysis is checked
- relevant tests are run
- major errors introduced by the phase are fixed
- no secret is exposed
- architecture remains consistent
- Codex summarizes modifications

At completion always report:

```text
PHASE COMPLETED:
FILES CREATED:
FILES MODIFIED:
DEPENDENCIES ADDED:
DATABASE CHANGES:
KNOWN LIMITATIONS:
TESTS / VALIDATION:
NEXT RECOMMENDED PHASE:
```

Then stop.

---

# 31. IMPORTANT RESTRICTIONS

Never:

- generate the entire app in one phase
- place Gemini API keys inside Flutter
- use MediaPipe
- use OpenCV
- use TensorFlow Lite
- create real-time AR makeup
- recommend makeup brands
- overwrite original selfies
- bypass authentication for private user resources
- disable RLS merely to make development easier
- hardcode production secrets
- silently ignore malformed Gemini data
- delete unrelated code
- rewrite working modules without reason
- begin a new phase automatically

---

# 32. CURRENT WORKING DIRECTORY

The project is located at:

```text
C:\Users\Kurt\facetune
```

Treat this directory as the project root.

Before making changes, inspect the actual project instead of assuming it is empty.

If existing code conflicts with this guide, preserve valid working functionality and refactor incrementally.

---

# 33. FIRST CODEX COMMAND

When beginning development for the first time, use the following instruction:

> Read `CODEX_MASTER_GUIDE.md` completely before making any changes.
>
> We are working only on **Phase 1 — Project Bootstrap & Architecture**.
>
> Inspect the existing Flutter project at `C:\Users\Kurt\facetune`.
>
> Do not implement later phases.
>
> Preserve any valid existing code.
>
> Establish the architecture, routing, Riverpod foundation, theme foundation, core error/config structure, and feature-first folders necessary for the future application.
>
> Add only dependencies justified by Phase 1.
>
> Run `dart format .`, `flutter analyze`, and any appropriate validation after implementation.
>
> Fix problems introduced by your changes.
>
> At the end, report the Phase Completion Summary defined in this guide and STOP.
>
> Do not proceed to Phase 2 until explicitly instructed.

---

# 34. FUTURE PHASE PROMPT FORMAT

For every future phase, use:

```text
Read CODEX_MASTER_GUIDE.md first.

Continue the existing FaceTune project.

Implement only:

PHASE [NUMBER] — [PHASE NAME]

Follow all architecture, security, UI, AI, and coding rules in CODEX_MASTER_GUIDE.md.

Before coding:
- inspect the current implementation
- identify reusable existing code
- identify the minimum files that need modification

Do not redo completed phases unless required to safely implement this phase.

Preserve existing working functionality.

Do not implement features assigned to later phases.

After implementation:
- format changed code
- run flutter analyze
- run relevant tests
- fix issues introduced by this phase

Provide the required Phase Completion Summary.

STOP after this phase.
```

---

# 35. FINAL ENGINEERING PRINCIPLE

Build FaceTune as if another senior engineering team will maintain the application after you.

Prefer clear architecture over clever code.

Prefer secure backend boundaries over convenience.

Prefer strongly typed contracts over fragile parsing.

Prefer incremental working software over massive code generation.

Prefer tested, maintainable implementations over shortcuts.

Every phase must leave the codebase in a better and still-working state.
