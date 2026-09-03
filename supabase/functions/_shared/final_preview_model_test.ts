import {
  assertEquals,
  assertThrows,
} from "https://deno.land/std@0.224.0/assert/mod.ts";

import {
  FINAL_PREVIEW_MODEL,
  finalPreviewModelConfigurationError,
  resolveFinalPreviewModel,
} from "./final_preview_model.ts";

/// V4-QA-8 remediation: the final-preview model cannot be anything else.
///
/// Both preview functions used to resolve
/// `Deno.env.get("GEMINI_IMAGE_MODEL")?.trim() || "gemini-3-pro-image"`, which
/// is correct only while the secret happens to be set. These tests pin the
/// three configuration states so the silent-substitution path cannot come back.

const VARIABLE = "GEMINI_IMAGE_MODEL";

/// Runs [body] with the variable set to [value], or unset when null.
///
/// Restores the previous value afterwards, so ordering between tests cannot
/// change an outcome.
function withConfiguredModel(value: string | null, body: () => void): void {
  const previous = Deno.env.get(VARIABLE);
  try {
    if (value === null) {
      Deno.env.delete(VARIABLE);
    } else {
      Deno.env.set(VARIABLE, value);
    }
    body();
  } finally {
    if (previous === undefined) {
      Deno.env.delete(VARIABLE);
    } else {
      Deno.env.set(VARIABLE, previous);
    }
  }
}

Deno.test("the locked model is the flash image model", () => {
  assertEquals(FINAL_PREVIEW_MODEL, "gemini-3.1-flash-image");
});

Deno.test("a missing variable resolves to the locked model", () => {
  withConfiguredModel(null, () => {
    assertEquals(finalPreviewModelConfigurationError(), null);
    assertEquals(resolveFinalPreviewModel(), "gemini-3.1-flash-image");
  });
});

Deno.test("a blank variable resolves to the locked model", () => {
  for (const blank of ["", "   ", "\t"]) {
    withConfiguredModel(blank, () => {
      assertEquals(finalPreviewModelConfigurationError(), null);
      assertEquals(resolveFinalPreviewModel(), "gemini-3.1-flash-image");
    });
  }
});

Deno.test("the correct variable resolves to the locked model", () => {
  withConfiguredModel("gemini-3.1-flash-image", () => {
    assertEquals(finalPreviewModelConfigurationError(), null);
    assertEquals(resolveFinalPreviewModel(), "gemini-3.1-flash-image");
  });
  // Surrounding whitespace is a formatting artefact, not a different model.
  withConfiguredModel("  gemini-3.1-flash-image  ", () => {
    assertEquals(resolveFinalPreviewModel(), "gemini-3.1-flash-image");
  });
});

Deno.test("the Pro model is rejected rather than obeyed", () => {
  withConfiguredModel("gemini-3-pro-image", () => {
    assertEquals(finalPreviewModelConfigurationError() !== null, true);
    assertThrows(() => resolveFinalPreviewModel(), Error, "misconfigured");
  });
});

Deno.test("any other model is rejected", () => {
  for (
    const other of [
      "gemini-2.0-flash",
      "some-other-model",
      "gemini-3.1-flash-image-preview",
      "GEMINI-3.1-FLASH-IMAGE",
    ]
  ) {
    withConfiguredModel(other, () => {
      assertEquals(
        finalPreviewModelConfigurationError() !== null,
        true,
        `${other} must be refused`,
      );
      assertThrows(() => resolveFinalPreviewModel(), Error);
    });
  }
});

Deno.test("the error names the expected model but never echoes the configured one", () => {
  withConfiguredModel("some-secret-looking-value", () => {
    const message = finalPreviewModelConfigurationError()!;
    assertEquals(message.includes("gemini-3.1-flash-image"), true);
    assertEquals(
      message.includes("some-secret-looking-value"),
      false,
      "a misconfigured value must not be readable back out of a response",
    );
  });
});
