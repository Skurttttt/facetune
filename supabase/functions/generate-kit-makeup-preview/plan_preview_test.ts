import {
  assert,
  assertEquals,
  assertRejects,
  assertStringIncludes,
} from "jsr:@std/assert@1";

import type { UsageResult } from "../_shared/ai_look_usage.ts";
import type { CanonicalPlan } from "../_shared/kit_makeup_plan.ts";
import {
  ATTEMPT_BUDGET_MS,
  type AttemptRow,
  type GenerationRow,
  INVOCATION_BUDGET_MS,
  LEASE_MS,
  PLAN_PREVIEW_MAX_ATTEMPTS,
  type PlanPreviewPorts,
  type PlanPreviewReply,
  repairCodesFrom,
  runPlanPreview,
} from "./plan_preview.ts";
import { FunctionFailure, type GeneratedImage } from "./types.ts";
import type { ValidationResult } from "./validator.ts";
import { readinessFailure, type ReadinessResult } from "./readiness.ts";

function ready(): ReadinessResult {
  return {
    status: "ready",
    readiness_version: "kit_tutorial_readiness_v1",
    manifest_prompt_version: "tutorial_manifest_v4_1",
    manifest_schema_version: "tutorial_manifest_schema_v1",
    included_categories: ["lips"],
    unbacked_present_categories: [],
    missing_required_categories: [],
    failure_code: null,
  };
}

function notReady(
  unbacked: Array<"foundation" | "concealer">,
  missing: Array<"lips">,
): ReadinessResult {
  return {
    ...ready(),
    status: "not_ready",
    included_categories: missing.length > 0 ? [] : ["lips"],
    unbacked_present_categories: unbacked,
    missing_required_categories: missing,
  };
}

const OPERATION = "30000000-0000-4000-8000-000000000001";
const RECOMMENDATION = "21000000-0000-4000-8000-000000000002";

