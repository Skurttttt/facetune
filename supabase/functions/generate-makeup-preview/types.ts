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
