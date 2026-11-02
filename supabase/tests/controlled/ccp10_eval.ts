/**
 * CCP-10 — the controlled evaluation runner.
 *
 * Runs the accepted CCP-9 plan through the real CCP, Tutorial and face analysis
 * entry points against a throwaway local Supabase stack. Every provider request
 * passes through one wrapper here, which classifies it, charges a persisted budget
 * before releasing it, and refuses anything unknown.
 *
 * Modes
 *   CCP10_MODE=dry  (default) A simulated provider answers everything. The process
 *                   must also be started WITHOUT network permission for the Gemini
 *                   host, so the operating runtime refuses it independently.
 *   CCP10_MODE=live Real Gemini. Requires the exact stage authorization, a key file
 *                   and three selfies outside any repository, and network permission
 *                   for the Gemini host. Not to be run without explicit authorization.
 *
 * Environment
 *   CCP10_STAGE                 1 or 2. Stage 2 continues Stage 1's run directory.
 *   CCP10_OUT                   Run directory, outside any repository.
 *   LOCAL_SUPABASE_URL, LOCAL_ANON_KEY, LOCAL_SERVICE_ROLE_KEY
 *   LOCAL_DB_CONTAINER          The throwaway database container.
 *   CCP10_REPO                  Optional: checkout for the protected source check.
 *   CCP10_WORKSPACE             Protected folder holding the harness copy, inputs
 *                               and outputs. Its real ACL is verified with icacls.
 *                               Required live; optional for a simulated run.
 *   CCP10_DRY_INJECT            Dry only: palette_mutation | validator_bypass |
 *                               manifest_call | guideline_call, to prove the stops.
 *   CCP10_DRY_SCENARIO          mixed | terminal_streak | provider_errors
 *   CCP10_DRY_CEILING           Dry only: a lower ceiling, to prove the hard stop.
 *   CCP10_LIVE_AUTHORIZATION    Live only: the exact token for this stage.
 *   CCP10_KEY_FILE              Live only: a file holding a GEMINI_API_KEY=... line.
 *   CCP10_SELFIES               Live only: S1,S2,S3 consented JPEG paths.
 *
 * Dry run, from supabase/functions:
 *   deno run --no-lock --allow-env --allow-read --allow-sys \
 *     --allow-write=<run dir> --allow-run=docker,git \
 *     --allow-net=127.0.0.1,localhost ../tests/controlled/ccp10_eval.ts
 *
 * A restricted --allow-read must include markerPathsFor(...) of every sensitive
 * path, because the location check refuses whatever it cannot prove. Add icacls to
 * --allow-run when CCP10_WORKSPACE is set.
 *
 * Never written anywhere: selfie bytes in results, signed URLs, storage paths,
 * prompt text, keys, or tokens. Accepted previews are written to the run directory
 * only, for the local blind human review.
 */
import { dirname, fromFileUrl, resolve } from "jsr:@std/path@1";
import { createClient } from "npm:@supabase/supabase-js@2";

import { createGeminiPreviewPorts } from "../../functions/generate-custom-palette-preview/gemini_client.ts";
import { judgeValidatorResponse } from "../../functions/generate-custom-palette-preview/validator.ts";
import { customPaletteValidatorPrompt } from "../../functions/generate-custom-palette-preview/validator_prompt.ts";
import {
  CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
  CUSTOM_COLOR_PALETTE_SOURCE_MODE,
  paletteDigest,
  type PaletteSelection,
  parseCustomPaletteRequest,
  parseFrozenPalette,
} from "../../functions/_shared/custom_palette_contract.ts";
import {
  DryProvider,
  type DryScenario,
  mixedBehavior,
} from "./ccp10_dry_provider.ts";
import {
  assertAllowedHost,
  assertLoopbackDatabase,
  assertOutsideRepository,
  assertProtectedAcl,
  assertProtectedWorkspace,
  assertThrowawayContainer,
  assertWithinWorkspace,
  CallBudget,
  CeilingReached,
  classifyProviderRequest,
  findLeak,
  GuardRefusal,
  paletteViolation,
  type ProviderKind,
  readReviewSheet,
  REVIEW_COLUMNS,
  reviewStopReason,
  samePalette,
  stageViolation,
  StopLoss,
  validatorBypassReason,
  wilson,
} from "./ccp10_guards.ts";
import {
  A_COLORS,
  type AccountId,
  ACCOUNTS,
  ALL_CASES,
  type Choice,
  type EvalCase,
  isClearCutProbe,
  LIVE_AUTHORIZATION,
  lookById,
  type LookCase,
  LOOKS,
  type ProbeCase,
  PROBES,
  probeTarget,
  REPLAY_CASES,
  selfieOf,
  type SelfieSlot,
  type Stage,
  STAGE_1_ACCOUNTS,
  STAGE_1_CEILING,
  TOTAL_CEILING,
  TUTORIAL_CATEGORY,
  type TutorialCase,
  TUTORIALS,
  type VariationCase,
  VARIATIONS,
  worstCaseFor,
} from "./ccp10_plan.ts";

const GEMINI_HOST = "generativelanguage.googleapis.com";
const PROTECTED_BASELINE = "2b29652";
const PROTECTED_PATHS = [
  "supabase/migrations",
  "supabase/functions/analyze-face",
  "supabase/functions/analyze-tutorial-manifest-v4",
  "supabase/functions/generate-tutorial-step-v4",
  "supabase/functions/generate-makeup-recommendation",
  "supabase/functions/generate-makeup-preview",
  "supabase/functions/generate-kit-makeup-recommendation",
  "supabase/functions/generate-kit-makeup-preview",
  "supabase/functions/generate-custom-palette-recommendation",
  "supabase/functions/generate-custom-palette-preview",
  "lib",
];

// ---------------------------------------------------------------------------
// Configuration and refusals. Nothing below this block runs if any check fails.
// ---------------------------------------------------------------------------

function refuse(message: string): never {
  // Directly to stderr: the log capture below would otherwise swallow it.
  Deno.stderr.writeSync(
    new TextEncoder().encode(`ccp10 refused: ${message}\n`),
  );
  Deno.exit(2);
}

const mode = Deno.env.get("CCP10_MODE") === "live"
  ? "live" as const
  : "dry" as const;
const stageText = Deno.env.get("CCP10_STAGE") ?? "1";
if (stageText !== "1" && stageText !== "2") {
  refuse("CCP10_STAGE must be 1 or 2");
}
const stage = Number(stageText) as Stage;
const outDir = Deno.env.get("CCP10_OUT") ?? "";
const url = Deno.env.get("LOCAL_SUPABASE_URL") ?? "";
const anon = Deno.env.get("LOCAL_ANON_KEY") ?? "";
const service = Deno.env.get("LOCAL_SERVICE_ROLE_KEY") ?? "";
const container = Deno.env.get("LOCAL_DB_CONTAINER") ?? "";
const repoCheck = Deno.env.get("CCP10_REPO") ?? "";
const workspace = Deno.env.get("CCP10_WORKSPACE") ?? "";
const inject = Deno.env.get("CCP10_DRY_INJECT") ?? "";
if (
  ![
    "",
    "palette_mutation",
    "validator_bypass",
    "manifest_call",
    "guideline_call",
  ]
    .includes(inject)
) {
  refuse("unknown CCP10_DRY_INJECT");
}
if (mode === "live" && inject) refuse("Fault injection is dry-run only.");
const harnessRoot = resolve(dirname(fromFileUrl(import.meta.url)), "../../..");

