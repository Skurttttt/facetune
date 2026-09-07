SUPABASE PW: facetune_123*

powershell -ExecutionPolicy Bypass -File tool/run_dev.ps1

flutter run --release --dart-define-from-file=config/development.json

flutter run --profile --dart-define-from-file=config/development.json

IMPORTANT:

This project was previously developed by Codex.

Inspect the CURRENT repository before modifying anything.

Do not assume previous implementation details.
Preserve all valid existing work.

gemini-3.6-flash
gemini-3.1-flash-image

- Subscription
- Web Admin
- Face analysis must be accurate and consistent
- Tutorial makeup overlay is not consistent it produce makeup overlay on step by step
- How do you specifically apply the makeup if hard, soft, etc.
- Detailed instructions and guidelines
- Loading screen after clicking Show me how UI
- Upload from gallery

Transition for every pages


I would actually use three documents

For this project, the cleanest setup would be:

SUBSCRIPTION_SOURCE_OF_TRUTH.md
WEB_ADMIN_SOURCE_OF_TRUTH.md
SUBSCRIPTION_ADMIN_SHARED_CONTRACT.md

The third one can stay short.

Shared Contract

It defines only the objects both systems must agree on.

For example:

Plan Codes

free
plus
pro
salon_pro
salon_pilot

And:

Entitlement Status

active
grace_period
expired
suspended
revoked

And:

Usage Status

reserved
committed
released

And:

Usage Type

final_makeup_preview

And common fields such as:

user_id
entitlement_id
plan_code
ai_look_limit
ai_look_used
ai_look_remaining
period_start
period_end
expires_at

This prevents Flutter, backend and Admin Web from all developing their own interpretation of what an entitlement means. Humans apparently enjoy naming the same thing four different ways unless threatened with documentation.