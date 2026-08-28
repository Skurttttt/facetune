/**
 * V3-6R — geometry gate runner.
 *
 * Sends ONE image (the original selfie) plus one Step Spec, and saves the
 * returned geometry JSON. No canonical preview, no previous geometry, no
 * second image — the probe rejects any field that could carry one.
 *
 * Run:
 *   PROBE_URL=... ANON_JWT=... PROBE_TOKEN=... npx -y deno@2 run \
 *     --allow-env --allow-net --allow-read --allow-write \
 *     tool/tutorial_v3_smoke/run_geometry_gate.ts [--only=blush]
 */

import { CATEGORY_SPECS, DIFFERENTIAL_SPECS } from "./geometry_fixtures.ts";
import {
  GEOMETRY_PROMPT_VERSION,
  type GeometrySpec,
  geometryMapperPrompt,
} from "./geometry_prompt.ts";

const OUT_DIR = "build/tutorial_v3_geometry_gate";
const BASE_IMAGE = "assets/images/beauty_portrait.png";

interface ProbeResult {
  ok: boolean;
  httpStatus?: number;
  elapsedMs?: number;
  model?: string;
  imagePartCount?: number;
  imageParts?: number;
  finishReason?: string | null;
  blockReason?: string | null;
  geometryJson?: string;
  error?: string;
  detail?: string;
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
      authorization: `Bearer ${jwt}`,
      apikey: jwt,
      "x-tutorial-v3-probe-token": token,
    },
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

  const only = argOf("only", "");
  await Deno.mkdir(OUT_DIR, { recursive: true });

  const baseBytes = await Deno.readFile(BASE_IMAGE);
  await Deno.writeFile(`${OUT_DIR}/original.png`, baseBytes);
  const image = { mimeType: "image/png", data: encodeBase64(baseBytes) };

  console.log(`prompt version = ${GEOMETRY_PROMPT_VERSION}`);
  console.log(`image (only)   = ${BASE_IMAGE} (${baseBytes.length}B)`);
  console.log("canonical preview = NOT SENT (geometry mapper takes one image)");

  const all: GeometrySpec[] = [...CATEGORY_SPECS, ...DIFFERENTIAL_SPECS];
  const specs = only ? all.filter((spec) => spec.id === only) : all;
  const metadata: Record<string, unknown>[] = [];

  for (const spec of specs) {
    const prompt = geometryMapperPrompt(spec);
    await Deno.writeTextFile(`${OUT_DIR}/${spec.id}_prompt.txt`, prompt);

    const result = await callProbe(url, jwt, token, prompt, image);
    if (!result.ok || !result.geometryJson) {
      console.error(
        `  ${spec.id}: NO GEOMETRY status=${result.httpStatus} ` +
          `error=${result.error ?? "-"} finish=${result.finishReason ?? "-"}`,
      );
      if (result.detail) console.error(`    detail: ${result.detail}`);
      metadata.push({ id: spec.id, category: spec.category, ok: false, ...strip(result) });
      continue;
    }

    await Deno.writeTextFile(
      `${OUT_DIR}/${spec.id}_geometry.json`,
      result.geometryJson,
    );

    // Shallow shape report only. Authoritative validation is the Dart
    // TutorialV3GeometryValidator, exercised by the Flutter render step.
    let primitiveCount = -1;
    let roles: string[] = [];
    try {
      const parsed = JSON.parse(result.geometryJson) as {
        primitives?: Array<{ kind?: string; role?: string }>;
      };
      primitiveCount = parsed.primitives?.length ?? -1;
      roles = [...new Set((parsed.primitives ?? []).map((p) => `${p.role}:${p.kind}`))];
    } catch {
      primitiveCount = -1;
    }

    console.log(
      `  ${spec.id}: OK ${result.elapsedMs}ms primitives=${primitiveCount} ` +
        `[${roles.join(" ")}]`,
    );
    metadata.push({
      id: spec.id,
      category: spec.category,
      ok: true,
      primitiveCount,
      roles,
      ...strip(result),
    });
  }

  await Deno.writeTextFile(
    `${OUT_DIR}/geometry_metadata.json`,
    JSON.stringify(
      {
        promptVersion: GEOMETRY_PROMPT_VERSION,
        architecture:
          "single image + step spec -> normalized geometry JSON; no canonical preview, no image output",
        metadata,
      },
      null,
      2,
    ),
  );
  console.log(`\nEvidence in ${OUT_DIR}/`);
}

/** Drops the geometry payload so metadata stays a summary. */
function strip(result: ProbeResult): Record<string, unknown> {
  const { geometryJson: _g, ...rest } = result;
  return rest as Record<string, unknown>;
}

if (import.meta.main) await main();
