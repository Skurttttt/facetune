# SUB-13 unit-economics evidence

Cost model version: `sub13_unit_economics_v1`

Status: reporting-only; insufficient observed production data for a commercial
decision.

Retrieval date: 2026-09-20 (Asia/Taipei).

## Boundary

This model is not runtime, entitlement, allowance, billing, purchase, or price
authority. It consumes privacy-safe technical counters after the fact. Mutable
provider prices and FX remain outside the application and database migration.

The telemetry schema version is `sub13_v1`. A successful delivered Final
Preview is a unique `final_preview`/`succeeded` metric joined to a committed
usage-ledger operation. A provider retry is `provider_attempt_count`, not a
second delivered unit. Tutorial manifest and generated-step calls are separate
technical operations and are counted only when a new provider call occurred.

## External inputs

- Provider: Google Gemini Developer API, Standard paid tier.
- Final Preview and Tutorial guideline model: `gemini-3.1-flash-image`.
- Official price on 2026-09-20: USD 0.50 per 1M input text/image tokens; USD
  3.00 per 1M text/thinking output tokens; USD 60.00 per 1M image-output
  tokens. Google lists a 1K image as 1,120 image tokens and USD 0.067.
- Tutorial manifest model: `gemini-3.6-flash`.
- Official introductory Standard price through 2026-12-31: USD 0.75 per 1M
  input tokens, USD 3.75 per 1M output tokens including thinking, and USD
  0.075 per 1M cached tokens. Prices increase from 2027-01-01, so this model
  must be re-versioned before using it after that boundary.
- Provider source: https://ai.google.dev/gemini-api/docs/pricing
- Model/default-resolution sources:
  https://ai.google.dev/gemini-api/docs/models/gemini-3.1-flash-image and
  https://ai.google.dev/gemini-api/docs/image-generation
- FX source: Bangko Sentral ng Pilipinas SDDS, Philippine peso per US dollar,
  2026-09-18 (latest available on the retrieval date): `1 USD = PHP 62.785`.
- FX source URL: https://www.bsp.gov.ph/Statistics/sdds/sdds.aspx

The BSP rate is a public reference conversion, not the rate on a cloud invoice.
Taxes, discounts, free-tier effects, contracted pricing, and payment timing can
make invoice conversion different.

## Evidence categories and formulas

- `MEASURED`: provider usage counters emitted by the accepted provider response.
- `ESTIMATED_FROM_PROVIDER_USAGE`: measured counters multiplied by the cited
  list prices, then by the cited FX rate.
- `MODELLED`: a stated scenario using published per-image equivalents when no
  operation-level usage exists.
- `INSUFFICIENT_DATA`: no representative measured window or a required billing
  dimension is absent.

For image operations, the defensible reporting calculation is the observed
input tokens at USD 0.50/1M plus observed text/thinking output at USD 3.00/1M
plus observed image-output tokens at USD 60.00/1M. Modality totals must be
reconciled so a token appearing in an aggregate and its modality detail is not
charged twice. If that reconciliation is unavailable, use the documented
per-image equivalent as a labelled modelled floor rather than claiming an
exact request cost.

For the text-only manifest, use observed input, output/thinking, and cached
token counters with the `gemini-3.6-flash` prices above. Missing counters remain
unknown; they are never fabricated as zero.

## Observed window

The SUB-13 implementation has not been remotely deployed. The local validation
window on 2026-09-20 contains no real Gemini calls and no successful delivered
production units. SQL telemetry fixtures were transactionally rolled back.
The one accepted SUB-12B sandbox Final Preview predates this instrumentation,
so it proves delivery and charging behavior but supplies no SUB-13 provider
usage counters. Effective delivered-unit costs are therefore
`INSUFFICIENT_DATA`.

## Modelled output-only floor

The locked image model defaults to 1K when no size is requested, while Tutorial
guidelines explicitly request 1K. At published Standard list price and the BSP
reference FX rate:

`USD 0.067 × PHP 62.785/USD = PHP 4.206595`

Rounded for reporting, one 1K image-output component is `PHP 4.21`. This is not
the complete cost of a request: input images/text, text/thinking output,
failed attempts, retries, storage, and networking are excluded.

A maximum-nine-step Tutorial scenario has one Final Preview plus nine generated
1K guideline images:

`10 × PHP 4.206595 = PHP 42.065950`

Rounded, that scenario's image-output-only component is `PHP 42.07`, before the
manifest, inputs, thinking/text, retries, failures, storage, and networking.
Not every accepted manifest contains nine generated steps, so this is a
scenario, not a per-AI-Look observation.

## Locked matrix scenario

The values below apply only the output-only floors above at full allowance
utilization. Cost is a lower bound; gross contribution before non-AI expenses
is therefore an upper bound.

| Offer | Retail | Allowance | Modelled AI/API cost floor | Gross contribution ceiling before non-AI expenses |
| --- | ---: | ---: | ---: | ---: |
| Plus | PHP 399 | 3 AI Looks | PHP 126.20 | PHP 272.80 |
| Plus Preview | PHP 399 | 30 Final Preview Credits | PHP 126.20 | PHP 272.80 |
| Pro | PHP 899 | 8 AI Looks | PHP 336.53 | PHP 562.47 |
| Pro Preview | PHP 899 | 80 Final Preview Credits | PHP 336.53 | PHP 562.47 |
| Salon Pro | PHP 2,999 | 35 AI Looks | PHP 1,472.31 | PHP 1,526.69 |
| Salon Preview | PHP 2,999 | 350 Final Preview Credits | PHP 1,472.31 | PHP 1,526.69 |

Excluded non-AI expenses include Google Play fees, taxes, Supabase, storage,
networking, support, refunds, chargebacks, payroll, and other operating costs.
The table is not a profit or net-margin statement.

## Planning hypotheses and top-up candidates

- `PHP 45` per Tutorial-enabled AI Look: `INSUFFICIENT DATA`. The nine-step
  image-output scenario is PHP 42.07 before other provider dimensions, so the
  hypothesis is plausible but is neither supported nor disproved by measured
  operations.
- `PHP 4` per Preview-only Final Preview: `INSUFFICIENT DATA`. The published
  1K output component alone converts to PHP 4.21, already PHP 0.21 (5.16%) over
  the hypothesis before inputs and overhead.
- Candidate A, PHP 149 for one Tutorial-capable AI Look: modelled technical
  floor PHP 42.07; gross-contribution ceiling PHP 106.93; technical cost is at
  least 28.23% of retail. Assessment: `INSUFFICIENT DATA`.
- Candidate B, PHP 149 for ten Preview-only Final Preview Credits: modelled
  technical floor PHP 42.07; gross-contribution ceiling PHP 106.93; technical
  cost is at least 28.23% of retail. Assessment: `INSUFFICIENT DATA`.

No top-up product, product id, purchased-credit ledger, balance, purchase flow,
price change, or allowance change is authorized or implemented by this report.
Human commercial approval remains required after a representative measured
window captures delivered units, actual step counts, token modalities,
failures, retries, and invoice reconciliation.
