// Pure parsing of a Google Play Real-time Developer Notification.
//
// Same discipline as `verify-google-play-purchase/verification.ts`: total
// functions over data, no network, no environment, no clock. The rules that
// decide what a notification *is* are the part worth testing exhaustively, and
// they are testable only if they need neither Pub/Sub nor Google to run.
//
// ## What this module is not allowed to decide
//
// Nothing here returns an entitlement, a status, or a plan. A notification is
// a trigger: it says which subscription changed and nothing more. The
// authority for what changed is the verified `SubscriptionPurchaseV2` read
// back from Google, and the authority for what that means is the database.
// The strongest statement this module makes is *which verified read to
// perform*, which is why `plannedAction` returns a verb rather than a state.

/// A notification that will not be processed, with a reason fit for a log.
///
/// Rejections are not errors in the HTTP sense. A malformed or foreign
/// notification is answered 200 and dropped, because asking Pub/Sub to
/// redeliver something that will never parse is an infinite retry.
export class NotificationRejected extends Error {
  constructor(readonly reason: string) {
    super(reason);
  }
}

/// The Pub/Sub push envelope, reduced to what matters.
export interface PubSubEnvelope {
  /// The transport's own message identifier. The deduplication anchor — see
  /// `claim_google_play_notification` for why it, and not the purchase token,
  /// is what makes a redelivery a no-op.
  messageId: string;
  publishTime: string | null;
  /// Base64 of the `DeveloperNotification` JSON.
  data: string;
}

/// Which block the notification carried. Mirrors the check constraint on
/// `provider_notification_events.notification_kind`.
export type NotificationKind =
  | "subscription"
  | "voided_purchase"
  | "one_time_product"
  | "pending_refund_review"
  | "test"
  | "unknown";

/// What this backend intends to do about a notification.
///
/// `reconcile` and `revoke` both begin with a verified read from Google; they
/// differ only in which outcome that read is expected to corroborate. Nothing
/// is written on the strength of the verb alone.
export type PlannedAction = "reconcile" | "revoke" | "ignore";

export interface DeveloperNotification {
  packageName: string;
  eventTime: string | null;
  kind: NotificationKind;
  /// The provider's numeric notification type, when the block carried one.
  /// Recorded for audit. Nothing branches on it except `plannedAction`, and
  /// then only to choose which verified read to make.
  notificationType: number | null;
  purchaseToken: string | null;
}

/// `SUBSCRIPTION_REVOKED`. The only subscription notification type that points
/// at an outcome Google's `SubscriptionState` cannot express, which is why it
/// is the only one named here.
const subscriptionRevokedType = 12;

/// The token shape Google issues.
///
/// Deliberately a second copy of the pattern in
/// `verify-google-play-purchase/verification.ts` rather than an import: that
/// file belongs to a deployed, separately validated function, and this phase
/// does not modify it. One regex is a cheaper duplication than a shared edit
/// to a function this phase is not re-verifying.
const purchaseTokenPattern = /^[A-Za-z0-9._~\-]{1,1024}$/;

function nonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.length > 0 ? value : null;
}

/// Parses the JSON body of a Pub/Sub push request.
export function parsePubSubEnvelope(body: unknown): PubSubEnvelope {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new NotificationRejected("envelope_not_an_object");
  }
  const message = (body as Record<string, unknown>).message;
  if (typeof message !== "object" || message === null) {
    throw new NotificationRejected("envelope_missing_message");
  }
  const fields = message as Record<string, unknown>;

  const messageId = nonEmptyString(fields.messageId) ??
    nonEmptyString(fields.message_id);
  if (messageId === null) {
    // Without a message id there is no deduplication anchor, and processing it
    // would mean processing it again on every redelivery.
    throw new NotificationRejected("envelope_missing_message_id");
  }

  const data = nonEmptyString(fields.data);
  if (data === null) {
    throw new NotificationRejected("envelope_missing_data");
  }

  return {
    messageId,
    publishTime: nonEmptyString(fields.publishTime) ??
      nonEmptyString(fields.publish_time),
    data,
  };
}

