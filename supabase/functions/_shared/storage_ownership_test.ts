import { assertEquals } from "jsr:@std/assert@1";

import { isOwnedOriginalPath } from "./storage_ownership.ts";

const user = "11111111-1111-4111-8111-111111111111";
const analysis = "22222222-2222-4222-8222-222222222222";
const image = "33333333-3333-4333-8333-333333333333";

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
