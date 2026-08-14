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
 * Verifies that a private image path is exactly the owner-scoped result of
 * one tutorial step, for the given session.
 *
 * Mirrors `isOwnedOriginalPath`'s segment-by-segment approach for the
 * `.../tutorials/{tutorialSessionId}/step_{NNNN}_result.{ext}` shape
 * documented in
 * `supabase/migrations/20260814000300_tutorial_sessions_steps.sql`. Used to
 * validate a *previous* step's `result_image_path` before treating it as
 * trusted input for the next step's cumulative source image — the path
 * comes from the database, but every stored path is re-validated here as
 * defense in depth, the same posture `isOwnedOriginalPath` already takes
 * for `analyses.original_image_path`.
 */
export function isOwnedTutorialResultPath(
  path: string,
  userId: string,
  analysisId: string,
  tutorialSessionId: string,
  allowedExtensions: readonly string[] = ["png", "jpg", "jpeg", "webp"],
): boolean {
  const segments = path.split("/");
  if (
    segments.length !== 6 ||
    segments[0] !== userId ||
    segments[1] !== "analyses" ||
    segments[2] !== analysisId ||
    segments[3] !== "tutorials" ||
    segments[4] !== tutorialSessionId
  ) {
    return false;
  }
  const fileName = segments[5];
  const match = /^step_(\d{4})_result\.([a-z0-9]+)$/.exec(fileName);
  if (!match) return false;
  const extension = match[2].toLowerCase();
  return allowedExtensions.includes(extension);
}
