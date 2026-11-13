/**
 * CCP-10 — proves each Stage 1 stop end to end by running the real runner with an
 * injected fault against the throwaway stack. Every run is simulated: the process
 * holds no network permission for Gemini and no key.
 *
 * Run from `supabase/functions` with the LOCAL_* variables and CCP10_TEST_WORKSPACE,
 * from a harness copy inside that protected workspace:
 *   deno test --no-lock --allow-all ../tests/controlled/ccp10_gates_test.ts
 */
import { assert, assertEquals } from "jsr:@std/assert@1";
import { dirname, fromFileUrl, join } from "jsr:@std/path@1";

import { ALL_CASES } from "./ccp10_plan.ts";

const HERE = dirname(fromFileUrl(import.meta.url));
const FUNCTIONS = join(HERE, "..", "..", "functions");
const WORKSPACE = Deno.env.get("CCP10_TEST_WORKSPACE") ?? "";
if (!WORKSPACE) throw new Error("CCP10_TEST_WORKSPACE is required.");

interface Summary {
  simulated: boolean;
  stop_reason: string | null;
  provider_calls: {
    total: number;
    ceiling: number;
    by_kind: Record<string, number>;
  };
  cases: { preview_requests: number; results_recorded: number };
  gates: Record<string, string>;
  evidence_complete: boolean;
  violations: string[];
  leak_scan: { logs: unknown; results: unknown };
}

let runs = 0;
async function run(env: Record<string, string> = {}) {
  runs += 1;
  const out = join(WORKSPACE, "out", `gate-${crypto.randomUUID().slice(0, 8)}`);
  const output = await new Deno.Command(Deno.execPath(), {
    args: [
      "run",
      "--no-lock",
      "--allow-env",
      "--allow-read",
      `--allow-write=${out}`,
      "--allow-sys",
      "--allow-run=docker,icacls",
      "--allow-net=127.0.0.1,localhost",
      join(HERE, "ccp10_eval.ts"),
    ],
    cwd: FUNCTIONS,
    env: {
      CCP10_MODE: "dry",
      CCP10_STAGE: "1",
      CCP10_OUT: out,
      CCP10_WORKSPACE: WORKSPACE,
      ...env,
    },
    stdout: "null",
    stderr: "piped",
  }).output();
  const summary = JSON.parse(
    Deno.readTextFileSync(join(out, "summary-stage1.json")),
  ) as Summary;
  const rows = Deno.readTextFileSync(join(out, "results.jsonl")).split("\n")
    .filter(Boolean).map((line) => JSON.parse(line));
  return { code: output.code, summary, rows, out };
}

Deno.test("normal simulated Stage 1, in the protected workspace, with full evidence", async () => {
  const { code, summary, rows, out } = await run();
  assertEquals(code, 0);
  assertEquals(summary.simulated, true);
  assertEquals(summary.stop_reason, null);
  assertEquals(summary.cases.preview_requests, 8);
  assert(summary.provider_calls.total <= 54);
  assertEquals(summary.provider_calls.ceiling, 54);
  assertEquals(summary.evidence_complete, true);
  assertEquals(summary.violations, []);
  assertEquals(summary.leak_scan.logs, "clean");
  assertEquals(summary.leak_scan.results, "clean");
  for (
    const gate of [
      "H1_palette_preserved",
      "H2_no_ai_color_stored",
      "H3_palette_identical_across_attempts",
      "H4_accounting_exact",
    ]
  ) {
    assertEquals(summary.gates[gate], "PASS", gate);
  }
  for (const row of rows) {
    const e = row.evidence;
    assert(/^[0-9a-f-]{36}$/.test(e.operation_id), row.id);
    assert(/^[0-9a-f-]{36}$/.test(e.palette_id), row.id);
    assert(/^[0-9a-f]{64}$/.test(e.palette_digest), row.id);
    assertEquals(e.digest_recomputed_consistent, true, row.id);
    assertEquals(e.accepted_attempt_number, 1, row.id);
    assertEquals(e.validator_outcome, "accepted", row.id);
    assert(typeof e.latency_ms === "number", row.id);
    assertEquals(e.retry_count, 0, row.id);
    assertEquals(e.usage_reservation, "reserved", row.id);
    assertEquals(e.usage_result, "committed", row.id);
  }
  // Stage 1 ends there: nothing from Stage 2 ran, and no Stage 2 summary exists.
  assertEquals(rows.length, 8);
  assert(rows.every((r) => !/^(F-|G-|N-|E-|H)/.test(r.id)));
  let stage2 = true;
  try {
    Deno.statSync(join(out, "summary-stage2.json"));
  } catch {
    stage2 = false;
  }
  assertEquals(stage2, false);
});

