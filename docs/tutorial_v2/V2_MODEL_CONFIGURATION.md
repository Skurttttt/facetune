# Tutorial V2 — Model Configuration

**Status:** authoritative for V2 phases
**Last updated:** V2-5

This document exists because V2-5's first attempt correctly halted at the model
capability gate. `gemini-3.6-flash` had been assumed to be the image generator
for the whole V2 pipeline. It is not. Later phases must not repeat that
assumption.

---

## The split

FaceTune uses **two different kinds of Gemini model**, and they are not
interchangeable.

| | Text / structured output | Image output |
| --- | --- | --- |
| Capability | text and JSON out | image bytes out |
| Endpoint | `/v1beta/models/{model}:generateContent` | `/v1/models/{model}:generateContent` |
| Response read from | `candidates[].content.parts[].text` | `candidates[].content.parts[].inlineData` |
| Stable app variable | `GEMINI_MODEL` | `GEMINI_IMAGE_MODEL` |
| Stable app default | `gemini-3.6-flash` | `gemini-3.1-flash-image` |
| Used by | `analyze-face`, `generate-makeup-recommendation`, `generate-kit-makeup-recommendation` | `generate-makeup-preview`, `generate-kit-makeup-preview` |

Both kinds accept images as **input**. Only the image models produce an image
as **output**. That distinction is the whole point of this document: sending an
image *in* proves nothing about getting an image *out*.

---

## V2 configuration keys

| Key | Default | Phase | Status |
| --- | --- | --- | --- |
| `TUTORIAL_V2_PLANNER_MODEL` | `gemini-3.6-flash` | V2-4 | implemented |
| `TUTORIAL_V2_GUIDELINE_MODEL` | `gemini-3.1-flash-image` | V2-5 | implemented |
| `TUTORIAL_V2_RESULT_MODEL` | **undecided** | V2-6 | not decided |

All are read server-side only, with `Deno.env.get(...)?.trim() || <default>`.
None is ever exposed to Flutter. A model swap must never require changing
Flutter UI, domain entities, repositories, session logic, Step Specs,
persistence, or My Makeup Kit logic.

### Why the planner uses a text model

The planner's job is:

```text
canonical preview image + attributes + recommendation  IN
    -> structured tutorial plan JSON  OUT
```

That is a text-output task with image input, which is exactly what
`analyze-face` already does in production with `gemini-3.6-flash`.

### Why the guideline generator uses an image model

The guideline generator's job is:

```text
identity + base state + canonical target + Step Spec  IN
    -> one annotated instructional image  OUT
```

That needs image output. `gemini-3.6-flash` cannot do it, so V2-5 uses
`gemini-3.1-flash-image` — the image model already verified in this project's
preview pipeline.

### `TUTORIAL_V2_RESULT_MODEL` is deliberately not decided here

V2-6 generates cumulative result images. It will need an image-output model,
but the specific choice is V2-6's to make against evidence available at that
time. Do not pre-commit it in this document.

---

## Generation configuration

Neither preview function sets a `generationConfig`, and V2-5's guideline client
deliberately matches that. The reasoning is recorded in
`docs/AI_QUALITY_NOTES.md`:

> The preview function still sets no `generationConfig`. Image-model sampling
> parameters were left untouched because an unsupported field there returns a
> 400 and breaks generation outright; that change needs a live request to
> validate.

That reasoning still holds. Guideline consistency is therefore pursued through
the prompt — which is fully under our control and fully testable — rather than
through sampling fields that have never been validated against this endpoint.

Introducing sampling controls is a legitimate V2-11 experiment once real
guideline output can be observed. It must be done with a live request, one
field at a time, not by assumption.

---

## Rules for later phases

1. Never assume one model covers both text and image work.
2. Verify the capability actually required by the phase before hardcoding.
3. Never silently substitute a model. If the requested one cannot do the job,
   stop and report the exact incompatibility (Source of Truth §22).
4. A 404 from the image endpoint means the configured model was not found.
   Surface it as a configuration fault (`GEMINI_MODEL_NOT_FOUND`), never as a
   transient outage.
5. Keep every model behind its own server-side key.
