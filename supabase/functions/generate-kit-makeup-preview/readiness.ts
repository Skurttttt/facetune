import { tutorialManifestPrompt } from "../analyze-tutorial-manifest-v4/prompt.ts";
import { TUTORIAL_MANIFEST_PROMPT_VERSION } from "../analyze-tutorial-manifest-v4/prompt.ts";
import {
  TUTORIAL_MANIFEST_SCHEMA,
  TUTORIAL_MANIFEST_SCHEMA_VERSION,
} from "../analyze-tutorial-manifest-v4/schema.ts";
import {
  parseManifestResponse,
  productBackedCategories,
  resolveManifest,
} from "../analyze-tutorial-manifest-v4/validation.ts";
import {
  noteProviderAttempt,
  readProviderUsage,
  type UsageSink,
} from "../_shared/ai_telemetry.ts";
import type { CanonicalPlan } from "../_shared/kit_makeup_plan.ts";
import {
  TUTORIAL_CATEGORIES,
  type TutorialCategory,
} from "../_shared/tutorial_vocabulary.ts";

/**
 * `kit_tutorial_readiness_v1` — Tutorial readiness as an acceptance condition.
 *
 * A plan-driven candidate is accepted only if the Tutorial manifest would
 * accept it. Rather than approximate that, readiness asks the manifest's own
 * question, byte for byte: the same `tutorial_manifest_v4_1` prompt, schema,
 * supporting context, image order, and generation settings, parsed by the
 * manifest's own parser and resolved by the manifest's own resolver against
 * the look's immutable snapshot. Nothing here selects a product, reads the
 * live kit, or changes what the manifest decides; `kit_preview_mismatch`
 * still runs, unchanged, when the user asks for the tutorial.
 *
 * Ready means: no present category lacks a backing product, at least one
 * category becomes a step, and every category the plan requires to be visible
 * becomes a step.
 */
export const KIT_TUTORIAL_READINESS_VERSION = "kit_tutorial_readiness_v1";

const requestTimeoutMs = 45000;
const maximumAttempts = 2;

export type ReadinessResult = {
  status: "ready" | "not_ready" | "failure";
  readiness_version: typeof KIT_TUTORIAL_READINESS_VERSION;
  manifest_prompt_version: string;
  manifest_schema_version: string;
  included_categories: TutorialCategory[];
  unbacked_present_categories: TutorialCategory[];
  missing_required_categories: TutorialCategory[];
  failure_code: string | null;
};

/** The model the manifest analyzer uses, resolved the same way. */
export function readinessModel(): string {
  return Deno.env.get("GEMINI_MANIFEST_MODEL")?.trim() || "gemini-3.6-flash";
}

/** The supporting context the manifest analyzer sends in kit mode, verbatim. */
export function kitManifestSupportingContext(
  backed: Set<TutorialCategory>,
): string {
  return `My Makeup Kit Mode. Categories the user owns a product for: ${
    [...backed].join(", ") || "none"
  }. This is context only and never evidence of visual presence.`;
}

function encodeBase64(bytes: Uint8Array): string {
  const chunkSize = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunkSize) {
    binary += String.fromCharCode(
      ...bytes.subarray(offset, offset + chunkSize),
    );
  }
  return btoa(binary);
}

/** The manifest analyzer's request body, built identically. */
export function manifestPreflightBody(
  original: { bytes: Uint8Array; mimeType: string },
  candidate: { bytes: Uint8Array; mimeType: string },
  supportingContext: string,
): string {
  return JSON.stringify({
    contents: [{
      role: "user",
      parts: [
        { text: tutorialManifestPrompt(supportingContext) },
        { text: "IMAGE A — ORIGINAL, before makeup:" },
        {
          inlineData: {
            mimeType: original.mimeType,
            data: encodeBase64(original.bytes),
          },
        },
        { text: "IMAGE B — FINAL, after makeup:" },
        {
          inlineData: {
            mimeType: candidate.mimeType,
            data: encodeBase64(candidate.bytes),
          },
        },
      ],
    }],
    generationConfig: {
      responseMimeType: "application/json",
      responseJsonSchema: TUTORIAL_MANIFEST_SCHEMA,
      maxOutputTokens: 2048,
      temperature: 0.1,
      topP: 0.8,
      candidateCount: 1,
    },
  });
}

/** A provider failure, classified. Never carries upstream text. */
export class ReadinessProviderError extends Error {
  constructor(readonly code: string) {
    super(code);
  }
}

