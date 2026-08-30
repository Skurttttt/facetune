import { createClient } from "npm:@supabase/supabase-js@2";

import { consumeAiQuota, quotaMessage } from "../_shared/ai_quota.ts";
import {
  isOwnedGeneratedPreviewPath,
  isOwnedOriginalPath,
} from "../_shared/storage_ownership.ts";
import { requestGeminiManifest } from "./gemini_client.ts";
import { TUTORIAL_MANIFEST_PROMPT_VERSION } from "./prompt.ts";
import { TUTORIAL_MANIFEST_SCHEMA_VERSION } from "./schema.ts";
import {
  FunctionFailure,
  type SourceMode,
  type TutorialCategory,
} from "./types.ts";
import {
  parseManifestResponse,
  productBackedCategories,
  resolveManifest,
} from "./validation.ts";

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, x-client-info, apikey, content-type",
};
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
      `[analyze-tutorial-manifest-v4] Missing server environment variable: ${name}`,
    );
    throw new FunctionFailure(
      500,
      "server_configuration",
      "The tutorial service is not configured.",
    );
  }
  return value;
}

/// The client names exactly one canonical preview, and which field it uses is
/// what determines the source mode.
///
/// The mode is never accepted as a client-supplied string: it is derived from
/// which owner-scoped table actually holds the row, so a caller cannot claim
/// Standard Mode for a kit look (or the reverse) to dodge the ownership
/// intersection.
function requestPayload(
  value: unknown,
): { previewId: string; sourceMode: SourceMode } {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid tutorial request is required.",
    );
  }
  const input = value as Record<string, unknown>;
  const standard = input.generatedImageId;
  const kit = input.kitGeneratedImageId;
  const hasStandard = typeof standard === "string";
  const hasKit = typeof kit === "string";
  if (hasStandard === hasKit) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "Provide exactly one canonical preview.",
    );
  }
  const previewId = (hasStandard ? standard : kit) as string;
  if (!uuidPattern.test(previewId)) {
    throw new FunctionFailure(
      400,
      "invalid_preview_id",
      "A valid canonical preview ID is required.",
    );
  }
  return {
    previewId,
    sourceMode: hasStandard ? "standard" : "my_makeup_kit",
  };
}

