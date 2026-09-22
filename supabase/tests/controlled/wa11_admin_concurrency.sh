#!/usr/bin/env bash
# WA-11 — controlled concurrency scenarios for the privileged admin writers,
# against the local Supabase Postgres (container `supabase_db_facetune`).
#
# pgTAP runs in one session, so real lock contention cannot be shown there
# (`wa11_admin_concurrency_hardening_test.sql` proves the end-state
# invariants). This harness opens two sessions per scenario, makes them
# overlap on the per-account advisory lock that every admin writer and the
# usage engine take, and asserts the ledger, entitlement, and audit state
# afterwards. Fixtures are created and removed by the script.
#
# Run from the repository root with the local stack up:
#   bash supabase/tests/controlled/wa11_admin_concurrency.sh
set -euo pipefail

DB="docker exec -i supabase_db_facetune psql -U postgres -d postgres -v ON_ERROR_STOP=1 -q -At"
ADMIN_A='80000000-0000-4000-8000-0000000000b0'
ADMIN_B='80000000-0000-4000-8000-0000000000b1'
ARTIST='80000000-0000-4000-8000-0000000000b2'
claims() { printf '{"sub":"%s","role":"authenticated"}' "$1"; }
PASS=0; FAIL=0

check() { # check <label> <actual> <expected>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); echo "ok   - $1"; else FAIL=$((FAIL+1)); echo "FAIL - $1 (have: $2 want: $3)"; fi
}
q() { $DB -c "$1"; }

cleanup() {
  $DB -c "delete from auth.users where id in ('$ADMIN_A','$ADMIN_B','$ARTIST');" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup

# ---------------------------------------------------------------------------
# Fixture: two administrators and one Salon Pilot artist with a 30-look pilot.
# ---------------------------------------------------------------------------
$DB <<SQL >/dev/null
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, email_change, email_change_token_new, recovery_token, is_anonymous
)
select '00000000-0000-0000-0000-000000000000', v.id, 'authenticated', 'authenticated', v.email, '',
       timezone('utc', now()), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb,
       timezone('utc', now()), timezone('utc', now()), '', '', '', '', false
from (values ('$ADMIN_A'::uuid, 'wa11-race-admin-a@example.invalid'),
             ('$ADMIN_B'::uuid, 'wa11-race-admin-b@example.invalid'),
             ('$ARTIST'::uuid,  'wa11-race-artist@example.invalid')) as v(id, email);
insert into public.admin_users (user_id, note) values ('$ADMIN_A', 'wa11 race A'), ('$ADMIN_B', 'wa11 race B');
insert into public.analyses (id, user_id, original_image_path)
  values ('80000000-0000-4000-8000-0000000000c0', '$ARTIST', '$ARTIST/analyses/x/original/selfie.jpg');
insert into public.recommendations (id, user_id, analysis_id, makeup_style)
  values ('80000000-0000-4000-8000-0000000000c1', '$ARTIST', '80000000-0000-4000-8000-0000000000c0', 'natural');
begin;
select set_config('request.jwt.claims', '$(claims "$ADMIN_A")', true);
set local role authenticated;
select public.admin_grant_salon_pilot('$ARTIST', '2027-06-30T23:59:59Z', 'WA-11 race fixture', 'race-grant', 30, null);
commit;
SQL

PILOT=$(q "select id from public.user_entitlements where user_id='$ARTIST' and plan_code='salon_pilot'")
state() { q "select set_config('request.jwt.claims', '$(claims "$ARTIST")', false); select (public.resolve_subscription_state())->>'$1';" | tail -1; }
ent() { q "select $1 from public.user_entitlements where id='$PILOT'"; }
audits() { q "select count(*) from public.admin_audit_events where target_entitlement_id='$PILOT'${1:-}"; }
check "fixture: 30 available on the pilot" "$(state availableAiLooks)" "30"
check "fixture: one grant audit"           "$(audits)" "1"

TMP="${TMPDIR:-/tmp}/wa11_conc.$$"; mkdir -p "$TMP"

