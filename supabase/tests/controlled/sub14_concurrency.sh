#!/usr/bin/env bash
# SUB-14 — controlled concurrency scenarios against the local Supabase
# Postgres (container `supabase_db_facetune`).
#
# pgTAP runs in one session, so real lock contention cannot be shown there.
# This harness opens two sessions per scenario, makes them overlap on the
# per-account advisory lock, and asserts the ledger arithmetic afterwards.
# Fixtures are created and removed by the script; nothing survives it.
#
# Run from the repository root with the local stack up:
#   bash supabase/tests/controlled/sub14_concurrency.sh
set -euo pipefail

DB="docker exec -i supabase_db_facetune psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -At"
U='10000000-0000-4000-8000-000000000401'
CLAIMS='{"sub":"'"$U"'","role":"authenticated"}'
PASS=0; FAIL=0

check() { # check <label> <actual> <expected>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); echo "ok   - $1"; else FAIL=$((FAIL+1)); echo "FAIL - $1 (have: $2 want: $3)"; fi
}

q() { $DB -c "$1"; }

# Removing the auth user cascades through every owned row. (Ledger and
# grant rows refuse direct deletes by trigger — deliberately — so the
# account itself is the only handle.)
cleanup() {
  $DB -c "delete from auth.users where id = '$U';" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# ---------------------------------------------------------------------------
# Fixture: a Plus account with one included AI Look left and one purchased
# Tutorial-capable credit.
# ---------------------------------------------------------------------------
$DB <<SQL >/dev/null
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token
) values (
  '00000000-0000-0000-0000-000000000000', '$U', 'authenticated', 'authenticated',
  'sub14-concurrency@example.invalid', '', timezone('utc', now()),
  '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
  timezone('utc', now()), timezone('utc', now()), '', '', '', ''
);
select public.activate_verified_google_play_subscription(
  '$U', 'facetune_plus', repeat('1', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '29 days',
  true, null, true);
select public.grant_verified_top_up_purchase('$U', 'facetune_ai_look_topup_1', repeat('2', 64), 'PURCHASED');
-- Spend two of the three included AI Looks.
insert into public.analyses (id, user_id, original_image_path)
  values ('40000000-0000-4000-8000-000000000401', '$U', '$U/analyses/x/original/selfie.jpg');
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
  values ('41000000-0000-4000-8000-000000000401', '$U', '40000000-0000-4000-8000-000000000401', 'natural');
select set_config('request.jwt.claims', '$CLAIMS', false);
select public.reserve_ai_look('50000000-0000-4000-8000-000000000001');
select public.reserve_ai_look('50000000-0000-4000-8000-000000000002');
insert into public.generated_images (id, user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values ('42000000-0000-4000-8000-000000000001', '$U', '40000000-0000-4000-8000-000000000401',
          '41000000-0000-4000-8000-000000000401', '$U/p1.png', 1),
         ('42000000-0000-4000-8000-000000000002', '$U', '40000000-0000-4000-8000-000000000401',
          '41000000-0000-4000-8000-000000000401', '$U/p2.png', 2);
select public.commit_ai_look('50000000-0000-4000-8000-000000000001', 'standard', '42000000-0000-4000-8000-000000000001');
select public.commit_ai_look('50000000-0000-4000-8000-000000000002', 'standard', '42000000-0000-4000-8000-000000000002');
SQL

state() { q "select set_config('request.jwt.claims', '$CLAIMS', false); select (public.resolve_subscription_state())->>'$1';" | tail -1; }
check "fixture: one included AI Look left"      "$(state availableAiLooks)" "1"
check "fixture: one purchased credit stored"    "$(state purchasedTutorialCreditsRemaining)" "1"

# Two sessions racing on one operation each. Session A holds the account
# lock (inside reserve) for two seconds before committing; B starts a
# moment later and must wait on that lock, then see A's row.
race_reserve() { # race_reserve <opA> <opB> <outA> <outB>
  $DB <<SQL > "$3" 2>&1 &
begin;
select set_config('request.jwt.claims', '$CLAIMS', true);
select public.reserve_ai_look('$1')::text;
select pg_sleep(2);
commit;
SQL
  local a=$!
  sleep 0.4
  $DB <<SQL > "$4" 2>&1 &
begin;
select set_config('request.jwt.claims', '$CLAIMS', true);
select public.reserve_ai_look('$2')::text;
commit;
SQL
  local b=$!
  wait $a $b
}

TMP="${TMPDIR:-/tmp}/sub14_conc.$$"; mkdir -p "$TMP"

# ---------------------------------------------------------------------------
# C1 — one included credit remaining, two simultaneous requests
# ---------------------------------------------------------------------------
race_reserve '50000000-0000-4000-8000-000000000011' '50000000-0000-4000-8000-000000000012' "$TMP/c1a" "$TMP/c1b"
A=$(grep -c '"ok": true' "$TMP/c1a" || true); B=$(grep -c '"ok": true' "$TMP/c1b" || true)
check "C1: both requests answered"                 "$(( $(grep -c '"ok"' "$TMP/c1a") + $(grep -c '"ok"' "$TMP/c1b") ))" "2"
check "C1: both are served (one included, one purchased), nobody twice" "$((A + B))" "2"
check "C1: the loser of the included credit is served the purchased credit, not refused" \
  "$(grep -o '"allowanceSource": "[a-z_]*"' "$TMP/c1a" "$TMP/c1b" | grep -o '[a-z_]*"$' | sort | tr -d '"' | paste -sd,)" "purchased_credit,subscription"
check "C1: two holds, no double-spend on the subscription" \
  "$(q "select count(*) filter (where allowance_source='subscription') || '/' || count(*) filter (where allowance_source='purchased_credit') from public.usage_ledger where user_id='$U' and status='reserved'")" "1/1"
check "C1: resolver shows 0 available, 0 purchased available" \
  "$(state availableAiLooks)/$(state availablePurchasedCredits)" "0/0"

# ---------------------------------------------------------------------------
# C2 — one top-up credit remaining, two simultaneous requests
# ---------------------------------------------------------------------------
# Release the purchased hold from C1 so exactly one purchased credit is free
# and the subscription is fully held.
q "select set_config('request.jwt.claims', '$CLAIMS', false); select public.release_ai_look((select operation_id from public.usage_ledger where user_id='$U' and allowance_source='purchased_credit' and status='reserved'), 'TEST');" >/dev/null
check "C2: precondition — one purchased credit free, subscription held" \
  "$(state availableAiLooks)/$(state availablePurchasedCredits)" "0/1"
race_reserve '50000000-0000-4000-8000-000000000021' '50000000-0000-4000-8000-000000000022' "$TMP/c2a" "$TMP/c2b"
A=$(grep -c '"ok": true' "$TMP/c2a" || true); B=$(grep -c '"ok": true' "$TMP/c2b" || true)
check "C2: exactly one wins the last purchased credit"   "$((A + B))" "1"
check "C2: the loser is refused on capacity" \
  "$(grep -o 'AI_LOOK_LIMIT_REACHED' "$TMP/c2a" "$TMP/c2b" | wc -l | tr -d ' ')" "1"
check "C2: exactly one live purchased-credit hold" \
  "$(q "select count(*) from public.usage_ledger where user_id='$U' and allowance_source='purchased_credit' and status in ('reserved','committed')")" "1"

# ---------------------------------------------------------------------------
# C3 — the same operation id from two devices at once
# ---------------------------------------------------------------------------
# Free one included credit to have something to hold.
q "select set_config('request.jwt.claims', '$CLAIMS', false); select public.release_ai_look((select operation_id from public.usage_ledger where user_id='$U' and allowance_source='subscription' and status='reserved'), 'TEST');" >/dev/null
race_reserve '50000000-0000-4000-8000-000000000031' '50000000-0000-4000-8000-000000000031' "$TMP/c3a" "$TMP/c3b"
check "C3: both devices get ok"          "$(( $(grep -c '"ok": true' "$TMP/c3a") + $(grep -c '"ok": true' "$TMP/c3b") ))" "2"
check "C3: exactly one is the original, one a replay" \
  "$(( $(grep -c '"replayed": true' "$TMP/c3a") + $(grep -c '"replayed": true' "$TMP/c3b") ))" "1"
check "C3: one ledger row for the operation" \
  "$(q "select count(*) from public.usage_ledger where operation_id='50000000-0000-4000-8000-000000000031'")" "1"

# ---------------------------------------------------------------------------
# C4 — renewal arrives while a reservation is being taken
# ---------------------------------------------------------------------------
# Session A reserves and sleeps inside its transaction while holding the
# account lock; session B is the provider's renewal write for the same
# account (also takes the lock). Both must land, in either order, with one
# entitlement row and the hold attached to it.
q "select set_config('request.jwt.claims', '$CLAIMS', false); select public.release_ai_look('50000000-0000-4000-8000-000000000031', 'TEST');" >/dev/null
$DB <<SQL > "$TMP/c4a" 2>&1 &
begin;
select set_config('request.jwt.claims', '$CLAIMS', true);
select public.reserve_ai_look('50000000-0000-4000-8000-000000000041')::text;
select pg_sleep(2);
commit;
SQL
a=$!; sleep 0.4
$DB <<SQL > "$TMP/c4b" 2>&1 &
select public.activate_verified_google_play_subscription(
  '$U', 'facetune_plus', repeat('1', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '59 days',
  true, null, true)::text;
SQL
b=$!; wait $a $b
check "C4: the reservation landed"           "$(grep -c '"ok": true' "$TMP/c4a")" "1"
check "C4: the renewal landed"               "$(grep -c '"ok": true' "$TMP/c4b")" "1"
check "C4: still one paid entitlement"       "$(q "select count(*) from public.user_entitlements where user_id='$U' and plan_code<>'free'")" "1"
check "C4: the hold is attached to that entitlement" \
  "$(q "select (l.entitlement_id = e.id)::text from public.usage_ledger l join public.user_entitlements e on e.user_id=l.user_id and e.plan_code<>'free' where l.operation_id='50000000-0000-4000-8000-000000000041'")" "true"
check "C4: the new period starts fresh (3 available) while the old hold is history" \
  "$(state availableAiLooks)" "3"

# ---------------------------------------------------------------------------
# C5 — expiry boundary during a reservation (reservation-time attribution)
# ---------------------------------------------------------------------------
# The hold from C4 was authorized while the plan was live. The provider now
# reports expiry. The already-authorized generation may still be committed;
# no new one may start.
$DB <<SQL >/dev/null
select public.activate_verified_google_play_subscription(
  '$U', 'facetune_plus', repeat('1', 64), 'SUBSCRIPTION_STATE_EXPIRED',
  timezone('utc', now()) - interval '31 days', timezone('utc', now()) - interval '1 minute',
  false, null, true);
insert into public.generated_images (id, user_id, analysis_id, recommendation_id, storage_path, generation_number)
  values ('42000000-0000-4000-8000-000000000003', '$U', '40000000-0000-4000-8000-000000000401',
          '41000000-0000-4000-8000-000000000401', '$U/p3.png', 3);
SQL
check "C5: the expired plan no longer governs; the account is back on Free" \
  "$(state planCode)/$(state availableAiLooks)" "free/1"
check "C5: a new reservation is served by Free's own lifetime look, never by the expired plan" \
  "$(q "select set_config('request.jwt.claims', '$CLAIMS', false); select (public.reserve_ai_look('50000000-0000-4000-8000-000000000051'))->>'ok';" | tail -1)/$(q "select plan_code from public.usage_ledger where operation_id='50000000-0000-4000-8000-000000000051'")" "true/free"
check "C5: with Free spent, the next reservation is refused" \
  "$(q "select set_config('request.jwt.claims', '$CLAIMS', false); select (public.reserve_ai_look('50000000-0000-4000-8000-000000000052'))->>'errorCode';" | tail -1)" "AI_LOOK_LIMIT_REACHED"
check "C5: the pre-expiry hold still commits (attributed at reservation time)" \
  "$(q "select set_config('request.jwt.claims', '$CLAIMS', false); select (public.commit_ai_look('50000000-0000-4000-8000-000000000041', 'standard', '42000000-0000-4000-8000-000000000003'))->>'ok';" | tail -1)" "true"
check "C5: the committed row keeps its Plus / AI Look provenance" \
  "$(q "select plan_code || '/' || allowance_unit from public.usage_ledger where operation_id='50000000-0000-4000-8000-000000000041'")" "plus/ai_look"

# ---------------------------------------------------------------------------
# C6 — plan transition around a reservation
# ---------------------------------------------------------------------------
$DB <<SQL >/dev/null
select public.activate_verified_google_play_subscription(
  '$U', 'facetune_plus', repeat('3', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '29 days',
  true, null, true);
SQL
$DB <<SQL > "$TMP/c6a" 2>&1 &
begin;
select set_config('request.jwt.claims', '$CLAIMS', true);
select public.reserve_ai_look('50000000-0000-4000-8000-000000000061')::text;
select pg_sleep(2);
commit;
SQL
a=$!; sleep 0.4
$DB <<SQL > "$TMP/c6b" 2>&1 &
select public.activate_verified_google_play_subscription(
  '$U', 'facetune_plus_preview', repeat('4', 64), 'SUBSCRIPTION_STATE_ACTIVE',
  timezone('utc', now()) - interval '1 day', timezone('utc', now()) + interval '29 days',
  true, repeat('3', 64), true)::text;
SQL
b=$!; wait $a $b
check "C6: the reservation on Plus landed"     "$(grep -c '"ok": true' "$TMP/c6a")" "1"
check "C6: the replacement to Plus Preview landed" "$(grep -c '"ok": true' "$TMP/c6b")" "1"
check "C6: one entitlement, now Plus Preview"  "$(q "select string_agg(plan_code, ',') from public.user_entitlements where user_id='$U' and status='active' and plan_code<>'free'")" "plus_preview"
check "C6: the hold keeps the provenance of the plan it was reserved under" \
  "$(q "select plan_code || '/' || allowance_unit from public.usage_ledger where operation_id='50000000-0000-4000-8000-000000000061'")" "plus/ai_look"
check "C6: no client-forged state — the resolver reports the provider's plan" "$(state planCode)" "plus_preview"

echo
echo "SUB-14 concurrency: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
