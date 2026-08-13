import '../../domain/entities/foundation_depth.dart';
import '../../domain/entities/foundation_undertone.dart';
import '../../domain/entities/makeup_kit_category.dart';
import '../../domain/entities/makeup_kit_finish.dart';
import '../../domain/entities/makeup_kit_product.dart';
import '../../domain/value_objects/normalized_hex_color.dart';

/// Maps between raw `makeup_kit_products` Supabase rows and the
/// [MakeupKitProduct] domain entity.
///
/// Every raw value is defensively re-validated here — a database row is
/// untrusted input, even though the columns are also constrained at the
/// schema level (`supabase/migrations/20260813000100_makeup_kit_products.sql`).
abstract final class MakeupKitProductDto {
  /// Parses a raw row (as returned by the Supabase client) into a domain
  /// entity. Throws a [FormatException] if the row is malformed.
  static MakeupKitProduct fromRow(Map<String, Object?> row) {
    return MakeupKitProduct(
      id: _requiredString(row, 'id'),
      userId: _requiredString(row, 'user_id'),
      category: _requiredEnum(row, 'category', MakeupKitCategory.fromCode),
      productName: _optionalString(row, 'product_name'),
      color: _requiredHex(row, 'color_hex'),
      colorLabel: _optionalString(row, 'color_label'),
      finish: _requiredEnum(row, 'finish', MakeupKitFinish.fromCode),
      foundationDepth: _optionalEnum(
        row,
        'foundation_depth',
        FoundationDepth.fromCode,
      ),
      foundationUndertone: _optionalEnum(
        row,
        'foundation_undertone',
        FoundationUndertone.fromCode,
      ),
      createdAt: DateTime.parse(_requiredString(row, 'created_at')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(row, 'updated_at')).toUtc(),
    );
  }

  /// Column values for inserting a new product owned by [userId].
  static Map<String, Object?> toInsertRow({
    required String userId,
    required MakeupKitProductDraft draft,
  }) => {'user_id': userId, ..._editableColumns(draft)};

  /// Column values for replacing an existing product's editable fields.
  static Map<String, Object?> toUpdateRow(MakeupKitProductDraft draft) =>
      _editableColumns(draft);

  static Map<String, Object?> _editableColumns(MakeupKitProductDraft draft) => {
    'category': draft.category.code,
    'product_name': draft.productName,
    'color_hex': draft.color.value,
    'color_label': draft.colorLabel,
    'finish': draft.finish.code,
    'foundation_depth': draft.foundationDepth?.code,
    'foundation_undertone': draft.foundationUndertone?.code,
  };

  static String _requiredString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('$key must be a non-empty string when present.');
    }
    return value;
  }

  static NormalizedHexColor _requiredHex(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is! String) throw FormatException('$key must be a string.');
    final parsed = NormalizedHexColor.tryParse(value);
    if (parsed == null) throw FormatException('$key is not a valid HEX color.');
    return parsed;
  }

  static T _requiredEnum<T>(
    Map<String, Object?> row,
    String key,
    T? Function(String code) fromCode,
  ) {
    final value = row[key];
    if (value is! String) throw FormatException('$key must be a string.');
    final parsed = fromCode(value);
    if (parsed == null) {
      throw FormatException('$key contains an unsupported value.');
    }
    return parsed;
  }

  static T? _optionalEnum<T>(
    Map<String, Object?> row,
    String key,
    T? Function(String code) fromCode,
  ) {
    final value = row[key];
    if (value == null) return null;
    if (value is! String) throw FormatException('$key must be a string.');
    final parsed = fromCode(value);
    if (parsed == null) {
      throw FormatException('$key contains an unsupported value.');
    }
    return parsed;
  }
}
