import '../../../features/subscription/domain/entities/entitlement_status.dart';
import '../../shared/admin_keyset_list_controller.dart';
import '../../shared/admin_wire.dart' as wire;

/// Salon Pilot research metrics (WA-13), exactly as
/// `admin_salon_pilot_research_metrics` returns them.
///
/// Every number is a server aggregate; nothing is derived here. The cost
/// block is deliberately a *statement of availability*: the system records
/// provider usage in tokens, images and attempts, never money, so the
/// effective cost per delivered AI Look is "not available" until real cost
/// data exists — the per-look planning assumption is never a runtime value.
class AdminSalonPilotResearch {
  const AdminSalonPilotResearch({
    required this.asOf,
    required this.pilots,
    required this.aiLooks,
    required this.operations,
    required this.billableUsage,
    required this.cost,
  });

  final DateTime asOf;
  final PilotCounts pilots;
  final PilotAiLookTotals aiLooks;
  final PilotOperationTotals operations;
  final PilotBillableUsage billableUsage;
  final PilotCostAvailability cost;

  static AdminSalonPilotResearch decode(Object? payload) {
    final v = wire.object(payload);
    if (v['ok'] != true || v['contractVersion'] != wire.adminContractVersion) {
      wire.malformed();
    }
    return AdminSalonPilotResearch(
      asOf: wire.date(v, 'asOf'),
      pilots: PilotCounts.decode(v['pilots']),
      aiLooks: PilotAiLookTotals.decode(v['aiLooks']),
      operations: PilotOperationTotals.decode(v['operations']),
      billableUsage: PilotBillableUsage.decode(v['billableUsage']),
      cost: PilotCostAvailability.decode(v['cost']),
    );
  }
}

class PilotCounts {
  const PilotCounts({
    required this.users,
    required this.entitlements,
    required this.inForce,
    required this.suspended,
    required this.lapsedOrExpired,
    required this.revoked,
    required this.expiringWithin14Days,
  });

  final int users;
  final int entitlements;
  final int inForce;
  final int suspended;
  final int lapsedOrExpired;
  final int revoked;
  final int expiringWithin14Days;

  static PilotCounts decode(Object? payload) {
    final v = wire.object(payload);
    return PilotCounts(
      users: wire.nonNegativeInt(v, 'users'),
      entitlements: wire.nonNegativeInt(v, 'entitlements'),
      inForce: wire.nonNegativeInt(v, 'inForce'),
      suspended: wire.nonNegativeInt(v, 'suspended'),
      lapsedOrExpired: wire.nonNegativeInt(v, 'lapsedOrExpired'),
      revoked: wire.nonNegativeInt(v, 'revoked'),
      expiringWithin14Days: wire.nonNegativeInt(v, 'expiringWithin14Days'),
    );
  }
}

class PilotAiLookTotals {
  const PilotAiLookTotals({
    required this.grantedBase,
    required this.adminAdjustmentsTotal,
    required this.effectiveAllowance,
    required this.committed,
    required this.reserved,
    required this.released,
    required this.remaining,
  });

  final int grantedBase;
  final int adminAdjustmentsTotal;
  final int effectiveAllowance;
  final int committed;
  final int reserved;
  final int released;
  final int remaining;

  static PilotAiLookTotals decode(Object? payload) {
    final v = wire.object(payload);
    return PilotAiLookTotals(
      grantedBase: wire.nonNegativeInt(v, 'grantedBase'),
      adminAdjustmentsTotal: wire.signedInt(v, 'adminAdjustmentsTotal'),
      effectiveAllowance: wire.nonNegativeInt(v, 'effectiveAllowance'),
      committed: wire.nonNegativeInt(v, 'committed'),
      reserved: wire.nonNegativeInt(v, 'reserved'),
      released: wire.nonNegativeInt(v, 'released'),
      remaining: wire.nonNegativeInt(v, 'remaining'),
    );
  }
}

/// Telemetry outcomes for one operation kind.
class OperationOutcomes {
  const OperationOutcomes({
    required this.succeeded,
    required this.failed,
    required this.denied,
    required this.duplicate,
  });

  final int succeeded;
  final int failed;
  final int denied;
  final int duplicate;

