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
  assertAllowedHost,
  assertLoopbackDatabase,
  assertOutsideRepository,
  assertThrowawayContainer,
  CallBudget,
  CeilingReached,
  classifyProviderRequest,
  findLeak,
  GuardRefusal,
  readReviewSheet,
  REVIEW_COLUMNS,
  reviewStopReason,
  samePalette,
  StopLoss,
  wilson,
} from "./ccp10_guards.ts";
import {
  ACCOUNTS,
  ALL_CASES,
  type Category,
  LIVE_AUTHORIZATION,
  LOOKS,
  PROBES,
  probeTarget,
  selfieOf,
  STAGE_1_ACCOUNTS,
  STAGE_1_CEILING,
  stepsOf,
  STYLES,
  TOTAL_CEILING,
  TUTORIALS,
  VARIATIONS,
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

Deno.test("worst-case arithmetic equals both ceilings exactly", () => {
  assertEquals(worstCaseThroughStage(1), STAGE_1_CEILING);
  assertEquals(worstCaseThroughStage(2), TOTAL_CEILING);
  assertEquals(STAGE_1_CEILING, 54);
  assertEquals(TOTAL_CEILING, 420);
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
): Promise<{ code: number; stderr: string }> {
  const output = await new Deno.Command(Deno.execPath(), {
    args: [
      "run",
      "--no-lock",
      "--allow-env",
      "--allow-read",
      "--allow-write",
      "--allow-sys",
      `--allow-net=${allowNet}`,
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
  // No prompt tuning, and no stored credentials.
  assert(!source.includes("password:") || !source.includes('"password"'));
});
