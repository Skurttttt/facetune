import { assert, assertEquals } from "jsr:@std/assert@1";

import {
  invalidRequestBody,
  mutationResponse,
  parseGrantSalonPilotRequest,
  SALON_PILOT_DEFAULT_INITIAL_ALLOWANCE,
} from "./admin_mutations.ts";

const now = new Date("2026-09-22T12:00:00Z");
const target = "40000000-0000-4000-8000-000000000001";

const valid = () => ({
  targetUserId: target.toUpperCase(),
  expiresAt: "2026-10-22T00:00:00Z",
  reason: "  Panel research cohort A ",
  idempotencyKey: "wa7-key-1",
});

Deno.test("a valid request normalizes and applies the Salon Pilot default", () => {
  const parsed = parseGrantSalonPilotRequest(valid(), now);
  assert(parsed.ok);
  assertEquals(parsed.value, {
    targetUserId: target,
    expiresAt: "2026-10-22T00:00:00.000Z",
    initialAllowance: SALON_PILOT_DEFAULT_INITIAL_ALLOWANCE,
    reason: "Panel research cohort A",
    idempotencyKey: "wa7-key-1",
  });
  assertEquals(SALON_PILOT_DEFAULT_INITIAL_ALLOWANCE, 30);
});

Deno.test("missing or invalid fields are refused by name, never coerced", () => {
  const cases: Array<[Record<string, unknown> | null, string]> = [
    [null, "body"],
    [{ ...valid(), targetUserId: "not-a-uuid" }, "targetUserId"],
    [{ ...valid(), expiresAt: undefined }, "expiresAt"],
    [{ ...valid(), expiresAt: "yesterday" }, "expiresAt"],
    [{ ...valid(), expiresAt: "2026-09-22T11:59:59Z" }, "expiresAt"],
    [{ ...valid(), initialAllowance: -1 }, "initialAllowance"],
    [{ ...valid(), initialAllowance: null }, "initialAllowance"],
    [{ ...valid(), initialAllowance: 30.5 }, "initialAllowance"],
    [{ ...valid(), initialAllowance: "30" }, "initialAllowance"],
    [{ ...valid(), reason: "   " }, "reason"],
    [{ ...valid(), reason: undefined }, "reason"],
    [{ ...valid(), reason: "x".repeat(501) }, "reason"],
    [{ ...valid(), idempotencyKey: "" }, "idempotencyKey"],
    [{ ...valid(), idempotencyKey: "k".repeat(129) }, "idempotencyKey"],
  ];
  for (const [body, field] of cases) {
    const parsed = parseGrantSalonPilotRequest(body, now);
    assert(!parsed.ok, field);
    assertEquals(parsed.field, field);
    // The message never echoes what the browser sent.
    assert(!parsed.message.includes("cohort"), field);
  }
});

Deno.test("the browser cannot supply trusted state", () => {
  const parsed = parseGrantSalonPilotRequest(
    {
      ...valid(),
      adminUserId: "50000000-0000-4000-8000-000000000000",
      beforeState: { status: "revoked" },
      entitlementStatus: "active",
    },
    now,
  );
  assert(parsed.ok);
  assertEquals(Object.keys(parsed.value).sort(), [
    "expiresAt",
    "idempotencyKey",
    "initialAllowance",
    "reason",
    "targetUserId",
  ]);
});

Deno.test("an invalid request answers 400 with the field and no echo", () => {
  const body = invalidRequestBody({
    ok: false,
    field: "reason",
    message: "reason is required (1-500 characters).",
  });
  assertEquals(body.success, false);
  assertEquals(body.errorCode, "invalid_request");
  assertEquals(body.field, "reason");
  assertEquals(body.retryable, false);
});

Deno.test("a writer success passes through untouched", () => {
  const result = {
    success: true,
    action: "grant_salon_pilot",
    replayed: true,
    entitlementId: "41000000-0000-4000-8000-000000000001",
    availableAiLooks: 29,
  };
  const response = mutationResponse(result);
  assertEquals(response.status, 200);
  assertEquals(response.body, result);
  assertEquals(response.outcome, "replayed");
});

Deno.test("writer failures map to the contract's HTTP statuses", () => {
  const expect: Array<[string, number, boolean]> = [
    ["ADMIN_UNAUTHORIZED", 403, false],
    ["USER_NOT_FOUND", 404, false],
    ["SALON_PILOT_ALREADY_GRANTED", 409, false],
    ["PROVIDER_STATE_CONFLICT", 409, false],
    ["IDEMPOTENCY_CONFLICT", 409, false],
    ["TEMPORARY_BACKEND_FAILURE", 503, true],
  ];
  for (const [code, status, retryable] of expect) {
    const response = mutationResponse({
      success: false,
      action: "grant_salon_pilot",
      errorCode: code,
      retryable: false,
    });
    assertEquals(response.status, status, code);
    assertEquals(response.body.errorCode, code);
    assertEquals(response.body.retryable, retryable, code);
    assertEquals(response.outcome, code);
    assert(typeof response.body.message === "string");
  }
});