let liveKey = "";
const selfiePaths = new Map<SelfieSlot, string>();

try {
  assertLoopbackDatabase(url);
  assertThrowawayContainer(container);
  assertOutsideRepository("CCP10_OUT", outDir, harnessRoot);
  if (!anon || !service) throw new GuardRefusal("Local keys are required.");
  for (
    const name of [
      "GEMINI_MODEL",
      "GEMINI_IMAGE_MODEL",
      "GEMINI_TUTORIAL_MODEL",
    ]
  ) {
    if (Deno.env.get(name)) {
      throw new GuardRefusal(`${name} must be unset: the models are locked.`);
    }
  }
  const network = await Deno.permissions.query({
    name: "net",
    host: GEMINI_HOST,
  });
  if (mode === "dry") {
    if (network.state === "granted") {
      throw new GuardRefusal(
        "A dry run must start without network permission for the Gemini host.",
      );
    }
  } else {
    if (
      Deno.env.get("CCP10_LIVE_AUTHORIZATION") !== LIVE_AUTHORIZATION[stage]
    ) {
      throw new GuardRefusal(
        "Live mode needs the exact authorization for this stage.",
      );
    }
    if (network.state !== "granted") {
      throw new GuardRefusal("Live mode needs permission for the Gemini host.");
    }
    const keyFile = Deno.env.get("CCP10_KEY_FILE") ?? "";
    assertOutsideRepository("CCP10_KEY_FILE", keyFile, harnessRoot);
    const line = Deno.readTextFileSync(keyFile).split(/\r?\n/)
      .find((entry) => entry.startsWith("GEMINI_API_KEY="));
    liveKey = line?.slice("GEMINI_API_KEY=".length).trim() ?? "";
    if (!liveKey) throw new GuardRefusal("The key file holds no key.");
    const selfies = (Deno.env.get("CCP10_SELFIES") ?? "").split(",")
      .map((path) => path.trim()).filter(Boolean);
    if (selfies.length !== 3) {
      throw new GuardRefusal("CCP10_SELFIES must list exactly 3 files.");
    }
    (["S1", "S2", "S3"] as const).forEach((slot, index) => {
      assertOutsideRepository(`Selfie ${slot}`, selfies[index], harnessRoot);
      if (!/\.jpe?g$/i.test(selfies[index])) {
        throw new GuardRefusal(
          "Selfies must be JPEG: analyze-face requires it.",
        );
      }
      selfiePaths.set(slot, selfies[index]);
    });
    if (!workspace) {
      throw new GuardRefusal("Live mode needs a protected CCP10_WORKSPACE.");
    }
    assertProtectedAcl("CCP10_KEY_FILE", keyFile);
    for (const [slot, path] of selfiePaths) {
      assertWithinWorkspace(`Selfie ${slot}`, path, workspace);
      assertProtectedAcl(`Selfie ${slot}`, path);
    }
  }
  if (workspace) {
    assertProtectedWorkspace(workspace);
    assertWithinWorkspace("The harness", harnessRoot, workspace);
    assertWithinWorkspace("CCP10_OUT", outDir, workspace);
  }
} catch (error) {
  refuse(error instanceof Error ? error.message : "configuration");
}

Deno.mkdirSync(outDir, { recursive: true });
Deno.mkdirSync(`${outDir}/review`, { recursive: true });

// A live ceiling does not reset with a new run directory: it lives at one fixed
// path, so the authorized budget holds across every live run on this machine.
const liveBudgetDir = `${
  Deno.env.get("USERPROFILE") ?? Deno.env.get("HOME")
}/.facetune-eval`;
let budgetPath = `${outDir}/budget.json`;
if (mode === "live") {
  Deno.mkdirSync(liveBudgetDir, { recursive: true });
  budgetPath = `${liveBudgetDir}/ccp10-live-budget.json`;
}
const dryCeiling = mode === "dry"
  ? Number(Deno.env.get("CCP10_DRY_CEILING") ?? "0")
  : 0;
const ceiling = dryCeiling > 0
  ? dryCeiling
  : stage === 1
  ? STAGE_1_CEILING
  : TOTAL_CEILING;
const budget = new CallBudget(budgetPath, ceiling);
const stopLoss = new StopLoss();
const scenarioText = Deno.env.get("CCP10_DRY_SCENARIO") ?? "mixed";
if (!["mixed", "terminal_streak", "provider_errors"].includes(scenarioText)) {
  refuse("unknown CCP10_DRY_SCENARIO");
}
const provider = new DryProvider(scenarioText as DryScenario);

Deno.env.set("SUPABASE_URL", url);
Deno.env.set("SUPABASE_ANON_KEY", anon);
Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", service);
Deno.env.set(
  "GEMINI_API_KEY",
  mode === "live" ? liveKey : "dry-run-holds-no-key",
);

// ---------------------------------------------------------------------------
// Everything a log could leak passes through this capture
// ---------------------------------------------------------------------------

const captured: string[] = [];
for (const level of ["log", "error", "warn", "info"] as const) {
  console[level] = (...args: unknown[]) => {
    captured.push(args.map(String).join(" "));
  };
}
function say(message: string): void {
  Deno.stdout.writeSync(new TextEncoder().encode(`${message}\n`));
}

// ---------------------------------------------------------------------------
// The one path to a provider
// ---------------------------------------------------------------------------

interface CaseProviderRecord {
  calls: number;
  paletteHashes: string[];
  observations: Array<Record<string, unknown>>;
  promptPalettes: Array<
    Array<{ category: string; colorHex: string; finish: string }>
  >;
  variationNumbers: number[];
  /** Held in memory only, to re-judge an accepted preview. Never written out. */
  validatorTexts: string[];
  frozenHash: string | null;
  expectedPalette: string[] | null;
}

function newRecord(): CaseProviderRecord {
  return {
    calls: 0,
    paletteHashes: [],
    observations: [],
    promptPalettes: [],
    variationNumbers: [],
    validatorTexts: [],
    frozenHash: null,
    expectedPalette: null,
  };
}
let current = newRecord();

