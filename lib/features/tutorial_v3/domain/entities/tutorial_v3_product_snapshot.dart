import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';

/// The product a step teaches, captured by value at plan time.
///
/// Kit-sourced steps snapshot an owned product: [productId] identifies the
/// `makeup_kit_products` row that was validated when the plan was built, so
/// a later edit or deletion of that product cannot silently change a
/// persisted tutorial. Standard-sourced steps describe a recommended shade
/// that the user does not own, so [productId] is null there.
class TutorialV3ProductSnapshot {
  const TutorialV3ProductSnapshot({
    required this.category,
    this.productId,
    this.productName,
    this.shadeName,
    this.color,
    this.finish,
  });

  /// The Kit category this product belongs to. Must match the category of
  /// the step that carries the snapshot.
  final MakeupKitCategory category;

  /// The owned `makeup_kit_products` row this snapshot was taken from.
  /// Required in Kit mode, and always null in standard mode.
  final String? productId;

  final String? productName;
  final String? shadeName;
  final NormalizedHexColor? color;
  final MakeupKitFinish? finish;

  /// Whether this snapshot refers to a product the user owns.
  bool get isOwnedProduct => productId != null;
}