Deno.test("palette mutation on a retry stops at once, before the call", async () => {
  const { code, summary, rows } = await run({
    CCP10_DRY_INJECT: "palette_mutation",
  });
  assertEquals(code, 3);
  assert(
    summary.stop_reason?.includes("frozen palette changed"),
    summary.stop_reason ?? "",
  );
  assert(summary.violations.some((v) => String(v).includes("frozen palette")));
  // 3 analyses, 1 plan, 1 image, 1 validator. The mutated image never left.
  assertEquals(summary.provider_calls.total, 6);
  assertEquals(summary.provider_calls.by_kind.image, 1);
  assertEquals(
    rows.filter((r) => r.kind === "look").length,
    1,
    "remaining cases did not run",
  );
});

Deno.test("validator bypass stops at once, and the preview is not offered for review", async () => {
  const { code, summary, rows, out } = await run({
    CCP10_DRY_INJECT: "validator_bypass",
  });
  assertEquals(code, 3);
  assert(
    summary.stop_reason?.includes("without an accepting validator"),
    summary.stop_reason ?? "",
  );
  assertEquals(
    rows.filter((r) => r.kind === "look").length,
    1,
    "remaining cases did not run",
  );
  assertEquals([...Deno.readDirSync(join(out, "review"))].length, 0);
});

for (
  const [inject, word] of [["manifest_call", "manifest"], [
    "guideline_call",
    "guideline",
  ]]
) {
  Deno.test(`a ${word} call in Stage 1 is refused, recorded, and stops the run`, async () => {
    const { code, summary, rows } = await run({ CCP10_DRY_INJECT: inject });
    assertEquals(code, 3);
    assertEquals(summary.stop_reason, `Stage 1 forbids a ${word} call`);
    assertEquals(summary.violations, [`Stage 1 forbids a ${word} call`]);
    assertEquals(
      summary.provider_calls.by_kind[word],
      undefined,
      "never charged or sent",
    );
    assertEquals(
      summary.provider_calls.total,
      3,
      "only the 3 setup analyses ran",
    );
    assertEquals(
      rows.filter((r) => r.kind === "look").length,
      0,
      "no case ran",
    );
  });
}

Deno.test("the targeted remediation run is exactly three cases and cannot lead to Stage 2", async () => {
  const out = join(
    WORKSPACE,
    "out",
    `gate-r1-${crypto.randomUUID().slice(0, 8)}`,
  );
  const command = (stage: string) =>
    new Deno.Command(Deno.execPath(), {
      args: [
        "run",
        "--no-lock",
        "--allow-env",
        "--allow-read",
        `--allow-write=${out}`,
        "--allow-sys",
        "--allow-run=docker,icacls",
        "--allow-net=127.0.0.1,localhost",
        join(HERE, "ccp10_eval.ts"),
      ],
      cwd: FUNCTIONS,
      env: {
        CCP10_MODE: "dry",
        CCP10_STAGE: stage,
        CCP10_OUT: out,
        CCP10_WORKSPACE: WORKSPACE,
      },
      stdout: "null",
      stderr: "piped",
    }).output();
  const r1 = await command("R1");
  assertEquals(r1.code, 0, new TextDecoder().decode(r1.stderr));
  const summary = JSON.parse(
    Deno.readTextFileSync(join(out, "summary-remediation-r1.json")),
  ) as Summary;
  assertEquals(summary.stop_reason, null);
  assertEquals(summary.cases.preview_requests, 3);
  assertEquals(summary.provider_calls.ceiling, 22);
  assert(summary.provider_calls.total <= 22);
  assertEquals(summary.evidence_complete, true);
  assertEquals(summary.gates.H4_accounting_exact, "PASS");
  const rows = Deno.readTextFileSync(join(out, "results.jsonl")).split("\n")
    .filter(Boolean).map((line) => JSON.parse(line));
  assertEquals(rows.map((r) => r.id).sort(), [
    "A-eyeliner-Violet",
    "C-eyeshadow-glitter",
    "D6",
  ]);
  // No Stage 1 summary exists here, so Stage 2 refuses to start from this run.
  const stage2 = await command("2");
  assertEquals(stage2.code, 2);
  assert(
    new TextDecoder().decode(stage2.stderr).includes("Stage 1's summary"),
  );
});

