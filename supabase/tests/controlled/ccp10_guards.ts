/**
 * CCP-10 — the safety controls, kept apart from the runner so each is tested
 * directly: target and path checks, the persisted call budget, stop-loss, the
 * leak scan, and the human review gate.
 */
import { dirname, isAbsolute, resolve } from "jsr:@std/path@1";

export class GuardRefusal extends Error {
  constructor(message: string) {
    super(message);
    this.name = "GuardRefusal";
  }
}

// ---------------------------------------------------------------------------
// Database target
// ---------------------------------------------------------------------------

export function assertLoopbackDatabase(url: string): void {
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    throw new GuardRefusal("LOCAL_SUPABASE_URL is not a URL.");
  }
  // An exact host, so loopback-looking names such as 127.0.0.1.example.com fail.
  if (
    parsed.protocol !== "http:" ||
    !["127.0.0.1", "localhost", "[::1]"].includes(parsed.hostname) ||
    parsed.username !== "" || parsed.password !== ""
  ) {
    throw new GuardRefusal(
      "LOCAL_SUPABASE_URL must be loopback. Remote databases are refused.",
    );
  }
}

export function assertThrowawayContainer(name: string): void {
  if (!/^supabase_db_[a-z0-9_]*_?throwaway$/.test(name)) {
    throw new GuardRefusal(
      "LOCAL_DB_CONTAINER must name a throwaway Supabase database.",
    );
  }
}

// ---------------------------------------------------------------------------
// Everything private stays outside any repository
// ---------------------------------------------------------------------------

function exists(path: string): boolean {
  try {
    Deno.statSync(path);
    return true;
  } catch {
    return false;
  }
}

function realOrResolved(path: string): string {
  const absolute = resolve(path);
  try {
    return Deno.realPathSync(absolute);
  } catch {
    return absolute;
  }
}