const codePattern = /^[a-z_]{1,40}$/;
/** Copies closed vocabulary only, so model prose can never reach the results. */
function safeObservations(text: string): Record<string, unknown> {
  try {
    const root = JSON.parse(text) as {
      categories?: Array<Record<string, unknown>>;
      introducedCategories?: unknown[];
      identity?: unknown;
    };
    const code = (value: unknown) =>
      typeof value === "string" && codePattern.test(value) ? value : "invalid";
    return {
      categories: (root.categories ?? []).map((entry) => ({
        category: code(entry.categoryCode),
        presence: code(entry.presence),
        color: code(entry.color),
        colorReason: code(entry.colorReason),
        finish: code(entry.finish),
        finishReason: code(entry.finishReason),
      })),
      introduced: (root.introducedCategories ?? []).map(code),
      identity: code(root.identity),
    };
  } catch {
    return { malformed: true };
  }
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(text),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

const realFetch = globalThis.fetch.bind(globalThis);
globalThis.fetch = (async (input: RequestInfo | URL, init?: RequestInit) => {
  const target = new URL(input instanceof Request ? input.url : String(input));
  assertAllowedHost(target.hostname);
  if (target.hostname !== GEMINI_HOST) return realFetch(input, init);

  // Once anything has stopped the run, no further provider call leaves this process.
  if (stopLoss.reason) throw new GuardRefusal("The run has stopped.");
  const halt = (reason: string): never => {
    stopLoss.stop(reason);
    throw new GuardRefusal(reason);
  };

  const body = typeof init?.body === "string" ? init.body : "";
  const request = JSON.parse(body) as {
    contents: Array<{ parts: Array<{ text?: string }> }>;
  };
  const firstText = request.contents[0].parts[0].text ?? "";
  let kind: ProviderKind;
  try {
    kind = classifyProviderRequest(target.pathname, firstText);
  } catch (error) {
    return halt(error instanceof Error ? error.message : "unknown request");
  }
  const forbidden = stageViolation(stage, kind);
  if (forbidden) {
    record({
      id: "violation",
      block: "-",
      kind: "violation",
      reason: forbidden,
    });
    return halt(forbidden);
  }
  if (kind === "image") {
    const marker = "Fixed palette: ";
    let section = firstText.slice(firstText.lastIndexOf(marker));
    if (inject === "palette_mutation" && current.paletteHashes.length > 0) {
      section = section.replace(
        /"colorHex":"#[0-9A-F]{6}"/,
        '"colorHex":"#000001"',
      );
    }
    const promptHash = await sha256(section);
    const palette = JSON.parse(section.slice(marker.length)) as Array<
      { category: string; colorHex: string; finish: string }
    >;
    const violation = paletteViolation({
      frozenHash: current.frozenHash ?? current.paletteHashes[0] ?? null,
      promptHash,
      expected: current.expectedPalette,
      prompt: palette.map((p) => `${p.category}|${p.colorHex}|${p.finish}`),
    });
    if (violation) {
      record({
        id: "violation",
        block: "-",
        kind: "violation",
        reason: violation,
      });
      return halt(violation);
    }
    current.paletteHashes.push(promptHash);
    current.promptPalettes.push(palette);
    const match = firstText.match(/This is variation (\d+)\./);
    if (match) current.variationNumbers.push(Number(match[1]));
  }
  budget.charge(kind);
  current.calls += 1;

  const response = mode === "dry"
    ? provider.answer(kind, body)
    : await realFetch(input, init);
  stopLoss.providerResponded(response.status);
  if (kind === "validator" && response.ok) {
    const copy = await response.clone().json() as {
      candidates?: Array<{ content?: { parts?: Array<{ text?: string }> } }>;
    };
    const text = copy.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? "").join("") ?? "";
    current.observations.push(safeObservations(text));
    if (inject !== "validator_bypass") current.validatorTexts.push(text);
  }
  return response;
}) as typeof fetch;

// ---------------------------------------------------------------------------
// The real entry points, captured in process
// ---------------------------------------------------------------------------

type Handler = (request: Request) => Promise<Response> | Response;

async function loadHandler(path: string): Promise<Handler> {
  const realServe = Deno.serve;
  let handler: Handler | null = null;
  // deno-lint-ignore no-explicit-any
  (Deno as any).serve = (captured: Handler) => {
    handler = captured;
    return { finished: Promise.resolve() };
  };
  try {
    await import(path);
  } finally {
    // deno-lint-ignore no-explicit-any
    (Deno as any).serve = realServe;
  }
  if (!handler) throw new Error("A function registered no handler.");
  return handler;
}

const handlers = {
  analysis: await loadHandler("../../functions/analyze-face/index.ts"),
  recommendation: await loadHandler(
    "../../functions/generate-custom-palette-recommendation/index.ts",
  ),
  preview: await loadHandler(
    "../../functions/generate-custom-palette-preview/index.ts",
  ),
  manifest: await loadHandler(
    "../../functions/analyze-tutorial-manifest-v4/index.ts",
  ),
  step: await loadHandler(
    "../../functions/generate-tutorial-step-v4/index.ts",
  ),
};

async function call(handler: Handler, token: string, body: unknown) {
  const response = await handler(
    new Request("http://local.invalid/fn", {
      method: "POST",
      headers: { authorization: `Bearer ${token}` },
      body: JSON.stringify(body),
    }),
  );
  // deno-lint-ignore no-explicit-any
  return { status: response.status, body: await response.json() as any };
}

// ---------------------------------------------------------------------------
// The throwaway database
// ---------------------------------------------------------------------------

const admin = createClient(url, service, {
  auth: { persistSession: false, autoRefreshToken: false },
});

/** Runs SQL as the database owner in the throwaway container, returning JSON. */
async function ownerQuery(sql: string): Promise<unknown> {
  const output = await new Deno.Command("docker", {
    args: [
      "exec",
      container,
      "psql",
      "-U",
      "postgres",
      "-d",
      "postgres",
      "-v",
      "ON_ERROR_STOP=1",
      "-At",
      "-c",
      sql,
    ],
    stdout: "piped",
    stderr: "null",
  }).output();
  if (!output.success) throw new Error("A local database query failed.");
  const text = new TextDecoder().decode(output.stdout).trim();
  // Statements print a command tag such as "INSERT 0 1"; only queries return JSON.
  return text.startsWith("[") || text.startsWith("{") ? JSON.parse(text) : null;
}

interface AccountState {
  userId: string;
  analysisId: string;
  entitlementId: string;
}
interface LookState {
  account: AccountId;
  recommendationId: string;
  previewId: string | null;
  frozen: unknown;
  hashes: string[];
}
interface RunState {
  mode: "dry" | "live";
  runTag: string;
  accounts: Partial<Record<AccountId, AccountState>>;
  looks: Record<string, LookState>;
  finished: string[];
  reviewIssued: number;
}

const statePath = `${outDir}/state.json`;
const resultsPath = `${outDir}/results.jsonl`;
const previousState = (() => {
  try {
    return JSON.parse(Deno.readTextFileSync(statePath)) as RunState;
  } catch {
    return null;
  }
})();
if (stage === 2 && !previousState) refuse("Stage 2 continues a Stage 1 run.");
if (previousState && previousState.mode !== mode) {
  refuse("A run directory cannot change mode.");
}
if (stage === 1 && previousState && previousState.finished.length > 0) {
  refuse("Stage 1 already ran in this directory.");
}
if (stage === 2) {
  // Stage 2 builds on Stage 1, so it may only follow a Stage 1 that finished clean.
  try {
    const stage1 = JSON.parse(
      Deno.readTextFileSync(`${outDir}/summary-stage1.json`),
    ) as {
      stop_reason: string | null;
      cases: { preview_requests: number; expected_preview_requests: number };
    };
    if (
      stage1.stop_reason !== null ||
      stage1.cases.preview_requests !== stage1.cases.expected_preview_requests
    ) {
      refuse("Stage 1 did not finish cleanly.");
    }
  } catch {
    refuse("Stage 2 needs Stage 1's summary.");
  }
}
const state: RunState = previousState ?? {
  mode,
  runTag: crypto.randomUUID().slice(0, 8),
  accounts: {},
  looks: {},
  finished: [],
  reviewIssued: 0,
};
function saveState(): void {
  Deno.writeTextFileSync(statePath, JSON.stringify(state, null, 1));
}

// The session is issued fresh on each run, so no credential is ever stored.
const sessions = new Map<
  AccountId,
  { token: string; client: ReturnType<typeof createClient> }
>();

