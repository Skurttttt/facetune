import {
  isOwnedGeneratedPreviewPath,
  isOwnedOriginalPath,
} from "./storage_ownership.ts";
import {
  asTutorialCategory,
  INVENTORY_TO_TUTORIAL,
  STANDARD_KEY_TO_TUTORIAL,
  type SourceMode,
  type TutorialCategory,
} from "./tutorial_vocabulary.ts";

/// A resolution failure. Carries a generic user-facing message plus a stable
/// code; never the underlying database error, path, or row content.
export class ResolutionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
    this.name = "ResolutionFailure";
  }
}

export interface ResolvedImage {
  /** Private storage path. Never a signed URL — those expire, so persisting or
   * passing one around would hand out a credential with its own lifetime. */
  path: string;
  mimeType: string;
  bytes: Uint8Array;
}

/// One immutable owned-product record, mapped to the category being generated.
///
/// Taken from the look's persisted snapshot, never from live inventory: a
/// product the user has since edited or deleted must still render the tutorial
/// exactly as the look was validated.
export interface ResolvedProduct {
  productId: string;
  inventoryCategory: string;
  productName: string | null;
  colorHex: string;
  colorLabel: string | null;
  finish: string;
  foundationDepth: string | null;
  foundationUndertone: string | null;
}

/// Brand-neutral Standard Mode guidance for one category.
export interface StandardCategoryPlan {
  planKey: string;
  shadeName: string;
  colorHex: string | null;
  placement: string;
  technique: string;
  finish: string;
  intensity: string;
}

/// Everything a guideline request needs, assembled entirely server-side.
///
/// Nothing in here originates from the client except the session id and the
/// category, and both are re-verified against owner-scoped rows before they
/// reach this object.
export interface TutorialGenerationContext {
  userId: string;
  tutorialSessionId: string;
  stepId: string;
  category: TutorialCategory;
  /** Position among the INCLUDED steps, and how many there are. */
  position: number;
  includedCount: number;
  generationAttempt: number;
  sourceMode: SourceMode;
  analysisId: string;
  /** Image A. The identity and "before" reference. */
  originalImage: ResolvedImage;
  /** Image B. The canonical final preview — the visual placement authority. */
  canonicalPreview: ResolvedImage;
  styleCode: string;
  /** Supporting facial attributes. Context for technique wording only; never
   * placement authority, which belongs to the canonical preview alone. */
  faceAttributes: Record<string, string | null>;
  /** Standard Mode brand-neutral guidance for this category, when present. */
  standardPlan: StandardCategoryPlan[];
  /** My Makeup Kit snapshot item(s) for this category. Empty in Standard Mode. */
  products: ResolvedProduct[];
}

/// The minimal Supabase surface the resolver needs.
export interface ResolverClient {
  // deno-lint-ignore no-explicit-any
  from: (table: string) => any;
  storage: {
    // deno-lint-ignore no-explicit-any
    from: (bucket: string) => any;
  };
}

export interface ResolveRequest {
  tutorialSessionId: string;
  category: string;
}

const uuidPattern =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const imageExtensions = ["jpg", "jpeg", "png", "webp"] as const;

function notFound(): ResolutionFailure {
  // One message for every "cannot resolve" case. Distinguishing "no such
  // session" from "not yours" would let a caller probe for other accounts' ids.
  return new ResolutionFailure(
    404,
    "tutorial_source_not_found",
    "This tutorial step is no longer available.",
  );
}