# Two sessions: A runs <sqlA> holding the account lock for two seconds
# before committing; B starts a moment later and must wait on that lock.
race() { # race <adminA> <sqlA> <adminB> <sqlB> <outA> <outB>
  $DB <<SQL > "$5" 2>&1 &
begin;
select set_config('request.jwt.claims', '$(claims "$1")', true);
set local role authenticated;
select ($2)::text;
select pg_sleep(2);
commit;
SQL
  local a=$!
  sleep 0.4
  $DB <<SQL > "$6" 2>&1 &
begin;
select set_config('request.jwt.claims', '$(claims "$3")', true);
set local role authenticated;
select ($4)::text;
commit;
SQL
  local b=$!
  wait $a $b
}
field() { grep -o "\"$2\": [^,}]*" "$1" | head -1 | sed 's/^[^:]*: //; s/"//g'; }

# ---------------------------------------------------------------------------
# R1 — the admin double-clicks +10: same key, two overlapping requests
# ---------------------------------------------------------------------------
race "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', 10, 'Double click', 'race-dbl', null, null)" \
     "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', 10, 'Double click', 'race-dbl', null, null)" \
     "$TMP/r1a" "$TMP/r1b"
check "R1: both requests succeed"            "$(field "$TMP/r1a" success)/$(field "$TMP/r1b" success)" "true/true"
check "R1: exactly one is the original, one a replay" "$(( $(grep -c '"replayed": true' "$TMP/r1a") + $(grep -c '"replayed": true' "$TMP/r1b") ))" "1"
check "R1: +10 applied once (40), one ledger row, version 2" \
  "$(ent 'base_ai_look_allowance + allowance_adjustment_total')/$(q "select count(*) from public.entitlement_allowance_adjustments where entitlement_id='$PILOT'")/$(ent version)" "40/1/2"
check "R1: one adjustment audit event"       "$(audits " and action='increase_allowance'")" "1"

# ---------------------------------------------------------------------------
# R2 — two admins at once: A +10, B +5, no expected version — no lost update
# ---------------------------------------------------------------------------
race "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', 10, 'A adds', 'race-a10', null, null)" \
     "$ADMIN_B" "public.admin_adjust_salon_pilot_allowance('$PILOT', 5, 'B adds', 'race-b5', null, null)" \
     "$TMP/r2a" "$TMP/r2b"
check "R2: both admins succeed"              "$(field "$TMP/r2a" success)/$(field "$TMP/r2b" success)" "true/true"
check "R2: B waited for A and saw A's change (B's response: effective 55)" "$(field "$TMP/r2b" effectiveAllowance)" "55"
check "R2: total 25 = 10 + 10 + 5, version 4, ledger sum equals total" \
  "$(ent allowance_adjustment_total)/$(ent version)/$(q "select sum(amount) from public.entitlement_allowance_adjustments where entitlement_id='$PILOT'")" "25/4/25"
check "R2: three adjustment audits, each with a distinct version" \
  "$(q "select count(*) || '/' || count(distinct (after_state->>'version')::int) from public.admin_audit_events where target_entitlement_id='$PILOT' and action='increase_allowance'")" "3/3"

# ---------------------------------------------------------------------------
# R3 — stale write: both admins loaded version 4 and submit against it
# ---------------------------------------------------------------------------
race "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', -10, 'A based on v4', 'race-stale-a', 4, null)" \
     "$ADMIN_B" "public.admin_adjust_salon_pilot_allowance('$PILOT', -20, 'B based on v4', 'race-stale-b', 4, null)" \
     "$TMP/r3a" "$TMP/r3b"
check "R3: the first to hold the lock applies"           "$(field "$TMP/r3a" success)" "true"
check "R3: the second is refused as stale, not applied over the first" "$(field "$TMP/r3b" errorCode)" "CONCURRENT_MODIFICATION"
check "R3: exactly one of the two landed (total 15, version 5)" "$(ent allowance_adjustment_total)/$(ent version)" "15/5"
check "R3: no audit for the refused write"   "$(audits)" "5"