for (
  const [inject, word] of [["preview_v1", "preview"], [
    "validator_v1",
    "validator",
  ]]
) {
  Deno.test(`a ${word} v1 version stops the run at once and blocks later calls`, async () => {
    const { code, summary, rows, out } = await run({
      CCP10_DRY_INJECT: inject,
    });
    assertEquals(code, 3);
    assert(
      summary.stop_reason?.includes(`${word} version is not`),
      summary.stop_reason ?? "",
    );
    assert(
      summary.violations.some((v) => String(v).includes(`${word} version`)),
    );
    // 3 setup analyses and one case's 3 calls; nothing after the stop.
    assertEquals(summary.provider_calls.total, 6);
    assertEquals(rows.filter((r) => r.kind === "look").length, 1);
    assertEquals([...Deno.readDirSync(join(out, "review"))].length, 0);
  });
}

Deno.test("the Stage 1 rerun runs the 8 Stage 1 cases, alone, with full identity evidence", async () => {
  const out = join(
    WORKSPACE,
    "out",
    `gate-1r-${crypto.randomUUID().slice(0, 8)}`,
  );
  const command = (stage: string) =>
    new Deno.Command(Deno.execPath(), {
      args: [
        "run",
        "--no-lock",
        "--allow-env",
        "--allow-read",
        `--allow-write=${out}`,
        "--allow-sys",
        "--allow-run=docker,icacls",
        "--allow-net=127.0.0.1,localhost",
        join(HERE, "ccp10_eval.ts"),
      ],
      cwd: FUNCTIONS,
      env: {
        CCP10_MODE: "dry",
        CCP10_STAGE: stage,
        CCP10_OUT: out,
        CCP10_WORKSPACE: WORKSPACE,
      },
      stdout: "null",
      stderr: "piped",
    }).output();
  const rerun = await command("1R");
  assertEquals(rerun.code, 0, new TextDecoder().decode(rerun.stderr));
  const summary = JSON.parse(
    Deno.readTextFileSync(join(out, "summary-stage1.json")),
  ) as Summary & {
    run: string;
    run_kind: string;
    live_budget: {
      spent_before: number;
      ceiling: number;
      new_call_allowance: number;
    };
  };
  assertEquals(summary.run, "Stage 1 Post-Remediation Rerun");
  assertEquals(summary.run_kind, "stage1_post_remediation_rerun");
  assertEquals(summary.stop_reason, null);
  assertEquals(summary.cases.preview_requests, 8);
  assertEquals(summary.live_budget.new_call_allowance, 54);
  assert(summary.provider_calls.total <= 54);
  assertEquals(summary.evidence_complete, true);
  const rows = Deno.readTextFileSync(join(out, "results.jsonl")).split("\n")
    .filter(Boolean).map((line) => JSON.parse(line));
  assertEquals(rows.map((r) => r.id).sort(), [
    "A-blush-Gold",
    "A-eyeliner-Violet",
    "A-lipstick-Red",
    "A-lipstick-Teal",
    "B-lipstick-dark",
    "C-eyeshadow-glitter",
    "D1",
    "D6",
  ]);
  for (const row of rows) {
    assertEquals(
      row.evidence.preview_version,
      "custom_palette_preview_v2",
      row.id,
    );
    assertEquals(
      row.evidence.validator_version,
      "custom_palette_validator_v2",
      row.id,
    );
    const features = row.observations.at(-1).identityFeatures;
    for (
      const name of ["faceShape", "skinMarks", "apparentAge", "eyes", "framing"]
    ) {
      assertEquals(features[name], "same", `${row.id} ${name}`);
    }
    assert(!("invalid" in features), row.id);
  }
  // It stopped there: nothing from Stage 2, and no Stage 2 summary.
  assert(rows.every((r) => !/^(F-|G-|N-|E-|H)/.test(r.id)));
  let stage2Summary = true;
  try {
    Deno.statSync(join(out, "summary-stage2.json"));
  } catch {
    stage2Summary = false;
  }
  assertEquals(stage2Summary, false);
});

