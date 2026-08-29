# V3-9 — My Makeup Kit Integration

**Branch:** `feature/step-by-step-tutorial-v3`
**Date:** 2026-08-28
**Preconditions:** V3-6B, V3-7, V3-8 complete
**Status:** Complete. **No remote mutation, nothing deployed, nothing applied.**

---

## 1. What this phase did

Kit mode was already wired through the V3 stack by earlier phases: the session
routes to `kit_makeup_recommendations`, the planner is shown only owned
products and re-verifies them, the geometry mapper re-verifies again at step
time, and the UI distinguishes an owned product from a recommended shade.

This phase audited that path against the Kit rules and closed the two places
where it did not hold, then pinned the whole boundary with tests.

**No core My Makeup Kit behaviour was changed.** Nothing under
`lib/features/makeup_kit/` or in the Kit Edge Functions was touched.

---

## 2. The two gaps found

### 2.1 The persisted Kit snapshot was written from the model's text

`planRows` built `product_snapshot_json` from the **model's** output —
`product_name`, `shade_name`, `color_hex`, `finish` — for every step, Kit
included.

Validation already rejected an unowned or wrong-category `product_id`, so the
model could not name a product the user did not own. But it could paraphrase
the shade name, or emit a different hex, for a product they *do* own. That
description is what gets persisted, and what V3-8 shows on screen under
`APPLY` — so a wrong colour swatch would be presented to the user as their own
product, indefinitely.

**Fix.** In Kit mode the snapshot is now built entirely from the matched
`OwnedProduct` — the row that came back from the RLS-scoped inventory read.
The only thing that survives from the model is the id it chose, and that is
looked up again in `planRows`:

```ts
const product = owned.get(step.productId);
if (product === undefined) throw new PlanRejected([...]);
const snapshot = {
  category: product.category,
  product_id: product.productId,
  color_hex: normalizeHex(product.colorHex) ?? product.colorHex,
  finish: product.finish,
};
```

A missing inventory entry throws rather than falling back, so there is no path
that writes model text into a Kit snapshot. Standard mode is unchanged: there
is no inventory row to copy, so the description still comes from the persisted
makeup plan by way of the prompt, and still carries no product id.

### 2.2 The canonical preview's folder was not checked against the source mode

`generate-makeup-preview` writes to `{user}/analyses/{analysis}/generated/…`
and `generate-kit-makeup-preview` writes to
`{user}/analyses/{analysis}/kit-generated/…`. Both live under the same
analysis and the same owner.

The session request checked that the preview's declared `sourceMode` matched
the session's, and the planner checked the path's owner prefix, `..` and
`/original/` — but nothing checked the **folder**. A Kit session whose
canonical path pointed into `generated/` would have passed every check and the
planner would have decomposed the standard look for the same face. Not a
cross-account leak, but the wrong destination, with nothing on the row to
reveal the mix-up.

**Fix.** `TutorialV3SourceMode.canonicalPreviewFolder` names the folder each
chain writes to. `TutorialV3CanonicalPreview.matchesSourceModeFolder` asserts
the path sits in it, enforced in `_validateRequest` at session creation and
again in the planner:

```ts
const canonicalFolder = isKit ? "/kit-generated/" : "/generated/";
```

---

## 3. Files changed

| File | Change |
|---|---|
| `supabase/functions/plan-tutorial-v3/validation.ts` | `planRows` takes `ownedProducts`; `productSnapshotOf` builds Kit snapshots from inventory and throws rather than falling back |
| `supabase/functions/plan-tutorial-v3/index.ts` | Passes `ownedProducts` to `planRows`; canonical path must sit in the mode's folder |
| `lib/.../domain/entities/tutorial_v3_source_mode.dart` | `canonicalPreviewFolder` |
| `lib/.../domain/entities/tutorial_v3_canonical_preview.dart` | `matchesSourceModeFolder` |
| `lib/.../data/repositories/supabase_tutorial_v3_repository.dart` | Folder check in `_validateRequest` |
| `supabase/functions/plan-tutorial-v3/validation_test.ts` | +7 tests (snapshot provenance, one-product kit, wrong-category product, cross-account, standard unchanged) |
| `test/.../supabase_tutorial_v3_repository_test.dart` | +4 Kit routing tests |
| `test/.../tutorial_v3_kit_integration_contract_test.dart` | **New** — 24 tests |

---

## 4. Rule compliance

| Rule | How it is met |
|---|---|
| use persisted Kit recommendation | The planner reads `kit_makeup_recommendations` by `session.kit_recommendation_id` and requires its `analysis_id` and `makeup_style` to still match the session |
| owned selected products only | The owned set is the recommendation's persisted snapshots, each re-read from `makeup_kit_products`; a step naming anything else is rejected, never repaired |
| server validates authoritative ownership | Twice: at plan time and again at geometry time, including the step's *own* `product_snapshot_json.product_id` — not just the look's list |
| persist/reuse product snapshots | Snapshots are by value and now copied from the inventory row. Nothing in `lib/features/tutorial_v3/` reads `makeup_kit_products`, so a later edit cannot rewrite a persisted step |
| incomplete kit valid | Only an *empty* look is refused. A one-product kit produces a two-step tutorial; asserted |
| omit unavailable categories | The prompt instructs it and a test proves a plan may teach a single category |
| no independent product selection | The planner never queries inventory to *choose*, only to *verify*; the owned set comes from the persisted recommendation |
| no core Kit rewrite | Nothing under `lib/features/makeup_kit/` or the Kit Edge Functions was modified |
| geometry mapper never invents products/shades | The mapper prompt carries no product field at all — asserted that `productId`, `productName`, `shadeName`, `colorHex` and `finish` appear nowhere in it |

