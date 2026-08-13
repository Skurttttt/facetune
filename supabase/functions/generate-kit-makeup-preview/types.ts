export type KitProductSnapshot = {
  productId: string;
  category: string;
  productName: string | null;
  colorHex: string;
  colorLabel: string | null;
  finish: string;
  foundationDepth: string | null;
  foundationUndertone: string | null;
};

export type CurrentKitProduct = {
  id: string;
  user_id: string;
  category: string;
  product_name: string | null;
  color_hex: string;
  color_label: string | null;
  finish: string;
  foundation_depth: string | null;
  foundation_undertone: string | null;
};

export type KitPreviewSelection = {
  productId: string;
  category: string;
  colorHex: string;
  finish: string;
  placement: string;
  technique: string;
  intensity: "sheer" | "soft" | "medium" | "bold";
};

export type NormalizedKitPreviewPlan = {
  selections: KitPreviewSelection[];
  overallIntensity: "sheer" | "soft" | "medium" | "bold";
};

export type GeneratedImage = {
  bytes: Uint8Array;
  mimeType: "image/png" | "image/jpeg" | "image/webp";
};

export class FunctionFailure extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly retryable = false,
  ) {
    super(message);
  }
}