  static OperationOutcomes decode(Object? payload) {
    final v = wire.object(payload);
    return OperationOutcomes(
      succeeded: wire.nonNegativeInt(v, 'succeeded'),
      failed: wire.nonNegativeInt(v, 'failed'),
      denied: wire.nonNegativeInt(v, 'denied'),
      duplicate: wire.nonNegativeInt(v, 'duplicate'),
    );
  }
}

class PilotOperationTotals {
  const PilotOperationTotals({
    required this.finalPreview,
    required this.tutorialManifest,
    required this.tutorialStep,
    required this.telemetryEvents,
  });

  final OperationOutcomes finalPreview;
  final OperationOutcomes tutorialManifest;
  final OperationOutcomes tutorialStep;
  final int telemetryEvents;

  static PilotOperationTotals decode(Object? payload) {
    final v = wire.object(payload);
    return PilotOperationTotals(
      finalPreview: OperationOutcomes.decode(v['finalPreview']),
      tutorialManifest: OperationOutcomes.decode(v['tutorialManifest']),
      tutorialStep: OperationOutcomes.decode(v['tutorialStep']),
      telemetryEvents: wire.nonNegativeInt(v, 'telemetryEvents'),
    );
  }
}

/// Provider usage in the units the system actually meters.
class PilotBillableUsage {
  const PilotBillableUsage({
    required this.providerAttempts,
    required this.inputTokens,
    required this.outputTokens,
    required this.totalTokens,
    required this.cachedTokens,
    required this.thoughtsTokens,
    required this.inputImageTokens,
    required this.outputImageTokens,
    required this.outputImages,
    required this.eventsWithTokenData,
    required this.eventsWithoutTokenData,
  });

  final int providerAttempts;
  final int inputTokens;
  final int outputTokens;
  final int totalTokens;
  final int cachedTokens;
  final int thoughtsTokens;
  final int inputImageTokens;
  final int outputImageTokens;
  final int outputImages;
  final int eventsWithTokenData;
  final int eventsWithoutTokenData;

  static PilotBillableUsage decode(Object? payload) {
    final v = wire.object(payload);
    return PilotBillableUsage(
      providerAttempts: wire.nonNegativeInt(v, 'providerAttempts'),
      inputTokens: wire.nonNegativeInt(v, 'inputTokens'),
      outputTokens: wire.nonNegativeInt(v, 'outputTokens'),
      totalTokens: wire.nonNegativeInt(v, 'totalTokens'),
      cachedTokens: wire.nonNegativeInt(v, 'cachedTokens'),
      thoughtsTokens: wire.nonNegativeInt(v, 'thoughtsTokens'),
      inputImageTokens: wire.nonNegativeInt(v, 'inputImageTokens'),
      outputImageTokens: wire.nonNegativeInt(v, 'outputImageTokens'),
      outputImages: wire.nonNegativeInt(v, 'outputImages'),
      eventsWithTokenData: wire.nonNegativeInt(v, 'eventsWithTokenData'),
      eventsWithoutTokenData: wire.nonNegativeInt(v, 'eventsWithoutTokenData'),
    );
  }
}

/// Whether a money figure exists. When [available] is false the figures are
/// null and the page says so; nothing is estimated in their place.
class PilotCostAvailability {
  const PilotCostAvailability({
    required this.available,
    required this.reason,
    required this.currency,
    required this.totalBillableCost,
    required this.effectiveCostPerDeliveredAiLook,
  });

  final bool available;
  final String? reason;
  final String? currency;
  final num? totalBillableCost;
  final num? effectiveCostPerDeliveredAiLook;

  static PilotCostAvailability decode(Object? payload) {
    final v = wire.object(payload);
    final available = wire.boolean(v, 'available');
    final total = v['totalBillableCost'];
    final perLook = v['effectiveCostPerDeliveredAiLook'];
    if (!v.containsKey('totalBillableCost') ||
        !v.containsKey('effectiveCostPerDeliveredAiLook') ||
        (total != null && total is! num) ||
        (perLook != null && perLook is! num) ||
        // A figure without availability, or availability without a figure,
        // is a shape the client refuses rather than guesses at.
        (available && (total == null || perLook == null)) ||
        (!available && (total != null || perLook != null))) {
      wire.malformed();
    }
    return PilotCostAvailability(
      available: available,
      reason: wire.nullableString(v, 'reason'),
      currency: wire.nullableString(v, 'currency'),
      totalBillableCost: total as num?,
      effectiveCostPerDeliveredAiLook: perLook as num?,
    );
  }
}

