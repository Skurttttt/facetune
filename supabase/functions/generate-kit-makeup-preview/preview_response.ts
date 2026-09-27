/** The client-facing shape of a persisted kit preview, shared by the v1 path
 * and the plan-driven path so both return exactly the same fields. */
export function previewResponse(
  row: Record<string, unknown>,
  originalImagePath: string,
) {
  return {
    preview: {
      id: row.id,
      mode: "makeup_kit",
      analysisId: row.analysis_id,
      kitRecommendationId: row.kit_recommendation_id,
      originalImagePath,
      generatedImagePath: row.storage_path,
      generationNumber: row.generation_number,
      modelId: row.model_name,
      promptVersion: row.prompt_version,
      createdAt: row.created_at,
    },
  };
}
