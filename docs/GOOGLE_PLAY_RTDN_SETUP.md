# Real-time Developer Notifications — setup

What a person has to do by hand before FaceTune reconciles subscription
lifecycle changes. The code (SUB-11) is complete; none of the steps below can
be performed from the repository.

Prerequisite: everything in `GOOGLE_PLAY_BILLING_SETUP.md` is done and a real
purchase has been verified end to end.

---

## What this connects

```text
Google Play  →  Pub/Sub topic  →  push subscription  →  google-play-rtdn
                                                              ↓
                                              purchases.subscriptionsv2.get
                                                              ↓
                                                   entitlement reconciled
```

A notification only says *that* something changed. The function always reads
the subscription back from Google before writing anything, so a malformed,
replayed, or spoofed notification cannot move an entitlement on its own.

---

## 1. Pub/Sub topic

In the Google Cloud project that owns the Play service account
(`skurttttt-project`):

```bash
gcloud pubsub topics create facetune-play-rtdn
```

Grant Play permission to publish to it. This exact service account is Google's
own publisher and is the same for every developer:

```bash
gcloud pubsub topics add-iam-policy-binding facetune-play-rtdn \
  --member="serviceAccount:google-play-developer-notifications@system.gserviceaccount.com" \
  --role="roles/pubsub.publisher"
```

Without this binding Play Console refuses to save the topic.

---

## 2. Push service account

The identity Pub/Sub uses when it calls the Edge Function. It is **not** the
Play API service account, and it needs no Play permissions at all.

```bash
gcloud iam service-accounts create facetune-rtdn-push \
  --display-name="FaceTune RTDN push"

gcloud projects add-iam-policy-binding skurttttt-project \
  --member="serviceAccount:facetune-rtdn-push@skurttttt-project.iam.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

---

## 3. Push subscription

The endpoint is the deployed function's URL. The audience is pinned and must
match the secret set in step 5 exactly — the function rejects any token minted
for a different audience.

```bash
gcloud pubsub subscriptions create facetune-play-rtdn-push \
  --topic=facetune-play-rtdn \
  --push-endpoint="https://usmlwaocafeqnspdsvmv.supabase.co/functions/v1/google-play-rtdn" \
  --push-auth-service-account="facetune-rtdn-push@skurttttt-project.iam.gserviceaccount.com" \
  --push-auth-token-audience="https://facetune.app/rtdn" \
  --ack-deadline=60 \
  --message-retention-duration=7d
```

Notes on those last two flags:

- **`--ack-deadline=60`** — the function performs a token exchange and a
  Google API call before answering. Ten seconds is not enough and produces
  duplicate deliveries.
- **`--message-retention-duration=7d`** — a notification that fails
  transiently is retried until it succeeds or expires. Seven days is enough to
  survive an outage over a weekend.

The audience string is arbitrary but fixed. Anything stable works; it is
compared verbatim.

---

## 4. Point Play Console at the topic

Play Console → **Monetize** → **Monetization setup** → *Real-time developer
notifications*:

1. Set the topic name to
   `projects/skurttttt-project/topics/facetune-play-rtdn`.
2. Save.
3. Press **Send test notification**.

The test ping is recorded and deliberately not acted on — it names no purchase.
Confirm it arrived with the query in section 6.

---

## 5. Edge Function secrets

```bash
supabase secrets set GOOGLE_PLAY_RTDN_AUDIENCE="https://facetune.app/rtdn"
supabase secrets set GOOGLE_PLAY_RTDN_SERVICE_ACCOUNT="facetune-rtdn-push@skurttttt-project.iam.gserviceaccount.com"
```

Both are required. With either missing the function refuses every request
rather than accepting an unauthenticated caller — an endpoint outside the
Supabase JWT gate that trusted its body would be a way for anyone to post
subscription events.

`GOOGLE_PLAY_PACKAGE_NAME` and `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` are already
set from the billing setup and are reused here.

---

## 6. Deploy

```bash
supabase db push
supabase functions deploy google-play-rtdn
```

`verify_jwt = false` for this function is set in `supabase/config.toml` and is
required — Pub/Sub presents a Google identity token, which Supabase's own gate
would reject. The function verifies that token itself: signature against
Google's published keys, then audience, then the pushing service account.

Verify what arrived (service-role query):

```sql
select notification_kind, notification_type, outcome, received_at
from public.provider_notification_events
order by received_at desc
limit 20;
```

Expected outcomes:

| Outcome | Meaning |
| --- | --- |
| `reconciled` | Verified with Google; the entitlement now matches. |
| `revoked` | Verified as revoked or refunded; access ended, history kept. |
| `unmatched` | A purchase no FaceTune account has ever verified. Normal for a tester who reinstalled against a different account. |
| `conflict` | Google's answer disagreed with our record, or Google would not describe the purchase at all — it stops serving subscriptions expired or refunded more than 60 days ago. Nothing written. |
| `ignored` | A test ping, another package, or a block this app does not sell. |
| `processing` | In flight. A row older than five minutes means a worker died mid-flight; the next redelivery takes the claim over. |

---

## 7. Testing lifecycle transitions

Internal-testing subscriptions run on Google's accelerated clock: a monthly
plan renews every **5 minutes** and auto-renews **6 times** before expiring.
A full lifecycle is therefore observable in about half an hour.

| To test | Do this | Expect |
| --- | --- | --- |
| Renewal | Wait 5 minutes | `SUBSCRIPTION_RENEWED` → `reconciled`, `period_end` advances, allowance back to full |
| Cancellation | Cancel in Play → Subscriptions | `SUBSCRIPTION_CANCELED` → `reconciled`, status stays `active`, `auto_renew` false |
| Expiration | Wait past the cancelled period | `SUBSCRIPTION_EXPIRED` → `reconciled`, status `expired` |
| Restore | Reinstall, tap **Restore purchases** | The purchase is re-verified and the entitlement repaired |
| Refund | Refund the order in Play Console | `SUBSCRIPTION_REVOKED` → `revoked` |

Two things to check after expiry, because they are the rules most easily got
wrong:

- New Final Previews are refused.
- History, Saved Looks, existing Final Previews and Tutorials all still open.

---

## 8. If notifications stop arriving

1. `provider_notification_events` empty → the problem is upstream. Check the
   Pub/Sub subscription's unacked message count.
2. Messages unacked and growing → the function is refusing them. `401` in its
   logs means audience or service account mismatch; re-check step 5.
3. Rows stuck in `processing` for more than five minutes → a worker died
   mid-flight. The next redelivery reclaims and completes it. If rows keep
   appearing there, the function is crashing rather than failing cleanly;
   check its logs.
4. Everything `unmatched` → the purchases were never verified by a signed-in
   user on this backend. Reconciliation cannot invent an owner, by design.

An entitlement is never wrong *because* a notification was missed: capacity and
authorization hang off the verified `period_end`, which refuses generation once
it passes whatever the recorded status says.
