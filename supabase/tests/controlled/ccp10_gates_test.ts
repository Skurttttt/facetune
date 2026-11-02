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

Deno.test("the stops all ran", () => assertEquals(runs, 5));