Deno.test("an unrecognised writer answer is a temporary failure, never a success", () => {
  for (
    const odd of [null, undefined, "ok", { success: true }, {
      success: false,
      errorCode: "SPENT",
    }]
  ) {
    const response = mutationResponse(odd);
    assertEquals(response.status, 503);
    assertEquals(response.body.success, false);
    assertEquals(response.body.errorCode, "TEMPORARY_BACKEND_FAILURE");
  }
});

Deno.test("zero and any positive integer allowance are accepted; no maximum is imposed", () => {
  for (const allowance of [0, 1, 30, 5000, 1_000_000]) {
    const parsed = parseGrantSalonPilotRequest(
      { ...valid(), initialAllowance: allowance },
      now,
    );
    assert(parsed.ok, String(allowance));
    assertEquals(parsed.value.initialAllowance, allowance);
  }
});

// ---------------------------------------------------------------------------
// WA-8 — allowance adjustment
// ---------------------------------------------------------------------------

import {
  adjustmentActionFor,
  parseAdjustAllowanceRequest,
} from "./admin_mutations.ts";

const entitlement = "41000000-0000-4000-8000-000000000001";
const validAdjust = () => ({
  entitlementId: entitlement.toUpperCase(),
  amount: 10,
  reason: " Panel testing extension ",
  idempotencyKey: "wa8-key-1",
  expectedVersion: 3,
});

Deno.test("an adjustment request normalizes and keeps its sign", () => {
  const parsed = parseAdjustAllowanceRequest(validAdjust());
  assert(parsed.ok);
  assertEquals(parsed.value, {
    entitlementId: entitlement,
    amount: 10,
    reason: "Panel testing extension",
    idempotencyKey: "wa8-key-1",
    expectedVersion: 3,
  });
  const reduction = parseAdjustAllowanceRequest({
    ...validAdjust(),
    amount: -12,
  });
  assert(reduction.ok);
  assertEquals(reduction.value.amount, -12);
  assertEquals(adjustmentActionFor(10), "increase_allowance");
  assertEquals(adjustmentActionFor(-12), "decrease_allowance");
});

Deno.test("expectedVersion is optional but must be a positive integer when given", () => {
  const omitted = parseAdjustAllowanceRequest({
    ...validAdjust(),
    expectedVersion: undefined,
  });
  assert(omitted.ok);
  assertEquals(omitted.value.expectedVersion, null);
  const explicitNull = parseAdjustAllowanceRequest({
    ...validAdjust(),
    expectedVersion: null,
  });
  assert(explicitNull.ok);
  assertEquals(explicitNull.value.expectedVersion, null);
  for (const bad of [0, -1, 1.5, "3"]) {
    const parsed = parseAdjustAllowanceRequest({
      ...validAdjust(),
      expectedVersion: bad,
    });
    assert(!parsed.ok, String(bad));
    assertEquals(parsed.field, "expectedVersion");
  }
});

Deno.test("adjustment fields are refused by name; no maximum is imposed", () => {
  const cases: Array<[Record<string, unknown> | null, string]> = [
    [null, "body"],
    [{ ...validAdjust(), entitlementId: "nope" }, "entitlementId"],
    [{ ...validAdjust(), amount: 0 }, "amount"],
    [{ ...validAdjust(), amount: 2.5 }, "amount"],
    [{ ...validAdjust(), amount: "10" }, "amount"],
    [{ ...validAdjust(), reason: "  " }, "reason"],
    [{ ...validAdjust(), idempotencyKey: "" }, "idempotencyKey"],
  ];
  for (const [body, field] of cases) {
    const parsed = parseAdjustAllowanceRequest(body);
    assert(!parsed.ok, field);
    assertEquals(parsed.field, field);
  }
  for (const amount of [5, 10, 250, -1, 100_000]) {
    assert(
      parseAdjustAllowanceRequest({ ...validAdjust(), amount }).ok,
      String(amount),
    );
  }
});

Deno.test("adjustment failures keep the writer's action and map to contract statuses", () => {
  const expect: Array<[string, number]> = [
    ["ENTITLEMENT_NOT_FOUND", 404],
    ["INVALID_ALLOWANCE_ADJUSTMENT", 400],
    ["ALLOWANCE_BELOW_COMMITTED_USAGE", 409],
    ["ALLOWANCE_CONFLICTS_WITH_ACTIVE_RESERVATION", 409],
    ["CONCURRENT_MODIFICATION", 409],
    ["ENTITLEMENT_EXPIRED", 409],
    ["ENTITLEMENT_REVOKED", 409],
  ];
  for (const [code, status] of expect) {
    const response = mutationResponse(
      {
        success: false,
        action: "decrease_allowance",
        errorCode: code,
        retryable: false,
      },
      "increase_allowance",
    );
    assertEquals(response.status, status, code);
    assertEquals(response.body.action, "decrease_allowance", code);
    assertEquals(response.body.errorCode, code);
    assert(
      typeof response.body.message === "string" &&
        response.body.message.length > 0,
      code,
    );
  }
  assertEquals(
    mutationResponse(null, "decrease_allowance").body.action,
    "decrease_allowance",
  );
  assertEquals(
    invalidRequestBody(
      { ok: false, field: "amount", message: "m" },
      "decrease_allowance",
    ).action,
    "decrease_allowance",
  );
});