# ---------------------------------------------------------------------------
# R4 — user generating during adjustment (both orders)
# ---------------------------------------------------------------------------
# effective 45 now. Spend 44 so exactly one look is free, then race a user
# reservation against an admin reduction that would not cover it.
$DB <<SQL >/dev/null
select set_config('request.jwt.claims', '$(claims "$ARTIST")', false);
do \$\$
declare i int; op uuid; img uuid;
begin
  for i in 1..44 loop
    op := gen_random_uuid();
    perform public.reserve_ai_look(op);
    insert into public.generated_images (user_id, analysis_id, recommendation_id, storage_path, generation_number)
      values ('$ARTIST', '80000000-0000-4000-8000-0000000000c0', '80000000-0000-4000-8000-0000000000c1',
              '$ARTIST/p' || i || '.png', i) returning id into img;
    perform public.commit_ai_look(op, 'standard', img);
  end loop;
end \$\$;
SQL
check "R4: precondition — 44 committed, 1 available" "$(state committedUsage)/$(state availableAiLooks)" "44/1"

# R4a: the user's reservation holds the lock first; the admin's reduction
# by 1 must wait and then be refused because the hold now counts.
race "$ARTIST"  "public.reserve_ai_look('80000000-0000-4000-8000-0000000000d1')" \
     "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', -1, 'cut during generation', 'race-cut-a', null, null)" \
     "$TMP/r4a" "$TMP/r4b"
check "R4a: the reservation is served"       "$(field "$TMP/r4a" ok)" "true"
check "R4a: the reduction waited and was refused (would strand the hold)" "$(field "$TMP/r4b" errorCode)" "ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION"
check "R4a: 0 available, never negative; allowance unchanged" "$(state availableAiLooks)/$(ent allowance_adjustment_total)" "0/15"

# R4b: release the hold, then the admin reduction holds the lock first; the
# user's reservation must wait and then be refused on capacity.
q "select set_config('request.jwt.claims', '$(claims "$ARTIST")', false); select public.release_ai_look('80000000-0000-4000-8000-0000000000d1', 'RACE_TEST');" >/dev/null
race "$ADMIN_A" "public.admin_adjust_salon_pilot_allowance('$PILOT', -1, 'cut before generation', 'race-cut-b', null, null)" \
     "$ARTIST"  "public.reserve_ai_look('80000000-0000-4000-8000-0000000000d2')" \
     "$TMP/r4c" "$TMP/r4d"
check "R4b: the reduction to the floor applies (44/44)" "$(field "$TMP/r4c" success)/$(field "$TMP/r4c" availableAiLooks)" "true/0"
check "R4b: the reservation waited and was refused on capacity" "$(field "$TMP/r4d" errorCode)" "AI_LOOK_LIMIT_REACHED"
check "R4b: nothing held, nothing negative, committed history intact" \
  "$(state reservedUsage)/$(state availableAiLooks)/$(state committedUsage)" "0/0/44"

# ---------------------------------------------------------------------------
# R5 — suspend during generation
# ---------------------------------------------------------------------------
$DB -c "begin; select set_config('request.jwt.claims', '$(claims "$ADMIN_A")', true); set local role authenticated; select public.admin_adjust_salon_pilot_allowance('$PILOT', 2, 'room', 'race-room', null, null); commit;" >/dev/null
race "$ARTIST"  "public.reserve_ai_look('80000000-0000-4000-8000-0000000000d3')" \
     "$ADMIN_A" "public.admin_set_salon_pilot_lifecycle('$PILOT', 'suspend_entitlement', 'review', 'race-susp', null, null)" \
     "$TMP/r5a" "$TMP/r5b"
check "R5: the reservation is served before the suspension lands" "$(field "$TMP/r5a" ok)" "true"
check "R5: the suspension waited and then applied"  "$(field "$TMP/r5b" success)/$(field "$TMP/r5b" status)" "true/suspended"
check "R5: the in-flight hold survives the suspension" "$(q "select status from public.usage_ledger where operation_id='80000000-0000-4000-8000-0000000000d3'")" "reserved"
check "R5: no new generation may start" \
  "$(q "select set_config('request.jwt.claims', '$(claims "$ARTIST")', false); select (public.reserve_ai_look('80000000-0000-4000-8000-0000000000d4'))->>'errorCode';" | tail -1)" "ENTITLEMENT_SUSPENDED"
