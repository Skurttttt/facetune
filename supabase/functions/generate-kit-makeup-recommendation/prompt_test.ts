import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";

import {
  KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION,
  kitMakeupRecommendationPrompt,
} from "./prompt.ts";

Deno.test("uses an isolated versioned prompt with strict inventory rules", () => {
  assertEquals(
    KIT_MAKEUP_RECOMMENDATION_PROMPT_VERSION,
    "kit_makeup_recommendation_v2",
  );
  const prompt = kitMakeupRecommendationPrompt(
    { skinTone: "medium", undertone: "warm" },
    "soft_glam",
    [{
      id: "11111111-1111-4111-8111-111111111111",
      user_id: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",
      category: "lipstick",
      product_name: null,
      color_hex: "#B86F72",
      color_label: "Nude Rose",
      finish: "cream",
      foundation_depth: null,
      foundation_undertone: null,
    }],
  );
  assertStringIncludes(prompt, "ONLY products");
  assertStringIncludes(prompt, "only one product or one category");
  assertStringIncludes(prompt, "11111111-1111-4111-8111-111111111111");
  assertStringIncludes(prompt, '"colorHex":"#B86F72"');
  // Owner IDs are deliberately excluded from the model prompt.
  assertEquals(prompt.includes("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"), false);
});