/// Decodes the base64 `DeveloperNotification` carried by the envelope.
export function decodeDeveloperNotification(
  data: string,
): DeveloperNotification {
  let json: string;
  try {
    json = new TextDecoder().decode(
      Uint8Array.from(atob(data), (character) => character.charCodeAt(0)),
    );
  } catch {
    throw new NotificationRejected("payload_not_base64");
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(json);
  } catch {
    throw new NotificationRejected("payload_not_json");
  }
  if (typeof parsed !== "object" || parsed === null || Array.isArray(parsed)) {
    throw new NotificationRejected("payload_not_an_object");
  }
  const payload = parsed as Record<string, unknown>;

  const packageName = nonEmptyString(payload.packageName);
  if (packageName === null) {
    throw new NotificationRejected("payload_missing_package");
  }

  const subscription = payload.subscriptionNotification as
    | Record<string, unknown>
    | undefined;
  const voided = payload.voidedPurchaseNotification as
    | Record<string, unknown>
    | undefined;
  const oneTime = payload.oneTimeProductNotification as
    | Record<string, unknown>
    | undefined;
  const pendingRefund = payload.pendingRefundReviewNotification as
    | Record<string, unknown>
    | undefined;
  const test = payload.testNotification as Record<string, unknown> | undefined;

  // Exactly one block is populated in practice. The order below decides only
  // in the pathological case where more than one is, and it puts the two this
  // backend acts on first so an added block cannot mask them.
  let kind: NotificationKind = "unknown";
  let block: Record<string, unknown> | undefined;
  if (subscription) {
    kind = "subscription";
    block = subscription;
  } else if (voided) {
    kind = "voided_purchase";
    block = voided;
  } else if (oneTime) {
    kind = "one_time_product";
    block = oneTime;
  } else if (pendingRefund) {
    kind = "pending_refund_review";
    block = pendingRefund;
  } else if (test) {
    kind = "test";
    block = test;
  }

  const rawType = block?.notificationType;
  const notificationType = typeof rawType === "number" &&
      Number.isFinite(rawType)
    ? rawType
    : null;

  // A token that does not match the provider's own shape is dropped rather
  // than forwarded: it would be rejected by Google anyway, and a malformed
  // value has no business reaching a URL this backend builds.
  const rawToken = nonEmptyString(block?.purchaseToken);
  const purchaseToken = rawToken !== null &&
      purchaseTokenPattern.test(rawToken)
    ? rawToken
    : null;

  return {
    packageName,
    eventTime: millisToIso(payload.eventTimeMillis),
    kind,
    notificationType,
    purchaseToken,
  };
}

/// Decides which verified read a notification calls for.
///
/// Note what is *not* expressed: there is no mapping from a notification type
/// to an entitlement status. Every subscription notification — renewed,
/// cancelled, on hold, paused, recovered, deferred, price changed — leads to
/// the same place, a fresh `purchases.subscriptionsv2.get`, because the
/// current verified resource describes all of them and the notification
/// describes none of them.
///
/// `SUBSCRIPTION_REVOKED` and a voided purchase are singled out only because
/// revocation is invisible in `SubscriptionState`: a revoked subscription
/// reads back as expired. They still require the verified read to corroborate
/// before anything is written.
export function plannedAction(
  notification: DeveloperNotification,
): PlannedAction {
  switch (notification.kind) {
    case "subscription":
      if (notification.purchaseToken === null) return "ignore";
      return notification.notificationType === subscriptionRevokedType
        ? "revoke"
        : "reconcile";
    case "voided_purchase":
      return notification.purchaseToken === null ? "ignore" : "revoke";
    // A test ping, a one-time product this app does not sell, and a refund
    // still under review all mean "nothing to reconcile". Recorded, answered
    // 200, and dropped.
    case "test":
    case "one_time_product":
    case "pending_refund_review":
    case "unknown":
      return "ignore";
  }
}

/// Google sends `eventTimeMillis` as a string of milliseconds.
function millisToIso(value: unknown): string | null {
  const millis = typeof value === "string"
    ? Number.parseInt(value, 10)
    : typeof value === "number"
    ? value
    : Number.NaN;
  if (!Number.isFinite(millis) || millis <= 0) return null;
  return new Date(millis).toISOString();
}
