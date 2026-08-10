import 'package:facetune/features/analysis/data/models/face_analysis_dto.dart';
import 'package:facetune/features/analysis/domain/entities/facial_attributes.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/analysis_response_fixture.dart';

void main() {
  test('parses a valid typed analysis response', () {
    final result = FaceAnalysisDto.fromResponse(validAnalysisResponse).analysis;

    expect(result.attributes.faceShape, FaceShape.oval);
    expect(result.attributes.undertone, Undertone.warm);
    expect(result.confidence.eyeColor, 0.89);
    expect(result.promptVersion, 'face_analysis_v1');
  });

  test('rejects an unsupported enum returned by the server', () {
    final response = _copyResponse();
    final analysis = response['analysis']! as Map<String, Object?>;
    final attributes = analysis['attributes']! as Map<String, Object?>;
    attributes['faceShape'] = 'hexagon';

    expect(() => FaceAnalysisDto.fromResponse(response), throwsFormatException);
  });

  test('rejects an out-of-range confidence value', () {
    final response = _copyResponse();
    final analysis = response['analysis']! as Map<String, Object?>;
    final confidence = analysis['confidence']! as Map<String, Object?>;
    confidence['skinTone'] = 1.5;

    expect(() => FaceAnalysisDto.fromResponse(response), throwsFormatException);
  });
}

Map<String, Object?> _copyResponse() {
  final analysis = validAnalysisResponse['analysis']! as Map<String, Object?>;
  return {
    'analysis': {
      ...analysis,
      'validation': {...(analysis['validation']! as Map<String, Object?>)},
      'attributes': {...(analysis['attributes']! as Map<String, Object?>)},
      'confidence': {...(analysis['confidence']! as Map<String, Object?>)},
    },
  };
}
