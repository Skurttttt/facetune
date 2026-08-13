import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  KIT_MAKEUP_PREVIEW_PROMPT_VERSION,
  kitMakeupPreviewPrompt,
} from "./prompt.ts";

Deno.test("uses isolated identity and exact registered-color rules", () => {
  const prompt = kitMakeupPreviewPrompt("soft_glam", {
    selections: [{
      productId: "11111111-1111-4111-8111-111111111111",
      category: "lipstick",
      colorHex: "#A45B67",
      finish: "matte",
      placement: "lips",
      technique: "thin even layer",
      intensity: "soft",
    }],
    overallIntensity: "soft",
  }, 2);

  assertEquals(KIT_MAKEUP_PREVIEW_PROMPT_VERSION, "kit_makeup_preview_v1");
  assertStringIncludes(prompt, "#A45B67");
  assertStringIncludes(prompt, "Do not replace a shade");
  assertStringIncludes(
    prompt,
    "Preserve the same person's recognizable identity",
  );
  assertStringIncludes(prompt, "variation 2");
});
