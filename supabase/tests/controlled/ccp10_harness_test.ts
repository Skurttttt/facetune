/**
 * CCP-10 — proves the plan and the safety controls. Needs no database and no network.
 *
 * Run from `supabase/functions`:
 *   deno test --no-lock --allow-read --allow-write --allow-env --allow-run \
 *     ../tests/controlled/ccp10_harness_test.ts
 */
import { assert, assertEquals, assertThrows } from "jsr:@std/assert@1";
import { dirname, fromFileUrl, join, resolve } from "jsr:@std/path@1";

import {
  CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
  CUSTOM_COLOR_PALETTE_SOURCE_MODE,
  CUSTOM_PALETTE_FINISHES,
  CUSTOM_PALETTE_STYLES,
  parseCustomPaletteRequest,
} from "../../functions/_shared/custom_palette_contract.ts";
import {
  aclViolations,
  assertAllowedHost,
  assertLoopbackDatabase,
  assertOutsideRepository,
  assertThrowawayContainer,
  assertWithinWorkspace,
  CallBudget,
  CeilingReached,
  classifyProviderRequest,
  findLeak,
  GuardRefusal,
  manifestModelViolation,
  markerPathsFor,
  paletteViolation,
  PROTECTED_BASELINE,
  PROTECTED_PATHS,
  protectedSourceCheck,
  readReviewSheet,
  recordValidatorObservations,
  REQUIRED_PREVIEW_VERSION,
  REQUIRED_VALIDATOR_VERSION,
  REVIEW_COLUMNS,
  reviewStopReason,
  samePalette,
  stageViolation,
  StopLoss,
  validatorBypassReason,
  versionViolation,
  wilson,
} from "./ccp10_guards.ts";
import {
  ACCOUNTS,
  ALL_CASES,
  authorizationFor,
  type Category,
  LIVE_AUTHORIZATION,
  lookById,
  LOOKS,
  PROBES,
  probeTarget,
  REMEDIATION_AUTHORIZATION,
  REMEDIATION_CEILING,
  REMEDIATION_R1,
  runCeiling,
  selfieOf,
  stage2BudgetViolation,
  STAGE_1_ACCOUNTS,
  STAGE_1_CEILING,
  STAGE_1_RERUN_AUTHORIZATION,
  STAGE_2_CEILING,
  stepsOf,
  STYLES,
  TOTAL_CEILING,
  TUTORIALS,
  VARIATIONS,
  worstCaseFor,
  worstCaseForLooks,
  worstCaseThroughStage,
} from "./ccp10_plan.ts";

const HERE = dirname(fromFileUrl(import.meta.url));
const ROOT = resolve(HERE, "../../..");

interface Vector {
  base: string;
  label: string;
  adjusted: string;
}
const VECTORS: Vector[] = JSON.parse(
  Deno.readTextFileSync(
    join(ROOT, "supabase/functions/_shared/custom_palette_vectors.json"),
  ),
);

// ---------------------------------------------------------------------------
// The plan is exactly what was accepted
// ---------------------------------------------------------------------------

Deno.test("the plan's counts are exactly the accepted CCP-9 plan", () => {
  const block = (name: string) => ALL_CASES.filter((c) => c.block === name);
  assertEquals(block("A").length, 16);
  assertEquals(block("B").length, 12);
  assertEquals(block("C").length, 11);
  assertEquals(block("D").length, 8);
  assertEquals(block("E").length, 6);
  assertEquals(block("F").length, 6);
  assertEquals(block("G").length, 6);
  assertEquals(block("H").length, 2);
  assertEquals(block("N").length, 12);
  assertEquals(ALL_CASES.length, 79);
  assertEquals(LOOKS.length + VARIATIONS.length, 61);
  assertEquals(new Set(ALL_CASES.map((c) => c.id)).size, 79);
  assertEquals(TUTORIALS.reduce((sum, t) => sum + stepsOf(t), 0), 15);
});

Deno.test("worst-case arithmetic: the plan's 54 and 420, Stage 2's 366, ceiling 440", () => {
  assertEquals(worstCaseThroughStage(1), STAGE_1_CEILING);
  // The accepted CCP-9 plan is unchanged: 420 calls through Stage 2.
  assertEquals(worstCaseThroughStage(2), 420);
  assertEquals(STAGE_1_CEILING, 54);
  assertEquals(
    STAGE_2_CEILING,
    worstCaseThroughStage(2) - worstCaseThroughStage(1),
  );
  assertEquals(STAGE_2_CEILING, 366);
  assertEquals(TOTAL_CEILING, 440);
});

Deno.test("Stage 1 is exactly the 8 accepted cases on 3 accounts", () => {
  const stage1 = ALL_CASES.filter((c) => c.stage === 1);
  assertEquals(stage1.map((c) => c.id).sort(), [
    "A-blush-Gold",
    "A-eyeliner-Violet",
    "A-lipstick-Red",
    "A-lipstick-Teal",
    "B-lipstick-dark",
    "C-eyeshadow-glitter",
    "D1",
    "D6",
  ]);
  for (const c of stage1) {
    assert(c.kind === "look" && STAGE_1_ACCOUNTS.includes(c.account), c.id);
  }
});

Deno.test("every look passes the real server contract", () => {
  for (const look of LOOKS) {
    const parsed = parseCustomPaletteRequest({
      paletteRequestId: "11111111-1111-4111-8111-111111111111",
      paletteVersion: CUSTOM_COLOR_PALETTE_CONTRACT_VERSION,
      sourceMode: CUSTOM_COLOR_PALETTE_SOURCE_MODE,
      analysisId: "22222222-2222-4222-8222-222222222222",
      style: look.style,
      derivedFromPaletteId: null,
      categorySelections: look.choices.map((c) => ({
        categoryCode: c.category,
        baseColorValue: c.base,
        adjustedColorValue: c.adjusted,
        colorLabel: c.label,
        finishCode: c.finish,
      })),
    });
    assertEquals(parsed.selections.length, look.choices.length, look.id);
  }
});

Deno.test("every adjusted color is one the real adjuster produces", () => {
  const known = new Set(VECTORS.map((v) => `${v.base}${v.adjusted}`));
  for (const look of LOOKS) {
    for (const choice of look.choices) {
      if (choice.adjusted === choice.base) continue;
      assert(
        known.has(`${choice.base}${choice.adjusted}`),
        `${look.id} ${choice.adjusted}`,
      );
    }
  }
});

Deno.test("the plan covers all 12 styles and all 15 finish pairs", () => {
  assertEquals(new Set(STYLES).size, 12);
  assertEquals(
    new Set(LOOKS.map((l) => l.style)),
    new Set(CUSTOM_PALETTE_STYLES),
  );
  const seen = new Set(
    LOOKS.flatMap((l) => l.choices.map((c) => `${c.category}/${c.finish}`)),
  );
  for (const [category, finishes] of Object.entries(CUSTOM_PALETTE_FINISHES)) {
    for (const finish of finishes) {
      assert(seen.has(`${category}/${finish}`), `${category}/${finish}`);
    }
  }
});

Deno.test("no account can reach the quota or the allowance", () => {
  for (const account of ACCOUNTS) {
    const previews = LOOKS.filter((l) => l.account === account).length +
      VARIATIONS.filter((v) =>
        LOOKS.find((l) => l.id === v.parent)!.account === account
      ).length;
    // Every preview can use 2 attempts, against 30 per hour per user.
    assert(previews * 2 <= 30, `${account}: ${previews} previews`);
    assert(previews <= 35, `${account} allowance`);
    assert(previews > 0, `${account} is unused`);
  }
});

Deno.test("each selfie gets real coverage", () => {
  for (const slot of ["S1", "S2", "S3"]) {
    const previews = LOOKS.filter((l) => selfieOf(l.account) === slot).length;
    assert(previews >= 15, `${slot}: ${previews}`);
  }
});

Deno.test("every probe's target is a contract-valid palette", () => {
  for (const probe of PROBES) {
    for (const label of ["Red", "Teal", "Violet", "Gold"]) {
      const target = probeTarget(probe, label);
      const finishes = CUSTOM_PALETTE_FINISHES[target.category as Category];
      assert(finishes.includes(target.finish), probe.id);
      if (probe.probe === "absent") assert(target.category !== probe.category);
      if (probe.probe === "hue") assert(target.label !== label);
      if (probe.probe === "dark") assert(target.adjusted !== target.base);
    }
  }
  assertEquals(PROBES.filter((p) => p.probe !== "dark").length, 8);
});

// ---------------------------------------------------------------------------
// Guards
// ---------------------------------------------------------------------------

Deno.test("only loopback databases are accepted", () => {
  for (
    const good of [
      "http://127.0.0.1:55321",
      "http://localhost:54321",
      "http://[::1]:54321",
    ]
  ) {
    assertLoopbackDatabase(good);
  }
  for (
    const bad of [
      "",
      "not a url",
      "https://abc.supabase.co",
      "http://abc.supabase.co",
      "https://127.0.0.1:54321",
      "http://127.0.0.1.example.com:54321",
      "http://localhost.evil.com",
      "http://10.0.0.5:54321",
      "http://user:pass@127.0.0.1:54321",
      "http://0.0.0.0:54321",
    ]
  ) {
    assertThrows(
      () => assertLoopbackDatabase(bad),
      GuardRefusal,
      undefined,
      bad,
    );
  }
});

