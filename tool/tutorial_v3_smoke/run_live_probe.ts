/**
 * V3-6A.1 — live four-category guideline smoke probe.
 *
 * Drives the temporary `tutorial-v3-guideline-smoke-probe` Edge Function,
 * which holds the server-side `GEMINI_API_KEY`. Saves every generated image
 * locally for visual evaluation.
 *
 * Run:
 *   PROBE_URL=... SMOKE_TOKEN=... npx -y deno@2 run \
 *     --allow-env --allow-net --allow-read --allow-write \
 *     tool/tutorial_v3_smoke/run_live_probe.ts [--variant=1] [--only=blush]
 *
 * Neither the smoke token nor the API key is ever printed or written to disk.
 */

import { GATE_STEP_SPECS, standInCanonicalPreviewPrompt } from "./fixtures.ts";
import {
  COLOUR_TRANSFER_NOTE,
  IMAGE_ONE_ADJACENT_NOTE,
  IMAGE_TWO_ADJACENT_NOTE,
  NON_PHOTOGRAPHIC_NOTE,
  GUIDELINE_PROMPT_VERSION,
  type GuidelineSpec,
  tutorialV3GuidelinePrompt,
} from "./guideline_prompt.ts";

const OUT_DIR = "build/tutorial_v3_gate";
const BASE_IMAGE = "assets/images/beauty_portrait.png";

type Part = { text: string } | {
  inlineData: { mimeType: string; data: string };
};

interface ProbeResult {
  ok: boolean;
  httpStatus?: number;
  elapsedMs?: number;
  model?: string;
  partKinds?: string[];
  finishReason?: string | null;
  blockReason?: string | null;
  mimeType?: string;
  data?: string;
  text?: string;
  detail?: string;
  error?: string;
}

function argOf(name: string, fallback: string): string {
  const hit = Deno.args.find((arg) => arg.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

function encodeBase64(bytes: Uint8Array): string {
  const chunk = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunk));
  }
  return btoa(binary);
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (c) => c.charCodeAt(0));
}

function extensionFor(mimeType: string): string {
  return mimeType === "image/png"
    ? "png"
    : mimeType === "image/webp"
    ? "webp"
    : "jpg";
}

/** Mirrors the production `validateGeneratedImage` rules. */
function validate(bytes: Uint8Array, mimeType: string): string[] {
  const problems: string[] = [];
  if (!["image/png", "image/jpeg", "image/webp"].includes(mimeType)) {
    problems.push(`unsupported mime ${mimeType}`);
  }
  if (bytes.length < 10 * 1024) problems.push(`too small (${bytes.length}B)`);
  if (bytes.length > 10 * 1024 * 1024) {
    problems.push(`too large (${bytes.length}B)`);
  }
  const ok = mimeType === "image/png"
    ? bytes[0] === 0x89 && bytes[1] === 0x50
    : mimeType === "image/jpeg"
    ? bytes[0] === 0xff && bytes[1] === 0xd8
    : String.fromCharCode(...bytes.slice(0, 4)) === "RIFF";
  if (!ok) problems.push("magic bytes do not match mime");
  return problems;
}

async function callProbe(
  url: string,
  token: string,
  parts: Part[],
): Promise<ProbeResult> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-tutorial-v3-smoke-token": token,
    },
    body: JSON.stringify({ parts }),
    signal: AbortSignal.timeout(180000),
  });
  if (!response.ok) {
    const detail = (await response.text().catch(() => "")).slice(0, 300);
    return { ok: false, httpStatus: response.status, detail };
  }
  return await response.json() as ProbeResult;
}

/**
 * Builds the ordered parts for one guideline call.
 *
 * Variant 1 — roles stated once, in the preamble.
 * Variant 2 — role notes moved adjacent to each image, overlays reframed as a
 *             non-photographic diagram layer.
 * Variant 3 — variant 2 plus an explicit colour-transfer ban.
 */
function buildParts(
  spec: GuidelineSpec,
  variant: number,
  base: { mimeType: string; data: string },
  target: { mimeType: string; data: string },
): Part[] {
  const prompt = tutorialV3GuidelinePrompt(spec);
  if (variant === 1) {
    return [
      { text: prompt },
      { inlineData: base },
      { inlineData: target },
    ];
  }

  const closing: string[] = [NON_PHOTOGRAPHIC_NOTE];
  if (variant >= 3) closing.push(COLOUR_TRANSFER_NOTE);

  return [
    { text: prompt },
    { text: IMAGE_ONE_ADJACENT_NOTE },
    { inlineData: base },
    { text: IMAGE_TWO_ADJACENT_NOTE },
    { inlineData: target },
    { text: closing.join("\n\n") },
  ];
}

