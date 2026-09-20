import 'dart:async';

import 'package:facetune/features/subscription/domain/entities/purchase_evidence.dart';
import 'package:facetune/features/subscription/domain/entities/purchase_update.dart';
import 'package:facetune/features/subscription/domain/entities/store_product.dart';
import 'package:facetune/features/subscription/domain/entities/subscription_plan_code.dart';
import 'package:facetune/features/subscription/domain/repositories/purchase_verification_gateway.dart';
import 'package:facetune/features/subscription/domain/repositories/store_billing_gateway.dart';

/// A billing provider driven entirely from a test.
///
/// Implements the domain interface rather than the SDK, which is the point of
/// that interface existing: the purchase flow's security properties can be
/// exercised without a store, a device, or a platform channel.
class FakeStoreBillingGateway implements StoreBillingGateway {
  FakeStoreBillingGateway({
    this.available = true,
    this.products = const [],
    this.startThrows,
  });

  final bool available;
  final List<StoreProduct> products;

  /// Thrown from [startPurchase] to simulate a provider that would not open.
  final Object? startThrows;

  final StreamController<PurchaseUpdate> updates =
      StreamController<PurchaseUpdate>.broadcast();

  final List<SubscriptionPlanCode> started = [];
  final List<String?> accountIds = [];
  final List<PurchaseEvidence> completed = [];

  /// How many times the update stream was read, to prove one provider
  /// subscription is shared rather than one attached per listener.
  int streamReads = 0;
  int disposeCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<StoreProduct>> loadProducts() async => products;

  @override
  Stream<PurchaseUpdate> get purchaseUpdates {
    streamReads++;
    return updates.stream;
  }

  @override
  Future<void> startPurchase(
    SubscriptionPlanCode plan, {
    String? obfuscatedAccountId,
  }) async {
    final failure = startThrows;
    if (failure != null) throw failure;
    started.add(plan);
    accountIds.add(obfuscatedAccountId);
  }

  /// How many times a restore was requested, and what the fake should do.
  int restoreCount = 0;

  /// Thrown from [restorePurchases] to simulate a provider that refused the
  /// query — the case that must not end in a restored plan.
  Object? restoreThrows;

  /// Delivered on the update stream when a restore is requested, standing in
  /// for the purchases Play already holds for the account.
  List<PurchaseUpdate> restoreDelivers = const [];

  /// When set, the provider query does not return until the test completes
  /// it — a stalled billing connection, from the controller's point of view.
  /// Whatever [restoreDelivers] holds at completion time is delivered then.
  Completer<void>? restoreGate;

  @override
  Future<void> restorePurchases() async {
    restoreCount++;
    final failure = restoreThrows;
    if (failure != null) throw failure;
    await restoreGate?.future;
    for (final update in restoreDelivers) {
      if (!updates.isClosed) updates.add(update);
    }
  }

  @override
  Future<void> completeVerifiedPurchase(PurchaseEvidence evidence) async {
    completed.add(evidence);
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    if (!updates.isClosed) await updates.close();
  }
}

/// A verification backend that records what it was asked to verify.
///
/// [failure], when set, is thrown to stand in for a server that refused or
/// could not be reached — the case that must never end in a granted plan.
class FakePurchaseVerificationGateway implements PurchaseVerificationGateway {
  FakePurchaseVerificationGateway({this.failure, this.gate});

  final Object? failure;
  final List<PurchaseEvidence> received = [];

  /// When set, a verification is recorded at once but does not answer until
  /// the test completes it — so a second delivery can arrive mid-flight.
  final Completer<void>? gate;

  @override
  Future<void> verify(PurchaseEvidence evidence) async {
    received.add(evidence);
    await gate?.future;
    final thrown = failure;
    if (thrown != null) throw thrown;
  }
}