Deno.test("only a throwaway container is accepted", () => {
  assertThrowawayContainer("supabase_db_ccp_throwaway");
  for (
    const bad of [
      "",
      "supabase_db_facetune",
      "postgres",
      "throwaway",
      "supabase_db_ccp_throwaway; rm",
    ]
  ) {
    assertThrows(
      () => assertThrowawayContainer(bad),
      GuardRefusal,
      undefined,
      bad,
    );
  }
});

Deno.test("private paths must be outside a repository", () => {
  const outside = Deno.makeTempDirSync({ prefix: "ccp10-guard-" });
  const fakeRoot = join(outside, "harness");
  Deno.mkdirSync(fakeRoot);
  try {
    assertOutsideRepository("x", join(outside, "out"), fakeRoot);
    assertThrows(
      () => assertOutsideRepository("x", "", fakeRoot),
      GuardRefusal,
    );
    assertThrows(
      () => assertOutsideRepository("x", "relative/path", fakeRoot),
      GuardRefusal,
    );
    // Inside the tree the harness runs from, even with no repository marker.
    assertThrows(
      () => assertOutsideRepository("x", join(fakeRoot, "out"), fakeRoot),
      GuardRefusal,
    );
    // Anywhere under a checkout, however deep.
    const checkout = join(outside, "checkout");
    Deno.mkdirSync(join(checkout, ".git"), { recursive: true });
    assertThrows(
      () => assertOutsideRepository("x", join(checkout, "a/b/c"), fakeRoot),
      GuardRefusal,
    );
    const flutter = join(outside, "flutter");
    Deno.mkdirSync(flutter);
    Deno.writeTextFileSync(join(flutter, "pubspec.yaml"), "");
    assertThrows(
      () => assertOutsideRepository("x", join(flutter, "out"), fakeRoot),
      GuardRefusal,
    );
  } finally {
    Deno.removeSync(outside, { recursive: true });
  }
});

Deno.test("hosts are an allow-list", () => {
  for (
    const good of [
      "generativelanguage.googleapis.com",
      "127.0.0.1",
      "localhost",
    ]
  ) {
    assertAllowedHost(good);
  }
  for (
    const bad of [
      "example.com",
      "abc.supabase.co",
      "generativelanguage.googleapis.com.evil.com",
    ]
  ) {
    assertThrows(() => assertAllowedHost(bad), GuardRefusal, undefined, bad);
  }
});

