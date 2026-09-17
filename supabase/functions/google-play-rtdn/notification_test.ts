import { assertEquals, assertThrows } from "jsr:@std/assert@1";

import {
  decodeDeveloperNotification,
  type DeveloperNotification,
  NotificationRejected,
  parsePubSubEnvelope,
  plannedAction,
} from "./notification.ts";

const token = "abc123._token-value~ok";

function encode(payload: unknown): string {
  return btoa(JSON.stringify(payload));
}

function developerNotification(
  overrides: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    version: "1.0",
    packageName: "io.facetune.app",
    eventTimeMillis: "1789000000000",
    subscriptionNotification: {
      version: "1.0",
      notificationType: 2,
      purchaseToken: token,
    },
    ...overrides,
  };
}

function notification(
  overrides: Partial<DeveloperNotification> = {},
): DeveloperNotification {
  return {
    packageName: "io.facetune.app",
    eventTime: null,
    kind: "subscription",
    notificationType: 2,
    purchaseToken: token,
    ...overrides,
  };
}

Deno.test("envelope: the message id is required", () => {
  // Without it there is no deduplication anchor, so the notification would be
  // reprocessed on every redelivery.
  assertThrows(
    () => parsePubSubEnvelope({ message: { data: encode({}) } }),
    NotificationRejected,
    "envelope_missing_message_id",
  );
});

Deno.test("envelope: data is required", () => {
  assertThrows(
    () => parsePubSubEnvelope({ message: { messageId: "m-1" } }),
    NotificationRejected,
    "envelope_missing_data",
  );
});

Deno.test("envelope: snake_case field names are accepted", () => {
  const envelope = parsePubSubEnvelope({
    message: {
      message_id: "m-1",
      publish_time: "2026-09-17T11:06:20Z",
      data: encode(developerNotification()),
    },
  });
  assertEquals(envelope.messageId, "m-1");
  assertEquals(envelope.publishTime, "2026-09-17T11:06:20Z");
});

Deno.test("payload: a subscription notification is read whole", () => {
  const decoded = decodeDeveloperNotification(
    encode(developerNotification()),
  );
  assertEquals(decoded.packageName, "io.facetune.app");
  assertEquals(decoded.kind, "subscription");
  assertEquals(decoded.notificationType, 2);
  assertEquals(decoded.purchaseToken, token);
  assertEquals(decoded.eventTime, new Date(1789000000000).toISOString());
});

Deno.test("payload: a malformed token is dropped rather than forwarded", () => {
  const decoded = decodeDeveloperNotification(
    encode(developerNotification({
      subscriptionNotification: {
        notificationType: 2,
        purchaseToken: "not a valid token!!",
      },
    })),
  );
  assertEquals(decoded.purchaseToken, null);
  // And with no token there is nothing to verify, so nothing is attempted.
  assertEquals(plannedAction(decoded), "ignore");
});

Deno.test("payload: a package name is required", () => {
  assertThrows(
    () => decodeDeveloperNotification(encode({ packageName: "" })),
    NotificationRejected,
    "payload_missing_package",
  );
});

Deno.test("payload: unparseable bodies are rejected, not guessed", () => {
  assertThrows(
    () => decodeDeveloperNotification("%%%not base64%%%"),
    NotificationRejected,
  );
  assertThrows(
    () => decodeDeveloperNotification(btoa("not json")),
    NotificationRejected,
    "payload_not_json",
  );
});

Deno.test("payload: a test notification is recognised as its own kind", () => {
  const decoded = decodeDeveloperNotification(
    encode({
      packageName: "io.facetune.app",
      testNotification: { version: "1.0" },
    }),
  );
  assertEquals(decoded.kind, "test");
  assertEquals(decoded.purchaseToken, null);
  assertEquals(plannedAction(decoded), "ignore");
});

Deno.test("payload: a voided purchase is recognised", () => {
  const decoded = decodeDeveloperNotification(
    encode({
      packageName: "io.facetune.app",
      voidedPurchaseNotification: {
        purchaseToken: token,
        orderId: "GS.0000-0000-0000",
        productType: 1,
        refundType: 1,
      },
    }),
  );
  assertEquals(decoded.kind, "voided_purchase");
  assertEquals(decoded.purchaseToken, token);
  assertEquals(plannedAction(decoded), "revoke");
});

Deno.test("action: every lifecycle type leads to the same verified read", () => {
  // The point of the phase. Renewed, cancelled, on hold, paused, recovered,
  // restarted, deferred, price-changed and pending-cancelled all reconcile:
  // none of them is interpreted from its number.
  for (const type of [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 17, 18, 19, 20, 22]) {
    assertEquals(
      plannedAction(notification({ notificationType: type })),
      "reconcile",
      `type ${type} must reconcile`,
    );
  }
});

Deno.test("action: revocation is the one type that points elsewhere", () => {
  assertEquals(
    plannedAction(notification({ notificationType: 12 })),
    "revoke",
  );
});

Deno.test("action: an unknown type still reconciles", () => {
  // A type Google adds later must not be silently ignored — the verified read
  // describes whatever it means, and the entitlement follows that.
  assertEquals(
    plannedAction(notification({ notificationType: 999 })),
    "reconcile",
  );
  assertEquals(
    plannedAction(notification({ notificationType: null })),
    "reconcile",
  );
});

Deno.test("action: blocks this backend does not sell are ignored", () => {
  for (const kind of ["one_time_product", "pending_refund_review", "unknown"] as const) {
    assertEquals(plannedAction(notification({ kind })), "ignore");
  }
});
