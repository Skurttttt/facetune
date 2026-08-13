import 'package:facetune/features/makeup_kit/data/models/makeup_kit_product_dto.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_depth.dart';
import 'package:facetune/features/makeup_kit/domain/entities/foundation_undertone.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_category.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_finish.dart';
import 'package:facetune/features/makeup_kit/domain/entities/makeup_kit_product.dart';
import 'package:facetune/features/makeup_kit/domain/value_objects/normalized_hex_color.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _validRow({
  String category = 'lipstick',
  Object? productName = 'My Nude Lipstick',
  String colorHex = '#B86F72',
  Object? colorLabel = 'Nude Rose',
  String finish = 'matte',
  Object? foundationDepth,
  Object? foundationUndertone,
}) => {
  'id': 'product-1',
  'user_id': 'user-1',
  'category': category,
  'product_name': productName,
  'color_hex': colorHex,
  'color_label': colorLabel,
  'finish': finish,
  'foundation_depth': foundationDepth,
  'foundation_undertone': foundationUndertone,
  'created_at': '2026-08-13T00:00:00Z',
  'updated_at': '2026-08-13T00:00:00Z',
};

void main() {
  group('fromRow', () {
    test('parses a complete lipstick row', () {
      final product = MakeupKitProductDto.fromRow(_validRow());

      expect(product.id, 'product-1');
      expect(product.userId, 'user-1');
      expect(product.category, MakeupKitCategory.lipstick);
      expect(product.productName, 'My Nude Lipstick');
      expect(product.color, NormalizedHexColor.parse('#B86F72'));
      expect(product.colorLabel, 'Nude Rose');
      expect(product.finish, MakeupKitFinish.matte);
      expect(product.foundationDepth, isNull);
      expect(product.foundationUndertone, isNull);
      expect(product.createdAt, DateTime.utc(2026, 8, 13));
      expect(product.updatedAt, DateTime.utc(2026, 8, 13));
    });

    test('parses foundation depth and undertone when present', () {
      final product = MakeupKitProductDto.fromRow(
        _validRow(
          category: 'foundation',
          finish: 'natural',
          foundationDepth: 'medium',
          foundationUndertone: 'warm',
        ),
      );

      expect(product.foundationDepth, FoundationDepth.medium);
      expect(product.foundationUndertone, FoundationUndertone.warm);
    });

    test('parses optional product name and color label as null', () {
      final product = MakeupKitProductDto.fromRow(
        _validRow(productName: null, colorLabel: null),
      );

      expect(product.productName, isNull);
      expect(product.colorLabel, isNull);
    });

    test('rejects an unsupported category code', () {
      expect(
        () => MakeupKitProductDto.fromRow(_validRow(category: 'mascara')),
        throwsFormatException,
      );
    });

    test('rejects an unsupported finish code', () {
      expect(
        () => MakeupKitProductDto.fromRow(_validRow(finish: 'holographic')),
        throwsFormatException,
      );
    });

    test('rejects a malformed hex color', () {
      expect(
        () => MakeupKitProductDto.fromRow(_validRow(colorHex: 'not-a-color')),
        throwsFormatException,
      );
    });

    test('rejects an unsupported foundation depth code', () {
      expect(
        () => MakeupKitProductDto.fromRow(
          _validRow(
            category: 'foundation',
            finish: 'natural',
            foundationDepth: 'extra_deep',
          ),
        ),
        throwsFormatException,
      );
    });

    test('rejects a missing required field', () {
      final row = _validRow()..remove('id');
      expect(() => MakeupKitProductDto.fromRow(row), throwsFormatException);
    });
  });

  group('toInsertRow / toUpdateRow', () {
    test('toInsertRow includes the owner and every editable column', () {
      final row = MakeupKitProductDto.toInsertRow(
        userId: 'user-1',
        draft: MakeupKitProductDraft(
          category: MakeupKitCategory.foundation,
          productName: 'Everyday Foundation',
          color: NormalizedHexColor.parse('#C99578'),
          colorLabel: 'Warm Beige',
          finish: MakeupKitFinish.natural,
          foundationDepth: FoundationDepth.medium,
          foundationUndertone: FoundationUndertone.warm,
        ),
      );

      expect(row, {
        'user_id': 'user-1',
        'category': 'foundation',
        'product_name': 'Everyday Foundation',
        'color_hex': '#C99578',
        'color_label': 'Warm Beige',
        'finish': 'natural',
        'foundation_depth': 'medium',
        'foundation_undertone': 'warm',
      });
    });

    test('toUpdateRow omits the owner column', () {
      final row = MakeupKitProductDto.toUpdateRow(
        MakeupKitProductDraft(
          category: MakeupKitCategory.blush,
          color: NormalizedHexColor.parse('#E69A7A'),
          finish: MakeupKitFinish.satin,
        ),
      );

      expect(row.containsKey('user_id'), isFalse);
      expect(row['category'], 'blush');
      expect(row['finish'], 'satin');
      expect(row['foundation_depth'], isNull);
      expect(row['foundation_undertone'], isNull);
    });
  });
}
