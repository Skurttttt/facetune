/**
 * CCP-10 — the simulated provider for dry runs. It never touches the network.
 *
 * It answers each request kind in the real wire format, so the real clients and
 * parsers run. The simulated validator judges what the simulated image actually
 * "rendered": each image carries a sequence number, and the palette it was asked
 * for is remembered against that number. A probe that compares a preview with a
 * different palette is therefore genuinely flagged, not scripted to look flagged.
 */
import type { ProviderKind } from "./ccp10_guards.ts";

export type DryScenario = "mixed" | "terminal_streak" | "provider_errors";

export type DryBehavior =
  | "clean"
  /** First attempt comes out wrong; the corrected attempt is right. */
  | "retry"
  /** Both attempts come out wrong. */
  | "terminal"
  /** The first image request fails with a 500. */
  | "provider_failure"
  /** Right color; the validator cannot judge the finish. */
  | "not_judgeable";

interface Rendered {
  entries: Array<{ category: string; colorHex: string; finish: string }>;
  wrong: boolean;
}

const MANIFEST_CATEGORIES = [
  "foundation",
  "concealer",
  "contour_bronzer",
  "blush",
  "highlighter",
  "eyebrows",
  "eyeshadow",
  "eyeliner",
  "lips",
];

function textEnvelope(text: string): Response {
  return Response.json({ candidates: [{ content: { parts: [{ text }] } }] });
}

function base64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

