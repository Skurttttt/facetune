import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../authentication/presentation/controllers/auth_controller.dart';
import '../../data/providers/subscription_providers.dart';
import '../../domain/errors/subscription_state_failure.dart';
import '../../domain/usecases/resolve_subscription_summary.dart';
import 'subscription_state.dart';

/// Holds the account's authoritative subscription state.
///
/// Rebuilt when the signed-in account changes, following the existing
/// convention (`settingsControllerProvider`, `makeupPreviewControllerProvider`)
/// of watching only the user id. Watching the whole auth state would rebuild
/// this on every unrelated auth field change and re-fetch needlessly.
///
/// The load is kicked off here, once, when the controller is created — not
/// from a widget `build()`. Nothing in this file can trigger a paid
/// generation; the only call it makes is the read-only resolver.
final subscriptionControllerProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>((ref) {
      final userId = ref.watch(
        authControllerProvider.select((state) => state.user?.id),
      );
      final controller = SubscriptionController(
        ref.watch(resolveSubscriptionSummaryProvider),
      );
      if (userId != null) {
        controller.load();
      } else {
        controller.markSignedOut();
      }
      return controller;
    });

class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController(this._resolve) : super(const SubscriptionState());

  final ResolveSubscriptionSummary _resolve;

  /// Monotonic counter identifying the newest request.
  ///
  /// A slow response from an earlier call must never overwrite a newer answer.
  /// Comparing against this on completion discards the stale one, which is the
  /// same epoch guard `MakeupPreviewController` uses.
  int _epoch = 0;

  /// First load: shows a loading state because there is nothing behind it.
  Future<void> load() => _fetch(refreshing: false);

  /// Deliberate re-read — a lifecycle event, a pull-to-refresh, or a return
  /// from a purchase flow. Keeps the current figures on screen while it runs.
  ///
  /// Callers drive this from explicit events. It is never called from `build()`
  /// and never on a timer, so a rebuilding widget cannot generate backend
  /// traffic.
  Future<void> refresh() => _fetch(refreshing: true);

  /// Clears account-specific state when the session ends.
  ///
  /// The summary is dropped rather than kept: the next account to sign in must
  /// never briefly see the previous account's plan or remaining AI Looks.
  void markSignedOut() {
    _epoch += 1;
    state = const SubscriptionState(status: SubscriptionStatus.signedOut);
  }

  Future<void> _fetch({required bool refreshing}) async {
    // A read already in flight is not duplicated. A rebuild storm therefore
    // cannot fan out into repeated backend calls.
    if (state.status == SubscriptionStatus.loading ||
        state.status == SubscriptionStatus.refreshing) {
      return;
    }

    final operation = ++_epoch;
    state = refreshing && state.hasSummary
        ? state.copyWith(
            status: SubscriptionStatus.refreshing,
            clearMessage: true,
          )
        : const SubscriptionState(status: SubscriptionStatus.loading);

    try {
      final summary = await _resolve();
      if (!mounted || operation != _epoch) return;
      state = SubscriptionState(
        status: SubscriptionStatus.ready,
        summary: summary,
      );
    } on SubscriptionStateFailure catch (failure) {
      if (!mounted || operation != _epoch) return;
      // A session failure clears the summary; anything else keeps the last
      // known answer visible behind the error, because stale figures are more
      // useful than none and are never authoritative anyway.
      state = failure.kind == SubscriptionStateFailureKind.sessionExpired
          ? SubscriptionState(
              status: SubscriptionStatus.failure,
              message: failure.message,
              failureKind: failure.kind,
              retryable: failure.retryable,
            )
          : SubscriptionState(
              status: SubscriptionStatus.failure,
              summary: state.summary,
              message: failure.message,
              failureKind: failure.kind,
              retryable: failure.retryable,
            );
    } on Object {
      if (!mounted || operation != _epoch) return;
      state = SubscriptionState(
        status: SubscriptionStatus.failure,
        summary: state.summary,
        message: 'Your subscription could not be loaded. Please try again.',
        failureKind: SubscriptionStateFailureKind.unknown,
      );
    }
  }
}
