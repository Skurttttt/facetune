import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/subscription_providers.dart';
import '../../domain/entities/purchase_update.dart';
import '../../domain/entities/subscription_plan_code.dart';
import '../../domain/entities/top_up_pack.dart';
import '../../domain/errors/plan_switch_conflict.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/repositories/purchase_verification_gateway.dart';
import '../../domain/repositories/store_billing_gateway.dart';
import '../../domain/repositories/top_up_verification_gateway.dart';
import 'purchase_state.dart';
import 'subscription_controller.dart';

/// Drives the Google Play purchase flow.
///
/// ## The one rule this class exists to enforce
///
/// A provider "purchased" result is not entitlement. Every path through
/// [_handleUpdate] that receives one does exactly the same thing: send the
/// evidence to the backend, and wait. There is no branch that unlocks a
/// feature, stores a plan, or adjusts an allowance, and no field on
/// [PurchaseState] capable of holding one — so the forbidden
/// `if (purchaseSucceeded) { … }` has nowhere to be written.
///
/// After verification succeeds the controller re-reads authoritative state
/// through `SubscriptionController.refresh()`. Note the direction: it asks the
/// server what the account now has. It never tells it.
final purchaseControllerProvider =
    StateNotifierProvider<PurchaseController, PurchaseState>((ref) {
      final controller = PurchaseController(
        store: ref.watch(storeBillingGatewayProvider),
        // Resolved lazily, at the moment a purchase actually needs verifying.
        // Browsing plans requires a store connection but no backend, so a
        // build that cannot reach one still shows the paywall and its prices
        // rather than failing to render it.
        verification: () => ref.read(purchaseVerificationGatewayProvider),
        // The top-up verifier, resolved the same lazy way. A separate gateway
        // and a separate Edge Function, so pack evidence and plan evidence can
        // never take each other's path.
        topUpVerification: () => ref.read(topUpVerificationGatewayProvider),
        // Read at call time rather than watched: refreshing authoritative state
        // is an action taken after a verified purchase, and watching the
        // subscription controller here would rebuild the billing connection
        // every time the account's figures changed.
        refreshSubscription: () =>
            ref.read(subscriptionControllerProvider.notifier).refresh(),
        // The account id is already an opaque identifier. It is passed so the
        // provider — and later the server — can tie a purchase back to the
        // account that started it. No email or display name is ever sent.
        accountId: ref.watch(
          authControllerProvider.select((state) => state.user?.id),
        ),
      )..start();
      // No `ref.onDispose` here: StateNotifierProvider already disposes the
      // notifier it creates, and disposing it a second time throws. The
      // provider stream subscription is released by the override of `dispose`
      // below, and the billing connection itself by
      // `storeBillingGatewayProvider`.
      return controller;
    });

class PurchaseController extends StateNotifier<PurchaseState> {
  PurchaseController({
    required StoreBillingGateway store,
    required PurchaseVerificationGateway Function() verification,
    required Future<void> Function() refreshSubscription,
    TopUpVerificationGateway Function()? topUpVerification,
    String? accountId,
    Duration restoreSettleWindow = const Duration(seconds: 5),
    Duration restoreTimeout = const Duration(seconds: 15),
  }) : _store = store,
       _verification = verification,
       _topUpVerification = topUpVerification,
       _refreshSubscription = refreshSubscription,
       _accountId = accountId,
       _restoreSettleWindow = restoreSettleWindow,
       _restoreTimeout = restoreTimeout,
       super(const PurchaseState());

  final StoreBillingGateway _store;

  /// Resolved on demand rather than held, so constructing this controller
  /// never requires a backend connection. See the provider above.
  final PurchaseVerificationGateway Function() _verification;

  /// The top-up counterpart of [_verification]. Optional so a build without
  /// top-ups wired still runs the subscription flow; a pack purchase arriving
  /// with none configured is refused rather than sent to the plan verifier.
  final TopUpVerificationGateway Function()? _topUpVerification;
  final Future<void> Function() _refreshSubscription;
  final String? _accountId;

  /// How long a restore waits for the provider to deliver what it found.
  ///
  /// The billing SDK has no completion signal for a restore: past purchases
  /// arrive on the same asynchronous stream as new ones, and "none" looks
  /// exactly like "not yet". So the query is given a window, after which
  /// silence is reported as nothing found — a message the user can act on,
  /// rather than a spinner that never resolves. Injectable so tests do not
  /// spend it.
  final Duration _restoreSettleWindow;

