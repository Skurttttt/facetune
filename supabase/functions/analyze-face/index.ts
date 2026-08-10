import { createClient } from "npm:@supabase/supabase-js@2";

import { requestGeminiAnalysis } from "./gemini_client.ts";
import { FACE_ANALYSIS_PROMPT_VERSION } from "./prompt.ts";
import { FunctionFailure } from "./types.ts";
import { parseAndValidateGeminiText } from "./validation.ts";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
};
const maximumImageBytes = 10 * 1024 * 1024;
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    console.error(
      `[analyze-face] Missing server environment variable: ${name}`,
    );
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The analysis service is not configured.",
    );
  }
  return value;
}

function requestPayload(
  value: unknown,
): { analysisId: string; storagePath: string } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid analysis request is required.",
    );
  }
  const input = value as Record<string, unknown>;
  if (
    typeof input.analysisId !== "string" || !uuidPattern.test(input.analysisId)
  ) {
    throw new FunctionFailure(
      400,
      "invalid_analysis_id",
      "A valid analysis ID is required.",
    );
  }
  if (typeof input.storagePath !== "string" || input.storagePath.length > 500) {
    throw new FunctionFailure(
      400,
      "invalid_storage_path",
      "A valid private image path is required.",
    );
  }
  return { analysisId: input.analysisId, storagePath: input.storagePath };
}

function analysisResponse(row: Record<string, unknown>) {
  const metadata = (row.raw_ai_metadata ?? {}) as Record<string, unknown>;
  return {
    analysis: {
      id: row.id,
      originalImagePath: row.original_image_path,
      validation: metadata.validation,
      attributes: {
        faceShape: row.face_shape,
        skinTone: row.skin_tone,
        undertone: row.undertone,
        eyeShape: row.eye_shape,
        lipShape: row.lip_shape,
        hairColor: row.hair_color,
        eyeColor: row.eye_color,
      },
      confidence: row.confidence_json,
      modelId: row.model_name,
      promptVersion: row.prompt_version,
      createdAt: row.created_at,
    },
  };
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse({
      error: {
        code: "method_not_allowed",
        message: "Method not allowed.",
        retryable: false,
      },
    }, 405);
  }

  let storagePath: string | null = null;
  let userClient: ReturnType<typeof createClient> | null = null;
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before analyzing a selfie.",
      );
    }
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const supabaseAnonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    const geminiApiKey = requiredEnvironment("GEMINI_API_KEY");
    const model = Deno.env.get("GEMINI_MODEL")?.trim() || "gemini-3.6-flash";
    userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await userClient.auth
      .getUser();
    if (authError || !authData.user) {
      throw new FunctionFailure(
        401,
        "invalid_session",
        "Your session has expired. Sign in again.",
      );
    }

    let decodedBody: unknown;
    try {
      decodedBody = await request.json();
    } catch {
      throw new FunctionFailure(
        400,
        "invalid_json",
        "The request body must be valid JSON.",
      );
    }
    const payload = requestPayload(decodedBody);
    storagePath = payload.storagePath;
    const expectedPrefix =
      `${authData.user.id}/analyses/${payload.analysisId}/original/`;
    if (
      !storagePath.startsWith(expectedPrefix) || !storagePath.endsWith(".jpg")
    ) {
      throw new FunctionFailure(
        403,
        "invalid_storage_ownership",
        "The image path is not owned by this session.",
      );
    }

    const { data: existing } = await userClient
      .from("analyses")
      .select("*")
      .eq("id", payload.analysisId)
      .maybeSingle();
    if (existing) return jsonResponse(analysisResponse(existing));

    const { data: storedImage, error: downloadError } = await userClient.storage
      .from("face-images")
      .download(storagePath);
    if (downloadError || !storedImage) {
      throw new FunctionFailure(
        404,
        "image_not_found",
        "The private selfie could not be loaded.",
      );
    }
    if (storedImage.size <= 0 || storedImage.size > maximumImageBytes) {
      throw new FunctionFailure(
        422,
        "invalid_image_size",
        "The selfie has an unsupported file size.",
      );
    }
    const mimeType = storedImage.type || "image/jpeg";
    if (mimeType !== "image/jpeg") {
      throw new FunctionFailure(
        422,
        "invalid_image_type",
        "The prepared selfie must be a JPEG image.",
      );
    }

    const imageBytes = new Uint8Array(await storedImage.arrayBuffer());
    const geminiText = await requestGeminiAnalysis(
      geminiApiKey,
      model,
      imageBytes,
      mimeType,
    );
    const result = parseAndValidateGeminiText(geminiText);
    const { data: inserted, error: insertError } = await userClient
      .from("analyses")
      .insert({
        id: payload.analysisId,
        user_id: authData.user.id,
        original_image_path: storagePath,
        face_shape: result.analysis.faceShape,
        skin_tone: result.analysis.skinTone,
        undertone: result.analysis.undertone,
        eye_shape: result.analysis.eyeShape,
        lip_shape: result.analysis.lipShape,
        hair_color: result.analysis.hairColor,
        eye_color: result.analysis.eyeColor,
        confidence_json: result.confidence,
        raw_ai_metadata: {
          validation: result.validation,
          schemaVersion: 1,
        },
        model_name: model,
        prompt_version: FACE_ANALYSIS_PROMPT_VERSION,
      } as never)
      .select("*")
      .single();
    if (insertError || !inserted) {
      console.error(
        `[analyze-face] Persistence failed code=${
          insertError?.code ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "The analysis could not be saved.",
        true,
      );
    }
    console.log(
      `[analyze-face] Analysis completed model=${model} prompt=${FACE_ANALYSIS_PROMPT_VERSION}`,
    );
    return jsonResponse(analysisResponse(inserted));
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "The analysis request could not be completed.",
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[analyze-face] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    if (failure.status === 422 && storagePath && userClient) {
      await userClient.storage.from("face-images").remove([storagePath]);
    }
    return jsonResponse({
      error: {
        code: failure.code,
        message: failure.message,
        retryable: failure.retryable,
      },
    }, failure.status);
  }
});
