// Authenticated access to the Google Play Developer API.
//
// Two calls are made:
//
//   purchases.subscriptionsv2.get        read the verified subscription
//   purchases.subscriptions.acknowledge  tell Google the purchase was handled
//
// `purchases.subscriptions.get` (v1) is deprecated in favour of
// `subscriptionsv2`; `acknowledge` has no v2 replacement and is not deprecated,
// so the two live at different API versions on purpose.
//
// The service account credential is read from the environment and never
// leaves this module. It is not logged, not returned, and not passed to the
// database.

import { VerificationFailure } from "./verification.ts";

const tokenEndpoint = "https://oauth2.googleapis.com/token";
const androidPublisherBase =
  "https://androidpublisher.googleapis.com/androidpublisher/v3/applications";
const androidPublisherScope =
  "https://www.googleapis.com/auth/androidpublisher";

/// Access tokens last an hour; this margin re-mints slightly early so a token
/// cannot expire in flight between being chosen and being used.
const tokenExpirySafetyMarginSeconds = 60;

interface ServiceAccount {
  clientEmail: string;
  privateKeyPem: string;
}

/// Parses the service-account JSON.
///
/// Failures are reported as a configuration error with no detail: a message
/// describing what was wrong with a credential file is a message that helps
/// someone probing it.
export function parseServiceAccount(raw: string): ServiceAccount {
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    throw new VerificationFailure(
      500,
      "server_configuration",
      "Purchase verification is not configured.",
    );
  }
  const account = parsed as Record<string, unknown>;
  const clientEmail = account?.client_email;
  const privateKey = account?.private_key;
  if (
    typeof clientEmail !== "string" || clientEmail.length === 0 ||
    typeof privateKey !== "string" || privateKey.length === 0
  ) {
    throw new VerificationFailure(
      500,
      "server_configuration",
      "Purchase verification is not configured.",
    );
  }
  return { clientEmail, privateKeyPem: privateKey };
}

function base64Url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlText(value: string): string {
  return base64Url(new TextEncoder().encode(value));
}

/// Imports a PKCS#8 PEM private key for RSASSA-PKCS1-v1_5 with SHA-256, which
/// is what Google's `RS256` assertion requires.
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  let der: Uint8Array;
  try {
    der = Uint8Array.from(atob(body), (character) => character.charCodeAt(0));
  } catch {
    throw new VerificationFailure(
      500,
      "server_configuration",
      "Purchase verification is not configured.",
    );
  }
  try {
    return await crypto.subtle.importKey(
      "pkcs8",
      der.buffer as ArrayBuffer,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["sign"],
    );
  } catch {
    throw new VerificationFailure(
      500,
      "server_configuration",
      "Purchase verification is not configured.",
    );
  }
}

interface CachedToken {
  accessToken: string;
  expiresAtEpochSeconds: number;
}

/// Mints and caches an access token for the Android Publisher scope.
///
/// The cache is per isolate, so a warm Edge Function reuses one token across
/// requests rather than performing an RSA signature and a token round trip for
/// every purchase.
export class GooglePlayApi {
  constructor(
    private readonly serviceAccount: ServiceAccount,
    private readonly packageName: string,
  ) {}

  private cachedToken: CachedToken | null = null;

