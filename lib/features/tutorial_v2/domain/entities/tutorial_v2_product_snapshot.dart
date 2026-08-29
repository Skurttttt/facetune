import '../../../makeup_kit/domain/entities/foundation_depth.dart';
import '../../../makeup_kit/domain/entities/foundation_undertone.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'tutorial_v2_category.dart';

/// Immutable point-in-time data for the owned product a Kit-mode tutorial
/// step teaches.
///
/// The snapshot is persisted with the tutorial rather than joined from live
/// inventory, so a saved tutorial stays historically accurate after the user
/// edits or deletes the product (Source of Truth §10). This mirrors what
/// `KitProductSnapshot` already does for Kit recommendations, but keeps the
/// values strongly typed instead of raw strings so an invalid finish or
/// colour cannot reach the AI boundary.
///
/// [productName] is optional: users are not required to name a product.
class TutorialV2ProductSnapshot {
  const TutorialV2ProductSnapshot({
    required this.productId,
    required this.category,
    required this.color,
    required this.finish,
    this.productName,
    this.colorLabel,
    this.foundationDepth,
    this.foundationUndertone,
  });

  final String productId;
  final TutorialV2Category category;
  final NormalizedHexColor color;
  final MakeupKitFinish finish;
  final String? productName;
  final String? colorLabel;
  final FoundationDepth? foundationDepth;
  final FoundationUndertone? foundationUndertone;

  /// The shade name shown to the user, when one exists.
  String? get shadeName => colorLabel;

  @override
  bool operator ==(Object other) =>
      other is TutorialV2ProductSnapshot &&
      other.productId == productId &&
      other.category == category &&
      other.color == color &&
      other.finish == finish &&
      other.productName == productName &&
      other.colorLabel == colorLabel &&
      other.foundationDepth == foundationDepth &&
      other.foundationUndertone == foundationUndertone;

  @override
  int get hashCode => Object.hash(
    productId,
    category,
    color,
    finish,
    productName,
    colorLabel,
    foundationDepth,
    foundationUndertone,
  );
}
