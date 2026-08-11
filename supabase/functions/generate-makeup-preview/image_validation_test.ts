import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import { validateGeneratedImage } from "./image_validation.ts";

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

Deno.test("accepts a size-bounded PNG with a matching signature", () => {
  const bytes = new Uint8Array(11 * 1024);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  const result = validateGeneratedImage(base64(bytes), "image/png");
  assertEquals(result.bytes.length, bytes.length);
});

Deno.test("rejects a MIME and signature mismatch", () => {
  const bytes = new Uint8Array(11 * 1024);
  bytes.set([0xff, 0xd8]);
  assertThrows(() => validateGeneratedImage(base64(bytes), "image/png"));
});