function deepFreeze<T>(value: T): T {
  if (value && typeof value === "object") {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}

// The orchestrator never reads the plan itself; it only hands the same frozen
// object to every generation and validation.
const plan = deepFreeze({
  plan_id: "22000000-0000-4000-8000-000000000002",
  selected_items: [{ tutorial_category: "lips" }],
}) as unknown as CanonicalPlan;

const ORIGINAL = new Uint8Array([9, 9, 9]);

type Generated = GeneratedImage | FunctionFailure;

function image(n: number): GeneratedImage {
  return { bytes: new Uint8Array([n, n, n, n]), mimeType: "image/png" };
}

function accepted(): ValidationResult {
  return {
    outcome: "accepted",
    validator_version: "kit_preview_validator_v1",
    planned_present_categories: ["lips"],
    unexpected_present_categories: [],
    missing_required_categories: [],
    uncertain_categories: [],
    mismatch_reasons: [],
    failure_code: null,
    evidence: { identity: "preserved", categories: {} },
  };
}

function mismatch(
  category: "foundation" | "concealer" | "eyeliner",
  outcome: "retryable_mismatch" | "nonretryable_mismatch" =
    "retryable_mismatch",
): ValidationResult {
  return {
    ...accepted(),
    outcome,
    unexpected_present_categories: [category],
    mismatch_reasons: [{
      code: outcome === "retryable_mismatch"
        ? "unplanned_makeup_present"
        : "preexisting_forbidden_makeup",
      category,
    }],
  };
}

type LedgerRow = {
  status: "reserved" | "committed" | "released";
  previewId: string | null;
};

type Attempt = AttemptRow & {
  repair_codes: string[];
  candidate_sha256: string | null;
};

/**
 * An in-memory world with the database's rules: an idempotent ledger keyed by
 * operation, one generation per operation, sequential bounded attempts with
 * one in flight, finalize only from a validating attempt with a slot, and one
 * preview per operation.
 */
class World {
  clock = 1_000_000;
  ledger = new Map<string, LedgerRow>();
  generations = new Map<string, GenerationRow>();
  attempts = new Map<string, Attempt[]>();
  previews = new Map<string, Record<string, unknown>>();
  storage = new Map<string, Uint8Array>();
  charges = 0;
  releases = 0;
  reserveCalls = 0;
  generateCalls: Array<{ plan: CanonicalPlan; repairs: string[] }> = [];
  generated: Generated[] = [];
  verdicts: Array<ValidationResult | Error> = [];
  /** Readiness per attempt; an empty queue means ready. */
  readiness: ReadinessResult[] = [];
  finalizedEvidence: Array<Record<string, unknown> | null> = [];
  generationMs = 1_000;
  validationMs = 1_000;
  uploadFails = false;
  inventoryChanged = false;
  prepareCalls: boolean[] = [];
  private nextId = 1;

  id(): string {
    return `id-${this.nextId++}`;
  }

  generation(): GenerationRow | undefined {
    return this.generations.get(OPERATION);
  }

  attemptList(): Attempt[] {
    const generation = this.generation();
    return generation ? this.attempts.get(generation.id) ?? [] : [];
  }

  run(): Promise<PlanPreviewReply> {
    return runPlanPreview({
      operationId: OPERATION,
      kitRecommendationId: RECOMMENDATION,
      plan,
      prepare: (isNew) => {
        this.prepareCalls.push(isNew);
        if (this.inventoryChanged) {
          return Promise.reject(
            new FunctionFailure(409, "inventory_changed", "changed"),
          );
        }
        return Promise.resolve({ bytes: ORIGINAL, mimeType: "image/jpeg" });
      },
    }, this.ports());
  }

  ports(): PlanPreviewPorts {
    const ok = (extra: Partial<UsageResult> = {}): UsageResult =>
      ({ ok: true, errorCode: null, ...extra }) as UsageResult;
    const denied = (errorCode: string): UsageResult =>
      ({ ok: false, errorCode }) as UsageResult;
    return {
      now: () => this.clock,
      reserve: (operationId) => {
        this.reserveCalls++;
        const row = this.ledger.get(operationId);
        if (!row) {
          this.ledger.set(operationId, { status: "reserved", previewId: null });
          return Promise.resolve(ok());
        }
        if (row.status === "reserved") return Promise.resolve(ok());
        return Promise.resolve(
          denied(
            row.status === "committed"
              ? "USAGE_ALREADY_COMMITTED"
              : "USAGE_ALREADY_RELEASED",
          ),
        );
      },
      commit: (operationId, previewId) => {
        const row = this.ledger.get(operationId)!;
        if (row.status === "committed") {
          return Promise.resolve(
            row.previewId === previewId
              ? ok({ replayed: true } as Partial<UsageResult>)
              : denied("USAGE_ALREADY_COMMITTED"),
          );
        }
        row.status = "committed";
        row.previewId = previewId;
        this.charges++;
        return Promise.resolve(ok());
      },
      release: (operationId) => {
        const row = this.ledger.get(operationId)!;
        if (row.status === "committed") {
          return Promise.resolve(denied("USAGE_ALREADY_COMMITTED"));
        }
        if (row.status === "reserved") this.releases++;
        row.status = "released";
        return Promise.resolve(ok());
      },
      findGeneration: (operationId) =>
        Promise.resolve(
          this.generations.has(operationId)
            ? { ...this.generations.get(operationId)! }
            : null,
        ),
      insertGeneration: ({ operationId, maxAttempts, leaseExpiresAt }) => {
        if (this.generations.has(operationId)) return Promise.resolve(null);
        const row: GenerationRow = {
          id: this.id(),
          operation_id: operationId,
          kit_recommendation_id: RECOMMENDATION,
          status: "in_progress",
          terminal_outcome: null,
          max_attempts: maxAttempts,
          lease_expires_at: leaseExpiresAt,
        };
        this.generations.set(operationId, row);
        this.attempts.set(row.id, []);
        return Promise.resolve({ ...row });
      },
      takeLease: (generationId, untilIso, atIso) => {
        const row = [...this.generations.values()].find((g) =>
          g.id === generationId
        )!;
        const free = row.lease_expires_at === null ||
          Date.parse(row.lease_expires_at) < Date.parse(atIso);
        if (row.status !== "in_progress" || !free) {
          return Promise.resolve(false);
        }
        row.lease_expires_at = untilIso;
        return Promise.resolve(true);
      },
      yieldLease: (generationId) => {
        const row = [...this.generations.values()].find((g) =>
          g.id === generationId
        )!;
        row.lease_expires_at = null;
        return Promise.resolve();
      },
      endGeneration: (generationId, outcome) => {
        const row = [...this.generations.values()].find((g) =>
          g.id === generationId
        )!;
        assert(
          this.attempts.get(generationId)!.every((a) =>
            a.status === "completed"
          ),
          "a generation ends only with nothing in flight",
        );
        row.status = "failed";
        row.terminal_outcome = outcome;
        row.lease_expires_at = null;
        return Promise.resolve();
      },
      listAttempts: (generationId) =>
        Promise.resolve(
          (this.attempts.get(generationId) ?? []).map((a) => ({ ...a })),
        ),
      startAttempt: ({ generationId, attemptNumber, repairCodes }) => {
        const generation = [...this.generations.values()].find((g) =>
          g.id === generationId
        )!;
        const list = this.attempts.get(generationId)!;
        if (
          generation.status !== "in_progress" ||
          list.some((a) => a.status !== "completed") ||
          attemptNumber !== list.length + 1 ||
          attemptNumber > generation.max_attempts
        ) return Promise.resolve(null);
        const attempt: Attempt = {
          id: this.id(),
          attempt_number: attemptNumber,
          status: "generating",
          outcome: null,
          reason_code: null,
          mismatch_categories: [],
          missing_required_categories: [],
          preview_storage_path: null,
          repair_codes: repairCodes,
          candidate_sha256: null,
        };
        list.push(attempt);
        return Promise.resolve(attempt.id);
      },
      markValidating: (attemptId, sha256) => {
        const attempt = this.find(attemptId);
        assertEquals(attempt.status, "generating");
        attempt.status = "validating";
        attempt.candidate_sha256 = sha256;
        return Promise.resolve();
      },
      completeAttempt: (attemptId, result) => {
        const attempt = this.find(attemptId);
        assert(attempt.status !== "completed", "completed is immutable");
        assert(result.outcome !== "accepted", "acceptance is finalize-only");
        attempt.status = "completed";
        attempt.outcome = result.outcome;
        attempt.reason_code = result.reason_code;
        if ("mismatch_categories" in result) {
          attempt.mismatch_categories = result.mismatch_categories;
          attempt.missing_required_categories =
            result.missing_required_categories;
        }
        return Promise.resolve();
      },
      abandonAttempt: (attemptId, reasonCode) => {
        const attempt = this.find(attemptId);
        if (attempt.status === "completed") return Promise.resolve();
        attempt.status = "completed";
        attempt.outcome = "abandoned";
        attempt.reason_code = reasonCode;
        return Promise.resolve();
      },
      claimSlot: (attemptId, extension) => {
        const attempt = this.find(attemptId);
        assertEquals(attempt.status, "validating");
        attempt.preview_storage_path ??=
          `user/analyses/a/kit-generated/${RECOMMENDATION}/preview_${
            String(attempt.attempt_number).padStart(4, "0")
          }.${extension}`;
        return Promise.resolve({
          generationNumber: attempt.attempt_number,
          storagePath: attempt.preview_storage_path,
        });
      },
      finalize: (attemptId, _validatorVersion, evidence) => {
        this.finalizedEvidence.push(evidence);
        const attempt = this.find(attemptId);
        const generation = this.generation()!;
        if (attempt.outcome === "accepted") {
          return Promise.resolve(this.previews.get(OPERATION)!.id as string);
        }
        if (
          attempt.status !== "validating" || !attempt.preview_storage_path ||
          !this.storage.has(attempt.preview_storage_path)
        ) {
          return Promise.reject(new Error("finalize refused"));
        }
        if (this.previews.has(OPERATION)) {
          return Promise.reject(new Error("unique operation_id"));
        }
        attempt.status = "completed";
        attempt.outcome = "accepted";
        const preview = {
          id: this.id(),
          operation_id: OPERATION,
          storage_path: attempt.preview_storage_path,
          content_sha256: attempt.candidate_sha256,
          accepted_attempt_id: attempt.id,
        };
        this.previews.set(OPERATION, preview);
        generation.status = "accepted";
        generation.terminal_outcome = "accepted";
        generation.lease_expires_at = null;
        return Promise.resolve(preview.id);
      },
      findPreview: (operationId) =>
        Promise.resolve(this.previews.get(operationId) ?? null),
      upload: (path, bytes) => {
        if (this.uploadFails) return Promise.reject(new Error("upload"));
        assert(!this.storage.has(path), "upsert is never used");
        this.storage.set(path, bytes);
        return Promise.resolve();
      },
      remove: (path) => {
        this.storage.delete(path);
        return Promise.resolve();
      },
      generate: (plan, _original, _variation, repairs) => {
        this.generateCalls.push({ plan, repairs });
        this.clock += this.generationMs;
        const next = this.generated.shift();
        if (!next) throw new Error("unscripted generation");
        return next instanceof FunctionFailure
          ? Promise.reject(next)
          : Promise.resolve(next);
      },
      validate: () => {
        this.clock += this.validationMs;
        const next = this.verdicts.shift();
        if (!next) throw new Error("unscripted validation");
        return next instanceof Error
          ? Promise.reject(next)
          : Promise.resolve(next);
      },
      assessReadiness: () => Promise.resolve(this.readiness.shift() ?? ready()),
      sha256: (bytes) =>
        Promise.resolve(
          [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("")
            .padEnd(64, "0"),
        ),
    };
  }

  private find(attemptId: string): Attempt {
    for (const list of this.attempts.values()) {
      const found = list.find((a) => a.id === attemptId);
      if (found) return found;
    }
    throw new Error("unknown attempt");
  }
}

function assertOneCharge(world: World) {
  assertEquals(world.charges, 1, "exactly one AI Look charged");
  assertEquals(world.releases, 0);
  assertEquals(world.ledger.size, 1, "one reservation for the request");
  assertEquals(world.previews.size, 1, "one accepted preview");
}

// ---------------------------------------------------------------------------
// Accounting
// ---------------------------------------------------------------------------

Deno.test("accepted on the first attempt: one commit", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());

  const reply = await world.run();

  assertEquals(reply.kind, "accepted");
  assertOneCharge(world);
  assertEquals(world.attemptList().length, 1);
  assertEquals(world.generation()!.status, "accepted");
});

