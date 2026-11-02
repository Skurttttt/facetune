import {
  CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
  type CustomPaletteRequest,
  PaletteContractError,
  paletteDigest,
  type PaletteSelection,
  parseCustomPaletteRequest,
} from "../_shared/custom_palette_contract.ts";
import type { PlacementAttributes } from "./prompt.ts";
import { CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION } from "./prompt.ts";
import { FunctionFailure } from "./types.ts";
import { parseCustomPaletteRecommendation } from "./validation.ts";

export interface StoredPaletteRecommendation {
  id: string;
  analysis_id: string;
  makeup_style: string;
  palette_digest: string;
  palette_version: string;
  palette_snapshot_json: unknown;
  derived_from_palette_id: string | null;
  recommendation_json: unknown;
  model_name: string;
  prompt_version: string;
  created_at: string;
}

export interface NewPaletteRecommendation {
  /** From the verified JWT, never from the request body. */
  user_id: string;
  analysis_id: string;
  makeup_style: string;
  palette_request_id: string;
  palette_version: string;
  palette_snapshot_json: readonly PaletteSelection[];
  palette_digest: string;
  derived_from_palette_id: string | null;
  recommendation_json: unknown;
  model_name: string;
  prompt_version: string;
}

export type InsertResult =
  | { kind: "inserted"; row: StoredPaletteRecommendation }
  | { kind: "duplicate" };

/**
 * Everything the handler needs from the outside world.
 *
 * Reads go through the caller's own client, so row level security scopes them.
 * Only [insert] uses the server's authority, and the handler supplies its
 * `user_id` from the verified JWT.
 */
export interface RecommendationPorts {
  /** The verified account behind [authorization], or `null`. */
  authenticate(authorization: string): Promise<string | null>;
  findByRequestId(
    paletteRequestId: string,
  ): Promise<StoredPaletteRecommendation | null>;
  /** `null` when the caller does not own the analysis. */
  loadAttributes(analysisId: string): Promise<PlacementAttributes | null>;
  /** Whether the caller owns this palette on this analysis. */
  ownsPalette(paletteId: string, analysisId: string): Promise<boolean>;
  consumeQuota(): Promise<{ allowed: boolean; message: string }>;
  generate(
    attributes: PlacementAttributes,
    style: string,
    selections: readonly PaletteSelection[],
  ): Promise<{ text: string; model: string }>;
  insert(row: NewPaletteRecommendation): Promise<InsertResult>;
}

const CONTRACT_MESSAGES: Readonly<Record<string, string>> = {
  invalid_analysis_id: "A valid analysis ID is required.",
  invalid_style: "Choose a supported makeup style.",
  palette_empty: "Choose at least one category.",
};

function responseBody(row: StoredPaletteRecommendation) {
  return {
    recommendation: {
      id: row.id,
      analysisId: row.analysis_id,
      style: row.makeup_style,
      paletteVersion: row.palette_version,
      palette: row.palette_snapshot_json,
      derivedFromPaletteId: row.derived_from_palette_id,
      plan: row.recommendation_json,
      modelId: row.model_name,
      promptVersion: row.prompt_version,
      createdAt: row.created_at,
    },
  };
}

/** Returns an existing row for this request id, or refuses a changed request. */
function replay(
  row: StoredPaletteRecommendation,
  request: CustomPaletteRequest,
  digest: string,
): StoredPaletteRecommendation {
  if (
    row.palette_digest !== digest ||
    row.analysis_id !== request.analysisId ||
    row.makeup_style !== request.style ||
    row.derived_from_palette_id !== request.derivedFromPaletteId
  ) {
    throw new FunctionFailure(
      409,
      "palette_request_conflict",
      "This request was already used for a different palette.",
    );
  }
  return row;
}

async function parseBody(request: Request): Promise<CustomPaletteRequest> {
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    throw new FunctionFailure(
      400,
      "invalid_json",
      "The request body must be valid JSON.",
    );
  }
  try {
    return parseCustomPaletteRequest(body);
  } catch (error) {
    if (error instanceof PaletteContractError) {
      throw new FunctionFailure(
        400,
        error.code,
        CONTRACT_MESSAGES[error.code] ?? "This palette is not valid.",
      );
    }
    throw error;
  }
}

/**
 * Freezes one palette and derives its recommendation from it.
 *
 * The palette is validated and digested before any AI call, and the AI's output
 * is stored beside it unmerged. Palette truth therefore never passes through
 * the model. A replay of a request id returns the stored row, spending no quota
 * and making no AI call.
 */
export async function createRecommendation(
  request: Request,
  ports: RecommendationPorts,
): Promise<{ status: number; body: unknown }> {
  const authorization = request.headers.get("authorization");
  if (!authorization?.toLowerCase().startsWith("bearer ")) {
    throw new FunctionFailure(
      401,
      "authentication_required",
      "Sign in before generating a look.",
    );
  }
  const userId = await ports.authenticate(authorization);
  if (!userId) {
    throw new FunctionFailure(
      401,
      "invalid_session",
      "Your session has expired. Sign in again.",
    );
  }

  const payload = await parseBody(request);
  const digest = await paletteDigest(payload.selections);

  const existing = await ports.findByRequestId(payload.paletteRequestId);
  if (existing) {
    return {
      status: 200,
      body: responseBody(replay(existing, payload, digest)),
    };
  }

  const attributes = await ports.loadAttributes(payload.analysisId);
  if (!attributes) {
    throw new FunctionFailure(
      404,
      "analysis_not_found",
      "The completed analysis could not be found.",
    );
  }
  if (
    payload.derivedFromPaletteId !== null &&
    !await ports.ownsPalette(payload.derivedFromPaletteId, payload.analysisId)
  ) {
    throw new FunctionFailure(
      400,
      "invalid_palette_contract",
      "This palette is not valid.",
    );
  }

  const quota = await ports.consumeQuota();
  if (!quota.allowed) {
    throw new FunctionFailure(429, "rate_limited", quota.message, true);
  }

  const generated = await ports.generate(
    attributes,
    payload.style,
    payload.selections,
  );
  const plan = parseCustomPaletteRecommendation(
    generated.text,
    payload.selections,
  );

  const result = await ports.insert({
    user_id: userId,
    analysis_id: payload.analysisId,
    makeup_style: payload.style,
    palette_request_id: payload.paletteRequestId,
    palette_version: CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
    palette_snapshot_json: payload.selections,
    palette_digest: digest,
    derived_from_palette_id: payload.derivedFromPaletteId,
    recommendation_json: plan,
    model_name: generated.model,
    prompt_version: CUSTOM_PALETTE_RECOMMENDATION_PROMPT_VERSION,
  });
  if (result.kind === "inserted") {
    return { status: 200, body: responseBody(result.row) };
  }

  // A concurrent invocation won the insert. Its row is the one truth.
  const winner = await ports.findByRequestId(payload.paletteRequestId);
  if (!winner) {
    throw new FunctionFailure(
      500,
      "persistence_failed",
      "The makeup plan could not be saved.",
      true,
    );
  }
  return { status: 200, body: responseBody(replay(winner, payload, digest)) };
}
