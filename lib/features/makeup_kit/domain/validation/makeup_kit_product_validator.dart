import '../catalog/makeup_kit_finish_catalog.dart';
import '../entities/makeup_kit_category.dart';
import '../entities/makeup_kit_product.dart';
import '../errors/makeup_kit_failure.dart';

/// Validates a [MakeupKitProductDraft] before it is sent to persistence.
///
/// This is the single place that enforces cross-field rules the database
/// cannot practically enforce as a per-category matrix (see
/// `supabase/migrations/20260813000100_makeup_kit_products.sql`), so create
/// and update flows fail fast with a clear message rather than relying on a
/// raw Postgres constraint violation reaching the UI.
abstract final class MakeupKitProductValidator {
  static void validate(MakeupKitProductDraft draft) {
    final errors = <String>[];

    if (!MakeupKitFinishCatalog.isValidCombination(
      draft.category,
      draft.finish,
    )) {
      errors.add(
        '${draft.finish.code} is not a valid finish for ${draft.category.code}.',
      );
    }

    if (draft.category != MakeupKitCategory.foundation) {
      if (draft.foundationDepth != null) {
        errors.add('Foundation depth only applies to Foundation products.');
      }
      if (draft.foundationUndertone != null) {
        errors.add('Foundation undertone only applies to Foundation products.');
      }
    }

    if (draft.productName != null && draft.productName!.trim().isEmpty) {
      errors.add('Product name cannot be blank.');
    }

    if (draft.colorLabel != null && draft.colorLabel!.trim().isEmpty) {
      errors.add('Color label cannot be blank.');
    }

    if (errors.isNotEmpty) {
      throw MakeupKitFailure(
        errors.join(' '),
        kind: MakeupKitFailureKind.validation,
        retryable: false,
      );
    }
  }
}