Deno.test("the budget refuses the call that would cross, and persists first", () => {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-budget-" });
  const path = join(dir, "budget.json");
  try {
    const budget = new CallBudget(path, 2);
    budget.charge("image");
    budget.charge("validator");
    assertEquals(JSON.parse(Deno.readTextFileSync(path)).total, 2);
    assertThrows(() => budget.charge("image"), CeilingReached);
    assertEquals(budget.total, 2);
    assert(budget.exhausted);

    // A restart cannot hand budget back, and Stage 2's ceiling includes Stage 1.
    const restarted = new CallBudget(path, 2);
    assertThrows(() => restarted.charge("image"), CeilingReached);
    const stage2 = new CallBudget(path, 3);
    assertEquals(stage2.total, 2);
    stage2.charge("image");
    assertThrows(() => stage2.charge("image"), CeilingReached);
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("provider requests must be recognized, on an approved model", () => {
  const text = "/v1beta/models/gemini-3.6-flash:generateContent";
  const image = "/v1beta/models/gemini-3.1-flash-image:generateContent";
  assertEquals(
    classifyProviderRequest(text, "You are the secure selfie suitability"),
    "analysis",
  );
  assertEquals(
    classifyProviderRequest(text, "You are FaceTune's brand-neutral makeup"),
    "recommendation",
  );
  assertEquals(
    classifyProviderRequest(text, "You are checking whether"),
    "validator",
  );
  assertEquals(
    classifyProviderRequest(text, "You are comparing two photographs"),
    "manifest",
  );
  assertEquals(
    classifyProviderRequest(image, "Edit the supplied selfie"),
    "image",
  );
  assertEquals(classifyProviderRequest(image, "anything else"), "guideline");
  assertThrows(
    () => classifyProviderRequest(text, "Something new"),
    GuardRefusal,
  );
  assertThrows(
    () =>
      classifyProviderRequest(
        "/v1beta/models/gemini-9:generateContent",
        "Edit the supplied selfie",
      ),
    GuardRefusal,
  );
});

Deno.test("stop-loss: terminal and provider streaks, reset by a success", () => {
  const terminal = new StopLoss();
  for (let i = 0; i < 4; i += 1) terminal.previewFinished(true);
  assertEquals(terminal.reason, null);
  terminal.previewFinished(false);
  for (let i = 0; i < 4; i += 1) terminal.previewFinished(true);
  assertEquals(terminal.reason, null);
  terminal.previewFinished(true);
  assert(terminal.reason?.includes("5 consecutive"));

  const provider = new StopLoss();
  provider.providerResponded(429);
  provider.providerResponded(503);
  provider.providerResponded(200);
  provider.providerResponded(500);
  provider.providerResponded(429);
  assertEquals(provider.reason, null);
  provider.providerResponded(502);
  assert(provider.reason?.includes("3 consecutive"));

  const first = new StopLoss();
  first.stop("first");
  first.stop("second");
  assertEquals(first.reason, "first");
});

Deno.test("the leak scan finds each kind of sensitive content", () => {
  for (
    const leak of [
      "x".repeat(250),
      "user/analyses/11111111-1111-4111-8111-111111111111/original",
      "custom-palette-generated",
      "preview_0001.png",
      "eyJhbGciOiJIUzI1NiJ9abc",
      "AIzaSyA1234567890123456789012",
      "sb_secret_abcd1234",
      "Fixed palette: []",
      "http://x/object/sign/y?token=abc",
    ]
  ) {
    assert(findLeak(leak) !== null, leak);
  }
  assertEquals(
    findLeak("my-configured-secret", ["my-configured-secret"]),
    "configured secret",
  );
  assertEquals(
    findLeak(
      '{"id":"D1","outcome":"accepted","palette":["blush:#D93A52:matte"]}',
    ),
    null,
  );
});

Deno.test("the Stage 2 review gate needs a complete sheet and applies stop-loss", () => {
  const header = REVIEW_COLUMNS.join(",");
  const row = (color: string, finish = "faithful", identity = "same_person") =>
    `R001,blush,#D93A52,matte,${color},${finish},${identity}`;
  const clean = readReviewSheet(`${header}\n${row("faithful")}\n`);
  assertEquals(clean.rows, 1);
  assertEquals(reviewStopReason(clean), null);
  assertThrows(
    () => readReviewSheet(`${header}\nR001,blush,#D93A52,matte,,,\n`),
    GuardRefusal,
  );
  assertThrows(
    () => readReviewSheet(`${header}\n${row("looks fine")}\n`),
    GuardRefusal,
  );
  assertThrows(
    () => readReviewSheet(`wrong,header\n${row("faithful")}\n`),
    GuardRefusal,
  );
  assertEquals(
    reviewStopReason(readReviewSheet(`${header}\n${row("severe")}\n`)),
    null,
  );
  assert(
    reviewStopReason(
      readReviewSheet(`${header}\n${row("severe")}\n${row("severe")}\n`),
    ),
  );
  assert(
    reviewStopReason(
      readReviewSheet(`${header}\n${row("faithful", "faithful", "changed")}\n`),
    ),
  );
});

Deno.test("palette comparison ignores key order and nothing else", () => {
  const stored = [{ b: "#D93A52", a: "blush" }, {
    a: "lipstick",
    b: "#000000",
  }];
  assert(samePalette(stored, [{ a: "blush", b: "#D93A52" }, {
    a: "lipstick",
    b: "#000000",
  }]));
  // A changed value, a changed order, a missing or extra key are all differences.
  assert(
    !samePalette(stored, [{ a: "blush", b: "#D93A53" }, {
      a: "lipstick",
      b: "#000000",
    }]),
  );
  assert(
    !samePalette(stored, [{ a: "lipstick", b: "#000000" }, {
      a: "blush",
      b: "#D93A52",
    }]),
  );
  assert(
    !samePalette(stored, [{ a: "blush" }, { a: "lipstick", b: "#000000" }]),
  );
  assert(
    !samePalette(stored, [{ a: "blush", b: "#D93A52", c: 1 }, {
      a: "lipstick",
      b: "#000000",
    }]),
  );
});

Deno.test("Stage 1 refuses manifest and guideline by what they are", () => {
  for (
    const kind of ["analysis", "recommendation", "image", "validator"] as const
  ) {
    assertEquals(stageViolation(1, kind), null);
    assertEquals(stageViolation(2, kind), null);
  }
  assert(stageViolation(1, "manifest")?.includes("forbids"));
  assert(stageViolation(1, "guideline")?.includes("forbids"));
  assertEquals(stageViolation(2, "manifest"), null);
  // A manifest pointed at the image model still classifies as a Tutorial call.
  const pointedAtImage = classifyProviderRequest(
    "/v1beta/models/gemini-3.1-flash-image:generateContent",
    "You are comparing two photographs",
  );
  assert(stageViolation(1, pointedAtImage)?.includes("forbids"));
});

Deno.test("a changed palette is a violation, on the hash or the content", () => {
  const prompt = ["blush|#D93A52|matte"];
  const base = { frozenHash: "a", promptHash: "a", expected: prompt, prompt };
  assertEquals(paletteViolation(base), null);
  assertEquals(paletteViolation({ ...base, frozenHash: null }), null);
  assert(paletteViolation({ ...base, promptHash: "b" })?.includes("retry"));
  assert(
    paletteViolation({ ...base, prompt: ["blush|#000000|matte"] })?.includes(
      "not the frozen",
    ),
  );
  assert(
    paletteViolation({ ...base, prompt: ["blush|#D93A52|satin"] })?.includes(
      "not the frozen",
    ),
  );
});

Deno.test("an accepted preview needs an accepting validator and matching records", () => {
  const good = {
    accepted: true,
    lastValidatorOutcome: "accepted",
    storedOutcome: "accepted",
    storedValidatorVersion: "custom_palette_validator_v1",
    acceptedAttemptStatus: "accepted",
  };
  assertEquals(validatorBypassReason(good), null);
  assertEquals(
    validatorBypassReason({
      ...good,
      accepted: false,
      lastValidatorOutcome: null,
    }),
    null,
  );
  for (
    const bad of [
      { lastValidatorOutcome: null },
      { lastValidatorOutcome: "retryable_palette_mismatch" },
      { lastValidatorOutcome: "validator_failure" },
      { storedOutcome: null },
      { storedValidatorVersion: null },
      { acceptedAttemptStatus: "provider_failure" },
    ]
  ) {
    assert(validatorBypassReason({ ...good, ...bad }), JSON.stringify(bad));
  }
});

Deno.test("ACL parsing allows only the named principals and fails closed", () => {
  const path = "C:\\Users\\K\\.facetune-eval\\ws";
  const allowed = ["NT AUTHORITY\\SYSTEM", "BUILTIN\\Administrators", "PC\\K"];
  const ok = "Successfully processed 1 files; Failed processing 0 files";
  const report = (...rules: string[]) =>
    `${path} ${rules.join("\r\n              ")}\r\n\r\n${ok}\r\n`;
  assertEquals(
    aclViolations(
      report(
        "NT AUTHORITY\\SYSTEM:(I)(OI)(CI)(F)",
        "BUILTIN\\Administrators:(I)(OI)(CI)(F)",
        "PC\\K:(I)(OI)(CI)(F)",
      ),
      path,
      allowed,
    ),
    [],
  );
  assertEquals(
    aclViolations(
      report("PC\\K:(F)", "PC\\CodexSandboxUsers:(OI)(CI)(RX)"),
      path,
      allowed,
    ),
    ["PC\\CodexSandboxUsers"],
  );
  assertEquals(
    aclViolations(report("PC\\K:(F)", "Everyone:(R)"), path, allowed),
    ["Everyone"],
  );
  assertEquals(
    aclViolations(report("PC\\K:(F)", "S-1-5-21-1-2-3-4:(M)"), path, allowed),
    ["S-1-5-21-1-2-3-4"],
  );
  assertEquals(aclViolations(report("garbage"), path, allowed).length, 1);
  assertEquals(aclViolations("", path, allowed).length, 1);
  assertEquals(
    aclViolations(
      "Successfully processed 0 files; Failed processing 1 files",
      path,
      allowed,
    ).length,
    1,
  );
  assertEquals(aclViolations(ok, path, allowed).length, 1);
});

Deno.test("marker paths cover every ancestor, and workspace containment holds", () => {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-marker-" });
  try {
    const markers = markerPathsFor(join(dir, "a", "b"));
    assert(
      markers.some((m) => m.endsWith("/.git") && m.includes("ccp10-marker-")),
    );
    assert(markers.some((m) => m.endsWith("/pubspec.yaml")));
    assert(markers.some((m) => m.endsWith("/supabase/config.toml")));
    assertWithinWorkspace("x", join(dir, "out"), dir);
    assertThrows(
      () => assertWithinWorkspace("x", dirname(dir), dir),
      GuardRefusal,
    );
    assertThrows(
      () => assertWithinWorkspace("x", `${dir}-sibling`, dir),
      GuardRefusal,
    );
    assertThrows(
      () => assertWithinWorkspace("x", "relative", dir),
      GuardRefusal,
    );
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("Wilson intervals are honest about small samples", () => {
  assertEquals(wilson(0, 0).rate, null);
  const eighty = wilson(49, 61);
  assert(eighty.low! > 0.67 && eighty.low! < 0.71, `${eighty.low}`);
  assert(eighty.high! > 0.87 && eighty.high! < 0.9, `${eighty.high}`);
  assertEquals(wilson(0, 61).low, 0);
  assert(wilson(0, 61).high! < 0.07);
});

// ---------------------------------------------------------------------------
// The runner refuses before doing anything
// ---------------------------------------------------------------------------

const SAFE_ENV = {
  LOCAL_SUPABASE_URL: "http://127.0.0.1:1",
  LOCAL_ANON_KEY: "local-anon-placeholder",
  LOCAL_SERVICE_ROLE_KEY: "local-service-placeholder",
  LOCAL_DB_CONTAINER: "supabase_db_test_throwaway",
};

async function runner(
  env: Record<string, string>,
  allowNet = "127.0.0.1",
  readFlag = "--allow-read",
  extraFlags: string[] = [],
): Promise<{ code: number; stderr: string }> {
  const output = await new Deno.Command(Deno.execPath(), {
    args: [
      "run",
      "--no-lock",
      "--allow-env",
      readFlag,
      "--allow-write",
      "--allow-sys",
      `--allow-net=${allowNet}`,
      ...extraFlags,
      join(HERE, "ccp10_eval.ts"),
    ],
    clearEnv: true,
    env: {
      ...(Deno.env.get("USERPROFILE")
        ? { USERPROFILE: Deno.env.get("USERPROFILE")! }
        : {}),
      ...(Deno.env.get("HOME") ? { HOME: Deno.env.get("HOME")! } : {}),
      ...(Deno.env.get("DENO_DIR")
        ? { DENO_DIR: Deno.env.get("DENO_DIR")! }
        : {}),
      ...(Deno.env.get("LOCALAPPDATA")
        ? { LOCALAPPDATA: Deno.env.get("LOCALAPPDATA")! }
        : {}),
      ...(Deno.env.get("SystemRoot")
        ? { SystemRoot: Deno.env.get("SystemRoot")! }
        : {}),
      // So the H9 check can find git.
      ...(Deno.env.get("PATH") ? { PATH: Deno.env.get("PATH")! } : {}),
      ...(Deno.env.get("PATHEXT") ? { PATHEXT: Deno.env.get("PATHEXT")! } : {}),
      ...env,
    },
    stdout: "null",
    stderr: "piped",
    cwd: join(ROOT, "supabase/functions"),
  }).output();
  return { code: output.code, stderr: new TextDecoder().decode(output.stderr) };
}

const refusals: Array<[string, Record<string, string>, string, string?]> = [
  [
    "a remote database",
    { LOCAL_SUPABASE_URL: "https://abc.supabase.co" },
    "must be loopback",
  ],
  [
    "a non-throwaway container",
    { LOCAL_DB_CONTAINER: "supabase_db_facetune" },
    "throwaway",
  ],
  ["an output directory in the repository", {
    CCP10_OUT: join(ROOT, "ccp10-out"),
  }, "CCP10_OUT must be outside"],
  [
    "a model override",
    { GEMINI_IMAGE_MODEL: "something-else" },
    "models are locked",
  ],
  [
    "a dry run allowed to reach Gemini",
    {},
    "without network permission",
    "127.0.0.1,generativelanguage.googleapis.com",
  ],
  [
    "live mode with no authorization",
    { CCP10_MODE: "live" },
    "exact authorization",
    "127.0.0.1,generativelanguage.googleapis.com",
  ],
  [
    "the Stage 1 token on Stage 2",
    {
      CCP10_MODE: "live",
      CCP10_STAGE: "2",
      CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1],
    },
    "exact authorization",
    "127.0.0.1,generativelanguage.googleapis.com",
  ],
  [
    "live mode without Gemini network permission",
    { CCP10_MODE: "live", CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1] },
    "permission for the Gemini host",
  ],
  [
    "live mode with no key file",
    { CCP10_MODE: "live", CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1] },
    "CCP10_KEY_FILE",
    "127.0.0.1,generativelanguage.googleapis.com",
  ],
];

for (const [name, overrides, message, net] of refusals) {
  Deno.test(`the runner refuses ${name}`, async () => {
    const out = Deno.makeTempDirSync({ prefix: "ccp10-refusal-" });
    try {
      const { code, stderr } = await runner(
        { ...SAFE_ENV, CCP10_OUT: out, ...overrides },
        net,
      );
      assertEquals(code, 2, stderr);
      assert(stderr.includes(message), stderr);
    } finally {
      Deno.removeSync(out, { recursive: true });
    }
  });
}

Deno.test("live mode refuses selfies that are not 3 JPEGs outside the repository", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-refusal-" });
  const key = join(out, "key.txt");
  // A placeholder, and every case below is refused before it could be sent.
  Deno.writeTextFileSync(key, "GEMINI_API_KEY=placeholder-never-sent\n");
  const base = {
    ...SAFE_ENV,
    CCP10_OUT: join(out, "run"),
    CCP10_MODE: "live",
    CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1],
    CCP10_KEY_FILE: key,
  };
  const net = "127.0.0.1,generativelanguage.googleapis.com";
  try {
    const none = await runner(base, net);
    assertEquals(none.code, 2);
    assert(none.stderr.includes("exactly 3"), none.stderr);
    const png = [1, 2, 3].map((n) => join(out, `s${n}.png`)).join(",");
    const wrongType = await runner({ ...base, CCP10_SELFIES: png }, net);
    assertEquals(wrongType.code, 2);
    assert(wrongType.stderr.includes("JPEG"), wrongType.stderr);
    const inRepo = [1, 2, 3].map((n) => join(ROOT, `s${n}.jpg`)).join(",");
    const repo = await runner({ ...base, CCP10_SELFIES: inRepo }, net);
    assertEquals(repo.code, 2);
    assert(repo.stderr.includes("outside the repository"), repo.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("Stage 2 refuses to follow a Stage 1 that did not finish clean", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage2-" });
  const base = { ...SAFE_ENV, CCP10_OUT: out, CCP10_STAGE: "2" };
  try {
    const none = await runner(base);
    assertEquals(none.code, 2);
    assert(none.stderr.includes("continues a Stage 1"), none.stderr);
    Deno.writeTextFileSync(
      join(out, "state.json"),
      JSON.stringify({
        mode: "dry",
        runTag: "t",
        accounts: {},
        looks: {},
        finished: [],
        reviewIssued: 0,
      }),
    );
    const noSummary = await runner(base);
    assertEquals(noSummary.code, 2);
    assert(noSummary.stderr.includes("Stage 1's summary"), noSummary.stderr);
    Deno.writeTextFileSync(
      join(out, "summary-stage1.json"),
      JSON.stringify({
        stop_reason: "any stop",
        cases: { preview_requests: 1, expected_preview_requests: 8 },
      }),
    );
    const stopped = await runner(base);
    assertEquals(stopped.code, 2);
    assert(stopped.stderr.includes("did not finish cleanly"), stopped.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("a path that cannot be verified refuses the run", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-closed-" });
  try {
    // Read access to the harness only: the repository markers cannot be checked.
    const { code, stderr } = await runner(
      { ...SAFE_ENV, CCP10_OUT: join(out, "run") },
      "127.0.0.1",
      `--allow-read=${ROOT}`,
    );
    assertEquals(code, 2, stderr);
    assert(stderr.includes("Cannot verify"), stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("a workspace whose ACL cannot be read refuses the run", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-closed-" });
  try {
    // No permission to run icacls, so nothing proves the folder is protected.
    const { code, stderr } = await runner({
      ...SAFE_ENV,
      CCP10_OUT: join(out, "run"),
      CCP10_WORKSPACE: out,
    });
    assertEquals(code, 2, stderr);
    assert(stderr.includes("Cannot verify"), stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("a workspace others can reach, such as Temp, refuses the run", async () => {
  const temp = Deno.env.get("TEMP");
  if (!temp || !Deno.build.os.startsWith("windows")) return;
  const out = Deno.makeTempDirSync({ dir: temp, prefix: "ccp10-temp-" });
  try {
    const { code, stderr } = await runner(
      {
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_WORKSPACE: out,
        // What icacls and the ACL check need, so the real ACL is what refuses.
        PATH: Deno.env.get("PATH") ?? "",
        PATHEXT: Deno.env.get("PATHEXT") ?? "",
        USERNAME: Deno.env.get("USERNAME") ?? "",
        COMPUTERNAME: Deno.env.get("COMPUTERNAME") ?? "",
      },
      "127.0.0.1",
      "--allow-read",
      ["--allow-run=icacls"],
    );
    assertEquals(code, 2, stderr);
    assert(stderr.includes("CCP10_WORKSPACE is not protected"), stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("a repository path as workspace refuses the run", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-closed-" });
  try {
    Deno.mkdirSync(join(out, ".git"));
    const { code, stderr } = await runner({
      ...SAFE_ENV,
      CCP10_OUT: join(out, "run"),
      CCP10_WORKSPACE: out,
    });
    assertEquals(code, 2, stderr);
    assert(stderr.includes("outside the repository"), stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("live mode refuses without a workspace, and refuses fault injection", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-refusal-" });
  const key = join(out, "key.txt");
  Deno.writeTextFileSync(key, "GEMINI_API_KEY=placeholder-never-sent\n");
  const base = {
    ...SAFE_ENV,
    CCP10_OUT: join(out, "run"),
    CCP10_MODE: "live",
    CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1],
    CCP10_KEY_FILE: key,
    CCP10_SELFIES: [1, 2, 3].map((n) => join(out, `s${n}.jpg`)).join(","),
  };
  const net = "127.0.0.1,generativelanguage.googleapis.com";
  try {
    const none = await runner(base, net);
    assertEquals(none.code, 2);
    assert(none.stderr.includes("protected CCP10_WORKSPACE"), none.stderr);
    const injected = await runner(
      { ...base, CCP10_DRY_INJECT: "validator_bypass" },
      net,
    );
    assertEquals(injected.code, 2);
    assert(injected.stderr.includes("dry-run only"), injected.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("the exact Gemini host and port is enough, and no broader grant is needed", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-net-" });
  const base = {
    ...SAFE_ENV,
    CCP10_OUT: join(out, "run"),
    CCP10_MODE: "live",
    CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1],
  };
  try {
    // Past the network check, stopped by the next one: no key file was given.
    const exact = await runner(
      base,
      "127.0.0.1,generativelanguage.googleapis.com:443",
    );
    assertEquals(exact.code, 2);
    assert(exact.stderr.includes("CCP10_KEY_FILE"), exact.stderr);
    // Another port, or another host on 443, is not that permission.
    for (
      const net of [
        "127.0.0.1,generativelanguage.googleapis.com:8443",
        "127.0.0.1,example.com:443",
      ]
    ) {
      const wrong = await runner(base, net);
      assertEquals(wrong.code, 2);
      assert(
        wrong.stderr.includes("permission for the Gemini host"),
        wrong.stderr,
      );
    }
    // A dry run holding that exact permission is still refused.
    const dry = await runner(
      { ...SAFE_ENV, CCP10_OUT: join(out, "run") },
      "127.0.0.1,generativelanguage.googleapis.com:443",
    );
    assertEquals(dry.code, 2);
    assert(dry.stderr.includes("without network permission"), dry.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

/** Runs ensureBudgetFolder in a process holding only the given permissions. */
async function budgetFolderProcess(
  folder: string,
  inside: string,
  flags: string[],
): Promise<{ code: number; stderr: string }> {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-budget-script-" });
  const script = join(dir, "script.ts");
  Deno.writeTextFileSync(
    script,
    `import { ensureBudgetFolder } from ${
      JSON.stringify(new URL("./ccp10_guards.ts", import.meta.url).href)
    };
ensureBudgetFolder(${JSON.stringify(folder)}, ${JSON.stringify(inside)});`,
  );
  try {
    const output = await new Deno.Command(Deno.execPath(), {
      args: ["run", "--no-lock", "--no-prompt", "--no-check", ...flags, script],
      stdout: "null",
      stderr: "piped",
      cwd: join(ROOT, "supabase/functions"),
    }).output();
    return {
      code: output.code,
      stderr: new TextDecoder().decode(output.stderr),
    };
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
}

Deno.test("an existing budget folder needs no permission on the folder", async () => {
  const folder = Deno.makeTempDirSync({ prefix: "ccp10-budget-folder-" });
  const workspace = join(folder, "workspace");
  Deno.mkdirSync(workspace);
  try {
    // Read on the workspace only, and write on nothing at all.
    const { code, stderr } = await budgetFolderProcess(folder, workspace, [
      `--allow-read=${workspace}`,
    ]);
    assertEquals(code, 0, stderr);
  } finally {
    Deno.removeSync(folder, { recursive: true });
  }
});

Deno.test("a missing budget folder fails safely outside the approved scope", async () => {
  const base = Deno.makeTempDirSync({ prefix: "ccp10-budget-missing-" });
  const folder = join(base, "absent");
  const workspace = join(folder, "workspace");
  try {
    const refused = await budgetFolderProcess(folder, workspace, [
      `--allow-read=${workspace}`,
    ]);
    assert(refused.code !== 0);
    assert(refused.stderr.includes("approved scope"), refused.stderr);
    assertThrows(() => Deno.statSync(folder), Deno.errors.NotFound);

    // A path that only looks inside proves nothing: it is outside, so mkdir runs.
    const sibling = await budgetFolderProcess(folder, `${folder}-other`, [
      `--allow-read=${base}`,
    ]);
    assert(sibling.code !== 0);

    // Given write scope on exactly that folder, it is created and nothing more.
    const created = await budgetFolderProcess(folder, workspace, [
      `--allow-read=${workspace}`,
      `--allow-write=${folder}`,
    ]);
    assertEquals(created.code, 0, created.stderr);
    assert(Deno.statSync(folder).isDirectory);
  } finally {
    Deno.removeSync(base, { recursive: true });
  }
});

Deno.test("the targeted remediation run is exactly R004, R006 and R008, at 22 calls", () => {
  assertEquals([...REMEDIATION_R1], [
    "A-eyeliner-Violet",
    "C-eyeshadow-glitter",
    "D6",
  ]);
  // The same cases and the same selfies that failed review.
  assertEquals(REMEDIATION_R1.map((id) => selfieOf(lookById(id).account)), [
    "S3",
    "S3",
    "S2",
  ]);
  assert(REMEDIATION_R1.every((id) => lookById(id).stage === 1));
  assertEquals(worstCaseForLooks(REMEDIATION_R1), 22);
  assertEquals(REMEDIATION_CEILING, 22);
  assert((REMEDIATION_AUTHORIZATION as string) !== LIVE_AUTHORIZATION[1]);
  assert((REMEDIATION_AUTHORIZATION as string) !== LIVE_AUTHORIZATION[2]);
});

Deno.test("the remediation token and the Stage tokens are not interchangeable", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-r1-" });
  const net = "127.0.0.1,generativelanguage.googleapis.com:443";
  try {
    for (
      const [stage, token] of [
        ["R1", LIVE_AUTHORIZATION[1]],
        ["1", REMEDIATION_AUTHORIZATION],
        ["2", REMEDIATION_AUTHORIZATION],
      ]
    ) {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_MODE: "live",
        CCP10_STAGE: stage,
        CCP10_LIVE_AUTHORIZATION: token,
      }, net);
      assertEquals(result.code, 2, stage);
      assert(result.stderr.includes("exact authorization"), result.stderr);
    }
    const unknown = await runner({
      ...SAFE_ENV,
      CCP10_OUT: join(out, "run"),
      CCP10_STAGE: "R2",
    });
    assertEquals(unknown.code, 2);
    assert(unknown.stderr.includes("1, 2, R1, or 1R"), unknown.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

// ---------------------------------------------------------------------------
// The Stage 1 post-remediation rerun
// ---------------------------------------------------------------------------

Deno.test("rerun: its token is unique, and each run kind requires its own", () => {
  const tokens = (["1", "2", "R1", "1R"] as const).map(authorizationFor);
  assertEquals(new Set(tokens).size, 4);
  assertEquals(authorizationFor("1R"), "CCP-10-STAGE-1-RERUN:8-cases:54-calls");
  assertEquals(STAGE_1_RERUN_AUTHORIZATION, authorizationFor("1R"));
});

Deno.test("rerun: 54 new calls on top of the 38 already spent, never past the total", () => {
  assertEquals(runCeiling("1R", 38), 92);
  assertEquals(runCeiling("1R", 0), 54);
  assertEquals(runCeiling("1R", 400), 440);
  assertEquals(runCeiling("1R", 440), 440);
  // The other kinds keep their allowances.
  assertEquals(runCeiling("1", 38), 54);
  assertEquals(runCeiling("R1", 27), 49);
});

Deno.test("rerun: the budget keeps prior calls and allows exactly 54 new ones", () => {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-rerun-budget-" });
  const path = join(dir, "ccp10-live-budget.json");
  const prior = {
    total: 38,
    byKind: { analysis: 5, recommendation: 11, image: 11, validator: 11 },
  };
  Deno.writeTextFileSync(path, JSON.stringify(prior));
  try {
    const budget = new CallBudget(path, runCeiling("1R", 38));
    // Reading the budget changes nothing.
    assertEquals(JSON.parse(Deno.readTextFileSync(path)), prior);
    let charged = 0;
    while (true) {
      try {
        budget.charge("image");
        charged += 1;
      } catch (error) {
        assert(error instanceof CeilingReached);
        break;
      }
    }
    assertEquals(charged, 54);
    const after = JSON.parse(Deno.readTextFileSync(path));
    assertEquals(after.total, 92);
    // Prior calls are still there, by kind; nothing was reset to make room.
    assertEquals(after.byKind.analysis, 5);
    assertEquals(after.byKind.recommendation, 11);
    assertEquals(after.byKind.validator, 11);
    assertEquals(after.byKind.image, 11 + 54);
    // A restart cannot hand any of it back.
    assertThrows(
      () => new CallBudget(path, runCeiling("1R", 38)).charge("image"),
      CeilingReached,
    );
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("rerun: a live rerun with no budget history is refused", async () => {
  const home = Deno.makeTempDirSync({ prefix: "ccp10-no-history-" });
  try {
    const result = await runner(
      {
        ...SAFE_ENV,
        CCP10_OUT: join(home, "run"),
        CCP10_MODE: "live",
        CCP10_STAGE: "1R",
        CCP10_LIVE_AUTHORIZATION: STAGE_1_RERUN_AUTHORIZATION,
        // A home with no history: the trick that would hand back the budget.
        USERPROFILE: home,
        HOME: home,
      },
      "127.0.0.1,generativelanguage.googleapis.com:443",
    );
    assertEquals(result.code, 2);
    assert(result.stderr.includes("live budget history"), result.stderr);
  } finally {
    Deno.removeSync(home, { recursive: true });
  }
});

Deno.test("rerun: the live budget lives at one fixed path that no setting moves", () => {
  const source = Deno.readTextFileSync(join(HERE, "ccp10_eval.ts"));
  assert(
    source.includes("budgetPath = `${liveBudgetDir}/ccp10-live-budget.json`;"),
  );
  assert(
    !/CCP10_[A-Z_]*BUDGET/.test(source),
    "no setting points the budget elsewhere",
  );
});

Deno.test("rerun: earlier run directories cannot be overwritten", async () => {
  const base = Deno.makeTempDirSync({ prefix: "ccp10-prior-" });
  try {
    for (const name of ["stage1", "remediation-r1"]) {
      const dir = join(base, name);
      Deno.mkdirSync(dir);
      const state = {
        mode: "dry",
        runTag: "prior",
        accounts: {},
        looks: {},
        finished: ["A-lipstick-Red"],
        reviewIssued: 1,
      };
      Deno.writeTextFileSync(join(dir, "state.json"), JSON.stringify(state));
      Deno.writeTextFileSync(join(dir, "results.jsonl"), "prior\n");
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: dir,
        CCP10_STAGE: "1R",
      });
      assertEquals(result.code, 2, name);
      assert(
        result.stderr.includes("already ran in this directory"),
        result.stderr,
      );
      // Untouched.
      assertEquals(
        JSON.parse(Deno.readTextFileSync(join(dir, "state.json"))),
        state,
      );
      assertEquals(
        Deno.readTextFileSync(join(dir, "results.jsonl")),
        "prior\n",
      );
    }
  } finally {
    Deno.removeSync(base, { recursive: true });
  }
});

Deno.test("rerun: Stage 2 refuses a predecessor that is not the clean rerun", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-pred-" });
  try {
    Deno.writeTextFileSync(
      join(out, "state.json"),
      JSON.stringify({
        mode: "dry",
        runTag: "t",
        accounts: {},
        looks: {},
        finished: [],
        reviewIssued: 0,
      }),
    );
    // A Stage 1 that finished clean, but is the original, failed-review run.
    Deno.writeTextFileSync(
      join(out, "summary-stage1.json"),
      JSON.stringify({
        stop_reason: null,
        run_kind: "stage1",
        cases: { preview_requests: 8, expected_preview_requests: 8 },
      }),
    );
    const result = await runner({
      ...SAFE_ENV,
      CCP10_OUT: out,
      CCP10_STAGE: "2",
    });
    assertEquals(result.code, 2);
    assert(result.stderr.includes("post-remediation rerun"), result.stderr);
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("evidence: every identity feature is recorded by its own name", () => {
  const features = {
    faceShape: "same",
    eyes: "same",
    eyebrows: "same",
    nose: "different",
    mouth: "same",
    skinMarks: "uncertain",
    apparentAge: "different",
    hair: "same",
    framing: "same",
  };
  const recorded = recordValidatorObservations(
    JSON.stringify({
      identityFeatures: features,
      identity: "changed",
      categories: [],
      introducedCategories: [],
    }),
    Object.keys(features),
  ) as { identityFeatures: Record<string, string>; identity: string };
  assertEquals(recorded.identityFeatures, features);
  assertEquals(recorded.identityFeatures.faceShape, "same");
  assertEquals(recorded.identityFeatures.skinMarks, "uncertain");
  assertEquals(recorded.identityFeatures.apparentAge, "different");
  assert(!("invalid" in recorded.identityFeatures));
  assertEquals(recorded.identity, "changed");
});

Deno.test("evidence: missing, unexpected and prose identity values stay visible as codes", () => {
  const names = ["faceShape", "eyes"];
  const recorded = recordValidatorObservations(
    JSON.stringify({
      identityFeatures: { eyes: "They look identical to me", ears: "same" },
      identity: "preserved",
    }),
    names,
  ) as {
    identityFeatures: Record<string, string>;
    unexpectedIdentityFeatures: number;
  };
  assertEquals(recorded.identityFeatures, {
    faceShape: "missing",
    eyes: "invalid",
  });
  assertEquals(recorded.unexpectedIdentityFeatures, 1);
  assertEquals(recordValidatorObservations("not json", names), {
    malformed: true,
  });
});

Deno.test("version lock: v2 passes; v1 or a missing preview version stops", () => {
  const v2 = {
    preview: [REQUIRED_PREVIEW_VERSION, REQUIRED_PREVIEW_VERSION],
    validator: [REQUIRED_VALIDATOR_VERSION, null],
  };
  assertEquals(REQUIRED_PREVIEW_VERSION, "custom_palette_preview_v2");
  assertEquals(REQUIRED_VALIDATOR_VERSION, "custom_palette_validator_v2");
  assertEquals(versionViolation(v2), null);
  assert(
    versionViolation({
      ...v2,
      preview: [...v2.preview, "custom_palette_preview_v1"],
    })
      ?.includes("preview version"),
  );
  assert(
    versionViolation({ ...v2, validator: ["custom_palette_validator_v1"] })
      ?.includes("validator version"),
  );
  assert(
    versionViolation({ ...v2, preview: [null] })?.includes("preview version"),
  );
});

Deno.test("source: only live mode can forward a Gemini request", () => {
  const source = Deno.readTextFileSync(join(HERE, "ccp10_eval.ts"));
  assert(source.includes(`const response = mode === "dry"
    ? provider.answer(kind, body)
    : await realFetch(input, init);`));
  // Exactly two forwards exist: loopback traffic, and that one live branch.
  assertEquals(source.split("realFetch(input, init)").length - 1, 2);
  assert(
    source.includes(
      "if (target.hostname !== GEMINI_HOST) return realFetch(input, init);",
    ),
  );
  // The charge comes before the response, on the one path to the provider.
  assert(
    source.indexOf("budget.charge(kind)") <
      source.indexOf("provider.answer(kind, body)"),
  );
  // Every stop check runs before the charge, and the kill switch before them all.
  const charge = source.indexOf("budget.charge(kind)");
  assert(
    source.indexOf("if (stopLoss.reason) throw new GuardRefusal") < charge,
  );
  assert(source.indexOf("stageViolation(stage, kind)") < charge);
  assert(source.indexOf("paletteViolation({") < charge);
  // No prompt tuning, and no stored credentials.
  assert(!source.includes("password:") || !source.includes('"password"'));
});

// ---------------------------------------------------------------------------
// GEMINI_MANIFEST_MODEL is the text model or unset, checked before anything runs
// ---------------------------------------------------------------------------

Deno.test("the manifest model is the text model, or unset", () => {
  for (const allowed of [undefined, "", "  ", "gemini-3.6-flash"]) {
    assertEquals(manifestModelViolation(allowed), null, `${allowed}`);
  }
  assert(
    manifestModelViolation("gemini-3.1-flash-image")?.includes("image model"),
  );
  assert(
    manifestModelViolation(" gemini-3.1-flash-image ")?.includes("image model"),
  );
  for (
    const refused of [
      "gemini-9",
      "gemini-3.6-pro",
      "gemini-3.6-flash-lite",
      "gemini-3-pro-image",
      "models/gemini-3.6-flash",
      "gemini-3.6-flash:generateContent",
      "GEMINI-3.6-FLASH",
      " gemini-3.6-flash",
      "gemini-3.6-flash\n",
      "gemini-3.6-flash,gemini-3.1-flash-image",
    ]
  ) {
    assert(
      manifestModelViolation(refused)?.includes("must be gemini-3.6-flash"),
      JSON.stringify(refused),
    );
  }
});

Deno.test("source: the manifest analyzer's default is the approved text model", () => {
  const source = Deno.readTextFileSync(
    join(ROOT, "supabase/functions/analyze-tutorial-manifest-v4/index.ts"),
  );
  const found = source.match(
    /Deno\.env\.get\("GEMINI_MANIFEST_MODEL"\)\?\.trim\(\) \|\|\s*"([^"]+)"/,
  );
  assertEquals(found?.[1], "gemini-3.6-flash");
  // That default is the model a manifest request is charged as a manifest on.
  assertEquals(
    classifyProviderRequest(
      `/v1beta/models/${found![1]}:generateContent`,
      "You are comparing two photographs",
    ),
    "manifest",
  );
  assertEquals(stageViolation(2, "manifest"), null);
  assert(stageViolation(1, "manifest")?.includes("forbids"));
});

const LIVE_NET = "127.0.0.1,generativelanguage.googleapis.com";
const manifestRefusals: Array<[string, Record<string, string>, string?]> = [
  ["the image model", { GEMINI_MANIFEST_MODEL: "gemini-3.1-flash-image" }],
  ["an unknown model", { GEMINI_MANIFEST_MODEL: "gemini-9" }],
  ["a malformed model", {
    GEMINI_MANIFEST_MODEL: "models/gemini-3.6-flash:generateContent",
  }],
  ["the image model on an authorized Stage 2", {
    GEMINI_MANIFEST_MODEL: "gemini-3.1-flash-image",
    CCP10_MODE: "live",
    CCP10_STAGE: "2",
    CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[2],
  }, LIVE_NET],
  ["the image model on Stage 1", {
    GEMINI_MANIFEST_MODEL: "gemini-3.1-flash-image",
    CCP10_MODE: "live",
    CCP10_LIVE_AUTHORIZATION: LIVE_AUTHORIZATION[1],
  }, LIVE_NET],
];

function liveBudgetBytes(): string | null {
  const home = Deno.env.get("USERPROFILE") ?? Deno.env.get("HOME") ?? "";
  try {
    return Deno.readTextFileSync(
      `${home}/.facetune-eval/ccp10-live-budget.json`,
    );
  } catch {
    return null;
  }
}

for (const [name, overrides, net] of manifestRefusals) {
  Deno.test(`the runner refuses ${name} as the manifest model, before any call or charge`, async () => {
    const out = Deno.makeTempDirSync({ prefix: "ccp10-manifest-" });
    const before = liveBudgetBytes();
    try {
      const run = join(out, "run");
      const { code, stderr } = await runner(
        { ...SAFE_ENV, CCP10_OUT: run, ...overrides },
        net,
      );
      assertEquals(code, 2, stderr);
      assert(stderr.includes("GEMINI_MANIFEST_MODEL"), stderr);
      // Refused before the output folder, the budget, or any handler existed.
      assertThrows(() => Deno.statSync(run), Deno.errors.NotFound);
      assertEquals(liveBudgetBytes(), before);
    } finally {
      Deno.removeSync(out, { recursive: true });
    }
  });
}

Deno.test("the approved manifest model, or none, passes startup to the next check", async () => {
  for (const value of ["gemini-3.6-flash", ""]) {
    const out = Deno.makeTempDirSync({ prefix: "ccp10-manifest-" });
    try {
      // Live without a token is refused by the authorization check, which runs
      // after the model checks: reaching it proves the model was accepted.
      const { code, stderr } = await runner(
        {
          ...SAFE_ENV,
          CCP10_OUT: join(out, "run"),
          CCP10_MODE: "live",
          CCP10_STAGE: "2",
          GEMINI_MANIFEST_MODEL: value,
        },
        LIVE_NET,
      );
      assertEquals(code, 2, stderr);
      assert(stderr.includes("exact authorization"), stderr);
      assert(!stderr.includes("GEMINI_MANIFEST_MODEL"), stderr);
    } finally {
      Deno.removeSync(out, { recursive: true });
    }
  }
});

// ---------------------------------------------------------------------------
// H9: protected source equals the authorized remediation, 56546aa
// ---------------------------------------------------------------------------

// A git checkout holding the baseline. The scratch copies these tests run from
// are not repositories, so the run passes one in.
const H9_REPO = Deno.env.get("CCP10_TEST_REPO") ?? ROOT;
const PRE_REMEDIATION = "2b29652";
const RERUN_HEAD = "e6fdb43e4e465d6b931be31e9fa893b03a5f8415";

function git(repo: string, ...args: string[]): string {
  const output = new Deno.Command("git", {
    args: ["-C", repo, "-c", "core.longpaths=true", ...args],
    stdout: "piped",
    stderr: "piped",
  }).outputSync();
  if (output.code !== 0) {
    throw new Error(
      `git ${args.join(" ")}: ${new TextDecoder().decode(output.stderr)}`,
    );
  }
  return new TextDecoder().decode(output.stdout).trim();
}

/** A disposable clone of lib and supabase at a commit, so no worktree is edited. */
function cloneAt(commit: string): { repo: string; dispose: () => void } {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-h9-" });
  const repo = join(dir, "r");
  git(dir, "clone", "--quiet", "--shared", "--no-checkout", H9_REPO, repo);
  // Line endings fixed in the clone itself, so a runner with another HOME (and no
  // global git config) sees the same tree.
  git(repo, "config", "core.autocrlf", "false");
  git(repo, "sparse-checkout", "set", "lib", "supabase");
  git(repo, "checkout", "--quiet", "--detach", commit);
  return { repo, dispose: () => Deno.removeSync(dir, { recursive: true }) };
}

Deno.test("H9: the baseline is the authorized remediation, not the stale one", () => {
  assertEquals(git(H9_REPO, "rev-parse", "56546aa"), PROTECTED_BASELINE);
  assertEquals(
    git(H9_REPO, "log", "-1", "--format=%s", PROTECTED_BASELINE),
    "fix(ccp): harden preview identity and palette validation",
  );
  const runnerSource = Deno.readTextFileSync(join(HERE, "ccp10_eval.ts"));
  assert(!runnerSource.includes(PRE_REMEDIATION));
  assert(!runnerSource.includes("PROTECTED_BASELINE ="));
  assert(runnerSource.includes("protectedSourceCheck(repoCheck)"));
});

Deno.test("H9: no protected path was dropped from the gate the rerun used", () => {
  const before = git(
    H9_REPO,
    "show",
    `${RERUN_HEAD}:supabase/tests/controlled/ccp10_eval.ts`,
  );
  assert(before.includes(`const PROTECTED_BASELINE = "${PRE_REMEDIATION}";`));
  const block = before.match(/const PROTECTED_PATHS = \[([\s\S]*?)\];/)![1];
  const old = [...block.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  assertEquals(old.length, 11);
  assertEquals([...PROTECTED_PATHS], old);
});

Deno.test("H9: the remediation changed only CCP preview code", () => {
  const changed = git(
    H9_REPO,
    "diff",
    "--name-only",
    PRE_REMEDIATION,
    PROTECTED_BASELINE,
    "--",
    ...PROTECTED_PATHS,
  ).split("\n").filter(Boolean);
  assert(changed.length > 0);
  for (const file of changed) {
    assert(
      file.startsWith("supabase/functions/generate-custom-palette-preview/"),
      file,
    );
  }
});

Deno.test("H9: the baseline and harness-only descendants pass; protected drift fails", async (t) => {
  const { repo, dispose } = cloneAt(PROTECTED_BASELINE);
  const restore = () => {
    git(repo, "reset", "--quiet", "--hard");
    git(repo, "clean", "--quiet", "-fd", "--", "lib", "supabase");
  };
  const edit = (file: string) => {
    const path = join(repo, file);
    Deno.statSync(path);
    Deno.writeTextFileSync(path, "\n// drift\n", { append: true });
  };
  try {
    await t.step("the exact tree at 56546aa passes", () => {
      assertEquals(protectedSourceCheck(repo), "PASS");
    });
    await t.step("the stale baseline would fail the same tree", () => {
      assertEquals(protectedSourceCheck(repo, PRE_REMEDIATION), "FAIL");
    });
    await t.step("an unknown baseline fails closed", () => {
      assertEquals(protectedSourceCheck(repo, "0".repeat(40)), "FAIL");
    });
    const drift: Array<[string, string]> = [
      [
        "CCP preview after 56546aa",
        "supabase/functions/generate-custom-palette-preview/prompt.ts",
      ],
      [
        "CCP validator after 56546aa",
        "supabase/functions/generate-custom-palette-preview/validator_prompt.ts",
      ],
      [
        "CCP recommendation",
        "supabase/functions/generate-custom-palette-recommendation/prompt.ts",
      ],
      [
        "Standard Recommendation",
        "supabase/functions/generate-makeup-recommendation/prompt.ts",
      ],
      [
        "Standard Final Preview",
        "supabase/functions/generate-makeup-preview/index.ts",
      ],
      [
        "My Makeup Kit Recommendation",
        "supabase/functions/generate-kit-makeup-recommendation/index.ts",
      ],
      [
        "My Makeup Kit Final Preview",
        "supabase/functions/generate-kit-makeup-preview/prompt.ts",
      ],
      [
        "Tutorial V4 step",
        "supabase/functions/generate-tutorial-step-v4/index.ts",
      ],
      [
        "Tutorial V4 manifest",
        "supabase/functions/analyze-tutorial-manifest-v4/prompt.ts",
      ],
      ["face analysis", "supabase/functions/analyze-face/prompt.ts"],
      [
        "subscription client source",
        "lib/features/subscription/data/data_sources/google_play_billing_data_source.dart",
      ],
      [
        "a subscription migration",
        "supabase/migrations/20260907000200_subscription_entitlement_resolver.sql",
      ],
    ];
    for (const [label, file] of drift) {
      await t.step(`modifying ${label} fails`, () => {
        edit(file);
        assertEquals(protectedSourceCheck(repo), "FAIL");
        restore();
        assertEquals(protectedSourceCheck(repo), "PASS");
      });
    }
    await t.step("a staged protected change fails", () => {
      edit("lib/main.dart");
      git(repo, "add", "lib/main.dart");
      assertEquals(protectedSourceCheck(repo), "FAIL");
      restore();
    });
    await t.step("a deleted protected file fails", () => {
      Deno.removeSync(
        join(repo, "supabase/functions/generate-makeup-preview/index.ts"),
      );
      assertEquals(protectedSourceCheck(repo), "FAIL");
      restore();
    });
    await t.step("a new untracked migration or module fails", () => {
      for (
        const file of [
          "supabase/migrations/20991231000000_unreviewed.sql",
          "supabase/functions/generate-makeup-recommendation/extra.ts",
        ]
      ) {
        Deno.writeTextFileSync(join(repo, file), "select 1;\n");
        assertEquals(protectedSourceCheck(repo), "FAIL", file);
        restore();
      }
    });
    await t.step("harness-only changes do not fail", () => {
      edit("supabase/tests/controlled/ccp10_plan.ts");
      Deno.writeTextFileSync(
        join(repo, "supabase/tests/controlled/ccp10_note.ts"),
        "export {};\n",
      );
      assertEquals(protectedSourceCheck(repo), "PASS");
      restore();
    });
    await t.step("the harness-only rerun commit after 56546aa passes", () => {
      git(repo, "checkout", "--quiet", "--detach", RERUN_HEAD);
      assertEquals(protectedSourceCheck(repo), "PASS");
    });
  } finally {
    dispose();
  }
});

// ---------------------------------------------------------------------------
// Stage 2 readiness: budget, token, case set, start gates
// ---------------------------------------------------------------------------

const STAGE_2_TOKEN = "CCP-10-STAGE-2:71-cases:366-calls";
/** The H9 check runs git, as the live scripts allow. */
const RUN_GIT = ["--allow-run=git"];

Deno.test("Stage 2 budget: 65 prior + 366 = 431, under the 440 global ceiling", () => {
  assertEquals(TOTAL_CEILING, 440);
  assertEquals(STAGE_2_CEILING, 366);
  assertEquals(runCeiling("2", 65), 431);
  assertEquals(runCeiling("2", 0), 366);
  assertEquals(stage2BudgetViolation(65), null);
  assertEquals(stage2BudgetViolation(74), null);
  assert(stage2BudgetViolation(75)?.includes("does not fit"));
  assert(stage2BudgetViolation(440)?.includes("does not fit"));
  // No run kind, at any spend, may count past the global ceiling.
  for (let spent = 0; spent <= 440; spent += 1) {
    for (const kind of ["1", "2", "R1", "1R"] as const) {
      assert(runCeiling(kind, spent) <= TOTAL_CEILING, `${kind} ${spent}`);
    }
  }
});

Deno.test("Stage 2 budget: the 65 prior calls stay, and exactly 366 new ones fit", () => {
  const dir = Deno.makeTempDirSync({ prefix: "ccp10-stage2-budget-" });
  const path = join(dir, "ccp10-live-budget.json");
  const prior = {
    total: 65,
    byKind: { analysis: 8, recommendation: 19, image: 19, validator: 19 },
  };
  Deno.writeTextFileSync(path, JSON.stringify(prior));
  try {
    const budget = new CallBudget(path, runCeiling("2", 65));
    assertEquals(budget.total, 65);
    assertEquals(JSON.parse(Deno.readTextFileSync(path)), prior);
    let charged = 0;
    while (true) {
      try {
        budget.charge("guideline");
        charged += 1;
      } catch (error) {
        assert(error instanceof CeilingReached);
        break;
      }
    }
    assertEquals(charged, 366);
    const after = JSON.parse(Deno.readTextFileSync(path));
    assertEquals(after.total, 431);
    assertEquals(after.byKind.analysis, 8);
    assertEquals(after.byKind.recommendation, 19);
    assertEquals(after.byKind.image, 19);
    assertEquals(after.byKind.validator, 19);
    // A restart reads 431 back: it cannot become a fresh 440-call budget, only 9
    // calls remain globally, and a second Stage 2 would refuse to start.
    const again = new CallBudget(path, runCeiling("2", 431));
    assertEquals(again.total, 431);
    assertEquals(again.ceiling, 440);
    assertEquals(again.remaining, 9);
    assert(stage2BudgetViolation(again.total)?.includes("does not fit"));
  } finally {
    Deno.removeSync(dir, { recursive: true });
  }
});

Deno.test("Stage 2 token: exact, unique, and not any other run's", () => {
  assertEquals(LIVE_AUTHORIZATION[2], STAGE_2_TOKEN);
  assertEquals(authorizationFor("2"), STAGE_2_TOKEN);
  const tokens = [
    authorizationFor("1"),
    authorizationFor("2"),
    authorizationFor("R1"),
    authorizationFor("1R"),
  ];
  assertEquals(new Set(tokens).size, 4);
});

Deno.test("Stage 2 is exactly the 71 accepted cases, within 366 calls", () => {
  const stage2 = ALL_CASES.filter((c) => c.stage === 2);
  assertEquals(stage2.length, 71);
  const kinds: Record<string, number> = {};
  for (const c of stage2) kinds[c.kind] = (kinds[c.kind] ?? 0) + 1;
  assertEquals(kinds, { look: 47, variation: 6, tutorial: 6, probe: 12 });
  const stage1Ids = new Set(
    ALL_CASES.filter((c) => c.stage === 1).map((c) => c.id),
  );
  assertEquals(stage1Ids.size, 8);
  assert(stage2.every((c) => !stage1Ids.has(c.id)));
  // Its 3 new accounts are analyzed; the 3 Stage 1 accounts carry over.
  const newAccounts = ACCOUNTS.filter((a) => !STAGE_1_ACCOUNTS.includes(a));
  assertEquals(newAccounts, ["S1b", "S2b", "S3b"]);
  assertEquals(
    newAccounts.length * 2 +
      stage2.reduce((sum, c) => sum + worstCaseFor(c), 0),
    STAGE_2_CEILING,
  );
});

Deno.test("Stage 2 refuses every other run's token", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage2-token-" });
  try {
    for (
      const token of [
        LIVE_AUTHORIZATION[1],
        REMEDIATION_AUTHORIZATION,
        STAGE_1_RERUN_AUTHORIZATION,
        "CCP-10-STAGE-2:79-cases:420-calls",
        `${STAGE_2_TOKEN} `,
        "",
      ]
    ) {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_MODE: "live",
        CCP10_STAGE: "2",
        CCP10_LIVE_AUTHORIZATION: token,
      }, LIVE_NET);
      assertEquals(result.code, 2, token);
      assert(result.stderr.includes("exact authorization"), result.stderr);
    }
    // And its own token authorizes nothing else.
    for (const stage of ["1", "R1", "1R"]) {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_MODE: "live",
        CCP10_STAGE: stage,
        CCP10_LIVE_AUTHORIZATION: STAGE_2_TOKEN,
      }, LIVE_NET);
      assertEquals(result.code, 2, stage);
      assert(result.stderr.includes("exact authorization"), result.stderr);
    }
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("there is no stage after 2: CCP-11 and CCP-12 cannot start from here", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage3-" });
  try {
    for (const stage of ["3", "11", "12", "CCP-11", "CCP-12", "2R", " 2"]) {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_STAGE: stage,
      });
      assertEquals(result.code, 2, stage);
      assert(result.stderr.includes("1, 2, R1, or 1R"), result.stderr);
    }
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
  const source = Deno.readTextFileSync(join(HERE, "ccp10_eval.ts"));
  assert(!/CCP-1[12]/.test(source));
});

Deno.test("Stage 2 keeps the model locks", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage2-models-" });
  try {
    for (
      const name of [
        "GEMINI_MODEL",
        "GEMINI_IMAGE_MODEL",
        "GEMINI_TUTORIAL_MODEL",
      ]
    ) {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: join(out, "run"),
        CCP10_STAGE: "2",
        [name]: "gemini-3.6-flash",
      });
      assertEquals(result.code, 2, name);
      assert(result.stderr.includes("models are locked"), result.stderr);
    }
  } finally {
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("Stage 2 live start: budget history, H9 repository, key file are required", async () => {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage2-live-" });
  const home = join(out, "home");
  Deno.mkdirSync(join(home, ".facetune-eval"), { recursive: true });
  const live = {
    ...SAFE_ENV,
    CCP10_OUT: join(out, "run"),
    CCP10_MODE: "live",
    CCP10_STAGE: "2",
    CCP10_LIVE_AUTHORIZATION: STAGE_2_TOKEN,
    USERPROFILE: home,
    HOME: home,
  };
  const { repo, dispose } = cloneAt(PROTECTED_BASELINE);
  try {
    const noRepo = await runner(live, LIVE_NET);
    assertEquals(noRepo.code, 2);
    assert(noRepo.stderr.includes("CCP10_REPO"), noRepo.stderr);
    // With no budget history it cannot begin a fresh budget.
    const noBudget = await runner(
      { ...live, CCP10_REPO: repo },
      LIVE_NET,
      "--allow-read",
      RUN_GIT,
    );
    assertEquals(noBudget.code, 2);
    assert(noBudget.stderr.includes("live budget history"), noBudget.stderr);
    Deno.writeTextFileSync(
      join(home, ".facetune-eval", "ccp10-live-budget.json"),
      JSON.stringify({ total: 65, byKind: {} }),
    );
    const noKey = await runner(
      { ...live, CCP10_REPO: repo },
      LIVE_NET,
      "--allow-read",
      RUN_GIT,
    );
    assertEquals(noKey.code, 2);
    assert(noKey.stderr.includes("CCP10_KEY_FILE"), noKey.stderr);
    const keyInRepo = await runner(
      {
        ...live,
        CCP10_REPO: repo,
        CCP10_KEY_FILE: join(ROOT, "supabase/config.toml"),
      },
      LIVE_NET,
      "--allow-read",
      RUN_GIT,
    );
    assertEquals(keyInRepo.code, 2);
    assert(keyInRepo.stderr.includes("CCP10_KEY_FILE"), keyInRepo.stderr);
    assertThrows(() => Deno.statSync(join(out, "run")), Deno.errors.NotFound);
  } finally {
    dispose();
    Deno.removeSync(out, { recursive: true });
  }
});

/** A Stage 2 directory seeded as a clean Stage 1 rerun would leave it. */
function stage2Directory(
  gates: Record<string, string> = {},
  extra: Record<string, string> = {},
): string {
  const out = Deno.makeTempDirSync({ prefix: "ccp10-stage2-dir-" });
  Deno.writeTextFileSync(
    join(out, "state.json"),
    JSON.stringify({
      mode: "dry",
      runTag: "seed",
      accounts: {},
      looks: {},
      finished: [],
      reviewIssued: 0,
    }),
  );
  Deno.writeTextFileSync(
    join(out, "summary-stage1.json"),
    JSON.stringify({
      run_kind: "stage1_post_remediation_rerun",
      stop_reason: null,
      cases: { preview_requests: 8, expected_preview_requests: 8 },
      gates: {
        H1_palette_preserved: "PASS",
        H2_no_ai_color_stored: "PASS",
        H3_palette_identical_across_attempts: "PASS",
        H4_accounting_exact: "PASS",
        ...gates,
      },
    }),
  );
  for (const [name, text] of Object.entries(extra)) {
    Deno.writeTextFileSync(join(out, name), text);
  }
  return out;
}

const stage2Refusals: Array<
  [string, Record<string, string>, Record<string, string>, string]
> = [
  [
    "a Stage 1 gate that did not pass",
    { H4_accounting_exact: "FAIL" },
    {},
    "H4_accounting_exact",
  ],
  [
    "a Stage 1 gate that is missing",
    { H2_no_ai_color_stored: "" },
    {},
    "H2_no_ai_color_stored",
  ],
  ["a directory where Stage 2 already ran", {}, {
    "summary-stage2.json": "{}",
  }, "already ran"],
  ["a budget whose Stage 2 worst case no longer fits", {}, {
    "budget.json": JSON.stringify({ total: 75, byKind: {} }),
  }, "does not fit"],
];

for (const [name, gates, extra, message] of stage2Refusals) {
  Deno.test(`Stage 2 refuses ${name}`, async () => {
    const out = stage2Directory(gates, extra);
    const before = [...Deno.readDirSync(out)].map((e) => e.name).sort();
    try {
      const result = await runner({
        ...SAFE_ENV,
        CCP10_OUT: out,
        CCP10_STAGE: "2",
      });
      assertEquals(result.code, 2, result.stderr);
      assert(result.stderr.includes(message), result.stderr);
      // Refused without writing a result or a summary.
      assertEquals(
        [...Deno.readDirSync(out)].map((e) => e.name).filter((n) =>
          n !== "review"
        )
          .sort(),
        before,
      );
    } finally {
      Deno.removeSync(out, { recursive: true });
    }
  });
}

Deno.test("Stage 2 refuses protected source that is not the H9 baseline", async () => {
  const out = stage2Directory();
  const { repo, dispose } = cloneAt(PROTECTED_BASELINE);
  try {
    Deno.writeTextFileSync(
      join(repo, "supabase/functions/generate-makeup-recommendation/prompt.ts"),
      "\n// drift\n",
      { append: true },
    );
    const result = await runner(
      {
        ...SAFE_ENV,
        CCP10_OUT: out,
        CCP10_STAGE: "2",
        CCP10_REPO: repo,
      },
      "127.0.0.1",
      "--allow-read",
      RUN_GIT,
    );
    assertEquals(result.code, 2, result.stderr);
    assert(result.stderr.includes("H9 baseline"), result.stderr);
  } finally {
    dispose();
    Deno.removeSync(out, { recursive: true });
  }
});

Deno.test("production and unknown hosts are refused", () => {
  for (
    const host of [
      "abc.supabase.co",
      "facetune.supabase.co",
      "api.supabase.com",
      "androidpublisher.googleapis.com",
      "127.0.0.1.example.com",
    ]
  ) {
    assertThrows(() => assertAllowedHost(host), GuardRefusal, undefined, host);
  }
  assertThrows(
    () => assertLoopbackDatabase("https://abc.supabase.co"),
    GuardRefusal,
  );
});

Deno.test("source: Stage 2 checks the next case's worst case, and the retry bound", () => {
  const source = Deno.readTextFileSync(join(HERE, "ccp10_eval.ts"));
  const loop = source.indexOf("for (const evalCase of queue) {");
  const fit = source.indexOf(
    "if (budget.total + worstCaseFor(evalCase) > budget.ceiling) {",
  );
  const start = source.indexOf("current = newRecord();", loop);
  assert(loop > 0 && loop < fit && fit < start);
  assert(
    source.includes(
      'if (attempts.length > 2) accounting.push("retry_bound_exceeded");',
    ),
  );
  assert(source.includes("stage2BudgetViolation(spentBefore)"));
});
