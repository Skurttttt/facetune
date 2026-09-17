// Authentication for the Pub/Sub push request.
//
// This endpoint cannot use Supabase's own JWT gate: the caller is Google, not
// a signed-in user, so the function is deployed with `verify_jwt = false` and
// authenticates the request itself. Everything that gate would have done is
// done here instead, and nothing is processed until it passes.
//
// ## What is verified
//
// Pub/Sub attaches an OIDC identity token minted for the push subscription's
// service account. It is a normal Google-signed JWT, so:
//
//   * the signature is checked against Google's published keys — this is what
//     makes the request unforgeable, and nothing else in this file matters
//     without it;
//   * `aud` must equal the audience configured on the push subscription, so a
//     token minted for some other service cannot be replayed at this one;
//   * `email` must be the service account configured for the subscription, so
//     any other Google identity — including another project's — is refused;
//   * `exp` must be in the future.
//
// A URL secret is deliberately not used instead. It would travel in the push
// subscription's endpoint, appear in Cloud console UI and in logs, and could
// not be rotated without a window where notifications are dropped.

/// Google's published signing keys for identity tokens.
const googleCertsUrl = "https://www.googleapis.com/oauth2/v3/certs";

/// Accepted issuers. Google mints identity tokens under both spellings.
const acceptedIssuers = new Set([
  "https://accounts.google.com",
  "accounts.google.com",
]);

/// Tolerance for clock skew between Google and the edge runtime.
const clockSkewSeconds = 60;

/// How long a fetched key set is reused. Google rotates keys slowly; an hour
/// keeps a warm isolate from fetching the set on every notification while
/// staying well inside the rotation window.
const keySetCacheSeconds = 3600;

export class PushAuthenticationFailed extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

interface Jwk {
  kid?: string;
  kty?: string;
  alg?: string;
  use?: string;
  n?: string;
  e?: string;
}

interface CachedKeySet {
  keys: Jwk[];
  fetchedAtEpochSeconds: number;
}

let cachedKeySet: CachedKeySet | null = null;

function base64UrlToBytes(value: string): Uint8Array {
  const padded = value.replace(/-/g, "+").replace(/_/g, "/")
    .padEnd(Math.ceil(value.length / 4) * 4, "=");
  return Uint8Array.from(atob(padded), (character) => character.charCodeAt(0));
}

function decodeSegment(segment: string): Record<string, unknown> {
  const json = new TextDecoder().decode(base64UrlToBytes(segment));
  const parsed = JSON.parse(json);
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new PushAuthenticationFailed("token_segment_not_an_object");
  }
  return parsed as Record<string, unknown>;
}

async function signingKeys(): Promise<Jwk[]> {
  const now = Math.floor(Date.now() / 1000);
  const cached = cachedKeySet;
  if (cached && now - cached.fetchedAtEpochSeconds < keySetCacheSeconds) {
    return cached.keys;
  }

  let response: Response;
  try {
    response = await fetch(googleCertsUrl);
  } catch {
    // Distinguished from a bad token on purpose: the caller answers this with
    // a retryable status so Pub/Sub redelivers, rather than dropping a
    // notification because Google's key endpoint blinked.
    throw new PushKeysUnavailable("certs_unreachable");
  }
  if (!response.ok) {
    throw new PushKeysUnavailable("certs_status_" + response.status);
  }

  const body = await response.json().catch(() => null) as
    | { keys?: Jwk[] }
    | null;
  const keys = body?.keys;
  if (!Array.isArray(keys) || keys.length === 0) {
    throw new PushKeysUnavailable("certs_empty");
  }

  cachedKeySet = { keys, fetchedAtEpochSeconds: now };
  return keys;
}

/// Google's key endpoint could not be read. Transient, and retryable.
export class PushKeysUnavailable extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

/// Verifies the Pub/Sub push request's OIDC token.
///
/// Returns the verified service-account email. Throws
/// [PushAuthenticationFailed] for anything that will never become valid, and
/// [PushKeysUnavailable] for a transient inability to check.
export async function verifyPushRequest(
  authorizationHeader: string | null,
  expected: { audience: string; serviceAccountEmail: string },
): Promise<string> {
  if (
    authorizationHeader === null ||
    !authorizationHeader.toLowerCase().startsWith("bearer ")
  ) {
    throw new PushAuthenticationFailed("missing_bearer_token");
  }
  const token = authorizationHeader.slice("bearer ".length).trim();
  const segments = token.split(".");
  if (segments.length !== 3) {
    throw new PushAuthenticationFailed("token_not_a_jwt");
  }

  let header: Record<string, unknown>;
  let claims: Record<string, unknown>;
  try {
    header = decodeSegment(segments[0]);
    claims = decodeSegment(segments[1]);
  } catch {
    throw new PushAuthenticationFailed("token_unreadable");
  }

  if (header.alg !== "RS256") {
    // The one accepted algorithm. Anything else — `none` above all — is
    // refused before a key is ever looked up.
    throw new PushAuthenticationFailed("token_algorithm_not_rs256");
  }
  const kid = typeof header.kid === "string" ? header.kid : null;
  if (kid === null) {
    throw new PushAuthenticationFailed("token_missing_kid");
  }

  const keys = await signingKeys();
  const jwk = keys.find((candidate) => candidate.kid === kid);
  if (!jwk) {
    throw new PushAuthenticationFailed("token_key_not_found");
  }

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "jwk",
      { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: "RS256", ext: true },
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"],
    );
  } catch {
    throw new PushAuthenticationFailed("token_key_unusable");
  }

  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    base64UrlToBytes(segments[2]),
    new TextEncoder().encode(`${segments[0]}.${segments[1]}`),
  );
  if (!verified) {
    throw new PushAuthenticationFailed("token_signature_invalid");
  }

  // Claims are only worth reading once the signature has been established.
  const now = Math.floor(Date.now() / 1000);
  const issuer = typeof claims.iss === "string" ? claims.iss : "";
  if (!acceptedIssuers.has(issuer)) {
    throw new PushAuthenticationFailed("token_issuer_rejected");
  }

  const expiry = typeof claims.exp === "number" ? claims.exp : 0;
  if (expiry + clockSkewSeconds <= now) {
    throw new PushAuthenticationFailed("token_expired");
  }

  const audience = typeof claims.aud === "string" ? claims.aud : "";
  if (audience !== expected.audience) {
    throw new PushAuthenticationFailed("token_audience_rejected");
  }

  const email = typeof claims.email === "string" ? claims.email : "";
  if (email !== expected.serviceAccountEmail) {
    throw new PushAuthenticationFailed("token_identity_rejected");
  }
  if (claims.email_verified !== true) {
    throw new PushAuthenticationFailed("token_email_unverified");
  }

  return email;
}
