# V3-5 — Guideline Image Model Capability Gate

**Phase:** V3-5 (verification only — no feature implementation)
**Date:** 2026-08-26
**Branch:** `feature/step-by-step-tutorial-v3`
**Requested guideline model:** `gemini-3.6-flash`
**Source of truth:** `FACETUNE_STEP_BY_STEP_TUTORIAL_V3_SOURCE_OF_TRUTH.md` §21

---

## Verdict

# NOT SUPPORTED

`gemini-3.6-flash` is configured, deployed and used in this project as a
**text/JSON-output** model. It is not, anywhere in this codebase, used to
produce image bytes, and the project deliberately maintains a **separate**
model variable for image output.

Per Source of Truth §21, this phase therefore **STOPS AND REPORTS**. No model
has been substituted, no configuration has been changed, and no guideline code
has been written.

### The exact incompatibility

```text
REQUIRED BY V3 GUIDELINE GENERATION
  source image(s) IN + structured instruction IN  ->  image bytes OUT

WHAT gemini-3.6-flash DOES IN THIS PROJECT
  source image IN + instruction IN  ->  text / JSON OUT
```

Both directions accept an image as **input**. Only one produces an image as
**output**. Sending an image *in* proves nothing about getting an image *out* —
that is the precise confusion §21 warns against, and it is the confusion this
gate exists to catch.

---

## Scope and honesty statement — read this before relying on the verdict

