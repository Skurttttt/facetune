# Tutorial V3 — guideline behaviour smoke gate (V3-6A)

Evidence-gathering harness for the V3-6A behavioural gate. It is **not**
production code and is deliberately outside `supabase/functions/`, so
`supabase functions deploy` can never pick it up.

## What it does

Sends two inline images plus one persisted-shaped Step Spec to the approved
guideline model and writes whatever comes back to disk:

```
IMAGE 1  original selfie          -> the base; must survive untouched
IMAGE 2  canonical final preview  -> reference only; must NOT be blended in
TEXT     Step Spec + scoped face attributes + strict visual rules
```

It runs the four required categories: **foundation, blush, eyeliner, lipstick**.

## Run

```bash
GEMINI_API_KEY=... npx -y deno@2 run \
  --allow-env --allow-net --allow-read --allow-write \
  tool/tutorial_v3_smoke/run_gate.ts
```

Options:

| Flag | Default | Meaning |
| --- | --- | --- |
| `--base=<path>` | `assets/images/beauty_portrait.png` | IMAGE 1 |
| `--target=<path>` | *(synthesised)* | IMAGE 2. If omitted, a stand-in canonical preview is generated from the base first. |
| `--out=<dir>` | `build/tutorial_v3_gate` | where evidence is written |

The model comes from `TUTORIAL_V3_GUIDELINE_MODEL` (default
`gemini-3.1-flash-image`). `GEMINI_IMAGE_MODEL` is deliberately **not**
consulted — V3 must be configurable without touching the premium preview.

## Output

```
build/tutorial_v3_gate/
  00_canonical_target.png      IMAGE 2 (only when synthesised)
  <category>_guideline.png     the generated guideline
  <category>_prompt.txt        the exact prompt sent
  summary.json                 status, byte counts, MIME, response part kinds
```

`build/` is gitignored, so generated faces are never committed.

## Reading the result

**Bytes are not a pass.** A successful run proves the request shape works and
the model returns image bytes. It says nothing about whether the overlays are
correct. Classification requires looking at the four images against the §14
criteria: identity preserved, no finished makeup, current category only, Step
Spec match, target alignment, IMAGE 2 not blended, no typography, and actually
useful to a person.

Record the outcome in
`docs/tutorial_v3/V3-6A_GUIDELINE_BEHAVIOR_SMOKE_GATE.md`.

## Tests

The prompt contract is machine-checkable and runs with no API key:

```bash
npx -y deno@2 test tool/tutorial_v3_smoke/
```
