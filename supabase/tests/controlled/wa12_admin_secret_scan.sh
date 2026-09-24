#!/usr/bin/env bash
# WA-12 — secret and privacy scan of the Web Admin boundaries.
#
# Scans (1) the built admin web bundle, if present, (2) the admin Flutter
# tree, and (3) the admin Edge Functions for anything that must never cross
# the browser or server boundary: service-role or secret keys, JWTs, Gemini
# keys, provider secrets, purchase tokens, signed URLs, and private-content
# field names. Source comments are not exempt — a leaked value in a comment
# ships too.
#
# Run from the repository root (build first for the bundle scan):
#   flutter build web -t lib/admin_main.dart --dart-define-from-file=config/production.json
#   bash supabase/tests/controlled/wa12_admin_secret_scan.sh
set -euo pipefail

PASS=0; FAIL=0
check() { # check <label> <actual> <expected>
  if [[ "$2" == "$3" ]]; then PASS=$((PASS+1)); echo "ok   - $1"; else FAIL=$((FAIL+1)); echo "FAIL - $1 (have: $2 want: $3)"; fi
}
count() { grep -rEo "$2" $1 2>/dev/null | wc -l | tr -d ' '; }

# ---------------------------------------------------------------------------
# 1. Built bundle (skipped, not failed, when no build is present)
# ---------------------------------------------------------------------------
if [[ -f build/web/main.dart.js ]]; then
  B="build/web/main.dart.js build/web/flutter_bootstrap.js build/web/index.html"
  # The Supabase SDK ships the literal prefix `sb_secret_` in a constant used
  # to REFUSE secret keys on the client; a real key would be longer.
  check "bundle: no service-role key or secret-key value"   "$(count "$B" 'service_role|sb_secret_[A-Za-z0-9_]{8,}')" "0"
  check "bundle: no JWT"                                      "$(count "$B" 'eyJ[A-Za-z0-9_-]{30,}\.eyJ[A-Za-z0-9_-]{30,}')" "0"
  check "bundle: no Gemini / Google API key"                  "$(count "$B" 'AIza[0-9A-Za-z_-]{30,}|GEMINI_API_KEY')" "0"
  check "bundle: no Play service-account or private key"      "$(count "$B" 'BEGIN (RSA |EC )?PRIVATE KEY|private_key_id|client_secret')" "0"
  check "bundle: no purchase-token or signed-URL plumbing"    "$(count "$B" 'purchase_token|purchaseToken|createSignedUrl|signedUrl')" "0"
  check "bundle: no writer RPC is named (mutations reach the database only through the Edge Functions)" \
    "$(count build/web/main.dart.js 'admin_(grant_salon_pilot|adjust_salon_pilot_allowance|extend_salon_pilot_expiration|set_salon_pilot_lifecycle|consume_budget)')" "0"
  check "bundle: the read RPCs are the ten known ones" \
    "$(grep -oE 'admin_(list|get|search|dashboard|salon_pilot_research)_[a-z_]+' build/web/main.dart.js | sort -u | tr '\n' ',')" \
    "admin_dashboard_metrics,admin_get_audit_event,admin_get_user,admin_list_audit_events,admin_list_entitlement_history,admin_list_entitlements,admin_list_salon_pilot_metrics,admin_list_usage,admin_salon_pilot_research_metrics,admin_search_users,"
else
  echo "skip - no build/web bundle present (build the admin entrypoint first)"
fi

# ---------------------------------------------------------------------------
# 2. Admin Flutter tree
# ---------------------------------------------------------------------------
L="lib/admin lib/admin_main.dart"
check "flutter: no service-role, secret, or JWT literal"     "$(count "$L" 'service_role|sb_secret_|eyJ[A-Za-z0-9_-]{30,}|SUPABASE_SERVICE')" "0"
check "flutter: no Gemini / provider key or endpoint"         "$(count "$L" 'GEMINI|gemini|AIza[0-9A-Za-z_-]{20,}|generativelanguage')" "0"
check "flutter: no purchase token, signed URL, or storage path field" \
  "$(count "$L" 'purchase_?token|purchaseReference|purchase_reference|signed_?url|createSignedUrl|storage_path|storagePath')" "0"
check "flutter: no image, prompt, or kit content field"       "$(count "$L" 'original_image_path|canonical_generated_image_id|kit_generated_image|prompt_text|makeup_kit_items|rawPrompt')" "0"
check "flutter: no hardcoded email, UUID, or password"        "$(count "$L" '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|password *[:=] *['"'"'"]')" "0"

# ---------------------------------------------------------------------------
# 3. Admin Edge Functions and shared modules
# ---------------------------------------------------------------------------
F="supabase/functions/admin-session supabase/functions/admin-grant-salon-pilot supabase/functions/admin-adjust-salon-pilot-allowance supabase/functions/admin-salon-pilot-lifecycle supabase/functions/_shared/admin_auth.ts supabase/functions/_shared/admin_mutations.ts supabase/functions/_shared/admin_contract.ts supabase/functions/_shared/admin_read_models.ts"
check "functions: no service-role key is read"                "$(count "$F" 'SERVICE_ROLE|service_role')" "0"
check "functions: only the public URL and anon key are read"  "$(grep -rhoE 'Deno\.env\.get\("[A-Z_]+"\)' $F | sort -u | tr '\n' ',')" 'Deno.env.get("SUPABASE_ANON_KEY"),Deno.env.get("SUPABASE_URL"),'
check "functions: no Gemini or provider secret is read"       "$(count "$F" 'GEMINI|GOOGLE_PLAY|PRIVATE_KEY|client_secret')" "0"
check "functions: logs never include a reason, email, body, or token" \
  "$(grep -rhoE 'console\.(log|error)\([^)]*\$\{[^}]*(reason|email|body|token|intent\.reason)[^}]*\}' $F | wc -l | tr -d ' ')" "0"
check "functions: no JWT literal"                             "$(count "$F" 'eyJ[A-Za-z0-9_-]{30,}')" "0"

echo
echo "WA-12 secret scan: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
