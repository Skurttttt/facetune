/**
 * Content integrity for accepted plan-driven kit previews.
 *
 * A plan-driven preview was accepted only after its exact bytes were
 * validated, and `kit_generated_images.content_sha256` records those bytes.
 * Storage lets the owner delete an object and upload different bytes at the
 * same path, so before any Tutorial analysis trusts a preview, the bytes it
 * downloaded are hashed and compared. Bytes that are not the accepted bytes
 * are never analyzed: a tutorial grounded in them would teach a look nobody
 * validated.
 *
 * Legacy previews (no plan) carry no hash and are not checked, exactly as
 * before. A plan-backed preview with a missing or malformed hash fails
 * closed. Each caller converts the thrown error into its own failure type.
 */

export const KIT_PREVIEW_INTEGRITY_FAILURE = "kit_preview_integrity_mismatch";
export const KIT_PREVIEW_INTEGRITY_MESSAGE =
  "This look's preview can no longer be verified. Create a new preview to continue.";

export class KitPreviewIntegrityError extends Error {
  constructor() {
    super(KIT_PREVIEW_INTEGRITY_FAILURE);
  }
}

const shaPattern = /^[0-9a-f]{64}$/;

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const hash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)),
  );
  return [...hash].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Compares without an early exit, so timing reveals nothing. */
function sameHex(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}

/**
 * Throws [KitPreviewIntegrityError] unless [bytes] are the accepted bytes of
 * the plan-backed preview [row]. Does nothing for a legacy preview.
 */
export async function assertKitPreviewIntegrity(
  bytes: Uint8Array,
  row: Record<string, unknown>,
): Promise<void> {
  if (row.plan_id === null || row.plan_id === undefined) return;
  const expected = row.content_sha256;
  if (typeof expected !== "string" || !shaPattern.test(expected)) {
    throw new KitPreviewIntegrityError();
  }
  if (!sameHex(await sha256Hex(bytes), expected)) {
    throw new KitPreviewIntegrityError();
  }
}
