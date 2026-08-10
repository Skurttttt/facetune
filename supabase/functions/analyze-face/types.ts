export type ValidationPayload = {
  faceCount: number;
  lightingAcceptable: boolean;
  sharpnessAcceptable: boolean;
  faceVisible: boolean;
  framingAcceptable: boolean;
};

export type AttributePayload = {
  faceShape: string;
  skinTone: string;
  undertone: string;
  eyeShape: string;
  lipShape: string;
  hairColor: string;
  eyeColor: string;
};

export type ConfidencePayload = Record<keyof AttributePayload, number>;

export type ValidatedGeminiResult = {
  imageValid: true;
  validation: ValidationPayload;
  analysis: AttributePayload;
  confidence: ConfidencePayload;
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