Deno.test("accepted on the second attempt: one commit", async () => {
  const world = new World();
  world.generated.push(image(1), image(2));
  world.verdicts.push(mismatch("foundation"), accepted());

  const reply = await world.run();

  assertEquals(reply.kind, "accepted");
  assertOneCharge(world);
  assertEquals(world.attemptList().map((a) => a.outcome), [
    "retryable_mismatch",
    "accepted",
  ]);
  // The only accepted bytes are attempt two's; attempt one left nothing.
  assertEquals([...world.storage.values()], [image(2).bytes]);
});

Deno.test("accepted on the third attempt: one commit", async () => {
  const world = new World();
  world.generated.push(
    image(1),
    new FunctionFailure(504, "GEMINI_TIMEOUT", "slow", true),
    image(3),
  );
  world.verdicts.push(mismatch("eyeliner"), accepted());

  const reply = await world.run();

  assertEquals(reply.kind, "accepted");
  assertOneCharge(world);
  assertEquals(world.attemptList().map((a) => a.outcome), [
    "retryable_mismatch",
    "provider_failure",
    "accepted",
  ]);
});

Deno.test("every attempt fails: released once, nothing persisted", async () => {
  const world = new World();
  world.generated.push(image(1), image(2), image(3));
  world.verdicts.push(
    mismatch("foundation"),
    mismatch("concealer"),
    mismatch("foundation"),
  );

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  if (reply.kind === "failed") {
    assertEquals(reply.terminalOutcome, "retry_exhausted");
    assertEquals(reply.failure.code, "preview_not_reliable");
    assertStringIncludes(reply.failure.message, "Your Makeup Kit is unchanged");
    assertEquals(reply.failure.message.includes("not in your kit"), false);
  }
  assertEquals(world.charges, 0);
  assertEquals(world.releases, 1);
  assertEquals(world.ledger.get(OPERATION)!.status, "released");
  assertEquals(world.previews.size, 0);
  assertEquals(world.storage.size, 0);
  assertEquals(world.attemptList().length, PLAN_PREVIEW_MAX_ATTEMPTS);
  assertEquals(world.generation()!.terminal_outcome, "retry_exhausted");
});