/** A file with a PNG signature, large enough to pass the guideline size check. */
function imageBytes(sequence: number): Uint8Array {
  const bytes = new Uint8Array(11 * 1024);
  bytes.set([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  new DataView(bytes.buffer).setUint32(16, sequence);
  return bytes;
}

function sequenceOf(data: string): number {
  const bytes = Uint8Array.from(
    atob(data.slice(0, 32)),
    (c) => c.charCodeAt(0),
  );
  return new DataView(bytes.buffer).getUint32(16);
}

function imageEnvelope(sequence: number): Response {
  return Response.json({
    candidates: [{
      content: {
        parts: [{
          inlineData: {
            data: base64(imageBytes(sequence)),
            mimeType: "image/png",
          },
        }],
      },
    }],
  });
}

function afterMarker<T>(prompt: string, marker: string): T {
  const start = prompt.lastIndexOf(marker) + marker.length;
  return JSON.parse(prompt.slice(start).split("\n")[0]) as T;
}

export class DryProvider {
  private sequence = 0;
  private readonly rendered = new Map<number, Rendered>();
  private firstImageOfCase = true;
  behavior: DryBehavior = "clean";

  constructor(readonly scenario: DryScenario) {}

  startCase(behavior: DryBehavior): void {
    this.firstImageOfCase = true;
    this.behavior = this.scenario === "terminal_streak" ? "terminal" : behavior;
  }

  answer(kind: ProviderKind, body: string): Response {
    if (this.scenario === "provider_errors") {
      return new Response("{}", { status: 503 });
    }
    const request = JSON.parse(body) as {
      contents: Array<{
        parts: Array<{ text?: string; inlineData?: { data: string } }>;
      }>;
    };
    const parts = request.contents[0].parts;
    const prompt = parts[0].text ?? "";
    switch (kind) {
      case "analysis":
        return textEnvelope(JSON.stringify({
          imageValid: true,
          validation: {
            faceCount: 1,
            lightingAcceptable: true,
            sharpnessAcceptable: true,
            faceVisible: true,
            framingAcceptable: true,
          },
          analysis: {
            faceShape: "oval",
            skinTone: "medium",
            undertone: "warm",
            eyeShape: "almond",
            lipShape: "full",
            hairColor: "dark_brown",
            eyeColor: "brown",
          },
          confidence: {
            faceShape: 0.9,
            skinTone: 0.9,
            undertone: 0.9,
            eyeShape: 0.9,
            lipShape: 0.9,
            hairColor: 0.9,
            eyeColor: 0.9,
          },
        }));
      case "recommendation":
        return this.plan(prompt);
      case "image":
        return this.image(prompt);
      case "validator":
        return this.validate(prompt, parts);
      case "manifest":
        return textEnvelope(JSON.stringify(Object.fromEntries(
          MANIFEST_CATEGORIES.map((category) => [category, {
            // Selected categories judged absent still become steps; a visible
            // unselected one still does not.
            presence: category === "foundation" ? "present" : "absent",
            visualConfidence: 0.9,
          }]),
        )));
      case "guideline":
        this.sequence += 1;
        return imageEnvelope(this.sequence);
    }
  }

  private plan(prompt: string): Response {
    const palette = afterMarker<Array<{ categoryCode: string }>>(
      prompt,
      "Fixed palette: ",
    );
    return textEnvelope(JSON.stringify({
      applications: palette.map(({ categoryCode }) => ({
        categoryCode,
        placement: "Along the natural contour of the feature.",
        technique: "Blend outward in light layers.",
        intensity: "medium",
        reasoning: "This suits the selected style.",
      })),
      overallIntensity: "soft",
      summary: "A balanced look that follows your chosen color.",
    }));
  }

  private image(prompt: string): Response {
    const first = this.firstImageOfCase;
    this.firstImageOfCase = false;
    if (this.behavior === "provider_failure" && first) {
      return new Response("{}", { status: 500 });
    }
    const palette = afterMarker<
      Array<{ category: string; colorHex: string; finish: string }>
    >(prompt, "Fixed palette: ");
    this.sequence += 1;
    this.rendered.set(this.sequence, {
      entries: palette,
      wrong: this.behavior === "terminal" ||
        (this.behavior === "retry" && first),
    });
    return imageEnvelope(this.sequence);
  }

  private validate(
    prompt: string,
    parts: Array<{ text?: string; inlineData?: { data: string } }>,
  ): Response {
    const listed = afterMarker<
      Array<{ categoryCode: string; colorHex: string; finish: string }>
    >(prompt, "Listed palette: ");
    const candidate = parts.filter((part) => part.inlineData).at(-1)!;
    const rendered = this.rendered.get(sequenceOf(candidate.inlineData!.data));
    const entries = rendered?.entries ?? [];
    const categories = listed.map((entry) => {
      const seen = entries.find((e) => e.category === entry.categoryCode);
      const base = {
        categoryCode: entry.categoryCode,
        featureVisibleInOriginal: true,
      };
      if (!seen) {
        return {
          ...base,
          presence: "absent",
          color: "not_applicable",
          colorReason: "none",
          finish: "not_applicable",
          finishReason: "none",
        };
      }
      const faithful = seen.colorHex === entry.colorHex && !rendered?.wrong;
      return {
        ...base,
        presence: "present",
        color: faithful ? "consistent" : "different",
        colorReason: faithful ? "none" : "hue_differs",
        finish: this.behavior === "not_judgeable"
          ? "not_judgeable"
          : "consistent",
        finishReason: "none",
      };
    });
    return textEnvelope(JSON.stringify({
      categories,
      introducedCategories: entries
        .map((entry) => entry.category)
        .filter((c) => !listed.some((entry) => entry.categoryCode === c)),
      identity: "preserved",
    }));
  }
}

/**
 * The behaviors the mixed scenario exercises. Cases other cases depend on stay
 * clean, because a dry run proves the harness rather than producing rates.
 */
export function mixedBehavior(
  caseId: string,
  index: number,
  protectedIds: ReadonlySet<string>,
): DryBehavior {
  if (protectedIds.has(caseId)) return "clean";
  if (index % 11 === 5) return "terminal";
  if (index % 7 === 3) return "retry";
  if (index % 13 === 6) return "provider_failure";
  if (index % 5 === 4) return "not_judgeable";
  return "clean";
}
