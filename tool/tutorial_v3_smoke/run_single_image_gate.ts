/**
 * V3-6A.2 — single-image renderer gate runner.
 *
 * Sends ONE image (the original selfie) plus the minimum sufficient Step Spec.
 * The canonical final preview is not loaded, not referenced, and not sendable:
 * the probe's request shape has no field for a second image.
 *
 * Run:
 *   PROBE_URL=... ANON_JWT=... PROBE_TOKEN=... npx -y deno@2 run \
 *     --allow-env --allow-net --allow-read --allow-write \
 *     tool/tutorial_v3_smoke/run_single_image_gate.ts [--variant=1] [--only=blush]
 *
 * No credential is printed or written to disk.
 */

import { SINGLE_IMAGE_SPECS } from "./single_image_fixtures.ts";
import {
  SINGLE_IMAGE_PROMPT_VERSION,
  type RendererSpec,
  singleImageGuidelinePrompt,
} from "./single_image_prompt.ts";

const OUT_DIR = "build/tutorial_v3_gate_single_image";
const BASE_IMAGE = "assets/images/beauty_portrait.png";

/** Variant 2/3 reinforcement, appended only when a variant needs it. */
const DIAGRAM_LAYER_NOTE = [
  "REMINDER — THIS IS A DIAGRAM, NOT A MAKEOVER.",
  "Imagine the photograph is printed on paper and you are drawing on it with a",
  "translucent marker. The paper underneath does not change at all.",
  "If the person's skin, eyes, lips or cheeks look even slightly different from",
  "the photograph once your marks are removed, the output is wrong.",
].join("\n");

const GEOMETRY_NOTE = [
  "REMINDER — FOLLOW THE STATED GEOMETRY EXACTLY.",
  "The WHERE field describes the precise region. Do not shift it, do not",
  "recentre it, and do not merge separate regions into one.",
  "If the instruction says two separate regions, draw two separate regions with",
  "clearly untouched space between them.",
].join("\n");

/**
 * Variant 3 addition, written against observed v1/v2 failures rather than
 * guessed at:
 *  - v1 lips came back desaturated; v2 lips came back filled solid red.
 *  - v2 foundation lightened the skin several shades.
 * Both are the same underlying error — recolouring a facial surface instead of
 * annotating it — so this note attacks that directly.
 */
const NO_RECOLOUR_NOTE = [
  "REMINDER — NEVER RECOLOUR A FACIAL SURFACE.",
  "Do not fill, tint, lighten, darken, saturate or desaturate the skin, the",
  "lips, the eyelids or the cheeks. Not even slightly.",
  "The lips must keep their exact original colour: mark their BORDER and show",
  "direction, but leave the lip surface itself completely untouched. A filled-in",
  "lip is wrong, and a paled or greyed lip is equally wrong.",
  "A coverage region must be a faint neutral wash that the real skin tone still",
  "shows through unchanged. If the skin under your region looks lighter, darker",
  "or smoother than the surrounding skin, the output is wrong.",
  "Outline and annotate. Never paint.",
].join("\n");

interface ProbeResult {
  ok: boolean;
  httpStatus?: number;
  elapsedMs?: number;
  model?: string;
  imagePartCount?: number;
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
  return Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
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
  if (bytes.length > 10 * 1024 * 1024) problems.push(`too large (${bytes.length}B)`);
  const ok = mimeType === "image/png"
    ? bytes[0] === 0x89 && bytes[1] === 0x50
    : mimeType === "image/jpeg"
    ? bytes[0] === 0xff && bytes[1] === 0xd8
    : String.fromCharCode(...bytes.slice(0, 4)) === "RIFF";
  if (!ok) problems.push("magic bytes do not match mime");
  return problems;
}

/** Builds the prompt for a variant. Never adds an image. */
export function promptForVariant(spec: RendererSpec, variant: number): string {
  const base = singleImageGuidelinePrompt(spec);
  if (variant === 1) return base;
  const extras = [DIAGRAM_LAYER_NOTE];
  if (variant >= 3) extras.push(NO_RECOLOUR_NOTE, GEOMETRY_NOTE);
  return [base, "", ...extras].join("\n");
}

async function callProbe(
  url: string,
  jwt: string,
  token: string,
  prompt: string,
  image: { mimeType: string; data: string },
): Promise<ProbeResult> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      // Platform gateway credential (JWT verification stays ON).
      "authorization": `Bearer ${jwt}`,
      "apikey": jwt,
      // Second factor: ephemeral, compiled into the probe at deploy time.
      "x-tutorial-v3-probe-token": token,
    },
    // Note the shape: a single `image`, never an array. There is no field
    // through which a canonical preview could be sent.
    body: JSON.stringify({ prompt, image }),
    signal: AbortSignal.timeout(180000),
  });
  if (!response.ok) {
    const detail = (await response.text().catch(() => "")).slice(0, 300);
    return { ok: false, httpStatus: response.status, detail };
  }
  return await response.json() as ProbeResult;
}

async function main(): Promise<void> {
  const url = Deno.env.get("PROBE_URL")?.trim();
  const jwt = Deno.env.get("ANON_JWT")?.trim();
  const token = Deno.env.get("PROBE_TOKEN")?.trim();
  if (!url || !jwt || !token) {
    console.error("PROBE_URL, ANON_JWT and PROBE_TOKEN must all be set.");
    Deno.exit(2);
  }

  const variant = Number(argOf("variant", "1"));
  const only = argOf("only", "");
  await Deno.mkdir(OUT_DIR, { recursive: true });

  console.log(`prompt version = ${SINGLE_IMAGE_PROMPT_VERSION}`);
  console.log(`variant        = ${variant}`);

  const baseBytes = await Deno.readFile(BASE_IMAGE);
  await Deno.writeFile(`${OUT_DIR}/original.png`, baseBytes);
  const image = { mimeType: "image/png", data: encodeBase64(baseBytes) };
  console.log(`image (only)   = ${BASE_IMAGE} (${baseBytes.length}B)`);
  console.log("canonical preview = NOT SENT (single-image architecture)");

  const specs = only
    ? SINGLE_IMAGE_SPECS.filter((spec) => spec.category === only)
    : SINGLE_IMAGE_SPECS;
  const metadata: Record<string, unknown>[] = [];

  for (const spec of specs) {
    console.log(`\n--- ${spec.category} (variant ${variant}) ---`);
    const prompt = promptForVariant(spec, variant);
    await Deno.writeTextFile(
      `${OUT_DIR}/${spec.category}_v${variant}_prompt.txt`,
      prompt,
    );

    const result = await callProbe(url, jwt, token, prompt, image);
    if (!result.ok || !result.data || !result.mimeType) {
      console.error(
        `  NO IMAGE status=${result.httpStatus} ` +
          `parts=[${(result.partKinds ?? []).join(",")}] ` +
          `finish=${result.finishReason ?? "-"} block=${result.blockReason ?? "-"}`,
      );
      if (result.detail) console.error(`  detail: ${result.detail}`);
      if (result.text) console.error(`  text: ${result.text.slice(0, 300)}`);
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
        `imageParts=${result.imagePartCount}`,
    );
    if (problems.length > 0) console.error(`  VALIDATION: ${problems.join("; ")}`);
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
      {
        promptVersion: SINGLE_IMAGE_PROMPT_VERSION,
        variant,
        architecture: "single-image; canonical preview not sent to renderer",
        metadata,
      },
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