Deno.test("a replay after acceptance never charges again", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());
  const first = await world.run();

  const second = await world.run();
  const third = await world.run();

  assertEquals(first.kind, "accepted");
  for (const reply of [second, third]) {
    assertEquals(reply.kind, "accepted");
    if (reply.kind === "accepted") {
      assertEquals(reply.replayed, true);
      assertEquals(reply.preview.id, world.previews.get(OPERATION)!.id);
    }
  }
  assertOneCharge(world);
  assertEquals(world.generateCalls.length, 1, "no new generation on replay");
});

Deno.test("a lost commit is committed once on replay", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());
  await world.run();
  // Simulate the commit never having landed.
  world.ledger.get(OPERATION)!.status = "reserved";
  world.ledger.get(OPERATION)!.previewId = null;
  world.charges = 0;

  const reply = await world.run();
  await world.run();

  assertEquals(reply.kind, "accepted");
  assertOneCharge(world);
});

Deno.test("the lead attempt's rejection is terminal when no retry can help", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(mismatch("eyeliner", "nonretryable_mismatch"));

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  if (reply.kind === "failed") {
    assertEquals(reply.terminalOutcome, "nonretryable_mismatch");
  }
  assertEquals(world.attemptList().length, 1);
  assertEquals(world.releases, 1);
  assertEquals(world.charges, 0);
});

