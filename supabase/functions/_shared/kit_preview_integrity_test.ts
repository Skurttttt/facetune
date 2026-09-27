import { assertRejects } from "jsr:@std/assert@1";

import {
  assertKitPreviewIntegrity,
  KitPreviewIntegrityError,
} from "./kit_preview_integrity.ts";

const bytes = new Uint8Array([1, 2, 3, 4]);

async function sha(value: Uint8Array): Promise<string> {
  const hash = new Uint8Array(
    await crypto.subtle.digest("SHA-256", new Uint8Array(value)),
  );
  return [...hash].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.test("the accepted bytes pass", async () => {
  await assertKitPreviewIntegrity(bytes, {
    plan_id: "plan",
    content_sha256: await sha(bytes),
  });
});

Deno.test("different bytes fail", async () => {
  await assertRejects(
    async () =>
      await assertKitPreviewIntegrity(new Uint8Array([1, 2, 3, 5]), {
        plan_id: "plan",
        content_sha256: await sha(bytes),
      }),
    KitPreviewIntegrityError,
  );
});

Deno.test("a plan-backed row without a usable hash fails closed", async () => {
  for (
    const content_sha256 of [null, "", "abc", (await sha(bytes)).toUpperCase()]
  ) {
    await assertRejects(
      () =>
        assertKitPreviewIntegrity(bytes, { plan_id: "plan", content_sha256 }),
      KitPreviewIntegrityError,
    );
  }
});

Deno.test("a legacy preview is not checked", async () => {
  await assertKitPreviewIntegrity(bytes, { plan_id: null });
  await assertKitPreviewIntegrity(bytes, {});
});
