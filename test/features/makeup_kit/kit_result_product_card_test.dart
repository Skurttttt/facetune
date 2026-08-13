import 'package:facetune/features/makeup_kit/domain/entities/kit_makeup_recommendation.dart';
import 'package:facetune/features/makeup_kit/presentation/widgets/kit_result_product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows the immutable owned-product snapshot and foundation metadata',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KitResultProductCard(
              selection: KitMakeupSelection(
                productId: 'product-1',
                category: 'foundation',
                colorHex: '#C99578',
                finish: 'natural',
                placement: 'Thin layer across the face',
                technique: 'Blend lightly',
                intensity: 'soft',
              ),
              snapshot: KitProductSnapshot(
                productId: 'product-1',
                category: 'foundation',
                productName: 'Everyday base',
                colorHex: '#C99578',
                colorLabel: 'Warm beige',
                finish: 'natural',
                foundationDepth: 'medium',
                foundationUndertone: 'warm',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Everyday base'), findsOneWidget);
      expect(find.textContaining('Foundation'), findsOneWidget);
      expect(find.textContaining('Warm beige · #C99578'), findsOneWidget);
      expect(find.textContaining('Natural finish · Soft'), findsOneWidget);
      expect(
        find.textContaining('Medium depth · Warm undertone'),
        findsOneWidget,
      );
      expect(find.text('Thin layer across the face'), findsOneWidget);
    },
  );
}