// ---------------------------------------------------------------------------
// WA-9 — Salon Pilot lifecycle
// ---------------------------------------------------------------------------

import { LIFECYCLE_ACTIONS, parseLifecycleRequest } from "./admin_mutations.ts";

const lifecycleNow = new Date("2026-09-22T12:00:00Z");
const validLifecycle = (action: string) => ({
  action,
  entitlementId: entitlement.toUpperCase(),
  reason: " Pilot access paused for review ",
  idempotencyKey: "wa9-key-1",
  expectedVersion: 2,
  newExpiresAt: "2027-03-31T23:59:59Z",
});

Deno.test("the four lifecycle actions parse; newExpiresAt is used only by extension", () => {
  assertEquals([...LIFECYCLE_ACTIONS], [
    "extend_expiration",
    "suspend_entitlement",
    "reactivate_entitlement",
    "revoke_entitlement",
  ]);
  for (const action of LIFECYCLE_ACTIONS) {
    const parsed = parseLifecycleRequest(validLifecycle(action), lifecycleNow);
    assert(parsed.ok, action);
    assertEquals(parsed.value.action, action);
    assertEquals(parsed.value.entitlementId, entitlement);
    assertEquals(parsed.value.reason, "Pilot access paused for review");
    assertEquals(parsed.value.expectedVersion, 2);
    assertEquals(
      parsed.value.newExpiresAt,
      action === "extend_expiration" ? "2027-03-31T23:59:59.000Z" : null,
    );
  }
});

Deno.test("lifecycle requests are refused by field, under their action where known", () => {
  const unknown = parseLifecycleRequest(
    validLifecycle("delete_entitlement"),
    lifecycleNow,
  );
  assert(!unknown.ok);
  assertEquals(unknown.field, "body");
  assertEquals(unknown.action, null);

  const cases: Array<[Record<string, unknown>, string, string]> = [
    [
      { ...validLifecycle("extend_expiration"), newExpiresAt: undefined },
      "newExpiresAt",
      "extend_expiration",
    ],
    [
      { ...validLifecycle("extend_expiration"), newExpiresAt: "yesterday" },
      "newExpiresAt",
      "extend_expiration",
    ],
    [
      {
        ...validLifecycle("extend_expiration"),
        newExpiresAt: "2026-09-22T11:59:59Z",
      },
      "newExpiresAt",
      "extend_expiration",
    ],
    [
      { ...validLifecycle("revoke_entitlement"), reason: "  " },
      "reason",
      "revoke_entitlement",
    ],
    [
      { ...validLifecycle("suspend_entitlement"), entitlementId: "nope" },
      "entitlementId",
      "suspend_entitlement",
    ],
    [
      { ...validLifecycle("reactivate_entitlement"), idempotencyKey: "" },
      "idempotencyKey",
      "reactivate_entitlement",
    ],
    [
      { ...validLifecycle("suspend_entitlement"), expectedVersion: 0 },
      "expectedVersion",
      "suspend_entitlement",
    ],
  ];
  for (const [body, field, action] of cases) {
    const parsed = parseLifecycleRequest(body, lifecycleNow);
    assert(!parsed.ok, field);
    assertEquals(parsed.field, field);
    assertEquals(parsed.action, action);
  }
  // A suspend request that happens to carry a date ignores it.
  const suspend = parseLifecycleRequest(
    { ...validLifecycle("suspend_entitlement"), newExpiresAt: "yesterday" },
    lifecycleNow,
  );
  assert(suspend.ok);
  assertEquals(suspend.value.newExpiresAt, null);
});

Deno.test("lifecycle failures map to contract statuses under the writer's action", () => {
  for (
    const [code, status] of [
      ["INVALID_ENTITLEMENT_TRANSITION", 409],
      ["PROVIDER_STATE_CONFLICT", 409],
      ["ENTITLEMENT_REVOKED", 409],
      ["ENTITLEMENT_EXPIRED", 409],
      ["CONCURRENT_MODIFICATION", 409],
      ["ENTITLEMENT_NOT_FOUND", 404],
    ] as Array<[string, number]>
  ) {
    const response = mutationResponse(
      {
        success: false,
        action: "revoke_entitlement",
        errorCode: code,
        retryable: false,
      },
      "revoke_entitlement",
    );
    assertEquals(response.status, status, code);
    assertEquals(response.body.action, "revoke_entitlement");
    assert(
      typeof response.body.message === "string" &&
        response.body.message.length > 0,
      code,
    );
  }
});