async function signIn(account: AccountId, userId: string) {
  const password = crypto.randomUUID();
  const email =
    `ccp10-${state.runTag}-${account.toLowerCase()}@example.invalid`;
  const updated = await admin.auth.admin.updateUserById(userId, { password });
  if (updated.error) throw new Error("Could not prepare a local account.");
  const auth = createClient(url, anon, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const signedIn = await auth.auth.signInWithPassword({ email, password });
  if (signedIn.error || !signedIn.data.session) {
    throw new Error("Could not sign in a local account.");
  }
  const token = signedIn.data.session.access_token;
  sessions.set(account, {
    token,
    client: createClient(url, anon, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    }),
  });
}

function dryJpeg(account: AccountId): Uint8Array {
  const bytes = new Uint8Array(4096);
  bytes.set([0xff, 0xd8, 0xff, 0xe0]);
  bytes[64] = account.charCodeAt(1);
  bytes[65] = account.charCodeAt(2);
  return bytes;
}

async function ensureAccount(account: AccountId): Promise<void> {
  const existing = state.accounts[account];
  if (existing) {
    await signIn(account, existing.userId);
    return;
  }
  const email =
    `ccp10-${state.runTag}-${account.toLowerCase()}@example.invalid`;
  const created = await admin.auth.admin.createUser({
    email,
    password: crypto.randomUUID(),
    email_confirm: true,
  });
  if (created.error || !created.data.user) {
    throw new Error("Could not create a local account.");
  }
  const userId = created.data.user.id;
  await signIn(account, userId);

  // salon_pro: 35 looks and Tutorial access. Entitlements have no client path.
  const entitlementId = crypto.randomUUID();
  const reference = await sha256(entitlementId);
  await ownerQuery(`
    insert into public.user_entitlements (
      id, user_id, plan_code, status, billing_provider, provider_product_id,
      provider_subscription_reference, period_start, period_end, starts_at,
      auto_renew, base_ai_look_allowance, verified_at
    ) values (
      '${entitlementId}', '${userId}', 'salon_pro', 'active', 'google_play',
      'facetune_salon_pro', '${reference}',
      timezone('utc', now()) - interval '1 day',
      timezone('utc', now()) + interval '29 days',
      timezone('utc', now()) - interval '1 day',
      true, 35, timezone('utc', now())
    )`);

  const session = sessions.get(account)!;
  const analysisId = crypto.randomUUID();
  const storagePath =
    `${userId}/analyses/${analysisId}/original/${crypto.randomUUID()}.jpg`;
  const bytes = mode === "live"
    ? Deno.readFileSync(selfiePaths.get(selfieOf(account))!)
    : dryJpeg(account);
  const uploaded = await session.client.storage.from("face-images").upload(
    storagePath,
    bytes,
    { contentType: "image/jpeg" },
  );
  if (uploaded.error) throw new Error("Could not store a selfie locally.");
  current = newRecord();
  const analysis = await call(handlers.analysis, session.token, {
    analysisId,
    storagePath,
  });
  if (analysis.status !== 200) {
    if (budget.exhausted) stopLoss.stop("provider call ceiling reached");
    stopLoss.stop(`selfie analysis failed: ${analysis.body?.error?.code}`);
    throw new Error("analysis");
  }
  state.accounts[account] = { userId, analysisId, entitlementId };
  saveState();
}

// ---------------------------------------------------------------------------
// Accounting and fidelity checks
// ---------------------------------------------------------------------------

function selectionsFor(
  look: { choices: Choice[] },
  requestId: string,
  analysisId: string,
) {
  return {
    paletteRequestId: requestId,
    paletteVersion: CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
    sourceMode: CUSTOM_COLOR_PALETTE_SOURCE_MODE,
    analysisId,
    categorySelections: look.choices.map((choice) => ({
      categoryCode: choice.category,
      baseColorValue: choice.base,
      adjustedColorValue: choice.adjusted,
      colorLabel: choice.label,
      finishCode: choice.finish,
    })),
  };
}

const COLOR_FIELD =
  /"(?:colorHex|color|finish|adjustedColorValue|baseColorValue)"\s*:/;
const HEX_VALUE = /#[0-9a-f]{3,8}\b/i;

async function ledgerFor(account: AccountId, operationId: string) {
  const { data } = await sessions.get(account)!.client
    .from("usage_ledger")
    .select("status,source_mode,canonical_custom_palette_preview_id")
    .eq("operation_id", operationId);
  return (data ?? []) as Array<{
    status: string;
    source_mode: string | null;
    canonical_custom_palette_preview_id: string | null;
  }>;
}

async function attemptsFor(operationId: string) {
  const rows = await ownerQuery(`
    select coalesce(json_agg(json_build_object(
      'attempt', attempt_number, 'status', status,
      'mismatchCategories', mismatch_category_codes,
      'reasons', mismatch_reason_codes
    ) order by attempt_number), '[]'::json)
    from public.custom_palette_preview_attempts
    where operation_id = '${operationId}'`);
  return rows as Array<{
    attempt: number;
    status: string;
    mismatchCategories: string[];
    reasons: string[];
  }>;
}

/**
 * The per-request evidence, read from the throwaway database while it is running.
 * Identifiers, digests, codes and timings only.
 */
async function evidenceFor(
  operationId: string,
  recommendationId: string,
  wallMs: number,
): Promise<{
  evidence: Record<string, unknown>;
  selections: PaletteSelection[];
  acceptedAttemptStatus: string | null;
  storedOutcome: string | null;
  storedValidatorVersion: string | null;
}> {
  const row = await ownerQuery(`
    select json_build_object(
      'digest', r.palette_digest,
      'snapshot', r.palette_snapshot_json,
      'accepted_attempt', g.accepted_attempt_number,
      'outcome', g.validation_outcome,
      'validator_version', g.validator_version,
      'ledger_status', u.status,
      'reserved', u.reserved_at is not null,
      'committed', u.committed_at is not null,
      'released', u.released_at is not null,
      'attempts', (
        select coalesce(json_agg(json_build_object(
          'number', a.attempt_number,
          'status', a.status,
          'seconds', round(extract(epoch from a.finished_at - a.started_at)::numeric, 3)
        ) order by a.attempt_number), '[]'::json)
        from public.custom_palette_preview_attempts a
        where a.operation_id = '${operationId}'
      )
    )
    from public.custom_palette_recommendations r
    left join public.custom_palette_generated_images g
      on g.operation_id = '${operationId}'
    left join public.usage_ledger u on u.operation_id = '${operationId}'
    where r.id = '${recommendationId}'`) as {
    digest: string;
    snapshot: unknown;
    accepted_attempt: number | null;
    outcome: string | null;
    validator_version: string | null;
    ledger_status: string | null;
    reserved: boolean | null;
    committed: boolean | null;
    released: boolean | null;
    attempts: Array<{ number: number; status: string; seconds: number | null }>;
  };
  const selections = parseFrozenPalette(row.snapshot);
  const recomputed = await paletteDigest(selections);
  const consistent = recomputed === row.digest;
  if (!consistent) stopLoss.stop("a stored palette digest does not match");
  const accepted = row.attempts.find((a) => a.number === row.accepted_attempt);
  return {
    selections,
    acceptedAttemptStatus: accepted?.status ?? null,
    storedOutcome: row.outcome,
    storedValidatorVersion: row.validator_version,
    evidence: {
      operation_id: operationId,
      palette_id: recommendationId,
      palette_digest: row.digest,
      digest_recomputed_consistent: consistent,
      accepted_attempt_number: row.accepted_attempt,
      validator_outcome: row.outcome ?? row.attempts.at(-1)?.status ?? null,
      validator_version: row.validator_version,
      latency_ms: wallMs,
      attempt_seconds: row.attempts.map((a) => a.seconds),
      retry_count: Math.max(0, row.attempts.length - 1),
      usage_reservation: row.reserved ? "reserved" : "none",
      usage_result: row.committed
        ? "committed"
        : row.released
        ? "released"
        : row.ledger_status ?? "none",
    },
  };
}

