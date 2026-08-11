import 'package:facetune/features/results/presentation/utils/result_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats enum and style codes for result presentation', () {
    expect(ResultFormatters.label('soft_glam'), 'Soft glam');
    expect(ResultFormatters.label('darkBrown'), 'Dark Brown');
  });
}
