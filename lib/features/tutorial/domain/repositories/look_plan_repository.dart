import '../entities/canonical_preview_ref.dart';
import '../entities/validated_look_plan.dart';

/// Resolves the validated look plan behind a canonical final preview.
///
/// There is deliberately no `create` here. Both recommendation modes already
/// produce and validate their plans through the shipped recommendation flow;
/// the tutorial only reads the result. Rebuilding an upstream recommendation
/// inside tutorial code would duplicate server-side ownership validation and
/// risk the two disagreeing.
///
/// Inventory access is likewise absent: `MakeupKitProductsRepository` already
/// owns it. The tutorial never reads live inventory anyway — it reads the
/// immutable snapshot captured when the look was created, so that reopening an
/// old tutorial is unaffected by later edits to the user's kit.
abstract interface class LookPlanRepository {
  /// Loads the validated look plan for [preview].
  ///
  /// The source mode is carried by both the reference and the returned plan,
  /// and the implementation must reject a disagreement rather than trusting
  /// either side alone.
  Future<ValidatedLookPlan> loadForCanonicalPreview(
    CanonicalPreviewRef preview,
  );
}
