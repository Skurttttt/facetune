# Google Play billing — setup

What a person has to do by hand before a FaceTune purchase can be verified.
The code for the client (SUB-9) and for server-side verification (SUB-10) is
complete; none of the steps below can be performed from the repository.

Sections 1–7 are done. A real Internal Testing purchase of FaceTune Plus was
verified end to end on 2026-09-17: Google confirmed the purchase, the
entitlement was written, and the purchase was acknowledged. Section 8 is set
up separately.

---

## 1. Identity

| Fact | Value | Where it is fixed |
| --- | --- | --- |
| Application ID | `io.facetune.app` | `android/app/build.gradle.kts` |
| Play Billing Library | 8.0.0 | via `in_app_purchase_android` 0.5.0 |
| `com.android.vending.BILLING` | merged automatically | from the Play Billing AAR |

The package name must match the Play Console app exactly. It can never be
changed once an app is published under it.

---

## 2. Release signing (blocks everything below)

`android/key.properties` does not exist, so `flutter build appbundle --release`
currently signs with debug keys and Google Play will reject the result. Create
the upload keystore as described in `PRODUCTION_CHECKLIST.md`, then build.

No Gradle change is needed — the release signing config already reads that file
and falls back to debug keys with a build warning when it is absent.

---

## 3. Subscriptions in Play Console

Create three subscriptions, each with a **monthly** base plan:

| Product ID | Plan | AI Looks / period |
| --- | --- | --- |
| `facetune_plus` | FaceTune Plus | 3 |
| `facetune_pro` | FaceTune Pro | 8 |
| `facetune_salon_pro` | Salon Pro | 35 |

The product IDs must match exactly. They are compiled into the client
(`StoreProductCatalog`) and bound to plan codes server-side in
`subscription_products.provider_product_id`.

**Do not create a product for `free` or `salon_pilot`.** Free is the default
entitlement and Salon Pilot is admin-granted; neither is sold, and both the
schema and the verification function refuse a purchase that names them.

Prices come from Play. The app displays whatever the store returns for the
user's region and never a figure written into the app — see the approved
commercial baseline in the Subscription Source of Truth for the intended
amounts.

> Google's own documentation disagrees on whether an app bundle must be
> uploaded to a track *before* subscriptions can be configured. The Play
> Console help pages list only a payments profile and a supported merchant
> location as prerequisites; the Play Billing setup guide says to upload first.
> Uploading to Internal Testing before creating the products satisfies both.

---

## 4. Google Cloud service account

Server-side verification authenticates to the Google Play Developer API as a
service account. This credential is **backend only**. It must never be placed in
the Flutter app, committed, or shared with a client.

1. In the Google Cloud project linked to the Play Console, create a service
   account.
2. Create a JSON key for it and download it once.
3. In Play Console → **Users and permissions**, invite that service account and
   grant it access to the FaceTune app with the **View financial data** and
   **Manage orders and subscriptions** permissions.
4. Enable the **Google Play Android Developer API** in the Cloud project.

Linking Play Console to the Cloud project can take up to 24 hours to propagate.
Verification will fail with a temporary-backend error until it does.

---

## 5. Edge Function secrets

Set these on the Supabase project before deploying:

```bash
supabase secrets set GOOGLE_PLAY_PACKAGE_NAME=io.facetune.app
supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON="$(cat service-account.json)"
```

Then delete the local JSON file. It is not in `.gitignore` by name because it
should never be inside the repository in the first place.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
provided to Edge Functions by the platform.

### Why this function holds the service-role key

Every other subscription database function derives its authority from
`auth.uid()`, so it is safe to expose to `authenticated`.
`activate_verified_google_play_subscription` cannot: its *arguments* are the
authority, because the fact being asserted — "Google confirmed this purchase" —
lives outside the database. It is therefore granted to `service_role` alone, and
this function is its only caller.

The user's identity is still established from the user's own JWT. The privileged
client is used for that one RPC and for nothing else.

---

## 6. Deploy

```bash
supabase db push
supabase functions deploy verify-google-play-purchase
```

The migration fills `subscription_products.provider_product_id` for the three
plans and creates the verification table and activation function. It is additive
and re-runnable.

---

## 7. Testing a real purchase

1. Add tester Google accounts under Play Console → **License testing**.
2. Upload a release-signed bundle to Internal Testing and opt the testers in.
3. Buy a plan on a device signed in as a license tester. Test purchases are free
   and are recorded with `test_purchase = true`.

What should happen: the purchase sheet completes, the client sends only the
purchase token, the backend confirms it with Google, writes the entitlement,
acknowledges the purchase, and the app re-reads its plan from the server.

If verification fails the purchase is deliberately left unacknowledged, and
Google refunds it automatically within three days. That is the intended
outcome — the user is never charged for access they did not receive.

---

## 8. Lifecycle, renewal and restore

Built in SUB-11, and set up separately: see `GOOGLE_PLAY_RTDN_SETUP.md`.

Renewal, cancellation, grace, hold, pause, expiry, refund and revocation are
reconciled from Real-time Developer Notifications, each one verified against
`purchases.subscriptionsv2.get` before anything is written. Restore purchases
is live on the paywall and runs through the same verification path.

Note what this does *not* mean: an entitlement is never wrong because a
notification was missed. Authorization hangs off the verified `period_end`,
which refuses new generation once it passes whatever the recorded status says.
Notifications move the status promptly; they are not what makes it safe.

## 9. What is still not built

- Apple App Store verification. The schema reserves `apple_app_store` as a
  compatibility code; nothing in the Android-only V1 scope produces it.
- Free entitlement provisioning and the admin-granted Salon Pilot path.
- Plan upgrade and downgrade flows. A purchase that replaces another is
  reconciled correctly when Google links the two, but no UI offers a change.