Deno.test("Stage 2 refuses the original Stage 1 as its predecessor", async () => {
  const { out } = await run();
  const stage2 = await new Deno.Command(Deno.execPath(), {
    args: [
      "run",
      "--no-lock",
      "--allow-env",
      "--allow-read",
      `--allow-write=${out}`,
      "--allow-sys",
      "--allow-run=docker,icacls",
      "--allow-net=127.0.0.1,localhost",
      join(HERE, "ccp10_eval.ts"),
    ],
    cwd: FUNCTIONS,
    env: {
      CCP10_MODE: "dry",
      CCP10_STAGE: "2",
      CCP10_OUT: out,
      CCP10_WORKSPACE: WORKSPACE,
    },
    stdout: "null",
    stderr: "piped",
  }).output();
  assertEquals(stage2.code, 2);
  assert(
    new TextDecoder().decode(stage2.stderr).includes("post-remediation rerun"),
  );
});

Deno.test("Stage 2 continues the rerun: its 71 cases, within 366 calls, then stops", async () => {
  const out = join(
    WORKSPACE,
    "out",
    `gate-s2-${crypto.randomUUID().slice(0, 8)}`,
  );
  const command = (stage: string) =>
    new Deno.Command(Deno.execPath(), {
      args: [
        "run",
        "--no-lock",
        "--allow-env",
        "--allow-read",
        `--allow-write=${out}`,
        "--allow-sys",
        "--allow-run=docker,icacls",
        "--allow-net=127.0.0.1,localhost",
        join(HERE, "ccp10_eval.ts"),
      ],
      cwd: FUNCTIONS,
      env: {
        CCP10_MODE: "dry",
        CCP10_STAGE: stage,
        CCP10_OUT: out,
        CCP10_WORKSPACE: WORKSPACE,
      },
      stdout: "null",
      stderr: "piped",
    }).output();
  const rerun = await command("1R");
  assertEquals(rerun.code, 0, new TextDecoder().decode(rerun.stderr));
  const stage1Summary = Deno.readTextFileSync(join(out, "summary-stage1.json"));
  const stage1Rows = Deno.readTextFileSync(join(out, "results.jsonl"));
  const stage1Key = Deno.readTextFileSync(join(out, "review_key.jsonl"));
  const spent = JSON.parse(stage1Summary).provider_calls.total as number;

  const stage2 = await command("2");
  assertEquals(stage2.code, 0, new TextDecoder().decode(stage2.stderr));
  const summary = JSON.parse(
    Deno.readTextFileSync(join(out, "summary-stage2.json")),
  ) as Summary & {
    run_kind: string;
    live_budget: {
      spent_before: number;
      ceiling: number;
      new_call_allowance: number;
    };
  };
  assertEquals(summary.run_kind, "stage2");
  assertEquals(summary.stop_reason, null);
  assertEquals(summary.violations, []);
  assertEquals(summary.evidence_complete, true);
  assertEquals(summary.live_budget.spent_before, spent);
  assertEquals(summary.live_budget.new_call_allowance, 366);
  assertEquals(summary.provider_calls.ceiling, spent + 366);
  assert(summary.provider_calls.total - spent <= 366);
  // Exactly the 71 Stage 2 cases were added, after Stage 1's, which are untouched.
  const allRows = Deno.readTextFileSync(join(out, "results.jsonl"));
  assert(allRows.startsWith(stage1Rows));
  const added = allRows.slice(stage1Rows.length).split("\n").filter(Boolean)
    .map((line) => JSON.parse(line) as { id: string; kind: string })
    .filter((row) => row.kind !== "violation");
  const ids = new Set(added.map((row) => row.id));
  assertEquals(
    [...ids].sort(),
    ALL_CASES.filter((c) => c.stage === 2).map((c) => c.id).sort(),
  );
  assertEquals(ids.size, 71);
  assertEquals(
    Deno.readTextFileSync(join(out, "summary-stage1.json")),
    stage1Summary,
  );
  assert(
    Deno.readTextFileSync(join(out, "review_key.jsonl")).startsWith(stage1Key),
  );
  // It stops there: Stage 2 again in this directory is refused, nothing follows it.
  // The budget no longer fits a second Stage 2's worst case, and the directory
  // already holds a Stage 2 summary: either one refuses it.
  const again = await command("2");
  const againError = new TextDecoder().decode(again.stderr);
  assertEquals(again.code, 2, againError);
  assert(/already ran|does not fit/.test(againError), againError);
  assertEquals(
    [...Deno.readDirSync(out)].filter((e) => /summary-stage[^12]/.test(e.name))
      .length,
    0,
  );
});

Deno.test("the stops all ran", () => assertEquals(runs, 8));