**I could not execute a live capability probe against the Gemini API.** The
`GEMINI_API_KEY` exists only as a Supabase Edge Function secret;
`npx -y supabase secrets list` returns a SHA-256 digest, not the key, and there
is no local `.env` or config file containing it (`config/development.json`
holds only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`).

The verdict therefore rests on three independent lines of evidence, all of
which agree:

1. **Structural evidence** — the live, deployed integration in this repository
   (§1–§8 below). This is direct and verifiable.
2. **Prior live-gate evidence** — V2-5 ran this exact gate *with* a live
   integration and recorded the same conclusion (§9).
3. **Configuration evidence** — the project maintains two separate model
   variables precisely because the capabilities differ (§2).

What I have **not** done is issue a request to
`/v1/models/gemini-3.6-flash:generateContent` and observe the response. §10
gives the exact command to do so. If you want a first-hand confirmation before
acting on this verdict, run it — it is a single call.

---

## Verification results, item by item

### 1. Endpoint / API version — **VERIFIED, and the split is exact**

Every Gemini client in the repository was inspected. The endpoint version
partitions perfectly by output type, with no exceptions:

| Function | Endpoint | Model variable | Output |
| --- | --- | --- | --- |
| `analyze-face` | `/v1beta/…:generateContent` | `GEMINI_MODEL` | text/JSON |
| `generate-makeup-recommendation` | `/v1beta/…` | `GEMINI_MODEL` | text/JSON |
| `generate-kit-makeup-recommendation` | `/v1beta/…` | `GEMINI_MODEL` | text/JSON |
| `plan-tutorial-v2` | `/v1beta/…` | `TUTORIAL_V2_PLANNER_MODEL` | text/JSON |
| `plan-tutorial-v3` (V3-4) | `/v1beta/…` | `TUTORIAL_V3_PLANNER_MODEL` | text/JSON |
| **`generate-makeup-preview`** | **`/v1/…`** | **`GEMINI_IMAGE_MODEL`** | **image bytes** |
| **`generate-kit-makeup-preview`** | **`/v1/…`** | **`GEMINI_IMAGE_MODEL`** | **image bytes** |

`gemini-3.6-flash` is the default of `GEMINI_MODEL` and of both planner
variables. **It appears on the `/v1beta` text path only. No code path in this
repository ever sends it to the `/v1` image endpoint.**

### 2. Request format — **VERIFIED, and the two paths differ materially**

Text path (`/v1beta`), from `generate-makeup-recommendation/gemini_client.ts`:

```jsonc
{
  "contents": [{ "role": "user", "parts": [ /* text, optional inlineData */ ] }],
  "generationConfig": {
    "responseMimeType": "application/json",
    "responseJsonSchema": { /* … */ },
    "maxOutputTokens": 4096, "temperature": 0.4, "topP": 0.9
  }
}
```

Image path (`/v1`), from `generate-makeup-preview/gemini_client.ts`:

```jsonc
{
  "contents": [{ "role": "user", "parts": [
    { "text": "…" },
    { "inlineData": { "mimeType": "image/jpeg", "data": "<base64>" } }
  ]}]
  // NO generationConfig at all — see docs/AI_QUALITY_NOTES.md
}
```

The image path sends **no `generationConfig`**, deliberately: an unsupported
field there returns 400 and breaks generation outright. The text path *depends*
on `generationConfig.responseMimeType = "application/json"` plus
`responseJsonSchema` — the very mechanism that makes it return text.

### 3. Image input support — **VERIFIED, supported on both paths**

Both paths accept `parts[].inlineData` with `mimeType` and base64 `data`.
`plan-tutorial-v2` and `plan-tutorial-v3` both send the canonical preview as an
inline image to a `/v1beta` text model and receive JSON. This is exactly why
image *input* cannot be used as evidence of image *output*.

### 4. Multiple input / reference images — **NOT VERIFIED IN THIS PROJECT**

This is a **second, independent gap**, and it applies regardless of which model
is chosen.

`contents[0].parts` is an array, so N image parts are structurally
expressible. But **every image-output call in this repository sends exactly one
`inlineData` part**: `generate-makeup-preview` sends the original selfie only,
and `generate-kit-makeup-preview` likewise sends one image.

V3 guideline generation requires **two** images per call:

```text
original selfie          (the surface to annotate — identity must be preserved)
canonical final preview  (the target reference, used only to understand intent)
```

Nothing in this project has ever proven that the image model produces correct
output from two input images, or that it reliably treats the second as a
*reference* rather than as something to blend into the first. That risk —
copying the finished makeup from the target onto the selfie — is precisely what
Source of Truth §6 and §14 forbid.

**This must be probed separately, whichever model is used.**

### 5. Image-output support — **NOT VERIFIED for `gemini-3.6-flash`**

No call in this repository has ever requested image output from
`gemini-3.6-flash`. The only model this project has ever asked for image bytes
is the `GEMINI_IMAGE_MODEL` default, `gemini-3.1-flash-image`, which does so in
production today (`generate-makeup-preview` is deployed at version 5).

The naming convention is corroborating but **not** proof on its own: the
`-image` suffix distinguishes the image-output variant. The decisive evidence is
that the project separates the variables at all, and that V2-5 established why
(§9).

### 6. Response shape — **VERIFIED, and the readers are incompatible**

Text path reads:

```ts
candidates[0].content.parts[].text        // joined, trimmed
```

Image path reads:

```ts
candidates[0].content.parts.find(p => p.inlineData?.data)
// -> { inlineData: { data: <base64>, mimeType } }
```

When no inline image part is present, the image client raises
**`GEMINI_NO_IMAGE_OUTPUT`** — distinguishing a refusal/`finishReason` (422,
non-retryable) from an empty response (502, retryable). A text model pointed at
the image path would produce `parts[].text` and no `inlineData`, so it would
fail here every time with `GEMINI_NO_IMAGE_OUTPUT`. **That is the exact error a
V3 implementation would hit if `gemini-3.6-flash` were hardcoded as the
guideline model.**

### 7. Inline image / MIME behavior — **VERIFIED**

From `generate-makeup-preview/image_validation.ts`, output is accepted only if:

| Check | Rule |
| --- | --- |
| MIME | exactly `image/png`, `image/jpeg` or `image/webp` |
| Decoding | base64 must decode |
| Magic bytes | signature must match the declared MIME (PNG header; JPEG `FFD8`…`FFD9`; WEBP `RIFF`/`WEBP`) |
| Size | ≥ 10 KB and ≤ 10 MB |

Input MIME is passed through from the stored object's extension. These rules
are directly reusable by V3 and satisfy the Source of Truth §23 requirement to
validate response shape, bytes, MIME, decodability and size.

### 8. Image edit / annotation capability — **VERIFIED for the image model**

`generate-makeup-preview` performs `image IN → edited image OUT`: it supplies
the user's original selfie and returns that same face with makeup applied. That
is an edit/transform of a supplied image, not text-to-image generation from
scratch.

This is genuinely encouraging for V3's use case — drawing instructional zones
and arrows onto an untouched selfie is the same class of operation. But it is
established for `gemini-3.1-flash-image`, **not** for `gemini-3.6-flash`.

Note the distinction that remains unproven for *any* model here: the preview
pipeline is asked to *alter the face* (apply makeup), whereas a V3 guideline
must **not** alter the face at all — only overlay marks. Whether the image model
will reliably leave the face untouched while adding an overlay is a separate
behavioural question that only device QA (§27) can answer.

---

## 9. Prior live-gate evidence

`docs/tutorial_v2/V2_MODEL_CONFIGURATION.md` — recovered in V3-0.5 and
retrievable with
`git show dc56ca1:docs/tutorial_v2/V2_MODEL_CONFIGURATION.md` — records V2-5
hitting this identical gate against a live integration:

> This document exists because V2-5's first attempt correctly halted at the
> model capability gate. `gemini-3.6-flash` had been assumed to be the image
> generator for the whole V2 pipeline. It is not. Later phases must not repeat
> that assumption.

and:

> That needs image output. `gemini-3.6-flash` cannot do it, so V2-5 uses
> `gemini-3.1-flash-image` — the image model already verified in this project's
> preview pipeline.

The stashed `NOTES.md` edit states the same in one line:

> `gemini-3.6-flash` cannot generate images.

This is a prior determination made by this project against this API. It is not
independent of the current codebase, but it *is* independent of my reading of
it, and it was reached at a time when a live call was possible.

---

## 10. How to confirm first-hand

One call settles it. Run this where `GEMINI_API_KEY` is available (never commit
the key, never paste it into a prompt or log):

```bash
# Capability probe: does gemini-3.6-flash return image bytes?
curl -s -X POST \
  "https://generativelanguage.googleapis.com/v1/models/gemini-3.6-flash:generateContent" \
  -H "content-type: application/json" \
  -H "x-goog-api-key: $GEMINI_API_KEY" \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [
        { "text": "Draw a translucent zone over the upper outer cheek of this photo. Return an image." },
        { "inlineData": { "mimeType": "image/jpeg", "data": "<base64 of any small jpeg>" } }
      ]
    }]
  }' | head -c 800