/// One Salon Pilot entitlement's research row (`admin_list_salon_pilot_metrics`).
class AdminPilotMetricsRow {
  const AdminPilotMetricsRow({
    required this.entitlementId,
    required this.userId,
    required this.email,
    required this.storedStatus,
    required this.effectiveStatus,
    required this.initialAllowance,
    required this.adminAdjustmentsTotal,
    required this.effectiveAllowance,
    required this.committed,
    required this.reserved,
    required this.remaining,
    required this.available,
    required this.deliveredFinalPreviews,
    required this.releasedOperations,
    required this.finalPreviewFailures,
    required this.tutorialOperations,
    required this.tutorialFailures,
    required this.providerAttempts,
    required this.totalTokens,
    required this.outputImages,
    required this.startsAt,
    required this.expiresAt,
    required this.lastActivityAt,
    required this.createdAt,
  });

  final String entitlementId;
  final String userId;
  final String? email;
  final EntitlementStatus storedStatus;
  final EntitlementStatus effectiveStatus;
  final int initialAllowance;
  final int adminAdjustmentsTotal;
  final int effectiveAllowance;
  final int committed;
  final int reserved;
  final int remaining;
  final int available;
  final int deliveredFinalPreviews;
  final int releasedOperations;
  final int finalPreviewFailures;
  final int tutorialOperations;
  final int tutorialFailures;
  final int providerAttempts;
  final int totalTokens;
  final int outputImages;
  final DateTime startsAt;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;
  final DateTime createdAt;

  static AdminPilotMetricsRow decode(Object? payload) {
    final v = wire.object(payload);
    return AdminPilotMetricsRow(
      entitlementId: wire.string(v, 'entitlementId'),
      userId: wire.string(v, 'userId'),
      email: wire.nullableString(v, 'email'),
      storedStatus: wire.vocabulary(
        v,
        'storedStatus',
        EntitlementStatus.fromCode,
      ),
      effectiveStatus: wire.vocabulary(
        v,
        'effectiveStatus',
        EntitlementStatus.fromCode,
      ),
      initialAllowance: wire.nonNegativeInt(v, 'initialAllowance'),
      adminAdjustmentsTotal: wire.signedInt(v, 'adminAdjustmentsTotal'),
      effectiveAllowance: wire.nonNegativeInt(v, 'effectiveAllowance'),
      committed: wire.nonNegativeInt(v, 'committed'),
      reserved: wire.nonNegativeInt(v, 'reserved'),
      remaining: wire.nonNegativeInt(v, 'remaining'),
      available: wire.nonNegativeInt(v, 'available'),
      deliveredFinalPreviews: wire.nonNegativeInt(v, 'deliveredFinalPreviews'),
      releasedOperations: wire.nonNegativeInt(v, 'releasedOperations'),
      finalPreviewFailures: wire.nonNegativeInt(v, 'finalPreviewFailures'),
      tutorialOperations: wire.nonNegativeInt(v, 'tutorialOperations'),
      tutorialFailures: wire.nonNegativeInt(v, 'tutorialFailures'),
      providerAttempts: wire.nonNegativeInt(v, 'providerAttempts'),
      totalTokens: wire.nonNegativeInt(v, 'totalTokens'),
      outputImages: wire.nonNegativeInt(v, 'outputImages'),
      startsAt: wire.date(v, 'startsAt'),
      expiresAt: wire.nullableDate(v, 'expiresAt'),
      lastActivityAt: wire.nullableDate(v, 'lastActivityAt'),
      createdAt: wire.date(v, 'createdAt'),
    );
  }

  static AdminListPage<AdminPilotMetricsRow> decodePage(Object? payload) {
    final v = wire.listEnvelope(payload);
    return AdminListPage(
      items: List.unmodifiable((v['items'] as List).map(decode)),
      nextCursor: wire.nullableString(v, 'nextCursor'),
    );
  }
}
