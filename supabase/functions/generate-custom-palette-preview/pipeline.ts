import {
  PaletteContractError,
  type PaletteSelection,
  parseFrozenPalette,
} from "../_shared/custom_palette_contract.ts";
import { parseCustomPaletteRecommendation } from "../generate-custom-palette-recommendation/validation.ts";
import type { CustomPalettePlan } from "../generate-custom-palette-recommendation/types.ts";
import {
  CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION,
  customPalettePreviewPrompt,
} from "./prompt.ts";
import { failedVerdict, judgeValidatorResponse } from "./validator.ts";
import type { PreviewVerdict } from "./validator.ts";
import { customPaletteValidatorPrompt } from "./validator_prompt.ts";

export interface PreviewImage {
  bytes: Uint8Array;
  mimeType: string;
}

/** The stored row a preview derives from, exactly as read. */
export interface FrozenPaletteSource {
  style: string;
  palette_snapshot_json: unknown;
  recommendation_json: unknown;
}

export interface PreviewPorts {
  /** Throws on any failure. Never returns an unusable image. */
  generateImage(
    prompt: string,
    original: PreviewImage,
  ): Promise<PreviewImage & { model: string }>;
  /** The validator model's raw text. Throws on any failure. */
  requestValidation(
    prompt: string,
    original: PreviewImage,
    candidate: PreviewImage,
  ): Promise<string>;
}

/** A candidate that passed. Only [runPreviewCandidate] can produce one. */
export interface AcceptedCandidate {
  outcome: "accepted";
  image: PreviewImage;
  model: string;
  prompt_version: string;
  verdict: PreviewVerdict;
}

export interface RejectedCandidate {
  outcome: Exclude<PreviewVerdict["outcome"], "accepted">;
  verdict: PreviewVerdict;
}

export type CandidateResult = AcceptedCandidate | RejectedCandidate;

export class InvalidFrozenPalette extends Error {
  constructor() {
    super("invalid_frozen_palette");
    this.name = "InvalidFrozenPalette";
  }
}

function sameBytes(first: Uint8Array, second: Uint8Array): boolean {
  if (first.length !== second.length) return false;
  for (let index = 0; index < first.length; index += 1) {
    if (first[index] !== second[index]) return false;
  }
  return true;
}

/**
 * Re-validates what was read back, before any paid call.
 *
 * The database already refuses an invalid palette, so a failure here means
 * something is badly wrong, and generating from it would be worse than stopping.
 */
function readSource(
  source: FrozenPaletteSource,
): { selections: PaletteSelection[]; plan: CustomPalettePlan } {
  try {
    const selections = parseFrozenPalette(source.palette_snapshot_json);
    const plan = parseCustomPaletteRecommendation(
      JSON.stringify(source.recommendation_json),
      selections,
    );
    return { selections, plan };
  } catch (error) {
    if (
      error instanceof PaletteContractError ||
      (error as Error)?.name === "FunctionFailure"
    ) {
      throw new InvalidFrozenPalette();
    }
    throw error;
  }
}

/** Throws [InvalidFrozenPalette] unless the stored palette and plan are valid. */
export function assertFrozenSource(source: FrozenPaletteSource): void {
  readSource(source);
}

/**
 * Produces and judges one candidate from one frozen palette.
 *
 * This is one attempt. Retrying, reserving and charging belong to the caller
 * (CCP-6). A candidate that does not pass comes back without its image, so
 * there is nothing a caller could persist by mistake; [AcceptedCandidate] is
 * the only shape that carries one.
 */
export async function runPreviewCandidate(
  source: FrozenPaletteSource,
  original: PreviewImage,
  variationNumber: number,
  ports: PreviewPorts,
  correction: readonly string[] = [],
): Promise<CandidateResult> {
  const { selections, plan } = readSource(source);

  let candidate: PreviewImage & { model: string };
  try {
    candidate = await ports.generateImage(
      customPalettePreviewPrompt(
        source.style,
        selections,
        plan.applications,
        variationNumber,
        correction,
      ),
      original,
    );
  } catch {
    return rejected(
      failedVerdict("provider_failure", "image_generation_failed"),
    );
  }
  if (sameBytes(candidate.bytes, original.bytes)) {
    return rejected(
      failedVerdict("provider_failure", "unchanged_generated_image"),
    );
  }

  let observations: string;
  try {
    observations = await ports.requestValidation(
      customPaletteValidatorPrompt(selections),
      original,
      candidate,
    );
  } catch {
    return rejected(
      failedVerdict("validator_failure", "validator_unavailable"),
    );
  }

  const verdict = judgeValidatorResponse(observations, selections);
  if (verdict.outcome !== "accepted") return rejected(verdict);
  return {
    outcome: "accepted",
    image: { bytes: candidate.bytes, mimeType: candidate.mimeType },
    model: candidate.model,
    prompt_version: CUSTOM_PALETTE_PREVIEW_PROMPT_VERSION,
    verdict,
  };
}

function rejected(verdict: PreviewVerdict): RejectedCandidate {
  return {
    outcome: verdict.outcome as RejectedCandidate["outcome"],
    verdict,
  };
}