IMG=$(q "insert into public.generated_images (user_id, analysis_id, recommendation_id, storage_path, generation_number) values ('$ARTIST', '80000000-0000-4000-8000-0000000000c0', '80000000-0000-4000-8000-0000000000c1', '$ARTIST/p45.png', 45) returning id")
check "R5: the already-authorized work still commits (reservation-time attribution)" \
  "$(q "select set_config('request.jwt.claims', '$(claims "$ARTIST")', false); select (public.commit_ai_look('80000000-0000-4000-8000-0000000000d3', 'standard', '$IMG'))->>'ok';" | tail -1)" "true"
check "R5: committed 45, nothing held, generation blocked" "$(state committedUsage)/$(state reservedUsage)/$(state generationAuthorized)" "45/0/false"

# ---------------------------------------------------------------------------
# R6 — revoke duplicate: same key, two overlapping requests
# ---------------------------------------------------------------------------
race "$ADMIN_A" "public.admin_set_salon_pilot_lifecycle('$PILOT', 'revoke_entitlement', 'terminated', 'race-rev', null, null)" \
     "$ADMIN_A" "public.admin_set_salon_pilot_lifecycle('$PILOT', 'revoke_entitlement', 'terminated', 'race-rev', null, null)" \
     "$TMP/r6a" "$TMP/r6b"
check "R6: both requests succeed"            "$(field "$TMP/r6a" success)/$(field "$TMP/r6b" success)" "true/true"
check "R6: exactly one replay"               "$(( $(grep -c '"replayed": true' "$TMP/r6a") + $(grep -c '"replayed": true' "$TMP/r6b") ))" "1"
check "R6: revoked once, one revocation audit, version advanced once" \
  "$(ent status)/$(audits " and action='revoke_entitlement'")/$(ent version)" "revoked/1/9"
check "R6: the account fell back to Free; the pilot's history is intact" \
  "$(state planCode)/$(q "select count(*) from public.usage_ledger where entitlement_id='$PILOT' and status='committed'")" "free/45"

# ---------------------------------------------------------------------------
# R7 — grant duplicate: same key, two overlapping requests on a fresh account
# ---------------------------------------------------------------------------
race "$ADMIN_A" "public.admin_grant_salon_pilot('$ARTIST', '2027-09-30T23:59:59Z', 'second pilot', 'race-grant-2', 30, null)" \
     "$ADMIN_A" "public.admin_grant_salon_pilot('$ARTIST', '2027-09-30T23:59:59Z', 'second pilot', 'race-grant-2', 30, null)" \
     "$TMP/r7a" "$TMP/r7b"
check "R7: both requests succeed, one replayed" \
  "$(field "$TMP/r7a" success)/$(field "$TMP/r7b" success)/$(( $(grep -c '"replayed": true' "$TMP/r7a") + $(grep -c '"replayed": true' "$TMP/r7b") ))" "true/true/1"
check "R7: exactly one new pilot row beside the revoked one" \
  "$(q "select count(*) from public.user_entitlements where user_id='$ARTIST' and plan_code='salon_pilot'")" "2"
check "R7: exactly one grant audit for the key" \
  "$(q "select count(*) from public.admin_audit_events where target_user_id='$ARTIST' and action='grant_salon_pilot' and idempotency_key='race-grant-2'")" "1"

# ---------------------------------------------------------------------------
# Global invariants after every race
# ---------------------------------------------------------------------------
check "invariant: adjustment totals equal ledger sums for every pilot" \
  "$(q "select bool_and(e.allowance_adjustment_total = coalesce((select sum(a.amount) from public.entitlement_allowance_adjustments a where a.entitlement_id = e.id), 0)) from public.user_entitlements e where e.user_id='$ARTIST'")" "t"
check "invariant: no negative capacity anywhere" \
  "$(q "select bool_and(greatest(0, e.base_ai_look_allowance + e.allowance_adjustment_total) >= (select count(*) from public.usage_ledger u where u.entitlement_id = e.id and u.status in ('committed','reserved'))) from public.user_entitlements e where e.user_id='$ARTIST' and e.plan_code='salon_pilot'")" "t"
check "invariant: no (target, action, key) audited twice" \
  "$(q "select count(*) from (select 1 from public.admin_audit_events where target_user_id='$ARTIST' group by target_user_id, action, idempotency_key having count(*) > 1) d")" "0"

echo
echo "WA-11 controlled concurrency: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
