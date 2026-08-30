import '../../../makeup_kit/domain/entities/foundation_depth.dart';
import '../../../makeup_kit/domain/entities/foundation_undertone.dart';
import '../../../makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_category.dart';
import '../../../makeup_kit/domain/entities/makeup_kit_finish.dart';
import '../../../makeup_kit/domain/value_objects/normalized_hex_color.dart';
import '../catalog/tutorial_category_mapping.dart';
import '../entities/tutorial_category.dart';
import '../errors/tutorial_failure.dart';

/// One immutable, point-in-time record of an owned product that was validated
/// and selected for a look.
///
/// This is deliberately a *typed* contract rather than the loosely-typed
/// [KitProductSnapshot] already persisted with kit recommendations. Tutorial
/// code routes on category and renders colour and finish, so both must be
/// parsed and rejected once at the boundary rather than re-parsed as raw
/// strings at every use site.
///
/// A snapshot is historical data. It intentionally does not track later edits
/// to the underlying inventory product: reopening an old look must show the
/// product as it was when the look was created, even if the user has since
/// changed its shade or deleted it entirely.
///
/// Product *identity* (what the user owns) lives here. Visual *placement*
/// authority (where and how the makeup appears) never does — that is grounded
/// only in the canonical final preview. The two are separate systems and this
/// type carries no placement, technique, or coverage data.
class LookProductSnapshotItem {
  const LookProductSnapshotItem({
    required this.productId,
    required this.kitCategory,
    required this.color,
    required this.finish,
    this.productName,
    this.colorLabel,
    this.foundationDepth,
    this.foundationUndertone,
  });

  /// The inventory product this snapshot was taken from.
  ///
  /// A reference for provenance only. The product row may since have been
  /// edited or deleted; this snapshot stays authoritative for the look.
  final String productId;

  /// The inventory category, preserved exactly as registered.
  ///
  /// Kept alongside [tutorialCategory] because Lipstick and Lip Gloss both
  /// present in the Lips step and the user must still be able to tell which
  /// product is which.
  final MakeupKitCategory kitCategory;

  final NormalizedHexColor color;
  final MakeupKitFinish finish;

  /// The user-supplied commercial name, when they chose to provide one. An
  /// incomplete kit is valid, so this is optional.
  final String? productName;
  final String? colorLabel;
  final FoundationDepth? foundationDepth;
  final FoundationUndertone? foundationUndertone;

  /// The tutorial step this product belongs to, derived from the
  /// application-owned mapping rather than stored.
  TutorialCategory get tutorialCategory =>
      TutorialCategoryMapping.fromKitCategory(kitCategory);

  /// Parses a persisted kit snapshot into the typed tutorial contract.
  ///
  /// Throws a [TutorialFailure] with
  /// [TutorialFailureKind.unsupportedCategory] when the stored category or
  /// finish is outside the controlled vocabulary, and
  /// [TutorialFailureKind.validation] when the stored colour is malformed.
  /// Rejecting here means no unsupported category can reach step generation.
  factory LookProductSnapshotItem.fromKitSnapshot(KitProductSnapshot snapshot) {
    final category = MakeupKitCategory.fromCode(snapshot.category);
    if (category == null) {
      throw TutorialFailure(
        'This look references a product category the tutorial does not '
        'support.',
        kind: TutorialFailureKind.unsupportedCategory,
        retryable: false,
      );
    }
    final finish = MakeupKitFinish.fromCode(snapshot.finish);
    if (finish == null) {
      throw TutorialFailure(
        'This look references a product finish the tutorial does not support.',
        kind: TutorialFailureKind.unsupportedCategory,
        retryable: false,
      );
    }
    final color = NormalizedHexColor.tryParse(snapshot.colorHex);
    if (color == null) {
      throw TutorialFailure(
        'This look references a product colour that could not be read.',
        kind: TutorialFailureKind.validation,
        retryable: false,
      );
    }
    return LookProductSnapshotItem(
      productId: snapshot.productId,
      kitCategory: category,
      color: color,
      finish: finish,
      productName: snapshot.productName,
      colorLabel: snapshot.colorLabel,
      foundationDepth: snapshot.foundationDepth == null
          ? null
          : FoundationDepth.fromCode(snapshot.foundationDepth!),
      foundationUndertone: snapshot.foundationUndertone == null
          ? null
          : FoundationUndertone.fromCode(snapshot.foundationUndertone!),
    );
  }
}

/// The complete immutable set of owned products validated for one look.
///
/// An empty or partial snapshot is a legitimate state: users are never
/// required to own a product in every category, and the system never invents a
/// missing one. Absence is represented by the category simply not appearing in
/// [items].
class LookProductSnapshot {
  LookProductSnapshot({required List<LookProductSnapshotItem> items})
    : items = List<LookProductSnapshotItem>.unmodifiable(items);

  /// An empty snapshot — a valid, fully-representable state.
  static final LookProductSnapshot empty = LookProductSnapshot(
    items: const <LookProductSnapshotItem>[],
  );

  final List<LookProductSnapshotItem> items;

  /// Every snapshot item that belongs to [category], preserving order.
  ///
  /// Returns more than one item where several owned products were
  /// intentionally used for the same tutorial step — a Lipstick and a Lip
  /// Gloss both applied in the Lips step being the canonical case.
  List<LookProductSnapshotItem> itemsFor(TutorialCategory category) =>
      List<LookProductSnapshotItem>.unmodifiable(
        items.where((item) => item.tutorialCategory == category),
      );

  /// Whether any owned product was selected for [category].
  bool covers(TutorialCategory category) =>
      items.any((item) => item.tutorialCategory == category);

  /// The tutorial categories backed by at least one selected product, in
  /// deterministic logical order.
  ///
  /// This is product coverage only — not tutorial inclusion. A category
  /// appearing here still requires visual grounding in the canonical final
  /// preview before it becomes a step.
  List<TutorialCategory> get coveredCategories =>
      TutorialCategory.orderedSubset(
        items.map((item) => item.tutorialCategory),
      );

  /// Parses a persisted kit snapshot list into the typed tutorial contract.
  factory LookProductSnapshot.fromKitSnapshots(
    List<KitProductSnapshot> snapshots,
  ) => LookProductSnapshot(
    items: snapshots.map(LookProductSnapshotItem.fromKitSnapshot).toList(),
  );
}
