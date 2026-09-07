import '../entities/reset_policy.dart';
import '../entities/subscription_plan_code.dart';
import '../entities/subscription_plan_definition.dart';

/// The single place in the Flutter app where a V1 plan's allowance or
/// classification is written down.
///
/// ## What this is
///
/// The approved V1 plan configuration, so that `3`, `8`, `35`, `30`, and `1`
/// appear exactly once in the client instead of being sprinkled through
/// widgets, controllers, and copy. Anything that needs to describe a plan reads
/// it from here.
///
/// ## What this is not
///
/// **This is not the authority on what a user is entitled to.** A live
/// entitlement carries its own server-resolved `SubscriptionAllowance`, which
/// may legitimately differ from the number below — a Salon Pilot grant that an
/// admin raised to 40 is still `salon_pilot`, and reading `30` from this
/// catalog would understate it. Resolve allowance from the entitlement; use
/// this catalog to describe plans (a paywall's plan comparison, a plan's
/// display name) and as the compile-time record of the approved baseline.
///
/// Changing a value here changes what the app *claims*. It does not change what
/// the backend grants, and it must never be used to try.
abstract final class SubscriptionPlanCatalog {
  static const SubscriptionPlanDefinition _free = SubscriptionPlanDefinition(
    planCode: SubscriptionPlanCode.free,
    displayName: 'FaceTune Free',
    // Not "publicly purchasable" because there is nothing to purchase: Free is
    // the default entitlement, not a product in a store.
    publiclyPurchasable: false,
    // One complimentary AI Look, granted once and never replenished.
    baseAiLookAllowance: 1,
    resetPolicy: ResetPolicy.none,
  );

  static const SubscriptionPlanDefinition _plus = SubscriptionPlanDefinition(
    planCode: SubscriptionPlanCode.plus,
    displayName: 'FaceTune Plus',
    publiclyPurchasable: true,
    baseAiLookAllowance: 3,
    resetPolicy: ResetPolicy.billingPeriod,
  );

  static const SubscriptionPlanDefinition _pro = SubscriptionPlanDefinition(
    planCode: SubscriptionPlanCode.pro,
    displayName: 'FaceTune Pro',
    publiclyPurchasable: true,
    baseAiLookAllowance: 8,
    resetPolicy: ResetPolicy.billingPeriod,
  );

  static const SubscriptionPlanDefinition _salonPro =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.salonPro,
        displayName: 'Salon Pro',
        publiclyPurchasable: true,
        // One makeup artist account drawing on a pool of AI Looks. There is no
        // per-client session quota and clients are never counted.
        baseAiLookAllowance: 35,
        resetPolicy: ResetPolicy.billingPeriod,
      );

  static const SubscriptionPlanDefinition _salonPilot =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.salonPilot,
        displayName: 'Salon Pilot',
        // Admin granted and non-public. It must never reach purchase UI.
        publiclyPurchasable: false,
        // The default initial grant. Administratively adjustable afterwards,
        // which is why a live entitlement's own allowance outranks this.
        baseAiLookAllowance: 30,
        resetPolicy: ResetPolicy.none,
      );

  static const Map<SubscriptionPlanCode, SubscriptionPlanDefinition>
  _definitions = {
    SubscriptionPlanCode.free: _free,
    SubscriptionPlanCode.plus: _plus,
    SubscriptionPlanCode.pro: _pro,
    SubscriptionPlanCode.salonPro: _salonPro,
    SubscriptionPlanCode.salonPilot: _salonPilot,
  };

  /// The definition for [planCode].
  ///
  /// Total by construction: every member of the controlled vocabulary has a
  /// definition, which `subscription_plan_catalog_test.dart` pins so that
  /// adding a plan code without a definition fails a test rather than throwing
  /// at runtime.
  static SubscriptionPlanDefinition definitionFor(
    SubscriptionPlanCode planCode,
  ) => _definitions[planCode]!;

  /// Every plan definition, in declaration order.
  static List<SubscriptionPlanDefinition> get all =>
      _definitions.values.toList(growable: false);

  /// The plans a user may buy, in ascending allowance order — the order a
  /// paywall presents them in.
  static List<SubscriptionPlanDefinition> get publiclyPurchasable =>
      _definitions.values
          .where((definition) => definition.publiclyPurchasable)
          .toList(growable: false);
}