/** The nearest ancestor that marks a project checkout, or null. */
export function repositoryContaining(path: string): string | null {
  let current = realOrResolved(path);
  while (true) {
    if (
      exists(`${current}/.git`) || exists(`${current}/pubspec.yaml`) ||
      exists(`${current}/supabase/config.toml`)
    ) {
      return current;
    }
    const parent = dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function isWithin(path: string, root: string): boolean {
  const child = realOrResolved(path).replaceAll("\\", "/").toLowerCase();
  const parent = realOrResolved(root).replaceAll("\\", "/").toLowerCase();
  return child === parent || child.startsWith(`${parent}/`);
}

/**
 * Refuses a path inside a checkout, or inside the tree the harness runs from
 * (which may be a scratch copy holding no repository marker).
 */
export function assertOutsideRepository(
  label: string,
  path: string,
  harnessRoot: string,
): void {
  if (!path || !isAbsolute(path)) {
    throw new GuardRefusal(`${label} must be an absolute path.`);
  }
  if (repositoryContaining(path) !== null || isWithin(path, harnessRoot)) {
    throw new GuardRefusal(`${label} must be outside the repository.`);
  }
}

// ---------------------------------------------------------------------------
// The provider call budget
// ---------------------------------------------------------------------------

export class CeilingReached extends Error {
  constructor() {
    super("provider call ceiling reached");
    this.name = "CeilingReached";
  }
}

export interface BudgetState {
  total: number;
  byKind: Record<string, number>;
}

/**
 * Counts every provider call and refuses the one that would cross a ceiling.
 *
 * The count is written to disk BEFORE the call is released, so a crash can never
 * hand back budget. The stage ceiling is cumulative, so Stage 2 includes Stage 1.
 */
export class CallBudget {
  private state: BudgetState;
  exhausted = false;

  constructor(
    private readonly path: string,
    readonly ceiling: number,
  ) {
    this.state = exists(path)
      ? JSON.parse(Deno.readTextFileSync(path)) as BudgetState
      : { total: 0, byKind: {} };
  }

  get total(): number {
    return this.state.total;
  }

  get byKind(): Readonly<Record<string, number>> {
    return this.state.byKind;
  }

  get remaining(): number {
    return this.ceiling - this.state.total;
  }

  charge(kind: string): void {
    if (this.state.total + 1 > this.ceiling) {
      this.exhausted = true;
      throw new CeilingReached();
    }
    this.state.total += 1;
    this.state.byKind[kind] = (this.state.byKind[kind] ?? 0) + 1;
    Deno.writeTextFileSync(this.path, JSON.stringify(this.state));
  }
}

// ---------------------------------------------------------------------------
// Provider request classification and the model lock
// ---------------------------------------------------------------------------

export type ProviderKind =
  | "analysis"
  | "recommendation"
  | "image"
  | "validator"
  | "manifest"
  | "guideline";

const IMAGE_MODEL = "gemini-3.1-flash-image";
const TEXT_MODEL = "gemini-3.6-flash";

/**
 * Names a request from its prompt and model, or refuses it. Unlike a catch-all, an
 * unknown request is an error: this harness must know everything it pays for.
 */
export function classifyProviderRequest(
  pathname: string,
  rawText: string,
): ProviderKind {
  const firstText = rawText.trimStart();
  const image = pathname.includes(`/models/${IMAGE_MODEL}:`);
  const text = pathname.includes(`/models/${TEXT_MODEL}:`);
  if (!image && !text) throw new GuardRefusal("Unapproved provider model.");
  if (image) {
    return firstText.startsWith("Edit the supplied selfie")
      ? "image"
      : "guideline";
  }
  if (firstText.startsWith("You are the secure selfie")) return "analysis";
  if (firstText.startsWith("You are FaceTune's brand-neutral")) {
    return "recommendation";
  }
  if (firstText.startsWith("You are checking")) return "validator";
  if (firstText.startsWith("You are comparing two photographs")) {
    return "manifest";
  }
  throw new GuardRefusal("Unrecognized provider request.");
}

/** The only hosts this process may reach. */
export function assertAllowedHost(hostname: string): void {
  if (
    hostname !== "generativelanguage.googleapis.com" &&
    hostname !== "127.0.0.1" && hostname !== "localhost" &&
    hostname !== "[::1]"
  ) {
    throw new GuardRefusal("Refused a request to an unapproved host.");
  }
}

// ---------------------------------------------------------------------------
// Stop-loss
// ---------------------------------------------------------------------------

export const CONSECUTIVE_TERMINAL_LIMIT = 5;
export const CONSECUTIVE_PROVIDER_ERROR_LIMIT = 3;

export class StopLoss {
  private terminalStreak = 0;
  private providerErrorStreak = 0;
  reason: string | null = null;

  stop(reason: string): void {
    this.reason ??= reason;
  }

  /** Call once per preview request, after it finishes. */
  previewFinished(terminal: boolean): void {
    this.terminalStreak = terminal ? this.terminalStreak + 1 : 0;
    if (this.terminalStreak >= CONSECUTIVE_TERMINAL_LIMIT) {
      this.stop(
        `${CONSECUTIVE_TERMINAL_LIMIT} consecutive terminal preview failures`,
      );
    }
  }

  /** Call for every provider response. */
  providerResponded(status: number): void {
    const hard = status === 429 || status >= 500;
    this.providerErrorStreak = hard ? this.providerErrorStreak + 1 : 0;
    if (this.providerErrorStreak >= CONSECUTIVE_PROVIDER_ERROR_LIMIT) {
      this.stop(
        `${CONSECUTIVE_PROVIDER_ERROR_LIMIT} consecutive provider 429 or 5xx responses`,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Leak scan
// ---------------------------------------------------------------------------

const LEAK_PATTERNS: ReadonlyArray<readonly [string, RegExp]> = [
  ["base64 image", /[A-Za-z0-9+/]{200,}/],
  ["storage path", /analyses\/[0-9a-f-]{36}|custom-palette-generated/],
  ["image file name", /[\w-]+\.(?:jpe?g|png|webp)\b/i],
  ["JWT", /eyJ[A-Za-z0-9_-]{10,}/],
  ["Google key", /AIza[0-9A-Za-z_-]{20,}/],
  ["Supabase secret", /sb_secret_[A-Za-z0-9_-]{4,}/],
  ["prompt text", /HIGHEST PRIORITY|Fixed palette|Edit the supplied selfie/],
  ["signed URL", /[?&]token=|\/object\/sign\//],
];

/** Names the first kind of sensitive content in [text], or null. */
export function findLeak(
  text: string,
  secrets: readonly string[] = [],
): string | null {
  for (const secret of secrets) {
    if (secret.length >= 8 && text.includes(secret)) return "configured secret";
  }
  for (const [name, pattern] of LEAK_PATTERNS) {
    if (pattern.test(text)) return name;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Palette comparison
// ---------------------------------------------------------------------------

function canonical(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(canonical);
  if (value !== null && typeof value === "object") {
    const input = value as Record<string, unknown>;
    return Object.fromEntries(
      Object.keys(input).sort().map((key) => [key, canonical(input[key])]),
    );
  }
  return value;
}

/**
 * Exact equality of two palettes, ignoring only object key order, because a jsonb
 * column does not keep it. Array order, every value, and every key still count.
 */
export function samePalette(a: unknown, b: unknown): boolean {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

// ---------------------------------------------------------------------------
// Rates
// ---------------------------------------------------------------------------

/** A Wilson 95% interval, so a small sample shows how little it can prove. */
export function wilson(
  successes: number,
  total: number,
): { rate: number | null; low: number | null; high: number | null } {
  if (total === 0) return { rate: null, low: null, high: null };
  const z = 1.959964;
  const p = successes / total;
  const denominator = 1 + (z * z) / total;
  const centre = p + (z * z) / (2 * total);
  const margin = z *
    Math.sqrt((p * (1 - p)) / total + (z * z) / (4 * total * total));
  const round = (value: number) => Math.round(value * 10000) / 10000;
  return {
    rate: round(p),
    low: round(Math.max(0, (centre - margin) / denominator)),
    high: round(Math.min(1, (centre + margin) / denominator)),
  };
}

// ---------------------------------------------------------------------------
// The human review gate before Stage 2
// ---------------------------------------------------------------------------

export const REVIEW_COLUMNS = [
  "review_id",
  "category",
  "target_hex",
  "target_finish",
  "color_verdict",
  "finish_verdict",
  "identity_verdict",
] as const;
const COLOR_VERDICTS = new Set(["faithful", "material_mismatch", "severe"]);
const FINISH_VERDICTS = new Set(["faithful", "contradicted", "not_judgeable"]);
const IDENTITY_VERDICTS = new Set(["same_person", "changed"]);

export interface ReviewOutcome {
  rows: number;
  severe: number;
  materialMismatches: number;
  finishContradictions: number;
  identityChanged: number;
}

/** Reads a completed review sheet. A blank or unknown verdict is a refusal. */
export function readReviewSheet(csv: string): ReviewOutcome {
  const lines = csv.split(/\r?\n/).filter((line) => line.trim().length > 0);
  if (lines[0]?.trim() !== REVIEW_COLUMNS.join(",")) {
    throw new GuardRefusal("The review sheet's columns have changed.");
  }
  const outcome: ReviewOutcome = {
    rows: 0,
    severe: 0,
    materialMismatches: 0,
    finishContradictions: 0,
    identityChanged: 0,
  };
  for (const line of lines.slice(1)) {
    const cells = line.split(",").map((cell) => cell.trim());
    const color = cells[4];
    const finish = cells[5];
    const identity = cells[6];
    if (
      cells.length !== REVIEW_COLUMNS.length ||
      !COLOR_VERDICTS.has(color) || !FINISH_VERDICTS.has(finish) ||
      !IDENTITY_VERDICTS.has(identity)
    ) {
      throw new GuardRefusal(`Review row ${cells[0]} is not complete.`);
    }
    outcome.rows += 1;
    if (color === "severe") outcome.severe += 1;
    if (color === "material_mismatch") outcome.materialMismatches += 1;
    if (finish === "contradicted") outcome.finishContradictions += 1;
    if (identity === "changed") outcome.identityChanged += 1;
  }
  return outcome;
}

/** The CCP-9 stop-loss on human findings: 2 severe, or any identity change. */
export function reviewStopReason(outcome: ReviewOutcome): string | null {
  if (outcome.identityChanged > 0) {
    return "an accepted preview changed identity";
  }
  if (outcome.severe >= 2) return "two confirmed severe palette replacements";
  return null;
}
