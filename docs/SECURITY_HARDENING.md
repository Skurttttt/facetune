# FaceTune security hardening (Phase 16)

This document records the Phase 16 audit: what the application code and backend
functions already enforce, what this phase changed, and what still requires
configuration in the Supabase dashboard or Google Cloud console.

## Trust boundary

```text
Flutter client  ── project URL + publishable key only
      ↓ user JWT
Edge Function   ── verifies JWT, acts as the caller via RLS
      ↓ server-only secret
Gemini API      ── GEMINI_API_KEY never leaves the server
```

- The Flutter client receives only `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
  `SupabaseConfig.validate()` rejects any key that is not `sb_publishable_`, so a
  service-role or secret key cannot be shipped by accident.
- `config/development.json` and `config/production.json` are gitignored; only
  `config/example.json` (placeholders) is committed.
- No Gemini key, service-role key, or database password exists anywhere in the
  Flutter source, assets, or Android manifest. Git history was searched for key
  literals and contains only environment-variable names.
- Every Edge Function builds its Supabase client from the **anon** key plus the
  caller's `Authorization` header. No function uses a service-role key, so RLS
  applies to every backend query.

## Authorization model

- All six application tables have RLS enabled, `anon` access revoked, and
  owner-only policies for select/insert/update/delete.
- Composite foreign keys (`(id, user_id)`, `(id, analysis_id, user_id)`) make
  cross-account linkage structurally impossible: a recommendation cannot point at
  another account's analysis even if the ID is guessed.
- `face-images` and `profile-avatars` are private buckets with size limits and
  MIME allow-lists. Storage policies require the first path segment to equal
  `auth.uid()`.
- `face-images` has no UPDATE policy, so an original selfie can never be
  overwritten.
- Images are read through short-lived signed URLs; only object paths are stored
  in PostgreSQL.
- SECURITY DEFINER functions all set `search_path = ''` and fully qualify names.

## Changed in Phase 16

### 1. Server-enforced AI quotas (new)

Previously any authenticated account could call the Gemini-backed functions an
unlimited number of times. `20260812000100_ai_usage_quota.sql` adds
`public.ai_usage_events` and `public.consume_ai_quota(text)`.

| Operation | Per hour | Per day |
| --- | --- | --- |
| `face_analysis` | 20 | 100 |
| `makeup_recommendation` | 40 | 200 |
| `makeup_preview` | 30 | 120 |

- Limits live **inside** the SQL function, not in its arguments, so a caller
  invoking the RPC directly cannot raise its own ceiling.
- `authenticated` holds `select` only. It cannot insert, edit, or delete usage
  rows, so a client cannot forge or reset its quota.
- The identity comes from `auth.uid()`, never from the request body.
- The check **fails closed**: if the quota RPC errors, the request is denied
  rather than allowed through to Gemini.
- Quota is consumed after validation and after the cached-result short circuit,
  so rejected and already-completed requests do not spend it.
- Exceeding a limit returns HTTP 429 with code `rate_limited`; the Flutter
  repositories map that to a friendly retryable message.

### 2. Strict storage-path ownership

`_shared/storage_ownership.ts` replaces prefix matching with exact segment
comparison. A `startsWith` test accepted traversal segments (`..`) and extra
path segments; the paths are now validated segment by segment with a UUID
filename check. `delete-history-item` rejects `.` and `..` segments as well.

### 3. Error-message leakage

`generate-makeup-preview` embedded internal codes in user-facing text
(`"[DATABASE_INSERT_FAILED] …"`). The machine-readable `code` field is retained
for client mapping; the human-readable `message` no longer carries internal
state names.

### 4. Explicit JWT verification

`delete-history-item` had no `verify_jwt` entry in `config.toml`. It is now
explicit for all four functions.

## Verified, unchanged

- Payload validation: UUID pattern checks, style allow-list, JSON-parse
  guarding, and a 500-character storage-path bound.
- File validation: size bounds (10 MiB), MIME allow-lists, and bucket-level
  limits, enforced both client-side and again server-side.
- Structured AI output is schema-validated before it becomes a typed model;
  malformed or refused responses map to sanitized failures.
- Gemini keys travel in the `x-goog-api-key` header, never a URL query string,
  and upstream retries are bounded (2 attempts).
- Logs record operation names, model IDs, status codes, and error *types* only —
  no image bytes, storage paths, user IDs, tokens, or raw upstream bodies.
- Deletion is authorized by RLS plus an exact owner-prefix check, removes
  storage objects before database rows, and verifies the prefix is empty
  afterwards.

## Requires manual configuration (not solvable in code)

1. **Apply the new migration**: `supabase db push` — quotas are not enforced
   until `20260812000100_ai_usage_quota.sql` is applied.
2. **Redeploy the Edge Functions** so the quota checks take effect:
   `npx -y supabase functions deploy analyze-face generate-makeup-recommendation generate-makeup-preview delete-history-item`
3. **Schedule usage cleanup**: `public.purge_ai_usage_events()` is not
   self-scheduling. Add a pg_cron job (Dashboard → Database → Cron) to run it
   daily.
4. **Restrict the Gemini API key** in the Google Cloud console to the
   Generative Language API, and set a billing quota/budget alert as the final
   backstop against runaway spend.
5. **Rotate keys** if the project's anon or service-role key was ever pasted
   into a shared channel.
6. **Auth settings** (Dashboard → Authentication): enable email confirmation for
   production, set password strength/leaked-password protection, and review
   per-IP auth rate limits — these are provider-side settings.
7. **CORS**: the functions send `Access-Control-Allow-Origin: *`. This is
   acceptable for a mobile client with no browser origin (a stolen JWT is still
   required to do anything). Restrict it to a known origin if a web client is
   ever added.
8. **Consider a storage retention policy** for old generated previews;
   deletion is currently user-initiated only.

## Known residual risks

- Quotas are per-account. A determined attacker who can create unlimited
  anonymous accounts can still consume AI capacity; the Google-side budget cap
  (item 4) is the backstop. Per-IP limiting would need a gateway in front of the
  functions.
- Anonymous accounts cannot be recovered or transferred. Signing out may make
  their private records permanently inaccessible. This is documented in the
  sign-out confirmation rather than fixed by weakening RLS.
- The quota check adds one round trip per AI request.