function mimeTypeFor(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

function text(row: Record<string, unknown>, key: string): string | null {
  const value = row[key];
  return typeof value === "string" && value.length > 0 ? value : null;
}

/// Resolves the complete, owner-proven context for one guideline request.
///
/// [client] must already be scoped to the caller's JWT, and [userId] must come
/// from `auth.getUser()` on that same client — never from the request body.
/// Every read below therefore passes through RLS as well as the explicit checks.
///
/// Deliberately absent from the request: model, resolution, prompt version,
/// image paths, product ids, and source mode. A caller supplies only which
/// session and which category, and even those are re-verified.
export async function resolveTutorialSource(
  client: ResolverClient,
  userId: string,
  request: ResolveRequest,
): Promise<TutorialGenerationContext> {
  if (!uuidPattern.test(request.tutorialSessionId)) {
    throw new ResolutionFailure(
      400,
      "invalid_request",
      "A valid tutorial step is required.",
    );
  }
  const category = asTutorialCategory(request.category);
  if (category === null) {
    // An unrecognised category never reaches a prompt.
    throw new ResolutionFailure(
      400,
      "unsupported_category",
      "That tutorial step is not supported.",
    );
  }

  const { data: sessionRow } = await client
    .from("tutorial_v4_sessions")
    .select(
      "id,user_id,analysis_id,source_mode,recommendation_id," +
        "kit_recommendation_id,canonical_generated_image_id," +
        "canonical_kit_generated_image_id,manifest_status",
    )
    .eq("id", request.tutorialSessionId)
    .maybeSingle();
  if (!sessionRow) throw notFound();
  const session = sessionRow as Record<string, unknown>;

  // RLS already scopes the read; this is the explicit second check, so a policy
  // regression cannot silently widen access.
  if (session.user_id !== userId) throw notFound();

  const sourceMode = session.source_mode;
  if (sourceMode !== "standard" && sourceMode !== "my_makeup_kit") {
    throw new ResolutionFailure(
      422,
      "invalid_source_mode",
      "This tutorial could not be prepared.",
    );
  }
  const isKit = sourceMode === "my_makeup_kit";

  if (session.manifest_status !== "accepted") {
    // Covers pending, analyzing, failed, and kit_preview_mismatch. A mismatched
    // look must never produce a guideline for a product the user does not own.
    throw new ResolutionFailure(
      409,
      session.manifest_status === "kit_preview_mismatch"
        ? "kit_preview_mismatch"
        : "manifest_not_accepted",
      "This tutorial is not ready.",
    );
  }

  // The category must be one the manifest actually included. In kit mode that
  // also means an owned product backs it.
  const { data: manifestRows } = await client
    .from("tutorial_v4_manifest_items")
    .select("category,presence,product_backed")
    .eq("tutorial_session_id", request.tutorialSessionId);
  const manifest = (manifestRows ?? []) as Array<Record<string, unknown>>;
  if (manifest.length === 0) throw notFound();

  const included = manifest.filter((item) =>
    item.presence === "present" && (!isKit || item.product_backed === true)
  );
  const approved = included.find((item) => item.category === category);
  if (!approved) {
    throw new ResolutionFailure(
      422,
      "category_not_included",
      "That step is not part of this look.",
    );
  }

  const { data: stepRow } = await client
    .from("tutorial_v4_steps")
    .select("id,position,generation_attempt")
    .eq("tutorial_session_id", request.tutorialSessionId)
    .eq("category", category)
    .maybeSingle();
  if (!stepRow) throw notFound();
  const step = stepRow as Record<string, unknown>;

  const recommendationId = isKit
    ? session.kit_recommendation_id
    : session.recommendation_id;
  const previewId = isKit
    ? session.canonical_kit_generated_image_id
    : session.canonical_generated_image_id;
  if (typeof recommendationId !== "string" || typeof previewId !== "string") {
    throw new ResolutionFailure(
      422,
      "invalid_source_mode",
      "This tutorial could not be prepared.",
    );
  }
  const analysisId = session.analysis_id as string;

  const [analysisResult, previewResult, recommendationResult] = await Promise
    .all([
      client.from("analyses").select(
        "id,original_image_path,face_shape,skin_tone,undertone,eye_shape," +
          "lip_shape,hair_color,eye_color",
      ).eq("id", analysisId).maybeSingle(),
      client.from(isKit ? "kit_generated_images" : "generated_images")
        .select("id,storage_path").eq("id", previewId).maybeSingle(),
      client.from(isKit ? "kit_makeup_recommendations" : "recommendations")
        .select(
          isKit
            ? "id,makeup_style,product_snapshot_json"
            : "id,makeup_style,recommendation_json",
        ).eq("id", recommendationId).maybeSingle(),
    ]);

  const analysis = analysisResult?.data as Record<string, unknown> | null;
  const preview = previewResult?.data as Record<string, unknown> | null;
  const recommendation = recommendationResult?.data as
    | Record<string, unknown>
    | null;
  if (!analysis || !preview || !recommendation) throw notFound();

  const originalPath = text(analysis, "original_image_path");
  const previewPath = text(preview, "storage_path");
  // Both images are mandatory. There is no single-image fallback: a guideline
  // drawn without the "before" reference could not tell makeup from a natural
  // feature, and one drawn without the final preview would have no target.
  if (!originalPath || !previewPath) throw notFound();

  if (!isOwnedOriginalPath(originalPath, userId, analysisId, imageExtensions)) {
    throw new ResolutionFailure(
      403,
      "invalid_original_path",
      "This tutorial could not be prepared.",
    );
  }
  if (
    !isOwnedGeneratedPreviewPath(
      previewPath,
      userId,
      analysisId,
      isKit ? "kit-generated" : "generated",
      recommendationId,
      imageExtensions,
    )
  ) {
    throw new ResolutionFailure(
      403,
      "invalid_preview_path",
      "This tutorial could not be prepared.",
    );
  }

  const [originalDownload, previewDownload] = await Promise.all([
    client.storage.from("face-images").download(originalPath),
    client.storage.from("face-images").download(previewPath),
  ]);
  if (
    originalDownload?.error || !originalDownload?.data ||
    previewDownload?.error || !previewDownload?.data
  ) {
    throw new ResolutionFailure(
      502,
      "source_image_unavailable",
      "The images for this tutorial could not be read.",
      true,
    );
  }

  const products = isKit
    ? resolveProducts(recommendation.product_snapshot_json, category)
    : [];
  if (isKit && products.length === 0) {
    // The manifest said this category was product-backed, so a snapshot item
    // must exist. Its absence means the two disagree, and inventing a product
    // is never the answer.
    throw new ResolutionFailure(
      409,
      "kit_preview_mismatch",
      "This step uses makeup that is not in your kit.",
    );
  }

  return {
    userId,
    tutorialSessionId: request.tutorialSessionId,
    stepId: step.id as string,
    category,
    position: typeof step.position === "number" ? step.position : 1,
    includedCount: included.length,
    generationAttempt: typeof step.generation_attempt === "number"
      ? step.generation_attempt
      : 0,
    sourceMode,
    analysisId,
    originalImage: {
      path: originalPath,
      mimeType: mimeTypeFor(originalPath),
      bytes: new Uint8Array(await originalDownload.data.arrayBuffer()),
    },
    canonicalPreview: {
      path: previewPath,
      mimeType: mimeTypeFor(previewPath),
      bytes: new Uint8Array(await previewDownload.data.arrayBuffer()),
    },
    styleCode: text(recommendation, "makeup_style") ?? "",
    faceAttributes: {
      faceShape: text(analysis, "face_shape"),
      skinTone: text(analysis, "skin_tone"),
      undertone: text(analysis, "undertone"),
      eyeShape: text(analysis, "eye_shape"),
      lipShape: text(analysis, "lip_shape"),
      hairColor: text(analysis, "hair_color"),
      eyeColor: text(analysis, "eye_color"),
    },
    standardPlan: isKit
      ? []
      : resolveStandardPlan(recommendation.recommendation_json, category),
    products,
  };
}

/// Extracts the immutable snapshot item(s) mapped to [category].
///
/// Reads the look's persisted snapshot only. `makeup_kit_products` is
/// deliberately never queried here: live inventory is not historical authority,
/// and a later edit must not change what an existing tutorial teaches.
export function resolveProducts(
  snapshot: unknown,
  category: TutorialCategory,
): ResolvedProduct[] {
  if (!Array.isArray(snapshot)) return [];
  const resolved: ResolvedProduct[] = [];
  for (const entry of snapshot) {
    if (typeof entry !== "object" || entry === null) continue;
    const row = entry as Record<string, unknown>;
    const inventoryCategory = text(row, "category");
    if (!inventoryCategory) continue;
    if (INVENTORY_TO_TUTORIAL[inventoryCategory] !== category) continue;
    const productId = text(row, "productId");
    const colorHex = text(row, "colorHex");
    const finish = text(row, "finish");
    if (!productId || !colorHex || !finish) continue;
    resolved.push({
      productId,
      inventoryCategory,
      productName: text(row, "productName"),
      colorHex,
      colorLabel: text(row, "colorLabel"),
      finish,
      foundationDepth: text(row, "foundationDepth"),
      foundationUndertone: text(row, "foundationUndertone"),
    });
  }
  return resolved;
}

/// Extracts the brand-neutral Standard Mode guidance for [category].
///
/// One tutorial category can draw on more than one plan key — Lips is fed by
/// both `lipstick` and `lipGloss` — so the result is a list.
export function resolveStandardPlan(
  plan: unknown,
  category: TutorialCategory,
): StandardCategoryPlan[] {
  if (typeof plan !== "object" || plan === null || Array.isArray(plan)) {
    return [];
  }
  const root = plan as Record<string, unknown>;
  const resolved: StandardCategoryPlan[] = [];
  for (const key of Object.keys(root)) {
    if (STANDARD_KEY_TO_TUTORIAL[key] !== category) continue;
    const entry = root[key];
    if (typeof entry !== "object" || entry === null) continue;
    const item = entry as Record<string, unknown>;
    const shadeName = text(item, "name");
    const placement = text(item, "placement");
    const technique = text(item, "technique");
    if (!shadeName || !placement || !technique) continue;
    resolved.push({
      planKey: key,
      shadeName,
      colorHex: text(item, "hex"),
      placement,
      technique,
      finish: text(item, "finish") ?? "",
      intensity: text(item, "intensity") ?? "",
    });
  }
  return resolved;
}

/// A log line safe to emit for a resolution.
///
/// Ids, a category, and counts only — never a storage path, a product name, a
/// shade, a face attribute, or any image data.
export function sanitizedResolutionLog(
  context: TutorialGenerationContext,
): string {
  return `[tutorial-source] session=${context.tutorialSessionId} ` +
    `step=${context.stepId} category=${context.category} ` +
    `mode=${context.sourceMode} position=${context.position}/${context.includedCount} ` +
    `products=${context.products.length} attempt=${context.generationAttempt}`;
}