---

## 5. Tests and results

| Suite | Count | Result |
|---|---|---|
| `flutter analyze` | — | **0 issues** |
| `flutter test` | **761** | **all pass** (was 733 after V3-8) |
| `deno test .../plan-tutorial-v3/` | **44** | all pass (was 38) |
| `deno test .../map-tutorial-v3-guideline-geometry/` | 38 | all pass |
| `deno test --allow-read tool/tutorial_v3_smoke/` | 46 | all pass |
| `git diff --check` | — | clean |

### Required checklist coverage

| Required test | Where |
|---|---|
| Unowned rejection | planner "kit mode accepts only owned products", "a product owned by another account is simply not owned here"; plan validator "rejects a Kit product the user does not own", "rejects a Kit step that invents a product"; Kit contract "an unowned product id is rejected, never repaired" |
| Incomplete Kit | planner "kit mode may omit categories the user cannot cover", "a one-product kit is a complete tutorial"; Kit contract "only an empty look is refused" |
| Cross-account safety | planner "a product owned by another account is simply not owned here"; Kit contract "both lookups run under the caller's JWT, so RLS scopes them", "a lookup failure denies rather than assumes ownership" |
| Snapshots | planner "a kit snapshot is copied from the user's inventory, not the model", "a kit product with no name or shade snapshots neither", "kit rows are refused rather than written from model text", "a standard snapshot still describes the recommended shade"; Kit contract "the persisted snapshot is copied from the inventory row", "the snapshot carries the product, not a live reference" |
| Routing | repository "a Kit session is keyed on the Kit preview column", "the same analysis can have one tutorial per mode", "a Kit preview stored outside the Kit folder is refused", "a standard preview stored in the Kit folder is refused"; Kit contract "the source mode decides the preview folder", "the planner refuses a target from the other chain" |
| Historical product changes | Kit contract "the tutorial never reads the live inventory table", "the snapshot carries the product, not a live reference"; mapper "the mapper checks again at geometry time" |
| Geometry only for valid persisted steps | Kit contract "it maps only a step that is already planned and persisted"; mapper contract (V3-6B) `step_spec_mismatch`, `source_mode_mismatch`, atomic claim |

---

## 6. What happens when a Kit product changes after planning

| Change | Behaviour |
|---|---|
| Product **deleted** | Its id no longer comes back from the RLS-scoped read. The planner refuses to plan and the mapper refuses to map, both with `inventory_changed`: *"A product in this look was edited or removed. Create a new kit look."* |
| Product **edited** (shade, name, finish) | The id still resolves, so ownership still holds. The persisted snapshot keeps the values captured at plan time, and that is what the tutorial teaches — deliberate, so a persisted tutorial cannot silently change under the user mid-way through following it |
| Product **transferred / another account's id** | Invisible under RLS, so indistinguishable from a deleted one and handled identically |

---

## 7. Risks and limitations

| # | Item | Severity | Notes |
|---|---|---|---|
| 1 | **Exposed legacy `service_role` credential** | **HIGH — UNRESOLVED** | Carried forward from V3-6A.2. Not touched. **Release is blocked until it is rotated/revoked outside Claude Code.** |
| 2 | An edited product keeps teaching its old shade | By design | The alternative — a tutorial that changes as you follow it — is worse. A user who wants the new shade creates a new kit look. Worth a product decision before launch. |
| 3 | No Kit entry point is wired | Expected | Reaching the tutorial needs analysis + recommendation + canonical preview resolved server-side, which is V3-10's stated goal. This phase made Kit *sessions* correct, not Kit *navigation*. |
| 4 | The Dart plan validator's `ownedKitProductIds` is test-only | Low | Deliberate: the server is authoritative for ownership. The domain rule is still expressed and exercised. |
| 5 | Migration `20260828000100` unapplied; mapper undeployed | Expected | V3-6B risks 2 and 3, unchanged. No Kit tutorial has run end to end. |
| 6 | Ownership is verified by id, not by content hash | Low | An edit that keeps the id is intentionally not an ownership change (see §6). |

---

## 8. Security impact

- **Ownership is never client-asserted.** Both functions read
  `makeup_kit_products` under the caller's JWT with no `user_id` filter, so RLS
  decides; an id belonging to another account simply does not come back.
  Asserted that neither function references `SERVICE_ROLE`.
- **A lookup failure denies.** `inventory_lookup_failed` is returned rather
  than proceeding on an unverified set.
- **The model's product description no longer reaches storage.** This phase's
  main fix removes the last path by which model output could describe a real
  user's real product in the database.
- **Cross-mode targeting is closed.** A session can no longer be created — or
  planned — against the other chain's preview.
- **No RLS change, no migration, no Kit table or policy touched, no
  deployment, no secret read or mutated.**

---

## 9. Acceptance status

| Criterion | Status |
|---|---|
| Uses the persisted Kit recommendation | Met |
| Owned selected products only | Met |
| Server validates authoritative ownership | Met |
| Product snapshots persisted and reused | Met |
| Incomplete kit valid | Met |
| Unavailable categories omitted | Met |
| No independent product selection | Met |
| No core Kit rewrite | Met |
| Geometry mapper never invents products or shades | Met |
| Required tests written and passing | Met |

**V3-9 is complete. STOPPING HERE. V3-10 is not authorized and has not been started.**
