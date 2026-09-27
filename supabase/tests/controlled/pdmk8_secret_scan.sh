#!/usr/bin/env bash
# PDMK-8 — secret and privacy scan of the plan-driven My Makeup Kit surfaces.
#
# (1) the Flutter client tree, (2) the plan-driven Edge Functions and shared
# modules, (3) what those server files may write to logs, and (4) the built
# Android APK, if present. Source comments are not exempt.
#
# Run from the repository root:
#   bash supabase/tests/controlled/pdmk8_secret_scan.sh
set -euo pipefail

PASS=0; FAIL=0
check() { # check <label> <actual> <expected>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); echo "ok   - $1"; else FAIL=$((FAIL+1)); echo "FAIL - $1 (have: $2 want: $3)"; fi
}
count() { grep -rEo "$2" $1 2>/dev/null | wc -l | tr -d ' '; }

# ---------------------------------------------------------------------------
# 1. Client
# ---------------------------------------------------------------------------
C="lib/features/makeup_kit lib/app"
check "client: no service-role or secret key reference" \
  "$(count "$C" 'service_role|SERVICE_ROLE|sb_secret_|SUPABASE_SERVICE')" "0"
check "client: no JWT literal" "$(count "$C" 'eyJ[A-Za-z0-9_-]{30,}')" "0"
check "client: no Gemini key, model call, or endpoint" \
  "$(grep -rEo --include='*.dart' 'GEMINI_API_KEY|AIza[0-9A-Za-z_-]{20,}|generativelanguage' $C | wc -l | tr -d ' ')" "0"
check "client: the durable store holds identifiers only" \
  "$(count lib/features/makeup_kit/data/data_sources/pdmk_pending_request_store.dart 'storage_?[Pp]ath|signed|token|bytes|colorHex|product_?[Nn]ame')" "0"
check "client: PDMK code never prints" \
  "$(count "lib/features/makeup_kit/data/data_sources/pdmk_pending_request_store.dart lib/features/makeup_kit/data/repositories/pdmk_preview_operation_driver.dart lib/features/makeup_kit/data/repositories/pdmk_pending_preview_resumer.dart lib/features/makeup_kit/presentation/widgets/pdmk_preview_resume_listener.dart" '(debugPrint|print)\(')" "0"

# ---------------------------------------------------------------------------
# 2. Server: where the service role may and may not be read
# ---------------------------------------------------------------------------
F="supabase/functions"
check "server: the service-role key is read only by the plan writers and telemetry" \
  "$(grep -rlE 'SUPABASE_SERVICE_ROLE_KEY' $F/_shared $F/generate-kit-makeup-recommendation $F/generate-kit-makeup-preview $F/analyze-tutorial-manifest-v4 --include='*.ts' | grep -v '_test\.ts$' | sort | tr '\n' ',')" \
  "$F/_shared/ai_telemetry.ts,$F/generate-kit-makeup-preview/plan_preview_supabase.ts,$F/generate-kit-makeup-recommendation/plan_request.ts,"
check "server: no Edge entrypoint reads the service-role key directly" \
  "$(count "$F/generate-kit-makeup-recommendation/index.ts $F/generate-kit-makeup-preview/index.ts $F/analyze-tutorial-manifest-v4/index.ts" 'SERVICE_ROLE')" "0"
check "server: no key literal anywhere in the functions tree" \
  "$(grep -rEo 'AIza[0-9A-Za-z_-]{30,}|sb_secret_[A-Za-z0-9_]{8,}|eyJ[A-Za-z0-9_-]{30,}\.eyJ[A-Za-z0-9_-]{30,}' $F --include='*.ts' | grep -v node_modules | wc -l | tr -d ' ')" "0"
# Every read or update of the server-only tables names the caller; the two
# inserts set user_id themselves.
S_PORTS="$F/generate-kit-makeup-preview/plan_preview_supabase.ts"
QUERIES=$(( $(grep -cE '(generations|attempts)\(\)' "$S_PORTS") - $(grep -cE '(generations|attempts)\(\)\.insert' "$S_PORTS") ))
check "server: every service-role read and update is scoped to the caller" \
  "$(grep -cE '\.eq\("user_id", userId\)' "$S_PORTS")" "$QUERIES"

# ---------------------------------------------------------------------------
# 3. Server logs: codes and counts only
# ---------------------------------------------------------------------------
P="$F/_shared/kit_makeup_plan.ts $F/_shared/kit_preview_integrity.ts $F/generate-kit-makeup-recommendation/plan_request.ts $F/generate-kit-makeup-preview/plan_route.ts $F/generate-kit-makeup-preview/plan_preview.ts $F/generate-kit-makeup-preview/plan_preview_supabase.ts $F/generate-kit-makeup-preview/validator.ts $F/generate-kit-makeup-preview/validator_client.ts $F/generate-kit-makeup-preview/readiness.ts"
check "logs: no path, hash, URL, token, prompt, evidence, image, or identity is interpolated" \
  "$(grep -hE 'console\.(log|error|warn)' $P | grep -ciE '\$\{[^}]*(path|sha|url|token|prompt|evidence|bytes|image|email|user|plan_json|snapshot|placement|technique)')" "0"

# ---------------------------------------------------------------------------
# 4. Built Android APK (skipped, not failed, when absent)
# ---------------------------------------------------------------------------
APK="build/app/outputs/flutter-apk/app-release.apk"
if [[ -f "$APK" ]]; then
  T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
  unzip -qq -o "$APK" 'lib/*/libapp.so' -d "$T"
  S="$T/strings.txt"; LC_ALL=C grep -aoE '[[:print:]]{6,}' "$T"/lib/*/libapp.so > "$S" || true
  check "apk: no Gemini key or endpoint" "$(grep -cE 'AIza[0-9A-Za-z_-]{30,}|generativelanguage|GEMINI_API_KEY' "$S")" "0"
  check "apk: no secret-key value" "$(grep -cE 'sb_secret_[A-Za-z0-9_]{8,}' "$S")" "0"
  # The public anon key is a JWT by design; no embedded JWT may carry the
  # service_role claim.
  JWTS="$(grep -oE 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}' "$S" || true)"
  ROLES=""
  for jwt in $JWTS; do
    p="$(printf '%s' "$jwt" | cut -d. -f2 | tr '_-' '/+')"
    while (( ${#p} % 4 )); do p="$p="; done
    ROLES="$ROLES$(printf '%s' "$p" | base64 -d 2>/dev/null | grep -oE '"role":"[a-z_]+"' || true),"
  done
  echo "info - embedded JWT roles: ${ROLES:-none}"
  check "apk: embedded JWTs are anon only" "$([[ "$ROLES" == *service_role* ]] && echo service_role || echo none)" "none"
else
  echo "skip - no release APK present (flutter build apk --release first)"
fi

echo "---"
echo "pass=$PASS fail=$FAIL"
[[ $FAIL -eq 0 ]]
