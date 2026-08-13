SUPABASE PW: facetune_123*

powershell -ExecutionPolicy Bypass -File tool/run_dev.ps1

IMPORTANT:

This project was previously developed by Codex.

Inspect the CURRENT repository before modifying anything.

Do not assume previous implementation details.
Preserve all valid existing work.

gemini-3.6-flash
gemini-3-pro-image

erun the important parts of 18, 20, 21, and 22 against the expanded app before you proceed to 23–26.


The existing Makeup Recommendation flow is frozen. My Makeup Kit must be additive, isolated, and must not modify the behavior of the existing recommendation system.


MK-1 → MK-3: Build the foundation.
Nothing exciting visually yet. We're establishing architecture, Supabase, security, models, repositories, and state management correctly before building on top of them.

MK-4 → MK-6: Build the actual makeup inventory.
This is when you'll start seeing the feature come alive: My Makeup Kit screen, categories, color picker, finish selection, Foundation attributes, Add/Edit/Delete.

MK-7 → MK-10: Connect the kit to FaceTune's AI.
This is the most important functional stage. Users choose between the original recommendation and their own kit, Gemini chooses among their products, anti-hallucination protection verifies those choices, and the AI preview applies the resulting look.

MK-11 → MK-12: Integrate and harden it.
Saved Looks and History understand kit-based looks, while errors, security, offline behavior, performance, and recovery are strengthened.

MK-13 → MK-14: Prove it works and finish it.
We test the whole system—including the original Makeup Recommendation—and then polish the UI/UX.

git add .
git commit -m "MK-6 — Edit, Delete & Inventory Management"
git push