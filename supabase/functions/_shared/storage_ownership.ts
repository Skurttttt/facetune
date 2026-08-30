/**
 * Verifies that a private image path is exactly the owner-scoped original for
 * the given analysis.
 *
 * Segment-by-segment comparison is deliberate: a `startsWith` prefix test
 * accepts traversal (`..`) and extra segments that can point outside the
 * session's own folder.
 */
export function isOwnedOriginalPath(
  path: string,
  userId: string,
  analysisId: string,
  allowedExtensions: readonly string[] = ["jpg"],
): boolean {
  const segments = path.split("/");
  if (
    segments.length !== 5 ||
    segments[0] !== userId ||
    segments[1] !== "analyses" ||
    segments[2] !== analysisId ||
    segments[3] !== "original"
  ) {
    return false;
  }
  const fileName = segments[4];
  const separator = fileName.lastIndexOf(".");
  if (separator <= 0) return false;
  const imageId = fileName.slice(0, separator);
  const extension = fileName.slice(separator + 1).toLowerCase();
  return /^[0-9a-f-]{36}$/i.test(imageId) &&
    allowedExtensions.includes(extension);
}

/**
 * Verifies that a path is exactly an owner-scoped canonical final preview for
 * the given analysis.
 *
 * The tutorial grounds every guideline in this image, so it must be proven to
 * belong to the caller with the same rigour as the original selfie rather than
 * trusted because it arrived alongside one.
 *
 * Shapes accepted (`folder` selects which):
 *   <userId>/analyses/<analysisId>/generated/<recommendationId>/preview_NNNN.ext
 *   <userId>/analyses/<analysisId>/kit-generated/<kitRecommendationId>/preview_NNNN.ext
 *
 * Segment-by-segment like `isOwnedOriginalPath`, because a prefix test would
 * accept traversal and extra segments. The `/original/` folder can never match,
 * so this cannot be used to read a selfie back as if it were a preview.
 */
export function isOwnedGeneratedPreviewPath(
  path: string,
  userId: string,
  analysisId: string,
  folder: "generated" | "kit-generated",
  ownerScopedId: string,
  allowedExtensions: readonly string[] = ["jpg", "jpeg", "png", "webp"],
): boolean {
  const segments = path.split("/");
  if (
    segments.length !== 6 ||
    segments[0] !== userId ||
    segments[1] !== "analyses" ||
    segments[2] !== analysisId ||
    segments[3] !== folder ||
    segments[4] !== ownerScopedId
  ) {
    return false;
  }
  const fileName = segments[5];
  const separator = fileName.lastIndexOf(".");
  if (separator <= 0) return false;
  const stem = fileName.slice(0, separator);
  const extension = fileName.slice(separator + 1).toLowerCase();
  return /^preview_\d{4}$/.test(stem) && allowedExtensions.includes(extension);
}
