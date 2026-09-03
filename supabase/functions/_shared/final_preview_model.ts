/** The one model allowed to render a canonical final preview.
 *
 * The canonical final preview is the visual authority the entire tutorial is
 * grounded in: the manifest classifies it, the guideline renderer compares
 * against it, and every quality baseline is measured from it. A preview drawn
 * by a different model is not comparable evidence, so the model is locked
 * rather than configured.
 *
 * Both final-preview paths — Standard and My Makeup Kit — resolve through here,
 * so the two cannot diverge.
 */
export const FINAL_PREVIEW_MODEL = "gemini-3.1-flash-image";

/** The environment variable that used to select the model, and now only
 * validates it. */
const CONFIGURED_MODEL_VARIABLE = "GEMINI_IMAGE_MODEL";

/** Why the deployed configuration cannot be used, or `null` when it can.
 *
 * V4-QA-8 found both preview functions resolving their model as
 * `Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() || "gemini-3-pro-image"`. That is
 * correct only while the secret is set: unset it, rotate it, or deploy to a
 * fresh project, and every canonical preview silently switches to a different
 * model — no code change, no failing test, no log that looks wrong. Every
 * tutorial baseline measured against those previews would quietly stop meaning
 * what it said.
 *
 * So the env var is no longer a selector. [FINAL_PREVIEW_MODEL] is always what
 * runs, and this function only decides whether the deployment *disagrees*:
 *
 *  * absent or blank — nothing disagrees, the locked model is used;
 *  * exactly the locked model — agrees, the locked model is used;
 *  * anything else — the deployment believes it is running a model this code
 *    will not run. Fail closed rather than silently ignoring the operator, or
 *    silently obeying them.
 *
 * The third case is deliberately an error rather than a shrug. Quietly
 * overriding a deliberate configuration would hide a real disagreement about
 * what production is doing, which is the same class of bug this replaces.
 *
 * The message names the expected model only. The configured value is never
 * echoed, so a misconfigured secret cannot be read back out of an API response.
 */
export function finalPreviewModelConfigurationError(): string | null {
  const configured = Deno.env.get(CONFIGURED_MODEL_VARIABLE)?.trim();
  if (!configured || configured === FINAL_PREVIEW_MODEL) return null;
  return `The image service is misconfigured: ${CONFIGURED_MODEL_VARIABLE} ` +
    `must be unset or exactly ${FINAL_PREVIEW_MODEL}.`;
}

/** The model to send, after checking the deployment agrees with the lock.
 *
 * Returns the locked model, or throws when configuration disagrees. Callers
 * convert the thrown message into their own failure type — the two preview
 * functions each own a `FunctionFailure`, and coupling this module to either
 * would drag one function's types into the other.
 *
 * Call this *before* the Gemini request, so a misconfigured deployment cannot
 * spend anything.
 */
export function resolveFinalPreviewModel(): string {
  const error = finalPreviewModelConfigurationError();
  if (error !== null) throw new Error(error);
  return FINAL_PREVIEW_MODEL;
}
