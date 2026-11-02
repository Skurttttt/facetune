import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import { requestGeminiCustomPaletteRecommendation } from "./gemini_client.ts";
import type {
  InsertResult,
  RecommendationPorts,
  StoredPaletteRecommendation,
} from "./handler.ts";
import { FunctionFailure } from "./types.ts";

const TABLE = "custom_palette_recommendations";
const UNIQUE_VIOLATION = "23505";

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(`[generate-custom-palette-recommendation] Missing ${name}`);
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The recommendation service is not configured.",
    );
  }
  return value;
}

function lookupFailed(): FunctionFailure {
  return new FunctionFailure(
    503,
    "lookup_failed",
    "Your look could not be prepared. Please try again.",
    true,
  );
}

/**
 * The real ports.
 *
 * Reads run as the caller, so row level security scopes them. The service-role
 * client exists only for the insert: clients have no write access to this
 * table, which is what stops anyone forging a plan or editing a frozen palette.
 */
export function createSupabasePorts(
  authorization: string,
): RecommendationPorts {
  const userClient = createClient(
    requiredEnvironment("SUPABASE_URL"),
    requiredEnvironment("SUPABASE_ANON_KEY"),
    {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    },
  );
  return {
    async authenticate() {
      const { data, error } = await userClient.auth.getUser();
      return error || !data.user ? null : data.user.id;
    },
    async findByRequestId(paletteRequestId) {
      const { data, error } = await userClient
        .from(TABLE)
        .select("*")
        .eq("palette_request_id", paletteRequestId)
        .maybeSingle();
      if (error) throw lookupFailed();
      return data as StoredPaletteRecommendation | null;
    },
    async loadAttributes(analysisId) {
      const { data, error } = await userClient
        .from("analyses")
        .select("face_shape, eye_shape, lip_shape")
        .eq("id", analysisId)
        .maybeSingle();
      if (error) throw lookupFailed();
      if (!data) return null;
      return {
        faceShape: data.face_shape,
        eyeShape: data.eye_shape,
        lipShape: data.lip_shape,
      };
    },
    async ownsPalette(paletteId, analysisId) {
      const { data, error } = await userClient
        .from(TABLE)
        .select("id")
        .eq("id", paletteId)
        .eq("analysis_id", analysisId)
        .maybeSingle();
      if (error) throw lookupFailed();
      return data !== null;
    },
    async consumeQuota() {
      const quota = await consumeAiQuota(
        userClient,
        "custom_palette_recommendation",
      );
      return { allowed: quota.allowed, message: quotaMessage(quota.reason) };
    },
    async generate(attributes, style, selections) {
      const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";
      const text = await requestGeminiCustomPaletteRecommendation(
        requiredEnvironment("GEMINI_API_KEY"),
        model,
        attributes,
        style,
        selections,
      );
      return { text, model };
    },
    async insert(row): Promise<InsertResult> {
      const serverClient = createClient(
        requiredEnvironment("SUPABASE_URL"),
        requiredEnvironment("SUPABASE_SERVICE_ROLE_KEY"),
        { auth: { persistSession: false, autoRefreshToken: false } },
      );
      const { data, error } = await serverClient
        .from(TABLE)
        .insert(row as never)
        .select("*")
        .single();
      if (error?.code === UNIQUE_VIOLATION) return { kind: "duplicate" };
      if (error || !data) {
        console.error(
          `[generate-custom-palette-recommendation] Persistence failed code=${
            error?.code ?? "unknown"
          }`,
        );
        throw new FunctionFailure(
          500,
          "persistence_failed",
          "The makeup plan could not be saved.",
          true,
        );
      }
      return { kind: "inserted", row: data as StoredPaletteRecommendation };
    },
  };
}
