import {
  canonicalJson,
  type CanonicalPlan,
  PlanViolation,
  verifyStoredPlan,
} from "../_shared/kit_makeup_plan.ts";
import { KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION } from "./prompt_v2.ts";
import { FunctionFailure } from "./types.ts";

export type PreviewRoute =
  | { kind: "legacy_v1" }
  | { kind: "plan_v2"; plan: CanonicalPlan };

/**
 * Which preview contract renders a saved kit recommendation.
 *
 * A recommendation without a plan is a historical v2 look and stays on
 * `kit_makeup_preview_v1`, unchanged. A plan-backed recommendation is rendered
 * only by the preview version its plan pinned, and only after the stored plan
 * is proven intact and identical to the snapshot persisted beside it. Nothing
 * here ever falls back from one contract to the other.
 */
export async function resolvePreviewRoute(
  row: Record<string, unknown>,
): Promise<PreviewRoute> {
  if (row.plan_id === null || row.plan_id === undefined) {
    return { kind: "legacy_v1" };
  }
  let plan: CanonicalPlan;
  try {
    plan = await verifyStoredPlan(row.plan_json, row.plan_digest);
  } catch (error) {
    if (!(error instanceof PlanViolation)) throw error;
    throw invalidPlan(error.code);
  }
  if (
    plan.plan_id !== row.plan_id ||
    plan.analysis_id !== row.analysis_id ||
    plan.style_code !== row.makeup_style
  ) throw invalidPlan("plan_row_mismatch");
  if (
    canonicalJson(row.product_snapshot_json) !==
      canonicalJson(plan.selected_items.map((item) => item.product_snapshot))
  ) throw invalidPlan("plan_snapshot_mismatch");
  if (plan.preview_prompt_version !== KIT_MAKEUP_PREVIEW_V2_PROMPT_VERSION) {
    throw invalidPlan("unsupported_preview_version");
  }
  return { kind: "plan_v2", plan };
}

function invalidPlan(code: string): FunctionFailure {
  console.error(`[generate-kit-makeup-preview] plan_refused code=${code}`);
  return new FunctionFailure(
    422,
    "invalid_kit_plan",
    "The saved kit-based makeup plan is invalid.",
  );
}
