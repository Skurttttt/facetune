/**
 * V3-6A — two-reference behavioural smoke gate runner.
 *
 * Sends the ORIGINAL SELFIE and the CANONICAL FINAL PREVIEW as two inline
 * images, plus one persisted-shaped Step Spec, and writes whatever the model
 * returns to disk for human visual evaluation.
 *
 * This produces EVIDENCE, not a verdict. A successful run proves the request
 * shape works and yields image bytes; it does not prove the overlays are
 * correct. Only a person looking at the four output images can classify the
 * gate (§15).
 *
 * Run:
 *   GEMINI_API_KEY=... npx -y deno@2 run --allow-env --allow-net --allow-read \
 *     --allow-write tool/tutorial_v3_smoke/run_gate.ts
 *
 * The key is read from the environment and never logged or written to disk.
 */

import { GATE_STEP_SPECS, standInCanonicalPreviewPrompt } from "./fixtures.ts";
import {
  GUIDELINE_PROMPT_VERSION,
  tutorialV3GuidelinePrompt,
} from "./guideline_prompt.ts";

const DEFAULT_BASE = "assets/images/beauty_portrait.png";
const DEFAULT_OUT = "build/tutorial_v3_gate";

/** V3 has its own variable. GEMINI_IMAGE_MODEL is deliberately not consulted. */
const MODEL = Deno.env.get("TUTORIAL_V3_GUIDELINE_MODEL")?.trim() ||
  "gemini-3.1-flash-image";

const ENDPOINT = (model: string) =>
  `https://generativelanguage.googleapis.com/v1/models/${
    encodeURIComponent(model)
  }:generateContent`;

interface ImagePayload {
  bytes: Uint8Array;
  mimeType: string;
}

function argOf(name: string, fallback: string): string {
  const prefix = `--${name}=`;
  const hit = Deno.args.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function encodeBase64(bytes: Uint8Array): string {
  const chunk = 0x8000;
  let binary = "";
  for (let offset = 0; offset < bytes.length; offset += chunk) {
    binary += String.fromCharCode(...bytes.subarray(offset, offset + chunk));
  }
  return btoa(binary);
}

function mimeFor(path: string): string {
  const extension = path.slice(path.lastIndexOf(".") + 1).toLowerCase();
  if (extension === "png") return "image/png";
  if (extension === "webp") return "image/webp";
  return "image/jpeg";
}

/** Mirrors the production `validateGeneratedImage` rules. */
function validateImage(data: unknown, mimeType: unknown): ImagePayload {
  if (
    typeof data !== "string" || data.length === 0 ||
    (mimeType !== "image/png" && mimeType !== "image/jpeg" &&
      mimeType !== "image/webp")
  ) {
    throw new Error(`invalid_generated_image mime=${String(mimeType)}`);
  }
  const binary = atob(data);
  const bytes = Uint8Array.from(binary, (c) => c.charCodeAt(0));
  if (bytes.length < 10 * 1024) {
    throw new Error(`image_too_small bytes=${bytes.length}`);
  }
  if (bytes.length > 10 * 1024 * 1024) {
    throw new Error(`image_too_large bytes=${bytes.length}`);
  }
  const signatureOk = mimeType === "image/png"
    ? bytes[0] === 0x89 && bytes[1] === 0x50
    : mimeType === "image/jpeg"
    ? bytes[0] === 0xff && bytes[1] === 0xd8
    : String.fromCharCode(...bytes.slice(0, 4)) === "RIFF";
  if (!signatureOk) throw new Error(`signature_mismatch mime=${mimeType}`);
  return { bytes, mimeType };
}

interface CallOutcome {
  image?: ImagePayload;
  textOnly?: string;
  blockReason?: string;
  finishReason?: string;
  httpStatus: number;
  partKinds: string[];
}

async function callModel(
  apiKey: string,
  parts: unknown[],
): Promise<CallOutcome> {
  const response = await fetch(ENDPOINT(MODEL), {
    method: "POST",
    headers: { "content-type": "application/json", "x-goog-api-key": apiKey },
    body: JSON.stringify({ contents: [{ role: "user", parts }] }),
    signal: AbortSignal.timeout(120000),
  });

  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    return {
      httpStatus: response.status,
      partKinds: [],
      textOnly: detail.replace(/\s+/g, " ").slice(0, 400),
    };
  }

  const payload = await response.json() as {
    candidates?: Array<{
      content?: {
        parts?: Array<
          { text?: string; inlineData?: { data?: unknown; mimeType?: unknown } }
        >;
      };
      finishReason?: string;
    }>;
    promptFeedback?: { blockReason?: string };
  };

  const candidate = payload.candidates?.[0];
  const candidateParts = candidate?.content?.parts ?? [];
  const partKinds = candidateParts.map((part) =>
    part.inlineData?.data ? "inlineData" : part.text ? "text" : "unknown"
  );

  const imagePart = candidateParts.find((part) => part.inlineData?.data);
  if (imagePart?.inlineData) {
    return {
      httpStatus: response.status,
      partKinds,
      image: validateImage(
        imagePart.inlineData.data,
        imagePart.inlineData.mimeType,
      ),
    };
  }

  return {
    httpStatus: response.status,
    partKinds,
    textOnly: candidateParts.map((p) => p.text ?? "").join("").slice(0, 400),
    blockReason: payload.promptFeedback?.blockReason,
    finishReason: candidate?.finishReason,
  };
}