type Row = Record<string, unknown> & {
  id: string;
  block: string;
  kind: string;
};
const rowsThisRun: Row[] = [];

function record(row: Row): void {
  rowsThisRun.push(row);
  Deno.writeTextFileSync(resultsPath, JSON.stringify(row) + "\n", {
    append: true,
  });
}

/** Issues one accepted preview for blind review, saved only in the run directory. */
async function exportForReview(
  caseId: string,
  account: AccountId,
  previewId: string,
  choices: Choice[],
): Promise<void> {
  const { data } = await sessions.get(account)!.client
    .from("custom_palette_generated_images")
    .select("storage_path")
    .eq("id", previewId)
    .single();
  const path = (data as { storage_path: string } | null)?.storage_path;
  if (!path) throw new Error("A preview has no stored image.");
  const download = await sessions.get(account)!.client.storage
    .from("face-images").download(path);
  if (download.error || !download.data) {
    throw new Error("Could not read a preview for review.");
  }
  state.reviewIssued += 1;
  const reviewId = `R${String(state.reviewIssued).padStart(3, "0")}`;
  Deno.writeFileSync(
    `${outDir}/review/${reviewId}.png`,
    new Uint8Array(await download.data.arrayBuffer()),
  );
  const sheet = `${outDir}/review_sheet.csv`;
  try {
    Deno.statSync(sheet);
  } catch {
    Deno.writeTextFileSync(sheet, REVIEW_COLUMNS.join(",") + "\n");
  }
  for (const choice of choices) {
    Deno.writeTextFileSync(
      sheet,
      `${reviewId},${choice.category},${choice.adjusted},${choice.finish},,,\n`,
      { append: true },
    );
  }
  // The answer key stays apart from the sheet, so the review stays blind.
  Deno.writeTextFileSync(
    `${outDir}/review_key.jsonl`,
    JSON.stringify({ reviewId, caseId, selfie: selfieOf(account) }) + "\n",
    { append: true },
  );
}

// ---------------------------------------------------------------------------
// Case runners
// ---------------------------------------------------------------------------

interface PreviewOutcome {
  status: number;
  code: string | null;
  previewId: string | null;
  invocations: number;
}

/** One logical preview. A 409 means still running: replay the SAME operation. */
async function runPreview(
  account: AccountId,
  recommendationId: string,
  operationId: string,
): Promise<PreviewOutcome> {
  const session = sessions.get(account)!;
  let invocations = 0;
  while (true) {
    invocations += 1;
    const result = await call(handlers.preview, session.token, {
      customPaletteRecommendationId: recommendationId,
      operationId,
    });
    if (result.status === 409 && invocations < 4) continue;
    return {
      status: result.status,
      code: result.body?.error?.code ?? null,
      previewId: result.body?.preview?.id ?? null,
      invocations,
    };
  }
}

/** Runs the preview, then checks accounting and prompt fidelity for it. */
async function previewChecks(
  evalCase: { id: string; block: string; kind: string },
  account: AccountId,
  recommendationId: string,
  choices: Choice[],
  expectedHashes: string[],
): Promise<{ row: Row; previewId: string | null }> {
  const operationId = crypto.randomUUID();
  current.frozenHash = expectedHashes[0] ?? null;
  current.expectedPalette = choices.map((c) =>
    `${c.category}|${c.adjusted}|${c.finish}`
  );
  const startedAt = Date.now();
  const outcome = await runPreview(account, recommendationId, operationId);
  const wallMs = Date.now() - startedAt;
  const accepted = outcome.status === 200 && outcome.previewId !== null;
  const attempts = await attemptsFor(operationId);
  const proof = await evidenceFor(operationId, recommendationId, wallMs);
  const lastText = current.validatorTexts.at(-1);
  const bypass = validatorBypassReason({
    accepted,
    lastValidatorOutcome: lastText === undefined
      ? null
      : judgeValidatorResponse(lastText, proof.selections).outcome,
    storedOutcome: proof.storedOutcome,
    storedValidatorVersion: proof.storedValidatorVersion,
    acceptedAttemptStatus: proof.acceptedAttemptStatus,
  });
  if (bypass) {
    record({ id: "violation", block: "-", kind: "violation", reason: bypass });
    stopLoss.stop(bypass);
  }
  const ledger = await ledgerFor(account, operationId);

  const accounting: string[] = [];
  if (ledger.length > 1) accounting.push("more_than_one_ledger_row");
  if (accepted) {
    if (ledger[0]?.status !== "committed") {
      accounting.push("accepted_not_committed");
    }
    if (ledger[0]?.source_mode !== CUSTOM_COLOR_PALETTE_SOURCE_MODE) {
      accounting.push("wrong_source_mode");
    }
    if (ledger[0]?.canonical_custom_palette_preview_id !== outcome.previewId) {
      accounting.push("wrong_preview_link");
    }
  } else if (ledger[0]?.status === "committed") {
    accounting.push("failure_was_charged");
  }

  const expected = choices.map((c) => `${c.category}|${c.adjusted}|${c.finish}`)
    .sort();
  const promptFidelity = current.promptPalettes.every((palette) =>
    JSON.stringify(
      palette.map((p) => `${p.category}|${p.colorHex}|${p.finish}`).sort(),
    ) === JSON.stringify(expected)
  );
  const hashes = [...new Set([...expectedHashes, ...current.paletteHashes])];

  let replay: Record<string, unknown> | null = null;
  if (accepted && REPLAY_CASES.includes(evalCase.id)) {
    const before = budget.total;
    const again = await runPreview(account, recommendationId, operationId);
    const after = await ledgerFor(account, operationId);
    const clean = again.previewId === outcome.previewId &&
      budget.total === before && after.length === 1 &&
      after[0].status === "committed";
    if (!clean) accounting.push("replay_changed_something");
    replay = {
      same_preview: again.previewId === outcome.previewId,
      new_calls: budget.total - before,
    };
  }

  const terminal = !accepted;
  stopLoss.previewFinished(terminal);
  if (accounting.length > 0) {
    stopLoss.stop(`accounting anomaly in ${evalCase.id}`);
  }

  // A preview that failed the validator check is never offered for review.
  if (accepted && !bypass) {
    await exportForReview(evalCase.id, account, outcome.previewId!, choices);
  }
  return {
    previewId: outcome.previewId,
    row: {
      id: evalCase.id,
      block: evalCase.block,
      kind: evalCase.kind,
      selfie: selfieOf(account),
      account,
      outcome: accepted ? "accepted" : "terminal",
      failure_code: outcome.code,
      attempts: attempts.length,
      first_attempt_accepted: attempts[0]?.status === "accepted",
      attempt_statuses: attempts.map((a) => a.status),
      mismatch_categories: [
        ...new Set(attempts.flatMap((a) => a.mismatchCategories)),
      ],
      mismatch_reasons: [...new Set(attempts.flatMap((a) => a.reasons))],
      observations: current.observations,
      ledger_status: ledger[0]?.status ?? null,
      accounting_anomalies: accounting,
      palette_hashes_distinct: hashes.length,
      prompt_matches_palette: promptFidelity,
      replay,
      variation_numbers: current.variationNumbers,
      invocations: outcome.invocations,
      provider_calls: current.calls,
      evidence: proof.evidence,
    },
  };
}

