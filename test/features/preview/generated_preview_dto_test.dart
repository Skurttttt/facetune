import 'package:facetune/features/preview/data/models/generated_preview_dto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/generated_preview_response_fixture.dart';

void main() {
  test('parses linked generated preview metadata', () {
    final dto = GeneratedPreviewDto.fromResponse(validGeneratedPreviewResponse);
    final result = dto.toDomain(
      originalImageUrl: 'https://signed.example/original',
      generatedImageUrl: 'https://signed.example/generated',
    );

    expect(result.generationNumber, 1);
    expect(result.promptVersion, 'makeup_preview_v1');
    expect(result.generatedImagePath, isNot(result.originalImagePath));
  });

  test('rejects a non-positive variation number', () {
    final response = Map<String, Object?>.from(validGeneratedPreviewResponse);
    final preview = Map<String, Object?>.from(response['preview']! as Map);
    preview['generationNumber'] = 0;
    response['preview'] = preview;

    expect(
      () => GeneratedPreviewDto.fromResponse(response),
      throwsFormatException,
    );
  });
}