async function main(): Promise<void> {
  const apiKey = Deno.env.get("GEMINI_API_KEY")?.trim();
  if (!apiKey) {
    console.error(
      "GEMINI_API_KEY is not set. This gate needs a live call — it cannot be\n" +
        "satisfied offline. Set the key in your shell and re-run.",
    );
    Deno.exit(2);
  }

  const basePath = argOf("base", DEFAULT_BASE);
  const targetPath = argOf("target", "");
  const outDir = argOf("out", DEFAULT_OUT);
  await Deno.mkdir(outDir, { recursive: true });

  console.log(`model            = ${MODEL}`);
  console.log(`prompt version   = ${GUIDELINE_PROMPT_VERSION}`);
  console.log(`base (IMAGE 1)   = ${basePath}`);

  const base: ImagePayload = {
    bytes: await Deno.readFile(basePath),
    mimeType: mimeFor(basePath),
  };

  // --- IMAGE 2: the canonical final preview --------------------------------
  let target: ImagePayload;
  if (targetPath) {
    console.log(`target (IMAGE 2) = ${targetPath} (supplied)`);
    target = {
      bytes: await Deno.readFile(targetPath),
      mimeType: mimeFor(targetPath),
    };
  } else {
    console.log("target (IMAGE 2) = generating a stand-in canonical preview…");
    const outcome = await callModel(apiKey, [
      { text: standInCanonicalPreviewPrompt() },
      {
        inlineData: {
          mimeType: base.mimeType,
          data: encodeBase64(base.bytes),
        },
      },
    ]);
    if (!outcome.image) {
      console.error(
        `Could not synthesise a canonical preview: status=${outcome.httpStatus} ` +
          `parts=[${outcome.partKinds.join(",")}] ` +
          `block=${outcome.blockReason ?? "-"} detail=${outcome.textOnly ?? "-"}`,
      );
      console.error(
        "Supply a real canonical preview with --target=<path> and re-run.",
      );
      Deno.exit(3);
    }
    target = outcome.image;
    await Deno.writeFile(`${outDir}/00_canonical_target.png`, target.bytes);
    console.log(`  wrote ${outDir}/00_canonical_target.png`);
  }

  // --- The four guideline calls -------------------------------------------
  const summary: Record<string, unknown>[] = [];
  for (const spec of GATE_STEP_SPECS) {
    console.log(`\n--- ${spec.category} ---`);
    const prompt = tutorialV3GuidelinePrompt(spec);
    await Deno.writeTextFile(`${outDir}/${spec.category}_prompt.txt`, prompt);

    let outcome: CallOutcome;
    try {
      // Order is load-bearing: IMAGE 1 (base) first, IMAGE 2 (reference)
      // second, matching the roles the prompt assigns by position.
      outcome = await callModel(apiKey, [
        { text: prompt },
        {
          inlineData: {
            mimeType: base.mimeType,
            data: encodeBase64(base.bytes),
          },
        },
        {
          inlineData: {
            mimeType: target.mimeType,
            data: encodeBase64(target.bytes),
          },
        },
      ]);
    } catch (error) {
      console.error(`  FAILED: ${error instanceof Error ? error.message : error}`);
      summary.push({ category: spec.category, error: String(error) });
      continue;
    }

    if (outcome.image) {
      const file = `${outDir}/${spec.category}_guideline.png`;
      await Deno.writeFile(file, outcome.image.bytes);
      console.log(
        `  image OK  bytes=${outcome.image.bytes.length} ` +
          `mime=${outcome.image.mimeType} parts=[${outcome.partKinds.join(",")}]`,
      );
      console.log(`  wrote ${file}`);
      summary.push({
        category: spec.category,
        httpStatus: outcome.httpStatus,
        bytes: outcome.image.bytes.length,
        mimeType: outcome.image.mimeType,
        partKinds: outcome.partKinds,
        file,
      });
    } else {
      console.error(
        `  NO IMAGE  status=${outcome.httpStatus} ` +
          `parts=[${outcome.partKinds.join(",")}] ` +
          `finish=${outcome.finishReason ?? "-"} ` +
          `block=${outcome.blockReason ?? "-"}`,
      );
      if (outcome.textOnly) console.error(`  detail: ${outcome.textOnly}`);
      summary.push({
        category: spec.category,
        httpStatus: outcome.httpStatus,
        partKinds: outcome.partKinds,
        finishReason: outcome.finishReason,
        blockReason: outcome.blockReason,
        textOnly: outcome.textOnly,
      });
    }
  }

  await Deno.writeTextFile(
    `${outDir}/summary.json`,
    JSON.stringify(
      { model: MODEL, promptVersion: GUIDELINE_PROMPT_VERSION, summary },
      null,
      2,
    ),
  );

  console.log(`\nEvidence written to ${outDir}/`);
  console.log(
    [
      "",
      "Now evaluate each image BY EYE against the §14 criteria. Bytes are not a pass.",
      "  1. identity preserved — same person, same features, same skin",
      "  2. no finished makeup of any kind",
      "  3. only the current category is taught",
      "  4. overlays match WHERE / DIRECTION / TECHNIQUE in the Step Spec",
      "  5. overlays point at the right part of the canonical target",
      "  6. IMAGE 2 was NOT blended, copied or used as the face",
      "  7. no text, letters or numbers drawn in the image",
      "  8. a normal user could act on it",
      "",
      "Record the outcome in docs/tutorial_v3/V3-6A_GUIDELINE_BEHAVIOR_SMOKE_GATE.md.",
    ].join("\n"),
  );
}

if (import.meta.main) await main();