async function runLook(look: LookCase): Promise<void> {
  const account = look.account;
  const session = sessions.get(account)!;
  const analysisId = state.accounts[account]!.analysisId;
  const parent = look.derivedFrom ? state.looks[look.derivedFrom] : null;
  if (look.derivedFrom && !parent) {
    record({
      id: look.id,
      block: look.block,
      kind: look.kind,
      outcome: "skipped",
      reason: "parent_unavailable",
    });
    return;
  }
  const requestId = crypto.randomUUID();
  const body = {
    ...selectionsFor(look, requestId, analysisId),
    style: look.style,
    derivedFromPaletteId: parent?.recommendationId ?? null,
  };
  const expected: PaletteSelection[] =
    parseCustomPaletteRequest(body).selections;
  const recommendation = await call(
    handlers.recommendation,
    session.token,
    body,
  );
  if (recommendation.status !== 200) {
    stopLoss.previewFinished(true);
    record({
      id: look.id,
      block: look.block,
      kind: look.kind,
      selfie: selfieOf(account),
      account,
      outcome: "recommendation_failed",
      failure_code: recommendation.body?.error?.code ?? null,
      provider_calls: current.calls,
    });
    return;
  }
  const recommendationId = recommendation.body.recommendation.id as string;
  const { data: stored } = await session.client
    .from("custom_palette_recommendations")
    .select("palette_snapshot_json,recommendation_json,derived_from_palette_id")
    .eq("id", recommendationId)
    .single();
  // deno-lint-ignore no-explicit-any
  const row = stored as any;
  const paletteFaithful = samePalette(row.palette_snapshot_json, expected);
  const planText = JSON.stringify(row.recommendation_json);
  const noAiColor = !COLOR_FIELD.test(planText) && !HEX_VALUE.test(planText);
  if (!paletteFaithful) stopLoss.stop(`palette not preserved in ${look.id}`);

  let parentUnchanged: boolean | null = null;
  if (parent) {
    const { data: parentRow } = await session.client
      .from("custom_palette_recommendations")
      .select("palette_snapshot_json")
      .eq("id", parent.recommendationId)
      .single();
    // deno-lint-ignore no-explicit-any
    parentUnchanged = samePalette(
      (parentRow as any).palette_snapshot_json,
      parent.frozen,
    );
  }

  const { row: previewRow, previewId } = await previewChecks(
    look,
    account,
    recommendationId,
    look.choices,
    [],
  );
  state.looks[look.id] = {
    account,
    recommendationId,
    previewId,
    frozen: row.palette_snapshot_json,
    hashes: current.paletteHashes,
  };
  record({
    ...previewRow,
    style: look.style,
    categories: look.choices.map((c) => c.category),
    palette: look.choices.map((c) => `${c.category}:${c.adjusted}:${c.finish}`),
    recommendation_palette_faithful: paletteFaithful,
    recommendation_no_ai_color: noAiColor,
    derived_links_parent: parent
      ? row.derived_from_palette_id === parent.recommendationId
      : null,
    parent_unchanged: parentUnchanged,
  });
}

async function runVariation(variation: VariationCase): Promise<void> {
  const parent = state.looks[variation.parent];
  if (!parent?.previewId) {
    record({
      id: variation.id,
      block: variation.block,
      kind: variation.kind,
      outcome: "skipped",
      reason: "parent_unavailable",
    });
    return;
  }
  const look = lookById(variation.parent);
  const { row, previewId } = await previewChecks(
    variation,
    parent.account,
    parent.recommendationId,
    look.choices,
    parent.hashes,
  );
  record({
    ...row,
    parent: variation.parent,
    new_preview: previewId !== parent.previewId,
  });
}

async function runTutorial(tutorial: TutorialCase): Promise<void> {
  const parent = state.looks[tutorial.parent];
  const skip = () =>
    record({
      id: tutorial.id,
      block: tutorial.block,
      kind: tutorial.kind,
      outcome: "skipped",
      reason: "parent_unavailable",
    });
  if (!parent?.previewId) return skip();
  const look = lookById(tutorial.parent);
  const session = sessions.get(parent.account)!;
  const manifest = await call(handlers.manifest, session.token, {
    customPalettePreviewId: parent.previewId,
  });
  if (manifest.status !== 200) {
    record({
      id: tutorial.id,
      block: tutorial.block,
      kind: tutorial.kind,
      outcome: "manifest_failed",
      failure_code: manifest.body?.error?.code ?? null,
      lineage_correct: false,
      provider_calls: current.calls,
    });
    return;
  }
  const sessionId = manifest.body.manifest.tutorialSessionId as string;
  const problems: string[] = [];
  if (manifest.body.manifest.sourceMode !== CUSTOM_COLOR_PALETTE_SOURCE_MODE) {
    problems.push("wrong_source_mode");
  }
  if (manifest.body.manifest.promptVersion !== "tutorial_manifest_v4_1") {
    problems.push("wrong_manifest_version");
  }
  let position = 0;
  const steps: Array<Record<string, unknown>> = [];
  for (const choice of look.choices) {
    position += 1;
    const category = TUTORIAL_CATEGORY[choice.category];
    // The same insert the app's ensureSteps makes.
    const inserted = await session.client.from("tutorial_v4_steps").insert({
      user_id: state.accounts[parent.account]!.userId,
      tutorial_session_id: sessionId,
      category,
      position,
    } as never);
    if (inserted.error) problems.push(`step_refused:${category}`);
    const step = await call(handlers.step, session.token, {
      tutorialSessionId: sessionId,
      category,
    });
    const item = step.body?.products?.items?.[0];
    const faithful = step.status === 200 &&
      item?.colorHex === choice.adjusted &&
      item?.finish === choice.finish &&
      step.body?.step?.promptVersion === "tutorial_guideline_v4_7";
    if (!faithful) problems.push(`step_not_faithful:${category}`);
    steps.push({
      category,
      status: step.status,
      faithful,
      failure_code: step.body?.error?.code ?? null,
    });
  }
  const before = budget.total;
  const unselected = await call(handlers.step, session.token, {
    tutorialSessionId: sessionId,
    category: "foundation",
  });
  if (
    unselected.body?.error?.code !== "category_not_included" ||
    budget.total !== before
  ) {
    problems.push("unselected_category_not_refused");
  }
  if (problems.length > 0) {
    stopLoss.stop(`Tutorial lineage failure in ${tutorial.id}`);
  }
  record({
    id: tutorial.id,
    block: tutorial.block,
    kind: tutorial.kind,
    selfie: selfieOf(parent.account),
    outcome: "completed",
    lineage_correct: problems.length === 0,
    problems,
    steps,
    provider_calls: current.calls,
  });
}