  /// How long the provider's own restore query is given to *return* before
  /// the attempt is reported as not completed.
  ///
  /// This bounds a different wait from [_restoreSettleWindow]. The settle
  /// window starts after the query has returned and gives the stream time to
  /// deliver. This one covers the query itself, which on Android is "wait for
  /// the billing service connection, then read the cached purchases" — and
  /// the plugin waits for that connection without limit, re-connecting and
  /// re-issuing the query for as long as the service keeps disconnecting.
  /// Left unbounded, one such stall would leave this controller in
  /// [PurchasePhase.restoring] forever: every purchase and restore action
  /// disabled, and no message to say why.
  ///
  /// Fifteen seconds is the cold-connection budget: a billing service bind
  /// completes in well under five seconds on a healthy device, and the two
  /// purchase reads behind it are local cache reads, so a query still
  /// outstanding at fifteen seconds is not going to answer in a way worth
  /// holding the screen for. Timing out here does not cancel the platform
  /// call. If it does answer later, its purchases still arrive on the stream
  /// and are verified exactly as any other delivery — see
  /// [_verifyWithBackend], which is what keeps a late answer safe.
  final Duration _restoreTimeout;

  /// Whether the provider delivered anything verifiable since the current
  /// restore began. Reset at the start of each restore.
  bool _restoreDeliveredPurchase = false;

  /// Purchase tokens whose backend verification is currently in flight.
  ///
  /// The provider can deliver the same purchase twice in close succession —
  /// a restore query that answered late landing beside a fresh one is the
  /// concrete case — and each delivery would otherwise start its own
  /// verification. The server's activation is idempotent on the purchase, so
  /// a repeat would not grant twice, but there is no reason to spend two round
  /// trips and race two state updates for one piece of evidence. Only the
  /// token is held, never the evidence; it is removed the moment the
  /// verification settles either way.
  final Set<String> _verifying = {};

  StreamSubscription<PurchaseUpdate>? _updates;

  /// Guards against a second provider subscription.
  ///
  /// Two subscriptions would forward each purchase for verification twice.
  /// The gateway already collapses its own provider listener to one; this is
  /// the same protection at the controller, so neither layer relies on the
  /// other being careful.
  bool _started = false;

  /// Connects to the provider and reports whether purchasing is possible.
  Future<void> start() async {
    if (_started) return;
    _started = true;

    _updates = _store.purchaseUpdates.listen(
      _handleUpdate,
      onError: (Object _) {
        if (!mounted) return;
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: 'The connection to Google Play was interrupted.',
        );
      },
    );

