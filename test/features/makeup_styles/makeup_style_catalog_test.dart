import 'package:facetune/features/makeup_styles/domain/catalog/makeup_style_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog exposes the twelve required styles with unique codes', () {
    final styles = MakeupStyleCatalog.styles;

    expect(styles.map((style) => style.name), [
      'Natural',
      'Everyday',
      'Office',
      'Soft Glam',
      'Full Glam',
      'Bridal',
      'Korean',
      'Clean Girl',
      'Party',
      'Date Night',
      'No Makeup Makeup',
      'Old Money',
    ]);
    expect(styles.map((style) => style.code).toSet(), hasLength(styles.length));
    expect(styles.every((style) => style.description.isNotEmpty), isTrue);
  });
}
