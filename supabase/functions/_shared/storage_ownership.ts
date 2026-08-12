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
