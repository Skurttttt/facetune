/**
 * Ephemeral probe token.
 *
 * This file is REPLACED WHOLESALE at deploy time with a freshly generated
 * token, then restored to this placeholder immediately afterwards. Replacing a
 * whole file avoids the failure mode that broke the V3-6A.2 probe, where a
 * regex substitution rewrote both the token constant AND the literal inside
 * the fail-safe guard, making the guard compare the token against itself.
 *
 * The placeholder is short on purpose: the guard rejects any token under 32
 * characters, so a probe deployed without replacement accepts nothing.
 */
export const PROBE_TOKEN = "unset";