```

Read the result exactly as the production client does:

- **`candidates[0].content.parts[].inlineData.data` present** → image output
  works; reclassify this document to `SUPPORTED` and record the observed
  `mimeType`.
- **Only `candidates[0].content.parts[].text` present** → confirms
  **NOT SUPPORTED**; this is what the production client reports as
  `GEMINI_NO_IMAGE_OUTPUT`.
- **HTTP 404** → the model does not exist on the `/v1` image endpoint at all,
  which the production client already classifies as
  `GEMINI_MODEL_NOT_FOUND` (a configuration fault, never a transient outage).

To also close the §4 gap, repeat with **two** `inlineData` parts and check both
that an image comes back and that the second image was treated as a reference
rather than blended into the first.

---

## 11. What this phase did NOT do

Per §21 and the phase instructions:

- **No model was substituted.** `TUTORIAL_V3_GUIDELINE_MODEL` has not been
  created, defaulted, or written into any file.
- **No guideline code was written.** No Edge Function, no client, no prompt.
- **No configuration was changed.** `GEMINI_MODEL` and `GEMINI_IMAGE_MODEL`
  are untouched; no secret was set or read.
- **No remote call was made** — to Gemini or to Supabase beyond the read-only
  `secrets list` used to establish that the key is not locally available.

---

## 12. Decision required before V3-6

The verified image-output model in this project is `gemini-3.1-flash-image`
(`GEMINI_IMAGE_MODEL`, in production today). **Naming it here is information
for your decision, not a substitution** — Source of Truth §21 reserves that
choice for you, and V3 must not reuse `GEMINI_IMAGE_MODEL` in any case, because
a V3 model change would then silently alter the stable premium preview.

The options, stated neutrally:

| Option | What it means |
| --- | --- |
| **A — Confirm the gate** | Run the §10 probe. If it confirms NOT SUPPORTED, choose a different guideline model explicitly. |
| **B — Authorize the verified image model** | Set `TUTORIAL_V3_GUIDELINE_MODEL = gemini-3.1-flash-image` as a **new** variable, separate from `GEMINI_IMAGE_MODEL`. |
| **C — Name a different model** | Any other image-output model; it must pass this same gate, including §4. |

Whichever is chosen, the §4 multi-image gap must still be probed before V3-6
relies on sending two images.

---

## Acceptance

| # | Requirement | Status |
| --- | --- | --- |
| 1 | Endpoint / API version | ✅ verified — `/v1beta` text vs `/v1` image, split is exact |
| 2 | Request format | ✅ verified — `generationConfig` present on text path, absent on image path |
| 3 | Image input support | ✅ verified — supported on both paths, proves nothing about output |
| 4 | Multiple input / reference images | ⚠️ **not verified in this project** — separate gap, applies to any model |
| 5 | Image-output support | ❌ **not verified for `gemini-3.6-flash`** — never requested from it |
| 6 | Response shape | ✅ verified — `inlineData` vs `text`; readers are incompatible |
| 7 | Inline image / MIME behavior | ✅ verified — 3 MIME types, magic-byte check, 10 KB–10 MB |
| 8 | Image edit / annotation capability | ✅ verified for `gemini-3.1-flash-image`; unverified for the requested model |
| — | Classification | **NOT SUPPORTED** |
| — | No silent substitution | ✅ none made |
| — | No feature implementation | ✅ none |

**V3-5: ACCEPTED — gate result is NOT SUPPORTED.**

## STOP