async function runProbe(probe: ProbeCase): Promise<void> {
  const label = A_COLORS.find((color) =>
    state.looks[`A-${probe.category}-${color}`]?.previewId
  );
  if (!label) {
    record({
      id: probe.id,
      block: probe.block,
      kind: probe.kind,
      outcome: "skipped",
      reason: "no_accepted_source",
    });
    return;
  }
  const source = state.looks[`A-${probe.category}-${label}`];
  const session = sessions.get(source.account)!;
  const target = probeTarget(probe, label);
  const selections = parseCustomPaletteRequest({
    ...selectionsFor(
      { choices: [target] },
      crypto.randomUUID(),
      crypto.randomUUID(),
    ),
    style: "natural",
    derivedFromPaletteId: null,
  }).selections;

  const { data: previewRow } = await session.client
    .from("custom_palette_generated_images")
    .select("storage_path")
    .eq("id", source.previewId!)
    .single();
  const { data: analysisRow } = await session.client
    .from("analyses")
    .select("original_image_path")
    .eq("id", state.accounts[source.account]!.analysisId)
    .single();
  const bucket = session.client.storage.from("face-images");
  // deno-lint-ignore no-explicit-any
  const candidate = await bucket.download((previewRow as any).storage_path);
  // deno-lint-ignore no-explicit-any
  const original = await bucket.download(
    (analysisRow as any).original_image_path,
  );
  if (candidate.error || original.error) {
    throw new Error("Could not read a probe's images.");
  }
  const ports = createGeminiPreviewPorts(Deno.env.get("GEMINI_API_KEY")!);
  let outcome = "validator_failure";
  let reasons: string[] = [];
  try {
    const text = await ports.requestValidation(
      customPaletteValidatorPrompt(selections),
      {
        bytes: new Uint8Array(await original.data!.arrayBuffer()),
        mimeType: "image/jpeg",
      },
      {
        bytes: new Uint8Array(await candidate.data!.arrayBuffer()),
        mimeType: "image/png",
      },
    );
    const verdict = judgeValidatorResponse(text, selections);
    outcome = verdict.outcome;
    reasons = [
      ...verdict.color_mismatch_reasons.map((r) => `${r.category}:${r.reason}`),
      ...verdict.mismatch_categories.map((c) => `${c}:mismatch`),
    ];
  } catch (error) {
    if (error instanceof CeilingReached) throw error;
  }
  record({
    id: probe.id,
    block: probe.block,
    kind: probe.kind,
    probe: probe.probe,
    clear_cut: isClearCutProbe(probe),
    source: `A-${probe.category}-${label}`,
    outcome,
    flagged: outcome === "retryable_palette_mismatch" ||
      outcome === "nonretryable_palette_mismatch",
    reasons,
    provider_calls: current.calls,
  });
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

function loadAllRows(): Row[] {
  try {
    return Deno.readTextFileSync(resultsPath).split("\n").filter(Boolean)
      .map((line) => JSON.parse(line) as Row);
  } catch {
    return [];
  }
}

// Stage 2 live may not begin until Stage 1's blind review is complete and clean.
let reviewNote = "not_required_at_stage_1";
if (stage === 2) {
  if (mode === "live") {
    try {
      const review = readReviewSheet(
        Deno.readTextFileSync(`${outDir}/review_sheet.csv`),
      );
      const reason = reviewStopReason(review);
      if (reason) refuse(`Stage 1 review stop-loss: ${reason}`);
      reviewNote = `stage_1_reviewed:${review.rows}_rows`;
    } catch (error) {
      refuse(error instanceof Error ? error.message : "review sheet");
    }
  } else {
    reviewNote = "simulated_no_human_review";
  }
}

const protectedIds = new Set<string>([
  ...REPLAY_CASES,
  ...LOOKS.filter((look) => look.stage === 1).map((look) => look.id),
  ...VARIATIONS.map((v) => v.parent),
  ...TUTORIALS.map((t) => t.parent),
  ...LOOKS.flatMap((look) => look.derivedFrom ? [look.derivedFrom] : []),
  ...PROBES.flatMap((probe) => [`A-${probe.category}-Red`]),
]);

function accountOf(evalCase: EvalCase): AccountId | null {
  if (evalCase.kind === "look") return evalCase.account;
  if (evalCase.kind === "variation" || evalCase.kind === "tutorial") {
    return lookById(evalCase.parent).account;
  }
  return null;
}

let setupFailed = false;
const accountsNeeded = stage === 1 ? STAGE_1_ACCOUNTS : ACCOUNTS;
for (const account of accountsNeeded) {
  try {
    await ensureAccount(account);
  } catch (error) {
    setupFailed = true;
    if (error instanceof Error && error.message !== "analysis") {
      stopLoss.stop(`local account setup failed: ${error.constructor.name}`);
    }
    break;
  }
  if (stopLoss.reason || budget.exhausted) break;
}

const queue = ALL_CASES.filter((c) =>
  c.stage === stage && !state.finished.includes(c.id)
);
let index = 0;
for (const evalCase of queue) {
  if (setupFailed || stopLoss.reason) break;
  if (budget.exhausted) {
    stopLoss.stop("provider call ceiling reached");
    break;
  }
  if (budget.total + worstCaseFor(evalCase) > budget.ceiling) {
    stopLoss.stop("the next case's worst case would cross the ceiling");
    break;
  }
  const account = accountOf(evalCase);
  if (account && !sessions.has(account)) {
    stopLoss.stop("a case's account is not ready");
    break;
  }
  current = newRecord();
  provider.startCase(
    inject === "palette_mutation"
      ? "retry"
      : mixedBehavior(evalCase.id, index, protectedIds),
  );
  if (
    index === 0 && (inject === "manifest_call" || inject === "guideline_call")
  ) {
    const manifest = inject === "manifest_call";
    await fetch(
      `https://${GEMINI_HOST}/v1beta/models/${
        manifest ? "gemini-3.6-flash" : "gemini-3.1-flash-image"
      }:generateContent`,
      {
        method: "POST",
        body: JSON.stringify({
          contents: [{
            parts: [{
              text: manifest
                ? "You are comparing two photographs"
                : "Injected guideline request",
            }],
          }],
        }),
      },
    ).catch(() => undefined);
    if (stopLoss.reason) break;
  }
  index += 1;
  try {
    switch (evalCase.kind) {
      case "look":
        await runLook(evalCase);
        break;
      case "variation":
        await runVariation(evalCase);
        break;
      case "tutorial":
        await runTutorial(evalCase);
        break;
      case "probe":
        await runProbe(evalCase);
        break;
    }
  } catch (error) {
    stopLoss.stop(
      error instanceof CeilingReached
        ? "provider call ceiling reached"
        : `harness error in ${evalCase.id}: ${
          error instanceof Error ? error.constructor.name : "unknown"
        }`,
    );
  }
  if (budget.exhausted) stopLoss.stop("provider call ceiling reached");
  const leak = findLeak(captured.join("\n"), [service, anon, liveKey]);
  if (leak) stopLoss.stop(`sensitive content in logs: ${leak}`);
  state.finished.push(evalCase.id);
  saveState();
  say(
    `ccp10 ${mode} stage ${stage} ${state.finished.length} ${evalCase.id} calls=${budget.total}/${budget.ceiling}`,
  );
}

// ---------------------------------------------------------------------------
// Summary and gates
// ---------------------------------------------------------------------------

const rows = loadAllRows();
const previews = rows.filter((r) => r.attempts !== undefined);
const looks = rows.filter((r) => r.kind === "look" && r.outcome !== "skipped");
const accepted = previews.filter((r) => r.outcome === "accepted");
const firstAccepted = previews.filter((r) => r.first_attempt_accepted === true);
const terminal = previews.filter((r) => r.outcome === "terminal");
// deno-lint-ignore no-explicit-any
const observationsOf = (r: Row) => (r.observations ?? []) as any[];
const finalObservation = (r: Row) => observationsOf(r).at(-1);
// deno-lint-ignore no-explicit-any
const categoryObservations = accepted.flatMap((r) =>
  (finalObservation(r)?.categories ?? []) as any[]
);
const finishJudgeable = categoryObservations.filter((o) =>
  o.finish === "consistent" || o.finish === "contradicted"
);
const probes = rows.filter((r) =>
  r.kind === "probe" && r.outcome !== "skipped"
);
const clearCut = probes.filter((r) => r.clear_cut === true);
const tutorials = rows.filter((r) =>
  r.kind === "tutorial" && r.outcome !== "skipped"
);
const expectedPreviews =
  ALL_CASES.filter((c) =>
    c.stage <= stage && (c.kind === "look" || c.kind === "variation")
  ).length;
const allAttempts = previews.flatMap((r) =>
  (r.attempt_statuses ?? []) as string[]
);

const byStratum = (key: (r: Row) => string[]) => {
  const groups = new Map<
    string,
    { n: number; accepted: number; terminal: number }
  >();
  for (const row of previews) {
    for (const name of key(row)) {
      const group = groups.get(name) ?? { n: 0, accepted: 0, terminal: 0 };
      group.n += 1;
      if (row.outcome === "accepted") group.accepted += 1;
      if (row.outcome === "terminal") group.terminal += 1;
      groups.set(name, group);
    }
  }
  return Object.fromEntries(groups);
};
const paletteOf = (r: Row) => (r.palette ?? []) as string[];
const strata = {
  block: byStratum((r) => [r.block]),
  selfie: byStratum((r) => [String(r.selfie)]),
  style: byStratum((r) => r.style ? [String(r.style)] : []),
  category: byStratum((r) => paletteOf(r).map((p) => p.split(":")[0])),
  finish: byStratum((r) => paletteOf(r).map((p) => p.split(":")[2])),
};
const fullyFailed = Object.entries(strata).flatMap(([name, groups]) =>
  Object.entries(groups)
    .filter(([, g]) => g.n >= 2 && g.accepted === 0)
    .map(([group]) => `${name}:${group}`)
);

function gitProtectedCheck(): string {
  if (!repoCheck) return "NOT_CHECKED";
  const result = new Deno.Command("git", {
    args: [
      "-C",
      repoCheck,
      "diff",
      "--quiet",
      PROTECTED_BASELINE,
      "--",
      ...PROTECTED_PATHS,
    ],
    stderr: "null",
  }).outputSync();
  return result.code === 0 ? "PASS" : "FAIL";
}

const scanTargets = [resultsPath, statePath, `${outDir}/review_key.jsonl`];
const resultLeaks = scanTargets.flatMap((path) => {
  try {
    const leak = findLeak(Deno.readTextFileSync(path), [
      service,
      anon,
      liveKey,
    ]);
    return leak ? [leak] : [];
  } catch {
    return [];
  }
});
const logLeak = findLeak(captured.join("\n"), [service, anon, liveKey]);
if (resultLeaks.length > 0) stopLoss.stop("sensitive content in results");

const complete = !stopLoss.reason && previews.length === expectedPreviews;
const gate = (ok: boolean) => complete ? (ok ? "PASS" : "FAIL") : "INCOMPLETE";
const humanGate = mode === "dry"
  ? "NOT_EVIDENCE_SIMULATED"
  : "PENDING_HUMAN_REVIEW";

const EVIDENCE_FIELDS = [
  "operation_id",
  "palette_id",
  "palette_digest",
  "digest_recomputed_consistent",
  "accepted_attempt_number",
  "validator_outcome",
  "latency_ms",
  "retry_count",
  "usage_reservation",
  "usage_result",
];
const evidenceComplete = previews.length > 0 && previews.every((r) => {
  const evidence = r.evidence as Record<string, unknown> | undefined;
  return evidence !== undefined &&
    EVIDENCE_FIELDS.every((field) => field in evidence) &&
    evidence.digest_recomputed_consistent === true;
});

const summary = {
  simulated: mode === "dry",
  note: mode === "dry"
    ? "Simulated provider. Proves the harness only; these rates say nothing about Gemini."
    : "Real provider. Human review decides H6 and H7.",
  stage,
  stop_reason: stopLoss.reason,
  review_gate: reviewNote,
  provider_calls: {
    total: budget.total,
    ceiling: budget.ceiling,
    by_kind: budget.byKind,
  },
  cases: {
    results_recorded: rows.length,
    preview_requests: previews.length,
    expected_preview_requests: expectedPreviews,
  },
  metrics: {
    recommendation_palette_fidelity: wilson(
      looks.filter((r) => r.recommendation_palette_faithful === true).length,
      looks.length,
    ),
    first_attempt_preview_acceptance: wilson(
      firstAccepted.length,
      previews.length,
    ),
    acceptance_within_retry_bound: wilson(accepted.length, previews.length),
    terminal_failure_rate: wilson(terminal.length, previews.length),
    attempts_by_status: allAttempts.reduce<Record<string, number>>(
      (all, status) => {
        all[status] = (all[status] ?? 0) + 1;
        return all;
      },
      {},
    ),
    finish_contradiction_rate_judgeable: wilson(
      finishJudgeable.filter((o) => o.finish === "contradicted").length,
      finishJudgeable.length,
    ),
    finish_not_judgeable:
      categoryObservations.filter((o) => o.finish === "not_judgeable").length,
    validator_probe_flagged: wilson(
      probes.filter((r) => r.flagged === true).length,
      probes.length,
    ),
    strata,
    groups_with_no_acceptance: fullyFailed,
  },
  gates: {
    H1_palette_preserved: gate(
      looks.length > 0 &&
        looks.every((r) => r.recommendation_palette_faithful === true),
    ),
    H2_no_ai_color_stored: gate(
      looks.length > 0 &&
        looks.every((r) => r.recommendation_no_ai_color === true),
    ),
    H3_palette_identical_across_attempts: gate(
      previews.every((r) =>
        r.palette_hashes_distinct === 1 && r.prompt_matches_palette === true
      ),
    ),
    H4_accounting_exact: gate(
      previews.every((r) =>
        (r.accounting_anomalies as unknown[]).length === 0
      ) &&
        previews.filter((r) => r.replay).length ===
          REPLAY_CASES.filter((id) => lookById(id).stage <= stage).length,
    ),
    H5_tutorial_lineage: stage === 1 ? "NOT_IN_STAGE_1" : gate(
      tutorials.length === TUTORIALS.length &&
        tutorials.every((r) => r.lineage_correct === true),
    ),
    H6_no_severe_replacement: humanGate,
    H7_identity_preserved: humanGate,
    H8_clear_probes_flagged: stage === 1 ? "NOT_IN_STAGE_1" : gate(
      clearCut.length === 8 && clearCut.every((r) => r.flagged === true),
    ),
    H9_protected_source_unchanged: gitProtectedCheck(),
  },
  evidence_complete: evidenceComplete,
  violations: rows.filter((r) => r.kind === "violation").map((r) => r.reason),
  leak_scan: {
    logs: logLeak ?? "clean",
    results: resultLeaks.length > 0 ? resultLeaks : "clean",
    log_lines_scanned: captured.length,
  },
};
Deno.writeTextFileSync(
  `${outDir}/summary-stage${stage}.json`,
  JSON.stringify(summary, null, 1),
);
say(
  `ccp10 ${mode} stage ${stage} finished: calls=${budget.total}/${budget.ceiling} previews=${previews.length}/${expectedPreviews} stop=${
    stopLoss.reason ?? "none"
  }`,
);
Deno.exit(stopLoss.reason ? 3 : 0);
