import type { GeneratedImage } from "./types.ts";
import { FunctionFailure } from "./types.ts";

const maximumBytes = 10 * 1024 * 1024;

// A guideline is an annotated photograph, so it is never a handful of bytes.
// Anything this small is a truncated or placeholder response, not an image the
// user should be shown.
const minimumBytes = 10 * 1024;

function decodeBase64(value: string): Uint8Array {
  try {
    const binary = atob(value);
    return Uint8Array.from(binary, (character) => character.charCodeAt(0));
  } catch {
    throw invalidImage();
  }
}

function invalidImage(): FunctionFailure {
  return new FunctionFailure(
    502,
    "invalid_guideline_image",
    "The image service returned an invalid guideline.",
    true,
  );
}

/**
 * Confirms the bytes really are the media type the model claimed.
 *
 * A declared MIME type is not evidence. Checking the magic bytes stops a
 * mislabelled or corrupt payload from being written into private storage and
 * later failing to decode on the device.
 */
function signatureMatches(bytes: Uint8Array, mimeType: string): boolean {
  if (mimeType === "image/png") {
    return bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 &&
      bytes[2] === 0x4e && bytes[3] === 0x47 && bytes[4] === 0x0d &&
      bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a;
  }
  if (mimeType === "image/jpeg") {
    return bytes.length >= 4 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
      bytes[bytes.length - 2] === 0xff && bytes[bytes.length - 1] === 0xd9;
  }
  if (mimeType === "image/webp") {
    return bytes.length >= 12 &&
      String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

export function validateGuidelineImage(
  data: unknown,
  mimeType: unknown,
): GeneratedImage {
  if (
    typeof data !== "string" || data.length === 0 ||
    (mimeType !== "image/png" && mimeType !== "image/jpeg" &&
      mimeType !== "image/webp")
  ) {
    throw invalidImage();
  }
  const bytes = decodeBase64(data);
  if (
    bytes.length < minimumBytes || bytes.length > maximumBytes ||
    !signatureMatches(bytes, mimeType)
  ) {
    throw invalidImage();
  }
  return { bytes, mimeType };
}

export function extensionFor(mimeType: GeneratedImage["mimeType"]): string {
  return mimeType === "image/png"
    ? "png"
    : mimeType === "image/webp"
    ? "webp"
    : "jpg";
}

/**
 * Builds the owner-scoped guideline path for one step.
 *
 * Mirrors `TutorialV2StoragePaths` in
 * `lib/features/tutorial_v2/domain/services/tutorial_v2_storage_paths.dart`.
 * Living under `{userId}/analyses/{analysisId}` is what lets the existing
 * `delete-history-item` sweep clean these up automatically.
 */
export function guidelinePath(
  userId: string,
  analysisId: string,
  sessionId: string,
  stepIndex: number,
  extension: string,
): string {
  const number = (stepIndex + 1).toString().padStart(4, "0");
  return `${userId}/analyses/${analysisId}/tutorial-v2/${sessionId}/step_${number}_guideline.${extension}`;
}

/**
 * Verifies a path is exactly this user's guideline asset for this session and
 * step.
 *
 * Segment-by-segment on purpose: a `startsWith` prefix test accepts `..`
 * traversal and extra segments that resolve outside the session folder. This
 * matches the posture `_shared/storage_ownership.ts` already takes for
 * original selfies.
 */
export function isOwnedGuidelinePath(
  path: string,
  userId: string,
  analysisId: string,
  sessionId: string,
  stepIndex: number,
): boolean {
  const segments = path.split("/");
  if (
    segments.length !== 6 ||
    segments[0] !== userId ||
    segments[1] !== "analyses" ||
    segments[2] !== analysisId ||
    segments[3] !== "tutorial-v2" ||
    segments[4] !== sessionId
  ) {
    return false;
  }
  const match = /^step_(\d{4})_guideline\.(png|jpg|jpeg|webp)$/.exec(
    segments[5],
  );
  if (!match) return false;
  return match[1] === (stepIndex + 1).toString().padStart(4, "0");
}

/**
 * Verifies a path the server is about to READ is one of this analysis's own
 * images and is not something the caller invented.
 */
export function isOwnedSourcePath(
  path: string,
  userId: string,
  analysisId: string,
): boolean {
  if (path.includes("..") || path.includes("//")) return false;
  const segments = path.split("/");
  return segments.length >= 4 &&
    segments[0] === userId &&
    segments[1] === "analyses" &&
    segments[2] === analysisId &&
    segments.every((segment) => segment !== "." && segment !== "..");
}
