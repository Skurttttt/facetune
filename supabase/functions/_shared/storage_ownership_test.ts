import { assertEquals } from "jsr:@std/assert@1";

import {
  isOwnedOriginalPath,
  isOwnedTutorialResultPath,
} from "./storage_ownership.ts";

const user = "11111111-1111-4111-8111-111111111111";
const analysis = "22222222-2222-4222-8222-222222222222";
const image = "33333333-3333-4333-8333-333333333333";
const session = "55555555-5555-4555-8555-555555555555";

Deno.test("accepts the exact owner-scoped original path", () => {
  assertEquals(
    isOwnedOriginalPath(
      `${user}/analyses/${analysis}/original/${image}.jpg`,
      user,
      analysis,
    ),
    true,
  );
});

Deno.test("rejects traversal that escapes the owner prefix", () => {
  assertEquals(
    isOwnedOriginalPath(
      `${user}/analyses/${analysis}/original/../../../other/${image}.jpg`,
      user,
      analysis,
    ),
    false,
  );
});

Deno.test("rejects another account's original", () => {
  assertEquals(
    isOwnedOriginalPath(
      `44444444-4444-4444-8444-444444444444/analyses/${analysis}/original/${image}.jpg`,
      user,
      analysis,
    ),
    false,
  );
});

Deno.test("rejects a generated preview supplied as an original", () => {
  assertEquals(
    isOwnedOriginalPath(
      `${user}/analyses/${analysis}/generated/${image}.jpg`,
      user,
      analysis,
    ),
    false,
  );
});

Deno.test("rejects an unexpected extension unless allowed", () => {
  assertEquals(
    isOwnedOriginalPath(
      `${user}/analyses/${analysis}/original/${image}.png`,
      user,
      analysis,
    ),
    false,
  );
  assertEquals(
    isOwnedOriginalPath(
      `${user}/analyses/${analysis}/original/${image}.png`,
      user,
      analysis,
      ["jpg", "png"],
    ),
    true,
  );
});

Deno.test("accepts the exact owner-scoped tutorial step result path", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/${session}/step_0004_result.png`,
      user,
      analysis,
      session,
    ),
    true,
  );
});

Deno.test("rejects traversal in a tutorial step result path", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/../../../other/step_0004_result.png`,
      user,
      analysis,
      session,
    ),
    false,
  );
});

Deno.test("rejects a tutorial step result path for a different session", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/66666666-6666-4666-8666-666666666666/step_0004_result.png`,
      user,
      analysis,
      session,
    ),
    false,
  );
});

Deno.test("rejects a tutorial step result path missing the step_ prefix", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/${session}/result_0004.png`,
      user,
      analysis,
      session,
    ),
    false,
  );
});

Deno.test("rejects a tutorial step result path with a malformed step number", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/${session}/step_4_result.png`,
      user,
      analysis,
      session,
    ),
    false,
  );
});

Deno.test("rejects an unexpected extension on a tutorial step result path unless allowed", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/${session}/step_0004_result.gif`,
      user,
      analysis,
      session,
    ),
    false,
  );
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/tutorials/${session}/step_0004_result.gif`,
      user,
      analysis,
      session,
      ["gif"],
    ),
    true,
  );
});

Deno.test("rejects an original selfie path supplied as a tutorial step result", () => {
  assertEquals(
    isOwnedTutorialResultPath(
      `${user}/analyses/${analysis}/original/${image}.jpg`,
      user,
      analysis,
      session,
    ),
    false,
  );
});