Deno.test("a provider failure that cannot recover ends the request", async () => {
  const world = new World();
  world.generated.push(
    new FunctionFailure(502, "GEMINI_BILLING_REQUIRED", "billing", false),
  );

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  if (reply.kind === "failed") {
    assertEquals(reply.terminalOutcome, "provider_failure");
  }
  assertEquals(world.attemptList()[0].reason_code, "gemini_billing_required");
  assertEquals(world.releases, 1);
});

// ---------------------------------------------------------------------------
// Plan and retry input
// ---------------------------------------------------------------------------

Deno.test("every attempt renders the same frozen plan, tightened by evidence", async () => {
  const world = new World();
  world.generated.push(image(1), image(2), image(3));
  world.verdicts.push(mismatch("foundation"), mismatch("eyeliner"), accepted());

  await world.run();

  assertEquals(world.generateCalls.length, 3);
  for (const call of world.generateCalls) assert(call.plan === plan);
  assertEquals(world.generateCalls.map((call) => call.repairs), [
    [],
    ["forbid_foundation"],
    ["forbid_eyeliner", "forbid_foundation"],
  ]);
  assertEquals(
    world.attemptList().map((attempt) => attempt.repair_codes),
    world.generateCalls.map((call) => call.repairs),
  );
});

Deno.test("repair codes come only from recorded mismatch evidence", () => {
  const row = (partial: Partial<AttemptRow>): AttemptRow => ({
    id: "a",
    attempt_number: 1,
    status: "completed",
    outcome: "retryable_mismatch",
    reason_code: null,
    mismatch_categories: [],
    missing_required_categories: [],
    preview_storage_path: null,
    ...partial,
  });
  assertEquals(
    repairCodesFrom([
      row({ mismatch_categories: ["concealer"] }),
      row({ missing_required_categories: ["lips"] }),
      row({ reason_code: "identity_changed" }),
      row({ outcome: "provider_failure", reason_code: "timeout" }),
      row({ outcome: "abandoned", reason_code: "lease_expired" }),
    ]),
    ["forbid_concealer", "preserve_identity", "require_lips"],
  );
});

Deno.test("an unchanged image is a failed attempt, not a preview", async () => {
  const world = new World();
  world.generated.push(
    { bytes: ORIGINAL, mimeType: "image/png" },
    image(2),
  );
  world.verdicts.push(accepted());

  await world.run();

  assertEquals(world.attemptList()[0].reason_code, "unchanged_generated_image");
  assertOneCharge(world);
});

Deno.test("a failed upload abandons the attempt and leaves nothing behind", async () => {
  const world = new World();
  world.generated.push(image(1), image(2));
  world.verdicts.push(accepted(), accepted());
  world.uploadFails = true;
  const ports = world.ports();
  let uploads = 0;
  const failingOnce: PlanPreviewPorts = {
    ...ports,
    upload: (path, bytes, mime) => {
      uploads++;
      if (uploads === 1) return Promise.reject(new Error("upload"));
      world.uploadFails = false;
      return ports.upload(path, bytes, mime);
    },
  };

  const reply = await runPlanPreview({
    operationId: OPERATION,
    kitRecommendationId: RECOMMENDATION,
    plan,
    prepare: () => Promise.resolve({ bytes: ORIGINAL, mimeType: "image/jpeg" }),
  }, failingOnce);

  assertEquals(reply.kind, "accepted");
  assertEquals(world.attemptList().map((a) => a.outcome), [
    "abandoned",
    "accepted",
  ]);
  assertEquals(world.attemptList()[0].reason_code, "persist_failed");
  assertEquals(world.storage.size, 1);
  assertOneCharge(world);
});

// ---------------------------------------------------------------------------
// Spanning invocations
// ---------------------------------------------------------------------------

