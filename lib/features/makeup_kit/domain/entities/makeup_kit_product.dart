import 'foundation_depth.dart';
import 'foundation_undertone.dart';
import 'makeup_kit_category.dart';
import 'makeup_kit_finish.dart';
import '../value_objects/normalized_hex_color.dart';

/// A single product an authenticated user has registered in My Makeup Kit.
class MakeupKitProduct {
  const MakeupKitProduct({
    required this.id,
    required this.userId,
    required this.category,
    this.productName,
    required this.color,
    this.colorLabel,
    required this.finish,
    this.foundationDepth,
    this.foundationUndertone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final MakeupKitCategory category;
  final String? productName;
  final NormalizedHexColor color;
  final String? colorLabel;
  final MakeupKitFinish finish;
  final FoundationDepth? foundationDepth;
  final FoundationUndertone? foundationUndertone;
  final DateTime createdAt;
  final DateTime updatedAt;

  MakeupKitProductDraft toDraft() => MakeupKitProductDraft(
    category: category,
    productName: productName,
    color: color,
    colorLabel: colorLabel,
    finish: finish,
    foundationDepth: foundationDepth,
    foundationUndertone: foundationUndertone,
  );
}

/// The editable fields of a My Makeup Kit product, used as input for both
/// creating a new product and replacing an existing one.
///
/// A draft is intentionally a full replacement rather than a sparse patch:
/// validating the whole draft on every create/update call guarantees a
/// category change can never leave stale, incompatible fields behind (e.g.
/// foundation depth surviving a change to Lipstick).
class MakeupKitProductDraft {
  const MakeupKitProductDraft({
    required this.category,
    this.productName,
    required this.color,
    this.colorLabel,
    required this.finish,
    this.foundationDepth,
    this.foundationUndertone,
  });

  final MakeupKitCategory category;
  final String? productName;
  final NormalizedHexColor color;
  final String? colorLabel;
  final MakeupKitFinish finish;
  final FoundationDepth? foundationDepth;
  final FoundationUndertone? foundationUndertone;
}