  private async accessToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1000);
    const cached = this.cachedToken;
    if (cached && cached.expiresAtEpochSeconds - tokenExpirySafetyMarginSeconds > now) {
      return cached.accessToken;
    }

    // The JWT bearer assertion flow for service accounts: an RS256 JWT whose
    // audience is the token endpoint, exchanged for an access token.
    const issuedAt = now;
    const expiresAt = now + 3600;
    const header = base64UrlText(JSON.stringify({ alg: "RS256", typ: "JWT" }));
    const claims = base64UrlText(JSON.stringify({
      iss: this.serviceAccount.clientEmail,
      scope: androidPublisherScope,
      aud: tokenEndpoint,
      iat: issuedAt,
      exp: expiresAt,
    }));
    const signingInput = `${header}.${claims}`;

    const key = await importPrivateKey(this.serviceAccount.privateKeyPem);
    const signature = await crypto.subtle.sign(
      "RSASSA-PKCS1-v1_5",
      key,
      new TextEncoder().encode(signingInput),
    );
    const assertion = `${signingInput}.${base64Url(new Uint8Array(signature))}`;

    let response: Response;
    try {
      response = await fetch(tokenEndpoint, {
        method: "POST",
        headers: { "content-type": "application/x-www-form-urlencoded" },
        body: new URLSearchParams({
          grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
          assertion,
        }),
      });
    } catch {
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Google Play could not be reached. Please try again.",
        true,
      );
    }

    if (!response.ok) {
      // The body can name the service account and the reason its credential
      // was rejected. It is dropped rather than surfaced or logged.
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Purchase verification is temporarily unavailable.",
        true,
      );
    }

    const payload = await response.json().catch(() => null) as
      | { access_token?: string; expires_in?: number }
      | null;
    const accessToken = payload?.access_token;
    if (typeof accessToken !== "string" || accessToken.length === 0) {
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Purchase verification is temporarily unavailable.",
        true,
      );
    }

    this.cachedToken = {
      accessToken,
      expiresAtEpochSeconds: now +
        (typeof payload?.expires_in === "number" ? payload.expires_in : 3600),
    };
    return accessToken;
  }

  /// Reads the subscription behind [purchaseToken].
  ///
  /// The request is scoped to this app's package name, so a token issued for a
  /// different application cannot resolve here at all — Google answers 404, and
  /// "wrong package" needs no separate check of our own.
  async getSubscription(purchaseToken: string): Promise<unknown> {
    const token = await this.accessToken();
    const url =
      `${androidPublisherBase}/${encodeURIComponent(this.packageName)}` +
      `/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`;

    let response: Response;
    try {
      response = await fetch(url, {
        headers: { authorization: `Bearer ${token}` },
      });
    } catch {
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Google Play could not be reached. Please try again.",
        true,
      );
    }

    if (response.status === 404 || response.status === 400) {
      // A token Google does not recognise for this package. Fabricated,
      // belonging to another app, or long since purged.
      throw new VerificationFailure(
        409,
        "PURCHASE_VERIFICATION_FAILED",
        "Google Play does not recognise this purchase.",
      );
    }
    if (response.status === 401 || response.status === 403) {
      // Our credential, not the user's problem.
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Purchase verification is temporarily unavailable.",
        true,
      );
    }
    if (!response.ok) {
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Google Play could not confirm this purchase. Please try again.",
        true,
      );
    }

    const body = await response.json().catch(() => null);
    if (body === null || typeof body !== "object") {
      throw new VerificationFailure(
        503,
        "TEMPORARY_BACKEND_FAILURE",
        "Google Play returned an unreadable response.",
        true,
      );
    }
    return body;
  }

  /// Acknowledges the purchase with Google.
  ///
  /// Google recommends acknowledging from the backend rather than the client,
  /// and an unacknowledged purchase is refunded automatically after three days.
  /// This runs only once the entitlement has actually been written, so an
  /// acknowledgement can never outrun the grant it is confirming.
  ///
  /// Returns whether it succeeded. A failure here is deliberately not fatal:
  /// the user has been granted what they paid for, and the client's own
  /// completion call remains as a second chance within the same window.
  async acknowledgeSubscription(
    purchaseToken: string,
    productId: string,
  ): Promise<boolean> {
    let token: string;
    try {
      token = await this.accessToken();
    } catch {
      return false;
    }
    const url =
      `${androidPublisherBase}/${encodeURIComponent(this.packageName)}` +
      `/purchases/subscriptions/${encodeURIComponent(productId)}` +
      `/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`;
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: "{}",
      });
      return response.ok;
    } catch {
      return false;
    }
  }
}