async function main(): Promise<void> {
  const url = Deno.env.get("PROBE_URL")?.trim();
  const token = Deno.env.get("SMOKE_TOKEN")?.trim();
  if (!url || !token) {
    console.error("PROBE_URL and SMOKE_TOKEN must both be set.");
    Deno.exit(2);
  }

  const variant = Number(argOf("variant", "1"));
  const only = argOf("only", "");
  await Deno.mkdir(OUT_DIR, { recursive: true });

  console.log(`prompt version = ${GUIDELINE_PROMPT_VERSION}`);
  console.log(`variant        = ${variant}`);

  const baseBytes = await Deno.readFile(BASE_IMAGE);
  const base = { mimeType: "image/png", data: encodeBase64(baseBytes) };
  await Deno.writeFile(`${OUT_DIR}/original.png`, baseBytes);
  console.log(`IMAGE 1        = ${BASE_IMAGE} (${baseBytes.length}B)`);

  // --- IMAGE 2: canonical Soft Glam target, generated once and reused -------
  const targetPath = `${OUT_DIR}/canonical_target.png`;
  let target: { mimeType: string; data: string };
  let existing: Uint8Array | null = null;
  try {
    existing = await Deno.readFile(targetPath);
  } catch {
    existing = null;
  }

  if (existing) {
    console.log(`IMAGE 2        = ${targetPath} (cached, ${existing.length}B)`);
    target = { mimeType: "image/png", data: encodeBase64(existing) };
  } else {
    console.log("IMAGE 2        = generating canonical Soft Glam target…");
    const result = await callProbe(url, token, [
      { text: standInCanonicalPreviewPrompt() },
      { inlineData: base },
    ]);
    if (!result.ok || !result.data || !result.mimeType) {
      console.error(
        `  canonical generation FAILED status=${result.httpStatus} ` +
          `parts=[${(result.partKinds ?? []).join(",")}] ` +
          `finish=${result.finishReason ?? "-"} block=${result.blockReason ?? "-"}`,
      );
      if (result.detail) console.error(`  detail: ${result.detail}`);
      if (result.text) console.error(`  text: ${result.text.slice(0, 300)}`);
      Deno.exit(3);
    }
    const bytes = decodeBase64(result.data);
    await Deno.writeFile(targetPath, bytes);
    target = { mimeType: result.mimeType, data: result.data };
    console.log(
      `  wrote ${targetPath} (${bytes.length}B, ${result.mimeType}, ${result.elapsedMs}ms)`,
    );
  }

  // --- Four guideline calls ------------------------------------------------
  const specs = only
    ? GATE_STEP_SPECS.filter((spec) => spec.category === only)
    : GATE_STEP_SPECS;
  const metadata: Record<string, unknown>[] = [];

  for (const spec of specs) {
    console.log(`\n--- ${spec.category} (variant ${variant}) ---`);
    const parts = buildParts(spec, variant, base, target);
    await Deno.writeTextFile(
      `${OUT_DIR}/${spec.category}_v${variant}_prompt.txt`,
      parts.filter((p): p is { text: string } => "text" in p)
        .map((p) => p.text).join("\n\n----- [image part here] -----\n\n"),
    );

    const result = await callProbe(url, token, parts);
    if (!result.ok || !result.data || !result.mimeType) {
      console.error(
        `  NO IMAGE status=${result.httpStatus} ` +
          `parts=[${(result.partKinds ?? []).join(",")}] ` +
          `finish=${result.finishReason ?? "-"} block=${result.blockReason ?? "-"}`,
      );
      if (result.text) console.error(`  text: ${result.text.slice(0, 300)}`);
      if (result.detail) console.error(`  detail: ${result.detail}`);
      metadata.push({ category: spec.category, variant, ...stripData(result) });
      continue;
    }

    const bytes = decodeBase64(result.data);
    const problems = validate(bytes, result.mimeType);
    const file =
      `${OUT_DIR}/${spec.category}_v${variant}_guideline.${extensionFor(result.mimeType)}`;
    await Deno.writeFile(file, bytes);
    console.log(
      `  image OK ${bytes.length}B ${result.mimeType} ${result.elapsedMs}ms ` +
        `parts=[${(result.partKinds ?? []).join(",")}]`,
    );
    if (problems.length > 0) console.error(`  VALIDATION: ${problems.join("; ")}`);
    console.log(`  wrote ${file}`);
    metadata.push({
      category: spec.category,
      variant,
      file,
      bytes: bytes.length,
      validationProblems: problems,
      ...stripData(result),
    });
  }

  await Deno.writeTextFile(
    `${OUT_DIR}/response_metadata_v${variant}.json`,
    JSON.stringify(
      { promptVersion: GUIDELINE_PROMPT_VERSION, variant, metadata },
      null,
      2,
    ),
  );
  console.log(`\nEvidence in ${OUT_DIR}/`);
}

/** Drops the base64 payload so no image data lands in metadata. */
function stripData(result: ProbeResult): Record<string, unknown> {
  const { data: _data, ...rest } = result;
  return rest as Record<string, unknown>;
}

if (import.meta.main) await main();
