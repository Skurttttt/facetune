import '../catalog/subscription_plan_catalog.dart';
import '../entities/subscription_plan_code.dart';

/// Why a subscription purchase was refused *before* the provider's sheet was
/// opened, because of what the provider already holds for the account.
enum PlanSwitchConflictKind {
  /// The provider reports more than one active FaceTune subscription for this
  /// Google account. There is no safe purchase to replace, and starting one
  /// would add a third. The user has to reduce the account to one
  /// subscription in Google Play first.
  multipleActiveSubscriptions,

  /// The provider already reports the requested product as active. Buying it
  /// again is not possible; the purchase should be restored instead.
  alreadyOwned,

  /// The requested change is between plans whose replacement terms are not
  /// approved. Nothing is started until commercial policy says how.
  unapprovedSwitch,
}

/// A controlled refusal to start a subscription purchase.
///
/// Follows the shape of `SubscriptionStateFailure`: a kind the UI can branch
/// on and copy it can show, with no provider payload and no purchase token.
/// Thrown by the billing gateway, which is the only layer that can see what
/// the provider holds; caught by the purchase controller, which shows it.
class PlanSwitchConflict implements Exception {
  const PlanSwitchConflict(this.kind, this.message);

  /// More than one active subscription on the provider side.
  ///
  /// Recovery guidance rather than an apology: the state is real, the app
  /// cannot fix it, and the user can. The current plan is unaffected because
  /// nothing was started.
  const PlanSwitchConflict.multipleActiveSubscriptions()
    : this(
        PlanSwitchConflictKind.multipleActiveSubscriptions,
        'Google Play shows more than one active FaceTune subscription on '
        'this Google account, so the app cannot tell which one to change. '
        'Open Google Play, go to Payments & subscriptions, cancel the '
        'subscription you do not want and wait for it to end, then try '
        'again. Your current plan is not affected.',
      );

  /// The requested plan is already active with the provider.
  const PlanSwitchConflict.alreadyOwned()
    : this(
        PlanSwitchConflictKind.alreadyOwned,
        'Google Play shows this plan is already active on this Google '
        'account. Use Restore purchases to bring it into FaceTune.',
      );

  /// The requested switch has no approved replacement terms.
  PlanSwitchConflict.unapprovedSwitch({
    required SubscriptionPlanCode from,
    required SubscriptionPlanCode to,
  }) : this(
         PlanSwitchConflictKind.unapprovedSwitch,
         'Switching from ${_nameOf(from)} to ${_nameOf(to)} is not available '
         'in the app yet. Plan changes are currently offered only between a '
         'plan and its Preview edition.',
       );

  final PlanSwitchConflictKind kind;

  /// Sanitized, user-facing copy. Never a provider payload, never a token.
  final String message;

  static String _nameOf(SubscriptionPlanCode plan) =>
      SubscriptionPlanCatalog.definitionFor(plan).displayName;

  @override
  String toString() => message;
}