Deno.test("an attempt starts only when a whole one fits the invocation", async () => {
  const world = new World();
  world.generationMs = 60_000;
  world.generated.push(image(1), image(2));
  world.verdicts.push(mismatch("foundation"), accepted());

  const first = await world.run();

  assertEquals(first, { kind: "in_progress", retryAfterMs: 0, busy: false });
  assert(INVOCATION_BUDGET_MS - 65_000 < ATTEMPT_BUDGET_MS);
  assertEquals(world.attemptList().length, 1);
  assertEquals(world.generation()!.lease_expires_at, null, "lease handed back");
  assertEquals(world.releases, 0);

  const second = await world.run();

  assertEquals(second.kind, "accepted");
  assertEquals(world.attemptList().map((a) => a.attempt_number), [1, 2]);
  assertOneCharge(world);
  assertEquals(world.prepareCalls, [true, false], "quota is taken once");
});

Deno.test("the bound holds across any number of invocations", async () => {
  const world = new World();
  world.generationMs = 60_000;
  world.generated.push(image(1), image(2), image(3), image(4));
  world.verdicts.push(
    mismatch("foundation"),
    mismatch("foundation"),
    mismatch("foundation"),
    accepted(),
  );

  const replies: PlanPreviewReply[] = [];
  for (let i = 0; i < 6; i++) replies.push(await world.run());

  assertEquals(world.attemptList().length, 3);
  assertEquals(world.generateCalls.length, 3);
  assertEquals(replies.at(-1)!.kind, "failed");
  assertEquals(world.releases, 1);
  assertEquals(world.charges, 0);
});

Deno.test("a duplicate request while another holds the lease waits", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());
  // Another invocation is mid-flight and holds a live lease.
  world.generations.set(OPERATION, {
    id: "gen-live",
    operation_id: OPERATION,
    kit_recommendation_id: RECOMMENDATION,
    status: "in_progress",
    terminal_outcome: null,
    max_attempts: 3,
    lease_expires_at: new Date(world.clock + 60_000).toISOString(),
  });
  world.attempts.set("gen-live", []);
  world.ledger.set(OPERATION, { status: "reserved", previewId: null });

  const reply = await world.run();

  assertEquals(reply.kind, "in_progress");
  if (reply.kind === "in_progress") assertEquals(reply.busy, true);
  assertEquals(world.generateCalls.length, 0);
  assertEquals(world.releases, 0, "a waiter never releases");
  assertEquals(world.ledger.get(OPERATION)!.status, "reserved");
});

Deno.test("a dead holder's attempt is abandoned and the request continues", async () => {
  const world = new World();
  world.generated.push(image(1), image(2));
  world.verdicts.push(new Error("container recycled"), accepted());

  await assertRejects(() => world.run(), Error, "container recycled");
  assertEquals(world.attemptList()[0].status, "validating");
  assertEquals(world.releases, 0, "an unexpected failure never releases");

  const reply = await world.run();

  assertEquals(reply.kind, "accepted");
  assertEquals(world.attemptList().map((a) => a.outcome), [
    "abandoned",
    "accepted",
  ]);
  assertEquals(world.attemptList()[0].reason_code, "lease_expired");
  assertOneCharge(world);
});

Deno.test("a live lease is respected until it expires", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());
  world.generations.set(OPERATION, {
    id: "gen-stale",
    operation_id: OPERATION,
    kit_recommendation_id: RECOMMENDATION,
    status: "in_progress",
    terminal_outcome: null,
    max_attempts: 3,
    lease_expires_at: new Date(world.clock + LEASE_MS).toISOString(),
  });
  world.attempts.set("gen-stale", []);
  world.ledger.set(OPERATION, { status: "reserved", previewId: null });

  assertEquals((await world.run()).kind, "in_progress");
  world.clock += LEASE_MS + 1;
  assertEquals((await world.run()).kind, "accepted");
  assertOneCharge(world);
});

Deno.test("a reservation released by reconciliation ends the request", async () => {
  const world = new World();
  world.generations.set(OPERATION, {
    id: "gen-orphan",
    operation_id: OPERATION,
    kit_recommendation_id: RECOMMENDATION,
    status: "in_progress",
    terminal_outcome: null,
    max_attempts: 3,
    lease_expires_at: null,
  });
  world.attempts.set("gen-orphan", []);
  world.ledger.set(OPERATION, { status: "released", previewId: null });

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  if (reply.kind === "failed") {
    assertEquals(reply.terminalOutcome, "reservation_released");
  }
  assertEquals(world.generation()!.status, "failed");
  assertEquals(world.releases, 0, "already released; not released again");
  assertEquals(world.generateCalls.length, 0);
});

