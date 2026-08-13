import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

import {
  assertOwnedHistoryPaths,
  historyPrefix,
  isOwnedHistoryPath,
} from "./storage_paths.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};
const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const bucket = "face-images";
const listPageSize = 100;
const removeBatchSize = 100;
const maximumObjects = 10000;

class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "content-type": "application/json" },
  });
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name)?.trim();
  if (!value) {
    throw new FunctionFailure(
      500,
      "server_configuration",
      "History management is not configured.",
    );
  }
  return value;
}

function requestedAnalysisId(value: unknown): string {
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new FunctionFailure(
      400,
      "invalid_request",
      "A valid history deletion request is required.",
    );
  }
  const analysisId = (value as Record<string, unknown>).analysisId;
  if (typeof analysisId !== "string" || !uuidPattern.test(analysisId)) {
    throw new FunctionFailure(
      400,
      "invalid_analysis_id",
      "A valid analysis ID is required.",
    );
  }
  return analysisId;
}

type UserClient = SupabaseClient<any, "public", "public", any, any>;

async function listFilesRecursively(
  client: UserClient,
  directory: string,
  collected: string[] = [],
): Promise<string[]> {
  let offset = 0;
  while (true) {
    const { data, error } = await client.storage.from(bucket).list(directory, {
      limit: listPageSize,
      offset,
      sortBy: { column: "name", order: "asc" },
    });
    if (error) {
      throw new FunctionFailure(
        500,
        "storage_list_failed",
        "Private history files could not be inspected.",
        true,
      );
    }
    const entries = data ?? [];
    for (const entry of entries) {
      const path = `${directory}/${entry.name}`;
      if (entry.id) {
        collected.push(path);
        if (collected.length > maximumObjects) {
          throw new FunctionFailure(
            409,
            "history_too_large",
            "This history session is too large to delete safely.",
          );
        }
      } else {
        await listFilesRecursively(client, path, collected);
      }
    }
    if (entries.length < listPageSize) break;
    offset += entries.length;
  }
  return collected;
}

async function removeFiles(client: UserClient, paths: string[]): Promise<void> {
  for (let offset = 0; offset < paths.length; offset += removeBatchSize) {
    const batch = paths.slice(offset, offset + removeBatchSize);
    const { error } = await client.storage.from(bucket).remove(batch);
    if (error) {
      throw new FunctionFailure(
        500,
        "storage_delete_failed",
        "Private history files could not be deleted. No database records were removed.",
        true,
      );
    }
  }
}

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(
      {
        error: {
          code: "method_not_allowed",
          message: "Method not allowed.",
          retryable: false,
        },
      },
      405,
    );
  }

  try {
    const authorization = request.headers.get("authorization");
    if (!authorization?.toLowerCase().startsWith("bearer ")) {
      throw new FunctionFailure(
        401,
        "authentication_required",
        "Sign in before deleting history.",
      );
    }
    const client = createClient(
      requiredEnvironment("SUPABASE_URL"),
      requiredEnvironment("SUPABASE_ANON_KEY"),
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false, autoRefreshToken: false },
      },
    );
    const { data: authData, error: authError } = await client.auth.getUser();
    if (authError || !authData.user) {
      throw new FunctionFailure(
        401,
        "authentication_failed",
        "Your session has expired. Sign in again.",
      );
    }

    let payload: unknown;
    try {
      payload = await request.json();
    } catch {
      throw new FunctionFailure(
        400,
        "invalid_json",
        "The request body must be valid JSON.",
      );
    }
    const analysisId = requestedAnalysisId(payload);
    const prefix = historyPrefix(authData.user.id, analysisId);
    const { data: analysis, error: analysisError } = await client
      .from("analyses")
      .select("id, original_image_path")
      .eq("id", analysisId)
      .maybeSingle();
    if (analysisError) {
      throw new FunctionFailure(
        500,
        "analysis_lookup_failed",
        "This history item could not be verified.",
        true,
      );
    }
    const { data: generated, error: generatedError } = await client
      .from("generated_images")
      .select("storage_path")
      .eq("analysis_id", analysisId);
    if (generatedError) {
      throw new FunctionFailure(
        500,
        "preview_lookup_failed",
        "This history item's previews could not be verified.",
        true,
      );
    }
    const { data: kitGenerated, error: kitGeneratedError } = await client
      .from("kit_generated_images")
      .select("storage_path")
      .eq("analysis_id", analysisId);
    if (kitGeneratedError) {
      throw new FunctionFailure(
        500,
        "kit_preview_lookup_failed",
        "This history item's kit previews could not be verified.",
        true,
      );
    }
    const recordedPaths = [
      ...(analysis?.original_image_path
        ? [analysis.original_image_path as string]
        : []),
      ...((generated ?? []).map((row) => row.storage_path as string)),
      ...((kitGenerated ?? []).map((row) => row.storage_path as string)),
    ];
    try {
      assertOwnedHistoryPaths(recordedPaths, prefix);
    } catch {
      throw new FunctionFailure(
        409,
        "unsafe_storage_path",
        "This history item contains an unsafe storage path.",
      );
    }

    const storedFiles = await listFilesRecursively(client, prefix);
    if (storedFiles.some((path) => !isOwnedHistoryPath(path, prefix))) {
      throw new FunctionFailure(
        409,
        "unsafe_storage_path",
        "This history item contains an unsafe storage path.",
      );
    }
    await removeFiles(client, storedFiles);
    const remaining = await listFilesRecursively(client, prefix);
    if (remaining.length > 0) {
      throw new FunctionFailure(
        500,
        "storage_cleanup_incomplete",
        "Private history cleanup did not complete. Try again.",
        true,
      );
    }

    if (analysis) {
      const { error: deleteError } = await client
        .from("analyses")
        .delete()
        .eq("id", analysisId);
      if (deleteError) {
        throw new FunctionFailure(
          500,
          "database_delete_failed",
          "Private files were removed, but history cleanup must be retried.",
          true,
        );
      }
    }
    return jsonResponse({
      deleted: true,
      analysisId,
      removedObjectCount: storedFiles.length,
      alreadyDeleted: analysis === null,
    });
  } catch (error) {
    const failure = error instanceof FunctionFailure
      ? error
      : new FunctionFailure(
        500,
        "server_error",
        "This history item could not be deleted.",
        true,
      );
    if (!(error instanceof FunctionFailure)) {
      console.error(
        `[delete-history-item] Unhandled error type=${
          error?.constructor?.name ?? "unknown"
        }`,
      );
    }
    console.error(`[delete-history-item] request_failed code=${failure.code}`);
    return jsonResponse(
      {
        error: {
          code: failure.code,
          message: failure.message,
          retryable: failure.retryable,
        },
      },
      failure.status,
    );
  }
});