/** Sends the manifest request within [budgetMs] and returns its JSON text. */
export async function requestManifestPreflight(
  apiKey: string,
  model: string,
  body: string,
  budgetMs: number,
  usageSink?: UsageSink,
): Promise<string> {
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${
    encodeURIComponent(model)
  }:generateContent`;
  const startedAt = Date.now();
  for (let attempt = 1; attempt <= maximumAttempts; attempt += 1) {
    const remainingMs = budgetMs - (Date.now() - startedAt);
    if (remainingMs <= 0) break;
    try {
      noteProviderAttempt(usageSink, attempt);
      const response = await fetch(endpoint, {
        method: "POST",
        headers: {
          "content-type": "application/json",
          "x-goog-api-key": apiKey,
        },
        body,
        signal: AbortSignal.timeout(Math.min(requestTimeoutMs, remainingMs)),
      });
      if (response.ok) {
        const payload = await response.json();
        const text = (payload as {
          candidates?: Array<
            { content?: { parts?: Array<{ text?: string }> } }
          >;
        }).candidates?.[0]?.content?.parts?.map((part) => part.text ?? "")
          .join("").trim();
        if (!text) throw new ReadinessProviderError("readiness_empty");
        if (usageSink) usageSink.usage = readProviderUsage(payload, attempt);
        return text;
      }
      const transient = response.status === 429 || response.status >= 500;
      if (transient && attempt < maximumAttempts) {
        await new Promise((resolve) => setTimeout(resolve, 400 * attempt));
        continue;
      }
      throw new ReadinessProviderError("readiness_upstream_error");
    } catch (error) {
      if (error instanceof ReadinessProviderError) throw error;
      if (attempt < maximumAttempts) continue;
      throw new ReadinessProviderError("readiness_timeout");
    }
  }
  throw new ReadinessProviderError("readiness_timeout");
}

/**
 * Resolves a manifest answer for a candidate against the plan and snapshot.
 * Malformed answers are a failure, never a pass.
 */
export function assessReadiness(
  plan: CanonicalPlan,
  snapshot: unknown,
  manifestText: string,
): ReadinessResult {
  const base = {
    readiness_version: KIT_TUTORIAL_READINESS_VERSION,
    manifest_prompt_version: TUTORIAL_MANIFEST_PROMPT_VERSION,
    manifest_schema_version: TUTORIAL_MANIFEST_SCHEMA_VERSION,
  } as const;
  const backed = productBackedCategories(snapshot);
  const allowed = new Set(plan.allowed_visual_categories);
  if (
    backed.size !== allowed.size ||
    [...backed].some((category) => !allowed.has(category))
  ) {
    return failure(base, "plan_snapshot_disagree");
  }
  let verdicts;
  try {
    verdicts = parseManifestResponse(manifestText);
  } catch {
    return failure(base, "readiness_malformed");
  }
  const resolved = resolveManifest(verdicts, "my_makeup_kit", backed);
  const required = TUTORIAL_CATEGORIES.filter((category) =>
    plan.selected_items.some((item) =>
      item.tutorial_category === category &&
      item.visible_intent === "required_visible"
    )
  );
  const missing = required.filter((category) =>
    !resolved.includedCategories.includes(category)
  );
  const ready = resolved.manifestStatus === "accepted" &&
    resolved.includedCategories.length > 0 && missing.length === 0;
  return {
    ...base,
    status: ready ? "ready" : "not_ready",
    included_categories: resolved.includedCategories,
    unbacked_present_categories: resolved.unbackedPresentCategories,
    missing_required_categories: missing,
    failure_code: null,
  };
}

export function readinessFailure(code: string): ReadinessResult {
  return failure({
    readiness_version: KIT_TUTORIAL_READINESS_VERSION,
    manifest_prompt_version: TUTORIAL_MANIFEST_PROMPT_VERSION,
    manifest_schema_version: TUTORIAL_MANIFEST_SCHEMA_VERSION,
  }, code);
}

function failure(
  base: Pick<
    ReadinessResult,
    "readiness_version" | "manifest_prompt_version" | "manifest_schema_version"
  >,
  code: string,
): ReadinessResult {
  return {
    ...base,
    status: "failure",
    included_categories: [],
    unbacked_present_categories: [],
    missing_required_categories: [],
    failure_code: code,
  };
}