Deno.test("an edited kit ends a request in progress", async () => {
  const world = new World();
  world.generationMs = 60_000;
  world.generated.push(image(1));
  world.verdicts.push(mismatch("foundation"));
  await world.run();
  world.inventoryChanged = true;

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  if (reply.kind === "failed") {
    assertEquals(reply.terminalOutcome, "inventory_changed");
    assertEquals(reply.failure.code, "inventory_changed");
  }
  assertEquals(world.releases, 1);
});

Deno.test("an operation for another look is refused", async () => {
  const world = new World();
  world.generations.set(OPERATION, {
    id: "gen-other",
    operation_id: OPERATION,
    kit_recommendation_id: "21000000-0000-4000-8000-000000000099",
    status: "in_progress",
    terminal_outcome: null,
    max_attempts: 3,
    lease_expires_at: null,
  });

  const error = await assertRejects(() => world.run(), FunctionFailure);
  assertEquals((error as FunctionFailure).code, "operation_conflict");
  assertEquals(world.reserveCalls, 0);
});

Deno.test("a finished failure replays without new work", async () => {
  const world = new World();
  world.generated.push(new FunctionFailure(502, "GEMINI_ACCESS_DENIED", "x"));
  await world.run();

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  assertEquals(world.generateCalls.length, 1);
  assertEquals(world.releases, 1);
});

// ---------------------------------------------------------------------------
// Tutorial readiness (PDMK-7)
// ---------------------------------------------------------------------------

Deno.test("an accepted preview is Tutorial-ready by construction", async () => {
  const world = new World();
  world.generated.push(image(1));
  world.verdicts.push(accepted());

  await world.run();

  const evidence = world.finalizedEvidence[0] as {
    readiness: ReadinessResult;
    validator: unknown;
  };
  assertEquals(evidence.readiness.status, "ready");
  assertEquals(
    evidence.readiness.readiness_version,
    "kit_tutorial_readiness_v1",
  );
  assertEquals(
    evidence.readiness.manifest_prompt_version,
    "tutorial_manifest_v4_1",
  );
  assert(evidence.validator !== undefined);
});

Deno.test("a candidate the Tutorial would refuse is never accepted", async () => {
  const world = new World();
  world.generated.push(image(1), image(2));
  world.verdicts.push(accepted(), accepted());
  // The validator passed it, but the manifest would see unbacked foundation:
  // a kit_preview_mismatch waiting to happen at Show me how.
  world.readiness.push(notReady(["foundation"], []));

  const reply = await world.run();

  assertEquals(reply.kind, "accepted");
  const [first, second] = world.attemptList();
  assertEquals(first.outcome, "retryable_mismatch");
  assertEquals(first.reason_code, "tutorial_not_ready");
  assertEquals(first.mismatch_categories, ["foundation"]);
  assertEquals(second.outcome, "accepted");
  assertEquals(world.generateCalls[1].repairs, ["forbid_foundation"]);
  assertOneCharge(world);
});

Deno.test("a required step the Tutorial would miss is a mismatch", async () => {
  const world = new World();
  world.generated.push(image(1), image(2));
  world.verdicts.push(accepted(), accepted());
  world.readiness.push(notReady([], ["lips"]));

  await world.run();

  assertEquals(world.attemptList()[0].missing_required_categories, ["lips"]);
  assertEquals(world.generateCalls[1].repairs, ["require_lips"]);
});

Deno.test("readiness that cannot be established is not a pass", async () => {
  const world = new World();
  world.generated.push(image(1), image(2), image(3));
  world.verdicts.push(accepted(), accepted(), accepted());
  world.readiness.push(
    readinessFailure("readiness_timeout"),
    readinessFailure("readiness_malformed"),
    readinessFailure("readiness_timeout"),
  );

  const reply = await world.run();

  assertEquals(reply.kind, "failed");
  assertEquals(world.attemptList().map((a) => a.outcome), [
    "validator_failure",
    "validator_failure",
    "validator_failure",
  ]);
  assertEquals(world.previews.size, 0);
  assertEquals(world.releases, 1);
  assertEquals(world.charges, 0);
});