function mimeTypeFor(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      { error: { code: "method_not_allowed", message: "Use POST." } },
      405,
    );
  }
  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before preparing a tutorial.",
      );
    }
    const supabaseUrl = requiredEnvironment("SUPABASE_URL");
    const supabaseAnonKey = requiredEnvironment("SUPABASE_ANON_KEY");
    // Reuses FaceTune's approved multimodal structured-output model. The
    // analyzer must never be the image renderer, and it must never be pointed
    // at an image-generation model.
    const model = Deno.env.get("GEMINI_MANIFEST_MODEL")?.trim() ||
      "gemini-3.6-flash";
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } = await client.auth.getUser();
    if (authError || !authData.user) {
      throw new FunctionFailure(
        401,
        "invalid_session",
        "Your session has expired. Sign in again.",
      );
    }
    const userId = authData.user.id;

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
    const { previewId, sourceMode } = requestPayload(body);
    const isKit = sourceMode === "my_makeup_kit";

    // Every read below goes through the RLS-scoped user client, so a preview
    // belonging to another account simply does not resolve.
    const previewTable = isKit ? "kit_generated_images" : "generated_images";
    const recommendationColumn = isKit
      ? "kit_recommendation_id"
      : "recommendation_id";
    const { data: preview, error: previewError } = await client
      .from(previewTable)
      .select(`id,analysis_id,${recommendationColumn},storage_path`)
      .eq("id", previewId)
      .maybeSingle();
    if (previewError || !preview) {
      throw new FunctionFailure(
        404,
        "canonical_preview_not_found",
        "The final look could not be found.",
      );
    }
    const previewRow = preview as unknown as Record<string, unknown>;
    const analysisId = previewRow.analysis_id as string;
    const recommendationId = previewRow[recommendationColumn] as string;
    const previewPath = previewRow.storage_path as string;

    // An accepted manifest for this exact preview is reused rather than
    // re-analyzed. Analysis is a paid multimodal call, so this check happens
    // before anything is downloaded and before quota is touched.
    const { data: existingSession } = await client
      .from("tutorial_v4_sessions")
      .select("id,manifest_status,manifest_prompt_version,manifest_schema_version")
      .eq(
        isKit ? "canonical_kit_generated_image_id" : "canonical_generated_image_id",
        previewId,
      )
      .maybeSingle();
    const existing = existingSession as Record<string, unknown> | null;
    if (
      existing &&
      (existing.manifest_status === "accepted" ||
        existing.manifest_status === "kit_preview_mismatch") &&
      existing.manifest_prompt_version === TUTORIAL_MANIFEST_PROMPT_VERSION &&
      existing.manifest_schema_version === TUTORIAL_MANIFEST_SCHEMA_VERSION
    ) {
      const { data: items } = await client
        .from("tutorial_v4_manifest_items")
        .select("category,position,presence,visual_confidence,product_backed")
        .eq("tutorial_session_id", existing.id as string)
        .order("position", { ascending: true });
      console.log(
        `[analyze-tutorial-manifest-v4] Reused session=${existing.id} status=${existing.manifest_status}`,
      );
      return jsonResponse({
        manifest: {
          tutorialSessionId: existing.id,
          sourceMode,
          manifestStatus: existing.manifest_status,
          model: null,
          promptVersion: TUTORIAL_MANIFEST_PROMPT_VERSION,
          schemaVersion: TUTORIAL_MANIFEST_SCHEMA_VERSION,
          reused: true,
          items: items ?? [],
        },
      });
    }

    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select("id,original_image_path")
      .eq("id", analysisId)
      .maybeSingle();
    if (analysisError || !analysis) {
      throw new FunctionFailure(
        404,
        "source_image_not_found",
        "The original analysis could not be found.",
      );
    }
    const originalPath =
      (analysis as unknown as Record<string, unknown>).original_image_path as string;

    // Both images are proven to belong to the caller, segment by segment,
    // before either is read. The tutorial is grounded entirely in this pair.
    if (!isOwnedOriginalPath(originalPath, userId, analysisId, [
      "jpg",
      "jpeg",
      "png",
      "webp",
    ])) {
      throw new FunctionFailure(
        403,
        "invalid_original_path",
        "The original image path is invalid.",
      );
    }
    if (
      !isOwnedGeneratedPreviewPath(
        previewPath,
        userId,
        analysisId,
        isKit ? "kit-generated" : "generated",
        recommendationId,
      )
    ) {
      throw new FunctionFailure(
        403,
        "invalid_preview_path",
        "The final look path is invalid.",
      );
    }

    // In kit mode the immutable snapshot decides what the user can actually
    // reproduce. It is read server-side and never supplied by the caller.
    let backed = new Set<TutorialCategory>();
    let supportingContext = "Standard Mode: no owned-product constraint.";
    if (isKit) {
      const { data: kitRecommendation, error: kitError } = await client
        .from("kit_makeup_recommendations")
        .select("id,product_snapshot_json")
        .eq("id", recommendationId)
        .maybeSingle();
      if (kitError || !kitRecommendation) {
        throw new FunctionFailure(
          404,
          "kit_recommendation_not_found",
          "The kit-based makeup plan is no longer available.",
        );
      }
      const snapshot =
        (kitRecommendation as unknown as Record<string, unknown>)
          .product_snapshot_json;
      backed = productBackedCategories(snapshot);
      supportingContext =
        `My Makeup Kit Mode. Categories the user owns a product for: ${
          [...backed].join(", ") || "none"
        }. This is context only and never evidence of visual presence.`;
    }

    const [originalDownload, previewDownload, quota] = await Promise.all([
      client.storage.from("face-images").download(originalPath),
      client.storage.from("face-images").download(previewPath),
      consumeAiQuota(client, "tutorial_manifest_analysis"),
    ]);
    if (!quota.allowed) {
      throw new FunctionFailure(
        429,
        "rate_limited",
        quotaMessage(quota.reason),
        true,
      );
    }
    // Fail safely: without BOTH images there is no visual comparison, and a
    // manifest that cannot see the final look must never be invented.
    if (
      originalDownload.error || !originalDownload.data ||
      previewDownload.error || !previewDownload.data
    ) {
      throw new FunctionFailure(
        502,
        "visual_comparison_unavailable",
        "The images needed to prepare this tutorial could not be read.",
        true,
      );
    }

    const geminiText = await requestGeminiManifest(
      requiredEnvironment("GEMINI_API_KEY"),
      model,
      {
        bytes: new Uint8Array(await originalDownload.data.arrayBuffer()),
        mimeType: mimeTypeFor(originalPath),
      },
      {
        bytes: new Uint8Array(await previewDownload.data.arrayBuffer()),
        mimeType: mimeTypeFor(previewPath),
      },
      supportingContext,
    );
    const verdicts = parseManifestResponse(geminiText);
    const resolved = resolveManifest(verdicts, sourceMode, backed);

    const sessionRow: Record<string, unknown> = {
      user_id: userId,
      analysis_id: analysisId,
      source_mode: sourceMode,
      status: resolved.manifestStatus === "kit_preview_mismatch"
        ? "kit_preview_mismatch"
        : "manifest_ready",
      manifest_status: resolved.manifestStatus,
      manifest_model: model,
      manifest_prompt_version: TUTORIAL_MANIFEST_PROMPT_VERSION,
      manifest_schema_version: TUTORIAL_MANIFEST_SCHEMA_VERSION,
      manifest_created_at: new Date().toISOString(),
    };
    if (isKit) {
      sessionRow.kit_recommendation_id = recommendationId;
      sessionRow.canonical_kit_generated_image_id = previewId;
    } else {
      sessionRow.recommendation_id = recommendationId;
      sessionRow.canonical_generated_image_id = previewId;
    }

    const { data: session, error: sessionError } = await client
      .from("tutorial_v4_sessions")
      .upsert(sessionRow as never, {
        onConflict: isKit
          ? "canonical_kit_generated_image_id"
          : "canonical_generated_image_id",
      })
      .select("id")
      .single();
    if (sessionError || !session) {
      console.error(
        `[analyze-tutorial-manifest-v4] Session persistence failed code=${
          sessionError?.code ?? "unknown"
        }`,
      );
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "The tutorial could not be saved.",
        true,
      );
    }
    const sessionId = (session as unknown as Record<string, unknown>)
      .id as string;

    // Replace rather than append, so a re-analysis after a version bump cannot
    // leave two generations of verdicts behind.
    await client.from("tutorial_v4_manifest_items").delete().eq(
      "tutorial_session_id",
      sessionId,
    );
    const { error: itemsError } = await client
      .from("tutorial_v4_manifest_items")
      .insert(
        resolved.items.map((item) => ({
          user_id: userId,
          tutorial_session_id: sessionId,
          category: item.category,
          position: item.position,
          presence: item.presence,
          visual_confidence: item.visualConfidence,
          product_backed: item.productBacked,
        })) as never,
      );
    if (itemsError) {
      console.error(
        `[analyze-tutorial-manifest-v4] Item persistence failed code=${itemsError.code}`,
      );
      throw new FunctionFailure(
        500,
        "persistence_failed",
        "The tutorial could not be saved.",
        true,
      );
    }

    console.log(
      `[analyze-tutorial-manifest-v4] Completed model=${model} prompt=${TUTORIAL_MANIFEST_PROMPT_VERSION} mode=${sourceMode} status=${resolved.manifestStatus} included=${resolved.includedCategories.length}`,
    );
    return jsonResponse({
      manifest: {
        tutorialSessionId: sessionId,
        sourceMode,
        manifestStatus: resolved.manifestStatus,
        model,
        promptVersion: TUTORIAL_MANIFEST_PROMPT_VERSION,
        schemaVersion: TUTORIAL_MANIFEST_SCHEMA_VERSION,
        reused: false,
        includedCategories: resolved.includedCategories,
        unbackedPresentCategories: resolved.unbackedPresentCategories,
        items: resolved.items,
      },
    });
  } catch (error) {
    const failure = error instanceof FunctionFailure ? error : new FunctionFailure(
      500,
      "server_error",
      "The tutorial request could not be completed.",
    );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[analyze-tutorial-manifest-v4] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
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
