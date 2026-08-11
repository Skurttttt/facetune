import type { GeneratedImage } from "./types.ts";
import { FunctionFailure } from "./types.ts";

const maximumBytes = 10 * 1024 * 1024;
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
    "invalid_generated_image",
    "The image service returned an invalid preview.",
    true,
  );
}

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
    return bytes.length >= 12 && String.fromCharCode(...bytes.slice(0, 4)) === "RIFF" &&
      String.fromCharCode(...bytes.slice(8, 12)) === "WEBP";
  }
  return false;
}

export function validateGeneratedImage(
  data: unknown,
  mimeType: unknown,
): GeneratedImage {
  if (
    typeof data !== "string" || data.length === 0 ||
    (mimeType !== "image/png" && mimeType !== "image/jpeg" &&
      mimeType !== "image/webp")
  ) throw invalidImage();
  const bytes = decodeBase64(data);
  if (
    bytes.length < minimumBytes || bytes.length > maximumBytes ||
    !signatureMatches(bytes, mimeType)
  ) throw invalidImage();
  return { bytes, mimeType };
}

export function extensionFor(mimeType: GeneratedImage["mimeType"]): string {
  return mimeType === "image/png" ? "png" : mimeType === "image/webp" ? "webp" : "jpg";
}
