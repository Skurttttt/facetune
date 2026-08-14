import 'package:facetune/features/step_by_step_tutorial/domain/entities/tutorial_face_geometry.dart';
import 'package:facetune/features/step_by_step_tutorial/domain/services/tutorial_face_geometry_provider.dart';
import 'package:flutter_test/flutter_test.dart';

TutorialGeometryRegion _region(TutorialGeometrySide side, double x, double y) =>
    TutorialGeometryRegion(
      side: side,
      boundary: [TutorialNormalizedPoint(x: x, y: y)],
    );

TutorialBilateralGeometry _pair({
  double leftX = 0.35,
  double rightX = 0.65,
  double y = 0.4,
}) => TutorialBilateralGeometry(
  left: _region(TutorialGeometrySide.left, leftX, y),
  right: _region(TutorialGeometrySide.right, rightX, y),
);

TutorialFaceGeometry _geometry({double confidence = 0.86}) =>
    TutorialFaceGeometry(
      eyes: _pair(y: 0.38),
      brows: _pair(y: 0.31),
      nose: _region(TutorialGeometrySide.center, 0.5, 0.5),
      lips: _region(TutorialGeometrySide.center, 0.5, 0.68),
      forehead: _region(TutorialGeometrySide.center, 0.5, 0.2),
      cheeks: _pair(y: 0.55),
      jaw: _region(TutorialGeometrySide.center, 0.5, 0.75),
      chin: _region(TutorialGeometrySide.center, 0.5, 0.82),
      faceBoundary: TutorialGeometryRegion(
        side: TutorialGeometrySide.center,
        boundary: [
          TutorialNormalizedPoint(x: 0.2, y: 0.15),
          TutorialNormalizedPoint(x: 0.8, y: 0.15),
          TutorialNormalizedPoint(x: 0.75, y: 0.85),
          TutorialNormalizedPoint(x: 0.25, y: 0.85),
        ],
      ),
      confidence: TutorialGeometryConfidence(
        score: confidence,
        source: TutorialGeometrySource.existingFaceTuneData,
      ),
    );

void main() {
  test('represents every required face region in normalized coordinates', () {
    final geometry = _geometry();

    expect(geometry.eyes.left.centerX, 0.35);
    expect(geometry.eyes.right.centerX, 0.65);
    expect(geometry.brows.left.centerY, 0.31);
    expect(geometry.nose.centerX, 0.5);
    expect(geometry.lips.centerY, 0.68);
    expect(geometry.forehead.centerY, 0.2);
    expect(geometry.cheeks.left.centerY, 0.55);
    expect(geometry.jaw.centerY, 0.75);
    expect(geometry.chin.centerY, 0.82);
    expect(geometry.faceBoundary.boundary, hasLength(4));
  });

  test('rejects non-finite and out-of-bounds normalized coordinates', () {
    for (final invalid in [-0.01, 1.01, double.nan, double.infinity]) {
      expect(
        () => TutorialNormalizedPoint(x: invalid, y: 0.5),
        throwsArgumentError,
        reason: '$invalid must not be accepted',
      );
    }
  });

  test('enforces image-relative left/right side and ordering', () {
    expect(
      () => TutorialBilateralGeometry(
        left: _region(TutorialGeometrySide.right, 0.3, 0.4),
        right: _region(TutorialGeometrySide.left, 0.7, 0.4),
      ),
      throwsArgumentError,
    );
    expect(() => _pair(leftX: 0.7, rightX: 0.3), throwsArgumentError);
  });

  test('geometry is image-size independent', () {
    final point = TutorialNormalizedPoint(x: 0.25, y: 0.75);

    expect(point.x, 0.25);
    expect(point.y, 0.75);
    expect(point.x * 512, 128);
    expect(point.x * 1024, 256);
    expect(point.y * 512, 384);
    expect(point.y * 1024, 768);
  });

  test('retains valid confidence and rejects invalid confidence', () {
    expect(_geometry(confidence: 0).confidence.score, 0);
    expect(_geometry(confidence: 1).confidence.score, 1);
    expect(
      () => TutorialGeometryConfidence(
        score: 1.1,
        source: TutorialGeometrySource.existingFaceTuneData,
      ),
      throwsArgumentError,
    );
  });

  test('provider may honestly return no geometry', () async {
    final provider = _FakeGeometryProvider(null);

    expect(await provider.loadForAnalysis('analysis-1'), isNull);
    expect(provider.lastAnalysisId, 'analysis-1');
  });

  test(
    'provider returns existing normalized geometry without inference',
    () async {
      final expected = _geometry();
      final provider = _FakeGeometryProvider(expected);

      expect(await provider.loadForAnalysis('analysis-2'), same(expected));
    },
  );
}

class _FakeGeometryProvider implements TutorialFaceGeometryProvider {
  _FakeGeometryProvider(this.geometry);

  final TutorialFaceGeometry? geometry;
  String? lastAnalysisId;

  @override
  Future<TutorialFaceGeometry?> loadForAnalysis(String analysisId) async {
    lastAnalysisId = analysisId;
    return geometry;
  }
}
