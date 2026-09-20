import '../entities/allowance_unit.dart';
import '../entities/reset_policy.dart';
import '../entities/subscription_plan_code.dart';
import '../entities/subscription_plan_definition.dart';

/// The single place in the Flutter app where a plan's allowance, unit, or
/// classification is written down.
///
/// ## What this is
///
/// The approved plan configuration, so that `1`, `3`, `30`, `8`, `80`, `35`,
/// `350` and `30` appear exactly once in the client instead of being sprinkled
/// through widgets, controllers, and copy. Anything that needs to describe a
/// plan reads it from here.
///
/// ## What this is not
///
/// **This is not the authority on what a user is entitled to.** A live
/// entitlement carries its own server-resolved `SubscriptionAllowance`, which
/// may legitimately differ from the number below — a Salon Pilot grant that an
/// admin raised to 40 is still `salon_pilot`, and reading `30` from this
/// catalog would understate it. Resolve allowance and capability from the
/// entitlement; use this catalog to describe plans (a paywall's plan
/// comparison, a plan's display name) and as the compile-time record of the
/// approved baseline.
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
    baseAllowance: 1,
    resetPolicy: ResetPolicy.none,
    allowanceUnit: AllowanceUnit.aiLook,
    // The approved V1 Free behaviour, preserved: the one Free look carries
    // the Tutorial like any AI Look does.
    tutorialEnabled: true,
  );

  static const SubscriptionPlanDefinition _plus = SubscriptionPlanDefinition(
    planCode: SubscriptionPlanCode.plus,
    displayName: 'FaceTune Plus',
    publiclyPurchasable: true,
    baseAllowance: 3,
    resetPolicy: ResetPolicy.billingPeriod,
    allowanceUnit: AllowanceUnit.aiLook,
    tutorialEnabled: true,
  );

  // The Preview-only sibling of Plus: same price, ten times the Final
  // Previews, and no Tutorial. Told apart from Plus by its own store product
  // and its configured capability — never by price.
  static const SubscriptionPlanDefinition _plusPreview =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.plusPreview,
        displayName: 'FaceTune Plus Preview',
        publiclyPurchasable: true,
        baseAllowance: 30,
        resetPolicy: ResetPolicy.billingPeriod,
        allowanceUnit: AllowanceUnit.finalPreviewCredit,
        tutorialEnabled: false,
      );

  static const SubscriptionPlanDefinition _pro = SubscriptionPlanDefinition(
    planCode: SubscriptionPlanCode.pro,
    displayName: 'FaceTune Pro',
    publiclyPurchasable: true,
    baseAllowance: 8,
    resetPolicy: ResetPolicy.billingPeriod,
    allowanceUnit: AllowanceUnit.aiLook,
    tutorialEnabled: true,
  );

  static const SubscriptionPlanDefinition _proPreview =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.proPreview,
        displayName: 'FaceTune Pro Preview',
        publiclyPurchasable: true,
        baseAllowance: 80,
        resetPolicy: ResetPolicy.billingPeriod,
        allowanceUnit: AllowanceUnit.finalPreviewCredit,
        tutorialEnabled: false,
      );

  static const SubscriptionPlanDefinition _salonPro =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.salonPro,
        displayName: 'Salon Pro',
        publiclyPurchasable: true,
        // One makeup artist account drawing on a pool of AI Looks. There is no
        // per-client session quota and clients are never counted.
        baseAllowance: 35,
        resetPolicy: ResetPolicy.billingPeriod,
        allowanceUnit: AllowanceUnit.aiLook,
        tutorialEnabled: true,
      );

  static const SubscriptionPlanDefinition _salonPreview =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.salonPreview,
        displayName: 'Salon Preview',
        publiclyPurchasable: true,
        baseAllowance: 350,
        resetPolicy: ResetPolicy.billingPeriod,
        allowanceUnit: AllowanceUnit.finalPreviewCredit,
        tutorialEnabled: false,
      );

  static const SubscriptionPlanDefinition _salonPilot =
      SubscriptionPlanDefinition(
        planCode: SubscriptionPlanCode.salonPilot,
        displayName: 'Salon Pilot',
        // Admin granted and non-public. It must never reach purchase UI.
        publiclyPurchasable: false,
        // The default initial grant. Administratively adjustable afterwards,
        // which is why a live entitlement's own allowance outranks this.
        baseAllowance: 30,
        resetPolicy: ResetPolicy.none,
        allowanceUnit: AllowanceUnit.aiLook,
        tutorialEnabled: true,
      );

  static const Map<SubscriptionPlanCode, SubscriptionPlanDefinition>
  _definitions = {
    SubscriptionPlanCode.free: _free,
    SubscriptionPlanCode.plus: _plus,
    SubscriptionPlanCode.plusPreview: _plusPreview,
    SubscriptionPlanCode.pro: _pro,
    SubscriptionPlanCode.proPreview: _proPreview,
    SubscriptionPlanCode.salonPro: _salonPro,
    SubscriptionPlanCode.salonPreview: _salonPreview,
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

  /// The plans a user may buy, in declaration order — each Tutorial-enabled
  /// plan followed by its Preview-only sibling, consumer tiers before the
  /// professional one.
  static List<SubscriptionPlanDefinition> get publiclyPurchasable =>
      _definitions.values
          .where((definition) => definition.publiclyPurchasable)
          .toList(growable: false);
}