    final available = await _store.isAvailable();
    if (!mounted) return;
    state = state.copyWith(
      storeAvailable: available,
      phase: available ? PurchasePhase.idle : PurchasePhase.unavailable,
    );
  }

  /// Opens Google Play's purchase sheet for [plan].
  ///
  /// Refuses plans that are not publicly purchasable by asking the provider for
  /// a product that does not exist — Free and Salon Pilot have no store product
  /// and the gateway rejects them — so this method cannot be turned into a way
  /// to obtain Salon Pilot.
  Future<void> buy(SubscriptionPlanCode plan) async {
    if (!state.canPurchase) return;

    state = state.copyWith(
      phase: PurchasePhase.starting,
      plan: plan,
      clearMessage: true,
      viaRestore: false,
    );

    try {
      await _store.startPurchase(plan, obfuscatedAccountId: _accountId);
    } on PlanSwitchConflict catch (conflict) {
      if (!mounted) return;
      // The gateway refused to open the sheet because of what the provider
      // already holds — a second active subscription, the same plan, or a
      // switch with no approved terms. Nothing was started, so the current
      // plan is untouched; the copy says what the user can do about it.
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message: conflict.message,
      );
    } on Object {
      if (!mounted) return;
      // Deliberately not the caught object's text: a provider or platform
      // message is not written for users and can name internal state.
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play could not open the purchase. Please try again in a '
            'moment.',
      );
    }
  }

  /// Opens Google Play's purchase sheet for a top-up [pack].
  ///
  /// The same shape as [buy]: the sheet is opened and nothing else happens
  /// here. The purchase arrives on the provider stream carrying the pack as a
  /// routing hint, is verified by the server, and the credits it grants are
  /// read back — never counted here.
  ///
  /// The paywall only offers a pack to an account the server says may use
  /// one, but that is a courtesy, not the gate: the server refuses a grant to
  /// an ineligible account, and Google refunds the unconsumed purchase.
  Future<void> buyTopUp(TopUpPack pack) async {
    if (!state.canPurchase) return;

    state = state.copyWith(
      phase: PurchasePhase.starting,
      // Naming the pack clears any plan hint; see `PurchaseState.copyWith`.
      topUpPack: pack,
      clearMessage: true,
      viaRestore: false,
    );

    try {
      await _store.startTopUpPurchase(pack, obfuscatedAccountId: _accountId);
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play could not open the purchase. Please try again in a '
            'moment.',
      );
    }
  }

  /// Recovers a subscription this account already owns.
  ///
  /// The path a restored purchase takes is deliberately the same one a fresh
  /// purchase takes — provider evidence, server verification, authoritative
  /// re-read — because "I bought this before" is not a stronger claim than "I
  /// am buying this now". Both are claims, and neither grants anything.
  ///
  /// Idempotent from the user's side: restoring twice verifies the same
  /// purchase twice, and the server's activation is keyed on the purchase, so
  /// the second pass lands on the same entitlement rather than a second one.
  Future<void> restore() async {
    if (!state.canPurchase) return;

    _restoreDeliveredPurchase = false;
    state = state.copyWith(
      phase: PurchasePhase.restoring,
      clearMessage: true,
      clearPlan: true,
      viaRestore: true,
    );

    try {
      await _store.restorePurchases().timeout(_restoreTimeout);
    } on TimeoutException {
      if (!mounted) return;
      // The provider may have delivered before its query returned; if so the
      // handler has already moved the phase on and this attempt is theirs.
      if (state.phase != PurchasePhase.restoring) return;
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play did not respond while checking your previous '
            'purchases. Please try again in a moment.',
      );
      return;
    } on Object {
      if (!mounted) return;
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play could not check your previous purchases. Please try '
            'again in a moment.',
      );
      return;
    }

    await Future<void>.delayed(_restoreSettleWindow);
    if (!mounted) return;

    // Anything the provider delivered has already moved the phase on, through
    // the same handler a live purchase uses. Only an untouched `restoring`
    // phase means the window closed in silence.
    if (state.phase != PurchasePhase.restoring) return;
    if (_restoreDeliveredPurchase) return;

    state = state.copyWith(
      phase: PurchasePhase.restoredNothing,
      message:
          'Google Play has no previous FaceTune subscription for this '
          'account. If you subscribed with a different Google account, sign '
          'in to that one on this device and try again.',
    );
  }

  /// Clears a finished attempt so the surface returns to a neutral state.
  void acknowledgeMessage() {
    if (state.isBusy) return;
    state = state.copyWith(
      phase: state.storeAvailable
          ? PurchasePhase.idle
          : PurchasePhase.unavailable,
      clearMessage: true,
      clearPlan: true,
      viaRestore: false,
    );
  }

  Future<void> _handleUpdate(PurchaseUpdate update) async {
    if (!mounted) return;

    switch (update.status) {
      case PurchaseUpdateStatus.pending:
        state = state.copyWith(
          phase: PurchasePhase.awaitingPayment,
          plan: update.planCode,
          topUpPack: update.topUpPack,
          message: update.isTopUp
              ? 'Google Play is waiting for your payment to complete. Your '
                    'credits are added once it does.'
              : 'Google Play is waiting for your payment to complete. Your '
                    'plan starts once it does.',
        );

      case PurchaseUpdateStatus.purchased:
      case PurchaseUpdateStatus.restored:
        // Noted before verification starts, so a restore that found something
        // never also reports that it found nothing when its window closes.
        _restoreDeliveredPurchase = true;
        if (update.isTopUp) {
          await _verifyTopUpWithBackend(update);
        } else {
          await _verifyWithBackend(update);
        }

      case PurchaseUpdateStatus.cancelled:
        state = state.copyWith(
          phase: PurchasePhase.cancelled,
          clearMessage: true,
          clearPlan: true,
        );

      case PurchaseUpdateStatus.failed:
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: update.message ?? 'The purchase did not go through.',
        );
    }
  }

  /// The only thing this app does with a successful provider purchase.
  ///
  /// The order below is deliberate and is the whole security property:
  ///
  /// ```text
  /// verify with the server  →  acknowledge with the provider  →  re-read state
  /// ```
  ///
  /// Acknowledging first would tell Google the entitlement was delivered before
  /// anything had checked that it should be, and would waive the automatic
  /// refund that currently protects a user whose purchase cannot be verified.
  Future<void> _verifyWithBackend(PurchaseUpdate update) async {
    final evidence = update.evidence;
    if (evidence == null || !update.hasVerifiableEvidence) {
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play did not return enough information to confirm this '
            'purchase.',
      );
      return;
    }

    // One verification per piece of evidence at a time. A second delivery of
    // the same purchase while the first is still with the server is dropped
    // here; the first's outcome is the outcome for both.
    if (!_verifying.add(evidence.purchaseToken)) return;

    state = state.copyWith(
      phase: PurchasePhase.verifying,
      plan: update.planCode,
      message: 'Confirming your purchase…',
    );

    try {
      try {
        await _verification().verify(
          evidence,
          source: update.status == PurchaseUpdateStatus.restored
              ? PurchaseVerificationSource.restore
              : PurchaseVerificationSource.purchase,
        );
      } on SubscriptionStateFailure catch (failure) {
        if (!mounted) return;
        // The purchase stays unacknowledged on purpose. Google refunds an
        // unacknowledged purchase automatically, which is the correct outcome
        // for a purchase nothing was able to verify.
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: failure.message,
        );
        return;
      } on Object {
        if (!mounted) return;
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: 'Your purchase could not be confirmed. Please try again.',
        );
        return;
      }

      // Verified. Only now may the provider be told the purchase was handled.
      if (update.awaitingCompletion) {
        await _store.completeVerifiedPurchase(evidence);
      }

      // Ask the server what the account actually has. Nothing here decides it.
      await _refreshSubscription();
      if (!mounted) return;
      state = state.copyWith(
        phase: PurchasePhase.verified,
        message: 'Your purchase is confirmed.',
      );
    } finally {
      _verifying.remove(evidence.purchaseToken);
    }
  }

  /// The only thing this app does with a successful top-up pack purchase.
  ///
  /// The same order as [_verifyWithBackend], for the same reason:
  ///
  /// ```text
  /// verify + grant on the server  →  consume with the provider  →  re-read
  /// ```
  ///
  /// Consuming first would tell Google the credits were delivered before
  /// anything had checked that they should be, and would waive the automatic
  /// refund that protects a purchase nothing was able to verify. Normally the
  /// server consumes itself, immediately after the grant; the device consumes
  /// only when the server reports it could not, and the grant already exists
  /// either way. Nothing here counts a credit.
  Future<void> _verifyTopUpWithBackend(PurchaseUpdate update) async {
    final evidence = update.evidence;
    if (evidence == null || !update.hasVerifiableEvidence) {
      state = state.copyWith(
        phase: PurchasePhase.failed,
        message:
            'Google Play did not return enough information to confirm this '
            'purchase.',
      );
      return;
    }

    if (!_verifying.add(evidence.purchaseToken)) return;

    state = state.copyWith(
      phase: PurchasePhase.verifying,
      topUpPack: update.topUpPack,
      message: 'Confirming your purchase…',
    );

    try {
      final verifier = _topUpVerification;
      if (verifier == null) {
        // Nothing can grant a credit in this build. The purchase is left
        // unconsumed on purpose, so Google refunds it.
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message:
              'Top-up packs cannot be confirmed yet. If you were charged, '
              'Google Play will refund it automatically.',
        );
        return;
      }

      TopUpVerificationResult result;
      try {
        result = await verifier().verify(
          evidence,
          source: update.status == PurchaseUpdateStatus.restored
              ? PurchaseVerificationSource.restore
              : PurchaseVerificationSource.purchase,
        );
      } on SubscriptionStateFailure catch (failure) {
        if (!mounted) return;
        // Unconsumed on purpose: an unverified pack is refunded by Google.
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: failure.message,
        );
        return;
      } on Object {
        if (!mounted) return;
        state = state.copyWith(
          phase: PurchasePhase.failed,
          message: 'Your purchase could not be confirmed. Please try again.',
        );
        return;
      }

      // Granted. Only now may the provider be told the purchase was handled.
      await _store.completeVerifiedTopUp(
        evidence,
        consumedByServer: result.consumedByServer,
      );

      // Ask the server what the account actually has. Nothing here decides it.
      await _refreshSubscription();
      if (!mounted) return;
      state = state.copyWith(
        phase: PurchasePhase.verified,
        message: result.replayed
            ? 'This purchase was already added to your account.'
            : 'Your purchase is confirmed. Your credits have been added.',
      );
    } finally {
      _verifying.remove(evidence.purchaseToken);
    }
  }

  @override
  void dispose() {
    _updates?.cancel();
    _updates = null;
    super.dispose();
  }
}
